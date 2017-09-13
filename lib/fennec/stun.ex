defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Fennec.TURN
  alias Fennec.Evaluator
  alias Fennec.UDP
  alias Fennec.Auth
  alias Jerboa.Params
  alias Jerboa.ChannelData

  @doc """
  This function implements phase 1 of message processing which is encoding/decoding.
  The decoded message is evaluated by `Fennec.Evaluator` and the return value
  of the `Fennec.Evaluator.service/4` is then encoded and returned from this function.
  """
  @spec process_message(binary, Fennec.client_info, UDP.server_opts, TURN.t) ::
    {:ok, {binary, TURN.t}} | {:ok, {:void, TURN.t}} | {:error, reason :: term}
  def process_message(data, client, server, turn_state) do
    with secret        =  Auth.get_secret(),
         {:ok, %Params{} = params} <- Jerboa.Format.decode(data, [secret: secret]),
         {%Params{} = resp, new_turn_state} <- Evaluator.service(params, client, server, turn_state) do
      {:ok, {Jerboa.Format.encode(resp), new_turn_state}}
    else
      {:ok, %ChannelData{} = channel_data} ->
        process_channel_data(channel_data, turn_state)
      {:void, new_turn_state} ->
        {:ok, {:void, new_turn_state}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec process_channel_data(ChannelData.t, TURN.t) :: {:ok, {:void, TURN.t}}
  defp process_channel_data(channel_data, turn_state) do
    new_turn_state = Evaluator.ChannelData.service(channel_data, turn_state)
    {:ok, {:void, new_turn_state}}
  end

end
