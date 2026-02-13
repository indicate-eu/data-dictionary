#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbWriteTable dbExistsTable dbListTables dbGetQuery dbExecute
#' @importFrom readr read_tsv cols col_integer col_character col_date
#' @importFrom arrow read_parquet
#' @importFrom dplyr tbl
#' @importFrom magrittr %>%
NULL

#' Check if DuckDB database exists
#'
#' @description Check if DuckDB database file exists in app folder
#'
#' @return TRUE if database exists, FALSE otherwise
#' @noRd
duckdb_exists <- function() {
  db_path <- get_duckdb_path()
  return(file.exists(db_path))
}

#' Get DuckDB database path
#'
#' @description Get the path where DuckDB database should be stored
#'
#' @return Path to DuckDB database file
#' @noRd
get_duckdb_path <- function() {
  app_dir <- get_app_dir(create = TRUE)
  file.path(app_dir, "ohdsi_vocabularies.duckdb")
}

#' Detect vocabulary file format in a folder
#'
#' @description Detects whether vocabulary files are in CSV or Parquet format
#'
#' @param vocab_folder Path to vocabularies folder
#'
#' @return Character: "parquet", "csv", or NULL if neither found
#' @noRd
detect_vocab_format <- function(vocab_folder) {
  # Check for Parquet files first (preferred)
  if (file.exists(file.path(vocab_folder, "CONCEPT.parquet"))) {
    return("parquet")
  }
  # Fall back to CSV
  if (file.exists(file.path(vocab_folder, "CONCEPT.csv"))) {
    return("csv")
  }
  return(NULL)
}

#' Read vocabulary file (CSV or Parquet)
#'
#' @description Reads a vocabulary file in either CSV or Parquet format
#'
#' @param vocab_folder Path to vocabularies folder
#' @param table_name Table name (e.g., "CONCEPT", "CONCEPT_RELATIONSHIP")
#' @param format File format ("csv" or "parquet")
#' @param col_types Column types specification for CSV (readr format)
#'
#' @return Data frame with vocabulary data
#' @noRd
read_vocab_file <- function(vocab_folder, table_name, format, col_types = NULL) {
  if (format == "parquet") {
    file_path <- file.path(vocab_folder, paste0(table_name, ".parquet"))
    return(as.data.frame(arrow::read_parquet(file_path)))
  } else {
    file_path <- file.path(vocab_folder, paste0(table_name, ".csv"))
    return(readr::read_tsv(file_path, col_types = col_types, show_col_types = FALSE))
  }
}

#' Load Parquet file directly into DuckDB table
#'
#' @description Uses DuckDB's native Parquet support for fast loading
#'
#' @param con DuckDB connection
#' @param vocab_folder Path to vocabularies folder
#' @param table_name Table name (e.g., "CONCEPT", "CONCEPT_RELATIONSHIP")
#'
#' @return NULL (side effect: creates table in DuckDB)
#' @noRd
load_parquet_to_duckdb <- function(con, vocab_folder, table_name) {
  file_path <- file.path(vocab_folder, paste0(table_name, ".parquet"))
  sql <- sprintf(
    "CREATE OR REPLACE TABLE %s AS SELECT * FROM read_parquet('%s')",
    tolower(table_name),
    file_path
  )
  DBI::dbExecute(con, sql)
}

#' Create DuckDB database from CSV or Parquet files
#'
#' @description Create a DuckDB database from OHDSI vocabulary files (CSV or Parquet)
#'
#' @param vocab_folder Path to vocabularies folder containing CSV or Parquet files
#'
#' @return List with success status and message
#' @noRd
create_duckdb_database <- function(vocab_folder) {
  if (is.null(vocab_folder) || !dir.exists(vocab_folder)) {
    return(list(
      success = FALSE,
      message = "Invalid vocabularies folder path"
    ))
  }

  # Detect file format
  format <- detect_vocab_format(vocab_folder)

  if (is.null(format)) {
    return(list(
      success = FALSE,
      message = "No vocabulary files found. Expected CONCEPT.csv or CONCEPT.parquet"
    ))
  }

  # Define required tables
  required_tables <- c(
    "CONCEPT",
    "CONCEPT_RELATIONSHIP",
    "CONCEPT_ANCESTOR",
    "CONCEPT_SYNONYM",
    "RELATIONSHIP"
  )

  # File extension based on format
  ext <- if (format == "parquet") ".parquet" else ".csv"

  # Check if all required files exist
  missing_files <- c()
  for (table in required_tables) {
    if (!file.exists(file.path(vocab_folder, paste0(table, ext)))) {
      missing_files <- c(missing_files, paste0(table, ext))
    }
  }

  if (length(missing_files) > 0) {
    return(list(
      success = FALSE,
      message = paste("Missing required files:", paste(missing_files, collapse = ", "))
    ))
  }

  db_path <- get_duckdb_path()

  # Force close all DuckDB connections before removing the file
  if (file.exists(db_path)) {
    tryCatch({
      all_cons <- DBI::dbListConnections(duckdb::duckdb())
      for (con in all_cons) {
        try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
      }
    }, error = function(e) {
      # Ignore errors during cleanup
    })

    gc()
    gc()
    Sys.sleep(0.5)

    unlink(db_path)

    if (file.exists(db_path)) {
      return(list(
        success = FALSE,
        message = "Cannot delete existing database file. Please restart R and try again."
      ))
    }
  }

  tryCatch({
    # Create DuckDB connection
    drv <- duckdb::duckdb(dbdir = db_path, read_only = FALSE)
    con <- DBI::dbConnect(drv)

    # Load tables based on format
    if (format == "parquet") {
      load_parquet_to_duckdb(con, vocab_folder, "CONCEPT")
      load_parquet_to_duckdb(con, vocab_folder, "CONCEPT_RELATIONSHIP")
      load_parquet_to_duckdb(con, vocab_folder, "CONCEPT_ANCESTOR")
      load_parquet_to_duckdb(con, vocab_folder, "CONCEPT_SYNONYM")
      load_parquet_to_duckdb(con, vocab_folder, "RELATIONSHIP")
    } else {
      # Load CSV files via R
      concept <- read_vocab_file(
        vocab_folder, "CONCEPT", format,
        col_types = readr::cols(
          concept_id = readr::col_integer(),
          concept_name = readr::col_character(),
          domain_id = readr::col_character(),
          vocabulary_id = readr::col_character(),
          concept_class_id = readr::col_character(),
          standard_concept = readr::col_character(),
          concept_code = readr::col_character(),
          valid_start_date = readr::col_date(format = "%Y%m%d"),
          valid_end_date = readr::col_date(format = "%Y%m%d"),
          invalid_reason = readr::col_character()
        )
      )
      DBI::dbWriteTable(con, "concept", concept, overwrite = TRUE)

      concept_relationship <- read_vocab_file(
        vocab_folder, "CONCEPT_RELATIONSHIP", format,
        col_types = readr::cols(
          concept_id_1 = readr::col_integer(),
          concept_id_2 = readr::col_integer(),
          relationship_id = readr::col_character(),
          valid_start_date = readr::col_date(format = "%Y%m%d"),
          valid_end_date = readr::col_date(format = "%Y%m%d"),
          invalid_reason = readr::col_character()
        )
      )
      DBI::dbWriteTable(con, "concept_relationship", concept_relationship, overwrite = TRUE)

      concept_ancestor <- read_vocab_file(
        vocab_folder, "CONCEPT_ANCESTOR", format,
        col_types = readr::cols(
          ancestor_concept_id = readr::col_integer(),
          descendant_concept_id = readr::col_integer(),
          min_levels_of_separation = readr::col_integer(),
          max_levels_of_separation = readr::col_integer()
        )
      )
      DBI::dbWriteTable(con, "concept_ancestor", concept_ancestor, overwrite = TRUE)

      concept_synonym <- read_vocab_file(
        vocab_folder, "CONCEPT_SYNONYM", format,
        col_types = readr::cols(
          concept_id = readr::col_integer(),
          concept_synonym_name = readr::col_character(),
          language_concept_id = readr::col_integer()
        )
      )
      DBI::dbWriteTable(con, "concept_synonym", concept_synonym, overwrite = TRUE)

      relationship <- read_vocab_file(
        vocab_folder, "RELATIONSHIP", format,
        col_types = readr::cols(
          relationship_id = readr::col_character(),
          relationship_name = readr::col_character(),
          is_hierarchical = readr::col_integer(),
          defines_ancestry = readr::col_integer(),
          reverse_relationship_id = readr::col_character(),
          relationship_concept_id = readr::col_integer()
        )
      )
      DBI::dbWriteTable(con, "relationship", relationship, overwrite = TRUE)
    }

    # Create indexes for better performance
    DBI::dbExecute(con, "CREATE INDEX idx_concept_id ON concept(concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_code ON concept(concept_code)")
    DBI::dbExecute(con, "CREATE INDEX idx_vocabulary_id ON concept(vocabulary_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_standard_concept ON concept(standard_concept)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_rel_1 ON concept_relationship(concept_id_1)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_rel_2 ON concept_relationship(concept_id_2)")
    DBI::dbExecute(con, "CREATE INDEX idx_concept_rel_id ON concept_relationship(relationship_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_ancestor ON concept_ancestor(ancestor_concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_descendant ON concept_ancestor(descendant_concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_synonym_concept ON concept_synonym(concept_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_relationship_id ON relationship(relationship_id)")
    DBI::dbExecute(con, "CREATE INDEX idx_defines_ancestry ON relationship(defines_ancestry)")

    # Close connection
    DBI::dbDisconnect(con, shutdown = TRUE)

    format_label <- if (format == "parquet") "Parquet" else "CSV"
    return(list(
      success = TRUE,
      message = paste0("DuckDB database created successfully from ", format_label, " files"),
      db_path = db_path,
      format = format
    ))

  }, error = function(e) {
    if (exists("con")) {
      try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
    }
    if (file.exists(db_path)) {
      unlink(db_path)
    }

    return(list(
      success = FALSE,
      message = paste("Error creating DuckDB database:", e$message)
    ))
  })
}

