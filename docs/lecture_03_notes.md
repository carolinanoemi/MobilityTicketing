# Lecture 3 — Where should reporting logic execute?

## The four approaches

| # | Approach | File / object | How it works |
|---|---|---|---|
| 1 | Direct query | `queries/base_revenue.sql` (no migration) | Re-adds up all payments from scratch every time. Always correct, nothing stored. |
| 2 | Function | `020_reporting_function.sql` → `captured_revenue_for_day()` | Same re-add-up logic, just saved as a reusable shortcut. Always correct, nothing stored. |
| 3 | Materialized view | `022_daily_captured_revenue.sql` → `daily_captured_revenue` | A saved snapshot. Only updates when you manually run `REFRESH`. Can go stale. |
| 4 | Trigger-maintained table | `021_daily_revenue_trigger.sql` → `daily_revenue_by_operator` | Auto-updates when a new payment is inserted, but blind to edits, deletes, and data that existed before the trigger was created. |

## Initial backfill gap

After applying all four approaches, direct query/function/materialized view
show 2 rows totaling 72 DKK; the trigger table shows 0 rows. The trigger
only fires `AFTER INSERT ON payments`, and `PAYMENT-1`/`PAYMENT-2` were
inserted by the seed data before the trigger existed. A trigger can't go back
in time for rows already there. The other three read from the base tables
(or a snapshot), so they don't care when data arrived.

## Case 1: captured payment insert

Inserted `PAY-CASE-CAPTURED` (36 DKK, `Captured`, `TICKET-1` → `OP-METRO`).

- **Trigger table:** OP-METRO: 36, 1 payment — correctly caught this new
  insert.
- **Direct query:** OP-METRO: 72 (2 payments), OP-BUS: 36 (1 payment).
- **Mismatch:** trigger table only counted the one payment it saw arrive. Still
  missing the original seed data and has no OP-BUS row at all.

## Case 2: failed payment insert (should not count)

Inserted `PAY-CASE-FAILED` (50 DKK, `Failed`, `TICKET-1` → `OP-METRO`).

- **Trigger table:** unchanged — still OP-METRO: 36, 1 payment.
- **Direct query:** unchanged — still OP-METRO: 72, OP-BUS: 36.
- Both correctly ignored it because `status = 'Failed'` is not `'Captured'`.

## Case 3: correction — Failed → Captured

Updated `PAY-CASE-FAILED` status from `'Failed'` to `'Captured'`.

- **Trigger table:** unchanged — still OP-METRO: 36, 1 payment.
- **Direct query:** OP-METRO jumped to 122 (3 payments: original 36 + case 1's
  36 + the corrected 50).
- **This is the clearest disagreement.** The trigger only fires on `INSERT`,
  never on `UPDATE`. The 50 DKK payment is now `Captured` in the real data,
  but the trigger table has no idea it changed.

## Case 4: correction — Captured → Refunded

Updated `PAY-CASE-CAPTURED` status from `'Captured'` to `'Refunded'`.

- **Trigger table:** unchanged — still OP-METRO: 36, 1 payment.
- **Direct query:** OP-METRO dropped to 86 (2 payments — the refunded one no
  longer counts).
- Same reason as case 3 — `UPDATE` doesn't fire the trigger, so the trigger
  table still counts this payment as captured revenue even though it's been
  refunded.

## Case 5: delete test data

Deleted `PAY-CASE-FAILED`.

- **Trigger table:** unchanged — still OP-METRO: 36, 1 payment.
- **Direct query:** OP-METRO dropped back to 36 (1 payment — deleted row is
  gone from the source).
- Same pattern — no `DELETE` handler on the trigger.

## Case 6: duplicate delivery of the same external reference

Inserted `PAY-CASE-DUPLICATE` reusing `external_payment_reference =
'gateway-capture-0001'` (same as `PAYMENT-1`).

