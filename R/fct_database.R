#' Database Functions
#'
#' @description Core database functions for SQLite connection and schema
#' @noRd
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery dbExistsTable

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

# DATABASE CONNECTION ====

#' Get Application Directory
#'
#' @description Get the directory for application data (database, config)
#' @return Character: Path to application directory
#' @noRd
get_app_dir <- function() {
  env_dir <- Sys.getenv("INDICATE_DATA_DIR", "")
  if (env_dir != "" && dir.exists(env_dir)) {
    return(env_dir)
  }

  app_dir <- rappdirs::user_data_dir("indicate", "indicate")
  if (!dir.exists(app_dir)) {
    dir.create(app_dir, recursive = TRUE)
  }

  app_dir
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

  invisible(NULL)
}
