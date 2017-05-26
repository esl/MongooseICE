defmodule Fennec.UDP.ChannelDataTest do
  use ExUnit.Case, async: false
  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.Format.Body.Attribute.Lifetime

  import Mock

  @recv_timeout 1_000

  setup ctx do
    sockets_count = ctx[:sockets] || 2
    udp = UDP.connect({127, 0, 0, 1}, {127, 0, 0, 1}, sockets_count)
    peer_port = UDP.port(udp, 1)
    peer_socket = UDP.socket(udp, 1)
    if ctx[:allocate], do: UDP.allocate(udp)
    on_exit fn ->
      UDP.close(udp)
    end
    {:ok, udp: udp, peer_socket: peer_socket, peer_port: peer_port}
  end

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
    with_mock Fennec.Time, [:passthrough], [
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
    with_mock Fennec.Time, [:passthrough], [
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
