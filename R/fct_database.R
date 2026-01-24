#' Database Functions
#'
#' @description Core database functions for SQLite connection and schema
#' @noRd
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery dbExistsTable

# CONFIG CRUD ====

#' Get Config Value
#'
#' @description Retrieve a configuration value from the database
#' @param key Configuration key
#' @return Character value or NULL if not found
#' @noRd
get_config_value <- function(key) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT value FROM config WHERE key = ?",
    params = list(key)
  )

  if (nrow(result) == 0) return(NULL)

  result$value[1]
}

#' Set Config Value
#'
#' @description Set a configuration value in the database
#' @param key Configuration key
#' @param value Configuration value
#' @return TRUE if successful
#' @noRd
set_config_value <- function(key, value) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Check if key exists
  existing <- DBI::dbGetQuery(
    con,
    "SELECT key FROM config WHERE key = ?",
    params = list(key)
  )

  if (nrow(existing) > 0) {
    DBI::dbExecute(
      con,
      "UPDATE config SET value = ?, updated_at = ? WHERE key = ?",
      params = list(value, timestamp, key)
    )
  } else {
    DBI::dbExecute(
      con,
      "INSERT INTO config (key, value, created_at, updated_at) VALUES (?, ?, ?, ?)",
      params = list(key, value, timestamp, timestamp)
    )
  }

  TRUE
}

# CONCEPT SETS CRUD ====

#' Add Concept Set
#'
#' @description Create a new concept set
#' @param id Concept set ID (optional, auto-generated if NULL)
#' @param name Concept set name
#' @param description Description
#' @param category Category
#' @param subcategory Subcategory
#' @param etl_comment ETL guidance comment
#' @param tags Comma-separated tags
#' @param created_by Username
#' @return Concept set ID
#' @noRd
add_concept_set <- function(id = NULL, name, description = NULL, category = NULL,
                            subcategory = NULL, etl_comment = NULL, tags = NULL,
                            created_by = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")

  if (is.null(id)) {
    max_id <- DBI::dbGetQuery(con, "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM concept_sets")
    id <- max_id$next_id[1]
  }

  DBI::dbExecute(
    con,
    "INSERT INTO concept_sets (id, name, description, category, subcategory, etl_comment, tags, created_by, created_date, modified_date)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(id, name, description, category, subcategory, etl_comment, tags, created_by, timestamp, timestamp)
  )

  id
}

#' Delete Concept Set
#'
#' @description Delete a concept set
#' @param concept_set_id Concept set ID
#' @return TRUE if successful
#' @noRd
delete_concept_set <- function(concept_set_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(con, "DELETE FROM concept_sets WHERE id = ?", params = list(concept_set_id))

  TRUE
}

#' Get All Concept Sets
#'
#' @description Retrieve all concept sets
#' @param language Language code for translations (not used yet)
#' @return Data frame with concept sets
#' @noRd
get_all_concept_sets <- function(language = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT
      id,
      name,
      description,
      category,
      subcategory,
      tags,
      version,
      created_date,
      modified_date,
      0 AS item_count
    FROM concept_sets
    ORDER BY category, subcategory, name"
  )
}

#' Get Concept Set by ID
#'
#' @description Retrieve a specific concept set
#' @param concept_set_id Concept set ID
#' @param language Language code (not used yet)
#' @return List with concept set data, or NULL if not found
#' @noRd
get_concept_set <- function(concept_set_id, language = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  cs <- DBI::dbGetQuery(
    con,
    "SELECT * FROM concept_sets WHERE id = ?",
    params = list(concept_set_id)
  )

  if (nrow(cs) == 0) return(NULL)

  as.list(cs[1, ])
}

#' Update Concept Set
#'
#' @description Update an existing concept set
#' @param concept_set_id Concept set ID
#' @param ... Fields to update
#' @return TRUE if successful
#' @noRd
update_concept_set <- function(concept_set_id, ...) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  updates <- list(...)
  if (length(updates) == 0) return(TRUE)

  set_clauses <- paste0(names(updates), " = ?", collapse = ", ")
  set_clauses <- paste0(set_clauses, ", modified_date = ?")

  timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  params <- c(unname(updates), timestamp, concept_set_id)

  DBI::dbExecute(
    con,
    paste0("UPDATE concept_sets SET ", set_clauses, " WHERE id = ?"),
    params = params
  )

  TRUE
}

