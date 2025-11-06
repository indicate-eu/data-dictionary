#' CSV File Path Utilities
#'
#' @description Helper functions for resolving CSV file paths across
#' development and production environments
#' @noRd

#' Get CSV File Path
#'
#' @description Resolves the path to a CSV file in the package's extdata directory.
#' Handles both installed package (production) and development environments.
#'
#' @param filename Character: Name of the CSV file (e.g., "general_concepts.csv")
#'
#' @return Character: Full path to the CSV file
#'
#' @details
#' The function attempts to locate the CSV file in two locations:
#' 1. Installed package location: system.file("extdata", "csv", filename, package = "indicate")
#' 2. Development location: file.path("inst", "extdata", "csv", filename)
#'
#' If the file doesn't exist in the installed location or the path is empty,
#' it falls back to the development path.
#'
#' @examples
#' \dontrun{
#'   # Get path to general concepts CSV
#'   csv_path <- get_csv_path("general_concepts.csv")
#'
#'   # Read the CSV file
#'   data <- readr::read_csv(csv_path)
#'
#'   # Write back to the CSV file
#'   readr::write_csv(data, csv_path)
#' }
#'
#' @noRd
get_csv_path <- function(filename) {
  # Try installed package location first
  csv_path <- system.file("extdata", "csv", filename, package = "indicate")

  # If not found or empty, use development path
  if (!file.exists(csv_path) || csv_path == "") {
    csv_path <- file.path("inst", "extdata", "csv", filename)
  }

  return(csv_path)
}
