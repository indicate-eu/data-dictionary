#' Data Dictionary File Utilities
#'
#' @description Helper functions for data dictionary file operations including path resolution
#' and data loading/saving for dictionary CSV files. Files are stored in the
#' user's app_folder/data_dictionary directory and are copied from the package on first launch.
#' @noRd

# List of CSV files managed by the application
CSV_FILES <- c(
  "general_concepts_en.csv",
  "general_concepts_fr.csv",
  "general_concepts_stats.csv",
  "projects.csv",
  "general_concepts_projects.csv",
  "general_concepts_details.csv",
  "custom_concepts.csv",
  "unit_conversions.csv",
  "general_concepts_history.csv",
  "general_concepts_details_history.csv",
  "general_concepts_last_id.txt",
  "custom_concepts_last_id.txt",
  "global_comment.txt"
)

#' Get User Data Dictionary Directory
#'
#' @description Returns the path to the user's data_dictionary directory in app_folder.
#' Creates the directory if it doesn't exist.
#'
#' @return Character: Full path to the user's data_dictionary directory
#'
#' @noRd
get_user_data_dictionary_dir <- function() {
  data_dict_dir <- get_app_dir("data_dictionary")
  return(data_dict_dir)
}

#' Get User CSV Directory (deprecated alias)
#'
#' @description Alias for get_user_data_dictionary_dir() for backward compatibility.
#'
#' @return Character: Full path to the user's data_dictionary directory
#'
#' @noRd
get_user_csv_dir <- function() {
  get_user_data_dictionary_dir()
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

#' Get Package Data Dictionary Directory
#'
#' @description Returns the path to the package's original data dictionary files in extdata.
#' These are the template files that get copied to the user's app_folder.
#'
#' @return Character: Full path to the package's data_dictionary directory
#'
#' @noRd
get_package_data_dictionary_dir <- function() {
  # Try installed package location first
  pkg_dir <- system.file("extdata", "data_dictionary", package = "indicate")

  # If not found or empty, use development path
  if (!dir.exists(pkg_dir) || pkg_dir == "") {
    pkg_dir <- file.path("inst", "extdata", "data_dictionary")
  }

  return(pkg_dir)
}

#' Get Package CSV Directory (deprecated alias)
#'
#' @description Alias for get_package_data_dictionary_dir() for backward compatibility.
#'
#' @return Character: Full path to the package's data_dictionary directory
#'
#' @noRd
get_package_csv_dir <- function() {
  get_package_data_dictionary_dir()
}

#' Initialize User Data Dictionary Files
#'
#' @description Copies data dictionary files from the package's extdata directory to the user's
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
initialize_user_data_dictionary_files <- function() {
  user_dir <- get_user_data_dictionary_dir()
  pkg_dir <- get_package_data_dictionary_dir()

  # Check if package data dictionary directory exists
  if (!dir.exists(pkg_dir)) {
    warning("Package data dictionary directory not found: ", pkg_dir)
    return(invisible(FALSE))
  }

  # Copy each file if it doesn't exist in user directory
  for (filename in CSV_FILES) {
    user_file <- file.path(user_dir, filename)
    pkg_file <- file.path(pkg_dir, filename)

    if (!file.exists(user_file) && file.exists(pkg_file)) {
      file.copy(pkg_file, user_file, overwrite = FALSE)
    }
  }

  return(invisible(TRUE))
}

#' Initialize User CSV Files (deprecated alias)
#'
#' @description Alias for initialize_user_data_dictionary_files() for backward compatibility.
#'
#' @return Invisible TRUE on success
#'
#' @noRd
initialize_user_csv_files <- function() {
  initialize_user_data_dictionary_files()
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

  # Ensure last ID tracking files exist
  initialize_last_id_file()
  initialize_custom_concepts_last_id_file()

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

  # Load general concepts stats (language-independent)
  general_concepts_stats <- read.csv(
    file.path(csv_dir, "general_concepts_stats.csv"),
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )

  # Join stats to general concepts
  general_concepts <- merge(
    general_concepts,
    general_concepts_stats,
    by = "general_concept_id",
    all.x = TRUE
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
    custom_concepts = custom_concepts,
    unit_conversions = unit_conversions
  ))
}

