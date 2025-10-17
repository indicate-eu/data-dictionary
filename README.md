# indicate: INDICATE Minimal Data Dictionary R Package

![Application Interface](man/figures/web_interface.png)

## Overview

The `indicate` R package provides an interactive Shiny application to explore the **INDICATE Minimal Data Dictionary**, a consensus-based collection of standardized clinical concepts designed to harmonize intensive care unit (ICU) data across Europe. The dictionary addresses semantic interoperability challenges in federated healthcare data infrastructures by providing explicit recommendations for terminology selection across diverse European ICU settings.

## Context

### The INDICATE Project

The INDICATE project, launched in December 2024 and funded by the European Union's Digital Europe Programme (grant 101167778), aims to establish a secure federated infrastructure for standardized ICU data across Europe. The project addresses critical challenges in collaborative research, AI model development, and data sharing for clinical decision-making and quality improvement.

### The Minimal Data Dictionary

The INDICATE Minimal Data Dictionary comprises **11,924 clinical concepts** organized into nine categories:

| Category | Number of Concepts | Description |
|----------|-------------------|-------------|
| Demographics and Encounters | 14 | Patient demographics and admissions (e.g., age, gender, dates) |
| Conditions | 230 | Diagnoses and medical conditions (e.g., ARDS, sepsis) |
| Clinical Observations | 21 | Non-numeric clinical assessments (e.g., Glasgow Coma Scale) |
| Vital Signs | 27 | Basic physiological measurements (e.g., heart rate) |
| Laboratory Measurements | 199 | Blood and urine tests (e.g., lactate, creatinine, sodium) |
| Microbiology | 50 | Culture results and pathogens (e.g., Pseudomonas aeruginosa) |
| Ventilation | 52 | Mechanical ventilation parameters (e.g., FiO₂, PEEP) |
| Drugs | 11,313 | Medications with dose and form (e.g., Norepinephrine 2 MG/ML Injection) |
| Procedures | 18 | Medical interventions (e.g., intubation, dialysis, ECMO) |

### Standard Terminologies

The dictionary uses internationally recognized standard terminologies:
- **SNOMED CT** for clinical concepts and ventilation parameters
- **LOINC** for laboratory measurements
- **RxNorm** for medications (Clinical Drug level)
- **ICD-10** for diagnoses
- **UCUM** for units of measure

### Clinical Use Cases

The dictionary was developed to support six clinical use cases:
1. **MIMIC-EU** - An Atlas of Anonymized Acute Care Cases
2. **Early Detection of Organ Failure**
3. **Virtual Digital Twin**
4. **Neonatal and Pediatric Sepsis Prediction**
5. **Quality Benchmarking Dashboards**
6. **Grand Rounds Workspace**

## Features

### Current Module: Dictionary Explorer

The Dictionary Explorer module provides:

- **General Concepts Overview**: Browse high-level clinical concepts organized by category and subcategory
- **Use Case Mapping**: See which use cases require each concept
- **Detailed Concept Information**: View complete details for each standardized terminology code including:
  - Vocabulary ID (SNOMED CT, LOINC, RxNorm, ICD-10)
  - Concept codes and OMOP Concept IDs
  - Preferred units with UCUM codes
  - Usage statistics from EHDEN network
  - Recommendations from clinical experts
- **External Integration**: Direct links to:
  - **ATHENA OHDSI** vocabulary browser for OMOP mapping
  - **FHIR Terminology Server** for FHIR-based transformations
- **Expert Comments**: Collaborative guidance from clinicians and data scientists
- **Interactive Filtering**: Search and filter concepts by category, subcategory, or use case
- **Keyboard Navigation**: Efficient browsing with keyboard shortcuts

### Future Modules

Planned modules include:
- **Semantic Alignment**: Tools to align user-imported concepts with the INDICATE dictionary
- **Dictionary Improvement**: Interface to propose additions and modifications to the dictionary

## Installation

```r
# Install the indicate package from GitLab
devtools::install_git("https://gitlab.com/ricdc/outils/indicate-data-dictionary.git")
```

## Usage

### Running the Application

To launch the INDICATE application:

```r
indicate::run_app()
```

The application will open in your default web browser.

### Usage Guide

#### Exploring General Concepts

1. The **General Concepts** table shows aggregated clinical concepts grouped by category and subcategory
2. Use the column filters to search for specific concepts or categories
3. The use case columns (UC1-UC6) indicate which use cases require each concept
4. Click on any row to see detailed concept information

#### Viewing Concept Details

When you select a general concept:
1. The **Concepts List** table displays all specific terminology codes associated with the concept
2. The **Comments** section shows expert guidance for using the concept
3. Click on any specific concept to view complete details in the **Selected Concept Details** panel
4. The "Recommended" column indicates the preferred concept when multiple options exist

#### Using External Links

The application provides direct links to:
- **OMOP Concept ID**: Links to ATHENA vocabulary browser for OMOP CDM mapping
- **FHIR Resource**: Links to FHIR Terminology Server for FHIR-based transformations

These links facilitate data transformation and ETL (Extract, Transform, Load) processes.

## Governance and Versioning

The INDICATE consortium has established a governance framework allowing members to propose modifications. All changes are tracked in version-controlled repositories to ensure:
- Transparency in dictionary evolution
- Accommodation of diverse requirements
- Preservation of semantic harmonization across the network

## Alignment with European Health Data Space (EHDS)

Future development includes alignment with **HealthDCAT-AP**, the European metadata profile for describing health data assets under the EHDS framework. This will:
- Make the dictionary easier to find, reference, and reuse
- Strengthen its role in enabling semantic interoperability
- Facilitate connections to federated infrastructures
- Ensure metadata consistency with FAIR principles

## License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)** - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

This work is funded by the European Union's Digital Europe Programme under grant 101167778.

The INDICATE consortium comprises partners from 12 European countries, with 15 data providers implementing a pan-European federated infrastructure.

## Contact

For questions or feedback about this package:

**Boris Delange**
Email: boris.delange@univ-rennes.fr

For information about the INDICATE project:
Visit: [INDICATE Project Website](https://indicate-europe.eu/)

## Contributing

Contributions to improve the package are welcome. Please contact the author for collaboration opportunities.

## Future Enhancements

Planned improvements include:
- **Semantic Alignment Module**: Tool to align user concepts with the dictionary
- **Dictionary Improvement Module**: Interface to propose additions and modifications
- **Extended Data Dictionary**: Additional clinical concepts
- **Enhanced semantic relationship mapping**
- **Integration with national and European health data catalogues**
- **Support for additional standard terminologies**
- **Improved visualization of concept relationships**
