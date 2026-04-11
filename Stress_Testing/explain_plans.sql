SET PAGESIZE 200
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON

PROMPT ============================================================
PROMPT Q1: Fact table scan - all documents
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q1' FOR
  SELECT d.title, d.document_type, d.discipline
  FROM document d;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q1', 'ALL'));

PROMPT ============================================================
PROMPT Q2: Index scan - keyword prefix
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q2' FOR
  SELECT k.keyword_key, k.keyword_text, k.wikidata_id
  FROM keyword k
  WHERE k.keyword_text LIKE 'stress%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q2', 'ALL'));

PROMPT ============================================================
PROMPT Q3: Index scan - author last name prefix
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q3' FOR
  SELECT a.author_key, a.last_name, a.first_name, a.author_id_hal
  FROM author a
  WHERE a.last_name LIKE 'S%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q3', 'ALL'));

PROMPT ============================================================
PROMPT Q4: Two-table join - documents with keywords
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q4' FOR
  SELECT d.title, k.keyword_text
  FROM doc_keyword dk
  JOIN keyword  k ON dk.keyword_key  = k.keyword_key
  JOIN document d ON dk.document_key = d.document_key
  WHERE k.keyword_text LIKE 'stress%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q4', 'ALL'));

PROMPT ============================================================
PROMPT Q5: Two-table join - documents with authors
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q5' FOR
  SELECT d.title, a.last_name, a.first_name, da.quality
  FROM doc_author da
  JOIN author   a ON da.author_key   = a.author_key
  JOIN document d ON da.document_key = d.document_key
  WHERE a.last_name LIKE 'S%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q5', 'ALL'));

PROMPT ============================================================
PROMPT Q6: Three-table join - author affiliations per document
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q6' FOR
  SELECT a.last_name, o.struct_name, d.title
  FROM author_organism ao
  JOIN doc_author da ON ao.document_key = da.document_key
                    AND ao.author_key   = da.author_key
  JOIN organism o    ON ao.organism_key  = o.organism_key
  JOIN author   a    ON da.author_key    = a.author_key
  JOIN document d    ON da.document_key  = d.document_key
  WHERE a.last_name LIKE 'S%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q6', 'ALL'));

PROMPT ============================================================
PROMPT Q7: Full star join - document + authors + keywords
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q7' FOR
  SELECT d.title, a.last_name, k.keyword_text, d.doi_id
  FROM document d
  JOIN doc_author  da ON d.document_key = da.document_key
  JOIN author       a ON da.author_key  = a.author_key
  JOIN doc_keyword dk ON d.document_key = dk.document_key
  JOIN keyword      k ON dk.keyword_key = k.keyword_key
  WHERE k.keyword_text LIKE 'stress%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q7', 'ALL'));

PROMPT ============================================================
PROMPT Q8: Aggregation - authors by document count
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q8' FOR
  SELECT a.last_name, a.first_name, a.author_id_hal, COUNT(da.document_key) AS doc_cnt
  FROM doc_author da
  JOIN author a ON da.author_key = a.author_key
  WHERE a.last_name LIKE 'S%'
  GROUP BY a.author_key, a.last_name, a.first_name, a.author_id_hal
  ORDER BY doc_cnt DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q8', 'ALL'));

PROMPT ============================================================
PROMPT Q9: Aggregation - organisms by distinct author count
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q9' FOR
  SELECT o.struct_name, o.hal_structure_id, COUNT(DISTINCT ao.author_key) AS auth_cnt
  FROM author_organism ao
  JOIN organism o ON ao.organism_key = o.organism_key
  GROUP BY o.organism_key, o.struct_name, o.hal_structure_id
  ORDER BY auth_cnt DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q9', 'ALL'));

PROMPT ============================================================
PROMPT Q10: CLOB access - abstracts matching keyword prefix
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q10' FOR
  SELECT DBMS_LOB.SUBSTR(d.abstract, 200, 1)
  FROM document d
  JOIN doc_keyword dk ON d.document_key = dk.document_key
  JOIN keyword      k ON dk.keyword_key = k.keyword_key
  WHERE d.abstract IS NOT NULL
    AND k.keyword_text LIKE 'stress%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q10', 'ALL'));

PROMPT ============================================================
PROMPT Q11: Filtered star join - alternate keyword prefix
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q11' FOR
  SELECT d.title, d.hal_id_s, k.keyword_text
  FROM document d
  JOIN doc_keyword dk ON d.document_key = dk.document_key
  JOIN keyword      k ON dk.keyword_key = k.keyword_key
  WHERE k.keyword_text LIKE 'algorithm%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q11', 'ALL'));

PROMPT ============================================================
PROMPT Q12: Correlated subquery - multi-affiliation authors
PROMPT ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q12' FOR
  SELECT a.last_name, a.first_name, a.author_id_hal
  FROM author a
  WHERE a.last_name LIKE 'S%'
    AND (
      SELECT COUNT(DISTINCT ao.organism_key)
      FROM author_organism ao
      WHERE ao.author_key = a.author_key
    ) > 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q12', 'ALL'));

PROMPT ============================================================
PROMPT All explain plans complete.
PROMPT ============================================================

EXIT
