import app/db
import app/util/api
import app/util/error
import app/web

import beecrypt
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/http/request
import gleam/json
import gleam/option.{Some}
import gleam/result
import gleam/string
import gwt.{type Jwt}
import ids/nanoid
import wisp.{type Request, type Response}

const secret = "this is the hook."

/// main router function, entry point for authentication endpoints
pub fn handle(path: List(String), req: Request, ctx: web.Context) -> Response {
  case path {
    ["signup"] -> handle_signup(req, ctx)
    ["login"] -> handle_login(req, ctx)
    ["logout"] -> handle_logout(req, ctx)
    _ -> wisp.not_found()
  }
}

/// middleware to gate endpoints behind authorization
pub fn authenticate(
  req: Request,
  ctx: web.Context,
  next: fn(web.Context) -> Response,
) -> Response {
  case
    Ok(req)
    |> result.try(get_token_from_request)
    |> result.try(ensure_token_not_blocked)
    |> result.try(parse_user_from_token)
  {
    Ok(user) -> {
      next(web.Context(..ctx, user: Some(user)))
    }
    _ -> error.json(error.unauthorized())
  }
}

type LoginData {
  LoginData(username: String, pw: String)
}

fn login_data_decoder() -> decode.Decoder(LoginData) {
  use username <- decode.field("username", decode.string)
  use pw <- decode.field("pw", decode.string)
  decode.success(LoginData(username:, pw:))
}

fn decode_login_data(body: dynamic.Dynamic) -> Result(LoginData, error.Error) {
  case decode.run(body, login_data_decoder()) {
    Ok(data) -> Ok(data)
    Error(_) -> error.input_error("username and pw are required fields")
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

fn gen_jwt(user: db.User) {
  gwt.new()
  |> gwt.set_jwt_id(nanoid.generate())
  |> gwt.set_payload_claim(
    "user",
    json.object([
      #("id", json.string(user.id)),
      #("username", json.string(user.username)),
    ]),
  )
  |> gwt.to_signed_string(gwt.HS256, secret)
}

fn parse_token(verified: Jwt(gwt.Verified)) {
  gwt.get_payload_claim(
    verified,
    "user",
    fn() {
      use id <- decode.field("id", decode.string)
      use username <- decode.field("username", decode.string)
      decode.success(db.User(id:, username:, pw_hash: "--"))
    }(),
  )
}

fn parse_user_from_token(token: String) -> Result(db.User, error.Error) {
  Ok(token)
  |> result.try(gwt.from_signed_string(_, secret))
  |> result.try(parse_token)
  |> result.replace_error(error.unauthorized())
}

fn get_header(req: Request, key: String) {
  case request.get_header(req, key) {
    Ok(header) -> Ok(header)
    Error(_) -> error.input_error(key <> " header is required")
  }
}

fn get_token_from_request(req: Request) -> Result(String, error.Error) {
  get_header(req, "Authorization")
  |> result.map(fn(header) { string.split(header, "Bearer ") })
  |> result.then(fn(words) {
    case words {
      ["", token] -> Ok(token)
      _ -> Error(error.unauthorized())
    }
  })
}

fn ensure_token_not_blocked(token: String) -> Result(String, error.Error) {
  // read from token blocklist table, updated on logout
  Ok(token)
}
