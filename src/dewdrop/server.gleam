//// Fluid (Socket.IO) server codec for the beryl runtime.
////
//// Peer to `dewdrop.codec()` (the aquamarine *client* codec): this exposes a
//// `beryl/wire/codec.Codec` so a beryl server speaks the canonical Fluid
//// `42[...]` frame provided by `windsock`. Pass it to `beryl.config`.
////
//// ```gleam
//// beryl.config(dewdrop/server.server_codec())
//// ```
////
//// ## Topic derivation
////
//// Socket.IO frames carry no topic. `connect_document` is mapped to a beryl
//// `Join` whose topic is `document:<tenant>:<doc>` read from the connect
//// payload. Other frames have no tenant/doc, so they decode with an empty
//// topic; routing them requires a client->topic map outside this pure codec.
////
//// ## Routerlicious argument shapes
////
//// Beryl carries one payload per inbound/outbound event, while Routerlicious
//// spreads some events over several Socket.IO arguments. This codec folds
//// those into one object so channels see a single, named payload:
////
//// - `submitOp(clientId, messageBatches)` decodes to
////   `{"clientId": ..., "messageBatches": ...}`.
//// - `submitSignal(clientId, signals)` decodes to
////   `{"clientId": ..., "signals": ...}`.
//// - Pushing `op` or `nack` encodes as `op(documentId, payload)`, with the
////   document id taken from the `document:<tenant>:<doc>` topic.
////
//// Every other event uses its first argument as the payload (or an empty
//// object when there is none) and is pushed as `event(payload)`.
////
//// ## Engine.IO control frames
////
//// Engine.IO `ping` (`2`) and `pong` (`3`) both decode as beryl heartbeats,
//// so either side of the Engine.IO handshake can drive liveness. The
//// Socket.IO namespace-connect packet (`40`) is transport control, not a
//// Fluid event, and decodes as `InvalidFormat`; a transport is expected to
//// answer it before the codec sees it.
////
//// ## Channel termination
////
//// A close encoder is attached, so beryl emits `42["close"]` to a client
//// whenever one of its channels ends gracefully (leave, server shutdown,
//// heartbeat eviction) instead of leaving the client to time out. No error
//// encoder is attached: Fluid has no event meaning "this channel crashed"
//// (`nack` rejects ops, not channels), so abnormal termination stays silent
//// rather than reusing an event with different semantics.

import beryl/wire/codec.{
  type Codec, type DecodeError, type Frame, type Inbound, type ReplyStatus,
  Event, Heartbeat, InvalidFormat, InvalidJson, Join, Leave, StatusError,
  StatusOk, TextFrame,
}
import dewdrop/events
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{None}
import gleam/string
import windsock

/// Socket.IO namespace-connect packet (`40`), sent by a client after the
/// Engine.IO handshake and before any Fluid event.
pub const socket_connect = "40"

/// Build a Fluid server `Codec` for beryl. Pair with `windsock` framing.
pub fn server_codec() -> Codec {
  codec.new(
    decode_text: decode_text,
    encode_reply: encode_reply,
    encode_push: encode_push,
    encode_heartbeat_reply: encode_heartbeat_reply,
  )
  |> codec.with_topicless_events
  |> codec.with_close_encoder(encode_close)
}

fn decode_text(text: String) -> Result(Inbound, DecodeError) {
  case text {
    t if t == windsock.ping || t == windsock.pong -> Ok(heartbeat_inbound())
    t if t == socket_connect ->
      Error(InvalidFormat("Socket.IO namespace connect is transport control"))
    _ ->
      case windsock.decode(text) {
        Ok(incoming) -> Ok(to_inbound(incoming))
        Error(windsock.InvalidJson(reason)) -> Error(InvalidJson(reason))
        Error(windsock.InvalidFormat(reason)) -> Error(InvalidFormat(reason))
      }
  }
}

fn to_inbound(incoming: windsock.Incoming) -> Inbound {
  let payload = payload_from_args(incoming.event, incoming.args)
  let kind = case incoming.event {
    e if e == events.connect_document -> Join
    e if e == events.close -> Leave
    other -> Event(other)
  }
  codec.inbound(
    join_ref: None,
    ref: None,
    topic: topic_from_payload(payload),
    kind: kind,
    payload: payload,
  )
}

/// Fold Routerlicious's multi-argument events into one named payload; every
/// other event's payload is its first argument.
fn payload_from_args(event: String, args: List(Dynamic)) -> Dynamic {
  case event, args {
    e, [client_id, messages, ..] if e == events.submit_op ->
      dynamic.properties([
        #(dynamic.string("clientId"), client_id),
        #(dynamic.string("messageBatches"), messages),
      ])
    e, [client_id, signals, ..] if e == events.submit_signal ->
      dynamic.properties([
        #(dynamic.string("clientId"), client_id),
        #(dynamic.string("signals"), signals),
      ])
    _, [first, ..] -> first
    _, [] -> dynamic.properties([])
  }
}

fn heartbeat_inbound() -> Inbound {
  codec.inbound(
    join_ref: None,
    ref: None,
    topic: "",
    kind: Heartbeat,
    payload: dynamic.properties([]),
  )
}

fn topic_from_payload(payload: Dynamic) -> String {
  let tenant =
    field_string(payload, "tenantId", field_string(payload, "tenant", ""))
  let doc = field_string(payload, "documentId", field_string(payload, "id", ""))
  case tenant, doc {
    "", _ -> ""
    _, "" -> ""
    _, _ -> "document:" <> tenant <> ":" <> doc
  }
}

fn field_string(value: Dynamic, key: String, fallback: String) -> String {
  case decode.run(value, decode.field(key, decode.string, decode.success)) {
    Ok(found) -> found
    Error(_) -> fallback
  }
}

fn encode_reply(
  _join_ref: option.Option(String),
  _ref: option.Option(String),
  _topic: String,
  status: ReplyStatus,
  payload: Json,
) -> Frame {
  case status {
    StatusOk ->
      TextFrame(windsock.encode(events.connect_document_success, [payload]))
    StatusError ->
      TextFrame(windsock.encode(events.connect_document_error, [payload]))
  }
}

fn encode_push(topic: String, event: String, payload: Json) -> Frame {
  case event {
    e if e == events.op || e == events.nack ->
      TextFrame(
        windsock.encode(event, [json.string(document_id(topic)), payload]),
      )
    _ -> TextFrame(windsock.encode(event, [payload]))
  }
}

/// The `<doc>` of a `document:<tenant>:<doc>` topic. Any other topic is
/// passed through unchanged so a non-standard topic still yields a frame.
fn document_id(topic: String) -> String {
  case string.split(topic, ":") {
    ["document", _, document_id] -> document_id
    _ -> topic
  }
}

fn encode_heartbeat_reply(_ref: option.Option(String)) -> Frame {
  TextFrame(windsock.pong)
}

/// Encode a graceful channel termination as Fluid's `close` event.
///
/// beryl supplies `(join_ref, topic)` so a Phoenix-style client can tell which
/// channel closed. Fluid frames carry neither, and this codec is topicless (a
/// socket has one joined document), so both are dropped and the frame is the
/// bare `42["close"]` — the server-side mirror of the client's `close`. No
/// payload is invented because Fluid defines none for this event.
fn encode_close(_join_ref: option.Option(String), _topic: String) -> Frame {
  TextFrame(windsock.encode(events.close, []))
}
