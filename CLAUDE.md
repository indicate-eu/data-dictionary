# CLAUDE.md - INDICATE Data Dictionary Project Guidelines

This file provides development guidelines for Claude Code when working on the INDICATE Data Dictionary Shiny application.

## Project Overview

**INDICATE Data Dictionary** is an R Shiny application for managing OHDSI-compliant concept sets for the INDICATE project (EU Digital Europe Programme, grant 101167778). It provides a web-based interface for browsing, creating, reviewing, and exporting clinical concept sets following the OMOP Common Data Model standards. The application supports 332 concept sets across 9 clinical domains for ICU data harmonization across 15 European data providers from 12 countries.

**Version**: 0.2.0.9002

**Technologies**: R (>= 4.0.0), Shiny (>= 1.7.0), DT, DBI, RSQLite, DuckDB, Arrow, bcrypt, shiny.i18n, shiny.router, shinyjs, visNetwork, jsonlite, stringdist, jQuery, DataTables

**License**: EUPL-1.2

**Author**: Boris Delange (boris.delange@univ-rennes.fr)

---

## Architecture Overview

### Dual Database Architecture

The application uses two databases:

1. **SQLite** (`indicate.db`) - Primary data store for application data
   - Location: `~/indicate_files/indicate.db` (default)
   - Can be overridden with `INDICATE_APP_FOLDER` environment variable
   - Auto-initializes tables on first connection via `init_database()`

2. **DuckDB** (`ohdsi_vocabularies.duckdb`) - Read-only OHDSI vocabulary store
   - Location: `~/indicate_files/ohdsi_vocabularies.duckdb`
   - Created from ATHENA CSV or Parquet files via General Settings
   - Contains tables: `concept`, `concept_relationship`, `concept_ancestor`, `concept_synonym`, `relationship`
   - Used for vocabulary lookups, hierarchy graphs, concept resolution

### SQLite Tables

**`concept_sets`**: OHDSI-compliant concept sets (extended with lifecycle metadata)
```sql
CREATE TABLE concept_sets (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  version TEXT DEFAULT '1.0.0',
  review_status TEXT DEFAULT 'draft',
  category TEXT,
  subcategory TEXT,
  long_description TEXT,
  tags TEXT,
  created_by_first_name TEXT, created_by_last_name TEXT,
  created_by_profession TEXT, created_by_affiliation TEXT, created_by_orcid TEXT,
  created_date TEXT,
  modified_by_first_name TEXT, modified_by_last_name TEXT,
  modified_by_profession TEXT, modified_by_affiliation TEXT, modified_by_orcid TEXT,
  modified_date TEXT
)
```

**`concept_set_items`**: Concepts within a concept set (follows OHDSI Concept Set Specification)
```sql
CREATE TABLE concept_set_items (
  concept_set_id INTEGER NOT NULL,
  concept_id INTEGER NOT NULL,
  concept_name TEXT, vocabulary_id TEXT, concept_code TEXT,
  domain_id TEXT, concept_class_id TEXT, standard_concept TEXT,
  is_excluded INTEGER DEFAULT 0,
  include_descendants INTEGER DEFAULT 1,
  include_mapped INTEGER DEFAULT 1,
  created_at TEXT,
  PRIMARY KEY (concept_set_id, concept_id)
)
```

**`concept_set_translations`**: Multilingual translations for concept set fields
```sql
CREATE TABLE concept_set_translations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  concept_set_id INTEGER NOT NULL,
  language TEXT NOT NULL,
  field TEXT NOT NULL,  -- 'name', 'description', 'category', 'subcategory', 'long_description'
  value TEXT,
  UNIQUE(concept_set_id, language, field)
)
```

**`concept_set_reviews`**: Review workflow with status tracking
```sql
CREATE TABLE concept_set_reviews (
  review_id INTEGER PRIMARY KEY AUTOINCREMENT,
  concept_set_id INTEGER NOT NULL,
  concept_set_version TEXT,
  reviewer_user_id INTEGER NOT NULL,
  status TEXT NOT NULL,  -- 'pending_review', 'approved', 'needs_revision'
  comments TEXT,
  review_date TEXT
)
```

**`concept_set_changelog`**: Version history and change tracking
```sql
CREATE TABLE concept_set_changelog (
  change_id INTEGER PRIMARY KEY AUTOINCREMENT,
  concept_set_id INTEGER NOT NULL,
  version_from TEXT, version_to TEXT,
  changed_by_user_id INTEGER,
  change_date TEXT,
  change_type TEXT,  -- 'created', 'updated', 'version_change', 'status_change'
  change_summary TEXT,
  changes_json TEXT
)
```

