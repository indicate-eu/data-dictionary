# LLM Concept Mapping Guide

This guide explains how to use an LLM CLI to perform OMOP concept mapping for the INDICATE Data Dictionary.

**Compatible LLM CLI tools**:
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic)
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) (Google)
- [Ollama with Claude Code](https://ollama.com/blog/claude) (local models via Ollama)
- Other LLM-powered CLI tools with file system access

## Overview

The mapping workflow consists of:
1. Loading source concepts from an alignment in the INDICATE database
2. Searching the OHDSI vocabulary (DuckDB) for matching OMOP concepts
3. Creating mappings with confidence scores and comments
4. Generating an INDICATE-format ZIP file for import

## Quick Start (Claude Code)

If using Claude Code, simply run the `/map-concepts` command which automates the entire workflow.

For other LLM tools, follow the steps below.

## Understanding the INDICATE Data Dictionary Structure

### General Concepts

**General concepts** are abstract clinical concepts (e.g., "Heart rate", "Systolic blood pressure") that serve as the standard reference for mapping. Each general concept:

- Has a unique `general_concept_id`
- Is organized by `category` and `subcategory`
- Can be mapped to one or more **OMOP concept IDs** (from SNOMED, LOINC, RxNorm, etc.)

```
General Concept: "Heart rate"
├── OMOP mappings:
│   ├── SNOMED 364075005 (Heart rate)
│   ├── LOINC 8867-4 (Heart rate)
│   └── LOINC 8893-0 (Heart rate by Pulse oximetry)
├── Expert comment (domain knowledge for alignment)
└── Expected distribution (JSON for data quality)
```

### Expert Comments

Each general concept may have an **expert comment** - domain knowledge written by clinicians to help with alignment decisions. These comments explain:

- What the concept represents clinically
- Common measurement methods or contexts
- Potential ambiguities or pitfalls
- When to use specific OMOP concepts

### Data Dictionary Files

The dictionary data is stored in CSV files in `inst/extdata/data_dictionary/`:

| File | Description |
|------|-------------|
| `general_concepts_en.csv` | General concepts with names and comments (English) |
| `general_concepts_fr.csv` | General concepts with names and comments (French) |
| `general_concepts_details.csv` | Mappings from general concepts to OMOP concept IDs |

## Prerequisites

### Required Files

1. **INDICATE Database**: `{app_folder}/indicate.db` (SQLite)
2. **OHDSI Vocabularies**: `{app_folder}/ohdsi_vocabularies.duckdb` (DuckDB)
3. **Source Concepts CSV**: `{app_folder}/concept_mapping/{file_id}.csv`

### Finding the App Folder

Default locations by OS:
- **macOS**: `~/indicate_files/`
- **Linux**: `~/.local/share/indicate/`
- **Windows**: `%LOCALAPPDATA%/indicate/`

**Always ask the user to confirm the path** - they may have customized it.

## Mapping Workflow

### Step 1: Configuration

Ask the user for:
1. **App folder path**
2. **Model name** for attribution (e.g., "Claude Opus 4", "Gemini 2.0", "Llama 3.3")

### Step 2: List Alignments

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

### Step 3: Load Source Concepts

```r
csv_path <- file.path("{app_folder}", "concept_mapping", "{file_id}.csv")
source_concepts <- read.csv(csv_path, stringsAsFactors = FALSE)

# Show categories if available
if ("category" %in% names(source_concepts)) {
  print(table(source_concepts$category))
}
```

### Step 4: Search OHDSI Vocabularies

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

## Mapping Rules

### Vocabulary Selection

| Concept Type | Primary Vocabulary |
|--------------|-------------------|
| Laboratory tests | LOINC |
| Drugs/Medications | RxNorm |
| Vital signs | SNOMED (preferred) or LOINC |
| Clinical observations | SNOMED |
| Conditions/Diagnoses | SNOMED |
| Procedures | SNOMED |

### Concept Requirements

All mapped concepts MUST be:
- **Standard**: `standard_concept = 'S'`
- **Valid**: `invalid_reason IS NULL`

### Confidence Scores

| Score | Description |
|-------|-------------|
| 1.0 | Exact semantic match |
| 0.9 | Very high confidence, minor differences |
| 0.8 | High confidence, appropriate but not perfect |
| 0.7 | Good match, some assumptions made |
| 0.6 | Acceptable, alternatives possible |
| No mapping | No suitable OMOP concept - do NOT force |

### Comment Guidelines

- **>= 0.9**: Usually no comment needed
- **0.7-0.9**: Brief note: `Confidence 0.8: [reason]`
- **< 0.7**: Explain: `Confidence 0.6 - UNCERTAIN: [reason]`

## Output Generation

### Using Helper Scripts (Recommended)

The project includes helper scripts in `inst/scripts/` to simplify output generation.

**Step 1: Create `mappings_list.json`**

```json
{
  "alignment_id": 2,
  "alignment_name": "Rennes - Concepts réanimation",
  "category": "Respiratoire / RESPI_Monitorage_Rennes",
  "description": "Respiratory monitoring concepts",
  "mappings": [
    {"code": "Parameter_123", "target_id": 3000461, "score": 1.0, "comment": ""},
    {"code": "Parameter_456", "target_id": null, "score": null, "comment": "UNMAPPED: reason"}
  ]
}
```

Save to: `{app_folder}/concept_mapping/mappings_list.json`

**Step 2: Run the scripts**

```bash
# From project root
Rscript inst/scripts/llm_create_mapping_csv.R "{app_folder}"
Rscript inst/scripts/llm_create_indicate_zip.R "{app_folder}" "{model_name}"
```

### Manual Generation

If you prefer not to use the helper scripts, you can generate files manually:

**Mapping CSV columns:**
```
source_vocabulary_id,source_concept_code,source_concept_name,target_vocabulary_id,target_concept_id,target_concept_name,confidence_score,comments
```

**INDICATE ZIP contents:**
- `metadata.json` - Export metadata
- `source_concepts.csv` - Source concept list
- `mappings.csv` - Mapping associations
- `evaluations.csv` - Empty (for future evaluations)
- `comments.csv` - Mapping comments

## Final Report

Generate a summary report with:
- Total concepts, mapped vs unmapped counts
- Confidence breakdown
- List of unmapped concepts with reasons
- List of low-confidence mappings for review
- Output file paths

## Import in INDICATE

1. Open INDICATE Data Dictionary
2. Go to **Concept Mapping** > select alignment
3. Go to **Import Mappings** tab
4. Select **INDICATE** format
5. Upload the generated ZIP file

## Reference Files

| File | Description |
|------|-------------|
| `llm_concept_mapping.md` | This guide |
| `.claude/commands/map-concepts.md` | Claude Code command |
| `inst/scripts/llm_create_mapping_csv.R` | CSV generation script |
| `inst/scripts/llm_create_indicate_zip.R` | ZIP generation script |