#' Load vocabularies from DuckDB database
#'
#' @description Load OHDSI vocabulary tables from DuckDB as lazy dplyr::tbl objects
#'
#' @return List with vocabulary tables (concept, concept_relationship, concept_ancestor, etc.)
#'         or NULL if database doesn't exist
#' @noRd
load_vocabularies_from_duckdb <- function() {
  db_path <- get_duckdb_path()

  if (!file.exists(db_path)) {
    return(NULL)
  }

  tryCatch({
    drv <- duckdb::duckdb(dbdir = db_path, read_only = TRUE)
    con <- DBI::dbConnect(drv)

    # Return lazy tbl objects for each table
    list(
      concept = dplyr::tbl(con, "concept"),
      concept_relationship = dplyr::tbl(con, "concept_relationship"),
      concept_ancestor = dplyr::tbl(con, "concept_ancestor"),
      concept_synonym = dplyr::tbl(con, "concept_synonym"),
      relationship = dplyr::tbl(con, "relationship"),
      .con = con
    )
  }, error = function(e) {
    warning("Error loading vocabularies from DuckDB: ", e$message)
    return(NULL)
  })
}

#' Get DuckDB connection
#'
#' @description Get a read-only connection to DuckDB database
#'
#' @return DuckDB connection or NULL if database doesn't exist
#' @noRd
get_duckdb_connection <- function() {
  db_path <- get_duckdb_path()

  if (!file.exists(db_path)) {
    return(NULL)
  }

  tryCatch({
    drv <- duckdb::duckdb(dbdir = db_path, read_only = TRUE)
    DBI::dbConnect(drv)
  }, error = function(e) {
    warning("Error connecting to DuckDB: ", e$message)
    return(NULL)
  })
}

#' Get Concept by ID
#'
#' @description Get concept details from vocabulary database
#'
#' @param concept_id OMOP Concept ID
#'
#' @return Data frame with concept details or empty data frame
#' @noRd
get_concept_by_id <- function(concept_id) {
  con <- get_duckdb_connection()
  if (is.null(con)) {
    return(data.frame())
  }
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  tryCatch({
    DBI::dbGetQuery(
      con,
      "SELECT
        concept_id,
        concept_name,
        domain_id,
        vocabulary_id,
        concept_class_id,
        standard_concept,
        concept_code,
        valid_start_date,
        valid_end_date
      FROM concept
      WHERE concept_id = ?",
      params = list(as.integer(concept_id))
    )
  }, error = function(e) {
    warning("Error getting concept: ", e$message)
    data.frame()
  })
}

#' Get Related Concepts
#'
#' @description Get concepts related to a given concept
#'
#' @param concept_id OMOP Concept ID
#' @param limit Maximum number of results (default 100)
#'
#' @return Data frame with related concepts
#' @noRd
get_related_concepts <- function(concept_id, limit = 100) {
  con <- get_duckdb_connection()
  if (is.null(con)) {
    return(data.frame())
  }
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  tryCatch({
    DBI::dbGetQuery(
      con,
      "SELECT
        c.concept_id,
        c.concept_name,
        cr.relationship_id,
        c.vocabulary_id
      FROM concept_relationship cr
      JOIN concept c ON cr.concept_id_2 = c.concept_id
      WHERE cr.concept_id_1 = ?
        AND cr.invalid_reason IS NULL
      ORDER BY cr.relationship_id, c.concept_name
      LIMIT ?",
      params = list(as.integer(concept_id), as.integer(limit))
    )
  }, error = function(e) {
    warning("Error getting related concepts: ", e$message)
    data.frame()
  })
}

#' Get Concept Descendants
#'
#' @description Get descendant concepts from the concept_ancestor table
#'
#' @param concept_id OMOP Concept ID
#'
#' @return Data frame with descendant concepts (no limit)
#' @noRd
get_concept_descendants <- function(concept_id) {
  con <- get_duckdb_connection()
  if (is.null(con)) {
    return(data.frame())
  }
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  tryCatch({
    DBI::dbGetQuery(
      con,
      "SELECT
        c.concept_id,
        c.concept_name,
        c.vocabulary_id,
        ca.min_levels_of_separation,
        ca.max_levels_of_separation
      FROM concept_ancestor ca
      JOIN concept c ON ca.descendant_concept_id = c.concept_id
      WHERE ca.ancestor_concept_id = ?
        AND ca.min_levels_of_separation > 0
      ORDER BY ca.min_levels_of_separation, c.concept_name",
      params = list(as.integer(concept_id))
    )
  }, error = function(e) {
    warning("Error getting concept descendants: ", e$message)
    data.frame()
  })
}

#' Get Concept Synonyms
#'
#' @description Get synonyms for a concept from the concept_synonym table
#'
#' @param concept_id OMOP Concept ID
#' @param limit Maximum number of results (default 100)
#'
#' @return Data frame with synonyms
#' @noRd
get_concept_synonyms <- function(concept_id, limit = 100) {
  con <- get_duckdb_connection()
  if (is.null(con)) {
    return(data.frame())
  }
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  tryCatch({
    # Check if concept_synonym table exists
    tables <- DBI::dbListTables(con)
    if (!"concept_synonym" %in% tables) {
      return(data.frame())
    }

    DBI::dbGetQuery(
      con,
      "SELECT
        cs.concept_synonym_name AS synonym,
        COALESCE(c.concept_name, 'Unknown') AS language,
        cs.language_concept_id
      FROM concept_synonym cs
      LEFT JOIN concept c ON cs.language_concept_id = c.concept_id
      WHERE cs.concept_id = ?
      ORDER BY cs.concept_synonym_name
      LIMIT ?",
      params = list(as.integer(concept_id), as.integer(limit))
    )
  }, error = function(e) {
    warning("Error getting concept synonyms: ", e$message)
    data.frame()
  })
}

