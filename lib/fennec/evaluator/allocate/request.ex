defmodule Fennec.Evaluator.Allocate.Request do
  @moduledoc false

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Params
  alias Fennec.TURN
  @lifetime 10 * 60

  @spec service(Params.t, map, TURN.t) :: {Params.t, TURN.t}
  def service(x, changes, turn_state) do
    request_status =
      {:valid, x, %{}}
      |> maybe(&verify_existing_allocation/4, [changes, turn_state])
      |> maybe(&verify_requested_transport/2)
      |> maybe(&verify_unknown_attributes/2)

    case request_status do
      {:error, error_code} ->
        {%{x | attributes: [error_code]}, turn_state}
      {:ok, {new_params, new_turn_state}} ->
        {new_params, new_turn_state}
      {:valid, _, state} ->
        allocate(x, state, changes, turn_state)
    end
  end

  defp allocate(x, _state, changes, turn_state) do
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

  defp verify_existing_allocation(x, state, changes, turn_state) do
    req_id = Params.get_id(x)
    case turn_state do
      %TURN{allocation: %TURN.Allocation{owner: ^req_id}} ->
        {:ok, allocation_params(x, changes, turn_state)}
      %TURN{allocation: %TURN.Allocation{}} ->
        {:error, %Attribute.ErrorCode{code: 437}}
      %TURN{allocation: nil} ->
        {:valid, x, state}
    end
  end

  defp verify_requested_transport(x, state) do
    case Params.get_attr(x, Attribute.RequestedTransport) do
      %Attribute.RequestedTransport{protocol: :udp} = t ->
        {:valid, %{x | attributes: x.attributes -- [t]}, state}
      %Attribute.RequestedTransport{} ->
        {:error, %Attribute.ErrorCode{code: 437}}
      _ ->
        {:error, %Attribute.ErrorCode{code: 400}}
      end
  end

  defp verify_unknown_attributes(x, state) do
    case Params.get_attrs(x) do
      [] ->
        {:valid, x, state}
      _ ->
        {:error, %Attribute.ErrorCode{code: 420}}
      end
  end

  defp maybe(result, check), do: maybe(result, check, [])

  defp maybe({:valid, x, state}, check, args) do
    apply(check, [x, state | args])
  end
  defp maybe({:ok, resp}, _check, _args), do: {:ok, resp}
  defp maybe({:error, error_code}, _check, _x), do: {:error, error_code}

  defp family(x) do
    case tuple_size(x) do
      4 ->
        :ipv4
      8 ->
        :ipv6
    end
  end
end
