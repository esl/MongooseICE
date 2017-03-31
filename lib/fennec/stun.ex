defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Fennec.TURN
  alias Fennec.Evaluator

  @spec process_message(binary, Fennec.ip, Fennec.portn, TURN.t) ::
    {:ok, {binary, %TURN{}}} | {:error, term}
  def process_message(data, ip, port, turn_state) do
    changes = %{address: ip, port: port}
    with {:ok, params} <- Jerboa.Format.decode(data),
         {resp, new_turn_state} = Evaluator.service(params, changes, turn_state) do
      {:ok, {Jerboa.Format.encode(resp), new_turn_state}}
    else
      :void ->
        {:ok, :void}
    end
  end
end
