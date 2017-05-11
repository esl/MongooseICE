defmodule Fennec.UDP.Worker do
  @moduledoc false
  # Process handling STUN messages received over UDP
  #
  # Currently when worker receives a message which can't
  # be decoded or doesn't know how to process a message
  # it simply crashes.

  alias Fennec.UDP
  alias Fennec.TURN
  alias Fennec.STUN
  alias Fennec.UDP.{WorkerSupervisor, Dispatcher}

  use GenServer
  require Logger

  # should be configurable
  @timeout 5_000

  @type state :: %{socket: UDP.socket,
                   nonce_updated_at: integer,
                   client: Fennec.client_info,
                   server: UDP.server_opts,
                   turn: TURN.t
                 }

  # Starts a UDP worker
  @spec start(atom, Fennec.client_info) :: {:ok, pid} | :error
  def start(worker_sup, client) do
    WorkerSupervisor.start_worker(worker_sup, client)
  end

  # Process UDP datagram which might be STUN message
  @spec process_data(pid, binary) :: :ok
  def process_data(pid, data) do
    GenServer.cast(pid, {:process_data, data})
  end

  def start_link(dispatcher, server_opts, client) do
    GenServer.start_link(__MODULE__, [dispatcher, server_opts, client])
  end

  ## GenServer callbacks

  def init([dispatcher, server_opts, client]) do
    _ = Dispatcher.register_worker(dispatcher, self(), client.ip, client.port)
    state = %{client: client, nonce_updated_at: 0,
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
        {:ok, {:void, new_turn_state}} ->
          %{state | turn: new_turn_state}
        {:ok, {resp, new_turn_state}} ->
          :ok = :gen_udp.send(state.client.socket, state.client.ip,
                              state.client.port, resp)
          %{state | turn: new_turn_state}
      end
    {:noreply, next_state, timeout(next_state)}
  end

  def handle_info({:udp, socket, ip, port, data}, state = %{turn:
                  %TURN{allocation: %TURN.Allocation{socket: socket}}}) do
    turn_state = state.turn
    next_state =
      case TURN.has_permission(turn_state, ip) do
        {^turn_state, false} ->
          Logger.debug(~s"Dropped data from peer #{ip}:#{port} due to no permission")
          __MODULE__.handle_peer_data(:no_permission, ip, port, data, state)
        {new_turn_state, false} ->
          Logger.debug(~s"Dropped data from peer #{ip}:#{port} due to stale permission")
          next_state = %{state | turn: new_turn_state}
          __MODULE__.handle_peer_data(:stale_permission, ip, port, data, next_state)
        {^turn_state, true} ->
          Logger.debug(~s"Processing data from peer #{ip}:#{port}")
          __MODULE__.handle_peer_data(:allowed, ip, port, data, state)
      end
    {:noreply, next_state, timeout(next_state)}
  end

  def handle_info(:timeout, state) do
    handle_timeout(state)
  end

  def handle_peer_data(:allowed, ip, port, data, state) do
    :ok = :gen_udp.send(state.client.socket, state.client.ip, state.client.port,
                        Jerboa.Format.encode(data_params(ip, port, data)))
    state
  end
  # This function clause is for (not) handling rejected peer's data.
  # It exists solely to make testing easier.
  def handle_peer_data(_, _ip, _port, _data, state), do: state

  # Extracted as a separate function,
  # as it's easier to trace for side effects this way.
  defp handle_timeout(state) do
    {:stop, :normal, state}
  end

  defp maybe_update_nonce(state) do
    %{nonce_updated_at: last_update, turn: turn_state} = state
    expire_at = last_update + Fennec.Auth.nonce_lifetime()
    now = Fennec.Time.system_time(:second)
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
    now = Fennec.Time.system_time(:second)
    timeout_ms = (expire_at - now) * 1000
    max(0, timeout_ms)
  end

  defp data_params(ip, port, data) do
    alias Jerboa.Params, as: P
    alias Jerboa.Format.Body.Attribute.{Data, XORPeerAddress}
    P.new()
    |> P.put_class(:indication)
    |> P.put_method(:data)
    |> P.put_attr(%Data{content: data})
    |> P.put_attr(XORPeerAddress.new(ip, port))
  end
end
