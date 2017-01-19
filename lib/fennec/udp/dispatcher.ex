defmodule Fennec.UDP.Dispatcher do
  @moduledoc false
  # Process dispatching UDP datagrams to workers associated
  # with source IP address and port

  alias Fennec.UDP
  alias Fennec.UDP.Worker

  @registry __MODULE__

  def start_link do
    Registry.start_link(:unique, @registry)
  end

  # Dispatches data to worker associated with given
  # IP and port number
  @spec dispatch(UDP.socket, Fennec.ip, Fennec.portn, binary) :: term
  def dispatch(socket, ip, port, data) do
    case find_or_start_worker(socket, ip, port) do
      {:ok, pid} ->
        Worker.process_data(pid, data)
      _ ->
        nil
    end
  end

  # Registers worker in dispatcher's registry
  #
  # This functions should be called only by workers,
  # because keys in the registry are bound to the calling process.
  # When the registering process dies, the keys are automatically
  # deregistered.
  @spec register_worker(pid, Fennec.ip, Fennec.portn) :: term
  def register_worker(pid, ip, port) do
    Registry.register(@registry, key(ip, port), pid)
  end

  defp find_or_start_worker(socket, ip, port) do
    case Registry.lookup(@registry, key(ip, port)) do
      [{_owner, pid}] -> {:ok, pid}
      [] ->
        start_worker(socket, ip, port)
    end
  end

  defp start_worker(socket, ip, port) do
    case Worker.start(socket, ip, port) do
      {:ok, pid} ->
        {:ok, pid}
      _ ->
        :error
    end
  end

  defp key(ip, port), do: {ip, port}
end
