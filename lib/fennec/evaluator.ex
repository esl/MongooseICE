defmodule Fennec.Evaluator do
  @moduledoc false

  alias Jerboa.Format, as: Parameters

  @spec service(Parameters.t, map) :: Parameters.t
  def service(p, changes) do
    case class(p) do
      :request ->
        Fennec.Evaluator.Request.service(p, changes)
      _ ->
        :error
    end
  end

  defp class(%Parameters{class: c}) do
    c
  end
end
