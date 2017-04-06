defmodule Fennec.TURN.Permission do
  @moduledoc false
  # This module defines a struct that is used to represent active TURN permission
  # created by a client for the allocation.

  defstruct address: nil, expire_at: 0

  @type t :: %__MODULE__{
    address: Fennec.ip,
    expire_at: integer # system time in seconds
  }
end
