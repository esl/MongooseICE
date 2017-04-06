defmodule Fennec.UDP.Worker do
  @moduledoc false
  # Process handling STUN messages received over UDP
  #
  # Currently when worker receives a message which can't
  # be decoded or don't know how to process a message
  # it simply crashes.

  alias Fennec.UDP
  alias Fennec.TURN
  alias Fennec.STUN
  alias Fennec.UDP.{WorkerSupervisor, Dispatcher}

  use GenServer
  require Logger

  # should be configurable
  @timeout 5_000


  @type state :: %{socket: :gen_udp.socket,
                   nonce_updated_at: integer,
                   client: Fennec.client_info,
                   server: Fennec.UDP.start_options,
                   turn: TURN.t
                 }

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

  def start_link(dispatcher, server_opts, socket, ip, port) do
    GenServer.start_link(__MODULE__, [dispatcher, server_opts, socket, ip, port])
  end

  ## GenServer callbacks

  def init([dispatcher, server_opts, socket, ip, port]) do
    _ = Dispatcher.register_worker(dispatcher, self(), ip, port)
    client = %{ip: ip, port: port}
    {:ok, %{socket: socket, client: client, nonce_updated_at: 0,
            server: server_opts, turn: %TURN{}}}
  end

  def handle_cast({:process_data, data}, state) do
    state = maybe_update_nonce(state)
    next_state =
      case STUN.process_message(data, state.client, state.server, state.turn) do
        {:ok, :void} ->
          state
        {:ok, {resp, new_turn_state}} ->
          :ok = :gen_udp.send(state.socket, state.client.ip,
                              state.client.port, resp)
          %{state | turn: new_turn_state}
      end
    {:noreply, next_state, timeout(next_state)}
  end

  def handle_info({:udp, socket, ip, port, data}, state = %{turn:
                  %TURN{allocation: %TURN.Allocation{socket: socket}}}) do
    next_state = handle_peer_data(ip, port, data, state)
    {:noreply, next_state}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  defp handle_peer_data(ip, port, data, state) do
    Logger.debug(~s"Peer #{ip}:#{port} sent data: #{data}")
    now = System.os_time(:seconds)
    case Enum.find(state.turn.perms, nil, &(&1.address == ip)) do
      %TURN.Permission{expire_at: expire_at} when expire_at < now ->
        Logger.debug(~s"Processing data from peer #{ip}:#{port}")
        state
      %TURN.Permission{} = p ->
        Logger.debug(~s"Dropped data from peer #{ip}:#{port} due to stale permission")
        new_turn_state = %TURN{state.turn | permissions: state.turn.perms -- [p]}
        %{state | turn: new_turn_state}
      nil ->
        Logger.debug(~s"Dropped data from peer #{ip}:#{port} due to no permission")
        state
    end
  end

  defp maybe_update_nonce(state) do
    %{nonce_updated_at: last_update, turn: turn_state} = state
    expire_at = last_update + Fennec.Auth.nonce_lifetime()
    now = System.os_time(:seconds)
    case expire_at < now do
      true ->
        new_turn_state = %TURN{turn_state | nonce: Fennec.Auth.gen_nonce()}
        %{state | turn: new_turn_state, nonce_updated_at: now}
      false ->
        state
    end
  end

  defp timeout(%{turn: %TURN{allocation: nil}}), do: @timeout
  defp timeout(%{turn: %TURN{allocation: allocation}}) do
    %TURN.Allocation{expire_at: expire_at} = allocation
    now = System.system_time(:second)
    max(0, expire_at - now)
  end
end
