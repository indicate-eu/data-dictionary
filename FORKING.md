# Forking guide — Data Dictionary

The INDICATE Data Dictionary is designed to be forked and reused by other teams. This guide walks through:
1. **Initial setup** — fork, configure, wipe INDICATE content
2. **Day-to-day** — adding your own concept sets, building
3. **Updating** — pulling the latest code from upstream while keeping your content
4. **Deployment** — publishing the static site (GitHub Pages or GitLab Pages)

---

## 1. Initial setup

### 1.1. Create your repository

The recommended path is **"Use this template"** on GitHub: it gives you a clean, separate history rather than a fork that always points back at INDICATE. On <https://github.com/indicate-eu/data-dictionary>, click `Use this template` → `Create a new repository`, name it (e.g. `<your-org>/data-dictionary`), then clone it locally:

```bash
git clone git@github.com:<your-org>/<your-repo>.git
cd <your-repo>
```

If you prefer GitLab, mirror or import the repo there: GitLab's `New project` → `Import project` → `Repository by URL` accepts `https://github.com/indicate-eu/data-dictionary.git`. The repo ships a `.gitlab-ci.yml` so GitLab Pages works out of the box (see §4.2).

### 1.2. Edit `config.json`

This file at the repo root holds everything that identifies the dictionary as yours:

```json
{
  "title": "My Team Data Dictionary",
  "languages": ["en", "fr"],
  "defaultLanguage": "en",
  "github": {
    "repo": "<your-org>/<your-repo>",
    "branch": "main",
    "upstream": "https://github.com/indicate-eu/data-dictionary.git",
    "upstreamBranch": "main"
  },
  "organization": {
    "name": "My Team",
    "url": "https://my-team.example.org"
  },
  "customVocabulary": {
    "id": "MYTEAM",
    "codePrefix": "MYTEAM-"
  },
  "branding": {
    "logo": "logo.png",
    "favicon": "favicon.png",
    "logoAlt": "My Team"
  },
  "tabs": {
    "showProjects": true,
    "showMappingRecommendations": true
  }
}
```

Key fields:
- **`title`** — shown in the browser tab and the SPA header. This is the name of *your* dictionary.
- **`github.repo`** — the URL fragment used for "Propose on GitHub" links (`https://github.com/<repo>/edit/<branch>/...`).
- **`github.upstream`** — kept pointing at INDICATE's repo so `update_from_upstream.py` knows where to pull code updates from.
- **`organization`** — default `metadata.organization` written into new concept sets.
- **`customVocabulary`** — vocabulary id and code prefix used when a user adds a *custom* concept (not from OMOP) inside the SPA.
- **`tabs`** — set `false` to hide the Projects or Mapping Recommendations tabs if you don't need them.

**Not configurable** (intentionally): the application name and version shown in the footer always reference the master upstream INDICATE app, since that's what's running here. Your dictionary content is versioned per concept set (`version` field in each `concept_sets/<id>.json`), independently of the app version.

### 1.3. Replace branding assets

Replace these files in `docs/` with your own:
- `docs/logo.png` — header logo (transparent PNG, ~64–128 px tall)
- `docs/favicon.png` — favicon (square PNG)
- `docs/data_dictionary.png` — README screenshot (optional)

If you change the file names, update `branding.logo` / `branding.favicon` in `config.json`.

### 1.4. Replace the Documentation page

The Documentation page (`#/documentation`, served from `docs/documentation.js`) is INDICATE-specific content (mission, partners, references). Edit `docs/documentation.js` to describe your own dictionary. Until you do, leave it as-is — it still renders, it just talks about INDICATE.

### 1.5. Wipe INDICATE content

```bash
python3 reset.py
```

This wipes `concept_sets/`, `projects/`, `concept_sets_resolved/`, resets `units/recommended_units.json` to `[]` and `id_counters.json` to `{1, 1}`. Generic content (`units/unit_conversions.json`, `mapping_recommendations/`) and configuration are kept. After confirming, the script also runs `build.py` to regenerate `docs/data.json`.

Flags:
- `--yes` — skip the confirmation prompt
- `--keep-units` — also keep `recommended_units.json` (otherwise reset to `[]`)
- `--no-build` — skip the rebuild step

### 1.6. Set up local terminology paths (optional but recommended)

Copy `config.local.example.json` to `config.local.json` (gitignored):

