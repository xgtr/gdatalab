
/* ********************** pp. 820 - 821
Q14-1 What states are in orders but not in zipcensus?
*/

-- too many redundant comparisions
SELECT DISTINCT o.state
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM zipcensus zc
                  WHERE o.state = zc.stab);

-- revised
-- 41 rows, 160 msec
SELECT o.state 
FROM (SELECT DISTINCT state FROM orders) o
WHERE NOT EXISTS (SELECT 1 FROM zipcensus zc
                 WHERE o.state = zc.stab);


-- method 2: use LEFT anti JOIN
SELECT o.state
FROM (SELECT DISTINCT state FROM orders) o LEFT JOIN
     (SELECT DISTINCT stab FROM zipcensus) zc ON o.state = zc.stab
WHERE stab IS NULL

-- Get the size of Intermediate table
-- method 1: 37.2 s, 223189393
SELECT count(*)
FROM orders o LEFT JOIN
     zipcensus zc ON o.state = zc.stab;

-- method 2: reduce sizes by JOIN
-- 177 msec, 223189393 (much faster)
SELECT sum(o.cnt * coalesce(zc.cnt, 1)) AS total
FROM (SELECT state, count(*) AS cnt
      FROM orders
      GROUP BY state) o LEFT JOIN
     (SELECT stab, count(*) AS cnt 
      FROM zipcensus
      GROUP BY stab) zc
     ON o.state = zc.stab;



/* ******************** p. 822
For states with at least one order, what is the
number of orders and valid zip codes?
*/
SELECT * FROM orders LIMIT 5;

-- method 1: LEFT JOIN 
-- Let's see the process of constructing queries
-- 1. answer what states have at least one order, and the number of orders
SELECT state, count(*) AS cnt
FROM orders
GROUP BY state
HAVING count(orderid) > 0;

-- 2. pipe step 1 as input to next query
-- 92 rows, 278 msec
-- NY: 53537, 1793
SELECT o.state, o.cnt AS cnt_order, 
       coalesce(zc.cnt, 0) AS cnt_zipcode
FROM (SELECT state, count(*) AS cnt
      FROM orders
      GROUP BY state
      HAVING count(orderid) > 0) o LEFT JOIN
     (SELECT stab, count(DISTINCT zcta5) AS cnt
      FROM zipcensus
      GROUP BY stab) zc
      ON o.state = zc.stab
ORDER BY cnt_order DESC;      


-- method 2: correlated subqueries
-- 92 rows, 8.3 s
-- NY: 53537, 1793
SELECT o.state, count(*) AS cnt_order,
       (SELECT count(DISTINCT zc.zcta5) AS cnt_zipcode
        FROM zipcensus zc
        WHERE zc.stab = o.state)
FROM orders o
GROUP BY o.state
ORDER BY cnt_order DESC;



/* *************************** p. 824 *******************
Q14-7 Which states have no orders with the most common product?
Difficult! But I solved it with the best method 
almost same as the one on pp. 826-827 ! (2016-12-02)
*/

-- the most common product
SELECT * FROM orderlines LIMIT 5;
SELECT * FROM orders LIMIT 5;

-- step 1: answer this question:
-- what's the productid of the most common product?
SELECT ol.productid, ol.cnt
FROM (SELECT productid, count(*) OVER (PARTITION BY productid) AS cnt
      FROM orderlines
      ORDER BY cnt DESC
      LIMIT 1) ol


-- step 2: anwser these questions
-- 1. what orderid HAVING the common product? This question is the opposite to the direct solution.
-- 21 rows, 528 msec
SELECT o.state
FROM orders o LEFT JOIN 
     (SELECT DISTINCT ol.orderid
      FROM orderlines ol INNER JOIN
           (SELECT productid, count(*) OVER (PARTITION BY productid) AS cnt
            FROM orderlines
            ORDER BY cnt DESC
            LIMIT 1) t 
           ON ol.productid = t.productid) ta
      ON o.orderid = ta.orderid
GROUP BY o.state
HAVING count(ta.orderid) = 0


-- Refactoring
-- use WITH common table expression, and simplify it by moving COUNT(*) to ORDER BY
-- debug by checking intermediate tables.
-- 21 rows, 211 msec
-- the best method
WITH most_pop AS (
    SELECT productid
    FROM orderlines
    GROUP BY productid
    ORDER BY count(*) DESC
    LIMIT 1
)
SELECT o.state
FROM orders o LEFT JOIN  -- check the intermediate table after LEFT JOIN
     (SELECT DISTINCT ol.orderid
      FROM orderlines ol INNER JOIN 
           most_pop mp 
           ON ol.productid = mp.productid) t
     ON o.orderid = t.orderid
