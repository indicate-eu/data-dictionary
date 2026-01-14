# CLAUDE.md - INDICATE Data Dictionary Project Guidelines

This file provides development guidelines for Claude Code when working on the INDICATE Data Dictionary Shiny application.

## Project Overview

**INDICATE Data Dictionary** is an R Shiny package that provides an interactive web application to explore the INDICATE Minimal Data Dictionary - a consensus-based collection of 11,924 standardized clinical concepts designed to harmonize intensive care unit (ICU) data across Europe.

**Technologies**: R (>= 4.0.0), Shiny (>= 1.7.0), DT, dplyr, readxl, shiny.i18n, shiny.router, DuckDB, jQuery, DataTables

**Author**: Boris Delange (boris.delange@univ-rennes.fr)

---

## Code Organization

### Directory Structure

```
indicate-data-dictionary/
├── R/                              # R source code
│   ├── run_app.R                  # Application entry point
│   ├── app_ui.R                   # Main UI function
│   ├── app_server.R               # Main server logic
│   ├── mod_dictionary_explorer.R  # Dictionary explorer module
│   ├── mod_concept_mapping.R      # Concept mapping module
│   ├── mod_projects.R             # Projects management module
│   ├── mod_general_settings.R     # General settings module
│   ├── mod_users.R                # User management module
│   ├── mod_dev_tools.R            # Development tools module
│   ├── mod_improvements.R         # Dictionary improvements module
│   ├── mod_login.R                # Login/authentication module
│   ├── mod_page_header.R          # Page header with navigation
│   ├── fct_concept_mapping.R      # Concept mapping and import/export functions
│   ├── fct_config.R               # Configuration and environment detection
│   ├── fct_database.R             # Database operations
│   ├── fct_datatable.R            # DataTable helper functions
│   ├── fct_duckdb.R               # DuckDB integration
│   ├── fct_history.R              # History tracking functions
│   ├── fct_projects.R             # Projects helper functions
│   ├── fct_shiny_helpers.R        # Shiny helper functions (R code execution, button visibility)
│   ├── fct_statistical_analysis.R # Statistical analysis functions
│   ├── fct_statistics_display.R   # Statistics display functions
│   ├── fct_url_builders.R         # URL builders (ATHENA, FHIR)
│   ├── fct_users.R                # User management functions
│   ├── fct_vocabularies.R         # OHDSI vocabulary functions
│   ├── utils_csv.R                # CSV data loading utilities
│   ├── utils_datatable_callbacks.R # DataTable callback utilities
│   ├── utils_datatables.R         # DataTable configuration utilities
│   ├── utils_server.R             # Server-side utilities
│   └── utils_ui.R                 # UI helper functions
├── inst/
│   ├── extdata/                   # Data files
│   │   └── data_dictionary/       # Data dictionary CSV files
│   │       ├── general_concepts_en.csv           # General concepts (English)
│   │       ├── general_concepts_fr.csv           # General concepts (French)
│   │       ├── general_concepts_details.csv      # Concept mappings to OMOP
│   │       ├── general_concepts_details_statistics.csv  # EHDEN usage statistics
│   │       ├── general_concepts_details_history.csv     # Edit history
│   │       ├── general_concepts_history.csv      # General concepts history
│   │       ├── general_concepts_projects.csv     # Project assignments
│   │       ├── general_concepts_stats.csv        # Aggregated statistics
│   │       ├── projects.csv                      # Project definitions
│   │       ├── custom_concepts.csv               # User-defined concepts
│   │       └── unit_conversions.csv              # Unit conversion mappings
│   ├── scripts/                   # Utility scripts
│   │   └── enrich_concept_mappings.R  # Data enrichment script
│   ├── translations/              # Internationalization files
│   │   ├── translation_en.csv     # English translations
│   │   └── translation_fr.csv     # French translations
│   └── www/                       # Web assets (CSS, JS, images)
│       ├── style.css              # Main stylesheet
│       ├── clipboard.js           # Clipboard copy functionality
│       ├── comments_scroll_sync.js # Comments scroll synchronization
│       ├── copy_menu.js           # Copy menu interactions
│       ├── dt_callback.js         # DataTable callbacks
│       ├── evaluate_mappings.js   # Evaluate mappings interactions
│       ├── folder_display.js      # Folder tree display
│       ├── keyboard_nav.js        # Keyboard navigation
│       ├── login_handler.js       # Login form interactions
│       ├── prevent_doubleclick_selection.js # Prevent text selection
│       ├── resizable_splitter.js  # Panel resizing
│       ├── selectize_modal_fix.js # Selectize modal z-index fix
│       ├── settings_menu.js       # Settings UI
│       ├── view_details.js        # Detail view management
│       ├── logo.png               # INDICATE logo
│       └── favicon.png            # Application favicon
├── man/                           # R documentation
├── tests/                         # Test files
├── DESCRIPTION                    # Package metadata
└── NAMESPACE                      # R namespace definitions
```

### Module Pattern

This project follows the **Shiny module pattern**:

- **Module UI**: `mod_<name>_ui(id, i18n)` - Creates namespaced UI elements with i18n support
- **Module Server**: `mod_<name>_server(id, data, config, ...)` - Implements server logic with namespace

**Example**:
```r
# UI function - receives i18n for translations
mod_dictionary_explorer_ui <- function(id, i18n) {
  ns <- NS(id)
  tagList(
    tags$h3(i18n$t("dictionary_explorer")),
    # Use ns() to wrap all input/output IDs
  )
}

# Server function - receives data and config (which contains i18n)
mod_dictionary_explorer_server <- function(id, data, config) {
  moduleServer(id, function(input, output, session) {
    i18n <- config$i18n
    # Module logic here
  })
}
```

### Code Structure and Outlines

**IMPORTANT: Always include structural outlines at the beginning of complex files**

For module files and complex R scripts, include a comprehensive outline as comments at the very beginning of the file. This outline serves as a table of contents and helps navigate large codebases.

**Outline Format**:
- Use clear section headers with `====` underlines
- Use hierarchical numbering for subsections
- Include brief descriptions of what each section does
- Keep outlines concise but informative

**Example from `mod_dictionary_explorer.R`**:

