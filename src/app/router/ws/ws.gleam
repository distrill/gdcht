import app/router/ws/pool
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/io
import gleam/list
import gleam/option.{None, Some}
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

fn handle_init(state, _selector, broadcaster) {
  fn(conn) {
    io.debug("socket handle_init - " <> string.inspect(state))
    let id = nanoid.generate()
    let _ = mist.send_text_frame(conn, "welcome!")
    let subject = process.new_subject()

    // Store the connection in the actor
    let assert True =
      process.call(
        broadcaster,
        fn(client) { pool.Connect(#(id, conn, subject), client) },
        10,
      )

    // io

    let thing = process.receive_forever(subject)()
    io.debug("THING" <> thing)
    //   Ok(msg) -> {
    //     io.debug("received message: " <> msg())
    //   }
    //   _ -> {
    //     io.debug("no message")
    //   }
    // }
    // process.spawn{
    //   }
    // process.receive_forever(subject)

    // Return the connection ID so that the WebSocket handler knows its ID
    #(id, None)
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
  fn(state, _conn, message) {
    case message {
      mist.Text(text) -> {
        wisp.log_debug("ws text 02: " <> text)
        // let connections = process.call(broadcaster, pool.GetConnections, 5)
        // wisp.log_debug(
        //   string.inspect(list.length(connections))
        //   <> " connections: "
        //   <> " ("
        //   <> string.inspect(process.self())
        //   <> ")",
        // )
        let _ =
          process.call(
            broadcaster,
            fn(client) { pool.Broadcast(#(state, text), client) },
            10,
          )
        // list.each(connections, fn(connection_data) {
        //   let #(_subject, _connection) = connection_data
        //   // process.send(subject, fn() {
        //   //   let _ = mist.send_text_frame(connection, text)
        //   //   Nil
        //   // })
        // })
        actor.continue(state)
      }
      mist.Binary(_) -> {
        io.debug("i think this is binary")
        // wisp.log_warning("unexpected websocket binary message")
        actor.continue(state)
      }
      mist.Custom(Broadcast(msg)) -> {
        io.debug("BROADCASTING MESSAGE: " <> msg)
        // wisp.log_warning("unexpected websocket custom message")
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
