#' Database Functions
#'
#' @description Functions to manage the application database for storing
#' configuration and user preferences
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
  # Get app folder from environment variable (set by run_app)
  app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)

  # Fallback to user config directory if not set
  if (is.na(app_folder) || app_folder == "") {
    db_dir <- rappdirs::user_config_dir("indicate")
  } else {
    # Use app_folder/indicate_files/
    db_dir <- file.path(app_folder, "indicate_files")
  }

  # Create directory if it doesn't exist
  if (!dir.exists(db_dir)) {
    dir.create(db_dir, recursive = TRUE, showWarnings = FALSE)
  }

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
          created_date TEXT,
          updated_at TEXT
        )"
      )
    }
  }

  invisible(NULL)
}

#' Get configuration value
#'
#' @description Retrieve a configuration value from the database
#'
#' @param key Configuration key
#' @param default Default value if key doesn't exist
#'
#' @return Configuration value or default
#' @noRd
get_config_value <- function(key, default = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT value FROM config WHERE key = ?",
    params = list(key)
  )

  if (nrow(result) == 0) {
    return(default)
  }

  return(result$value[1])
}

#' Set configuration value
#'
#' @description Save a configuration value to the database
#'
#' @param key Configuration key
#' @param value Configuration value
#'
#' @return TRUE if successful
#' @noRd
set_config_value <- function(key, value) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Get current timestamp
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Check if key exists
  existing <- DBI::dbGetQuery(
    con,
    "SELECT key FROM config WHERE key = ?",
    params = list(key)
  )

  if (nrow(existing) > 0) {
    # Update existing
    DBI::dbExecute(
      con,
      "UPDATE config SET value = ?, updated_at = ? WHERE key = ?",
      params = list(value, timestamp, key)
    )
  } else {
    # Insert new
    DBI::dbExecute(
      con,
      "INSERT INTO config (key, value, updated_at) VALUES (?, ?, ?)",
      params = list(key, value, timestamp)
    )
  }

  return(TRUE)
}

#' Get all configuration values
#'
#' @description Retrieve all configuration values from the database
#'
#' @return Named list of configuration values
#' @noRd
get_all_config <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(con, "SELECT key, value FROM config")

  if (nrow(result) == 0) {
    return(list())
  }

  # Convert to named list
  config_list <- as.list(setNames(result$value, result$key))

  return(config_list)
}

#' Delete configuration value
#'
#' @description Remove a configuration value from the database
#'
#' @param key Configuration key
#'
#' @return TRUE if successful
#' @noRd
delete_config_value <- function(key) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM config WHERE key = ?",
    params = list(key)
  )

  return(TRUE)
}

#' Get OHDSI Vocabularies folder path
#'
#' @description Get the configured OHDSI Vocabularies folder path
#'
#' @return Folder path or NULL if not configured
#' @export
get_vocab_folder <- function() {
  get_config_value("vocab_folder_path", default = NULL)
}

#' Set OHDSI Vocabularies folder path
#'
#' @description Save the OHDSI Vocabularies folder path
#'
#' @param path Folder path
#'
#' @return TRUE if successful
#' @export
set_vocab_folder <- function(path) {
  set_config_value("vocab_folder_path", path)
}

#' Get DuckDB option status
#'
#' @description Get whether DuckDB database should be used
#'
#' @return TRUE or FALSE
#' @export
get_use_duckdb <- function() {
  value <- get_config_value("use_duckdb", default = "false")
  return(value == "true")
}

#' Set DuckDB option status
#'
#' @description Set whether DuckDB database should be used
#'
#' @param use_duckdb Logical value
#'
#' @return TRUE if successful
#' @export
set_use_duckdb <- function(use_duckdb) {
  value <- if (use_duckdb) "true" else "false"
  set_config_value("use_duckdb", value)
}

#' Get all concept alignments
#'
#' @description Retrieve all concept alignments from the database
#'
#' @return Data frame with all alignments
#' @noRd
get_all_alignments <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT alignment_id, name, description, file_id, original_filename, created_date, updated_at
     FROM concept_alignments
     ORDER BY created_date DESC"
  )

  return(result)
}

#' Add new concept alignment
#'
#' @description Add a new concept alignment to the database
#'
#' @param name Alignment name
#' @param description Alignment description
#' @param file_id Unique file identifier
#' @param original_filename Original filename
#'
#' @return Alignment ID of the newly created alignment
#' @noRd
add_alignment <- function(name, description = "", file_id, original_filename = "") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  created_date <- format(Sys.Date(), "%Y-%m-%d")

  DBI::dbExecute(
    con,
    "INSERT INTO concept_alignments (name, description, file_id, original_filename, created_date, updated_at)
     VALUES (?, ?, ?, ?, ?, ?)",
    params = list(name, description, file_id, original_filename, created_date, timestamp)
  )

  # Get the ID of the newly inserted alignment
  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")

  return(result$id[1])
}

#' Update concept alignment
#'
#' @description Update an existing concept alignment
#'
#' @param alignment_id Alignment ID
#' @param name Alignment name
#' @param description Alignment description
#'
#' @return TRUE if successful
#' @noRd
update_alignment <- function(alignment_id, name, description = "") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "UPDATE concept_alignments
     SET name = ?, description = ?, updated_at = ?
     WHERE alignment_id = ?",
    params = list(name, description, timestamp, alignment_id)
  )

  return(TRUE)
}

#' Delete concept alignment
#'
#' @description Delete a concept alignment from the database
#'
#' @param alignment_id Alignment ID
#'
#' @return TRUE if successful
#' @noRd
delete_alignment <- function(alignment_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM concept_alignments WHERE alignment_id = ?",
    params = list(alignment_id)
  )

  return(TRUE)
}
