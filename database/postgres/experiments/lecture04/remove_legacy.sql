-- Start only after your ID-only reader and writer are ready.

-- TODO: Inspect views and functions that use tickets.product_code.
-- Update or remove those dependencies deliberately.
-- Drop the column without CASCADE and test your final reader and writer.


-- Keep this rehearsal reversible. Record what would need to happen before
-- you committed the same change in a real rollout.

begin;
set local lock_timeout = '3s';

-- Check what depends on tickets.product_code before dropping it
select dependent_ns.nspname as schema,
       dependent_view.relname as name,
       dependent_view.relkind as type
from pg_depend
join pg_rewrite on pg_depend.objid = pg_rewrite.oid
join pg_class as dependent_view on pg_rewrite.ev_class = dependent_view.oid
join pg_namespace dependent_ns on dependent_view.relnamespace = dependent_ns.oid
join pg_attribute on pg_depend.refobjid = pg_attribute.attrelid
    and pg_depend.refobjsubid = pg_attribute.attnum
where pg_attribute.attrelid = 'tickets'::regclass
  and pg_attribute.attname = 'product_code';

-- Drop the old column
alter table tickets drop column product_code;

commit;