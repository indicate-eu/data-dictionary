#!/usr/bin/env python3
"""Update the code of this fork from the INDICATE upstream repository.

Pulls the latest version of the application code (build/resolve/reset scripts,
SPA assets in docs/, Claude skills, CLAUDE.md) from the upstream repo,
without touching team-owned content (concept_sets/, projects/, units/,
mapping_recommendations/, config.json, branding assets, etc.).

The upstream URL and branch are read from config.json (`github.upstream` and
`github.upstreamBranch`); override with --upstream / --branch.

Run from the repository root:

    python3 update_from_upstream.py            # interactive (asks before overwriting)
    python3 update_from_upstream.py --yes      # non-interactive
    python3 update_from_upstream.py --dry-run  # show what would change

Changes land as uncommitted modifications in the working tree — review with
`git diff` and commit when satisfied.
"""

import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))

# Files and directories to pull from upstream. Glob-friendly — directories are pulled recursively.
# Anything not in this list is preserved as-is in the fork.
UPSTREAM_PATHS = [
    "build.py",
    "resolve.py",
    "reset.py",
    "update_from_upstream.py",
    "CLAUDE.md",
    "FORKING.md",
    "config.local.example.json",
    ".gitignore",
    ".gitlab-ci.yml",
    "docs/index.html",
    "docs/app.css",
    "docs/app.js",
    "docs/router.js",
    "docs/spa-init.js",
    "docs/concept-sets.js",
    "docs/projects.js",
    "docs/mapping-recommendations.js",
    "docs/settings.js",
    "docs/general-settings.js",
    "docs/dev-tools.js",
    "docs/documentation.js",
    "docs/duckdb-loader.js",
    "docs/projects.html",
    "docs/settings.html",
    "docs/general-settings.html",
    "docs/dev-tools.html",
    ".claude/skills",
]

# Explicitly NEVER touched (even if they appear under a path above by accident).
# These are the files a fork owns and must be preserved.
PROTECTED = {
    "config.json",            # fork's branding/identity
    "config.local.json",      # fork's machine paths (gitignored anyway)
    "docs/logo.png",
    "docs/favicon.png",
    "docs/data_dictionary.png",
}


def run(cmd, check=True, capture=False):
    """Run a shell command, return CompletedProcess."""
    return subprocess.run(cmd, cwd=ROOT, check=check,
                          capture_output=capture, text=True)


def load_config():
    path = os.path.join(ROOT, "config.json")
    if not os.path.isfile(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def ensure_git_repo():
    if not os.path.isdir(os.path.join(ROOT, ".git")):
        sys.exit("Error: not a git repository. Run `git init` first, or clone the fork.")


def working_tree_clean():
    out = run(["git", "status", "--porcelain"], capture=True).stdout
    return out.strip() == ""


def ensure_upstream_remote(url):
    """Ensure a remote named 'upstream' points at `url`. Add or update as needed."""
    res = run(["git", "remote", "get-url", "upstream"], check=False, capture=True)
    if res.returncode != 0:
        run(["git", "remote", "add", "upstream", url])
        print(f"  Added remote 'upstream' -> {url}")
        return
    current = res.stdout.strip()
    if current != url:
        run(["git", "remote", "set-url", "upstream", url])
        print(f"  Updated remote 'upstream' from {current} -> {url}")


def fetch_upstream(branch):
    print(f"Fetching upstream/{branch}...")
    run(["git", "fetch", "upstream", branch])


def checkout_paths(branch, paths, dry_run):
    """Checkout the given paths from upstream/<branch>. Skip protected files."""
    ref = f"upstream/{branch}"
    safe = [p for p in paths if p not in PROTECTED]
    if dry_run:
        print(f"\nWould checkout {len(safe)} path(s) from {ref}:")
        for p in safe:
            print(f"  - {p}")
        return
    # Use --pathspec-from-stdin? Simpler: pass all paths in one go.
    # Some paths may not exist upstream yet (e.g. FORKING.md on older versions); checkout silently
    # skips missing paths only if we pass them one at a time.
    for p in safe:
        res = run(["git", "checkout", ref, "--", p], check=False, capture=True)
        if res.returncode != 0:
            # Path may not exist upstream yet — log and continue.
            print(f"  - skipped {p} (not present in {ref})")
        else:
            print(f"  - updated {p}")


def main():
    parser = argparse.ArgumentParser(description="Update fork code from the INDICATE upstream repository.")
    parser.add_argument("--upstream", help="Override upstream URL (default: config.json -> github.upstream)")
    parser.add_argument("--branch", help="Override upstream branch (default: config.json -> github.upstreamBranch, then 'main')")
    parser.add_argument("--yes", action="store_true", help="Skip the confirmation prompt")
    parser.add_argument("--dry-run", action="store_true", help="Show what would change without modifying files")
    args = parser.parse_args()

    ensure_git_repo()

    cfg = load_config().get("github", {})
    url = args.upstream or cfg.get("upstream")
    branch = args.branch or cfg.get("upstreamBranch") or "main"
    if not url:
        sys.exit("Error: no upstream URL. Pass --upstream <url>, or set github.upstream in config.json.")

    if not args.dry_run and not working_tree_clean():
        print("Warning: working tree has uncommitted changes. The update will mix with them.")
        if not args.yes:
            answer = input("Proceed anyway? [y/N] ").strip().lower()
            if answer not in ("y", "yes"):
                sys.exit("Aborted.")

    ensure_upstream_remote(url)
    fetch_upstream(branch)

    print(f"\nUpdating code from upstream/{branch}. The following content is preserved:")
    print("  - concept_sets/, projects/, units/, mapping_recommendations/, concept_sets_resolved/")
    print("  - config.json, config.local.json, id_counters.json")
    print("  - docs/logo.png, docs/favicon.png, docs/data_dictionary.png")
    print("  - docs/data.json, docs/data_inline.js (regenerated via build.py)")
    print()

    if not args.dry_run and not args.yes:
        answer = input("Proceed? [y/N] ").strip().lower()
        if answer not in ("y", "yes"):
            sys.exit("Aborted.")

    checkout_paths(branch, UPSTREAM_PATHS, args.dry_run)

    if args.dry_run:
        return

    print("\nDone. Review changes with `git diff` and commit when satisfied.")
    print("If build.py or any source data changed, run `python3 build.py` to regenerate docs/data.json.")


if __name__ == "__main__":
    main()
