defmodule Fennec.ReservationLog do
  @moduledoc false

  ## Runtime support for storing and fetching pending reservations.
  ## I.e. an ETS table owner process.

  alias Fennec.TURN.Reservation
  alias Jerboa.Format.Body.Attribute.ReservationToken

  def start_link() do
    Agent.start_link(fn -> init_db(__MODULE__) end, name: __MODULE__)
  end

  def child_spec() do
    Supervisor.Spec.worker(Fennec.ReservationLog, [])
  end

  @spec register(Reservation.t) :: :ok | {:error, :exists}
  def register(%Reservation{} = r) do
    case :ets.insert_new(__MODULE__, Reservation.to_tuple(r)) do
      false ->
        {:error, :exists}
      _ -> :ok
    end
  end

  @spec take(ReservationToken.t) :: Reservation.t | nil
  def take(%ReservationToken{} = token) do
    case :ets.take(__MODULE__, token.value) do
      [] -> nil
      [r] ->
        Reservation.from_tuple(r)
    end
  end

  @spec expire(ReservationToken.t) :: :ok
  def expire(token) do
    case take(token) do
      nil -> :ok
      %Reservation{} ->
        :ok
    end
  end

  defp init_db(table_name) do
    ## TODO: largely guesswork here, not load tested
    perf_opts = [write_concurrency: true]
    ^table_name = :ets.new(table_name, [:public, :named_table] ++ perf_opts)
  end

end
