defmodule MongooseICE.Evaluator.Helper do
  @moduledoc false
  # This module defines several helper functions commonly used in
  # request/indication implementations

  def maybe(result, check), do: maybe(result, check, [])

  def maybe({:continue, params, state}, check, args) do
    apply(check, [params, state | args])
  end
  def maybe({:respond, resp}, _check, _args), do: {:respond, resp}
  def maybe({:error, error_code}, _check, _x), do: {:error, error_code}

  @spec family(MongooseICE.ip) :: :ipv4 | :ipv6
  def family(addr) when tuple_size(addr) == 4, do: :ipv4
  def family(addr) when tuple_size(addr) == 8, do: :ipv6
end
