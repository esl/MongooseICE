defmodule Fennec.TURN do
  @moduledoc false
  # This module defines a struct used as TURN protocol state.

  alias Jerboa.Format
  alias Fennec.TURN.Channel

  defstruct allocation: nil, permissions: %{}, channels: [],
    nonce: nil, realm: nil

  @permission_lifetime 5 * 60 # MUST be 5mins

  @type t :: %__MODULE__{
    allocation: nil | Fennec.TURN.Allocation.t,
    permissions: %{peer_addr :: Fennec.ip => expiration_time :: integer},
    channels: [Channel.t],
    nonce: String.t,
    realm: String.t
  }

  @spec has_permission(state :: t, Fennec.ip) :: {new_state :: t, boolean}
  def has_permission(state, ip) do
    now = Fennec.Time.system_time(:second)
    perms = state.permissions
    case Map.get(perms, ip) do
      nil ->
        {state, false}
      expire_at when expire_at <= now ->
        new_perms = Map.delete(perms, ip)
        new_state = %__MODULE__{state | permissions: new_perms}
        {new_state, false}
      _ ->
        {state, true}
    end
  end

  @spec put_permission(t, peer_ip :: Fennec.ip) :: t
  def put_permission(turn_state, peer) do
    expire_at = Fennec.Time.system_time(:second) + @permission_lifetime
    new_permissions = Map.put(turn_state.permissions, peer, expire_at)
    %__MODULE__{turn_state | permissions: new_permissions}
  end

  @spec get_channel(t, peer_or_number :: Fennec.address | Format.channel_number)
    :: {:ok, Channel.t} | :error
  def get_channel(turn, number) when is_integer(number) do
    find_channel turn, & &1.number == number
  end
  def get_channel(turn, peer) do
    find_channel turn, & &1.peer == peer
  end

  @spec find_channel(t, (Channel.t -> boolean)) :: {:ok, Channel.t} | :error
  defp find_channel(turn, pred) do
    case Enum.find(turn.channels, pred) do
      nil -> :error
      c   -> {:ok, c}
    end
  end

  @spec put_channel(t, Channel.t) :: t
  def put_channel(turn, %Channel{peer: peer} = channel) do
    channels =
      case get_channel(turn, peer) do
        {:ok, _} ->
          Enum.reject(turn.channels, & &1.peer == peer)
        :error ->
          turn.channels
      end
    %{turn | channels: [channel | channels]}
  end
end
