# dewdrop

Fluid Framework protocol codec for Gleam — the Fluid analogue of [roost](https://github.com/tylerbutler/roost).

> **Status:** pre-1.0. API unstable. Not published on Hex.

## What it does

- Owns the canonical Fluid (Socket.IO) wire frame: an event name plus positional
  args (`42["event", ...args]`), in `dewdrop/frame`.
- Provides the Fluid event vocabulary (`connect_document`, `submitOp`, `op`,
  `signal`, `nack`, ...) and encoders for them.
- Pairs with [aquamarine](https://github.com/tylerbutler/aquamarine) as a
  pluggable codec, the way `roost` backs `aquamarine/phoenix`.

## Quick start

```gleam
import dewdrop
import gleam/json

pub fn join() {
  dewdrop.encode_connect(json.object([#("id", json.string("doc"))]))
}
```

## aquamarine integration

`dewdrop.codec()` now exposes a minimal `aquamarine/codec.Codec` for Fluid's
`connect_document` / `connect_document_success` handshake. It uses the first
positional string arg as the reply ref when decoding success frames, which keeps
upstream aquamarine's channel lifecycle usable while the Socket.IO-specific
reply-correlation issue remains open.
