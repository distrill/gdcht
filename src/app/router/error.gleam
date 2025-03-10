import gleam/json
import gleam/string_tree

pub fn to_json_string(msg: String) -> string_tree.StringTree {
  json.to_string_tree(json.object([#("error", json.string(msg))]))
}
