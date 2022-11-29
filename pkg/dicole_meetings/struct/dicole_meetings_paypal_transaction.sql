CREATE TABLE IF NOT EXISTS dicole_meetings_paypal_transaction (
  id       %%INCREMENT%%,
  domain_id       int unsigned not null,
  user_id         int unsigned not null,
  received_date   bigint unsigned not null,
  payment_date    bigint unsigned not null,
  transaction_id  varchar(40) not null,
  notes           text,

  unique          ( id ),
  primary key     ( id ),
  unique          ( transaction_id ),
  key             ( transaction_id(20) ),
  key             ( user_id )
)
