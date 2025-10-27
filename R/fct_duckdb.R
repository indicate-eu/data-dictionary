#' DuckDB Functions
#'
#' @description Functions to manage DuckDB database for OHDSI vocabularies
#'
#' @noRd
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbWriteTable dbExistsTable dbListTables dbGetQuery dbExecute
#' @importFrom readr read_tsv cols col_integer col_character col_date
#' @importFrom dplyr tbl

#' Get DuckDB database path
#'
#' @description Get the path where DuckDB database should be stored
#'
#' @param vocab_folder Path to vocabularies folder
#'
#' @return Path to DuckDB database file
#' @noRd
get_duckdb_path <- function(vocab_folder) {
  file.path(vocab_folder, "vocabularies.duckdb")
}

#' Create DuckDB database from CSV files
#'
#' @description Create a DuckDB database from OHDSI vocabulary CSV files
#'
#' @param vocab_folder Path to vocabularies folder containing CSV files
#'
#' @return List with success status and message
#' @export
create_duckdb_database <- function(vocab_folder) {
  if (is.null(vocab_folder) || !dir.exists(vocab_folder)) {
    return(list(
      success = FALSE,
      message = "Invalid vocabularies folder path"
    ))
  }

  # Define required files
  required_files <- c(
    "CONCEPT.csv",
    "CONCEPT_RELATIONSHIP.csv",
    "CONCEPT_ANCESTOR.csv",
    "CONCEPT_SYNONYM.csv"
  )

  # Check if all required files exist
  missing_files <- c()
  for (file in required_files) {
    if (!file.exists(file.path(vocab_folder, file))) {
      missing_files <- c(missing_files, file)
    }
  }

  if (length(missing_files) > 0) {
    return(list(
      success = FALSE,
      message = paste("Missing required files:", paste(missing_files, collapse = ", "))
    ))
  }

  db_path <- get_duckdb_path(vocab_folder)

  # Force close all DuckDB connections before removing the file
  if (file.exists(db_path)) {
    # Try to disconnect all DuckDB connections
    tryCatch({
      # Get all DuckDB drivers and disconnect them
      all_cons <- DBI::dbListConnections(duckdb::duckdb())
      for (con in all_cons) {
        try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
      }
    }, error = function(e) {
      # Ignore errors during cleanup
    })

    # Force garbage collection multiple times
    gc()
    gc()
    Sys.sleep(0.5)

    # Try to remove the file
    unlink(db_path)

    # If file still exists, it's locked - return error
    if (file.exists(db_path)) {
      return(list(
        success = FALSE,
        message = "Cannot delete existing database file. Please restart R and try again."
      ))
    }
  }

  tryCatch({
    # Create DuckDB connection
    drv <- duckdb::duckdb(dbdir = db_path, read_only = FALSE)
    con <- DBI::dbConnect(drv)

    # Load CONCEPT table
    concept <- readr::read_tsv(
      file.path(vocab_folder, "CONCEPT.csv"),
      col_types = readr::cols(
        concept_id = readr::col_integer(),
        concept_name = readr::col_character(),
        domain_id = readr::col_character(),
        vocabulary_id = readr::col_character(),
        concept_class_id = readr::col_character(),
        standard_concept = readr::col_character(),
        concept_code = readr::col_character(),
        valid_start_date = readr::col_date(format = "%Y%m%d"),
        valid_end_date = readr::col_date(format = "%Y%m%d"),
        invalid_reason = readr::col_character()
      ),
      show_col_types = FALSE
    )
    DBI::dbWriteTable(con, "concept", concept, overwrite = TRUE)

    # Load CONCEPT_RELATIONSHIP table
    concept_relationship <- readr::read_tsv(
      file.path(vocab_folder, "CONCEPT_RELATIONSHIP.csv"),
      col_types = readr::cols(
        concept_id_1 = readr::col_integer(),
        concept_id_2 = readr::col_integer(),
        relationship_id = readr::col_character(),
        valid_start_date = readr::col_date(format = "%Y%m%d"),
        valid_end_date = readr::col_date(format = "%Y%m%d"),
        invalid_reason = readr::col_character()
      ),
      show_col_types = FALSE
    )
    DBI::dbWriteTable(con, "concept_relationship", concept_relationship, overwrite = TRUE)

    # Load CONCEPT_ANCESTOR table
    concept_ancestor <- readr::read_tsv(
      file.path(vocab_folder, "CONCEPT_ANCESTOR.csv"),
      col_types = readr::cols(
        ancestor_concept_id = readr::col_integer(),
        descendant_concept_id = readr::col_integer(),
        min_levels_of_separation = readr::col_integer(),
        max_levels_of_separation = readr::col_integer()
      ),
      show_col_types = FALSE
    )
    DBI::dbWriteTable(con, "concept_ancestor", concept_ancestor, overwrite = TRUE)

    # Load CONCEPT_SYNONYM table
    concept_synonym <- readr::read_tsv(
      file.path(vocab_folder, "CONCEPT_SYNONYM.csv"),
      col_types = readr::cols(
        concept_id = readr::col_integer(),
        concept_synonym_name = readr::col_character(),
        language_concept_id = readr::col_integer()
      ),
      show_col_types = FALSE
    )
    DBI::dbWriteTable(con, "concept_synonym", concept_synonym, overwrite = TRUE)

    # Create indexes for better performance
    DBI::dbExecute(con, "CREATE INDEX idx_concept_id ON concept(concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_code ON concept(concept_code)")
    DBI::dbExecute(con, "CREATE INDEX idx_vocabulary_id ON concept(vocabulary_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_standard_concept ON concept(standard_concept)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_rel_1 ON concept_relationship(concept_id_1)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_rel_2 ON concept_relationship(concept_id_2)")
    DBI::dbExecute(con, "CREATE INDEX idx_ancestor ON concept_ancestor(ancestor_concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_descendant ON concept_ancestor(descendant_concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_synonym_concept ON concept_synonym(concept_id)")

    # Close connection
    DBI::dbDisconnect(con, shutdown = TRUE)

    return(list(
      success = TRUE,
      message = "DuckDB database created successfully",
      db_path = db_path
    ))

  }, error = function(e) {
    # Clean up on error
    if (exists("con")) {
      try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
    }
    if (file.exists(db_path)) {
      unlink(db_path)
    }

    return(list(
      success = FALSE,
      message = paste("Error creating DuckDB database:", e$message)
    ))
  })
}

