import aquamarine/channel
import aquamarine/error
import aquamarine/socket
import aquamarine/transport
import beryl/wire/codec
import dewdrop
import dewdrop/server
import gleam/erlang/process.{type Subject}
import gleam/json

pub fn pong_does_not_fail_a_pending_join_or_reach_a_channel_test() -> Nil {
  let #(socket, sink) =
    start_socket(fn(sink, text) {
      process.send(sink, transport.Text("3"))
      accept_join(sink, text)
    })
  let joined = channel.join(socket, "document:t1:d1", join_payload(), 1000)
  process.send(sink, transport.Text("3"))
  let assert Ok(Nil) = socket.close(socket)

  let assert Ok(channel) = joined
  assert channel.receive(channel, 1000) == Error(error.ChannelClosed)
  assert channel.receive(channel, 0) == Error(error.Transport(error.Timeout))
}

fn start_socket(
  send_text: fn(Subject(transport.Frame), String) -> Nil,
) -> #(socket.Socket, Subject(transport.Frame)) {
  let connected = process.new_subject()
  let connector = fn(sink) {
    process.send(connected, sink)
    Ok(
      transport.Transport(
        send_text: fn(text) { send_text(sink, text) },
        close: fn() { Ok(Nil) },
      ),
    )
  }
  let assert Ok(socket) =
    socket.test_config(connector, dewdrop.codec())
    |> socket.with_heartbeat_ms(86_400_000)
    |> socket.start
  let assert Ok(sink) = process.receive(connected, 1000)
  #(socket, sink)
}

fn join_payload() -> json.Json {
  json.object([
    #("tenantId", json.string("t1")),
    #("documentId", json.string("d1")),
  ])
}

fn accept_join(sink: Subject(transport.Frame), text: String) -> Nil {
  let server_codec = server.server_codec()
  let assert Ok(inbound) = codec.apply_decode_text(server_codec, text)
  case codec.inbound_kind(inbound) {
    codec.Join -> {
      let assert codec.TextFrame(reply) =
        codec.apply_encode_reply(
          server_codec,
          codec.inbound_join_ref(inbound),
          codec.inbound_ref(inbound),
          codec.inbound_topic(inbound),
          codec.StatusOk,
          json.object([#("status", json.string("ok"))]),
        )
      process.send(sink, transport.Text(reply))
    }
    codec.Event(_) | codec.Heartbeat | codec.Leave -> Nil
  }
}
