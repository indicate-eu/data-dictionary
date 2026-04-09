---
name: build-catalog
description: Rebuild the GitHub Pages catalog data files (data.json and data_inline.js) from source JSON. Use after any change to concept_sets/, projects/, concept_sets_resolved/, units/, or mapping_recommendations/.
allowed-tools: Bash
---

# Build Catalog

Rebuild the static site data files by running `build.py`.

## Instructions

### Step 1: Run build.py

```bash
python3 build.py
```

Run this from the repository root. It aggregates all source JSON into:
- `docs/data.json` — compact JSON for fetch-based loading
- `docs/data_inline.js` — same data as `const DATA={...};` for direct script inclusion
- `docs/resolved_concept_ids.json` — unique concept IDs for DuckDB filtering
- `docs/concept_sets_resolved/` — individual resolved JSON files for lazy loading (only for concept sets with >100 resolved concepts; smaller ones are inlined in data.json/data_inline.js)

### Step 2: Report Results

Show the build output (number of concept sets, projects, resolved sets, file sizes).

### Step 3: Remind About Commit

Tell the user that `docs/data.json`, `docs/data_inline.js`, `docs/resolved_concept_ids.json`, and `docs/concept_sets_resolved/` need to be committed and pushed for the changes to appear on GitHub Pages.
