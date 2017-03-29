defmodule Fennec.Evaluator.Allocate.Request do
  @moduledoc false

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Params
  alias Fennec.TURN
  @lifetime 10 * 60

  @spec service(Params.t, map, %TURN{}) :: Params.t
  def service(x, changes, turn_state) do
    req_id = Params.get_id(x)
    case turn_state do
      %TURN{allocation: %TURN.Allocation{owner: ^req_id}} ->
        {x, turn_state}
      %TURN{allocation: %TURN.Allocation{}} ->
        :error
      %TURN{allocation: nil} ->
        allocate(x, changes, turn_state)
    end
  end

  defp allocate(x, %{address: a, port: p}, turn_state) do
    {:ok, socket} = :gen_udp.open(0, [:binary, :inet, {:active, true}])
    {:ok, {addr, port}} = :inet.sockname(socket)
    allocation = %Fennec.TURN.Allocation{
      socket: socket,
      expire_at: System.system_time(:second) + @lifetime,
      owner: Params.get_id(x)
    }
    new_turn_state = %{turn_state | allocation: allocation}
    attrs = [
      %Attribute.XORMappedAddress{
        family: family(a),
        address: a,
        port: p
      },
      %Attribute.XORRelayedAddress{
        family: family(addr),
        address: addr,
        port: port
      },
      %Attribute.Lifetime{
        duration: @lifetime
      }
    ]

    IO.puts inspect attrs
    {%{x | attributes: attrs}, new_turn_state}
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
