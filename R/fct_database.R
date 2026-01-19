#' Database Functions
#'
#' @description Core database functions for managing the application database
#' connection and schema initialization
#'
#' @noRd
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery dbExistsTable

#' Get database connection
#'
#' @description Create or get connection to the application database
#'
#' @return DBI connection object
#' @noRd
get_db_connection <- function() {
  # Get database directory using centralized path resolution
  db_dir <- get_app_dir()
  db_path <- file.path(db_dir, "indicate.db")

  # Connect to database
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

  # Initialize tables if needed
  init_database(con)

  return(con)
}

#' Initialize database tables
#'
#' @description Create necessary tables if they don't exist
#'
#' @param con DBI connection object
#'
#' @return NULL (invisible)
#' @noRd
init_database <- function(con) {
  # Create config table
  if (!DBI::dbExistsTable(con, "config")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE config (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT
      )"
    )
  }

  # Create concept_alignments table or migrate if needed
  if (!DBI::dbExistsTable(con, "concept_alignments")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE concept_alignments (
        alignment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        file_id TEXT NOT NULL,
        original_filename TEXT,
        column_types TEXT,
        created_date TEXT,
        updated_at TEXT
      )"
    )
  } else {
    # Check if we need to migrate from old schema
    columns <- DBI::dbGetQuery(con, "PRAGMA table_info(concept_alignments)")

    if (!"file_id" %in% columns$name) {
      # Old schema detected, migrate to new schema
      # Drop old table and recreate
      DBI::dbExecute(con, "DROP TABLE concept_alignments")
      DBI::dbExecute(
        con,
        "CREATE TABLE concept_alignments (
          alignment_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          file_id TEXT NOT NULL,
          original_filename TEXT,
          column_types TEXT,
          created_date TEXT,
          updated_at TEXT
        )"
      )
    }

    # Add column_types column if missing
    if (!"column_types" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE concept_alignments ADD COLUMN column_types TEXT")
    }
  }

  # Create user_accesses table for permission profiles
  if (!DBI::dbExistsTable(con, "user_accesses")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE user_accesses (
        user_access_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        created_at TEXT,
        updated_at TEXT
      )"
    )

    # Insert default user access profiles
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

    DBI::dbExecute(
      con,
      "INSERT INTO user_accesses (name, description, created_at, updated_at) VALUES (?, ?, ?, ?)",
      params = list("Admin", "Full access to all features", timestamp, timestamp)
    )

    DBI::dbExecute(
      con,
      "INSERT INTO user_accesses (name, description, created_at, updated_at) VALUES (?, ?, ?, ?)",
      params = list("Read only", "Read-only access to all features", timestamp, timestamp)
    )
  }

  # Create user_access_permissions table for granular permissions
  if (!DBI::dbExistsTable(con, "user_access_permissions")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE user_access_permissions (
        permission_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_access_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        permission TEXT NOT NULL,
        access_level TEXT NOT NULL,
        FOREIGN KEY (user_access_id) REFERENCES user_accesses(user_access_id),
        UNIQUE(user_access_id, category, permission)
      )"
    )

    # Insert default permissions for Admin (full_access for all)
    admin_permissions <- list(
      c("dictionary", "add_general_concept"),
      c("dictionary", "edit_general_concept"),
      c("dictionary", "delete_general_concept"),
      c("dictionary", "add_associated_concept"),
      c("dictionary", "edit_associated_concept"),
      c("dictionary", "delete_associated_concept"),
      c("dictionary", "update_comment"),
      c("dictionary", "update_statistical_summary"),
      c("dictionary", "delete_history"),
      c("projects", "access_projects"),
      c("projects", "add_project"),
      c("projects", "edit_project"),
      c("projects", "delete_project"),
      c("projects", "assign_concepts"),
      c("alignments", "access_concepts_mapping"),
      c("alignments", "add_alignment"),
      c("alignments", "edit_alignment"),
      c("alignments", "delete_alignment"),
      c("alignments", "import_alignment"),
      c("alignments", "add_mapping"),
      c("alignments", "import_mappings"),
      c("alignments", "delete_mapping"),
      c("alignments", "export_mappings"),
      c("alignments", "evaluate_mappings"),
      c("users", "access_users_page"),
      c("users", "add_user"),
      c("users", "edit_user"),
      c("users", "delete_user"),
      c("user_accesses", "add_user_access"),
      c("user_accesses", "edit_user_access"),
      c("user_accesses", "delete_user_access"),
      c("user_accesses", "edit_permissions"),
      c("general_settings", "access_general_settings"),
      c("general_settings", "access_terminologies"),
      c("general_settings", "access_backup_restore"),
      c("dictionary_settings", "access_dictionary_settings"),
      c("dictionary_settings", "import_data_dictionary"),
      c("dictionary_settings", "export_data_dictionary"),
      c("dictionary_settings", "add_unit_conversion"),
      c("dictionary_settings", "edit_unit_conversion"),
      c("dictionary_settings", "delete_unit_conversion"),
      c("dev_tools", "view_dev_tools"),
      c("dev_tools", "execute_code")
    )

    for (perm in admin_permissions) {
      DBI::dbExecute(
        con,
        "INSERT INTO user_access_permissions (user_access_id, category, permission, access_level)
         VALUES (1, ?, ?, 'full_access')",
        params = list(perm[1], perm[2])
      )
    }

    # Insert default permissions for Read only (read_only for all)
    for (perm in admin_permissions) {
      DBI::dbExecute(
        con,
        "INSERT INTO user_access_permissions (user_access_id, category, permission, access_level)
         VALUES (2, ?, ?, 'read_only')",
        params = list(perm[1], perm[2])
      )
    }
  } else {
    # Migration: Add delete_history permission if missing
    existing_perm <- DBI::dbGetQuery(
      con,
      "SELECT 1 FROM user_access_permissions WHERE category = 'dictionary' AND permission = 'delete_history' LIMIT 1"
    )

    if (nrow(existing_perm) == 0) {
      # Get all user access profiles
      user_accesses <- DBI::dbGetQuery(con, "SELECT user_access_id, name FROM user_accesses")

      for (i in seq_len(nrow(user_accesses))) {
        ua_id <- user_accesses$user_access_id[i]
        ua_name <- user_accesses$name[i]

        # Admin gets full_access, others get read_only
        access_level <- if (ua_name == "Admin") "full_access" else "read_only"

        DBI::dbExecute(
          con,
          "INSERT INTO user_access_permissions (user_access_id, category, permission, access_level)
           VALUES (?, 'dictionary', 'delete_history', ?)",
          params = list(ua_id, access_level)
        )
      }
    }
  }

  # Create users table with secure password storage
  if (!DBI::dbExistsTable(con, "users")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        login TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        role TEXT,
        affiliation TEXT,
        user_access_id INTEGER,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (user_access_id) REFERENCES user_accesses(user_access_id)
      )"
    )

    # Create default admin user (admin/admin) with Admin user access
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    password_hash <- hash_password("admin")

    DBI::dbExecute(
      con,
      "INSERT INTO users (login, password_hash, salt, first_name, last_name, role, affiliation, user_access_id, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      params = list("admin", password_hash, "", "Admin", "User", "Administrator", "", 1, timestamp, timestamp)
    )
  } else {
    # Add user_access_id column if missing (migration)
    columns <- DBI::dbGetQuery(con, "PRAGMA table_info(users)")
    if (!"user_access_id" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE users ADD COLUMN user_access_id INTEGER REFERENCES user_accesses(user_access_id)")
      # Set existing users to Admin access by default
      DBI::dbExecute(con, "UPDATE users SET user_access_id = 1 WHERE user_access_id IS NULL")
    }
  }

  # Create imported_mappings table for tracking CSV imports
  if (!DBI::dbExistsTable(con, "imported_mappings")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE imported_mappings (
        import_id INTEGER PRIMARY KEY AUTOINCREMENT,
        alignment_id INTEGER NOT NULL,
        original_filename TEXT NOT NULL,
        import_mode TEXT NOT NULL,
        concepts_count INTEGER NOT NULL,
        imported_by_user_id INTEGER,
        imported_at TEXT NOT NULL,
        FOREIGN KEY (alignment_id) REFERENCES concept_alignments(alignment_id),
        FOREIGN KEY (imported_by_user_id) REFERENCES users(user_id)
      )"
    )
  }

  # Create concept_mappings table
  if (!DBI::dbExistsTable(con, "concept_mappings")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE concept_mappings (
        mapping_id INTEGER PRIMARY KEY AUTOINCREMENT,
        alignment_id INTEGER NOT NULL,
        csv_file_path TEXT NOT NULL,
        row_id INTEGER NOT NULL,
        target_general_concept_id INTEGER,
        target_omop_concept_id INTEGER,
        target_custom_concept_id INTEGER,
        mapped_by_user_id INTEGER,
        imported_user_name TEXT,
        mapping_datetime TEXT,
        imported_mapping_id INTEGER,
        FOREIGN KEY (alignment_id) REFERENCES concept_alignments(alignment_id),
        FOREIGN KEY (mapped_by_user_id) REFERENCES users(user_id),
        FOREIGN KEY (imported_mapping_id) REFERENCES imported_mappings(import_id)
      )"
    )
  }

  # Create mapping_evaluations table
  if (!DBI::dbExistsTable(con, "mapping_evaluations")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE mapping_evaluations (
        evaluation_id INTEGER PRIMARY KEY AUTOINCREMENT,
        alignment_id INTEGER NOT NULL,
        mapping_id INTEGER NOT NULL,
        evaluator_user_id INTEGER,
        imported_user_name TEXT,
        rating INTEGER,
        is_approved INTEGER,
        comment TEXT,
        evaluated_at TEXT,
        FOREIGN KEY (alignment_id) REFERENCES concept_alignments(alignment_id),
        FOREIGN KEY (evaluator_user_id) REFERENCES users(user_id),
        FOREIGN KEY (mapping_id) REFERENCES concept_mappings(mapping_id)
      )"
    )
  }

  # Create mapping_comments table for discussion comments on mappings
  if (!DBI::dbExistsTable(con, "mapping_comments")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE mapping_comments (
        comment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        mapping_id INTEGER NOT NULL,
        user_id INTEGER,
        imported_user_name TEXT,
        comment TEXT NOT NULL,
        evaluation_status INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (mapping_id) REFERENCES concept_mappings(mapping_id),
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )"
    )
  }

  # Create projects table
  if (!DBI::dbExistsTable(con, "projects")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE projects (
        project_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        short_description TEXT NOT NULL,
        creator_first_name TEXT,
        creator_last_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )"
    )
  }

  # Load default projects if table is empty
  projects_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM projects")$n
  if (projects_count == 0) {
    load_default_projects(con)
  }

  # Create project_general_concepts table
  if (!DBI::dbExistsTable(con, "project_general_concepts")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE project_general_concepts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        general_concept_id INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(project_id),
        UNIQUE(project_id, general_concept_id)
      )"
    )
  }

  # Load default project general concepts if table is empty
  pgc_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM project_general_concepts")$n
  if (pgc_count == 0) {
    load_default_project_general_concepts(con)
  }

  # Create project_metadata table
  if (!DBI::dbExistsTable(con, "project_metadata")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE project_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        key TEXT NOT NULL,
        value TEXT,
        FOREIGN KEY (project_id) REFERENCES projects(project_id),
        UNIQUE(project_id, key)
      )"
    )
  }

  # Load default project metadata if table is empty
  pm_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM project_metadata")$n
  if (pm_count == 0) {
    load_default_project_metadata(con)
  }

  # Migration: Add edit_context permission if missing
  existing_perm <- DBI::dbGetQuery(
    con,
    "SELECT 1 FROM user_access_permissions WHERE category = 'projects' AND permission = 'edit_context' LIMIT 1"
  )

  if (nrow(existing_perm) == 0) {
    # Get all user access profiles
    user_accesses <- DBI::dbGetQuery(con, "SELECT user_access_id, name FROM user_accesses")

    for (i in seq_len(nrow(user_accesses))) {
      ua_id <- user_accesses$user_access_id[i]
      ua_name <- user_accesses$name[i]

      # Admin gets full_access, others get read_only
      access_level <- if (ua_name == "Admin") "full_access" else "read_only"

      DBI::dbExecute(
        con,
        "INSERT INTO user_access_permissions (user_access_id, category, permission, access_level)
         VALUES (?, 'projects', 'edit_context', ?)",
        params = list(ua_id, access_level)
      )
    }
  }

  invisible(NULL)
}

