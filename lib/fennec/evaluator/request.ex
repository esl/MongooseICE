defmodule Fennec.Evaluator.Request do
  @moduledoc """

  Common to ALL REQUESTS. E.g. all requests wind up as a success
  response OR a failure response.

  """

  alias Jerboa.Format, as: Parameters

  @spec service(Parameters.t, map) :: Parameters.t
  def service(parameters, changes) do
    parameters
    |> service_(changes)
    |> response
  end

  def service_(p, changes) do
    case method(p) do
      :binding ->
        Fennec.Evaluator.Binding.Request.service(p, changes)
      _ ->
        :error
    end
  end

  defp method(%Parameters{method: m}) do
    m
  end

  defp response(x) do
    case errors?(x) do
      false ->
        success(x)
      true ->
        failure(x)
    end
  end

  defp errors?(%Parameters{attributes: _}) do
    false
  end

  defp success(x) do
    %{x | class: :success}
  end

  defp failure(x) do
    %{x | class: :failure}
  end
end
