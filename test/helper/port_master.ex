defmodule Helper.PortMaster do
  use GenServer

  @base_client_port 32_000
  @base_server_port 12_000
  @server_name :port_master

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @server_name)
  end

  def checkout_port(type) do
    GenServer.call(@server_name, {:checkout_port, type})
  end

  def init(_opts) do
    {:ok, %{
      next_client: @base_client_port,
      next_server: @base_server_port
    }}
  end

  def handle_call({:checkout_port, :client}, _from, state) do
    new_state = %{state | next_client: state.next_client + 1}
    {:reply, state.next_client, new_state}
  end

  def handle_call({:checkout_port, :server}, _from, state) do
    new_state = %{state | next_server: state.next_server + 1}
    {:reply, state.next_server, new_state}
  end

end
