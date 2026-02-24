#!/usr/bin/env python3
"""Resolve concept sets using OMOP vocabulary tables.

Vocabulary source can be either a DuckDB database or a folder of Athena CSV files.

Usage:
    python3 resolve.py --db /path/to/ohdsi_vocabularies.duckdb
    python3 resolve.py --csv-dir /path/to/athena_csv_folder
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
    ids_str = ",".join(str(i) for i in concept_ids)
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
    ids_str = ",".join(str(i) for i in concept_ids)
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

    # Build included set
    included_ids = {i["concept"]["conceptId"] for i in included_items}

    # Expand descendants for included
    desc_items = [i for i in included_items if i.get("includeDescendants", False)]
    if desc_items:
        desc_source = {i["concept"]["conceptId"] for i in desc_items}
        included_ids |= get_descendants(con, desc_source)

    # Expand mapped for included
    mapped_items = [i for i in included_items if i.get("includeMapped", False)]
    if mapped_items:
        mapped_source = {i["concept"]["conceptId"] for i in mapped_items}
        included_ids |= get_mapped(con, mapped_source)

    # Build excluded set
    excluded_ids = set()
    if excluded_items:
        excluded_ids = {i["concept"]["conceptId"] for i in excluded_items}

        desc_items = [i for i in excluded_items if i.get("includeDescendants", False)]
        if desc_items:
            desc_source = {i["concept"]["conceptId"] for i in desc_items}
            excluded_ids |= get_descendants(con, desc_source)

        mapped_items = [i for i in excluded_items if i.get("includeMapped", False)]
        if mapped_items:
            mapped_source = {i["concept"]["conceptId"] for i in mapped_items}
            excluded_ids |= get_mapped(con, mapped_source)

    # Final resolution
    resolved_ids = included_ids - excluded_ids

    if not resolved_ids:
        return []

    # Fetch concept details
    ids_str = ",".join(str(i) for i in resolved_ids)
    rows = con.execute(
        f"SELECT concept_id, concept_name, vocabulary_id, domain_id, "
        f"concept_class_id, concept_code, standard_concept "
        f"FROM concept "
        f"WHERE concept_id IN ({ids_str}) "
        f"ORDER BY concept_name"
    ).fetchall()

    return [
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


def resolve_one(con, cs_id):
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

    os.makedirs(OUT_DIR, exist_ok=True)
    out = {"conceptSetId": cs_id, "resolvedConcepts": concepts}
    out_path = os.path.join(OUT_DIR, f"{cs_id}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    return name, len(concepts)


def connect_from_csv(csv_dir):
    """Create an in-memory DuckDB connection from Athena CSV files."""
    required = ["CONCEPT.csv", "CONCEPT_ANCESTOR.csv", "CONCEPT_RELATIONSHIP.csv"]
    for fname in required:
        fpath = os.path.join(csv_dir, fname)
        if not os.path.exists(fpath):
            print(f"Error: required file not found: {fpath}", file=sys.stderr)
            sys.exit(1)

    con = duckdb.connect(":memory:")
    print("Loading Athena CSV files into memory...")
    con.execute(f"CREATE TABLE concept AS SELECT * FROM read_csv_auto('{os.path.join(csv_dir, 'CONCEPT.csv')}', delim='\\t', header=true)")
    con.execute(f"CREATE TABLE concept_ancestor AS SELECT * FROM read_csv_auto('{os.path.join(csv_dir, 'CONCEPT_ANCESTOR.csv')}', delim='\\t', header=true)")
    con.execute(f"CREATE TABLE concept_relationship AS SELECT * FROM read_csv_auto('{os.path.join(csv_dir, 'CONCEPT_RELATIONSHIP.csv')}', delim='\\t', header=true)")
    print("CSV files loaded.")
    return con


def main():
    parser = argparse.ArgumentParser(description="Resolve concept sets using OMOP vocabularies")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--db", help="Path to a DuckDB database containing OMOP vocabulary tables")
    source.add_argument("--csv-dir", help="Path to a folder of Athena CSV files (CONCEPT.csv, CONCEPT_ANCESTOR.csv, CONCEPT_RELATIONSHIP.csv)")
    parser.add_argument("--id", type=int, default=None, help="Resolve a single concept set by ID")
    args = parser.parse_args()

    if args.db:
        if not os.path.exists(args.db):
            print(f"Error: database not found: {args.db}", file=sys.stderr)
            sys.exit(1)
        con = duckdb.connect(args.db, read_only=True)
    else:
        if not os.path.isdir(args.csv_dir):
            print(f"Error: directory not found: {args.csv_dir}", file=sys.stderr)
            sys.exit(1)
        con = connect_from_csv(args.csv_dir)

    if args.id is not None:
        result = resolve_one(con, args.id)
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
        result = resolve_one(con, cs_id)
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
