CREATE TABLE IF NOT EXISTS dicole_meetings_dispatched_email (
  dispatch_id	 	%%INCREMENT%%,
  domain_id      	int unsigned not null,
  user_id	 	int unsigned not null,
  event_id	 	int unsigned not null,
  processed_date 	bigint unsigned not null,
  completed_date 	bigint unsigned,
  sent_date	 	bigint unsigned not null,

  message_id text not null,

  to_email	 	text,
  from_email     	text,
  reply_email    	text,
  subject		text,
  html_content   	mediumtext,
  text_content		mediumtext,
  calendar_content      mediumtext,
  html_stripped         mediumtext,
  text_stripped         mediumtext,

  final_content		mediumtext,
  prese_id_list		text,
  comment_id_list	text,
  notes                 text,

  unique         ( dispatch_id ),
  primary key    ( dispatch_id ),
  key            ( message_id(64), completed_date )
)
