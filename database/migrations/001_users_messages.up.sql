BEGIN TRANSACTION;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS "user" (
  id text PRIMARY KEY DEFAULT 'user.' || encode(gen_random_bytes(10), 'hex') NOT NULL,
  username text NOT NULL,
  pw_hash text NOT NULL,

  UNIQUE(username)
);

CREATE TABLE IF NOT EXISTS "conversation" (
  id text PRIMARY KEY DEFAULT 'conversation.' || encode(gen_random_bytes(10), 'hex') NOT NULL,
  name text
);

CREATE TABLE IF NOT EXISTS "conversation_membership" (
  id text PRIMARY KEY DEFAULT 'conversation_membership.' || encode(gen_random_bytes(10), 'hex') NOT NULL,
  user_id text NOT NULL,
  conversation_id text NOT NULL,

  UNIQUE(user_id, conversation_id)
);


CREATE TABLE IF NOT EXISTS "message" (
  id text PRIMARY KEY DEFAULT 'message.' || encode(gen_random_bytes(10), 'hex') NOT NULL,
  ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  content text NOT NULL,
  user_id text NOT NULL,
  conversation_id text NOT NULL,

  CONSTRAINT fk_message_actor 
    FOREIGN KEY (user_id)
      REFERENCES "user"(id),
  CONSTRAINT fk_message_conversation
    FOREIGN KEY (conversation_id)
      REFERENCES "conversation"(id)
);

CREATE TABLE IF NOT EXISTS "token_blocklist" (
  id text PRIMARY KEY
);

COMMIT;
