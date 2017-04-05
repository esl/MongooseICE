defmodule Fennec.UDP.BindingTest do
  use ExUnit.Case
  import Helper.UDP

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORMappedAddress

  @recv_timeout 5_000

  describe "binding request" do

    test "returns response with IPv6 XOR mapped address attribute" do
      server_port = 13_100
      server_address = {0, 0, 0, 0, 0, 0, 0, 1}
      client_port = 43_100
      client_address = {0, 0, 0, 0, 0, 0, 0, 1}
      Fennec.UDP.start_link(ip: server_address, port: server_port)
      id = Params.generate_id()
      req = binding_request(id)

      {:ok, sock} = :gen_udp.open(client_port,
                                  [:binary, active: false, ip: client_address])
      :ok = :gen_udp.send(sock, server_address, server_port, req)

      assert {:ok,
              {^server_address,
               ^server_port,
               resp}} = :gen_udp.recv(sock, 0, @recv_timeout)
      :gen_udp.close(sock)
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
