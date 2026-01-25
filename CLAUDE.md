# CLAUDE.md - INDICATE Data Dictionary Project Guidelines

This file provides development guidelines for Claude Code when working on the INDICATE Data Dictionary Shiny application.

## Project Overview

**INDICATE Data Dictionary** is an R Shiny application for managing OHDSI-compliant concept sets. It provides a user interface for browsing, creating, and managing clinical concept sets following the OMOP Common Data Model standards.

**Technologies**: R (>= 4.0.0), Shiny (>= 1.7.0), DT, DBI, RSQLite, bcrypt, shiny.i18n, shiny.router, shinyjs, jQuery, DataTables

**Author**: Boris Delange (boris.delange@univ-rennes.fr)

---

## Architecture Overview

### Database Architecture

The application uses **SQLite** as the primary data store:

- Database location: `rappdirs::user_data_dir("indicate", "indicate")/indicate.db`
- Can be overridden with `INDICATE_DATA_DIR` environment variable
- Auto-initializes tables on first connection

### Core Tables

**`concept_sets`**: OHDSI-compliant concept sets
```sql
CREATE TABLE concept_sets (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  version TEXT DEFAULT '1.0.0',
  category TEXT,
  subcategory TEXT,
  etl_comment TEXT,
  tags TEXT,
  created_by TEXT,
  created_date TEXT,
  modified_by TEXT,
  modified_date TEXT
)
```

**`users`**: Application users
```sql
CREATE TABLE users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  login TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  role TEXT,
  affiliation TEXT,
  user_access_id INTEGER,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (user_access_id) REFERENCES user_accesses(user_access_id)
)
```

**`user_accesses`**: User permission levels
```sql
CREATE TABLE user_accesses (
  user_access_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TEXT,
  updated_at TEXT
)
```

Default user accesses: Admin, Editor, Read only
Default user: admin (password: admin)

---

## Code Organization

### Directory Structure

```
indicate-data-dictionary/
├── R/                              # R source code
│   ├── run_app.R                  # Application entry point
│   ├── app_ui.R                   # Main UI function
│   ├── app_server.R               # Main server logic
│   ├── mod_data_dictionary.R      # Data dictionary module (main page)
│   ├── mod_concept_mapping.R      # Concept mapping module
│   ├── mod_projects.R             # Projects management module
│   ├── mod_general_settings.R     # General settings module
│   ├── mod_dictionary_settings.R  # Dictionary settings module
│   ├── mod_users.R                # User management module
│   ├── mod_dev_tools.R            # Development tools module
│   ├── mod_page_header.R          # Page header with navigation
│   ├── fct_database.R             # Database operations (SQLite)
│   ├── fct_datatable.R            # DataTable helper functions
│   ├── fct_users.R                # User management functions
│   ├── utils_ui.R                 # UI helpers (create_page_layout, create_panel, create_modal, show_modal, hide_modal)
│   └── utils_server.R             # Server utilities
├── inst/
│   ├── translations/              # Internationalization files
│   │   ├── translation_en.csv     # English translations
│   │   └── translation_fr.csv     # French translations
│   └── www/                       # Web assets (CSS, JS, images)
│       ├── style.css              # Main stylesheet
│       ├── logo.png               # INDICATE logo
│       └── favicon.png            # Application favicon
├── old/                           # Archived code (reference only)
├── DESCRIPTION                    # Package metadata
└── NAMESPACE                      # R namespace definitions
```

### Function Libraries

#### `fct_database.R` - Database Operations

CRUD operations for concept sets and database initialization:
- `add_concept_set()`: Create a new concept set
- `delete_concept_set()`: Delete a concept set
- `get_all_concept_sets()`: Retrieve all concept sets
- `get_app_dir()`: Get application data directory
- `get_concept_set()`: Retrieve a specific concept set
- `get_db_connection()`: Create SQLite connection
- `init_database()`: Initialize database tables
- `update_concept_set()`: Update an existing concept set

**CRITICAL: RSQLite NULL Handling**

RSQLite does NOT accept `NULL` values in parameterized queries. Using `NULL` causes the error:
```
Error: Parameter X does not have length 1.
```

