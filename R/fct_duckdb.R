#' DuckDB Functions
#'
#' @description Functions to manage DuckDB database for OHDSI vocabularies
#'
#' @noRd
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbWriteTable dbExistsTable dbListTables dbGetQuery dbExecute
#' @importFrom readr read_tsv cols col_integer col_character col_date
#' @importFrom arrow read_parquet
#' @importFrom dplyr tbl

#' Detect vocabulary file format in a folder
#'
#' @description Detects whether vocabulary files are in CSV or Parquet format
#'
#' @param vocab_folder Path to vocabularies folder
#'
#' @return Character: "parquet", "csv", or NULL if neither found
#' @noRd
detect_vocab_format <- function(vocab_folder) {
  # Check for Parquet files first (preferred)
  if (file.exists(file.path(vocab_folder, "CONCEPT.parquet"))) {
    return("parquet")
  }
  # Fall back to CSV
  if (file.exists(file.path(vocab_folder, "CONCEPT.csv"))) {
    return("csv")
  }
  return(NULL)
}

#' Read vocabulary file (CSV or Parquet)
#'
#' @description Reads a vocabulary file in either CSV or Parquet format
#'
#' @param vocab_folder Path to vocabularies folder
#' @param table_name Table name (e.g., "CONCEPT", "CONCEPT_RELATIONSHIP")
#' @param format File format ("csv" or "parquet")
#' @param col_types Column types specification for CSV (readr format)
#'
#' @return Data frame with vocabulary data
#' @noRd
read_vocab_file <- function(vocab_folder, table_name, format, col_types = NULL) {
  if (format == "parquet") {
    file_path <- file.path(vocab_folder, paste0(table_name, ".parquet"))
    return(as.data.frame(arrow::read_parquet(file_path)))
  } else {
    file_path <- file.path(vocab_folder, paste0(table_name, ".csv"))
    return(readr::read_tsv(file_path, col_types = col_types, show_col_types = FALSE))
  }
}

#' Load Parquet file directly into DuckDB table
#'
#' @description Uses DuckDB's native Parquet support for fast loading
#'
#' @param con DuckDB connection
#' @param vocab_folder Path to vocabularies folder
#' @param table_name Table name (e.g., "CONCEPT", "CONCEPT_RELATIONSHIP")
#'
#' @return NULL (side effect: creates table in DuckDB)
#' @noRd
load_parquet_to_duckdb <- function(con, vocab_folder, table_name) {
  file_path <- file.path(vocab_folder, paste0(table_name, ".parquet"))
  sql <- sprintf(
    "CREATE OR REPLACE TABLE %s AS SELECT * FROM read_parquet('%s')",
    tolower(table_name),
    file_path
  )
  DBI::dbExecute(con, sql)
}

