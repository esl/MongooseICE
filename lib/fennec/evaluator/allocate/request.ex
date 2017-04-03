defmodule Fennec.Evaluator.Allocate.Request do
  @moduledoc false

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Params
  alias Fennec.TURN
  @lifetime 10 * 60

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t}
  def service(params, client, server, turn_state) do
    request_status =
      {:continue, params, %{}}
      |> maybe(&verify_existing_allocation/5, [client, server, turn_state])
      |> maybe(&verify_requested_transport/2)
      |> maybe(&verify_unknown_attributes/2)
      |> maybe(&allocate/5, [client, server, turn_state])

    case request_status do
      {:error, error_code} ->
        {%{params | attributes: [error_code]}, turn_state}
      {:respond, {new_params, new_turn_state}} ->
        {new_params, new_turn_state}
    end
  end

  defp allocation_params(params, %{ip: a, port: p}, server,
                         turn_state = %TURN{allocation: allocation}) do
    %TURN.Allocation{socket: socket, expire_at: expire_at} = allocation
    {:ok, {socket_addr, port}} = :inet.sockname(socket)
    addr = server[:relay_ip] || socket_addr
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
    {%{params | attributes: attrs}, turn_state}
  end

  defp allocate(params, _state, client, server, turn_state) do
    addr = server[:relay_ip]
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true, ip: addr])
    allocation = %Fennec.TURN.Allocation{
      socket: socket,
      expire_at: System.system_time(:second) + @lifetime,
      owner: Params.get_id(params)
    }

    new_turn_state = %{turn_state | allocation: allocation}
    {:respond, allocation_params(params, client, server, new_turn_state)}
  end

  defp verify_existing_allocation(params, state, client, server, turn_state) do
    req_id = Params.get_id(params)
    case turn_state do
      %TURN{allocation: %TURN.Allocation{owner: ^req_id}} ->
        {:respond, allocation_params(params, client, server, turn_state)}
      %TURN{allocation: %TURN.Allocation{}} ->
        {:error, %Attribute.ErrorCode{code: 437}}
      %TURN{allocation: nil} ->
        {:continue, params, state}
    end
  end

  defp verify_requested_transport(params, state) do
    case Params.get_attr(params, Attribute.RequestedTransport) do
      %Attribute.RequestedTransport{protocol: :udp} = t ->
        {:continue, %{params | attributes: params.attributes -- [t]}, state}
      %Attribute.RequestedTransport{} ->
        {:error, %Attribute.ErrorCode{code: 437}}
      _ ->
        {:error, %Attribute.ErrorCode{code: 400}}
      end
  end

  defp verify_unknown_attributes(params, state) do
    with u  <- Params.get_attr(params, Attribute.Username),
         r  <- Params.get_attr(params, Attribute.Realm),
         [] <- Params.get_attrs(params) -- [u, r] do
      {:continue, params, state}
    else
      _ ->
        {:error, %Attribute.ErrorCode{code: 420}}
    end
  end

  defp maybe(result, check), do: maybe(result, check, [])

  defp maybe({:continue, params, state}, check, args) do
    apply(check, [params, state | args])
  end
  defp maybe({:respond, resp}, _check, _args), do: {:respond, resp}
  defp maybe({:error, error_code}, _check, _x), do: {:error, error_code}

  defp family(addr) when tuple_size(addr) == 4, do: :ipv4
  defp family(addr) when tuple_size(addr) == 8, do: :ipv6

end
