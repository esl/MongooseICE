# Fennec

[![Build Status][BUILD BADGE]][BUILD LINK]
[![Coverage Status][COVERAGE BADGE]][COVERAGE LINK]

[Documentation](https://hexdocs.pm/fennec/0.2.0)

Fennec is a STUN server by [Erlang Solutions][OUR SITE] whose internals aim to be well written and tested.

## Rationale

Many modern applications (mobile and web) are media intensive like those involving audio, video, gaming, and file transfer.
Fennec helps to get communication done peer-to-peer (without going through a server) so your **bandwidth and server-side costs don't need to be as much of a concern**.

## Resources

Some helpful technical material:

* For the bigger picture see the **RTCPeerConnection plus servers** section under [this][OVERVIEW] tutorial
* Fennec alone isn't enough to get peer-to-peer communication going.
The reason why is described in [this][SIGNALING] tutorial.
Our [XMPP server][MONGOOSE], MongooseIM, is perfect for building a combination of signaling and chat applications
* Find the STUN, TURN, and ICE RFCs (at the IETF site)

### Installation

Fennec is available on [Hex](https://hex.pm/packages/fennec). To use it, just add it to your dependencies:

```elixir
def deps do
  [{:fennec, "~> 0.2.0"}]
end
```

### Checklist of STUN/TURN methods supported by Fennec

- [x] Binding
- [x] Allocate
- [x] Refresh
- [x] Send
- [x] Data
- [x] CreatePermission
- [ ] ChannelBind

### Checklist of STUN/TURN attributes supported by Fennec

#### Comprehension Required

- [x] XOR-MAPPED-ADDRESS
- [x] MESSAGE-INTEGRITY
- [x] ERROR-CODE
- [x] UNKNOWN-ATTRIBUTES
- [x] REALM
- [x] NONCE
- [ ] CHANNEL-NUMBER
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

[BUILD BADGE]: https://travis-ci.org/esl/fennec.svg?branch=master
[BUILD LINK]: https://travis-ci.org/esl/fennec

[COVERAGE BADGE]: https://coveralls.io/repos/github/esl/fennec/badge.svg
[COVERAGE LINK]: https://coveralls.io/github/esl/fennec

[OUR SITE]: https://www.erlang-solutions.com/

[OVERVIEW]: https://www.html5rocks.com/en/tutorials/webrtc/basics/#toc-rtcpeerconnection
[SIGNALING]: https://www.html5rocks.com/en/tutorials/webrtc/basics/#toc-rtcpeerconnection

[MONGOOSE]: https://github.com/esl/MongooseIM
