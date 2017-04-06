defmodule Helper.Allocation do

  alias Helper.UDP

  def monitor_owner(ctx) do
    [{_, relay_pid, _, _}] = Supervisor.which_children(udp_worker_sup(ctx.udp.server_port))
    Process.monitor(relay_pid)
  end

  defp udp_worker_sup(port) do
    port
    |> Fennec.UDP.base_name()
    |> Fennec.UDP.worker_sup_name()
  end

end
