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

#' Import target concept mappings from alignment creation
#'
#' @description Import mappings from target_concept_id column when creating an alignment.
#' Imports all mappings regardless of whether the target concept exists in INDICATE.
#'
#' @param alignment_id Alignment ID
#' @param source_data Data frame with source data including target_concept_id column
#' @param csv_filename CSV filename for the alignment
#' @param user_id User ID performing the import
#' @param original_filename Original filename for the import record
#'
#' @return Number of mappings imported
#' @noRd
import_target_concept_mappings <- function(alignment_id, source_data, csv_filename, user_id, original_filename) {
  if (!"target_concept_id" %in% colnames(source_data)) {
    return(0)
  }

  # Filter rows with valid target_concept_id
  mappings_to_import <- source_data[!is.na(source_data$target_concept_id) & source_data$target_concept_id != "", ]

  if (nrow(mappings_to_import) == 0) {
    return(0)
  }

  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Start transaction
 DBI::dbBegin(con)

  tryCatch({
    # Create import record
    DBI::dbExecute(
      con,
      "INSERT INTO imported_mappings (alignment_id, original_filename, import_mode, concepts_count, imported_by_user_id, imported_at)
       VALUES (?, ?, ?, 0, ?, ?)",
      params = list(alignment_id, original_filename, "initial", user_id, timestamp)
    )

    import_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]

    imported_count <- 0

    # Process each row with a target_concept_id
    for (i in seq_len(nrow(source_data))) {
      target_id <- source_data$target_concept_id[i]

      # Skip empty or NA values
      if (is.na(target_id) || target_id == "") {
        next
      }

      # Convert to integer
      target_concept_id <- suppressWarnings(as.integer(target_id))
      if (is.na(target_concept_id)) {
        next
      }

      # Use mapping_id as source_concept_index (1-based index)
      source_concept_index <- if ("mapping_id" %in% colnames(source_data)) {
        source_data$mapping_id[i]
      } else {
        i
      }

      # Create unique csv_mapping_id
      max_id <- DBI::dbGetQuery(
        con,
        "SELECT COALESCE(MAX(csv_mapping_id), 0) as max_id FROM concept_mappings WHERE csv_file_path = ?",
        params = list(csv_filename)
      )$max_id[1]

      # Insert mapping
      DBI::dbExecute(
        con,
        "INSERT INTO concept_mappings (alignment_id, csv_file_path, csv_mapping_id, source_concept_index,
                                       target_omop_concept_id, imported_mapping_id, mapping_datetime)
         VALUES (?, ?, ?, ?, ?, ?, ?)",
        params = list(alignment_id, csv_filename, max_id + 1, source_concept_index, target_concept_id, import_id, timestamp)
      )

      imported_count <- imported_count + 1
    }

    # Update import record with actual count
    DBI::dbExecute(
      con,
      "UPDATE imported_mappings SET concepts_count = ? WHERE import_id = ?",
      params = list(imported_count, import_id)
    )

    DBI::dbCommit(con)

    return(imported_count)
  }, error = function(e) {
    DBI::dbRollback(con)
    warning("Failed to import target concept mappings: ", e$message)
    return(0)
  })
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
