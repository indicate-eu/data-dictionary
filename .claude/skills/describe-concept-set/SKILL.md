---
name: describe-concept-set
description: Generate a detailed clinical description for an INDICATE concept set, using UMLS, LOINC, and SNOMED vocabulary sources. Use when the user wants to describe or document a concept set.
allowed-tools: Bash, Read, Write, Glob, Grep, WebFetch, WebSearch, AskUserQuestion, TodoWrite
argument-hint: "[concept-set-name]"
---

# Describe Concept Set

Generate a detailed clinical description for an INDICATE concept set, using UMLS, LOINC, and SNOMED vocabulary sources.

## Instructions

You are an expert in OHDSI/OMOP vocabularies and clinical terminologies. Your task is to generate a comprehensive description of a concept set that helps clinicians, laboratory experts, data scientists, and clinical informaticians understand what the concept set captures and how to align source data to it.

### Step 1: Get Configuration

Ask the user for:

1. **Concept set name** (e.g., "Heart rate", "Mechanical ventilation")
2. **Concept set ID** (the numeric ID, e.g., 327)
3. **Vocabularies folder path** — the root folder containing the terminology subfolders:
   - `UMLS - 2025AB/META/` (UMLS RRF files)
   - `LOINC source/Loinc_2.81/` (LOINC CSV files)
   - `SNOMED source/` (SNOMED RF2 files)
4. **Language** for the output description (default: English)

The GitHub URLs for the concept set files are:
- OHDSI definition: `https://raw.githubusercontent.com/indicate-eu/data-dictionary/refs/heads/main/concept_sets/{id}.json`
- Resolved concepts: `https://raw.githubusercontent.com/indicate-eu/data-dictionary/refs/heads/main/concept_sets_resolved/{id}.json`

### Step 2: Fetch Concept Set Data

Fetch both JSON files:
1. The **OHDSI concept set definition** (contains included/excluded items with `isExcluded`, `includeDescendants`, `includeMapped` flags)
2. The **resolved concept set** (contains the final list of concepts after resolution)

Parse these to identify:
- **Included concepts**: Items in the resolved list that are standard concepts (`standardConcept: "S"`)
- **Excluded concepts**: Items in the OHDSI definition where `isExcluded: true`
- **Hierarchy nodes**: LOINC Hierarchy items used to include descendants

### Step 3: Search Vocabulary Sources

For each vocabulary source, search for definitions and metadata.

#### 3a. UMLS (most important for definitions)

**Find the parent CUI** — Search `MRCONSO.RRF` for the general concept (not individual LOINC codes, which rarely have definitions):
```bash
grep "|ENG|" MRCONSO.RRF | grep "|MSH|" | grep -i "concept_name"
```

**Get definitions** from `MRDEF.RRF` — Search by CUI for definitions from these sources (in priority order):
- **MSH** (MeSH) — most authoritative medical definitions
- **NCI** (NCI Thesaurus) — good clinical definitions
- **CSP** (CRISP Thesaurus) — concise definitions
- **ICF** (International Classification of Functioning) — functional perspective
- **HPO** (Human Phenotype Ontology) — for phenotype-related concepts
- **MEDLINEPLUS** — patient-friendly definitions

```bash
grep "^CUI_HERE|" MRDEF.RRF
```

**Get semantic type** from `MRSTY.RRF`:
```bash
grep "^CUI_HERE|" MRSTY.RRF
```

**Get MeSH hierarchy** from `MRREL.RRF` — find parent/child MeSH concepts:
```bash
grep "^CUI_HERE|" MRREL.RRF | grep "|MSH|"
```

**Get synonyms** from `MRCONSO.RRF` — find all English terms for the CUI:
```bash
grep "^CUI_HERE|" MRCONSO.RRF | grep "|ENG|"
```

#### 3b. LOINC Source (for LOINC-based concept sets)

