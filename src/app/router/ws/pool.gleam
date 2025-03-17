import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

pub type GdChtMessage {
  GdChtBroadcast(String)
}

type State =
  Dict(String, Subject(GdChtMessage))

pub type Message {
  Shutdown

  Connect(data: #(String, Subject(GdChtMessage)), reply_with: Subject(Bool))

  Disconnect(id: String, reply_with: Subject(Bool))

  Broadcast(data: #(String, String), reply_with: Subject(Bool))
}

pub fn handle_message(
  message: Message,
  state: State,
) -> actor.Next(Message, State) {
  case message {
    Shutdown -> actor.Stop(process.Normal)

    Connect(data, client) -> {
      let #(id, subject) = data
      let new_state = dict.insert(state, id, subject)
      process.send(client, True)
      actor.continue(new_state)
    }

    Disconnect(id, client) -> {
      let new_state = dict.delete(state, id)
      process.send(client, True)
      actor.continue(new_state)
    }

    Broadcast(data, client) -> {
      let #(sender_id, message) = data
      dict.to_list(state)
      |> list.each(fn(connection) {
        let #(id, subject) = connection
        case sender_id == id {
          False -> process.send(subject, GdChtBroadcast(message))
          True -> Nil
        }
      })
      process.send(client, True)
      actor.continue(state)
    }
  }
}
