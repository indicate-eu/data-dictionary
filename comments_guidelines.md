# Expert Comments Guidelines for INDICATE Data Dictionary

This document provides guidelines for writing expert comments that help data scientists and clinicians choose the correct concept alignment in the INDICATE Minimal Data Dictionary.

## Purpose

Expert comments serve to:
- **Define concepts** clinically for data scientists who may not have clinical expertise
- **Guide mapping decisions** by explaining when to use generic vs specific concepts
- **Provide context** about measurement methods, clinical scenarios, and equipment
- **Highlight important clinical considerations** and common pitfalls

## Target Audience

- **Data scientists** mapping local database concepts to INDICATE standard concepts
- **Clinical data managers** harmonizing ICU data across institutions
- **Researchers** using the INDICATE dictionary for data standardization

---

## Vocabulary Source Data Access

When writing expert comments, you can access official descriptions from LOINC and SNOMED CT source files to supplement your documentation. The INDICATE Data Dictionary package provides a unified function `get_concept_info()` to retrieve concept descriptions.

### Environment Variable Setup

Before using the source data functions, set the following environment variables:

**For LOINC:**
```r
Sys.setenv(LOINC_CSV_PATH = "/Users/borisdelange/Documents/Vocabularies/LOINC source/Loinc_2.81/LoincTable/Loinc.csv")
```

**For SNOMED CT:**
```r
Sys.setenv(SNOMED_RF2_PATH = "/tmp/SnomedCT_InternationalRF2_PRODUCTION_20251101T120000Z/Snapshot/Terminology")
```

**To persist these settings across R sessions**, add them to your `.Renviron` file:

```bash
# Open .Renviron in your home directory
file.edit("~/.Renviron")

# Add these lines:
LOINC_CSV_PATH="/Users/borisdelange/Documents/Vocabularies/LOINC source/Loinc_2.81/LoincTable/Loinc.csv"
SNOMED_RF2_PATH="/tmp/SnomedCT_InternationalRF2_PRODUCTION_20251101T120000Z/Snapshot/Terminology"

# Save and restart R
```

### Using get_concept_info()

The `get_concept_info()` function provides a unified interface to retrieve concept descriptions from both LOINC and SNOMED CT source files.

**Function signature:**
```r
get_concept_info(vocabulary = c("LOINC", "SNOMED"), code)
```

**Examples:**

```r
# Load the function from the package
source("R/fct_vocabularies.R")

# Get LOINC concept information
get_concept_info("LOINC", "8867-4")
# Output:
# LOINC Code: 8867-4
# Component: Heart rate
# System: XXX
# Method: (empty)
# Long Name: Heart rate
# Definition: (not available)

# Get SNOMED concept information
get_concept_info("SNOMED", "364075005")
# Output:
# SNOMED Concept ID: 364075005
# FSN: Heart rate (observable entity)
# Synonyms: HR | Cardiac frequency | Heart frequency | Pulse rate | ...
# Definition: (not available)
```

**Return values:**
- **For LOINC**: Returns a data frame with columns `LOINC_NUM`, `COMPONENT`, `SYSTEM`, `METHOD_TYP`, `LONG_COMMON_NAME`, `DefinitionDescription`
- **For SNOMED**: Returns a list with `ConceptID`, `FSN` (Fully Specified Name), `Synonyms` (character vector), `Definition`

### LOINC Source Data Structure

The `Loinc.csv` file contains these relevant columns:

- **`LOINC_NUM`**: LOINC code (e.g., "8867-4")
- **`COMPONENT`**: What is measured (e.g., "Heart rate")
- **`PROPERTY`**: Type of property (e.g., "NRat" = Numeric Rate)
- **`SYSTEM`**: Anatomical location or specimen type (e.g., "XXX" = unspecified, "Arterial system", "Intra arterial line")
- **`METHOD_TYP`**: Measurement method (e.g., "Pulse oximetry", "EKG", "Invasive")
- **`LONG_COMMON_NAME`**: Full human-readable name
- **`SHORTNAME`**: Abbreviated name
- **`DefinitionDescription`**: Official LOINC definition text (when available)