Search `LoincTable/Loinc.csv` for each LOINC code to get:
- **COMPONENT**: What is measured (e.g., "Heart rate")
- **PROPERTY**: Type of measurement (e.g., "NRat" = Number Rate)
- **TIME_ASPCT**: Temporal aspect (e.g., "Pt" = Point in time)
- **SYSTEM**: Where measured (e.g., "XXX", "Peripheral artery", "Heart")
- **SCALE_TYP**: Scale type (e.g., "Qn" = Quantitative)
- **METHOD_TYP**: Method (e.g., "Pulse oximetry", "Palpation", "EKG")
- **LONG_COMMON_NAME**: Full descriptive name
- **CONSUMER_NAME**: Patient-friendly name
- **RELATEDNAMES2**: Related keywords
- **EXAMPLE_UCUM_UNITS**: Expected units
- **CLASS**: LOINC class
- **ORDER_OBS**: Order vs Observation

Also check:
- `AccessoryFiles/ConsumerName/ConsumerName.csv` for simplified names
- `AccessoryFiles/PartFile/Part.csv` for component definitions

#### 3c. SNOMED Source (for SNOMED-based concept sets)

If the concept set contains SNOMED concepts, extract from the RF2 ZIP:
- `sct2_Description_Snapshot-en_INT_20251101.txt` — FSN and synonyms
- `sct2_TextDefinition_Snapshot-en_INT_20251101.txt` — Full text definitions (only ~3.6% of concepts have them)

```bash
unzip -p "path/to/zip" "*/sct2_Description_Snapshot-en*" | grep "SNOMED_ID"
unzip -p "path/to/zip" "*/sct2_TextDefinition_Snapshot-en*" | grep "SNOMED_ID"
```

#### 3d. Web Search (complementary)

Use web search to find additional clinical information that vocabulary files may not provide:
- **Clinical guidelines** mentioning the concept (e.g., normal ranges, measurement protocols)
- **Wikipedia or medical references** for clear clinical context
- **LOINC.org** for official LOINC descriptions and usage notes
- **SNOMED browser** for concept details and hierarchy context

This is especially useful for:
- Concepts that lack definitions in UMLS/SNOMED (most LOINC codes)
- Understanding clinical nuances (e.g., when to use invasive vs non-invasive measurement)
- Normal ranges and units in specific clinical contexts (ICU, neonatal, etc.)

Present web sources found to the user and let them decide which to include in the final description.

#### 3e. Units Data (recommended units & conversions)

The INDICATE data dictionary maintains two unit files that specify how measurements should be stored:

- `units/recommended_units.csv` — Maps each OMOP measurement concept to its recommended unit (columns: `concept_id`, `recommended_unit_concept_id`)
- `units/unit_conversions.csv` — Lists conversion factors between units for specific measurements (columns: `omop_concept_id_1`, `unit_concept_id_1`, `conversion_factor`, `omop_concept_id_2`, `unit_concept_id_2`)

These files are available locally in the repository or via GitHub:
- `https://raw.githubusercontent.com/indicate-eu/data-dictionary/refs/heads/main/units/recommended_units.csv`
- `https://raw.githubusercontent.com/indicate-eu/data-dictionary/refs/heads/main/units/unit_conversions.csv`

**Lookup process**:

1. Get the OMOP concept IDs of all resolved standard concepts from the resolved concept set JSON.
2. Search `recommended_units.csv` for rows where `concept_id` matches any of these OMOP concept IDs. This gives the recommended unit concept ID for each measurement.
3. Search `unit_conversions.csv` for rows where `omop_concept_id_1` or `omop_concept_id_2` matches any of these OMOP concept IDs. This gives the accepted alternative units and their conversion factors.
4. To resolve unit concept IDs to human-readable names (e.g., 8541 → "beats per minute"), look up the concept ID in the OMOP vocabulary. If an OMOP vocabulary database is not available, use Athena (`https://athena.ohdsi.org/search-terms/terms/{unitConceptId}`) or infer from LOINC `EXAMPLE_UCUM_UNITS` field.

