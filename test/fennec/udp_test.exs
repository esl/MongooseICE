defmodule Fennec.UDPTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime,
                                      XORRelayedAddress, ErrorCode,
                                      RequestedTransport}

  @recv_timeout 5000

  describe "binding request" do

    test "returns response with IPv6 XOR mapped address attribute" do
      server_port = 13_100
      server_address = {0, 0, 0, 0, 0, 0, 0, 1}
      client_port = 43_100
      client_address = {0, 0, 0, 0, 0, 0, 0, 1}
      Fennec.UDP.start_link(ip: server_address, port: server_port)
      id = :crypto.strong_rand_bytes(12)
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
      id = :crypto.strong_rand_bytes(12)
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
      id = :crypto.strong_rand_bytes(12)
      req = allocate_request(id, [
        %RequestedTransport{protocol: :udp},
        %Lifetime{duration: 5}
      ])

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 420} = error
    end

    test "returns response with IPv6 XOR relayed address attribute", ctx do
      udp = ctx.udp
      %{server_address: server_address, client_address: client_address} = udp
      client_port = client_port(udp, 0)
      id = :crypto.strong_rand_bytes(12)
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
      id1 = :crypto.strong_rand_bytes(12)
      id2 = :crypto.strong_rand_bytes(12)
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
      id = :crypto.strong_rand_bytes(12)
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



  test "start/1 and stop/1 a UDP server linked to Fennec.Supervisor" do
    port = 23_232
    {:ok, _} = Fennec.UDP.start(ip: {127, 0, 0, 1}, port: port)

    assert [{:"Elixir.Fennec.UDP.23232", _, _, _}] =
      Supervisor.which_children(Fennec.Supervisor)
    assert :ok = Fennec.UDP.stop(port)
    assert [] = Supervisor.which_children(Fennec.Supervisor)
  end

  defp binding_request(id) do
    %Params{class: :request, method: :binding, identifier: id} |> Format.encode()
  end

  defp binding_indication(id) do
    %Params{class: :indication, method: :binding, identifier: id} |> Format.encode()
  end

  defp allocate_request(id) do
    allocate_request(id, [%RequestedTransport{protocol: :udp}])
  end

  defp allocate_request(id, attrs) do
    %Params{class: :request, method: :allocate, identifier: id,
            attributes: attrs}
    |> Format.encode()
  end

  defp udp_connect(server_address, server_port, client_address, client_port,
                   client_count) do
    Application.put_env(:fennec, :relay_addr, server_address)
    Fennec.UDP.start_link(ip: server_address, port: server_port)

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

  defp client_port(udp, client_id) do
     udp.client_port_base + client_id + 1
  end
end
