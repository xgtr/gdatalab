/* 
 * SQL Cookbook by Molinaro (O'Reilly 2005)
 */
    
CREATE TABLE emp (
    empno integer NOT NULL,
    ename varchar(10),
    job   varchar(9),
    mgr   integer,  -- empno of an employee's manager
    hiredate date,
    sal   integer,  -- salary
    comm  integer,  -- if an employee earns a commission
    deptno integer
);

INSERT INTO emp (empno, ename, job, mgr, hiredate, sal, comm, deptno) VALUES 
    (7369, 'SMITH',  'CLERK', 7902, '1980-12-17', 800, NULL, 20),
    (7499, 'ALLEN',  'SALESMAN', 7698, '1981-2-20', 1600,  300, 30),
    (7521, 'WARD',   'SALESMAN', 7698, '1981-2-22', 1250,  500, 30),
    (7566, 'JONES',  'MANAGER',  7839, '1981-4-2',  2975, NULL, 20),
    (7654, 'MARTIN', 'SALESMAN', 7698, '1981-9-28', 1250, 1400, 30),
    (7698, 'BLAKE',  'MANAGER',  7839, '1981-5-1',  2850, NULL, 30),
    (7782, 'CLARK',  'MANAGER',  7839, '1981-6-9',  2450, NULL, 10),
    (7788, 'SCOTT',  'ANALYST',  7566, '1982-12-9', 3000, NULL, 20),
    (7839, 'KING',   'PRESIDENT', NULL, '1981-11-17', 5000, NULL, 10),
    (7844, 'TURNER', 'SALESMAN',  7698, '1981-9-8',  1500, 0, 30),
    (7876, 'ADAMS',  'CLERK',     7788, '1983-1-12', 1100, NULL, 20),
    (7900, 'JAMES',  'CLERK',     7698, '1981-12-3', 950, NULL, 30),
    (7902, 'FORD',   'ANALYST',   7566, '1981-12-3', 3000, NULL, 20),
    (7934, 'MILLER', 'CLERK',     7782, '1982-1-23', 1300, NULL, 10);

 

CREATE TABLE dept (
    deptno integer,
    dname  varchar(14),
    loc varchar(13)
);

INSERT INTO dept (deptno, dname, loc) VALUES
    (10, 'ACCOUNTING', 'NEW YORK'),
    (20, 'RESEARCH',   'DALLAS'),
    (30, 'SALES',      'CHICAGO'),
    (40, 'OPERATIONS', 'BOSTON');


-- Create pivot tables
CREATE TABLE t1 AS
    SELECT t.x AS id FROM generate_series(1, 1) AS t(x);
CREATE TABLE t10 AS
    SELECT t.x AS id FROM generate_series(1, 10) AS t(x);
CREATE TABLE t100 AS
    SELECT t.x AS id FROM generate_series(1, 100) AS t(x);
CREATE TABLE t500 AS
    SELECT t.x AS id FROM generate_series(1, 500) AS t(x);


SELECT * FROM emp;
SELECT * FROM dept;
SELECT * FROM t100;

--------------------------

/* generate_series() */

SELECT * FROM generate_series(1, 31, 2);
SELECT * FROM generate_series('2016-11-24'::date, '2016-11-27', '1 day');
SELECT * FROM generate_series('2016-11-24'::date, '2016-11-27', '2 days');

-- You can think of generate_series() as a temporary table t having one column x
SELECT t.x FROM generate_series(1, 3) AS t(x);
-- current_date is a key word of PostgreSQL
SELECT current_date + t.x AS dates FROM generate_series(0, 3) AS t(x);



--------------------------------
-- Chapter 9. Date Manipulation
--------------------------------

/* 
 * 9.1 Determing if a year is leap year
 * 2016-11-24, 2016-12-12
 */
-- Check the last day of February. If 29, it's a leap year.

-- step 1: get the first day of the current year
SELECT date_trunc('year', current_date);  -- truncate to specified precision
SELECT CAST(date_trunc('year', current_date) AS date);  -- "2016-01-01"
SELECT CAST(date_trunc('year', current_date) AS timestamp)-- changing date to timestamp will give "2016-01-01 00:00:00"

-- step 2: get the first day of February
SELECT CAST(date_trunc('year', current_date) AS date) + interval '1 month';

-- step 3: or directly add 31 days to Feburary 1st, then add another 29 days to see what month it is
-- then extract month. If 2, leap year; 3, not.
SELECT extract(month from (cast(date_trunc('year', current_date) AS date) + 31 + 29))




-----------------------------------------
-- Chapter 12. Reporting and Warehousing
-----------------------------------------

