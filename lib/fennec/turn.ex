defmodule Fennec.TURN do
  @moduledoc false
  # This module defines a struct used as TURN protocol state.

  defstruct allocation: nil, permissions: %{}, channels: [],
            nonce: nil, realm: nil, reservation_timer_ref: nil

  @type t :: %__MODULE__{
    allocation: nil | Fennec.TURN.Allocation.t,
    permissions: %{peer_addr :: Fennec.ip => expiration_time :: integer},
    channels: [],
    nonce: String.t,
    realm: String.t,
    reservation_timer_ref: Process.timer_ref
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
end
