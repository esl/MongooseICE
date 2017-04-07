defmodule Helper.Macros do
  defmacro __using__(_opts) do
    quote do
      @eventually_timeout 5_000
      defmacro eventually(truly) do
        quote do
          Helper.Macros.wait_for(fn -> unquote truly end, @eventually_timeout)
        end
      end
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
