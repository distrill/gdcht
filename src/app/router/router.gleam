import app/router/api/api
import app/router/ws/ws
import app/util/error
import app/web
import config

import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import mist.{type Connection, type ResponseData}
import wisp

import wisp/wisp_mist

pub fn listen(ctx: web.Context) {
  let websocket_handler = ws.handle()
  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        ["api", ..path] ->
          wisp_mist.handler(api.handle(path, ctx), config.session_secret())(req)
        ["ws", ..] -> websocket_handler(req)
        _ -> wisp_mist.handler(fallback, config.session_secret())(req)
      }
    }
    |> mist.new
    |> mist.port(config.port())
    |> mist.start_http
}

fn fallback(_req: wisp.Request) -> wisp.Response {
  error.handle_not_found()
}
