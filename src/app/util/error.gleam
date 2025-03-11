import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/string_tree
import pog
import wisp.{type Response}

pub type Error {
  InputError(String)
  DatabaseError(pog.QueryError)
  InvariantError(String)
  DecodeError(List(decode.DecodeError))
  InternalError
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

pub fn internal_error() {
  Error(InternalError)
}

fn to_json_string(msg: String) -> string_tree.StringTree {
  json.to_string_tree(json.object([#("error", json.string(msg))]))
}

pub fn json(err: Error) -> Response {
  io.debug(err)
  case err {
    InputError(err) -> wisp.json_response(to_json_string(err), 422)
    _ -> wisp.json_response(to_json_string("something went wrong"), 500)
  }
}
