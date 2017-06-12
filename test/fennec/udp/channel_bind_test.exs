defmodule Fennec.UDP.ChannelBindTest do
  use ExUnit.Case, async: false

  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.ChannelNumber

  import Mock

  setup ctx do
    udp = UDP.connect({127, 0, 0, 1}, {127, 0, 0, 1}, 1)
    allocate_time = Fennec.Time.system_time(:second)
    if ctx[:allocate], do: UDP.allocate(udp)
    on_exit fn ->
      UDP.close(udp)
    end
    {:ok, udp: udp, allocate_time: allocate_time}
  end

  test "fails without active allocation", %{udp: udp} do
    id = Params.generate_id()
    req = UDP.channel_bind_request(id, [])

    resp = no_auth(UDP.communicate(udp, 0, req))
    params = Format.decode!(resp)

    assert Params.get_class(params) == :failure
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id
    assert [error] = Params.get_attrs(params)
    assert error.name == :allocation_mismatch
  end

  @tag :allocate
  test "fails without XOR-PEER-ADDRESS attribute", %{udp: udp} do
    id = Params.generate_id()
    attrs = [
      %ChannelNumber{number: 0x4000}
    ]
    req = UDP.channel_bind_request(id, attrs)

    resp = no_auth(UDP.communicate(udp, 0, req))
    params = Format.decode!(resp)

    assert Params.get_class(params) == :failure
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id
    assert [error] = Params.get_attrs(params)
    assert error.name == :bad_request
  end

  @tag :allocate
  test "fails without CHANNEL-NUMBER attribute", %{udp: udp} do
    id = Params.generate_id()
    attrs = [
      XPA.new({127, 0, 0, 1}, 12_345)
    ]
    req = UDP.channel_bind_request(id, attrs)

    resp = no_auth(UDP.communicate(udp, 0, req))
    params = Format.decode!(resp)

    assert Params.get_class(params) == :failure
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id
    assert [error] = Params.get_attrs(params)
    assert error.name == :bad_request
  end

  @tag :allocate
  test "succeeds with CHANNEL-NUMBER and XOR-PEER-ADDRESS attributes",
    %{udp: udp} do
    worker = UDP.worker(udp, 0)
    id = Params.generate_id()
    peer_ip = {127, 0, 0, 1}
    peer_port = 12_345
    channel_number = 0x4000
    attrs = [
      %ChannelNumber{number: channel_number},
      XPA.new(peer_ip, peer_port)
    ]
    req = UDP.channel_bind_request(id, attrs)

    resp = no_auth(UDP.communicate(udp, 0, req))
    assert [channel] = GenServer.call(worker, :get_channels)
    assert channel.peer == {peer_ip, peer_port}
    assert channel.number == channel_number
    permissions = GenServer.call(worker, :get_permissions)
    assert peer_ip in Map.keys(permissions)
    params = Format.decode!(resp)

    assert Params.get_class(params) == :success
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id
  end

  @tag :allocate
  test "refreshes given previously bound peer and channel number",
    %{udp: udp, allocate_time: allocate_time} do
    worker = UDP.worker(udp, 0)
    peer_ip = {127, 0, 0, 1}
    peer_port = 12_345
    channel_number = 0x4000
    id1 = Params.generate_id()
    id2 = Params.generate_id()
    attrs = [
      %ChannelNumber{number: channel_number},
      XPA.new(peer_ip, peer_port)
    ]
    req1 = UDP.channel_bind_request(id1, attrs)
    req2 = UDP.channel_bind_request(id2, attrs)

    base_time = allocate_time + 10
    expiration_time1 =
      with_mock Fennec.Time, [:passthrough], [system_time: fn (:second) ->
                                               base_time end] do
        # 1st request
        no_auth(UDP.communicate(udp, 0, req1))
        assert [channel] = GenServer.call(worker, :get_channels)
        assert channel.peer == {peer_ip, peer_port}
        assert channel.number == channel_number
        channel.expiration_time
      end

    # 2nd request
    time_passed = 2 * 60
    with_mock Fennec.Time, [:passthrough], [system_time: fn (:second) ->
      base_time + time_passed
    end] do
      resp = no_auth(UDP.communicate(udp, 0, req2))
      params = Format.decode!(resp)

      assert Params.get_class(params) == :success
      assert Params.get_method(params) == :channel_bind
      assert Params.get_id(params) == id2
      assert [channel] = GenServer.call(worker, :get_channels)
      assert channel.peer == {peer_ip, peer_port}
      assert channel.number == channel_number
      expiration_time2 = channel.expiration_time
      assert expiration_time2 == expiration_time1 + time_passed
    end
  end

  @tag :allocate
  test "fails given already bound peer address", %{udp: udp} do
    worker = UDP.worker(udp, 0)
    peer_ip = {127, 0, 0, 1}
    peer_port = 12_345
    xor_peer_addr = XPA.new(peer_ip, peer_port)

    channel_number1 = 0x4000
    id1 = Params.generate_id()
    attrs1 = [
      %ChannelNumber{number: channel_number1},
      xor_peer_addr
    ]
    req1 = UDP.channel_bind_request(id1, attrs1)

    channel_number2 = 0x4001
    id2 = Params.generate_id()
    attrs2 = [
      %ChannelNumber{number: channel_number2},
      xor_peer_addr
    ]
    req2 = UDP.channel_bind_request(id2, attrs2)

    # 1st request
    no_auth(UDP.communicate(udp, 0, req1))
    assert [channel] = GenServer.call(worker, :get_channels)
    assert channel.number == channel_number1
    assert channel.peer == {peer_ip, peer_port}

    # 2nd request
    resp = no_auth(UDP.communicate(udp, 0, req2))
    params = Format.decode!(resp)

    assert Params.get_class(params) == :failure
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id2
    assert [error] = Params.get_attrs(params)
    assert error.name == :bad_request
    assert [^channel] = GenServer.call(worker, :get_channels)
  end

  @tag :allocate
  test "fails given already bound channel number", %{udp: udp} do
    peer_ip1 = {127, 0, 0, 1}
    peer_port1 = 12_345
    worker = UDP.worker(udp, 0)
    channel_number = 0x4000
    id1 = Params.generate_id()
    attrs1 = [
      %ChannelNumber{number: channel_number},
      XPA.new(peer_ip1, peer_port1)
    ]
    req1 = UDP.channel_bind_request(id1, attrs1)

    peer_ip2 = {127, 0, 0, 2}
    peer_port2 = 54_321
    id2 = Params.generate_id()
    attrs2 = [
      %ChannelNumber{number: channel_number},
      XPA.new(peer_ip2, peer_port2)
    ]
    req2 = UDP.channel_bind_request(id2, attrs2)

    # 1st request
    no_auth(UDP.communicate(udp, 0, req1))
    assert [channel] = GenServer.call(worker, :get_channels)
    assert channel.number == channel_number
    assert channel.peer == {peer_ip1, peer_port1}

    # 2nd request
    resp = no_auth(UDP.communicate(udp, 0, req2))
    params = Format.decode!(resp)

    assert Params.get_class(params) == :failure
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id2
    assert [error] = Params.get_attrs(params)
    assert error.name == :bad_request
    assert [^channel] = GenServer.call(worker, :get_channels)
  end
end