GROUP BY o.state
HAVING count(t.orderid) = 0 


-- another way: explicit chained JOINs
-- the two JOINs in the main FROM can be chained but need some changes as shown below
-- 21 row, 403 msec
-- not as good and tuitive as the method above
WITH most_pop AS (
    SELECT productid
    FROM orderlines
    GROUP BY productid
    ORDER BY count(*) DESC
    LIMIT 1
)
SELECT o.state --, mp.productid
FROM orders o 
     INNER JOIN
     orderlines ol ON o.orderid = ol.orderid
     LEFT JOIN
     most_pop mp ON ol.productid = mp.productid
GROUP BY o.state
HAVING count(mp.productid) = 0


-- 92 states
SELECT DISTINCT state FROM orders;

-- use NOT EXISTS
-- 92 rows
-- wrong result!
WITH most_pop AS (
    SELECT productid
    FROM orderlines
    GROUP BY productid
    ORDER BY count(*) DESC
    LIMIT 1
)
SELECT DISTINCT o.state
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM orderlines ol
                  WHERE o.orderid = ol.orderid AND 
                  ol.productid IN (SELECT productid FROM most_pop))



/* ******************************** p. 828
Q14-8 What proportion of a state's population lives in each zip code?
*/
SELECT stab, zcta5, totpop  FROM zipcensus 
WHERE stab = 'NY'
ORDER BY zcta5;

SELECT stab, zcta5, round(1.0* totpop / sum(totpop) OVER (PARTITION BY stab), 6)
FROM zipcensus zc
WHERE stab = 'NY'
--GROUP BY stab, zcta5, totpop; -- tuple record (stab, zcta5, totpop) is unique combinations



/* ******************************* pp. 828-829
Q14-9 calculate the number of active subscribers on each day.
*/
SELECT * FROM calendar LIMIT 5;

-- 2390959
SELECT count(*) FROM subscribers 
WHERE stopdate IS NULL OR stopdate > '2006-12-28';

-- method 1: translate the question directly
-- 9.5 secs
SELECT c.date, 
   (SELECT count(*)
    FROM subscribers s
    WHERE s.startdate <= c.date AND 
          (s.stopdate > c.date OR s.stopdate IS NULL)) AS num_users
FROM calendar c
WHERE c.date BETWEEN '2006-01-01' AND '2006-01-07'
--WHERE c.date >= '2006-01-01' AND c.date <= '2006-01-07'


-- method 2
-- from Linoff. A clever use of window function ORDER BY
-- see PostgreSQL window functions docs
-- but the key ideas is the construction of a creative support table:
-- you can count the subscribers only when they start 
-- and then subtract them out when they stop.
SELECT sd.date, sum(sum(sd.inc)) OVER (order by sd.date)
FROM (SELECT startdate AS date, 1 AS inc
      FROM subscribers
      UNION ALL
      SELECT coalesce(stopdate, '2006-12-31'), -1 AS inc
      FROM subscribers
      --ORDER BY inc
      --LIMIT 50
     ) sd
GROUP BY sd.date
          


/* **************************** p. 830
Q14-10 How many active households are there on each day?
*/
-- 1. take a look at a few data sets
SELECT * FROM campaigns LIMIT 10;

SELECT * FROM orders ORDER BY orderdate LIMIT 10;  -- the earliest orderdate is 2009-10-04
SELECT * FROM orders ORDER BY orderdate DESC LIMIT 10;    -- the latest orderdate is 2016-09-20
SELECT * FROM orderlines ORDER BY billdate DESC LIMIT 10; -- the latest billdate is 2016-09-21

-- in customers, one householdid may have multiple customerids which are unique
SELECT count(*) FROM customers;   -- 189559
SELECT count(DISTINCT customerid) FROM customers;  -- 189559
SELECT count(DISTINCT householdid) FROM customers; -- 156258


-- 2. first answer this question:
-- for 2009-10-07, according to the one-year active biz rule, 
-- how many active householdids are there?
SELECT count(DISTINCT c.householdid) AS cnt
FROM customers c INNER JOIN
     orders o ON c.customerid = o.customerid
WHERE '2009-10-07'::date BETWEEN o.orderdate AND o.orderdate + interval '1 year'     
--WHERE o.orderdate BETWEEN '2009-10-07'::date - interval '1 year' AND '2009-10-07'
-- the first WHERE is better, though they give the same results: 468


