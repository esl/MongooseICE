defmodule Fennec.UDP.CreatePermissionTest do
  use ExUnit.Case, async: false
  use Helper.Macros
  import Helper.UDP
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
                  {127, 0, 0, 1}, 42_100 + port_mod, 2)
    on_exit fn ->
      udp_close(udp)
    end

    {:ok, [udp: udp]}
  end

  describe "worker's permissions state" do
    setup ctx do
      udp_allocate(ctx.udp)
      {:ok, []}
    end

    test "contains no permissions after allocate", ctx do
      udp = ctx.udp
      worker = worker(udp, 0)

      assert %{} == GenServer.call(worker, :get_permissions)
    end

    test "contains permission after create_permission request", ctx do
      udp = ctx.udp
      worker = worker(udp, 0)

      udp_create_permissions(udp, [{127, 0, 10, 0}])
      assert %{{127, 0, 10, 0} => expire_at} =
        GenServer.call(worker, :get_permissions)

      later_5min = Fennec.Helper.now + 5 * 60
      assert expire_at in (later_5min - 5)..(later_5min + 5)
    end

    test "contains several permission after create_permission request", ctx do
      udp = ctx.udp
      worker = worker(udp, 0)

      udp_create_permissions(udp, [{127, 0, 10, 0}, {127, 0, 10, 1}])

      # Time passes
      time_passed = 2 * 60
      with_mock Fennec.Helper, [:passthrough], [
        now: fn -> :meck.passthrough([]) + time_passed end
      ] do
        udp_create_permissions(udp, [{127, 0, 10, 2}, {127, 0, 10, 3}])

        assert %{
          {127, 0, 10, 0} => expire_at_0,
          {127, 0, 10, 1} => expire_at_1,
          {127, 0, 10, 2} => expire_at_2,
          {127, 0, 10, 3} => expire_at_3
        } = GenServer.call(worker, :get_permissions)

        assert expire_at_0 == expire_at_1
        assert expire_at_2 == expire_at_3

        assert expire_at_2 >= expire_at_0 + time_passed
      end
    end

    test "contains refreshed permission after second create_permission", ctx do
      udp = ctx.udp
      worker = worker(udp, 0)

      udp_create_permissions(udp, [{127, 0, 10, 0}])
      assert %{{127, 0, 10, 0} => expire_at_1} =
        GenServer.call(worker, :get_permissions)

      # Time passes
      time_passed = 2 * 60
      with_mock Fennec.Helper, [:passthrough], [
        now: fn -> :meck.passthrough([]) + time_passed end
      ] do
        udp_create_permissions(udp, [{127, 0, 10, 0}])

        assert %{{127, 0, 10, 0} => expire_at_2} =
          GenServer.call(worker, :get_permissions)

        assert expire_at_2 - expire_at_1 >= time_passed
        assert expire_at_2 - expire_at_1 < 2 * time_passed
      end
    end

    defp worker(udp, client_id) do
      alias Fennec.UDP
      alias Fennec.UDP.Dispatcher

      base_name = UDP.base_name(udp.server_port)
      dispatcher = UDP.dispatcher_name(base_name)
      [{_, worker}] = Dispatcher.lookup_worker(dispatcher, udp.client_address,
                                               client_port(udp, client_id))
      worker
    end
  end

  describe "peer's data" do
    test "gets rejected without correct permission", ctx do
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

        # Invalied CreatePermission
        udp_create_permissions(udp, [{127, 0, 0, 2}])

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
