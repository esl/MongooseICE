defmodule Fennec.UDP.WorkerSupervisor do
  @moduledoc false
  # Supervisor of `Fennec.UDP.Worker` processes

  alias Fenned.UDP

  def start_link do
    import Supervisor.Spec, warn: false

    children = [
      worker(Fennec.UDP.Worker, [], restart: :temporary)
    ]

    opts = [strategy: :simple_one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  # Starts worker under WorkerSupervisor
  @spec start_worker(UDP.socket, Fennec.ip, Fennec.portn) :: {:ok, pid} | :error
  def start_worker(socket, ip, port) do
    case Supervisor.start_child(__MODULE__, [socket, ip, port]) do
      {:ok, pid} ->
        {:ok, pid}
      _ ->
        :error
    end
  end
end
