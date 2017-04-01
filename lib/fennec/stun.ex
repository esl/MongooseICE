defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Fennec.TURN
  alias Jerboa.Params
  alias Fennec.Evaluator
  alias Fennec.UDP
  alias Fennec.Auth

  @spec process_message(binary, Fennec.client_info, UDP.server_opts, TURN.t) ::
    {:ok, {binary, %TURN{}}} | {:ok, :void}
  def process_message(data, client, server, turn_state) do
    with secret        <- Auth.get_secret(),
         {:ok, params} <- Jerboa.Format.decode(data, [secret: secret]),
         {:ok, params} <- Auth.maybe(&Auth.authenticate/3, params, server, turn_state),
         {:ok, params} <- Auth.maybe(&Auth.authorize/3, params, server, turn_state),
         {resp, new_turn_state} <- Evaluator.service(params, client, server, turn_state) do
      {:ok, {Jerboa.Format.encode(resp), new_turn_state}}
    else
      :void ->
        {:ok, :void}
      {:error, %Params{} = error_msg} ->
        error_msg = Params.put_class(error_msg, :failure)
        {:ok, {Jerboa.Format.encode(error_msg), turn_state}}
      {:error, reason} ->
        {:error, reason}
    end
  end

end
