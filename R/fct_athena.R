#' Load OHDSI Vocabularies
#'
#' @description
#' Load OHDSI vocabulary files from disk into memory
#'
#' @param vocab_folder Path to OHDSI vocabularies folder
#'
#' @return List with concept, concept_relationship, and concept_ancestor data frames
#' @noRd
#'
#' @importFrom readr read_tsv cols col_integer col_character
load_ohdsi_vocabularies <- function(vocab_folder) {
  if (is.null(vocab_folder) || vocab_folder == "" || !dir.exists(vocab_folder)) {
    message("OHDSI Vocabularies folder not configured or doesn't exist")
    return(NULL)
  }

  tryCatch({
    message("Loading OHDSI vocabularies from: ", vocab_folder)

    # Check if DuckDB option is enabled and database exists
    use_duckdb <- get_use_duckdb()
    db_exists <- duckdb_exists(vocab_folder)

    if (use_duckdb && db_exists) {
      message("  Loading from DuckDB database...")
      result <- load_vocabularies_from_duckdb(vocab_folder)
      message("  OHDSI vocabularies loaded successfully from DuckDB!")
      return(result)
    }

    # Fall back to CSV loading
    concept_path <- file.path(vocab_folder, "CONCEPT.csv")
    concept_relationship_path <- file.path(vocab_folder, "CONCEPT_RELATIONSHIP.csv")
    concept_ancestor_path <- file.path(vocab_folder, "CONCEPT_ANCESTOR.csv")

    if (!file.exists(concept_path) || !file.exists(concept_relationship_path) || !file.exists(concept_ancestor_path)) {
      message("Required vocabulary files not found in: ", vocab_folder)
      return(NULL)
    }

    # Load all three files in parallel using future
    message("  Loading CONCEPT, CONCEPT_RELATIONSHIP, and CONCEPT_ANCESTOR in parallel from CSV...")

    concept_future <- future::future({
      readr::read_tsv(
        concept_path,
        col_types = readr::cols(
          concept_id = readr::col_integer(),
          concept_name = readr::col_character(),
          domain_id = readr::col_character(),
          vocabulary_id = readr::col_character(),
          concept_class_id = readr::col_character(),
          standard_concept = readr::col_character(),
          concept_code = readr::col_character(),
          invalid_reason = readr::col_character()
        ),
        show_col_types = FALSE
      )
    })

    concept_relationship_future <- future::future({
      readr::read_tsv(
        concept_relationship_path,
        col_types = readr::cols(
          concept_id_1 = readr::col_integer(),
          concept_id_2 = readr::col_integer(),
          relationship_id = readr::col_character()
        ),
        show_col_types = FALSE
      )
    })

    concept_ancestor_future <- future::future({
      readr::read_tsv(
        concept_ancestor_path,
        col_types = readr::cols(
          ancestor_concept_id = readr::col_integer(),
          descendant_concept_id = readr::col_integer()
        ),
        show_col_types = FALSE
      )
    })

    # Wait for all futures to complete
    concept <- future::value(concept_future)
    concept_relationship <- future::value(concept_relationship_future)
    concept_ancestor <- future::value(concept_ancestor_future)

    message("  OHDSI vocabularies loaded successfully from CSV!")

    return(list(
      concept = concept,
      concept_relationship = concept_relationship,
      concept_ancestor = concept_ancestor
    ))

  }, error = function(e) {
    message("Error loading OHDSI vocabularies: ", e$message)
    return(NULL)
  })
}

#' Query OHDSI Vocabularies for Related Concepts
#'
#' @description
#' Functions to query preloaded OHDSI vocabularies for concept relationships
#' and descendants
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing preloaded vocabulary data frames
#'
#' @return Data frame with related concepts
#' @noRd
#'
#' @importFrom dplyr filter select left_join bind_rows distinct arrange mutate

#' Get related concepts (maps to / mapped from) - filtered for standard and valid
get_related_concepts_filtered <- function(concept_id, vocabularies) {
  if (is.null(vocabularies)) {
    return(data.frame())
  }

  tryCatch({
    # Get all relationships for this concept (filter BEFORE collecting)
    relationships <- vocabularies$concept_relationship %>%
      dplyr::filter(
        concept_id_1 == concept_id | concept_id_2 == concept_id
      ) %>%
      dplyr::collect()

    if (nrow(relationships) == 0) {
      return(data.frame())
    }

    # Get related concept IDs
    related_ids <- unique(c(
      relationships$concept_id_1[relationships$concept_id_2 == concept_id],
      relationships$concept_id_2[relationships$concept_id_1 == concept_id]
    ))

    # Get concept details for related concepts (filter BEFORE collecting)
    concepts_info <- vocabularies$concept %>%
      dplyr::filter(
        concept_id %in% related_ids,
        standard_concept == 'S',
        is.na(invalid_reason)
      ) %>%
      dplyr::collect()

    if (nrow(concepts_info) == 0) {
      return(data.frame())
    }

    # Build related concepts with relationship information
    related_data <- data.frame()

    for (i in 1:nrow(relationships)) {
      rel <- relationships[i, ]
      related_concept_id <- ifelse(rel$concept_id_1 == concept_id, rel$concept_id_2, rel$concept_id_1)

      # Find concept info
      concept_info <- concepts_info[concepts_info$concept_id == related_concept_id, ]

      if (nrow(concept_info) > 0) {
        related_data <- dplyr::bind_rows(
          related_data,
          data.frame(
            omop_concept_id = concept_info$concept_id[1],
            concept_name = concept_info$concept_name[1],
            vocabulary_id = concept_info$vocabulary_id[1],
            concept_code = concept_info$concept_code[1],
            relationship_id = rel$relationship_id,
            stringsAsFactors = FALSE
          )
        )
      }
    }

    return(related_data)

  }, error = function(e) {
    message("Error querying related concepts: ", e$message)
    return(data.frame())
  })
}