#' Get default projects directory path
#'
#' @description Returns the path to the default_projects directory,
#' with fallback to development path if package is not installed.
#'
#' @return Character: Full path to the default_projects directory
#' @noRd
get_default_projects_dir <- function() {
  # Try installed package location first
  pkg_dir <- system.file("extdata", "default_projects", package = "indicate")

  # If not found or empty, use development path
 if (!dir.exists(pkg_dir) || pkg_dir == "") {
    pkg_dir <- file.path("inst", "extdata", "default_projects")
  }

  return(pkg_dir)
}

#' Load default projects from CSV
#'
#' @description Load default projects from the default_projects CSV file
#'
#' @param con DBI connection object
#'
#' @return NULL (invisible)
#' @noRd
load_default_projects <- function(con) {
  csv_path <- file.path(get_default_projects_dir(), "projects.csv")

  if (!file.exists(csv_path)) {
    return(invisible(NULL))
  }

  projects <- read.csv(csv_path, stringsAsFactors = FALSE)

  for (i in seq_len(nrow(projects))) {
    DBI::dbExecute(
      con,
      "INSERT INTO projects (project_id, name, short_description, creator_first_name, creator_last_name, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)",
      params = list(
        projects$project_id[i],
        projects$name[i],
        projects$short_description[i],
        projects$creator_first_name[i],
        projects$creator_last_name[i],
        projects$created_at[i],
        projects$updated_at[i]
      )
    )
  }

  invisible(NULL)
}

