defmodule MongooseICE.TURN.Channel do
  @moduledoc false
  # Defines a struct representing a TRUN channel

  defstruct [:peer, :number, :expiration_time]

  @type t :: %__MODULE__{
    peer: MongooseICE.address,
    number: Jerboa.Format.ChannelNumber,
    expiration_time: pos_integer
  }
end
