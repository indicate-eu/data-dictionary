#' Statistical Analysis Functions
#'
#' @description Functions to compute and compare statistical distributions
#' for OMOP concepts, used for automated concept alignment

# OMOP CDM TABLE CONFIGURATION ====

#' Get OMOP CDM Table Configuration
#'
#' @description Returns configuration for all OMOP CDM v5.4 clinical event tables
#' @return List of table configurations
#' @noRd
get_omop_table_configs <- function() {
  list(
    measurement = list(
      table = "measurement",
      concept_column = "measurement_concept_id",
      numeric_column = "value_as_number",
      categorical_column = "value_as_string",
      date_column = "measurement_date"
    ),
    observation = list(
      table = "observation",
      concept_column = "observation_concept_id",
      numeric_column = "value_as_number",
      categorical_column = "value_as_string",
      date_column = "observation_date"
    ),
    drug_exposure = list(
      table = "drug_exposure",
      concept_column = "drug_concept_id",
      numeric_column = NULL,
      categorical_column = NULL,
      date_column = "drug_exposure_start_date"
    ),
    condition_occurrence = list(
      table = "condition_occurrence",
      concept_column = "condition_concept_id",
      numeric_column = NULL,
      categorical_column = NULL,
      date_column = "condition_start_date"
    ),
    procedure_occurrence = list(
      table = "procedure_occurrence",
      concept_column = "procedure_concept_id",
      numeric_column = NULL,
      categorical_column = NULL,
      date_column = "procedure_date"
    ),
    device_exposure = list(
      table = "device_exposure",
      concept_column = "device_concept_id",
      numeric_column = NULL,
      categorical_column = NULL,
      date_column = "device_exposure_start_date"
    ),
    specimen = list(
      table = "specimen",
      concept_column = "specimen_concept_id",
      numeric_column = NULL,
      categorical_column = NULL,
      date_column = "specimen_date"
    )
  )
}


# BATCH PROCESSING FUNCTIONS ====

