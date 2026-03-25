SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TIMING ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

DECLARE
  v_loops NUMBER := 50;
  v_rc    SYS_REFCURSOR;
BEGIN
  FOR i IN 1..v_loops LOOP

    -- Q1: Fact table scan
    OPEN v_rc FOR
      SELECT d.title, d.document_type, d.discipline
      FROM document d
      WHERE ROWNUM = 1;
    CLOSE v_rc;

    -- Q2: Index scan — keyword text (idx_keyword_text)
    OPEN v_rc FOR
      SELECT k.keyword_key, k.keyword_text, k.wikidata_id
      FROM keyword k
      WHERE k.keyword_text LIKE 'stress%'
      AND ROWNUM = 1;
    CLOSE v_rc;

    -- Q3: Index scan — author name (idx_author_name)
    OPEN v_rc FOR
      SELECT a.author_key, a.last_name, a.first_name, a.author_id_hal
      FROM author a
      WHERE a.last_name LIKE 'S%'
      AND ROWNUM = 1;
    CLOSE v_rc;

    -- Q4: Two-table join — documents with keywords
    OPEN v_rc FOR
      SELECT d.title, k.keyword_text
      FROM doc_keyword dk
      JOIN keyword  k ON dk.keyword_key  = k.keyword_key
      JOIN document d ON dk.document_key = d.document_key
      WHERE ROWNUM = 1;
    CLOSE v_rc;

    -- Q5: Two-table join — documents with authors
    OPEN v_rc FOR
      SELECT d.title, a.last_name, a.first_name, da.quality
      FROM doc_author da
      JOIN author   a ON da.author_key   = a.author_key
      JOIN document d ON da.document_key = d.document_key
      WHERE ROWNUM = 1;
    CLOSE v_rc;

    -- Q6: Three-table join — author affiliations per document
    OPEN v_rc FOR
      SELECT a.last_name, o.struct_name, d.title
      FROM author_organism ao
      JOIN doc_author da ON ao.document_key = da.document_key
                        AND ao.author_key   = da.author_key
      JOIN organism o    ON ao.organism_key  = o.organism_key
      JOIN author   a    ON da.author_key    = a.author_key
      JOIN document d    ON da.document_key  = d.document_key
      WHERE ROWNUM = 1;
    CLOSE v_rc;

    -- Q7: Full star join — document + authors + keywords
    OPEN v_rc FOR
      SELECT d.title, a.last_name, k.keyword_text, d.doi_id
      FROM document d
      JOIN doc_author  da ON d.document_key = da.document_key
      JOIN author       a ON da.author_key  = a.author_key
      JOIN doc_keyword dk ON d.document_key = dk.document_key
      JOIN keyword      k ON dk.keyword_key = k.keyword_key
      WHERE ROWNUM = 1;
    CLOSE v_rc;

    -- Q8: Aggregation — top author by document count
    OPEN v_rc FOR
      SELECT a.last_name, a.first_name, a.author_id_hal
      FROM doc_author da
      JOIN author a ON da.author_key = a.author_key
      GROUP BY a.author_key, a.last_name, a.first_name, a.author_id_hal
      ORDER BY COUNT(da.document_key) DESC
      FETCH FIRST 1 ROW ONLY;
    CLOSE v_rc;

    -- Q9: Aggregation — top organism by distinct author count
    OPEN v_rc FOR
      SELECT o.struct_name, o.hal_structure_id
      FROM author_organism ao
      JOIN organism o ON ao.organism_key = o.organism_key
      GROUP BY o.organism_key, o.struct_name, o.hal_structure_id
      ORDER BY COUNT(DISTINCT ao.author_key) DESC
      FETCH FIRST 1 ROW ONLY;
    CLOSE v_rc;

    -- Q10: CLOB access — read abstract
    OPEN v_rc FOR
      SELECT DBMS_LOB.SUBSTR(d.abstract, 200, 1)
      FROM document d
      WHERE d.abstract IS NOT NULL
      AND ROWNUM = 1;
    CLOSE v_rc;

    -- Q11: Filtered star join — keyword search
    OPEN v_rc FOR
      SELECT d.title, d.hal_id_s, k.keyword_text
      FROM document d
      JOIN doc_keyword dk ON d.document_key = dk.document_key
      JOIN keyword      k ON dk.keyword_key = k.keyword_key
      WHERE k.keyword_text LIKE 'algorithm%'
      AND ROWNUM = 1;
    CLOSE v_rc;

    -- Q12: Correlated subquery — multi-affiliation authors
    OPEN v_rc FOR
      SELECT a.last_name, a.first_name, a.author_id_hal
      FROM author a
      WHERE (
        SELECT COUNT(DISTINCT ao.organism_key)
        FROM author_organism ao
        WHERE ao.author_key = a.author_key
      ) > 1
      AND ROWNUM = 1;
    CLOSE v_rc;

  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Read stress test complete: ' || v_loops || ' iterations x 12 queries = ' || (v_loops * 12) || ' total queries');
END;
/

EXIT
