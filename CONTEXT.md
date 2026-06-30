# dewdrop — context

## Purpose

dewdrop is the **Fluid Framework protocol codec for Gleam** — the Fluid analogue
of [roost](https://github.com/tylerbutler/roost). roost owns the Phoenix channel
wire frame; `windsock` owns the generic **Socket.IO** text-frame primitives;
dewdrop owns the canonical **Fluid** event vocabulary and adapters. dewdrop and
roost are meant to plug into
[aquamarine](https://github.com/tylerbutler/aquamarine) as codecs, so a Gleam
client can speak Fluid without depending on a Phoenix-specific codec.

It is a peer to `windsock`, `roost`, and `levee` (`../windsock`,
`../dewdrop`, `../roost`, `../levee`).

End goal: a lightweight Gleam Fluid client usable as an in-VM integration test
client for levee (full handshake: join → `connect_document` → `submitOp`/`op`),
without Node/Playwright.

## Why a separate frame (not roost)

Canonical Fluid is Socket.IO: `socket.emit("submitOp", clientId, messages)` — an
event name plus positional args (`42["event", ...args]`). `windsock` owns that
raw Socket.IO event frame. roost's frame is the Phoenix 5-tuple `[join_ref, ref,
topic, event, payload]`. levee adapted Fluid to Phoenix, but dewdrop targets
canonical Fluid, so it composes with `windsock` instead of roost.

## Current state

- `../windsock/src/windsock.gleam` — Socket.IO frame encode/decode + heartbeat.
- `src/dewdrop/events.gleam` — Fluid event vocabulary.
- `src/dewdrop.gleam` — Fluid encoders and aquamarine codec adapter.
- `src/dewdrop/server.gleam` — beryl server codec adapter.
- dewdrop depends on `windsock`, `aquamarine`, and `beryl`; `windsock` stays
  dependency-light with only `gleam_stdlib` + `gleam_json` production
  dependencies.

## Current integration notes

`dewdrop.codec()` now returns an `aquamarine/codec.Codec` using Fluid events and
custom reply matching for `connect_document_success`. `dewdrop/server` exposes a
beryl codec that maps Fluid Socket.IO frames into beryl inbound messages.

Next protocol work should stay above `windsock`: payload normalization, richer
Fluid message typing, and levee integration tests belong in
dewdrop/spillway/levee, not the raw frame package.