#' Save General Concepts to CSV
#'
#' @description Save general concepts data to CSV file in user's app_folder.
#' This function saves both the language-specific file (category, subcategory, name, comments)
#' and the stats file (statistical_summary) separately.
#'
#' @param general_concepts_data Data frame with general concepts (may include statistical_summary)
#' @param language Character: Language code ("en" or "fr"). Defaults to
#'   INDICATE_LANGUAGE environment variable or "en".
#'
#' @return NULL (side effect: saves files)
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

  # Separate language-specific columns from stats
  language_cols <- c("general_concept_id", "category", "subcategory", "general_concept_name", "comments")
  stats_cols <- c("general_concept_id", "statistical_summary")

  # Save language-specific file (without statistical_summary), sorted by ID
  language_data <- general_concepts_data[, intersect(language_cols, names(general_concepts_data)), drop = FALSE]
  language_data <- language_data[order(language_data$general_concept_id), ]
  general_concepts_file <- paste0("general_concepts_", language, ".csv")
  write.csv(
    language_data,
    file.path(csv_dir, general_concepts_file),
    row.names = FALSE,
    quote = TRUE
  )

  # Save stats file (only if statistical_summary column exists), sorted by ID
  if ("statistical_summary" %in% names(general_concepts_data)) {
    stats_data <- general_concepts_data[, intersect(stats_cols, names(general_concepts_data)), drop = FALSE]
    stats_data <- stats_data[order(stats_data$general_concept_id), ]
    write.csv(
      stats_data,
      file.path(csv_dir, "general_concepts_stats.csv"),
      row.names = FALSE,
      quote = TRUE
    )
  }
}

