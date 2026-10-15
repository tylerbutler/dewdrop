# dewdrop

Fluid Framework protocol codec for Gleam — the Fluid analogue of [roost](https://github.com/tylerbutler/roost).

> **Status:** pre-1.0. API unstable. Not published on Hex.

## What it does

- Uses [windsock](https://github.com/tylerbutler/windsock) for canonical
  Socket.IO text frames: an event name plus positional args
  (`42["event", ...args]`).
- Provides the Fluid event vocabulary (`connect_document`, `submitOp`, `op`,
  `signal`, `nack`, summaries, close, ...) in `dewdrop/event`.
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

`dewdrop/event` contains dependency-light constants for the Fluid events dewdrop
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

The module was renamed from `dewdrop/events` to `dewdrop/event`. Update existing
imports to the singular name; the top-level `dewdrop` constants are unchanged.

## beryl server codec

`dewdrop/server.server_codec()` exposes a `beryl/wire/codec.Codec` for Fluid
Socket.IO text frames. It decodes `connect_document` as a beryl join, derives a
`document:<tenant>:<doc>` topic from the connect payload when possible, handles
heartbeat ping packets, and encodes Fluid replies and pushes through `windsock`.

It also attaches a close encoder, so beryl sends `42["close"]` when a channel
terminates gracefully (leave, server shutdown, heartbeat eviction) rather than
letting the client wait out push timeouts. Abnormal termination is not signalled
— Fluid has no channel-error event, and `nack` rejects ops rather than channels.

```gleam
import beryl
import dewdrop/server

pub fn config() {
  beryl.config(server.server_codec())
}
```

## aquamarine integration

`dewdrop.codec()` exposes a minimal `aquamarine/codec.Codec` for Fluid's
join handshake. It sends `connect_document(join_ref, payload)`, where `join_ref`
is a string used to match the reply to the waiting join call.
`dewdrop/server` retains this reference, reads the document payload from the
second argument, and echoes the reference in both success and error replies.
Success payloads must contain `"status": "ok"`; error payloads can contain a
string `"reason"`, which is returned to the caller.

This reference-prefixed form is an adapter extension, not the canonical Fluid
join shape. `dewdrop.encode_connect(payload)` still sends the payload-only form;
the server accepts it and replies without a reference. The aquamarine adapter
does not match replies that have no reference.

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