#' Compute Statistical Summaries for All Concepts in OMOP Database
#'
#' @description Batch process all concepts across all OMOP CDM tables
#'
#' @param conn DBI database connection object (DuckDB, PostgreSQL, etc.)
#' @param tables Vector of table names to process (default: all clinical event tables)
#' @param min_rows Minimum number of rows for a concept to be included (default: 10)
#' @param max_categorical_values Maximum distinct values to treat as categorical (default: 50)
#' @param min_categorical_count Minimum count for categorical value (default: 10)
#' @param max_stored_categories Maximum categories to store in JSON (default: 10)
#' @param compute_percentiles Whether to compute percentiles (default: TRUE)
#' @param batch_size Number of concepts to process per batch (default: 100)
#' @param progress_callback Function to call with progress updates (default: NULL)
#' @param output_file Path to save results as CSV (default: NULL, returns data.frame)
#'
#' @return Data frame with columns: vocabulary_id, concept_id, concept_code, table_name, statistical_summary_json
#' @export
#'
#' @examples
#' \dontrun{
#'   conn <- DBI::dbConnect(duckdb::duckdb(), "omop.duckdb")
#'
#'   # Process all tables and save to CSV
#'   results <- compute_all_omop_statistics(
#'     conn = conn,
#'     output_file = "omop_statistics.csv",
#'     progress_callback = function(msg) cat(msg, "\n")
#'   )
#'
#'   DBI::dbDisconnect(conn)
#' }
compute_all_omop_statistics <- function(conn,
                                        tables = NULL,
                                        min_rows = 10,
                                        max_categorical_values = 50,
                                        min_categorical_count = 10,
                                        max_stored_categories = 10,
                                        compute_percentiles = TRUE,
                                        batch_size = 100,
                                        progress_callback = NULL,
                                        output_file = NULL) {

  # Get table configurations
  table_configs <- get_omop_table_configs()

  # Filter to requested tables
  if (!is.null(tables)) {
    table_configs <- table_configs[names(table_configs) %in% tables]
  }

  # Filter to tables that exist in the database
  table_configs <- Filter(function(cfg) DBI::dbExistsTable(conn, cfg$table), table_configs)

  if (length(table_configs) == 0) {
    stop("No valid OMOP tables found in database")
  }

  # Initialize results
  all_results <- list()

  # Process each table
  for (table_name in names(table_configs)) {
    cfg <- table_configs[[table_name]]

    if (!is.null(progress_callback)) {
      progress_callback(sprintf("Processing table: %s", cfg$table))
    }

    # Get list of concepts with counts
    concept_counts_query <- sprintf(
      "SELECT %s as concept_id, COUNT(*) as row_count
       FROM %s
       WHERE %s IS NOT NULL
       GROUP BY %s
       HAVING COUNT(*) >= %d
       ORDER BY COUNT(*) DESC",
      cfg$concept_column,
      cfg$table,
      cfg$concept_column,
      cfg$concept_column,
      min_rows
    )

    concept_counts <- DBI::dbGetQuery(conn, concept_counts_query)

    if (nrow(concept_counts) == 0) {
      if (!is.null(progress_callback)) {
        progress_callback(sprintf("  No concepts found with >= %d rows", min_rows))
      }
      next
    }

    if (!is.null(progress_callback)) {
      progress_callback(sprintf("  Found %d concepts to process", nrow(concept_counts)))
    }

    # Process in batches
    n_concepts <- nrow(concept_counts)
    n_batches <- ceiling(n_concepts / batch_size)

    for (batch_idx in seq_len(n_batches)) {
      start_idx <- (batch_idx - 1) * batch_size + 1
      end_idx <- min(batch_idx * batch_size, n_concepts)

      batch_concepts <- concept_counts$concept_id[start_idx:end_idx]

      if (!is.null(progress_callback)) {
        progress_callback(sprintf("  Batch %d/%d: processing concepts %d-%d",
                                  batch_idx, n_batches, start_idx, end_idx))
      }

      # Get concept information from CONCEPT table for this batch
      concept_info_query <- sprintf(
        "SELECT concept_id, vocabulary_id, concept_code
         FROM concept
         WHERE concept_id IN (%s)",
        paste(batch_concepts, collapse = ", ")
      )

      concept_info <- tryCatch({
        DBI::dbGetQuery(conn, concept_info_query)
      }, error = function(e) {
        if (!is.null(progress_callback)) {
          progress_callback(sprintf("    Warning: Could not retrieve concept info from CONCEPT table: %s", e$message))
        }
        # Create empty data frame with expected structure
        data.frame(
          concept_id = integer(0),
          vocabulary_id = character(0),
          concept_code = character(0),
          stringsAsFactors = FALSE
        )
      })

      # Process each concept in batch
      batch_results <- lapply(seq_along(batch_concepts), function(i) {
        concept_id <- batch_concepts[i]

        tryCatch({
          summary_json <- compute_single_concept_statistics(
            conn = conn,
            concept_id = concept_id,
            table_name = cfg$table,
            concept_column = cfg$concept_column,
            value_column = cfg$value_column,
            date_column = cfg$date_column,
            max_categorical_values = max_categorical_values,
            min_categorical_count = min_categorical_count,
            max_stored_categories = max_stored_categories,
            compute_percentiles = compute_percentiles
          )

          # Get concept info for this concept
          concept_row <- concept_info[concept_info$concept_id == concept_id, ]

          if (nrow(concept_row) == 0) {
            # Concept not found in CONCEPT table
            data.frame(
              vocabulary_id = NA_character_,
              concept_id = concept_id,
              concept_code = NA_character_,
              table_name = cfg$table,
              statistical_summary_json = summary_json,
              stringsAsFactors = FALSE
            )
          } else {
            data.frame(
              vocabulary_id = concept_row$vocabulary_id[1],
              concept_id = concept_id,
              concept_code = concept_row$concept_code[1],
              table_name = cfg$table,
              statistical_summary_json = summary_json,
              stringsAsFactors = FALSE
            )
          }
        }, error = function(e) {
          if (!is.null(progress_callback)) {
            progress_callback(sprintf("    Error processing concept %d: %s", concept_id, e$message))
          }
          NULL
        })
      })

      # Remove NULL entries (failed computations)
      batch_results <- Filter(Negate(is.null), batch_results)

      if (length(batch_results) > 0) {
        batch_df <- do.call(rbind, batch_results)
        all_results[[length(all_results) + 1]] <- batch_df

        # Append to output file if specified
        if (!is.null(output_file)) {
          write.table(
            batch_df,
            file = output_file,
            append = file.exists(output_file),
            col.names = !file.exists(output_file),
            row.names = FALSE,
            sep = ",",
            quote = TRUE
          )
        }
      }
    }
  }

  # Combine all results
  if (length(all_results) == 0) {
    return(data.frame(
      vocabulary_id = character(0),
      concept_id = integer(0),
      concept_code = character(0),
      table_name = character(0),
      statistical_summary_json = character(0),
      stringsAsFactors = FALSE
    ))
  }

  final_results <- do.call(rbind, all_results)

  if (!is.null(progress_callback)) {
    progress_callback(sprintf("Complete! Processed %d concepts across %d tables",
                              nrow(final_results), length(table_configs)))
  }

  return(final_results)
}