#' Delete DuckDB database
#'
#' @description Delete the DuckDB database file
#'
#' @param vocab_folder Path to vocabularies folder
#'
#' @return List with success status and message
#' @export
delete_duckdb_database <- function(vocab_folder) {
  if (is.null(vocab_folder) || !dir.exists(vocab_folder)) {
    return(list(
      success = FALSE,
      message = "Invalid vocabularies folder path"
    ))
  }

  db_path <- get_duckdb_path(vocab_folder)

  if (!file.exists(db_path)) {
    return(list(
      success = TRUE,
      message = "DuckDB database does not exist"
    ))
  }

  tryCatch({
    # Force garbage collection to close any lingering connections
    gc()

    # Small delay to ensure connections are fully closed
    Sys.sleep(0.5)

    unlink(db_path)

    return(list(
      success = TRUE,
      message = "DuckDB database deleted successfully"
    ))
  }, error = function(e) {
    return(list(
      success = FALSE,
      message = paste("Error deleting DuckDB database:", e$message)
    ))
  })
}

#' Check if DuckDB database exists
#'
#' @description Check if DuckDB database file exists
#'
#' @param vocab_folder Path to vocabularies folder
#'
#' @return TRUE if database exists, FALSE otherwise
#' @export
duckdb_exists <- function(vocab_folder) {
  if (is.null(vocab_folder) || !dir.exists(vocab_folder)) {
    return(FALSE)
  }

  db_path <- get_duckdb_path(vocab_folder)
  return(file.exists(db_path))
}

#' Load vocabularies from DuckDB
#'
#' @description Load OHDSI vocabularies from DuckDB database using lazy connections
#'
#' @param vocab_folder Path to vocabularies folder
#'
#' @return List with dplyr::tbl connections to concept, concept_relationship, and concept_ancestor tables
#' @export
load_vocabularies_from_duckdb <- function(vocab_folder) {
  if (is.null(vocab_folder) || !dir.exists(vocab_folder)) {
    stop("Invalid vocabularies folder path")
  }

  db_path <- get_duckdb_path(vocab_folder)

  if (!file.exists(db_path)) {
    stop("DuckDB database does not exist")
  }

  tryCatch({
    # Connect to DuckDB
    drv <- duckdb::duckdb(dbdir = db_path, read_only = TRUE)
    con <- DBI::dbConnect(drv)

    # Create lazy dplyr::tbl connections (queries are executed on-demand)
    concept <- dplyr::tbl(con, "concept")
    concept_relationship <- dplyr::tbl(con, "concept_relationship")
    concept_ancestor <- dplyr::tbl(con, "concept_ancestor")
    concept_synonym <- dplyr::tbl(con, "concept_synonym")

    # Return list with lazy connections
    # IMPORTANT: Connection stays open for lazy evaluation
    return(list(
      concept = concept,
      concept_relationship = concept_relationship,
      concept_ancestor = concept_ancestor,
      concept_synonym = concept_synonym,
      connection = con  # Keep connection alive
    ))

  }, error = function(e) {
    if (exists("con")) {
      try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
    }
    stop(paste("Error loading vocabularies from DuckDB:", e$message))
  })
}
