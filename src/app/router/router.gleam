import app/router/auth
import app/router/conversations
import app/web

import gleam/io
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: web.Context) -> Response {
  use req <- web.middleware(req)

  io.debug("path")
  io.debug(req.path)
  case wisp.path_segments(req) {
    ["auth", ..path] -> auth.handle(path, req, ctx)
    ["conversations", ..path] -> conversations.handle(path, req, ctx)
    _ -> wisp.not_found()
  }
}
