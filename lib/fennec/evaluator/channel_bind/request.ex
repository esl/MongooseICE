defmodule Fennec.Evaluator.ChannelBind.Request do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.ErrorCode
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.ChannelNumber
  alias Fennec.UDP
  alias Fennec.TURN
  alias Fennec.TURN.Channel

  import Fennec.Evaluator.Helper, only: [maybe: 3, maybe: 2]

  require Logger

  @lifetime 10 * 60 # 10 minutes

  @spec service(Params.t, Fennec.client_info, UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t}
  def service(params, _, _, turn_state) do
    request_status =
      {:continue, params, %{}}
      |> maybe(&verify_allocation/3, [turn_state])
      |> maybe(&verify_xor_peer_address/2)
      |> maybe(&verify_channel_number/2)
      |> maybe(&verify_channel_binding/3, [turn_state])
      |> maybe(&bind_channel/3, [turn_state])

    case request_status do
      {:error, error_code} ->
        {%{params | attributes: [error_code]}, turn_state}
      {:respond, {new_params, new_turn_state}} ->
        {new_params, new_turn_state}
    end
  end

  @spec verify_allocation(Params.t, context :: map, TURN.t)
    :: {:error, ErrorCode.t} | {:continue, Params.t, map}
  defp verify_allocation(params, context, turn_state) do
    case turn_state do
      %TURN{allocation: %TURN.Allocation{}} ->
        {:continue, params, context}
      _ ->
        {:error, ErrorCode.new(:allocation_mismatch)}
    end
  end

  @spec verify_xor_peer_address(Params.t, context :: map)
    :: {:error, ErrorCode.t} | {:continue, Params.t, map}
  defp verify_xor_peer_address(params, context) do
    with %XPA{} = xor_peer_addr <- Params.get_attr(params, XPA),
         :ipv4                  <- xor_peer_addr.family do
         peer = {xor_peer_addr.address, xor_peer_addr.port}
      {:continue, params, Map.put(context, :peer, peer)}
    else
      _ -> {:error, ErrorCode.new(:bad_request)}
    end
  end

  @spec verify_channel_number(Params.t, context :: map)
    :: {:error, ErrorCode.t} | {:continue, Params.t, map}
  defp verify_channel_number(params, context) do
    with %ChannelNumber{} = cn <- Params.get_attr(params, ChannelNumber),
         true                  <- valid_channel_number?(cn) do
      {:continue, params, Map.put(context, :channel_number, cn.number)}
    else
      _ -> {:error, ErrorCode.new(:bad_request)}
    end
  end

  @spec verify_channel_binding(Params.t, context :: map, TURN.t)
    :: {:error, ErrorCode.t} | {:continue, Params.t, map}
  defp verify_channel_binding(params, context, turn_state) do
    %{peer: peer, channel_number: channel_number} = context
    cond do
      channel_bound?(turn_state, peer, channel_number) ->
        {:continue, params, Map.put(context, :refresh?, true)}
      peer_bound?(turn_state, peer) ->
        {:error, ErrorCode.new(:bad_request)}
      channel_number_bound?(turn_state, channel_number) ->
        {:error, ErrorCode.new(:bad_request)}
      true ->
        {:continue, params, Map.put(context, :refresh?, false)}
    end
  end

  @spec bind_channel(Params.t, context :: map, TURN.t)
    :: {:respond, {Params.t, TURN.t}}
  defp bind_channel(params, context, turn_state) do
    %{peer: peer, channel_number: channel_number, refresh?: refresh?} = context
    {ip, port} = peer
      _ = if refresh? do
        Logger.debug fn ->
          "Refreshing channel ##{channel_number} bound to peer #{ip}:#{port}"
        end
      else
        Logger.debug fn ->
          "Binding channel ##{channel_number} to peer #{ip}:#{port}"
        end
      end
      new_turn_state =
        create_or_update_channel(turn_state, peer, channel_number)
        |> TURN.put_permission(ip)
    {:respond, {Params.set_attrs(params, []), new_turn_state}}
  end

  @spec valid_channel_number?(ChannelNumber.t) :: boolean
  defp valid_channel_number?(%ChannelNumber{number: number}) do
    number in 0x4000..0x7FFF
  end

  @spec channel_bound?(TURN.t, Fennec.address, Jerboa.Format.channel_number)
    :: boolean
  defp channel_bound?(turn_state, peer, channel_number) do
    with {:ok, channel} <- TURN.get_channel(turn_state, peer),
         true           <- channel.number == channel_number do
      true
    else
      _ -> false
    end
  end

  @spec peer_bound?(TURN.t, Fennec.address) :: boolean
  defp peer_bound?(turn_state, peer) do
    case TURN.get_channel(turn_state, peer) do
      {:ok, _} -> true
      _        -> false
    end
  end

  @spec channel_number_bound?(TURN.t, Jerboa.Format.channel_number) :: boolean
  defp channel_number_bound?(turn_state, channel_number) do
    case TURN.get_channel(turn_state, channel_number) do
      {:ok, _} -> true
      _        -> false
    end
  end

  @spec create_or_update_channel(TURN.t, peer :: Fennec.address,
    Format.channel_number) :: TURN.t
  defp create_or_update_channel(turn_state, peer, channel_number) do
    expire_at = Fennec.Time.system_time(:second) + @lifetime
    channel = %Channel{peer: peer, number: channel_number,
                       expiration_time: expire_at}
    TURN.put_channel(turn_state, channel)
  end
end
