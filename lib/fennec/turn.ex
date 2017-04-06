defmodule Fennec.TURN do
  @moduledoc false
  # This module defines a struct used as TURN protocol state.

  defstruct allocation: nil, permissions: [], channels: [],
            nonce: nil, realm: nil

  @type t :: %__MODULE__{
    allocation: nil | Fennec.TURN.Allocation.t,
    permissions: %{Fennec.ip => integer},
    channels: [],
    nonce: String.t,
    realm: String.t
  }
end
