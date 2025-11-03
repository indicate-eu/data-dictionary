#' Concept Alignments Functions
#'
#' @description Functions to manage concept alignment CRUD operations
#'
#' @noRd

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
    "SELECT alignment_id, name, description, file_id, original_filename, created_date, updated_at
     FROM concept_alignments
     ORDER BY created_date DESC"
  )

  return(result)
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