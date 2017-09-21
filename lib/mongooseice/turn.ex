defmodule MongooseICE.TURN do
  @moduledoc false
  # This module defines a struct used as TURN protocol state.

  alias Jerboa.Format
  alias MongooseICE.TURN.Channel

  defstruct allocation: nil, permissions: %{}, channels: [],
    nonce: nil, realm: nil

  @permission_lifetime 5 * 60 # MUST be 5mins
  @channel_lifetime 10 * 60   # MUST be 10 minutes

  @type t :: %__MODULE__{
    allocation: nil | MongooseICE.TURN.Allocation.t,
    permissions: %{peer_addr :: MongooseICE.ip => expiration_time :: integer},
    channels: [Channel.t],
    nonce: String.t,
    realm: String.t
  }

  @spec has_permission(state :: t, MongooseICE.ip) :: {new_state :: t, boolean}
  def has_permission(state, ip) do
    now = MongooseICE.Time.system_time(:second)
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

  @spec put_permission(t, peer_ip :: MongooseICE.ip) :: t
  def put_permission(turn_state, peer) do
    expire_at = MongooseICE.Time.system_time(:second) + @permission_lifetime
    new_permissions = Map.put(turn_state.permissions, peer, expire_at)
    %__MODULE__{turn_state | permissions: new_permissions}
  end

  @spec get_channel(t, peer_or_number :: MongooseICE.address | Format.channel_number)
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

  @spec put_channel(t, MongooseICE.address, Format.channel_number) :: t
  def put_channel(turn, peer, channel_number) do
    now = MongooseICE.Time.system_time(:second)
    channel = %Channel{peer: peer, number: channel_number,
                       expiration_time: now + @channel_lifetime}
    channels =
      case get_channel(turn, peer) do
        {:ok, _} ->
          Enum.reject(turn.channels, & &1.peer == peer)
        :error ->
          turn.channels
      end
    %{turn | channels: [channel | channels]}
  end

  @spec has_channel(t, peer_or_number :: MongooseICE.address | Format.channel_number)
    :: {:ok, t, Channel.t} | {:error, t}
  def has_channel(turn_state, peer_or_number) do
    now = MongooseICE.Time.system_time(:second)
    with {:ok, channel}     <- get_channel(turn_state, peer_or_number),
         {peer_ip, _}        = channel.peer,
         true               <- channel.expiration_time > now,
         {turn_state, true} <- has_permission(turn_state, peer_ip) do
      {:ok, turn_state, channel}
    else
      :error ->
        {:error, turn_state}
      false ->
        {:error, remove_channel(turn_state, peer_or_number)}
      {turn_state, false} ->
        {:error, turn_state}
    end
  end

  @spec remove_channel(t, peer_or_number :: MongooseICE.address | Format.channel_number)
    :: t
  defp remove_channel(turn_state, peer_or_number) do
    {:ok, channel} = get_channel(turn_state, peer_or_number)
    new_channels =
      Enum.reject(turn_state.channels, & &1.peer == channel.peer)
    %__MODULE__{turn_state | channels: new_channels}
  end
end
