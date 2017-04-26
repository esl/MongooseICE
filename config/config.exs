use Mix.Config

config :mix_docker, image: "rslota/fennec"

import_config "#{Mix.env}.exs"
