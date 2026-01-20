#' Create INDICATE export from LLM mappings
#'
#' @description
#' This script creates an INDICATE-format ZIP from a mappings JSON file.
#' It generates files in a temporary folder, validates them, and only creates
#' the ZIP if validation passes.
#'
#' @details
#' Required input: JSON file with mappings (path passed as argument)
#'
#' Run from project root:
#' Rscript inst/scripts/llm_create_indicate_export.R <app_folder> <model_name> <json_file>
#'
#' Example:
#' Rscript inst/scripts/llm_create_indicate_export.R ~/indicate_files "Claude Opus 4.5" mappings_list_2025-01-20_13-15-00.json

library(duckdb)
library(DBI)
library(RSQLite)
library(jsonlite)
library(zip)

# Parse arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: Rscript llm_create_indicate_export.R <app_folder> <model_name> <json_file>")
}

app_folder <- path.expand(args[1])
model_name <- args[2]
json_file <- args[3]

# Author attribution
author_first_name <- "LLM -"
author_last_name <- model_name

cat("=== LLM INDICATE Export ===\n\n")
cat("App folder:", app_folder, "\n")
cat("Model:", model_name, "\n\n")

# Read mapping configuration
config_path <- file.path(app_folder, "concept_mapping", json_file)
if (!file.exists(config_path)) {
  stop("JSON file not found at: ", config_path)
}

config <- fromJSON(config_path)
alignment_id <- config$alignment_id
category_filter <- config$category
mappings_list <- config$mappings

cat("Alignment ID:", alignment_id, "\n")
cat("Category:", category_filter, "\n")
cat("Mappings count:", nrow(mappings_list), "\n\n")

# Create output folder with timestamp
timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
export_folder_name <- paste0("llm_export_", timestamp)
export_folder <- file.path(app_folder, "concept_mapping", export_folder_name)
dir.create(export_folder, showWarnings = FALSE)

cat("Export folder:", export_folder, "\n\n")

# Load source concepts from alignment
indicate_db <- file.path(app_folder, "indicate.db")
con <- dbConnect(SQLite(), indicate_db)
alignment <- dbGetQuery(con, "SELECT file_id, name FROM concept_alignments WHERE alignment_id = ?",
                        params = list(alignment_id))
dbDisconnect(con)

if (nrow(alignment) == 0) {
  stop("Alignment not found with ID: ", alignment_id)
}

source_csv_path <- file.path(app_folder, "concept_mapping", paste0(alignment$file_id, ".csv"))
source_concepts_raw <- read.csv(source_csv_path, stringsAsFactors = FALSE)

# Filter by category if specified
if (!is.null(category_filter) && category_filter != "") {
  filtered <- source_concepts_raw[source_concepts_raw$category == category_filter, ]
} else {
  filtered <- source_concepts_raw
}

# Connect to vocabularies for enrichment
vocab_con <- dbConnect(duckdb(), file.path(app_folder, "ohdsi_vocabularies.duckdb"), read_only = TRUE)

# ============================================================
# STEP 1: Generate mapping CSV (internal use)
# ============================================================
cat("Step 1: Generating mapping data...\n")

