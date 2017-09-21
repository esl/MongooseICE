defmodule MongooseICE.UDP do
  @moduledoc """
  UDP STUN server

  The easiest way to start a server is to spawn it under MongooseICE's
  supervision tree providing the following configuration:

      config :mongooseice, :servers,
        udp: [ip: {192,168, 1, 21}, port: 32323]

  ...or hook it up to your supervision tree:

      children = [
        MongooseICE.UDP.child_spec([port: 3478]),
        MongooseICE.UDP.child_spec([port: 1234]),
        ...
      ]

  You can also start a server under MongooseICE's supervision tree
  using `start/1`.

  ## Options

  All methods of starting a server accept the same configuration options
  passed as a keyword list:
  * `:port` - the port which server should be bound to
  * `:ip` - the address of an interface which server should listen on
  * `:relay_ip` - the address of an interface which relay should listen on
  * `:realm` - public name of the server used as context of authorization.
  Does not have to be same as the server's hostname, yet in very basic configuration it may be.

  You may start multiple UDP servers at a time.
  """

  @type socket :: :gen_udp.socket
  @type server_opts :: [option]
  @type option :: {:ip, MongooseICE.ip} | {:port, MongooseICE.portn} |
                  {:relay_ip, MongooseICE.ip} | {:realm, String.t}

  @default_opts [ip: {127, 0, 0, 1}, port: 3478, relay_ip: {127, 0, 0, 1},
                 realm: "localhost"]
  @allowed_opts [:ip, :port, :relay_ip, :realm]

  @doc """
  Starts UDP STUN server under MongooseICE's supervisor

  Accepts the same options as `start_link/1`.
  """
  @spec start(server_opts) :: Supervisor.on_start_child
  def start(opts \\ @default_opts) do
    child = child_spec(opts)
    Supervisor.start_child(MongooseICE.Supervisor, child)
  end

  @doc """
  Stops UDP server started with start/1

  It accepts the *port number* server is running on as argument
  """
  @spec stop(MongooseICE.portn) :: :ok | :error
  def stop(port) do
    name = base_name(port)
    with :ok <- Supervisor.terminate_child(MongooseICE.Supervisor, name),
         :ok <- Supervisor.delete_child(MongooseICE.Supervisor, name) do
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
  @spec start_link(server_opts) :: Supervisor.on_start
  def start_link(opts \\ @default_opts) do
    opts = normalize_opts(opts)
    MongooseICE.UDP.Supervisor.start_link(opts)
  end

  @doc """
  Returns child specification of UDP server which can be hooked
  up into supervision tree
  """
  @spec child_spec(server_opts) :: Supervisor.Spec.spec
  def child_spec(opts) do
    opts = normalize_opts(opts)
    name = base_name(opts[:port])
    Supervisor.Spec.supervisor(MongooseICE.UDP.Supervisor, [opts], id: name)
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
