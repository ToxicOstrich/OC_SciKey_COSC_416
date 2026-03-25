ALTER SESSION SET CONTAINER = pdb;

-- =====================================================
-- DROP EVERYTHING (in correct order)
-- =====================================================
DROP TABLE author_organism  CASCADE CONSTRAINTS PURGE;
DROP TABLE doc_keyword      CASCADE CONSTRAINTS PURGE;
DROP TABLE doc_author       CASCADE CONSTRAINTS PURGE;
DROP TABLE document         CASCADE CONSTRAINTS PURGE;
DROP TABLE organism         CASCADE CONSTRAINTS PURGE;
DROP TABLE author           CASCADE CONSTRAINTS PURGE;
DROP TABLE keyword          CASCADE CONSTRAINTS PURGE;

DROP SEQUENCE seq_keyword;
DROP SEQUENCE seq_author;
DROP SEQUENCE seq_organism;
DROP SEQUENCE seq_document;

-- =====================================================
-- CREATE SEQUENCES
-- =====================================================
CREATE SEQUENCE seq_keyword    START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_author     START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_organism   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_document   START WITH 1 INCREMENT BY 1;

-- =====================================================
-- DIMENSION TABLES
-- =====================================================

-- Keyword dimension
CREATE TABLE keyword (
    keyword_key  NUMBER(19) DEFAULT seq_keyword.NEXTVAL PRIMARY KEY,
    keyword_text VARCHAR2(1000) NOT NULL,
    wikidata_id VARCHAR2(20),
    bnf_id      VARCHAR2(100),
    CONSTRAINT uk_keyword_wikidata_id UNIQUE (wikidata_id),
    CONSTRAINT uk_keyword_bnf_id UNIQUE (bnf_id)
)
TABLESPACE scikey_data;

-- Author dimension (unique person)
CREATE TABLE author (
    author_key  NUMBER(19) DEFAULT seq_author.NEXTVAL PRIMARY KEY,
    author_id_hal   VARCHAR2(100) NOT NULL,      -- e.g., 'gaetan-hains'
    first_name  VARCHAR2(255),
    last_name   VARCHAR2(255),
    CONSTRAINT uk_author_author_id UNIQUE (author_id_hal)
)
TABLESPACE scikey_data;

-- Organism dimension (institution/structure)
CREATE TABLE organism (
    organism_key      NUMBER(19) DEFAULT seq_organism.NEXTVAL PRIMARY KEY,
    hal_structure_id  NUMBER(19) NOT NULL,
    struct_name       VARCHAR2(255),
    CONSTRAINT uk_organism_hal_id UNIQUE (hal_structure_id)
)
TABLESPACE scikey_data;

-- =====================================================
-- FACT TABLE (DOCUMENT)
-- =====================================================

CREATE TABLE document (
    document_key    NUMBER(19) DEFAULT seq_document.NEXTVAL PRIMARY KEY,
    hal_document_id NUMBER(19) NOT NULL,               -- business key from HAL
    hal_id_s        VARCHAR2(50),                      -- proper string format HAL ID
    document_type   VARCHAR2(50),
    classification  VARCHAR2(300),                     
    title           VARCHAR2(600),
    abstract        CLOB,
    discipline      VARCHAR2(100),
    domain_codes    CLOB,
    url_primary     CLOB,
    doi_id          VARCHAR2(255),                       
    isbn            VARCHAR2(255),                       
    CONSTRAINT uk_document_hal_document_id UNIQUE (hal_document_id)
)
TABLESPACE scikey_data
LOB (abstract, domain_codes, url_primary) STORE AS (TABLESPACE scikey_data);

-- =====================================================
-- BRIDGE TABLES (many-to-many relationships)
-- =====================================================

-- Document ↔ Keyword
CREATE TABLE doc_keyword (
    document_key NUMBER(19) NOT NULL,
    keyword_key  NUMBER(19) NOT NULL,
    CONSTRAINT pk_doc_keyword PRIMARY KEY (document_key, keyword_key),
    CONSTRAINT fk_dk_document FOREIGN KEY (document_key) REFERENCES document(document_key) ON DELETE CASCADE,
    CONSTRAINT fk_dk_keyword  FOREIGN KEY (keyword_key)  REFERENCES keyword(keyword_key) ON DELETE CASCADE
)
TABLESPACE scikey_data;

-- Document ↔ Author (with occurrence attributes)
CREATE TABLE doc_author (
    document_key  NUMBER(19) NOT NULL,
    author_key    NUMBER(19) NOT NULL,
    author_index  NUMBER(10) NOT NULL,   -- position in the author list (0 = first)
    quality       VARCHAR2(50),           -- e.g., 'aut' for author, 'dgs' for advisor, etc. --contribution type
    CONSTRAINT pk_doc_author PRIMARY KEY (document_key, author_key),
    CONSTRAINT uk_doc_author_order UNIQUE (document_key, author_index), -- ensures one author per position
    CONSTRAINT fk_da_document FOREIGN KEY (document_key) REFERENCES document(document_key) ON DELETE CASCADE,
    CONSTRAINT fk_da_author   FOREIGN KEY (author_key)   REFERENCES author(author_key) ON DELETE CASCADE
)
TABLESPACE scikey_data;

-- Author‑Organism (per document occurrence)
CREATE TABLE author_organism (
    document_key   NUMBER(19) NOT NULL,
    author_key     NUMBER(19) NOT NULL,
    organism_key   NUMBER(19) NOT NULL,
    CONSTRAINT pk_author_organism PRIMARY KEY (document_key, author_key, organism_key),
    CONSTRAINT fk_ao_doc_author FOREIGN KEY (document_key, author_key)
        REFERENCES doc_author(document_key, author_key) ON DELETE CASCADE,
    CONSTRAINT fk_ao_organism   FOREIGN KEY (organism_key)
        REFERENCES organism(organism_key) ON DELETE CASCADE
)
TABLESPACE scikey_data;

-- =====================================================
-- INDEXES FOR PERFORMANCE 
-- =====================================================
-- All indexes explicitly placed in scikey_index tablespace
CREATE INDEX idx_da_author ON doc_author(author_key) 
TABLESPACE scikey_index;

CREATE INDEX idx_dk_keyword ON doc_keyword(keyword_key) 
TABLESPACE scikey_index;

CREATE INDEX idx_ao_organism ON author_organism(organism_key) 
TABLESPACE scikey_index;

CREATE INDEX idx_keyword_text ON keyword(keyword_text) 
TABLESPACE scikey_index;

CREATE INDEX idx_author_name ON author(last_name, first_name) 
TABLESPACE scikey_index;

CREATE INDEX idx_document_hal_id ON document(hal_id_s) 
TABLESPACE scikey_index;

COMMIT;
