import gleam/dynamic/decode
import gleam/json
import gleam/string
import gleam/string_tree
import pog
import wisp.{type Response}

pub type Error {
  InputError(String)
  DatabaseError(pog.QueryError)
  InvariantError(String)
  DecodeError(List(decode.DecodeError))
  JsonDecodeError(json.DecodeError)
  InternalError(String)
  UnauthorizedError
  ForbiddenError
  NotFoundError
}

pub fn input_error(msg: String) {
  Error(InputError(msg))
}

pub fn db_error(err: pog.QueryError) {
  Error(DatabaseError(err))
}

pub fn invariant(msg: String) {
  Error(InvariantError(msg))
}

pub fn decode_error(errs: List(decode.DecodeError)) {
  Error(DecodeError(errs))
}

pub fn json_decode_error(err: json.DecodeError) {
  Error(JsonDecodeError(err))
}

pub fn internal_error(msg: String) {
  Error(InternalError(msg))
}

pub fn internal_error_from_message(msg: String) {
  Error(msg)
}

pub fn unauthorized() {
  UnauthorizedError
}

pub fn forbidden() {
  ForbiddenError
}

pub fn not_found() {
  NotFoundError
}

fn to_json_string(msg: String) -> string_tree.StringTree {
  json.to_string_tree(json.object([#("error", json.string(msg))]))
}

pub fn json(err: Error) -> Response {
  wisp.log_warning(string.inspect(err))
  case err {
    InputError(err) -> wisp.json_response(to_json_string(err), 422)
    UnauthorizedError -> wisp.json_response(to_json_string("unauthorized"), 401)
    ForbiddenError -> wisp.json_response(to_json_string("forbidden"), 403)
    NotFoundError -> wisp.json_response(to_json_string("not found"), 404)
    _ -> wisp.json_response(to_json_string("something went wrong"), 500)
  }
}

pub fn handle_not_found() {
  json(not_found())
}
