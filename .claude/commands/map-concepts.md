# Map Source Concepts to OMOP

Map source concepts from an INDICATE alignment to OMOP standard vocabulary concepts.

## Key Concepts

The INDICATE Data Dictionary uses **general concepts** (abstract clinical concepts like "Heart rate") that are mapped to one or more **OMOP concept IDs** (SNOMED, LOINC, RxNorm).

Each general concept may have:
- **Expert comment**: Domain knowledge to help with alignment (common methods, ambiguities, when to use specific concepts)
- **Expected distribution** (JSON): Typical value ranges for data quality validation

See `llm_concept_mapping.md` for detailed structure documentation.

## Instructions

You are an expert in OMOP CDM vocabulary mapping. Your task is to map source concepts to standard OMOP concepts.

### Step 1: Get Configuration

Ask the user for:

1. **App folder path** (where INDICATE stores data files)
   - Default macOS: `~/indicate_files/`
   - Default Linux: `~/.local/share/indicate/`
   - Default Windows: `%LOCALAPPDATA%/indicate/`

2. **Model name** for attribution in generated files
   - Examples: "Claude Opus 4", "Gemini 2.0 Flash", "Llama 3.3 70B"
   - This will appear as the author in mapping files

Verify that these files exist:
- `{app_folder}/indicate.db`
- `{app_folder}/ohdsi_vocabularies.duckdb`

### Step 2: List Alignments

Query the INDICATE database to list available alignments:

```r
library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "{app_folder}/indicate.db")
alignments <- dbGetQuery(con, "
  SELECT alignment_id, name, description, file_id, created_date
  FROM concept_alignments
  ORDER BY created_date DESC
")
dbDisconnect(con)
print(alignments)
```

Ask the user which alignment to map (by `alignment_id`).

### Step 3: Load Source Concepts

Load the source concepts CSV and show available categories:

```r
con <- dbConnect(SQLite(), "{app_folder}/indicate.db")
alignment <- dbGetQuery(con, "SELECT file_id, name FROM concept_alignments WHERE alignment_id = ?", params = list(ALIGNMENT_ID))
dbDisconnect(con)

csv_path <- file.path("{app_folder}", "concept_mapping", paste0(alignment$file_id, ".csv"))
source_concepts <- read.csv(csv_path, stringsAsFactors = FALSE)

cat(sprintf("Loaded %d source concepts\n", nrow(source_concepts)))

if ("category" %in% names(source_concepts)) {
  cat("\nCategories (with concept counts):\n")
  print(sort(table(source_concepts$category), decreasing = TRUE))
}
```

**Ask the user**:
1. Filter by category? (show list with counts)
2. Sort order? (by category, alphabetically, or as-is)

### Step 4: Perform Mapping

For each source concept:

1. **Search OHDSI vocabularies** using DuckDB:
```r
library(duckdb)
vocab_con <- dbConnect(duckdb(), "{app_folder}/ohdsi_vocabularies.duckdb", read_only = TRUE)

dbGetQuery(vocab_con, "
  SELECT concept_id, concept_name, vocabulary_id, domain_id, standard_concept
  FROM concept
  WHERE concept_name ILIKE '%search_term%'
    AND standard_concept = 'S'
    AND invalid_reason IS NULL
  ORDER BY vocabulary_id, LENGTH(concept_name)
  LIMIT 20
")
```

2. **Apply mapping rules**:
   - **Laboratory tests**: Always use LOINC
   - **Drugs/Medications**: Always use RxNorm
   - **Vital signs**: Prefer SNOMED (both exist, use SNOMED unless LOINC is more specific)
   - **Clinical observations, conditions, procedures**: Use SNOMED
   - Only standard concepts (`standard_concept = 'S'`)
   - Only valid concepts (`invalid_reason IS NULL`)

3. **Decide: map or skip**:
   - Suitable OMOP concept exists → create mapping with confidence score
   - NO suitable concept → do NOT force, mark as unmapped

4. **Confidence scores** (mapped only):
   - 1.0: Exact semantic match
   - 0.9: Very high confidence, minor differences
   - 0.8: High confidence, appropriate but not perfect
   - 0.7: Good match, some assumptions made
   - 0.6: Acceptable, alternatives possible
   - <0.6: Low confidence

5. **Comments** - be concise:
   - Score >= 0.9: Usually no comment needed
   - Score 0.7-0.9: Brief note: `Confidence 0.8: [reason]`
   - Score < 0.7: Explain: `Confidence 0.6 - UNCERTAIN: [reason]`

### Step 5: Generate Output Files

**1. Create `mappings_list.json`** at `{app_folder}/concept_mapping/mappings_list.json`:

```json
{
  "alignment_id": 2,
  "alignment_name": "Rennes - Concepts réanimation",
  "category": "Respiratoire / RESPI_Monitorage_Rennes",
  "description": "Respiratory monitoring concepts mapped to OMOP",
  "mappings": [
    {"code": "Parameter_123", "target_id": 3000461, "score": 1.0, "comment": ""},
    {"code": "Parameter_456", "target_id": 3024171, "score": 0.8, "comment": "Confidence 0.8: reason"},
    {"code": "Parameter_789", "target_id": null, "score": null, "comment": "UNMAPPED: no equivalent"}
  ]
}
```

**2. Run the scripts** (from project root):

```bash
# Create mapping CSV
Rscript inst/scripts/llm_create_mapping_csv.R "{app_folder}"

# Create INDICATE ZIP with model name as author
Rscript inst/scripts/llm_create_indicate_zip.R "{app_folder}" "{model_name}"
```

### Step 6: Generate Final Report

Display a comprehensive report:

```
=== MAPPING REPORT ===

Alignment: [Name]
Category: [If filtered]
Date: YYYY-MM-DD
Author: [Model name]

SUMMARY
-------
Total source concepts: 50
  - Mapped: 42 (84%)
  - Unmapped: 8 (16%)

CONFIDENCE BREAKDOWN (mapped only)
----------------------------------
  High (>= 0.9):    35 (83%)
  Medium (0.7-0.9):  5 (12%)
  Low (< 0.7):       2 (5%)

UNMAPPED CONCEPTS
-----------------
1. Parameter_49687 - Concept_name
   Reason: No standard concept for this

LOW CONFIDENCE MAPPINGS (< 0.8)
-------------------------------
1. Parameter_49688 -> LOINC 1988318 (Concept name)
   Confidence: 0.7 - Reason

OUTPUT FILES
------------
- Mapping CSV: {app_folder}/concept_mapping/mapping_<timestamp>.csv
- INDICATE ZIP: {app_folder}/concept_mapping/indicate_mapping_<timestamp>.zip

NEXT STEPS
----------
1. Review unmapped concepts - consider custom concepts
2. Review low-confidence mappings with domain expert
3. Import ZIP: Concept Mapping > Import Mappings > INDICATE format
```

## Reference

See `llm_concept_mapping.md` for detailed documentation.
