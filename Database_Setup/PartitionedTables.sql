-- =====================================================
-- SCIKEY DATABASE — FULL DDL
-- Oracle 19c | Partitioned + Indexed
-- =====================================================

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
CREATE SEQUENCE seq_keyword  START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_author   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_organism START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_document START WITH 1 INCREMENT BY 1;

-- =====================================================
-- KEYWORD
-- Range partitioned by first character of keyword_text.
--
-- Distribution (868k total):
--   Latin    848,518  — partitioned A-Z individually
--   Other     12,940  \
--   Numeric    7,068   }— caught in p_kw_other (MAXVALUE)
--   Cyrillic      27  /
-- =====================================================
CREATE TABLE keyword (
    keyword_key  NUMBER(19)     DEFAULT seq_keyword.NEXTVAL,
    keyword_text VARCHAR2(1000) NOT NULL,
    wikidata_id  VARCHAR2(20),
    bnf_id       VARCHAR2(100),
    CONSTRAINT pk_keyword             PRIMARY KEY (keyword_key),
    CONSTRAINT uk_keyword_wikidata_id UNIQUE (wikidata_id),
    CONSTRAINT uk_keyword_bnf_id      UNIQUE (bnf_id)
)
TABLESPACE scikey_data
PARTITION BY RANGE (keyword_text)
(
    PARTITION p_kw_a    VALUES LESS THAN ('B'),   -- A: 61,393
    PARTITION p_kw_b    VALUES LESS THAN ('C'),   -- B: 29,092
    PARTITION p_kw_c    VALUES LESS THAN ('D'),   -- C: 87,884
    PARTITION p_kw_d    VALUES LESS THAN ('E'),   -- D: 45,564
    PARTITION p_kw_e    VALUES LESS THAN ('F'),   -- E: 43,669
    PARTITION p_kw_f    VALUES LESS THAN ('G'),   -- F: 34,368
    PARTITION p_kw_g    VALUES LESS THAN ('H'),   -- G: 27,359
    PARTITION p_kw_h    VALUES LESS THAN ('I'),   -- H: 27,654
    PARTITION p_kw_i    VALUES LESS THAN ('J'),   -- I: 38,895
    PARTITION p_kw_j    VALUES LESS THAN ('K'),   -- J:  6,230
    PARTITION p_kw_k    VALUES LESS THAN ('L'),   -- K:  5,680
    PARTITION p_kw_l    VALUES LESS THAN ('M'),   -- L: 34,994
    PARTITION p_kw_m    VALUES LESS THAN ('N'),   -- M: 68,914
    PARTITION p_kw_n    VALUES LESS THAN ('O'),   -- N: 24,170
    PARTITION p_kw_o    VALUES LESS THAN ('P'),   -- O: 19,493
    PARTITION p_kw_p    VALUES LESS THAN ('Q'),   -- P: 77,618
    PARTITION p_kw_q    VALUES LESS THAN ('R'),   -- Q:  5,016
    PARTITION p_kw_r    VALUES LESS THAN ('S'),   -- R: 44,646
    PARTITION p_kw_s    VALUES LESS THAN ('T'),   -- S: 81,533
    PARTITION p_kw_t    VALUES LESS THAN ('U'),   -- T: 44,056
    PARTITION p_kw_u    VALUES LESS THAN ('V'),   -- U:  9,004
    PARTITION p_kw_v    VALUES LESS THAN ('W'),   -- V: 17,025
    PARTITION p_kw_w    VALUES LESS THAN ('X'),   -- W:  9,461
    PARTITION p_kw_xyz  VALUES LESS THAN ('a'),   -- X:1,591 Y:1,085 Z:2,124
    PARTITION p_kw_other VALUES LESS THAN (MAXVALUE) -- Numeric, Cyrillic, Other
);

-- =====================================================
-- AUTHOR (unpartitioned — dimension table)
-- =====================================================
CREATE TABLE author (
    author_key    NUMBER(19)    DEFAULT seq_author.NEXTVAL PRIMARY KEY,
    author_id_hal VARCHAR2(100) NOT NULL,
    first_name    VARCHAR2(255),
    last_name     VARCHAR2(255),
    CONSTRAINT uk_author_author_id UNIQUE (author_id_hal)
)
TABLESPACE scikey_data;

-- =====================================================
-- ORGANISM (unpartitioned — dimension table)
-- =====================================================
CREATE TABLE organism (
    organism_key     NUMBER(19) DEFAULT seq_organism.NEXTVAL PRIMARY KEY,
    hal_structure_id NUMBER(19) NOT NULL,
    struct_name      VARCHAR2(255),
    CONSTRAINT uk_organism_hal_id UNIQUE (hal_structure_id)
)
TABLESPACE scikey_data;

