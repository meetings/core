CREATE TABLE IF NOT EXISTS dicole_meetings_matchmaker_url (
    id              	    %%INCREMENT%%,
    domain_id               int unsigned not null,
    user_id                 int unsigned not null,
    creator_id              int unsigned not null,
    creation_date   	    bigint unsigned not null,
    disabled_date   	    bigint unsigned not null,
    url_fragment            text,

    notes           	    text,

    unique          	    (id),
    primary key     	    (id),
    key                     (user_id),
    key                     (url_fragment(10))
)