```r
# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Dictionary Explorer interface with two main views:
# - General Concepts Page: Browse and manage general concepts
# - Mapped Concepts Page: View and edit OMOP concept mappings
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Breadcrumb & Action Buttons Container
#      ### Content Area (Tables & Containers)
#   ## UI - Modals
#      ### Modal - Concept Details Viewer
#      ### Modal - Add New General Concept
#      ### Modal - Hierarchy Graph Fullscreen
#      ### Modal - Add Mapping to General Concept (OMOP Search)
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Selection State
#      ### Edit Mode State
#      ### Data Management
#      ### Cascade Triggers
#
#   ## 2) Server - Navigation & Events
#      ### Initialize Data
#      ### Primary State Observers
#      ### Cascade Observers
#      ### Button Visibility Management
#
#   ## 3) Server - General Concepts Page
#      ### a) General Concepts Table (Top-Left Panel)
#         #### Table Rendering
#         #### Category Filtering
#         #### Row Selection
#         #### Edit Mode Actions
#      ### b) Add General Concept Modal
#         #### Modal Handlers
#         #### Form Validation
#         #### Data Persistence
#
#   ## 4) Server - General Concept Detail Page
#      ### a) Concept Mappings Table (Bottom-Left Panel)
#         #### Table Rendering
#         #### Row Selection
#         #### Edit Actions (Toggle Recommended, Delete)
#      ### b) Add Mapping Modal (OMOP Search)
#         #### OMOP Concepts Table
#         #### Concept Details Display
#         #### Descendants Table
#         #### Add Selected Concept
#      ### c) Selected Mapping Details (Top-Right Panel)
#         #### Mapping Information Display
#         #### Related Concepts Graph
#         #### Hierarchy Graph
#      ### d) Comments Panel (Bottom-Right Panel)
#         #### Comments Display
#         #### Comments Editing

# Load required packages
library(shiny)
library(DT)
# ... rest of code
```

**Example from `mod_use_cases.R`**:

```r
# MODULE STRUCTURE OVERVIEW ====
#
# This module manages use cases and their associated general concepts
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Breadcrumb Navigation
#      ### Use Cases Table (when no use case selected)
#      ### Use Case Details (when use case selected)
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Selection State
#      ### Data Management
#      ### Triggers
#
#   ## 2) Server - Navigation
#      ### Breadcrumb Updates
#      ### View Switching
#
#   ## 3) Server - Use Cases List View
#      ### Table Rendering
#      ### Row Selection
#
#   ## 4) Server - Use Case Details View
#      ### Header Information
#      ### Assigned Concepts Table
#      ### Required Concepts Display

# Load required packages
library(shiny)
# ... rest of code
```

**Benefits of Outlines**:
- Quick navigation to specific functionality
- Understanding code structure before diving into details
- Easier code reviews and maintenance
- Clear documentation of architecture
- Helps identify missing sections or inconsistencies

**When to Use Outlines**:
- ✅ Module files (`mod_*.R`) - always include
- ✅ Complex utility files with multiple related functions
- ✅ Files longer than 500 lines
- ❌ Simple helper function files with 2-3 functions
- ❌ Configuration files

### Application Modules

**Core Modules**:

1. **`mod_dictionary_explorer.R`**:
   - Browse INDICATE dictionary concepts
   - Four-panel quadrant layout with resizable splitters
   - General concepts table with category/subcategory hierarchy
   - Concept mappings to OMOP vocabularies (SNOMED, LOINC, RxNorm, ICD-10)
   - Edit mode for modifying mappings and statistics
   - Links to ATHENA and FHIR resources
   - Comments display with markdown rendering
   - Concept set toggles (is_excluded, include_descendants, include_mapped)
   - Fullscreen modal for concept set visualization

2. **`mod_concept_mapping.R`**:
   - Create and manage alignments (collections of source concepts)
   - Align source concepts to dictionary general concepts
   - Four tabs: Summary, All Mappings, Import Mappings, Evaluate Mappings
   - Import mappings from CSV/Excel and INDICATE format
   - Export to Usagi, STCM, and ATLAS JSON formats
   - Coverage display with percentage-based color coding
   - Projects compatibility view
   - Multi-page modal forms for alignment creation
   - Comments system for mapping evaluations

3. **`mod_projects.R`**:
   - Manage project definitions
   - Assign general concepts to projects
   - View project requirements and coverage
   - Breadcrumb navigation

4. **`mod_general_settings.R`**:
   - Configure application behavior
   - OHDSI vocabulary folder selection
   - Language preferences
   - Data export/import

5. **`mod_users.R`**:
   - User management (admin only)
   - Create, edit, delete users
   - Role assignment

6. **`mod_dev_tools.R`**:
   - Data quality metrics (missing comments, non-standard concepts)
   - R console for querying OHDSI vocabularies
   - Debug data issues

7. **`mod_improvements.R`**:
   - Propose dictionary improvements
   - Submit new concepts
   - Track improvement status

8. **`mod_login.R`**:
   - User authentication
   - Login form handling

9. **`mod_page_header.R`**:
   - Application header with navigation tabs
   - User menu and settings access

### Function Libraries

**`fct_vocabularies.R`**:
- `search_omop_concepts()`: Search OHDSI vocabulary concepts
- `get_concept_details()`: Fetch concept details with relationships
- `get_concept_descendants()`: Fetch concept hierarchy
- `get_concept_ancestors()`: Fetch concept ancestors
- `get_related_concepts()`: Get related concepts by relationship type
- `get_concept_descendants_count()`: Count descendant concepts
- `get_concept_mapped_count()`: Count mapped concepts
- `resolve_concept_set()`: Resolve concept set with descendants/mapped inclusion

**`fct_concept_mapping.R`**:
- `import_indicate_alignment()`: Import alignments from INDICATE format
- `export_usagi_format()`: Export alignments to Usagi format
- `export_stcm_format()`: Export alignments to STCM format
- `export_atlas_json()`: Export concept sets to ATLAS JSON format

**`fct_url_builders.R`**:
- `build_athena_url()`: Generate ATHENA OHDSI links
- `build_fhir_url()`: Generate FHIR Terminology Server links

**`fct_database.R`**:
- `save_csv_data()`: Save data to CSV files
- `load_csv_data()`: Load data from CSV files

