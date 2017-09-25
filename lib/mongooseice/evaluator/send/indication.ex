defmodule MongooseICE.Evaluator.Send.Indication do
  @moduledoc false

  require Logger
  import MongooseICE.Evaluator.Helper
  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.ErrorCode
  alias Jerboa.Params
  alias MongooseICE.TURN

  @spec service(Params.t, MongooseICE.client_info, MongooseICE.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t}
  def service(params, _client, _server, turn_state) do
    request_status =
      {:continue, params, %{}}
      |> maybe(&verify_allocation/3, [turn_state])
      |> maybe(&verify_dont_fragment/2, [])
      |> maybe(&verify_xor_peer_address/2, [])
      |> maybe(&verify_data/2, [])
      |> maybe(&verify_permissions/3, [turn_state])
      |> maybe(&send/3, [turn_state])

    case request_status do
      {:error, error_code} ->
        {%Params{params | attributes: [error_code]}, turn_state}
      {:respond, :void} ->
        {%Params{params | attributes: []}, turn_state}
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

  defp verify_dont_fragment(params, state) do
    case Params.get_attr(params, Attribute.DontFragment) do
      %Attribute.DontFragment{} ->
        {:error, ErrorCode.new(:unknown_attribute)} # Currently unsupported
      _ ->
        {:continue, params, state}
      end
  end

  defp verify_xor_peer_address(params, state) do
    # The request MUST have exactly one XORPeerAddress
    case Params.get_attrs(params, Attribute.XORPeerAddress) do
      [%Attribute.XORPeerAddress{}] ->
        {:continue, params, state}
      _ ->
        {:error, ErrorCode.new(:bad_request)}
    end
  end

  defp verify_data(params, state) do
    # The request MUST have exactly one Data attribute
    case Params.get_attrs(params, Attribute.Data) do
      [%Attribute.Data{}] ->
        {:continue, params, state}
      _ ->
        {:error, ErrorCode.new(:bad_request)}
    end
  end

  defp verify_permissions(params, state, turn_state) do
    peer = Params.get_attr(params, Attribute.XORPeerAddress)
    case MongooseICE.TURN.has_permission(turn_state, peer.address) do
      {_, false} ->
        {:error, ErrorCode.new(:forbidden)}
      {_, true} ->
        {:continue, params, state}
    end
  end

  defp send(params, _state, turn_state) do
    sock = turn_state.allocation.socket
    peer = Params.get_attr(params, Attribute.XORPeerAddress)
    data = Params.get_attr(params, Attribute.Data)
    :ok = :gen_udp.send(sock, peer.address, peer.port, data.content)
    {:respond, :void}
  end

end
