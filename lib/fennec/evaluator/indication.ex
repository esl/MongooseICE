defmodule Fennec.Evaluator.Indication do
  @moduledoc false

  alias Jerboa.Params

  @spec service(Params.t, map) :: Params.t | :void
  def service(parameters, _) do
    case method(parameters) do
      :binding ->
        :void
      _ ->
        :error
    end
  end

  defp method(%Params{method: m}) do
    m
  end
end
