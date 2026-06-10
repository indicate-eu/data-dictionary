#!/usr/bin/env python3
"""Resolve concept sets using OMOP vocabulary tables.

Vocabulary source can be:
  - a DuckDB database file (`.duckdb` or `.db`)
  - a folder of Athena tab-separated CSV files (CONCEPT.csv, CONCEPT_ANCESTOR.csv,
    CONCEPT_RELATIONSHIP.csv)
  - a folder of Parquet files with the same names (.parquet)

The source is detected automatically from the path. If no `--vocab` flag is provided,
falls back to the `ohdsiVocab` key in config.local.json.

Usage:
    python3 resolve.py --vocab /path/to/ohdsi_vocabularies.duckdb
    python3 resolve.py --vocab /path/to/athena_csv_folder
    python3 resolve.py --vocab /path/to/parquet_folder
    python3 resolve.py --vocab <path> --id 10   # resolve a single concept set
    python3 resolve.py                # uses config.local.json (ohdsiVocab)
"""

import argparse
import glob
import json
import os
import sys

import duckdb

ROOT = os.path.dirname(os.path.abspath(__file__))
CS_DIR = os.path.join(ROOT, "concept_sets")
OUT_DIR = os.path.join(ROOT, "concept_sets_resolved")


def expand_ids(con, base_ids, items, flag_col, expand_func):
    """Expand a set of concept IDs using a flag and an expansion function."""
    flagged = [item for item in items if item.get(flag_col, False)]
    if not flagged:
        return base_ids
    source_ids = {item["concept"]["conceptId"] for item in flagged}
    extra = expand_func(con, source_ids)
    return base_ids | extra


def get_descendants(con, concept_ids):
    """Get descendant concept IDs from concept_ancestor table."""
    if not concept_ids:
        return set()
    # int() so a malformed conceptId in a JSON file fails fast instead of
    # being interpolated into the SQL.
    ids_str = ",".join(str(int(i)) for i in concept_ids)
    rows = con.execute(
        f"SELECT DISTINCT descendant_concept_id "
        f"FROM concept_ancestor "
        f"WHERE ancestor_concept_id IN ({ids_str}) "
        f"AND descendant_concept_id != ancestor_concept_id"
    ).fetchall()
    return {r[0] for r in rows}


def get_mapped(con, concept_ids):
    """Get mapped concept IDs from concept_relationship table."""
    if not concept_ids:
        return set()
    ids_str = ",".join(str(int(i)) for i in concept_ids)
    rows = con.execute(
        f"SELECT DISTINCT concept_id_2 "
        f"FROM concept_relationship "
        f"WHERE concept_id_1 IN ({ids_str}) "
        f"AND relationship_id IN ('Maps to', 'Mapped from')"
    ).fetchall()
    return {r[0] for r in rows}


def resolve_concept_set(con, items):
    """Resolve a concept set expression into a list of concept details.

    Algorithm (matches R function in data-dictionary/R/fct_duckdb.R):
    1. Partition items into included and excluded
    2. For each partition, expand with descendants and mapped concepts
    3. Final = included - excluded
    4. Fetch concept details for final IDs
    """
    if not items:
        return []

    included_items = [i for i in items if not i.get("isExcluded", False)]
    excluded_items = [i for i in items if i.get("isExcluded", False)]

    if not included_items:
        return []

    included_ids = {i["concept"]["conceptId"] for i in included_items}
    included_ids = expand_ids(con, included_ids, included_items, "includeDescendants", get_descendants)
    included_ids = expand_ids(con, included_ids, included_items, "includeMapped", get_mapped)

    excluded_ids = set()
    if excluded_items:
        excluded_ids = {i["concept"]["conceptId"] for i in excluded_items}
        excluded_ids = expand_ids(con, excluded_ids, excluded_items, "includeDescendants", get_descendants)
        excluded_ids = expand_ids(con, excluded_ids, excluded_items, "includeMapped", get_mapped)

    resolved_ids = included_ids - excluded_ids

    if not resolved_ids:
        return []

    # Separate DB concepts from custom concepts (ID >= 2,100,000,000)
    CUSTOM_CONCEPT_BASE = 2_100_000_000
    db_ids = {i for i in resolved_ids if i < CUSTOM_CONCEPT_BASE}
    custom_ids = {i for i in resolved_ids if i >= CUSTOM_CONCEPT_BASE}

    # Fetch DB concept details
    db_concepts = []
    if db_ids:
        ids_str = ",".join(str(int(i)) for i in db_ids)
        rows = con.execute(
            f"SELECT concept_id, concept_name, vocabulary_id, domain_id, "
            f"concept_class_id, concept_code, standard_concept "
            f"FROM concept "
            f"WHERE concept_id IN ({ids_str})"
        ).fetchall()

        db_concepts = [
            {
                "conceptId": r[0],
                "conceptName": r[1],
                "vocabularyId": r[2],
                "domainId": r[3],
                "conceptClassId": r[4],
                "conceptCode": r[5],
                "standardConcept": r[6],
            }
            for r in rows
        ]

    # Build custom concept details from expression items. Discard each id once
    # emitted so a concept appearing in several items isn't duplicated.
    custom_concepts = []
    if custom_ids:
        remaining = set(custom_ids)
        all_items = included_items + excluded_items
        for item in all_items:
            c = item.get("concept", {})
            cid = c.get("conceptId")
            if cid in remaining:
                remaining.discard(cid)
                custom_concepts.append({
                    "conceptId": cid,
                    "conceptName": c.get("conceptName", ""),
                    "vocabularyId": c.get("vocabularyId", ""),
                    "domainId": c.get("domainId", ""),
                    "conceptClassId": c.get("conceptClassId", ""),
                    "conceptCode": c.get("conceptCode", ""),
                    "standardConcept": c.get("standardConcept", None),
                })

    result = db_concepts + custom_concepts
    # Sort by conceptId: a stable, unique key that never shifts between vocabulary
    # releases, so the stored file stays diff-clean. Human-readable ordering (by
    # name) is a presentation concern handled by the SPA's resolved-concepts table.
    result.sort(key=lambda x: x.get("conceptId", 0))
    return result


