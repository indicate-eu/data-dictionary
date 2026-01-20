#' Create OMOP mapping CSV from LLM mapping data
#'
#' @description
#' This script creates a mapping CSV file from a mapping list provided by an LLM.
#' The LLM should create a mappings_list.json file with the mapping data before running.
#'
#' @details
#' Required input file: {app_folder}/concept_mapping/mappings_list.json
#' Format:
#' {
#'   "alignment_id": 2,
#'   "category": "Respiratoire / RESPI_Monitorage_Rennes",
#'   "mappings": [
#'     {"code": "Parameter_123", "target_id": 3000461, "score": 1.0, "comment": ""},
#'     {"code": "Parameter_456", "target_id": null, "score": null, "comment": "UNMAPPED: reason"}
#'   ]
#' }
#'
#' Run from project root:
#' Rscript inst/scripts/llm_create_mapping_csv.R ~/indicate_files

library(duckdb)
library(DBI)
library(RSQLite)
library(jsonlite)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript llm_create_mapping_csv.R <app_folder>")
}

app_folder <- path.expand(args[1])

# Read mapping configuration
config_path <- file.path(app_folder, "concept_mapping", "mappings_list.json")
if (!file.exists(config_path)) {
  stop("mappings_list.json not found at: ", config_path)
}

config <- fromJSON(config_path)
alignment_id <- config$alignment_id
category_filter <- config$category
mappings_list <- config$mappings

# Load source concepts
con <- dbConnect(SQLite(), file.path(app_folder, "indicate.db"))
alignment <- dbGetQuery(con, "SELECT file_id, name FROM concept_alignments WHERE alignment_id = ?",
                        params = list(alignment_id))
dbDisconnect(con)

csv_path <- file.path(app_folder, "concept_mapping", paste0(alignment$file_id, ".csv"))
source_concepts <- read.csv(csv_path, stringsAsFactors = FALSE)

# Filter by category if specified
if (!is.null(category_filter) && category_filter != "") {
  filtered <- source_concepts[source_concepts$category == category_filter, ]
} else {
  filtered <- source_concepts
}

# Connect to vocabularies
vocab_con <- dbConnect(duckdb(), file.path(app_folder, "ohdsi_vocabularies.duckdb"), read_only = TRUE)

# Build mapping dataframe
mapping <- data.frame(
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

      mapping <- rbind(mapping, data.frame(
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
      mapping <- rbind(mapping, data.frame(
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

dbDisconnect(vocab_con)

# Save mapping with readable timestamp format
timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
output_path <- file.path(app_folder, "concept_mapping", paste0("mapping_", timestamp, ".csv"))
write.csv(mapping, output_path, row.names = FALSE)

cat("Mapping CSV created:", output_path, "\n")
cat("Total concepts:", nrow(mapping), "\n")
cat("Mapped:", sum(!is.na(mapping$target_concept_id)), "\n")
cat("Unmapped:", sum(is.na(mapping$target_concept_id)), "\n")