#' Create DuckDB database from CSV or Parquet files
#'
#' @description Create a DuckDB database from OHDSI vocabulary files (CSV or Parquet)
#'
#' @param vocab_folder Path to vocabularies folder containing CSV or Parquet files
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

  # Detect file format
  format <- detect_vocab_format(vocab_folder)

  if (is.null(format)) {
    return(list(
      success = FALSE,
      message = "No vocabulary files found. Expected CONCEPT.csv or CONCEPT.parquet"
    ))
  }

  # Define required tables
  required_tables <- c(
    "CONCEPT",
    "CONCEPT_RELATIONSHIP",
    "CONCEPT_ANCESTOR",
    "CONCEPT_SYNONYM",
    "RELATIONSHIP"
  )

  # File extension based on format
  ext <- if (format == "parquet") ".parquet" else ".csv"

  # Check if all required files exist
  missing_files <- c()
  for (table in required_tables) {
    if (!file.exists(file.path(vocab_folder, paste0(table, ext)))) {
      missing_files <- c(missing_files, paste0(table, ext))
    }
  }

  if (length(missing_files) > 0) {
    return(list(
      success = FALSE,
      message = paste("Missing required files:", paste(missing_files, collapse = ", "))
    ))
  }

  db_path <- get_duckdb_path()
  
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

    # Load tables based on format
    if (format == "parquet") {
      # Use DuckDB native Parquet reading (much faster)
      load_parquet_to_duckdb(con, vocab_folder, "CONCEPT")
      load_parquet_to_duckdb(con, vocab_folder, "CONCEPT_RELATIONSHIP")
      load_parquet_to_duckdb(con, vocab_folder, "CONCEPT_ANCESTOR")
      load_parquet_to_duckdb(con, vocab_folder, "CONCEPT_SYNONYM")
      load_parquet_to_duckdb(con, vocab_folder, "RELATIONSHIP")
    } else {
      # Load CSV files via R (original method)
      concept <- read_vocab_file(
        vocab_folder, "CONCEPT", format,
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
        )
      )
      DBI::dbWriteTable(con, "concept", concept, overwrite = TRUE)

      concept_relationship <- read_vocab_file(
        vocab_folder, "CONCEPT_RELATIONSHIP", format,
        col_types = readr::cols(
          concept_id_1 = readr::col_integer(),
          concept_id_2 = readr::col_integer(),
          relationship_id = readr::col_character(),
          valid_start_date = readr::col_date(format = "%Y%m%d"),
          valid_end_date = readr::col_date(format = "%Y%m%d"),
          invalid_reason = readr::col_character()
        )
      )
      DBI::dbWriteTable(con, "concept_relationship", concept_relationship, overwrite = TRUE)

      concept_ancestor <- read_vocab_file(
        vocab_folder, "CONCEPT_ANCESTOR", format,
        col_types = readr::cols(
          ancestor_concept_id = readr::col_integer(),
          descendant_concept_id = readr::col_integer(),
          min_levels_of_separation = readr::col_integer(),
          max_levels_of_separation = readr::col_integer()
        )
      )
      DBI::dbWriteTable(con, "concept_ancestor", concept_ancestor, overwrite = TRUE)

      concept_synonym <- read_vocab_file(
        vocab_folder, "CONCEPT_SYNONYM", format,
        col_types = readr::cols(
          concept_id = readr::col_integer(),
          concept_synonym_name = readr::col_character(),
          language_concept_id = readr::col_integer()
        )
      )
      DBI::dbWriteTable(con, "concept_synonym", concept_synonym, overwrite = TRUE)

      relationship <- read_vocab_file(
        vocab_folder, "RELATIONSHIP", format,
        col_types = readr::cols(
          relationship_id = readr::col_character(),
          relationship_name = readr::col_character(),
          is_hierarchical = readr::col_integer(),
          defines_ancestry = readr::col_integer(),
          reverse_relationship_id = readr::col_character(),
          relationship_concept_id = readr::col_integer()
        )
      )
      DBI::dbWriteTable(con, "relationship", relationship, overwrite = TRUE)
    }

    # Create indexes for better performance
    DBI::dbExecute(con, "CREATE INDEX idx_concept_id ON concept(concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_code ON concept(concept_code)")
    DBI::dbExecute(con, "CREATE INDEX idx_vocabulary_id ON concept(vocabulary_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_standard_concept ON concept(standard_concept)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_rel_1 ON concept_relationship(concept_id_1)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_rel_2 ON concept_relationship(concept_id_2)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_rel_id ON concept_relationship(relationship_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_ancestor ON concept_ancestor(ancestor_concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_descendant ON concept_ancestor(descendant_concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_synonym_concept ON concept_synonym(concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_relationship_id ON relationship(relationship_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_defines_ancestry ON relationship(defines_ancestry)")

    # Close connection
    DBI::dbDisconnect(con, shutdown = TRUE)

    format_label <- if (format == "parquet") "Parquet" else "CSV"
    return(list(
      success = TRUE,
      message = paste0("DuckDB database created successfully from ", format_label, " files"),
      db_path = db_path,
      format = format
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
#' @description Delete the DuckDB database file from app_folder
#'
#' @return List with success status and message
#' @export
delete_duckdb_database <- function() {
  db_path <- get_duckdb_path()
  
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
#' @description Check if DuckDB database file exists in app_folder
#'
#' @return TRUE if database exists, FALSE otherwise
#' @export
duckdb_exists <- function() {
  db_path <- get_duckdb_path()
  return(file.exists(db_path))
}

#' Get DuckDB database path
#'
#' @description Get the path where DuckDB database should be stored in app_folder/indicate_files
#'
#' @return Path to DuckDB database file
#' @noRd
get_duckdb_path <- function() {
  app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = path.expand("~"))
  indicate_files_folder <- file.path(app_folder, "indicate_files")

  # Create indicate_files folder if it doesn't exist
  if (!dir.exists(indicate_files_folder)) {
    dir.create(indicate_files_folder, recursive = TRUE)
  }

  file.path(indicate_files_folder, "vocabularies.duckdb")
}

#' Load vocabularies from DuckDB
#'
#' @description Load OHDSI vocabularies from DuckDB database using lazy connections
#'
#' @return List with dplyr::tbl connections to concept, concept_relationship, and concept_ancestor tables
#' @export
load_vocabularies_from_duckdb <- function() {
  db_path <- get_duckdb_path()

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
    relationship <- dplyr::tbl(con, "relationship")

    # Return list with lazy connections
    # IMPORTANT: Connection stays open for lazy evaluation
    return(list(
      concept = concept,
      concept_relationship = concept_relationship,
      concept_ancestor = concept_ancestor,
      concept_synonym = concept_synonym,
      relationship = relationship,
      connection = con  # Keep connection alive
    ))

  }, error = function(e) {
    if (exists("con")) {
      try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
    }
    stop(paste("Error loading vocabularies from DuckDB:", e$message))
  })
}
