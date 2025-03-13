import envoy
import gleam/int

pub fn database_url() -> String {
  must("DATABASE_URL")
}

pub fn auth_secret() -> String {
  must("AUTH_SECRET")
}

pub fn session_secret() -> String {
  must("SESSION_SECRET")
}

pub fn port() -> Int {
  may("PORT", "8000") |> must_int()
}

fn must(key: String) -> String {
  case envoy.get(key) {
    Ok(value) -> value
    Error(_) -> panic as { key <> " is not set" }
  }
}

fn must_int(key: String) -> Int {
  case int.parse(key) {
    Ok(value) -> value
    Error(_) -> panic as { key <> " is not a valid integer" }
  }
}

fn may(key: String, default: String) -> String {
  case envoy.get(key) {
    Ok(value) -> value
    Error(_) -> default
  }
}
