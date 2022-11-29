CREATE TABLE IF NOT EXISTS dicole_meetings_date_proposal (
  proposal_id       %%INCREMENT%%,
  domain_id         int unsigned not null,
  meeting_id        int unsigned not null,
  created_by        int unsigned not null,
  created_date      bigint unsigned not null,
  disabled_date     bigint unsigned not null,
  removed_date      bigint unsigned not null,
  begin_date        bigint unsigned not null,
  end_date          bigint unsigned not null,

  unique            ( proposal_id ),
  primary key       ( proposal_id ),
  key		        ( domain_id, meeting_id )
)
