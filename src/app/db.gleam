import app/util/error

import gleam/dynamic/decode
import gleam/option.{type Option}
import pog.{type Connection}

pub type User {
  User(id: String, username: String, pw_hash: String)
}

pub type NewUser {
  NewUser(username: String, pw_hash: String)
}

pub type Conversation {
  Conversation(id: String, name: Option(String))
}

pub fn fetch_users(db: Connection) -> Result(List(User), error.Error) {
  let sql_query =
    "
    SELECT * FROM \"user\"
  "

  let row_decoder = {
    use id <- decode.field("id", decode.string)
    use username <- decode.field("username", decode.string)
    use pw_hash <- decode.field("pw_hash", decode.string)
    decode.success(User(id:, username:, pw_hash:))
  }

  case
    pog.query(sql_query)
    |> pog.returning(row_decoder)
    |> pog.execute(db)
  {
    Ok(returned) -> Ok(returned.rows)
    Error(err) -> error.db_error(err)
  }
}

pub fn create_user(db: Connection, user: NewUser) -> Result(User, error.Error) {
  let sql_query =
    "
    INSERT INTO
      \"user\" (username, pw_hash)
    VALUES
      ($1, $2)
    RETURNING *
  "
  let row_decoder = {
    use id <- decode.field("id", decode.string)
    use username <- decode.field("username", decode.string)
    use pw_hash <- decode.field("pw_hash", decode.string)
    decode.success(User(id:, username:, pw_hash:))
  }
  case
    pog.query(sql_query)
    |> pog.parameter(pog.text(user.username))
    |> pog.parameter(pog.text(user.pw_hash))
    |> pog.returning(row_decoder)
    |> pog.execute(db)
  {
    Ok(returned) -> {
      case returned.rows {
        [user, ..] -> Ok(user)
        _ -> error.internal_error()
      }
    }
    Error(pog.ConstraintViolated(..)) ->
      error.input_error("username already exists")
    Error(err) -> error.db_error(err)
  }
}

pub fn fetch_conversations(
  db: Connection,
  user_id: String,
) -> Result(List(Conversation), error.Error) {
  let sql_query =
    "
    SELECT 
      conversation.id, 
      conversation.name
    FROM conversation
      INNER JOIN conversation_membership 
        ON conversation_membership.conversation_id = conversation.id
    WHERE conversation_membership.user_id = $1
  "

  let row_decoder = {
    use id <- decode.field("id", decode.string)
    use name <- decode.field("name", decode.optional(decode.string))
    decode.success(Conversation(id:, name:))
  }

  case
    pog.query(sql_query)
    |> pog.parameter(pog.text(user_id))
    |> pog.returning(row_decoder)
    |> pog.execute(db)
  {
    Ok(returned) -> Ok(returned.rows)
    Error(err) -> error.db_error(err)
  }
}
