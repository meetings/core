CREATE TABLE IF NOT EXISTS dicole_meetings_scheduling_answer (
    id              	    %%INCREMENT%%,
    domain_id               int unsigned not null,
    creator_id              int unsigned not null,
    user_id                 int unsigned not null,
    meeting_id              int unsigned not null,
    scheduling_id           int unsigned not null,
    option_id               int unsigned not null,

    created_date            bigint unsigned not null,
    removed_date   	    bigint unsigned not null,

    answer                  tinytext,
    notes                   text,

    unique                  (id),
    primary key             (id),
    key                     (scheduling_id)
)
