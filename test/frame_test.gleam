import dewdrop
import gleam/json
import gleam/option

pub fn encodes_connect_document_test() {
  assert dewdrop.encode_connect(json.object([#("id", json.string("doc"))]))
    == "42[\"connect_document\",{\"id\":\"doc\"}]"
}

pub fn encodes_submit_op_with_client_id_and_messages_test() {
  assert dewdrop.encode_submit_op(
      json.string("c1"),
      json.preprocessed_array([]),
    )
    == "42[\"submitOp\",\"c1\",[]]"
}

pub fn builds_an_aquamarine_codec_with_a_join_frame_test() {
  let codec = dewdrop.codec()

  assert codec.encode_join(
      "join-1",
      "doc",
      json.object([#("id", json.string("doc"))]),
    )
    == "42[\"connect_document\",\"join-1\",{\"id\":\"doc\"}]"
}

pub fn has_no_leave_frame_test() {
  // Fluid clients leave a document by dropping the socket, so there is no
  // leave event to encode.
  assert dewdrop.codec().leave_event == ""
}

pub fn decodes_connect_document_success_as_reply_frame_test() {
  let codec = dewdrop.codec()

  let assert Ok(incoming) =
    codec.decode(
      "42[\"connect_document_success\",\"join-1\",{\"status\":\"ok\"}]",
    )

  assert incoming.event == "connect_document_success"
  assert incoming.ref == option.Some("join-1")
}
