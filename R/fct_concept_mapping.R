#' Concept CRUD Functions
#'
#' @description Functions to manage concept alignments and mappings
#' CRUD operations (Create, Read, Update, Delete)
#'
#' @noRd

# CONCEPT ALIGNMENTS ====

#' Add new concept alignment
#'
#' @description Add a new concept alignment to the database
#'
#' @param name Alignment name
#' @param description Alignment description
#' @param file_id Unique file identifier
#' @param original_filename Original filename
#' @param column_types JSON string with column type definitions
#'
#' @return Alignment ID of the newly created alignment
#' @noRd
add_alignment <- function(name, description = "", file_id, original_filename = "", column_types = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "INSERT INTO concept_alignments (name, description, file_id, original_filename, column_types, created_date, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)",
    params = list(name, description, file_id, original_filename, column_types, timestamp, timestamp)
  )

  # Get the ID of the newly inserted alignment
  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")

  return(result$id[1])
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
    "SELECT alignment_id, name, description, file_id, original_filename, column_types, created_date, updated_at
     FROM concept_alignments
     ORDER BY created_date DESC"
  )

  return(result)
}

#' Apply column types to dataframe
#'
#' @description Apply column types stored as JSON to a dataframe
#'
#' @param df Dataframe to modify
#' @param column_types_json JSON string with column type definitions
#'
#' @return Modified dataframe with applied types
#' @noRd
apply_column_types <- function(df, column_types_json) {
  if (is.null(column_types_json) || is.na(column_types_json) || column_types_json == "") {
    return(df)
  }

  column_types <- tryCatch(
    jsonlite::fromJSON(column_types_json),
    error = function(e) NULL
  )

  if (is.null(column_types)) {
    return(df)
  }

  for (col_name in names(column_types)) {
    if (!col_name %in% colnames(df)) next

    col_type <- column_types[[col_name]]
    df[[col_name]] <- tryCatch({
      switch(col_type,
        "character" = as.character(df[[col_name]]),
        "numeric" = as.numeric(df[[col_name]]),
        "integer" = as.integer(df[[col_name]]),
        "factor" = as.factor(df[[col_name]]),
        "date" = as.Date(df[[col_name]]),
        "datetime" = as.POSIXct(df[[col_name]]),
        "logical" = as.logical(df[[col_name]]),
        df[[col_name]]
      )
    }, error = function(e) df[[col_name]])
  }

  return(df)
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

# CONCEPT MAPPINGS ====

#' Delete concept mapping
#'
#' @description Delete a mapping from the database
#'
#' @param mapping_id Mapping ID to delete
#'
#' @return TRUE if successful
#' @noRd
delete_concept_mapping <- function(mapping_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM concept_mappings WHERE mapping_id = ?",
    params = list(mapping_id)
  )

  TRUE
}

#' Get concept mappings for an alignment
#'
#' @description Retrieve all mappings for a specific alignment from the database
#'
#' @param alignment_id Alignment ID
#'
#' @return Data frame with mapping information
#' @noRd
get_alignment_mappings <- function(alignment_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT * FROM concept_mappings WHERE alignment_id = ?",
    params = list(alignment_id)
  )
}
