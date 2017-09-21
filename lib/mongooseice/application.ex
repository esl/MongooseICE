defmodule MongooseICE.Application do
  @moduledoc false

  @app :mongooseice
  @ip_addr_config_keys [:ip, :relay_ip]

  use Application

  def start(_type, _args) do
    loglevel = Confex.get(@app, :loglevel, :info)
    Logger.configure(level: loglevel)

    opts = [strategy: :one_for_one, name: MongooseICE.Supervisor]
    Supervisor.start_link([MongooseICE.ReservationLog.child_spec()] ++ servers(), opts)
  end

  defp servers do
    @app
    |> Confex.get_map(:servers, [])
    |> Enum.filter(fn({type, _}) -> is_proto_enabled(type) end)
    |> Enum.map(&make_server/1)
  end

  defp is_proto_enabled(type) do
    @app
    |> Confex.get(String.to_atom(~s"#{type}_enabled"), true)
  end

  defp make_server({type, config}) do
    config
    |> normalize_server_config()
    |> server_mod(type).child_spec()
  end

  defp normalize_server_config(config) do
    Enum.map(config, fn({key, value}) ->
      case Enum.member?(@ip_addr_config_keys, key) do
        false -> {key, value}
        true  -> {key, normalize_ip_addr(value)}
      end
    end)
  end

  defp normalize_ip_addr(addr) when is_binary(addr) do
    MongooseICE.Helper.string_to_inet(addr)
  end
  defp normalize_ip_addr(addr), do: addr

  defp server_mod(:udp), do: MongooseICE.UDP
end
