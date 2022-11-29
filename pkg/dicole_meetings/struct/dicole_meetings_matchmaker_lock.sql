CREATE TABLE IF NOT EXISTS dicole_meetings_matchmaker_lock (
    id              	    %%INCREMENT%%,
    domain_id               int unsigned not null,
    creator_id              int unsigned not null,
    expected_confirmer_id   int unsigned not null,
    matchmaker_id           int unsigned not null,
    location_id             int unsigned not null,
    created_meeting_id      int unsigned not null,
    creation_date   	    bigint unsigned not null,
    expire_date             bigint unsigned not null,
    cancel_date             bigint unsigned not null,
    locked_slot_begin_date  bigint unsigned not null,
    locked_slot_end_date    bigint unsigned not null,

    title                   text,
    agenda                  text,

    notes           	    text,

    unique          	    (id),
    primary key     	    (id),
    key                     (matchmaker_id)
)
