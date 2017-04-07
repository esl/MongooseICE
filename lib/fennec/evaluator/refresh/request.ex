defmodule Fennec.Evaluator.Refresh.Request do
  @moduledoc """
  Implements Refresh request as defined by [RFC 5766 Section 7: Refreshing an Allocation][rfc5766-sec7].

  [rfc5766-sec7]: https://tools.ietf.org/html/rfc5766#section-7
  """

  #alias Jerboa.Format.Attribute
  #alias Jerboa.Params
  #alias Fennec.TURN

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t}
  def service(params, _client, _server, turn_state) do
    {params, turn_state}
  end

end
