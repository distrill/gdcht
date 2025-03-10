BEGIN TRANSACTION;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS "user" (
  id text PRIMARY KEY DEFAULT 'user.' || encode(gen_random_bytes(10), 'hex') NOT NULL,
  username text NOT NULL,
  pw_hash text NOT NULL
);

CREATE TABLE IF NOT EXISTS "conversation" (
  id text PRIMARY KEY DEFAULT 'conversation.' || encode(gen_random_bytes(10), 'hex') NOT NULL,
  name text
);

CREATE TABLE IF NOT EXISTS "conversation_membership" (
  id text PRIMARY KEY DEFAULT 'conversation_membership.' || encode(gen_random_bytes(10), 'hex') NOT NULL,
  user_id text NOT NULL,
  conversation_id text NOT NULL
);


CREATE TABLE IF NOT EXISTS "message" (
  id text PRIMARY KEY DEFAULT 'message.' || encode(gen_random_bytes(10), 'hex') NOT NULL,
  ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  content text NOT NULL,
  actor_id text NOT NULL,
  recipient_id text NOT NULL
);

COMMIT;