**`fct_duckdb.R`**:
- `initialize_duckdb()`: Set up in-memory database for vocabularies
- `load_vocabulary_tables()`: Load OHDSI vocabulary CSV files
- `create_indexes()`: Optimize queries

**`fct_history.R`**:
- `log_action()`: Record user actions to history files
- `get_history()`: Retrieve action history

**`fct_config.R`**:
- `is_container()`: Detect Docker/container environment
- `get_vocab_path()`: Get vocabulary folder path

**`fct_datatable.R`**:
- `create_datatable()`: Create standardized DataTables
- `format_datatable_columns()`: Apply consistent formatting
- `prepare_concept_set_display()`: Prepare concept set data with HTML toggles
- `get_concept_set_datatable_columns()`: Column configuration for concept set DataTables

**`fct_shiny_helpers.R`**:
- `execute_r_code_safely()`: Execute R code with error handling
- `get_button_visibility()`: Determine button visibility based on user role and view state

**`fct_statistics_display.R`**:
- `render_statistics_summary()`: Display EHDEN network statistics
- `format_statistics_values()`: Format numeric values for display

**`fct_projects.R`**:
- Helper functions for project management

**`utils_csv.R`**:
- `load_csv_data()`: Load CSV data with type handling
- `get_comment_for_language()`: Extract comment text for a general concept in current language

---

## Naming Conventions

### R Code

**Functions**:
- `run_app()` - Exported entry point
- `mod_*_ui()`, `mod_*_server()` - Module pattern
- `get_*()`, `load_*()` - Data accessors/loaders
- `build_*()` - Constructors (URLs, HTML elements)
- `create_*()` - Factory functions

**Variables**:
- Use **snake_case** for all R variables and function names
- Descriptive names: `aggregated_data`, `filtered_details`, `selected_category_row`
- Reactive values: Clearly indicate reactivity context

**Files**:
- `mod_<name>.R` - Module files
- `utils_<purpose>.R` - Utility groups (config, data, helpers)
- `app_<component>.R` - Main app components (ui, server)

### JavaScript

**Functions**:
- `create_keyboard_nav()` - Factory functions
- `build_fhir_url()` - URL builders
- `create_link()` - Element constructors
- `initQuadrantSplitter()` - Initialize four-panel layout
- `toggleRecommended()` - Filter recommended concepts

**Variables**: Use **camelCase**

**Event Handlers**: Use descriptive names ending in `Handler` (e.g., `navigationHandler`, `tabHandler`)

### CSS

**Classes**:
- `.header`, `.header-logo`, `.header-title` - Hierarchical BEM-like naming
- `.main-panel`, `.summary-container` - Purpose-based
- `.section-header`, `.table-container` - Component naming

---

## Data Handling

### Data Storage Architecture

The application uses a **dual data storage approach**:

1. **CSV Files** (`inst/extdata/data_dictionary/`): Structured data for application use
2. **DuckDB** (runtime): In-memory database for fast queries and joins

### CSV Data Files

The application uses the following CSV files:

- **`general_concepts_en.csv`**: Core concept definitions in English (category, subcategory, general_concept_name, comments)
- **`general_concepts_fr.csv`**: Core concept definitions in French
- **`general_concepts_details.csv`**: Mappings between general concepts and OMOP vocabularies (SNOMED, LOINC, RxNorm, ICD-10)
- **`general_concepts_details_statistics.csv`**: EHDEN network usage statistics (loinc_rank, ehden_rows_count, ehden_num_data_sources)
- **`general_concepts_details_history.csv`**: Edit history for concept mappings
- **`general_concepts_history.csv`**: Edit history for general concepts
- **`general_concepts_projects.csv`**: Which projects require which general concepts
- **`general_concepts_stats.csv`**: Aggregated statistics for general concepts
- **`projects.csv`**: Project definitions (id, name, description, short_name)
- **`custom_concepts.csv`**: User-defined source concepts for alignments
- **`unit_conversions.csv`**: Unit measurement mappings

### Data Loading

Load CSV data with explicit column types when needed:

```r
col_types <- cols(
  general_concept_id = col_integer(),
  category = col_character(),
  omop_concept_id = col_integer(),
  ...
)
data <- read_csv(file_path, col_types = col_types)
```

### Data Transformation Rules

1. **Boolean Conversion**: "X" markers → TRUE, empty → FALSE
2. **Factor Variables**: Use for categorical columns (category, subcategory, vocabulary_id)
3. **NA Handling**: Preserve NA values during import, display as "/" in UI
4. **Source Attribution**: Keep `source_sheet` column for tracking data origin

### Column Naming

**General Concepts** (`general_concepts_en.csv`, `general_concepts_fr.csv`):
- `general_concept_id`: Unique identifier
- `category`, `subcategory`, `general_concept_name`: Concept hierarchy
- `comments`: Expert guidance text (markdown format)

**Concept Mappings** (`general_concepts_details.csv`):
- `general_concept_id`: Link to general concept
- `vocabulary_id`: Standard terminology (SNOMED, LOINC, RxNorm, ICD10CM)
- `concept_code`: Code in the vocabulary
- `concept_name`: Display name
- `omop_concept_id`: OMOP CDM concept ID
- `omop_unit_concept_id`: Unit concept ID (for measurements)
- `standard_concept`: From OHDSI vocabulary (S=Standard, C=Classification, NULL=Non-standard)
- `is_excluded`: Boolean for concept set exclusion
- `include_descendants`: Boolean to include descendant concepts in concept set
- `include_mapped`: Boolean to include mapped concepts in concept set

**Concept Statistics** (`general_concepts_details_statistics.csv`):
- `omop_concept_id`: Link to concept mapping
- `loinc_rank`: LOINC usage ranking
- `ehden_rows_count`: Number of rows in EHDEN network
- `ehden_num_data_sources`: Number of data sources using this concept

**Project Assignments** (`general_concepts_projects.csv`):
- `general_concept_id`: Link to general concept
- `project_id`: Link to project
- `is_required`: Boolean for requirement status

**Custom Concepts** (`custom_concepts.csv`):
- `custom_concept_id`: Unique identifier
- `alignment_id`: Link to alignment
- `source_concept_name`: User-defined source concept name
- `description`: Concept description
- `general_concept_id`: Link to dictionary general concept (if aligned)
- `created_at`, `updated_at`: Timestamps

