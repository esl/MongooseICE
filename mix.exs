defmodule MongooseICE.Mixfile do
  use Mix.Project

  def project do
    [app: :mongooseice,
     version: "0.4.0",
     name: "MongooseICE",
     description: "STUN/TURN server",
     source_url: "https://github.com/esl/mongooseice",
     homepage_url: "http://mongooseim.readthedocs.io",
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
    [extra_applications: [:logger, :runtime_tools, :crypto],
     mod: {MongooseICE.Application, []}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/helper.ex"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:confex, "~> 2.0.1"},
     {:mix_docker, "~> 0.3.0", runtime: false},
     {:ex_doc, "~> 0.14", runtime: false, only: :dev},
     {:credo, "~> 0.5", runtime: false, only: :dev},
     {:dialyxir, "~> 0.4", runtime: false, only: :dev},
     {:excoveralls, "~> 0.5", runtime: false, only: :test},
     {:inch_ex, "~> 0.5", runtime: false, only: :dev},
     {:mock, "~> 0.2.0", only: :test},
     {:jerboa, "~> 0.3"}]
  end

  defp package do
    [licenses: ["Apache 2.0"],
     maintainers: ["Erlang Solutions"],
     links: %{"GitHub" => "https://github.com/esl/mongooseice"}]
  end

  defp docs do
    [main: "MongooseICE",
     logo: "static/mongooseim_logo.png",
     extras: ["README.md": [title: "MongooseICE"]]]
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
