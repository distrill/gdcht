import app/db
import app/router/auth
import app/util/api
import app/util/error
import app/web

import gleam/http.{Get}
import gleam/json
import gleam/list
import gleam/result
import wisp.{type Request, type Response}

pub fn handle(path: List(string), req: Request, ctx: web.Context) -> Response {
  use ctx <- auth.authenticate(req, ctx)

  case req.method, path {
    Get, [] -> handle_get_conversations(req, ctx)
    _, _ -> wisp.not_found()
  }
}

fn get_param(query: List(#(String, String)), key: String) {
  case query |> list.key_find(key) {
    Ok(user_id) -> Ok(user_id)
    _ -> error.input_error("user_id is required")
  }
}

fn handle_get_conversations(req: Request, ctx: web.Context) -> Response {
  let result = {
    use user_id <- result.try(
      req
      |> wisp.get_query()
      |> get_param("user_id"),
    )
    db.fetch_conversations(ctx.db, user_id)
    |> result.unwrap([])
    |> list.map(api.conversation_to_json)
    |> json.preprocessed_array
    |> Ok
  }

  case result {
    Ok(data) -> api.json(data)
    Error(err) -> error.json(err)
  }
}
