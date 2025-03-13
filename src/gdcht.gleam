import app/router/router
import app/web
import config

import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{None}
import gleam/result
import mist.{type Connection, type ResponseData}
import pog
import wisp

import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let db =
    pog.url_config(config.database_url())
    |> result.unwrap(pog.default_config())
    |> fn(config) { pog.Config(..config, rows_as_map: True) }
    |> pog.connect

  let context = web.Context(db, None)

  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        ["api", ..path] ->
          wisp_mist.handler(
            router.handle(path, context),
            config.session_secret(),
          )(req)
        _ ->
          response.new(404)
          |> response.set_body(mist.Bytes(bytes_tree.new()))
      }
    }
    |> mist.new
    |> mist.port(config.port())
    |> mist.start_http

  process.sleep_forever()
}
