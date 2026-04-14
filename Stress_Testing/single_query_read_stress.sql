SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TIMING ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

DECLARE
    v_loops          NUMBER := 1000;
    v_rc             SYS_REFCURSOR;

    TYPE t_str_tab IS TABLE OF VARCHAR2(60) INDEX BY PLS_INTEGER;

    v_kw_prefixes    t_str_tab;
    v_auth_prefixes  t_str_tab;
    v_kw_idx         PLS_INTEGER;
    v_auth_idx       PLS_INTEGER;
    v_title          VARCHAR2(500);
    v_doc_type       VARCHAR2(100);
    v_doi            VARCHAR2(100);
    v_abstract       VARCHAR2(300);
    v_last_name      VARCHAR2(100);
    v_first_name     VARCHAR2(100);
    v_institution    VARCHAR2(200);
    v_keyword        VARCHAR2(100);
    v_coauthor_cnt   NUMBER;
    v_row_count      NUMBER;
    v_total_rows     NUMBER := 0;

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
        v_row_count := 0;

        OPEN v_rc FOR
            SELECT d.title,
                   d.document_type,
                   d.doi_id,
                   DBMS_LOB.SUBSTR(d.abstract, 300, 1) AS abstract_preview,
                   a.last_name,
                   a.first_name,
                   o.struct_name                        AS institution,
                   k.keyword_text,
                   (SELECT COUNT(*)
                      FROM doc_author da2
                     WHERE da2.document_key = d.document_key) AS coauthor_count
              FROM document    d
              JOIN doc_keyword dk ON d.document_key  = dk.document_key
              JOIN keyword     k  ON dk.keyword_key  = k.keyword_key
              JOIN doc_author  da ON d.document_key   = da.document_key
              JOIN author      a  ON da.author_key    = a.author_key
         LEFT JOIN author_organism ao ON da.document_key = ao.document_key
                                     AND da.author_key   = ao.author_key
         LEFT JOIN organism    o  ON ao.organism_key  = o.organism_key
             WHERE k.keyword_text LIKE v_kw_prefixes(v_kw_idx)
               AND a.last_name    LIKE v_auth_prefixes(v_auth_idx)
             ORDER BY coauthor_count DESC, d.title;

        LOOP
            FETCH v_rc INTO v_title, v_doc_type, v_doi, v_abstract,
                            v_last_name, v_first_name, v_institution,
                            v_keyword, v_coauthor_cnt;
            EXIT WHEN v_rc%NOTFOUND;
            v_row_count := v_row_count + 1;
        END LOOP;

        CLOSE v_rc;
        v_total_rows := v_total_rows + v_row_count;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Stress test complete: '
        || v_loops || ' iterations, '
        || v_total_rows || ' total rows fetched');
END;
/

EXIT