- **Trigger table:** OP-METRO: 72, 2 payments.
- **Direct query:** OP-METRO: 72, 2 payments.
- Both agree — but **both are wrong**. This is the same real-world payment
  inserted twice. Actual revenue should be 36, not 72. There's no `UNIQUE`
  constraint on `external_payment_reference`, so neither approach catches the
  duplicate. This is a different kind of problem — not about the trigger
  missing changes, but about all four approaches trusting bad data.

## Materialized view: staleness

Before refreshing, `daily_captured_revenue` still showed the snapshot from
before any test cases ran. After running
`REFRESH MATERIALIZED VIEW daily_captured_revenue;`, it matched the direct
query exactly (OP-BUS: 36/1, OP-METRO: 72/2). The trigger table still
showed only OP-METRO: 72/2 — no OP-BUS, because no OP-BUS payment was ever
inserted after the trigger existed.

## Responsibility matrix

| Criterion | Direct query | Function | Materialized view | Trigger table |
|---|---|---|---|---|
| Correctness | Always correct — reads live data | Same as direct query | Correct at time of last refresh only | Missing pre-existing data, edits, deletes, and refunds |
| Freshness | Always current | Always current | Stale until manually refreshed | Current for new inserts only; blind to everything else |
| Write cost | None — read only | None — read only | None until refresh (refresh re-scans everything) | Extra write on every captured payment insert |
| Read cost | Re-scans and re-joins every time (slow on large tables) | Same as direct query | Fast — reads pre-computed snapshot | Fast — reads pre-computed summary row |
| Hidden side effects | None | None | None (refresh is explicit) | Every payment insert silently writes to a second table |
| Rebuildability | Nothing to rebuild — it's a live query | Nothing to rebuild | `REFRESH` rebuilds from scratch | No rebuild path — must be dropped and re-seeded manually |
| Operational complexity | None | Low (function must be created once) | Low (must remember to refresh) | High (must handle backfill, updates, deletes, refunds, duplicates) |

## Side-effect trace (for one `INSERT INTO payments` with status `'Captured'`)

1. **Constraints checked:** `payments.ticket_id` FK confirms the ticket
   exists; `payments.user_id` FK confirms the user exists; status CHECK (if
   present) validates the value.
2. **Trigger fires:** the `AFTER INSERT` trigger on `payments` runs.
3. **Summary table write:** the trigger function inserts or updates a row in
   `daily_revenue_by_operator`, adding the payment's amount and incrementing
   the count for that operator + date.
4. **Rows touched:** the new `payments` row + one row in
   `daily_revenue_by_operator` (inserted or updated).
5. **Commit/rollback:** both writes are in the same transaction — if the
   payment insert is rolled back, the trigger's summary-table write is also
   rolled back.
6. **When each report becomes current:**
   - Direct query / function: immediately (they read live data).
   - Materialized view: not until the next `REFRESH`.
   - Trigger table: immediately for this insert (but not for any corrections).
7. **What the application can observe:** after commit, the payment row is
   visible. The trigger table's summary is also updated. The materialized
   view still shows stale data until refreshed.

## Issue register

`daily_revenue_by_operator` has no backfill path and no `UPDATE`/`DELETE`
handling. It silently diverges from the source of truth the moment a payment
is corrected (Failed → Captured, Captured → Refunded), deleted, or when an
operator's first payment predates the trigger's creation. There is no way to
rebuild it from the trigger alone — it must be dropped, recreated, and
manually backfilled from the base tables.

## Decision record

**Recommendation:** use the direct query or function as the authority for
on-demand revenue reports. They are always correct and have no hidden state
to manage. For a dashboard that tolerates a short delay, the materialized
view is acceptable with a defined refresh interval (e.g. every 5 minutes) —
it's fast to read and can be fully rebuilt with a single `REFRESH`. The
trigger-maintained table is not recommended as-is: it would need `UPDATE` and
`DELETE` handlers, an explicit backfill step for pre-existing data, and
duplicate-delivery protection before it could be trusted as a reporting
source. The added complexity and hidden side effects outweigh the read-speed
benefit when the materialized view offers similar performance with a simpler
rebuild path.
