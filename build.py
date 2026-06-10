#!/usr/bin/env python3
"""Build docs/data_inline.js and docs/data.json from concept_sets/, projects/, units/ and mapping_recommendations/."""

import datetime
import hashlib
import json
import glob
import os
import shutil
import subprocess

import snapshot

ROOT = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.join(ROOT, "docs")


def git_show(sha, repo_path):
    """Return the contents of `repo_path` at commit `sha`, or None if not found."""
    try:
        result = subprocess.run(
            ["git", "show", f"{sha}:{repo_path}"],
            cwd=ROOT,
            capture_output=True,
            # The files are UTF-8 JSON; without this, stdout is decoded with the
            # locale encoding (cp1252 on Windows) and French text comes out mangled.
            encoding="utf-8",
            check=True,
        )
        return result.stdout
    except subprocess.CalledProcessError:
        return None


def project_cs_entries(p):
    """Return the flat list of {id, version} entries pinned by a project, traversing
    groups when present and falling back to the legacy flat `conceptSets` array."""
    if isinstance(p.get("groups"), list):
        out = []
        for g in p["groups"]:
            out.extend(g.get("conceptSets") or [])
        return out
    return p.get("conceptSets") or []


def collect_versioned_snapshots(projects, concept_sets, versions_index):
    """For each (id, version) pinned by a project where version != current source version,
    fetch the snapshot of concept_sets/{id}.json and concept_sets_resolved/{id}.json at the
    commit recorded in the index. Return (cs_versions, resolved_versions) dicts shaped as
    {id: {version: full_json}}."""
    current_versions = {cs["id"]: cs.get("version") for cs in concept_sets}
    needed = set()
    for p in projects:
        for entry in project_cs_entries(p):
            cs_id = entry.get("id")
            version = entry.get("version")
            if cs_id is None or not version:
                continue
            if version == current_versions.get(cs_id):
                continue
            needed.add((cs_id, version))

    cs_versions = {}
    resolved_versions = {}
    missing = []
    for cs_id, version in sorted(needed):
        sha = versions_index.get(str(cs_id), {}).get(version)
        if not sha:
            missing.append((cs_id, version, "no SHA in index"))
            continue
        cs_blob = git_show(sha, f"concept_sets/{cs_id}.json")
        if cs_blob is None:
            missing.append((cs_id, version, f"git show concept_sets/{cs_id}.json @ {sha[:10]} failed"))
            continue
        cs_versions.setdefault(str(cs_id), {})[version] = json.loads(cs_blob)

        resolved_blob = git_show(sha, f"concept_sets_resolved/{cs_id}.json")
        if resolved_blob is not None:
            resolved_versions.setdefault(str(cs_id), {})[version] = json.loads(resolved_blob)

    if missing:
        print("  WARNINGS while collecting versioned snapshots:")
        for cs_id, version, why in missing:
            print(f"    concept set {cs_id} v{version}: {why}")
    return cs_versions, resolved_versions


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

    print("Updating concept_sets_versions.json...")
    snapshot.main()

    concept_sets = load_json_dir(os.path.join(ROOT, "concept_sets"))
    projects = load_json_dir(os.path.join(ROOT, "projects"))
    versions_index = load_json_file(os.path.join(ROOT, "concept_sets_versions.json")) or {}

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

    # Compute a content hash from all data sources. Hash the actual content —
    # not (id, modifiedDate, version) — so a hand-edit that forgets to bump
    # modifiedDate still changes the hash and triggers the SPA's update/merge
    # prompt for users with local drafts.
    cs_fingerprint = hashlib.sha256(json.dumps(concept_sets, sort_keys=True).encode()).hexdigest()[:16]
    proj_fingerprint = hashlib.sha256(json.dumps(projects, sort_keys=True).encode()).hexdigest()[:16]
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
                "vocabularyVersion": r.get("vocabularyVersion"),
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

    cs_versions, resolved_versions = collect_versioned_snapshots(projects, concept_sets, versions_index)
    n_cs_snapshots = sum(len(v) for v in cs_versions.values())
    n_resolved_snapshots = sum(len(v) for v in resolved_versions.values())

    data = {
        "dataVersion": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "dataHash": data_hash,
        "config": config,
        "conceptSets": concept_sets,
        "projects": projects,
        "resolvedConceptSets": resolved_inline,
        "conceptSetVersions": cs_versions,
        "resolvedConceptSetVersions": resolved_versions,
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
          f"mapping recommendations ({mr_langs} languages), "
          f"versioned snapshots ({n_cs_snapshots} concept sets, {n_resolved_snapshots} resolved)")
    print(f"  -> docs/data.json ({os.path.getsize(os.path.join(DOCS, 'data.json')):,} bytes)")
    print(f"  -> docs/data_inline.js ({os.path.getsize(os.path.join(DOCS, 'data_inline.js')):,} bytes)")


if __name__ == "__main__":
    main()