#' Load default project general concepts from CSV
#'
#' @description Load default project general concepts from the default_projects CSV file
#'
#' @param con DBI connection object
#'
#' @return NULL (invisible)
#' @noRd
load_default_project_general_concepts <- function(con) {
  csv_path <- file.path(get_default_projects_dir(), "project_general_concepts.csv")

  if (!file.exists(csv_path)) {
    return(invisible(NULL))
  }

  mappings <- read.csv(csv_path, stringsAsFactors = FALSE)

  for (i in seq_len(nrow(mappings))) {
    DBI::dbExecute(
      con,
      "INSERT INTO project_general_concepts (project_id, general_concept_id)
       VALUES (?, ?)",
      params = list(
        mappings$project_id[i],
        mappings$general_concept_id[i]
      )
    )
  }

  invisible(NULL)
}

#' Load default project metadata from CSV
#'
#' @description Load default project metadata from the default_projects CSV file
#'
#' @param con DBI connection object
#'
#' @return NULL (invisible)
#' @noRd
load_default_project_metadata <- function(con) {
  csv_path <- file.path(get_default_projects_dir(), "project_metadata.csv")

  if (!file.exists(csv_path)) {
    return(invisible(NULL))
  }

  metadata <- read.csv(csv_path, stringsAsFactors = FALSE)

  for (i in seq_len(nrow(metadata))) {
    DBI::dbExecute(
      con,
      "INSERT INTO project_metadata (project_id, key, value)
       VALUES (?, ?, ?)",
      params = list(
        metadata$project_id[i],
        metadata$key[i],
        metadata$value[i]
      )
    )
  }

  invisible(NULL)
}

