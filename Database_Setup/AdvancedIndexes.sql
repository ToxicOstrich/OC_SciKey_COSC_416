-- =====================================================
-- SCIKEY DATABASE — INDEX DDL
-- Run this AFTER data has been fully loaded.
--
-- LOCAL  = one segment per partition, prunes with table
-- GLOBAL = single segment across all partitions
-- =====================================================

ALTER SESSION SET CONTAINER = pdb;

-- ── keyword — LOCAL (partitioned table) ─────────────
-- keyword_text prefix scans (Q2, Q4, Q7, Q10, Q11)
CREATE INDEX idx_keyword_text
    ON keyword(keyword_text)
    LOCAL TABLESPACE scikey_index;

-- Case-insensitive keyword searches
CREATE INDEX idx_keyword_text_upper
    ON keyword(UPPER(keyword_text))
    LOCAL TABLESPACE scikey_index;

-- ── document — LOCAL ─────────────────────────────────
CREATE INDEX idx_document_hal_id
    ON document(hal_id_s)
    LOCAL TABLESPACE scikey_index;

CREATE INDEX idx_document_hal_doc_id
    ON document(hal_document_id)
    LOCAL TABLESPACE scikey_index;

CREATE INDEX idx_document_doi
    ON document(doi_id)
    LOCAL TABLESPACE scikey_index;

-- Bitmap — document_type (low cardinality)
CREATE BITMAP INDEX bidx_document_type
    ON document(document_type)
    LOCAL TABLESPACE scikey_index;

-- Bitmap — discipline (low cardinality)
CREATE BITMAP INDEX bidx_document_discipline
    ON document(discipline)
    LOCAL TABLESPACE scikey_index;

-- ── doc_keyword — LOCAL ──────────────────────────────
CREATE INDEX idx_doc_keyword_document
    ON doc_keyword(document_key)
    LOCAL TABLESPACE scikey_index;

CREATE INDEX idx_dk_keyword
    ON doc_keyword(keyword_key)
    LOCAL TABLESPACE scikey_index;

-- ── doc_author — LOCAL ───────────────────────────────
CREATE INDEX idx_doc_author_document
    ON doc_author(document_key)
    LOCAL TABLESPACE scikey_index;

CREATE INDEX idx_da_author
    ON doc_author(author_key)
    LOCAL TABLESPACE scikey_index;

-- Bitmap — quality (low cardinality)
CREATE BITMAP INDEX bidx_doc_author_quality
    ON doc_author(quality)
    LOCAL TABLESPACE scikey_index;

-- ── author_organism — LOCAL ──────────────────────────
CREATE INDEX idx_ao_organism
    ON author_organism(organism_key)
    LOCAL TABLESPACE scikey_index;

CREATE INDEX idx_ao_document_author
    ON author_organism(document_key, author_key)
    LOCAL TABLESPACE scikey_index;

-- ── author — GLOBAL (unpartitioned dimension table) ──
CREATE INDEX idx_author_name
    ON author(last_name, first_name)
    TABLESPACE scikey_index;

CREATE INDEX idx_author_lastname_upper
    ON author(UPPER(last_name))
    TABLESPACE scikey_index;

COMMIT;