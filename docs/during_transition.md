PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> docker compose exec -T postgres psql -U mobility -d mobility -c "select id, product_code, product_id, price, currency from tickets order by id;"


    id    | product_code | product_id | price | currency
----------+--------------+------------+-------+----------
 TICKET-1 | SINGLE       |            | 36.00 | DKK
 TICKET-2 | SINGLE       |            | 36.00 | DKK
 TICKET-3 | DAY          |            | 65.00 | DKK
(3 rows)



PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> docker compose exec -T postgres psql -U mobility -d mobility -c "select id, code, price, currency from products order by code;"

                  id                  |  code  | price | currency
--------------------------------------+--------+-------+----------
 5a8270ce-c382-4a6a-a5b6-b51f1bb652ce | DAY    | 80.00 | DKK
 5513222e-74d7-4681-be0a-7d73be28339d | SINGLE | 36.00 | DKK
(2 rows)



PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> Get-Content database/postgres/experiments/lecture04/new_reader.sql | docker compose exec -T postgres psql -U mobility -d mobility

     id      |         resolved_product_id          | price | currency
-------------+--------------------------------------+-------+----------
 LAB04-OLD-1 | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 TICKET-1    | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 TICKET-2    | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 TICKET-3    | 5a8270ce-c382-4a6a-a5b6-b51f1bb652ce | 65.00 | DKK
(4 rows)

PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter>


PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> Get-Content database/postgres/experiments/lecture04/new_writer.sql | docker compose exec -T postgres psql -U mobility -d mobility

                  id                  |  code  | price | currency
--------------------------------------+--------+-------+----------
 5a8270ce-c382-4a6a-a5b6-b51f1bb652ce | DAY    | 80.00 | DKK
 5513222e-74d7-4681-be0a-7d73be28339d | SINGLE | 36.00 | DKK
(2 rows)

INSERT 0 1
PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter>


Difference between the old and new readers/writers (old/new ticket style):

PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> docker compose exec -T postgres psql -U mobility -d mobility -c "select id, product_code, product_id, price from tickets order by id;"

     id      | product_code |              product_id              | price
-------------+--------------+--------------------------------------+-------
 LAB04-NEW-1 | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00
 LAB04-OLD-1 | SINGLE       |                                      | 36.00
 TICKET-1    | SINGLE       |                                      | 36.00
 TICKET-2    | SINGLE       |                                      | 36.00
 TICKET-3    | DAY          |                                      | 65.00
(5 rows)

PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter>



PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> docker compose exec -T postgres psql -U mobility -d mobility -c "select id, product_code, product_id, price from tickets order by id;"

     id      | product_code |              product_id              | price
-------------+--------------+--------------------------------------+-------
 LAB04-NEW-1 | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00
 LAB04-OLD-1 | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00
 TICKET-1    | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00
 TICKET-2    | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00
 TICKET-3    | DAY          | 5a8270ce-c382-4a6a-a5b6-b51f1bb652ce | 65.00
(5 rows)

PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter>


PS C:\Users\carol\source\repos\mobilityticketing-lecture-4-starter> Get-Content database/postgres/experiments/lecture04/verify.sql | docker compose exec -T postgres psql -U mobility -d mobility

     id      | product_code |              product_id              | price | currency
-------------+--------------+--------------------------------------+-------+----------
 LAB04-NEW-1 | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 LAB04-OLD-1 | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 LAB04-OLD-2 | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 TICKET-1    | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 TICKET-2    | SINGLE       | 5513222e-74d7-4681-be0a-7d73be28339d | 36.00 | DKK
 TICKET-3    | DAY          | 5a8270ce-c382-4a6a-a5b6-b51f1bb652ce | 65.00 | DKK
(6 rows)

 id | product_code | product_id
----+--------------+------------
(0 rows)