### Expert Comments for General Concepts

**IMPORTANT**: When asked to create or modify expert comments for general concepts:

1. **ALWAYS read and follow the guidelines in `comments_guidelines.md`** located at the project root
2. **DO NOT modify `general_concepts.csv`** directly
3. **Return the comment as markdown text in the chat** so the user can review and manually add it to the database

The `comment` field in `general_concepts.csv` contains expert guidance to help data scientists and clinicians choose the correct concept alignment.

**Before writing any expert comment**, consult `comments_guidelines.md` for:
- Complete template structure with required and optional sections
- Section-by-section writing guidelines
- Examples by concept category (vital signs, lab values, ventilation parameters, ICD-10 conditions, drugs, clinical scores)
- Standard LOINC pre-coordination explanation text
- Style and formatting rules
- Common pitfalls to avoid

---

## Reactive Programming Patterns

### Key Reactive Values

```r
# Aggregated summary data
aggregated_data <- reactive({
  # Group and summarize data
})

# Selected row tracking
selected_category_row <- reactive({
  req(input$summary_table_rows_selected)
  # Return selected row data
})

# Filtered details based on selection
filtered_details <- reactive({
  req(selected_category_row())
  # Filter data based on selection
})
```

### Best Practices

**CRITICAL SHINY REACTIVITY RULES**

These rules MUST be followed throughout the application:

#### 1. Observer Naming and Usage

**ALWAYS use `observe_event()` (with underscore), NEVER `observeEvent()` or `observe()`**

❌ **Avoid**:
```r
observeEvent(input$button, { ... })  # Wrong function name
observe({ ... })                      # Wrong - not explicit enough
```

✅ **Prefer**:
```r
observe_event(input$button, {
  # Handler code
}, ignoreNULL = FALSE, ignoreInit = FALSE)
```

**Key parameters for `observe_event()`**:
- `ignoreNULL = FALSE`: Execute even when reactive value is NULL (important for initial state)
- `ignoreInit = FALSE`: Execute on initialization (important for setting up initial UI state)

#### 2. Error Handling in Observers

**NEVER add `tryCatch()` inside `observe_event()` - it's already handled by the wrapper**

The application uses a custom `observe_event()` wrapper (defined in `utils_error_handling.R`) that automatically logs errors.

❌ **Avoid**:
```r
observe_event(input$button, {
  tryCatch({
    # Code here
  }, error = function(e) {
    log_error(e)
  })
})
```

✅ **Prefer**:
```r
observe_event(input$button, {
  # Code here - errors are automatically logged
})
```

#### 3. No Shiny Package Prefix

**NEVER use `shiny::` prefix - Shiny is imported at application start**

❌ **Avoid**:
```r
shiny::observeEvent(...)
shiny::reactive(...)
shiny::updateTextInput(...)
```

✅ **Prefer**:
```r
observe_event(...)
reactive(...)
updateTextInput(...)
```

#### 4. No Nested Observers

**NEVER nest `observe_event()` inside another `observe_event()`**

This creates complex dependencies and makes debugging impossible.

❌ **Avoid**:
```r
observe_event(input$button1, {
  observe_event(input$button2, {
    # Nested observer
  })
})
```

✅ **Prefer**:
```r
# Use separate observers
observe_event(input$button1, {
  # Handler 1
})

observe_event(input$button2, {
  # Handler 2
})

# Or use a reactive value to coordinate
observe_event(input$button1, {
  trigger(trigger() + 1)
})

observe_event(trigger(), {
  # Responds to trigger changes
})
```

#### 5. Output Rendering Must Be Inside observe_event

**NEVER create standalone `output$...` assignments - always wrap in `observe_event()`**

This ensures outputs respond to specific triggers and prevents unnecessary re-rendering.

❌ **Avoid**:
```r
output$my_table <- DT::renderDT({
  # Direct output assignment
  data()
})
```

✅ **Prefer**:
```r
observe_event(table_trigger(), {
  output$my_table <- DT::renderDT({
    data()
  })
}, ignoreInit = FALSE)
```

#### 6. Validation Pattern

**Use `if()... return()` instead of `req()` for validation**

This provides explicit control flow and is easier to debug.

❌ **Avoid**:
```r
observe_event(input$button, {
  req(input$value)
  req(data())
  # Process data
})
```

✅ **Prefer**:
```r
observe_event(input$button, {
  if (is.null(input$value)) return()
  if (is.null(data())) return()

  # Process data
})
```

#### 7. UI Location

**Place ALL static UI elements in `mod_*_ui()`, NOT in server with `renderUI()`**

Only use `uiOutput()`/`renderUI()` when content truly changes dynamically based on data.

❌ **Avoid**:
```r
# In UI
uiOutput(ns("static_buttons"))

# In server
output$static_buttons <- renderUI({
  tagList(
    actionButton(ns("btn1"), "Button 1"),
    actionButton(ns("btn2"), "Button 2")
  )
})
```

✅ **Prefer**:
```r
# In UI - all static elements
tags$div(
  id = ns("static_buttons"),
  actionButton(ns("btn1"), "Button 1"),
  actionButton(ns("btn2"), "Button 2")
)

# In server - only control visibility
observe_event(some_condition(), {
  if (some_condition()) {
    shinyjs::show("static_buttons")
  } else {
    shinyjs::hide("static_buttons")
  }
})
```

**Benefits**: Faster rendering, better performance, elements available in DOM immediately for JavaScript, easier debugging.

#### 8. Cascade Reactivity Pattern

**Use trigger-based cascade pattern to avoid multiplying observers for the same events**

Instead of having multiple observers watching the same reactive value, use intermediate triggers that cascade changes.

❌ **Avoid**:
```r
# Multiple observers watching same input
observe_event(input$mode, {
  update_ui_element_1()
})

observe_event(input$mode, {
  update_ui_element_2()
})

observe_event(input$mode, {
  update_ui_element_3()
})
```

