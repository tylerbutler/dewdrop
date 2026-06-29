//// Fluid (Socket.IO) server codec for the beryl runtime.
////
//// Peer to `dewdrop.codec()` (the aquamarine *client* codec): this exposes a
//// `beryl/wire/codec.Codec` so a beryl server speaks the canonical Fluid
//// `42[...]` frame owned by `dewdrop/frame`. Pass it to `beryl.config`.
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

import beryl/wire/codec.{
  type Codec, type DecodeError, type Frame, type Inbound, type ReplyStatus,
  Codec, Event, Heartbeat, Inbound, InvalidFormat, InvalidJson, Join, Leave,
  StatusError, StatusOk, TextFrame,
}
import dewdrop/events
import dewdrop/frame
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{None}

/// Build a Fluid server `Codec` for beryl. Pair with `dewdrop/frame` framing.
pub fn server_codec() -> Codec {
  Codec(
    decode_text: decode_text,
    decode_binary: None,
    encode_reply: encode_reply,
    encode_push: encode_push,
    encode_heartbeat_reply: encode_heartbeat_reply,
  )
}

fn decode_text(text: String) -> Result(Inbound, DecodeError) {
  case text {
    t if t == frame.ping -> Ok(heartbeat_inbound())
    _ ->
      case frame.decode(text) {
        Ok(incoming) -> Ok(to_inbound(incoming))
        Error(frame.InvalidJson(reason)) -> Error(InvalidJson(reason))
        Error(frame.InvalidFormat(reason)) -> Error(InvalidFormat(reason))
      }
  }
}

fn to_inbound(incoming: frame.Incoming) -> Inbound {
  let payload = first_arg(incoming.args)
  let kind = case incoming.event {
    e if e == events.connect_document -> Join
    e if e == events.close -> Leave
    other -> Event(other)
  }
  Inbound(
    join_ref: None,
    ref: None,
    topic: topic_from_payload(payload),
    kind: kind,
    payload: payload,
  )
}

fn heartbeat_inbound() -> Inbound {
  Inbound(
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
  let doc =
    field_string(payload, "documentId", field_string(payload, "id", ""))
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

fn first_arg(args: List(Dynamic)) -> Dynamic {
  case args {
    [first, ..] -> first
    [] -> dynamic.properties([])
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
    StatusOk -> TextFrame(frame.encode(events.connect_document_success, [payload]))
    StatusError -> TextFrame(frame.encode(events.connect_document_error, [payload]))
  }
}

fn encode_push(_topic: String, event: String, payload: Json) -> Frame {
  TextFrame(frame.encode(event, [payload]))
}

fn encode_heartbeat_reply(_ref: option.Option(String)) -> Frame {
  TextFrame(frame.pong)
}
