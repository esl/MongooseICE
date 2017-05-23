defmodule Fennec.UDP.ChannelBindTest do
  use ExUnit.Case, async: false

  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.ChannelNumber

  setup ctx do
    udp = UDP.connect({127, 0, 0, 1}, {127, 0, 0, 1}, 1)
    if ctx[:allocate], do: UDP.allocate(udp)
    on_exit fn ->
      UDP.close(udp)
    end
    {:ok, udp: udp}
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
    id = Params.generate_id()
    attrs = [
      %ChannelNumber{number: 0x4000},
      XPA.new({127, 0, 0, 1}, 12_345)
    ]
    req = UDP.channel_bind_request(id, attrs)

    resp = no_auth(UDP.communicate(udp, 0, req))
    params = Format.decode!(resp)

    assert Params.get_class(params) == :success
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id
  end

  @tag :allocate
  test "succeeds given previously bound peer and channel number", %{udp: udp} do
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

    # 1st request
    no_auth(UDP.communicate(udp, 0, req1))
    # 2nd request
    resp = no_auth(UDP.communicate(udp, 0, req2))
    params = Format.decode!(resp)

    assert Params.get_class(params) == :success
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id2
  end

  @tag :allocate
  test "fails given already bound peer address", %{udp: udp} do
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
    # 2nd request
    resp = no_auth(UDP.communicate(udp, 0, req2))
    params = Format.decode!(resp)

    assert Params.get_class(params) == :failure
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id2
    assert [error] = Params.get_attrs(params)
    assert error.name == :bad_request
  end

  @tag :allocate
  test "fails given already bound channel number", %{udp: udp} do
    channel_number = %ChannelNumber{number: 0x4000}

    id1 = Params.generate_id()
    attrs1 = [
      channel_number,
      XPA.new({127, 0, 0, 1}, 12_345)
    ]
    req1 = UDP.channel_bind_request(id1, attrs1)

    id2 = Params.generate_id()
    attrs2 = [
      channel_number,
      XPA.new({127, 0, 0, 1}, 54_321)
    ]
    req2 = UDP.channel_bind_request(id2, attrs2)

    # 1st request
    no_auth(UDP.communicate(udp, 0, req1))
    # 2nd request
    resp = no_auth(UDP.communicate(udp, 0, req2))
    params = Format.decode!(resp)

    assert Params.get_class(params) == :failure
    assert Params.get_method(params) == :channel_bind
    assert Params.get_id(params) == id2
    assert [error] = Params.get_attrs(params)
    assert error.name == :bad_request
  end
end
