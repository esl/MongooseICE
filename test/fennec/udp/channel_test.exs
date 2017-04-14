defmodule Fennec.UDP.ChannelTest do
  use ExUnit.Case, async: false
  use Helper.Macros

  alias Helper.UDP

  @peer_addr {127, 0, 0, 1}

  setup ctx do
    {:ok, [udp: UDP.setup_connection(ctx, :ipv4)]}
  end

  describe "channel bind request" do

    test "creates a new channel", _ctx do
      flunk "not implemented yet"
    end

    test "refreshes an existing permission", _ctx do
      flunk "not implemented yet"
    end

    test "refreshes an existing channel binding", _ctx do
      flunk "not implemented yet"
    end

  end

end
