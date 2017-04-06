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
    state = %{socket: socket, client: client, nonce_updated_at: 0,
              server: server_opts, turn: %TURN{}}
    {:ok, state, timeout(state)}
  end

  def handle_call(:get_permissions, _from, state) do
    {:reply, state.turn.permissions, state, timeout(state)}
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
    now = Fennec.Helper.now
    next_state =
      case Map.get(state.turn.permissions, ip) do
        nil ->
          Logger.debug(~s"Dropped data from peer #{ip}:#{port} due to no permission")
          __MODULE__.handle_peer_data(:no_permission, ip, port, data, state)
        expire_at when expire_at > now ->
          Logger.debug(~s"Processing data from peer #{ip}:#{port}")
          __MODULE__.handle_peer_data(:allowed, ip, port, data, state)
        _ ->
          Logger.debug(~s"Dropped data from peer #{ip}:#{port} due to stale permission")
          new_perms = Map.delete(state.turn.permissions, ip)
          new_turn_state = %TURN{state.turn | permissions: new_perms}
          next_state = %{state | turn: new_turn_state}
          __MODULE__.handle_peer_data(:stale_permission, ip, port, data, next_state)
      end
    {:noreply, next_state, timeout(next_state)}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  def handle_peer_data(:allowed, _ip, _port, _data, state) do
    state
  end
  # This function clouse is for (not) handling rejected peer's data.
  # It exists solely to make testing easier.
  def handle_peer_data(_, _ip, _port, _data, state), do: state

  defp maybe_update_nonce(state) do
    %{nonce_updated_at: last_update, turn: turn_state} = state
    expire_at = last_update + Fennec.Auth.nonce_lifetime()
    now = Fennec.Helper.now
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
    now = Fennec.Helper.now
    max(0, expire_at - now)
  end
end
