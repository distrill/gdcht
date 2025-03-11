import app/db

import gleam/json.{type Json}
import gleam/string_tree
import wisp.{type Response}

fn to_json_string(data: Json) -> string_tree.StringTree {
  json.to_string_tree(json.object([#("data", data)]))
}

pub fn json(data: Json) -> Response {
  wisp.json_response(to_json_string(data), 200)
}

pub fn user_to_json(user: db.User) -> json.Json {
  json.object([
    #("id", json.string(user.id)),
    #("username", json.string(user.username)),
  ])
}

pub fn conversation_to_json(conversation: db.Conversation) -> json.Json {
  json.object([
    #("id", json.string(conversation.id)),
    #("name", json.nullable(conversation.name, of: json.string)),
  ])
}
