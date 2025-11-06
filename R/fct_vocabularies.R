#' OHDSI Vocabularies Functions
#'
#' @description Functions to load and query OHDSI vocabulary data from CSV
#' or DuckDB
#'
#' @noRd
#'
#' @importFrom readr read_tsv cols col_integer col_character
#' @importFrom dplyr filter select left_join bind_rows distinct arrange mutate

#' Get all related concepts (combined)
#'
#' @description Retrieve all related concepts by combining relationship-based
#' and hierarchy-based (ancestor/descendant) concepts. Marks concepts as
#' recommended if they exist in the provided existing mappings.
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data (concept, concept_relationship, concept_ancestor tables)
#' @param existing_mappings Data frame with existing mappings containing omop_concept_id column
#'
#' @return Data frame with combined related and descendant concepts, with recommended column
#' @noRd
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

#' Build hierarchy graph data for visNetwork visualization
#'
#' @description
#' Get ancestors, descendants, and relationships for a concept to build
#' an interactive hierarchy graph
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data
#' @param max_levels_up Maximum ancestor levels to include (default: 5)
#' @param max_levels_down Maximum descendant levels to include (default: 5)
#'
#' @return List with nodes and edges data frames for visNetwork
#' @noRd
get_concept_hierarchy_graph <- function(concept_id, vocabularies,
                                        max_levels_up = 5,
                                        max_levels_down = 5) {
  if (is.null(vocabularies)) {
    return(list(nodes = data.frame(), edges = data.frame()))
  }
  
  tryCatch({
    # Get selected concept details
    selected_concept <- vocabularies$concept %>%
      dplyr::filter(concept_id == !!concept_id) %>%
      dplyr::collect()
    
    if (nrow(selected_concept) == 0) {
      return(list(nodes = data.frame(), edges = data.frame()))
    }
    
    # Get ancestors and descendants from concept_ancestor
    ancestors_data <- vocabularies$concept_ancestor %>%
      dplyr::filter(descendant_concept_id == !!concept_id) %>%
      dplyr::collect()
    
    descendants_data <- vocabularies$concept_ancestor %>%
      dplyr::filter(ancestor_concept_id == !!concept_id) %>%
      dplyr::collect()
    
    # Get unique concept IDs
    ancestor_ids <- setdiff(unique(ancestors_data$ancestor_concept_id), concept_id)
    descendant_ids <- setdiff(unique(descendants_data$descendant_concept_id), concept_id)
    
    # Calculate hierarchy levels
    # Helper function to safely compute min
    safe_min <- function(x) {
      x_clean <- x[!is.na(x)]
      if (length(x_clean) == 0) return(NA_real_)
      min(x_clean)
    }
    
    ancestors_with_level <- ancestors_data %>%
      dplyr::filter(ancestor_concept_id != !!concept_id) %>%
      dplyr::group_by(ancestor_concept_id) %>%
      dplyr::summarise(
        min_separation = safe_min(min_levels_of_separation),
        .groups = "drop"
      ) %>%
      dplyr::filter(!is.na(min_separation)) %>%
      dplyr::mutate(hierarchy_level = -min_separation)
    
    descendants_with_level <- descendants_data %>%
      dplyr::filter(descendant_concept_id != !!concept_id) %>%
      dplyr::group_by(descendant_concept_id) %>%
      dplyr::summarise(
        min_separation = safe_min(min_levels_of_separation),
        .groups = "drop"
      ) %>%
      dplyr::filter(!is.na(min_separation)) %>%
      dplyr::mutate(hierarchy_level = min_separation)
    
    # Combine levels
    concept_levels <- dplyr::bind_rows(
      data.frame(concept_id = concept_id, hierarchy_level = 0),
      data.frame(
        concept_id = ancestors_with_level$ancestor_concept_id,
        hierarchy_level = ancestors_with_level$hierarchy_level
      ),
      data.frame(
        concept_id = descendants_with_level$descendant_concept_id,
        hierarchy_level = descendants_with_level$hierarchy_level
      )
    )
    
    # Get all concept details
    all_concept_ids <- c(concept_id, ancestor_ids, descendant_ids)
    all_concepts <- vocabularies$concept %>%
      dplyr::filter(concept_id %in% all_concept_ids) %>%
      dplyr::collect()
    
    # Join with levels and add relationship type
    all_concepts <- all_concepts %>%
      dplyr::left_join(concept_levels, by = "concept_id") %>%
      dplyr::mutate(
        relationship_type = dplyr::case_when(
          concept_id == !!concept_id ~ "selected",
          concept_id %in% ancestor_ids ~ "ancestor",
          concept_id %in% descendant_ids ~ "descendant",
          TRUE ~ "other"
        )
      )
    
    # Limit to specified levels
    all_concepts_limited <- all_concepts %>%
      dplyr::filter(
        hierarchy_level >= -max_levels_up,
        hierarchy_level <= max_levels_down
      )
    
    limited_concept_ids <- all_concepts_limited$concept_id
    
    # Get hierarchical relationships metadata (where defines_ancestry = 1)
    hierarchical_rel_info <- vocabularies$relationship %>%
      dplyr::filter(defines_ancestry == 1) %>%
      dplyr::select(relationship_id, reverse_relationship_id) %>%
      dplyr::collect()
    
    hierarchical_rels <- hierarchical_rel_info$relationship_id
    
    # Identify child-to-parent relationships (like "Is a")
    # These are relationships where the reverse is the parent-to-child form
    child_to_parent_rels <- hierarchical_rel_info %>%
      dplyr::filter(relationship_id < reverse_relationship_id) %>%
      dplyr::pull(relationship_id)
    
    # Get relationships between limited concepts using hierarchical relationships
    relationships <- vocabularies$concept_relationship %>%
      dplyr::filter(
        concept_id_1 %in% limited_concept_ids,
        concept_id_2 %in% limited_concept_ids,
        relationship_id %in% hierarchical_rels
      ) %>%
      dplyr::collect()
    
    # Build nodes data frame
    nodes <- all_concepts_limited %>%
      dplyr::mutate(
        id = concept_id,
        label = dplyr::if_else(
          nchar(concept_name) > 50,
          paste0(substr(concept_name, 1, 47), "..."),
          concept_name
        ),
        title = paste0(
          "<div style='font-family: Arial; padding: 12px; max-width: 600px; min-width: 250px; white-space: normal;'>",
          "<b style='font-size: 15px; color: #0f60af; word-wrap: break-word; overflow-wrap: break-word; display: block; line-height: 1.4; white-space: normal;'>",
          concept_name,
          "</b><br><br>",
          "<table style='width: 100%; font-size: 13px;'>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>OMOP ID:</td><td style='word-break: break-word;'><b>", concept_id, "</b></td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Vocabulary:</td><td style='word-break: break-word;'>", vocabulary_id, "</td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Code:</td><td style='word-break: break-word;'>", concept_code, "</td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Class:</td><td style='word-break: break-word;'>", concept_class_id, "</td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Level:</td><td style='word-break: break-word;'>", hierarchy_level, "</td></tr>",
          "</table>",
          "</div>"
        ),
        level = hierarchy_level,
        color = dplyr::case_when(
          relationship_type == "selected" ~ "#0f60af",
          relationship_type == "ancestor" ~ "#6c757d",
          relationship_type == "descendant" ~ "#28a745",
          TRUE ~ "#ffc107"
        ),
        shape = "box",
        borderWidth = dplyr::if_else(relationship_type == "selected", 4, 2),
        font.size = dplyr::if_else(relationship_type == "selected", 16, 13),
        font.color = "white",
        shadow = dplyr::if_else(relationship_type == "selected", TRUE, FALSE),
        mass = dplyr::if_else(relationship_type == "selected", 5, 1)
      ) %>%
      dplyr::select(id, label, title, level, color, shape, borderWidth,
                    font.size, font.color, shadow, mass)
    
    # Build edges data frame (parent -> child direction)
    # For child-to-parent relationships: swap direction (parent=concept_id_2, child=concept_id_1)
    # For parent-to-child relationships: keep direction (parent=concept_id_1, child=concept_id_2)
    edges <- relationships %>%
      dplyr::mutate(
        from = dplyr::if_else(
          relationship_id %in% child_to_parent_rels,
          concept_id_2,
          concept_id_1
        ),
        to = dplyr::if_else(
          relationship_id %in% child_to_parent_rels,
          concept_id_1,
          concept_id_2
        ),
        arrows = "to",
        color = "#999",
        width = 2,
        smooth = TRUE
      ) %>%
      dplyr::select(from, to, arrows, color, width, smooth) %>%
      dplyr::distinct()
    
    return(list(
      nodes = nodes,
      edges = edges,
      stats = list(
        total_ancestors = length(ancestor_ids),
        total_descendants = length(descendant_ids),
        displayed_ancestors = sum(nodes$color == "#6c757d"),
        displayed_descendants = sum(nodes$color == "#28a745")
      )
    ))
    
  }, error = function(e) {
    return(list(nodes = data.frame(), edges = data.frame()))
  })
}

