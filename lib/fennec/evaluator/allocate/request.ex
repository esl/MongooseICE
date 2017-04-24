defmodule Fennec.Evaluator.Allocate.Request do
  @moduledoc false

  import Fennec.Evaluator.Helper, only: [
    family: 1,
    maybe: 2, maybe: 3
  ]

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.ErrorCode
  alias Jerboa.Params
  alias Fennec.TURN

  require Integer

  @create_relays_max_retries 100

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t}
  def service(params, client, server, turn_state) do
    request_status =
      {:continue, params, %{}}
      |> maybe(&verify_existing_allocation/5, [client, server, turn_state])
      |> maybe(&verify_requested_transport/2)
      |> maybe(&verify_dont_fragment/2)
      |> maybe(&verify_reservation_token/2)
      |> maybe(&verify_even_port/2)
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
    lifetime = max(0, expire_at - Fennec.Time.system_time(:second))
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

  defp allocate(params, state, client, server, turn_state) do
    {:ok, socket} = create_relays(params, state, server)
    allocation = %Fennec.TURN.Allocation{
      socket: socket,
      expire_at: Fennec.Time.system_time(:second) + TURN.Allocation.default_lifetime(),
      req_id: Params.get_id(params),
      owner_username: owner_username(params)
    }

    new_turn_state = %{turn_state | allocation: allocation}
    {:respond, allocation_params(params, client, server, new_turn_state)}
  end

  defp create_relays(params, state, server) do
    status =
      {:continue, params, create_relay_state(state)}
      |> maybe(&open_this_relay/3, [server])
      |> maybe(&reserve_another_relay/3, [server])
    case status do
      _ -> :erlang.error(:"not implemented yet")
    end
  end

  defp create_relay_state(allocate_state) do
    Map.merge(%{this_socket: nil,
                this_port: nil,
                retries: @create_relays_max_retries},
              allocate_state)
  end

  defp open_this_relay(_params, %{retries: r}, _server)
    when r < 0, do: {:error, :even_port_max_retries}
  defp open_this_relay( params, state, server) do
    case {Params.get_attr(params, Attribute.EvenPort),
          :gen_udp.open(0, udp_opts(server))} do
      {nil, {:ok, socket}} ->
        {:continue, params, %{state | this_socket: socket}}
      {%Attribute.EvenPort{}, {:ok, socket}} ->
        {:ok, {_, port}} = :inet.sockname(socket)
        if Integer.is_even(port) do
          {:continue, params,
            %{state | this_socket: socket, this_port: port}}
        else
          :gen_udp.close(socket)
          new_state = %{state | retries: state.retries - 1}
          open_this_relay(params, new_state, server)
        end
      {_, {:error, reason}} ->
        {:error, reason}
    end
  end

  defp reserve_another_relay(params, state, server) do
    case Params.get_attr(params, Attribute.EvenPort) do
      nil                                   -> {:continue, params, state}
      %Attribute.EvenPort{reserved?: false} -> {:continue, params, state}
      %Attribute.EvenPort{reserved?: true}  ->
        port = state.this_port + 1
        case :gen_udp.open(port, udp_opts(server)) do
          {:error, :eaddrinuse} ->
            :gen_udp.close(state.this_socket)
            create_relays(params, %{retries: state.retries - 1}, server)
            {:error, _} = e -> e
          {:ok, socket} ->
            reservation = Reservation.new(socket)
            ## TODO: finish!
            #Dispatcher.start_worker
            :erlang.error(:"not implemented yet")
        end
    end
  end

  defp udp_opts(server) do
    ## TODO: {:active, true} is not an option for a production system!
    [:binary, active: true, ip: server[:relay_ip]]
  end

  defp verify_existing_allocation(params, state, client, server, turn_state) do
    req_id = Params.get_id(params)
    case turn_state do
      %TURN{allocation: %TURN.Allocation{req_id: ^req_id}} ->
        {:respond, allocation_params(params, client, server, turn_state)}
      %TURN{allocation: %TURN.Allocation{}} ->
        {:error, ErrorCode.new(:allocation_mismatch)}
      %TURN{allocation: nil} ->
        {:continue, params, state}
    end
  end

  defp verify_requested_transport(params, state) do
    case Params.get_attr(params, Attribute.RequestedTransport) do
      %Attribute.RequestedTransport{protocol: :udp} = t ->
        {:continue, %{params | attributes: params.attributes -- [t]}, state}
      %Attribute.RequestedTransport{} ->
        {:error, ErrorCode.new(:allocation_mismatch)}
      _ ->
        {:error, ErrorCode.new(:bad_request)}
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

  defp verify_reservation_token(params, state) do
    even_port = Params.get_attr(params, Attribute.EvenPort)
    case Params.get_attr(params, Attribute.ReservationToken) do
      %Attribute.ReservationToken{} when even_port != nil ->
        {:error, ErrorCode.new(:bad_request)}
      %Attribute.ReservationToken{} ->
        {:error, ErrorCode.new(:unknown_attribute)} # Currently unsupported
      _ ->
        {:continue, params, state}
      end
  end

  defp verify_even_port(params, state) do
    reservation_token = Params.get_attr(params, Attribute.ReservationToken)
    case Params.get_attr(params, Attribute.EvenPort) do
      %Attribute.EvenPort{} when reservation_token != nil ->
        {:error, ErrorCode.new(:bad_request)}
      _ ->
        {:continue, params, state}
    end
  end

  defp owner_username(params) do
    case Params.get_attr(params, Attribute.Username) do
      %Attribute.Username{value: owner_username} ->
        owner_username
      _ ->
        nil
    end
  end

  @spec dispatcher(Fennec.UDP.server_opts) :: atom
  defp dispatcher(server) do
    server[:port]
    |> Fennec.UDP.base_name()
    |> Fennec.UDP.dispatcher_name()
  end

end
