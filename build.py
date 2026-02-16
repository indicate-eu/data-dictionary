#!/usr/bin/env python3
"""Build docs/data_inline.js and docs/data.json from concept_sets/, projects/, units/ and etl_guidelines/."""

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

    data = {
        "conceptSets": concept_sets,
        "projects": projects,
        "resolvedConceptSets": resolved,
        "unitConversions": unit_conversions,
        "recommendedUnits": recommended_units,
        "etlGuidelines": etl_guidelines
    }
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
