-- Check available products first
select id, code, price, currency from products order by code;

-- New-style insert: accepts product_id, derives product_code from it
\set ticket_id 'LAB04-NEW-1'
\set ticket_code 'LAB04-CODE-NEW-1'
\set product_id '5513222e-74d7-4681-be0a-7d73be28339d'

insert into tickets
    (id, user_id, trip_id, ticket_code, status, product_id, product_code,
     valid_from_utc, valid_to_utc, price, currency)
select :'ticket_id', 'USER-1', 'TRIP-M2-20260429-0800', :'ticket_code',
       'Active', p.id, p.code,
       '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', 36.00, 'DKK'
from products p
where p.id = :'product_id'::uuid;