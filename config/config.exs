use Mix.Config

config :mix_docker, image: "fennec"
config :mix_docker,
  dockerfile_build: "docker/Dockerfile.build",
  dockerfile_release: "docker/Dockerfile.release"

import_config "#{Mix.env}.exs"
