
PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> notepad database/postgres/experiments/lecture04/remove_legacy.sql
PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> Get-Content database/postgres/experiments/lecture04/remove_legacy.sql | docker compose exec -T postgres psql -U mobility -d mobility

BEGIN
SET
 schema | name | type
--------+------+------
(0 rows)

ALTER TABLE
COMMIT



PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> Get-Content database/postgres/experiments/lecture04/final_writer.sql | docker compose exec -T postgres psql -U mobility -d mobility

INSERT 0 1

PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> Get-Content database/postgres/experiments/lecture04/final_reader.sql | docker compose exec -T postgres psql -U mobility -d mobility

      id       |              product_id              | price | currency
---------------+--------------------------------------+-------+----------
 LAB04-FINAL-1 | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 LAB04-NEW-1   | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 LAB04-OLD-1   | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 LAB04-OLD-2   | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 TICKET-1      | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 TICKET-2      | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 TICKET-3      | 5a8270ce-c382-4a6a-a5b6-b51f1bb652ce | 65.00 | DKK
 TICKET-BAD    | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
(8 rows)

      id       |              product_id              | product_code | price | currency
---------------+--------------------------------------+--------------+-------+----------
 LAB04-FINAL-1 | 5513222e-74d7-4681-be0a-7d73be28339d | SINGLE       | 36.00 | DKK
 LAB04-NEW-1   | 5513222e-74d7-4681-be0a-7d73be28339d | SINGLE       | 36.00 | DKK
 LAB04-OLD-1   | 5513222e-74d7-4681-be0a-7d73be28339d | SINGLE       | 36.00 | DKK
 LAB04-OLD-2   | 5513222e-74d7-4681-be0a-7d73be28339d | SINGLE       | 36.00 | DKK
 TICKET-1      | 5513222e-74d7-4681-be0a-7d73be28339d | SINGLE       | 36.00 | DKK
 TICKET-2      | 5513222e-74d7-4681-be0a-7d73be28339d | SINGLE       | 36.00 | DKK
 TICKET-3      | 5a8270ce-c382-4a6a-a5b6-b51f1bb652ce | DAY          | 65.00 | DKK
 TICKET-BAD    | 5513222e-74d7-4681-be0a-7d73be28339d | SINGLE       | 36.00 | DKK
(8 rows)

PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter>