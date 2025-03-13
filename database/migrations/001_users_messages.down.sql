BEGIN TRANSACTION;

DROP TABLE IF EXISTS "token_blocklist";

DROP TABLE IF EXISTS "message";

DROP TABLE IF EXISTS "conversation_membership";

DROP TABLE IF EXISTS "conversation";

DROP TABLE IF EXISTS "user";

COMMIT;
