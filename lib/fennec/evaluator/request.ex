defmodule Fennec.Evaluator.Request do
  @moduledoc false

  alias Jerboa.Params
  alias Fennec.TURN

  @spec service(Params.t, map, %TURN{}) :: Params.t
  def service(params, changes, turn_state) do
    case service_(params, changes, turn_state) do
      {new_params, new_turn_state} ->
        {response(new_params), new_turn_state}
      new_params ->
        {response(new_params), turn_state}
    end
  end

  def service_(p, changes, turn_state) do
    case method(p) do
      :binding ->
        Fennec.Evaluator.Binding.Request.service(p, changes, turn_state)
      _ ->
        {:error, :unsupported_method}
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
