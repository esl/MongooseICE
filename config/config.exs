use Mix.Config

config :mix_docker, image: "fennec"

import_config "#{Mix.env}.exs"
