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

    # Import each JSON file with appropriate mode handling
    imported_count <- 0
    updated_count <- 0
    skipped_count <- 0
    errors <- character()

    con <- get_db_connection()
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    for (json_file in json_files) {
      # Read JSON to get the concept set ID
      json_data <- tryCatch({
        jsonlite::fromJSON(json_file)
      }, error = function(e) {
        errors <- c(errors, basename(json_file))
        return(NULL)
      })

      if (is.null(json_data)) next

      concept_set_id <- json_data$id

      # Check if concept set already exists
      existing <- DBI::dbGetQuery(
        con,
        "SELECT id FROM concept_sets WHERE id = ?",
        params = list(concept_set_id)
      )

      is_update <- FALSE

      if (mode == "add") {
        # Add mode: skip if exists
        if (nrow(existing) > 0) {
          skipped_count <- skipped_count + 1
          next
        }
      } else if (mode == "replace") {
        # Replace mode: delete existing before importing
        if (nrow(existing) > 0) {
          DBI::dbExecute(
            con,
            "DELETE FROM concept_sets WHERE id = ?",
            params = list(concept_set_id)
          )
          is_update <- TRUE
        }
      }

      # Import the concept set
      result <- import_concept_set_from_json(json_file, language = language)

      if (!is.null(result)) {
        if (is_update) {
          updated_count <- updated_count + 1
        } else {
          imported_count <- imported_count + 1
        }
      } else {
        errors <- c(errors, basename(json_file))
      }
    }

    # Build message based on mode and results
    if (mode == "add") {
      total_processed <- imported_count + skipped_count
      message_text <- sprintf(
        "Imported %d new concept sets, %d skipped (already exist)",
        imported_count, skipped_count
      )
    } else {
      total_processed <- imported_count + updated_count
      message_text <- sprintf(
        "Imported %d new concept sets, %d updated",
        imported_count, updated_count
      )
    }

    if (length(errors) > 0) {
      message_text <- sprintf("%s, %d failed", message_text, length(errors))
    }

    return(list(
      success = TRUE,
      count = total_processed,
      imported = imported_count,
      updated = updated_count,
      skipped = skipped_count,
      errors = errors,
      message = message_text
    ))

  }, error = function(e) {
    return(list(
      success = FALSE,
      count = 0,
      message = paste("Error:", e$message)
    ))
  })
}
