use Mix.Config

config :fennec, secret: "abc"
config :fennec, servers: [
  {:udp, [
    ip:     {127, 0, 0, 1},
    port:   12_100,
    realm:  "turn1.localhost"
  ]},
  {:udp, [
    ip:     {127, 0, 0, 1},
    port:   12_200,
    realm:  "turn2.localhost"
  ]}
]