# SINGLE CONCEPT COMPUTATION ====

#' Compute Statistical Summary for Single Concept
#'
#' @description Compute statistics for a single concept (used internally by batch processing)
#' @noRd
compute_single_concept_statistics <- function(conn,
                                              concept_id,
                                              table_name,
                                              concept_column,
                                              value_column,
                                              date_column,
                                              max_categorical_values = 50,
                                              min_categorical_count = 10,
                                              max_stored_categories = 10,
                                              compute_percentiles = TRUE) {

  # Get total row count and patient count for the entire table
  total_query <- sprintf(
    "SELECT
      COUNT(*) as total_rows,
      COUNT(DISTINCT person_id) as total_patients
    FROM %s",
    table_name
  )

  total_stats <- DBI::dbGetQuery(conn, total_query)
  total_rows <- total_stats$total_rows[1]
  total_patients <- total_stats$total_patients[1]

  # Build base query for concept statistics
  if (!is.null(value_column)) {
    base_query <- sprintf(
      "SELECT
        %s as value,
        person_id,
        %s as date_value
      FROM %s
      WHERE %s = %d
        AND %s IS NOT NULL",
      value_column,
      date_column,
      table_name,
      concept_column,
      concept_id,
      value_column
    )
  } else {
    # For tables without value_column (e.g., condition_occurrence)
    base_query <- sprintf(
      "SELECT
        person_id,
        %s as date_value
      FROM %s
      WHERE %s = %d",
      date_column,
      table_name,
      concept_column,
      concept_id
    )
  }

  # Get data
  concept_data <- DBI::dbGetQuery(conn, base_query)

  if (nrow(concept_data) == 0) {
    return(get_default_statistical_summary_template())
  }

  # Basic counts
  rows_count <- nrow(concept_data)
  patients_count <- length(unique(concept_data$person_id))
  rows_percent <- round((rows_count / total_rows) * 100, 2)
  patients_percent <- round((patients_count / total_patients) * 100, 2)
  measurement_density <- round(rows_count / patients_count, 2)

  # Date range
  date_min <- min(concept_data$date_value, na.rm = TRUE)
  date_max <- max(concept_data$date_value, na.rm = TRUE)

  # If no value column, return counts only
  if (!is.null(value_column) && "value" %in% colnames(concept_data)) {
    values <- concept_data$value
    distinct_values <- unique(values)
    n_distinct <- length(distinct_values)

    # Check if categorical or numeric
    is_categorical <- n_distinct <= max_categorical_values

    if (is_categorical) {
      # Categorical data
      value_counts <- table(values)
      value_counts_sorted <- sort(value_counts, decreasing = TRUE)

      # Filter: only keep values with count >= min_categorical_count
      value_counts_filtered <- value_counts_sorted[value_counts_sorted >= min_categorical_count]

      # Keep only top max_stored_categories
      value_counts_final <- head(value_counts_filtered, max_stored_categories)

      possible_values <- lapply(names(value_counts_final), function(val) {
        list(
          value = val,
          count = as.numeric(value_counts_final[val]),
          percent = round((as.numeric(value_counts_final[val]) / rows_count) * 100, 2)
        )
      })

      summary <- list(
        data_types = list("categorical"),
        rows_count = rows_count,
        rows_percent = rows_percent,
        patients_count = patients_count,
        patients_percent = patients_percent,
        measurement_density = measurement_density,
        date_range = list(
          min = as.character(date_min),
          max = as.character(date_max)
        ),
        statistical_data = list(),
        possible_values = possible_values
      )

    } else {
      # Numeric data
      values_numeric <- suppressWarnings(as.numeric(values))
      values_numeric <- values_numeric[!is.na(values_numeric)]

      if (length(values_numeric) == 0) {
        return(get_default_statistical_summary_template())
      }

      # Compute basic statistics
      min_val <- min(values_numeric, na.rm = TRUE)
      max_val <- max(values_numeric, na.rm = TRUE)
      mean_val <- mean(values_numeric, na.rm = TRUE)
      median_val <- median(values_numeric, na.rm = TRUE)
      sd_val <- sd(values_numeric, na.rm = TRUE)

      # Compute percentiles if requested
      if (compute_percentiles) {
        p5 <- quantile(values_numeric, 0.05, na.rm = TRUE)
        p25 <- quantile(values_numeric, 0.25, na.rm = TRUE)
        p75 <- quantile(values_numeric, 0.75, na.rm = TRUE)
        p95 <- quantile(values_numeric, 0.95, na.rm = TRUE)
      } else {
        p5 <- p25 <- p75 <- p95 <- NULL
      }

      # Coefficient of variation
      cv <- if (!is.na(mean_val) && mean_val != 0) abs(sd_val / mean_val) else NULL

      summary <- list(
        data_types = list("numeric"),
        rows_count = rows_count,
        rows_percent = rows_percent,
        patients_count = patients_count,
        patients_percent = patients_percent,
        measurement_density = measurement_density,
        date_range = list(
          min = as.character(date_min),
          max = as.character(date_max)
        ),
        statistical_data = list(
          min = round(min_val, 2),
          max = round(max_val, 2),
          mean = round(mean_val, 2),
          median = round(median_val, 2),
          sd = round(sd_val, 2),
          cv = if (!is.null(cv)) round(cv, 3) else NULL,
          p5 = if (!is.null(p5)) round(p5, 2) else NULL,
          p25 = if (!is.null(p25)) round(p25, 2) else NULL,
          p75 = if (!is.null(p75)) round(p75, 2) else NULL,
          p95 = if (!is.null(p95)) round(p95, 2) else NULL
        ),
        possible_values = list()
      )
    }
  } else {
    # No value column - just counts
    summary <- list(
      data_types = list("count"),
      rows_count = rows_count,
      rows_percent = rows_percent,
      patients_count = patients_count,
      patients_percent = patients_percent,
      measurement_density = measurement_density,
      date_range = list(
        min = as.character(date_min),
        max = as.character(date_max)
      ),
      statistical_data = list(),
      possible_values = list()
    )
  }

  # Convert to JSON
  json_string <- jsonlite::toJSON(summary, auto_unbox = TRUE, pretty = FALSE, null = "null")

  return(as.character(json_string))
}