**Note**: The `DefinitionDescription` field is often empty for many LOINC concepts. Use `LONG_COMMON_NAME`, `COMPONENT`, `SYSTEM`, and `METHOD_TYP` to construct descriptions when official definitions are not available.

### SNOMED CT Source Data Structure

SNOMED CT uses RF2 (Release Format 2) files with two key data sources:

**Description File** (`sct2_Description_Snapshot-en_INT_*.txt`):
- **Fully Specified Name (FSN)**: Unique, unambiguous concept name with semantic tag (typeId: 900000000000003001)
- **Synonyms**: Alternative terms for the concept (typeId: 900000000000013009)

**Text Definition File** (`sct2_TextDefinition_Snapshot-en_INT_*.txt`):
- **Definition**: Formal text definition (rarely populated - only ~12% of concepts)

**Important Notes:**
- SNOMED FSN always includes a semantic tag in parentheses (e.g., "Heart rate (observable entity)")
- Synonyms provide common clinical terms used in practice
- Text definitions are sparse; rely on FSN and synonyms for most concepts

### Workflow for Writing Expert Comments

1. **Set environment variables** (one-time setup in `.Renviron`)
2. **Retrieve source descriptions** using `get_concept_info()`
3. **Review official terminology** for accuracy
4. **Write clinical definitions** in plain language for data scientists
5. **Add mapping guidance** based on LOINC/SNOMED structure
6. **Include units and normal values** not found in source files

**Example workflow:**

```r
# 1. Get LOINC description
get_concept_info("LOINC", "76214-6")
# Invasive Mean blood pressure

# 2. Get SNOMED description
get_concept_info("SNOMED", "6797001")
# Mean blood pressure (observable entity)

# 3. Write expert comment incorporating source data + clinical guidance
# (See examples in subsequent sections)
```

---

## Standard Markdown Structure

All expert comments should follow this **modular structure**:

```markdown
# Definition
[Clinical definition in 1-2 sentences + standard units]
[Optional: mention of normal values if relevant]

# Mapping Strategy
[LOINC pre-coordination explanation if applicable - see section 2 for standard text]
[One sentence stating what to prioritize]

## Recommended concepts

**Default and [primary dimension] concepts:**

- **[Default concept]** ([Vocabulary] [Code]): Use when [condition]
- **[Concept]** ([Vocab] [Code]): [When to use this concept]

**[Additional grouping if needed]:**

- **[Concept]** ([Vocab] [Code]): [When to use this concept]

## Not recommended for routine use
[OPTIONAL - only when there are many non-recommended concepts]

[Explanation of when to use these concepts and FACT_RELATIONSHIP recommendation]

**[Grouping name]:**

- **[Concept]** ([Vocab] [Code]): [When to use this concept]

# Clinical Context
[OPTIONAL - only for very complex concepts like Cardiac Output]

**[Context type]:** [Guidance]

# Important Notes
[OPTIONAL - clinical warnings, common pitfalls]

- [Important note]
```

### Required Sections

All expert comments **must include**:

1. **Definition** - Clinical definition with units and normal values
2. **Mapping Strategy** with:
   - LOINC pre-coordination explanation (if applicable)
   - Statement of what to prioritize
   - **Recommended concepts** subsection with default concept and primary dimension groupings

### Optional Sections

Include these sections **only when necessary**:

3. **Not recommended for routine use** (within Mapping Strategy) - For concepts with many position/context modifiers that should use FACT_RELATIONSHIP instead
4. **Clinical Context** - For complex concepts with multiple clinical scenarios (e.g., ICU vs cardiology settings)
5. **Important Notes** - Clinical warnings, measurement caveats, common errors

---

## Writing Guidelines

### 1. Definition Section

**Format:**
```markdown
# Definition

[Concept name] represents/is [clinical definition], expressed in **[units]**.
[Optional: Normal values: X-Y units in adults at rest.]
[Optional: Additional clinical context in 1 sentence.]
```

**Best practices:**
- Keep to 1-3 sentences maximum
- **Bold** the units (e.g., **L/min**, **bpm**, **mmol/L**)
- Include normal/typical ranges when clinically relevant
- Use present tense, active voice
- Avoid jargon unless necessary (then explain it)

