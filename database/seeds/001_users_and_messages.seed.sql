BEGIN TRANSACTION;

INSERT INTO "user" 
  (id, username, pw_hash) 
VALUES 
  ('user.2345', 'brent', 'bh_pw_hash'), 
  ('user.3456', 'tom', 'tom_pw_has'),
  ('user.4567', 'mitch', 'mitch_pw_hash');

INSERT INTO "conversation" 
  (id) 
VALUES 
  ('conversation.8787'),
  ('conversation.9876');

INSERT INTO "conversation_membership"
  (id, user_id, conversation_id)
VALUES
  -- brent and tom
  ('conversation_membership.1234', 'user.2345', 'conversation.8787'),
  ('conversation_membership.2345', 'user.3456', 'conversation.8787'),

  -- brent and mitch
  ('conversation_membership.3456', 'user.2345', 'conversation.9876'),
  ('conversation_membership.4567', 'user.4567', 'conversation.9876');

COMMIT;