# Projects CRUD Functions ====

#' Get all projects
#'
#' @description Retrieve all projects from the database
#'
#' @return Data frame with all projects
#' @noRd
get_all_projects <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT project_id, name, short_description, creator_first_name, creator_last_name, created_at, updated_at
     FROM projects
     ORDER BY project_id"
  )

  result
}

#' Get project by ID
#'
#' @description Retrieve a specific project
#'
#' @param project_id Project ID
#'
#' @return Data frame with project info, or NULL if not found
#' @noRd
get_project <- function(project_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT project_id, name, short_description, creator_first_name, creator_last_name, created_at, updated_at
     FROM projects
     WHERE project_id = ?",
    params = list(project_id)
  )

  if (nrow(result) == 0) return(NULL)

  result[1, ]
}

#' Add new project
#'
#' @description Create a new project in the database
#'
#' @param name Project name
#' @param short_description Short description
#' @param creator_first_name Creator's first name
#' @param creator_last_name Creator's last name
#'
#' @return Project ID of newly created project, or NULL if name exists
#' @noRd
add_project <- function(name, short_description, creator_first_name = "", creator_last_name = "") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Check if name already exists
  existing <- DBI::dbGetQuery(
    con,
    "SELECT name FROM projects WHERE LOWER(name) = LOWER(?)",
    params = list(name)
  )

  if (nrow(existing) > 0) {
    return(NULL)
  }

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "INSERT INTO projects (name, short_description, creator_first_name, creator_last_name, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?)",
    params = list(name, short_description, creator_first_name, creator_last_name, timestamp, timestamp)
  )

  # Get the ID of the newly inserted project
  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")

  result$id[1]
}

