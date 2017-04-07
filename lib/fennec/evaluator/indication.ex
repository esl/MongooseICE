defmodule Fennec.Evaluator.Indication do
  @moduledoc false

  alias Jerboa.Params
  alias Fennec.TURN
  alias Fennec.Evaluator

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: :void
  def service(params, client, server, turn_state) do
    case method(params) do
      :binding ->
        ## This call is external to be mockable.
        __MODULE__.void()
      :send ->
        Evaluator.Send.Indication.service(params, client, server, turn_state)
    end
  end

  defp method(params) do
    Params.get_method(params)
  end

  @doc false
  def void, do: :void

end
