# Lecture 4 — Compatible schema migration

## What this lab is about

Changing a column in a database that already has data in it. You can't just
swap columns in one step — you'd lose the links between existing rows and
break any code still using the old column name. The solution is a pattern
called expand/contract: add the new thing alongside the old thing, move the
data over, then remove the old thing only when nothing uses it anymore.

## The four approaches to migration (and why only one works)

| Approach | What happens | Result |
|---|---|---|
| Drop old column, add new one, make it required immediately | Existing tickets lose their product link, column is empty, NOT NULL fails | Breaks everything |
| Add new column, skip backfill, make it required | Existing tickets still have empty `tickets.product_id`, NOT NULL fails | Breaks on existing data |
| Add new column, backfill, make it required, then remove old column | Everything migrated safely, old and new code works during the overlap | Works |
| Just rename the column | PostgreSQL doesn't auto-rename all the code/queries referencing it | Breaks everything that uses the old name |

## Starting point (before any migration)

| Ticket | product_code | Price | Currency |
|---|---|---|---|
| TICKET-1 | SINGLE | 36.00 | DKK |
| TICKET-2 | SINGLE | 36.00 | DKK |
| TICKET-3 | DAY | 65.00 | DKK |

TICKET-3 was deliberately sold at a discounted price (65 DKK instead of the
catalogue price of 80 DKK). If the migration accidentally copies the current
product price instead of keeping the ticket's original price, this number
would silently change to 80. That must not happen.

Zero orphan tickets (every `tickets.product_code` points to a real
`products.code`).

## Step 2: The unsafe version (deliberately breaking it)

Tried dropping `tickets.product_code` inside a transaction:

```sql
begin;
alter table tickets drop column product_code;
select id, product_code, price, currency from tickets order by id;
-- ERROR: column "product_code" does not exist
rollback;
```

**Why this is unsafe:**
- Existing tickets instantly lose their link to products — no way to know
  which product a ticket belonged to.
- Any code (queries, apps, functions) that references `product_code` breaks
  immediately.
- There's no `tickets.product_id` to fall back on, so the link is gone
  forever unless you have a backup.

## Step 3: Expand — add new columns without removing old ones

Migration `030_expand_product_identity.sql`:
- Added `products.id` (UUID) — a stable identity that survives product renames.
- Filled in a random UUID for each existing product.
- Added `tickets.product_id` (UUID, nullable) — the new reference column.
- Added a foreign key from `tickets.product_id` to `products.id` (marked
  `NOT VALID` so it doesn't check existing rows yet).

After this step:
- Every product has a UUID (`products.id`).
- Every ticket still has `tickets.product_code` (unchanged).
- `tickets.product_id` exists but is empty on all existing tickets.
- Old code (readers and writers using `product_code`) still works fine.

Product UUIDs generated:
- DAY → `5a8270ce-c382-4a6a-a5b6-b51f1bb652ce`
- SINGLE → `5513222e-74d7-4681-be0a-7d73be28339d`

## Step 4: Old and new code working side by side

### Old reader (`old_reader.sql`)
Reads tickets using `tickets.product_code`. Still works after the expand —
nothing was removed.

### Old writer (`old_writer.sql`)
Inserts a ticket using only `tickets.product_code`. Still works — the new
`tickets.product_id` column is nullable, so leaving it empty is fine.

### New reader (`new_reader.sql`)
Uses a two-path join:
- If `tickets.product_id` is filled in → join `products` through that.
- If `tickets.product_id` is still empty → fall back to joining through
  `tickets.product_code`.

This means it works both before and after the backfill — it handles tickets
written by old code and new code in the same query.

### New writer (`new_writer.sql`)
Takes a `products.id` (UUID) as input, looks up the product, and stores
*both* `tickets.product_id` and `tickets.product_code` on the ticket. This
way old readers can still read tickets created by the new writer. The price
is passed in directly — not copied from the product catalogue.

## Step 5: Backfill existing tickets

Migration `031_backfill_ticket_product.sql`:

```sql
update tickets t
set product_id = p.id
from products p
where t.product_id is null
  and p.code = t.product_code;
```

What this does: for every ticket where `tickets.product_id` is still empty,
look up its `tickets.product_code` in the `products` table, find the matching
`products.id` (UUID), and fill it in.

Key property: **safe to run more than once.** The `where t.product_id is null`
means it only touches tickets that haven't been filled in yet. Running it a
second time changes zero rows. This matters because if the script gets
interrupted halfway through, you can just run it again.

Results:
- First run: `UPDATE 4` (filled in the 4 tickets that had empty
  `tickets.product_id`).
- Second run: `UPDATE 0` (nothing left to fill).
- After inserting one more old-style ticket and running again: `UPDATE 1`
  (caught the late arrival).

Verification (`verify.sql`) returned zero problem rows — every ticket has a
valid `tickets.product_id` that agrees with its `tickets.product_code`.

**Prices unchanged:** TICKET-3 still shows 65.00 DKK (not 80.00). The
backfill only filled in `tickets.product_id` — it never touched
`tickets.price`.

## Step 6: Make `tickets.product_id` required

Migration `032_require_ticket_product.sql`:

```sql
begin;
alter table tickets validate constraint tickets_product_id_fk;
alter table tickets alter column product_id set not null;
commit;
```

### Deliberate failure first

Inserted `TICKET-BAD` using old-style code (no `tickets.product_id`), then
tried to run the migration. Postgres refused:

```
ERROR: column "product_id" contains null values
ROLLBACK
```

The database stopped us from making the rule while bad data still existed.
The whole transaction was rolled back — nothing half-applied.

### Fix and retry

Ran the backfill again (`UPDATE 1` — caught `TICKET-BAD`), verified zero
problem rows, then re-ran the migration. This time it succeeded.

From this point on: **no ticket can ever be inserted without a
`tickets.product_id`**. The database will refuse it.

## Step 7: Remove the old column

### Dependency check

Ran a query to find any views, functions, or other objects that depend on
`tickets.product_code`. Result: zero dependencies.

### Rehearsal (rollback)

Ran the drop inside a transaction ending with `rollback` — confirmed it works
without actually removing anything.

### Real drop (commit)

Ran the same thing with `commit`. Column is gone.

### Final writer

Inserts a ticket using only `tickets.product_id`, no `product_code`. This
previously failed (because `product_code` had a NOT NULL rule). Now it works
because the column doesn't exist anymore.

### Final reader

Joins `tickets` to `products` through `tickets.product_id` only. Gets the
product code from `products.code` (the products table), not from `tickets`.
If someone renames a product's code, old tickets still link correctly through
the UUID — which was the whole point of this migration.

### Final state

All 8 tickets verified. TICKET-3 still 65.00 DKK. Every ticket has a valid
`tickets.product_id`. The `tickets.product_code` column no longer exists.

## The expand/contract pattern (summary)

| Phase | What happens | Old code works? | New code works? |
|---|---|---|---|
| 1. Expand | Add new column alongside old one | Yes | Yes (with fallback) |
| 2. Backfill | Fill in the new column for existing rows | Yes | Yes |
| 3. Require | Make the new column NOT NULL | No (old writers fail) | Yes |
| 4. Contract | Remove the old column | No | Yes |

The key insight: there's a window (phases 1-2) where both old and new code
work at the same time. This is what makes it safe to deploy gradually — you
don't need to update every piece of code at the exact same instant.

## One modelling assumption that may change later

*(Write one thing about this migration that you'd handle differently in
production — e.g. the backfill runs as a single UPDATE, which locks every
ticket row at once. On a table with millions of rows, you'd batch it into
smaller chunks to avoid holding a long lock.)*
