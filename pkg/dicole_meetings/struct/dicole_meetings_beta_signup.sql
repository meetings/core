CREATE TABLE IF NOT EXISTS dicole_meetings_beta_signup (
  signup_id       %%INCREMENT%%,
  domain_id       int unsigned not null,
  invited_user_id int unsigned not null,
  invited_date    bigint unsigned not null,
  signup_date     bigint unsigned not null,
  email           text,

  unique          ( signup_id ),
  primary key     ( signup_id )
)
