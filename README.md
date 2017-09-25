# MongooseICE

[![Build Status][BUILD BADGE]][BUILD LINK]
[![Coverage Status][COVERAGE BADGE]][COVERAGE LINK]

[Documentation](https://hexdocs.pm/mongooseice/0.4.0)

MongooseICE is a STUN server by [Erlang Solutions][OUR SITE] whose internals aim to be well written and tested.

## Rationale

Many modern applications (mobile and web) are media intensive like those involving audio, video, gaming, and file transfer.
MongooseICE helps to get communication done peer-to-peer (without going through a server) so your **bandwidth and server-side costs don't need to be as much of a concern**.

## Resources

Some helpful technical material:

* For the bigger picture see the **RTCPeerConnection plus servers** section under [this][OVERVIEW] tutorial
* MongooseICE alone isn't enough to get peer-to-peer communication going.
The reason why is described in [this][SIGNALING] tutorial.
Our [XMPP server][MONGOOSE], MongooseIM, is perfect for building a combination of signaling and chat applications
* Find the STUN, TURN, and ICE RFCs (at the IETF site)

### Installation as part of other application

MongooseICE is available on [Hex](https://hex.pm/packages/mongooseice). To use it, just add it to your dependencies:

```elixir
def deps do
  [
    {:mongooseice, "~> 0.4.0"}
  ]
end
```

### Installation as standalone service

For now there are two ways of starting `MongooseICE` as standalone application. Via release built from
source or via prebuilt docker image. The docker image could be used for production system with a proper
network setup (the easiest one would be `--net=host` docker option). For developement on non-docker-native platforms
it is probably easier to start the built release then setup docker container to work correctly.
This is due to the fact that TURN server uses system ephemeral port pool for allocations, which is
not so easy to map to the host machine. This issue is not visible on Linux systems, since you
can allow docker to use its private virtual network and just use the docker container's IP address
as the relay IP (which is set this way in `MongooseICE` by default when using the docker image).

#### Building and using a release

You may build the release and use it on production system. In order to do that, just type:

```bash
MIX_ENV=prod mix do deps.get, release
```

The release can be configured by environment variables described in **Configuration** section below.

#### Using docker prebuilt container

You can use our prebuilt docker images on our dockerhub:

```bash
docker run -it -p 3478:3478/udp -e "MONGOOSEICE_STUN_SECRET=very_secret" mongooseim/mongooseice
```

This command will start the *MongooseICE* server with default configuration and with STUN secret set
to *very_secret*. If you are using this on Linux, the part with `-p 3478:3478/udp` is not needed, since
you can access the server directly using the container's IP. You can configure the server by passing
environment variables to the container. All those variables are described in **Configuration** section below.

#### Building docker container

Well, that's gonna be quite simple and short:

```bash
MIX_ENV=prod mix do deps.get, docker.build, docker.release
```

And that's it. You have just built `MongooseICE's` docker image. The name of the image should be
visible at the end of the output of the command you've just run. You can configure the container by
setting environment variables that are described in **Configuration** section below.

#### Configuration

Assuming you are using release built with env `prod` or the docker image, you will have access to
the following system's environment viaribles:

##### General configuration

* `MONGOOSEICE_LOGLEVEL` - `debug`/`info`/`warn`/`error` - Log level of the application. `info` is the default one
* `MONGOOSEICE_UDP_ENABLED` - `true`/`false` - Enable or disable UDP STUN/TURN interface. Enabled by default
* `MONGOOSEICE_TCP_ENABLED` - `true`/`false` - *Not yet supported* - Enable or disable TCP STUN/TURN interface. Disabled by default.
* `MONGOOSEICE_STUN_SECRET` - Secret that STUN/TURN clients have to use to authorize with the server

##### UDP configuration

The following variables configure UDP STUN/TURN interface. It must be enabled via `MONGOOSEICE_UDP_ENABLED=true` in order for those options to take effect.

* `MONGOOSEICE_UDP_BIND_IP` - IP address on which MongooseICE listens for requests. Release default is `127.0.0.1`, but in case of docker container the default is `0.0.0.0`
* `MONGOOSEICE_UDP_PORT` - Port which server listens on for STUN/TURN requests. Default is `3478`
* `MONGOOSEICE_UDP_REALM` - Realm name for this MongooseICE server as defined in [TURN RFC](https://tools.ietf.org/rfc/rfc5766.txt). Default: `udp.localhost.local`
* `MONGOOSEICE_UDP_RELAY_IP` - IP of the relay interface. All `allocate` requests will return this IP address to the client, therefore this cannot be set to `0.0.0.0`. Release default is `127.0.0.1`, but in case of docker container the default is set to the first IP address returned by `hostname -i` on the container.

##### TCP configuration

TCP is not yet supported.

### Checklist of STUN/TURN methods supported by MongooseICE

- [x] Binding
- [x] Allocate
- [x] Refresh
- [x] Send
- [x] Data
- [x] CreatePermission
- [x] ChannelBind

### Checklist of STUN/TURN attributes supported by MongooseICE

#### Comprehension Required

- [x] XOR-MAPPED-ADDRESS
- [x] MESSAGE-INTEGRITY
- [x] ERROR-CODE
- [x] UNKNOWN-ATTRIBUTES
- [x] REALM
- [x] NONCE
- [x] CHANNEL-NUMBER
- [x] LIFETIME
- [x] XOR-PEER-ADDRESS
- [x] DATA
- [x] XOR-RELAYED-ADDRESS
- [x] EVEN-PORT
- [x] REQUESTED-TRANSPORT
- [ ] DONT-FRAGMENT
- [x] RESERVATION-TOKEN
- [ ] PRIORITY
- [ ] USE-CANDIDATE
- [ ] ICE-CONTROLLED
- [ ] ICE-CONTROLLING

#### Comprehension Optional

- [ ] SOFTWARE
- [ ] ALTERNATE-SERVER
- [ ] FINGERPRINT

## License

Copyright 2017 Erlang Solutions Ltd.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

[BUILD BADGE]: https://travis-ci.org/esl/MongooseICE.svg?branch=master
[BUILD LINK]: https://travis-ci.org/esl/MongooseICE

[COVERAGE BADGE]: https://coveralls.io/repos/github/esl/MongooseICE/badge.svg
[COVERAGE LINK]: https://coveralls.io/github/esl/MongooseICE

[OUR SITE]: https://www.erlang-solutions.com/

[OVERVIEW]: https://www.html5rocks.com/en/tutorials/webrtc/basics/#toc-rtcpeerconnection
[SIGNALING]: https://www.html5rocks.com/en/tutorials/webrtc/basics/#toc-rtcpeerconnection

[MONGOOSE]: https://github.com/esl/MongooseIM
