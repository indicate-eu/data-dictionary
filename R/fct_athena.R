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

    concept_path <- file.path(vocab_folder, "CONCEPT.csv")
    concept_relationship_path <- file.path(vocab_folder, "CONCEPT_RELATIONSHIP.csv")
    concept_ancestor_path <- file.path(vocab_folder, "CONCEPT_ANCESTOR.csv")

    if (!file.exists(concept_path) || !file.exists(concept_relationship_path) || !file.exists(concept_ancestor_path)) {
      message("Required vocabulary files not found in: ", vocab_folder)
      return(NULL)
    }

    # Load all three files in parallel using future
    message("  Loading CONCEPT, CONCEPT_RELATIONSHIP, and CONCEPT_ANCESTOR in parallel...")

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
          concept_code = readr::col_character()
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

    message("  OHDSI vocabularies loaded successfully!")

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

#' Get related concepts (maps to / mapped from)
get_related_concepts <- function(concept_id, vocabularies) {
  if (is.null(vocabularies)) {
    return(data.frame())
  }

  tryCatch({
    concept_relationship <- vocabularies$concept_relationship
    concept <- vocabularies$concept

    # Get relationships: Maps to / Mapped from
    relationships <- concept_relationship %>%
      dplyr::filter(
        (concept_id_1 == concept_id | concept_id_2 == concept_id) &
        relationship_id %in% c("Maps to", "Mapped from")
      )

    # Get related concept IDs
    related_ids <- unique(c(
      relationships$concept_id_1[relationships$concept_id_2 == concept_id],
      relationships$concept_id_2[relationships$concept_id_1 == concept_id]
    ))

    if (length(related_ids) == 0) {
      return(data.frame())
    }

    # Get concept details
    related_concepts <- concept %>%
      dplyr::filter(concept_id %in% related_ids) %>%
      dplyr::select(
        omop_concept_id = concept_id,
        concept_name,
        vocabulary_id,
        concept_code
      )

    return(related_concepts)

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
    concept_ancestor <- vocabularies$concept_ancestor
    concept <- vocabularies$concept

    # Get descendants
    descendants <- concept_ancestor %>%
      dplyr::filter(ancestor_concept_id == concept_id)

    if (nrow(descendants) == 0) {
      return(data.frame())
    }

    # Get concept details
    descendant_concepts <- concept %>%
      dplyr::filter(concept_id %in% descendants$descendant_concept_id) %>%
      dplyr::select(
        omop_concept_id = concept_id,
        concept_name,
        vocabulary_id,
        concept_code
      )

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
