-- 2016-11-30
-- pgAdmin 4 crashed and erased all contents in a sql script file!!
-- Be cautious: save sql files in Notepad++
-- Back to pgAdmin III

/* p. 821
Lab: NOT IN vs NOT EXISTS
See: https://www.postgresql.org/docs/current/static/functions-subquery.html
*/
DROP TABLE t_y_no_null;
CREATE TABLE ta AS (
    SELECT s1.y AS y FROM generate_series(2, 5) s1(y));

-- t_y_no_null.y has no NULLs
CREATE TABLE t_y_no_null AS (
    SELECT s1.x AS x, s2.y AS y 
    FROM generate_series(1, 4) s1(x) LEFT JOIN
         generate_series(1, 4) s2(y) ON s1.x = s2.y);

-- t_y_has_null.y has NULLs
CREATE TABLE t_y_has_null AS (
    SELECT s1.x AS x, s2.y AS y 
    FROM generate_series(1, 5) s1(x) LEFT JOIN
         generate_series(2,4,2) s2(y) ON s1.x = s2.y);

        
SELECT * FROM ta;
SELECT * FROM t_y_no_null;
SELECT * FROM t_y_has_null;



-- What y numbers in ta but not in t_y_no_null?
-- Expected results: 5

-- NOT IN 
-- return 5 -- correct
SELECT *
FROM ta
WHERE ta.y NOT IN (SELECT y FROM t_y_no_null);

-- NOT EXISTS
-- return 5 -- correct
SELECT *
FROM ta
WHERE NOT EXISTS (SELECT 1 FROM t_y_no_null tno
                  WHERE ta.y = tno.y);


/* So far so good, but next we'll see the difference between NOT IN and NOT EXISTS. 
*/

-- What y numbers are in ta but not in t_y_has_null?
-- Expected results: 3, 5

-- NOT IN gives empty result
-- Wrong!
SELECT *
FROM ta
WHERE ta.y NOT IN (SELECT y FROM t_y_has_null);

-- but NOT EXISTS give 3, 5 -- correct
SELECT *
FROM ta
WHERE NOT EXISTS (SELECT 1 FROM t_y_has_null thas
                  WHERE ta.y = thas.y);


                  