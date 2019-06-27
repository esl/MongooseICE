defmodule Helper.Macros do
  defmacro __using__(_opts) do
    quote do
      @eventually_timeout 5_000
      import unquote(__MODULE__)
      import Mock
    end
  end

  defmacro no_auth(do_something) do
    quote do
      with_mock MongooseICE.Auth, [:passthrough], [
        maybe: fn(_, p, _, _) -> {:ok, p} end
      ] do
       unquote do_something
      end
    end
  end

  defmacro eventually(truly) do
    quote do
      Helper.Macros.wait_for(fn -> unquote truly end, @eventually_timeout)
    end
  end

  # This macro sends the binary request and return binary response.
  # The response will be returned for both :request and :indication but
  # using different methods. For :request, normal UDP communication is used,
  # while for :indication, this macro uses Mock history to get final response params
  # since those are dropped just before sending via UDP due to nature of :indications
  defmacro communicate_all(udp, client_id, req) do
    alias Helper.UDP
    alias Jerboa.Params
    quote do
      # First, we need to mock MongooseICE.Evaluator.on_result to gather results
      with_mock MongooseICE.Evaluator, [:passthrough], [] do
        # Then we send the request
        :ok = UDP.send(unquote(udp), unquote(client_id), unquote(req))
        case Params.get_class(Jerboa.Format.decode!(unquote(req))) do
          :request ->     unquote(receive_request_response(udp, client_id))
          :indication ->  unquote(receive_indication_response())
        end
      end
    end
  end

  defp receive_request_response(udp, client_id) do
    # In case of the request, get response via UDP
    quote do
      Helper.UDP.recv(unquote(udp), unquote(client_id))
    end
  end

  defp receive_indication_response() do
    # For indication we need to get result from MongooseICE.Evaluator.on_result
    # call history
    quote do
      assert eventually called MongooseICE.Evaluator.on_result(:indication, :_)
      history = :meck.history(MongooseICE.Evaluator)
      history = # Filter only calls to on_result/2
        Enum.filter(history, fn(entry) ->
          case entry do
            {_caller, {_mod, :on_result, _args}, _ret} -> true
            _ -> false
          end
        end)
      # Get last call
      {_caller, {_mod, _fun, [_calss, params]}, _ret} = List.last(history)
      Jerboa.Format.encode(params)
    end
  end

  def wait_for(fun, timeout) when timeout > 0 do
    timestep = 100
    case fun.() do
      true -> true
      false ->
        Process.sleep(timestep)
        wait_for(fun, timeout - timestep)
    end
  end
  def wait_for(fun, _timeout), do: fun.()

end
