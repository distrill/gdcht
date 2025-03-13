import app/db
import app/util/api
import app/util/error
import app/web
import config

import beecrypt
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/http/request
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gwt.{type Jwt}
import ids/nanoid
import pog
import wisp.{type Request, type Response}

/// main router function, entry point for authentication endpoints
pub fn handle(path: List(String), req: Request, ctx: web.Context) -> Response {
  case req.method, path {
    Post, ["signup"] -> handle_post_signup(req, ctx)
    Post, ["login"] -> handle_post_login(req, ctx)
    Post, ["logout"] -> handle_post_logout(req, ctx)
    _, _ -> wisp.not_found()
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
    |> result.try(verify_token)
    |> result.try(ensure_token_not_blocked(_, ctx.db))
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

pub fn parse_body(req: Request) -> Result(dynamic.Dynamic, error.Error) {
  case
    Ok(req)
    |> result.try(wisp.read_body_to_bitstring)
    |> result.try(bit_array.to_string)
    |> result.try(fn(str) {
      case json.decode(str, Ok) {
        Ok(data) -> Ok(data)
        Error(_) -> Error(Nil)
      }
    })
  {
    Ok(data) -> Ok(data)
    _ -> error.input_error("malformed body")
  }
}

fn handle_post_signup(req: Request, ctx: web.Context) -> Response {
  case
    Ok(req)
    |> result.try(parse_body)
    |> result.try(decode_login_data)
    |> result.try(create_user(_, ctx.db))
    |> result.map(gen_jwt)
  {
    Ok(data) -> api.json(data)
    Error(err) -> error.json(err)
  }
}

fn handle_post_login(req: Request, ctx: web.Context) -> Response {
  case
    Ok(req)
    |> result.try(parse_body)
    |> result.try(decode_login_data)
    |> result.try(verify_credentials(_, ctx.db))
    |> result.map(gen_jwt)
  {
    Ok(data) -> api.json(data)
    Error(err) -> error.json(err)
  }
}

fn handle_post_logout(req: Request, ctx: web.Context) -> Response {
  case
    Ok(req)
    |> result.try(get_token_from_request)
    |> result.try(verify_token)
    |> result.try(get_token_id)
    |> result.try(db.create_token_blocklist(ctx.db, _))
  {
    Ok(_) -> api.json(json.string("ok"))
    Error(err) -> error.json(err)
  }
}

fn create_user(login_data: LoginData, db: pog.Connection) {
  db.create_user(
    db,
    db.NewUser(login_data.username, beecrypt.hash(login_data.pw)),
  )
}

// returns a user from the database if password matches
fn verify_credentials(
  login_data: LoginData,
  db: pog.Connection,
) -> Result(db.User, error.Error) {
  Ok(db)
  |> result.try(db.fetch_user(_, login_data.username))
  |> result.try(compare_passwords(_, login_data.pw))
}

fn compare_passwords(user: db.User, pw: String) -> Result(db.User, error.Error) {
  case beecrypt.verify(pw, user.pw_hash) {
    True -> Ok(user)
    False -> Error(error.unauthorized())
  }
}

fn gen_jwt(user: db.User) {
  let token =
    gwt.new()
    |> gwt.set_jwt_id(nanoid.generate())
    |> gwt.set_payload_claim(
      "user",
      json.object([
        #("id", json.string(user.id)),
        #("username", json.string(user.username)),
      ]),
    )
    |> gwt.to_signed_string(gwt.HS256, config.auth_secret())
  json.object([#("token", json.string(token))])
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

fn verify_token(token: String) -> Result(gwt.Jwt(gwt.Verified), error.Error) {
  Ok(token)
  |> result.try(gwt.from_signed_string(_, config.auth_secret()))
  |> result.replace_error(error.unauthorized())
}

fn parse_user_from_token(
  token: gwt.Jwt(gwt.Verified),
) -> Result(db.User, error.Error) {
  Ok(token)
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

fn is_token_blocklist(
  id: String,
  db: pog.Connection,
) -> Result(Bool, error.Error) {
  use maybe_token <- result.try(db.fetch_token_blocklist(db, id))
  case maybe_token {
    Some(_) -> Ok(True)
    None -> Ok(False)
  }
}

fn get_token_id(token: gwt.Jwt(gwt.Verified)) -> Result(String, error.Error) {
  gwt.get_jwt_id(token) |> result.replace_error(error.unauthorized())
}

fn ensure_token_not_blocked(
  token: gwt.Jwt(gwt.Verified),
  db: pog.Connection,
) -> Result(gwt.Jwt(gwt.Verified), error.Error) {
  let is_token_blocklist =
    Ok(token)
    |> result.try(get_token_id)
    |> result.try(is_token_blocklist(_, db))

  case is_token_blocklist {
    Ok(False) -> Ok(token)
    _ -> Error(error.unauthorized())
  }
}
