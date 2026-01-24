#' Concept CRUD Functions
#'
#' @description Functions to manage concept alignments and mappings
#' CRUD operations (Create, Read, Update, Delete)
#'
#' @noRd

# CONCEPT ALIGNMENTS ====

#' Add new concept alignment
#'
#' @description Add a new concept alignment to the database
#'
#' @param name Alignment name
#' @param description Alignment description
#' @param file_id Unique file identifier
#' @param original_filename Original filename
#' @param column_types JSON string with column type definitions
#'
#' @return Alignment ID of the newly created alignment
#' @noRd
add_alignment <- function(name, description = "", file_id, original_filename = "", column_types = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "INSERT INTO concept_alignments (name, description, file_id, original_filename, column_types, created_date, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)",
    params = list(name, description, file_id, original_filename, column_types, timestamp, timestamp)
  )

  # Get the ID of the newly inserted alignment
  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")

  return(result$id[1])
}

#' Delete concept alignment
#'
#' @description Delete a concept alignment from the database
#'
#' @param alignment_id Alignment ID
#'
#' @return TRUE if successful
#' @noRd
delete_alignment <- function(alignment_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM concept_alignments WHERE alignment_id = ?",
    params = list(alignment_id)
  )

  return(TRUE)
}

#' Get all concept alignments
#'
#' @description Retrieve all concept alignments from the database
#'
#' @return Data frame with all alignments
#' @noRd
get_all_alignments <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT alignment_id, name, description, file_id, original_filename, column_types, created_date, updated_at
     FROM concept_alignments
     ORDER BY created_date DESC"
  )

  return(result)
}

#' Apply column types to dataframe
#'
#' @description Apply column types stored as JSON to a dataframe
#'
#' @param df Dataframe to modify
#' @param column_types_json JSON string with column type definitions
#'
#' @return Modified dataframe with applied types
#' @noRd
apply_column_types <- function(df, column_types_json) {
  if (is.null(column_types_json) || is.na(column_types_json) || column_types_json == "") {
    return(df)
  }

  column_types <- tryCatch(
    jsonlite::fromJSON(column_types_json),
    error = function(e) NULL
  )

  if (is.null(column_types)) {
    return(df)
  }

  for (col_name in names(column_types)) {
    if (!col_name %in% colnames(df)) next

    col_type <- column_types[[col_name]]
    df[[col_name]] <- tryCatch({
      switch(col_type,
        "character" = as.character(df[[col_name]]),
        "numeric" = as.numeric(df[[col_name]]),
        "integer" = as.integer(df[[col_name]]),
        "factor" = as.factor(df[[col_name]]),
        "date" = as.Date(df[[col_name]]),
        "datetime" = as.POSIXct(df[[col_name]]),
        "logical" = as.logical(df[[col_name]]),
        df[[col_name]]
      )
    }, error = function(e) df[[col_name]])
  }

  return(df)
}

#' Import target concept mappings from alignment creation
#'
#' @description Import mappings from target_concept_id column when creating an alignment.
#' Imports all mappings regardless of whether the target concept exists in INDICATE.
#'
#' @param alignment_id Alignment ID
#' @param source_data Data frame with source data including target_concept_id column
#' @param csv_filename CSV filename for the alignment
#' @param user_id User ID performing the import
#' @param original_filename Original filename for the import record
#'
#' @return Number of mappings imported
#' @noRd
import_target_concept_mappings <- function(alignment_id, source_data, csv_filename, user_id, original_filename) {
  if (!"target_concept_id" %in% colnames(source_data)) {
    return(0)
  }

  # Filter rows with valid target_concept_id
  mappings_to_import <- source_data[!is.na(source_data$target_concept_id) & source_data$target_concept_id != "", ]

  if (nrow(mappings_to_import) == 0) {
    return(0)
  }

  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Start transaction
 DBI::dbBegin(con)

  tryCatch({
    # Create import record
    DBI::dbExecute(
      con,
      "INSERT INTO imported_mappings (alignment_id, original_filename, import_mode, concepts_count, imported_by_user_id, imported_at)
       VALUES (?, ?, ?, 0, ?, ?)",
      params = list(alignment_id, original_filename, "initial", user_id, timestamp)
    )

    import_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]

    imported_count <- 0

    # Process each row with a target_concept_id
    for (i in seq_len(nrow(source_data))) {
      target_id <- source_data$target_concept_id[i]

      # Skip empty or NA values
      if (is.na(target_id) || target_id == "") {
        next
      }

      # Convert to integer
      target_concept_id <- suppressWarnings(as.integer(target_id))
      if (is.na(target_concept_id)) {
        next
      }

      # Use row_id from source data (1-based index)
      source_row_id <- if ("row_id" %in% colnames(source_data)) {
        source_data$row_id[i]
      } else {
        i
      }

      # Insert mapping
      DBI::dbExecute(
        con,
        "INSERT INTO concept_mappings (alignment_id, csv_file_path, row_id,
                                       target_omop_concept_id, imported_mapping_id, mapping_datetime)
         VALUES (?, ?, ?, ?, ?, ?)",
        params = list(alignment_id, csv_filename, source_row_id, target_concept_id, import_id, timestamp)
      )

      imported_count <- imported_count + 1
    }

    # Update import record with actual count
    DBI::dbExecute(
      con,
      "UPDATE imported_mappings SET concepts_count = ? WHERE import_id = ?",
      params = list(imported_count, import_id)
    )

    DBI::dbCommit(con)

    return(imported_count)
  }, error = function(e) {
    DBI::dbRollback(con)
    warning("Failed to import target concept mappings: ", e$message)
    return(0)
  })
}

