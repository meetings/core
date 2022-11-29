CREATE TABLE IF NOT EXISTS dicole_meetings_agent_object_log (
    id              	    %%INCREMENT%%,
    domain_id               int unsigned not null,
    partner_id              int unsigned not null,

    created_date            bigint unsigned not null,

    area                    text,
    model                   text,
    uid                     text,

    old_payload             mediumtext,
    new_payload             mediumtext,

    unique                  (id),
    primary key             (id),
    key                     (domain_id, partner_id, area(8), model(8), uid(64))
)