```bash
cp config.local.example.json config.local.json
```

`config.local.json` looks like this:

```json
{
  "ohdsiVocab": "/path/to/ohdsi_vocabularies.duckdb_or_folder_with_CSV_or_Parquet",
  "loincPath": "/path/to/loinc_distribution",
  "snomedPath": "/path/to/snomed_rf2_release",
  "umlsPath": "/path/to/umls_metathesaurus",
  "npuCodesPath": "/path/to/npu-codes-latest.csv"
}
```

All entries are optional; fill in only what you have, the tools will prompt you for missing paths when needed. Each key points to a different terminology resource:

- **`ohdsiVocab`** — the OHDSI vocabulary, used by `resolve.py` and the `resolve-concept-sets` skill to expand concept sets (descendants, mapped concepts) using the `CONCEPT`, `CONCEPT_ANCESTOR`, and `CONCEPT_RELATIONSHIP` tables. Download the vocabularies you need (LOINC, SNOMED, RxNorm, ATC, UCUM, etc.) from <a href="https://athena.ohdsi.org/vocabulary/list" target="_blank" rel="noopener">ATHENA</a> (free, OHDSI account required). Three formats are accepted, auto-detected:

  - a folder of **Parquet files** — *recommended*: faster to load, much smaller on disk, and the in-browser SPA uses them to let you browse the hierarchy of *any* OMOP concept (including concepts not yet in the catalog). With CSV, in-browser hierarchy browsing is limited to concepts already used in existing concept sets.
  - a folder of **CSV files** as downloaded from Athena — works out of the box, no conversion needed.
  - a **`.duckdb` database file**, if you've already loaded the vocabularies into DuckDB.

  Athena ships CSV by default. To convert to Parquet, run one of the following in the folder containing the Athena CSV files (both CSV and Parquet can coexist — Parquet files are preferred when both are present):

  **DuckDB CLI** (install: `brew install duckdb` on macOS, or see <a href="https://duckdb.org/docs/installation" target="_blank" rel="noopener">duckdb.org/docs/installation</a>):
  ```bash
  cd /path/to/athena_download

  for f in CONCEPT CONCEPT_ANCESTOR CONCEPT_RELATIONSHIP CONCEPT_SYNONYM \
           RELATIONSHIP VOCABULARY DOMAIN CONCEPT_CLASS DRUG_STRENGTH; do
    [ -f "$f.csv" ] && duckdb -c \
      "COPY (SELECT * FROM read_csv('$f.csv', delim='\t', header=true, quote='')) \
       TO '$f.parquet' (FORMAT PARQUET);"
  done
  ```

  **Python** (`pip install duckdb`):
  ```bash
  cd /path/to/athena_download

  python3 -c "
  import duckdb, os
  for f in ['CONCEPT','CONCEPT_ANCESTOR','CONCEPT_RELATIONSHIP','CONCEPT_SYNONYM',
            'RELATIONSHIP','VOCABULARY','DOMAIN','CONCEPT_CLASS','DRUG_STRENGTH']:
      if os.path.exists(f+'.csv'):
          duckdb.sql(\"COPY (SELECT * FROM read_csv('\"+f+\".csv', delim='\t', header=true, quote='')) TO '\"+f+\".parquet' (FORMAT PARQUET)\")
          print(f'  {f}.csv -> {f}.parquet')
  "
  ```

- **`loincPath`** — the official LOINC distribution, used by the `describe-concept-set` skill to retrieve LOINC Part descriptions and `EXAMPLE_UCUM_UNITS` (the source of truth for recommended units on laboratory concepts). Download from <a href="https://loinc.org/downloads/" target="_blank" rel="noopener">https://loinc.org/downloads/</a> (free, registration required) and point this to the unzipped folder containing `LoincTable/Loinc.csv` and `AccessoryFiles/`.

- **`snomedPath`** — the SNOMED CT International RF2 release, used by the `describe-concept-set` skill to retrieve SNOMED Fully Specified Names and textual definitions. Download from <a href="https://www.nlm.nih.gov/healthit/snomedct/international.html" target="_blank" rel="noopener">https://www.nlm.nih.gov/healthit/snomedct/international.html</a> (free, UMLS licence required) and point this to the unzipped RF2 snapshot folder.