#' Save General Concepts Stats to CSV
#'
#' @description Save general concepts statistics data to CSV file
#'
#' @param stats_data Data frame with general_concept_id and statistical_summary
#'
#' @return NULL (side effect: saves file)
#' @noRd
save_general_concepts_stats_csv <- function(stats_data) {
  csv_dir <- get_user_csv_dir()
  # Sort by general_concept_id before saving
  stats_data <- stats_data[order(stats_data$general_concept_id), ]
  write.csv(
    stats_data,
    file.path(csv_dir, "general_concepts_stats.csv"),
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

#' Get Next General Concept ID
#'
#' @description Generates the next unique general_concept_id by reading and incrementing
#' the value stored in general_concepts_last_id.txt. This prevents ID reuse even if
#' concepts are deleted, ensuring alignment imports always reference the correct concept.
#'
#' @param general_concepts Data frame with current general concepts (used only for initialization)
#'
#' @return Integer: The next available general_concept_id
#' @noRd
get_next_general_concept_id <- function(general_concepts = NULL) {
  csv_dir <- get_user_csv_dir()
  last_id_file <- file.path(csv_dir, "general_concepts_last_id.txt")


  if (file.exists(last_id_file)) {
    # Read the last used ID
    last_id <- as.integer(readLines(last_id_file, n = 1, warn = FALSE))
    if (is.na(last_id)) last_id <- 0
  } else {
    # Initialize from current data if file doesn't exist
    if (!is.null(general_concepts) && nrow(general_concepts) > 0) {
      last_id <- max(general_concepts$general_concept_id, na.rm = TRUE)
    } else {
      last_id <- 0
    }
  }

  # Increment and save the new ID
  new_id <- last_id + 1
  writeLines(as.character(new_id), last_id_file)

  return(new_id)
}

#' Initialize Last ID File
#'
#' @description Initializes the general_concepts_last_id.txt file based on current data.
#' Called during application startup to ensure the file exists and is up to date.
#'
#' @return Invisible TRUE on success
#' @noRd
initialize_last_id_file <- function() {
  csv_dir <- get_user_csv_dir()
  last_id_file <- file.path(csv_dir, "general_concepts_last_id.txt")

  # Only initialize if file doesn't exist
  if (!file.exists(last_id_file)) {
    # Read all language files to find the max ID
    max_id <- 0

    for (lang in c("en", "fr")) {
      lang_file <- file.path(csv_dir, paste0("general_concepts_", lang, ".csv"))
      if (file.exists(lang_file)) {
        data <- read.csv(lang_file, stringsAsFactors = FALSE)
        if (nrow(data) > 0 && "general_concept_id" %in% names(data)) {
          file_max <- max(data$general_concept_id, na.rm = TRUE)
          if (!is.na(file_max) && file_max > max_id) {
            max_id <- file_max
          }
        }
      }
    }

    # Write the max ID to the file
    writeLines(as.character(max_id), last_id_file)
  }

  return(invisible(TRUE))
}

#' Get Next Custom Concept ID
#'
#' @description Generates the next unique custom_concept_id by reading and incrementing
#' the value stored in custom_concepts_last_id.txt. This prevents ID reuse even if
#' concepts are deleted, ensuring alignment imports always reference the correct concept.
#'
#' @param custom_concepts Data frame with current custom concepts (used only for initialization)
#'
#' @return Integer: The next available custom_concept_id
#' @noRd
get_next_custom_concept_id <- function(custom_concepts = NULL) {
  csv_dir <- get_user_csv_dir()
  last_id_file <- file.path(csv_dir, "custom_concepts_last_id.txt")

  if (file.exists(last_id_file)) {
    # Read the last used ID
    last_id <- as.integer(readLines(last_id_file, n = 1, warn = FALSE))
    if (is.na(last_id)) last_id <- 0
  } else {
    # Initialize from current data if file doesn't exist
    if (!is.null(custom_concepts) && nrow(custom_concepts) > 0) {
      last_id <- max(custom_concepts$custom_concept_id, na.rm = TRUE)
    } else {
      last_id <- 0
    }
  }

  # Increment and save the new ID
  new_id <- last_id + 1
  writeLines(as.character(new_id), last_id_file)

  return(new_id)
}

#' Initialize Custom Concepts Last ID File
#'
#' @description Initializes the custom_concepts_last_id.txt file based on current data.
#' Called during application startup to ensure the file exists and is up to date.
#'
#' @return Invisible TRUE on success
#' @noRd
initialize_custom_concepts_last_id_file <- function() {
  csv_dir <- get_user_csv_dir()
  last_id_file <- file.path(csv_dir, "custom_concepts_last_id.txt")

  # Only initialize if file doesn't exist
  if (!file.exists(last_id_file)) {
    custom_concepts_file <- file.path(csv_dir, "custom_concepts.csv")
    max_id <- 0

    if (file.exists(custom_concepts_file)) {
      data <- read.csv(custom_concepts_file, stringsAsFactors = FALSE)
      if (nrow(data) > 0 && "custom_concept_id" %in% names(data)) {
        file_max <- max(data$custom_concept_id, na.rm = TRUE)
        if (!is.na(file_max) && file_max > max_id) {
          max_id <- file_max
        }
      }
    }

    # Write the max ID to the file
    writeLines(as.character(max_id), last_id_file)
  }

  return(invisible(TRUE))
}

#' Get Comment for a General Concept in the Current Language
#'
#' @description Extracts the comment text for a general concept.
#' Each language has its own CSV file with a 'comments' column containing
#' expert guidance in that language.
#'
#' @param concept_info A data frame containing concept information with a 'comments' column
#' @param lang The current language code (e.g., "en", "fr") - kept for API consistency
#'
#' @return Character string with the comment text, or empty string if not found
#' @noRd
get_comment_for_language <- function(concept_info, lang) {
  if (nrow(concept_info) == 0) return("")

  # Use 'comments' column - each language file has its own comments
  if ("comments" %in% names(concept_info) && !is.na(concept_info$comments[1])) {
    concept_info$comments[1]
  } else {
    ""
  }
}

#' Get Global Comment
#'
#' @description Reads the global comment from the global_comment.txt file
#' in the user's app_folder/data_dictionary directory.
#'
#' @return Character string with the global comment, or empty string if not found
#' @noRd
get_global_comment <- function() {
  file_path <- get_csv_path("global_comment.txt")

  if (!file.exists(file_path)) {
    return("")
  }

  # Read all lines and join with newline
  content <- readLines(file_path, warn = FALSE)
  paste(content, collapse = "\n")
}

#' Save Global Comment
#'
#' @description Saves the global comment to the global_comment.txt file
#' in the user's app_folder/data_dictionary directory.
#'
#' @param comment Character string with the global comment content
#'
#' @return Invisible TRUE on success
#' @noRd
save_global_comment <- function(comment) {
  file_path <- get_csv_path("global_comment.txt")

  # Write content to file
  writeLines(comment, file_path)

  return(invisible(TRUE))
}
