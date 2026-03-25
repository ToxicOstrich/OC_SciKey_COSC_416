"""
load_hal_json.py
================
Loads HAL JSON records into an Oracle 19c database in memory-efficient chunks.

Dependencies:
    pip install oracledb

Usage:
    python load_hal_json.py --file path/to/records.json

The script is idempotent: re-running it on the same data will not create
duplicates (it uses INSERT-or-skip logic based on the unique constraints
defined in the DDL).
"""

import argparse
import json
import logging
import sys
from pathlib import Path

import oracledb  # python-oracledb (successor to cx_Oracle)

# ──────────────────────────────────────────────
# CONFIGURATION  –  edit these before running
# ──────────────────────────────────────────────
DB_DSN      = "localhost:1521/pdb"   # host:port/service_name

CHUNK_SIZE  = 500   # number of JSON records held in memory at once
LOG_LEVEL   = logging.INFO
# ──────────────────────────────────────────────

logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger(__name__)


# ──────────────────────────────────────────────────────────────────────────────
# JSON streaming helpers
# ──────────────────────────────────────────────────────────────────────────────

def iter_json_chunks(filepath: Path, chunk_size: int):
    """
    Yields lists of records of length <= chunk_size without loading the
    entire file into memory.  Assumes the top-level JSON value is an array.
    """
    with filepath.open("r", encoding="utf-8") as fh:
        # json.JSONDecoder lets us pull objects one at a time from the stream.
        decoder = json.JSONDecoder()
        raw = fh.read()          # read full text; streaming parse below keeps
                                 # only one chunk worth of *objects* in memory
        idx = 0
        length = len(raw)

        # skip leading whitespace / opening bracket
        while idx < length and raw[idx] in " \t\n\r":
            idx += 1
        if idx >= length or raw[idx] != "[":
            raise ValueError("Top-level JSON value must be an array.")
        idx += 1  # consume '['

        chunk: list[dict] = []
        while idx < length:
            # skip whitespace and commas between objects
            while idx < length and raw[idx] in " \t\n\r,":
                idx += 1
            if idx >= length or raw[idx] == "]":
                break
            obj, end_idx = decoder.raw_decode(raw, idx)
            idx = end_idx
            chunk.append(obj)
            if len(chunk) >= chunk_size:
                yield chunk
                chunk = []

        if chunk:
            yield chunk


# ──────────────────────────────────────────────────────────────────────────────
# Parsing helpers
# ──────────────────────────────────────────────────────────────────────────────

def parse_author_structures(auth_id_has_structure: list[str]) -> dict[str, list[tuple[int, str]]]:
    """
    Parse authIdHasStructure_fs into a dict keyed by person-composite-ID
    (e.g. '557364-772577') mapping to a list of (struct_id, struct_name).

    Entry format:
      "<personCompositeId>_FacetSep_<Full Name>_JoinSep_<structId>_FacetSep_<structName>"
    """
    result: dict[str, list[tuple[int, str]]] = {}
    for entry in auth_id_has_structure:
        parts = entry.split("_FacetSep_")
        # parts[0] = personCompositeId, parts[1] = "Name_JoinSep_structId", parts[2] = structName
        if len(parts) < 3:
            continue
        person_id = parts[0]
        mid = parts[1]                       # "Guido Petrucci_JoinSep_155441"
        struct_name = parts[2]
        join_parts = mid.split("_JoinSep_")
        if len(join_parts) < 2:
            continue
        try:
            struct_id = int(join_parts[1])
        except ValueError:
            continue
        result.setdefault(person_id, []).append((struct_id, struct_name))
    return result


def parse_author_person_id(facet_str: str) -> str:
    """
    Extract the person composite ID from authFullNameIdFormPerson_fs entry.
    Format: "<Full Name>_FacetSep_<personCompositeId>"
    Returns the personCompositeId string.
    """
    parts = facet_str.split("_FacetSep_")
    return parts[1] if len(parts) >= 2 else ""


# ──────────────────────────────────────────────────────────────────────────────
# Upsert helpers (INSERT … skip on duplicate)
# ──────────────────────────────────────────────────────────────────────────────

def get_or_create_journal(cur, issn, title) -> int | None:
    """Return journal_key, inserting if absent. Returns None if both args None."""
    if issn is None and title is None:
        return None
    cur.execute(
        "SELECT journal_key FROM journal WHERE (issn = :1 OR (:1 IS NULL)) AND title = :2",
        [issn, title],
    )
    row = cur.fetchone()
    if row:
        return row[0]
    cur.execute(
        "INSERT INTO journal (issn, title) VALUES (:1, :2) RETURNING journal_key INTO :3",
        [issn, title, cur.var(oracledb.NUMBER)],
    )
    return int(cur.fetchone()[0]) if False else int(cur.bindvars[2].getvalue()[0])