**`concept_set_stats`**: Distribution statistics (JSON blob per concept set)

**`users`**: Application users
```sql
CREATE TABLE users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  login TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  first_name TEXT, last_name TEXT,
  profession TEXT, affiliation TEXT, orcid TEXT,
  user_access_id INTEGER,
  created_at TEXT, updated_at TEXT
)
```

**`user_accesses`**: Permission levels (Admin, Editor, Read only)

**`projects`**: Project definitions with justification and bibliography

**`project_concept_sets`**: Many-to-many association between projects and concept sets

**`tags`**: Reusable tags with color codes

**`recommended_units`**: Recommended UCUM units per concept

**`unit_conversions`**: Unit conversion factors between measurement concepts

**`config`**: Key-value configuration store

Default user: admin / admin

---

## Code Organization

### Directory Structure

```
indicate-data-dictionary/
├── R/                                # R source code (23,028 lines total)
│   ├── run_app.R                    # Application entry point (78 lines)
│   ├── app_ui.R                     # Main UI with router (107 lines)
│   ├── app_server.R                 # Main server, module init (112 lines)
│   ├── mod_data_dictionary.R        # Dictionary explorer module (8,113 lines)
│   ├── mod_concept_mapping.R        # Concept mapping - IN PROGRESS (56 lines)
│   ├── mod_projects.R               # Projects management (1,091 lines)
│   ├── mod_general_settings.R       # General settings (1,077 lines)
│   ├── mod_dictionary_settings.R    # Dictionary settings, tags, units (2,138 lines)
│   ├── mod_users.R                  # User management (974 lines)
│   ├── mod_dev_tools.R              # Development tools (706 lines)
│   ├── mod_page_header.R            # Navigation header (300 lines)
│   ├── mod_login.R                  # Login/authentication (244 lines)
│   ├── fct_database.R               # SQLite CRUD operations (2,006 lines)
│   ├── fct_duckdb.R                 # DuckDB vocabulary queries (1,706 lines)
│   ├── fct_import_export.R          # ZIP/GitHub import, JSON export (584 lines)
│   ├── fct_datatable.R              # DataTable helpers (470 lines)
│   ├── fct_users.R                  # User auth functions (346 lines)
│   ├── fct_fuzzy_search.R           # Fuzzy search engine (746 lines)
│   ├── fct_statistics_display.R     # Statistics display helpers (1,088 lines)
│   ├── fct_optimize.R               # Performance optimization (249 lines)
│   ├── utils_ui.R                   # UI helpers (689 lines)
│   └── utils_server.R               # Server utilities (148 lines)
├── inst/
│   ├── translations/                # i18n files (CSV: base,en / base,fr)
│   └── www/                         # Web assets (style.css, fuzzy_search.js, logo.png, favicon.png)
├── man/figures/                      # README screenshots
├── Dockerfile                        # Docker deployment (rocker/tidyverse:4.4.2)
├── DESCRIPTION                       # Package metadata
├── NAMESPACE                         # R namespace
└── LICENSE                           # EUPL-1.2
```

### Function Libraries

#### `fct_database.R` - SQLite Operations (2,006 lines)

Config CRUD: `get_config_value()`, `set_config_value()`

Concept Sets CRUD: `add_concept_set()`, `delete_concept_set()`, `get_all_concept_sets()`, `get_concept_set()`, `update_concept_set()`

Concept Set Items CRUD: `add_concept_set_item()`, `delete_concept_set_item()`, `get_concept_set_items()`, `update_concept_set_item()`

Reviews & Changelog: `add_concept_set_review()`, `delete_concept_set_review()`, `update_concept_set_review()`, `get_concept_set_reviews()`, `add_changelog_entry()`, `delete_changelog_entry()`, `update_changelog_entry()`, `get_version_history()`

Statistics: `update_concept_set_stats()`

Tags CRUD: `add_tag()`, `delete_tag()`, `get_all_tags()`, `get_tag_usage_count()`, `update_tag()`

Projects CRUD: `add_project()`, `delete_project()`, `get_all_projects()`, `get_project()`, `update_project()`

Project-Concept Sets: `add_project_concept_set()`, `remove_project_concept_set()`, `get_project_concept_sets()`, `get_available_concept_sets_for_project()`, `get_concept_set_ids_for_projects()`

Recommended Units: `add_recommended_unit()`, `delete_recommended_unit()`, `get_all_recommended_units()`, `load_default_recommended_units()`

Unit Conversions: `add_unit_conversion()`, `delete_unit_conversion()`, `get_all_unit_conversions()`, `load_default_unit_conversions()`, `update_unit_conversion()`

