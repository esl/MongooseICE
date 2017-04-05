defmodule Helper.UDP do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime,
                                      XORRelayedAddress, ErrorCode,
                                      RequestedTransport, EvenPort,
                                      ReservationToken, XORPeerAddress}

  import Mock

  @recv_timeout 5_000

  def binding_request(id) do
    %Params{class: :request, method: :binding, identifier: id} |> Format.encode()
  end

  def binding_indication(id) do
    %Params{class: :indication, method: :binding, identifier: id} |> Format.encode()
  end

  def allocate_request(id) do
    allocate_request(id, [%RequestedTransport{protocol: :udp}])
  end

  def peers(peers) do
    for {ip, port} <- peers do
      %XORPeerAddress{
        address: ip,
        port: port,
        family: Fennec.Evaluator.Helper.family(ip)
      }
    end
  end

  def create_permissions_request(id, attrs) do
    %Params{class: :request, method: :create_permission, identifier: id,
            attributes: attrs}
    |> Format.encode()
  end

  def allocate_params(id, attrs) do
    %Params{class: :request, method: :allocate, identifier: id,
            attributes: attrs}
  end

  def allocate_request(id, attrs) do
    allocate_params(id, attrs)
    |> Format.encode()
  end

  def udp_connect(server_address, server_port, client_address, client_port,
                   client_count) do
    Application.put_env(:fennec, :relay_addr, server_address)
    Fennec.UDP.start_link(ip: server_address, port: server_port,
                          relay_ip: server_address)

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

  def udp_allocate(udp) do
    id = Params.generate_id()
    req = allocate_request(id)
    resp = udp_communicate(udp, 0, req)
    params = Format.decode!(resp)
    %Params{class: :success,
            method: :allocate,
            identifier: ^id} = params
  end

  def udp_close(%{sockets: sockets}) do
    for sock <- sockets do
      :gen_udp.close(sock)
    end
  end

  def udp_send(udp, client_id, req) do
    sock = Enum.at(udp.sockets, client_id)
    :ok = :gen_udp.send(sock, udp.server_address, udp.server_port, req)
  end

  def udp_recv(udp, client_id) do
    %{server_address: server_address, server_port: server_port} = udp
    {sock, _} = List.pop_at(udp.sockets, client_id)
    {:ok, {^server_address,
           ^server_port,
           resp}} = :gen_udp.recv(sock, 0, @recv_timeout)
    resp
  end

  def udp_communicate(udp, client_id, req) do
    with_mock Fennec.Auth, [:passthrough], [
      maybe: fn(_, p, _, _) -> {:ok, p} end
    ] do
     :ok = udp_send(udp, client_id, req)
     udp_recv(udp, client_id)
   end
  end

  def client_port(udp, client_id) do
     udp.client_port_base + client_id + 1
  end
end
