defmodule Fennec.UDP.DataTest do
  use ExUnit.Case, async: false
  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.XORRelayedAddress

  import Mock

  setup ctx do
    {:ok, [udp: UDP.setup_connection(ctx, :ipv4)]}
  end

  describe "incoming datagram" do

    setup ctx do
      params = %Params{class: :success} = UDP.allocate(ctx.udp)
      {:ok, [relay_sock: Params.get_attr(params, XORRelayedAddress)]}
    end

    test "gets discarded when there's no permission for peer", ctx do
      flunk "not implemented yet"
    end

  end

  describe "incoming datagram with peer permission" do

    test "is relayed over a channel", _ctx do
      flunk "not implemented yet"
    end

    test "is relayed as a Data indication", _ctx do
      ## The Data indication MUST contain both:
      ##
      ## - an XOR-PEER-ADDRESS - source transport address of the datagram
      ## - a DATA attribute - 'data octets' field from the datagram
      ##
      ## The client SHOULD also check that the XOR-PEER-ADDRESS attribute value
      ## contains an IP address with which the client believes
      ## there is an active permission.
      flunk "not implemented yet"
    end

  end

end