def get_or_create_keyword(cur, keyword_text: str) -> int:
    cur.execute(
        "SELECT keyword_key FROM keyword WHERE keyword_text = :1",
        [keyword_text],
    )
    row = cur.fetchone()
    if row:
        return row[0]
    out = cur.var(oracledb.NUMBER)
    cur.execute(
        "INSERT INTO keyword (keyword_text) VALUES (:1) RETURNING keyword_key INTO :2",
        [keyword_text, out],
    )
    return int(out.getvalue()[0])


def get_or_create_organism(cur, hal_structure_id: int, struct_name: str) -> int:
    cur.execute(
        "SELECT organism_key FROM organism WHERE hal_structure_id = :1",
        [hal_structure_id],
    )
    row = cur.fetchone()
    if row:
        return row[0]
    out = cur.var(oracledb.NUMBER)
    cur.execute(
        "INSERT INTO organism (hal_structure_id, struct_name) VALUES (:1, :2) "
        "RETURNING organism_key INTO :3",
        [hal_structure_id, struct_name, out],
    )
    return int(out.getvalue()[0])


def get_or_create_author(cur, author_id_hal: str, first_name: str, last_name: str) -> int:
    cur.execute(
        "SELECT author_key FROM author WHERE author_id_hal = :1",
        [author_id_hal],
    )
    row = cur.fetchone()
    if row:
        return row[0]
    out = cur.var(oracledb.NUMBER)
    cur.execute(
        "INSERT INTO author (author_id_hal, first_name, last_name) "
        "VALUES (:1, :2, :3) RETURNING author_key INTO :4",
        [author_id_hal, first_name, last_name, out],
    )
    return int(out.getvalue()[0])


def insert_document(cur, rec: dict, journal_key: int | None) -> int | None:
    """
    Insert the document row.  Returns document_key, or None if the document
    already exists (idempotent).
    """
    hal_document_id = int(rec["docid"])
    cur.execute(
        "SELECT document_key FROM document WHERE hal_document_id = :1",
        [hal_document_id],
    )
    row = cur.fetchone()
    if row:
        log.debug("Document %s already exists – skipping.", hal_document_id)
        return row[0]

    out = cur.var(oracledb.NUMBER)
    cur.execute(
        """
        INSERT INTO document
            (hal_document_id, hal_id_s, document_type, classification,
             title, abstract, discipline, domain_codes, url_primary,
             journal_key, doi_id, isbn)
        VALUES
            (:1, :2, :3, :4,
             :5, :6, :7, :8, :9,
             :10, :11, :12)
        RETURNING document_key INTO :13
        """,
        [
            hal_document_id,
            rec.get("halId_s"),
            rec.get("docType_s"),
            rec.get("classification_s"),
            # title_s can be a list in some HAL records; take first element
            (rec["title_s"][0] if isinstance(rec.get("title_s"), list) else rec.get("title_s")),
            (rec["abstract_s"][0] if isinstance(rec.get("abstract_s"), list) else rec.get("abstract_s")),
            rec.get("discipline"),
            rec.get("domain_codes"),
            rec.get("url_primary"),
            journal_key,
            rec.get("doiId_s"),
            rec.get("isbn_id"),
            out,
        ],
    )
    return int(out.getvalue()[0])


# ──────────────────────────────────────────────────────────────────────────────
# Main record processor
# ──────────────────────────────────────────────────────────────────────────────

