ALTER SESSION SET CONTAINER = pdb;

-- ── keyword ──────────────────────────────────────────
DROP INDEX idx_keyword_text;
DROP INDEX idx_keyword_text_upper;

-- ── document ─────────────────────────────────────────
DROP INDEX idx_document_hal_id;
DROP INDEX idx_document_doi;
DROP INDEX bidx_document_type;
DROP INDEX bidx_document_discipline;

-- ── doc_keyword ───────────────────────────────────────
DROP INDEX idx_doc_keyword_document;
DROP INDEX idx_dk_keyword;

-- ── doc_author ────────────────────────────────────────
DROP INDEX idx_doc_author_document;
DROP INDEX idx_da_author;
DROP INDEX bidx_doc_author_quality;

-- ── author_organism ───────────────────────────────────
DROP INDEX idx_ao_organism;
DROP INDEX idx_ao_document_author;

-- ── author ────────────────────────────────────────────
DROP INDEX idx_author_name;
DROP INDEX idx_author_lastname_upper;