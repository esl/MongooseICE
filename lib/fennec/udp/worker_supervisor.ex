defmodule Fennec.UDP.WorkerSupervisor do
  @moduledoc false
  # Supervisor of `Fennec.UDP.Worker` processes

  alias Fennec.UDP

  def start_link(base_name, server_opts) do
    import Supervisor.Spec, warn: false

    name = UDP.worker_sup_name(base_name)
    dispatcher = UDP.dispatcher_name(base_name)

    children = [
      worker(Fennec.UDP.Worker, [dispatcher, server_opts], restart: :temporary)
    ]

    opts = [strategy: :simple_one_for_one, name: name]
    Supervisor.start_link(children, opts)
  end

  # Starts worker under WorkerSupervisor
  @spec start_worker(atom, Fennec.client_info) :: {:ok, pid} | :error
  def start_worker(worker_sup, client) do
    case Supervisor.start_child(worker_sup, [client]) do
      {:ok, pid} ->
        {:ok, pid}
      _ ->
        :error
    end
  end
end
