defmodule MongooseICE.UDP.ServerTest do
  use ExUnit.Case

  test "start/1 and stop/1 a UDP server linked to MongooseICE.Supervisor" do
    port = Helper.PortMaster.checkout_port(:server)
    {:ok, _} = MongooseICE.UDP.start(ip: {127, 0, 0, 1}, port: port)

    expected_name = String.to_atom(~s"Elixir.MongooseICE.UDP.#{port}")
    assert [{MongooseICE.ReservationLog, _, _, _}, {^expected_name, _, _, _}] =
      Enum.sort(Supervisor.which_children(MongooseICE.Supervisor))
    assert :ok = MongooseICE.UDP.stop(port)
    assert [{MongooseICE.ReservationLog, _, _, _}] =
      Supervisor.which_children(MongooseICE.Supervisor)
  end

  test "start/1 allows to start multiple servers on different ports" do
    port1 = 1234
    port2 = 4321

    assert {:ok, _} = MongooseICE.UDP.start(port: port1)
    assert {:ok, _} = MongooseICE.UDP.start(port: port2)

    MongooseICE.UDP.stop port1
    MongooseICE.UDP.stop port2
  end

  test "start/1 does not allow to start multiple servers on the same port" do
    port = 3478

    assert {:ok, _} = MongooseICE.UDP.start(port: port)
    assert {:error, {:already_started, _}} = MongooseICE.UDP.start(port: port)

    MongooseICE.UDP.stop(port)
  end
end
