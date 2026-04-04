-- ============================================================
-- Explain Plans for Critical Stress Test Queries
-- Run as: sqlplus user/pass@db @explain_plans.sql
-- ============================================================

SET PAGESIZE 200
SET LINESIZE 200
SET LONG 50000
SET LONGCHUNKSIZE 50000
SET FEEDBACK OFF
SET VERIFY OFF

-- ============================================================
-- Q4: Documents with keywords via MV
-- ============================================================
PROMPT ============================================================
PROMPT Q4: Document-Keyword lookup via MV_DOC_AUTHOR_KEYWORD
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'Q4' FOR
  SELECT title, keyword_text
  FROM MV_DOC_AUTHOR_KEYWORD
  WHERE keyword_text LIKE 'algorithm%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q4', 'ALL'));


-- ============================================================
-- Q5: Documents with authors via MV
-- ============================================================
PROMPT ============================================================
PROMPT Q5: Document-Author lookup via MV_DOC_AUTHOR_KEYWORD
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'Q5' FOR
  SELECT title, last_name, first_name, quality
  FROM MV_DOC_AUTHOR_KEYWORD
  WHERE last_name LIKE 'S%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q5', 'ALL'));


-- ============================================================
-- Q6: Author affiliations joined with doc MV
-- ============================================================
PROMPT ============================================================
PROMPT Q6: Author-Organism joined with Doc-Author MV
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'Q6' FOR
  SELECT aod.last_name, aod.struct_name, mv.title
  FROM MV_AUTHOR_ORGANISM_DISTINCT aod
  JOIN MV_DOC_AUTHOR_KEYWORD mv
    ON aod.author_key = mv.author_key
  WHERE aod.last_name LIKE 'S%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q6', 'ALL'));


-- ============================================================
-- Q7: Full star join via MV
-- ============================================================
PROMPT ============================================================
PROMPT Q7: Star join — keyword filtered via MV_DOC_AUTHOR_KEYWORD
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'Q7' FOR
  SELECT title, last_name, keyword_text, doi_id
  FROM MV_DOC_AUTHOR_KEYWORD
  WHERE keyword_text LIKE 'algorithm%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q7', 'ALL'));


-- ============================================================
-- Q8: Authors by document count via MV
-- ============================================================
PROMPT ============================================================
PROMPT Q8: Author document counts via MV_AUTHOR_DOC_COUNTS
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'Q8' FOR
  SELECT last_name, first_name, author_id_hal, doc_cnt
  FROM MV_AUTHOR_DOC_COUNTS
  WHERE last_name LIKE 'S%'
  ORDER BY doc_cnt DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q8', 'ALL'));


-- ============================================================
-- Q9: Organisms by distinct author count via MV
-- ============================================================
PROMPT ============================================================
PROMPT Q9: Organism author counts via MV_AUTHOR_ORGANISM_DISTINCT
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'Q9' FOR
  SELECT struct_name, hal_structure_id, COUNT(DISTINCT author_key) AS auth_cnt
  FROM MV_AUTHOR_ORGANISM_DISTINCT
  GROUP BY organism_key, struct_name, hal_structure_id
  ORDER BY auth_cnt DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q9', 'ALL'));


-- ============================================================
-- Q11: Filtered star join alternate keyword via MV
-- ============================================================
PROMPT ============================================================
PROMPT Q11: Alternate keyword star join via MV_DOC_AUTHOR_KEYWORD
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'Q11' FOR
  SELECT title, hal_id_s, keyword_text
  FROM MV_DOC_AUTHOR_KEYWORD
  WHERE keyword_text LIKE 'model%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q11', 'ALL'));


-- ============================================================
-- Q12: Multi-affiliation authors via MV
-- ============================================================
PROMPT ============================================================
PROMPT Q12: Multi-affiliation authors via MV_AUTHOR_ORGANISM_DISTINCT
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'Q12' FOR
  SELECT author_key, first_name, last_name, author_id_hal,
         COUNT(DISTINCT organism_key) AS org_cnt
  FROM MV_AUTHOR_ORGANISM_DISTINCT
  WHERE last_name LIKE 'S%'
  GROUP BY author_key, first_name, last_name, author_id_hal
  HAVING COUNT(DISTINCT organism_key) > 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q12', 'ALL'));


-- ============================================================
-- Cleanup plan table entries
-- ============================================================
PROMPT ============================================================
PROMPT Cleaning up PLAN_TABLE...
PROMPT ============================================================

DELETE FROM PLAN_TABLE WHERE STATEMENT_ID IN ('Q4','Q5','Q6','Q7','Q8','Q9','Q11','Q12');
COMMIT;

PROMPT Done.
EXIT
