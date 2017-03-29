defmodule Fennec.UDPTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime,
                                      XORRelayedAddress, ErrorCode}

  @recv_timeout 5000

  describe "binding request" do

    test "returns response with IPv6 XOR mapped address attribute" do
      server_port = 12_121
      server_address = {0, 0, 0, 0, 0, 0, 0, 1}
      client_port = 43_434
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

    test "returns response with IPv6 XOR relayed address attribute" do
      server_port = 12_122
      server_address = {0, 0, 0, 0, 0, 0, 0, 1}
      client_port = 43_435
      client_address = {0, 0, 0, 0, 0, 0, 0, 1}
      Application.put_env(:fennec, :relay_addr, server_address)

      Fennec.UDP.start_link(ip: server_address, port: server_port)
      id = :crypto.strong_rand_bytes(12)
      req = allocate_request(id)

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
      assert relayed_port != server_port
    end

    test "returns error after second allocation" do
      server_port = 12_123
      server_address = {127, 0, 0, 1}
      client_port = 43_436
      client_address = {127, 0, 0, 1}
      Application.put_env(:fennec, :relay_addr, server_address)

      Fennec.UDP.start_link(ip: server_address, port: server_port)
      id1 = :crypto.strong_rand_bytes(12)
      id2 = :crypto.strong_rand_bytes(12)
      req1 = allocate_request(id1)
      req2 = allocate_request(id2)

      {:ok, sock} = :gen_udp.open(client_port,
                                  [:binary, active: false, ip: client_address])

      :ok = :gen_udp.send(sock, server_address, server_port, req1)
      assert {:ok,
              {^server_address,
               ^server_port,
               _resp}} = :gen_udp.recv(sock, 0, @recv_timeout)

      :ok = :gen_udp.send(sock, server_address, server_port, req2)
      assert {:ok,
              {^server_address,
               ^server_port,
               resp}} = :gen_udp.recv(sock, 0, @recv_timeout)


      :gen_udp.close(sock)
      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id2,
                     attributes: [error]} = params
      assert %ErrorCode{code: 437} = error
    end

    test "returns success after redundant allocation" do
      server_port = 12_125
      server_address = {127, 0, 0, 1}
      client_port = 43_437
      client_address = {127, 0, 0, 1}
      Application.put_env(:fennec, :relay_addr, server_address)

      Fennec.UDP.start_link(ip: server_address, port: server_port)
      id = :crypto.strong_rand_bytes(12)
      req = allocate_request(id)

      {:ok, sock} = :gen_udp.open(client_port,
                                  [:binary, active: false, ip: client_address])

      :ok = :gen_udp.send(sock, server_address, server_port, req)
      assert {:ok,
              {^server_address,
               ^server_port,
               _resp}} = :gen_udp.recv(sock, 0, @recv_timeout)

      :ok = :gen_udp.send(sock, server_address, server_port, req)
      assert {:ok,
              {^server_address,
               ^server_port,
               resp}} = :gen_udp.recv(sock, 0, @recv_timeout)


      :gen_udp.close(sock)
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

    assert [{:"Elixir.Fennec.UDP.23232", _, _, _}] = Supervisor.which_children(Fennec.Supervisor)
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
    %Params{class: :request, method: :allocate, identifier: id} |> Format.encode()
  end
end