# DISTRIBUTION SIMILARITY FUNCTIONS ====

#' Compare Two Statistical Distributions
#'
#' @description Compute multiple similarity metrics between two statistical distributions
#'
#' @param summary1 Statistical summary JSON string or parsed list (concept 1)
#' @param summary2 Statistical summary JSON string or parsed list (concept 2)
#' @param weights Named vector of weights for each metric (default: equal weights)
#'
#' @return List with similarity scores:
#'   - overall_score: Weighted average of all metrics (0-1, higher = more similar)
#'   - quantile_similarity: Overlap of quantile ranges (0-1)
#'   - cv_similarity: Similarity of coefficients of variation (0-1)
#'   - range_similarity: Overlap of value ranges (0-1)
#'   - categorical_similarity: Jaccard similarity for categorical values (0-1, or NULL)
#'   - distribution_distance: Normalized distance metric (0-1, lower = more similar)
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   similarity <- compare_distributions(summary_json1, summary_json2)
#'   print(similarity$overall_score)
#' }
compare_distributions <- function(summary1, summary2, weights = NULL) {

  # Parse JSON if needed
  if (is.character(summary1)) {
    summary1 <- jsonlite::fromJSON(summary1)
  }
  if (is.character(summary2)) {
    summary2 <- jsonlite::fromJSON(summary2)
  }

  # Check if both are numeric or both are categorical
  type1 <- summary1$data_types[1]
  type2 <- summary2$data_types[1]

  if (type1 != type2) {
    # Different data types - very low similarity
    return(list(
      overall_score = 0.1,
      quantile_similarity = NULL,
      cv_similarity = NULL,
      range_similarity = NULL,
      categorical_similarity = NULL,
      distribution_distance = 1.0,
      message = "Different data types"
    ))
  }

  if (type1 == "categorical") {
    # Categorical comparison
    values1 <- sapply(summary1$possible_values, function(x) x$value)
    values2 <- sapply(summary2$possible_values, function(x) x$value)

    # Jaccard similarity
    intersection <- length(intersect(values1, values2))
    union <- length(union(values1, values2))
    jaccard <- if (union > 0) intersection / union else 0

    # Compare frequency distributions
    freq1 <- sapply(summary1$possible_values, function(x) x$percent)
    freq2 <- sapply(summary2$possible_values, function(x) x$percent)
    names(freq1) <- values1
    names(freq2) <- values2

    # Only compare common values
    common_values <- intersect(values1, values2)
    if (length(common_values) > 0) {
      freq1_common <- freq1[common_values]
      freq2_common <- freq2[common_values]

      # Jensen-Shannon divergence (symmetric version of KL divergence)
      freq_dist <- js_divergence(freq1_common, freq2_common)
      freq_similarity <- 1 - freq_dist
    } else {
      freq_similarity <- 0
    }

    overall <- (jaccard + freq_similarity) / 2

    return(list(
      overall_score = round(overall, 3),
      categorical_similarity = round(jaccard, 3),
      frequency_similarity = round(freq_similarity, 3),
      quantile_similarity = NULL,
      cv_similarity = NULL,
      range_similarity = NULL,
      distribution_distance = round(1 - overall, 3)
    ))

  } else {
    # Numeric comparison
    stats1 <- summary1$statistical_data
    stats2 <- summary2$statistical_data

    # 1. Quantile overlap similarity
    quantile_sim <- compute_quantile_similarity(stats1, stats2)

    # 2. CV similarity (coefficient of variation)
    cv_sim <- compute_cv_similarity(stats1, stats2)

    # 3. Range overlap
    range_sim <- compute_range_overlap(stats1, stats2)

    # 4. Distribution distance (normalized)
    dist_score <- compute_distribution_distance(stats1, stats2)

    # Default weights if not provided
    if (is.null(weights)) {
      weights <- c(
        quantile = 0.35,
        cv = 0.25,
        range = 0.25,
        distance = 0.15
      )
    }

    # Compute weighted overall score
    overall <- (
      quantile_sim * weights["quantile"] +
        cv_sim * weights["cv"] +
        range_sim * weights["range"] +
        (1 - dist_score) * weights["distance"]
    )

    return(list(
      overall_score = round(overall, 3),
      quantile_similarity = round(quantile_sim, 3),
      cv_similarity = round(cv_sim, 3),
      range_similarity = round(range_sim, 3),
      distribution_distance = round(dist_score, 3),
      categorical_similarity = NULL
    ))
  }
}


