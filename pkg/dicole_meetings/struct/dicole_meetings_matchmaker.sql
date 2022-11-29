CREATE TABLE IF NOT EXISTS dicole_meetings_matchmaker (
    id              	    %%INCREMENT%%,
    domain_id               int unsigned not null,
    partner_id              int unsigned not null,
    creator_id              int unsigned not null,
    matchmaking_event_id    int unsigned not null,
    logo_attachment_id 	    int unsigned not null,

    created_date            bigint unsigned not null,
    validated_date          bigint unsigned not null,
    disabled_date   	    bigint unsigned not null,

    allow_multiple          int unsigned not null,

    vanity_url_path         text,

    name                    text,
    description             text,
    website                 text,
    notes                   text,

    unique                  (id),
    primary key             (id),
    key                     (vanity_url_path(64))
)
