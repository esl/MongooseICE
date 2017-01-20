defmodule Fennec.UDP.Receiver do
  @moduledoc false
  # STUN UDP receiver process

  use GenServer

  @type state :: %{dispatcher: atom,
                   worker_sup: atom,
                   socket: Fennec.UDP.socket}

  def start_link(listen_port, base_name) do
    name = Fennec.UDP.receiver_name(base_name)
    GenServer.start_link(__MODULE__, [listen_port, base_name], name: name)
  end

  def init([listen_port, base_name]) do
    worker_sup = Fennec.UDP.worker_sup_name(base_name)
    dispatcher = Fennec.UDP.dispatcher_name(base_name)
    state = %{dispatcher: dispatcher, worker_sup: worker_sup, socket: nil}
    case :gen_udp.open(listen_port, [:binary, active: true]) do
      {:ok, socket} ->
        {:ok, %{state | socket: socket}}
      {:error, reason} ->
        {:stop, "Failed to open UDP socket. Reason: #{inspect reason}"}
    end
  end

  def handle_info({:udp, socket, ip, port, data}, %{socket: socket} = state) do
    _ = Fennec.UDP.Dispatcher.dispatch(state.dispatcher, state.worker_sup,
      state.socket, ip, port, data)
    {:noreply, state}
  end
end
