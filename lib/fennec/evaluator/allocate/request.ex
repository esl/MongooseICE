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
        allocation_params(x, changes, turn_state)
      %TURN{allocation: %TURN.Allocation{}} ->
        error_code = %Attribute.ErrorCode{code: 437}
        {%{x | attributes: [error_code]}, turn_state}
      %TURN{allocation: nil} ->
        allocate(x, changes, turn_state)
    end
  end

  defp allocate(x, changes, turn_state) do
    addr = Application.get_env(:fennec, :relay_addr, {127, 0, 0, 1})
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true, ip: addr])
    allocation = %Fennec.TURN.Allocation{
      socket: socket,
      expire_at: System.system_time(:second) + @lifetime,
      owner: Params.get_id(x)
    }
    new_turn_state = %{turn_state | allocation: allocation}
    allocation_params(x, changes, new_turn_state)
  end

  defp allocation_params(x, %{address: a, port: p},
                         turn_state = %TURN{allocation: allocation}) do
    addr = Application.get_env(:fennec, :relay_addr, {127, 0, 0, 1})
    %TURN.Allocation{socket: socket, expire_at: expire_at} = allocation
    {:ok, port} = :inet.port(socket)
    lifetime = max(0, expire_at - System.system_time(:second))
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
        duration: lifetime
      }
    ]
    {%{x | attributes: attrs}, turn_state}
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
