defmodule Fennec.UDP.CreatePermissionTest do
  use ExUnit.Case
  import Helper.UDP

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.ErrorCode

  describe "create_permission request" do

    setup ctx do
      test_case_id = ctx.line
      port_mod = test_case_id * 10
      udp =
        udp_connect({0, 0, 0, 0, 0, 0, 0, 1}, 12_100 + port_mod,
                    {0, 0, 0, 0, 0, 0, 0, 1}, 42_100 + port_mod, 1)
      on_exit fn ->
        udp_close(udp)
      end

      {:ok, [udp: udp]}
    end

    test "fails without XORPeerAddress attribute", ctx do
      udp = ctx.udp
      udp_allocate(udp)

      id = Params.generate_id()
      req = create_permissions_request(id, [])

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
      req = create_permissions_request(id, [])

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
      peers = peers([{{123,123,6,1}, 1234}])
      req = create_permissions_request(id, peers)

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
        {{123,123,6,1}, 1231},
        {{123,123,6,2}, 1232},
        {{123,123,6,3}, 1233},
      ])
      req = create_permissions_request(id, peers)

      resp = udp_communicate(udp, 0, req)

      params = Format.decode!(resp)
      assert %Params{class: :success,
                     method: :create_permission,
                     identifier: ^id} = params
    end

  end
end
