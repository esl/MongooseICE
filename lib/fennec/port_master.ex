defmodule Fennec.PortMaster do
  use GenServer

  @base_relay_port 50_000
  @server_name :port_master

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @server_name)
  end

  def checkout_port(type) do
    GenServer.call(@server_name, {:checkout_port, type})
  end

  def init(_opts) do
    {:ok, %{
      next_relay: @base_relay_port
    }}
  end

  def handle_call({:checkout_port, :relay}, _from, state) do
    new_state = %{state | next_relay: state.next_relay + 1}
    {:reply, state.next_relay, new_state}
  end

end
