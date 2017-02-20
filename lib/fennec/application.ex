defmodule Fennec.Application do
  @moduledoc false

  use Application

  import Supervisor.Spec

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Fennec.Supervisor]
    Supervisor.start_link(servers(), opts)
  end

  defp servers do
    :fennec
    |> Application.get_env(:servers, [])
    |> Enum.map(&make_server/1)
  end

  defp make_server({type, config}) do
    type
    |> server_mod()
    |> supervisor([config])
  end

  defp server_mod(:udp), do: Fennec.UDP
end
