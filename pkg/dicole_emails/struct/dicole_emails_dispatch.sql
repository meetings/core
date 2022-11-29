CREATE TABLE IF NOT EXISTS dicole_emails_dispatch (
    dispatch_id  %%INCREMENT%%,
    dispatch_key text,
    data_hash    text,
    data         text,
    unique      (dispatch_id),
    primary key (dispatch_id)
);
