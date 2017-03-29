defmodule Fennec.UDP.Worker do
  @moduledoc false
  # Process handling STUN messages received over UDP
  #
  # Currently when worker receives a message which can't
  # be decoded or don't know how to process a message
  # it simply crashes.

  alias Fennec.UDP
  alias Fennec.TURN
  alias Fennec.UDP.{WorkerSupervisor, Dispatcher}

  use GenServer

  # should be configurable
  @timeout 5_000

  @type state :: %{socket: :gen_udp.socket,
                   ip: :inet.ip_address,
                   port: :inet.port_number,
                   turn: %TURN{}}

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
    {:ok, %{socket: socket, ip: ip, port: port, turn: %TURN{}}}
  end

  def handle_cast({:process_data, data}, state) do
    next_state =
      case Fennec.STUN.process_message(data, state.ip, state.port, state.turn) do
        {:ok, :void} ->
          state
        {:ok, {resp, new_turn_state}} ->
          :ok = :gen_udp.send(state.socket, state.ip, state.port, resp)
          %{state | turn: new_turn_state}
        {:error, _reason} ->
          state
      end
    {:noreply, next_state, timeout(next_state)}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  defp timeout(%{turn: %TURN{allocation_socket: nil}}), do: @timeout
  defp timeout(%{turn: %TURN{allocation_time: refreshed_at}}) do
    now = System.system_time(:second)
    now - refreshed_at
  end
end
