defmodule Fennec.UDP.Receiver do
  @moduledoc false
  # STUN UDP receiver process

  use GenServer

  @type state :: %{dispatcher: atom,
                   worker_sup: atom,
                   socket: Fennec.UDP.socket}

  def start_link(base_name, opts) do
    name = Fennec.UDP.receiver_name(base_name)
    GenServer.start_link(__MODULE__, [base_name, opts], name: name)
  end

  def init([base_name, opts]) do
    worker_sup = Fennec.UDP.worker_sup_name(base_name)
    dispatcher = Fennec.UDP.dispatcher_name(base_name)
    state = %{dispatcher: dispatcher, worker_sup: worker_sup, socket: nil}
    socket_opts = [:binary, active: true, ip: opts[:ip]]
    case :gen_udp.open(opts[:port], socket_opts) do
      {:ok, socket} ->
        {:ok, %{state | socket: socket}}
      {:error, reason} ->
        {:stop, "Failed to open UDP(#{opts[:ip]}:#{opts[:port]}) socket. Reason: #{inspect reason}"}
    end
  end

  def handle_info({:udp, socket, ip, port, data}, %{socket: socket} = state) do
    ## TODO: refactor to a proper struct?
    client = %{socket: socket, ip: ip, port: port}
    _ = Fennec.UDP.Dispatcher.dispatch(state.dispatcher, state.worker_sup, client, data)
    {:noreply, state}
  end
end
