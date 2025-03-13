import app/router/auth
import app/router/conversations
import app/web

import wisp.{type Request, type Response}

pub fn handle(req: Request, ctx: web.Context) -> Response {
  use req <- web.middleware(req)

  case req.method, wisp.path_segments(req) {
    _, ["auth", ..path] -> auth.handle(path, req, ctx)
    _, ["conversations", ..path] -> conversations.handle(path, req, ctx)
    _, _ -> wisp.not_found()
  }
}
