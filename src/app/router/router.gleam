import app/router/auth
import app/router/conversations
import app/web

import wisp.{type Request, type Response}

pub fn handle(path: List(String), ctx: web.Context) {
  fn(req: Request) -> Response {
    use req <- web.middleware(req)

    case req.method, path {
      _, ["auth", ..path] -> auth.handle(path, req, ctx)
      _, ["conversations", ..path] -> conversations.handle(path, req, ctx)
      _, _ -> wisp.not_found()
    }
  }
}
