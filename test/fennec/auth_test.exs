defmodule Fennec.AuthTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{Username, ErrorCode,
                                      RequestedTransport, Nonce, Realm}

  @recv_timeout 5000
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
      allocate_request(id)
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
      allocate_request(id)
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
      allocate_request(id, attrs)
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
      allocate_request(id, attrs)
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
      allocate_request(id, attrs)
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
      allocate_request(id, attrs)
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
      allocate_request(id, attrs)
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
      allocate_request(id, attrs)
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
      allocate_request(id, attrs)
      |> Format.encode(secret: @valid_secret)

    resp = udp_communicate(udp, 0, req)

    params = Format.decode!(resp)
    assert %Params{class: :success,
                   method: :allocate,
                   identifier: ^id} = params
  end

  defp allocate_request(id) do
    allocate_request(id, [%RequestedTransport{protocol: :udp}])
  end

  defp allocate_request(id, attrs) do
    %Params{class: :request, method: :allocate, identifier: id,
            attributes: attrs}
  end

  defp udp_connect(server_address, server_port, client_address, client_port,
                   client_count) do
    Application.put_env(:fennec, :relay_addr, server_address)
    Fennec.UDP.start_link(ip: server_address, port: server_port,
                          relay_ip: server_address, realm: "localhost")

    sockets =
      for i <- 1..client_count do
        {:ok, sock} =
          :gen_udp.open(client_port + i,
                        [:binary, active: false, ip: client_address])
          sock
      end

    %{
      server_address: server_address,
      server_port: server_port,
      client_address: client_address,
      client_port_base: client_port,
      sockets: sockets
    }
  end

  defp udp_close(%{sockets: sockets}) do
    for sock <- sockets do
      :gen_udp.close(sock)
    end
  end

  defp udp_send(udp, client_id, req) do
    sock = Enum.at(udp.sockets, client_id)
    :ok = :gen_udp.send(sock, udp.server_address, udp.server_port, req)
  end

  defp udp_recv(udp, client_id) do
    %{server_address: server_address, server_port: server_port} = udp
    {sock, _} = List.pop_at(udp.sockets, client_id)
    assert {:ok,
            {^server_address,
             ^server_port,
             resp}} = :gen_udp.recv(sock, 0, @recv_timeout)
    resp
  end

  defp udp_communicate(udp, client_id, req) do
    :ok = udp_send(udp, client_id, req)
    udp_recv(udp, client_id)
  end

  defp get_nonce(udp) do
    id = Params.generate_id()
    req =
      allocate_request(id)
      |> Format.encode()
    resp = udp_communicate(udp, 0, req)
    Params.get_attr(Format.decode!(resp), Nonce)
  end
end
