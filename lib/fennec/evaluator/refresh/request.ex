defmodule Fennec.Evaluator.Refresh.Request do
  @moduledoc false
  # Implements Refresh request as defined by [RFC 5766 Section 7: Refreshing an Allocation][rfc5766-sec7].
  # [rfc5766-sec7]: https://tools.ietf.org/html/rfc5766#section-7

  import Fennec.Evaluator.Helper, only: [maybe: 3]
  alias Fennec.{TURN, TURN.Allocation}
  alias Jerboa.Format.Body.Attribute.{ErrorCode, Lifetime}
  alias Jerboa.Params

  @spec service(Params.t, Fennec.client_info, Fennec.UDP.server_opts, TURN.t)
    :: {Params.t, TURN.t}
  def service(params, _client, _server, turn_state) do
    status =
      {:continue, params, %{}}
      |> maybe(&allocation_mismatch/3, [turn_state])
      |> maybe(&refresh/3, [turn_state])
    case status do
      {:error, code} ->
        {%{params | attributes: [code]}, turn_state}
      {:respond, {new_params, new_turn_state}} ->
        {new_params, new_turn_state}
    end
  end

  defp allocation_mismatch(_params, _state, %TURN{allocation: nil}) do
    {:error, ErrorCode.new(:allocation_mismatch)}
  end
  defp allocation_mismatch(params, state, %TURN{allocation: _}) do
    {:continue, params, state}
  end

  defp refresh(params, _state, %TURN{allocation: a} = t) do
    case Params.get_attr(params, Lifetime) do
      %Lifetime{duration: 0} ->
        new_a = %Allocation{ a | expire_at: 0 }
        {:respond, {params, %TURN{ t | allocation: new_a }}}
      %Lifetime{duration: d} ->
        refresh_(params, t, d)
      nil ->
        refresh_(params, t, Allocation.default_lifetime())
    end
  end

  defp refresh_(params, %TURN{allocation: a} = t, requested_lifetime) do
    lifetime =
      requested_lifetime
      |> min(Allocation.maximum_lifetime())
      |> max(Allocation.default_lifetime())
    new_params = %Params{ params | attributes: [%Lifetime{duration: lifetime}] }
    now = Fennec.Time.system_time(:seconds)
    new_a = %Allocation{ a | expire_at: now + lifetime }
    {:respond, {new_params, %TURN{ t | allocation: new_a }}}
  end

end
