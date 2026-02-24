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

Ask the user which OMOP vocabulary source they want to use. `resolve.py` natively supports:

1. **DuckDB database** (`--db <path>`) — a `.duckdb` file containing OMOP vocabulary tables (`concept`, `concept_ancestor`, `concept_relationship`)
2. **Athena CSV folder** (`--csv-dir <path>`) — a directory containing tab-separated CSV files downloaded from [Athena](https://athena.ohdsi.org/vocabulary/list): `CONCEPT.csv`, `CONCEPT_ANCESTOR.csv`, and `CONCEPT_RELATIONSHIP.csv`

If the user has a different source (PostgreSQL, MySQL, etc.), adapt accordingly — for instance by exporting the relevant tables to CSV, loading them into a temporary DuckDB, or modifying the script as needed.

Ask the user for the full path to their vocabulary source.

### Step 3: Run resolve.py

Run the script from the repository root.

**Single concept set:**
```bash
python3 resolve.py --db <path> --id <ID>
# or
python3 resolve.py --csv-dir <path> --id <ID>
```

**All concept sets:**
```bash
python3 resolve.py --db <path>
# or
python3 resolve.py --csv-dir <path>
```

### Step 4: Show Results

1. Show the script output (number of resolved concepts)
2. For a single concept set: read the resolved file (`concept_sets_resolved/{id}.json`) and show a brief summary — total concepts and breakdown by vocabulary (SNOMED, LOINC, RxNorm, etc.)
3. Ask the user if they also want to rebuild the static site data by running `python3 build.py`