**Solution**: Always convert `NULL` to `NA` before passing to `DBI::dbExecute()`:

```r
# Helper function to convert NULL to NA
null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x

# Use in INSERT statements
DBI::dbExecute(
  con,
  "INSERT INTO table (col1, col2, col3) VALUES (?, ?, ?)",
  params = list(value1, null_to_na(optional_value), null_to_na(another_optional))
)

# Use in UPDATE statements with dynamic parameters
updates <- list(...)
updates <- lapply(updates, null_to_na)  # Convert all NULL values
```

**When to apply**:
- Any optional parameter that could be `NULL`
- Values from user input that might be empty strings converted to `NULL`
- Default parameter values like `description = NULL`

#### `fct_users.R` - User Management

User authentication and CRUD operations:
- `add_user()`: Create a new user
- `add_user_access()`: Create a new user access profile
- `authenticate_user()`: Verify credentials and return user
- `delete_user()`: Delete a user
- `delete_user_access()`: Delete a user access profile
- `get_all_user_accesses()`: Retrieve all user access profiles
- `get_all_users()`: Retrieve all users
- `hash_password()`: Create bcrypt hash
- `update_user()`: Update an existing user
- `update_user_access()`: Update a user access profile
- `verify_password()`: Check password against hash

#### `fct_datatable.R` - DataTable Helpers

Standardized DataTable creation:
- `add_button_handlers()`: Add click handlers to DataTable buttons
- `create_datatable_actions()`: Generate action buttons HTML
- `create_empty_datatable()`: Create empty table with message
- `create_standard_datatable()`: Factory for consistent DataTables (includes Columns button by default)
- `datatable_select_rows()`: Select or unselect all rows in a DataTable
- `get_datatable_language()`: Get language options for DataTables
- `style_standard_concept_column()`: Apply color styling to standard_concept columns

**DataTable Row Selection Helper**:
```r
# Select all rows
proxy <- DT::dataTableProxy("my_table", session = session)
datatable_select_rows(proxy, select = TRUE, data = my_data)

# Unselect all rows
datatable_select_rows(proxy, select = FALSE)
```

#### `utils_ui.R` - UI Refactoring Functions

**IMPORTANT**: Always use these functions to maintain consistent UI across the application.

**Layout Functions**:
- `create_page_layout(layout, ..., splitter)`: Create page layouts
  - Layouts: `"full"`, `"left-right"`, `"top-bottom"`, `"left-wide"`, `"right-wide"`, `"quadrant"`
  - Pass panel contents as `...` arguments (number depends on layout type)
  - `splitter = TRUE` adds resizable splitters between panels

- `create_panel(title, content, header_extra, class, id, tooltip)`: Create a panel with optional header
  - `title`: Panel title (NULL for no header)
  - `content`: Panel content (tagList or tags)
  - `header_extra`: Extra content in header (e.g., buttons)
  - `tooltip`: Tooltip text for info icon

**Modal Functions**:
- `create_modal(id, title, body, footer, size, icon, ns)`: Create modal dialogs
  - `size`: `"small"`, `"medium"`, `"large"`, `"fullscreen"`
  - `icon`: FontAwesome class (e.g., `"fas fa-folder-open"`)
  - `ns`: Namespace function from module

- `show_modal(modal_id)`: Show a modal by ID
- `hide_modal(modal_id)`: Hide a modal by ID

**Display Functions**:
- `create_detail_item(label, value, format_number, url, color)`: Create label-value pairs
  - Handles NULL/NA values automatically (displays "/")
  - `format_number = TRUE`: Format numbers with separators
  - `url`: Make value a clickable link
  - `color`: Custom text color

#### `utils_server.R` - Server Refactoring Functions

**Observer Functions**:
- `observe_event(eventExpr, handlerExpr, log, ...)`: Enhanced observeEvent with error handling
  - Automatically wraps code in try-catch
  - Logs events and errors based on `log_level` variable
  - **ALWAYS use this instead of `observeEvent()`**

- `try_catch(trigger, code, log)`: Error handling wrapper (used internally by observe_event)

**Validation Functions**:
- `validate_required_inputs(input, fields)`: Validate required form fields
  - `fields`: Named list where names are input IDs and values are error element IDs
  - Returns TRUE if all valid, FALSE if any errors

