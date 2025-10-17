#' Load INDICATE Dataset
#'
#' @description Load and preprocess the INDICATE minimal dataset from Excel file
#'
#' @param file_path Path to the Excel file. If NULL, uses the default path in inst/extdata
#'
#' @return A list containing the processed data and comments
#' @noRd
#'
#' @importFrom readxl excel_sheets read_xlsx
#' @importFrom purrr map_df
#' @importFrom dplyr mutate across
load_indicate_data <- function(file_path = NULL) {

  # Use default path if not provided
  if (is.null(file_path)) {
    file_path <- app_sys("extdata", "minimal_dataset.xlsx")
  }

  # Check if file exists
  if (!file.exists(file_path)) {
    stop("Dataset file not found at: ", file_path)
  }

  # Define expected column types
  col_types <- c(
    category = "text",
    subcategory = "text",
    general_concept_name = "text",
    concept_name = "text",
    vocabulary_id = "text",
    concept_code = "text",
    omop_concept_id = "numeric",
    unit_concept_name = "text",
    omop_unit_concept_id = "numeric",
    data_type = "text",
    omop_table = "text",
    omop_column = "text",
    omop_domain_id = "text",
    ehden_rows_count = "numeric",
    ehden_num_data_sources = "numeric",
    loinc_rank = "numeric",
    recommended = "text",
    uc1 = "text", uc2 = "text", uc3 = "text",
    uc4 = "text", uc5 = "text", uc6 = "text"
  )

  # Load Excel sheets (excluding comments and unit_conversions)
  all_sheets <- excel_sheets(file_path)
  regular_sheets <- all_sheets[!all_sheets %in% c("comments", "unit_conversions")]

  # Load and combine data from all sheets
  data <- map_df(regular_sheets, function(sheet) {
    read_xlsx(
      file_path,
      sheet = sheet,
      col_types = rep("text", length(col_types)),
      na = "NA"
    ) %>%
      mutate(source_sheet = sheet)
  })

  # Load comments separately
  comments <- read_xlsx(file_path, sheet = "comments")

  # Data preprocessing
  data <- data %>%
    mutate(
      category = factor(category),
      subcategory = factor(subcategory),
      across(starts_with("uc"), factor)
    )

  # Transform "X" markers to boolean values
  columns_to_convert <- c("recommended", paste0("uc", 1:6))
  for (col in columns_to_convert) {
    if (col %in% names(data)) {
      data[[col]] <- ifelse(
        is.na(data[[col]]),
        FALSE,
        ifelse(data[[col]] == "X", TRUE, FALSE)
      )
    }
  }

  list(
    data = data,
    comments = comments
  )
}