/*
 * 12.1 Pivoting a result set into one row
 * 2016-11-25, 2016-12-13
 */
SELECT deptno, count(1) AS cnt
FROM emp
GROUP BY deptno
ORDER BY deptno;

-- Method 1: Use CASE expression and SUM() aggregation functions
SELECT sum(CASE deptno WHEN 10 THEN 1 END) AS dept_10,
       sum(CASE deptno WHEN 20 THEN 1 END) AS dept_20,
       sum(CASE WHEN deptno = 30 THEN 1 ELSE 0 END) AS dept_30
FROM emp


-- Method 2: Use inline view
SELECT *
FROM (SELECT deptno, count(*) AS cnt FROM emp
      GROUP BY deptno) t

SELECT max(CASE deptno WHEN 10 THEN cnt END) AS dept_10,
       max(CASE deptno WHEN 20 THEN cnt END) AS dept_20,
       max(CASE deptno WHEN 30 THEN cnt END) AS dept_30
FROM (SELECT deptno, count(*) AS cnt FROM emp
      GROUP BY deptno) t



/*
 * 12.2 Pivoting a result set into multiple rows
 * 2016-11-25, 2016-11-26, 2016-12-14, 2016-12-15
 * use ROW_NUMBER(): number of the current row within its partition, counting from 1
 * Use the window function ROW_NUMBER OVER to make each JOB/ENAME combination unique.
 * Pivot the result set using a CASE expression and the aggregate function MAX while grouping
 * on the value returned by the window function
 */
SELECT * FROM emp;
SELECT ename, job FROM emp;

-- one CASE doesn't work for this question
SELECT CASE job WHEN 'CLERK' THEN ename
                WHEN 'SALESMAN' THEN ename
       END
FROM emp;
       
-- use multiple CASEs
-- but how to remove NULL rows?
SELECT CASE job WHEN 'CLERK' THEN ename END AS job_clerk,
       CASE job WHEN 'SALESMAN' THEN ename END AS job_salesman
FROM emp;


-- Method 1: use ROW_NUMBER() window function
SELECT ename, job, row_number() OVER (PARTITION BY job ORDER BY ename) AS rnk
FROM emp;

SELECT max(CASE job WHEN 'ANALYST' THEN ename END) AS analyst,
       max(CASE job WHEN 'CLERK' THEN ename END) AS clerk
FROM (SELECT ename, job, 
             row_number() OVER (PARTITION BY job ORDER BY ename) AS rnk
      FROM emp) t
GROUP BY rnk
ORDER BY rnk



-- Method 2: Create a support table 
SELECT ename, job, 
       (SELECT count(*) FROM emp d WHERE e.job=d.job AND e.ename < d.ename) AS rnk 
       -- Actually it's the function ROW_NUMBER()
FROM emp e
ORDER BY job, rnk;


SELECT 
    max(CASE WHEN t.job = 'CLERK' THEN t.ename END) AS clerk,
    max(CASE WHEN t.job = 'SALESMAN' THEN t.ename END) AS salesman,
    max(CASE WHEN t.job = 'MANAGER' THEN t.ename END) AS manager,
    max(CASE WHEN t.job = 'ANALYST' THEN t.ename END) AS analyst, 
    max(CASE WHEN t.job = 'PRESIDENT' THEN t.ename END) AS president
FROM (SELECT ename, job, 
           (SELECT count(*) FROM emp d WHERE e.job=d.job AND e.ename < d.ename) AS rnk
      FROM emp e) t
GROUP BY t.rnk      
ORDER BY t.rnk;


/*
 * 12.3 Reverse pivoting a result set (melt)
 * 2016-12-26
 */

-- key: use CROSS JOIN to create a Cartesian product




/*
 * 12.5 Suppressing repeatint values from a result set
 * 2016-12-26
 * My solution is better than the book's.
 */
SELECT deptno, ename
FROM emp
ORDER BY deptno 

-- use ROW_NUMBER() window function
SELECT CASE WHEN rnk = 1 THEN deptno END AS dept_no, ename
FROM (SELECT deptno, ename, 
             row_number() OVER (PARTITION BY deptno ORDER BY ename) AS rnk
      FROM emp) t



-----------------------------------------
-- Chapter 13. Hierarchical Queries
-----------------------------------------

/*
 * 13.1 Expressing a parent-child relationship
 * 2016-12-15
 */

SELECT * FROM emp;

SELECT e.empno, e.ename, e.mgr, d.empno, d.ename
FROM emp e LEFT JOIN
     emp d ON e.mgr = d.empno;


SELECT format('%-10s work for %10s', e.ename, d.ename)
FROM emp e LEFT JOIN
     emp d ON e.mgr = d.empno;