#' Get concept synonyms from concept_synonym table
#'
#' @description Retrieve all synonyms for a given concept from the
#' concept_synonym table, including language information.
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data
#'   (must include concept_synonym and concept tables)
#'
#' @return Data frame with columns: synonym, language, language_concept_id
#' @noRd
get_concept_synonyms <- function(concept_id, vocabularies) {
  if (is.null(vocabularies) || is.null(vocabularies$concept_synonym)) {
    return(data.frame())
  }
  
  tryCatch({
    # Get synonyms for this concept (filter BEFORE collecting)
    synonyms <- vocabularies$concept_synonym %>%
      dplyr::filter(concept_id == !!concept_id) %>%
      dplyr::collect()
    
    if (nrow(synonyms) == 0) {
      return(data.frame())
    }
    
    # Get language names for language_concept_id
    language_ids <- unique(synonyms$language_concept_id)
    language_info <- vocabularies$concept %>%
      dplyr::filter(concept_id %in% language_ids) %>%
      dplyr::select(concept_id, concept_name) %>%
      dplyr::collect()
    
    # Join synonym names with language names
    result <- synonyms %>%
      dplyr::left_join(
        language_info,
        by = c("language_concept_id" = "concept_id")
      ) %>%
      dplyr::select(
        synonym = concept_synonym_name,
        language = concept_name,
        language_concept_id
      ) %>%
      dplyr::arrange(synonym)
    
    return(result)
    
  }, error = function(e) {
    return(data.frame())
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

#' Get all hierarchy concepts (ancestors and descendants)
#'
#' @description Retrieve all concepts in the hierarchy (both ancestors and
#' descendants) for a given concept using concept_ancestor table and
#' hierarchical relationships.
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data (concept,
#'   concept_ancestor, concept_relationship, relationship tables)
#'
#' @return Data frame with hierarchy concepts including columns:
#'   omop_concept_id, concept_name, vocabulary_id, concept_code,
#'   relationship_id (Ancestor/Descendant)
#' @noRd
get_descendant_concepts <- function(concept_id, vocabularies) {
  if (is.null(vocabularies)) {
    return(data.frame())
  }
  
  tryCatch({
    # Get hierarchical relationship IDs (where defines_ancestry = 1)
    hierarchical_rels <- vocabularies$relationship %>%
      dplyr::filter(defines_ancestry == 1) %>%
      dplyr::select(relationship_id, reverse_relationship_id) %>%
      dplyr::collect()
    
    hierarchical_rel_ids <- hierarchical_rels$relationship_id
    
    # Identify child-to-parent relationships (like "Is a")
    child_to_parent_rels <- hierarchical_rels %>%
      dplyr::filter(relationship_id < reverse_relationship_id) %>%
      dplyr::pull(relationship_id)
    
    # Get ancestors
    ancestors <- vocabularies$concept_ancestor %>%
      dplyr::filter(descendant_concept_id == concept_id) %>%
      dplyr::collect()
    
    # Get descendants
    descendants <- vocabularies$concept_ancestor %>%
      dplyr::filter(ancestor_concept_id == concept_id) %>%
      dplyr::collect()
    
    # Combine all related concept IDs
    ancestor_ids <- if (nrow(ancestors) > 0) ancestors$ancestor_concept_id else c()
    descendant_ids <- if (nrow(descendants) > 0) descendants$descendant_concept_id else c()
    all_related_ids <- unique(c(ancestor_ids, descendant_ids))
    
    if (length(all_related_ids) == 0) {
      return(data.frame())
    }
    
    # Get concept details for all related concepts
    all_concepts <- vocabularies$concept %>%
      dplyr::filter(
        concept_id %in% all_related_ids,
        standard_concept == 'S',
        is.na(invalid_reason)
      ) %>%
      dplyr::select(
        omop_concept_id = concept_id,
        concept_name,
        vocabulary_id,
        concept_code
      ) %>%
      dplyr::collect()
    
    if (nrow(all_concepts) == 0) {
      return(data.frame())
    }
    
    # Get direct relationships from concept_relationship
    # For ancestors: current concept is concept_id_1, ancestor is concept_id_2
    ancestor_relationships <- vocabularies$concept_relationship %>%
      dplyr::filter(
        concept_id_1 == concept_id,
        concept_id_2 %in% ancestor_ids,
        relationship_id %in% hierarchical_rel_ids
      ) %>%
      dplyr::select(concept_id_2, relationship_id) %>%
      dplyr::collect() %>%
      dplyr::mutate(direction = "ancestor")
    
    # For descendants: current concept is concept_id_1, descendant is concept_id_2
    descendant_relationships <- vocabularies$concept_relationship %>%
      dplyr::filter(
        concept_id_1 == concept_id,
        concept_id_2 %in% descendant_ids,
        relationship_id %in% hierarchical_rel_ids
      ) %>%
      dplyr::select(concept_id_2, relationship_id) %>%
      dplyr::collect() %>%
      dplyr::mutate(direction = "descendant")
    
    # Also check reverse direction for ancestors (current concept is concept_id_2)
    ancestor_relationships_reverse <- vocabularies$concept_relationship %>%
      dplyr::filter(
        concept_id_2 == concept_id,
        concept_id_1 %in% ancestor_ids,
        relationship_id %in% hierarchical_rel_ids
      ) %>%
      dplyr::select(concept_id_1, relationship_id) %>%
      dplyr::collect() %>%
      dplyr::rename(concept_id_2 = concept_id_1) %>%
      dplyr::mutate(direction = "ancestor")
    
    # Combine all relationships
    all_relationships <- dplyr::bind_rows(
      ancestor_relationships,
      ancestor_relationships_reverse,
      descendant_relationships
    )
    
    # Join to add relationship_id and direction
    if (nrow(all_relationships) > 0) {
      all_concepts <- all_concepts %>%
        dplyr::left_join(
          all_relationships,
          by = c("omop_concept_id" = "concept_id_2")
        ) %>%
        dplyr::mutate(
          relationship_id = dplyr::case_when(
            !is.na(direction) & direction == "ancestor" ~ "Ancestor",
            !is.na(direction) & direction == "descendant" ~ "Descendant",
            omop_concept_id %in% ancestor_ids ~ "Ancestor",
            omop_concept_id %in% descendant_ids ~ "Descendant",
            TRUE ~ "Related"
          )
        ) %>%
        dplyr::select(-direction)
    } else {
      all_concepts <- all_concepts %>%
        dplyr::mutate(
          relationship_id = dplyr::if_else(
            omop_concept_id %in% ancestor_ids,
            "Ancestor",
            "Descendant"
          )
        )
    }
    
    # Sort: Ancestors first, then Descendants, then alphabetically by concept_name
    all_concepts <- all_concepts %>%
      dplyr::arrange(
        dplyr::desc(relationship_id == "Ancestor"),
        concept_name
      )
    
    return(all_concepts)
    
  }, error = function(e) {
    return(data.frame())
  })
}

#' Get related concepts (maps to / mapped from) without filtering
#'
#' @description Retrieve all related concepts through concept_relationship
#' table without applying standard_concept or invalid_reason filters.
#' Includes all relationship types.
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data (concept,
#'   concept_relationship tables)
#'
#' @return Data frame with related concepts including columns:
#'   omop_concept_id, concept_name, vocabulary_id, concept_code,
#'   relationship_id. Sorted by relationship_id frequency then concept_name.
#' @noRd
get_related_concepts <- function(concept_id, vocabularies) {
  if (is.null(vocabularies)) {
    return(data.frame())
  }
  
  tryCatch({
    # Get all relationships for this concept (filter only on concept_id_1)
    relationships <- vocabularies$concept_relationship %>%
      dplyr::filter(concept_id_1 == concept_id) %>%
      dplyr::collect()
    
    if (nrow(relationships) == 0) {
      return(data.frame())
    }
    
    # Get related concept IDs (only concept_id_2 since we filtered on concept_id_1)
    related_ids <- unique(relationships$concept_id_2)
    
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
      related_concept_id <- rel$concept_id_2
      
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
    
    # Sort by relationship_id frequency (descending), then by concept_name
    # First, count frequency of each relationship_id
    rel_counts <- related_data %>%
      dplyr::count(relationship_id, sort = TRUE)
    
    # Create a factor with levels ordered by frequency
    related_data <- related_data %>%
      dplyr::mutate(
        relationship_id = factor(relationship_id, levels = rel_counts$relationship_id)
      ) %>%
      dplyr::arrange(relationship_id, concept_name) %>%
      dplyr::mutate(relationship_id = as.character(relationship_id))
    
    return(related_data)

  }, error = function(e) {
    return(data.frame())
  })
}

#' Get related concepts filtered for standard and valid concepts
#'
#' @description Retrieve related concepts through concept_relationship table
#' with filters applied: only standard concepts (standard_concept = 'S') and
#' valid concepts (invalid_reason IS NULL).
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data (concept,
#'   concept_relationship tables)
#'
#' @return Data frame with related concepts including columns:
#'   omop_concept_id, concept_name, vocabulary_id, concept_code,
#'   relationship_id. Only includes standard and valid concepts.
#' @noRd
get_related_concepts_filtered <- function(concept_id, vocabularies) {
  if (is.null(vocabularies)) {
    return(data.frame())
  }

  tryCatch({
    # Get all relationships for this concept (filter only on concept_id_1)
    relationships <- vocabularies$concept_relationship %>%
      dplyr::filter(concept_id_1 == concept_id) %>%
      dplyr::collect()

    if (nrow(relationships) == 0) {
      return(data.frame())
    }

    # Get related concept IDs (only concept_id_2 since we filtered on concept_id_1)
    related_ids <- unique(relationships$concept_id_2)

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
      related_concept_id <- rel$concept_id_2

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
    return(data.frame())
  })
}

#' Load OHDSI relationships mappings
#'
#' @description Load additional concept mappings from OHDSI vocabulary relationships
#' for all recommended concepts. This enriches the dictionary with related concepts.
#'
#' For general concepts:
#' - Uses "Maps to", "Mapped from" relationships and concept_ancestor hierarchy
#' - Filters to same vocabulary and valid concepts
#'
#' For Drug category concepts (RxNorm):
#' - Finds Ingredient by exact name match (case-insensitive)
#' - Follows "RxNorm has ing" to find Clinical Drug Comp
#' - Follows "Constitutes" to find Clinical Drug
#' - Only includes final Clinical Drug concepts
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

  # Step 6: RxNorm Drug enrichment for general concepts with category = "Drug"
  # Load general concepts to identify Drug category concepts
  general_concepts_path <- get_package_dir("extdata", "csv", "general_concepts.csv")
  general_concepts <- readr::read_csv(general_concepts_path, show_col_types = FALSE)

  # Filter to Drug category
  drug_concepts <- general_concepts %>%
    dplyr::filter(category == "Drug") %>%
    dplyr::select(general_concept_id, general_concept_name)

  if (nrow(drug_concepts) > 0) {
    drug_mappings_list <- list()

    for (i in seq_len(nrow(drug_concepts))) {
      drug <- drug_concepts[i, ]
      general_concept_id <- drug$general_concept_id
      general_concept_name <- drug$general_concept_name

      # Find Ingredient in RxNorm/RxNorm Extension (case-insensitive)
      ingredients <- vocab_data$concept %>%
        dplyr::filter(
          vocabulary_id %in% c("RxNorm", "RxNorm Extension"),
          concept_class_id == "Ingredient",
          is.na(invalid_reason)
        ) %>%
        dplyr::collect() %>%
        dplyr::mutate(concept_name_lower = tolower(concept_name)) %>%
        dplyr::filter(concept_name_lower == tolower(general_concept_name)) %>%
        dplyr::select(-concept_name_lower)

      if (nrow(ingredients) == 0) next

      ingredient_ids <- ingredients$concept_id

      # Find Clinical Drug Comp via "RxNorm has ing" relationship
      # Relationship: Clinical Drug Comp (concept_id_1) -> "has ing" -> Ingredient (concept_id_2)
      clinical_drug_comp_ids <- vocab_data$concept_relationship %>%
        dplyr::filter(
          concept_id_2 %in% ingredient_ids,
          relationship_id == "RxNorm has ing"
        ) %>%
        dplyr::select(concept_id_1) %>%
        dplyr::collect() %>%
        dplyr::pull(concept_id_1)

      if (length(clinical_drug_comp_ids) == 0) next

      # Filter to only Clinical Drug Comp
      clinical_drug_comps <- vocab_data$concept %>%
        dplyr::filter(
          concept_id %in% clinical_drug_comp_ids,
          concept_class_id == "Clinical Drug Comp",
          is.na(invalid_reason)
        ) %>%
        dplyr::collect()

      if (nrow(clinical_drug_comps) == 0) next

      clinical_drug_comp_ids <- clinical_drug_comps$concept_id

      # Find Clinical Drugs via "Constitutes" relationship
      # Clinical Drug Comp (concept_id_1) -> "Constitutes" -> Clinical Drug (concept_id_2)
      final_clinical_drug_ids <- vocab_data$concept_relationship %>%
        dplyr::filter(
          concept_id_1 %in% clinical_drug_comp_ids,
          relationship_id == "Constitutes"
        ) %>%
        dplyr::select(concept_id_2) %>%
        dplyr::collect() %>%
        dplyr::pull(concept_id_2)

      if (length(final_clinical_drug_ids) == 0) next

      # Filter to only Clinical Drug class
      clinical_drugs <- vocab_data$concept %>%
        dplyr::filter(
          concept_id %in% final_clinical_drug_ids,
          concept_class_id == "Clinical Drug",
          is.na(invalid_reason)
        ) %>%
        dplyr::collect()

      if (nrow(clinical_drugs) == 0) next

      # All Clinical Drugs are always marked as recommended
      is_recommended <- rep(TRUE, nrow(clinical_drugs))

      # Create new mappings
      new_drug_rows <- data.frame(
        general_concept_id = general_concept_id,
        omop_concept_id = clinical_drugs$concept_id,
        omop_unit_concept_id = NA_character_,
        recommended = is_recommended,
        source = "ohdsi_relationships",
        stringsAsFactors = FALSE
      )

      drug_mappings_list[[length(drug_mappings_list) + 1]] <- new_drug_rows
    }

    # Combine drug mappings
    if (length(drug_mappings_list) > 0) {
      drug_mappings <- dplyr::bind_rows(drug_mappings_list)

      # Get Clinical Drug concept IDs to replace
      clinical_drug_ids <- drug_mappings$omop_concept_id

      # Remove any existing Clinical Drug mappings that we're about to replace
      # This ensures Clinical Drugs are always recommended = TRUE
      concept_mappings <- concept_mappings %>%
        dplyr::filter(
          !(source == "ohdsi_relationships" &
            omop_concept_id %in% clinical_drug_ids)
        )

      # Add Clinical Drug mappings (all with recommended = TRUE)
      concept_mappings <- dplyr::bind_rows(concept_mappings, drug_mappings)
    }
  }

  return(concept_mappings)
}

#' Load OHDSI Vocabularies
#'
#' @description Load OHDSI vocabulary files from disk into memory. Supports
#' both DuckDB database (if enabled and available) and CSV file loading.
#' Automatically detects which method to use based on configuration.
#'
#' @param vocab_folder Path to OHDSI vocabularies folder containing CSV files
#'   or DuckDB database
#'
#' @return List with vocabulary data:
#'   - If DuckDB: lazy dplyr::tbl connections (concept, concept_relationship,
#'     concept_ancestor, concept_synonym, relationship, connection)
#'   - If CSV: data frames (concept, concept_relationship, concept_ancestor,
#'     concept_synonym)
#'   Returns NULL if folder doesn't exist or required files are missing
#' @noRd
load_ohdsi_vocabularies <- function(vocab_folder) {
  if (is.null(vocab_folder) || vocab_folder == "" || !dir.exists(vocab_folder)) {
    return(NULL)
  }
  
  tryCatch({
    # Check if DuckDB option is enabled and database exists
    use_duckdb <- get_use_duckdb()
    db_exists <- duckdb_exists(vocab_folder)

    if (use_duckdb && db_exists) {
      result <- load_vocabularies_from_duckdb()
      return(result)
    }
    
    # Fall back to CSV loading
    concept_path <- file.path(vocab_folder, "CONCEPT.csv")
    concept_relationship_path <- file.path(vocab_folder, "CONCEPT_RELATIONSHIP.csv")
    concept_ancestor_path <- file.path(vocab_folder, "CONCEPT_ANCESTOR.csv")
    concept_synonym_path <- file.path(vocab_folder, "CONCEPT_SYNONYM.csv")

    if (!file.exists(concept_path) || !file.exists(concept_relationship_path) || !file.exists(concept_ancestor_path)) {
      return(NULL)
    }
    
    # Load files sequentially from CSV
    concept <- readr::read_tsv(
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
    
    concept_relationship <- readr::read_tsv(
      concept_relationship_path,
      col_types = readr::cols(
        concept_id_1 = readr::col_integer(),
        concept_id_2 = readr::col_integer(),
        relationship_id = readr::col_character()
      ),
      show_col_types = FALSE
    )
    
    concept_ancestor <- readr::read_tsv(
      concept_ancestor_path,
      col_types = readr::cols(
        ancestor_concept_id = readr::col_integer(),
        descendant_concept_id = readr::col_integer()
      ),
      show_col_types = FALSE
    )
    
    # Load CONCEPT_SYNONYM if file exists
    concept_synonym <- if (file.exists(concept_synonym_path)) {
      readr::read_tsv(
        concept_synonym_path,
        col_types = readr::cols(
          concept_id = readr::col_integer(),
          concept_synonym_name = readr::col_character(),
          language_concept_id = readr::col_integer()
        ),
        show_col_types = FALSE
      )
    } else {
      NULL
    }

    return(list(
      concept = concept,
      concept_relationship = concept_relationship,
      concept_ancestor = concept_ancestor,
      concept_synonym = concept_synonym
    ))

  }, error = function(e) {
    return(NULL)
  })
}

#' Get Clinical Drug Concepts from Ingredient
#'
#' @description Query OHDSI vocabularies to retrieve Clinical Drug concepts
#' that are descendants of a given RxNorm Ingredient concept
#'
#' @param ingredient_concept_id Integer. The RxNorm Ingredient concept_id
#' @param vocabularies Reactive containing preloaded OHDSI vocabulary tables
#'
#' @return Data frame with Clinical Drug concepts
#' @noRd
#'
#' @importFrom dplyr filter select arrange distinct inner_join
get_clinical_drugs_from_ingredient <- function(
    ingredient_concept_id,
    vocabularies
) {
  # Validate input
  if (is.null(ingredient_concept_id) || is.na(ingredient_concept_id)) {
    return(data.frame(
      concept_id = integer(),
      concept_name = character(),
      vocabulary_id = character(),
      concept_code = character(),
      concept_class_id = character()
    ))
  }

  # Get vocabulary tables
  concept <- vocabularies$concept
  concept_ancestor <- vocabularies$concept_ancestor

  # Get Clinical Drug descendants using concept_ancestor
  clinical_drugs <- concept_ancestor %>%
    filter(ancestor_concept_id == ingredient_concept_id) %>%
    inner_join(
      concept %>%
        filter(
          concept_class_id == "Clinical Drug",
          vocabulary_id %in% c("RxNorm", "RxNorm Extension"),
          domain_id == "Drug",
          is.na(invalid_reason) | invalid_reason == ""
        ),
      by = c("descendant_concept_id" = "concept_id")
    ) %>%
    select(
      concept_id = descendant_concept_id,
      concept_name,
      vocabulary_id,
      concept_code,
      concept_class_id,
      standard_concept
    ) %>%
    distinct() %>%
    arrange(concept_name)

  return(as.data.frame(clinical_drugs))
}