#' Update concept alignment
#'
#' @description Update an existing concept alignment
#'
#' @param alignment_id Alignment ID
#' @param name Alignment name
#' @param description Alignment description
#'
#' @return TRUE if successful
#' @noRd
update_alignment <- function(alignment_id, name, description = "") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "UPDATE concept_alignments
     SET name = ?, description = ?, updated_at = ?
     WHERE alignment_id = ?",
    params = list(name, description, timestamp, alignment_id)
  )

  return(TRUE)
}

# CONCEPT MAPPINGS ====

#' Delete concept mapping
#'
#' @description Delete a mapping from the database
#'
#' @param mapping_id Mapping ID to delete
#'
#' @return TRUE if successful
#' @noRd
delete_concept_mapping <- function(mapping_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM concept_mappings WHERE mapping_id = ?",
    params = list(mapping_id)
  )

  TRUE
}

#' Get concept mappings for an alignment
#'
#' @description Retrieve all mappings for a specific alignment from the database
#'
#' @param alignment_id Alignment ID
#'
#' @return Data frame with mapping information
#' @noRd
get_alignment_mappings <- function(alignment_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT * FROM concept_mappings WHERE alignment_id = ?",
    params = list(alignment_id)
  )
}

# EXPORT FUNCTIONS ====

#' Export mappings in Usagi format
#'
#' @description Export mappings in a format compatible with OHDSI Usagi
#'
#' @param mappings_full Full mapping data from database
#' @param selected_mappings Filtered mappings with evaluation counts
#' @param source_df Source CSV data
#' @param vocab_data Vocabulary data (DuckDB connection)
#' @param alignment_name Name of the alignment
#' @param current_user Current user object
#' @param i18n Translation object
#'
#' @return Data frame in Usagi format
#' @noRd
export_usagi_format <- function(mappings_full, selected_mappings, source_df, vocab_data, alignment_name, current_user, i18n) {

  # Initialize export data frame with Usagi columns
  export_rows <- list()

  for (i in seq_len(nrow(mappings_full))) {
    mapping <- mappings_full[i, ]
    eval_data <- selected_mappings[selected_mappings$mapping_id == mapping$mapping_id, ]

    if (nrow(eval_data) == 0) next

    # Get source concept info from CSV
    source_code <- ""
    source_name <- ""
    source_frequency <- 0

    if (!is.null(source_df) && !is.na(mapping$row_id) && "row_id" %in% colnames(source_df)) {
      matching_rows <- source_df[source_df$row_id == mapping$row_id, ]
      if (nrow(matching_rows) > 0) {
        src_row <- matching_rows[1, ]
        if ("concept_code" %in% colnames(src_row)) {
          source_code <- as.character(src_row$concept_code)
        }
        if ("concept_name" %in% colnames(src_row)) {
          source_name <- as.character(src_row$concept_name)
        }
        if ("frequency" %in% colnames(src_row)) {
          source_frequency <- as.integer(src_row$frequency)
        }
      }
    }

    # Get target concept info from vocabulary
    concept_id <- 0
    concept_name <- ""
    domain_id <- ""
    vocabulary_id <- ""

    if (!is.na(mapping$target_omop_concept_id) && mapping$target_omop_concept_id != 0) {
      concept_id <- mapping$target_omop_concept_id

      if (!is.null(vocab_data)) {
        target_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == !!mapping$target_omop_concept_id) %>%
          dplyr::select(concept_id, concept_name, domain_id, vocabulary_id) %>%
          dplyr::collect()

        if (nrow(target_info) > 0) {
          concept_name <- target_info$concept_name[1]
          domain_id <- target_info$domain_id[1]
          vocabulary_id <- target_info$vocabulary_id[1]
        }
      }
    }

    # Determine mapping status based on evaluations
    approval_count <- eval_data$approval_count[1]
    rejection_count <- eval_data$rejection_count[1]
    uncertain_count <- eval_data$uncertain_count[1]
    total_evaluations <- eval_data$total_evaluations[1]

    mapping_status <- if (approval_count > 0) {
      "APPROVED"
    } else if (rejection_count > 0) {
      "INVALID"
    } else if (uncertain_count > 0) {
      "FLAGGED"
    } else {
      "UNCHECKED"
    }

    # Determine equivalence
    equivalence <- "UNREVIEWED"
    if (approval_count > 0 || rejection_count > 0 || uncertain_count > 0) {
      equivalence <- "EQUIVALENT"
    }

    # Build row
    export_row <- data.frame(
      sourceCode = source_code,
      sourceName = source_name,
      sourceFrequency = source_frequency,
      sourceAutoAssignedConceptIds = "",
      matchScore = 0.00,
      mappingStatus = mapping_status,
      equivalence = equivalence,
      statusSetBy = if (!is.null(current_user)) current_user$login else "",
      statusSetOn = floor(as.numeric(Sys.time()) * 1000),
      conceptId = concept_id,
      conceptName = concept_name,
      domainId = domain_id,
      mappingType = "MAPS_TO",
      comment = "",
      createdBy = if (!is.null(current_user)) current_user$login else "",
      createdOn = floor(as.numeric(as.POSIXct(mapping$mapping_datetime)) * 1000),
      assignedReviewer = "",
      stringsAsFactors = FALSE
    )

    export_rows[[length(export_rows) + 1]] <- export_row
  }

  if (length(export_rows) == 0) {
    return(data.frame(
      sourceCode = character(),
      sourceName = character(),
      sourceFrequency = integer(),
      sourceAutoAssignedConceptIds = character(),
      matchScore = numeric(),
      mappingStatus = character(),
      equivalence = character(),
      statusSetBy = character(),
      statusSetOn = numeric(),
      conceptId = integer(),
      conceptName = character(),
      domainId = character(),
      mappingType = character(),
      comment = character(),
      createdBy = character(),
      createdOn = numeric(),
      assignedReviewer = character(),
      stringsAsFactors = FALSE
    ))
  }

  dplyr::bind_rows(export_rows)
}

