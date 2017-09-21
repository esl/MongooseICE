use Mix.Config

config :mongooseice, loglevel:
  {:system, :atom, "MONGOOSEICE_LOGLEVEL", :info}

config :mongooseice, udp_enabled:
  {:system, :boolean, "MONGOOSEICE_UDP_ENABLED", true}

# TCP is NOT supported yet anyway, so don't enable this option
config :mongooseice, tcp_enabled:
  {:system, :boolean, "MONGOOSEICE_TCP_ENABLED", false}

config :mongooseice, secret:
  {:system, :string, "MONGOOSEICE_STUN_SECRET", :base64.encode(:crypto.strong_rand_bytes(128))}

config :mongooseice, servers: [
  {:udp, [
    ip:       {:system, :string,  "MONGOOSEICE_UDP_BIND_IP",   "127.0.0.1"},
    port:     {:system, :integer, "MONGOOSEICE_UDP_PORT",      3478},
    realm:    {:system, :string,  "MONGOOSEICE_UDP_REALM",     "udp.localhost.local"},
    relay_ip: {:system, :string,  "MONGOOSEICE_UDP_RELAY_IP",  "127.0.0.1"},
  ]},
  {:tcp, [
    ip:       {:system, :string,  "MONGOOSEICE_TCP_BIND_IP",   "127.0.0.1"},
    port:     {:system, :integer, "MONGOOSEICE_TCP_PORT",      3478},
    realm:    {:system, :string,  "MONGOOSEICE_TCP_REALM",     "tcp.localhost.local"},
    relay_ip: {:system, :string,  "MONGOOSEICE_TCP_RELAY_IP",  "127.0.0.1"},
  ]},
]
