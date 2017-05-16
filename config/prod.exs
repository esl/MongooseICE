use Mix.Config

config :fennec, loglevel:
  {:system, :atom, "FENNEC_LOGLEVEL", :info}

config :fennec, udp_enabled:
  {:system, :boolean, "FENNEC_UDP_ENABLED", true}

# TCP is NOT supported yet anyway, so don't enable this option
config :fennec, tcp_enabled:
  {:system, :boolean, "FENNEC_TCP_ENABLED", false}

config :fennec, secret:
  {:system, :string, "FENNEC_STUN_SECRET", :base64.encode(:crypto.strong_rand_bytes(128))}

config :fennec, servers: [
  {:udp, [
    ip:       {:system, :string,  "FENNEC_UDP_BIND_IP",   "127.0.0.1"},
    port:     {:system, :integer, "FENNEC_UDP_PORT",      3478},
    realm:    {:system, :string,  "FENNEC_UDP_REALM",     "udp.localhost.local"},
    relay_ip: {:system, :string,  "FENNEC_UDP_RELAY_IP",  "127.0.0.1"},
  ]},
  {:tcp, [
    ip:       {:system, :string,  "FENNEC_TCP_BIND_IP",   "127.0.0.1"},
    port:     {:system, :integer, "FENNEC_TCP_PORT",      3478},
    realm:    {:system, :string,  "FENNEC_TCP_REALM",     "tcp.localhost.local"},
    relay_ip: {:system, :string,  "FENNEC_TCP_RELAY_IP",  "127.0.0.1"},
  ]},
]
