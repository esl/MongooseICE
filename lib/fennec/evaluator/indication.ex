defmodule Fennec.Evaluator.Indication do
  @moduledoc false

  alias Jerboa.Params
  alias Fennec.TURN

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: Params.t | :void
  def service(parameters, _, _server, _turn_state) do
    case method(parameters) do
      :binding ->
        ## This call is external to be mockable.
        __MODULE__.void()
    end
  end

  defp method(params) do
    Params.get_method(params)
  end

  @doc false
  def void, do: :void

end
