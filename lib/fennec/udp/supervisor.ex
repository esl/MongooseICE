defmodule Fennec.UDP.Supervisor do
  @moduledoc false
  # Supervisor of UDP listener, dispatcher and workers

  require Logger

  @spec start_link(Fennec.UDP.server_opts) :: Supervisor.on_start
  def start_link(opts) do
    import Supervisor.Spec, warn: false

    base_name = Fennec.UDP.base_name(opts[:port])
    name = Fennec.UDP.sup_name(base_name)

    children = [
      supervisor(Fennec.UDP.Dispatcher, [base_name]),
      supervisor(Fennec.UDP.WorkerSupervisor, [base_name, opts]),
      worker(Fennec.UDP.Receiver, [base_name, opts])
    ]

    Logger.info(~s"Starting STUN/TURN server (#{opts[:ip]}:#{opts[:port]}) " <>
                ~s"with relay_ip: #{opts[:relay_ip]}")

    opts = [strategy: :one_for_all, name: name]
    Supervisor.start_link(children, opts)
  end
end