✅ **Prefer**:
```r
# Primary observer updates trigger
observe_event(input$mode, {
  mode_trigger(mode_trigger() + 1)
}, ignoreInit = TRUE)

# Cascade observer updates multiple dependent triggers
observe_event(mode_trigger(), {
  ui_element_1_trigger(ui_element_1_trigger() + 1)
  ui_element_2_trigger(ui_element_2_trigger() + 1)
  ui_element_3_trigger(ui_element_3_trigger() + 1)
}, ignoreInit = TRUE)

# Individual observers respond to their triggers
observe_event(ui_element_1_trigger(), {
  update_ui_element_1()
}, ignoreInit = FALSE)

observe_event(ui_element_2_trigger(), {
  update_ui_element_2()
}, ignoreInit = FALSE)

observe_event(ui_element_3_trigger(), {
  update_ui_element_3()
}, ignoreInit = FALSE)
```

**Benefits**:
- Centralized state management
- Easier to track dependency chains
- Prevents redundant observer execution
- Clear separation between state changes and UI updates

**Example from Dictionary Explorer**:
```r
# When edit mode changes, update a single trigger
observe_event(general_concepts_edit_mode(), {
  general_concepts_edit_mode_trigger(general_concepts_edit_mode_trigger() + 1)
}, ignoreInit = TRUE)

# Cascade: edit mode trigger fires multiple UI triggers
observe_event(general_concepts_edit_mode_trigger(), {
  breadcrumb_trigger(breadcrumb_trigger() + 1)
  general_concepts_table_trigger(general_concepts_table_trigger() + 1)
}, ignoreInit = TRUE)

# Each UI element responds to its own trigger
observe_event(breadcrumb_trigger(), {
  output$breadcrumb <- renderUI({ ... })
}, ignoreInit = FALSE)

observe_event(general_concepts_table_trigger(), {
  output$general_concepts_table <- DT::renderDT({ ... })
}, ignoreInit = FALSE)
```

#### Summary Checklist

Before submitting code, verify:

- [ ] All observers use `observe_event()` (with underscore)
- [ ] No `tryCatch()` inside `observe_event()`
- [ ] No `shiny::` prefixes anywhere
- [ ] No nested `observe_event()` blocks
- [ ] All `output$...` assignments are inside `observe_event()`
- [ ] Validation uses `if()... return()` instead of `req()`
- [ ] Static UI elements are in `mod_*_ui()`, not `renderUI()`
- [ ] Cascade reactivity pattern is used for complex state changes

---

## UI Development

### Application Architecture

The application uses **`shiny.router`** for client-side routing with a multi-module interface:

**Navigation System**:
- Uses `shiny.router::router_ui()` and `shiny.router::router_server()` for routing
- Routes defined in `app_ui.R` with `route()` functions
- Client-side navigation (no page reload on tab change)

**Available Routes**:
1. **`/`** (root): Dictionary Explorer - Browse and search the INDICATE dictionary
2. **`/mapping`**: Concept Mapping - Align user concepts with dictionary concepts
3. **`/projects`**: Projects - Manage projects and concept assignments
4. **`/improvements`**: Improvements - Propose dictionary enhancements
5. **`/general-settings`**: General Settings - Configure application behavior
6. **`/users`**: Users - User management (admin only)
7. **`/dev-tools`**: Dev Tools - Database inspection and debugging (development mode)

**Module Loading**:
- All module UI elements are loaded at application start (lightweight HTML)
- All module server functions are initialized after user authentication
- Data (CSV, DuckDB vocabularies) loads progressively after login

### Using shiny.router

**Route Definition** (in `app_ui.R`):
```r
router_ui(
  route("/", create_page_container(mod_dictionary_explorer_ui("dictionary_explorer"))),
  route("projects", create_page_container(mod_projects_ui("projects"))),
  route("mapping", create_page_container(mod_concept_mapping_ui("concept_mapping"))),
  # ... other routes
)
```

**Route Initialization** (in `app_server.R`):
```r
# Initialize router - REQUIRED at the top of app_server
shiny.router::router_server(root_page = "/")
```

**Navigation**:
- Use `shiny.router::change_page("/route-name")` to programmatically navigate
- Links: Use `<a href="#!/route-name">Link Text</a>` for hashbang navigation
- The router automatically handles browser back/forward buttons

**Important Notes**:
- Do NOT use custom JavaScript for navigation - `shiny.router` handles this
- Route names in `route()` should NOT include leading `/` (except root)
- URLs will use hashbang format: `http://app/#!/route-name`

### Dictionary Explorer Layout

The Dictionary Explorer uses a **four-panel quadrant layout**:
- **Top-Left**: General concepts table (aggregated by category/subcategory)
- **Top-Right**: Selected concept details and comments
- **Bottom-Left**: Concept mappings table (specific terminology codes)
- **Bottom-Right**: Selected mapping details

All panels are **resizable** using draggable splitters (horizontal and vertical).

### Concept Mapping Layout

The Concept Mapping module uses a hierarchical navigation:
- **Breadcrumb navigation**: Shows current location in folder structure
- **Folder view**: Tree-like structure for organizing custom concepts
- **Table view**: List of concepts with alignment status
- **Modal dialogs**: Multi-page forms for creating/editing alignments

### UI Best Practices

**IMPORTANT: Static vs Dynamic UI**

- **ALWAYS place static UI elements directly in the UI function**, not in the server with `uiOutput`/`renderUI`
- Only use `uiOutput`/`renderUI` when the UI truly needs to change dynamically based on reactive data
- Static elements that only need show/hide behavior should be in the UI and controlled with `shinyjs::show()`/`shinyjs::hide()`

❌ **Avoid**:
```r
# UI
uiOutput(ns("static_menu"))

# Server
output$static_menu <- renderUI({
  tags$div(
    # Static menu items that never change
  )
})
```

✅ **Prefer**:
```r
# UI
tags$div(
  id = ns("static_menu"),
  # Static menu items here
)

# Server (if needed for visibility)
observe({
  if (condition) {
    shinyjs::show("static_menu")
  } else {
    shinyjs::hide("static_menu")
  }
})
```

**When to use `uiOutput`/`renderUI`**:
- Content changes based on data (e.g., list of items from database)
- Number of UI elements varies dynamically
- Complex conditional rendering that can't be handled with show/hide

**Benefits of static UI**:
- Faster rendering (no server round-trip)
- Better performance
- Elements available in DOM immediately for JavaScript
- Easier debugging

