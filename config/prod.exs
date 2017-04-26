use Mix.Config

config :fennec, secret: "Zd5Pb2O2"
config :fennec, servers: [
  {:udp, [
    ip:         {217, 182, 204, 9},
    relay_ip:   {217, 182, 204, 9},
    port:       12_100,
    realm:      "ovh"
  ]}
]
