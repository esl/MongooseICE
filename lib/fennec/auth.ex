defmodule Fennec.Auth do
  @moduledoc false
  # This module implements authentication and authorization of
  # the STUN and TURN protocol.

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.{Username, Nonce, Realm}
  alias Jerboa.Params
  alias Fennec.TURN

  @nonce_bytes 48
  @nonce_lifetime_seconds 60 * 60 # 1h
  @authorized_methods [:allocate, :refresh, :create_permission, :channel_bind]

  def get_secret do
    Confex.get(:fennec, :secret)
  end

  def nonce_lifetime() do
    @nonce_lifetime_seconds
  end

  def gen_nonce do
    @nonce_bytes
    |> :crypto.strong_rand_bytes()
    |> :binary.decode_unsigned()
    |> Integer.to_string(16)
  end

  def authorize(params, server, turn_state) do
    # All authorized requests must have matching username with one that
    # created an allocation, if any
    %Username{value: username} = Params.get_attr(params, Username)
    case turn_state do
      %TURN{allocation: %TURN.Allocation{owner_username: ^username}} ->
        {:ok, params}
      %TURN{allocation: nil} ->
        {:ok, params}
      _ ->
        {:error, error_params(:wrong_credentials, params, server, turn_state)}
    end
  end

  def authenticate(params, server, turn_state) do
    nonce = turn_state.nonce
    signed? = params.signed?

    with %Username{}                <- Params.get_attr(params, Username),
         %Realm{}                   <- Params.get_attr(params, Realm),
         n = %Nonce{value: ^nonce}  <- Params.get_attr(params, Nonce),
         true                       <- params.verified? do
      {:ok, %Params{params | attributes: params.attributes -- [n]}}
    else
      false -> # Not verified -> error code 401
        {:error, error_params(:unauthorized, params, server, turn_state)}
      %Nonce{} -> # Invalid nonce, error code 438
        {:error, error_params(:stale_nonce, params, server, turn_state)}
      nil when not signed? ->
        {:error, error_params(:unauthorized, params, server, turn_state)}
      _ when signed? -> # If message is signed and there are some attributes
                        # missing, we need to respond with error code 400
        {:error, error_params(:bad_request, params, server, turn_state)}
    end
  end

  def maybe(action_fun, params, server, turn_state) do
    case should_authorize?(params) do
      true ->
        action_fun.(params, server, turn_state)
      false ->
        {:ok, params}
    end
  end

  defp should_authorize?(params) do
    should_authorize?(Params.get_class(params), Params.get_method(params))
  end

  defp should_authorize?(:request, method)
       when method in @authorized_methods, do: true
  defp should_authorize?(_, _), do: false

  defp error_params(code_or_name, params, server, turn_state) do
    %Params{params | attributes: [
      Attribute.ErrorCode.new(code_or_name),
      %Attribute.Realm{value: server[:realm]},
      %Attribute.Nonce{value: turn_state.nonce}
    ]}
  end
end
