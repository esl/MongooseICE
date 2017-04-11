defmodule Fennec.UDP.SendTest do
  use ExUnit.Case, async: false
  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{ErrorCode, XORPeerAddress, Data,
                                      XORRelayedAddress}

  setup ctx do
    {:ok, [udp: UDP.setup_connection(ctx, :ipv4)]}
  end

  describe "send request with no allocation" do
    test "gets rejected", ctx do
      udp = ctx.udp

      id = Params.generate_id()
      peer = XORPeerAddress.new({127, 0, 0, 1}, 12345)
      data = %Data{content: ""}
      req = UDP.send_request(id, [peer, data])

      resp = no_auth(communicate_all(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :send,
                     identifier: ^id} = params

      assert %ErrorCode{code: 437} = Params.get_attr(params, ErrorCode)
    end
  end

  describe "send request with allocation" do
    setup ctx do
      UDP.allocate(ctx.udp)
      {:ok, []}
    end

    test "gets rejected when there's no permission", ctx do
      udp = ctx.udp

      id = Params.generate_id()
      peer = XORPeerAddress.new({127, 0, 0, 1}, 12345)
      data = %Data{content: ""}
      req = UDP.send_request(id, [peer, data])

      resp = no_auth(communicate_all(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :send,
                     identifier: ^id} = params

      assert %ErrorCode{code: 403} = Params.get_attr(params, ErrorCode)
    end

    test "gets rejected when no peer is given", ctx do
      udp = ctx.udp

      id = Params.generate_id()
      req = UDP.send_request(id, [%Data{content: ""}])

      resp = no_auth(communicate_all(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :send,
                     identifier: ^id} = params

      assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
    end

    test "gets rejected when no data is given", ctx do
      udp = ctx.udp

      id = Params.generate_id()
      peer = XORPeerAddress.new({127, 0, 0, 1}, 12345)
      req = UDP.send_request(id, [peer])

      resp = no_auth(communicate_all(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :send,
                     identifier: ^id} = params

      assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
    end
  end

  describe "send request with allocation and permission" do
    setup ctx do
      allocate_params = UDP.allocate(ctx.udp)

      UDP.create_permissions(ctx.udp, [{127, 0, 0, 1}])
      {:ok, [relay_sock: Params.get_attr(allocate_params, XORRelayedAddress)]}
    end

    test "delivers data to peer", ctx do
      udp = ctx.udp
      {:ok, sock} = :gen_udp.open(0, [{:active, true}, :binary])
      {:ok, port} = :inet.port(sock)

      id = Params.generate_id()
      peer = XORPeerAddress.new({127, 0, 0, 1}, port)
      data = %Data{content: "some content"}
      req = UDP.send_request(id, [peer, data])

      resp = no_auth(communicate_all(udp, 0, req))

      # Check whether indication was processed with success
      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :send,
                     identifier: ^id} = params

      # Check whether peer got the data
      relay_ip = ctx.relay_sock.address
      relay_port = ctx.relay_sock.port
      assert_receive {:udp, ^sock, ^relay_ip, ^relay_port, "some content"}
    end
  end
end
