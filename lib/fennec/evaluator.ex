defmodule Fennec.Evaluator do
  @moduledoc false

  alias Jerboa.Params

  @spec service(Params.t, map, %Fennec.TURN{}) :: Params.t | :void
  def service(p, changes, turn_state) do
    case class(p) do
      :request ->
        Fennec.Evaluator.Request.service(p, changes, turn_state)
      :indication ->
        Fennec.Evaluator.Indication.service(p, changes, turn_state)
      _ ->
        :error
    end
  end

  defp class(x) do
    Params.get_class(x)
  end
end
