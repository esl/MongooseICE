defmodule Fennec.TURN do
  @moduledoc false
  # This module defines a struct used as TURN protocol state.

  alias Jerboa.Format
  alias Fennec.TURN.Channel

  defstruct allocation: nil, permissions: %{}, channels: {%{}, %{}},
    nonce: nil, realm: nil

  @permission_lifetime 5 * 60 # MUST be 5mins

  @type t :: %__MODULE__{
    allocation: nil | Fennec.TURN.Allocation.t,
    permissions: %{peer_addr :: Fennec.ip => expiration_time :: integer},
    channels: {%{peer :: Fennec.address => Channel.t},
               %{Format.channel_number  => Channel.t}},
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
    {_, number_to_channel} = turn.channels
    Map.fetch(number_to_channel, number)
  end
  def get_channel(turn, peer) do
    {peer_to_channel, _} = turn.channels
    Map.fetch(peer_to_channel, peer)
  end

  @spec put_channel(t, Channel.t) :: t
  def put_channel(turn, %Channel{peer: peer, number: number} = channel) do
    {peer_to_channel, number_to_channel} = turn.channels
    new_channels = {Map.put(peer_to_channel, peer, channel),
                    Map.put(number_to_channel, number, channel)}
    %{turn | channels: new_channels}
  end
end