# Helper Functions for Distribution Comparison ----

#' Compute Quantile Similarity
#'
#' @description Compare overlap of quantile ranges (IQR and 90% range)
#' @noRd
compute_quantile_similarity <- function(stats1, stats2) {
  # Check if percentiles are available
  if (is.null(stats1$p25) || is.null(stats2$p25)) {
    return(0.5)  # Default moderate similarity if percentiles not available
  }

  # IQR overlap (25th to 75th percentile)
  iqr_overlap <- range_overlap_helper(
    stats1$p25, stats1$p75,
    stats2$p25, stats2$p75
  )

  # 90% range overlap (5th to 95th percentile)
  range90_overlap <- if (!is.null(stats1$p5) && !is.null(stats2$p5)) {
    range_overlap_helper(
      stats1$p5, stats1$p95,
      stats2$p5, stats2$p95
    )
  } else {
    iqr_overlap  # Fallback to IQR if p5/p95 not available
  }

  # Weight IQR more heavily than 90% range
  (iqr_overlap * 0.6 + range90_overlap * 0.4)
}

#' Compute Range Overlap Helper
#'
#' @description Compute overlap between two ranges
#' @noRd
range_overlap_helper <- function(min1, max1, min2, max2) {
  # Compute overlap length
  overlap_start <- max(min1, min2)
  overlap_end <- min(max1, max2)
  overlap_length <- max(0, overlap_end - overlap_start)

  # Compute union length
  union_start <- min(min1, min2)
  union_end <- max(max1, max2)
  union_length <- union_end - union_start

  if (union_length == 0) return(0)

  overlap_length / union_length
}

