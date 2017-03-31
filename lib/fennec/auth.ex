defmodule Fennec.Auth do
  @moduledoc false
  # This module implements authentication and authorization of
  # the STUN and TURN protocol.

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.{Username, Nonce, Realm}
  alias Jerboa.Params

  @nonce_bytes 48
  @nonce_lifetime_seconds 60 * 60 # 1h

  def get_secret do
    Application.get_env(:fennec, :secret)
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

  def authorize(params, _turn_state) do
    # Right now, any authenticated user will do
    {:ok, params}
  end

  def authenticate(params, turn_state) do
    nonce = turn_state.nonce
    signed? = params.signed?

    with %Username{}                <- Params.get_attr(params, Username),
         %Realm{}                   <- Params.get_attr(params, Realm),
         n = %Nonce{value: ^nonce}  <- Params.get_attr(params, Nonce),
         true                       <- params.verified? do
      {:ok, %Params{params | attributes: params.attributes -- [n]}}
    else
      false -> # Not verified -> error code 401
        {:error, error_params(401, params, turn_state)}
      _ when signed? -> # If message is signed and there are some attributes
                        # missing, we need to respond with error code 400
        {:error, error_params(400, params, turn_state)}
      %Nonce{} -> # Invalid nonce, error code 438
        {:error, error_params(438, params, turn_state)}
      nil when not signed? ->
        {:error, error_params(401, params, turn_state)}
    end
  end

  def maybe(action_fun, params, turn_state) do
    case should_authorize?(params) do
      true ->
        action_fun.(params, turn_state)
      false ->
        {:ok, params}
    end
  end

  defp should_authorize?(params) do
    should_authorize?(Params.get_class(params), Params.get_method(params))
  end
  defp should_authorize?(:request, :allocate), do: true
  defp should_authorize?(_, _), do: false

  defp error_params(code, params, turn_state) do
    %Params{params | attributes: [
      %Attribute.ErrorCode{code: code},
      %Attribute.Realm{value: turn_state.realm},
      %Attribute.Nonce{value: turn_state.nonce}
    ]}
  end
end