- **`umlsPath`** — the UMLS Metathesaurus, used by the `describe-concept-set` skill as a fallback source of clinical definitions when LOINC Part descriptions and SNOMED definitions are sparse. Download from <a href="https://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html" target="_blank" rel="noopener">https://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html</a> (free, UMLS licence required) and point this to the Metathesaurus folder containing `MRCONSO.RRF` and `MRDEF.RRF`.

- **`npuCodesPath`** — the NPU (Nomenclature for Properties and Units) database, used by the `describe-concept-set` skill as the primary citable source for laboratory measurement definitions (NPU is the IFCC/IUPAC reference for clinical biology). Download from <a href="https://npu-terminology.org/npu-database/" target="_blank" rel="noopener">https://npu-terminology.org/npu-database/</a> (free) and point this to the `npu-codes-latest.csv` file.

For more detail on what each terminology contains and how the skills use them, see the in-app **Documentation → Sources** page.

Once filled in:
- `python3 resolve.py` runs without `--vocab`
- The Claude skills `describe-concept-set` and `resolve-concept-sets` no longer ask for these paths each run

### 1.7. First commit

```bash
git add config.json docs/logo.png docs/favicon.png docs/data.json docs/data_inline.js
git add concept_sets/ projects/ units/recommended_units.json id_counters.json
git commit -m "Initialize fork for <my team>"
git push
```

Then publish the static site (see §4 below).

---

## 2. Day-to-day

### Add or edit concept sets

Either:
- Use the SPA at `https://<your-org>.github.io/<your-repo>/` — create concept sets locally (stored in `localStorage`), then "Propose on GitHub" to commit them.
- Or edit `concept_sets/<id>.json` directly, then `python3 build.py`.

When creating a new concept set or project file by hand, increment the matching counter in `id_counters.json` (`build.py` validates this and bumps it automatically if too low).

### Resolve concept sets

```bash
python3 resolve.py            # all sets, uses config.local.json
python3 resolve.py --id 42    # single set
```

### Rebuild the static site

```bash
python3 build.py
```

After any change to `concept_sets/`, `projects/`, `units/`, `mapping_recommendations/`, or `concept_sets_resolved/`, regenerate `docs/data.json` and `docs/data_inline.js` and commit them.

---

## 3. Updating from upstream

INDICATE keeps shipping fixes and new features. To pull them into your fork:

```bash
python3 update_from_upstream.py
```

What it does:
1. Adds (or updates) a git remote named `upstream` pointing at the URL in `config.json -> github.upstream`.
2. Runs `git fetch upstream <branch>`.
3. Checks out a fixed list of code paths from `upstream/<branch>`: `build.py`, `resolve.py`, `reset.py`, `update_from_upstream.py`, all of `docs/*.js`, `docs/*.html`, `docs/*.css`, `.claude/skills/`, `CLAUDE.md`, `FORKING.md`, `config.local.example.json`, `.gitignore`, `.gitlab-ci.yml`.
4. Leaves your content alone: `concept_sets/`, `projects/`, `units/`, `mapping_recommendations/`, `id_counters.json`, `config.json`, `config.local.json`, `docs/logo.png`, `docs/favicon.png`, `docs/data_dictionary.png`, and the generated `docs/data.json` / `docs/data_inline.js`.

Flags:
- `--dry-run` — show what would change without modifying anything
- `--yes` — skip the confirmation prompt
- `--upstream <url>` — override the upstream URL
- `--branch <name>` — override the upstream branch

After it finishes:

```bash
git diff --stat       # see what changed
git diff              # review changes in detail
python3 build.py      # if build.py or any data file changed
git commit -am "Update from upstream"
git push
```

If a code change conflicts with a local customization (e.g. you edited `docs/documentation.js` for your own dictionary), `git checkout upstream/main -- <path>` will overwrite your version. Resolve by re-applying your local edits on top, or by removing that path from the `UPSTREAM_PATHS` list in `update_from_upstream.py`.

### When NOT to use it

`update_from_upstream.py` is for routine updates. If the upstream has done a breaking change (e.g. renamed `config.json` keys), read the upstream `CHANGELOG` or commit log first — you may need to migrate your `config.json` by hand before running the update.

---

## 4. Deployment

The static site lives in `docs/`. Both GitHub Pages and GitLab Pages can serve it directly without a build step (because `docs/data.json` and `docs/data_inline.js` are committed — they are regenerated locally with `python3 build.py` whenever source data changes).

### 4.1. GitHub Pages

