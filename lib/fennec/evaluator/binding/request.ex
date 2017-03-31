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

  defp family(addr) when tuple_size(addr) == 4, do: :ipv4
  defp family(addr) when tuple_size(addr) == 8, do: :ipv6
  
end
