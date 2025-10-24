# Script to restructure concept_mappings.csv into three separate files
# To address licensing concerns with SNOMED and other vocabularies

library(dplyr)
library(readr)

# Read current concept_mappings.csv
csv_dir <- "inst/extdata/csv"
concept_mappings <- read_csv(
  file.path(csv_dir, "concept_mappings.csv"),
  col_types = cols(.default = col_character())
)

# Display structure
cat("Original concept_mappings structure:\n")
cat("Rows:", nrow(concept_mappings), "\n")
cat("Columns:", paste(names(concept_mappings), collapse = ", "), "\n\n")

# 1. Create concept_mappings.csv (allégé)
# Columns: general_concept_id, omop_concept_id, omop_unit_concept_id, recommended
# Only for concepts with OMOP concept IDs (non-INDICATE vocabularies)
new_concept_mappings <- concept_mappings %>%
  filter(!is.na(omop_concept_id) & omop_concept_id != "NA") %>%
  select(
    general_concept_id,
    omop_concept_id,
    omop_unit_concept_id,
    recommended
  ) %>%
  distinct()

cat("New concept_mappings.csv:\n")
cat("Rows:", nrow(new_concept_mappings), "\n")
cat("Sample:\n")
print(head(new_concept_mappings, 10))
cat("\n")

# 2. Create concept_statistics.csv
# Columns: omop_concept_id, loinc_rank, ehden_rows_count, ehden_num_data_sources
# Only for concepts with statistics
concept_statistics <- concept_mappings %>%
  filter(!is.na(omop_concept_id) & omop_concept_id != "NA") %>%
  select(
    omop_concept_id,
    loinc_rank,
    ehden_rows_count,
    ehden_num_data_sources
  ) %>%
  distinct() %>%
  filter(
    !is.na(loinc_rank) |
    !is.na(ehden_rows_count) |
    !is.na(ehden_num_data_sources)
  )

cat("concept_statistics.csv:\n")
cat("Rows:", nrow(concept_statistics), "\n")
cat("Sample:\n")
print(head(concept_statistics, 10))
cat("\n")

# 3. Create custom_concepts.csv
# Columns: general_concept_id, vocabulary_id, concept_code, concept_name, omop_unit_concept_id, recommended
# Only for INDICATE vocabulary
custom_concepts <- concept_mappings %>%
  filter(vocabulary_id == "INDICATE") %>%
  select(
    general_concept_id,
    vocabulary_id,
    concept_code,
    concept_name,
    omop_unit_concept_id,
    recommended
  ) %>%
  distinct()

cat("custom_concepts.csv:\n")
cat("Rows:", nrow(custom_concepts), "\n")
cat("Sample:\n")
print(head(custom_concepts, 10))
cat("\n")

# Verify no data loss
total_original <- nrow(concept_mappings)
total_new <- nrow(new_concept_mappings) + nrow(custom_concepts)
cat("Data verification:\n")
cat("Original rows:", total_original, "\n")
cat("New concept_mappings rows:", nrow(new_concept_mappings), "\n")
cat("Custom concepts rows:", nrow(custom_concepts), "\n")
cat("Total in new files:", total_new, "\n")

if (total_new != total_original) {
  warning("Row count mismatch! Please verify data integrity.")
}

# Save new CSV files
write_csv(new_concept_mappings, file.path(csv_dir, "concept_mappings_new.csv"), na = "")
write_csv(concept_statistics, file.path(csv_dir, "concept_statistics.csv"), na = "")
write_csv(custom_concepts, file.path(csv_dir, "custom_concepts.csv"), na = "")

cat("\nFiles created successfully:\n")
cat("- concept_mappings_new.csv\n")
cat("- concept_statistics.csv\n")
cat("- custom_concepts.csv\n")
