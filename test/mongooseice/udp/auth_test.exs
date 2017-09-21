defmodule MongooseICE.UDP.AuthTest do
  use ExUnit.Case
  use MongooseICE.UDP.AuthTemplate

  alias Jerboa.Format.Body.Attribute.{Lifetime, RequestedTransport, XORPeerAddress}

  test_auth_for(:allocate, [%RequestedTransport{protocol: :udp}])

  test_auth_for(:create_permission, [%XORPeerAddress{
    address: {127, 0, 0, 1},
    port: 0,
    family: :ipv4
  }])

  test_auth_for(:refresh, [%Lifetime{duration: 1020}])
end