#' Export mappings in SOURCE_TO_CONCEPT_MAP format
#'
#' @description Export mappings in OMOP CDM SOURCE_TO_CONCEPT_MAP format
#'
#' @param mappings_full Full mapping data from database
#' @param source_df Source CSV data
#' @param vocab_data Vocabulary data (DuckDB connection)
#'
#' @return Data frame in SOURCE_TO_CONCEPT_MAP format
#' @noRd
export_source_to_concept_map_format <- function(mappings_full, source_df, vocab_data) {

  export_rows <- list()

  for (i in seq_len(nrow(mappings_full))) {
    mapping <- mappings_full[i, ]

    # Get source concept info from CSV
    source_code <- ""
    source_code_description <- ""
    source_vocabulary_id <- ""

    if (!is.null(source_df) && !is.na(mapping$row_id) && "row_id" %in% colnames(source_df)) {
      matching_rows <- source_df[source_df$row_id == mapping$row_id, ]
      if (nrow(matching_rows) > 0) {
        src_row <- matching_rows[1, ]
        if ("concept_code" %in% colnames(src_row)) {
          source_code <- as.character(src_row$concept_code)
        }
        if ("concept_name" %in% colnames(src_row)) {
          source_code_description <- as.character(src_row$concept_name)
        }
        if ("vocabulary_id" %in% colnames(src_row)) {
          source_vocabulary_id <- as.character(src_row$vocabulary_id)
        }
      }
    }

    # Get target concept info
    target_concept_id <- 0
    target_vocabulary_id <- ""

    if (!is.na(mapping$target_omop_concept_id) && mapping$target_omop_concept_id != 0) {
      target_concept_id <- mapping$target_omop_concept_id

      if (!is.null(vocab_data)) {
        target_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == !!mapping$target_omop_concept_id) %>%
          dplyr::select(concept_id, vocabulary_id) %>%
          dplyr::collect()

        if (nrow(target_info) > 0) {
          target_vocabulary_id <- target_info$vocabulary_id[1]
        }
      }
    }

    # Valid start date from mapping datetime
    valid_start_date <- "1970-01-01"
    if (!is.na(mapping$mapping_datetime)) {
      valid_start_date <- tryCatch(
        format(as.Date(as.POSIXct(mapping$mapping_datetime)), "%Y-%m-%d"),
        error = function(e) "1970-01-01"
      )
    }

    export_row <- data.frame(
      source_code = source_code,
      source_concept_id = 0L,
      source_vocabulary_id = source_vocabulary_id,
      source_code_description = source_code_description,
      target_concept_id = as.integer(target_concept_id),
      target_vocabulary_id = target_vocabulary_id,
      valid_start_date = valid_start_date,
      valid_end_date = "2099-12-31",
      invalid_reason = NA_character_,
      stringsAsFactors = FALSE
    )

    export_rows[[length(export_rows) + 1]] <- export_row
  }

  if (length(export_rows) == 0) {
    return(data.frame(
      source_code = character(),
      source_concept_id = integer(),
      source_vocabulary_id = character(),
      source_code_description = character(),
      target_concept_id = integer(),
      target_vocabulary_id = character(),
      valid_start_date = character(),
      valid_end_date = character(),
      invalid_reason = character(),
      stringsAsFactors = FALSE
    ))
  }

  dplyr::bind_rows(export_rows)
}

