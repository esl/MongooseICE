defmodule Fennec.TURN.Reservation do
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

  defstruct [:token, :socket, :t_ref]

  @type t :: %__MODULE__{
    token: ReservationToken.t,
    socket: Fennec.UDP.socket,
    t_ref: :timer.tref()
  }

  @spec new(Fennec.UDP.socket) :: t
  def new(socket) do
    %__MODULE__{token: ReservationToken.new(),
                socket: socket}
  end

  @spec default_timeout :: Fennec.Time.seconds
  def default_timeout, do: 30

  ## Only intended for storing in ETS
  def to_tuple(%__MODULE__{} = r) do
    %__MODULE__{token: %ReservationToken{value: token}} = r
    {token, r.socket}
  end

  ## Only intended for storing in ETS
  def from_tuple({token, socket}) when is_binary(token) and is_port(socket) do
    %__MODULE__{token: %ReservationToken{value: token},
                socket: socket}
  end

end
