defmodule MongooseICE.UDP.RefreshTest do
  use ExUnit.Case
  use Helper.Macros

  describe "refresh request" do

    alias Helper.{Allocation, UDP}
    alias Jerboa.Format
    alias Jerboa.Format.Body.Attribute
    alias Jerboa.Params

    import Mock, only: [
      called: 1,
      with_mock: 3,
      with_mocks: 2
    ]

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
      resp = no_auth(UDP.communicate(ctx.udp, client_id, req))
      params = Format.decode!(resp)
      ## then the result is an allocation mismatch error
      %Params{class: :failure,
              attributes: [%Attribute.ErrorCode{name: :allocation_mismatch}],
              identifier: ^req_id} = params
    end

    test "extends the allocation", ctx do
      ## given allocation
      non_standard_lifetime = 17 * 60
      client_id = 0
      now = MongooseICE.Time.system_time(:second)
      future_after_expiry = now + 14 * 60
      future_after_second_expiry = now + 153 * 60
      UDP.allocate(ctx.udp)
      ## when Refresh is sent
      allocation_owner = Helper.Allocation.owner(ctx)
      mref = Helper.Allocation.monitor_owner(ctx)
      params = UDP.refresh(ctx.udp, [%Attribute.Lifetime{duration: non_standard_lifetime}])
      ## then the allocation gets extended
      %Params{class: :success,
              attributes: [%Attribute.Lifetime{duration: ^non_standard_lifetime}]} = params
      ## time travel 1: future_after_expiry is the point at which the allocation
      ## would have expired if it hadn't been extended
      with_mocks [
        {MongooseICE.Time, [],
          [system_time: fn (:second) -> future_after_expiry end]},
        {MongooseICE.Evaluator.Indication, [:passthrough], []}
      ] do
        ## First indication triggers reading the new time.
        ## If the allocation timed out, we would trigger the process exit here.
        ## However, the owner process **might exit after we assert its existence.**
        :ok = UDP.send(ctx.udp, client_id, UDP.binding_indication(Params.generate_id()))
        assert eventually called MongooseICE.Evaluator.Indication.void()
        assert Process.alive?(allocation_owner)
        ## Second indication asserts the allocation did not expire even
        ## if the assertion above was a false positive.
        :ok = UDP.send(ctx.udp, client_id, UDP.binding_indication(Params.generate_id()))
        assert eventually called MongooseICE.Evaluator.Indication.void()
        assert Process.alive?(allocation_owner)
      end
      ## time travel 2: future_after_second_expiry is the point at which the allocation
      ## would expire even though it had been extended
      with_mock MongooseICE.Time, [
        system_time: fn (:second) -> future_after_second_expiry end
      ] do
        :ok = UDP.send(ctx.udp, client_id, UDP.binding_indication(Params.generate_id()))
        assert_receive {:DOWN, ^mref, :process, _pid, _info}, 3_000
        assert called MongooseICE.Time.system_time(:second)
      end
    end

  end

end
