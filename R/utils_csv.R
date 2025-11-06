#' CSV File Utilities
#'
#' @description Helper functions for CSV file operations including path resolution
#' and data loading/saving for dictionary CSV files
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

#' Load CSV Data
#'
#' @description Load dictionary data from CSV files
#'
#' @return List containing all data tables
#' @noRd
load_csv_data <- function() {
  csv_dir <- get_package_dir("extdata", "csv")

  # Check if CSV directory exists
  if (!dir.exists(csv_dir)) {
    stop("CSV directory not found. Please run data-raw/convert_excel_to_csv.R first.")
  }

  # Load all CSV files
  general_concepts <- read.csv(
    file.path(csv_dir, "general_concepts.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  use_cases <- read.csv(
    file.path(csv_dir, "use_cases.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  general_concept_use_cases <- read.csv(
    file.path(csv_dir, "general_concept_use_cases.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  concept_mappings <- read.csv(
    file.path(csv_dir, "concept_mappings.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  # Rename is_recommended to recommended for consistency with UI
  if ("is_recommended" %in% names(concept_mappings)) {
    names(concept_mappings)[names(concept_mappings) == "is_recommended"] <- "recommended"
  }

  concept_statistics <- read.csv(
    file.path(csv_dir, "concept_statistics.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  custom_concepts <- read.csv(
    file.path(csv_dir, "custom_concepts.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  unit_conversions <- read.csv(
    file.path(csv_dir, "unit_conversions.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  return(list(
    general_concepts = general_concepts,
    use_cases = use_cases,
    general_concept_use_cases = general_concept_use_cases,
    concept_mappings = concept_mappings,
    concept_statistics = concept_statistics,
    custom_concepts = custom_concepts,
    unit_conversions = unit_conversions
  ))
}

#' Save General Concept Use Cases to CSV
#'
#' @description Save general concept use cases mappings to CSV file
#'
#' @param general_concept_use_cases_data Data frame with mappings
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_general_concept_use_cases_csv <- function(general_concept_use_cases_data) {
  csv_dir <- get_package_dir("extdata", "csv")
  if (!dir.exists(csv_dir)) {
    dir.create(csv_dir, recursive = TRUE)
  }
  write.csv(
    general_concept_use_cases_data,
    file.path(csv_dir, "general_concept_use_cases.csv"),
    row.names = FALSE,
    quote = TRUE
  )
}

#' Save Use Cases to CSV
#'
#' @description Save use cases data to CSV file
#'
#' @param use_cases_data Data frame with use cases
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_use_cases_csv <- function(use_cases_data) {
  csv_dir <- get_package_dir("extdata", "csv")
  if (!dir.exists(csv_dir)) {
    dir.create(csv_dir, recursive = TRUE)
  }
  write.csv(
    use_cases_data,
    file.path(csv_dir, "use_cases.csv"),
    row.names = FALSE,
    quote = TRUE
  )
}