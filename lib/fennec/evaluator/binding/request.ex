defmodule Fennec.Evaluator.Binding.Request do
  @moduledoc false

  alias Jerboa.Format

  @spec service(Params.t, map, %Fennec.TURN{}) :: Params.t
  def service(x, %{address: a, port: p}, _turn_state) do
    %{x | attributes: [attribute(family(a), a, p)]}
  end

  defp attribute(f, a, p) do
    %Format.Body.Attribute.XORMappedAddress{
      family: f,
      address: a,
      port: p
    }
  end

  defp family(x) do
    case tuple_size(x) do
      4 ->
        :ipv4
      8 ->
        :ipv6
    end
  end
end
