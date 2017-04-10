defmodule Fennec.Evaluator do
  @moduledoc false

  require Logger

  alias Jerboa.Params
  alias Fennec.TURN
  alias Fennec.Auth
  alias Jerboa.Format.Body.Attribute

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t} | :void
  def service(params, client, server, turn_state) do
    case service_(params, client, server, turn_state) do
      {new_params, new_turn_state} ->
        {response(new_params), new_turn_state}
      new_params ->
        {response(new_params), turn_state}
    end
  end

  defp service_(params, client, server, turn_state) do
    with {:ok, params} <- Auth.maybe(&Auth.authenticate/3, params, server, turn_state),
         {:ok, params} <- Auth.maybe(&Auth.authorize/3, params, server, turn_state) do
      handler(class(params)).service(params, client, server, turn_state)
    else
      {:error, error_params} ->
        {error_params, turn_state}
    end
  end

  defp on_error(:request, result) do
    Logger.debug ~s"Request #{Params.get_method(result)} failed..."
  end
  defp on_error(:success, result) do
    Logger.debug ~s"Indication #{Params.get_method(result)} dropped..."
  end

  defp class(params) do
    Params.get_class(params)
  end

  defp response(result) do
    case errors?(result) do
      false ->
        success(class(result), result)
      true ->
        on_error(class(result), result)
        failure(class(result), result)
    end
  end

  defp errors?(%Params{attributes: attrs}) do
     attrs
     |> Enum.any?(&error_attr?/1)
  end

  defp success(:request, params), do: Params.put_class(params, :success)
  defp success(:indication, _params), do: :void

  defp failure(:request, params), do: Params.put_class(params, :failure)
  defp failure(:success, _params), do: :void

  defp error_attr?(%Attribute.ErrorCode{}), do: true
  defp error_attr?(_), do: false

  defp handler(:request), do: Fennec.Evaluator.Request
  defp handler(:indication), do: Fennec.Evaluator.Indication

end
