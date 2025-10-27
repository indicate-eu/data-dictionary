#' Enrich concept_mappings.csv with descendants and related concepts
#'
#' @description
#' This script enriches concept_mappings.csv by adding related concepts based on
#' the source vocabulary of each concept. Each source concept is processed individually
#' to maintain the association with its general_concept_id.
#'
#' For each source concept:
#' 1. Get Maps to/from + descendants within same vocabulary
#' 2. Get Maps to/from towards other allowed vocabularies (except for RxNorm)
#' 3. Get descendants of those cross-vocabulary concepts
#'
#' @details
#' Run this script from the project root:
#' Rscript inst/scripts/enrich_concept_mappings.R

library(dplyr)
library(readr)

# Source the DuckDB functions
source("R/fct_duckdb.R")

# Define allowed vocabularies
ALLOWED_VOCABS <- c("RxNorm", "RxNorm Extension", "LOINC", "SNOMED", "ICD10")

# Load OHDSI vocabularies from DuckDB
if (!duckdb_exists()) {
  stop("DuckDB database does not exist. Please create it first using create_duckdb_database().")
}

message("Loading vocabularies from DuckDB...")
vocab_data <- load_vocabularies_from_duckdb()

# Load current concept_mappings.csv
concept_mappings_path <- file.path("inst", "extdata", "csv", "concept_mappings.csv")

if (!file.exists(concept_mappings_path)) {
  stop("concept_mappings.csv not found")
}

original_mappings <- readr::read_csv(
  concept_mappings_path,
  col_types = readr::cols(
    general_concept_id = readr::col_integer(),
    omop_concept_id = readr::col_integer(),
    omop_unit_concept_id = readr::col_character(),
    recommended = readr::col_logical()
  )
)

message("Loaded ", nrow(original_mappings), " original concept mappings")

# Store which concepts were originally recommended
originally_recommended <- original_mappings %>%
  dplyr::filter(recommended == TRUE) %>%
  dplyr::select(general_concept_id, omop_concept_id, omop_unit_concept_id)

# Get vocabulary info for all original concepts
message("\nGetting vocabulary information for original concepts...")
original_concept_ids <- unique(original_mappings$omop_concept_id)

concept_vocabs <- vocab_data$concept %>%
  dplyr::filter(concept_id %in% original_concept_ids) %>%
  dplyr::select(concept_id, vocabulary_id, domain_id, concept_class_id) %>%
  dplyr::collect()

# Function to get Maps to/from relationships
get_relationships <- function(concept_ids, vocab_data) {
  if (length(concept_ids) == 0) return(data.frame(concept_id_1 = integer(), concept_id_2 = integer()))

  vocab_data$concept_relationship %>%
    dplyr::filter(
      concept_id_1 %in% concept_ids,
      relationship_id %in% c("Maps to", "Mapped from")
    ) %>%
    dplyr::select(concept_id_1, concept_id_2) %>%
    dplyr::collect()
}

# Function to get descendants via CONCEPT_ANCESTOR
get_descendants <- function(concept_ids, vocab_data) {
  if (length(concept_ids) == 0) return(data.frame(ancestor_concept_id = integer(), descendant_concept_id = integer()))

  vocab_data$concept_ancestor %>%
    dplyr::filter(ancestor_concept_id %in% concept_ids) %>%
    dplyr::select(ancestor_concept_id, descendant_concept_id) %>%
    dplyr::collect()
}

# Function to filter concepts by vocabulary and domain rules
filter_concepts <- function(concept_ids, vocab_data, allowed_vocabs = NULL) {
  if (length(concept_ids) == 0) return(integer(0))

  filtered <- vocab_data$concept %>%
    dplyr::filter(concept_id %in% concept_ids) %>%
    dplyr::select(concept_id, vocabulary_id, domain_id, concept_class_id, invalid_reason) %>%
    dplyr::collect()

  # Only keep valid concepts (invalid_reason IS NULL)
  filtered <- filtered %>%
    dplyr::filter(is.na(invalid_reason))

  # Apply vocabulary filter if specified
  if (!is.null(allowed_vocabs)) {
    filtered <- filtered %>%
      dplyr::filter(vocabulary_id %in% allowed_vocabs)
  }

  # For Drug domain, only keep Clinical Drug class
  filtered <- filtered %>%
    dplyr::filter(
      domain_id != "Drug" | concept_class_id == "Clinical Drug"
    )

  filtered$concept_id
}

# Initialize result with original mappings
all_mappings <- original_mappings

# Process each original mapping individually
message("\n--- Processing concepts individually ---")

mappings_with_vocab <- original_mappings %>%
  dplyr::left_join(
    concept_vocabs %>% dplyr::select(concept_id, vocabulary_id),
    by = c("omop_concept_id" = "concept_id")
  )

total_mappings <- nrow(mappings_with_vocab)
processed_count <- 0

