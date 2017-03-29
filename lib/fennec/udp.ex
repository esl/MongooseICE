defmodule Fennec.UDP do
  @moduledoc """
  UDP STUN server

  The easiest way to start a server is to spawn it under Fennec's
  supervision tree providing the following configuration:

      config :fennec, :servers,
        udp: [ip: {192,168, 1, 21}, port: 32323]

  ...or hook it up to your supervision tree:

      children = [
        supervisor(Fennec.UDP, [[port: 3478]]),
        supervisor(Fennec.UDP, [[port: 1234]]),
        ...
      ]

  You can also start a server under Fennec's supervision tree
  using `start/1`.

  ## Options

  All methods of starting a server accept the same configuration options
  passed as a keyword list:
  * `:port` - the port which server should be bound to
  * `:ip` - the address of an interface which server should listen on

  You may start multiple UDP servers at a time.
  """

  @type socket :: :gen_udp.socket
  @type start_options :: [option]
  @type option :: {:ip, Fennec.ip} | {:port, Fennec.portn}

  @default_opts [ip: {127, 0, 0, 1}, port: 3478]
  @allowed_opts [:ip, :port]

  @doc """
  Starts UDP STUN server under Fennec's supervisor

  Accepts the same options as `start_link/1`.
  """
  @spec start(start_options) :: Supervisor.on_start_child
  def start(opts) do
    opts = normalize_opts(opts)
    name = base_name(opts[:port])
    child = Supervisor.Spec.supervisor(Fennec.UDP.Supervisor, [opts], id: name)
    Supervisor.start_child(Fennec.Supervisor, child)
  end

  @doc """
  Stops UDP server started with start/1

  It accepts the *port number* server is running on as argument
  """
  @spec stop(Fennec.portn) :: :ok | :error
  def stop(port) do
    name = base_name(port)
    with :ok <- Supervisor.terminate_child(Fennec.Supervisor, name),
         :ok <- Supervisor.delete_child(Fennec.Supervisor, name) do
      :ok
    else
      _ -> :error
    end
  end

  @doc """
  Starts UDP STUN server with given options

  Default options are:
      #{inspect @default_opts}

  Links the server to the calling process.
  """
  @spec start_link(start_options) :: Supervisor.on_start
  def start_link(opts) do
    opts = normalize_opts(opts)
    Fennec.UDP.Supervisor.start_link(opts)
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
  def relay_sup_name(base_name) do
    build_name(base_name, "RelaySupervisor")
  end

  @doc false
  defp build_name(base, suffix) do
    "#{base}.#{suffix}" |> String.to_atom()
  end
end