**IMPORTANT**: Functions within `fct_*.R` files must be in **alphabetical order**.

---

## Module Pattern

This project follows the **Shiny module pattern**:

### Module Structure

```r
# UI function - receives i18n for translations
mod_example_ui <- function(id, i18n) {
  ns <- NS(id)
  tagList(
    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",
        # Module content here
      )
    )
  )
}

# Server function - receives i18n and optional parameters
mod_example_server <- function(id, i18n, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    # Module logic here
  })
}
```

### Module File Structure

Every module file must include a structural outline:

```r
# MODULE STRUCTURE OVERVIEW ====
#
# This module provides [description]
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Section 1
#      ### Section 2
#   ## UI - Modals
#      ### Modal - Add/Edit Form
#      ### Modal - Delete Confirmation
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### State Variables
#      ### Triggers
#
#   ## 2) Server - Data Loading
#      ### Load Data
#
#   ## 3) Server - Table Rendering
#      ### Render Table
#
#   ## 4) Server - CRUD Operations
#      ### Add
#      ### Edit
#      ### Delete

# UI SECTION ====

mod_example_ui <- function(id, i18n) {
  # ...
}

# SERVER SECTION ====

mod_example_server <- function(id, i18n, current_user = NULL) {
  # ...
}
```

---

## Reactive Programming Patterns

### CRITICAL SHINY REACTIVITY RULES

These rules MUST be followed throughout the application:

#### 1. Observer Naming

**ALWAYS use `observe_event()` (with underscore), NEVER `observeEvent()` or `observe()`**

```r
# CORRECT
observe_event(input$button, {
  # Handler code
}, ignoreInit = TRUE)

# WRONG
observeEvent(input$button, { ... })
observe({ ... })
```

#### 2. Key Parameters

- `ignoreInit = TRUE`: For user-triggered actions (button clicks)
- `ignoreInit = FALSE`: For initial state setup (table rendering)
- `ignoreNULL = FALSE`: Execute even when reactive value is NULL

#### 3. Output Rendering

**Always wrap outputs in `observe_event()`**

```r
# CORRECT
observe_event(data_trigger(), {
  output$my_table <- DT::renderDT({
    data()
  })
}, ignoreInit = FALSE)

# WRONG - standalone output assignment
output$my_table <- DT::renderDT({ data() })
```

#### 4. Validation Pattern

**Use `if()... return()` instead of `req()`**

```r
# CORRECT
observe_event(input$button, {
  if (is.null(input$value)) return()
  if (is.null(data())) return()
  # Process data
}, ignoreInit = TRUE)

# WRONG
observe_event(input$button, {
  req(input$value)
  req(data())
  # Process data
})
```

#### 5. Trigger-Based Updates

Use triggers to coordinate UI updates:

```r
# Reactive values
data <- reactiveVal(NULL)
table_trigger <- reactiveVal(0)

# When data changes, increment trigger
observe_event(data(), {
  table_trigger(table_trigger() + 1)
}, ignoreNULL = FALSE)

# Render table when trigger fires
observe_event(table_trigger(), {
  output$my_table <- DT::renderDT({
    # ...
  })
}, ignoreInit = FALSE)
```

#### 6. No Nested Observers

**NEVER nest `observe_event()` inside another `observe_event()`**

```r
# WRONG
observe_event(input$button1, {
  observe_event(input$button2, {
    # Nested observer - BAD
  })
})

# CORRECT - use separate observers
observe_event(input$button1, { ... }, ignoreInit = TRUE)
observe_event(input$button2, { ... }, ignoreInit = TRUE)
```

#### 7. No Error Handling in Observers

**NEVER add `tryCatch()` inside `observe_event()`**

The application uses a custom wrapper that handles errors.

#### 8. No Shiny Package Prefix

**NEVER use `shiny::` prefix**

```r
# CORRECT
observe_event(...)
reactive(...)
updateTextInput(...)

# WRONG
shiny::observeEvent(...)
shiny::reactive(...)
```

#### 9. No observe_event(TRUE, ...)

**NEVER use `observe_event(TRUE, ...)` for initialization**

