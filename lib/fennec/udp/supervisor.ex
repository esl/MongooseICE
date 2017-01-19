defmodule Fennec.UDP.Supervisor do
  @moduledoc false
  # Supervisor of UDP listener, dispatcher and workers

  @spec start_link(Fennec.portn) :: Supervisor.on_start
  def start_link(port) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Fennec.UDP.Receiver, [port]),
      supervisor(Fennec.UDP.Dispatcher, []),
      supervisor(Fennec.UDP.WorkerSupervisor, [])
    ]

    opts = [strategy: :one_for_all, name: Fennec.UDP.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
