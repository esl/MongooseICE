defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Fennec.TURN
  alias Fennec.Evaluator
  alias Fennec.UDP
  alias Fennec.Auth
  alias Jerboa.Params

  @doc """
  This function implements phase 1 of message processing which is encoding/decoding.
  The decoded message is evaluated by `Fennec.Evaluator` and the return value
  of the `Fennec.Evaluator.service/4` is then encoded and returned from this function.
  """
  @spec process_message(binary, Fennec.client_info, UDP.server_opts, TURN.t) ::
    {:ok, {binary, %TURN{}}} | {:ok, :void} | {:error, reason :: term}
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