**Examples:**

✅ **Good:**
> Heart rate represents the number of heartbeats per unit of time, expressed in **beats per minute (bpm)**. Normal resting heart rate in adults ranges from 60-100 bpm.

✅ **Good:**
> Positive End-Expiratory Pressure (PEEP) is the pressure in the lungs above atmospheric pressure at the end of expiration, expressed in **cmH2O**. Typical ICU values: 5-15 cmH2O.

❌ **Too technical:**
> Heart rate is the frequency of cardiac contractile cycles per temporal unit quantified via electrocardiographic R-R interval analysis.

❌ **Too vague:**
> Heart rate is how fast the heart beats.

---

### 2. Mapping Strategy Section

**Format:**
```markdown
# Mapping Strategy

[Explanation of LOINC pre-coordination if applicable - use standard text below]

[One sentence stating what to prioritize]

## Recommended concepts

**Default and [primary dimension] concepts:**

- **[Default concept]** ([Vocab] [Code]): Use when [condition]
- **[Concept]** ([Vocab] [Code]): [When to use this concept]

**[Additional grouping if needed]:**

- **[Concept]** ([Vocab] [Code]): [When to use this concept]

## Not recommended for routine use

[Explanation of when to use these concepts and FACT_RELATIONSHIP recommendation]

**[Grouping name]:**

- **[Concept]** ([Vocab] [Code]): [When to use this concept]
```

**Best practices:**
- For concepts with many LOINC mappings that combine dimensions (method + position + context), **start with the standard LOINC pre-coordination explanation**:
  > "LOINC uses **pre-coordinated concepts** that combine multiple dimensions (measurement method + position + context) into single codes. This can create redundancy when only one dimension (e.g., method) is documented. For most ICU use cases, we recommend capturing the measurement method and linking position or clinical context separately via OMOP FACT_RELATIONSHIP table."
- State what to **prioritize** (usually measurement method for vital signs/labs)
- Split concepts into **"Recommended concepts"** and **"Not recommended for routine use"** sections when applicable
- In "Recommended concepts":
  - List the **default/generic concept first**
  - Group by **primary dimension** (e.g., measurement method)
  - Include specialized concepts (neonatal, obstetric) if they are recommended for those populations
- In "Not recommended for routine use":
  - Explain when to use these concepts (e.g., "only when position is the primary clinical focus")
  - Recommend using **FACT_RELATIONSHIP** with SNOMED position/context concepts instead
  - Provide OMOP concept IDs for common SNOMED modifiers (e.g., "Supine body position" SNOMED 4221822, "Sitting position" SNOMED 4142787)
- Keep descriptions concise (one line per concept)
- Use consistent phrasing: "Use when...", "For...", "Measured via..."

**Examples:**

✅ **Good (concept with pre-coordinated LOINC concepts):**
```markdown
# Mapping Strategy

LOINC uses **pre-coordinated concepts** that combine multiple dimensions (measurement method + position + context) into single codes. This can create redundancy when only one dimension (e.g., method) is documented. For most ICU use cases, we recommend capturing the measurement method and linking position or clinical context separately via OMOP FACT_RELATIONSHIP table.

Prioritize the **measurement method** over position or context modifiers.

## Recommended concepts

**Default and measurement method concepts:**

- **Heart rate** (LOINC 8867-4): Use when measurement method is unspecified
- **Heart rate by Pulse oximetry** (LOINC 8889-8): Heart rate derived from photoplethysmography via pulse oximeter sensor
- **Heart rate.beat-to-beat by EKG** (LOINC 76282-3): Heart rate captured via electrocardiography (ECG/telemetry)
- **Heart rate Intra arterial line by Invasive** (LOINC 60978-4): Heart rate measured via intra-arterial catheter

**Neonatal/obstetric concepts:**

- **1 minute Apgar Heart rate** (LOINC 32407-9): Apgar score heart rate component at 1 minute after birth (0-2 scale, not bpm)
- **Fetal Heart rate** (LOINC 55283-6): Heart rate measured in utero via fetal monitoring

## Not recommended for routine use

Use these concepts **only when position, activity, or clinical context is the primary clinical focus** (e.g., orthostatic vital sign assessment, exercise stress testing).

For most use cases, we recommend capturing patient position or clinical context separately using OMOP FACT_RELATIONSHIP table linked to SNOMED position concepts (e.g., "Supine body position" SNOMED 4221822, "Sitting position" SNOMED 4142787) rather than using pre-coordinated LOINC concepts.

**Specific concepts by patient position/activity:**

- **Heart rate --supine** (LOINC 68999-2): Measured while patient is lying flat
- **Heart rate --sitting** (LOINC 69000-8): Measured while patient is seated
- **Heart rate --standing** (LOINC 69001-6): Measured while patient is upright/standing
```

