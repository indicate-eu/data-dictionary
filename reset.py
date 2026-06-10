#!/usr/bin/env python3
"""Reset the data dictionary to an empty state for a fresh fork.

Wipes team-specific content (concept sets, projects, resolved sets, mapping
recommendations text), resets ID counters and the concept_sets_versions.json
index. Keeps reusable reference data (UCUM unit conversions, OMOP recommended
units) and configuration files (config.json, config.local.json, branding
assets).

Run from the repository root:

    python3 reset.py        # interactive (asks for confirmation)
    python3 reset.py --yes  # non-interactive

After reset, run build.py to regenerate the static site data files (the script
does this automatically unless --no-build is passed).
"""

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))


def list_files(pattern):
    return sorted(glob.glob(os.path.join(ROOT, pattern)))


def plan_actions():
    """Return a list of (label, action_callable) tuples describing the reset plan."""
    actions = []

    cs_files = list_files("concept_sets/*.json")
    if cs_files:
        actions.append((f"Delete {len(cs_files)} concept set(s) in concept_sets/",
                        lambda: [os.remove(p) for p in cs_files]))

    proj_files = list_files("projects/*.json")
    if proj_files:
        actions.append((f"Delete {len(proj_files)} project(s) in projects/",
                        lambda: [os.remove(p) for p in proj_files]))

    resolved_files = list_files("concept_sets_resolved/*.json")
    if resolved_files:
        actions.append((f"Delete {len(resolved_files)} resolved concept set(s) in concept_sets_resolved/",
                        lambda: [os.remove(p) for p in resolved_files]))

    mapping = os.path.join(ROOT, "mapping_recommendations", "mapping_recommendations.json")
    if os.path.isfile(mapping):
        current = _read_json(mapping)
        langs = list((current.get("translations") or {}).keys()) or ["en", "fr"]
        empty = {"translations": {l: {"content": ""} for l in langs}}
        if current != empty:
            actions.append(("Reset mapping_recommendations/mapping_recommendations.json content to empty (structure preserved)",
                            lambda: _write_json(mapping, empty)))

    counters = os.path.join(ROOT, "id_counters.json")
    if os.path.isfile(counters):
        current = _read_json(counters)
        if current.get("nextConceptSetId") != 1 or current.get("nextProjectId") != 1:
            actions.append(("Reset id_counters.json to {nextConceptSetId: 1, nextProjectId: 1}",
                            lambda: _write_json(counters, {"nextConceptSetId": 1, "nextProjectId": 1})))

    # The versions index points (id, version) pairs at upstream commit SHAs. Kept
    # as-is it would make snapshot.py silently skip the fork's own first versions
    # (the pairs look already published) and build.py fetch upstream content.
    versions = os.path.join(ROOT, "concept_sets_versions.json")
    if os.path.isfile(versions) and _read_json(versions) != {}:
        actions.append(("Reset concept_sets_versions.json to {} (upstream version index)",
                        lambda: _write_json(versions, {})))

    return actions


def _read_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _write_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def main():
    parser = argparse.ArgumentParser(description="Reset the data dictionary to an empty state for a fresh fork.")
    parser.add_argument("--yes", action="store_true", help="Skip the confirmation prompt")
    parser.add_argument("--no-build", action="store_true", help="Skip running build.py at the end")
    args = parser.parse_args()

    actions = plan_actions()

    if not actions:
        print("Nothing to reset — the dictionary is already empty.")
        return

    print("The following changes will be made:")
    for label, _ in actions:
        print(f"  - {label}")
    print()
    print("Kept as-is: config.json, config.local.json, units/unit_conversions.json,")
    print("  units/recommended_units.json, docs/ (branding assets and generated files).")
    print()

    if not args.yes:
        answer = input("Proceed? [y/N] ").strip().lower()
        if answer not in ("y", "yes"):
            print("Aborted.")
            sys.exit(1)

    for label, fn in actions:
        fn()
        print(f"  ✓ {label}")

    if args.no_build:
        print("\nDone. Run `python3 build.py` to regenerate docs/data.json and docs/data_inline.js.")
        return

    print("\nRunning build.py to regenerate static site data...")
    rc = subprocess.call([sys.executable, os.path.join(ROOT, "build.py")], cwd=ROOT)
    if rc != 0:
        print("build.py failed. Run it manually after fixing the issue.", file=sys.stderr)
        sys.exit(rc)


if __name__ == "__main__":
    main()
