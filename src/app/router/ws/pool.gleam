import gleam/dict.{type Dict}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string
import mist.{type WebsocketConnection}
import wisp

type State =
  Dict(String, #(Subject(fn() -> String), WebsocketConnection))

pub type Message {
  Shutdown

  Connect(
    data: #(String, WebsocketConnection, Subject(fn() -> String)),
    reply_with: Subject(Bool),
  )

  Disconnect(id: String, reply_with: Subject(Bool))

  Broadcast(data: #(String, String), reply_with: Subject(Bool))

  GetConnections(
    reply_with: Subject(List(#(Subject(fn() -> String), WebsocketConnection))),
  )
}

pub fn handle_message(
  message: Message,
  state: State,
) -> actor.Next(Message, State) {
  case message {
    Shutdown -> actor.Stop(process.Normal)

    Connect(data, client) -> {
      let #(id, connection, pid) = data
      let new_state = dict.insert(state, id, #(pid, connection))
      wisp.log_debug(
        "broadcast init - "
        <> int.to_string(dict.size(state))
        <> " -> "
        <> int.to_string(dict.size(new_state)),
      )
      io.debug(new_state)
      process.send(client, True)
      actor.continue(new_state)
    }

    Disconnect(id, client) -> {
      let new_state = dict.delete(state, id)
      wisp.log_debug("broadcast disconnect - " <> string.inspect(new_state))
      process.send(client, True)
      actor.continue(new_state)
    }

    Broadcast(data, client) -> {
      let #(_sender_id, message) = data
      wisp.log_debug("broadcast broadcast- " <> string.inspect(state))
      dict.to_list(state)
      |> list.each(fn(connection) {
        let #(_id, #(sender, conn)) = connection
        process.send(sender, fn() { message })
        mist.send_text_frame(conn, message)
        // case id == sender_id {
        //   True -> Nil
        //   False -> {
        //     let _ = mist.send_text_frame(conn, message)
        //     Nil
        // }
        // }
      })
      process.send(client, True)
      actor.continue(state)
    }
    GetConnections(client) -> {
      process.send(client, dict.values(state))
      actor.continue(state)
    }
  }
}