```bash
# Example: search recommended units for concept IDs from resolved set
grep -E "^(3027018|4239408|...)" units/recommended_units.csv

# Example: search conversions for those concept IDs
grep -E "(3027018|4239408|...)" units/unit_conversions.csv
```

**What to extract**:
- The recommended unit for each standard concept (or confirm they all share the same recommended unit)
- Any alternative units with conversion factors (e.g., "/min" ↔ "{beats}/min")
- Whether all concepts in the set share the same recommended unit or if there are exceptions

### Step 4: Present Raw Data

Before generating the description, show the user what was found:

```
=== VOCABULARY DATA FOUND ===

UMLS DEFINITIONS:
- [Source]: "Definition text..."
- [Source]: "Definition text..."

SEMANTIC TYPE: T201 - Clinical Attribute

MESH HIERARCHY:
- Parents: ...
- Children: ...
- Related: ...

SYNONYMS: term1, term2, term3

LOINC DECOMPOSITION (for each included standard concept):
| LOINC Code | Long Name | System | Method | Condition | UCUM Units | Class |
|------------|-----------|--------|--------|-----------|------------|-------|
| ...        | ...       | ...    | ...    | ...       | ...        | ...   |

SNOMED DATA (if applicable):
- FSN: ...
- Synonyms: ...
- TextDefinition: ...

EXCLUDED CONCEPTS:
| Concept | Reason for exclusion (inferred) |
|---------|-------------------------------|
| ...     | ...                           |

UNITS DATA:
- Recommended unit: [unit name] (concept ID: ...)
- Alternative units with conversions:
  | From Unit | To Unit | Conversion Factor |
  |-----------|---------|-------------------|
  | ...       | ...     | ...               |
- Concepts without recommended unit: [list or "none"]

WEB SOURCES (if found):
- [URL]: key information found
```

Ask the user if they want to adjust anything before generating the description.

### Step 4b: Propose Concept Grouping

Before generating the description, present the proposed logical grouping of included standard concepts to the user. Group concepts by method, site, condition, or clinical context — NOT alphabetically.

A concept may appear in **multiple groups** if it logically belongs to more than one category (e.g., a concept specifying both a method and a patient condition should appear under both "By measurement method" and "By clinical condition").

Ask the user if they want to adjust the grouping before proceeding.

### Step 5: Generate Description

Generate a structured description in Markdown and **write it to a temporary file** (`tmp_{concept_set_name}_description.md` at the repository root) so the user can preview it easily.

#### Writing Guidelines

- **Audience**: Clinicians, laboratory experts, data scientists, and clinical informaticians — some may be domain experts, others not
- **Goal**: Enable correct data alignment and provide a shared reference for multidisciplinary teams
- **Tone**: Precise, technical but accessible — a clinician should recognize the clinical reality, a data scientist should understand what to map
- **Keep it simple**: Do NOT include LOINC technical jargon in the description body (no LOINC class names like "HRTRATE.ATOM", no "System is XXX (unspecified)", no UMLS semantic type codes like "T201"). The LOINC/UMLS decomposition data is used to *inform* the writing but should not appear verbatim. The description must be easy to read for a non-terminologist.
- **UMLS as a source, not in the text**: UMLS definitions (MeSH, NCI, ICF, etc.) should be used to write authoritative clinical definitions, but UMLS-specific identifiers (CUIs, semantic types, MeSH descriptor IDs) should only appear in the References section, never in the body text. Same for MeSH hierarchy — describe the clinical context naturally (e.g., "Heart rate is a vital sign and a hemodynamic parameter") without citing MeSH tree numbers.
- **DO NOT** repeat general ETL/mapping rules (LOINC for labs, RxNorm for drugs, etc.) — these are documented elsewhere
- **DO** include the OMOP concept_id alongside the vocabulary code and the vocabulary name for every concept citation, using the format `concept_id / concept_code (vocabulary)` (e.g., `3027018 / 8867-4 (LOINC)`, `4091643 / 249043002 (SNOMED)`). The OMOP concept_id comes first, then the vocabulary code, then the vocabulary name in parentheses. This applies everywhere a concept is cited: included concepts, excluded concepts (both hierarchy nodes and individual standard concepts), inline references in prose, and mapping notes.
- **DO** explain clinical nuances that affect mapping decisions
- **DO** explain what distinguishes each concept from similar ones
- **DO** group concepts logically (by method, site, condition) rather than alphabetically
- **DO** highlight which concept is the most generic/default one
- **No assumptions in mapping notes**: When information is missing from the source data (e.g., method, site, or position not documented), always map to the most general concept. Do NOT suggest alternative specific concepts as fallbacks — if the information is not there, use the generic concept, period.