✅ **Good (complex concept with hierarchy, no pre-coordination issue):**
```markdown
# Mapping Strategy

Prioritize the most granular concept available that matches your measurement method and anatomical location. Use the generic "Cardiac output" concept only when the specific measurement method or anatomical location cannot be determined.

## Recommended concepts

**Default concept:**

- **Cardiac output** (SNOMED 82799009): Use when measurement method and anatomical location are unknown

**Left Ventricular concepts:**

- **Left ventricular Cardiac output by US.doppler** (LOINC 8735-3): Doppler ultrasound measurement through LVOT or aortic valve
- **Left ventricular Cardiac output by Indicator dilution** (LOINC 8737-9): Thermodilution or other indicator-based techniques (Swan-Ganz, PiCCO)
- **Left ventricular Cardiac output by Continuous** (LOINC 76519-8): Continuous monitoring systems (PiCCO, FloTrac, LiDCO)

**Right Ventricular concepts:**

- **Right ventricular cardiac output** (SNOMED 428628004): Generic right ventricular measurement
- **Right ventricular Cardiac output by Indicator dilution** (LOINC 101151-9): Pulmonary artery thermodilution (Swan-Ganz catheter)
```

❌ **Too vague:**
```markdown
Use the best concept you can find. If you don't know which one, use the generic one.
```

❌ **Missing context:**
```markdown
**Specific concepts:**
- **Heart rate by Pulse oximetry** (LOINC 8889-8)
- **Heart rate.beat-to-beat by EKG** (LOINC 76282-3)
```
*Problem: Doesn't explain when to use each concept*

---

### 3. Clinical Context Section (Optional)

**When to include:**
- Concept has different clinical uses in different specialties (ICU vs cardiology)
- Measurement method varies significantly by clinical setting
- Equipment or protocols differ across contexts

**Format:**
```markdown
# Clinical Context

**For [setting/specialty]:**
- [Guidance for this context]

**For [setting/specialty]:**
- [Guidance for this context]
```

**Example:**
```markdown
# Clinical Context

**For intensive care/critical care monitoring:**
- Thermodilution methods (Swan-Ganz, PiCCO) → Use "Indicator dilution" concepts
- Pulse contour analysis (FloTrac, LiDCO) → Use "Continuous" measurement concepts
- Point-of-care ultrasound → Use Doppler or 2D ultrasound concepts

**For cardiology assessments:**
- Transthoracic echocardiography → Use LVOT Doppler or 2D calculated methods
- Cardiac catheterization → Use Fick method or indicator dilution concepts
- Cardiac MRI → Use "by MR" concept
```

**Do NOT include this section for:**
- Simple vital signs (temperature, SpO2)
- Laboratory values with straightforward specimen types
- Drugs (unless route matters significantly)

---

### 4. Important Notes Section (Optional)

**When to include:**
- Common measurement errors or misunderstandings
- Clinical warnings (e.g., when measurements may be unreliable)
- Physiological caveats (e.g., intrinsic PEEP in COPD)
- Data quality considerations
- Distinction between similar concepts

**Format:**
```markdown
# Important Notes

- [Concise note with clinical or technical insight]
- [Another important consideration]
```

