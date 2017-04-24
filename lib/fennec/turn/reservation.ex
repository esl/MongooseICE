defmodule Reservation do
  @moduledoc false

  ## A Reservation represents a relay address reserved
  ## by an allocation request with a positive `EvenPort.reserved?`.
  ## The relay address is created along with a RESERVATION-TOKEN
  ## which is returned to the client requesting the allocation,
  ## and is stored until another allocation request with the same
  ## reservation token is sent by the client.
  ## The Reservation is then turned into a full-blown Allocation.
  ## This mechanism is used to allocate consecutive port pairs,
  ## for example for RTP and RTCP transmissions.

  alias Jerboa.Format.Body.Attribute.ReservationToken

  defstruct [:token, :socket]

  @type t :: %__MODULE__{
    token: ReservationToken.t,
    socket: Fennec.UDP.socket
  }

  @spec new(Fennec.UDP.socket) :: t
  def new(socket) do
    %__MODULE__{token: ReservationToken.new(),
                socket: socket}
  end

end