# TAGS CRUD ====

#' Add Tag
#'
#' @description Create a new tag
#' @param name Tag name
#' @param color Tag color (hex code, default: #6c757d)
#' @return Tag ID
#' @noRd
add_tag <- function(name, color = "#6c757d") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "INSERT INTO tags (name, color, created_at, updated_at) VALUES (?, ?, ?, ?)",
    params = list(name, color, timestamp, timestamp)
  )

  # Return the new tag ID
  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")
  result$id[1]
}

#' Delete Tag
#'
#' @description Delete a tag (only if not used by any concept set)
#' @param tag_id Tag ID
#' @return TRUE if deleted, FALSE if tag is in use
#' @noRd
delete_tag <- function(tag_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Get tag name

  tag <- DBI::dbGetQuery(con, "SELECT name FROM tags WHERE tag_id = ?", params = list(tag_id))
  if (nrow(tag) == 0) return(TRUE)

  tag_name <- tag$name[1]

  # Check if tag is used in any concept set
  # Tags are stored as comma-separated values in the tags column
  usage <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS count FROM concept_sets WHERE tags LIKE ? OR tags LIKE ? OR tags LIKE ? OR tags = ?",
    params = list(
      paste0("%,", tag_name, ",%"),
      paste0(tag_name, ",%"),
      paste0("%,", tag_name),
      tag_name
    )
  )

  if (usage$count[1] > 0) {
    return(FALSE)
  }

  DBI::dbExecute(con, "DELETE FROM tags WHERE tag_id = ?", params = list(tag_id))
  TRUE
}

#' Get All Tags
#'
#' @description Retrieve all tags
#' @return Data frame with tags
#' @noRd
get_all_tags <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT tag_id, name, COALESCE(color, '#6c757d') as color, created_at, updated_at FROM tags ORDER BY name"
  )
}

#' Get Tag Usage Count
#'
#' @description Get the number of concept sets using a tag
#' @param tag_name Tag name
#' @return Integer count
#' @noRd
get_tag_usage_count <- function(tag_name) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  usage <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS count FROM concept_sets WHERE tags LIKE ? OR tags LIKE ? OR tags LIKE ? OR tags = ?",
    params = list(
      paste0("%,", tag_name, ",%"),
      paste0(tag_name, ",%"),
      paste0("%,", tag_name),
      tag_name
    )
  )

  usage$count[1]
}

#' Update Tag
#'
#' @description Update a tag name and/or color
#' @param tag_id Tag ID
#' @param name New tag name
#' @param color New tag color (hex code)
#' @return TRUE if successful
#' @noRd
update_tag <- function(tag_id, name, color = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Get old tag name for updating concept sets
  old_tag <- DBI::dbGetQuery(con, "SELECT name FROM tags WHERE tag_id = ?", params = list(tag_id))
  if (nrow(old_tag) == 0) return(FALSE)

  old_name <- old_tag$name[1]
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Update tag name and color
  if (!is.null(color)) {
    DBI::dbExecute(
      con,
      "UPDATE tags SET name = ?, color = ?, updated_at = ? WHERE tag_id = ?",
      params = list(name, color, timestamp, tag_id)
    )
  } else {
    DBI::dbExecute(
      con,
      "UPDATE tags SET name = ?, updated_at = ? WHERE tag_id = ?",
      params = list(name, timestamp, tag_id)
    )
  }

  # Update tag references in concept sets
  # This is a bit complex because tags are comma-separated
  concept_sets <- DBI::dbGetQuery(
    con,
    "SELECT id, tags FROM concept_sets WHERE tags LIKE ? OR tags LIKE ? OR tags LIKE ? OR tags = ?",
    params = list(
      paste0("%,", old_name, ",%"),
      paste0(old_name, ",%"),
      paste0("%,", old_name),
      old_name
    )
  )

  for (i in seq_len(nrow(concept_sets))) {
    tags_list <- strsplit(concept_sets$tags[i], ",")[[1]]
    tags_list <- trimws(tags_list)
    tags_list[tags_list == old_name] <- name
    new_tags <- paste(tags_list, collapse = ",")

    DBI::dbExecute(
      con,
      "UPDATE concept_sets SET tags = ? WHERE id = ?",
      params = list(new_tags, concept_sets$id[i])
    )
  }

  TRUE
}

