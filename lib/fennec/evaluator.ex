defmodule Fennec.Evaluator do
  @moduledoc false

  alias Jerboa.Params
  alias Fennec.TURN

  @spec service(Params.t, map, TURN.t) :: {Params.t, TURN.t} | :void
  def service(p, client, turn_state) do
    case class(p) do
      :request ->
        Fennec.Evaluator.Request.service(p, client, turn_state)
      :indication ->
        Fennec.Evaluator.Indication.service(p, client, turn_state)
    end
  end

  defp class(params) do
    Params.get_class(params)
  end
end
