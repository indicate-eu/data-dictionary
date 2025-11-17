# INDICATE Minimal Data Dictionary

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

The INDICATE Data Dictionary application provides a comprehensive suite of tools for working with standardized clinical concepts:

### 1. Dictionary Explorer

Browse and explore the INDICATE Minimal Data Dictionary:

- **Four-Panel Quadrant Layout**: Simultaneous view of general concepts, mappings, and detailed information
- **General Concepts Overview**: Browse 11,924 clinical concepts organized by category and subcategory
- **Use Case Mapping**: See which of the 6 use cases require each concept
- **Detailed Concept Information**: View complete details for each standardized terminology code:
  - Vocabulary ID (SNOMED CT, LOINC, RxNorm, ICD-10)
  - Concept codes and OMOP Concept IDs
  - Preferred units with UCUM codes
  - Usage statistics from EHDEN network
  - Expert recommendations
- **External Integration**: Direct links to:
  - **ATHENA OHDSI** vocabulary browser for OMOP mapping
  - **FHIR Terminology Server** for FHIR-based transformations
- **Expert Comments**: Collaborative guidance from clinicians and data scientists
- **Interactive Filtering**: Search and filter concepts by category, subcategory, or use case
- **Keyboard Navigation**: Efficient browsing with arrow keys and keyboard shortcuts
- **Resizable Panels**: Customize your workspace with draggable panel splitters

### 2. Concept Mapping

Align your own clinical concepts with the INDICATE dictionary:

- **Custom Concept Management**: Create and organize your own clinical concepts
- **Folder-Based Organization**: Hierarchical structure for organizing concepts by project or domain
- **Semantic Alignment**: Map custom concepts to INDICATE dictionary concepts
- **ATHENA Integration**: Search ATHENA vocabulary for concept suggestions
- **Concept Descendants**: Automatically find child concepts (e.g., all types of a medication)
- **Alignment History**: Track when and how concepts were mapped
- **Multi-Step Wizards**: Guided forms for creating alignments with validation

### 3. Use Case Management

Define and manage clinical use cases:

- **Use Case Definitions**: Create and edit use case metadata (name, description, objectives)
- **Concept Assignment**: Assign INDICATE concepts to specific use cases
- **Requirement Tracking**: Mark which concepts are required vs. optional
- **Coverage Analysis**: View which concepts are covered by each use case
- **Breadcrumb Navigation**: Intuitive hierarchical navigation

### 4. Settings

Configure the application to your needs:

- **Database Settings**: Configure data storage and connection parameters
- **UI Preferences**: Customize interface behavior and appearance
- **Data Export/Import**: Export your custom concepts and mappings for sharing
- **Development Mode**: Enable advanced features for debugging

### 5. Development Tools

Database inspection and debugging (development mode):

- **Table Browser**: View all database tables and their schemas
- **SQL Console**: Execute custom SQL queries
- **Data Inspector**: Examine table contents and relationships
- **Query Performance**: Analyze query execution

### Future Enhancements

Planned improvements include:
- **Dictionary Improvement Module**: Interface to propose additions and modifications to the INDICATE dictionary
- **Extended Data Dictionary**: Additional clinical concepts beyond the current scope
- **Enhanced Visualization**: Concept relationship mapping and dependency graphs
- **Integration with National Catalogues**: Connect to European health data catalogues
- **Support for Additional Terminologies**: Beyond SNOMED CT, LOINC, RxNorm, and ICD-10
- **Collaborative Features**: Multi-user editing and concept review workflows

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

### First Connection

#### Login

When you first launch the application, you will see the login screen.

<p align="center">
  <img src="man/figures/first_login.png" alt="Login Screen" width="300"/>
</p>

**Default credentials**:
- **Username**: `admin`
- **Password**: `admin`

**Important**: For security reasons, you should change the default password immediately after your first login:
1. Click the **Settings icon** (cog) in the top-right corner
2. Navigate to **Users**
3. Update the admin password

**Anonymous access**:
- You can also log in as **Anonymous** for read-only access
- Anonymous users can browse the dictionary but cannot make modifications
- No editing, creating, or deleting of concepts is allowed in anonymous mode

#### Setting up ATHENA vocabularies

After logging in, you need to import ATHENA vocabulary data to enable full functionality.