# DATABASE CONNECTION ====

#' Get Application Directory Path
#'
#' @description Resolves the application directory path using environment variables
#' or default user home directory. Handles both development and production environments.
#' The application data is stored in ~/indicate_files/ by default.
#'
#' @param subdir Character: Subdirectory name (e.g., "concept_mapping").
#'   If NULL, returns the base application directory (indicate_files/).
#' @param create Logical: Create directory if it doesn't exist (default TRUE)
#'
#' @return Character: Full path to the application directory
#' @noRd
get_app_dir <- function(subdir = NULL, create = TRUE) {
  # Check for custom application folder in environment
  app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)

  if (is.na(app_folder) || app_folder == "") {
    # Use default: home directory with indicate_files subfolder
    base_dir <- file.path(path.expand("~"), "indicate_files")
  } else {
    # Use custom application folder
    if (basename(app_folder) == "indicate_files") {
      base_dir <- app_folder
    } else {
      base_dir <- file.path(app_folder, "indicate_files")
    }
  }

  # Append subdirectory if specified
  if (!is.null(subdir)) {
    base_dir <- file.path(base_dir, subdir)
  }

  # Create directory if requested and doesn't exist
  if (create && !dir.exists(base_dir)) {
    dir.create(base_dir, recursive = TRUE, showWarnings = FALSE)
  }

  base_dir
}

#' Get Database Connection
#'
#' @description Create or get connection to the application SQLite database
#' @return DBI connection object
#' @noRd
get_db_connection <- function() {
  db_dir <- get_app_dir()
  db_path <- file.path(db_dir, "indicate.db")

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  init_database(con)

  con
}

#' Initialize Database Tables
#'
#' @description Create necessary tables if they don't exist
#' @param con DBI connection object
#' @return NULL (invisible)
#' @noRd
init_database <- function(con) {
  # Config table
  if (!DBI::dbExistsTable(con, "config")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE config (
        key TEXT PRIMARY KEY,
        value TEXT,
        created_at TEXT,
        updated_at TEXT
      )"
    )
  }

  # Concept Sets table
  if (!DBI::dbExistsTable(con, "concept_sets")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE concept_sets (
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
      )"
    )
  }

  # Tags table
  if (!DBI::dbExistsTable(con, "tags")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE tags (
        tag_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT DEFAULT '#6c757d',
        created_at TEXT,
        updated_at TEXT
      )"
    )
  } else {
    # Migration: add color column if it doesn't exist
    cols <- DBI::dbGetQuery(con, "PRAGMA table_info(tags)")
    if (!("color" %in% cols$name)) {
      DBI::dbExecute(con, "ALTER TABLE tags ADD COLUMN color TEXT DEFAULT '#6c757d'")
    }
  }

  # User Accesses table
  if (!DBI::dbExistsTable(con, "user_accesses")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE user_accesses (
        user_access_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT,
        updated_at TEXT
      )"
    )

    # Insert default user accesses
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    DBI::dbExecute(
      con,
      "INSERT INTO user_accesses (name, description, created_at, updated_at) VALUES
        ('Admin', 'Full access to all features', ?, ?),
        ('Editor', 'Can edit content but not manage users', ?, ?),
        ('Read only', 'Can only view content', ?, ?)",
      params = list(timestamp, timestamp, timestamp, timestamp, timestamp, timestamp)
    )
  }

  # Users table
  if (!DBI::dbExistsTable(con, "users")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE users (
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
      )"
    )

    # Insert default admin user (password: admin)
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    admin_hash <- bcrypt::hashpw("admin", bcrypt::gensalt(12))
    DBI::dbExecute(
      con,
      "INSERT INTO users (login, password_hash, first_name, last_name, role, user_access_id, created_at, updated_at)
       VALUES ('admin', ?, 'Admin', 'User', 'Admin', 1, ?, ?)",
      params = list(admin_hash, timestamp, timestamp)
    )
  }

  invisible(NULL)
}
