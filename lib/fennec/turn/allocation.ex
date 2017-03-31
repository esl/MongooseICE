defmodule Fennec.TURN.Allocation do
  @moduledoc false
  # This module defines a struct that is used to represent active TURN allocation
  # made by a client.

  defstruct socket: nil, owner: nil, expire_at: 0

  @type t :: %__MODULE__{
    socket: :gen_udp.socket,
    owner: binary,
    expire_at: integer # system time in seconds
  }
end
