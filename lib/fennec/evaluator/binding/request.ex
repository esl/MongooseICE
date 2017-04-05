defmodule Fennec.Evaluator.Binding.Request do
  @moduledoc false

  import Fennec.Evaluator.Helper
  alias Jerboa.Format
  alias Jerboa.Params
  alias Fennec.TURN

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: Params.t
  def service(params, %{ip: a, port: p}, _server, _turn_state) do
    %{params | attributes: [attribute(family(a), a, p)]}
  end

  defp attribute(f, a, p) do
    %Format.Body.Attribute.XORMappedAddress{
      family: f,
      address: a,
      port: p
    }
  end

end
