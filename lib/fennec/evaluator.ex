defmodule Fennec.Evaluator do
  @moduledoc false

  require Logger

  alias Jerboa.Params
  alias Fennec.TURN
  alias Fennec.Auth
  alias Jerboa.Format.Body.Attribute

  @doc """
  This function implements the second phase of the message processing. Here,
  message gets authenticated, authorized and passed to specific request handler.
  The response from the specific request handler gets normalized before
  leaving this function (i.e. gets :success or :failure class or is
  changed to :void if this is an response to :indication message).
  """
  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t} | {:void, TURN.t}
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

  # This function is run every time the params are returned from processing.
  # The Params have already set message class to either :failure or :success.
  # Return value of this function will be the message that will be send back to the client.
  @spec on_result(:request | :indication, Params.t) :: Params.t | :void
  def on_result(:request, result) do
    if Params.get_class(result) == :failure do
      e = error(result)
      Logger.debug ~s"Request #{Params.get_method(result)} failed due " <>
                   ~s"to error #{e.name} (#{e.code})..."
    end

    result
  end
  def on_result(:indication, result) do
    if Params.get_class(result) == :failure do
      e = error(result)
      Logger.debug ~s"Indication #{Params.get_method(result)} dropped due " <>
                   ~s"to error #{e.name} (#{e.code})..."
    end

    :void
  end

  defp class(params) do
    Params.get_class(params)
  end

  # Puts :success or :failure message class and runs `on_result/2` hook
  defp response(:void), do: :void
  defp response(params) do
    result =
      case errors?(params) do
        false ->
          success(params)
        true ->
          failure(params)
      end
    __MODULE__.on_result(class(params), result)
  end


  defp errors?(params) do
     error(params) != nil
  end

  defp error(params), do: Params.get_attr(params, Attribute.ErrorCode)

  defp success(params), do: Params.put_class(params, :success)

  defp failure(params), do: Params.put_class(params, :failure)

  defp handler(:request), do: Fennec.Evaluator.Request
  defp handler(:indication), do: Fennec.Evaluator.Indication

end
