defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Fennec.TURN
  alias Fennec.Evaluator

  @spec process_message(binary, Fennec.client_info, TURN.t) ::
    {:ok, {binary, %TURN{}}} | {:ok, :void}
  def process_message(data, client, turn_state) do
    with {:ok, params} <- Jerboa.Format.decode(data),
         {resp, new_turn_state} = Evaluator.service(params, client, turn_state) do
      {:ok, {Jerboa.Format.encode(resp), new_turn_state}}
    else
      :void ->
        {:ok, :void}
    end
  end
end