**Step 1: Download vocabularies from ATHENA**

![ATHENA Download](man/figures/athena_download.png)

1. Go to [https://athena.ohdsi.org](https://athena.ohdsi.org)
2. Select the following vocabularies:
   - **LOINC**
   - **SNOMED**
   - **RxNorm**
   - **RxNorm Extension**
   - **ATC**
   - **ICD10**
3. Click **Download Vocabularies**
4. Extract the downloaded ZIP file to a folder on your computer

**Step 2: Import vocabularies into the application**

![ATHENA Import Settings](man/figures/athena_import.png)

1. Click the **Settings icon** (cog) in the top-right corner
2. Navigate to **General Settings**
3. In the **OHDSI Vocabularies** section, click **Browse**
4. Select the folder containing the extracted CSV files from ATHENA
5. The application will create a DuckDB database from the CSV files
   - This database will be saved in the `app_folder` directory (specified with the `app_folder` argument of `run_app()`, or your home directory by default)
   - Future connections will load concepts faster from this database
6. Wait for the import to complete
   - The application will process all CSV files
   - A progress indicator shows the import status
   - Once complete, all features will be available

### Usage Guide

#### 1. Dictionary Explorer

The Dictionary Explorer provides a four-panel layout for browsing the INDICATE Minimal Data Dictionary.

![Dictionary Explorer Interface](man/figures/dictionary_explorer.png)

**Exploring General Concepts**:
1. Navigate to the **Dictionary Explorer** tab
2. The top-left panel shows general concepts grouped by category and subcategory
3. Use column filters to search for specific concepts (e.g., "lactate", "sepsis")
4. The use case columns (UC1-UC6) show which use cases require each concept
5. Click any row to load detailed information

![Concept Details View](man/figures/concept_details.png)

**Viewing General Concept Details**:
1. After selecting a general concept, the bottom-left panel shows all terminology mappings
2. Each row represents a specific code in a standard vocabulary (SNOMED, LOINC, RxNorm, ICD-10)
3. The "Recommended" column (✓) indicates the preferred mapping
4. Click on a mapping to see full details in the right panels

<p align="center">
  <img src="man/figures/concept_relationships.png" alt="Concept Relationships" width="750"/>
</p>

**Exploring Concept Relationships**:
- View the hierarchical structure of concepts with the relationships tree
- See parent and child concepts in the hierarchy
- Understand relationship types (Is a, Has ingredient, Subsumes, etc.)

**Using External Links**:
- **OMOP Concept ID**: Click to open ATHENA vocabulary browser
- **FHIR Resource**: Click to open FHIR Terminology Server
- These facilitate ETL processes and data transformation

#### 2. Concept Mapping

The Concept Mapping module allows you to align your custom concepts with the INDICATE dictionary.

![Concept Mapping Overview](man/figures/concept_mapping.png)

![Add Alignment Interface](man/figures/add_alignment_interface.png)

**Aligning to Dictionary**:

![Alignment Wizard](man/figures/alignment_wizard.png)

**Aligning to Dictionary**:
1. Select a custom concept from your list
2. Click **Add Alignment** to map it to the INDICATE dictionary
3. **Page 1**: Select the general concept from the dictionary
4. **Page 2**: Choose specific mappings (you can select multiple)
   - Use "Add descendants" to include child concepts automatically
5. Save the alignment

#### 3. Use Case Management

Define and manage clinical use cases with assigned concepts.

![Use Cases Overview](man/figures/use_cases.png)

**Defining Use Cases**:
1. Navigate to the **Use Cases** tab
2. Click **Add Use Case** to create a new use case
3. Enter name, description, and short name
4. Save the use case

**Assigning Concepts**:
1. Select a use case from the list
2. View assigned concepts in the table
3. Add or remove concept assignments as needed
4. Mark concepts as required or optional

#### 4. Settings

**Configuring the Application**:
1. Navigate to the **Settings** tab
2. Adjust database and UI preferences
3. Export your custom concepts and mappings
4. Import previously saved configurations

#### 5. Development Tools

![Development Tools](man/figures/dev_tools.png)

**Inspecting the Database** (development mode only):
1. Navigate to the **Dev Tools** tab
2. Browse tables and view schemas
3. Execute SQL queries to inspect data
4. Debug data issues

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