mapping_df <- data.frame(
  source_vocabulary_id = character(),
  source_concept_code = character(),
  source_concept_name = character(),
  target_vocabulary_id = character(),
  target_concept_id = integer(),
  target_concept_name = character(),
  confidence_score = numeric(),
  comments = character(),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(mappings_list))) {
  m <- mappings_list[i, ]
  src <- filtered[filtered$concept_code == m$code, ]

  if (nrow(src) == 1) {
    if (!is.na(m$target_id) && !is.null(m$target_id)) {
      target <- dbGetQuery(vocab_con, sprintf("
        SELECT concept_id, concept_code, concept_name, vocabulary_id
        FROM concept WHERE concept_id = %d
      ", m$target_id))

      mapping_df <- rbind(mapping_df, data.frame(
        source_vocabulary_id = src$vocabulary_id,
        source_concept_code = src$concept_code,
        source_concept_name = src$concept_name,
        target_vocabulary_id = target$vocabulary_id,
        target_concept_id = target$concept_id,
        target_concept_name = target$concept_name,
        confidence_score = m$score,
        comments = ifelse(is.null(m$comment), "", m$comment),
        stringsAsFactors = FALSE
      ))
    } else {
      mapping_df <- rbind(mapping_df, data.frame(
        source_vocabulary_id = src$vocabulary_id,
        source_concept_code = src$concept_code,
        source_concept_name = src$concept_name,
        target_vocabulary_id = NA,
        target_concept_id = NA,
        target_concept_name = NA,
        confidence_score = NA,
        comments = ifelse(is.null(m$comment), "", m$comment),
        stringsAsFactors = FALSE
      ))
    }
  }
}

# Save internal mapping CSV
mapping_csv_path <- file.path(export_folder, "mapping.csv")
write.csv(mapping_df, mapping_csv_path, row.names = FALSE)
cat("   Created: mapping.csv\n")

# ============================================================
# STEP 2: Generate INDICATE format files
# ============================================================
cat("\nStep 2: Generating INDICATE format files...\n")

# source_concepts.csv
source_concepts <- data.frame(
  row_id = seq_len(nrow(mapping_df)),
  vocabulary_id = mapping_df$source_vocabulary_id,
  concept_code = mapping_df$source_concept_code,
  concept_name = mapping_df$source_concept_name,
  category = ifelse(!is.null(config$category), config$category, ""),
  stringsAsFactors = FALSE
)
write.csv(source_concepts, file.path(export_folder, "source_concepts.csv"), row.names = FALSE)
cat("   Created: source_concepts.csv\n")

# mappings.csv (INDICATE format)
mappings_export <- data.frame(
  mapping_id = seq_len(nrow(mapping_df)),
  row_id = seq_len(nrow(mapping_df)),
  target_general_concept_id = NA_integer_,
  target_omop_concept_id = mapping_df$target_concept_id,
  target_custom_concept_id = NA_integer_,
  mapping_datetime = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  user_first_name = author_first_name,
  user_last_name = author_last_name,
  vocabulary_id = mapping_df$source_vocabulary_id,
  concept_code = mapping_df$source_concept_code,
  confidence_score = mapping_df$confidence_score,
  stringsAsFactors = FALSE
)
write.csv(mappings_export, file.path(export_folder, "mappings.csv"), row.names = FALSE)
cat("   Created: mappings.csv\n")

# evaluations.csv (empty)
evaluations <- data.frame(
  mapping_id = integer(),
  is_approved = integer(),
  comment = character(),
  evaluated_at = character(),
  user_first_name = character(),
  user_last_name = character(),
  stringsAsFactors = FALSE
)
write.csv(evaluations, file.path(export_folder, "evaluations.csv"), row.names = FALSE)
cat("   Created: evaluations.csv\n")

# comments.csv
has_comment <- !is.na(mapping_df$comments) & mapping_df$comments != ""
if (any(has_comment)) {
  comments <- data.frame(
    mapping_id = which(has_comment),
    comment = mapping_df$comments[has_comment],
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    user_first_name = author_first_name,
    user_last_name = author_last_name,
    stringsAsFactors = FALSE
  )
} else {
  comments <- data.frame(
    mapping_id = integer(),
    comment = character(),
    created_at = character(),
    user_first_name = character(),
    user_last_name = character(),
    stringsAsFactors = FALSE
  )
}
write.csv(comments, file.path(export_folder, "comments.csv"), row.names = FALSE)
cat("   Created: comments.csv\n")

# metadata.json
metadata <- list(
  format_version = "1.0",
  format_type = "INDICATE_DATA_DICTIONARY",
  export_date = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
  exported_by = paste(author_first_name, author_last_name),
  alignment = list(
    name = ifelse(!is.null(config$alignment_name), config$alignment_name, "LLM Mapping"),
    description = ifelse(!is.null(config$description), config$description, "Mapping generated by LLM"),
    source_vocabulary = ifelse(nrow(mapping_df) > 0, mapping_df$source_vocabulary_id[1], "")
  ),
  statistics = list(
    total_source_concepts = nrow(source_concepts),
    total_mappings = sum(!is.na(mappings_export$target_omop_concept_id))
  )
)
write_json(metadata, file.path(export_folder, "metadata.json"), pretty = TRUE, auto_unbox = TRUE)
cat("   Created: metadata.json\n")

# ============================================================
# STEP 3: Validation
# ============================================================
cat("\nStep 3: Validating mappings...\n")

errors <- character()
warnings <- character()

# 3.1 Validate source codes
valid_codes <- filtered$concept_code
invalid_codes <- mappings_list$code[!mappings_list$code %in% valid_codes]
if (length(invalid_codes) > 0) {
  errors <- c(errors, sprintf("Source codes not found in alignment: %s", paste(invalid_codes, collapse = ", ")))
}

dup_codes <- mappings_list$code[duplicated(mappings_list$code)]
if (length(dup_codes) > 0) {
  errors <- c(errors, sprintf("Duplicate source codes: %s", paste(dup_codes, collapse = ", ")))
}
cat("   - Source codes: ", ifelse(length(invalid_codes) == 0 && length(dup_codes) == 0, "OK", "ERRORS"), "\n")

# 3.2 Validate target concepts
mapped_rows <- mappings_list[!is.na(mappings_list$target_id), ]
if (nrow(mapped_rows) > 0) {
  target_ids <- mapped_rows$target_id
  target_ids_str <- paste(target_ids, collapse = ", ")
  query <- sprintf("
    SELECT concept_id, concept_name, standard_concept, invalid_reason
    FROM concept WHERE concept_id IN (%s)
  ", target_ids_str)
  found_concepts <- dbGetQuery(vocab_con, query)

  missing_ids <- target_ids[!target_ids %in% found_concepts$concept_id]
  if (length(missing_ids) > 0) {
    errors <- c(errors, sprintf("Target concepts not found: %s", paste(missing_ids, collapse = ", ")))
  }

  non_standard <- found_concepts[is.na(found_concepts$standard_concept) | found_concepts$standard_concept != "S", ]
  if (nrow(non_standard) > 0) {
    errors <- c(errors, sprintf("Non-standard concepts: %s", paste(non_standard$concept_id, collapse = ", ")))
  }

  invalid_concepts <- found_concepts[!is.na(found_concepts$invalid_reason), ]
  if (nrow(invalid_concepts) > 0) {
    errors <- c(errors, sprintf("Invalid concepts: %s", paste(invalid_concepts$concept_id, collapse = ", ")))
  }
  cat("   - Target concepts: ", ifelse(length(missing_ids) == 0 && nrow(non_standard) == 0 && nrow(invalid_concepts) == 0, "OK", "ERRORS"), "\n")
} else {
  cat("   - Target concepts: No mapped concepts to validate\n")
}

dbDisconnect(vocab_con)

# 3.3 Validate scores
if ("score" %in% names(mappings_list)) {
  scored_rows <- mappings_list[!is.na(mappings_list$score), ]
  invalid_scores <- scored_rows[scored_rows$score < 0 | scored_rows$score > 1, ]
  if (nrow(invalid_scores) > 0) {
    errors <- c(errors, sprintf("Scores out of range: %s", paste(invalid_scores$code, collapse = ", ")))
  }

  mapped_no_score <- mappings_list[!is.na(mappings_list$target_id) & is.na(mappings_list$score), ]
  if (nrow(mapped_no_score) > 0) {
    errors <- c(errors, sprintf("Mapped without score: %s", paste(mapped_no_score$code, collapse = ", ")))
  }

  unmapped_with_score <- mappings_list[is.na(mappings_list$target_id) & !is.na(mappings_list$score), ]
  if (nrow(unmapped_with_score) > 0) {
    errors <- c(errors, sprintf("Unmapped with score: %s", paste(unmapped_with_score$code, collapse = ", ")))
  }
  cat("   - Scores: ", ifelse(nrow(invalid_scores) == 0 && nrow(mapped_no_score) == 0 && nrow(unmapped_with_score) == 0, "OK", "ERRORS"), "\n")
}

# 3.4 Validate comments
if ("comment" %in% names(mappings_list) && "score" %in% names(mappings_list)) {
  low_conf_no_comment <- mappings_list[!is.na(mappings_list$score) & mappings_list$score < 0.8 &
                                         (is.na(mappings_list$comment) | mappings_list$comment == ""), ]
  if (nrow(low_conf_no_comment) > 0) {
    warnings <- c(warnings, sprintf("Low confidence without comment: %s", paste(low_conf_no_comment$code, collapse = ", ")))
  }

  unmapped_no_comment <- mappings_list[is.na(mappings_list$target_id) &
                                         (is.na(mappings_list$comment) | mappings_list$comment == ""), ]
  if (nrow(unmapped_no_comment) > 0) {
    warnings <- c(warnings, sprintf("Unmapped without explanation: %s", paste(unmapped_no_comment$code, collapse = ", ")))
  }
  cat("   - Comments: ", ifelse(nrow(low_conf_no_comment) == 0 && nrow(unmapped_no_comment) == 0, "OK", "WARNINGS"), "\n")
}

# ============================================================
# STEP 4: Create ZIP or report errors
# ============================================================
cat("\n")

mapped_count <- sum(!is.na(mapping_df$target_concept_id))
unmapped_count <- sum(is.na(mapping_df$target_concept_id))

if (length(errors) > 0) {
  cat("=== VALIDATION FAILED ===\n\n")
  cat("ERRORS:\n")
  for (err in errors) {
    cat("  - ", err, "\n")
  }
  if (length(warnings) > 0) {
    cat("\nWARNINGS:\n")
    for (warn in warnings) {
      cat("  - ", warn, "\n")
    }
  }
  cat("\nFiles kept in:", export_folder, "\n")
  cat("Fix errors in mappings_list.json and re-run.\n")
  quit(status = 1)
}

# Validation passed - create ZIP
cat("=== VALIDATION PASSED ===\n\n")

if (length(warnings) > 0) {
  cat("WARNINGS (non-blocking):\n")
  for (warn in warnings) {
    cat("  - ", warn, "\n")
  }
  cat("\n")
}

zip_filename <- paste0("indicate_", timestamp, ".zip")
zip_path <- file.path(app_folder, "concept_mapping", zip_filename)

old_wd <- getwd()
setwd(export_folder)
zip::zip(
  zip_path,
  files = c("metadata.json", "source_concepts.csv", "mappings.csv", "evaluations.csv", "comments.csv")
)
setwd(old_wd)

# Remove export folder after successful ZIP creation
unlink(export_folder, recursive = TRUE)

# Remove input JSON file after successful ZIP creation
unlink(config_path)

cat("Summary:\n")
cat("  Mapped:   ", mapped_count, " (", round(100 * mapped_count / nrow(mapping_df)), "%)\n", sep = "")
cat("  Unmapped: ", unmapped_count, " (", round(100 * unmapped_count / nrow(mapping_df)), "%)\n", sep = "")
cat("\n")
cat("ZIP created: ", zip_path, "\n")
cat("Author: ", author_first_name, author_last_name, "\n")
cat("\nImport in INDICATE: Concept Mapping > Import Mappings > INDICATE format\n")
