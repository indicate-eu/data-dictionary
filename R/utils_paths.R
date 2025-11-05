#' Path Utilities
#'
#' @description Helper functions for resolving application directory paths
#' across development and production environments
#' @noRd

#' Get Application Directory Path
#'
#' @description Resolves the application directory path using environment variables
#' or default user configuration directory. Handles both development
#' and production environments.
#'
#' @param subdir Character: Subdirectory name (e.g., "concept_mapping").
#'   If NULL, returns the base application directory (indicate_files/).
#' @param create Logical: Create directory if it doesn't exist (default TRUE)
#'
#' @return Character: Full path to the application directory
#' @noRd
#'
#' @examples
#' \dontrun{
#'   # Get base application directory
#'   app_dir <- get_app_dir()
#'
#'   # Get concept mapping directory
#'   mapping_dir <- get_app_dir("concept_mapping")
#'
#'   # Get database directory
#'   db_dir <- get_app_dir()
#'   db_path <- file.path(db_dir, "indicate.db")
#'
#'   # Get path without creating directory
#'   temp_dir <- get_app_dir("temp", create = FALSE)
#' }
get_app_dir <- function(subdir = NULL, create = TRUE) {
  # Check for custom application folder in environment
  app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)

  if (is.na(app_folder) || app_folder == "") {
    # Use default user configuration directory
    base_dir <- rappdirs::user_config_dir("indicate")
  } else {
    # Use custom application folder
    base_dir <- file.path(app_folder, "indicate_files")
  }

  # Append subdirectory if specified
  if (!is.null(subdir)) {
    base_dir <- file.path(base_dir, subdir)
  }

  # Create directory if requested and doesn't exist
  if (create && !dir.exists(base_dir)) {
    dir.create(base_dir, recursive = TRUE, showWarnings = FALSE)
  }

  return(base_dir)
}
