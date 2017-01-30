defmodule Fennec.UDP.Worker do
  @moduledoc false
  # Process handling STUN messages received over UDP
  #
  # Currently when worker receives a message which can't
  # be decoded or don't know how to process a message
  # it simply crashes.

  alias Fennec.UDP
  alias Fennec.UDP.{WorkerSupervisor, Dispatcher}

  use GenServer

  # should be configurable
  @timeout 5_000

  @type state :: %{socket: :gen_udp.socket,
                   ip: :inet.ip_address,
                   port: :inet.port_number}

  # Starts a UDP worker
  @spec start(atom, UDP.socket, Fennec.ip, Fennec.portn) :: {:ok, pid} | :error
  def start(worker_sup, socket, ip, port) do
    WorkerSupervisor.start_worker(worker_sup, socket, ip, port)
  end

  # Process UDP datagram which might be STUN message
  @spec process_data(pid, binary) :: :ok
  def process_data(pid, data) do
    GenServer.cast(pid, {:process_data, data})
  end

  def start_link(dispatcher, socket, ip, port) do
    GenServer.start_link(__MODULE__, [dispatcher, socket, ip, port])
  end

  ## GenServer callbacks

  def init([dispatcher, socket, ip, port]) do
    _ = Dispatcher.register_worker(dispatcher, self(), ip, port)
    {:ok, %{socket: socket, ip: ip, port: port}}
  end

  def handle_cast({:process_data, data}, state) do
    case Fennec.STUN.process_message!(data, state.ip, state.port) do
      :void ->
        :ok
      resp ->
        :ok = :gen_udp.send(state.socket, state.ip, state.port, resp)
    end
    {:noreply, state, @timeout}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end
end
