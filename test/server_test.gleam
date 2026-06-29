import beryl/wire/codec.{
  Event, Heartbeat, Join, Leave, StatusError, StatusOk, TextFrame,
}
import dewdrop/server
import gleam/json
import gleam/option.{None}
import startest.{describe, it}
import startest/expect

fn decode(text) {
  let c = server.server_codec()
  c.decode_text(text)
}

pub fn server_codec_tests() {
  describe("dewdrop/server", [
    it("maps connect_document to Join with document topic", fn() {
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
      expect.to_equal(inbound.kind, Join)
      expect.to_equal(inbound.topic, "document:t1:d1")
    }),
    it("maps close to Leave", fn() {
      let assert Ok(inbound) = decode("42[\"close\",{}]")
      expect.to_equal(inbound.kind, Leave)
    }),
    it("maps submitOp to Event", fn() {
      let assert Ok(inbound) = decode("42[\"submitOp\",{}]")
      expect.to_equal(inbound.kind, Event("submitOp"))
    }),
    it("treats engine.io ping as Heartbeat", fn() {
      let assert Ok(inbound) = decode("2")
      expect.to_equal(inbound.kind, Heartbeat)
    }),
    it("encodes a push as a 42 frame", fn() {
      let c = server.server_codec()
      c.encode_push("document:t1:d1", "op", json.string("x"))
      |> expect.to_equal(TextFrame("42[\"op\",\"x\"]"))
    }),
    it("encodes a reply as connect_document_success", fn() {
      let c = server.server_codec()
      c.encode_reply(None, None, "t", StatusOk, json.string("ok"))
      |> expect.to_equal(TextFrame("42[\"connect_document_success\",\"ok\"]"))
    }),
    it("encodes an error reply as connect_document_error", fn() {
      let c = server.server_codec()
      c.encode_reply(None, None, "t", StatusError, json.string("nope"))
      |> expect.to_equal(TextFrame("42[\"connect_document_error\",\"nope\"]"))
    }),
    it("answers heartbeat with engine.io pong", fn() {
      let c = server.server_codec()
      c.encode_heartbeat_reply(None)
      |> expect.to_equal(TextFrame("3"))
    }),
  ])
}
