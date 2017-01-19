defmodule Fennec.Mixfile do
  use Mix.Project

  def project do
    [app: :fennec,
     version: "0.1.0",
     description: "STUN/TURN server",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Fennec.Application, []}]
  end

  defp deps do
    []
  end
end
