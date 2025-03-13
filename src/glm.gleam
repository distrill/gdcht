import app/router/router
import app/web

import envoy
import gleam/erlang/process
import gleam/option.{None}
import gleam/result
import mist
import pog
import wisp
import wisp/wisp_mist

pub type User {
  User(username: String, pw_hash: String)
}

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let db =
    pog.url_config(envoy.get("DATABASE_URL") |> result.unwrap(""))
    |> result.unwrap(pog.default_config())
    |> fn(config) { pog.Config(..config, rows_as_map: True) }
    |> pog.connect

  let context = web.Context(db, None)
  let handler = router.handle(_, context)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
