#!/usr/bin/env python3
"""Build docs/data_inline.js and docs/data.json from concept_sets/, projects/, units/ and mapping_recommendations/."""

import datetime
import hashlib
import json
import glob
import os
import shutil

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
    config_path = os.path.join(ROOT, "config.json")
    if not os.path.isfile(config_path):
        raise SystemExit(f"Missing config.json at {config_path}. See config.json in the repo root.")
    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    concept_sets = load_json_dir(os.path.join(ROOT, "concept_sets"))
    projects = load_json_dir(os.path.join(ROOT, "projects"))

    resolved_dir = os.path.join(ROOT, "concept_sets_resolved")
    resolved = load_json_dir(resolved_dir, sort_key="conceptSetId") if os.path.isdir(resolved_dir) else []

    unit_conversions = load_json_file(os.path.join(ROOT, "units", "unit_conversions.json"))
    recommended_units = load_json_file(os.path.join(ROOT, "units", "recommended_units.json"))
    mapping_recommendations = load_json_file(os.path.join(ROOT, "mapping_recommendations", "mapping_recommendations.json"))

    # Load and validate ID counters
    counters_path = os.path.join(ROOT, "id_counters.json")
    counters = load_json_file(counters_path) if os.path.isfile(counters_path) else {}
    next_cs_id = counters.get("nextConceptSetId", 1)
    next_proj_id = counters.get("nextProjectId", 1)
    max_cs_id = max((cs["id"] for cs in concept_sets), default=0)
    max_proj_id = max((p["id"] for p in projects), default=0)
    if next_cs_id <= max_cs_id:
        next_cs_id = max_cs_id + 1
        print(f"  WARNING: nextConceptSetId was too low, bumped to {next_cs_id}")
    if next_proj_id <= max_proj_id:
        next_proj_id = max_proj_id + 1
        print(f"  WARNING: nextProjectId was too low, bumped to {next_proj_id}")
    with open(counters_path, "w", encoding="utf-8") as f:
        json.dump({"nextConceptSetId": next_cs_id, "nextProjectId": next_proj_id}, f, indent=2)
        f.write("\n")

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
    mapping_fingerprint = hashlib.sha256(json.dumps(mapping_recommendations, sort_keys=True).encode()).hexdigest()[:16] if mapping_recommendations else ""
    full_fingerprint = "\n".join([cs_fingerprint, proj_fingerprint, units_fingerprint, rec_units_fingerprint, mapping_fingerprint])
    data_hash = hashlib.sha256(full_fingerprint.encode()).hexdigest()[:16]

    # Split resolved sets: inline if <= threshold, deferred otherwise
    RESOLVED_INLINE_THRESHOLD = 100
    resolved_inline = []
    deferred_count = 0
    for r in resolved:
        concepts = r.get("resolvedConcepts", [])
        if len(concepts) <= RESOLVED_INLINE_THRESHOLD:
            resolved_inline.append(r)
        else:
            resolved_inline.append({
                "conceptSetId": r["conceptSetId"],
                "resolvedConcepts": [],
                "resolvedDeferred": True,
                "resolvedCount": len(concepts)
            })
            deferred_count += 1

    # Copy deferred resolved files to docs/ for lazy loading
    docs_resolved_dir = os.path.join(DOCS, "concept_sets_resolved")
    if os.path.isdir(docs_resolved_dir):
        shutil.rmtree(docs_resolved_dir)
    if deferred_count > 0:
        os.makedirs(docs_resolved_dir, exist_ok=True)
        for r in resolved:
            concepts = r.get("resolvedConcepts", [])
            if len(concepts) > RESOLVED_INLINE_THRESHOLD:
                src = os.path.join(resolved_dir, f"{r['conceptSetId']}.json")
                if os.path.isfile(src):
                    dst = os.path.join(docs_resolved_dir, f"{r['conceptSetId']}.json")
                    shutil.copy2(src, dst)

    data = {
        "dataVersion": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "dataHash": data_hash,
        "config": config,
        "conceptSets": concept_sets,
        "projects": projects,
        "resolvedConceptSets": resolved_inline,
        "unitConversions": unit_conversions,
        "recommendedUnits": recommended_units,
        "mappingRecommendations": mapping_recommendations,
        "nextConceptSetId": next_cs_id,
        "nextProjectId": next_proj_id
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

    mr_langs = len(mapping_recommendations.get('translations', {})) if mapping_recommendations else 0
    print(f"Built {len(concept_sets)} concept sets, {len(projects)} projects, {len(resolved)} resolved "
          f"({len(resolved) - deferred_count} inline, {deferred_count} deferred), "
          f"{len(unit_conversions)} unit conversions, {len(recommended_units)} recommended units, "
          f"mapping recommendations ({mr_langs} languages)")
    print(f"  -> docs/data.json ({os.path.getsize(os.path.join(DOCS, 'data.json')):,} bytes)")
    print(f"  -> docs/data_inline.js ({os.path.getsize(os.path.join(DOCS, 'data_inline.js')):,} bytes)")


if __name__ == "__main__":
    main()
