defmodule Fennec.UDP.CreatePermissionTest do
  use ExUnit.Case, async: false
  use Helper.Macros
  import Helper.UDP
  import ExUnit.CaptureLog
  import Mock

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{ErrorCode, XORRelayedAddress}
  alias Fennec.UDP.Worker

  setup ctx do
    test_case_id = ctx.line
    port_mod = test_case_id * 10
    udp =
      udp_connect({127, 0, 0, 1}, 12_100 + port_mod,
                  {127, 0, 0, 1}, 42_100 + port_mod, 1)
    on_exit fn ->
      udp_close(udp)
    end

    {:ok, [udp: udp]}
  end

  describe "peer's data" do
    test "gets rejected without permission", ctx do
      udp = ctx.udp
      with_mock Worker, [:passthrough], [
        handle_peer_data: fn(_, _, _, _, state) -> state end
      ] do
        # Allocate
        allocate_res = udp_allocate(udp)
        %XORRelayedAddress{
          address: relay_ip,
          port: relay_port
        } = Params.get_attr(allocate_res, XORRelayedAddress)

        # No CreatePermission

        # Peer sends data
        {:ok, sock} = :gen_udp.open(0)
        :ok = :gen_udp.send(sock, relay_ip, relay_port, "some_bytes")

        assert eventually called Worker.handle_peer_data(:no_permission, :_, :_, :_, :_)
      end
    end

    test "gets rejected with stale permission", ctx do
      udp = ctx.udp
      with_mock Worker, [:passthrough], [
        handle_peer_data: fn(_, _, _, _, state) -> state end
      ] do
        # Allocate
        allocate_res = udp_allocate(udp)
        %XORRelayedAddress{
          address: relay_ip,
          port: relay_port
        } = Params.get_attr(allocate_res, XORRelayedAddress)

        # CreatePermission
        udp_create_permissions(udp, [{127, 0, 0, 1}])

        # Time passes
        with_mock Fennec.Helper, [:passthrough], [
          now: fn -> :meck.passthrough([]) + 5 * 60 end
        ] do
          # Peer sends data
          {:ok, sock} = :gen_udp.open(0)
          :ok = :gen_udp.send(sock, relay_ip, relay_port, "some_bytes")

          assert eventually called Worker.handle_peer_data(:stale_permission, :_, :_, :_, :_)
        end
      end
    end

    test "is accepted with valid permission", ctx do
      udp = ctx.udp
      with_mock Worker, [:passthrough], [
        handle_peer_data: fn(_, _, _, _, state) -> state end
      ] do
        # Allocate
        allocate_res = udp_allocate(udp)
        %XORRelayedAddress{
          address: relay_ip,
          port: relay_port
        } = Params.get_attr(allocate_res, XORRelayedAddress)

        # CreatePermission
        udp_create_permissions(udp, [{127, 0, 0, 1}])

        # Peer sends data
        {:ok, sock} = :gen_udp.open(0)
        :ok = :gen_udp.send(sock, relay_ip, relay_port, "some_bytes")

        assert eventually called Worker.handle_peer_data(:allowed, :_, :_, :_, :_)
      end
    end
  end

  describe "create_permission request" do

    test "fails without XORPeerAddress attribute", ctx do
      udp = ctx.udp
      udp_allocate(udp)

      id = Params.generate_id()
      req = create_permission_request(id, [])

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :create_permission,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 400} = error
    end

    test "fails without active allocation", ctx do
      udp = ctx.udp
      id = Params.generate_id()
      req = create_permission_request(id, [])

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :create_permission,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 437} = error
    end

    test "succeeds with one XORPeerAddress", ctx do
      udp = ctx.udp
      udp_allocate(udp)

      id = Params.generate_id()
      peers = peers([{123, 123, 6, 1}])
      req = create_permission_request(id, peers)

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :create_permission,
                     identifier: ^id} = params
    end

    test "succeeds with multiple XORPeerAddress", ctx do
      udp = ctx.udp
      udp_allocate(udp)

      id = Params.generate_id()
      peers = peers([
        {123, 123, 6, 1},
        {123, 123, 6, 2},
        {123, 123, 6, 3},
      ])
      req = create_permission_request(id, peers)

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :create_permission,
                     identifier: ^id} = params
    end

  end
end