#' Update project
#'
#' @description Update an existing project
#'
#' @param project_id Project ID
#' @param name Project name (optional)
#' @param short_description Short description (optional)
#'
#' @return TRUE if successful, FALSE if name already exists
#' @noRd
update_project <- function(project_id, name = NULL, short_description = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # If name is being updated, check for duplicates
  if (!is.null(name)) {
    existing <- DBI::dbGetQuery(
      con,
      "SELECT project_id FROM projects WHERE LOWER(name) = LOWER(?) AND project_id != ?",
      params = list(name, project_id)
    )

    if (nrow(existing) > 0) {
      return(FALSE)
    }
  }

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  updates <- c()
  params <- list()

  if (!is.null(name)) {
    updates <- c(updates, "name = ?")
    params <- c(params, name)
  }

  if (!is.null(short_description)) {
    updates <- c(updates, "short_description = ?")
    params <- c(params, short_description)
  }

  updates <- c(updates, "updated_at = ?")
  params <- c(params, timestamp)

  params <- c(params, project_id)

  query <- paste0(
    "UPDATE projects SET ",
    paste(updates, collapse = ", "),
    " WHERE project_id = ?"
  )

  DBI::dbExecute(con, query, params = params)

  TRUE
}

#' Delete project
#'
#' @description Delete a project and all associated data
#'
#' @param project_id Project ID
#'
#' @return TRUE if successful
#' @noRd
delete_project <- function(project_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Delete project metadata
  DBI::dbExecute(
    con,
    "DELETE FROM project_metadata WHERE project_id = ?",
    params = list(project_id)
  )

  # Delete project general concepts
  DBI::dbExecute(
    con,
    "DELETE FROM project_general_concepts WHERE project_id = ?",
    params = list(project_id)
  )

  # Delete project
  DBI::dbExecute(
    con,
    "DELETE FROM projects WHERE project_id = ?",
    params = list(project_id)
  )

  TRUE
}