#### References Format

Use **numbered Vancouver-style references** throughout the description:

- **Inline citations**: Use `[1]`, `[2]`, etc. in the body text to cite sources.
- **References section**: At the end, list all references in a `## References` section with this format:

```markdown
## References

[1] {Author(s)}. {Title}. In: {Book/Journal}. {Publisher}; {Year}.
    Available: <a href="{URL}" target="_blank">{URL}</a>
```

Key rules for references:
- **Links must open in a new page**: Use HTML `<a href="..." target="_blank">` for all URLs in the references section, since the description is rendered as HTML/Markdown in a web application.
- **Do NOT cite vocabulary sources as references** — LOINC, SNOMED, and UMLS are the standard vocabulary sources used to build the data dictionary and are already known to the audience. Every concept in the description already carries its LOINC or SNOMED code, which is sufficient. UMLS definitions (MeSH, NCI, ICF, etc.) are used to *write* the clinical definitions but UMLS itself should not appear as a reference.
- **Only cite truly external sources**: clinical guidelines, textbooks, web references (e.g., StatPearls, UpToDate, society guidelines).
- **Do NOT list individual concept codes** (LOINC codes, SNOMED IDs, UMLS CUIs) in the references section. The concepts are identified by their codes in the body text.
- **Web sources**: Standard bibliographic format with author, title, publisher, and URL.
- **INDICATE units data**: Reference `recommended_units.csv` and `unit_conversions.csv` if unit data was found and used.

#### Structure

```markdown
## Definition & Clinical Context

[2-4 paragraphs combining:]
- Authoritative definition (synthesized from MeSH/NCI/UMLS definitions, without mentioning UMLS explicitly)
- What this measures and why it matters clinically
- Where this fits clinically (e.g., "a vital sign and hemodynamic parameter" — derived from MeSH hierarchy but expressed naturally)
- Key clinical contexts where this is used (ICU, emergency, routine monitoring...)
- Normal ranges if relevant and available [with reference]
- Units of measurement (from LOINC EXAMPLE_UCUM_UNITS and/or INDICATE units data)

## Included Concepts

[Brief intro explaining the concept set structure]

### [Group 1 name — e.g., "General heart rate"]
[For each concept:]
- *[OMOP concept_id] / [vocabulary code] — [Long common name] ([vocabulary])*: [1-2 sentence clinical description. No LOINC technical fields.]

### [Group 2 name — e.g., "By measurement method"]
...

[Group concepts logically. A concept may appear in multiple groups if relevant.]

**Note on units**: If all concepts share the same unit, state it once at the set level. Only call out individual units when they differ.

## Excluded Concepts

[Brief intro explaining the exclusion strategy]

[For each excluded concept or group:]
### [Group name]
[Why excluded]

## Mapping Notes

- Which concept to use as default when the source doesn't specify method/site
- Common source system names that map to specific concepts
- Disambiguation tips for similar-sounding concepts
- Any gotchas or common mapping errors
- IMPORTANT: Never suggest fallback to a specific concept when information is missing — always default to the most general concept

## References

[Numbered Vancouver-style references as described above]
```

### Step 6: Output

Write the generated description to `tmp_{concept_set_name}_description.md` at the repository root so the user can preview it in their IDE. Present it and ask if they want any adjustments.

The description can then be:
1. Stored as the `longDescription` field in the concept set metadata
2. Used as documentation for the INDICATE data dictionary
3. Shared with data providers for alignment guidance
