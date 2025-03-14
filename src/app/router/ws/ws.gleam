import app/router/ws/pool
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import gleam/string
import ids/nanoid
import mist.{type Connection, type WebsocketConnection}
import wisp

pub type Message {
  Broadcast(String)
}

pub fn handle() {
  let selector = process.new_selector()
  let state = ""
  let assert Ok(broadcaster) = actor.start(dict.new(), pool.handle_message)
  fn(req: Request(Connection)) {
    mist.websocket(
      request: req,
      on_init: handle_init(state, selector, broadcaster),
      on_close: handle_close(broadcaster),
      handler: handle_message(broadcaster),
    )
  }
}

fn handle_init(state, selector, broadcaster) {
  fn(conn) {
    io.debug("socket handle_init - " <> string.inspect(state))
    let id = nanoid.generate()
    let _ = mist.send_text_frame(conn, "welcome!")

    // Store the connection in the actor
    let assert True =
      process.call(
        broadcaster,
        fn(client) { pool.Connect(#(id, conn, process.self()), client) },
        10,
      )

    // Return the connection ID so that the WebSocket handler knows its ID
    #(id, Some(selector))
  }
}

fn handle_close(broadcaster) {
  fn(state) {
    io.debug("socket handle_close - " <> string.inspect(state))
    let assert True =
      process.call(
        broadcaster,
        fn(client) { pool.Disconnect(state, client) },
        10,
      )
    wisp.log_debug("goodbye!")
  }
}

fn handle_message(broadcaster) {
  fn(state, _, message) {
    case message {
      mist.Text(text) -> {
        wisp.log_debug("ws text 02: " <> text)
        let connections = process.call(broadcaster, pool.GetConnections, 5)
        list.each(connections, fn(connection_data) {
          let #(pid, connection) = connection_data
          process.send(pid, fn(_) { mist.send_text_frame(connection, text) })
        })
        actor.continue(state)
      }
      mist.Binary(_) -> {
        wisp.log_warning("unexpected websocket binary message")
        actor.continue(state)
      }
      mist.Custom(_) -> {
        wisp.log_warning("unexpected websocket custom message")
        actor.continue(state)
      }
      mist.Closed -> {
        wisp.log_debug("ws closed")
        actor.Stop(process.Normal)
      }
      mist.Shutdown -> {
        wisp.log_debug("ws shut down")
        actor.Stop(process.Normal)
      }
    }
  }
}
