import dewdrop
import dewdrop/frame
import gleam/json
import gleam/option
import startest.{describe, it}
import startest/expect

pub fn frame_tests() {
  describe("dewdrop/frame", [
    it("encodes an event with positional args", fn() {
      frame.encode("op", [json.string("c1"), json.int(7)])
      |> expect.to_equal("42[\"op\",\"c1\",7]")
    }),
    it("encodes an event with no args", fn() {
      frame.encode("nack", [])
      |> expect.to_equal("42[\"nack\"]")
    }),
    it("decodes an event frame", fn() {
      let assert Ok(incoming) = frame.decode("42[\"op\",\"c1\"]")
      incoming.event |> expect.to_equal("op")
    }),
    it("rejects non-event packets", fn() {
      frame.decode("40")
      |> expect.to_be_error
      Nil
    }),
  ])
}

pub fn codec_tests() {
  describe("dewdrop", [
    it("encodes connect_document", fn() {
      dewdrop.encode_connect(json.object([#("id", json.string("doc"))]))
      |> expect.to_equal("42[\"connect_document\",{\"id\":\"doc\"}]")
    }),
    it("encodes submitOp with client id and messages", fn() {
      dewdrop.encode_submit_op(json.string("c1"), json.preprocessed_array([]))
      |> expect.to_equal("42[\"submitOp\",\"c1\",[]]")
    }),
    it("builds an aquamarine codec with a join frame", fn() {
      let codec = dewdrop.codec()

      codec.encode_join(
        "join-1",
        "doc",
        json.object([#("id", json.string("doc"))]),
      )
      |> expect.to_equal("42[\"connect_document\",\"join-1\",{\"id\":\"doc\"}]")
    }),
    it(
      "decodes connect_document_success replies as aquamarine reply frames",
      fn() {
        let codec = dewdrop.codec()

        let assert Ok(incoming) =
          codec.decode(
            "42[\"connect_document_success\",\"join-1\",{\"status\":\"ok\"}]",
          )

        incoming.event |> expect.to_equal("connect_document_success")
        incoming.ref |> expect.to_equal(option.Some("join-1"))
      },
    ),
  ])
}
