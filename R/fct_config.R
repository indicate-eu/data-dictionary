#' Configuration Functions
#'
#' @description Functions to manage application configuration settings
#' stored in the database and static application configuration
#'
#' @noRd

#' Check if running in a container environment
#'
#' @description Detects if the application is running inside a Docker container
#' by checking the INDICATE_ENV environment variable
#'
#' @return TRUE if running in container, FALSE otherwise
#' @noRd
is_container <- function() {

  Sys.getenv("INDICATE_ENV") == "docker"
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

#' Get Application Configuration
#'
#' @description Returns the configuration settings for the INDICATE application
#'
#' @return A list containing configuration parameters
#' @noRd
get_config <- function() {
  list(
    # FHIR configuration - Base URLs for terminology services
    fhir_base_url = list(
      SNOMED = "https://tx.fhir.org/r4",
      LOINC = "https://tx.fhir.org/r4",
      ICD10 = "https://tx.fhir.org/r4",
      UCUM = "https://tx.fhir.org/r4",
      RxNorm = "https://tx.fhir.org/r4"
    ),
    
    # FHIR system identifiers for each vocabulary
    fhir_systems = list(
      SNOMED = "http://snomed.info/sct",
      LOINC = "http://loinc.org",
      ICD10 = "http://hl7.org/fhir/sid/icd-10",
      UCUM = "http://unitsofmeasure.org",
      RxNorm = "http://www.nlm.nih.gov/research/umls/rxnorm"
    ),
    
    # Vocabularies that should show "No link available" for FHIR
    fhir_no_link_vocabularies = c("RxNorm Extension"),
    
    # External links
    athena_base_url = "https://athena.ohdsi.org/search-terms/terms"
  )
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

#' Get OHDSI mappings last sync time
#'
#' @description Retrieve the last synchronization time for OHDSI relationships mappings
#'
#' @return POSIXct timestamp or NULL if never synced
#' @noRd
get_ohdsi_mappings_sync <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))
  
  result <- DBI::dbGetQuery(
    con,
    "SELECT value FROM config WHERE key = 'ohdsi_mappings_last_sync'"
  )
  
  if (nrow(result) == 0 || is.na(result$value[1])) {
    return(NULL)
  }
  
  # Convert string to POSIXct
  as.POSIXct(result$value[1], tz = "UTC")
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

#' Get OHDSI Vocabularies folder path
#'
#' @description Get the configured OHDSI Vocabularies folder path
#'
#' @return Folder path or NULL if not configured
#' @export
get_vocab_folder <- function() {
  get_config_value("vocab_folder_path", default = NULL)
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

#' Set OHDSI mappings last sync time
#'
#' @description Save the last synchronization time for OHDSI relationships mappings
#'
#' @param timestamp POSIXct timestamp (defaults to current time)
#'
#' @return TRUE if successful
#' @noRd
set_ohdsi_mappings_sync <- function(timestamp = Sys.time()) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Convert timestamp to string
  timestamp_str <- format(timestamp, "%Y-%m-%d %H:%M:%S", tz = "UTC")

  DBI::dbExecute(
    con,
    "INSERT OR REPLACE INTO config (key, value, updated_at) VALUES ('ohdsi_mappings_last_sync', ?, ?)",
    params = list(timestamp_str, format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  )

  TRUE
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