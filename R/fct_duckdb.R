#' DuckDB Functions
#'
#' @description Functions to manage DuckDB database for OHDSI vocabularies
#'
#' @noRd
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbWriteTable dbExistsTable dbListTables dbGetQuery dbExecute
#' @importFrom readr read_tsv cols col_integer col_character col_date
#' @importFrom arrow read_parquet
#' @importFrom dplyr tbl

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
              domain_id, concept_class_id, standard_concept
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
              c.domain_id, c.concept_class_id, c.standard_concept,
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
              c.domain_id, c.concept_class_id, c.standard_concept,
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
    nodes$title <- paste0(
      "<div style='font-family: Arial; padding: 10px; max-width: 400px;'>",
      "<b style='color: #0f60af;'>", all_concepts$concept_name, "</b><br><br>",
      "<table style='font-size: 12px;'>",
      "<tr><td style='color: #666;'>OMOP ID:</td><td><b>", all_concepts$concept_id, "</b></td></tr>",
      "<tr><td style='color: #666;'>Vocabulary:</td><td>", all_concepts$vocabulary_id, "</td></tr>",
      "<tr><td style='color: #666;'>Code:</td><td>", all_concepts$concept_code, "</td></tr>",
      "<tr><td style='color: #666;'>Domain:</td><td>", all_concepts$domain_id, "</td></tr>",
      "<tr><td style='color: #666;'>Class:</td><td>", all_concepts$concept_class_id, "</td></tr>",
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