#' Get Concept Hierarchy Graph Data
#'
#' @description Build hierarchy graph data for visNetwork visualization.
#' Gets ancestors and descendants for a concept.
#'
#' @param concept_id OMOP Concept ID
#' @param max_levels_up Maximum ancestor levels to include (default: 5)
#' @param max_levels_down Maximum descendant levels to include (default: 5)
#'
#' @return List with nodes and edges data frames for visNetwork
#' @noRd
get_concept_hierarchy_graph <- function(concept_id, max_levels_up = 5, max_levels_down = 5) {
  con <- get_duckdb_connection()
  if (is.null(con)) {
    return(list(nodes = data.frame(), edges = data.frame(), stats = NULL))
  }
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  tryCatch({
    # Get selected concept details
    selected_concept <- DBI::dbGetQuery(
      con,
      "SELECT concept_id, concept_name, vocabulary_id, concept_code,
              domain_id, concept_class_id, standard_concept, invalid_reason
       FROM concept WHERE concept_id = ?",
      params = list(as.integer(concept_id))
    )

    if (nrow(selected_concept) == 0) {
      return(list(nodes = data.frame(), edges = data.frame(), stats = NULL))
    }

    # Get ancestors (concepts where the selected concept is a descendant)
    ancestors <- DBI::dbGetQuery(
      con,
      "SELECT ca.ancestor_concept_id AS concept_id,
              c.concept_name, c.vocabulary_id, c.concept_code,
              c.domain_id, c.concept_class_id, c.standard_concept, c.invalid_reason,
              -ca.min_levels_of_separation AS hierarchy_level
       FROM concept_ancestor ca
       JOIN concept c ON ca.ancestor_concept_id = c.concept_id
       WHERE ca.descendant_concept_id = ?
         AND ca.min_levels_of_separation > 0
         AND ca.min_levels_of_separation <= ?
       ORDER BY ca.min_levels_of_separation",
      params = list(as.integer(concept_id), as.integer(max_levels_up))
    )

    # Get descendants
    descendants <- DBI::dbGetQuery(
      con,
      "SELECT ca.descendant_concept_id AS concept_id,
              c.concept_name, c.vocabulary_id, c.concept_code,
              c.domain_id, c.concept_class_id, c.standard_concept, c.invalid_reason,
              ca.min_levels_of_separation AS hierarchy_level
       FROM concept_ancestor ca
       JOIN concept c ON ca.descendant_concept_id = c.concept_id
       WHERE ca.ancestor_concept_id = ?
         AND ca.min_levels_of_separation > 0
         AND ca.min_levels_of_separation <= ?
       ORDER BY ca.min_levels_of_separation",
      params = list(as.integer(concept_id), as.integer(max_levels_down))
    )

    # Combine all concepts
    selected_concept$hierarchy_level <- 0
    all_concepts <- rbind(
      selected_concept,
      if (nrow(ancestors) > 0) ancestors else data.frame(),
      if (nrow(descendants) > 0) descendants else data.frame()
    )

    if (nrow(all_concepts) == 0) {
      return(list(nodes = data.frame(), edges = data.frame(), stats = NULL))
    }

    # Build nodes data frame for visNetwork
    nodes <- data.frame(
      id = all_concepts$concept_id,
      label = ifelse(
        nchar(all_concepts$concept_name) > 50,
        paste0(substr(all_concepts$concept_name, 1, 47), "..."),
        all_concepts$concept_name
      ),
      level = all_concepts$hierarchy_level,
      color = ifelse(
        all_concepts$concept_id == concept_id,
        "#0f60af",  # Selected concept: blue
        ifelse(
          all_concepts$hierarchy_level < 0,
          "#6c757d",  # Ancestors: gray
          "#28a745"   # Descendants: green
        )
      ),
      shape = "box",
      borderWidth = ifelse(all_concepts$concept_id == concept_id, 4, 2),
      font.size = ifelse(all_concepts$concept_id == concept_id, 16, 13),
      font.color = "white",
      stringsAsFactors = FALSE
    )

    # Build title (tooltip) for nodes
    standard_display <- dplyr::case_when(
      is.na(all_concepts$standard_concept) | all_concepts$standard_concept == "" ~ "Non-standard",
      all_concepts$standard_concept == "S" ~ "Standard",
      all_concepts$standard_concept == "C" ~ "Classification",
      TRUE ~ "Non-standard"
    )
    validity_display <- ifelse(
      is.na(all_concepts$invalid_reason) | all_concepts$invalid_reason == "",
      "Valid",
      all_concepts$invalid_reason
    )

    nodes$title <- paste0(
      "<div style='font-family: Arial; padding: 10px; max-width: 400px;'>",
      "<b style='color: #0f60af;'>", all_concepts$concept_name, "</b><br><br>",
      "<table style='font-size: 12px; border-spacing: 8px 2px;'>",
      "<tr><td style='color: #666; padding-right: 12px;'>OMOP ID:</td><td><b>", all_concepts$concept_id, "</b></td></tr>",
      "<tr><td style='color: #666; padding-right: 12px;'>Vocabulary:</td><td>", all_concepts$vocabulary_id, "</td></tr>",
      "<tr><td style='color: #666; padding-right: 12px;'>Code:</td><td>", all_concepts$concept_code, "</td></tr>",
      "<tr><td style='color: #666; padding-right: 12px;'>Domain:</td><td>", all_concepts$domain_id, "</td></tr>",
      "<tr><td style='color: #666; padding-right: 12px;'>Class:</td><td>", all_concepts$concept_class_id, "</td></tr>",
      "<tr><td style='color: #666; padding-right: 12px;'>Standard:</td><td>", standard_display, "</td></tr>",
      "<tr><td style='color: #666; padding-right: 12px;'>Validity:</td><td>", validity_display, "</td></tr>",
      "</table></div>"
    )

    # Get direct parent-child relationships (min_levels_of_separation = 1)
    all_concept_ids <- all_concepts$concept_id
    edges <- DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT ancestor_concept_id AS from_id, descendant_concept_id AS to_id
         FROM concept_ancestor
         WHERE min_levels_of_separation = 1
           AND ancestor_concept_id IN (%s)
           AND descendant_concept_id IN (%s)",
        paste(all_concept_ids, collapse = ","),
        paste(all_concept_ids, collapse = ",")
      )
    )

    if (nrow(edges) > 0) {
      edges <- data.frame(
        from = edges$from_id,
        to = edges$to_id,
        arrows = "to",
        color = "#999",
        width = 2,
        stringsAsFactors = FALSE
      )
    } else {
      edges <- data.frame(
        from = integer(0),
        to = integer(0),
        arrows = character(0),
        color = character(0),
        width = numeric(0)
      )
    }

    # Calculate stats
    stats <- list(
      total_ancestors = nrow(ancestors),
      total_descendants = nrow(descendants),
      displayed_ancestors = nrow(ancestors),
      displayed_descendants = nrow(descendants)
    )

    return(list(nodes = nodes, edges = edges, stats = stats))

  }, error = function(e) {
    warning("Error getting concept hierarchy graph: ", e$message)
    return(list(nodes = data.frame(), edges = data.frame(), stats = NULL))
  })
}

