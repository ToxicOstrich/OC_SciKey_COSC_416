-- =====================================================
-- SAFE DROP
-- =====================================================
BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_doc_author_keyword';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -12003 THEN RAISE; END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_author_doc_counts';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -12003 THEN RAISE; END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_author_organism_distinct';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -12003 THEN RAISE; END IF;
END;
/

-- =====================================================
-- MV 1
-- =====================================================
CREATE MATERIALIZED VIEW mv_doc_author_keyword
TABLESPACE scikey_data
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    d.document_key,
    d.hal_document_id,
    d.hal_id_s,
    d.title,
    d.document_type,
    d.discipline,
    d.doi_id,
    da.author_key,
    da.quality,
    a.author_id_hal,
    a.first_name,
    a.last_name,
    dk.keyword_key,
    k.keyword_text,
    k.wikidata_id
FROM document d
JOIN doc_author da
    ON d.document_key = da.document_key
JOIN author a
    ON da.author_key = a.author_key
JOIN doc_keyword dk
    ON d.document_key = dk.document_key
JOIN keyword k
    ON dk.keyword_key = k.keyword_key;

CREATE INDEX idx_mv_dak_keyword_text
    ON mv_doc_author_keyword(keyword_text)
    TABLESPACE scikey_index;

CREATE INDEX idx_mv_dak_last_name
    ON mv_doc_author_keyword(last_name)
    TABLESPACE scikey_index;

CREATE INDEX idx_mv_dak_dockey
    ON mv_doc_author_keyword(document_key)
    TABLESPACE scikey_index;

CREATE INDEX idx_mv_dak_authorkey
    ON mv_doc_author_keyword(author_key)
    TABLESPACE scikey_index;

-- =====================================================
-- MV 2
-- =====================================================
CREATE MATERIALIZED VIEW mv_author_doc_counts
TABLESPACE scikey_data
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    a.author_key,
    a.author_id_hal,
    a.first_name,
    a.last_name,
    COUNT(DISTINCT da.document_key) AS doc_cnt
FROM doc_author da
JOIN author a
    ON da.author_key = a.author_key
GROUP BY
    a.author_key,
    a.author_id_hal,
    a.first_name,
    a.last_name;

CREATE INDEX idx_mv_adc_last_name
    ON mv_author_doc_counts(last_name)
    TABLESPACE scikey_index;

CREATE INDEX idx_mv_adc_author_key
    ON mv_author_doc_counts(author_key)
    TABLESPACE scikey_index;

CREATE INDEX idx_mv_adc_doc_cnt
    ON mv_author_doc_counts(doc_cnt)
    TABLESPACE scikey_index;

-- =====================================================
-- MV 3
-- =====================================================
CREATE MATERIALIZED VIEW mv_author_organism_distinct
TABLESPACE scikey_data
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT DISTINCT
    a.author_key,
    a.author_id_hal,
    a.first_name,
    a.last_name,
    o.organism_key,
    o.struct_name,
    o.hal_structure_id
FROM author_organism ao
JOIN author a
    ON ao.author_key = a.author_key
JOIN organism o
    ON ao.organism_key = o.organism_key;

CREATE INDEX idx_mv_aod_author_key
    ON mv_author_organism_distinct(author_key)
    TABLESPACE scikey_index;

CREATE INDEX idx_mv_aod_organism_key
    ON mv_author_organism_distinct(organism_key)
    TABLESPACE scikey_index;

CREATE INDEX idx_mv_aod_last_name
    ON mv_author_organism_distinct(last_name)
    TABLESPACE scikey_index;

COMMIT;