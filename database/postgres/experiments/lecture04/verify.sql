-- Show all tickets with both references
select t.id, t.product_code, t.product_id, t.price, t.currency
from tickets t
order by t.id;

-- Find any ticket where product_id is null, product doesn't exist,
-- or product_code and product_id point to different products
select t.id, t.product_code, t.product_id
from tickets t
left join products p on p.id = t.product_id
where t.product_id is null
   or p.id is null
   or t.product_code is distinct from p.code;
