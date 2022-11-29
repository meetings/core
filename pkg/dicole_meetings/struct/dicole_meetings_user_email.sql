CREATE TABLE IF NOT EXISTS dicole_meetings_user_email (
  email_id       %%INCREMENT%%,
  domain_id      int unsigned not null,
  user_id        int unsigned not null,
  created_date   bigint unsigned not null,
  verified_date bigint unsigned not null,
  email          text,

  unique         ( email_id ),
  primary key    ( email_id ),
  key		 ( domain_id, user_id ),
  key            ( domain_id, email(32) )
)
