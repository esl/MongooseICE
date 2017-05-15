defmodule Fennec.TURN.Reservation.Instance do
  @moduledoc false

  use GenServer

  def init([registry, allocation_worker, reservation, timeout]) do
    {:ok, _owner} = Registry.register(registry, reservation.token, self())
    monitor_ref = Process.monitor(allocation_worker)
    {:ok, %{reservation: reservation, monitor_ref: monitor_ref}, timeout}
  end

  def handle_call(:take, {from, _tag}, %{reservation: reservation} = state) do
    :ok = :gen_udp.controlling_process(reservation.socket, from)
    # Reply, clear reservation and timout right away
    {:reply, reservation, %{state | reservation: nil}, 0}
  end

  def handle_info(:timeout, state), do: do_stop(state)
  def handle_info({:DOWN, monitor_ref, :process, _obj, _info},
                  %{monitor_ref: monitor_ref} = state) do
    do_stop(state)
  end

  defp do_stop(state) do
    if state.reservation != nil do
      :ok = :inet.close(state.reservation.socket)
    end

    Process.demonitor(state.monitor_ref)
    {:stop, :normal, %{state | reservation: nil}}
  end

end