for (i in seq_len(nrow(mappings_with_vocab))) {
  mapping <- mappings_with_vocab[i, ]

  processed_count <- processed_count + 1
  if (processed_count %% 50 == 0) {
    message("  Processed ", processed_count, "/", total_mappings, " mappings...")
  }

  source_concept_id <- mapping$omop_concept_id
  general_concept_id <- mapping$general_concept_id
  unit_concept_id <- mapping$omop_unit_concept_id
  source_vocab <- mapping$vocabulary_id

  # Skip if invalid vocabulary
  if (is.na(source_vocab) || !(source_vocab %in% ALLOWED_VOCABS)) {
    next
  }

  # Step 1: Get Maps to/from + descendants within same vocabulary
  step1_rels <- get_relationships(source_concept_id, vocab_data)
  step1_descs <- get_descendants(source_concept_id, vocab_data)

  step1_concepts <- unique(c(
    step1_rels$concept_id_2,
    step1_descs$descendant_concept_id
  ))

  # Filter to same vocabulary and valid concepts
  step1_filtered <- filter_concepts(
    step1_concepts,
    vocab_data,
    allowed_vocabs = source_vocab
  )

  # For RxNorm/RxNorm Extension: stop here
  if (source_vocab %in% c("RxNorm", "RxNorm Extension")) {
    new_concept_ids <- step1_filtered
  } else {
    # For LOINC, SNOMED, ICD10: continue with cross-vocabulary

    # Use original concept + step1 for cross-vocabulary relationships
    all_concepts_so_far <- unique(c(source_concept_id, step1_filtered))

    # Define target vocabularies (exclude source and RxNorm)
    target_vocabs <- setdiff(ALLOWED_VOCABS, c(source_vocab, "RxNorm", "RxNorm Extension"))

    # Step 2: Get cross-vocabulary relationships
    step2_rels <- get_relationships(all_concepts_so_far, vocab_data)
    step2_concepts <- unique(step2_rels$concept_id_2)

    step2_filtered <- filter_concepts(
      step2_concepts,
      vocab_data,
      allowed_vocabs = target_vocabs
    )

    # Step 3: Get descendants of cross-vocabulary concepts
    if (length(step2_filtered) > 0) {
      step3_descs <- get_descendants(step2_filtered, vocab_data)
      step3_concepts <- unique(step3_descs$descendant_concept_id)

      step3_filtered <- filter_concepts(
        step3_concepts,
        vocab_data,
        allowed_vocabs = target_vocabs
      )
    } else {
      step3_filtered <- integer(0)
    }

    new_concept_ids <- unique(c(step1_filtered, step2_filtered, step3_filtered))
  }

  # Create new mappings for this specific general_concept_id
  if (length(new_concept_ids) > 0) {
    new_rows <- data.frame(
      general_concept_id = general_concept_id,
      omop_concept_id = new_concept_ids,
      omop_unit_concept_id = unit_concept_id,
      recommended = FALSE,
      stringsAsFactors = FALSE
    )

    # Filter out concepts that already exist
    existing_keys <- all_mappings %>%
      dplyr::mutate(key = paste(general_concept_id, omop_concept_id, omop_unit_concept_id, sep = "_")) %>%
      dplyr::pull(key)

    new_rows <- new_rows %>%
      dplyr::mutate(key = paste(general_concept_id, omop_concept_id, omop_unit_concept_id, sep = "_")) %>%
      dplyr::filter(!key %in% existing_keys) %>%
      dplyr::select(-key)

    if (nrow(new_rows) > 0) {
      all_mappings <- dplyr::bind_rows(all_mappings, new_rows)
    }
  }
}

message("\n--- Final processing ---")

# Restore recommended=TRUE for originally recommended concepts
all_mappings <- all_mappings %>%
  dplyr::left_join(
    originally_recommended %>% dplyr::mutate(was_recommended = TRUE),
    by = c("general_concept_id", "omop_concept_id", "omop_unit_concept_id")
  ) %>%
  dplyr::mutate(
    recommended = dplyr::if_else(!is.na(was_recommended), TRUE, FALSE)
  ) %>%
  dplyr::select(-was_recommended)

# Sort by general_concept_id and recommended (recommended first)
all_mappings <- all_mappings %>%
  dplyr::arrange(general_concept_id, dplyr::desc(recommended), omop_concept_id)

# Final deduplication check
final_count_before <- nrow(all_mappings)
all_mappings <- all_mappings %>%
  dplyr::distinct(general_concept_id, omop_concept_id, omop_unit_concept_id, .keep_all = TRUE)
final_count_after <- nrow(all_mappings)

if (final_count_before != final_count_after) {
  message("Removed ", final_count_before - final_count_after, " duplicate entries")
}

message("\n--- Summary ---")
message("Original mappings: ", nrow(original_mappings))
message("Final mappings: ", nrow(all_mappings))
message("New mappings added: ", nrow(all_mappings) - nrow(original_mappings))
message("Recommended mappings: ", sum(all_mappings$recommended))

# Save enriched concept_mappings.csv
readr::write_csv(all_mappings, concept_mappings_path)
message("\nEnriched concept_mappings.csv saved to: ", concept_mappings_path)

# Close DuckDB connection
if (!is.null(vocab_data$connection)) {
  DBI::dbDisconnect(vocab_data$connection, shutdown = TRUE)
}

message("\nDone!")
