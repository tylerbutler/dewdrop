//// Fluid Framework protocol codec — the Fluid analogue of `roost`.
////
//// dewdrop owns the canonical Fluid (Socket.IO) wire frame in `dewdrop/frame`
//// and the event vocabulary below. It pairs with
//// [aquamarine](https://github.com/tylerbutler/aquamarine) as a pluggable
//// codec, the same way `roost` backs `aquamarine/phoenix`.
////
//// The public `codec()` function exposes an `aquamarine/codec.Codec` that
//// maps Fluid's `connect_document` / `connect_document_success` events onto the
//// generic channel lifecycle. It currently uses the first positional string arg
//// as the reply ref on inbound success frames, which keeps the integration
//// compatible with the current aquamarine transport while the upstream issue
//// around reply matching remains open.

import aquamarine/codec as aquamarine_codec
import dewdrop/events
import dewdrop/frame
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dynamic_decode
import gleam/json
import gleam/option.{type Option, None, Some}

/// Event-name vocabulary lives in `dewdrop/events` so importers can use the
/// names without depending on aquamarine or beryl. Re-exported here for
/// backwards compatibility.
pub const connect_document = events.connect_document

pub const connect_document_success = events.connect_document_success

pub const connect_document_error = events.connect_document_error

pub const submit_op = events.submit_op

pub const submit_signal = events.submit_signal

pub const op = events.op

pub const signal = events.signal

pub const nack = events.nack

/// Build an `aquamarine/codec.Codec` for Fluid event frames.
pub fn codec() -> aquamarine_codec.Codec {
  aquamarine_codec.Codec(
    decode: decode_aquamarine,
    encode_join: encode_join,
    encode_push: encode_push,
    encode_heartbeat: encode_heartbeat,
    matches_reply: matches_reply,
    reply_status: reply_status,
    join_event: connect_document,
    reply_event: connect_document_success,
    close_event: events.close,
    error_event: connect_document_error,
    heartbeat_topic: "",
  )
}

/// Encode a `connect_document` frame.
pub fn encode_connect(payload: json.Json) -> String {
  frame.encode(connect_document, [payload])
}

/// Encode a `submitOp` frame: `submitOp(client_id, messages)`.
pub fn encode_submit_op(client_id: json.Json, messages: json.Json) -> String {
  frame.encode(submit_op, [client_id, messages])
}

/// Encode a `submitSignal` frame: `submitSignal(client_id, signals)`.
pub fn encode_submit_signal(
  client_id: json.Json,
  signals: json.Json,
) -> String {
  frame.encode(submit_signal, [client_id, signals])
}

/// Decode an inbound Fluid event frame.
pub fn decode(text: String) -> Result(frame.Incoming, frame.DecodeError) {
  frame.decode(text)
}

fn decode_aquamarine(
  text: String,
) -> Result(aquamarine_codec.Incoming, aquamarine_codec.DecodeError) {
  case decode(text) {
    Ok(incoming) ->
      Ok(aquamarine_codec.Incoming(
        join_ref: None,
        ref: extract_ref(incoming.event, incoming.args),
        topic: "",
        event: incoming.event,
        payload: payload_from_args(incoming.args),
      ))
    Error(error) -> Error(decode_error(error))
  }
}

fn encode_join(join_ref: String, topic: String, payload: json.Json) -> String {
  let _ = topic
  frame.encode(connect_document, [json.string(join_ref), payload])
}

fn encode_push(
  join_ref: String,
  ref: String,
  topic: String,
  event: String,
  payload: json.Json,
) -> String {
  let _ = join_ref
  let _ = ref
  let _ = topic
  frame.encode(event, [payload])
}

fn encode_heartbeat(ref: String) -> String {
  let _ = ref
  frame.encode_heartbeat()
}

fn decode_error(error: frame.DecodeError) -> aquamarine_codec.DecodeError {
  case error {
    frame.InvalidJson(reason) -> aquamarine_codec.InvalidJson(reason)
    frame.InvalidFormat(reason) -> aquamarine_codec.InvalidFormat(reason)
  }
}

fn matches_reply(
  incoming: aquamarine_codec.Incoming,
  join_ref: String,
) -> Bool {
  case incoming.event, incoming.ref {
    "connect_document_success", Some(reply_ref) -> reply_ref == join_ref
    _, _ -> False
  }
}

fn reply_status(incoming: aquamarine_codec.Incoming) -> Result(Nil, String) {
  case incoming.event {
    "connect_document_success" ->
      case
        dynamic_decode.run(
          incoming.payload,
          dynamic_decode.field("status", dynamic_decode.string, fn(status) {
            dynamic_decode.success(status)
          }),
        )
      {
        Ok("ok") -> Ok(Nil)
        Ok(_) -> Error("join rejected")
        Error(_) -> Error("malformed reply")
      }
    _ -> Error("malformed reply")
  }
}

fn extract_ref(event: String, args: List(Dynamic)) -> Option(String) {
  case event, args {
    "connect_document_success", [first, ..] -> decode_string(first)
    _, _ -> None
  }
}

fn payload_from_args(args: List(Dynamic)) -> Dynamic {
  case args {
    [] -> dynamic.properties([])
    [arg] -> arg
    [_, ..rest] -> payload_from_args(rest)
  }
}

fn decode_string(value: Dynamic) -> Option(String) {
  case dynamic_decode.run(value, dynamic_decode.string) {
    Ok(string) -> Some(string)
    Error(_) -> None
  }
}
