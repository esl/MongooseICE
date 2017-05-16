defmodule Fennec.Mixfile do
  use Mix.Project

  def project do
    [app: :fennec,
     version: "0.2.0",
     name: "Fennec",
     description: "STUN/TURN server",
     source_url: "https://github.com/esl/fennec",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package(),
     docs: docs(),
     dialyzer: dialyzer(),
     test_coverage: test_coverage(),
     preferred_cli_env: preferred_cli_env()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Fennec.Application, []}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/helper.ex"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:ex_doc, "~> 0.14", runtime: false, only: :dev},
     {:credo, "~> 0.5", runtime: false, only: :dev},
     {:dialyxir, "~> 0.4", runtime: false, only: :dev},
     {:excoveralls, "~> 0.5", runtime: false, only: :test},
     {:inch_ex, "~> 0.5", runtime: false, only: :dev},
     {:mock, "~> 0.2.0", only: :test},
     {:jerboa, github: "esl/jerboa"}]
  end

  defp package do
    [licenses: ["Apache 2.0"],
     maintainers: ["Erlang Solutions"],
     links: %{"GitHub" => "https://github.com/esl/fennec"}]
  end

  defp docs do
    [main: "Fennec",
     extras: ["README.md": [title: "Fennec"]]]
  end

  defp dialyzer do
    [plt_core_path: ".dialyzer/",
     flags: ["-Wunmatched_returns", "-Werror_handling",
             "-Wrace_conditions", "-Wunderspecs"]]
  end

  defp test_coverage do
    [tool: ExCoveralls]
  end

  defp preferred_cli_env do
    ["coveralls": :test, "coveralls.detail": :test,
     "coveralls.travis": :test, "coveralls.html": :test]
  end
end
