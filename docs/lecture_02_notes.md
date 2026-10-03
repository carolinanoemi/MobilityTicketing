# Lecture 2 — SQL operations and constraints

## Data integrity: rule → mechanism

| Rule | Mechanism | Status |
|---|---|---|
| Tickets must reference existing users, trips, products | `FOREIGN KEY` | Already in place from lecture 1 |
| Payments must reference existing tickets | `FOREIGN KEY` | Already in place from lecture 1 |
| Validations must reference existing tickets | `FOREIGN KEY` | Already in place from lecture 1 |
| Prices / payment amounts cannot be negative | `CHECK (price >= 0)` / `CHECK (amount >= 0)` | Added |
| Ticket validity cannot end before it begins | `CHECK (valid_to >= valid_from)` | Added |
| Status values must come from an accepted set | `CHECK (status IN (...))` on `trips`, `tickets`, `payments` | Added |
| External payment references must not represent the same payment twice | `UNIQUE (external_ref)`, nullable for cash/manual payments | Added |
| Ticket codes must identify tickets unambiguously | `PRIMARY KEY` on `tickets.id` | Already unique via PK — no separate code column needed |
| Capacity cannot be negative / reserved seats cannot exceed capacity | *Not implemented — see note below* | Deliberately out of scope |

### Why capacity/reserved-seats isn't a constraint here

Capacity has no column to live on yet — conceptually it belongs on a future
`vehicles` table (or a `trip.vehicle_id` reference), not on `products` or
`trips` directly. Even once it exists, "reserved seats" is a *count of rows in
`tickets`* for a given trip — a plain `CHECK` constraint only ever sees columns
on the row being written, so it structurally cannot compare against an
aggregate of other rows. Enforcing this correctly needs a trigger or an
application-layer check, not a constraint. This is itself a fact every
application needs to know: the database does *not* currently guarantee seats
aren't oversold.

## SQL operations

### Ticket purchase
Inserts a row into `tickets` (referencing an existing `user`, `product`,
`route`, `trip`) and, once payment is taken, a row into `payments` referencing
that ticket. Before the write: the referenced user/product/trip must already
exist (enforced by FK). After the write: the ticket's `valid_from`/`valid_to`
window and `status` must satisfy their `CHECK` constraints, and the payment's
`amount`/`status`/`external_ref` must satisfy theirs. Concurrency (e.g. two
purchases racing for the last seat) is explicitly out of scope for this
lecture.

### Ticket validation
Inserts a row into `validations` referencing an existing `ticket`, `trip`, and
`stop` (all enforced by FK). No `CHECK` currently governs *which* ticket
statuses may be validated (e.g. should an `'expired'` ticket be blockable at
the constraint level?) — flagged as a possible future rule, not implemented
here.

### Timetable maintenance
Updating or replacing `trips`/`routes` data must not silently break existing
`tickets`, `payments`, or `validations` that reference them. This is the
direct motivation for the referential integrity decisions below.

## Referential integrity decisions

- **`tickets`, `payments`, `validations`** — never hard-deleted. These are
  financial/audit records; their FKs are left at the default `RESTRICT`, and
  lifecycle changes go through `status` values (e.g. `'refunded'`,
  `'cancelled'`) rather than row deletion.
- **`trips`** — never hard-deleted once a ticket exists against it, for the
  same reason; a cancelled trip becomes `status = 'cancelled'`.
- **`routes`, `stops`** — FKs default to `RESTRICT`, so a route/stop can
  already be deleted freely while unused, and is already blocked once real
  history (trips, tickets, validations) references it — no extra config
  needed for that. Added an explicit `active` boolean column to both tables so
  a route/stop with existing history can be "discontinued" without deleting
  it, preserving everything historical that points to it.

## Implementation

New migration: `004_constraints.sql` (additive only — does not modify
`001_relational_baseline.sql`). Seed data extended in `002_seed.sql` with
`users`, `products`, and `tickets` rows to support testing. Test writes for
every constraint (valid + invalid) in `004_constraints_test.sql`.

### Test evidence

*(Paste your terminal output from running `004_constraints_test.sql` here —
every `-- valid` line should show `INSERT 0 1`; every `-- invalid` line should
show an `ERROR` naming the specific constraint it violated.)*

## What can every application writing to this database safely assume?

Every foreign key guarantees a ticket can never reference a nonexistent user,
product, or trip, and a payment or validation can never reference a
nonexistent ticket — no application needs to re-check existence before
writing. `CHECK` constraints guarantee prices/amounts are never negative, a
ticket's validity window is never inverted, and status columns can only ever
hold an accepted value. A `UNIQUE` constraint on `payments.external_ref`
guarantees a retried gateway call can't silently double-insert a payment.
Deletion is restricted by default everywhere history exists; discontinuing a
route/stop or changing a ticket/trip's lifecycle happens through status
columns, not row deletion. The one rule *not* enforced at the database level
is reserved-seats-vs-capacity, since it requires comparing against other rows
— something a row-level constraint cannot do.
