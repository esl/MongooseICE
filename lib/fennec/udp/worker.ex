defmodule Fennec.UDP.Worker do
  @moduledoc false
  # Process handling STUN messages received over UDP

  alias Fennec.UDP
  alias Fennec.UDP.{WorkerSupervisor, Dispatcher}

  use GenServer

  # should be configurable
  @timeout 5_000

  @type state :: %{socket: :gen_udp.socket,
                   ip: :inet.ip_address,
                   port: :inet.port_number}

  # Starts a UDP worker
  @spec start(UDP.socket, Fennec.ip, Fennec.portn) :: {:ok, pid} | :error
  def start(socket, ip, port) do
    WorkerSupervisor.start_worker(socket, ip, port)
  end

  # Process UDP datagram which might be STUN message
  @spec process_data(pid, binary) :: :ok
  def process_data(pid, data) do
    GenServer.cast(pid, {:process_data, data})
  end

  def start_link(socket, ip, port) do
    GenServer.start_link(__MODULE__, [socket, ip, port])
  end

  ## GenServer callbacks

  def init([socket, ip, port]) do
    Dispatcher.register_worker(self(), ip, port)
    {:ok, %{socket: socket, ip: ip, port: port}}
  end

  def handle_cast({:process_data, data}, state) do
    require Logger
    Logger.debug "[#{inspect self()}] Worker received: #{inspect data}"
    {:noreply, state, @timeout}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end
end
