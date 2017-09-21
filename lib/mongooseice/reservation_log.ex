defmodule MongooseICE.ReservationLog do
  @moduledoc false

  ## Runtime support for storing and fetching pending reservations.
  ## ReservationLog is just a process registry of processes implemented in
  ## MongooseICE.TURN.Reservation.Instance module. Each of those processes corresponds to single
  ## reservation in order to easly invalidate itself when needed.

  alias MongooseICE.TURN.Reservation
  alias Jerboa.Format.Body.Attribute.ReservationToken

  require Logger

  def start_link() do
    Registry.start_link(:unique, __MODULE__)
  end

  def child_spec() do
    Supervisor.Spec.worker(__MODULE__, [])
  end

  @spec register(Reservation.t, timeout :: MongooseICE.Time.seconds) :: :ok
  def register(%Reservation{} = reservation, timeout) do
    {:ok, reservation_pid} = GenServer.start_link(Reservation.Instance, [
      __MODULE__, self(), reservation, :timer.seconds(timeout)
    ])
    :ok = :gen_udp.controlling_process(reservation.socket, reservation_pid)
  end

  @spec take(ReservationToken.t) :: Reservation.t | nil
  def take(%ReservationToken{} = token) do
    case Registry.lookup(__MODULE__, token) do
      [] -> nil
      [{_owner, pid}] ->
        GenServer.call(pid, :take)
    end
  end

end
