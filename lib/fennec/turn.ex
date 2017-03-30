defmodule Fennec.TURN do
  @moduledoc """
  This module defines a record used as TURN protocol state.
  """

  defstruct allocation: nil, permissions: [], channels: []

  @type t :: %__MODULE__{
    allocation: nil | Fennec.TURN.Allocation.t,
    permissions: [],
    channels: []
  }
end
