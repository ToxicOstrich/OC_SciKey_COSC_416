#!/usr/bin/env bash
# =============================================================
# READ STRESS TEST — exercises every table, index, and join path
# =============================================================
DB_USER="your user"
DB_PASS="your password"
DB_CONN="your connection string"

SESSIONS=${1:-4}
LOOPS=${2:-50}

run_session() {
  local sid=$1

  sqlplus -s "${DB_USER}/${DB_PASS}@${DB_CONN} as sysdba" <<SQL > "read_stress_session_${sid}.log" 2>&1
SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TIMING ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

DECLARE
  v_cnt   NUMBER;
  v_dummy VARCHAR2(4000);
BEGIN
  FOR i IN 1..${LOOPS} LOOP

    -- =======================================================
    -- Q1: Full table count on fact table (baseline)
    -- =======================================================
    SELECT COUNT(*) INTO v_cnt FROM document;

    -- =======================================================
    -- Q2: Index scan — keyword text lookup (idx_keyword_text)
    -- =======================================================
    BEGIN
      SELECT keyword_text INTO v_dummy
      FROM keyword
      WHERE keyword_text LIKE 'stress%'
      AND ROWNUM = 1;
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
    END;

    -- =======================================================
    -- Q3: Index scan — author name lookup (idx_author_name)
    -- =======================================================
    BEGIN
      SELECT last_name || ', ' || first_name INTO v_dummy
      FROM author
      WHERE last_name LIKE 'S%'
      AND ROWNUM = 1;
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
    END;

    -- =======================================================
    -- Q4: Two-table join — documents with their keywords
    --     (doc_keyword bridge → keyword)
    -- =======================================================
    SELECT COUNT(*) INTO v_cnt
    FROM doc_keyword dk
    JOIN keyword k ON dk.keyword_key = k.keyword_key;

    -- =======================================================
    -- Q5: Two-table join — documents with their authors
    --     (doc_author bridge → author)
    -- =======================================================
    SELECT COUNT(*) INTO v_cnt
    FROM doc_author da
    JOIN author a ON da.author_key = a.author_key;

    -- =======================================================
    -- Q6: Three-table join — author affiliations per document
    --     (author_organism → doc_author → organism)
    -- =======================================================
    SELECT COUNT(*) INTO v_cnt
    FROM author_organism ao
    JOIN doc_author da ON ao.document_key = da.document_key
                      AND ao.author_key   = da.author_key
    JOIN organism o    ON ao.organism_key  = o.organism_key;

    -- =======================================================
    -- Q7: Full star join — document → authors → keywords
    --     Simulates a real search result page
    -- =======================================================
    SELECT COUNT(*) INTO v_cnt
    FROM document d
    JOIN doc_author  da ON d.document_key = da.document_key
    JOIN author       a ON da.author_key  = a.author_key
    JOIN doc_keyword dk ON d.document_key = dk.document_key
    JOIN keyword      k ON dk.keyword_key = k.keyword_key;

    -- =======================================================
    -- Q8: Aggregation — top authors by document count
    -- =======================================================
    BEGIN
      SELECT a.last_name INTO v_dummy
      FROM doc_author da
      JOIN author a ON da.author_key = a.author_key
      GROUP BY a.author_key, a.last_name
      ORDER BY COUNT(*) DESC
      FETCH FIRST 1 ROW ONLY;
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
    END;

    -- =======================================================
    -- Q9: Aggregation — top organisms by author count
    -- =======================================================
    BEGIN
      SELECT o.struct_name INTO v_dummy
      FROM author_organism ao
      JOIN organism o ON ao.organism_key = o.organism_key
      GROUP BY o.organism_key, o.struct_name
      ORDER BY COUNT(DISTINCT ao.author_key) DESC
      FETCH FIRST 1 ROW ONLY;
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
    END;

    -- =======================================================
    -- Q10: CLOB access — read abstract from fact table
    --      Forces LOB segment I/O
    -- =======================================================
    BEGIN
      SELECT DBMS_LOB.SUBSTR(abstract, 200, 1) INTO v_dummy
      FROM document
      WHERE abstract IS NOT NULL
      AND ROWNUM = 1;
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
    END;

    -- =======================================================
    -- Q11: Filtered star join — specific keyword search
    --      Realistic "find papers about X" query
    -- =======================================================
    SELECT COUNT(*) INTO v_cnt
    FROM document d
    JOIN doc_keyword dk ON d.document_key = dk.document_key
    JOIN keyword      k ON dk.keyword_key = k.keyword_key
    WHERE k.keyword_text LIKE 'algorithm%';

    -- =======================================================
    -- Q12: Correlated subquery — authors who published with
    --      more than one organism (tests nested loops)
    -- =======================================================
    SELECT COUNT(*) INTO v_cnt
    FROM author a
    WHERE (
      SELECT COUNT(DISTINCT ao.organism_key)
      FROM author_organism ao
      WHERE ao.author_key = a.author_key
    ) > 1;

  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Session ${sid}: ${LOOPS} iterations complete');
END;
/

EXIT
SQL
}

echo "Starting read stress test: ${SESSIONS} sessions x ${LOOPS} loops"
echo "Each loop runs 12 queries across all 6 tables"
echo "---"

START_TIME=$(date +%s)

for ((i=1; i<=SESSIONS; i++)); do
  run_session "$i" &
done

wait

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
TOTAL_QUERIES=$((SESSIONS * LOOPS * 12))

echo "---"
echo "Read stress test complete."
echo "Total queries executed: ${TOTAL_QUERIES}"
echo "Wall clock time: ${ELAPSED}s"
echo "Throughput: ~$((TOTAL_QUERIES / (ELAPSED + 1))) queries/sec"
echo ""
echo "Per-session logs: read_stress_session_*.log"
echo "Check logs for 'Elapsed:' lines to see individual query timings."
