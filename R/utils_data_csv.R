#' Load CSV Data
#'
#' @description Load dictionary data from CSV files
#'
#' @return List containing all data tables
#' @noRd
load_csv_data <- function() {
  csv_dir <- app_sys("extdata", "csv")

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