#' Get related concepts (maps to / mapped from) - all concepts without filtering
get_related_concepts <- function(concept_id, vocabularies) {
  if (is.null(vocabularies)) {
    return(data.frame())
  }

  tryCatch({
    # Get all relationships for this concept (filter BEFORE collecting)
    relationships <- vocabularies$concept_relationship %>%
      dplyr::filter(
        concept_id_1 == concept_id | concept_id_2 == concept_id
      ) %>%
      dplyr::collect()

    if (nrow(relationships) == 0) {
      return(data.frame())
    }

    # Get related concept IDs
    related_ids <- unique(c(
      relationships$concept_id_1[relationships$concept_id_2 == concept_id],
      relationships$concept_id_2[relationships$concept_id_1 == concept_id]
    ))

    # Get concept details for related concepts (filter BEFORE collecting, no other filtering)
    concepts_info <- vocabularies$concept %>%
      dplyr::filter(concept_id %in% related_ids) %>%
      dplyr::collect()

    if (nrow(concepts_info) == 0) {
      return(data.frame())
    }

    # Build related concepts with relationship information
    related_data <- data.frame()

    for (i in 1:nrow(relationships)) {
      rel <- relationships[i, ]
      related_concept_id <- ifelse(rel$concept_id_1 == concept_id, rel$concept_id_2, rel$concept_id_1)

      # Find concept info
      concept_info <- concepts_info[concepts_info$concept_id == related_concept_id, ]

      if (nrow(concept_info) > 0) {
        related_data <- dplyr::bind_rows(
          related_data,
          data.frame(
            omop_concept_id = concept_info$concept_id[1],
            concept_name = concept_info$concept_name[1],
            vocabulary_id = concept_info$vocabulary_id[1],
            concept_code = concept_info$concept_code[1],
            relationship_id = rel$relationship_id,
            stringsAsFactors = FALSE
          )
        )
      }
    }

    return(related_data)

  }, error = function(e) {
    message("Error querying related concepts: ", e$message)
    return(data.frame())
  })
}

#' Get descendant concepts from concept_ancestor
get_descendant_concepts <- function(concept_id, vocabularies) {
  if (is.null(vocabularies)) {
    return(data.frame())
  }

  tryCatch({
    # Get descendants (filter BEFORE collecting)
    descendants <- vocabularies$concept_ancestor %>%
      dplyr::filter(ancestor_concept_id == concept_id) %>%
      dplyr::collect()

    if (nrow(descendants) == 0) {
      return(data.frame())
    }

    # Get concept details for descendants (filter BEFORE collecting)
    descendant_concepts <- vocabularies$concept %>%
      dplyr::filter(
        concept_id %in% descendants$descendant_concept_id,
        standard_concept == 'S',
        is.na(invalid_reason)
      ) %>%
      dplyr::select(
        omop_concept_id = concept_id,
        concept_name,
        vocabulary_id,
        concept_code
      ) %>%
      dplyr::collect() %>%
      dplyr::mutate(relationship_id = "Is a")

    return(descendant_concepts)

  }, error = function(e) {
    message("Error querying descendant concepts: ", e$message)
    return(data.frame())
  })
}

#' Get all related concepts (combined)
get_all_related_concepts <- function(concept_id, vocabularies, existing_mappings) {
  # Get related concepts from relationships
  related <- get_related_concepts(concept_id, vocabularies)

  # Get descendant concepts
  descendants <- get_descendant_concepts(concept_id, vocabularies)

  # Combine and remove duplicates
  all_concepts <- dplyr::bind_rows(related, descendants) %>%
    dplyr::distinct(omop_concept_id, .keep_all = TRUE)

  if (nrow(all_concepts) == 0) {
    return(data.frame())
  }

  # Mark as recommended if in existing mappings
  all_concepts <- all_concepts %>%
    dplyr::mutate(
      recommended = omop_concept_id %in% existing_mappings$omop_concept_id
    ) %>%
    dplyr::arrange(dplyr::desc(recommended), concept_name)

  return(all_concepts)
}
