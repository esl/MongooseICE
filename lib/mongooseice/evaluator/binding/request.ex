defmodule MongooseICE.Evaluator.Binding.Request do
  @moduledoc false

  import MongooseICE.Evaluator.Helper
  alias Jerboa.Format
  alias Jerboa.Params
  alias MongooseICE.TURN

  @spec service(Params.t, MongooseICE.client_info, MongooseICE.UDP.server_opts, TURN.t)
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
