-- TODO: Adapt your new writer to use product_id without tickets.product_code.
-- Keep id, user_id, trip_id, ticket_code, status, validity dates, price and
-- currency in the insert. Use a fresh ticket ID and ticket code.
-- Test after removing the old column. If you try it while that column still
-- exists, check whether its NOT NULL constraint allows the insert.

\set ticket_id 'LAB04-FINAL-1'
\set ticket_code 'LAB04-CODE-FINAL-1'
\set product_id '5513222e-74d7-4681-be0a-7d73be28339d'

insert into tickets
    (id, user_id, trip_id, ticket_code, status, product_id,
     valid_from_utc, valid_to_utc, price, currency)
values (:'ticket_id', 'USER-1', 'TRIP-M2-20260429-0800', :'ticket_code',
        'Active', :'product_id'::uuid,
        '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', 36.00, 'DKK');