#' Export alignment in INDICATE Data Dictionary format
#'
#' @description Export alignment as ZIP file containing source concepts,
#' mappings, evaluations, comments and metadata
#'
#' @param alignment_id Alignment ID to export
#' @param alignment_name Name of the alignment
#' @param alignment_description Description of the alignment
#' @param current_user Current user information
#' @param db_path Path to the SQLite database
#' @param mapping_dir Path to concept_mapping directory
#'
#' @return Path to the created ZIP file (temporary file)
#' @noRd
export_indicate_format <- function(alignment_id, alignment_name, alignment_description,
                                    current_user, db_path, mapping_dir) {

  if (!file.exists(db_path)) {
    stop("Database not found")
  }

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Get alignment info
  alignment <- DBI::dbGetQuery(
    con,
    "SELECT * FROM concept_alignments WHERE alignment_id = ?",
    params = list(alignment_id)
  )

  if (nrow(alignment) == 0) {
    stop("Alignment not found")
  }

  # Get mappings for this alignment with user info
  mappings <- DBI::dbGetQuery(
    con,
    "SELECT cm.mapping_id, cm.row_id,
            cm.target_general_concept_id, cm.target_omop_concept_id, cm.target_custom_concept_id,
            cm.mapping_datetime,
            u.first_name as user_first_name, u.last_name as user_last_name
     FROM concept_mappings cm
     LEFT JOIN users u ON cm.mapped_by_user_id = u.user_id
     WHERE cm.alignment_id = ?",
    params = list(alignment_id)
  )

  # Get evaluations for these mappings with user info (first_name, last_name only)
  evaluations <- data.frame()
  if (nrow(mappings) > 0) {
    mapping_ids <- paste(mappings$mapping_id, collapse = ",")
    evaluations <- DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT e.mapping_id, e.is_approved, e.comment, e.evaluated_at,
                u.first_name as user_first_name, u.last_name as user_last_name
         FROM mapping_evaluations e
         LEFT JOIN users u ON e.evaluator_user_id = u.user_id
         WHERE e.mapping_id IN (%s)",
        mapping_ids
      )
    )
  }

  # Get comments for these mappings with user info (first_name, last_name only)
  comments <- data.frame()
  if (nrow(mappings) > 0) {
    mapping_ids <- paste(mappings$mapping_id, collapse = ",")
    comments <- DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT c.mapping_id, c.comment, c.created_at,
                u.first_name as user_first_name, u.last_name as user_last_name
         FROM mapping_comments c
         LEFT JOIN users u ON c.user_id = u.user_id
         WHERE c.mapping_id IN (%s)",
        mapping_ids
      )
    )
  }

  # Read source concepts CSV
  file_id <- alignment$file_id[1]
  source_csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
  source_concepts <- data.frame()
  if (file.exists(source_csv_path)) {
    source_concepts <- read.csv(source_csv_path, stringsAsFactors = FALSE)
  }

  # Calculate statistics
  stats <- list(
    total_source_concepts = nrow(source_concepts),
    total_mappings = nrow(mappings),
    total_evaluations = nrow(evaluations),
    total_comments = nrow(comments),
    approved_count = sum(evaluations$is_approved == 1, na.rm = TRUE),
    rejected_count = sum(evaluations$is_approved == 0, na.rm = TRUE),
    uncertain_count = sum(evaluations$is_approved == -1, na.rm = TRUE)
  )

  # Build exported_by as "First Last" or fallback to login

  exported_by_name <- "unknown"
  if (!is.null(current_user)) {
    if (!is.null(current_user$first_name) && !is.null(current_user$last_name) &&
        current_user$first_name != "" && current_user$last_name != "") {
      exported_by_name <- paste(current_user$first_name, current_user$last_name)
    } else if (!is.null(current_user$login)) {
      exported_by_name <- current_user$login
    }
  }

  # Create metadata
  metadata <- list(
    format_version = "1.0",
    format_type = "INDICATE_DATA_DICTIONARY",
    export_date = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
    exported_by = exported_by_name,
    alignment = list(
      name = alignment_name,
      description = alignment_description,
      created_date = alignment$created_date[1],
      column_types = if ("column_types" %in% colnames(alignment)) alignment$column_types[1] else NULL
    ),
    statistics = stats
  )

  # Create temporary directory for ZIP contents
  temp_dir <- tempfile(pattern = "indicate_export_")
  dir.create(temp_dir)

  # Write files
  jsonlite::write_json(metadata, file.path(temp_dir, "metadata.json"), pretty = TRUE, auto_unbox = TRUE)

  if (nrow(source_concepts) > 0) {
    write.csv(source_concepts, file.path(temp_dir, "source_concepts.csv"), row.names = FALSE)
  }

  if (nrow(mappings) > 0) {
    # Prepare mappings for export
    mappings_export <- mappings

    # Enrich mappings with vocabulary_id and concept_code from source_concepts
    # Join on row_id (DB) with row_id (CSV)
    if (nrow(source_concepts) > 0 && "row_id" %in% colnames(source_concepts)) {
      mappings_export$vocabulary_id <- NA_character_
      mappings_export$concept_code <- NA_character_

      for (i in seq_len(nrow(mappings_export))) {
        target_row_id <- mappings_export$row_id[i]
        matching_rows <- source_concepts[source_concepts$row_id == target_row_id, ]
        if (nrow(matching_rows) > 0) {
          src_row <- matching_rows[1, ]
          if ("vocabulary_id" %in% colnames(src_row)) {
            mappings_export$vocabulary_id[i] <- as.character(src_row$vocabulary_id)
          }
          if ("concept_code" %in% colnames(src_row)) {
            mappings_export$concept_code[i] <- as.character(src_row$concept_code)
          }
        }
      }
    }

    write.csv(mappings_export, file.path(temp_dir, "mappings.csv"), row.names = FALSE)
  }

  if (nrow(evaluations) > 0) {
    write.csv(evaluations, file.path(temp_dir, "evaluations.csv"), row.names = FALSE)
  }

  if (nrow(comments) > 0) {
    write.csv(comments, file.path(temp_dir, "comments.csv"), row.names = FALSE)
  }

  # Create ZIP file
  zip_path <- tempfile(pattern = "indicate_export_", fileext = ".zip")

  # Get list of files to zip
  files_to_zip <- list.files(temp_dir, full.names = TRUE)

  # Create ZIP (using zip package or base R)
  old_wd <- getwd()
  setwd(temp_dir)
  zip::zip(zip_path, files = basename(files_to_zip))
  setwd(old_wd)

  # Clean up temp directory

  unlink(temp_dir, recursive = TRUE)

  return(zip_path)
}


