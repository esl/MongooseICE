defmodule Fennec.Evaluator do
  @moduledoc false

  alias Jerboa.Params
  alias Fennec.TURN

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t} | :void
  def service(p, client, server, turn_state) do
    case class(p) do
      :request ->
        Fennec.Evaluator.Request.service(p, client, server, turn_state)
      :indication ->
        Fennec.Evaluator.Indication.service(p, client, server, turn_state)
    end
  end

  defp class(params) do
    Params.get_class(params)
  end
end
