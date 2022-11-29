CREATE TABLE IF NOT EXISTS dicole_meetings_partner (
    id              %%INCREMENT%%,
    domain_id       int unsigned not null,
    creator_id      int unsigned not null,

    creation_date   bigint unsigned not null,

    api_key         varchar(20) not null,
    domain_alias    varchar(32) not null,

    localization_namespace text,
    name            text,
    notes           mediumtext,

    unique          (id),
    primary key     (id),
    key             (api_key),
    key             (domain_alias)
)
