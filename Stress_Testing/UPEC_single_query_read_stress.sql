SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TIMING ON
SET SERVEROUTPUT ON SIZE 1000000
WHENEVER SQLERROR CONTINUE
-- =====================================================
-- STRESS TEST
-- Configure v_loops to set number of iterations
-- =====================================================
DECLARE
  v_loops NUMBER := 1000;
  v_rc    SYS_REFCURSOR;
BEGIN
  FOR i IN 1..v_loops LOOP
    OPEN v_rc FOR
      SELECT d.title,
             d.document_type,
             d.doi_id,
             DBMS_LOB.SUBSTR(d.abstract, 300, 1) AS abstract_preview,
             a.last_name,
             a.first_name,
             o.struct_name AS institution,
             k.keyword_text,
             k.wikidata_id,
             (SELECT COUNT(*)
              FROM doc_author da2
              WHERE da2.document_key = d.document_key) AS coauthor_count
      FROM document d
      JOIN doc_author      da ON d.document_key  = da.document_key
      JOIN author           a ON da.author_key   = a.author_key
      JOIN author_organism ao ON da.document_key = ao.document_key
                             AND da.author_key    = ao.author_key
      JOIN organism          o ON ao.organism_key = o.organism_key
      JOIN doc_keyword      dk ON d.document_key  = dk.document_key
      JOIN keyword           k ON dk.keyword_key  = k.keyword_key
      WHERE o.hal_structure_id = 420786
        AND k.wikidata_id = 'Q462462905'
      ORDER BY coauthor_count DESC, d.title;
 CLOSE v_rc;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('UPEC Wikidata stress test complete: '
    || v_loops || ' iterations');
END;
/
EXIT
