CREATE TABLE IF NOT EXISTS dicole_meetings_agent_object_state (
    id              	    %%INCREMENT%%,
    domain_id               int unsigned not null,
    partner_id              int unsigned not null,
    set_by                  int unsigned not null,

    created_date            bigint unsigned not null,
    set_date                bigint unsigned not null,
    removed_date   	        bigint unsigned not null,

    generation              text,
    area                    text,
    model                   text,
    uid                     text,

    payload                 mediumtext,

    unique                  (id),
    primary key             (id),
    key                     (domain_id, partner_id, generation(8), area(8), model(8), uid(64))
)
