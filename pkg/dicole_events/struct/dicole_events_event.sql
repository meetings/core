CREATE TABLE IF NOT EXISTS dicole_events_event (
  event_id          %%INCREMENT%%,
  domain_id         int unsigned not null,
  group_id          int unsigned not null,
  created_date      bigint unsigned not null,
  removed_date      bigint unsigned not null,
  updated_date      bigint unsigned not null,
  promoted_date     bigint unsigned not null,
  begin_date        bigint unsigned not null,
  end_date          bigint unsigned not null,
  reg_begin_date    bigint unsigned not null,
  reg_end_date      bigint unsigned not null,
  creator_id        int unsigned not null,
  event_state       int unsigned not null,
  invite_policy     int unsigned not null,
  num_attenders     int unsigned not null,
  max_attenders     int unsigned not null,
  show_yes          int unsigned not null,
  show_no           int unsigned not null,
  show_maybe        int unsigned not null,
  show_waiting      int unsigned not null,
  show_pages        int unsigned not null,
  show_posts        int unsigned not null,
  show_media        int unsigned not null,
  show_tweets       int unsigned not null,
  show_stream       int unsigned not null,
  show_feedback     int unsigned not null,
  show_map          int unsigned not null,
  show_chat         int unsigned not null,
  show_freeform     int unsigned not null,
  show_counter      int unsigned not null,
  show_imedia       int unsigned not null,
  show_planners     int unsigned not null,
  show_promo        int unsigned not null,
  show_extras       int unsigned not null,
  show_title        int unsigned not null,

  logo_attachment   int unsigned not null,
  banner_attachment int unsigned not null,

  latitude          double,
  longitude         double,

  title             text,
  abstract          text,
  description       text,
  stream            text,
  location_name     text,
  sos_med_tag       text,
  attend_info       text,
  require_phone     text,
  require_invite    text,
  freeform_title    text,
  freeform_content  text,

  notes             text,

  unique         ( event_id ),
  primary key    ( event_id ),
  key            ( domain_id ),
  key            ( domain_id, creator_id ),
  key            ( begin_date ),
  key            ( begin_date, end_date )
)