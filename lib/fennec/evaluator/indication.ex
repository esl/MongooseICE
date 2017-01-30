defmodule Fennec.Evaluator.Indication do
  @moduledoc """

  Common to ALL INDICATIONS. E.g. all requests wind up as a success
  response OR a failure response.

  """

  alias Jerboa.Format, as: Parameters

  @spec service(Parameters.t, map) :: Parameters.t | :void
  def service(parameters, _) do
    case method(parameters) do
      :binding ->
        :void
      _ ->
        :error
    end
  end

  defp method(%Parameters{method: m}) do
    m
  end
end
