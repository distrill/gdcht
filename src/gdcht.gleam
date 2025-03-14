import app/router/router
import app/web
import config

import gleam/erlang/process
import gleam/option.{None}
import gleam/result
import pog
import wisp

pub fn main() {
  wisp.configure_logger()
  wisp.set_logger_level(wisp.DebugLevel)

  let db =
    pog.url_config(config.database_url())
    |> result.unwrap(pog.default_config())
    |> fn(config) { pog.Config(..config, rows_as_map: True) }
    |> pog.connect

  let ctx = web.Context(db, None)

  let _ = router.listen(ctx)

  process.sleep_forever()
}
