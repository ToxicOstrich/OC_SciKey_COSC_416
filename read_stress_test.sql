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

  -- Random-pick arrays for LIKE filters
  TYPE t_str_tab IS TABLE OF VARCHAR2(60) INDEX BY PLS_INTEGER;
  v_kw_prefixes   t_str_tab;
  v_auth_prefixes  t_str_tab;
  v_kw_idx         PLS_INTEGER;
  v_auth_idx       PLS_INTEGER;
BEGIN
  -- Seed the random generator
  DBMS_RANDOM.SEED(TO_NUMBER(TO_CHAR(SYSTIMESTAMP, 'FF6')));

  -- Keyword LIKE prefixes (varied enough to hit different index ranges)
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

  -- Author last-name LIKE prefixes
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

    -- Pick random prefixes for this iteration
    v_kw_idx   := TRUNC(DBMS_RANDOM.VALUE(1, 13));  -- 1..12
    v_auth_idx := TRUNC(DBMS_RANDOM.VALUE(1, 11));   -- 1..10

    -- Q1: Fact table scan — random page of documents
    OPEN v_rc FOR
      SELECT d.title, d.document_type, d.discipline
      FROM document d;
    CLOSE v_rc;

    -- Q2: Index scan — random keyword prefix (idx_keyword_text)
    OPEN v_rc FOR
      SELECT k.keyword_key, k.keyword_text, k.wikidata_id
      FROM keyword k
      WHERE k.keyword_text LIKE v_kw_prefixes(v_kw_idx);
    CLOSE v_rc;

    -- Q3: Index scan — random author last-name prefix (idx_author_name)
    OPEN v_rc FOR
      SELECT a.author_key, a.last_name, a.first_name, a.author_id_hal
      FROM author a
      WHERE a.last_name LIKE v_auth_prefixes(v_auth_idx);
    CLOSE v_rc;

    -- Q4: Two-table join — documents with keywords (random keyword prefix)
    OPEN v_rc FOR
      SELECT d.title, k.keyword_text
      FROM doc_keyword dk
      JOIN keyword  k ON dk.keyword_key  = k.keyword_key
      JOIN document d ON dk.document_key = d.document_key
      WHERE k.keyword_text LIKE v_kw_prefixes(v_kw_idx);
    CLOSE v_rc;

    -- Q5: Two-table join — documents with authors (random author prefix)
    OPEN v_rc FOR
      SELECT d.title, a.last_name, a.first_name, da.quality
      FROM doc_author da
      JOIN author   a ON da.author_key   = a.author_key
      JOIN document d ON da.document_key = d.document_key
      WHERE a.last_name LIKE v_auth_prefixes(v_auth_idx);
    CLOSE v_rc;

    -- Q6: Three-table join — author affiliations per document (random author prefix)
    OPEN v_rc FOR
      SELECT a.last_name, o.struct_name, d.title
      FROM author_organism ao
      JOIN doc_author da ON ao.document_key = da.document_key
                        AND ao.author_key   = da.author_key
      JOIN organism o    ON ao.organism_key  = o.organism_key
      JOIN author   a    ON da.author_key    = a.author_key
      JOIN document d    ON da.document_key  = d.document_key
      WHERE a.last_name LIKE v_auth_prefixes(v_auth_idx);
    CLOSE v_rc;

    -- Q7: Full star join — document + authors + keywords (random keyword prefix)
    OPEN v_rc FOR
      SELECT d.title, a.last_name, k.keyword_text, d.doi_id
      FROM document d
      JOIN doc_author  da ON d.document_key = da.document_key
      JOIN author       a ON da.author_key  = a.author_key
      JOIN doc_keyword dk ON d.document_key = dk.document_key
      JOIN keyword      k ON dk.keyword_key = k.keyword_key
      WHERE k.keyword_text LIKE v_kw_prefixes(v_kw_idx);
    CLOSE v_rc;

    -- Q8: Aggregation — authors by document count (random author prefix)
    OPEN v_rc FOR
      SELECT a.last_name, a.first_name, a.author_id_hal, COUNT(da.document_key) AS doc_cnt
      FROM doc_author da
      JOIN author a ON da.author_key = a.author_key
      WHERE a.last_name LIKE v_auth_prefixes(v_auth_idx)
      GROUP BY a.author_key, a.last_name, a.first_name, a.author_id_hal
      ORDER BY doc_cnt DESC;
    CLOSE v_rc;

    -- Q9: Aggregation — organisms by distinct author count
    OPEN v_rc FOR
      SELECT o.struct_name, o.hal_structure_id, COUNT(DISTINCT ao.author_key) AS auth_cnt
      FROM author_organism ao
      JOIN organism o ON ao.organism_key = o.organism_key
      GROUP BY o.organism_key, o.struct_name, o.hal_structure_id
      ORDER BY auth_cnt DESC;
    CLOSE v_rc;

    -- Q10: CLOB access — read abstracts matching random keyword prefix
    OPEN v_rc FOR
      SELECT DBMS_LOB.SUBSTR(d.abstract, 200, 1)
      FROM document d
      JOIN doc_keyword dk ON d.document_key = dk.document_key
      JOIN keyword      k ON dk.keyword_key = k.keyword_key
      WHERE d.abstract IS NOT NULL
        AND k.keyword_text LIKE v_kw_prefixes(v_kw_idx);
    CLOSE v_rc;

    -- Q11: Filtered star join — alternate keyword prefix each iteration
    OPEN v_rc FOR
      SELECT d.title, d.hal_id_s, k.keyword_text
      FROM document d
      JOIN doc_keyword dk ON d.document_key = dk.document_key
      JOIN keyword      k ON dk.keyword_key = k.keyword_key
      WHERE k.keyword_text LIKE v_kw_prefixes(MOD(v_kw_idx, 12) + 1);
    CLOSE v_rc;

    -- Q12: Correlated subquery — multi-affiliation authors (random name prefix)
    OPEN v_rc FOR
      SELECT a.last_name, a.first_name, a.author_id_hal
      FROM author a
      WHERE a.last_name LIKE v_auth_prefixes(v_auth_idx)
        AND (
          SELECT COUNT(DISTINCT ao.organism_key)
          FROM author_organism ao
          WHERE ao.author_key = a.author_key
        ) > 1;
    CLOSE v_rc;

  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Read stress test complete: ' || v_loops
    || ' iterations x 12 queries = ' || (v_loops * 12) || ' total queries');
END;
/

EXIT
