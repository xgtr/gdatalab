
-- Subquery type 1:
-- Inline view
-- SQL Cookbook 12.1
-- the subquery in FROM clause is an inline view

SELECT *
FROM (SELECT deptno, count(*) AS cnt FROM emp
      GROUP BY deptno) t


-- Subquery type 2:
-- Scalar subquery
-- SQL Cookbook 12.2
-- cnt is a scalar

SELECT ename, (SELECT count(*) FROM emp) AS cnt
FROM emp;