In the GitHub repo: `Settings` → `Pages` → `Source: Deploy from a branch` → `Branch: main, folder: /docs` → `Save`. After 1–2 minutes the site is published at:

```
https://<your-org>.github.io/<your-repo>/
```

Each push to `main` redeploys automatically. You can also use a custom domain via the same settings page.

### 4.2. GitLab Pages

The repo ships a `.gitlab-ci.yml` that publishes `docs/` to GitLab Pages on every push to the default branch. No configuration needed beyond pushing the repo to GitLab — GitLab Pages is enabled by default for public projects, and the `pages` job runs as part of the standard pipeline.

After the first successful pipeline, the site is published at:

```
https://<group>.gitlab.io/<project>/
```

(or, for personal namespaces, `https://<username>.gitlab.io/<project>/`). Custom domains are configured in `Settings` → `Pages`.

### 4.3. Rebuilding data files when needed

If you would rather not commit the generated files (`docs/data.json`, `docs/data_inline.js`, `docs/resolved_concept_ids.json`, `docs/concept_sets_resolved/`), add them to `.gitignore` and uncomment the build step inside `.gitlab-ci.yml` (or set up an equivalent GitHub Actions workflow). The default setup commits them to keep CI minimal — the data is the canonical artifact, the page just serves it.

---

## 5. Sharing concept sets between dictionaries

Forks are not isolated. A concept set authored in one dictionary (yours, INDICATE's, or any other fork) can be **imported into another** — so teams can reuse each other's work instead of redefining the same variables. The format is identical across all forks, so an import is just a copy of the JSON plus some bookkeeping.

### 5.1. Importing from another dictionary

In the SPA, on the concept sets list, click **Import**. Two modes:

- **From a repository** — paste the URL of another dictionary's repo (e.g. `https://github.com/indicate-eu/data-dictionary`). The app fetches that dictionary's published catalog (`data.json` from its Pages site) and its `concept_sets_versions.json`, then lists every concept set in a table. Filter/sort, tick the ones you want, and import. Each row is flagged **New**, **Already imported**, or **Conflict** (you already have that set at a different version — importing overwrites your local copy).
- **From a single concept set** — paste a raw JSON URL (e.g. a `raw.githubusercontent.com/.../concept_sets/10.json` link; a GitHub `/blob/` page URL is converted automatically) and preview it, or paste the JSON directly and import in one click.

Imported sets land in your local catalog (in the browser's `localStorage`); review them, then **Propose on GitHub** to commit them to your repo like any other edit.

### 5.2. Identity & provenance — how sharing stays traceable

So that a shared set can always be traced back to where it came from, four metadata fields work together (all under `metadata` in each `concept_sets/<id>.json`):

- **`uniqueId`** — a UUID identifying the concept set's *lineage*. It is generated once at creation and **kept unchanged when the set is imported into another repo**. So the same concept set keeps the same `uniqueId` everywhere it travels — even after the importing team edits it. A `uniqueId` is unique *within* a repo: importing one you already have either skips it (same version) or overwrites your copy (different version), never creates a duplicate.
- **`organization`** — split into `created` (the team that authored the set, immutable) and `current` (the team responsible for the latest content). When you import a set, `current` becomes *your* organization while `created` stays the original author — so authorship is preserved but it's clear who maintains the copy now.
- **`sourceRepo`** — the URL of the repo currently maintaining the object, refreshed on every edit. Because it lives inside the JSON, provenance survives even a manual copy-paste.
- **`origin`** — the provenance of an imported copy, written **once at import** and then frozen: `{ uniqueId, repo, version, commit, organization, importedDate }`. The `commit` is the exact source SHA (read from the source repo's `concept_sets_versions.json`), so you can always fetch back the precise version your copy was derived from. For sets created in your own dictionary, `origin` is `null`.

You don't manage these fields by hand — the SPA writes them on create, edit, and import. The id you see in the file name (`concept_sets/383.json`) is a **local** display id, re-assigned on import to avoid collisions; cross-dictionary matching is done on `uniqueId`, never on that number.

### 5.3. The fork model in one line

Importing is a **fork of a single concept set**: same `uniqueId` (shared lineage), your `organization.current`, a frozen `origin` pointing at the source. Two dictionaries can then evolve the same set independently, and the `origin` + `uniqueId` make the relationship — and any divergence — explicit.
