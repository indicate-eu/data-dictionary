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
        created_at TEXT,
        updated_at TEXT
      )"
    )

    # Create default admin user (admin/admin)
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    password_hash <- hash_password("admin")

    DBI::dbExecute(
      con,
      "INSERT INTO users (login, password_hash, salt, first_name, last_name, role, affiliation, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
      params = list("admin", password_hash, "", "Admin", "User", "Administrator", "", timestamp, timestamp)
    )
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

  invisible(NULL)
}
