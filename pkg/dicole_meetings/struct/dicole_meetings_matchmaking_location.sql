CREATE TABLE IF NOT EXISTS dicole_meetings_matchmaking_location (
    id              	    %%INCREMENT%%,
    domain_id               int unsigned not null,
    creator_id              int unsigned not null,
    matchmaking_event_id    int unsigned not null,
    matchmaker_id           int unsigned not null,
    creation_date   	    bigint unsigned not null,
    deletion_date           bigint unsigned not null,

    availability_data       text,
    name           	    text,

    notes           	    text,

    unique          	    (id),
    primary key     	    (id),
    key                     (matchmaking_event_id),
    key                     (matchmaker_id)
)
