defmodule Fennec.Evaluator do
  @moduledoc false

  alias Jerboa.Params
  alias Fennec.TURN

  @spec service(Params.t, map, TURN.t) :: {Params.t, TURN.t} | :void
  def service(p, changes, turn_state) do
    case class(p) do
      :request ->
        Fennec.Evaluator.Request.service(p, changes, turn_state)
      :indication ->
        Fennec.Evaluator.Indication.service(p, changes, turn_state)
    end
  end

  defp class(x) do
    Params.get_class(x)
  end
end
