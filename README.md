# Compulsory Assignment 1 review guide

Submitted commit: *(fill in after final commit)*

Setup and reset instructions: run `docker compose up -d` from the repository
root. Reset with `docker compose down` then `docker compose up -d`. The
database is available at `localhost:5432` with user `mobility`, database
`mobility`, password `mobility`. Apply migrations from the root with
`Get-Content <path> | docker compose exec -T postgres psql -U mobility -d mobility`.

## Where to find the work

**Lecture 1: model, workload map and queries:**
- ER diagram: [`docs/er_diagram.drawio`](docs/er_diagram.drawio)
- Schema: [`database/postgres/init/001_relational_baseline.sql`](database/postgres/init/001_relational_baseline.sql)
- Seed data: [`database/postgres/init/002_seed.sql`](database/postgres/init/002_seed.sql)
- Workload queries (upcoming trips, ordered stops, routes with trip counts):
  [`database/postgres/queries/003_queries.sql`](database/postgres/queries/003_queries.sql)
- Workload map, PK decision, functional dependency: [`docs/lecture_01_notes.md`](docs/lecture_01_notes.md)

**Lecture 2: constraints and tests:**
- Constraint migration: [`database/postgres/migrations/004_constraints.sql`](database/postgres/migrations/004_constraints.sql)
- Valid/invalid write tests: [`database/postgres/tests/004_constraints_test.sql`](database/postgres/tests/004_constraints_test.sql)
- Test output: [`database/postgres/tests/004_constraints_test_output.txt`](database/postgres/tests/004_constraints_test_output.txt)
- Integrity map, rule table, and "what can every app assume" explanation:
  [`docs/lecture_02_notes.md`](docs/lecture_02_notes.md)

**Lecture 3: reporting experiment and comparison:**
- Reporting function: [`database/postgres/migrations/020_reporting_function.sql`](database/postgres/migrations/020_reporting_function.sql)
- Trigger + summary table: [`database/postgres/migrations/021_daily_revenue_trigger.sql`](database/postgres/migrations/021_daily_revenue_trigger.sql)
- Materialized view: [`database/postgres/migrations/022_daily_captured_revenue.sql`](database/postgres/migrations/022_daily_captured_revenue.sql)
- Base revenue query: [`database/postgres/queries/base_revenue.sql`](database/postgres/queries/base_revenue.sql)
- Test cases, responsibility matrix, side-effect trace, and recommendation:
  [`docs/lecture_03_notes.md`](docs/lecture_03_notes.md)

**Lecture 4: migration stages and verification:**
- Expand migration: [`database/postgres/migrations/030_expand_product_identity.sql`](database/postgres/migrations/030_expand_product_identity.sql)
- Backfill migration: [`database/postgres/migrations/031_backfill_ticket_product.sql`](database/postgres/migrations/031_backfill_ticket_product.sql)
- Require migration: [`database/postgres/migrations/032_require_ticket_product.sql`](database/postgres/migrations/032_require_ticket_product.sql)
- Old/new reader and writer scripts: [`database/postgres/experiments/lecture04/`](database/postgres/experiments/lecture04/)
- Verification and ticket-price evidence: [`docs/lecture_04_notes.md`](docs/lecture_04_notes.md)

## Two decisions worth discussing

### 1. Route-stop primary key: (route_id, stop_sequence) instead of (route_id, stop_id)

I chose `(route_id, stop_sequence)` because Copenhagen's circular metro line
(Cityringen/M3) revisits the same stop as it loops. If `stop_id` were part of
the key, that stop could only appear once per route — breaking circular
routes. `stop_sequence` is unique per position, so it handles both linear and
circular routes.

**Alternative:** `(route_id, stop_id)` would be simpler and would prevent
accidentally listing the same stop twice, but it would make circular routes
impossible to model.

**Evidence:** [`docs/lecture_01_notes.md`](docs/lecture_01_notes.md), section
"Primary key decision: route_stops".

### 2. Direct query over trigger table for revenue reporting

The trigger-maintained summary table (`daily_revenue_by_operator`) silently
diverges from reality when payments are corrected (Failed → Captured),
refunded (Captured → Refunded), or deleted — it only fires on `INSERT`, not
`UPDATE` or `DELETE`. It also misses any data that existed before the trigger
was created. The direct query is always correct because it reads from the
base tables every time.

**Alternative:** the trigger table is faster to read, but its hidden side
effects and lack of a rebuild path make it unreliable without adding
UPDATE/DELETE handlers and a backfill step.

**Evidence:** [`docs/lecture_03_notes.md`](docs/lecture_03_notes.md), cases 3–5
show the disagreement; the responsibility matrix compares all four approaches.

## One limitation or open question

The database does not enforce that reserved seats cannot exceed trip capacity.
`reserved_seats` would need to be a count of `tickets` rows for a given trip,
and a `CHECK` constraint can only see columns on the row being written — it
cannot count rows in another table. Enforcing this correctly needs a trigger,
a serializable transaction, or application-layer logic. Until then, every
application writing to this database must handle overbooking itself — the
database does not guarantee it.

**Evidence:** [`docs/lecture_02_notes.md`](docs/lecture_02_notes.md), section
"Why capacity/reserved-seats isn't a constraint here".
**What we would check next:** whether a `BEFORE INSERT` trigger on `tickets`
that counts existing tickets for the same trip and compares against
`trips.capacity` is the right mechanism, or whether this belongs in the
application layer where concurrency control (row locking, serializable
transactions) is handled.
