# Lecture 1 — Relational baseline

## System context

MobilityTicketing is a city transport ticketing system. Customers buy tickets
to ride buses and metros. Operators (like "City Metro" and "City Bus") run
routes through the city — each route is an ordered sequence of stops. Trips
are individual scheduled departures on a route (e.g. the M2 metro leaving at
08:00 on a specific date). Customers buy a ticket for a specific trip,
pay for it, and have it validated when they board.

## Access-pattern map

| Access pattern | Tables touched | What happens |
|---|---|---|
| Route search | `routes`, `route_stops`, `stops` | A customer looks up which routes serve a stop, or what stops a route passes through. Read-only. |
| Ticket purchase | `tickets`, `products`, `users`, `payments` | A customer picks a product (e.g. "Single Ride"), a ticket row is created linking the user, trip, and product, then a payment is recorded. |
| Ticket validation | `validations`, `tickets`, `trips`, `stops` | When the customer boards, their ticket is scanned. A validation row records which ticket, on which trip, at which stop, and whether it was accepted. |
| Timetable updates | `trips`, `routes` | An operator adds, changes, or cancels scheduled trips on a route. May affect existing tickets if a trip is cancelled. |
| Real-time availability | `trips` | Check how many seats are left on a trip. Capacity currently has no column — see assumption note below. |
| Reporting | Cross-table, read-only | Aggregate queries across payments, tickets, trips, routes to calculate things like daily revenue per operator. |

## ER diagram

See `er_diagram.drawio` (or the image export alongside this file). Entities:
operators, routes, stops, route_stops, trips, users, products, tickets,
payments, validations. All cardinalities are one-to-many (e.g. one operator has
many routes, one route has many trips, one ticket has many payments, one
ticket has many validations).

## Primary key decision: `route_stops`

**PK = (route_id, stop_sequence)**

Within the seed data, a repeated stop on a route doesn't happen for the bus
example (route reversal creates a new `route_id` rather than reusing one).
However, since the schema explicitly supports multiple mode values including
`metro`, and Copenhagen operates a circular metro line (Cityringen/M3) where a
stop is revisited as the train loops, the schema must still allow a stop to
occur more than once on the same route. Therefore `(route_id, stop_sequence)`
remains the correct primary key, even though today's seed data happens not to
exercise that case.

## Functional dependency

`(route_id, stop_sequence) determines stop_id` in `route_stops`: for a given route and
position in its sequence, the stop at that position is fully determined.

This is exactly why `stop_sequence` alone can't be the key — it repeats across
different routes — and why `stop_id` alone can't be the key either, since the
same stop can appear on multiple routes (and, per the M3 case above,
potentially more than once on the *same* route). Enforcing this FD via the
composite primary key prevents an update anomaly where the same
`(route_id, stop_sequence)` pair could otherwise be inserted twice with two
different `stop_id` values, leaving the route's stop order ambiguous.

## What this implementation proves / leaves unknown

**Proves:** the schema can represent operators, routes, an ordered sequence of
stops per route, and scheduled trips, recreatable from an empty database, with
FK relationships enforcing that route_stops/trips can't reference nonexistent
routes or stops.

**Leaves unknown:** ticket purchase, validation, payment, and capacity/seat
availability are not yet modelled — those arrive in lecture 2.

## Schema comparison: lecture 1 vs lecture 3/4 starter

In my lecture 1 implementation, I added `operator_id` as a foreign key
directly on `tickets` and `products`. The lecture 3/4 starter schema does not
have `operator_id` on tickets — instead, you find the operator by following
the chain `ticket to trip to route to operator`.

Both designs work. The tradeoff:
- **Direct FK (my lecture 1 version):** faster to query "which operator does
  this ticket belong to" — one column lookup instead of joining through three
  tables. But it stores the same information in two places (tickets *and*
  routes both know the operator), which means they could disagree if one gets
  updated and the other doesn't.
- **Indirect link (lecture 3/4 version):** the operator only lives on
  `routes`, so there's one source of truth. You need more joins to find it,
  but you can never have a ticket that says "OP-METRO" while its route says
  "OP-BUS".

The lecture 3/4 approach avoids that inconsistency risk, which is why the
later schema dropped the direct FK.

## One modelling assumption that may change later

The `route_stops` primary key assumes that `(route_id, stop_sequence)` is
enough to uniquely identify a stop on a route. This works today because
circular routes like M3 would use incrementing sequence numbers (stop 1, 2, 3,
... back to stop 1 at sequence position N). But if the system later needs to
model routes that branch (e.g. an express service that skips stops), or
routes where the sequence changes by time of day, the current key might need
revisiting.