Translations: `get_all_concept_set_translations()`, `get_concept_set_translation()`, `set_concept_set_translation()`

Database: `get_app_dir()`, `get_db_connection()`, `init_database()`

**CRITICAL: RSQLite NULL Handling**

RSQLite does NOT accept `NULL` values in parameterized queries. Always use:
```r
null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x
```

#### `fct_duckdb.R` - Vocabulary Operations (1,706 lines)

Database management: `duckdb_exists()`, `get_duckdb_path()`, `get_duckdb_connection()`, `create_duckdb_database()`, `delete_duckdb_database()`, `load_vocabularies_from_duckdb()`

File handling: `detect_vocab_format()`, `read_vocab_file()`, `load_parquet_to_duckdb()`

Concept queries: `get_concept_by_id()`, `get_related_concepts()`, `get_concept_descendants()`, `get_concept_synonyms()`

Hierarchy: `get_concept_hierarchy_graph()`, `count_hierarchy_concepts()`

Concept set resolution: `resolve_concept_set()`

Export: `export_concept_set_to_json()`, `export_all_concept_sets()`, `export_concept_list()`, `export_concept_set_to_sql()`

Import: `import_concept_set_from_json()`

#### `fct_import_export.R` - Import/Export (584 lines)

GitHub integration: `parse_github_url()`, `download_github_concept_sets()`, `download_github_folder()`, `get_github_latest_commit()`, `import_concept_sets_from_github()`, `import_projects_from_github()`, `import_project_from_json()`

Update workflow: `check_concept_sets_updates()`, `apply_concept_sets_updates()`

ZIP import: `import_concept_sets_from_zip()`

Config keys for GitHub: `concept_sets_repo_url`, `concept_sets_last_commit_sha`

#### `fct_fuzzy_search.R` - Fuzzy Search Engine (746 lines)

Server-side fuzzy search with stringdist matching. Used for concept search across the dictionary.

#### `fct_statistics_display.R` - Statistics Helpers (1,088 lines)

Functions for rendering concept set statistics and distribution data.

#### `fct_datatable.R` - DataTable Helpers (470 lines)

`add_button_handlers()`, `create_datatable_actions()`, `create_empty_datatable()`, `create_standard_datatable()`, `datatable_select_rows()`, `get_datatable_language()`, `style_standard_concept_column()`

#### `fct_users.R` - User Management (346 lines)

`add_user()`, `add_user_access()`, `authenticate_user()`, `delete_user()`, `delete_user_access()`, `get_all_user_accesses()`, `get_all_users()`, `hash_password()`, `update_user()`, `update_user_access()`, `verify_password()`

#### `utils_ui.R` - UI Helpers (689 lines)

Layout: `create_page_layout(layout, ..., splitter)` - Layouts: `"full"`, `"left-right"`, `"top-bottom"`, `"left-wide"`, `"right-wide"`, `"quadrant"`

Panels: `create_panel(title, content, header_extra, class, id, tooltip)`

Modals: `create_modal(id, title, body, footer, size, icon, ns)`, `show_modal()`, `hide_modal()`

Display: `create_detail_item(label, value, format_number, url, color)`

#### `utils_server.R` - Server Helpers (148 lines)

`observe_event(eventExpr, handlerExpr, log, ...)` - **ALWAYS use this instead of `observeEvent()`**

`try_catch(trigger, code, log)` - Error handling wrapper

`validate_required_inputs(input, fields)` - Form validation

**IMPORTANT**: Functions within `fct_*.R` files must be in **alphabetical order**.

---

## Module Pattern

### Module Structure

```r
mod_example_ui <- function(id, i18n) {
  ns <- NS(id)
  tagList(
    tags$div(
      class = "main-panel",
      tags$div(class = "main-content",
        # Module content here
      )
    )
  )
}

mod_example_server <- function(id, i18n, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    log_level <- strsplit(Sys.getenv("INDICATE_DEBUG_MODE", "error"), ",")[[1]]
    # Module logic here
  })
}
```

### Module File Structure

Every module file must include a structural outline at the top (see existing modules for examples).

---

## Reactive Programming Patterns

### CRITICAL SHINY REACTIVITY RULES

#### 1. ALWAYS use `observe_event()` (with underscore), NEVER `observeEvent()` or `observe()`

#### 2. Key Parameters
- `ignoreInit = TRUE`: For user-triggered actions (button clicks)
- `ignoreInit = FALSE`: For initial state setup (table rendering)
- `ignoreNULL = FALSE`: Execute even when reactive value is NULL