-- =====================================================
-- DOCUMENT
-- Composite partitioning: LIST (discipline) x HASH (hal_document_id)
--
-- LOB clause must appear BEFORE PARTITION BY clause (ORA-14301).
--
-- Distribution:
--   NULL                 524,396  → 16 subpartitions
--   Computer Science     133,006  →  8 subpartitions
--   Chemical Engineering  46,675  →  4 subpartitions
--   Marketing             17,237  →  2 subpartitions
--   Political Science     15,612  →  2 subpartitions
--   Civil Engineering     13,074  →  2 subpartitions
-- =====================================================
CREATE TABLE document (
    document_key    NUMBER(19)    DEFAULT seq_document.NEXTVAL,
    hal_document_id NUMBER(19)    NOT NULL,
    hal_id_s        VARCHAR2(50),
    document_type   VARCHAR2(50),
    classification  VARCHAR2(300),
    title           VARCHAR2(600),
    abstract        CLOB,
    discipline      VARCHAR2(100),
    domain_codes    CLOB,
    url_primary     CLOB,
    doi_id          VARCHAR2(255),
    isbn            VARCHAR2(255),
    CONSTRAINT pk_document        PRIMARY KEY (document_key),
    CONSTRAINT uk_document_hal_id UNIQUE (hal_document_id)
)
TABLESPACE scikey_data
LOB (abstract, domain_codes, url_primary) STORE AS
    (TABLESPACE scikey_data ENABLE STORAGE IN ROW CHUNK 8192 NOCACHE)
PARTITION BY LIST (discipline)
SUBPARTITION BY HASH (hal_document_id)
(
    PARTITION p_unknown   VALUES (NULL)                   SUBPARTITIONS 16,
    PARTITION p_cs        VALUES ('Computer Science')     SUBPARTITIONS 8,
    PARTITION p_chemeng   VALUES ('Chemical Engineering') SUBPARTITIONS 4,
    PARTITION p_marketing VALUES ('Marketing')            SUBPARTITIONS 2,
    PARTITION p_polisci   VALUES ('Political Science')    SUBPARTITIONS 2,
    PARTITION p_civil     VALUES ('Civil Engineering')    SUBPARTITIONS 2
);

-- =====================================================
-- BRIDGE TABLES
-- Reference partitioned — inherits document partitions
-- via foreign key chain.
-- NOTE: FK must be NOT DEFERRABLE for reference partitioning.
-- =====================================================

-- Document ↔ Keyword
CREATE TABLE doc_keyword (
    document_key NUMBER(19) NOT NULL,
    keyword_key  NUMBER(19) NOT NULL,
    CONSTRAINT pk_doc_keyword PRIMARY KEY (document_key, keyword_key),
    CONSTRAINT fk_dk_document FOREIGN KEY (document_key)
        REFERENCES document(document_key) ON DELETE CASCADE NOT DEFERRABLE,
    CONSTRAINT fk_dk_keyword  FOREIGN KEY (keyword_key)
        REFERENCES keyword(keyword_key)   ON DELETE CASCADE
)
PARTITION BY REFERENCE (fk_dk_document)
TABLESPACE scikey_data;

-- Document ↔ Author
CREATE TABLE doc_author (
    document_key NUMBER(19) NOT NULL,
    author_key   NUMBER(19) NOT NULL,
    author_index NUMBER(10) NOT NULL,
    quality      VARCHAR2(50),
    CONSTRAINT pk_doc_author       PRIMARY KEY (document_key, author_key),
    CONSTRAINT uk_doc_author_order UNIQUE (document_key, author_index),
    CONSTRAINT fk_da_document      FOREIGN KEY (document_key)
        REFERENCES document(document_key) ON DELETE CASCADE NOT DEFERRABLE,
    CONSTRAINT fk_da_author        FOREIGN KEY (author_key)
        REFERENCES author(author_key)     ON DELETE CASCADE
)
PARTITION BY REFERENCE (fk_da_document)
TABLESPACE scikey_data;

-- Author ↔ Organism (per document)
CREATE TABLE author_organism (
    document_key NUMBER(19) NOT NULL,
    author_key   NUMBER(19) NOT NULL,
    organism_key NUMBER(19) NOT NULL,
    CONSTRAINT pk_author_organism PRIMARY KEY (document_key, author_key, organism_key),
    CONSTRAINT fk_ao_doc_author   FOREIGN KEY (document_key, author_key)
        REFERENCES doc_author(document_key, author_key) ON DELETE CASCADE NOT DEFERRABLE,
    CONSTRAINT fk_ao_organism     FOREIGN KEY (organism_key)
        REFERENCES organism(organism_key) ON DELETE CASCADE
)
PARTITION BY REFERENCE (fk_ao_doc_author)
TABLESPACE scikey_data;

COMMIT;