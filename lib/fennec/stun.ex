defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Fennec.TURN
  alias Fennec.Evaluator
  alias Fennec.UDP
  alias Fennec.Auth
  alias Jerboa.Params

  @spec process_message(binary, Fennec.client_info, UDP.server_opts, TURN.t) ::
    {:ok, {binary, %TURN{}}} | {:ok, :void}
  def process_message(data, client, server, turn_state) do
    with secret        =  Auth.get_secret(),
         {:ok, params} <- Jerboa.Format.decode(data, [secret: secret]),
         {%Params{} = resp, new_turn_state} <- Evaluator.service(params, client, server, turn_state) do
      {:ok, {Jerboa.Format.encode(resp), new_turn_state}}
    else
      {:void, new_turn_state} ->
        {:ok, {:void, new_turn_state}}
      {:error, reason} ->
        {:error, reason}
    end
  end

end
