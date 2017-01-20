defmodule Fennec.UDP do
  @moduledoc """
  UDP STUN server

  The easiest way to start a server is to hook it up
  to your supervision tree:

      children = [
        supervisor(Fennec.UDP, [[port: 3478]]),
        supervisor(Fennec.UDP, [[port: 1234]]),
        ...
      ]

  You may start multiple UDP servers at a time.
  """

  @type socket :: :gen_udp.socket
  @type start_options :: [option]
  @type option :: {:ip, :inet.ip_address} | {:port, :inet.port_number}

  @default_opts [ip: {127, 0, 0, 1}, port: 3478]
  @allowed_opts [:ip, :port]

  @doc """
  Starts UDP STUN server with given options

  Default options are:
      #{inspect @default_opts}

  Links the server to the calling process. If the server with given port
  number was already started, this function will crash.
  """
  @spec start_link(start_options) :: Supervisor.on_start
  def start_link(opts) do
    opts = normalize_opts(opts)
    {:ok, pid} = Fennec.UDP.Supervisor.start_link(opts)
  end

  defp normalize_opts(opts) do
    @default_opts
    |> Keyword.merge(opts)
    |> Keyword.take(@allowed_opts)
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
