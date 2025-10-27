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
