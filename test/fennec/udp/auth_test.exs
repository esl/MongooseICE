defmodule Fennec.UDP.AuthTest do
  use ExUnit.Case

  # We need to override udp_communicate/3 since default implementation in
  # Helpers.UDP skips authentication and authorization
  import Helper.UDP, except: [udp_communicate: 3]

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{Username, ErrorCode,
                                      RequestedTransport, Nonce, Realm}



  @max_value_bytes 763 - 1
  @max_value_chars 128 - 1
  @valid_secret "abc"
  @invalid_secret "abcd"

  setup ctx do
    Application.put_env(:fennec, :secret, @valid_secret)
    test_case_id = ctx.line
    port_mod = test_case_id * 10
    udp =
      udp_connect({0, 0, 0, 0, 0, 0, 0, 1}, 12_100 + port_mod,
                  {0, 0, 0, 0, 0, 0, 0, 1}, 42_100 + port_mod, 1)
    on_exit fn ->
      udp_close(udp)
    end

    {:ok, [udp: udp]}
  end

  test "empty request returns nonce and realm", ctx do
    udp = ctx.udp
    id = Params.generate_id()
    req =
      allocate_params(id, [%RequestedTransport{protocol: :udp}])
      |> Format.encode()

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :failure,
                   method: :allocate,
                   identifier: ^id} = params

    assert %ErrorCode{code: 401} = Params.get_attr(params, ErrorCode)
    assert %Nonce{value: nonce} = Params.get_attr(params, Nonce)
    assert %Realm{value: realm} = Params.get_attr(params, Realm)

    assert String.length(nonce) > 0
    assert String.length(nonce) <= @max_value_chars
    assert byte_size(nonce) <= @max_value_bytes

    assert String.length(realm) > 0
    assert String.length(realm) <= @max_value_chars
    assert byte_size(realm) <= @max_value_bytes
  end

  test "request with all missing attributes fails to authenticate", ctx do
    udp = ctx.udp
    id = Params.generate_id()
    req =
      allocate_params(id, [%RequestedTransport{protocol: :udp}])
      |> Format.encode(secret: @valid_secret, realm: "realm", username: "user")

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :failure,
                   method: :allocate,
                   identifier: ^id} = params

    assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
  end

  test "request with missing nonce attribute fails to authenticate", ctx do
    udp = ctx.udp
    id = Params.generate_id()
    attrs = [
      %RequestedTransport{protocol: :udp},
      %Realm{value: "localhost"},
      %Username{value: "user"}
    ]
    req =
      allocate_params(id, attrs)
      |> Format.encode(secret: @valid_secret)

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :failure,
                   method: :allocate,
                   identifier: ^id} = params

    assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
  end

  test "request with missing username attributes fails to authenticate", ctx do
    udp = ctx.udp
    id = Params.generate_id()
    attrs = [
      %RequestedTransport{protocol: :udp},
      %Realm{value: "localhost"},
      %Nonce{value: "nonce"}
    ]
    req =
      allocate_params(id, attrs)
      |> Format.encode(secret: @valid_secret, username: "user")

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :failure,
                   method: :allocate,
                   identifier: ^id} = params

    assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
  end

  test "request with missing realm attributes fails to authenticate", ctx do
    udp = ctx.udp
    id = Params.generate_id()
    attrs = [
      %RequestedTransport{protocol: :udp},
      %Username{value: "user"}
    ]
    req =
      allocate_params(id, attrs)
      |> Format.encode(secret: @valid_secret, realm: "localhost")

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :failure,
                   method: :allocate,
                   identifier: ^id} = params

    assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
  end

  test "request with invalid secret fails to authenticate", ctx do
    udp = ctx.udp
    nonce_attr = get_nonce(udp)
    id = Params.generate_id()
    attrs = [
      %RequestedTransport{protocol: :udp},
      %Username{value: "user"},
      %Realm{value: "localhost"},
      nonce_attr
    ]
    req =
      allocate_params(id, attrs)
      |> Format.encode(secret: @invalid_secret)

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :failure,
                   method: :allocate,
                   identifier: ^id} = params

    assert %ErrorCode{code: 401} = Params.get_attr(params, ErrorCode)
  end

  test "request with no message integrity fails to authenticate", ctx do
    udp = ctx.udp
    nonce_attr = get_nonce(udp)
    id = Params.generate_id()
    attrs = [
      %RequestedTransport{protocol: :udp},
      %Username{value: "user"},
      %Realm{value: "localhost"},
      nonce_attr
    ]
    req =
      allocate_params(id, attrs)
      |> Format.encode()

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :failure,
                   method: :allocate,
                   identifier: ^id} = params

    assert %ErrorCode{code: 401} = Params.get_attr(params, ErrorCode)
  end

  test "request with invalid nonce fails to authenticate", ctx do
    udp = ctx.udp
    id = Params.generate_id()
    attrs = [
      %RequestedTransport{protocol: :udp},
      %Username{value: "user"},
      %Realm{value: "localhost"},
      %Nonce{value: "some_invalid_nonce...hopefully"}
    ]
    req =
      allocate_params(id, attrs)
      |> Format.encode(secret: @valid_secret)

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :failure,
                   method: :allocate,
                   identifier: ^id} = params

    assert %ErrorCode{code: 438} = Params.get_attr(params, ErrorCode)
    assert %Nonce{value: nonce} = Params.get_attr(params, Nonce)
    assert %Realm{value: realm} = Params.get_attr(params, Realm)

    assert String.length(nonce) > 0
    assert String.length(nonce) <= @max_value_chars
    assert byte_size(nonce) <= @max_value_bytes

    assert String.length(realm) > 0
    assert String.length(realm) <= @max_value_chars
    assert byte_size(realm) <= @max_value_bytes
  end

  test "request with valid nonce authenticate successfully", ctx do
    udp = ctx.udp
    id = Params.generate_id()
    nonce_attr = get_nonce(udp)
    attrs = [
      %RequestedTransport{protocol: :udp},
      %Username{value: "user"},
      %Realm{value: "localhost"},
      nonce_attr
    ]
    req =
      allocate_params(id, attrs)
      |> Format.encode(secret: @valid_secret)

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :success,
                   method: :allocate,
                   identifier: ^id} = params
  end

  test "request with differet username fails to authorize", ctx do
    udp = ctx.udp
    id = Params.generate_id()
    nonce_attr = get_nonce(udp)
    attrs = [
      %RequestedTransport{protocol: :udp},
      %Username{value: "user"},
      %Realm{value: "localhost"},
      nonce_attr
    ]
    req =
      allocate_params(id, attrs)
      |> Format.encode(secret: @valid_secret)

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :success,
                   method: :allocate,
                   identifier: ^id} = params
  end

  def udp_communicate(udp, client_id, req) do
    :ok = udp_send(udp, client_id, req)
    udp_recv(udp, client_id)
  end

  defp get_nonce(udp) do
    id = Params.generate_id()
    req = allocate_request(id)
    resp = udp_communicate(udp, 0, req)
    Params.get_attr(Format.decode!(resp), Nonce)
  end
end
