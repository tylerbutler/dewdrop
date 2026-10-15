import aquamarine/codec as aquamarine_codec
import dewdrop
import gleam/json
import gleam/option

pub fn encodes_connect_document_test() -> Nil {
  assert dewdrop.encode_connect(json.object([#("id", json.string("doc"))]))
    == "42[\"connect_document\",{\"id\":\"doc\"}]"
}

pub fn encodes_submit_op_with_client_id_and_messages_test() -> Nil {
  assert dewdrop.encode_submit_op(
      json.string("c1"),
      json.preprocessed_array([]),
    )
    == "42[\"submitOp\",\"c1\",[]]"
}

pub fn builds_an_aquamarine_codec_with_a_join_frame_test() -> Nil {
  let codec = dewdrop.codec()

  assert codec.encode_join(
      "join-1",
      "doc",
      json.object([#("id", json.string("doc"))]),
    )
    == "42[\"connect_document\",\"join-1\",{\"id\":\"doc\"}]"
}

pub fn has_no_leave_frame_test() -> Nil {
  // Fluid clients leave a document by dropping the socket, so there is no
  // leave event to encode.
  assert dewdrop.codec().leave_event == ""
}

pub fn decodes_pong_without_matching_a_pending_reply_test() -> Nil {
  let codec = dewdrop.codec()
  let assert Ok(incoming) = codec.decode("3")
  assert incoming.topic == codec.heartbeat_topic
  assert incoming.ref == option.None
  assert !codec.matches_reply(incoming, "join-1")
  let assert Error(_) = dewdrop.decode("3")
  Nil
}

pub fn decodes_connect_document_success_as_reply_frame_test() -> Nil {
  let codec = dewdrop.codec()

  let assert Ok(incoming) =
    codec.decode(
      "42[\"connect_document_success\",\"join-1\",{\"status\":\"ok\"}]",
    )

  assert incoming.event == "connect_document_success"
  assert incoming.ref == option.Some("join-1")
}

pub fn does_not_match_uncorrelated_join_replies_test() -> Nil {
  let codec = dewdrop.codec()
  let assert Ok(success) =
    codec.decode("42[\"connect_document_success\",{\"status\":\"ok\"}]")
  assert success.ref == option.None
  assert !codec.matches_reply(success, "join-1")
  let assert Ok(rejection) =
    codec.decode("42[\"connect_document_error\",{\"reason\":\"rejected\"}]")
  assert rejection.ref == option.None
  assert !codec.matches_reply(rejection, "join-1")
}

pub fn rejects_non_string_join_reply_references_test() -> Nil {
  let codec = dewdrop.codec()
  assert codec.decode("42[\"connect_document_success\",1,{\"status\":\"ok\"}]")
    == Error(aquamarine_codec.InvalidFormat(
      "Join reply reference must be a string",
    ))
  assert codec.decode("42[\"connect_document_error\",1,{}]")
    == Error(aquamarine_codec.InvalidFormat(
      "Join reply reference must be a string",
    ))
}

pub fn rejects_a_join_when_the_error_reply_has_no_reason_test() -> Nil {
  let codec = dewdrop.codec()
  let assert Ok(incoming) =
    codec.decode("42[\"connect_document_error\",\"join-1\",{}]")
  assert codec.matches_reply(incoming, "join-1")
  assert codec.reply_status(incoming) == Error("join rejected")
}

pub fn does_not_match_a_non_reply_event_with_a_reference_test() -> Nil {
  let codec = dewdrop.codec()
  let assert Ok(incoming) = codec.decode("42[\"op\",\"join-1\",{}]")
  let incoming =
    aquamarine_codec.Incoming(..incoming, ref: option.Some("join-1"))
  assert !codec.matches_reply(incoming, "join-1")
}
