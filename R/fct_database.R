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

  # Create users table with secure password storage
  if (!DBI::dbExistsTable(con, "users")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        login TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        first_name TEXT,
        last_name TEXT,
        role TEXT,
        affiliation TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )"
    )

    # Create default admin user (admin/admin)
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    password_hash <- hash_password("admin")

    DBI::dbExecute(
      con,
      "INSERT INTO users (login, password_hash, salt, first_name, last_name, role, affiliation, is_active, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      params = list("admin", password_hash, "", "Admin", "User", "Administrator", "", 1, timestamp, timestamp)
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

# User Management Functions ---------------------------------------------------

#' Hash password using bcrypt
#'
#' @description Create secure password hash using bcrypt (cost=12)
#' bcrypt is specifically designed for password hashing with:
#' - Built-in salt generation
#' - Adaptive cost factor (resistant to brute-force as hardware improves)
#' - Protection against timing attacks
#'
#' @param password Plain text password
#'
#' @return Hashed password string (contains salt and hash)
#' @noRd
hash_password <- function(password) {
  # bcrypt with cost=12 (recommended, ~300ms per hash on modern CPU)
  # The hash includes the salt, so no need to store it separately
  bcrypt::hashpw(password, bcrypt::gensalt(12))
}

#' Verify password against stored bcrypt hash
#'
#' @description Check if provided password matches stored bcrypt hash
#'
#' @param password Plain text password
#' @param stored_hash Stored bcrypt hash (includes salt)
#'
#' @return Logical TRUE if password matches
#' @noRd
verify_password <- function(password, stored_hash) {
  tryCatch({
    bcrypt::checkpw(password, stored_hash)
  }, error = function(e) {
    FALSE
  })
}

#' Authenticate user
#'
#' @description Verify user credentials and return user information
#'
#' @param login User login
#' @param password User password
#'
#' @return User data frame if authenticated, NULL otherwise
#' @noRd
authenticate_user <- function(login, password) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Get user data
  result <- DBI::dbGetQuery(
    con,
    "SELECT user_id, login, password_hash, first_name, last_name,
            role, affiliation, is_active
     FROM users
     WHERE login = ? AND is_active = 1",
    params = list(login)
  )

  if (nrow(result) == 0) {
    return(NULL)
  }

  user <- result[1, ]

  # Verify password using bcrypt
  if (verify_password(password, user$password_hash)) {
    return(user)
  }

  NULL
}

#' Get all users
#'
#' @description Retrieve all users from the database
#'
#' @return Data frame with all users (excluding password fields)
#' @noRd
get_all_users <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT user_id, login, first_name, last_name, role, affiliation,
            is_active, created_at, updated_at
     FROM users
     ORDER BY created_at DESC"
  )

  result
}

#' Add new user
#'
#' @description Create a new user in the database
#'
#' @param login User login
#' @param password User password
#' @param first_name First name
#' @param last_name Last name
#' @param role User role
#' @param affiliation User affiliation
#'
#' @return User ID of newly created user, or NULL if login exists
#' @noRd
add_user <- function(login, password, first_name = "", last_name = "",
                     role = "", affiliation = "") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Check if login already exists
  existing <- DBI::dbGetQuery(
    con,
    "SELECT login FROM users WHERE login = ?",
    params = list(login)
  )

  if (nrow(existing) > 0) {
    return(NULL)
  }

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  password_hash <- hash_password(password)

  DBI::dbExecute(
    con,
    "INSERT INTO users (login, password_hash, salt, first_name, last_name,
                        role, affiliation, is_active, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(login, password_hash, "", first_name, last_name,
                  role, affiliation, 1, timestamp, timestamp)
  )

  # Get the ID of the newly inserted user
  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")

  result$id[1]
}

#' Update user
#'
#' @description Update an existing user
#'
#' @param user_id User ID
#' @param login User login
#' @param password User password (if NULL, password not changed)
#' @param first_name First name
#' @param last_name Last name
#' @param role User role
#' @param affiliation User affiliation
#' @param is_active Active status
#'
#' @return TRUE if successful
#' @noRd
update_user <- function(user_id, login = NULL, password = NULL,
                        first_name = NULL, last_name = NULL, role = NULL,
                        affiliation = NULL, is_active = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Build update query dynamically based on provided parameters
  updates <- c()
  params <- list()

  if (!is.null(login)) {
    updates <- c(updates, "login = ?")
    params <- c(params, login)
  }

  if (!is.null(password)) {
    password_hash <- hash_password(password)
    updates <- c(updates, "password_hash = ?")
    params <- c(params, password_hash)
  }

  if (!is.null(first_name)) {
    updates <- c(updates, "first_name = ?")
    params <- c(params, first_name)
  }

  if (!is.null(last_name)) {
    updates <- c(updates, "last_name = ?")
    params <- c(params, last_name)
  }

  if (!is.null(role)) {
    updates <- c(updates, "role = ?")
    params <- c(params, role)
  }

  if (!is.null(affiliation)) {
    updates <- c(updates, "affiliation = ?")
    params <- c(params, affiliation)
  }

  if (!is.null(is_active)) {
    updates <- c(updates, "is_active = ?")
    params <- c(params, as.integer(is_active))
  }

  updates <- c(updates, "updated_at = ?")
  params <- c(params, timestamp)

  # Add user_id to end of params
  params <- c(params, user_id)

  query <- paste0(
    "UPDATE users SET ",
    paste(updates, collapse = ", "),
    " WHERE user_id = ?"
  )

  DBI::dbExecute(con, query, params = params)

  TRUE
}

#' Delete user
#'
#' @description Delete a user from the database
#'
#' @param user_id User ID
#'
#' @return TRUE if successful
#' @noRd
delete_user <- function(user_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM users WHERE user_id = ?",
    params = list(user_id)
  )

  TRUE
}
