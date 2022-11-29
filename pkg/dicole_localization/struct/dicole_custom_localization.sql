CREATE TABLE IF NOT EXISTS dicole_custom_localization (
  localization_id	%%INCREMENT%%,
  creation_date bigint unsigned not null,
  namespace_key TEXT,
  namespace_area int unsigned not null default 0,
  namespace_lang TEXT,
  localization_key TEXT,
  localization_value TEXT,
  unique    ( localization_id ),
  primary key   ( localization_id ),
  key       ( creation_date )
)
