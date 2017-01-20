defmodule Fennec.UDP do
  @moduledoc """
  UDP STUN server

  The easiest way to start a server is to hook it up
  to your supervision tree:

      children = [
        supervisor(Fennec.UDP, [3478]),
        supervisor(Fennec.UDP, [1234]),
        ...
      ]

  You may start multiple UDP servers at a time.
  """

  @type socket :: :gen_udp.socket

  @doc """
  Starts UDP STUN server receiving on a given port number

  Links the server to a calling process.
  """
  @spec start_link(Fennec.portn) :: Supervisor.on_start
  def start_link(port) do
    Fennec.UDP.Supervisor.start_link(port)
  end

  @doc false
  def base_name(port) do
    "#{__MODULE__}.#{port}" |> String.to_atom()
  end

  @doc false
  def sup_name(base_name) do
    build_name(base_name, "Supervisor")
  end

  @doc false
  def receiver_name(base_name) do
    build_name(base_name, "Receiver")
  end

  @doc false
  def dispatcher_name(base_name) do
    build_name(base_name, "Dispatcher")
  end

  @doc false
  def worker_sup_name(base_name) do
    build_name(base_name, "WorkerSupervisor")
  end

  @doc false
  defp build_name(base, suffix) do
    "#{base}.#{suffix}" |> String.to_atom()
  end
end
