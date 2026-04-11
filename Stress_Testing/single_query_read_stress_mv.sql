SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TIMING ON
SET SERVEROUTPUT ON SIZE 1000000
WHENEVER SQLERROR CONTINUE

-- =====================================================
-- EXPLAIN PLAN CHECK  (MV1 + MV3, join-back for abstract)
-- =====================================================
-- MV1  mv_doc_author_keyword        covers document/doc_author/author/doc_keyword/keyword
-- MV3  mv_author_organism_distinct   covers author_organism/author/organism
-- MV2  mv_author_doc_counts          NOT usable: it counts docs-per-author,
--      but the query needs coauthors-per-document — different dimension.
--      Scalar subquery against doc_author is kept for correctness.
-- Join-back to document base table required for abstract LOB (not in MV1).
-- =====================================================

EXPLAIN PLAN FOR
  SELECT dak.title,
         dak.document_type,
         dak.doi_id,
         DBMS_LOB.SUBSTR(d.abstract, 300, 1) AS abstract_preview,
         dak.last_name,
         dak.first_name,
         aod.struct_name                      AS institution,
         dak.keyword_text,
         (SELECT COUNT(*)
            FROM doc_author da2
           WHERE da2.document_key = dak.document_key) AS coauthor_count
    FROM mv_doc_author_keyword dak
    -- join-back: abstract LOB not in MV1
    JOIN document d
         ON dak.document_key = d.document_key
    -- MV3: author-to-institution mapping
    LEFT JOIN mv_author_organism_distinct aod
         ON dak.author_key = aod.author_key
   WHERE dak.keyword_text LIKE 'system%'
     AND dak.last_name    LIKE 'S%'
   ORDER BY coauthor_count DESC, dak.title;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'ALL'));

-- =====================================================
-- STRESS TEST  (MV-driven)
-- =====================================================
DECLARE
  v_loops NUMBER := 50;
  v_rc    SYS_REFCURSOR;

  TYPE t_str_tab IS TABLE OF VARCHAR2(60) INDEX BY PLS_INTEGER;
  v_kw_prefixes   t_str_tab;
  v_auth_prefixes t_str_tab;
  v_kw_idx        PLS_INTEGER;
  v_auth_idx      PLS_INTEGER;
BEGIN
  DBMS_RANDOM.SEED(TO_NUMBER(TO_CHAR(SYSTIMESTAMP, 'FF6')));

  v_kw_prefixes(1)  := 'stress%';
  v_kw_prefixes(2)  := 'algorithm%';
  v_kw_prefixes(3)  := 'model%';
  v_kw_prefixes(4)  := 'network%';
  v_kw_prefixes(5)  := 'optim%';
  v_kw_prefixes(6)  := 'learn%';
  v_kw_prefixes(7)  := 'data%';
  v_kw_prefixes(8)  := 'simul%';
  v_kw_prefixes(9)  := 'comput%';
  v_kw_prefixes(10) := 'analy%';
  v_kw_prefixes(11) := 'control%';
  v_kw_prefixes(12) := 'system%';

  v_auth_prefixes(1)  := 'S%';
  v_auth_prefixes(2)  := 'M%';
  v_auth_prefixes(3)  := 'B%';
  v_auth_prefixes(4)  := 'L%';
  v_auth_prefixes(5)  := 'D%';
  v_auth_prefixes(6)  := 'C%';
  v_auth_prefixes(7)  := 'R%';
  v_auth_prefixes(8)  := 'G%';
  v_auth_prefixes(9)  := 'P%';
  v_auth_prefixes(10) := 'T%';

  FOR i IN 1..v_loops LOOP
    v_kw_idx   := TRUNC(DBMS_RANDOM.VALUE(1, 13));
    v_auth_idx := TRUNC(DBMS_RANDOM.VALUE(1, 11));

    OPEN v_rc FOR
      SELECT dak.title,
             dak.document_type,
             dak.doi_id,
             DBMS_LOB.SUBSTR(d.abstract, 300, 1) AS abstract_preview,
             dak.last_name,
             dak.first_name,
             aod.struct_name                      AS institution,
             dak.keyword_text,
             (SELECT COUNT(*)
                FROM doc_author da2
               WHERE da2.document_key = dak.document_key) AS coauthor_count
        FROM mv_doc_author_keyword dak
        JOIN document d
             ON dak.document_key = d.document_key
        LEFT JOIN mv_author_organism_distinct aod
             ON dak.author_key = aod.author_key
       WHERE dak.keyword_text LIKE v_kw_prefixes(v_kw_idx)
         AND dak.last_name    LIKE v_auth_prefixes(v_auth_idx)
       ORDER BY coauthor_count DESC, dak.title;

    CLOSE v_rc;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('MV stress test (mv_doc_author_keyword + mv_author_organism_distinct): '
    || v_loops || ' iterations');
END;
/

EXIT