#' Count Concept Hierarchy Size (Fast)
#'
#' @description Quickly count the number of ancestors and descendants
#' for a concept without building the full graph.
#'
#' @param concept_id OMOP Concept ID
#' @param max_levels_up Maximum ancestor levels to count (default: 5)
#' @param max_levels_down Maximum descendant levels to count (default: 5)
#'
#' @return List with ancestors_count, descendants_count, and total_count
#' @noRd
count_hierarchy_concepts <- function(concept_id, max_levels_up = 5, max_levels_down = 5) {
  con <- get_duckdb_connection()
  if (is.null(con)) {
    return(list(ancestors_count = 0, descendants_count = 0, total_count = 1))
  }
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  tryCatch({
    # Count ancestors
    ancestors_count <- DBI::dbGetQuery(
      con,
      "SELECT COUNT(*) as cnt
       FROM concept_ancestor
       WHERE descendant_concept_id = ?
         AND min_levels_of_separation > 0
         AND min_levels_of_separation <= ?",
      params = list(as.integer(concept_id), as.integer(max_levels_up))
    )$cnt

    # Count descendants
    descendants_count <- DBI::dbGetQuery(
      con,
      "SELECT COUNT(*) as cnt
       FROM concept_ancestor
       WHERE ancestor_concept_id = ?
         AND min_levels_of_separation > 0
         AND min_levels_of_separation <= ?",
      params = list(as.integer(concept_id), as.integer(max_levels_down))
    )$cnt

    return(list(
      ancestors_count = ancestors_count,
      descendants_count = descendants_count,
      total_count = ancestors_count + descendants_count + 1
    ))

  }, error = function(e) {
    warning("Error counting hierarchy concepts: ", e$message)
    return(list(ancestors_count = 0, descendants_count = 0, total_count = 1))
  })
}

#' Delete DuckDB database
#'
#' @description Delete the DuckDB database file
#'
#' @return List with success status and message
#' @noRd
delete_duckdb_database <- function() {
  db_path <- get_duckdb_path()

  if (!file.exists(db_path)) {
    return(list(
      success = TRUE,
      message = "DuckDB database does not exist"
    ))
  }

  tryCatch({
    gc()
    Sys.sleep(0.5)
    unlink(db_path)

    return(list(
      success = TRUE,
      message = "DuckDB database deleted successfully"
    ))
  }, error = function(e) {
    return(list(
      success = FALSE,
      message = paste("Error deleting DuckDB database:", e$message)
    ))
  })
}

#' Resolve Concept Set
#'
#' @description Resolve a concept set by including descendants and mapped concepts
#' based on the include_descendants and include_mapped flags, and excluding
#' concepts marked as is_excluded.
#'
#' @param concepts Data frame with concept set items. Must contain columns:
#'   concept_id, is_excluded, include_descendants, include_mapped
#'
#' @return Data frame with resolved concepts (unique, sorted by concept_name)
#' @noRd
resolve_concept_set <- function(concepts) {
  if (is.null(concepts) || nrow(concepts) == 0) {
    return(data.frame())
  }

  # Ensure required columns exist with default values
  if (!"is_excluded" %in% names(concepts)) {
    concepts$is_excluded <- FALSE
  }
  if (!"include_descendants" %in% names(concepts)) {
    concepts$include_descendants <- TRUE
  }
  if (!"include_mapped" %in% names(concepts)) {
    concepts$include_mapped <- TRUE
  }

  # Convert to logical if needed
  concepts$is_excluded <- as.logical(concepts$is_excluded)
  concepts$include_descendants <- as.logical(concepts$include_descendants)
  concepts$include_mapped <- as.logical(concepts$include_mapped)

  # Replace NA with defaults
  concepts$is_excluded[is.na(concepts$is_excluded)] <- FALSE
  concepts$include_descendants[is.na(concepts$include_descendants)] <- TRUE
  concepts$include_mapped[is.na(concepts$include_mapped)] <- TRUE

  # Check if DuckDB is available
  db_path <- get_duckdb_path()
  if (!file.exists(db_path)) {
    # No vocabulary database - just filter out excluded concepts
    return(concepts[!concepts$is_excluded, ])
  }

  # Partition into included and excluded items
  included_items <- concepts[!concepts$is_excluded, ]
  excluded_items <- concepts[concepts$is_excluded, ]

  if (nrow(included_items) == 0) {
    return(data.frame())
  }

  # Start with base concept IDs for included set
  included_ids <- included_items$concept_id

  tryCatch({
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

    # --- Build INCLUDED set ---

    # Add descendants where include_descendants is TRUE
    incl_with_desc <- included_items[included_items$include_descendants == TRUE, ]
    if (nrow(incl_with_desc) > 0) {
      ancestor_ids <- paste(incl_with_desc$concept_id, collapse = ",")
      descendants <- DBI::dbGetQuery(
        con,
        sprintf(
          "SELECT DISTINCT descendant_concept_id
           FROM concept_ancestor
           WHERE ancestor_concept_id IN (%s)
             AND descendant_concept_id != ancestor_concept_id",
          ancestor_ids
        )
      )
      if (nrow(descendants) > 0) {
        included_ids <- c(included_ids, descendants$descendant_concept_id)
      }
    }

    # Add mapped concepts where include_mapped is TRUE
    incl_with_mapped <- included_items[included_items$include_mapped == TRUE, ]
    if (nrow(incl_with_mapped) > 0) {
      source_ids <- paste(incl_with_mapped$concept_id, collapse = ",")
      mapped <- DBI::dbGetQuery(
        con,
        sprintf(
          "SELECT DISTINCT concept_id_2
           FROM concept_relationship
           WHERE concept_id_1 IN (%s)
             AND relationship_id IN ('Maps to', 'Mapped from')",
          source_ids
        )
      )
      if (nrow(mapped) > 0) {
        included_ids <- c(included_ids, mapped$concept_id_2)
      }
    }

    included_ids <- unique(included_ids)

    # --- Build EXCLUDED set ---

    excluded_ids <- integer(0)
    if (nrow(excluded_items) > 0) {
      # Start with base excluded concept IDs
      excluded_ids <- excluded_items$concept_id

      # Add descendants where include_descendants is TRUE
      excl_with_desc <- excluded_items[excluded_items$include_descendants == TRUE, ]
      if (nrow(excl_with_desc) > 0) {
        ancestor_ids <- paste(excl_with_desc$concept_id, collapse = ",")
        descendants <- DBI::dbGetQuery(
          con,
          sprintf(
            "SELECT DISTINCT descendant_concept_id
             FROM concept_ancestor
             WHERE ancestor_concept_id IN (%s)
               AND descendant_concept_id != ancestor_concept_id",
            ancestor_ids
          )
        )
        if (nrow(descendants) > 0) {
          excluded_ids <- c(excluded_ids, descendants$descendant_concept_id)
        }
      }

      # Add mapped concepts where include_mapped is TRUE
      excl_with_mapped <- excluded_items[excluded_items$include_mapped == TRUE, ]
      if (nrow(excl_with_mapped) > 0) {
        source_ids <- paste(excl_with_mapped$concept_id, collapse = ",")
        mapped <- DBI::dbGetQuery(
          con,
          sprintf(
            "SELECT DISTINCT concept_id_2
             FROM concept_relationship
             WHERE concept_id_1 IN (%s)
               AND relationship_id IN ('Maps to', 'Mapped from')",
            source_ids
          )
        )
        if (nrow(mapped) > 0) {
          excluded_ids <- c(excluded_ids, mapped$concept_id_2)
        }
      }

      excluded_ids <- unique(excluded_ids)
    }

    # --- Final resolution: INCLUDED minus EXCLUDED ---

    resolved_ids <- setdiff(included_ids, excluded_ids)

    # Get concept details for all resolved IDs
    if (length(resolved_ids) > 0) {
      ids_str <- paste(resolved_ids, collapse = ",")
      resolved_concepts <- DBI::dbGetQuery(
        con,
        sprintf(
          "SELECT concept_id, concept_name, vocabulary_id, domain_id,
                  concept_class_id, concept_code, standard_concept
           FROM concept
           WHERE concept_id IN (%s)
           ORDER BY concept_name",
          ids_str
        )
      )

      return(resolved_concepts)
    }

    return(data.frame())

  }, error = function(e) {
    warning("Error resolving concept set: ", e$message)
    # Fallback: return non-excluded concepts
    return(concepts[!concepts$is_excluded, ])
  })
}

