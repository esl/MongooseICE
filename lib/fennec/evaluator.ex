defmodule Fennec.Evaluator do
  @moduledoc false

  alias Jerboa.Format, as: Parameters

  @spec service(Parameters.t, map) :: Parameters.t | :void
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

  defp class(%Parameters{class: c}) do
    c
  end
end