**Best practices:**
- Use bullet points (easier to scan)
- Keep each note to 1-2 sentences
- Focus on **actionable information** (not just interesting facts)
- Prioritize clinical safety and data quality

**Examples:**

✅ **Good:**
```markdown
# Important Notes

- Heart rate from pulse oximetry may differ from ECG-derived heart rate in cases of arrhythmias or poor peripheral perfusion
- ECG provides the most accurate heart rate measurement and is the gold standard for detecting arrhythmias
```

✅ **Good:**
```markdown
# Important Notes

- Use "Total PEEP" for routine measured values without pause maneuver
- Use "Intrinsic" and "Extrinsic" only when an expiratory pause was performed to distinguish them
- In physiological conditions without shunts, left ventricular cardiac output equals right ventricular cardiac output
```

❌ **Too general:**
```markdown
# Important Notes

- Always check data quality
- Consult clinicians if unsure
```

---

## Examples by Concept Category

### Category 1: Simple Vital Signs (e.g., Temperature, SpO2)

**Characteristics:**
- Few or no measurement method variants
- Universally understood
- Standard units

**Template:**
```markdown
# Definition

[Concept] represents [clinical definition], expressed in **[units]**. Normal values: [range].

# Mapping Strategy

**Default concept:** [Name] ([Vocab] [Code]) - Use for all [concept] measurements

**Specific concepts** (if applicable):
- **[Name]** ([Vocab] [Code]): [Specific measurement site or method]
```

**Example: Body Temperature**
```markdown
# Definition

Body temperature represents core or peripheral body temperature, expressed in **degrees Celsius (°C)** or **degrees Fahrenheit (°F)**. Normal core temperature: 36.5-37.5°C (97.7-99.5°F).

# Mapping Strategy

**Default concept:** Body temperature (LOINC 8310-5) - Use when measurement site is unspecified

**Specific concepts:**
- **Core temperature** (LOINC 8329-5): Measured at core sites (rectal, esophageal, pulmonary artery, bladder)
- **Oral temperature** (LOINC 8331-1): Measured orally
- **Axillary temperature** (LOINC 8332-9): Measured in the axilla
- **Tympanic temperature** (LOINC 8333-7): Measured via tympanic membrane (infrared ear thermometer)

# Important Notes

- Core temperature is most accurate for critically ill patients
- Peripheral measurements (oral, axillary, tympanic) may underestimate core temperature in shock or hypothermia
```

---

### Category 2: Laboratory Values (e.g., Glucose, Creatinine, Electrolytes)

**Characteristics:**
- Specimen type variations (arterial, venous, capillary)
- Standard units (may have US vs SI units)
- Point-of-care vs lab measurements

**Template:**
```markdown
# Definition

[Lab parameter] represents [what it measures], expressed in **[units]**. Normal range: [values].

# Mapping Strategy

**Default concept:** [Name] in Blood (LOINC [Code]) - Use when specimen type is unspecified

**Specific concepts:**
- **[Name] in Serum or Plasma** (LOINC [Code]): Laboratory measurement from venous sample
- **[Name] in Arterial blood** (LOINC [Code]): From arterial blood gas analysis
- **[Name] in Capillary blood** (LOINC [Code]): Point-of-care fingerstick measurement
```

**Example: Plasma Glucose**
```markdown
# Definition

Plasma glucose represents the concentration of glucose in blood plasma, expressed in **mmol/L** or **mg/dL**. Normal fasting values: 3.9-5.5 mmol/L (70-100 mg/dL).

# Mapping Strategy

**Default concept:** Glucose [Mass/volume] in Blood (LOINC 2345-7) - Use when specimen type is unspecified

**Specific concepts:**
- **Glucose [Mass/volume] in Serum or Plasma** (LOINC 2345-7): Laboratory measurement from venous or arterial blood sample
- **Glucose [Mass/volume] in Capillary blood** (LOINC 2339-0): Point-of-care fingerstick measurement
- **Glucose [Mass/volume] in Arterial blood** (LOINC 2340-8): From arterial blood gas analysis

# Important Notes

- Point-of-care capillary measurements may differ from laboratory plasma measurements by ±10-15%
- For critically ill patients, arterial blood gas glucose is preferred for accuracy
```

