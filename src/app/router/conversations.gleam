import app/db
import app/util/api
import app/util/error
import app/web

import gleam/http.{Get}
import gleam/json
import gleam/list
import gleam/result
import wisp.{type Request, type Response}

pub fn handle(path: List(string), req: Request, ctx: web.Context) -> Response {
  case path {
    [] -> handle_conversations(req, ctx)
    _ -> wisp.not_found()
  }
}

fn handle_conversations(req: Request, ctx: web.Context) -> Response {
  case req.method {
    Get -> handle_get_conversations(req, ctx)
    _ -> wisp.method_not_allowed(allowed: [Get])
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
