import app/router/conversations
import app/web

import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: web.Context) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    ["conversations"] -> conversations.handle(req, ctx)
    _ -> wisp.not_found()
  }
}
