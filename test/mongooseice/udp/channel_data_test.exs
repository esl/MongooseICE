defmodule MongooseICE.UDP.ChannelDataTest do
  use ExUnit.Case, async: false
  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.{Params, ChannelData}
  alias Jerboa.Format.Body.Attribute.{Lifetime, XORRelayedAddress,
                                      XORPeerAddress}

  import Mock

  @recv_timeout 1_000

  setup ctx do
    sockets_count = ctx[:sockets] || 2
    udp = UDP.connect({127, 0, 0, 1}, {127, 0, 0, 1}, sockets_count)
    peer_port = UDP.port(udp, 1)
    peer_socket = UDP.socket(udp, 1)
    client_socket = UDP.socket(udp, 0)

    allocate_ctx =
      if ctx[:allocate] do
        resp = UDP.allocate(udp)
        xor_relayed_addr = Params.get_attr(resp, XORRelayedAddress)
        [relay_ip: xor_relayed_addr.address,
         relay_port: xor_relayed_addr.port]
      else
        []
      end

    on_exit fn ->
      UDP.close(udp)
    end

    {:ok, allocate_ctx ++ [udp: udp,
                           peer_socket: peer_socket,
                           peer_port: peer_port,
                           client_socket: client_socket]}
  end

  describe "from TURN client to peer" do
    test "doesn't relay without an allocation", %{udp: udp, peer_socket: peer} do
      channel_data = UDP.channel_data(0x4000, "hello")

      UDP.send(udp, 0, channel_data)

      assert {:error, :timeout} = :gen_udp.recv peer, 0, @recv_timeout
    end

    @tag :allocate
    test "doesn't relay without channel bound",
      %{udp: udp, peer_socket: peer} do
      channel_data = UDP.channel_data(0x4000, "hello")

      UDP.send(udp, 0, channel_data)

      assert {:error, :timeout} = :gen_udp.recv peer, 0, @recv_timeout
    end

    @tag :allocate
    test "doesn't relay without channel bound but with permission",
      %{udp: udp, peer_socket: peer} do
      UDP.create_permissions(udp, [{127, 0, 0, 1}])
      channel_data = UDP.channel_data(0x4000, "hello")

      UDP.send(udp, 0, channel_data)

      assert {:error, :timeout} = :gen_udp.recv peer, 0, @recv_timeout
      worker = UDP.worker(udp, 0)
      assert %{{127, 0, 0, 1} => _} = GenServer.call(worker, :get_permissions)
    end

    @tag :allocate
    test "relays data with channel bound",
      %{udp: udp, peer_socket: peer, peer_port: port} do
      channel_number = 0x4000
      UDP.channel_bind(udp, channel_number, {127, 0, 0, 1}, port)
      data = "hello"
      channel_data = UDP.channel_data(channel_number, data)

      UDP.send(udp, 0, channel_data)

      assert {:ok, {_, _, ^data}} = :gen_udp.recv peer, 0, @recv_timeout
    end

    @tag :allocate
    test "doesn't relay if permission expired but channel is still bound",
      %{udp: udp, peer_socket: peer, peer_port: port} do
      channel_number = 0x4000
      UDP.channel_bind(udp, channel_number, {127, 0, 0, 1}, port)
      data = "hello"
      channel_data = UDP.channel_data(channel_number, data)

      time_passed = 8 * 60 # permission expires after 5 minutes, channel after 10
      with_mock MongooseICE.Time, [:passthrough], [
        system_time: fn (:second) -> :meck.passthrough([:second]) + time_passed end
      ] do
        UDP.send(udp, 0, channel_data)

        assert {:error, :timeout} = :gen_udp.recv peer, 0, @recv_timeout
        worker = UDP.worker(udp, 0)
        assert %{} == GenServer.call(worker, :get_permissions)
        assert [_] = GenServer.call(worker, :get_channels)
      end
    end

    @tag :allocate
    test "doesn't relay if channel expired",
      %{udp: udp, peer_socket: peer, peer_port: port} do
      channel_number = 0x4000
      UDP.channel_bind(udp, channel_number, {127, 0, 0, 1}, port)
      data = "hello"
      channel_data = UDP.channel_data(channel_number, data)

      # we need to refresh the allocation so that it doesn't time out
      UDP.refresh(udp, [%Lifetime{duration: 20 * 60}])
      time_passed = 11 * 60 # channel expires after 10 minutes
      with_mock MongooseICE.Time, [:passthrough], [
        system_time: fn (:second) -> :meck.passthrough([:second]) + time_passed end
      ] do
        UDP.send(udp, 0, channel_data)

        assert {:error, :timeout} = :gen_udp.recv peer, 0, @recv_timeout
        worker = UDP.worker(udp, 0)
        assert [] == GenServer.call(worker, :get_channels)
      end
    end

    @tag allocate: true, sockets: 3
    test "relays data only to peer bound to channel",
      %{udp: udp, peer_socket: peer_socket1, peer_port: peer_port1} do
      peer_socket2 = UDP.socket(udp, 2)
      channel_number = 0x4000
      UDP.channel_bind(udp, channel_number, {127, 0, 0, 1}, peer_port1)
      data = "hello"
      channel_data = UDP.channel_data(channel_number, data)

      UDP.send(udp, 0, channel_data)

      assert {:ok, {_, _, ^data}} = :gen_udp.recv peer_socket1, 0, @recv_timeout
      assert {:error, :timeout} = :gen_udp.recv peer_socket2, 0, @recv_timeout
    end
  end

  describe "from peer to TURN client" do
    @tag :allocate
    test "doesn't relay without channel bound", ctx do
      %{client_socket: client, peer_socket: peer,
        relay_ip: relay_ip, relay_port: relay_port} = ctx
      data = "hello"

      :ok = :gen_udp.send peer, relay_ip, relay_port, data

      assert {:error, :timeout} = :gen_udp.recv client, 0, @recv_timeout
    end

    @tag :allocate
    test "doesn't relay over channel without channel bound but with permission",
      ctx do
      %{udp: udp, client_socket: client, peer_socket: peer,
        relay_ip: relay_ip, relay_port: relay_port} = ctx
      UDP.create_permissions(udp, [{127, 0, 0, 1}])
      data = "hello"

      :ok = :gen_udp.send peer, relay_ip, relay_port, data

      assert {:ok, {_, _, payload}} = :gen_udp.recv client, 0, @recv_timeout
      assert {:ok, %Params{method: :data}} = Jerboa.Format.decode(payload)
      worker = UDP.worker(udp, 0)
      assert %{{127, 0, 0, 1} => _} = GenServer.call(worker, :get_permissions)
    end

    @tag :allocate
    test "relays data with channel bound", ctx do
      %{udp: udp, client_socket: client, peer_socket: peer,
        peer_port: peer_port, relay_ip: relay_ip, relay_port: relay_port} = ctx
      channel_number = 0x4000
      UDP.channel_bind(udp, channel_number, {127, 0, 0, 1}, peer_port)
      data = "hello"

      :ok = :gen_udp.send peer, relay_ip, relay_port, data

      assert {:ok, {_, _, payload}} = :gen_udp.recv client, 0, @recv_timeout
      assert {:ok, %ChannelData{data: data, channel_number: channel_number}} ==
        Jerboa.Format.decode(payload)
    end

    @tag :allocate
    test "doesn't relay if permission expired but channel is still bound", ctx do
      %{udp: udp, client_socket: client, peer_socket: peer,
        peer_port: peer_port, relay_ip: relay_ip, relay_port: relay_port} = ctx
      channel_number = 0x4000
      UDP.channel_bind(udp, channel_number, {127, 0, 0, 1}, peer_port)
      data = "hello"

      time_passed = 8 * 60 # permission expires after 5 minutes, channel after 10
      with_mock MongooseICE.Time, [:passthrough], [
        system_time: fn (:second) -> :meck.passthrough([:second]) + time_passed end
      ] do
        :ok = :gen_udp.send peer, relay_ip, relay_port, data

        assert {:error, :timeout} = :gen_udp.recv client, 0, @recv_timeout
        worker = UDP.worker(udp, 0)
        assert %{} == GenServer.call(worker, :get_permissions)
        assert [_] = GenServer.call(worker, :get_channels)
      end
    end

    @tag :allocate
    test "doesn't relay over channel if channel expired", ctx do
      %{udp: udp, client_socket: client, peer_socket: peer,
        peer_port: peer_port, relay_ip: relay_ip, relay_port: relay_port} = ctx
      channel_number = 0x4000
      UDP.channel_bind(udp, channel_number, {127, 0, 0, 1}, peer_port)
      data = "hello"

      # we need to refresh the allocation so that it doesn't time out
      UDP.refresh(udp, [%Lifetime{duration: 20 * 60}])
      time_passed = 11 * 60 # channel expires after 10 minutes
      with_mock MongooseICE.Time, [:passthrough], [
        system_time: fn (:second) -> :meck.passthrough([:second]) + time_passed end
      ] do
        :ok = :gen_udp.send peer, relay_ip, relay_port, data

        assert {:error, :timeout} = :gen_udp.recv client, 0, @recv_timeout
        worker = UDP.worker(udp, 0)
        assert [] == GenServer.call(worker, :get_channels)
      end
    end

    @tag allocate: true, sockets: 3
    test "relays data over channel only from peer bound to channel", ctx do
      %{udp: udp, client_socket: client, peer_socket: peer_socket1,
        peer_port: peer_port1, relay_ip: relay_ip, relay_port: relay_port} = ctx
      peer_socket2 = UDP.socket(udp, 2)
      peer_port2 = UDP.port(udp, 2)
      channel_number = 0x4000
      UDP.channel_bind(udp, channel_number, {127, 0, 0, 1}, peer_port1)
      data = "hello"

      :ok = :gen_udp.send peer_socket1, relay_ip, relay_port, data
      :ok = :gen_udp.send peer_socket2, relay_ip, relay_port, data

      {:ok, {_, _, recv1}} = :gen_udp.recv client, 0, @recv_timeout
      {:ok, {_, _, recv2}} = :gen_udp.recv client, 0, @recv_timeout

      assert {[channel_data], [params]} =
        [recv1, recv2]
        |> Enum.map(&Jerboa.Format.decode!/1)
        |> Enum.split_with(fn msg ->
          case msg do
            %ChannelData{} -> true
            _              -> false
          end
        end)
      assert %ChannelData{data: data, channel_number: channel_number} ==
          channel_data
      assert Params.get_method(params) == :data
      xor_peer_addr = Params.get_attr(params, XORPeerAddress)
      assert xor_peer_addr.port == peer_port2
    end
  end
end
