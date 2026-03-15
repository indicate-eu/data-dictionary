#!/usr/bin/env python3
"""Build docs/data_inline.js and docs/data.json from concept_sets/, projects/, units/ and etl_guidelines/."""

import datetime
import hashlib
import json
import glob
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.join(ROOT, "docs")


def load_json_dir(directory, sort_key="id"):
    """Load all .json files from a directory, sorted by sort_key."""
    items = []
    for path in glob.glob(os.path.join(directory, "*.json")):
        with open(path, "r", encoding="utf-8") as f:
            items.append(json.load(f))
    items.sort(key=lambda x: x.get(sort_key, 0))
    return items


def load_json_file(path):
    """Load a single JSON file (array or object)."""
    if not os.path.isfile(path):
        return []
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def load_text_file(path):
    """Load a text file as a string."""
    if not os.path.isfile(path):
        return ""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def main():
    concept_sets = load_json_dir(os.path.join(ROOT, "concept_sets"))
    projects = load_json_dir(os.path.join(ROOT, "projects"))

    resolved_dir = os.path.join(ROOT, "concept_sets_resolved")
    resolved = load_json_dir(resolved_dir, sort_key="conceptSetId") if os.path.isdir(resolved_dir) else []

    unit_conversions = load_json_file(os.path.join(ROOT, "units", "unit_conversions.json"))
    recommended_units = load_json_file(os.path.join(ROOT, "units", "recommended_units.json"))
    etl_guidelines = load_text_file(os.path.join(ROOT, "etl_guidelines", "etl_guidelines.md"))

    # Compute a content hash from all data sources
    cs_fingerprint = "|".join(
        str(cs["id"]) + ":" + cs.get("modifiedDate", "") + ":" + cs.get("version", "")
        for cs in concept_sets
    )
    proj_fingerprint = "|".join(
        str(p["id"]) + ":" + p.get("modifiedDate", "")
        for p in projects
    )
    units_fingerprint = hashlib.sha256(json.dumps(unit_conversions, sort_keys=True).encode()).hexdigest()[:16]
    rec_units_fingerprint = hashlib.sha256(json.dumps(recommended_units, sort_keys=True).encode()).hexdigest()[:16]
    etl_fingerprint = hashlib.sha256(etl_guidelines.encode()).hexdigest()[:16] if etl_guidelines else ""
    full_fingerprint = "\n".join([cs_fingerprint, proj_fingerprint, units_fingerprint, rec_units_fingerprint, etl_fingerprint])
    data_hash = hashlib.sha256(full_fingerprint.encode()).hexdigest()[:16]

    data = {
        "dataVersion": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "dataHash": data_hash,
        "conceptSets": concept_sets,
        "projects": projects,
        "resolvedConceptSets": resolved,
        "unitConversions": unit_conversions,
        "recommendedUnits": recommended_units,
        "etlGuidelines": etl_guidelines
    }
    # Extract unique concept IDs from resolved concept sets for DuckDB filtering
    resolved_ids = set()
    for rcs in resolved:
        for c in rcs.get("resolvedConcepts", []):
            resolved_ids.add(c["conceptId"])
    # Also include concept IDs from expression items
    for cs in concept_sets:
        for item in cs.get("expression", {}).get("items", []):
            cid = item.get("concept", {}).get("conceptId")
            if cid:
                resolved_ids.add(cid)
    resolved_ids_list = sorted(resolved_ids)
    with open(os.path.join(DOCS, "resolved_concept_ids.json"), "w", encoding="utf-8") as f:
        json.dump(resolved_ids_list, f, separators=(",", ":"))
    print(f"  -> docs/resolved_concept_ids.json ({len(resolved_ids_list)} unique concept IDs)")

    compact = json.dumps(data, ensure_ascii=False, separators=(",", ":"))

    with open(os.path.join(DOCS, "data.json"), "w", encoding="utf-8") as f:
        f.write(compact)

    with open(os.path.join(DOCS, "data_inline.js"), "w", encoding="utf-8") as f:
        f.write("const DATA=" + compact + ";")

    print(f"Built {len(concept_sets)} concept sets, {len(projects)} projects, {len(resolved)} resolved, "
          f"{len(unit_conversions)} unit conversions, {len(recommended_units)} recommended units, "
          f"ETL guidelines {'loaded' if etl_guidelines else 'empty'}")
    print(f"  -> docs/data.json ({os.path.getsize(os.path.join(DOCS, 'data.json')):,} bytes)")
    print(f"  -> docs/data_inline.js ({os.path.getsize(os.path.join(DOCS, 'data_inline.js')):,} bytes)")


if __name__ == "__main__":
    main()
