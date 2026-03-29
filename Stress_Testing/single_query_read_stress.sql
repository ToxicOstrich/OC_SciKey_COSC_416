SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TIMING ON
SET SERVEROUTPUT ON SIZE 1000000
WHENEVER SQLERROR CONTINUE

-- =====================================================
-- EXPLAIN PLAN CHECK
-- =====================================================
EXPLAIN PLAN FOR
  SELECT /*+ FULL(d) FULL(dk) FULL(k) FULL(da) FULL(a) FULL(ao) FULL(o)
             NO_INDEX(d) NO_INDEX(dk) NO_INDEX(k) NO_INDEX(da)
             NO_INDEX(a) NO_INDEX(ao) NO_INDEX(o) */
          d.title,
          d.document_type,
          d.doi_id,
          DBMS_LOB.SUBSTR(d.abstract, 300, 1) AS abstract_preview,
          a.last_name,
          a.first_name,
          o.struct_name AS institution,
          k.keyword_text,
          (SELECT /*+ FULL(da2) NO_INDEX(da2) */ COUNT(*)
           FROM doc_author da2
           WHERE da2.document_key = d.document_key) AS coauthor_count
  FROM document d
  JOIN doc_keyword  dk ON d.document_key          = dk.document_key
  JOIN keyword       k ON dk.keyword_key           = k.keyword_key
  JOIN doc_author   da ON d.document_key           = da.document_key
  JOIN author        a ON da.author_key            = a.author_key
  LEFT JOIN author_organism ao ON da.document_key  = ao.document_key
                              AND da.author_key     = ao.author_key
  LEFT JOIN organism o ON ao.organism_key           = o.organism_key
  WHERE SUBSTR(k.keyword_text, 1, 4000) LIKE 'system%'
    AND SUBSTR(a.last_name,    1, 4000) LIKE 'S%'
  ORDER BY coauthor_count DESC, d.title;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'ALL'));

-- =====================================================
-- STRESS TEST
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
      SELECT /*+ FULL(d) FULL(dk) FULL(k) FULL(da) FULL(a) FULL(ao) FULL(o)
                 NO_INDEX(d) NO_INDEX(dk) NO_INDEX(k) NO_INDEX(da)
                 NO_INDEX(a) NO_INDEX(ao) NO_INDEX(o) */
              d.title,
              d.document_type,
              d.doi_id,
              DBMS_LOB.SUBSTR(d.abstract, 300, 1) AS abstract_preview,
              a.last_name,
              a.first_name,
              o.struct_name AS institution,
              k.keyword_text,
              (SELECT /*+ FULL(da2) NO_INDEX(da2) */ COUNT(*)
               FROM doc_author da2
               WHERE da2.document_key = d.document_key) AS coauthor_count
      FROM document d
      JOIN doc_keyword  dk ON d.document_key         = dk.document_key
      JOIN keyword       k ON dk.keyword_key          = k.keyword_key
      JOIN doc_author   da ON d.document_key          = da.document_key
      JOIN author        a ON da.author_key           = a.author_key
      LEFT JOIN author_organism ao ON da.document_key = ao.document_key
                                  AND da.author_key   = ao.author_key
      LEFT JOIN organism o ON ao.organism_key          = o.organism_key
      WHERE SUBSTR(k.keyword_text, 1, 4000) LIKE v_kw_prefixes(v_kw_idx)
        AND SUBSTR(a.last_name,    1, 4000) LIKE v_auth_prefixes(v_auth_idx)
      ORDER BY coauthor_count DESC, d.title;

    CLOSE v_rc;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Single-query stress test complete: '
    || v_loops || ' iterations');
END;
/
EXIT
