-- Manual evidence: run each pair against a DB with 001+002+004 applied.
-- "-- valid" statements should succeed. "-- invalid" statements should
-- fail with the named constraint in the error message.

-- products_price_non_negative
insert into products (id, operator_id, city_id, name, price)
values ('PROD-TEST-OK', 'OP-METRO', 'CPH', 'Test Ticket', 10.00); -- valid

insert into products (id, operator_id, city_id, name, price)
values ('PROD-TEST-BAD', 'OP-METRO', 'CPH', 'Test Ticket', -5.00); -- invalid

-- payments_amount_non_negative
-- (requires an existing ticket_id — substitute one you've seeded)
insert into payments (id, ticket_id, amount, currency, status, created_at)
values ('PAY-TEST-OK', 'TICKET-01', 25.00, 'DKK', 'pending', now()); -- valid

insert into payments (id, ticket_id, amount, currency, status, created_at)
values ('PAY-TEST-BAD', 'TICKET-01', -25.00, 'DKK', 'pending', now()); -- invalid

-- payments_status_allowed
insert into payments (id, ticket_id, amount, currency, status, created_at)
values ('PAY-TEST-BADSTATUS', 'TICKET-01', 25.00, 'DKK', 'unicorn', now()); -- invalid

-- payments_external_ref_unique
insert into payments (id, ticket_id, amount, currency, status, created_at, external_ref)
values ('PAY-TEST-REF1', 'TICKET-01', 25.00, 'DKK', 'completed', now(), 'GATEWAY-TXN-001'); -- valid

insert into payments (id, ticket_id, amount, currency, status, created_at, external_ref)
values ('PAY-TEST-REF2', 'TICKET-01', 25.00, 'DKK', 'completed', now(), 'GATEWAY-TXN-001'); -- invalid: duplicate external_ref

insert into payments (id, ticket_id, amount, currency, status, created_at, external_ref)
values ('PAY-TEST-NOREF', 'TICKET-01', 25.00, 'DKK', 'completed', now(), null); -- valid: nulls don't collide

-- tickets_valid_window
insert into tickets (id, operator_id, user_id, product_id, route_id, trip_id, status, valid_from, valid_to)
values ('TICKET-TEST-OK', 'OP-METRO', 'USER-01', 'PROD-TEST-OK', 'LINE-M2', 'TRIP-M2-001',
        'active', '2026-09-01 07:00:00+00', '2026-09-01 09:00:00+00'); -- valid

insert into tickets (id, operator_id, user_id, product_id, route_id, trip_id, status, valid_from, valid_to)
values ('TICKET-TEST-BAD', 'OP-METRO', 'USER-01', 'PROD-TEST-OK', 'LINE-M2', 'TRIP-M2-001',
        'active', '2026-09-01 09:00:00+00', '2026-09-01 07:00:00+00'); -- invalid: valid_to before valid_from

-- tickets_status_allowed
insert into tickets (id, operator_id, user_id, product_id, route_id, trip_id, status, valid_from, valid_to)
values ('TICKET-TEST-BADSTATUS', 'OP-METRO', 'USER-01', 'PROD-TEST-OK', 'LINE-M2', 'TRIP-M2-001',
        'zombie', '2026-09-01 07:00:00+00', '2026-09-01 09:00:00+00'); -- invalid

-- trips_status_allowed
insert into trips (id, route_id, service_date, scheduled_departure_utc, status)
values ('TRIP-TEST-BADSTATUS', 'LINE-M2', '2026-09-01', '2026-09-01 07:00:00+00', 'floating'); -- invalid