#' Compute CV Similarity
#'
#' @description Compare coefficients of variation
#' @noRd
compute_cv_similarity <- function(stats1, stats2) {
  cv1 <- stats1$cv
  cv2 <- stats2$cv

  if (is.null(cv1) || is.null(cv2)) {
    return(0.5)  # Default moderate similarity
  }

  # Similarity based on ratio of CVs
  # If CVs are similar, ratio is close to 1
  ratio <- if (cv2 != 0) min(cv1, cv2) / max(cv1, cv2) else 0

  ratio
}

#' Compute Range Overlap for Min-Max
#'
#' @description Compute overlap of full ranges
#' @noRd
compute_range_overlap <- function(stats1, stats2) {
  range_overlap_helper(stats1$min, stats1$max, stats2$min, stats2$max)
}

#' Compute Distribution Distance
#'
#' @description Compute normalized distance between distributions based on standardized statistics
#' @noRd
compute_distribution_distance <- function(stats1, stats2) {
  # Normalize statistics to 0-1 scale based on their ranges
  # Compare mean positions within ranges
  mean1_norm <- (stats1$mean - stats1$min) / (stats1$max - stats1$min)
  mean2_norm <- (stats2$mean - stats2$min) / (stats2$max - stats2$min)

  if (is.na(mean1_norm) || is.na(mean2_norm)) {
    return(0.5)
  }

  # Distance between normalized means
  mean_dist <- abs(mean1_norm - mean2_norm)

  # Compare median positions
  median1_norm <- (stats1$median - stats1$min) / (stats1$max - stats1$min)
  median2_norm <- (stats2$median - stats2$min) / (stats2$max - stats2$min)

  median_dist <- if (!is.na(median1_norm) && !is.na(median2_norm)) {
    abs(median1_norm - median2_norm)
  } else {
    mean_dist
  }

  # Average distance
  avg_dist <- (mean_dist + median_dist) / 2

  avg_dist
}

#' Jensen-Shannon Divergence
#'
#' @description Compute JS divergence between two probability distributions
#' @noRd
js_divergence <- function(p, q) {
  # Normalize to probabilities
  p <- p / sum(p)
  q <- q / sum(q)

  # Average distribution
  m <- (p + q) / 2

  # KL divergences
  kl_pm <- kl_divergence(p, m)
  kl_qm <- kl_divergence(q, m)

  # JS divergence (symmetric)
  js <- (kl_pm + kl_qm) / 2

  # Normalize to 0-1
  sqrt(js)
}

#' Kullback-Leibler Divergence
#'
#' @description Compute KL divergence from P to Q
#' @noRd
kl_divergence <- function(p, q) {
  # Avoid log(0)
  epsilon <- 1e-10
  p <- pmax(p, epsilon)
  q <- pmax(q, epsilon)

  sum(p * log(p / q))
}