### Color Scheme

**Brand Colors** (INDICATE):
- Primary: `#0f60af` (blue)
- Success: `#28a745` (green for standard concepts)
- Danger: `#dc3545` (red for non-standard concepts)
- Background: `#f8f9fa` (light gray)
- Text: `#333` (dark gray)

### DataTables Configuration

Use DT package with these conventions:

```r
DT::renderDT({
  datatable(
    data,
    selection = 'single',      # Single row selection
    rownames = FALSE,          # No row numbers
    class = 'cell-border stripe hover',
    options = list(
      pageLength = 25,
      dom = 'ftp',             # Filter, table, pagination
      ordering = TRUE,
      autoWidth = FALSE
    )
  ) %>%
  formatStyle(...)             # Apply conditional formatting
})
```

### External Links

Always create clickable links to external resources:
- **FHIR Terminology Server**: Use `build_fhir_url()` helper
- **ATHENA OHDSI**: Use `build_athena_url()` helper
- Use `create_link()` to generate HTML anchor tags

---

## JavaScript Integration

### File Organization

JavaScript and CSS files in `inst/www/`:

- **`style.css`** - All application styles and CSS classes
- **`clipboard.js`** - Clipboard copy functionality
- **`comments_scroll_sync.js`** - Comments panel scroll synchronization
- **`copy_menu.js`** - Copy menu interactions
- **`dt_callback.js`** - DataTable event callbacks and customization
- **`evaluate_mappings.js`** - Evaluate mappings tab interactions
- **`folder_display.js`** - Folder tree visualization for concept mapping
- **`keyboard_nav.js`** - Keyboard navigation helpers
- **`login_handler.js`** - Login form interactions (Enter key, etc.)
- **`prevent_doubleclick_selection.js`** - Prevent accidental text selection on double-click
- **`resizable_splitter.js`** - Panel resizing (horizontal/vertical splitters)
- **`selectize_modal_fix.js`** - Fix selectize dropdowns in modals (z-index)
- **`settings_menu.js`** - Settings UI interactions
- **`view_details.js`** - Detail panel management and display

**Note**: Navigation is handled by `shiny.router` (R package), not custom JavaScript

### CSS Classes Reference

The application provides a comprehensive set of reusable CSS classes defined in `inst/www/style.css`. Use these classes for consistent styling across modules.

#### Layout & Structure Classes

- **`.main-panel`** - Main content wrapper with padding and flex layout
- **`.main-content`** - Content container inside main panel
- **`.card-container`** - White box with shadow and rounded corners
- **`.card-container-flex`** - Card container that fills available space
- **`.table-container`** - Styled container for tables with shadow
- **`.panel-container-top`** - Top panel in split layouts (max 40% height)
- **`.panel-container-full`** - Full height panel container

#### Typography & Text

