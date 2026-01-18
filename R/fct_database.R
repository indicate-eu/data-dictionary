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

  invisible(NULL)
}