---

### Category 3: Ventilation Parameters (e.g., PEEP, Tidal Volume)

**Characteristics:**
- Set vs measured distinction
- Inspiratory vs expiratory for measured values
- Complex physiological interpretation

**Template:**
```markdown
# Definition

[Parameter] represents [physiological definition], expressed in **[units]**. Typical ICU values: [range].

# Mapping Strategy

**Default concept:** [Name] (SNOMED [Code]) - Use when set/measured distinction is unavailable

**Specific concepts:**
- **[Name] setting** (LOINC [Code]): Value set on the ventilator
- **[Name] measured** (LOINC [Code]): Value measured by the ventilator

# Important Notes

- [Clinical interpretation notes]
- [When to use set vs measured]
```

**Example: PEEP**
```markdown
# Definition

Positive End-Expiratory Pressure (PEEP) is the pressure in the lungs above atmospheric pressure at the end of expiration, expressed in **cmH2O**. Typical ICU values: 5-15 cmH2O.

# Mapping Strategy

**Default concept:** Positive end expiratory pressure (SNOMED 250854009) - Use when set/measured distinction is unavailable

**Specific concepts:**
- **Positive end expiratory pressure setting** (LOINC 76248-4): Value set on the ventilator
- **Total PEEP Respiratory system** (LOINC 76530-5): Measured PEEP (includes intrinsic + extrinsic components)
- **Intrinsic PEEP Respiratory system** (LOINC 76254-2): Auto-PEEP, measured during expiratory pause maneuver
- **Extrinsic PEEP Respiratory system** (LOINC 76253-4): Applied PEEP, measured during expiratory pause maneuver

# Important Notes

- Use "Total PEEP" for routine measured values without an expiratory pause maneuver
- Use "Intrinsic" and "Extrinsic" PEEP only when an expiratory pause was performed to distinguish them
- In spontaneously breathing patients, intrinsic PEEP may be present without extrinsic PEEP (e.g., COPD, asthma)
```

---

### Category 4: ICD-10 Conditions (e.g., Diabetes, COPD, CHF)

**Characteristics:**
- Hierarchical coding (more digits = more specificity)
- Type, complications, severity encoded in code
- Strong preference for granular codes

**Template:**
```markdown
# Definition

[Condition] is [clinical definition]. ICD-10 coding distinguishes [what distinctions are encoded].

# Mapping Strategy

**Always use the most specific ICD-10 code available** that captures [type/complication/severity].

**Hierarchy of specificity:**
1. **Most specific:** [Description of most granular level]
2. **Intermediate:** [Description of intermediate level]
3. **Least specific:** [Description of least granular level - avoid when possible]

**Key ICD-10 categories:**
- **[Code pattern]**: [Category description]
- **[Code pattern]**: [Category description]

# Important Notes

- Avoid using unspecified codes when more specific information is documented
- [Additional coding guidance]
```

**Example: Diabetes Mellitus**
```markdown
# Definition

Diabetes mellitus is a chronic metabolic disorder characterized by hyperglycemia. ICD-10 coding distinguishes type, complications, and control status.

# Mapping Strategy

**Always use the most specific ICD-10 code available** that captures type, complications, and control status.

**Hierarchy of specificity:**
1. **Most specific:** Type + complication + control (e.g., E11.65 - Type 2 diabetes with hyperglycemia)
2. **Intermediate:** Type + complication (e.g., E11.6 - Type 2 diabetes with other specified complication)
3. **Least specific:** Type only (e.g., E11 - Type 2 diabetes mellitus)

**Key ICD-10 categories:**
- **E10.x**: Type 1 diabetes mellitus
- **E11.x**: Type 2 diabetes mellitus
- **E13.x**: Other specified diabetes mellitus
- **E14.x**: Unspecified diabetes mellitus (avoid if type is known)

# Important Notes

- Avoid using unspecified codes (E14) when the diabetes type is documented
- Fourth and fifth digit codes capture complications (retinopathy, nephropathy, neuropathy, circulatory)
- Document insulin use separately as a drug exposure, not implied by diagnosis code alone
```

