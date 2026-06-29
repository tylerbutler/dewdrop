# dewdrop — context

## Purpose

dewdrop is the **Fluid Framework protocol codec for Gleam** — the Fluid analogue
of [roost](https://github.com/tylerbutler/roost). roost owns the Phoenix channel
wire frame; dewdrop owns the canonical **Fluid (Socket.IO)** wire frame and event
vocabulary. Both are meant to plug into
[aquamarine](https://github.com/tylerbutler/aquamarine) as codecs, so a Gleam
client can speak Fluid without depending on a Phoenix-specific codec.

It is a peer to `roost` and `levee` (`../dewdrop`, `../roost`, `../levee`).

End goal: a lightweight Gleam Fluid client usable as an in-VM integration test
client for levee (full handshake: join → `connect_document` → `submitOp`/`op`),
without Node/Playwright.

## Why a separate frame (not roost)

Canonical Fluid is Socket.IO: `socket.emit("submitOp", clientId, messages)` — an
event name plus positional args (`42["event", ...args]`). roost's frame is the
Phoenix 5-tuple `[join_ref, ref, topic, event, payload]`. levee adapted Fluid to
Phoenix, but dewdrop targets canonical Fluid, so its frame is genuinely distinct.

## Current state

- `src/dewdrop/frame.gleam` — Socket.IO frame encode/decode + heartbeat. ✅ tested
- `src/dewdrop.gleam` — Fluid event vocabulary + encoders (`connect_document`,
  `submitOp`, `submitSignal`, `op`, `signal`, `nack`). ✅ tested
- 6 startest tests pass; `gleam build --warnings-as-errors` clean.
- No production deps beyond `gleam_stdlib` + `gleam_json` (aquamarine dropped for
  now — see blocker).

## Blocker

A turnkey `aquamarine.Codec` value cannot be built yet. aquamarine's `Codec`
correlates the join reply via `ref == join_ref`; Socket.IO has no ref/topic.
Proposed fix: pluggable `matches_reply: fn(Incoming, String) -> Bool` —
**tylerbutler/aquamarine#9**.

## Next steps (in order)

1. Land aquamarine#9 (add `matches_reply`; `phoenix.codec()` keeps default).
2. Re-add aquamarine dep; resolve the `gleam_stdlib` conflict with startest
   (aquamarine wants >=1.0, startest/bigben wants <1.0) — bump or swap test dep.
3. Add `dewdrop.codec()` returning `aquamarine.Codec` with Fluid events and
   `matches_reply: connect_document_success`.
4. Add payload normalizers mirroring client/levee-driver `contracts.ts`.
5. Build a minimal client connecting to levee; assert full handshake.
6. Wire as a levee integration test; verify it surfaces the missing server
   ping/pong (see levee bug discussion).
