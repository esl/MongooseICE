defmodule Fennec.UDP.AuthTest do
  use ExUnit.Case
  use Fennec.UDP.AuthTemplate

  alias Jerboa.Format.Body.Attribute.{Lifetime, RequestedTransport, XORPeerAddress}
  alias Jerboa.Format.Body.Attribute.{RequestedTransport, XORPeerAddress, Data}

  test_auth_for(:allocate, [%RequestedTransport{protocol: :udp}])

  test_auth_for(:create_permission, [%XORPeerAddress{
    address: {127, 0, 0, 1},
    port: 0,
    family: :ipv4
  }])

  test_auth_for(:refresh, [%Lifetime{duration: 1020}])

  test_auth_for(:send, [
    %XORPeerAddress{
      address: {127, 0, 0, 1},
      port: 2345,
      family: :ipv4
    },
    %Data{content: "some data"}])
end
