#' OHDSI Mappings Functions
#'
#' @description Functions to load and manage OHDSI vocabulary relationship mappings
#'
#' @noRd

#' Load OHDSI relationships mappings
#'
#' @description Load additional concept mappings from OHDSI vocabulary relationships
#' for all recommended concepts. This enriches the dictionary with related concepts.
#'
#' @param vocab_data Vocabularies data (DuckDB connection with concept, concept_relationship, concept_ancestor tables)
#' @param concept_mappings Current concept_mappings dataframe
#' @param preserve_recommended Logical. If TRUE, preserve the recommended status of existing ohdsi_relationships mappings
#'
#' @return Updated concept_mappings dataframe with source column
#' @noRd
load_ohdsi_relationships <- function(vocab_data, concept_mappings, preserve_recommended = FALSE) {
  if (is.null(vocab_data)) {
    stop("OHDSI vocabularies not loaded. Please configure the ATHENA folder in Settings.")
  }

  # Define allowed vocabularies
  ALLOWED_VOCABS <- c("RxNorm", "RxNorm Extension", "LOINC", "SNOMED", "ICD10")

  # Step 1: If preserve_recommended is TRUE, save the recommended status
  if (preserve_recommended) {
    recommended_omop_ids <- concept_mappings %>%
      dplyr::filter(source == "ohdsi_relationships", recommended == TRUE) %>%
      dplyr::pull(omop_concept_id)
  }

  # Step 2: Remove all existing ohdsi_relationships mappings
  concept_mappings <- concept_mappings %>%
    dplyr::filter(source != "ohdsi_relationships")

  # Step 3: Get all recommended mappings (source = "manual")
  recommended_mappings <- concept_mappings %>%
    dplyr::filter(source == "manual", recommended == TRUE)

  if (nrow(recommended_mappings) == 0) {
    return(concept_mappings)
  }

  # Step 4: For each recommended mapping, enrich with related concepts
  new_mappings_list <- list()

  for (i in seq_len(nrow(recommended_mappings))) {
    mapping <- recommended_mappings[i, ]
    general_concept_id <- mapping$general_concept_id
    source_concept_id <- mapping$omop_concept_id
    unit_concept_id <- mapping$omop_unit_concept_id

    # Get vocabulary info
    concept_info <- vocab_data$concept %>%
      dplyr::filter(concept_id == source_concept_id) %>%
      dplyr::select(vocabulary_id) %>%
      dplyr::collect()

    if (nrow(concept_info) == 0) next

    source_vocab <- concept_info$vocabulary_id[1]

    if (!(source_vocab %in% ALLOWED_VOCABS)) next

    # Get relationships and descendants
    step1_rels <- vocab_data$concept_relationship %>%
      dplyr::filter(
        concept_id_1 == source_concept_id,
        relationship_id %in% c("Maps to", "Mapped from")
      ) %>%
      dplyr::select(concept_id_2) %>%
      dplyr::collect()

    step1_descs <- vocab_data$concept_ancestor %>%
      dplyr::filter(ancestor_concept_id == source_concept_id) %>%
      dplyr::select(descendant_concept_id) %>%
      dplyr::collect()

    step1_concepts <- unique(c(step1_rels$concept_id_2, step1_descs$descendant_concept_id))

    # Filter to same vocabulary and valid concepts
    if (length(step1_concepts) > 0) {
      step1_filtered <- vocab_data$concept %>%
        dplyr::filter(
          concept_id %in% step1_concepts,
          vocabulary_id == source_vocab,
          is.na(invalid_reason)
        ) %>%
        dplyr::filter(domain_id != "Drug" | concept_class_id == "Clinical Drug") %>%
        dplyr::select(concept_id) %>%
        dplyr::collect() %>%
        dplyr::pull(concept_id)
    } else {
      step1_filtered <- integer(0)
    }

    new_concept_ids <- step1_filtered

    # Create new mappings
    if (length(new_concept_ids) > 0) {
      # Check if we should preserve recommended status
      if (preserve_recommended) {
        is_recommended <- new_concept_ids %in% recommended_omop_ids
      } else {
        is_recommended <- rep(FALSE, length(new_concept_ids))
      }

      new_rows <- data.frame(
        general_concept_id = general_concept_id,
        omop_concept_id = new_concept_ids,
        omop_unit_concept_id = unit_concept_id,
        recommended = is_recommended,
        source = "ohdsi_relationships",
        stringsAsFactors = FALSE
      )

      new_mappings_list[[length(new_mappings_list) + 1]] <- new_rows
    }
  }

  # Step 5: Combine all new mappings
  if (length(new_mappings_list) > 0) {
    new_mappings <- dplyr::bind_rows(new_mappings_list)

    # Filter out duplicates (mappings that already exist)
    existing_keys <- concept_mappings %>%
      dplyr::mutate(key = paste(general_concept_id, omop_concept_id, sep = "_")) %>%
      dplyr::pull(key)

    new_mappings <- new_mappings %>%
      dplyr::mutate(key = paste(general_concept_id, omop_concept_id, sep = "_")) %>%
      dplyr::filter(!key %in% existing_keys) %>%
      dplyr::select(-key)

    if (nrow(new_mappings) > 0) {
      concept_mappings <- dplyr::bind_rows(concept_mappings, new_mappings)
    }
  }

  return(concept_mappings)
}