- **`.section-title`** - Section heading (18px, weight 600, blue #0f60af)
- **`.breadcrumb-link`** - Clickable breadcrumb navigation links
- **`.bold-value`** - Bold text for emphasis
- **`.true-value`** - Green bold text for TRUE values
- **`.false-value`** - Red bold text for FALSE values

#### Buttons

- **`.btn-primary-custom`** - Primary action button (blue #0f60af)
- **`.btn-success-custom`** - Success button (green #28a745)
- **`.btn-secondary-custom`** - Secondary button (gray #6c757d)
- **`.btn-danger-custom`** - Danger/delete button (red #dc3545)
- **`.btn-toggle`** - Toggle button with active state
- **`.btn-cancel`** - Cancel button (gray)
- **`.btn-action`**, **`.view-details-btn`** - Small action buttons

#### Navigation

- **`.header`**, **`.header-left`**, **`.header-right`** - Application header components
- **`.header-nav`** - Navigation tabs container
- **`.nav-tab`** - Individual navigation tab
- **`.nav-tab-active`** - Active navigation tab state
- **`.nav-tab-settings`** - Settings icon tab

#### Category & Badges

- **`.category-badge`** - Pill-shaped category badge
- **`.category-badge.selected`** - Selected category state (orange)

#### Modals

- **`.modal-overlay`** - Full-screen modal backdrop
- **`.modal-content`** - Modal dialog container
- **`.modal-header`** - Modal header section
- **`.modal-body`** - Modal content section
- **`.modal-close`** - Close button (×)
- **`.modal-fullscreen`** - Fullscreen modal (for graphs)

#### Forms & Validation

- **`.input-error-message`** - Form validation error text (red, 12px, hidden by default)
- **`.toggle-switch`**, **`.toggle-slider`** - Custom toggle switch components
- **`.toggle-switch.toggle-small`** - Smaller toggle switches for DataTable cells
- **`.toggle-switch.toggle-exclude`** - Red toggles for exclusion indicators
- **`.toggle-count`** - Font styling for toggle counts

#### Quadrant Layout (Four-Panel View)

- **`.quadrant-layout`** - Container for 4-panel layout
- **`.top-section`**, **`.bottom-section`** - Horizontal sections
- **`.quadrant`** - Individual quadrant panel
- **`.quadrant-top-left`**, **`.quadrant-top-right`** - Top panels
- **`.quadrant-bottom-left`**, **`.quadrant-bottom-right`** - Bottom panels
- **`.quadrant-content`** - Content area inside quadrant
- **`.section-header-with-tabs`** - Quadrant header with tabs

#### Splitters & Resizing

- **`.splitter`** - Draggable panel divider (horizontal/vertical)
- **`.resizing`** - Applied during drag operation

#### Comments & Info

- **`.comments-section`**, **`.comments-container`** - Comment display areas
- **`.info-icon`** - Info icon with tooltip on hover
- **`.has-tooltip`** - Element with tooltip (no style change on hover)

#### Concept Details

- **`.concept-details-container`** - Container for concept metadata
- **`.detail-item`** - Individual detail row with label and value
- **`.section-header`** - Section header with colored dot indicator

#### Tabs

- **`.section-tabs`** - Tab button container
- **`.tab-btn`** - Individual tab button
- **`.tab-btn-active`** - Active tab state

#### Tables & DataTables

DataTables are styled globally, but you can use these classes:
- **`.relationship-table`** - Custom styled table for relationships
- **`.dataTable`** - Automatically applied to DT tables
- **`.btn-colvis`** - DataTable column visibility button styling
- **`.dt-buttons`** - DataTable buttons container styling
- **`.delete-icon`** - Delete icon with hover effects

#### Utilities

- **`.check-icon`** - Green checkmark icon
- **`.vocab-status`** - Vocabulary loading status badge
- **`.vocab-status-loading`** - Loading state (orange, pulsing)
- **`.vocab-status-loaded`** - Loaded state (green)

#### File Browser

- **`.file-browser-header`**, **`.file-browser-item`** - Folder navigation UI
- **`.file-browser-folder`** - Folder item with hover effect

#### Usage Examples

```r
# Card container with table
tags$div(
  class = "card-container card-container-flex",
  tags$h4("Data Overview"),
  tags$div(class = "table-container",
    DT::DTOutput(ns("my_table"))
  )
)

# Primary action button
actionButton(
  ns("save_btn"),
  "Save Changes",
  class = "btn-primary-custom"
)

# Error message
tags$div(
  id = ns("error_msg"),
  class = "input-error-message",
  "This field is required"
)

# Section with header
tags$div(
  tags$div(class = "section-title", "Results"),
  tags$div(class = "card-container",
    # Content here
  )
)

# Category badge
tags$span(
  class = "category-badge selected",
  "Vital Signs"
)

# Modal dialog
tags$div(
  id = ns("confirm_modal"),
  class = "modal-overlay",
  style = "display: none;",
  tags$div(
    class = "modal-content",
    tags$div(class = "modal-header",
      tags$h3("Confirm Action"),
      tags$button(class = "modal-close", "×")
    ),
    tags$div(class = "modal-body",
      # Modal content
    )
  )
)
```

### JavaScript Conventions

1. **Use jQuery**: Application relies on jQuery and jQuery UI
2. **Event Delegation**: Use event delegation for dynamically created elements
3. **Try-Catch Blocks**: Wrap error-prone code in try-catch for robustness
4. **Console Logging**: Use `console.log()` for debugging (remove in production)

### Keyboard Navigation

**Note**: Keyboard navigation is not currently implemented with custom JavaScript. Standard browser and DataTables keyboard shortcuts apply:
- Tab: Navigate between interactive elements
- Enter: Activate buttons and links
- DataTables: Built-in search field navigation

### UI Component Patterns

**Modal Dialogs**:
- Use `.modal-overlay` for full-screen overlay
- Use `.modal-content` for dialog container
- Multi-page modals: Switch content with JavaScript
- Close on overlay click or close button

**Breadcrumb Navigation**:
- Show current location in hierarchical views
- Clickable ancestors for navigation
- Auto-update on navigation events

**Folder Trees**:
- Hierarchical display with expand/collapse
- Icons for folders and items
- Drag-and-drop support (future)

**Splitters**:
- Horizontal and vertical panel dividers
- Draggable with visual feedback
- Implemented in `resizable_splitter.js`
- Used in Dictionary Explorer for two-panel layouts

---

## External Service Integration

### FHIR Terminology Server

Base URL: `https://tx.fhir.org/r4/`

Endpoints:
- CodeSystem lookup: `/CodeSystem/$lookup?system=<system>&code=<code>`
- ValueSet expansion: `/ValueSet/$expand?url=<url>`

**Vocabulary System Mappings**:
- SNOMED CT: `http://snomed.info/sct`
- LOINC: `http://loinc.org`
- RxNorm: `http://www.nlm.nih.gov/research/umls/rxnorm`
- ICD10: `http://hl7.org/fhir/sid/icd-10-cm`
- UCUM (units): `http://unitsofmeasure.org`

### OHDSI ATHENA

Base URL: `https://athena.ohdsi.org/search-terms/terms/<concept_id>`

Use for OMOP concept lookups.

---

## Internationalization (i18n)

The application supports multiple languages using **shiny.i18n**:

### Configuration

- Translation files are stored in `inst/translations/`
- Supported languages: English (`en`), French (`fr`)
- Set language via `INDICATE_LANGUAGE` environment variable or `run_app(language = "en")`

### Translation Files

- **`translation_en.csv`**: English translations (key, translation columns)
- **`translation_fr.csv`**: French translations (key, translation columns)

### Usage in Code

```r
# In module UI - pass i18n as parameter
mod_example_ui <- function(id, i18n) {
  ns <- NS(id)
  tagList(
    tags$h3(i18n$t("section_title")),
    actionButton(ns("save"), i18n$t("save_button"))
  )
}

# In module server - use i18n from config
mod_example_server <- function(id, config) {
  moduleServer(id, function(input, output, session) {
    i18n <- config$i18n
    # Use i18n$t("key") for translations
  })
}
```

### Adding New Translations

1. Add the key to both `translation_en.csv` and `translation_fr.csv`
2. Ensure consistent key naming (snake_case)
3. Keep translations concise for UI elements

---

## Testing Guidelines

### Test Files Location

Place test files in `tests/` directory.

### Testing Data

Use sample data files (e.g., `icd10_snomed_mapping.csv`) for testing.

### Testing Framework

Use **testthat** (>= 3.0.0):

```r
test_that("function returns expected output", {
  result <- my_function(input)
  expect_equal(result, expected_output)
})
```

---

## Documentation Standards

### Roxygen2 Comments

All exported functions must have complete documentation:

```r
#' Run the INDICATE Data Dictionary Application
#'
#' @param ... Additional arguments passed to shiny::runApp()
#'
#' @return A Shiny app object
#' @export
#'
#' @importFrom shiny shinyApp
#'
#' @examples
#' \dontrun{
#'   run_app()
#' }
run_app <- function(...) {
  # Function body
}
```

### Internal Documentation

For internal functions, use clear comments explaining:
- Purpose of the function
- Expected input types
- Return value description
- Any side effects

**IMPORTANT**: Write comments as if the code is being written for the first time, not as documentation of changes.

❌ Avoid: `# Fixed the aggregation bug`
✅ Prefer: `# Group concepts by category and count use cases`

---

## Code Style

### R Code Style

Follow **tidyverse style guide** conventions:
- **Indentation**: 2 spaces (no tabs)
- **Line Length**: 80 characters max
- **Assignment**: Use `<-` for assignment, not `=`
- **Spacing**: Space after commas, around operators
- **Pipes**: Use `%>%` from magrittr

**Example**:
```r
aggregated_data <- data %>%
  filter(!is.na(category)) %>%
  group_by(category, subcategory) %>%
  summarise(
    count = n(),
    .groups = "drop"
  )
```

### CSS Code Style

- **Indentation**: 2 spaces
- **Selectors**: One per line for multi-selector rules
- **Properties**: Alphabetical order when possible
- **Colors**: Use hex codes, lowercase
- **Comments**: Section headers with `/* --- Comment --- */`

### JavaScript Code Style

- **Indentation**: 2 spaces
- **Semicolons**: Use semicolons
- **Quotes**: Single quotes for strings
- **Variables**: `const` and `let`, avoid `var`
- **Functions**: Use named functions when possible

---

## Accessibility Guidelines

### Keyboard Navigation

- All interactive elements must be keyboard accessible
- Use `tabindex` appropriately
- Implement arrow key navigation for tables
- Provide visual focus indicators

### Color Contrast

Ensure sufficient color contrast for text:
- Normal text: 4.5:1 contrast ratio minimum
- Large text: 3:1 contrast ratio minimum

### Semantic HTML

Use semantic HTML elements:
- `<button>` for actions
- `<a>` for links
- `<table>` for tabular data
- Proper heading hierarchy (`<h1>`, `<h2>`, etc.)

---

## Performance Optimization

### Data Processing

1. **Preprocessing**: Process data once on load, not reactively
2. **Filtering**: Use dplyr for efficient filtering
3. **Aggregation**: Compute summaries reactively only when needed
4. **Caching**: Use reactive values to cache computed results

### DataTables

1. **Client-Side Processing**: Use `server = FALSE` for small datasets (<10,000 rows)
2. **Pagination**: Default page length of 25 rows
3. **Column Rendering**: Use DT formatters for conditional styling

### JavaScript

1. **Event Delegation**: Attach handlers to parent elements
2. **Debouncing**: Debounce resize and scroll events
3. **Minimize DOM Manipulation**: Batch DOM updates when possible

---

## Error Handling

### R Error Handling

```r
# Validate inputs
req(input$table_rows_selected)

# Check data dimensions
if (nrow(selected_data) != 1) {
  warning("Expected single row, got ", nrow(selected_data))
  return(NULL)
}

# Handle missing data
value <- if (!is.na(data$column)) data$column else "/"
```

### JavaScript Error Handling

```javascript
try {
  // Potentially error-prone code
  var selectedRow = table.row('.selected').data();
} catch (error) {
  console.error('Error selecting row:', error);
}
```

---

## Deployment Considerations

### Docker and Hugging Face Spaces

The application can be deployed on [Hugging Face Spaces](https://huggingface.co/spaces) using Docker.

**Dockerfile Configuration**:
- Base image: `r-base:4.4.2`
- Port: **7860** (Hugging Face default)
- Uses Posit Package Manager for faster binary package installation
- Sets `INDICATE_ENV=docker` environment variable for container detection

**Environment Detection**:

The application detects whether it's running in a container using `is_container()` from `fct_config.R`:

```r
is_container <- function() {
  Sys.getenv("INDICATE_ENV") == "docker"
}
```

This affects UI behavior:
- **Local mode**: Browse button to select vocabulary folder on filesystem
- **Container mode**: Upload button to upload CSV files via browser

**Hugging Face Deployment Steps**:
1. Create a new Space at [huggingface.co/new-space](https://huggingface.co/new-space) with **Docker** SDK
2. Clone the Space repository and copy application files
3. Ensure README.md has the YAML header (see [Spaces config reference](https://huggingface.co/docs/hub/spaces-config-reference)):
   ```yaml
   ---
   title: INDICATE Data Dictionary
   sdk: docker
   ---
   ```
4. Use Git LFS for binary files: `git lfs track "*.png"`
5. Push to deploy (first build ~15-20 minutes)

### Package Building

Before deployment:
1. Update `DESCRIPTION` version
2. Run `devtools::document()` to update documentation
3. Run `devtools::check()` to validate package
4. Test with `run_app()` locally

### Dependencies

Ensure all package dependencies are:
- Listed in `DESCRIPTION` under `Imports`
- Minimum versions specified where critical
- Available on CRAN or documented alternatives

### Data Files

- Keep CSV files in `inst/extdata/data_dictionary/`
- Ensure file sizes are reasonable (<50 MB per file)
- Document data update procedures
- Use version control for data files

---

## Future Development

### Implemented Features

1. **Semantic Alignment Module**: Align user concepts with dictionary general concepts
2. **Import/Export**: Support for Usagi, STCM, ATLAS JSON, and INDICATE formats
3. **Concept Sets**: Advanced concept set management with descendants/mapped inclusion
4. **Coverage Metrics**: Percentage-based coverage display with color coding
5. **Comments System**: Mapping evaluations with comments
6. **Internationalization**: English and French language support

### Planned Features

1. **HealthDCAT-AP Alignment**: FAIR principles for EHDS
2. **Additional Terminologies**: Beyond current vocabularies
3. **Enhanced Visualization**: Concept relationship mapping

### Extension Points

- New modules should follow the `mod_<name>` pattern
- New utilities should be grouped in `utils_<purpose>.R`
- New data sources should be added to `inst/extdata/`
- New web assets should be placed in `inst/www/`

---

## Contact & Support

**Author**: Boris Delange (boris.delange@univ-rennes.fr)

**License**: GPL (>= 3)

**Project Context**: Part of the INDICATE project for ICU data harmonization in Europe

---

## Summary

When working on this project:

1. **Follow the Shiny module pattern** for new features
2. **Use snake_case** for R code, **camelCase** for JavaScript
3. **Document all exported functions** with Roxygen2
4. **Test thoroughly** with realistic data
5. **Maintain accessibility** standards
6. **Write clear commit messages** in English without emojis
7. **Comment code purposefully**, not historically
8. **Optimize for performance** with large datasets
9. **Integrate external services** (FHIR, ATHENA) consistently
10. **Keep the codebase modular and maintainable**

This is a production-ready healthcare data application - quality and reliability are paramount.
