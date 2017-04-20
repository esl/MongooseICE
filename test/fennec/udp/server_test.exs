defmodule Fennec.UDP.ServerTest do
  use ExUnit.Case

  test "start/1 and stop/1 a UDP server linked to Fennec.Supervisor" do
    port = Helper.PortMaster.checkout_port(:server)
    {:ok, _} = Fennec.UDP.start(ip: {127, 0, 0, 1}, port: port)

    expected_name = String.to_atom(~s"Elixir.Fennec.UDP.#{port}")
    assert [{^expected_name, _, _, _}] =
      Supervisor.which_children(Fennec.Supervisor)
    assert :ok = Fennec.UDP.stop(port)
    assert [] = Supervisor.which_children(Fennec.Supervisor)
  end

  test "start/1 allows to start multiple servers on different ports" do
    port1 = 1234
    port2 = 4321

    assert {:ok, _} = Fennec.UDP.start(port: port1)
    assert {:ok, _} = Fennec.UDP.start(port: port2)

    Fennec.UDP.stop port1
    Fennec.UDP.stop port2
  end

  test "start/1 does not allow to start multiple servers on the same port" do
    port = 3478

    assert {:ok, _} = Fennec.UDP.start(port: port)
    assert {:error, {:already_started, _}} = Fennec.UDP.start(port: port)

    Fennec.UDP.stop(port)
  end
end
