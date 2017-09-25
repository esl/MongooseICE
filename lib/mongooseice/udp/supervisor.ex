defmodule MongooseICE.UDP.Supervisor do
  @moduledoc false
  # Supervisor of UDP listener, dispatcher and workers

  require Logger

  @spec start_link(MongooseICE.UDP.server_opts) :: Supervisor.on_start
  def start_link(opts) do
    import Supervisor.Spec, warn: false

    base_name = MongooseICE.UDP.base_name(opts[:port])
    name = MongooseICE.UDP.sup_name(base_name)

    children = [
      supervisor(MongooseICE.UDP.Dispatcher, [base_name]),
      supervisor(MongooseICE.UDP.WorkerSupervisor, [base_name, opts]),
      worker(MongooseICE.UDP.Receiver, [base_name, opts])
    ]

    Logger.info(~s"Starting STUN/TURN server (#{opts[:ip]}:#{opts[:port]}) " <>
                ~s"with relay_ip: #{opts[:relay_ip]}")

    opts = [strategy: :one_for_all, name: name]
    Supervisor.start_link(children, opts)
  end
end
