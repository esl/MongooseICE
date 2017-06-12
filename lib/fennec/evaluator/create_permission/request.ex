defmodule Fennec.Evaluator.CreatePermission.Request do
  @moduledoc false

  import Fennec.Evaluator.Helper
  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.ErrorCode
  alias Jerboa.Params
  alias Fennec.TURN

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t}
  def service(params, _client, _server, turn_state) do
    request_status =
      {:continue, params, %{}}
      |> maybe(&verify_allocation/3, [turn_state])
      |> maybe(&verify_xor_peer_address/2, [])
      |> maybe(&create_permissions/3, [turn_state])

    case request_status do
      {:error, error_code} ->
        {%{params | attributes: [error_code]}, turn_state}
      {:respond, {new_params, new_turn_state}} ->
        {new_params, new_turn_state}
    end
  end

  defp verify_allocation(params, state, turn_state) do
    case turn_state do
      %TURN{allocation: %TURN.Allocation{}} ->
        {:continue, params, state}
      _ ->
        {:error, ErrorCode.new(:allocation_mismatch)}
    end
  end

  defp verify_xor_peer_address(params, state) do
    # The request MUST have at least one XORPeerAddress
    case Params.get_attr(params, Attribute.XORPeerAddress) do
      %Attribute.XORPeerAddress{} ->
        {:continue, params, state}
      _ ->
        {:error, ErrorCode.new(:bad_request)}
    end
  end

  defp create_permissions(params, _state, turn_state) do
    peers = Params.get_attrs(params, Attribute.XORPeerAddress)
    new_turn_state =
      peers
      |> Enum.map(& Map.fetch!(&1, :address))
      |> Enum.reduce(turn_state, & TURN.put_permission(&2, &1))
    new_params = %Params{params | attributes: []}
    {:respond, {new_params, new_turn_state}}
  end

end