def read_vocabulary_version(con):
    """Read the OMOP vocabulary release info from the VOCABULARY table.

    Returns a dict of the shape
        {"release": "v5.0 27-FEB-26", "SNOMED": "...", "RxNorm": "...", ...}
    where "release" is the version stored on the special 'None' vocabulary row,
    and each other key is a vocabulary_id mapped to its vocabulary_version.

    Returns None when the source has no VOCABULARY table (e.g. a .duckdb that
    only contains concept / concept_ancestor / concept_relationship). The version
    is then recorded as null so the gap is visible rather than silently missing.
    """
    try:
        rows = con.execute(
            "SELECT vocabulary_id, vocabulary_version FROM vocabulary "
            "WHERE vocabulary_version IS NOT NULL"
        ).fetchall()
    except Exception:
        return None
    if not rows:
        return None
    version = {}
    for vocab_id, vocab_version in rows:
        if vocab_id == "None":
            version["release"] = vocab_version
        else:
            version[vocab_id] = vocab_version
    return version


def resolve_one(con, cs_id, vocab_version=None):
    """Resolve a single concept set by ID.

    Returns (name, count) on success, or None if the file doesn't exist.
    Writes the resolved JSON to concept_sets_resolved/{id}.json.
    """
    path = os.path.join(CS_DIR, f"{cs_id}.json")
    if not os.path.exists(path):
        print(f"Error: concept set not found: {path}", file=sys.stderr)
        return None

    with open(path, "r", encoding="utf-8") as f:
        cs = json.load(f)

    name = cs.get("name", "")
    items = (cs.get("expression") or {}).get("items", [])

    concepts = resolve_concept_set(con, items)

    # Stamp only the release plus the versions of vocabularies actually present
    # in this set's resolved concepts — the full VOCABULARY table lists ~50
    # vocabularies, most irrelevant to any given set.
    set_version = None
    if vocab_version is not None:
        used = {c.get("vocabularyId") for c in concepts if c.get("vocabularyId")}
        set_version = {"release": vocab_version.get("release")}
        for vocab_id in sorted(used):
            if vocab_id in vocab_version:
                set_version[vocab_id] = vocab_version[vocab_id]

    os.makedirs(OUT_DIR, exist_ok=True)
    out = {
        "conceptSetId": cs_id,
        "vocabularyVersion": set_version,
        "resolvedConcepts": concepts,
    }
    out_path = os.path.join(OUT_DIR, f"{cs_id}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    return name, len(concepts)


REQUIRED_TABLES = ["CONCEPT", "CONCEPT_ANCESTOR", "CONCEPT_RELATIONSHIP"]


def detect_vocab_format(path):
    """Return one of 'duckdb', 'csv', 'parquet' based on what the path contains."""
    if os.path.isfile(path):
        if path.lower().endswith((".duckdb", ".db")):
            return "duckdb"
        raise SystemExit(f"Error: vocabulary file is not a DuckDB database (.duckdb or .db): {path}")
    if not os.path.isdir(path):
        raise SystemExit(f"Error: vocabulary path not found: {path}")
    has_csv = all(os.path.isfile(os.path.join(path, t + ".csv")) for t in REQUIRED_TABLES)
    has_parquet = all(os.path.isfile(os.path.join(path, t + ".parquet")) for t in REQUIRED_TABLES)
    if has_csv:
        return "csv"
    if has_parquet:
        return "parquet"
    raise SystemExit(
        f"Error: folder does not contain the required OMOP tables: {path}\n"
        f"Expected either {[t + '.csv' for t in REQUIRED_TABLES]} or "
        f"{[t + '.parquet' for t in REQUIRED_TABLES]}."
    )


# Optional: loaded when present so the vocabulary release can be stamped into
# the resolved files. Not required for resolution itself.
OPTIONAL_TABLES = ["VOCABULARY"]


def connect_from_csv(csv_dir):
    """Create an in-memory DuckDB connection from Athena CSV files."""
    con = duckdb.connect(":memory:")
    print("Loading Athena CSV files into memory...")

    def load(table, src):
        # Athena exports are unquoted TSVs whose values may contain literal `"`
        # (e.g. inch marks in concept names) — disable quote detection, and pass
        # the path as a prepared-statement parameter so quotes/apostrophes in
        # the path can't break the SQL.
        con.execute(
            f"CREATE TABLE {table} AS SELECT * FROM read_csv_auto(?, delim='\t', header=true, quote='')",
            [src],
        )

    load("concept", os.path.join(csv_dir, "CONCEPT.csv"))
    load("concept_ancestor", os.path.join(csv_dir, "CONCEPT_ANCESTOR.csv"))
    load("concept_relationship", os.path.join(csv_dir, "CONCEPT_RELATIONSHIP.csv"))
    for table in OPTIONAL_TABLES:
        src = os.path.join(csv_dir, f"{table}.csv")
        if os.path.isfile(src):
            load(table.lower(), src)
    print("CSV files loaded.")
    return con


def connect_from_parquet(parquet_dir):
    """Create an in-memory DuckDB connection from Parquet files."""
    con = duckdb.connect(":memory:")
    print("Loading Parquet files into memory...")
    for table in REQUIRED_TABLES:
        path = os.path.join(parquet_dir, f"{table}.parquet")
        con.execute(f"CREATE TABLE {table.lower()} AS SELECT * FROM read_parquet(?)", [path])
    for table in OPTIONAL_TABLES:
        src = os.path.join(parquet_dir, f"{table}.parquet")
        if os.path.isfile(src):
            con.execute(f"CREATE TABLE {table.lower()} AS SELECT * FROM read_parquet(?)", [src])
    print("Parquet files loaded.")
    return con


def load_local_config():
    """Load config.local.json (gitignored) if it exists, else {}."""
    path = os.path.join(ROOT, "config.local.json")
    if not os.path.isfile(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def main():
    parser = argparse.ArgumentParser(description="Resolve concept sets using OMOP vocabularies")
    parser.add_argument("--vocab", help="Path to OMOP vocabulary source (.duckdb file, or folder of CSV/Parquet files). "
                                        "If omitted, falls back to the 'ohdsiVocab' key in config.local.json.")
    parser.add_argument("--id", type=int, default=None, help="Resolve a single concept set by ID")
    args = parser.parse_args()

    vocab = args.vocab
    if not vocab:
        vocab = load_local_config().get("ohdsiVocab")
        if not vocab:
            print("Error: no vocabulary source. Pass --vocab <path>, or set 'ohdsiVocab' in "
                  "config.local.json (see config.local.example.json).",
                  file=sys.stderr)
            sys.exit(1)

    fmt = detect_vocab_format(vocab)
    if fmt == "duckdb":
        con = duckdb.connect(vocab, read_only=True)
    elif fmt == "csv":
        con = connect_from_csv(vocab)
    else:
        con = connect_from_parquet(vocab)

    vocab_version = read_vocabulary_version(con)
    if vocab_version and vocab_version.get("release"):
        print(f"Vocabulary release: {vocab_version['release']}")
    else:
        print("Vocabulary release: unknown (no VOCABULARY table in source) — recording null")

    if args.id is not None:
        result = resolve_one(con, args.id, vocab_version)
        con.close()
        if result is None:
            sys.exit(1)
        name, count = result
        print(f"  {name} (id={args.id}): {count} resolved concepts")
        print(f"Output: {os.path.join(OUT_DIR, f'{args.id}.json')}")
        return

    paths = sorted(glob.glob(os.path.join(CS_DIR, "*.json")))
    ids = []
    for p in paths:
        stem = os.path.splitext(os.path.basename(p))[0]
        if stem.isdigit():
            ids.append(int(stem))

    total = len(ids)
    resolved_count = 0
    total_concepts = 0

    for idx, cs_id in enumerate(ids, 1):
        result = resolve_one(con, cs_id, vocab_version)
        if result is not None:
            name, count = result
            total_concepts += count
            resolved_count += 1
            print(f"  [{idx}/{total}] {name} (id={cs_id}): {count} resolved concepts")

    con.close()

    print(f"\nResolved {resolved_count}/{total} concept sets -> {total_concepts} total concepts")
    print(f"Output: {OUT_DIR}/")


if __name__ == "__main__":
    main()
