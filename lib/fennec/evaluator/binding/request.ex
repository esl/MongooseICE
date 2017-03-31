defmodule Fennec.Evaluator.Binding.Request do
  @moduledoc false

  alias Jerboa.Format
  alias Fennec.TURN

  @spec service(Params.t, map, TURN.t) :: Params.t
  def service(params, %{address: a, port: p}, _turn_state) do
    %{params | attributes: [attribute(family(a), a, p)]}
  end

  defp attribute(f, a, p) do
    %Format.Body.Attribute.XORMappedAddress{
      family: f,
      address: a,
      port: p
    }
  end

  defp family(params) do
    case tuple_size(params) do
      4 ->
        :ipv4
      8 ->
        :ipv6
    end
  end
end