# Project General Concepts CRUD Functions ====

#' Get project general concepts
#'
#' @description Get all general concepts assigned to a project
#'
#' @param project_id Project ID
#'
#' @return Data frame with general concept IDs
#' @noRd
get_project_general_concepts <- function(project_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT general_concept_id FROM project_general_concepts WHERE project_id = ?",
    params = list(project_id)
  )

  result
}

#' Get all project general concepts
#'
#' @description Get all project-general concept mappings
#'
#' @return Data frame with project_id and general_concept_id
#' @noRd
get_all_project_general_concepts <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT project_id, general_concept_id FROM project_general_concepts ORDER BY project_id, general_concept_id"
  )

  result
}

#' Add general concept to project
#'
#' @description Assign a general concept to a project
#'
#' @param project_id Project ID
#' @param general_concept_id General concept ID
#'
#' @return TRUE if successful, FALSE if already exists
#' @noRd
add_project_general_concept <- function(project_id, general_concept_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  tryCatch({
    DBI::dbExecute(
      con,
      "INSERT INTO project_general_concepts (project_id, general_concept_id) VALUES (?, ?)",
      params = list(project_id, general_concept_id)
    )
    TRUE
  }, error = function(e) {
    # Unique constraint violation
    FALSE
  })
}

#' Remove general concept from project
#'
#' @description Remove a general concept assignment from a project
#'
#' @param project_id Project ID
#' @param general_concept_id General concept ID
#'
#' @return TRUE if successful
#' @noRd
remove_project_general_concept <- function(project_id, general_concept_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM project_general_concepts WHERE project_id = ? AND general_concept_id = ?",
    params = list(project_id, general_concept_id)
  )

  TRUE
}

#' Remove all general concepts from project
#'
#' @description Remove all general concept assignments from a project
#'
#' @param project_id Project ID
#'
#' @return TRUE if successful
#' @noRd
remove_all_project_general_concepts <- function(project_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM project_general_concepts WHERE project_id = ?",
    params = list(project_id)
  )

  TRUE
}

# Project Metadata CRUD Functions ====

#' Get project metadata
#'
#' @description Get all metadata for a project
#'
#' @param project_id Project ID
#'
#' @return Data frame with key-value pairs
#' @noRd
get_project_metadata <- function(project_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT key, value FROM project_metadata WHERE project_id = ?",
    params = list(project_id)
  )

  result
}

#' Get project metadata value
#'
#' @description Get a specific metadata value for a project
#'
#' @param project_id Project ID
#' @param key Metadata key
#'
#' @return Value string, or NULL if not found
#' @noRd
get_project_metadata_value <- function(project_id, key) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT value FROM project_metadata WHERE project_id = ? AND key = ?",
    params = list(project_id, key)
  )

  if (nrow(result) == 0) return(NULL)

  result$value[1]
}

#' Set project metadata
#'
#' @description Set a metadata value for a project (insert or update)
#'
#' @param project_id Project ID
#' @param key Metadata key
#' @param value Metadata value
#'
#' @return TRUE if successful
#' @noRd
set_project_metadata <- function(project_id, key, value) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Use INSERT OR REPLACE for upsert behavior
  DBI::dbExecute(
    con,
    "INSERT OR REPLACE INTO project_metadata (project_id, key, value)
     VALUES (?, ?, ?)",
    params = list(project_id, key, value)
  )

  TRUE
}

#' Delete project metadata
#'
#' @description Delete a specific metadata key from a project
#'
#' @param project_id Project ID
#' @param key Metadata key
#'
#' @return TRUE if successful
#' @noRd
delete_project_metadata <- function(project_id, key) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM project_metadata WHERE project_id = ? AND key = ?",
    params = list(project_id, key)
  )

  TRUE
}
