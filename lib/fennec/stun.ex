defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Fennec.TURN

  @spec process_message(binary, Fennec.ip, Fennec.portn, TURN.t) ::
    {:ok, {binary, %TURN{}}} | {:error, term}
  def process_message(data, ip, port, turn_state) do
    case Jerboa.Format.decode(data) do
      {:ok, params} ->
        case Fennec.Evaluator.service(params, %{address: ip, port: port}, turn_state) do
          :void ->
            {:ok, :void}
          {resp, new_turn_state} when is_map(resp) ->
            {:ok, {Jerboa.Format.encode(resp), new_turn_state}}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end
end