# IMPORT VALIDATION FUNCTIONS ====

#' Validate import file based on format
#'
#' @description Validates CSV file structure based on selected format
#'
#' @param csv_data Data frame from CSV file
#' @param format Import format (csv, stcm, usagi)
#' @param i18n Internationalization object
#'
#' @return List with valid (logical), message (character), and column_mapping (list)
#' @noRd
validate_import_file <- function(csv_data, format, i18n) {
  columns <- colnames(csv_data)

  if (format == "csv") {
    # CSV format: any columns accepted, manual mapping required
    return(list(
      valid = TRUE,
      message = "",
      column_mapping = NULL
    ))
  }

  if (format == "stcm") {
    # SOURCE_TO_CONCEPT_MAP format - required columns
    required_cols <- c("source_code", "source_vocabulary_id", "target_concept_id")
    missing <- setdiff(required_cols, columns)

    if (length(missing) > 0) {
      return(list(
        valid = FALSE,
        message = paste(i18n$t("missing_columns"), paste(missing, collapse = ", ")),
        column_mapping = NULL
      ))
    }

    return(list(
      valid = TRUE,
      message = "",
      column_mapping = list(
        source_code = "source_code",
        source_vocabulary_id = "source_vocabulary_id",
        target_concept_id = "target_concept_id"
      )
    ))
  }

  if (format == "usagi") {
    # Usagi format - required columns
    required_cols <- c("sourceCode", "conceptId")
    missing <- setdiff(required_cols, columns)

    if (length(missing) > 0) {
      return(list(
        valid = FALSE,
        message = paste(i18n$t("missing_columns"), paste(missing, collapse = ", ")),
        column_mapping = NULL
      ))
    }

    # Check for optional columns
    has_vocab <- "sourceVocabulary" %in% columns
    has_name <- "sourceName" %in% columns

    return(list(
      valid = TRUE,
      message = "",
      column_mapping = list(
        source_code = "sourceCode",
        source_vocabulary_id = if (has_vocab) "sourceVocabulary" else NULL,
        source_name = if (has_name) "sourceName" else NULL,
        target_concept_id = "conceptId"
      )
    ))
  }

  # Unknown format
  return(list(
    valid = FALSE,
    message = "Unknown format",
    column_mapping = NULL
  ))
}


