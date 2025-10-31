# Script to add source column to concept_mappings.csv
# Keep only recommended=TRUE rows and set source="manual"

library(readr)
library(dplyr)

# Read current concept_mappings
concept_mappings <- read_csv(
  "inst/extdata/csv/concept_mappings.csv",
  show_col_types = FALSE
)

cat("Original rows:", nrow(concept_mappings), "\n")
cat("Recommended=TRUE rows:", sum(concept_mappings$recommended, na.rm = TRUE), "\n")

# Filter to keep only recommended=TRUE
concept_mappings_filtered <- concept_mappings %>%
  filter(recommended == TRUE) %>%
  mutate(source = "manual")

cat("Filtered rows:", nrow(concept_mappings_filtered), "\n")

# Reorder columns: general_concept_id, omop_concept_id, omop_unit_concept_id, recommended, source
concept_mappings_final <- concept_mappings_filtered %>%
  select(general_concept_id, omop_concept_id, omop_unit_concept_id, recommended, source)

# Write to CSV
write_csv(
  concept_mappings_final,
  "inst/extdata/csv/concept_mappings.csv"
)

cat("New CSV saved with", nrow(concept_mappings_final), "rows\n")
cat("Column names:", paste(names(concept_mappings_final), collapse = ", "), "\n")
