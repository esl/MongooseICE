defmodule Fennec.UDP.BindingTest do
  use ExUnit.Case
  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORMappedAddress

  describe "binding request" do

    setup do
      {:ok, [udp: UDP.setup_connection([], :ipv4)]}
    end

    test "returns response with IPv4 XOR mapped address attribute", ctx do
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
                               family: :ipv4} = a
    end
  end

end