#' Export concept set to ATLAS JSON format
#'
#' @description Export a concept set in ATLAS-compatible format.
#'              Outputs only the expression object with UPPER_SNAKE_CASE concept fields,
#'              as expected by OHDSI ATLAS import.
#'
#' @param concept_set_id Concept set ID
#' @param concepts_data Data frame with concept set items (optional, if not provided will be fetched)
#'
#' @return JSON string in ATLAS format
#' @noRd
export_concept_set_to_atlas_json <- function(concept_set_id, concepts_data = NULL) {
  tryCatch({
    # Get concepts if not provided
    if (is.null(concepts_data)) {
      con <- get_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)
      concepts_data <- DBI::dbGetQuery(
        con,
        "SELECT * FROM concept_set_items WHERE concept_set_id = ? ORDER BY concept_id",
        params = list(concept_set_id)
      )
    } else {
      concepts_data <- concepts_data[order(concepts_data$concept_id), ]
    }

    # Enrich concepts with DuckDB vocabulary data
    vocab_lookup <- NULL
    if (duckdb_exists() && nrow(concepts_data) > 0) {
      tryCatch({
        con_vocab <- get_duckdb_connection()
        on.exit(DBI::dbDisconnect(con_vocab, shutdown = TRUE), add = TRUE)
        ids <- paste(concepts_data$concept_id, collapse = ",")
        vocab_lookup <- DBI::dbGetQuery(
          con_vocab,
          paste0("SELECT concept_id, standard_concept, invalid_reason,
                  valid_start_date, valid_end_date FROM concept WHERE concept_id IN (", ids, ")")
        )
      }, error = function(e) NULL)
    }

    # Build ATLAS-compatible items with UPPER_SNAKE_CASE concept fields
    items <- lapply(seq_len(nrow(concepts_data)), function(i) {
      concept <- concepts_data[i, ]
      cid <- as.integer(concept$concept_id)

      # Use DuckDB data if available, fallback to SQLite data
      vocab_row <- if (!is.null(vocab_lookup)) vocab_lookup[vocab_lookup$concept_id == cid, ] else NULL
      has_vocab <- !is.null(vocab_row) && nrow(vocab_row) > 0

      std_concept <- if (has_vocab) {
        v <- vocab_row$standard_concept[1]
        if (is.na(v) || v == "") NULL else as.character(v)
      } else {
        if (length(concept$standard_concept) == 0 || is.na(concept$standard_concept)) NULL else as.character(concept$standard_concept)
      }

      invalid_reason <- if (has_vocab) {
        v <- vocab_row$invalid_reason[1]
        if (is.na(v) || v == "") NULL else as.character(v)
      } else {
        if (length(concept$invalid_reason) == 0 || is.na(concept$invalid_reason)) NULL else as.character(concept$invalid_reason)
      }

      valid_start <- if (has_vocab) as.character(vocab_row$valid_start_date[1]) else "19700101"
      valid_end <- if (has_vocab) as.character(vocab_row$valid_end_date[1]) else "20991231"

      # ATLAS expects YYYYMMDD format without dashes
      valid_start <- gsub("-", "", valid_start)
      valid_end <- gsub("-", "", valid_end)

      list(
        concept = list(
          CONCEPT_ID = cid,
          CONCEPT_NAME = as.character(concept$concept_name),
          DOMAIN_ID = as.character(concept$domain_id),
          VOCABULARY_ID = as.character(concept$vocabulary_id),
          CONCEPT_CLASS_ID = as.character(concept$concept_class_id),
          STANDARD_CONCEPT = if (is.null(std_concept)) "" else std_concept,
          STANDARD_CONCEPT_CAPTION = if (is.null(std_concept)) "Unknown" else if (std_concept == "S") "Standard" else "Non-Standard",
          CONCEPT_CODE = as.character(concept$concept_code),
          VALID_START_DATE = valid_start,
          VALID_END_DATE = valid_end,
          INVALID_REASON = if (is.null(invalid_reason)) "V" else invalid_reason,
          INVALID_REASON_CAPTION = if (is.null(invalid_reason)) "Valid" else "Invalid"
        ),
        isExcluded = as.logical(concept$is_excluded) %in% TRUE,
        includeDescendants = as.logical(concept$include_descendants) %in% TRUE,
        includeMapped = as.logical(concept$include_mapped) %in% TRUE
      )
    })

    # ATLAS expects only the expression object: { "items": [...] }
    result <- list(items = items)

    return(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE, null = "null"))

  }, error = function(e) {
    warning("Error exporting to ATLAS JSON: ", e$message)
    return(NULL)
  })
}