#' Validate INDICATE ZIP file
#'
#' @description Validates INDICATE export ZIP file structure
#'
#' @param zip_path Path to ZIP file
#' @param i18n Internationalization object
#'
#' @return List with valid (logical), message (character), mappings_count, evaluations_count
#' @noRd
validate_indicate_zip <- function(zip_path, i18n) {
  if (!file.exists(zip_path)) {
    return(list(valid = FALSE, message = "File not found"))
  }

  # List files in ZIP
  tryCatch({
    zip_contents <- zip::zip_list(zip_path)
    files_in_zip <- zip_contents$filename

    # Check for required metadata.json
    if (!"metadata.json" %in% files_in_zip) {
      return(list(
        valid = FALSE,
        message = paste(i18n$t("missing_columns"), "metadata.json")
      ))
    }

    # Extract to temp directory for validation
    temp_dir <- tempfile(pattern = "indicate_validate_")
    dir.create(temp_dir)
    on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

    zip::unzip(zip_path, exdir = temp_dir)

    # Read and validate metadata
    metadata_path <- file.path(temp_dir, "metadata.json")
    metadata <- jsonlite::read_json(metadata_path)

    if (is.null(metadata$format_type) || metadata$format_type != "INDICATE_DATA_DICTIONARY") {
      return(list(
        valid = FALSE,
        message = paste(i18n$t("import_validation_error"), "Invalid format_type in metadata")
      ))
    }

    # Count mappings and evaluations
    mappings_count <- 0
    evaluations_count <- 0

    if ("mappings.csv" %in% files_in_zip) {
      mappings <- read.csv(file.path(temp_dir, "mappings.csv"), stringsAsFactors = FALSE)
      mappings_count <- nrow(mappings)
    }

    if ("evaluations.csv" %in% files_in_zip) {
      evaluations <- read.csv(file.path(temp_dir, "evaluations.csv"), stringsAsFactors = FALSE)
      evaluations_count <- nrow(evaluations)
    }

    return(list(
      valid = TRUE,
      message = "",
      mappings_count = mappings_count,
      evaluations_count = evaluations_count,
      metadata = metadata
    ))
  }, error = function(e) {
    return(list(
      valid = FALSE,
      message = e$message
    ))
  })
}