#### 3. Output Rendering - Always wrap outputs in `observe_event()`

```r
observe_event(data_trigger(), {
  output$my_table <- DT::renderDT({ data() })
}, ignoreInit = FALSE)
```

#### 4. Validation - Use `if()... return()` instead of `req()`

#### 5. Trigger-Based Updates for coordinating UI updates

#### 6. No Nested Observers - NEVER nest `observe_event()` inside another

#### 7. No Error Handling in Observers - NEVER add `tryCatch()` inside `observe_event()`

#### 8. No Shiny Package Prefix - NEVER use `shiny::`

#### 9. No `observe_event(TRUE, ...)` - Put initialization directly in `moduleServer` body

---

## UI Development

### Navigation System

Uses **`shiny.router`** for client-side routing:
- `/`: Data Dictionary (main page)
- `/mapping`: Concept Mapping (in progress)
- `/projects`: Projects
- `/general-settings`: General Settings
- `/dictionary-settings`: Dictionary Settings
- `/users`: User Management
- `/dev-tools`: Development Tools

### UI Best Practices

- **ALWAYS place static UI in `mod_*_ui()`**, not server
- Only use `uiOutput()`/`renderUI()` when content truly changes dynamically
- Use `shinyjs::show()`/`shinyjs::hide()` for visibility
- Use `create_modal()` from `utils_ui.R` for modals
- Use `create_page_layout()` and `create_panel()` for consistent layouts
- Use `create_detail_item()` for label-value pairs

### DataTable Pattern

Use factorized helpers: `create_standard_datatable()`, `create_empty_datatable()`, `create_datatable_actions()`, `add_button_handlers()`

### DataTables in Hidden Divs

Use `outputOptions(output, "my_table", suspendWhenHidden = FALSE)` after initializing with empty table.

### CSS Classes

**Buttons**: `.btn-primary-custom` (blue), `.btn-success-custom` (green), `.btn-secondary-custom` (gray), `.btn-danger-custom` (red), `.btn-purple-custom` (violet)

**Layout**: `.main-panel`, `.main-content`, `.modal-overlay`, `.modal-content`

**Info Icons**: `.info-icon` with `data-tooltip` attribute, content `HTML("&#x3f;")`

---

## Internationalization (i18n)

Translation files in `inst/translations/` (CSV with columns `base,<language_code>`):
- `translation_en.csv` - English
- `translation_fr.csv` - French

Usage: `i18n$t("key")` in UI, `as.character(i18n$t("key"))` in server

---

## JSON Format

Concept sets follow the OHDSI Concept Set Specification with INDICATE extensions:

```json
{
  "id": 42,
  "name": "Heart rate",
  "description": "...",
  "version": "1.0.0",
  "expression": {
    "items": [
      {
        "concept": { "conceptId": 3027018, "conceptName": "Heart rate", ... },
        "isExcluded": false,
        "includeDescendants": true,
        "includeMapped": true
      }
    ]
  },
  "tags": ["vitals"],
  "reviewStatus": "approved",
  "metadata": {
    "translations": { "en": {...}, "fr": {...} },
    "createdByDetails": { "firstName": "...", "orcid": "..." },
    "reviews": [...],
    "versions": [...],
    "distributionStats": {...}
  }
}
```

---

## Naming Conventions

- **Functions**: `mod_*_ui()`, `mod_*_server()`, `get_*()`, `add_*()`, `update_*()`, `delete_*()`, `create_*()`, `export_*()`, `import_*()`
- **Variables**: snake_case, reactive values: `editing_id`, `data_trigger`
- **Files**: `mod_<name>.R`, `fct_<domain>.R` (alphabetical!), `utils_<purpose>.R`, `app_<component>.R`
- **CSS**: `.component-name`, `.component-name-variant`
- **JavaScript**: camelCase

---

## Development Checklist

- [ ] All observers use `observe_event()` (with underscore)
- [ ] All observers have explicit `ignoreInit` parameter
- [ ] No `tryCatch()` inside `observe_event()`
- [ ] No `shiny::` prefixes
- [ ] No nested `observe_event()` blocks
- [ ] All `output$...` assignments inside `observe_event()`
- [ ] Validation uses `if()... return()` instead of `req()`
- [ ] Static UI in `mod_*_ui()`, not `renderUI()`
- [ ] Functions in `fct_*.R` files in alphabetical order
- [ ] Translations added for new UI text
- [ ] NULL values converted to NA for RSQLite queries

---

## Contact & Support

**Author**: Boris Delange (boris.delange@univ-rennes.fr)

**License**: EUPL-1.2
