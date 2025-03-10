import app/db
import app/router/error
import app/web
import gleam/io

import gleam/http.{Get}
import gleam/json
import gleam/list
import gleam/result
import wisp.{type Request, type Response}

pub fn handle(req: Request, ctx: web.Context) -> Response {
  case wisp.path_segments(req) {
    ["conversations"] -> handle_conversations(req, ctx)
    _ -> wisp.not_found()
  }
}

fn handle_conversations(req: Request, ctx: web.Context) -> Response {
  case req.method {
    Get -> handle_get_conversations(req, ctx)
    _ -> wisp.method_not_allowed(allowed: [Get])
  }
}

fn get_user_id(req: Request) {
  case wisp.get_query(req) |> list.key_find("user_id") {
    Ok(user_id) -> Ok(user_id)
    _ -> Error(#("user_id is required", 422))
  }
}

fn handle_get_conversations(req: Request, ctx: web.Context) -> Response {
  let result = {
    use user_id <- result.try(get_user_id(req))
    let conversations =
      db.fetch_conversations(ctx.db, user_id)
      |> result.unwrap([])
      |> list.map(fn(conversation) {
        json.object([
          #("id", json.string(conversation.id)),
          #("name", json.nullable(conversation.name, of: json.string)),
        ])
      })
    json.object([#("data", json.preprocessed_array(conversations))])
    |> json.to_string_tree
    |> Ok
  }

  case result {
    Ok(data) -> wisp.json_response(data, 200)
    Error(#(err, code)) -> {
      io.debug(err)
      wisp.json_response(error.to_json_string(err), code)
    }
  }
}
