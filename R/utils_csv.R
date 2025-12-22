#' CSV File Utilities
#'
#' @description Helper functions for CSV file operations including path resolution
#' and data loading/saving for dictionary CSV files. CSV files are stored in the
#' user's app_folder directory and are copied from the package on first launch.
#' @noRd

# List of CSV files managed by the application
CSV_FILES <- c(
  "general_concepts_en.csv",
  "general_concepts_fr.csv",
  "projects.csv",
  "general_concepts_projects.csv",
  "general_concepts_details.csv",
  "general_concepts_details_statistics.csv",
  "custom_concepts.csv",
  "unit_conversions.csv",
  "general_concepts_history.csv",
  "general_concepts_details_history.csv"
)

#' Get User CSV Directory
#'
#' @description Returns the path to the user's CSV directory in app_folder.
#' Creates the directory if it doesn't exist.
#'
#' @return Character: Full path to the user's CSV directory
#'
#' @noRd
get_user_csv_dir <- function() {
  csv_dir <- get_app_dir("csv")
  return(csv_dir)
}

#' Get CSV File Path
#'
#' @description Resolves the path to a CSV file in the user's app_folder directory.
#' This is the primary function for getting paths to user-editable CSV files.
#'
#' @param filename Character: Name of the CSV file (e.g., "general_concepts.csv")
#'
#' @return Character: Full path to the CSV file in the user's app_folder
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
  csv_dir <- get_user_csv_dir()
  return(file.path(csv_dir, filename))
}

#' Get Package CSV Directory
#'
#' @description Returns the path to the package's original CSV files in extdata.
#' These are the template files that get copied to the user's app_folder.
#'
#' @return Character: Full path to the package's CSV directory
#'
#' @noRd
get_package_csv_dir <- function() {
  # Try installed package location first
  pkg_dir <- system.file("extdata", "csv", package = "indicate")

  # If not found or empty, use development path
  if (!dir.exists(pkg_dir) || pkg_dir == "") {
    pkg_dir <- file.path("inst", "extdata", "csv")
  }

  return(pkg_dir)
}

#' Initialize User CSV Files
#'
#' @description Copies CSV files from the package's extdata directory to the user's
#' app_folder if they don't already exist. This ensures users have their own
#' editable copies of the dictionary data.
#'
#' @return Invisible TRUE on success
#'
#' @details
#' This function should be called during application startup (in run_app or app_server).
#' It only copies files that don't already exist in the user's directory, preserving
#' any modifications the user has made.
#'
#' @noRd
initialize_user_csv_files <- function() {
  user_csv_dir <- get_user_csv_dir()
  pkg_csv_dir <- get_package_csv_dir()

  # Check if package CSV directory exists
 if (!dir.exists(pkg_csv_dir)) {
    warning("Package CSV directory not found: ", pkg_csv_dir)
    return(invisible(FALSE))
  }

  # Copy each CSV file if it doesn't exist in user directory
  for (filename in CSV_FILES) {
    user_file <- file.path(user_csv_dir, filename)
    pkg_file <- file.path(pkg_csv_dir, filename)

    if (!file.exists(user_file) && file.exists(pkg_file)) {
      file.copy(pkg_file, user_file, overwrite = FALSE)
    }
  }

  return(invisible(TRUE))
}