#' Export concept set to OHDSI JSON format
#'
#' @description Export a concept set to OHDSI-compliant JSON format
#'              Based on https://ohdsi.github.io/TAB/Concept-Set-Specification.html
#'
#' @param concept_set_id Concept set ID
#' @param concepts_data Data frame with concept set items (optional, if not provided will be fetched)
#'
#' @return JSON string in OHDSI format
#' @noRd
export_concept_set_to_json <- function(concept_set_id, concepts_data = NULL) {
  tryCatch({
    # Get concept set metadata
    con <- get_db_connection()
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    cs <- DBI::dbGetQuery(
      con,
      "SELECT * FROM concept_sets WHERE id = ?",
      params = list(concept_set_id)
    )

    if (nrow(cs) == 0) {
      stop("Concept set not found")
    }

    # Get concepts if not provided
    if (is.null(concepts_data)) {
      concepts_data <- DBI::dbGetQuery(
        con,
        "SELECT * FROM concept_set_items WHERE concept_set_id = ? ORDER BY concept_id",
        params = list(concept_set_id)
      )
    } else {
      concepts_data <- concepts_data[order(concepts_data$concept_id), ]
    }

    # Enrich concepts with DuckDB vocabulary data (valid dates, standard_concept, invalid_reason)
    vocab_lookup <- NULL
    if (duckdb_exists() && nrow(concepts_data) > 0) {
      tryCatch({
        con_vocab <- get_duckdb_connection()
        on.exit(DBI::dbDisconnect(con_vocab, shutdown = TRUE), add = TRUE)
        ids <- paste(concepts_data$concept_id, collapse = ",")
        vocab_lookup <- DBI::dbGetQuery(
          con_vocab,
          paste0("SELECT concept_id, standard_concept, invalid_reason,
                  valid_start_date, valid_end_date FROM concept WHERE concept_id IN (", ids, ")")
        )
      }, error = function(e) NULL)
    }

    # Build OHDSI JSON structure - expression items
    items <- lapply(seq_len(nrow(concepts_data)), function(i) {
      concept <- concepts_data[i, ]
      cid <- as.integer(concept$concept_id)

      # Use DuckDB data if available, fallback to SQLite data
      vocab_row <- if (!is.null(vocab_lookup)) vocab_lookup[vocab_lookup$concept_id == cid, ] else NULL
      has_vocab <- !is.null(vocab_row) && nrow(vocab_row) > 0

      std_concept <- if (has_vocab) {
        v <- vocab_row$standard_concept[1]
        if (is.na(v) || v == "") NULL else as.character(v)
      } else {
        if (length(concept$standard_concept) == 0 || is.na(concept$standard_concept)) NULL else as.character(concept$standard_concept)
      }

      invalid_reason <- if (has_vocab) {
        v <- vocab_row$invalid_reason[1]
        if (is.na(v) || v == "") NULL else as.character(v)
      } else {
        if (length(concept$invalid_reason) == 0 || is.na(concept$invalid_reason)) NULL else as.character(concept$invalid_reason)
      }

      valid_start <- if (has_vocab) as.character(vocab_row$valid_start_date[1]) else "1970-01-01"
      valid_end <- if (has_vocab) as.character(vocab_row$valid_end_date[1]) else "2099-12-31"

      list(
        concept = list(
          conceptId = cid,
          conceptName = as.character(concept$concept_name),
          domainId = as.character(concept$domain_id),
          vocabularyId = as.character(concept$vocabulary_id),
          conceptClassId = as.character(concept$concept_class_id),
          standardConcept = std_concept,
          standardConceptCaption = if (is.null(std_concept)) "Unknown" else if (std_concept == "S") "Standard" else "Non-Standard",
          conceptCode = as.character(concept$concept_code),
          validStartDate = valid_start,
          validEndDate = valid_end,
          invalidReason = invalid_reason,
          invalidReasonCaption = if (is.null(invalid_reason)) "Valid" else "Invalid"
        ),
        isExcluded = as.logical(concept$is_excluded) %in% TRUE,
        includeDescendants = as.logical(concept$include_descendants) %in% TRUE,
        includeMapped = as.logical(concept$include_mapped) %in% TRUE
      )
    })

    # Parse tags if present
    tags <- if (!is.null(cs$tags) && !is.na(cs$tags) && nchar(cs$tags) > 0) {
      strsplit(cs$tags, ",")[[1]]
    } else {
      character(0)
    }

    # Get reviews with full user information
    reviews_data <- DBI::dbGetQuery(
      con,
      "SELECT r.review_id, r.status, r.comments, r.review_date, r.concept_set_version,
              u.first_name, u.last_name, u.affiliation, u.profession, u.orcid
       FROM concept_set_reviews r
       LEFT JOIN users u ON r.reviewer_user_id = u.user_id
       WHERE r.concept_set_id = ?
       ORDER BY r.review_date DESC",
      params = list(concept_set_id)
    )

    reviews <- if (nrow(reviews_data) > 0) {
      lapply(seq_len(nrow(reviews_data)), function(i) {
        r <- reviews_data[i, ]
        list(
          reviewId = as.integer(r$review_id),
          reviewer = list(
            firstName = if (!is.na(r$first_name)) as.character(r$first_name) else NULL,
            lastName = if (!is.na(r$last_name)) as.character(r$last_name) else NULL,
            affiliation = if (!is.na(r$affiliation)) as.character(r$affiliation) else NULL,
            profession = if (!is.na(r$profession)) as.character(r$profession) else NULL,
            orcid = if (!is.na(r$orcid)) as.character(r$orcid) else NULL
          ),
          reviewDate = as.character(r$review_date),
          status = as.character(r$status),
          comments = if (!is.na(r$comments)) as.character(r$comments) else NULL,
          version = as.character(r$concept_set_version)
        )
      })
    } else {
      list()
    }

    # Get version history
    versions_data <- DBI::dbGetQuery(
      con,
      "SELECT version_to AS version, change_date AS version_date, change_summary
       FROM concept_set_changelog
       WHERE concept_set_id = ?
       ORDER BY change_date DESC",
      params = list(concept_set_id)
    )

    versions <- if (nrow(versions_data) > 0) {
      lapply(seq_len(nrow(versions_data)), function(i) {
        v <- versions_data[i, ]
        list(
          version = as.character(v$version),
          versionDate = as.character(v$version_date),
          changeSummary = if (!is.na(v$change_summary)) as.character(v$change_summary) else NULL
        )
      })
    } else {
      list()
    }

    # Get distribution stats
    stats_data <- DBI::dbGetQuery(
      con,
      "SELECT stats FROM concept_set_stats WHERE concept_set_id = ?",
      params = list(concept_set_id)
    )

    distribution_stats <- if (nrow(stats_data) > 0 && !is.na(stats_data$stats[1])) {
      jsonlite::fromJSON(stats_data$stats[1])
    } else {
      NULL
    }

    # Get all translations
    translations_data <- DBI::dbGetQuery(
      con,
      "SELECT language, field, value FROM concept_set_translations WHERE concept_set_id = ?",
      params = list(concept_set_id)
    )

    # Organize translations by language
    translations <- list()
    if (nrow(translations_data) > 0) {
      languages <- unique(translations_data$language)
      for (lang in languages) {
        lang_data <- translations_data[translations_data$language == lang, ]

        # Create named list with correct field order
        lang_translations <- list()

        # Add fields in order: name, description, category, subcategory, longDescription
        field_order <- c("name", "description", "category", "subcategory", "long_description")
        field_names <- c("name", "description", "category", "subcategory", "longDescription")

        for (i in seq_along(field_order)) {
          field <- field_order[i]
          field_name <- field_names[i]
          value <- lang_data$value[lang_data$field == field]
          if (length(value) > 0 && !is.na(value)) {
            lang_translations[[field_name]] <- value
          }
        }

        if (length(lang_translations) > 0) {
          translations[[lang]] <- lang_translations
        }
      }
    }

    # Build createdByDetails
    created_by_details <- list(
      firstName = if (!is.null(cs$created_by_first_name) && !is.na(cs$created_by_first_name)) as.character(cs$created_by_first_name) else NULL,
      lastName = if (!is.null(cs$created_by_last_name) && !is.na(cs$created_by_last_name)) as.character(cs$created_by_last_name) else NULL,
      affiliation = if (!is.null(cs$created_by_affiliation) && !is.na(cs$created_by_affiliation)) as.character(cs$created_by_affiliation) else NULL,
      profession = if (!is.null(cs$created_by_profession) && !is.na(cs$created_by_profession)) as.character(cs$created_by_profession) else NULL,
      orcid = if (!is.null(cs$created_by_orcid) && !is.na(cs$created_by_orcid)) as.character(cs$created_by_orcid) else NULL
    )

    # Build author display names from first/last name fields
    build_author_name <- function(first, last) {
      first <- if (!is.null(first) && !is.na(first) && nchar(first) > 0) first else NULL
      last <- if (!is.null(last) && !is.na(last) && nchar(last) > 0) last else NULL
      if (!is.null(first) && !is.null(last)) paste(first, last)
      else if (!is.null(first)) first
      else if (!is.null(last)) last
      else NULL
    }
    created_by_name <- build_author_name(cs$created_by_first_name, cs$created_by_last_name)
    modified_by_name <- build_author_name(cs$modified_by_first_name, cs$modified_by_last_name)

    # Convert timestamps (2026-02-12T16:03:49Z) to date-only (2026-02-12)
    to_date_only <- function(x) {
      if (is.null(x) || is.na(x)) return(NULL)
      substr(as.character(x), 1, 10)
    }

    # Build complete OHDSI-compliant JSON structure
    result <- list(
      id = as.integer(cs$id),
      name = as.character(cs$name),
      description = if (!is.null(cs$description) && !is.na(cs$description)) as.character(cs$description) else NULL,
      version = if (!is.null(cs$version) && !is.na(cs$version)) as.character(cs$version) else "1.0.0",
      createdBy = created_by_name,
      createdDate = to_date_only(cs$created_date),
      modifiedBy = if (!is.null(modified_by_name)) modified_by_name else created_by_name,
      modifiedDate = to_date_only(cs$modified_date),
      createdByTool = "INDICATE Data Dictionary v0.2.0.9002",
      expression = list(
        items = items
      ),
      tags = tags,
      reviewStatus = if (!is.null(cs$review_status) && !is.na(cs$review_status) && cs$review_status != "") as.character(cs$review_status) else "draft",
      metadata = list(
        translations = if (length(translations) > 0) translations else NULL,
        createdByDetails = created_by_details,
        reviews = reviews,
        versions = versions,
        distributionStats = distribution_stats
      )
    )

    return(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE, null = "null"))

  }, error = function(e) {
    warning("Error exporting to JSON: ", e$message)
    return(NULL)
  })
}

