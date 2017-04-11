defmodule Fennec.UDP.BindingTest do
  use ExUnit.Case
  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORMappedAddress

  describe "binding request" do

    setup do
      udp =
        UDP.connect({0, 0, 0, 0, 0, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}, 1)
      on_exit fn ->
        UDP.close(udp)
      end

      {:ok, [udp: udp]}
    end

    test "returns response with IPv6 XOR mapped address attribute", ctx do
      udp = ctx.udp
      client_address = udp.client_address
      client_port = UDP.client_port(udp, 0)

      id = Params.generate_id()
      req = UDP.binding_request(id)

      resp = no_auth(UDP.communicate(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :binding,
                     identifier: ^id,
                     attributes: [a]} = params
      assert %XORMappedAddress{address: ^client_address,
                               port: ^client_port,
                               family: :ipv6} = a
    end
  end

end