Put initialization code directly in the moduleServer body, outside of any observer.

```r
# WRONG - observe_event(TRUE, ...) is an anti-pattern
observe_event(TRUE, {
  saved_path <- get_config_value("vocab_folder")
  if (!is.null(saved_path)) {
    selected_folder(saved_path)
  }
}, once = TRUE)

# CORRECT - direct initialization in moduleServer
mod_example_server <- function(id, i18n) {
  moduleServer(id, function(input, output, session) {
    # Reactive values
    selected_folder <- reactiveVal(NULL)

    # Direct initialization - runs once when module loads
    saved_path <- get_config_value("vocab_folder")
    if (!is.null(saved_path)) {
      selected_folder(saved_path)
    }

    # Rest of server logic...
  })
}
```

---

## UI Development

### Navigation System

The application uses **`shiny.router`** for client-side routing:

**Available Routes**:
- `/`: Data Dictionary (main page)
- `/mapping`: Concept Mapping
- `/projects`: Projects
- `/general-settings`: General Settings
- `/dictionary-settings`: Dictionary Settings
- `/users`: User Management
- `/dev-tools`: Development Tools

### UI Best Practices

**Static vs Dynamic UI**:
- **ALWAYS place static UI in `mod_*_ui()`**, not server
- Only use `uiOutput()`/`renderUI()` when content truly changes dynamically
- Use `shinyjs::show()`/`shinyjs::hide()` for visibility

**Modal Pattern** (use `create_modal()` from `utils_ui.R`):
```r
# In UI - use the create_modal() helper function
create_modal(
  id = "confirm_modal",
  title = "Confirm Action",
  body = tags$p("Are you sure you want to proceed?"),
  footer = tagList(
    actionButton(ns("cancel"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
    actionButton(ns("confirm"), i18n$t("confirm"), class = "btn-primary-custom", icon = icon("check"))
  ),
  size = "medium",  # "small", "medium", "large", "fullscreen"
  icon = "fas fa-question-circle",
  ns = ns
)

# In server - show modal
show_modal(ns("confirm_modal"))

# In server - hide modal
hide_modal(ns("confirm_modal"))
```

The `create_modal()` function automatically handles:
- Click outside to close (on overlay)
- Close button (×) in header
- Proper namespacing
- Consistent styling

### DataTable Pattern

Use the factorized helper functions:

```r
observe_event(data_trigger(), {
  output$my_table <- DT::renderDT({
    data <- my_data()
    if (is.null(data) || nrow(data) == 0) {
      return(create_empty_datatable(as.character(i18n$t("no_data"))))
    }

    # Add action buttons
    data$Actions <- sapply(data$id, function(id) {
      create_datatable_actions(list(
        list(label = as.character(i18n$t("edit")), icon = "edit", type = "warning", class = "btn-edit", data_attr = list(id = id)),
        list(label = as.character(i18n$t("delete")), icon = "trash", type = "danger", class = "btn-delete", data_attr = list(id = id))
      ))
    })

    dt <- create_standard_datatable(
      data,
      selection = "none",
      filter = "top",
      escape = FALSE,
      col_defs = list(
        list(visible = FALSE, targets = 0),  # Hide ID column
        list(width = "150px", targets = ncol(data)),  # Actions column
        list(className = "dt-center", targets = ncol(data))
      )
    )

    add_button_handlers(dt, handlers = list(
      list(selector = ".btn-edit", input_id = ns("edit_item")),
      list(selector = ".btn-delete", input_id = ns("delete_item"))
    ))
  })
}, ignoreInit = FALSE)
```

### DataTables in Hidden Divs (Tabs, Panels)

