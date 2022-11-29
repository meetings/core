CREATE TABLE IF NOT EXISTS dicole_meetings_scheduling (
    id              	    %%INCREMENT%%,
    domain_id               int unsigned not null,
    partner_id              int unsigned not null,
    creator_id              int unsigned not null,
    meeting_id              int unsigned not null,

    created_date            bigint unsigned not null,
    completed_date          bigint unsigned not null,
    cancelled_date          bigint unsigned not null,
    removed_date   	    bigint unsigned not null,

    notes                   text,

    unique                  (id),
    primary key             (id),
    key                     (meeting_id)
)
