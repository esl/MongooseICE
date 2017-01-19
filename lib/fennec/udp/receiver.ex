defmodule Fennec.UDP.Receiver do
  @moduledoc false
  # STUN UDP receiver process

  use GenServer

  @type state :: Fennec.UDP.socket

  def start_link(listen_port) do
    GenServer.start_link(__MODULE__, [listen_port], name: __MODULE__)
  end

  def init([listen_port]) do
    case :gen_udp.open(listen_port, [:binary, active: true]) do
      {:ok, socket} ->
        {:ok, socket}
      {:error, reason} ->
        {:stop, "Failed to open UDP socket. Reason: #{inspect reason}"}
    end
  end

  def handle_info({:udp, socket, ip, port, data}, socket) do
    Fennec.UDP.Dispatcher.dispatch(socket, ip, port, data)
    {:noreply, socket}
  end
end