---

### Category 5: Drugs (e.g., Antibiotics, Sedatives, Vasopressors)

**Characteristics:**
- Usually straightforward (one drug = one concept)
- May have formulation differences (IV vs PO)
- Dosing captured separately

**Template:**
```markdown
# Definition

[Drug name] is a [drug class] used for [indication]. Typical dosing: [range and route].

# Mapping Strategy

**Default concept:** [Drug name] (RxNorm [Code]) - Use for all [drug] exposures regardless of formulation

**Specific concepts** (if applicable):
- **[Drug name] Injection** (RxNorm [Code]): Intravenous formulation
- **[Drug name] Oral Product** (RxNorm [Code]): Oral formulation
```

**Example: Vancomycin**
```markdown
# Definition

Vancomycin is a glycopeptide antibiotic used for serious Gram-positive infections, particularly methicillin-resistant Staphylococcus aureus (MRSA). Typical dosing: 15-20 mg/kg IV every 8-12 hours.

# Mapping Strategy

**Default concept:** Vancomycin (RxNorm 11124) - Use for all vancomycin exposures regardless of formulation or route

**Specific concepts:**
- **Vancomycin Injection** (RxNorm 1190838): Intravenous formulation
- **Vancomycin Oral Product** (RxNorm 1190837): Oral formulation (used for Clostridioides difficile colitis)

# Important Notes

- Document route of administration separately (IV vs PO have different indications)
- Therapeutic drug monitoring (trough levels) should be captured as separate lab measurements (LOINC 4090-4)
```

---

### Category 6: Clinical Observation Scores (e.g., GCS, RASS, CAM-ICU)

**Characteristics:**
- Standardized scoring systems
- Often have total score + component scores
- Defined score ranges

**Template:**
```markdown
# Definition

[Score name] is a [type of assessment] scale [what it assesses] based on [components]. Total score range: **[min-max]** ([interpretation]).

# Mapping Strategy

**Default concept:** [Score name] total (LOINC [Code]) - Use for the composite score

**Component concepts** (recommended for granularity):
- **[Component 1]** (LOINC [Code]): Score [range]
- **[Component 2]** (LOINC [Code]): Score [range]

# Important Notes

- [Interpretation guidance]
- [Special considerations for scoring]
```

**Example: Glasgow Coma Scale**
```markdown
# Definition

Glasgow Coma Scale (GCS) is a neurological scale assessing level of consciousness based on eye, verbal, and motor responses. Total score range: **3-15** (lower score = worse neurological function).

# Mapping Strategy

**Default concept:** Glasgow coma score total (LOINC 9269-2) - Use for the composite score (3-15)

**Component concepts** (recommended for granularity):
- **Glasgow coma score eye opening** (LOINC 9267-6): Score 1-4
- **Glasgow coma score verbal** (LOINC 9270-0): Score 1-5
- **Glasgow coma score motor** (LOINC 9268-4): Score 1-6

# Important Notes

- Always map both the total score AND individual components when available (provides richer clinical data)
- For intubated patients, verbal component cannot be assessed; document as "Unable to assess" rather than assigning a score
- GCS ≤8 typically indicates severe impairment requiring airway protection
```

---

## Style and Formatting Guidelines

### Markdown Formatting

- Use `# Heading` for section titles (not `## Subheading`)
- Use `**bold**` for:
  - Units (e.g., **L/min**, **mmol/L**, **bpm**)
  - Concept names in the mapping list
  - Key clinical terms requiring emphasis
- Use `- bullet points` for lists (not numbered lists in most cases)
- Use backticks for code values: `LOINC 8867-4`

### Language and Tone

- **Active voice**: "Use this concept when..." (not "This concept should be used when...")
- **Present tense**: "Heart rate represents..." (not "Heart rate represented...")
- **Clear and direct**: Avoid unnecessary qualifiers ("very", "extremely", "clearly")
- **Clinical accuracy**: Use precise medical terminology
- **Data scientist friendly**: Explain clinical terms that may be unfamiliar

### Consistency

