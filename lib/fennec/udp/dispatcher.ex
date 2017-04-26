defmodule Fennec.UDP.Dispatcher do
  @moduledoc false
  # Process dispatching UDP datagrams to workers associated
  # with source IP address and port

  alias Fennec.UDP
  alias Fennec.UDP.Worker

  def start_link(base_name) do
    name = UDP.dispatcher_name(base_name)
    Registry.start_link(:unique, name)
  end

  # Dispatches data to worker associated with client's
  # server-reflexive IP and port number
  @spec dispatch(atom, atom, Fennec.client_info, binary) :: term
  def dispatch(dispatcher, worker_sup, client, data) do
    case find_or_start_worker(dispatcher, worker_sup, client) do
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
  @spec register_worker(atom, pid, Fennec.ip, Fennec.portn) :: term
  def register_worker(dispatcher, worker_pid, ip, port) do
    Registry.register(dispatcher, key(ip, port), worker_pid)
  end

  @spec lookup_worker(atom, Fennec.ip, Fennec.portn) :: [{pid, pid}]
  def lookup_worker(dispatcher, ip, port) do
    Registry.lookup(dispatcher, key(ip, port))
  end

  defp find_or_start_worker(dispatcher, worker_sup, client) do
    %{ip: ip, port: port} = client
    case lookup_worker(dispatcher, ip, port) do
      [{_owner, pid}] -> {:ok, pid}
      [] ->
        start_worker(worker_sup, client)
    end
  end

  defp start_worker(worker_sup, client) do
    case Worker.start(worker_sup, client) do
      {:ok, pid} ->
        {:ok, pid}
      _ ->
        :error
    end
  end

  defp key(ip, port), do: {ip, port}
end
