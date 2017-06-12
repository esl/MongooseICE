defmodule Fennec.UDP.CreatePermissionTest do
  use ExUnit.Case, async: false
  use Helper.Macros
  import Mock

  alias Helper.UDP
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{ErrorCode, XORRelayedAddress}
  alias Fennec.UDP.Worker

  setup do
    udp =
      UDP.connect({127, 0, 0, 1}, {127, 0, 0, 1}, 2)
    on_exit fn ->
      UDP.close(udp)
    end

    {:ok, [udp: udp]}
  end

  describe "worker's permissions state" do
    setup ctx do
      UDP.allocate(ctx.udp)
      {:ok, []}
    end

    test "contains no permissions after allocate", ctx do
      udp = ctx.udp
      worker = UDP.worker(udp, 0)

      assert %{} == GenServer.call(worker, :get_permissions)
    end

    test "contains permission after create_permission request", ctx do
      udp = ctx.udp
      worker = UDP.worker(udp, 0)

      UDP.create_permissions(udp, [{127, 0, 10, 0}])
      assert %{{127, 0, 10, 0} => expire_at} =
        GenServer.call(worker, :get_permissions)

      later_5min = Fennec.Time.system_time(:second) + 5 * 60
      assert_in_delta expire_at, later_5min, 5
    end

    test "contains several permission after create_permission request", ctx do
      udp = ctx.udp
      worker = UDP.worker(udp, 0)

      UDP.create_permissions(udp, [{127, 0, 10, 0}, {127, 0, 10, 1}])

      # Time passes
      time_passed = 2 * 60
      with_mock Fennec.Time, [:passthrough], [
        system_time: fn (:second) -> :meck.passthrough([:second]) + time_passed end
      ] do
        UDP.create_permissions(udp, [{127, 0, 10, 2}, {127, 0, 10, 3}])

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
      worker = UDP.worker(udp, 0)

      UDP.create_permissions(udp, [{127, 0, 10, 0}])
      assert %{{127, 0, 10, 0} => expire_at_1} =
        GenServer.call(worker, :get_permissions)

      # Time passes
      time_passed = 2 * 60
      with_mock Fennec.Time, [:passthrough], [
        system_time: fn (:second) -> :meck.passthrough([:second]) + time_passed end
      ] do
        UDP.create_permissions(udp, [{127, 0, 10, 0}])

        assert %{{127, 0, 10, 0} => expire_at_2} =
          GenServer.call(worker, :get_permissions)

        assert expire_at_2 - expire_at_1 >= time_passed
        assert expire_at_2 - expire_at_1 < 2 * time_passed
      end
    end
  end

  describe "peer's data" do
    test "gets rejected without correct permission", ctx do
      udp = ctx.udp
      with_mock Worker, [:passthrough], [] do
        # Allocate
        allocate_res = UDP.allocate(udp)
        %XORRelayedAddress{
          address: relay_ip,
          port: relay_port
        } = Params.get_attr(allocate_res, XORRelayedAddress)

        # Invalied CreatePermission
        UDP.create_permissions(udp, [{127, 0, 0, 2}])

        # Peer sends data
        {:ok, sock} = :gen_udp.open(0)
        :ok = :gen_udp.send(sock, relay_ip, relay_port, "some_bytes")

        assert eventually called Worker.handle_peer_data(:no_permission, :_, :_, :_, :_)
      end
    end

    test "gets rejected with stale permission", ctx do
      udp = ctx.udp
      with_mock Worker, [:passthrough], [] do
        # Allocate
        allocate_res = UDP.allocate(udp)
        %XORRelayedAddress{
          address: relay_ip,
          port: relay_port
        } = Params.get_attr(allocate_res, XORRelayedAddress)

        # CreatePermission
        UDP.create_permissions(udp, [{127, 0, 0, 1}])

        # Time passes
        with_mock Fennec.Time, [:passthrough], [
          system_time: fn (:second) -> :meck.passthrough([:second]) + 5 * 60 end
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
      with_mock Worker, [:passthrough], [] do
        # Allocate
        allocate_res = UDP.allocate(udp)
        %XORRelayedAddress{
          address: relay_ip,
          port: relay_port
        } = Params.get_attr(allocate_res, XORRelayedAddress)

        # CreatePermission
        UDP.create_permissions(udp, [{127, 0, 0, 1}])

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
      UDP.allocate(udp)

      id = Params.generate_id()
      req = UDP.create_permission_request(id, [])

      resp = no_auth(UDP.communicate(udp, 0, req))

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
      req = UDP.create_permission_request(id, [])

      resp = no_auth(UDP.communicate(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :failure,
                     method: :create_permission,
                     identifier: ^id,
                     attributes: [error]} = params

      assert %ErrorCode{code: 437} = error
    end

    test "succeeds with one XORPeerAddress", ctx do
      udp = ctx.udp
      UDP.allocate(udp)

      id = Params.generate_id()
      peers = UDP.peers([{123, 123, 6, 1}])
      req = UDP.create_permission_request(id, peers)

      resp = no_auth(UDP.communicate(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :create_permission,
                     identifier: ^id} = params
    end

    test "succeeds with multiple XORPeerAddress", ctx do
      udp = ctx.udp
      UDP.allocate(udp)

      id = Params.generate_id()
      peers = UDP.peers([
        {123, 123, 6, 1},
        {123, 123, 6, 2},
        {123, 123, 6, 3},
      ])
      req = UDP.create_permission_request(id, peers)

      resp = no_auth(UDP.communicate(udp, 0, req))

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :create_permission,
                     identifier: ^id} = params
    end

  end
end
