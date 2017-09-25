defmodule MongooseICE.Evaluator.ChannelData do
  @moduledoc false

  alias MongooseICE.TURN
  alias MongooseICE.TURN.Channel
  alias Jerboa.ChannelData

  require Logger

  @spec service(ChannelData.t, TURN.t) :: TURN.t
  def service(channel_data, turn_state) do
    case TURN.has_channel(turn_state, channel_data.channel_number) do
      {:ok, turn_state, channel} ->
        send(turn_state, channel, channel_data)
        turn_state
      {:error, turn_state} ->
        Logger.debug fn ->
          "Dropping data sent over channel ##{channel_data.channel_number}. " <>
            "Channel may not exist or there is no permission for the bound peer"
        end
        turn_state
    end
  end

  @spec send(TURN.t, Channel.t, ChannelData.t) :: :ok
  defp send(turn_state, channel, channel_data) do
    sock = turn_state.allocation.socket
    {peer_ip, peer_port} = channel.peer
    data = channel_data.data
    :ok = :gen_udp.send(sock, peer_ip, peer_port, data)
  end

end