-- 3. make date as a variable (use a correlated subquery)
-- subqueries can be in SELECT 
-- this is a correlated subquery which is a subquery (a query nested inside another query) 
-- that uses values from the outer query
SELECT ca.date,
       (SELECT count(DISTINCT c.householdid)
        FROM customers c JOIN
             orders o ON c.customerid = o.customerid 
        WHERE ca.date BETWEEN o.orderdate AND o.orderdate + interval '1 year') AS cnt
FROM calendar ca
WHERE ca.date BETWEEN '2009-10-04' AND '2009-10-10';


-- slow down & sweat the small stuff
-- remember: nothing is particularly hard if you divide it into small jobs.
-- need to understand LAG(), LEAD(), and especially SUM() OVER (ORDER BY ...)
-- see PostgreSQL docs
-- first create a small test table for the lab


DROP TABLE temp_customers;
CREATE TABLE temp_customers AS (
SELECT c.householdid, o.orderdate
FROM customers c JOIN
     (SELECT householdid
      FROM customers
      GROUP BY householdid
      HAVING count(*) = 3
      LIMIT 3) h
     ON c.householdid = h.householdid
     JOIN orders o
     ON c.customerid = o.customerid
     
ORDER BY orderdate--, householdid
);
SELECT * FROM temp_customers;

-- okay, let's see what LAG() and LEAD() will do
SELECT *,
       lag(orderdate) OVER (PARTITION BY householdid ORDER BY orderdate) AS lag_date,
      lead(orderdate) OVER (PARTITION BY householdid ORDER BY orderdate) AS lead_date
FROM temp_customers t
WHERE t.householdid = 18116681
ORDER BY orderdate;      


WITH oc AS (
    SELECT *,
       lag(orderdate) OVER (PARTITION BY householdid ORDER BY orderdate) AS lag_date,
      lead(orderdate) OVER (PARTITION BY householdid ORDER BY orderdate) AS lead_date
    FROM temp_customers t
    WHERE t.householdid = 18116681
)
SELECT *, SUM(inc) OVER (ORDER BY thedate)
FROM (SELECT oc.householdid, oc.orderdate AS thedate, lag_date, lead_date, 1 as inc
       FROM oc
       WHERE lag_date IS NULL OR lag_date + 365 < OrderDate
) d;
/* original table
"householdid";"orderdate";"lag_date";"lead_date"
"18116681";"2009-10-21";    ""       ;"2011-02-07"
"18116681";"2011-02-07";"2009-10-21";"2011-12-18"
"18116681";"2011-12-18";"2011-02-07";     ""
*/

/* the result table
"householdid";"thedate";"lag_date";"lead_date";"inc";"sum"
"18116681";"2009-10-21";"";"2011-02-07";"1";"1"
"18116681";"2011-02-07";"2009-10-21";"2011-12-18";"1";"2"
*/
/* Note
Why 2011-12-18 is excluded?
Because `SUM(inc) OVER (ORDER BY thedate)` is a cumsum operation.
2011-12-18 is still within its lag_date (2011-02-07) + '1 year', which means if we count 
2011-12-18 as 1, when thedate is 2011-12-18, for householdid 18116681, it will be counted
twice as active, but it's wrong. Our goal is to calculate the number of DISTINCT active 
householdids. When thedate is 2011-12-18, the householdid 18116681 should be only counted
once. Remember: 2011-02-07 is still active until 2012-02-06. All other cumstomerids of the
household 18116681 within the period 2011-02-07 to 2012-02-06 shouldn't be counted again.

The first condition: WHERE lag_date IS NULL 
That means the order is the first one of the householdid 18116681, so it should be counted
as active for the orderdate.

The second condition: lag_date + 365 < orderate
It means even its lag_date adds one year, the new date is still earlier than the current
orderdate, so the current order should be safely counted as active.
That makes SUM() OVER (ORDER BY orderdate) give correct cumsum, not count duplicates.
*/


 
WITH oc AS (
    SELECT *,
       lag(orderdate) OVER (PARTITION BY householdid ORDER BY orderdate) AS lag_date,
      lead(orderdate) OVER (PARTITION BY householdid ORDER BY orderdate) AS lead_date
    FROM temp_customers t
    WHERE t.householdid = 18116681
)
SELECT *, SUM(inc) OVER (ORDER BY thedate)
FROM  (SELECT oc.householdid, oc.OrderDate + 365 AS thedate, lag_date, lead_date, -1 as inc  
       -- Notice: here `orderdate + 365` means that the customerid is not active after a year.
       FROM oc
       WHERE lead_date IS NULL OR lead_date - 365 > OrderDate) d
/* original table
"householdid";"orderdate";"lag_date";"lead_date"
"18116681";"2009-10-21";    ""       ;"2011-02-07"
"18116681";"2011-02-07";"2009-10-21";"2011-12-18"
"18116681";"2011-12-18";"2011-02-07";     ""
*/