- Always use the format: `**[Concept name]** ([Vocabulary] [Code]):`
- Vocabulary abbreviations:
  - LOINC (not Loinc or loinc)
  - SNOMED (not SNOMED CT or snomed)
  - RxNorm (not rxnorm or RXNORM)
  - ICD10 (not ICD-10 or icd10)
- Units: Use standard abbreviations with spaces where appropriate:
  - L/min (not l/min or L/min.)
  - mmol/L (not mmol/l)
  - mg/dL (not mg/dl)
  - bpm (not BPM or beats/min)
  - cmH2O (not cm H2O or cmH20)

---

## Checklist for Writing Expert Comments

Before finalizing an expert comment, verify:

- [ ] **Definition section** includes clinical definition + units + normal values (if relevant)
- [ ] **Mapping Strategy** starts with general principle in one sentence
- [ ] **Default concept** is clearly identified with use case
- [ ] **Specific concepts** are listed with concise use case descriptions
- [ ] **Clinical Context section** is included only if truly necessary (complex concepts)
- [ ] **Important Notes section** is included only if there are clinical warnings or common pitfalls
- [ ] All concept names are **bolded**
- [ ] All units are **bolded**
- [ ] Vocabulary names are capitalized correctly (LOINC, SNOMED, RxNorm, ICD10)
- [ ] Language is clear, concise, and free of jargon
- [ ] Formatting follows the markdown conventions

---

## Common Pitfalls to Avoid

### ❌ Don't: Over-explain

**Bad example:**
> Heart rate is a vital sign that has been measured for centuries and is one of the most fundamental assessments in medicine. It reflects the cardiac cycle and can be influenced by many factors including autonomic tone, medications, fever, pain, and anxiety. The measurement has evolved over time from manual palpation to modern electronic monitoring.

**Why it's bad:** Too much background, not actionable for mapping decisions

**Good alternative:**
> Heart rate represents the number of heartbeats per unit of time, expressed in **beats per minute (bpm)**. Normal resting heart rate in adults ranges from 60-100 bpm.

---

### ❌ Don't: Assume clinical knowledge

**Bad example:**
> Use the LVOT VTI method for TTE-derived CO estimates.

**Why it's bad:** Assumes familiarity with abbreviations and clinical protocols

**Good alternative:**
> Use "Left ventricular Cardiac output by US.doppler" for Doppler ultrasound measurements through the left ventricular outflow tract (LVOT), typically during transthoracic echocardiography (TTE).

---

### ❌ Don't: Omit units

**Bad example:**
> Normal cardiac output: 4-8

**Why it's bad:** Units are essential for data scientists to validate their mappings

**Good alternative:**
> Normal cardiac output: 4-8 **L/min** in adults at rest

---

### ❌ Don't: List concepts without context

**Bad example:**
```markdown
**Specific concepts:**
- Heart rate by Pulse oximetry (LOINC 8889-8)
- Heart rate.beat-to-beat by EKG (LOINC 76282-3)
- Heart rate Intra arterial line by Invasive (LOINC 60978-4)
```

**Why it's bad:** Doesn't explain when to use each concept

**Good alternative:**
```markdown
**Specific concepts:**
- **Heart rate by Pulse oximetry** (LOINC 8889-8): Heart rate derived from photoplethysmography (pulse oximeter sensor)
- **Heart rate.beat-to-beat by EKG** (LOINC 76282-3): Heart rate captured via electrocardiography (ECG/telemetry)
- **Heart rate Intra arterial line by Invasive** (LOINC 60978-4): Heart rate measured via intra-arterial catheter (ICU/OR setting)
```

---

## Revision and Quality Control

Expert comments should be reviewed for:

1. **Clinical accuracy**: Definitions, normal values, and clinical context are correct
2. **Completeness**: All mapped concepts in the dictionary are addressed
3. **Clarity**: A data scientist without clinical training can understand the guidance
4. **Consistency**: Format and style match other comments in the dictionary
5. **Actionability**: Clear decision rules for when to use each concept

---

## Contact

For questions about these guidelines or specific concept mapping questions, contact:
- **Boris Delange** (boris.delange@univ-rennes.fr)
