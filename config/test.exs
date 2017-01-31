use Mix.Config

config :jerboa, :test,
  server: [%{name: "Google (remote)",
             address: {74, 125, 143, 127},
             port: 19_302},
           %{name: "Fennec (local)",
             address: {127, 0, 0, 1},
             port: 8_192}
          ]