#' Export all concept sets to ZIP file
#'
#' @description Creates a ZIP file containing all concept sets as JSON files
#'
#' @param language Language code for translations (default: "en")
#' @param concept_set_ids Optional vector of concept set IDs to export (default: NULL = all)
#'
#' @return Path to the generated ZIP file, or NULL on error
#' @noRd
export_all_concept_sets <- function(language = "en", concept_set_ids = NULL) {
  tryCatch({
    # Get all concept sets with translations
    concept_sets <- get_all_concept_sets(language = language)

    if (is.null(concept_sets) || nrow(concept_sets) == 0) {
      return(NULL)
    }

    # Filter by concept_set_ids if provided
    if (!is.null(concept_set_ids) && length(concept_set_ids) > 0) {
      concept_sets <- concept_sets[concept_sets$id %in% concept_set_ids, ]
      if (nrow(concept_sets) == 0) {
        return(NULL)
      }
    }

    # Create temporary directory for export
    temp_dir <- tempfile()
    dir.create(temp_dir)
    concept_sets_dir <- file.path(temp_dir, "concept_sets")
    dir.create(concept_sets_dir)

    # Export each concept set as JSON
    for (i in seq_len(nrow(concept_sets))) {
      cs <- concept_sets[i, ]
      json <- export_concept_set_to_json(cs$id)

      if (!is.null(json)) {
        json_path <- file.path(concept_sets_dir, sprintf("%d.json", cs$id))
        writeLines(json, json_path, useBytes = TRUE)
      }
    }

    # Create ZIP file
    zip_file <- tempfile(fileext = ".zip")
    current_dir <- getwd()
    setwd(temp_dir)
    utils::zip(zip_file, "concept_sets", flags = "-r9Xq")
    setwd(current_dir)

    # Check if ZIP was created
    if (!file.exists(zip_file)) {
      return(NULL)
    }

    # Clean up temp directory
    unlink(temp_dir, recursive = TRUE)

    return(zip_file)

  }, error = function(e) {
    warning("Error exporting all concept sets: ", e$message)
    return(NULL)
  })
}

#' Export resolved concept IDs as comma-separated list
#'
#' @description Export concept set as comma-separated list of concept IDs (for PHOEBE)
#'
#' @param concepts_data Data frame with concept set items
#'
#' @return Character string with comma-separated concept IDs
#' @noRd
export_concept_list <- function(concepts_data) {
  # Resolve the concept set
  resolved <- resolve_concept_set(concepts_data)

  if (nrow(resolved) == 0) {
    return("")
  }

  # Return comma-separated list of concept IDs
  return(paste(resolved$concept_id, collapse = ", "))
}

#' Generate SQL query for concept set
#'
#' @description Generate SQL query to retrieve all records matching the resolved concepts
#'              Groups by domain_id to query appropriate CDM tables
#'
#' @param concept_set_name Name of the concept set (for comment)
#' @param concepts_data Data frame with concept set items
#' @param include_names Logical, if TRUE includes concept names as comments (default: TRUE)
#'
#' @return SQL query string
#' @noRd
export_concept_set_to_sql <- function(concept_set_name, concepts_data, include_names = TRUE) {
  # Resolve the concept set
  resolved <- resolve_concept_set(concepts_data)

  if (nrow(resolved) == 0) {
    return("-- No concepts to query")
  }

  # Group concepts by domain_id
  domains <- split(resolved, resolved$domain_id)

  # Map domain_id to CDM table names
  domain_table_map <- list(
    "Condition" = "condition_occurrence",
    "Drug" = "drug_exposure",
    "Procedure" = "procedure_occurrence",
    "Measurement" = "measurement",
    "Observation" = "observation",
    "Device" = "device_exposure",
    "Specimen" = "specimen",
    "Visit" = "visit_occurrence"
  )

  # Build SQL queries for each domain
  queries <- character()

  for (domain in names(domains)) {
    table_name <- domain_table_map[[domain]]

    if (is.null(table_name)) {
      # Skip domains without a clear CDM table mapping
      next
    }

    concepts_in_domain <- domains[[domain]]

    # Build concept IDs list with optional names
    if (include_names) {
      # Create list with comments
      concept_lines <- sapply(seq_len(nrow(concepts_in_domain)), function(i) {
        concept <- concepts_in_domain[i, ]
        # Clean concept name for comment (remove special characters that might break SQL)
        clean_name <- gsub("'", "''", concept$concept_name)
        sprintf("  %s%s-- %s",
                concept$concept_id,
                if (i < nrow(concepts_in_domain)) "," else "",
                clean_name)
      })
      concept_ids_str <- paste(concept_lines, collapse = "\n")
    } else {
      # Simple comma-separated list
      concept_ids_str <- paste(concepts_in_domain$concept_id, collapse = ", ")
    }

    # Determine concept_id column name based on table
    concept_col <- paste0(gsub("_occurrence|_exposure", "", table_name), "_concept_id")

    if (include_names) {
      query <- sprintf(
        "-- %s domain\nSELECT *\nFROM %s\nWHERE %s IN (\n%s\n)",
        domain,
        table_name,
        concept_col,
        concept_ids_str
      )
    } else {
      query <- sprintf(
        "-- %s domain\nSELECT *\nFROM %s\nWHERE %s IN (%s)",
        domain,
        table_name,
        concept_col,
        concept_ids_str
      )
    }

    queries <- c(queries, query)
  }

  # Combine all queries with UNION ALL
  if (length(queries) == 0) {
    return("-- No queryable domains found")
  }

  header <- sprintf("-- SQL query for concept set: %s\n-- Generated on: %s\n\n",
                    concept_set_name,
                    format(Sys.time(), "%Y-%m-%d %H:%M:%S"))

  if (length(queries) == 1) {
    return(paste0(header, queries[1]))
  }

  # For multiple tables, we can't use UNION ALL (different schemas)
  # So we return each query separately
  return(paste0(header, paste(queries, collapse = "\n\n")))
}

