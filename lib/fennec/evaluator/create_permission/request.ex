defmodule Fennec.Evaluator.CreatePermission.Request do
  @moduledoc false

  import Fennec.Evaluator.Helper
  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Params
  alias Fennec.TURN

  @lifetime 5 * 60 # MUST be 5mins

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
        {:error, %Attribute.ErrorCode{code: 437}}
    end
  end

  defp verify_xor_peer_address(params, state) do
    # The request MUST have at least one XORPeerAddress
    case Params.get_attr(params, Attribute.XORPeerAddress) do
      %Attribute.XORPeerAddress{} ->
        {:continue, params, state}
      _ ->
        {:error, %Attribute.ErrorCode{code: 400}}
    end
  end

  defp create_permissions(params, _state, turn_state) do
    expire_at = Fennec.Time.system_time(:second) + @lifetime
    peers = Params.get_attrs(params, Attribute.XORPeerAddress)
    added_pemissions =
      for peer = %Attribute.XORPeerAddress{} <- peers do
        {peer.address, expire_at}
      end

    new_permissions =
      added_pemissions
      |> Enum.into(turn_state.permissions)

    # Construct new protocol state and response for the client
    new_turn_state = %TURN{turn_state | permissions: new_permissions}
    new_params = %Params{params | attributes: []}
    {:respond, {new_params, new_turn_state}}
  end

end
