# INDICATE Data Dictionary

JSON content (concept sets, projects, units, mapping recommendations) for the INDICATE Data Dictionary, plus a static GitHub Pages SPA (`docs/`) to browse it. See @README.md for the what/why.

## Commands

```bash
python3 resolve.py --vocab <path>          # resolve concept sets → concept_sets_resolved/ (needs OMOP vocab)
python3 resolve.py --vocab <path> --id 10  # resolve one set (after editing its expression)
python3 build.py                           # snapshot + build docs/data.json etc. (no vocab needed)
python3 reset.py                           # wipe team content for a fresh fork (see its docstring)
python3 update_from_upstream.py            # pull upstream code, keep team content
```

`--vocab` is auto-detected: a `.duckdb` file, or a folder of Athena CSV / Parquet (`CONCEPT.*`, `CONCEPT_ANCESTOR.*`, `CONCEPT_RELATIONSHIP.*`). Omit it to use the `ohdsiVocab` key in `config.local.json`. Each script's docstring documents its full CLI — read it rather than guessing flags.

## Source vs. generated files

**Edit these** (source of truth): `concept_sets/`, `projects/`, `concept_sets_resolved/`, `units/`, `mapping_recommendations/`, `config.json`.

**Never hand-edit** (generated, gitignored, produced by CI): `docs/data.json`, `docs/data_inline.js`, `docs/resolved_concept_ids.json`, `docs/concept_sets_resolved/`. Also never hand-edit `concept_sets_versions.json` (only `snapshot.py` writes it) or `id_counters.json` (only `build.py`, which auto-corrects it).

Pushing to `main` triggers `.github/workflows/build-and-deploy.yml`, which runs `build.py` and deploys `docs/`. Running `build.py` locally is only for previewing — not required for the live site.

## Build pipeline

Three independent scripts; `build.py` does **not** re-resolve, it reads existing resolved files as-is.

- **`resolve.py`** — expands `expression.items` (descendants via `concept_ancestor`, mapped via `concept_relationship`; resolved = included − excluded) using the OMOP vocab, writing `concept_sets_resolved/{id}.json`. Run only after editing a set's `expression`. Algorithm mirrors `R/fct_duckdb.R`.
- **`snapshot.py`** — records `(id, version) → HEAD commit SHA` in `concept_sets_versions.json` for any version not yet indexed. Auto-called by `build.py`.
- **`build.py`** — calls `snapshot.py`, then bundles all source JSON into `docs/data.json` + `docs/data_inline.js`. Resolved sets ≤100 concepts are inlined; larger ones are deferred to `docs/concept_sets_resolved/{id}.json` (lazy-loaded). See the script docstrings for output shape details.

## Data schemas

The canonical, fully-annotated concept set schema is @concept_set.example.json — follow its field order and structure exactly. Project schema: read any `projects/*.json`. Resolved schema: read any `concept_sets_resolved/*.json`.

Key fields not obvious from the example:

- **Root `name`/`description` mirror English**: top-level `name` = `metadata.translations.en.name`; top-level `description` = `metadata.translations.en.shortDescription`. The SPA keeps them in sync on edit; translations are the source of truth.
- **`shortDescription`** is the one-line datatable summary; **`longDescription`** is full Markdown shown in the detail view. Both live per-language. **No cross-language fallback** anywhere — a missing translation shows nothing (intentional, to encourage filling it).

## Conventions

- **Multilingual is language-first**: `{ en: {...}, fr: {...} }` keyed by BCP 47 code, camelCase fields (`shortDescription`). Applies to concept sets (`metadata.translations`), projects (`translations`), groups (`groups[].translations`), mapping recommendations. When adding a translatable field, put it **inside** the per-language object — never a field-first `{en, fr}` inline object. (Rationale: issue #17.) The SPA normalizes legacy `localStorage` shapes at read time, but all committed JSON must use the current shape.
- **OMOP concept metadata must come from the vocab DB, never hard-coded.** When building/editing `expression.items[].concept`, read `standard_concept`, `domain_id`, `vocabulary_id`, `concept_class_id`, `concept_code`, `concept_name`, `valid*Date`, `invalid_reason` from `SELECT … FROM concept WHERE concept_id = ?`.
- **`standardConcept` drives the SPA badge** (`App.standardBadge`), not `standardConceptCaption` (informational only). Values: `'S'` Standard, `'C'` Classification (valid hierarchy anchor with `includeDescendants`), `null` Non-standard. Writing `standardConcept: null` + `standardConceptCaption: "Classification"` is a common mistake → badge shows "Non-standard". **Non-standard concepts should not be used directly**; prefer the standard concept they `Maps to`.
- **`reviewStatus`** (concept set `metadata.reviewStatus`) is one of exactly these **snake_case** slugs — no other value is valid: `draft`, `pending_review`, `approved`, `needs_revision`, `deprecated`. Write the slug, not the human label (the README's prose `draft → pending review → approved → …` describes the *workflow*, not the literal values; a spaced value breaks the SPA filter and status badge — see `statusLabelsMap` in `docs/app.js`).
- **Categories**: from `metadata.translations.{lang}.category` / `subcategory`. **Versioning**: semantic `version`. **Athena links**: `https://athena.ohdsi.org/search-terms/terms/{conceptId}`.
- **IDs** (`id_counters.json`): monotonic, never reused; increment the relevant counter when creating a file by hand (`build.py` auto-corrects if too low).

### Recommended units (lab/biology)

`units/recommended_units.json` follows the **`EXAMPLE_UCUM_UNITS`** column of the official LOINC table (`LoincTable/Loinc.csv`, https://loinc.org/downloads/), matched by the concept's LOINC `concept_code`. If several units are listed, pick the one matching the property (e.g. `umol/L` for a Moles/volume LOINC). Any deviation must be justified in the concept set description. **Non-lab** concepts (vitals, scales, doses): methodology not yet defined — TBD.

## Versioned concept sets in projects

Projects pin each concept set to a `version` (`groups[].conceptSets: [{id, version}]`); the SPA renders that exact pinned version even after the source is bumped, preserving reproducibility. History is stored as an **index of commit SHAs** in `concept_sets_versions.json` (not duplicated files); `build.py` fetches the historical JSON via `git show <sha>:concept_sets/{id}.json`.

**When bumping a `version`, follow the two-commit workflow** (details + the `HEAD`-SHA pitfall are in `snapshot.py`'s docstring):

1. Edit the `version` field, commit it.
2. `python3 build.py` (calls `snapshot.py`, which stamps the new pair at `HEAD` — refuses files with uncommitted changes).
3. Commit the updated `concept_sets_versions.json`.

`snapshot.py` is idempotent. **Never reuse a published `(id, version)` pair** — if a version is wrong, bump again rather than rewriting it.

## SPA (`docs/`)

Single-page app, hash-routed (`#/concept-sets`, `#/projects?id=1`, …). `app.js` exposes `window.App` (shared state + utilities like `escapeHtml`, `getConceptSet`, `standardBadge`); each page is an IIFE (`concept-sets.js`, `projects.js`, `settings.js`, `dev-tools.js`, …) exposing `show`/`hide`. `router.js` + `spa-init.js` boot it; `duckdb-loader.js` loads OHDSI Athena files into in-browser DuckDB-WASM. Users can edit concept sets/projects locally (`localStorage`) and "Propose on GitHub" (copies JSON, opens the edit URL for a PR). Read the relevant module before changing SPA behavior.
