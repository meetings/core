CREATE TABLE IF NOT EXISTS dicole_event_source_gateway (
  gateway_id        %%INCREMENT%%,

  last_update           bigint unsigned not null,
  gateway               text,
  last_error            text,

  unique    ( gateway_id ),
  primary key   ( gateway_id )
)
