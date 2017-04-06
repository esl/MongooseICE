defmodule Fennec.Helper do
  @moduledoc """
  Helper module that defines some commonly used functions in order to make
  code cleaner and testing easier.
  """

  import Kernel, except: [to_string: 1]
  defimpl String.Chars, for: Tuple do
    def to_string({a, b, c, d} = addr) when
      is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) do
      Fennec.Helper.inet_to_string(addr)
    end

    def to_string({a, b, c, d, e, f, g, h} = addr) when
      is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d)
      and is_integer(e) and is_integer(f) and is_integer(g) and is_integer(h) do
      Fennec.Helper.inet_to_string(addr)
    end
  end

  @spec inet_to_string(Fennec.ip) :: String.t
  def inet_to_string(addr) do
    Kernel.to_string(:inet.ntoa(addr))
  end
end
