
id | Name | rank_id | supervisor_id

-------------------------------------
1  | john  |  3      |      2

2  | james |  5      |      1

3  | george|  4      |      3

4  | aby   |  3      |      2

5  | john  |  2      |      1

/*
 * SQL Pattern: Chained JOINs
 */

CREATE TABLE employee (
    id serial,
    name varchar(10),
    rank_id integer,
    supervisor_rank_id integer
);

INSERT INTO employee (name, rank_id, supervisor_rank_id) VALUES
    ('John', 3, 2),
    ('James', 5, 1),
    ('George', 4, 3),
    ('Aby', 3, 2),
    ('John', 2, 1);

SELECT * FROM employee;

id | rank_name ------------------ 1 | president 2 | vice president 3 | prime minister 4 | cabinet minister 5 | minister

CREATE TABLE rank (
    id integer,
    rank_name varchar(20)
);

INSERT INTO rank (id, rank_name) VALUES 
    (1, 'President'),
    (2, 'Vice President'),
    (3, 'Prime Minister'),
    (4, 'Cabinet Minister'),
    (5, 'Minister');

SELECT * FROM rank; 


-- Solution: JOIN employee to rank twice
-- which is called chain JOINs
SELECT e.id, e.name, r1.rank_name AS employ_rank, r2.rank_name AS supervisor_rank
FROM employee e 
     INNER JOIN rank r1 ON e.rank_id = r1.id
     INNER JOIN rank r2 ON e.supervisor_rank_id = r2.id;


-- Discussion
-- Again, it's about THINK IN TABLES/SETS
-- Every JOIN creates a new table.
-- Take a look at what the new table is. You will understand what the JOINs create.
-- Notice: use SELECT * to see the whole table.
SELECT * 
FROM employee e
    INNER JOIN rank r1 ON e.rank_id = r1.id;

SELECT * 
FROM employee e
    INNER JOIN rank r1 ON e.rank_id = r1.id
    INNER JOIN rank r2 ON e.supervisor_rank_id = r2.id;
         