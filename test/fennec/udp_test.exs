defmodule Fennec.UDPTest do
  use ExUnit.Case

  import Helper.UDP

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime,
                                      XORRelayedAddress, ErrorCode,
                                      RequestedTransport, EvenPort,
                                      ReservationToken, XORPeerAddress}

  import Mock

  @recv_timeout 5000

  describe "binding request" do

    test "returns response with IPv6 XOR mapped address attribute" do
      server_port = 13_100
      server_address = {0, 0, 0, 0, 0, 0, 0, 1}
      client_port = 43_100
      client_address = {0, 0, 0, 0, 0, 0, 0, 1}
      Fennec.UDP.start_link(ip: server_address, port: server_port)
      id = Params.generate_id()
      req = binding_request(id)

      {:ok, sock} = :gen_udp.open(client_port,
                                  [:binary, active: false, ip: client_address])
      :ok = :gen_udp.send(sock, server_address, server_port, req)

      assert {:ok,
              {^server_address,
               ^server_port,
               resp}} = :gen_udp.recv(sock, 0, @recv_timeout)
      :gen_udp.close(sock)
      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :binding,
                     identifier: ^id,
                     attributes: [a]} = params
      assert %XORMappedAddress{address: ^client_address,
                               port: ^client_port,
                               family: :ipv6} = a
    end
  end

  describe "allocate request" do

    setup ctx do
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

    test "fails without RequestedTransport attribute", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = allocate_request(id, [])

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 400} = error
    end

    test "fails with unknown attribute", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = allocate_request(id, [
        %RequestedTransport{protocol: :udp},
        %EvenPort{}
      ])

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 420} = error
    end

    test "fails if EvenPort and ReservationToken are supplied", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = allocate_request(id, [
        %RequestedTransport{protocol: :udp},
        %EvenPort{},
        %ReservationToken{value: "12345678"}
      ])

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 400} = error
    end

    test "returns response with IPv6 XOR relayed address attribute", ctx do
      udp = ctx.udp
      %{server_address: server_address, client_address: client_address} = udp
      client_port = client_port(udp, 0)
      id = Params.generate_id()
      req = allocate_request(id)

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id,
                     attributes: attrs} = params
      [lifetime, mapped, relayed] = Enum.sort(attrs)

      assert %Lifetime{duration: 600} = lifetime

      assert %XORMappedAddress{address: ^client_address,
                               port: ^client_port,
                               family: :ipv6} = mapped

      assert %XORRelayedAddress{address: ^server_address,
                                port: relayed_port,
                                family: :ipv6} = relayed
      assert relayed_port != udp.server_port
    end

    test "returns error after second allocation", ctx do
      udp = ctx.udp
      id1 = Params.generate_id()
      id2 = Params.generate_id()
      req1 = allocate_request(id1)
      req2 = allocate_request(id2)

      _resp = udp_communicate(udp, 0, req1)
      resp = udp_communicate(udp, 0, req2)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id2,
                     attributes: [error]} = params
      assert %ErrorCode{code: 437} = error
    end

    test "returns success after redundant allocation", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = allocate_request(id)

      _resp = udp_communicate(udp, 0, req)
      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id,
                     attributes: attrs} = params
      assert 3 = length(attrs)
    end
  end

  describe "create_permission request" do

    setup ctx do
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

    test "fails without XORPeerAddress attribute", ctx do
      udp = ctx.udp
      udp_allocate(udp)

      id = Params.generate_id()
      req = create_permissions_request(id, [])

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :create_permission,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 400} = error
    end

    test "fails without active allocation", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = create_permissions_request(id, [])

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :create_permission,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 437} = error
    end

    test "succeeds with one XORPeerAddress", ctx do
      udp = ctx.udp
      udp_allocate(udp)

      id = Params.generate_id()
      peers = peers([{{123,123,6,1}, 1234}])
      req = create_permissions_request(id, peers)

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :create_permission,
                     identifier: ^id} = params
    end

    test "succeeds with multiple XORPeerAddress", ctx do
      udp = ctx.udp
      udp_allocate(udp)

      id = Params.generate_id()
      peers = peers([
        {{123,123,6,1}, 1231},
        {{123,123,6,2}, 1232},
        {{123,123,6,3}, 1233},
      ])
      req = create_permissions_request(id, peers)

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :create_permission,
                     identifier: ^id} = params
    end

  end

  test "start/1 and stop/1 a UDP server linked to Fennec.Supervisor" do
    port = 23_232
    {:ok, _} = Fennec.UDP.start(ip: {127, 0, 0, 1}, port: port)

    assert [{:"Elixir.Fennec.UDP.23232", _, _, _}] =
      Supervisor.which_children(Fennec.Supervisor)
    assert :ok = Fennec.UDP.stop(port)
    assert [] = Supervisor.which_children(Fennec.Supervisor)
  end
end
