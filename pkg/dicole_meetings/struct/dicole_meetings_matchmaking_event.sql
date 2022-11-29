CREATE TABLE IF NOT EXISTS dicole_meetings_matchmaking_event (
    id              	%%INCREMENT%%,
    domain_id       	int unsigned not null,
    partner_id          int unsigned not null,
    creator_id       	int unsigned not null,
    creation_date   	bigint unsigned not null,
    begin_date          bigint unsigned not null,
    end_date            bigint unsigned not null,

    custom_name         text,
    organizer_name      text,
    organizer_url       text,
    organizer_email     text,
    
    notes           	text,

    unique          	(id),
    primary key     	(id)
)
