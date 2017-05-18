defmodule Fennec.UDP.AllocateTest do
  use ExUnit.Case
  use Helper.Macros

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime,
                                      XORRelayedAddress, ErrorCode,
                                      RequestedTransport, EvenPort,
                                      ReservationToken, Lifetime}

  require Integer

  describe "allocate request" do

    setup do
      {:ok, [udp: UDP.setup_connection([], :ipv4)]}
    end

    test "fails without RequestedTransport attribute", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = UDP.allocate_request(id, [])

      resp = no_auth(UDP.communicate(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 400} = error
    end

    test "fails if EvenPort and ReservationToken are supplied", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = UDP.allocate_request(id, [
        %RequestedTransport{protocol: :udp},
        %EvenPort{},
        %ReservationToken{value: "12345678"}
      ])

      resp = no_auth(UDP.communicate(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 400} = error
    end

    test "returns response with IPv4 XOR relayed address attribute", ctx do
      udp = ctx.udp
      %{server_address: server_address, client_address: client_address} = udp
      client_port = UDP.client_port(udp, 0)
      id = Params.generate_id()
      req = UDP.allocate_request(id)

      resp = no_auth(UDP.communicate(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id,
                     attributes: attrs} = params
      [lifetime, mapped, relayed] = Enum.sort(attrs)

      assert %Lifetime{duration: 600} = lifetime

      assert %XORMappedAddress{address: ^client_address,
                               port: ^client_port,
                               family: :ipv4} = mapped

      assert %XORRelayedAddress{address: ^server_address,
                                port: relayed_port,
                                family: :ipv4} = relayed
      assert relayed_port != udp.server_port
    end

    test "returns error after second allocation with different id", ctx do
      udp = ctx.udp
      id1 = Params.generate_id()
      id2 = Params.generate_id()
      req1 = UDP.allocate_request(id1)
      req2 = UDP.allocate_request(id2)

      resp1 = no_auth(UDP.communicate(udp, 0, req1))
      params1 = Format.decode!(resp1)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id1} = params1

      resp2 = no_auth(UDP.communicate(udp, 0, req2))

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

      resp1 = no_auth(UDP.communicate(udp, 0, req))
      params1 = Format.decode!(resp1)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id} = params1

      resp2 = no_auth(UDP.communicate(udp, 0, req))

      params2 = Format.decode!(resp2)
      assert %Params{class: :success,
                     method: :allocate,
                     identifier: ^id,
                     attributes: attrs} = params2
      assert 3 = length(attrs)
    end

  end

  describe "allocate request with EVEN-PORT attribute" do

    test "allocates an even port" do
      addr = {127, 0, 0, 1}
      for _ <- 1..100 do
        udp = UDP.connect(addr, addr, 1)
        id = Params.generate_id()
        req = UDP.allocate_request(id, [
          %RequestedTransport{protocol: :udp},
          %EvenPort{}
        ])

        resp = no_auth(UDP.communicate(udp, 0, req))
        params = Format.decode!(resp)
        assert %Params{class: :success,
                       method: :allocate,
                       identifier: ^id} = params
        %XORRelayedAddress{port: relay_port} = Params.get_attr(params, XORRelayedAddress)
        assert Integer.is_even(relay_port)
        UDP.close(udp)
      end
    end

    test "reserves a higher port if requested" do
      ## given a TURN server
      addr = {127, 0, 0, 1}
      ## when allocating a UDP relay address with an even port
      ## and reserving the next port
      udp1 = UDP.connect(addr, addr, 1)
      on_exit fn -> UDP.close(udp1) end
      params1 = UDP.allocate(udp1, attributes: [
        %RequestedTransport{protocol: :udp},
        %EvenPort{reserved?: true}
      ])
      %XORRelayedAddress{port: relay_port1} = Params.get_attr(params1, XORRelayedAddress)
      reservation_token = Params.get_attr(params1, ReservationToken)
      ## then the next allocation with a RESERVATION-TOKEN
      ## allocates a relay address with the reserved port
      udp2 = UDP.connect(addr, addr, 1)
      on_exit fn -> UDP.close(udp2) end
      params2 = UDP.allocate(udp2, attributes: [reservation_token])
      %XORRelayedAddress{port: relay_port2} = Params.get_attr(params2, XORRelayedAddress)
      assert Integer.is_even(relay_port1)
      assert relay_port2 == relay_port1 + 1
    end

  end

  describe "allocation" do

    import Mock

    setup ctx do
      {:ok, [udp: UDP.setup_connection(ctx)]}
    end

    test "expires after timeout", ctx do
      ## given an existing allocation
      client_id = 0
      UDP.allocate(ctx.udp)
      ## when its timeout is reached
      mref = Helper.Allocation.monitor_owner(ctx)
      now = Fennec.Time.system_time(:second)
      future = now + 10_000
      with_mock Fennec.Time, [system_time: fn(:second) -> future end] do
        ## send indication to trigger timeout
        :ok = UDP.send(ctx.udp, client_id, UDP.binding_indication(Params.generate_id()))
        ## then the allocation is deleted
        assert_receive {:DOWN, ^mref, :process, _pid, _info}, 3_000
        assert called Fennec.Time.system_time(:second)
      end
    end

  end

  describe "reservation" do
    import Mock

    test "expires after timeout", _ctx do
      ## Set reservation timeout to 1 second
      with_mock Fennec.TURN.Reservation, [:passthrough], [default_timeout: fn() -> 1 end] do
        ## given a TURN server
        addr = {127, 0, 0, 1}
        ## given the allocation
        udp1 = UDP.connect(addr, addr, 1)
        on_exit fn -> UDP.close(udp1) end
        params1 = UDP.allocate(udp1, attributes: [
          %RequestedTransport{protocol: :udp},
          %EvenPort{reserved?: true}
        ])
        reservation_token = Params.get_attr(params1, ReservationToken)

        ## when reservation lifetime ends
        Process.sleep(1500)

        ## then the reservation expires
        udp2 = UDP.connect(addr, addr, 1)
        on_exit fn -> UDP.close(udp2) end
        id = Params.generate_id()
        req = UDP.allocate_request(id, [
          reservation_token,
          %RequestedTransport{protocol: :udp}
        ])
        resp = no_auth(UDP.communicate(udp2, 0, req))
        params = Format.decode!(resp)
        assert %Params{class: :failure,
                       method: :allocate,
                       identifier: ^id,
                       attributes: [error]} = params
        assert %ErrorCode{name: :insufficient_capacity} = error
      end
    end

    test "expires if original allocation is deleted", ctx do
      ## given a TURN server
      addr = {127, 0, 0, 1}
      ## given the allocation
      udp1 = UDP.connect(addr, addr, 1)
      on_exit fn -> UDP.close(udp1) end
      params1 = UDP.allocate(udp1, attributes: [
        %RequestedTransport{protocol: :udp},
        %EvenPort{reserved?: true}
      ])
      reservation_token = Params.get_attr(params1, ReservationToken)

      ## when the reservation is manually removed
      UDP.refresh(udp1, [%Lifetime{duration: 0}])

      ## when cleanups have finished
      Process.sleep(100)

      ## then the reservation expires
      udp2 = UDP.connect(addr, addr, 1)
      on_exit fn -> UDP.close(udp2) end
      id = Params.generate_id()
      req = UDP.allocate_request(id, [
        reservation_token,
        %RequestedTransport{protocol: :udp}
      ])
      resp = no_auth(UDP.communicate(udp2, 0, req))
      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params
      assert %ErrorCode{name: :insufficient_capacity} = error
    end

    test "expires if original allocation expires", ctx do
      ## given a TURN server
      addr = {127, 0, 0, 1}
      ## given the allocation
      udp1 = UDP.connect(addr, addr, 1)
      on_exit fn -> UDP.close(udp1) end
      params1 = UDP.allocate(udp1, attributes: [
        %RequestedTransport{protocol: :udp},
        %EvenPort{reserved?: true}
      ])
      reservation_token = Params.get_attr(params1, ReservationToken)

      ## when the allocation timeouts
      now = Fennec.Time.system_time(:second)
      future = now + 10_000
      with_mock Fennec.Time, [system_time: fn(:second) -> future end] do
        ## send indication to trigger timeout
        :ok = UDP.send(udp1, 0, UDP.binding_indication(Params.generate_id()))
        assert eventually called Fennec.Time.system_time(:second)
      end

      ## when cleanups have finished
      Process.sleep(100)

      ## then the reservation expires
      udp2 = UDP.connect(addr, addr, 1)
      on_exit fn -> UDP.close(udp2) end
      id = Params.generate_id()
      req = UDP.allocate_request(id, [
        reservation_token,
        %RequestedTransport{protocol: :udp}
      ])
      resp = no_auth(UDP.communicate(udp2, 0, req))
      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :allocate,
                     identifier: ^id,
                     attributes: [error]} = params
      assert %ErrorCode{name: :insufficient_capacity} = error
    end
  end

end
