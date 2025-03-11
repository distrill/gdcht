import app/db
import app/util/api
import app/util/error
import app/web

import beecrypt
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/json
import gleam/result
import gwt
import ids/nanoid
import wisp.{type Request, type Response}

type LoginData {
  LoginData(username: String, pw: String)
}

fn login_data_decoder() -> decode.Decoder(LoginData) {
  use username <- decode.field("username", decode.string)
  use pw <- decode.field("pw", decode.string)
  decode.success(LoginData(username:, pw:))
}

fn decode_login_data(body: dynamic.Dynamic) {
  case decode.run(body, login_data_decoder()) {
    Ok(data) -> Ok(data)
    Error(_) -> error.input_error("username and pw are required fields")
  }
}

pub fn gen_jwt(user: db.User) {
  gwt.new()
  |> gwt.set_jwt_id(nanoid.generate())
  |> gwt.set_payload_claim(
    "user",
    json.object([
      #("id", json.string(user.id)),
      #("username", json.string(user.username)),
    ]),
  )
  |> gwt.to_signed_string(gwt.HS256, "this is the hook.")
}

pub fn handle(path: List(String), req: Request, ctx: web.Context) -> Response {
  case path {
    ["signup"] -> handle_signup(req, ctx)
    ["login"] -> handle_login(req, ctx)
    ["logout"] -> handle_logout(req, ctx)
    _ -> wisp.not_found()
  }
}

fn handle_signup(req: Request, ctx: web.Context) -> Response {
  case req.method {
    Post -> handle_post_signup(req, ctx)
    _ -> wisp.method_not_allowed(allowed: [Post])
  }
}

fn handle_login(req: Request, ctx: web.Context) -> Response {
  case req.method {
    Post -> handle_post_login(req, ctx)
    _ -> wisp.method_not_allowed(allowed: [Post])
  }
}

fn handle_logout(req: Request, ctx: web.Context) -> Response {
  case req.method {
    Post -> handle_post_logout(req, ctx)
    _ -> wisp.method_not_allowed(allowed: [Post])
  }
}

fn handle_post_signup(req: Request, ctx: web.Context) -> Response {
  use body <- wisp.require_json(req)

  let result = {
    use data <- result.try(decode_login_data(body))
    use user <- result.try(db.create_user(
      ctx.db,
      db.NewUser(data.username, beecrypt.hash(data.pw)),
    ))

    Ok(json.object([#("token", json.string(gen_jwt(user)))]))
  }

  case result {
    Ok(data) -> api.json(data)
    Error(err) -> error.json(err)
  }
}

fn handle_post_login(_req: Request, _ctx: web.Context) -> Response {
  wisp.not_found()
}

fn handle_post_logout(_req: Request, _ctx: web.Context) -> Response {
  wisp.not_found()
}
