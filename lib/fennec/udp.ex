defmodule Fennec.UDP do
  @moduledoc """
  STUN stack on UDP
  """

  @type socket :: :gen_udp.socket

  @doc """
  Starts UDP STUN stack with receiveing packets on given port
  """
  @spec start_link(Fennec.portn) :: Supervisor.on_start
  def start_link(port) do
    Fennec.UDP.Supervisor.start_link(port)
  end
end
