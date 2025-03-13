import envoy

pub fn database_url() -> String {
  must("DATABASE_URL")
}

pub fn auth_secret() -> String {
  must("AUTH_SECRET")
}

fn must(key: String) -> String {
  case envoy.get(key) {
    Ok(value) -> value
    Error(_) -> panic as { key <> " is not set" }
  }
}
