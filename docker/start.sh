#!/bin/bash

# Setting default relay IP to `hostname -I` is much better then leaving 127.0.0.1 in docker container.
# Especially on linux system, where docker container IP is effectively exclusive for Fennec
# On Windows and macOS it will not be accessible since the container is hidden in ~VM

DEFAULT_RELAY_IP=`hostname -I | awk '{print $1}'`

export FENNEC_UDP_RELAY_IP=${FENNEC_UDP_RELAY_IP:=$DEFAULT_RELAY_IP}
export FENNEC_TCP_RELAY_IP=${FENNEC_TCP_RELAY_IP:=$DEFAULT_RELAY_IP}

/opt/app/bin/fennec "$@"