#' Load CSV Data
#'
#' @description Load dictionary data from CSV files in the user's app_folder.
#' Initializes user CSV files from package if they don't exist.
#'
#' @param language Character: Language code ("en" or "fr"). Defaults to
#'   INDICATE_LANGUAGE environment variable or "en".
#'
#' @return List containing all data tables
#' @noRd
load_csv_data <- function(language = NULL) {
  # Get language from parameter or environment variable

  if (is.null(language)) {
    language <- Sys.getenv("INDICATE_LANGUAGE", "en")
  }

  # Validate language code
  if (!language %in% c("en", "fr")) {
    language <- "en"
  }

  # Ensure user CSV files exist
  initialize_user_csv_files()

  csv_dir <- get_user_csv_dir()

  # Check if CSV directory exists
  if (!dir.exists(csv_dir)) {
    stop("CSV directory not found: ", csv_dir)
  }

  # Load language-specific general concepts file
  general_concepts_file <- paste0("general_concepts_", language, ".csv")
  general_concepts <- read.csv(
    file.path(csv_dir, general_concepts_file),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  projects <- read.csv(
    file.path(csv_dir, "projects.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  general_concept_projects <- read.csv(
    file.path(csv_dir, "general_concepts_projects.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  concept_mappings <- read.csv(
    file.path(csv_dir, "general_concepts_details.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  concept_statistics <- read.csv(
    file.path(csv_dir, "general_concepts_details_statistics.csv"),
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
    projects = projects,
    general_concept_projects = general_concept_projects,
    concept_mappings = concept_mappings,
    concept_statistics = concept_statistics,
    custom_concepts = custom_concepts,
    unit_conversions = unit_conversions
  ))
}

#' Save General Concepts to CSV
#'
#' @description Save general concepts data to CSV file in user's app_folder
#'
#' @param general_concepts_data Data frame with general concepts
#' @param language Character: Language code ("en" or "fr"). Defaults to
#'   INDICATE_LANGUAGE environment variable or "en".
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_general_concepts_csv <- function(general_concepts_data, language = NULL) {
  # Get language from parameter or environment variable
  if (is.null(language)) {
    language <- Sys.getenv("INDICATE_LANGUAGE", "en")
  }

  # Validate language code
  if (!language %in% c("en", "fr")) {
    language <- "en"
  }

  csv_dir <- get_user_csv_dir()
  general_concepts_file <- paste0("general_concepts_", language, ".csv")
  write.csv(
    general_concepts_data,
    file.path(csv_dir, general_concepts_file),
    row.names = FALSE,
    quote = TRUE
  )
}

#' Save Concept Mappings to CSV
#'
#' @description Save concept mappings (general_concepts_details) to CSV file
#'
#' @param concept_mappings_data Data frame with concept mappings
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_concept_mappings_csv <- function(concept_mappings_data) {
  csv_dir <- get_user_csv_dir()
  write.csv(
    concept_mappings_data,
    file.path(csv_dir, "general_concepts_details.csv"),
    row.names = FALSE,
    quote = TRUE
  )
}

#' Save General Concept Projects to CSV
#'
#' @description Save general concept projects mappings to CSV file
#'
#' @param general_concept_projects_data Data frame with mappings
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_general_concept_projects_csv <- function(general_concept_projects_data) {
  csv_dir <- get_user_csv_dir()
  write.csv(
    general_concept_projects_data,
    file.path(csv_dir, "general_concepts_projects.csv"),
    row.names = FALSE,
    quote = TRUE
  )
}

#' Save Projects to CSV
#'
#' @description Save projects data to CSV file
#'
#' @param projects_data Data frame with projects
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_projects_csv <- function(projects_data) {
  csv_dir <- get_user_csv_dir()
  write.csv(
    projects_data,
    file.path(csv_dir, "projects.csv"),
    row.names = FALSE,
    quote = TRUE
  )
}

#' Save Custom Concepts to CSV
#'
#' @description Save custom concepts data to CSV file
#'
#' @param custom_concepts_data Data frame with custom concepts
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_custom_concepts_csv <- function(custom_concepts_data) {
  csv_dir <- get_user_csv_dir()
  write.csv(
    custom_concepts_data,
    file.path(csv_dir, "custom_concepts.csv"),
    row.names = FALSE,
    quote = TRUE
  )
}

#' Save Concept Statistics to CSV
#'
#' @description Save concept statistics data to CSV file
#'
#' @param concept_statistics_data Data frame with concept statistics
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_concept_statistics_csv <- function(concept_statistics_data) {
  csv_dir <- get_user_csv_dir()
  write.csv(
    concept_statistics_data,
    file.path(csv_dir, "general_concepts_details_statistics.csv"),
    row.names = FALSE,
    quote = TRUE
  )
}

#' Save Unit Conversions to CSV
#'
#' @description Save unit conversions data to CSV file
#'
#' @param unit_conversions_data Data frame with unit conversions
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_unit_conversions_csv <- function(unit_conversions_data) {
  csv_dir <- get_user_csv_dir()
  write.csv(
    unit_conversions_data,
    file.path(csv_dir, "unit_conversions.csv"),
    row.names = FALSE,
    quote = TRUE
  )
}
