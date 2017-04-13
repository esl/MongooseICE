defmodule Fennec.UDP.DataTest do
  use ExUnit.Case, async: false
  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{Data, XORPeerAddress, XORRelayedAddress}

  import Mock

  @peer_addr {127, 0, 0, 1}

  setup ctx do
    {:ok, [udp: UDP.setup_connection(ctx, :ipv4)]}
  end

  describe "incoming peer datagram" do

    setup ctx do
      params = UDP.allocate(ctx.udp)
      {:ok, [relay_sock: Params.get_attr(params, XORRelayedAddress)]}
    end

    test "gets discarded when there's no permission for peer", ctx do
      ## given a relay address for a peer with no permission
      %XORRelayedAddress{address: relay_addr, port: relay_port} = ctx.relay_sock
      {:ok, peer} = :gen_udp.open(0, [{:active, :false}, :binary])
      {:ok, peer_port} = :inet.port(peer)
      self_ = self()
      with_mock Fennec.UDP.Worker, [:passthrough], [
        handle_peer_data: fn (:no_permission, ip, port, data, state) ->
          ## we can't use `assert called ...` as we want to ignore `state`
          send self_, {:no_permission, ip, port, data}
          :meck.passthrough([:no_permission, ip, port, data, state])
        end
      ] do
        ## when the peer sends a datagram
        data = "arbitrary data"
        :ok = :gen_udp.send(peer, relay_addr, relay_port, data)
        ## then the datagram gets silently discarded
        ## we can't use `assert called ...` as we want to ignore `state`
        receive do
          {:no_permission, @peer_addr, ^peer_port, ^data} ->
            :ok
          after 3000 ->
            flunk("handle_peer_data timeout")
          end
      end
    end

  end

  describe "incoming peer datagram with permission" do

    setup ctx do
      params = UDP.allocate(ctx.udp)
      UDP.create_permissions(ctx.udp, [@peer_addr])
      {:ok, [relay_sock: Params.get_attr(params, XORRelayedAddress)]}
    end

    test "is relayed as a Data indication", ctx do
      ## given a relay address for a peer
      %XORRelayedAddress{address: relay_addr, port: relay_port} = ctx.relay_sock
      {:ok, peer} = :gen_udp.open(0, [{:active, :false}, :binary])
      {:ok, peer_port} = :inet.port(peer)
      ## when the peer sends a datagram
      data = "arbitrary data"
      :ok = :gen_udp.send(peer, relay_addr, relay_port, data)
      ## then the datagram payload gets delivered as a Data indication
      raw = UDP.recv(ctx.udp, _client_id = 0)
      params = Format.decode!(raw)
      assert %Params{class: :indication,
                     method: :data,
                     attributes: attrs} = params
      assert %XORPeerAddress{address: @peer_addr,
                             port: peer_port,
                             family: :ipv4} == Params.get_attr(params, XORPeerAddress)
      assert %Data{content: data} == Params.get_attr(params, Data)
    end

  end

end
