defmodule Fennec.Evaluator.Request do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute
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
      :allocate ->
        Fennec.Evaluator.Allocate.Request.service(p, changes, turn_state)
    end
  end

  defp method(x) do
    Params.get_method(x)
  end

  defp response(result) do
    case errors?(result) do
      false ->
        success(result)
      true ->
        failure(result)
    end
  end

  defp errors?(%Params{attributes: attrs}) do
     attrs
     |> Enum.any? &error_attr?/1
  end

  defp success(x) do
    Params.put_class(x, :success)
  end

  defp failure(x) do
    Params.put_class(x, :failure)
  end

  defp error_attr?(%Attribute.ErrorCode{}), do: true
  defp error_attr?(_), do: false
end
