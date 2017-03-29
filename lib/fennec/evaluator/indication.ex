defmodule Fennec.Evaluator.Indication do
  @moduledoc false

  alias Jerboa.Params

  @spec service(Params.t, map, %Fennec.TURN{}) :: Params.t | :void
  def service(parameters, _, turn_state) do
    case method(parameters) do
      :binding ->
        :void
      _ ->
        {:error, :unsupported_method}
    end
  end

  defp method(x) do
    Params.get_method(x)
  end
end
