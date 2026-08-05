import beryl/wire/codec.{
  Event, Heartbeat, Join, Leave, StatusError, StatusOk, TextFrame,
}
import dewdrop/server
import gleam/json
import gleam/option.{None, Some}

fn decode(text) {
  let c = server.server_codec()
  codec.decode_text(c)(text)
}

pub fn maps_connect_document_to_join_with_document_topic_test() {
  let payload =
    json.to_string(
      json.object([
        #("event", json.string("connect_document")),
        #("tenantId", json.string("t1")),
        #("documentId", json.string("d1")),
      ]),
    )
  let frame = "42[\"connect_document\"," <> payload <> "]"
  let assert Ok(inbound) = decode(frame)
  assert codec.inbound_kind(inbound) == Join
  assert codec.inbound_topic(inbound) == "document:t1:d1"
}

pub fn maps_close_to_leave_test() {
  let assert Ok(inbound) = decode("42[\"close\",{}]")
  assert codec.inbound_kind(inbound) == Leave
}

pub fn maps_submit_op_to_event_test() {
  let assert Ok(inbound) = decode("42[\"submitOp\",{}]")
  assert codec.inbound_kind(inbound) == Event("submitOp")
}

pub fn treats_engine_io_ping_as_heartbeat_test() {
  let assert Ok(inbound) = decode("2")
  assert codec.inbound_kind(inbound) == Heartbeat
}

pub fn encodes_a_push_as_a_42_frame_test() {
  let c = server.server_codec()
  assert codec.encode_push(c)("document:t1:d1", "op", json.string("x"))
    == TextFrame("42[\"op\",\"x\"]")
}

pub fn encodes_a_reply_as_connect_document_success_test() {
  let c = server.server_codec()
  assert codec.encode_reply(c)(None, None, "t", StatusOk, json.string("ok"))
    == TextFrame("42[\"connect_document_success\",\"ok\"]")
}

pub fn encodes_an_error_reply_as_connect_document_error_test() {
  let c = server.server_codec()
  assert codec.encode_reply(c)(
      None,
      None,
      "t",
      StatusError,
      json.string("nope"),
    )
    == TextFrame("42[\"connect_document_error\",\"nope\"]")
}

pub fn answers_heartbeat_with_engine_io_pong_test() {
  let c = server.server_codec()
  assert codec.encode_heartbeat_reply(c)(None) == TextFrame("3")
}

pub fn attaches_a_channel_close_encoder_test() {
  let c = server.server_codec()
  let assert Some(_) = codec.encode_close(c)
}

pub fn encodes_a_channel_close_as_a_close_frame_test() {
  let c = server.server_codec()
  let assert Some(encode_close) = codec.encode_close(c)
  assert encode_close(Some("join-1"), "document:t1:d1")
    == TextFrame("42[\"close\"]")
}

pub fn encodes_a_channel_close_without_a_join_ref_test() {
  let c = server.server_codec()
  let assert Some(encode_close) = codec.encode_close(c)
  assert encode_close(None, "") == TextFrame("42[\"close\"]")
}
