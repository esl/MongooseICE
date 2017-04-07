defmodule Fennec.UDP.AuthTest do
  use ExUnit.Case
  use Fennec.UDP.AuthTemplate

  alias Jerboa.Format.Body.Attribute.{RequestedTransport, XORPeerAddress}

  test_auth_for(:allocate, [%RequestedTransport{protocol: :udp}])

  test_auth_for(:create_permission, [%XORPeerAddress{
    address: {127, 0, 0, 1},
    port: 0,
    family: :ipv4
  }])
end
