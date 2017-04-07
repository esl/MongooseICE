defmodule Fennec.UDP.RefreshTest do
  use ExUnit.Case

  describe "refresh request" do

    alias Helper.{Allocation, UDP}
    alias Jerboa.Format
    alias Jerboa.Format.Body.Attribute
    alias Jerboa.Params

    setup ctx do
      {:ok, [udp: UDP.setup_connection(ctx)]}
    end

    test "with a lifetime of 0 deletes the allocation", ctx do
      ## given allocation
      UDP.allocate(ctx.udp)
      ## when sending Refresh with lifetime = 0
      mref = Allocation.monitor_owner(ctx)
      %Params{class: :success} = UDP.refresh(ctx.udp, [%Attribute.Lifetime{duration: 0}])
      ## then the allocation is deleted
      assert_receive {:DOWN, ^mref, :process, _pid, _info}, 5_000
    end

    test "errors with allocation mismatch if there's no allocation", ctx do
      ## given no allocation or expired allocation
      client_id = 0
      ## when Refresh is sent
      req_id = Params.generate_id()
      req = UDP.refresh_request(req_id, [])
      resp = UDP.communicate(ctx.udp, client_id, req)
      params = Format.decode!(resp)
      ## then the result is an allocation mismatch error
      %Params{class: :failure,
              attributes: [%Attribute.ErrorCode{name: :allocation_mismatch}],
              identifier: ^req_id} = params
    end

  end

end
