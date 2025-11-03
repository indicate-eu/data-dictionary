#' Concept Mappings Functions
#'
#' @description Functions to manage concept mapping CRUD operations
#'
#' @noRd

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