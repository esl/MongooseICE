defmodule Fennec.Evaluator do
  @moduledoc false

  alias Jerboa.Params

  @spec service(Params.t, map) :: Params.t | :void
  def service(p, changes) do
    case class(p) do
      :request ->
        Fennec.Evaluator.Request.service(p, changes)
      :indication ->
        Fennec.Evaluator.Indication.service(p, changes)
      _ ->
        :error
    end
  end

  defp class(x) do
    Params.get_class(x)
  end
end
