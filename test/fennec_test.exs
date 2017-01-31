defmodule FennecTest do
  use ExUnit.Case, async: true

  @moduletag :system

  setup do

    ## Given:
    import Fennec.Test.Helper.Server, only: [configuration: 1]
    {:ok, alice} = Jerboa.Client.start(server: configuration("Google"))
    on_exit fn ->
      :ok = Jerboa.Client.stop(alice)
    end
    {:ok,
     client: alice}
  end

  describe "Fennec over UDP Transport" do

    test "send binding request; recieve success response", %{client: alice} do

      ## When:
      x = Jerboa.Client.bind(alice)

      ## Then:
      assert family(x) == "IPv4"
    end

    test "send binding indication", %{client: alice} do

      ## When:
      x = for _ <- 1..3 do
        Jerboa.Client.persist(alice)
      end

      ## Then:
      assert Enum.all?(x, &ok?/1) == true
    end
  end

  defp family({address, _}) when tuple_size(address) == 4 do
    "IPv4"
  end

  defp ok?(x) do
    x == :ok
  end
end
