CREATE TABLE IF NOT EXISTS dicole_meetings_scheduling_option (
    id              	    %%INCREMENT%%,
    domain_id               int unsigned not null,
    creator_id              int unsigned not null,
    meeting_id              int unsigned not null,
    scheduling_id           int unsigned not null,

    created_date            bigint unsigned not null,
    begin_date              bigint unsigned not null,
    end_date                bigint unsigned not null,
    removed_date   	    bigint unsigned not null,

    notes                   text,

    unique                  (id),
    primary key             (id),
    key                     (scheduling_id)
)
