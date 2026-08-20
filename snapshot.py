#!/usr/bin/env python3
"""Update concept_sets_versions.json with the current commit SHA for any concept set
whose version is not yet recorded in the index.

Workflow:
  1. Edit concept_sets/{id}.json (e.g. bump version 1.0.0 -> 1.1.0).
  2. git commit -am "Update concept set {id} to v1.1.0"
  3. python3 snapshot.py
  4. git commit -am "Snapshot concept set {id} v1.1.0"

The index maps {id: {version: commit_sha}} so build.py can later retrieve the
exact JSON of any pinned (id, version) pair via `git show <sha>:concept_sets/{id}.json`.

Why HEAD, and why two commits:
  For every (id, version) pair NOT already in the index, this records the CURRENT
  HEAD sha -- not the commit that historically introduced that version. It therefore
  assumes the version on disk at HEAD is the canonical content for that pair. Two
  consequences:

  1. A file with uncommitted (staged or unstaged) changes is SKIPPED with a warning:
     pinning HEAD while the file differs from HEAD would record a sha whose content
     does not match. So you must commit the version bump BEFORE snapshotting, then
     commit the updated index AFTER -- the two-commit workflow above.

  2. If you batch several version bumps across multiple commits and snapshot only at
     the end, every newly-seen pair is stamped with the same HEAD. That is fine ONLY
     because each version's content is frozen the moment it is committed -- which is
     why you must NEVER reuse a published (id, version) pair. If a version turns out
     wrong, bump to a new version rather than rewriting the old one.

     Caveat: only the version currently on disk is seen. If the SAME file is bumped
     twice across commits (1.0.0 -> 1.1.0 -> 1.2.0) before snapshotting, the
     intermediate 1.1.0 is never indexed and any project pinned to it will fail at
     build time. Snapshot after every bump of a given file.

This script is idempotent: pairs already in the index are never re-stamped, so
re-running it (or build.py) does nothing once everything is recorded. Never edit
concept_sets_versions.json by hand.

Backfill (--backfill):
  The default mode only ever sees the version currently on disk, so a version that
  came and went between two runs is missed -- which is what happens when others push
  bumps for a while and nobody snapshots in between (contributions merged through the
  SPA's "Propose" button, for one: CI runs build.py but never commits the index).

  --backfill walks the git history of every concept_sets/*.json instead, reads the
  `version` field at each commit that touched it, and records the FIRST commit where
  each version appears. That sha is strictly better than the HEAD approximation above:
  it is the commit that actually introduced the version, so `git show <sha>:...` is
  guaranteed to return that version's content. It also recovers the intermediate
  versions the caveat above calls unreachable.

  It is additive only. A pair already in the index keeps its recorded sha even when
  the walk finds a different (more accurate) one, because those shas are published --
  the SPA resolves them at runtime to fetch past versions, so rewriting one would
  repoint a version someone already cited. Such disagreements are reported as
  "divergences" and left alone; --show-divergences lists them individually.

  Deleted concept sets are included: their file is gone from disk but a project may
  still pin one, and the history still holds the content.

  Cost: one `git log` per file plus one `git show` per touching commit -- seconds on a
  repo this size, but enough that it stays opt-in and is never called by build.py.
"""

import argparse
import glob
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
CONCEPT_SETS_DIR = os.path.join(ROOT, "concept_sets")
INDEX_PATH = os.path.join(ROOT, "concept_sets_versions.json")


