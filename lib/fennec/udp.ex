defmodule Fennec.UDP do
  @moduledoc """
  UDP STUN server

  The easiest way to start a server is to hook it up
  to your supervision tree:

      children = [
        supervisor(Fennec.UDP, [port_number])
      ]

  Currently only one UDP server may be started at a time.
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
end
