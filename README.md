# dewdrop

Fluid Framework protocol codec for Gleam — the Fluid analogue of [roost](https://github.com/tylerbutler/roost).

> **Status:** pre-1.0. API unstable. Not published on Hex.

## What it does

- Uses [windsock](https://github.com/tylerbutler/windsock) for canonical
  Socket.IO text frames: an event name plus positional args
  (`42["event", ...args]`).
- Provides the Fluid event vocabulary (`connect_document`, `submitOp`, `op`,
  `signal`, `nack`, summaries, close, ...) in `dewdrop/events`.
- Provides top-level encoders for common client frames and a decoder for inbound
  Fluid event frames.
- Provides `dewdrop/server`, a beryl server codec for tests and servers that
  need to speak the same Fluid Socket.IO text-frame shape.
- Pairs with [aquamarine](https://github.com/tylerbutler/aquamarine) as a
  pluggable client codec, the way `roost` backs `aquamarine/phoenix`.

## Quick start

```gleam
import dewdrop
import gleam/json

pub fn join() {
  dewdrop.encode_connect(json.object([#("id", json.string("doc"))]))
}
```

## Fluid frame shape

Fluid event packets are Socket.IO event frames:

```text
42["submitOp", clientId, messages]
```

`windsock` keeps that shape explicit. It encodes an event name followed by
ordered JSON arguments, decodes inbound `42[...]` packets into an event name plus
dynamic positional args, and exposes heartbeat packet constants: `2` for ping and
`3` for pong. dewdrop layers Fluid event names and aquamarine/beryl adapters on
top of that raw framing package.

## Event vocabulary

`dewdrop/events` contains dependency-light constants for the Fluid events dewdrop
knows about:

- `connect_document`
- `connect_document_success`
- `connect_document_error`
- `submitOp`
- `submitSignal`
- `op`
- `signal`
- `nack`
- `close`
- `submitSummary`
- `summaryAck`
- `summaryNack`

## beryl server codec

`dewdrop/server.server_codec()` exposes a `beryl/wire/codec.Codec` for Fluid
Socket.IO text frames. It decodes `connect_document` as a beryl join, derives a
`document:<tenant>:<doc>` topic from the connect payload when possible, handles
heartbeat ping packets, and encodes Fluid replies and pushes through `windsock`.

```gleam
import beryl
import dewdrop/server

pub fn config() {
  beryl.config(server.server_codec())
}
```

## aquamarine integration

`dewdrop.codec()` exposes a minimal `aquamarine/codec.Codec` for Fluid's
`connect_document` / `connect_document_success` handshake. It uses the first
positional string arg as the reply ref when decoding success frames, which keeps
upstream aquamarine's channel lifecycle usable while the Socket.IO-specific
reply-correlation issue remains open.

## Why this is not a Phoenix channel codec

Fluid and Phoenix use different wire shapes.

Fluid's Socket.IO event frame is event-first and positional:

```text
42["event", ...args]
```

Phoenix channels use a five-part tuple with channel correlation fields in the
frame:

```text
[join_ref, ref, topic, event, payload]
```

That difference is why dewdrop uses `windsock` for Socket.IO framing instead of
reusing the Phoenix codec shape from roost.