/* the result table
"householdid";"thedate";"lag_date";"lead_date";"inc";"sum"
"18116681";"2010-10-21";"";"2011-02-07";"-1";"-1"
"18116681";"2012-12-17";"2011-02-07";"";"-1";"-2"
*/
/* Note
The result table of this query is inactive householdids for (each date + 1 year), not the orderdate.
It's counting inactive ones one year later since the orderdate.
Why 2011-02-07 is not included?
Let's see the first condition: WHERE lead_date IS NULL
No lead_date, the current orderdate is the last one, so after a year, it's inactive.

The second condition: lead_date - 365 > OrderDate ( orderdate + 365 < lead_date)
If it's not the last order for the household 18116681, even add 1 year, it's still earlier than
its lead_date, so after one year, it's counted as inactive.

*/

/* Summary
This question "how many active households are there on each date?" was really a stretch.

If I want to use window functions to answer it, here are takeaways:
1. SUM() OVER (ORDRE BY ...) is cumsum
2. For each orderdate, calculate its contribution to active AND inactive by comparing other orderdates
   of the same household. The biz rules are: a household can have multiple orders (so multiple orderdates);
   on orderdate can be counted as active after the date such as 1 year or 1 week.
*/

-- OK, let me write the two queries again together 
-- First, intuitive one
SELECT c.date,
    (SELECT count(DISTINCT cu.householdid) AS cnt
     FROM customers cu INNER JOIN
          orders o 
          ON cu.customerid = o.customerid
     WHERE c.date BETWEEN o.orderdate AND o.orderdate + interval '365 days') t
FROM calendar c
WHERE c.date BETWEEN '2009-10-04' AND '2009-10-11'

-- Second, use Scaffold Table pattern
WITH oc AS (
    SELECT orderdate, lag(orderdate) OVER (PARTITION BY householdid ORDER BY orderdate) AS lag_date,
           lead(orderdate) OVER (PARTITION BY householdid ORDER BY orderdate) AS lead_date
    FROM orders o INNER JOIN
         customers c ON o.customerid = c.customerid
)
SELECT thedate, sum(inc) AS daily_cnt, sum(sum(inc)) OVER (ORDER BY thedate) AS cum_cnt
-- for SUM(SUM(inc)), the inner SUM(inc) is not window function, it's same as 'daily_cnt'.
-- the outer SUM(..) is the window function.
FROM (SELECT orderdate AS thedate, 1 AS inc
      FROM oc
      WHERE lag_date IS NULL OR lag_date + 365 < orderdate
      UNION ALL
      SELECT orderdate + 365, -1 AS inc
      FROM oc
      WHERE lead_date IS NULL OR lead_date > orderdate + 365
     ) t
GROUP BY thedate



/* **************************** p. 831
Q14-11
How many different maximum prices has a product had?
I don't think it's a good quesiton.
*/
SELECT * FROM orderlines LIMIT 5;

-- direct translation of the question
SELECT t.productid, count(DISTINCT max_price) AS cnt_max
FROM (SELECT productid, shipdate, max(unitprice) AS max_price, count(*) cnt 
      FROM orderlines
      GROUP BY productid, shipdate) t
GROUP BY t.productid
ORDER BY cnt_max DESC


/* ****************************** p. 832
What is the most recent national holiday before each order?
*/
SELECT date, hol_national, holidaytype FROM calendar LIMIT 10;
SELECT count(*) FROM orders;

WITH cn AS(
    SELECT date, hol_national
    FROM calendar
    WHERE holidaytype = 'national'
)
SELECT o.orderdate, first_value(cn.next_national) OVER (PARTITION BY o.orderdate ORDER BY cn.date)
FROM orders o INNER JOIN
     cn ON cn.date BETWEEN o.orderdate AND o.orderdate - 100


-- Interleave tables
WITH oc as (
    SELECT o.OrderId, o.OrderDate, NULL as HolidayDate, NULL as HolidayName
    FROM Orders o
    UNION ALL
    SELECT NULL, Date, Date as HolidayDate, HolidayName
    FROM Calendar c
    WHERE c.HolidayTYpe = 'national'
)
SELECT tt.*
FROM (SELECT orderid, orderdate, holidaydate, 
             max(holidayname) OVER (PARTITION BY holidaydate) AS holidayname
      FROM (SELECT oc.OrderId, oc.OrderDate,
                  MAX(oc.HolidayDate) OVER (ORDER BY oc.OrderDate) as HolidayDate, 
                  oc.holidayname
            FROM oc) t
      ) tt
WHERE orderid IS NOT NULL

