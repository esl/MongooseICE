defmodule Fennec.UDP.RefreshTest do
  use ExUnit.Case

  describe "refresh request" do

    alias Helper.{Allocation, UDP}
    alias Jerboa.Format.Body.Attribute.Lifetime
    alias Jerboa.Params

    setup ctx do
      {:ok, [udp: UDP.setup_connection(ctx)]}
    end

    test "with a lifetime of 0 deletes the allocation", ctx do
      ## given allocation
      UDP.allocate(ctx.udp)
      ## when sending Refresh with lifetime = 0
      mref = Allocation.monitor_owner(ctx)
      %Params{class: :success} = UDP.refresh(ctx.udp, [%Lifetime{duration: 0}])
      ## then the allocation is deleted
      assert_receive {:DOWN, ^mref, :process, _pid, _info}, 5_000
    end

  end

end