#' Import concept set from JSON file
#'
#' @description Imports a concept set from an OHDSI-compliant JSON file
#'              Fetches complete concept details from vocabulary database
#'
#' @param json_file Path to JSON file
#' @param language Language code for default language (default: "en")
#'
#' @return Concept set ID if successful, NULL on error
#' @noRd
import_concept_set_from_json <- function(json_file, language = "en") {
  tryCatch({
    # Read JSON file with UTF-8 encoding
    json_text <- readLines(json_file, encoding = "UTF-8", warn = FALSE)
    json_data <- jsonlite::fromJSON(paste(json_text, collapse = "\n"), simplifyVector = FALSE)

    # Extract basic concept set information
    concept_set_id <- json_data$id  # Get ID from JSON to preserve it
    name <- json_data$name
    description <- json_data$description
    version <- if (!is.null(json_data$version)) json_data$version else "1.0.0"
    tags <- if (!is.null(json_data$tags) && length(json_data$tags) > 0) paste(unlist(json_data$tags), collapse = ",") else NULL

    # Extract translatable fields from translations
    # IMPORTANT: category and subcategory should ALWAYS use English values (as translation keys)
    # Only longDescription uses the specified language
    translations <- json_data$metadata$translations
    en_data <- if (!is.null(translations[["en"]])) translations[["en"]] else NULL
    lang_data <- if (!is.null(translations[[language]])) translations[[language]] else translations[["en"]]

    # Always use English values for category/subcategory (translation keys)
    category <- if (!is.null(en_data$category)) en_data$category else NULL
    subcategory <- if (!is.null(en_data$subcategory)) en_data$subcategory else NULL
    # Use specified language for long description
    long_description <- if (!is.null(lang_data$longDescription)) lang_data$longDescription else NULL

    # Extract author information
    created_by_first_name <- NULL
    created_by_last_name <- NULL
    created_by_profession <- NULL
    created_by_affiliation <- NULL
    created_by_orcid <- NULL

    if (!is.null(json_data$metadata$createdByDetails)) {
      created_by_first_name <- json_data$metadata$createdByDetails$firstName
      created_by_last_name <- json_data$metadata$createdByDetails$lastName
      created_by_profession <- json_data$metadata$createdByDetails$profession
      created_by_affiliation <- json_data$metadata$createdByDetails$affiliation
      created_by_orcid <- json_data$metadata$createdByDetails$orcid
    } else if (!is.null(json_data$createdBy)) {
      # Parse "FirstName LastName" format
      parts <- strsplit(json_data$createdBy, " ")[[1]]
      if (length(parts) >= 2) {
        created_by_first_name <- parts[1]
        created_by_last_name <- paste(parts[-1], collapse = " ")
      }
    }

    # Create concept set in database with the ID from JSON
    concept_set_id <- add_concept_set(
      id = concept_set_id,  # Pass the ID from JSON to preserve it
      name = name,
      description = description,
      category = category,
      subcategory = subcategory,
      tags = tags,
      long_description = long_description,
      created_by_first_name = created_by_first_name,
      created_by_last_name = created_by_last_name,
      created_by_profession = created_by_profession,
      created_by_affiliation = created_by_affiliation,
      created_by_orcid = created_by_orcid,
      language = language
    )

    # Add translations if present
    if (!is.null(json_data$metadata$translations)) {
      translations <- json_data$metadata$translations

      for (lang in names(translations)) {
        lang_data <- translations[[lang]]

        # Set translations for this language
        if (!is.null(lang_data$name)) {
          set_concept_set_translation(concept_set_id, lang, "name", lang_data$name)
        }
        if (!is.null(lang_data$description)) {
          set_concept_set_translation(concept_set_id, lang, "description", lang_data$description)
        }
        if (!is.null(lang_data$category)) {
          set_concept_set_translation(concept_set_id, lang, "category", lang_data$category)
        }
        if (!is.null(lang_data$subcategory)) {
          set_concept_set_translation(concept_set_id, lang, "subcategory", lang_data$subcategory)
        }
        if (!is.null(lang_data$longDescription)) {
          set_concept_set_translation(concept_set_id, lang, "long_description", lang_data$longDescription)
        }
      }
    }

    # Update version if different from default
    if (!is.null(version) && version != "1.0.0") {
      update_concept_set(concept_set_id, version = version, language = language)
    }

    # Update review status if present
    review_status <- json_data$reviewStatus
    if (!is.null(review_status) && review_status != "draft") {
      update_concept_set(concept_set_id, review_status = review_status, language = language)
    }

    # Import concept set items if present
    if (!is.null(json_data$expression$items) && length(json_data$expression$items) > 0) {
      # Get DuckDB connection to fetch concept details
      if (duckdb_exists()) {
        con_vocab <- get_duckdb_connection()
        on.exit(DBI::dbDisconnect(con_vocab, shutdown = TRUE), add = TRUE)

        # PERFORMANCE OPTIMIZATION: Batch query all concept IDs at once
        # Extract all concept IDs from items
        all_concept_ids <- sapply(json_data$expression$items, function(item) item$concept$conceptId)

        # Fetch all concept details in a single query
        concept_ids_string <- paste(all_concept_ids, collapse = ",")
        all_concept_details <- DBI::dbGetQuery(
          con_vocab,
          sprintf("SELECT concept_id, concept_name, domain_id, vocabulary_id, concept_class_id,
                          standard_concept, concept_code
                   FROM concept
                   WHERE concept_id IN (%s)", concept_ids_string)
        )

        # Create a lookup map for fast access
        concepts_map <- setNames(
          split(all_concept_details, seq(nrow(all_concept_details))),
          all_concept_details$concept_id
        )

        # Now loop through items and use the lookup map
        for (item in json_data$expression$items) {
          concept_id <- item$concept$conceptId
          is_excluded <- isTRUE(item$isExcluded)
          include_descendants <- isTRUE(item$includeDescendants)
          include_mapped <- isTRUE(item$includeMapped)

          # Look up concept details from the map
          if (as.character(concept_id) %in% names(concepts_map)) {
            concept <- concepts_map[[as.character(concept_id)]]

            # Add concept to concept set
            add_concept_set_item(
              concept_set_id = concept_set_id,
              concept_id = concept$concept_id,
              concept_name = concept$concept_name,
              vocabulary_id = concept$vocabulary_id,
              concept_code = concept$concept_code,
              domain_id = concept$domain_id,
              concept_class_id = concept$concept_class_id,
              standard_concept = concept$standard_concept,
              is_excluded = is_excluded,
              include_descendants = include_descendants,
              include_mapped = include_mapped
            )
          } else {
            # Concept not found in vocabulary - add with placeholder values
            warning(sprintf("Concept %d not found in vocabulary database", concept_id))
            add_concept_set_item(
              concept_set_id = concept_set_id,
              concept_id = concept_id,
              concept_name = if (!is.null(item$concept$conceptName)) item$concept$conceptName else paste0("Concept ", concept_id),
              vocabulary_id = if (!is.null(item$concept$vocabularyId)) item$concept$vocabularyId else "Unknown",
              concept_code = if (!is.null(item$concept$conceptCode)) item$concept$conceptCode else "",
              domain_id = if (!is.null(item$concept$domainId)) item$concept$domainId else "Unknown",
              concept_class_id = if (!is.null(item$concept$conceptClassId)) item$concept$conceptClassId else "Unknown",
              standard_concept = if (!is.null(item$concept$standardConcept)) item$concept$standardConcept else NULL,
              is_excluded = is_excluded,
              include_descendants = include_descendants,
              include_mapped = include_mapped
            )
          }
        }
      } else {
        # No vocabulary database - add with placeholder values from JSON
        for (item in json_data$expression$items) {
          add_concept_set_item(
            concept_set_id = concept_set_id,
            concept_id = item$concept$conceptId,
            concept_name = if (!is.null(item$concept$conceptName)) item$concept$conceptName else paste0("Concept ", item$concept$conceptId),
            vocabulary_id = if (!is.null(item$concept$vocabularyId)) item$concept$vocabularyId else "Unknown",
            concept_code = if (!is.null(item$concept$conceptCode)) item$concept$conceptCode else "",
            domain_id = if (!is.null(item$concept$domainId)) item$concept$domainId else "Unknown",
            concept_class_id = if (!is.null(item$concept$conceptClassId)) item$concept$conceptClassId else "Unknown",
            standard_concept = if (!is.null(item$concept$standardConcept)) item$concept$standardConcept else NULL,
            is_excluded = isTRUE(item$isExcluded),
            include_descendants = isTRUE(item$includeDescendants),
            include_mapped = isTRUE(item$includeMapped)
          )
        }
      }
    }

    return(concept_set_id)

  }, error = function(e) {
    warning("Error importing concept set from JSON: ", e$message)
    return(NULL)
  })
}
