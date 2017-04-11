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
end
