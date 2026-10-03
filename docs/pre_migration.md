Ticket	Product code	Price	Currency

TICKET-1	SINGLE	36.00	DKK

TICKET-2	SINGLE	36.00	DKK

TICKET-3	DAY	65.00	DKK



ERROR, when just altering table (DROP):

mobility=# begin;
BEGIN
mobility=*# alter table tickets drop column product_code;
ALTER TABLE
mobility=*# select id, product_code, price, currency from tickets order by id;
ERROR:  column "product_code" does not exist
LINE 1: select id, product_code, price, currency from tickets order ...
                   ^
mobility=!# rollback;