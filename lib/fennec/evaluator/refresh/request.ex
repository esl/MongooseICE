defmodule Fennec.Evaluator.Refresh.Request do
  @moduledoc """
  Implements Refresh request as defined by [RFC 5766 Section 7: Refreshing an Allocation][rfc5766-sec7].

  [rfc5766-sec7]: https://tools.ietf.org/html/rfc5766#section-7
  """

  alias Fennec.{TURN, TURN.Allocation}
  alias Jerboa.Format.Body.Attribute.Lifetime
  alias Jerboa.Params

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t}
  def service(params, _client, _server, turn_state) do
    ## TODO: match on duration!
    %Lifetime{duration: 0} = Params.get_attr(params, Lifetime)
    case turn_state.allocation do
      nil ->
        {params, turn_state}
      a ->
        new_a = %Allocation{ a | expire_at: 0 }
        {params, %TURN{ turn_state | allocation: new_a }}
    end
  end

end
