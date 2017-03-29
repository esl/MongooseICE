defmodule Fennec.Evaluator.Request do
  @moduledoc false

  alias Jerboa.Params
  alias Fennec.TURN

  @spec service(Params.t, map, %TURN{}) :: Params.t
  def service(params, changes, turn_state) do
    case service_(params, changes, turn_state) do
      {new_params, new_turn_state} ->
        IO.puts inspect new_turn_state 
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

  defp errors?(%Params{attributes: _}), do: false
  defp errors?(:error), do: true


  defp success(x) do
    Params.put_class(x, :success)
  end

  defp failure(x) do
    Params.put_class(x, :failure)
  end
end
