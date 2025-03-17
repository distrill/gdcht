import app/router/ws/pool
import gleam/dict
import gleam/erlang/process
import gleam/function
import gleam/http/request.{type Request}
import gleam/option.{Some}
import gleam/otp/actor
import ids/nanoid
import mist.{type Connection}
import wisp

pub fn handle() {
  let assert Ok(broadcaster) = actor.start(dict.new(), pool.handle_message)
  fn(req: Request(Connection)) {
    mist.websocket(
      request: req,
      on_init: handle_init(broadcaster),
      on_close: handle_close(broadcaster),
      handler: handle_message(broadcaster),
    )
  }
}

fn handle_init(broadcaster) {
  fn(conn) {
    let id = nanoid.generate()
    let _ = mist.send_text_frame(conn, "welcome!")

    let subject = process.new_subject()
    let selector =
      process.new_selector() |> process.selecting(subject, function.identity)

    let assert True =
      process.call(
        broadcaster,
        fn(client) { pool.Connect(#(id, subject), client) },
        10,
      )

    #(id, Some(selector))
  }
}

fn handle_close(broadcaster) {
  fn(state) {
    let assert True =
      process.call(
        broadcaster,
        fn(client) { pool.Disconnect(state, client) },
        10,
      )
    Nil
  }
}

fn handle_message(broadcaster) {
  fn(state, conn, message) {
    case message {
      mist.Text(text) -> {
        let _ =
          process.call(
            broadcaster,
            fn(client) { pool.Broadcast(#(state, text), client) },
            10_000,
          )
        actor.continue(state)
      }
      mist.Binary(_) -> {
        actor.continue(state)
      }
      mist.Custom(pool.BroadcastMessage(msg)) -> {
        let _ = mist.send_text_frame(conn, msg)
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
