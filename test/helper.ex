defmodule Fennec.Test.Helper do
  @moduledoc false

  defmodule Server do
    @moduledoc false

    def configuration(name) when is_binary(name) do
      Enum.find(configuration(), select(name))
    end

    defp configuration do
      Keyword.fetch!(environment(), :server)
    end

    defp select(name) do
      fn %{name: ^name} ->
        true
        %{name: _} ->
          false
      end
    end

    defp environment do
      Application.fetch_env!(:jerboa, :test)
    end
  end
end