**Problem**: When a DataTable is inside a hidden element (like a tab panel that's not initially visible), Shiny's lazy evaluation means `renderDT` won't execute until the element becomes visible. This can cause tables to not render when switching tabs.

**Solution**: Use `outputOptions()` with `suspendWhenHidden = FALSE` to force rendering even when hidden. You must also initialize the output first before calling `outputOptions()`.

```r
# 1. Initialize empty table first (required for outputOptions to work)
output$my_table <- DT::renderDT({
  create_empty_datatable("")
})

# 2. Observer to update table when trigger fires
observe_event(table_trigger(), {
  if (is.null(selected_item())) return()

  output$my_table <- DT::renderDT({
    data <- get_data(selected_item()$id)
    # ... create datatable
  })
}, ignoreInit = TRUE)

# 3. Force render even when hidden
outputOptions(output, "my_table", suspendWhenHidden = FALSE)
```

**Key points**:
- `outputOptions()` must be called AFTER the output is created (not before)
- Initialize with an empty table first, then update via observer
- Use `ignoreInit = TRUE` on the update observer to avoid double rendering

### CSS Classes

**Layout**:
- `.main-panel` - Main content wrapper
- `.main-content` - Content container
- `.modal-overlay` - Full-screen modal backdrop
- `.modal-content` - Modal dialog container
- `.modal-header`, `.modal-body`, `.modal-footer` - Modal sections
- `.modal-close` - Close button (×)

**Buttons**:
- `.btn-primary-custom` - Primary action (blue #0f60af)
- `.btn-success-custom` - Success action (green #28a745)
- `.btn-secondary-custom` - Secondary action (gray #6c757d)
- `.btn-danger-custom` - Danger action (red #dc3545)
- `.btn-purple-custom` - Purple action (violet #7c3aed)

**Forms**:
- `.form-label` - Form field label
- `.input-error-message` - Validation error text
- `.mb-15` - Margin bottom 15px

**DataTables**:
- `.dt-action-btn` - Action button base
- `.dt-action-btn-warning` - Edit button (yellow)
- `.dt-action-btn-danger` - Delete button (red)

**Info Icons with Tooltips**:
Use `.info-icon` with `data-tooltip` attribute for custom CSS tooltips:

```r
# In UI - info icon with tooltip
tags$span(
  class = "info-icon",
  `data-tooltip` = as.character(i18n$t("tooltip_text_key")),
  HTML("&#x3f;")  # Question mark character
)
```

The tooltip appears on hover using CSS ::after pseudo-element. Features:
- Uses `data-tooltip` attribute (not `title`) for custom styling
- Content is the `?` character using `HTML("&#x3f;")`
- Tooltip appears below the icon with a small arrow
- Semi-transparent delay (0.5s) before showing

---

## Internationalization (i18n)

Translation files are in `inst/translations/`:
- `translation_en.csv` - English
- `translation_fr.csv` - French

**Format**: CSV with columns `base,<language_code>`

**Usage**:
```r
# In UI
i18n$t("translation_key")

# In server (as character for JS)
as.character(i18n$t("translation_key"))
```

---

## Naming Conventions

### R Code

**Functions**:
- `mod_*_ui()`, `mod_*_server()` - Module pattern
- `get_*()` - Data retrieval
- `add_*()`, `update_*()`, `delete_*()` - CRUD operations
- `create_*()` - Factory functions
- `hash_*()`, `verify_*()` - Security functions

**Variables**:
- Use **snake_case** for all R variables and function names
- Reactive values: `editing_id`, `deleting_id`, `data_trigger`
- Module parameters: `id`, `i18n`, `current_user`

**Files**:
- `mod_<name>.R` - Module files
- `fct_<domain>.R` - Function libraries (alphabetical order!)
- `utils_<purpose>.R` - Utility functions
- `app_<component>.R` - Main app components

### CSS

- `.component-name` - Component class
- `.component-name-variant` - Variant modifier

### JavaScript

- Use **camelCase** for functions and variables

---

## Development Checklist

Before submitting code, verify:

- [ ] All observers use `observe_event()` (with underscore)
- [ ] All observers have explicit `ignoreInit` parameter
- [ ] No `tryCatch()` inside `observe_event()`
- [ ] No `shiny::` prefixes
- [ ] No nested `observe_event()` blocks
- [ ] All `output$...` assignments are inside `observe_event()`
- [ ] Validation uses `if()... return()` instead of `req()`
- [ ] Static UI elements are in `mod_*_ui()`, not `renderUI()`
- [ ] Functions in `fct_*.R` files are in alphabetical order
- [ ] Translations added for new UI text

---

## Contact & Support

**Author**: Boris Delange (boris.delange@univ-rennes.fr)

**License**: GPL (>= 3)