def process_record(cur, rec: dict) -> None:
    # ── Journal (HAL records don't always expose ISSN; extend if yours do) ──
    journal_key = None  # extend here if your JSON includes journal/issn fields

    # ── Document ────────────────────────────────────────────────────────────
    document_key = insert_document(cur, rec, journal_key)
    if document_key is None:
        return  # already existed; nothing more to do

    # ── Keywords ────────────────────────────────────────────────────────────
    for kw in rec.get("keyword_s") or []:
        kw = kw.strip()
        if not kw:
            continue
        keyword_key = get_or_create_keyword(cur, kw)
        try:
            cur.execute(
                "INSERT INTO doc_keyword (document_key, keyword_key) VALUES (:1, :2)",
                [document_key, keyword_key],
            )
        except oracledb.IntegrityError:
            pass  # duplicate – already linked

    # ── Parse per-author structure map ──────────────────────────────────────
    auth_struct_map = parse_author_structures(
        rec.get("authIdHasStructure_fs") or []
    )

    # Build a map: personCompositeId -> slug from authIdHal_s (may be partial)
    # authIdHal_s only contains slugs for authors who registered one; others absent.
    # We'll fall back to the numeric composite ID for those.
    hal_slugs = rec.get("authIdHal_s") or []

    # authFullNameIdFormPerson_fs gives us the composite IDs in author order
    person_facets = rec.get("authFullNameIdFormPerson_fs") or []
    first_names   = rec.get("authFirstName_s") or []
    last_names    = rec.get("authLastName_s")  or []
    qualities     = rec.get("authQuality_s")   or []

    # Build a lookup: person_composite_id -> hal_slug (if available)
    # We match slugs positionally where the counts agree, otherwise skip.
    # A safer approach is to match by name, but HAL doesn't guarantee ordering.
    # Since authIdHal_s may have fewer entries, we build a set and match greedily.
    slug_set = set(hal_slugs)

    # We iterate authors in order using authFullNameIdFormPerson_fs as the index.
    for idx, facet_str in enumerate(person_facets):
        person_id  = parse_author_person_id(facet_str)
        first_name = first_names[idx] if idx < len(first_names) else None
        last_name  = last_names[idx]  if idx < len(last_names)  else None
        quality    = qualities[idx]   if idx < len(qualities)   else None

        # Determine author_id_hal: prefer slug, fall back to numeric composite ID
        # Match slug by last name (simplistic but effective for most HAL data)
        matched_slug = None
        if last_name:
            normalised_last = last_name.lower().replace(" ", "-").replace("é", "e") \
                                                .replace("è", "e").replace("ê", "e") \
                                                .replace("ô", "o").replace("â", "a")
            for slug in slug_set:
                if normalised_last in slug.lower():
                    matched_slug = slug
                    slug_set.discard(slug)
                    break

        if not matched_slug:
            log.debug(
                "Author at index %d ('%s %s') in doc %s has no HAL slug – skipping.",
                idx, first_name, last_name, rec.get("docid"),
            )
            continue
        author_id_hal = matched_slug

        author_key = get_or_create_author(cur, author_id_hal, first_name, last_name)

        # ── doc_author bridge ────────────────────────────────────────────────
        try:
            cur.execute(
                "INSERT INTO doc_author (document_key, author_key, author_index, quality) "
                "VALUES (:1, :2, :3, :4)",
                [document_key, author_key, idx, quality],
            )
        except oracledb.IntegrityError:
            pass  # duplicate

        # ── Organisms for this author in this document ───────────────────────
        structures = auth_struct_map.get(person_id, [])
        for (struct_id, struct_name) in structures:
            organism_key = get_or_create_organism(cur, struct_id, struct_name)
            try:
                cur.execute(
                    "INSERT INTO author_organism (document_key, author_key, organism_key) "
                    "VALUES (:1, :2, :3)",
                    [document_key, author_key, organism_key],
                )
            except oracledb.IntegrityError:
                pass  # duplicate


# ──────────────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────────────

def main(filepath: Path) -> None:
    log.info("Connecting to Oracle at %s using OS authentication …", DB_DSN)
    connection = oracledb.connect(
        dsn=DB_DSN,
        externalauth=True,
        mode=oracledb.AUTH_MODE_DEFAULT,
    )
    log.info("Connected.")

    total_processed = 0
    total_errors    = 0

    try:
        with connection.cursor() as cur:
            for chunk_num, chunk in enumerate(iter_json_chunks(filepath, CHUNK_SIZE), start=1):
                log.info("Processing chunk %d  (%d records) …", chunk_num, len(chunk))
                for rec in chunk:
                    try:
                        process_record(cur, rec)
                        total_processed += 1
                    except Exception as exc:
                        total_errors += 1
                        log.error(
                            "Failed to process docid=%s: %s",
                            rec.get("docid", "?"),
                            exc,
                        )
                        connection.rollback()   # roll back the failed record only
                        continue

                connection.commit()             # commit after each successful chunk
                log.info("Chunk %d committed.", chunk_num)

    finally:
        connection.close()

    log.info(
        "Done. %d records processed successfully, %d errors.",
        total_processed,
        total_errors,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load HAL JSON records into Oracle 19c.")
    parser.add_argument("--file", required=True, help="Path to the JSON input file.")
    args = parser.parse_args()

    json_path = Path(args.file)
    if not json_path.exists():
        log.error("File not found: %s", json_path)
        sys.exit(1)

    main(json_path)