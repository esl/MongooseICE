defmodule Fennec.Evaluator.Indication do
  @moduledoc false

  alias Jerboa.Params
  alias Fennec.TURN

  @spec service(Params.t, map, TURN.t) :: Params.t | :void
  def service(parameters, _, _turn_state) do
    case method(parameters) do
      :binding ->
        :void
    end
  end

  defp method(x) do
    Params.get_method(x)
  end
end