def load_index():
    if not os.path.isfile(INDEX_PATH):
        return {}
    with open(INDEX_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def save_index(index):
    sorted_index = {
        str(k): dict(sorted(v.items()))
        for k, v in sorted(index.items(), key=lambda kv: int(kv[0]))
    }
    with open(INDEX_PATH, "w", encoding="utf-8") as f:
        json.dump(sorted_index, f, indent=2, ensure_ascii=False)
        f.write("\n")


def current_head_sha():
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except FileNotFoundError:
        sys.exit(
            "git is not installed, but snapshot.py needs it to record the commit of each\n"
            "concept set version. In CI, use an image that ships git (e.g. python:3.12-alpine\n"
            "plus `apk add --no-cache git`)."
        )
    except subprocess.CalledProcessError as e:
        stderr = e.stderr.strip()
        # A fresh fork right after reset.py has no commit yet, so HEAD does not
        # resolve. Say so plainly instead of echoing git's "ambiguous argument".
        if "ambiguous argument 'HEAD'" in stderr or "unknown revision" in stderr:
            sys.exit(
                "This repository has no commits yet, so there is no HEAD to snapshot against.\n"
                "Commit your files first, then run build.py again."
            )
        sys.exit(f"git rev-parse HEAD failed: {stderr}")


def dirty_paths():
    """Return the set of repo-relative paths with uncommitted (staged or unstaged) changes."""
    result = subprocess.run(
        ["git", "status", "--porcelain", "--", "concept_sets"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    paths = set()
    for line in result.stdout.splitlines():
        # Format: "XY path" (or "XY old -> new" for renames).
        entry = line[3:]
        if " -> " in entry:
            entry = entry.split(" -> ", 1)[1]
        paths.add(entry.strip().strip('"'))
    return paths


def all_historical_paths():
    """Return every concept_sets/*.json path git has ever known, deleted ones included.

    `git log --name-only --diff-filter=AMD` over the directory covers files that no
    longer exist on disk: a project can still pin a version of a set that was later
    removed, and the history is the only place left holding it.
    """
    result = subprocess.run(
        ["git", "log", "--pretty=format:", "--name-only", "--diff-filter=AMD",
         "--", "concept_sets"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    paths = set()
    for line in result.stdout.splitlines():
        line = line.strip().strip('"')
        if line.startswith("concept_sets/") and line.endswith(".json"):
            paths.add(line)
    return sorted(paths)


def commits_touching(path):
    """Commits that touched `path`, oldest first."""
    result = subprocess.run(
        ["git", "log", "--format=%H", "--reverse", "--", path],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.split()


def read_at_commit(sha, path):
    """Parse path's JSON as of `sha`, or None if absent/unreadable there.

    A commit that deletes the file, or one where the JSON is malformed, simply has no
    version to contribute -- the walk skips it rather than failing the whole backfill.
    """
    result = subprocess.run(
        ["git", "show", f"{sha}:{path}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def first_commit_per_version(path):
    """Map {version: first sha where the file carried it} across path's whole history.

    Keyed by the id seen alongside, so a file whose id changed mid-history (should not
    happen, but the index is keyed by id) still attributes each version correctly.
    """
    found = {}
    for sha in commits_touching(path):
        cs = read_at_commit(sha, path)
        if not isinstance(cs, dict):
            continue
        cs_id = cs.get("id")
        version = cs.get("version")
        if cs_id is None or not version:
            continue
        key = (str(cs_id), version)
        if key not in found:
            found[key] = sha
    return found


def backfill(dry_run=False, show_divergences=False):
    index = load_index()

    paths = all_historical_paths()
    if not paths:
        print("No concept set history found — nothing to backfill.")
        return

    print(f"Scanning the history of {len(paths)} concept set file(s)…")

    new_entries = []
    divergences = []

    for path in paths:
        for (key, version), sha in sorted(first_commit_per_version(path).items()):
            recorded = index.get(key, {}).get(version)
            if recorded is None:
                index.setdefault(key, {})[version] = sha
                new_entries.append((key, version, sha, path))
            elif recorded != sha:
                # Published sha wins — see the module docstring.
                divergences.append((key, version, recorded, sha))

    if divergences:
        print()
        print(f"{len(divergences)} pair(s) already indexed at a different commit than the "
              f"one that introduced them.")
        print("Left untouched: those shas are published and the app resolves them at runtime.")
        if show_divergences:
            for key, version, recorded, found in divergences:
                print(f"  concept set {key} v{version}: indexed {recorded[:10]}, "
                      f"introduced at {found[:10]}")
        else:
            print("Re-run with --show-divergences to list them.")

    if not new_entries:
        print()
        print("No missing versions found. Index unchanged.")
        return

    print()
    print(f"{'Would add' if dry_run else 'Added'} {len(new_entries)} missing "
          f"(id, version) pair(s):")
    for key, version, sha, path in new_entries:
        deleted = "" if os.path.isfile(os.path.join(ROOT, path)) else "  [deleted file]"
        print(f"  concept set {key} -> v{version} at {sha[:10]}{deleted}")

    if dry_run:
        print()
        print("Dry run — concept_sets_versions.json was not modified.")
        return

    save_index(index)
    print()
    print("Don't forget to commit concept_sets_versions.json.")


def main():
    index = load_index()
    sha = current_head_sha()
    dirty = dirty_paths()

    new_entries = []
    warnings = []

    for path in sorted(glob.glob(os.path.join(CONCEPT_SETS_DIR, "*.json"))):
        with open(path, "r", encoding="utf-8") as f:
            cs = json.load(f)
        cs_id = cs.get("id")
        version = cs.get("version")
        if cs_id is None or not version:
            warnings.append(f"  {os.path.basename(path)}: missing id or version, skipped")
            continue

        key = str(cs_id)
        existing = index.get(key, {})
        if version in existing:
            continue

        if os.path.relpath(path, ROOT).replace(os.sep, "/") in dirty:
            warnings.append(
                f"  concept_sets/{cs_id}.json: uncommitted changes — "
                f"commit them before running snapshot.py (skipped v{version})"
            )
            continue

        index.setdefault(key, {})[version] = sha
        new_entries.append((cs_id, version))

    if warnings:
        print("Warnings:")
        for w in warnings:
            print(w)

    if not new_entries:
        print("No new versions to snapshot. Index unchanged.")
        return

    save_index(index)
    print(f"Snapshotted {len(new_entries)} new (id, version) pair(s) at {sha[:10]}:")
    for cs_id, version in new_entries:
        print(f"  concept set {cs_id} -> v{version}")
    print()
    print("Don't forget to commit concept_sets_versions.json.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Record the commit sha of each concept set version in "
                    "concept_sets_versions.json.",
        epilog="Without --backfill, stamps versions currently on disk at HEAD "
               "(the two-commit workflow). With it, walks the git history to recover "
               "versions no run ever saw. Both modes only ever add to the index.",
    )
    parser.add_argument(
        "--backfill",
        action="store_true",
        help="walk the git history and add every (id, version) pair missing from the "
             "index, using the commit that introduced it",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="with --backfill, list what would be added without writing the index",
    )
    parser.add_argument(
        "--show-divergences",
        action="store_true",
        help="with --backfill, list indexed pairs whose recorded sha differs from the "
             "commit that introduced them (reported but never rewritten)",
    )
    args = parser.parse_args()

    if args.dry_run and not args.backfill:
        sys.exit("--dry-run only applies to --backfill.")
    if args.show_divergences and not args.backfill:
        sys.exit("--show-divergences only applies to --backfill.")

    if args.backfill:
        backfill(dry_run=args.dry_run, show_divergences=args.show_divergences)
    else:
        main()
