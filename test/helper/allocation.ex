defmodule Helper.Allocation do

  def monitor_owner(ctx) do
    Process.monitor(owner(ctx))
  end

  def owner(ctx) do
    [{_, relay_pid, _, _}] = Supervisor.which_children(udp_worker_sup(ctx.udp.server_port))
    relay_pid
  end

  defp udp_worker_sup(port) do
    port
    |> MongooseICE.UDP.base_name()
    |> MongooseICE.UDP.worker_sup_name()
  end

end
