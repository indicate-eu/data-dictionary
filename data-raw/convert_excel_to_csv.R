# Script to convert minimal_data_dictionary.xlsx to CSV files
# This script should be run manually when updating the dictionary

library(readxl)
library(dplyr)
library(tidyr)
library(purrr)

# Paths
excel_path <- "inst/extdata/minimal_data_dictionary.xlsx"
csv_dir <- "inst/extdata/csv"

# Create CSV directory if it doesn't exist
if (!dir.exists(csv_dir)) {
  dir.create(csv_dir, recursive = TRUE)
}

# Get all sheets except comments and unit_conversions
all_sheets <- excel_sheets(excel_path)
data_sheets <- setdiff(all_sheets, c("comments", "unit_conversions"))

message("Reading Excel sheets...")

# Read all data sheets and combine
all_data <- map_dfr(data_sheets, function(sheet_name) {
  message("  Reading sheet: ", sheet_name)

  col_types <- c(
    "text", "text", "text", "text", "text", "text", "numeric",
    "text", "text", "text", "text", "text", "text", "numeric",
    "text", "text", "text", "text", "text", "text", "text", "text", "text"
  )

  read_excel(excel_path, sheet = sheet_name, col_types = col_types) %>%
    mutate(source_sheet = sheet_name)
})

# Read comments and unit_conversions
comments_data <- read_excel(excel_path, sheet = "comments")
unit_conversions_data <- read_excel(excel_path, sheet = "unit_conversions")

message("\nProcessing data...")

# 1. Create general_concepts.csv
general_concepts <- all_data %>%
  select(category, subcategory, general_concept_name) %>%
  distinct() %>%
  arrange(category, subcategory, general_concept_name) %>%
  mutate(general_concept_id = row_number()) %>%
  select(general_concept_id, category, subcategory, general_concept_name)

# Add athena_concept_id (NULL for now, will be filled manually)
general_concepts <- general_concepts %>%
  mutate(athena_concept_id = NA_integer_)

# Add comments
general_concepts <- general_concepts %>%
  left_join(
    comments_data %>% select(category, general_concept_name, comments),
    by = c("category", "general_concept_name")
  )

message("  Created general_concepts: ", nrow(general_concepts), " rows")

# 2. Create use_cases.csv (manual creation with 6 default use cases)
use_cases <- tibble(
  use_case_id = 1:6,
  use_case_name = c(
    "COVID-19 ICU",
    "Sepsis monitoring",
    "Ventilation management",
    "Laboratory tracking",
    "Medication administration",
    "Vital signs monitoring"
  ),
  description = c(
    "Patients admitted to ICU with COVID-19",
    "Monitoring of sepsis patients",
    "Mechanical ventilation parameters",
    "Laboratory results tracking",
    "Drug administration records",
    "Continuous vital signs monitoring"
  )
)

message("  Created use_cases: ", nrow(use_cases), " rows")

# 3. Create general_concept_use_cases.csv (junction table)
general_concept_use_cases <- all_data %>%
  left_join(
    general_concepts %>% select(general_concept_id, category, subcategory, general_concept_name),
    by = c("category", "subcategory", "general_concept_name")
  ) %>%
  select(general_concept_id, starts_with("uc")) %>%
  pivot_longer(cols = starts_with("uc"), names_to = "use_case", values_to = "value") %>%
  filter(!is.na(value) & value == "X") %>%
  mutate(use_case_id = as.integer(gsub("uc", "", use_case))) %>%
  select(general_concept_id, use_case_id) %>%
  distinct() %>%
  arrange(general_concept_id, use_case_id)

message("  Created general_concept_use_cases: ", nrow(general_concept_use_cases), " rows")

# 4. Create concept_mappings.csv
concept_mappings <- all_data %>%
  left_join(
    general_concepts %>% select(general_concept_id, category, subcategory, general_concept_name),
    by = c("category", "subcategory", "general_concept_name")
  ) %>%
  mutate(
    recommended = TRUE
  ) %>%
  select(
    general_concept_id,
    concept_name,
    vocabulary_id,
    concept_code,
    omop_concept_id,
    recommended,
    unit_concept_code = unit_concept_name,
    omop_unit_concept_id,
    data_type,
    omop_table,
    omop_column,
    omop_domain_id,
    ehden_rows_count,
    ehden_num_data_sources,
    loinc_rank
  ) %>%
  arrange(general_concept_id, concept_name)

message("  Created concept_mappings: ", nrow(concept_mappings), " rows")

# 5. unit_conversions.csv (copy from Excel)
unit_conversions <- unit_conversions_data

message("  Created unit_conversions: ", nrow(unit_conversions), " rows")

# Write CSV files
message("\nWriting CSV files...")

write.csv(general_concepts,
          file.path(csv_dir, "general_concepts.csv"),
          row.names = FALSE,
          na = "")
message("  ✓ general_concepts.csv")

write.csv(use_cases,
          file.path(csv_dir, "use_cases.csv"),
          row.names = FALSE,
          na = "")
message("  ✓ use_cases.csv")

write.csv(general_concept_use_cases,
          file.path(csv_dir, "general_concept_use_cases.csv"),
          row.names = FALSE,
          na = "")
message("  ✓ general_concept_use_cases.csv")

write.csv(concept_mappings,
          file.path(csv_dir, "concept_mappings.csv"),
          row.names = FALSE,
          na = "")
message("  ✓ concept_mappings.csv")

write.csv(unit_conversions,
          file.path(csv_dir, "unit_conversions.csv"),
          row.names = FALSE,
          na = "")
message("  ✓ unit_conversions.csv")

message("\n✅ Conversion complete! CSV files saved to: ", csv_dir)

# Print summary
message("\nSummary:")
message("  - ", nrow(general_concepts), " general concepts")
message("  - ", nrow(use_cases), " use cases")
message("  - ", nrow(general_concept_use_cases), " general concept-use case associations")
message("  - ", nrow(concept_mappings), " concept mappings")
message("  - ", nrow(unit_conversions), " unit conversions")
