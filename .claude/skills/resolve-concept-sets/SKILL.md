---
name: resolve-concept-sets
description: Resolve INDICATE concept sets using OMOP vocabulary tables. Expands descendants and mapped concepts via resolve.py. Use when the user wants to resolve one or all concept sets.
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: "[concept-set-id or 'all']"
---

# Resolve Concept Sets

Resolve INDICATE concept set expressions into lists of OMOP concepts using the `resolve.py` script.

## Instructions

### Step 1: Parse Arguments

`$ARGUMENTS` should be one of:
- A **numeric concept set ID** (e.g., `327`) — resolve that single concept set
- `all` — resolve all concept sets
- Empty or missing — ask the user what they want to resolve

### Step 2: Get Vocabulary Source

First, check whether `config.local.json` exists at the repo root and contains an `ohdsiVocab` key. `resolve.py` reads it automatically when no CLI flag is passed, so if it is set you do **not** need to ask the user — just run `resolve.py` without `--vocab`.

If the key is not set, ask the user for a path. `resolve.py` accepts any of:

1. A **DuckDB database** — a `.duckdb` file containing OMOP vocabulary tables (`concept`, `concept_ancestor`, `concept_relationship`)
2. An **Athena CSV folder** — a directory containing tab-separated `CONCEPT.csv`, `CONCEPT_ANCESTOR.csv`, and `CONCEPT_RELATIONSHIP.csv` (downloadable from [Athena](https://athena.ohdsi.org/vocabulary/list))
3. A **Parquet folder** — a directory containing `CONCEPT.parquet`, `CONCEPT_ANCESTOR.parquet`, and `CONCEPT_RELATIONSHIP.parquet`

The three tables above are **required**. `VOCABULARY` (`VOCABULARY.csv` / `VOCABULARY.parquet`, also from the Athena download) is **optional but recommended**: when present, `resolve.py` stamps each resolved file with a `vocabularyVersion` block (the OMOP release plus the version of each vocabulary present in that set), so the exact vocabulary release behind a resolution is traceable. Without it, `vocabularyVersion` is recorded as `null`. A standard Athena vocabulary download (CSV or Parquet) already includes `VOCABULARY`; prefer pointing the script at that folder rather than a stripped-down `.duckdb` that only has the three required tables.

The format is detected automatically from the path. If the user has a different source (PostgreSQL, MySQL, etc.), adapt accordingly — for instance by exporting the relevant tables to CSV/Parquet or loading them into a temporary DuckDB.

Once the user gives you the path, suggest they save it to `config.local.json` under `ohdsiVocab` so they don't have to provide it again.

### Step 3: Run resolve.py

Run the script from the repository root.

**Single concept set:**
```bash
python3 resolve.py --id <ID>                       # uses config.local.json
python3 resolve.py --vocab <path> --id <ID>        # explicit path
```

**All concept sets:**
```bash
python3 resolve.py                                 # uses config.local.json
python3 resolve.py --vocab <path>
```

### Step 4: Show Results

1. Show the script output (number of resolved concepts)
2. For a single concept set: read the resolved file (`concept_sets_resolved/{id}.json`) and show a brief summary — total concepts and breakdown by vocabulary (SNOMED, LOINC, RxNorm, etc.)
3. Ask the user if they also want to rebuild the static site data by running `python3 build.py`
