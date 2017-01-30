defmodule Fennec.Evaluator.Request do
  @moduledoc false

  alias Jerboa.Params

  @spec service(Params.t, map) :: Params.t
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

  defp method(x) do
    Params.get_method(x)
  end

  defp response(x) do
    case errors?(x) do
      false ->
        success(x)
      true ->
        failure(x)
    end
  end

  defp errors?(%Params{attributes: _}) do
    false
  end

  defp success(x) do
    Params.put_class(x, :success)
  end

  defp failure(x) do
    Params.put_class(x, :failure)
  end
end
