-- The same 10 query stress test, using materialized views

SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TIMING ON
SET SERVEROUTPUT ON
SET TRANSACTION READ ONLY
WHENEVER SQLERROR CONTINUE

DECLARE
  v_loops NUMBER := 50;
  v_rc    SYS_REFCURSOR;

  TYPE t_str_tab IS TABLE OF VARCHAR2(60) INDEX BY PLS_INTEGER;
  v_kw_prefixes   t_str_tab;
  v_auth_prefixes  t_str_tab;
  v_kw_idx         PLS_INTEGER;
  v_auth_idx       PLS_INTEGER;
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

    -- Q1: Full table scan (no MV applicable, stays on base table)
    OPEN v_rc FOR
      SELECT d.title, d.document_type, d.discipline
      FROM document d;
    CLOSE v_rc;

    -- Q2: Keyword lookup (no MV needed, simple index scan)
    OPEN v_rc FOR
      SELECT k.keyword_key, k.keyword_text, k.wikidata_id
      FROM keyword k
      WHERE k.keyword_text LIKE v_kw_prefixes(v_kw_idx);
    CLOSE v_rc;

    -- Q3: Author lookup (no MV needed, simple index scan)
    OPEN v_rc FOR
      SELECT a.author_key, a.last_name, a.first_name, a.author_id_hal
      FROM author a
      WHERE a.last_name LIKE v_auth_prefixes(v_auth_idx);
    CLOSE v_rc;

    -- Q4: Documents with keywords — NOW USES MV
    OPEN v_rc FOR
      SELECT title, keyword_text
      FROM MV_DOC_AUTHOR_KEYWORD
      WHERE keyword_text LIKE v_kw_prefixes(v_kw_idx);
    CLOSE v_rc;

    -- Q5: Documents with authors — NOW USES MV
    OPEN v_rc FOR
      SELECT title, last_name, first_name, quality
      FROM MV_DOC_AUTHOR_KEYWORD
      WHERE last_name LIKE v_auth_prefixes(v_auth_idx);
    CLOSE v_rc;

    -- Q6: Author affiliations per document — NOW USES MV
    OPEN v_rc FOR
      SELECT aod.last_name, aod.struct_name, mv.title
      FROM MV_AUTHOR_ORGANISM_DISTINCT aod
      JOIN MV_DOC_AUTHOR_KEYWORD mv
        ON aod.author_key = mv.author_key
      WHERE aod.last_name LIKE v_auth_prefixes(v_auth_idx);
    CLOSE v_rc;

    -- Q7: Full star join — NOW USES MV
    OPEN v_rc FOR
      SELECT title, last_name, keyword_text, doi_id
      FROM MV_DOC_AUTHOR_KEYWORD
      WHERE keyword_text LIKE v_kw_prefixes(v_kw_idx);
    CLOSE v_rc;

    -- Q8: Authors by document count — NOW USES MV
    OPEN v_rc FOR
      SELECT last_name, first_name, author_id_hal, doc_cnt
      FROM MV_AUTHOR_DOC_COUNTS
      WHERE last_name LIKE v_auth_prefixes(v_auth_idx)
      ORDER BY doc_cnt DESC;
    CLOSE v_rc;

    -- Q9: Organisms by distinct author count — NOW USES MV
    OPEN v_rc FOR
      SELECT struct_name, hal_structure_id, COUNT(DISTINCT author_key) AS auth_cnt
      FROM MV_AUTHOR_ORGANISM_DISTINCT
      GROUP BY organism_key, struct_name, hal_structure_id
      ORDER BY auth_cnt DESC;
    CLOSE v_rc;

    -- Q10: CLOB access — stays on base tables (abstract not in MV)
    OPEN v_rc FOR
      SELECT DBMS_LOB.SUBSTR(d.abstract, 200, 1)
      FROM document d
      JOIN doc_keyword dk ON d.document_key = dk.document_key
      JOIN keyword k ON dk.keyword_key = k.keyword_key
      WHERE d.abstract IS NOT NULL
        AND k.keyword_text LIKE v_kw_prefixes(v_kw_idx);
    CLOSE v_rc;

    -- Q11: Filtered star join alternate prefix — NOW USES MV
    OPEN v_rc FOR
      SELECT title, hal_id_s, keyword_text
      FROM MV_DOC_AUTHOR_KEYWORD
      WHERE keyword_text LIKE v_kw_prefixes(MOD(v_kw_idx, 12) + 1);
    CLOSE v_rc;

    -- Q12: Multi-affiliation authors — NOW USES MV
    OPEN v_rc FOR
      SELECT author_key, first_name, last_name, author_id_hal,
             COUNT(DISTINCT organism_key) AS org_cnt
      FROM MV_AUTHOR_ORGANISM_DISTINCT
      WHERE last_name LIKE v_auth_prefixes(v_auth_idx)
      GROUP BY author_key, first_name, last_name, author_id_hal
      HAVING COUNT(DISTINCT organism_key) > 1;
    CLOSE v_rc;

  END LOOP;

  DBMS_OUTPUT.PUT_LINE('MV stress test complete: ' || v_loops
    || ' iterations x 12 queries = ' || (v_loops * 12) || ' total queries');
END;
/

EXIT
