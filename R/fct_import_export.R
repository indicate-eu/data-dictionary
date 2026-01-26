#' Import/Export Functions for Concept Sets
#'
#' @description Functions to import and export concept sets from/to ZIP files
#'
#' @noRd

#' Import concept sets from ZIP file
#'
#' @description Imports concept sets from a ZIP file containing JSON files
#'              Supports two structures: JSON at root or in concept_sets/ folder
#'
#' @param zip_file Path to ZIP file
#' @param mode Import mode: "add" (add to existing) or "replace" (replace all)
#' @param language Language code for default language (default: "en")
#'
#' @return List with success status, count of imported concept sets, and any errors
#' @noRd
import_concept_sets_from_zip <- function(zip_file, mode = "add", language = "en") {
  tryCatch({
    # Create temporary directory for extraction
    temp_dir <- tempfile()
    dir.create(temp_dir)
    on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

    # Extract ZIP
    utils::unzip(zip_file, exdir = temp_dir)

    # Find JSON files - check both root and concept_sets/ folder
    json_files <- list.files(temp_dir, pattern = "\\.json$", full.names = TRUE, recursive = FALSE)

    # If no JSON at root, check for concept_sets/ folder
    if (length(json_files) == 0) {
      concept_sets_dir <- file.path(temp_dir, "concept_sets")
      if (dir.exists(concept_sets_dir)) {
        json_files <- list.files(concept_sets_dir, pattern = "\\.json$", full.names = TRUE, recursive = FALSE)
      }
    }

    # Filter out README files
    json_files <- json_files[!grepl("README", basename(json_files), ignore.case = TRUE)]

    if (length(json_files) == 0) {
      return(list(
        success = FALSE,
        count = 0,
        message = "no_json_files_found"
      ))
    }

    # If mode is "replace", delete all existing concept sets
    if (mode == "replace") {
      con <- get_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Delete all concept sets (cascade will handle related tables)
      DBI::dbExecute(con, "DELETE FROM concept_sets")
    }

    # Import each JSON file
    imported_count <- 0
    errors <- character()

    for (json_file in json_files) {
      result <- import_concept_set_from_json(json_file, language = language)

      if (!is.null(result)) {
        imported_count <- imported_count + 1
      } else {
        errors <- c(errors, basename(json_file))
      }
    }

    return(list(
      success = TRUE,
      count = imported_count,
      errors = errors,
      message = if (length(errors) > 0) {
        sprintf("Imported %d concept sets, %d failed", imported_count, length(errors))
      } else {
        sprintf("Successfully imported %d concept sets", imported_count)
      }
    ))

  }, error = function(e) {
    return(list(
      success = FALSE,
      count = 0,
      message = paste("Error:", e$message)
    ))
  })
}
