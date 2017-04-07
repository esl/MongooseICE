defmodule Fennec.TURN.Allocation do
  @moduledoc false
  # This module defines a struct that is used to represent active TURN allocation
  # made by a client.

  defstruct socket: nil, owner_username: nil, req_id: nil, expire_at: 0

  @type t :: %__MODULE__{
    socket: :gen_udp.socket,
    req_id: binary,
    owner_username: binary,
    expire_at: integer # system time in seconds
  }

  @doc false
  def default_lifetime, do: 10 * 60

end
