defmodule Fennec.UDP.AllocateTest do
  use ExUnit.Case

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime,
                                      XORRelayedAddress, ErrorCode,
                                      RequestedTransport, EvenPort,
                                      ReservationToken}

  describe "allocate request" do

    setup ctx do
      test_case_id = ctx.line
      port_mod = test_case_id * 10
      udp =
        UDP.connect({0, 0, 0, 0, 0, 0, 0, 1}, 12_100 + port_mod,
                    {0, 0, 0, 0, 0, 0, 0, 1}, 42_100 + port_mod, 1)
      on_exit fn ->
        UDP.close(udp)
      end

      {:ok, [udp: udp]}
    end

    test "fails without RequestedTransport attribute", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = UDP.allocate_request(id, [])

      resp = UDP.communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 400} = error
    end

    test "fails with unknown attribute", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = UDP.allocate_request(id, [
        %RequestedTransport{protocol: :udp},
        %EvenPort{}
      ])

      resp = UDP.communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 420} = error
    end

    test "fails if EvenPort and ReservationToken are supplied", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = UDP.allocate_request(id, [
        %RequestedTransport{protocol: :udp},
        %EvenPort{},
        %ReservationToken{value: "12345678"}
      ])

      resp = UDP.communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 400} = error
    end

    test "returns response with IPv6 XOR relayed address attribute", ctx do
      udp = ctx.udp
      %{server_address: server_address, client_address: client_address} = udp
      client_port = UDP.client_port(udp, 0)
      id = Params.generate_id()
      req = UDP.allocate_request(id)

      resp = UDP.communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id,
                     attributes: attrs} = params
      [lifetime, mapped, relayed] = Enum.sort(attrs)

      assert %Lifetime{duration: 600} = lifetime

      assert %XORMappedAddress{address: ^client_address,
                               port: ^client_port,
                               family: :ipv6} = mapped

      assert %XORRelayedAddress{address: ^server_address,
                                port: relayed_port,
                                family: :ipv6} = relayed
      assert relayed_port != udp.server_port
    end

    test "returns error after second allocation with different id", ctx do
      udp = ctx.udp
      id1 = Params.generate_id()
      id2 = Params.generate_id()
      req1 = UDP.allocate_request(id1)
      req2 = UDP.allocate_request(id2)

      resp1 = UDP.communicate(udp, 0, req1)
      params1 = Format.decode!(resp1)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id1} = params1

      resp2 = UDP.communicate(udp, 0, req2)

      params2 = Format.decode!(resp2)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id2,
                     attributes: [error]} = params2
      assert %ErrorCode{code: 437} = error
    end

    test "returns success after second allocation with the same id", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = UDP.allocate_request(id)

      resp1 = UDP.communicate(udp, 0, req)
      params1 = Format.decode!(resp1)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id} = params1

      resp2 = UDP.communicate(udp, 0, req)

      params2 = Format.decode!(resp2)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id,
                     attributes: attrs} = params2
      assert 3 = length(attrs)
    end
  end
end
