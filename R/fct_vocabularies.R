#' OHDSI Vocabularies Functions
#'
#' @description Functions to load and query OHDSI vocabulary data from CSV
#' or DuckDB
#'
#' @noRd
#'
#' @importFrom readr read_tsv cols col_integer col_character
#' @importFrom dplyr filter select left_join bind_rows distinct arrange mutate

#' Decode escaped UTF-8 hex bytes in a string
#'
#' @description Converts strings with escaped hex bytes (e.g., <e5><bf><83>)
#' back to proper UTF-8 characters. OHDSI Athena vocabularies sometimes
#' store non-ASCII characters in this escaped format.
#'
#' @param x Character string potentially containing escaped hex bytes
#'
#' @return Character string with decoded UTF-8 characters
#' @noRd
decode_escaped_utf8 <- function(x) {
  if (is.na(x) || !grepl("<[0-9a-f]{2}>", x, ignore.case = TRUE)) {
    return(x)
  }

  tryCatch({
    # Find all sequences of consecutive <xx> hex bytes
    result <- x
    # Keep replacing until no more matches
    while (grepl("<[0-9a-f]{2}>", result, ignore.case = TRUE)) {
      # Find the first sequence of consecutive hex bytes
      match <- regexpr("(<[0-9a-f]{2}>)+", result, ignore.case = TRUE)
      if (match == -1) break

      matched_str <- regmatches(result, match)
      # Extract hex values
      hex_values <- gsub("[<>]", "", matched_str)
      hex_pairs <- strsplit(hex_values, "")[[1]]
      hex_pairs <- paste0(
        hex_pairs[seq(1, length(hex_pairs), 2)],
        hex_pairs[seq(2, length(hex_pairs), 2)]
      )
      # Convert to raw bytes and then to UTF-8 character
      raw_bytes <- as.raw(strtoi(hex_pairs, 16L))
      decoded <- rawToChar(raw_bytes)
      Encoding(decoded) <- "UTF-8"
      # Replace in result
      result <- sub("(<[0-9a-f]{2}>)+", decoded, result, ignore.case = TRUE)
    }
    result
  }, error = function(e) x)
}

#' Get all related concepts (combined)
#'
#' @description Retrieve all related concepts by combining relationship-based
#' and hierarchy-based (ancestor/descendant) concepts. Marks concepts as
#' existing if they are already in the provided existing mappings.
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data (concept, concept_relationship, concept_ancestor tables)
#' @param existing_mappings Data frame with existing mappings containing omop_concept_id column
#'
#' @return Data frame with combined related and descendant concepts, with is_existing column
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

  # Mark as existing if in existing mappings
  all_concepts <- all_concepts %>%
    dplyr::mutate(
      is_existing = omop_concept_id %in% existing_mappings$omop_concept_id
    ) %>%
    dplyr::arrange(dplyr::desc(is_existing), concept_name)

  return(all_concepts)
}

#' Count concepts in hierarchy graph (lightweight check before rendering)
#'
#' @description
#' Count the number of ancestors and descendants for a concept within specified
#' levels. Use this before calling get_concept_hierarchy_graph to warn users
#' about large graphs that may cause performance issues.
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data
#' @param max_levels_up Maximum ancestor levels to count (default: 5)
#' @param max_levels_down Maximum descendant levels to count (default: 5)
#'
#' @return List with total_count, ancestors_count, descendants_count
#' @noRd
count_hierarchy_concepts <- function(concept_id, vocabularies,
                                     max_levels_up = 5,
                                     max_levels_down = 5) {
  if (is.null(vocabularies)) {
    return(list(total_count = 0, ancestors_count = 0, descendants_count = 0))
  }

  tryCatch({
    # Get ancestors within max_levels_up
    ancestors_data <- vocabularies$concept_ancestor %>%
      dplyr::filter(
        descendant_concept_id == !!concept_id,
        min_levels_of_separation <= max_levels_up,
        min_levels_of_separation > 0
      ) %>%
      dplyr::select(ancestor_concept_id) %>%
      dplyr::distinct() %>%
      dplyr::collect()

    # Get descendants within max_levels_down
    descendants_data <- vocabularies$concept_ancestor %>%
      dplyr::filter(
        ancestor_concept_id == !!concept_id,
        min_levels_of_separation <= max_levels_down,
        min_levels_of_separation > 0
      ) %>%
      dplyr::select(descendant_concept_id) %>%
      dplyr::distinct() %>%
      dplyr::collect()

    ancestors_count <- nrow(ancestors_data)
    descendants_count <- nrow(descendants_data)

    return(list(
      total_count = 1 + ancestors_count + descendants_count,
      ancestors_count = ancestors_count,
      descendants_count = descendants_count
    ))

  }, error = function(e) {
    return(list(total_count = 0, ancestors_count = 0, descendants_count = 0))
  })
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
                                        max_levels_down = 5,
                                        previous_concept_id = NULL) {
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

    # Mark previous concept if provided (after initial assignment to avoid vectorization issues)
    if (!is.null(previous_concept_id)) {
      all_concepts <- all_concepts %>%
        dplyr::mutate(
          relationship_type = dplyr::if_else(
            concept_id == previous_concept_id & relationship_type != "selected",
            "previous",
            relationship_type
          )
        )
    }
    
    # Limit to specified levels
    all_concepts_limited <- all_concepts %>%
      dplyr::filter(
        hierarchy_level >= -max_levels_up,
        hierarchy_level <= max_levels_down
      )
    
    limited_concept_ids <- all_concepts_limited$concept_id
    
    # Build edges from concept_ancestor with min_levels_of_separation = 1
    # This gives us direct parent-child relationships, which is more reliable
    # than concept_relationship (some LOINC hierarchies are missing from concept_relationship)

    # Get direct parent-child relationships from concept_ancestor
    # where ancestor is parent and descendant is child (1 level apart)
    direct_relationships <- vocabularies$concept_ancestor %>%
      dplyr::filter(
        min_levels_of_separation == 1,
        ancestor_concept_id %in% limited_concept_ids,
        descendant_concept_id %in% limited_concept_ids
      ) %>%
      dplyr::select(ancestor_concept_id, descendant_concept_id) %>%
      dplyr::distinct() %>%
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
        # Format standard_concept for display
        standard_display = dplyr::case_when(
          standard_concept == "S" ~ "<span style='color: #28a745; font-weight: bold;'>Standard</span>",
          standard_concept == "C" ~ "<span style='color: #0f60af; font-weight: bold;'>Classification</span>",
          TRUE ~ "<span style='color: #dc3545; font-weight: bold;'>Non-standard</span>"
        ),
        title = paste0(
          "<div style='font-family: Arial; padding: 12px; max-width: 600px; min-width: 250px; white-space: normal;'>",
          "<b style='font-size: 15px; color: #0f60af; word-wrap: break-word; overflow-wrap: break-word; display: block; line-height: 1.4; white-space: normal;'>",
          concept_name,
          "</b><br><br>",
          "<table style='width: 100%; font-size: 13px;'>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>OMOP ID:</td><td style='word-break: break-word;'><b>", concept_id, "</b></td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Domain:</td><td style='word-break: break-word;'>", domain_id, "</td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Vocabulary:</td><td style='word-break: break-word;'>", vocabulary_id, "</td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Code:</td><td style='word-break: break-word;'>", concept_code, "</td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Class:</td><td style='word-break: break-word;'>", concept_class_id, "</td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Standard:</td><td style='word-break: break-word;'>", standard_display, "</td></tr>",
          "<tr><td style='color: #666; padding-right: 15px; white-space: nowrap;'>Level:</td><td style='word-break: break-word;'>", hierarchy_level, "</td></tr>",
          "</table>",
          "<div style='margin-top: 10px; font-size: 11px; color: #999; text-align: center;'>Double-click to recenter graph on this concept</div>",
          "</div>"
        ),
        level = hierarchy_level,
        color = dplyr::case_when(
          relationship_type == "selected" ~ "#0f60af",
          relationship_type == "previous" ~ "#fd7e14",
          relationship_type == "ancestor" ~ "#6c757d",
          relationship_type == "descendant" ~ "#28a745",
          TRUE ~ "#ffc107"
        ),
        shape = "box",
        borderWidth = dplyr::case_when(
          relationship_type == "selected" ~ 4,
          relationship_type == "previous" ~ 3,
          TRUE ~ 2
        ),
        font.size = dplyr::case_when(
          relationship_type == "selected" ~ 16,
          relationship_type == "previous" ~ 14,
          TRUE ~ 13
        ),
        font.color = "white",
        shadow = dplyr::if_else(relationship_type %in% c("selected", "previous"), TRUE, FALSE),
        mass = dplyr::case_when(
          relationship_type == "selected" ~ 5,
          relationship_type == "previous" ~ 3,
          TRUE ~ 1
        )
      ) %>%
      dplyr::select(id, label, title, level, color, shape, borderWidth,
                    font.size, font.color, shadow, mass)
    
    # Build edges data frame (parent -> child direction)
    # ancestor_concept_id is the parent, descendant_concept_id is the child
    edges <- direct_relationships %>%
      dplyr::mutate(
        from = ancestor_concept_id,
        to = descendant_concept_id,
        arrows = "to",
        color = "#999",
        width = 2,
        smooth = TRUE
      ) %>%
      dplyr::select(from, to, arrows, color, width, smooth)
    
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

    # Decode escaped UTF-8 bytes (e.g., <e5><bf><83> -> actual UTF-8 character)
    # OHDSI Athena vocabularies may store non-ASCII chars in escaped hex format
    synonyms$concept_synonym_name <- sapply(
      synonyms$concept_synonym_name,
      decode_escaped_utf8,
      USE.NAMES = FALSE
    )
    
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
#' for all manual mappings. This enriches the dictionary with related concepts.
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
#'
#' @return Updated concept_mappings dataframe with source column
#' @noRd
load_ohdsi_relationships <- function(vocab_data, concept_mappings) {
  if (is.null(vocab_data)) {
    stop("OHDSI vocabularies not loaded. Please configure the ATHENA folder in Settings.")
  }

  # Define allowed vocabularies
  ALLOWED_VOCABS <- c("RxNorm", "RxNorm Extension", "LOINC", "SNOMED", "ICD10")

  # Step 1: Remove all existing ohdsi_relationships mappings
  concept_mappings <- concept_mappings %>%
    dplyr::filter(source != "ohdsi_relationships")

  # Step 2: Get all manual mappings as the base for enrichment
  manual_mappings <- concept_mappings %>%
    dplyr::filter(source == "manual")

  if (nrow(manual_mappings) == 0) {
    return(concept_mappings)
  }
  
  # Step 3: For each manual mapping, enrich with related concepts
  new_mappings_list <- list()

  for (i in seq_len(nrow(manual_mappings))) {
    mapping <- manual_mappings[i, ]
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
      new_rows <- data.frame(
        general_concept_id = general_concept_id,
        omop_concept_id = new_concept_ids,
        omop_unit_concept_id = unit_concept_id,
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
  # Use English file as reference (Drug category is the same in all languages)
  general_concepts_path <- get_csv_path("general_concepts_en.csv")
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

      # Create new mappings for Clinical Drugs
      new_drug_rows <- data.frame(
        general_concept_id = general_concept_id,
        omop_concept_id = clinical_drugs$concept_id,
        omop_unit_concept_id = NA_character_,
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
      concept_mappings <- concept_mappings %>%
        dplyr::filter(
          !(source == "ohdsi_relationships" &
            omop_concept_id %in% clinical_drug_ids)
        )

      # Add Clinical Drug mappings
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

#' Get Descendants Count for a Concept
#'
#' @description Count the number of descendant concepts for a given OMOP concept.
#' Uses the concept_ancestor table to find all descendants.
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data (concept_ancestor table)
#'
#' @return Integer count of descendant concepts (excluding the concept itself)
#' @noRd
get_concept_descendants_count <- function(concept_id, vocabularies) {
  if (is.null(vocabularies) || is.null(concept_id) || is.na(concept_id)) {
    return(0L)
  }

  tryCatch({
    descendants <- vocabularies$concept_ancestor %>%
      dplyr::filter(
        ancestor_concept_id == concept_id,
        descendant_concept_id != concept_id
      ) %>%
      dplyr::summarise(n = dplyr::n()) %>%
      dplyr::collect()

    return(as.integer(descendants$n[1]))
  }, error = function(e) {
    return(0L)
  })
}

#' Get Mapped Concepts Count for a Concept
#'
#' @description Count the number of concepts mapped to/from a given OMOP concept.
#' Uses the concept_relationship table with "Maps to" and "Mapped from" relationships.
#'
#' @param concept_id OMOP concept ID
#' @param vocabularies List containing vocabulary data (concept_relationship table)
#'
#' @return Integer count of mapped concepts
#' @noRd
get_concept_mapped_count <- function(concept_id, vocabularies) {
  if (is.null(vocabularies) || is.null(concept_id) || is.na(concept_id)) {
    return(0L)
  }

  tryCatch({
    mapped <- vocabularies$concept_relationship %>%
      dplyr::filter(
        concept_id_1 == concept_id,
        relationship_id %in% c("Maps to", "Mapped from")
      ) %>%
      dplyr::summarise(n = dplyr::n()) %>%
      dplyr::collect()

    return(as.integer(mapped$n[1]))
  }, error = function(e) {
    return(0L)
  })
}

#' Resolve Concept Set
#'
#' @description Resolve a concept set by including descendants and mapped concepts
#' based on the include_descendants and include_mapped flags, and excluding
#' concepts marked as is_excluded.
#'
#' @param mappings Data frame with concept mappings. Must contain columns:
#'   omop_concept_id, is_excluded, include_descendants, include_mapped
#' @param vocabularies List containing vocabulary data
#'
#' @return Data frame with resolved concepts (unique, sorted by concept_name)
#' @noRd
resolve_concept_set <- function(mappings, vocabularies) {
  if (is.null(mappings) || nrow(mappings) == 0) {
    return(data.frame())
  }

  # Ensure required columns exist with default values
  if (!"is_excluded" %in% names(mappings)) {
    mappings$is_excluded <- FALSE
  }
  if (!"include_descendants" %in% names(mappings)) {
    mappings$include_descendants <- FALSE
  }
  if (!"include_mapped" %in% names(mappings)) {
    mappings$include_mapped <- FALSE
  }

  # Convert to logical if needed (CSV may read as character)
  mappings$is_excluded <- as.logical(mappings$is_excluded)
  mappings$include_descendants <- as.logical(mappings$include_descendants)
  mappings$include_mapped <- as.logical(mappings$include_mapped)

  # Replace NA with FALSE
  mappings$is_excluded[is.na(mappings$is_excluded)] <- FALSE
  mappings$include_descendants[is.na(mappings$include_descendants)] <- FALSE
  mappings$include_mapped[is.na(mappings$include_mapped)] <- FALSE

  if (is.null(vocabularies)) {
    return(mappings %>% dplyr::filter(!.data$is_excluded))
  }

  # Filter out excluded concepts for resolution
  non_excluded <- mappings %>%
    dplyr::filter(!.data$is_excluded)

  if (nrow(non_excluded) == 0) {
    return(data.frame())
  }

  # Start with base concepts
  resolved_ids <- non_excluded$omop_concept_id

  tryCatch({
    # Add descendants where include_descendants is TRUE
    concepts_with_descendants <- non_excluded %>%
      dplyr::filter(.data$include_descendants == TRUE)

    if (nrow(concepts_with_descendants) > 0) {
      for (cid in concepts_with_descendants$omop_concept_id) {
        descendants <- vocabularies$concept_ancestor %>%
          dplyr::filter(
            ancestor_concept_id == cid,
            descendant_concept_id != cid
          ) %>%
          dplyr::select(descendant_concept_id) %>%
          dplyr::collect()

        if (nrow(descendants) > 0) {
          resolved_ids <- c(resolved_ids, descendants$descendant_concept_id)
        }
      }
    }

    # Add mapped concepts where include_mapped is TRUE
    concepts_with_mapped <- non_excluded %>%
      dplyr::filter(.data$include_mapped == TRUE)

    if (nrow(concepts_with_mapped) > 0) {
      for (cid in concepts_with_mapped$omop_concept_id) {
        mapped <- vocabularies$concept_relationship %>%
          dplyr::filter(
            concept_id_1 == cid,
            relationship_id %in% c("Maps to", "Mapped from")
          ) %>%
          dplyr::select(concept_id_2) %>%
          dplyr::collect()

        if (nrow(mapped) > 0) {
          resolved_ids <- c(resolved_ids, mapped$concept_id_2)
        }
      }
    }

    # Get unique concept IDs
    resolved_ids <- unique(resolved_ids)

    # Get concept details for all resolved IDs
    if (length(resolved_ids) > 0) {
      resolved_concepts <- vocabularies$concept %>%
        dplyr::filter(concept_id %in% resolved_ids) %>%
        dplyr::select(
          omop_concept_id = concept_id,
          concept_name,
          vocabulary_id,
          domain_id,
          concept_code,
          standard_concept
        ) %>%
        dplyr::collect() %>%
        dplyr::arrange(concept_name)

      return(resolved_concepts)
    }

    return(data.frame())

  }, error = function(e) {
    return(mappings %>% dplyr::filter(!is_excluded))
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

#' Get Concept Information from LOINC or SNOMED Source Files
#'
#' @description Retrieve concept descriptions from LOINC or SNOMED CT source
#' files. For LOINC, returns component, system, method, long name, and definition.
#' For SNOMED, returns Fully Specified Name (FSN), synonyms, and text definition.
#'
#' @param vocabulary Character. Either "LOINC" or "SNOMED"
#' @param code Character. The LOINC code (e.g., "8867-4") or SNOMED concept ID
#'   (e.g., "364075005")
#'
#' @return For LOINC: data frame with columns LOINC_NUM, COMPONENT, SYSTEM,
#'   METHOD_TYP, LONG_COMMON_NAME, DefinitionDescription. For SNOMED: list with
#'   ConceptID, FSN, Synonyms (vector), Definition. Returns NULL if not found.
#'
#' @details
#' Requires environment variables:
#' - LOINC_CSV_PATH: Path to Loinc.csv file
#' - SNOMED_RF2_PATH: Path to SNOMED RF2 Snapshot/Terminology directory
#'
#' @examples
#' \dontrun{
#' # Set environment variables first
#' Sys.setenv(LOINC_CSV_PATH = "/path/to/Loinc.csv")
#' Sys.setenv(SNOMED_RF2_PATH = "/path/to/SNOMED/Snapshot/Terminology")
#'
#' # Get LOINC concept info
#' get_concept_info("LOINC", "8867-4")
#'
#' # Get SNOMED concept info
#' get_concept_info("SNOMED", "364075005")
#' }
#'
#' @noRd
#' @importFrom readr read_csv read_tsv cols col_character col_integer
#' @importFrom dplyr filter pull
get_concept_info <- function(vocabulary = c("LOINC", "SNOMED"), code) {
  vocabulary <- match.arg(vocabulary)

  if (vocabulary == "LOINC") {
    loinc_path <- Sys.getenv("LOINC_CSV_PATH")

    if (loinc_path == "" || !file.exists(loinc_path)) {
      message("LOINC_CSV_PATH environment variable not set or file does not exist")
      message("Set it with: Sys.setenv(LOINC_CSV_PATH = '/path/to/Loinc.csv')")
      return(invisible(NULL))
    }

    # Load LOINC table
    loinc <- readr::read_csv(loinc_path, show_col_types = FALSE)

    # Get concept info
    result <- loinc %>%
      dplyr::filter(LOINC_NUM == code) %>%
      dplyr::select(LOINC_NUM, COMPONENT, SYSTEM, METHOD_TYP, LONG_COMMON_NAME, DefinitionDescription)

    if (nrow(result) == 0) {
      message("LOINC code '", code, "' not found")
      return(invisible(NULL))
    }

    cat("LOINC Code:", result$LOINC_NUM, "\n")
    cat("Component:", result$COMPONENT, "\n")
    cat("System:", result$SYSTEM, "\n")
    cat("Method:", result$METHOD_TYP, "\n")
    cat("Long Name:", result$LONG_COMMON_NAME, "\n")
    cat("Definition:", ifelse(is.na(result$DefinitionDescription), "(not available)", result$DefinitionDescription), "\n")

    return(invisible(result))

  } else if (vocabulary == "SNOMED") {
    snomed_path <- Sys.getenv("SNOMED_RF2_PATH")

    if (snomed_path == "" || !dir.exists(snomed_path)) {
      message("SNOMED_RF2_PATH environment variable not set or directory does not exist")
      message("Set it with: Sys.setenv(SNOMED_RF2_PATH = '/path/to/SNOMED/Snapshot/Terminology')")
      return(invisible(NULL))
    }

    # Construct file paths
    desc_file <- list.files(snomed_path, pattern = "^sct2_Description_Snapshot.*\\.txt$", full.names = TRUE)[1]
    def_file <- list.files(snomed_path, pattern = "^sct2_TextDefinition_Snapshot.*\\.txt$", full.names = TRUE)[1]

    if (is.na(desc_file) || is.na(def_file)) {
      message("SNOMED RF2 files not found in: ", snomed_path)
      return(invisible(NULL))
    }

    # Load SNOMED description file
    snomed_descriptions <- readr::read_tsv(
      desc_file,
      show_col_types = FALSE,
      col_types = readr::cols(
        id = readr::col_character(),
        effectiveTime = readr::col_character(),
        active = readr::col_integer(),
        moduleId = readr::col_character(),
        conceptId = readr::col_character(),
        languageCode = readr::col_character(),
        typeId = readr::col_character(),
        term = readr::col_character(),
        caseSignificanceId = readr::col_character()
      )
    )

    # Load SNOMED text definitions
    snomed_definitions <- readr::read_tsv(
      def_file,
      show_col_types = FALSE,
      col_types = readr::cols(
        id = readr::col_character(),
        effectiveTime = readr::col_character(),
        active = readr::col_integer(),
        moduleId = readr::col_character(),
        conceptId = readr::col_character(),
        languageCode = readr::col_character(),
        typeId = readr::col_character(),
        term = readr::col_character(),
        caseSignificanceId = readr::col_character()
      )
    )

    # Get Fully Specified Name (FSN)
    fsn <- snomed_descriptions %>%
      dplyr::filter(conceptId == code, active == 1, typeId == "900000000000003001") %>%
      dplyr::pull(term)

    # Get synonyms
    synonyms <- snomed_descriptions %>%
      dplyr::filter(conceptId == code, active == 1, typeId == "900000000000013009") %>%
      dplyr::pull(term)

    # Get text definition
    definition <- snomed_definitions %>%
      dplyr::filter(conceptId == code, active == 1) %>%
      dplyr::pull(term)

    if (length(fsn) == 0) {
      message("SNOMED concept ID '", code, "' not found")
      return(invisible(NULL))
    }

    result <- list(
      ConceptID = code,
      FSN = fsn,
      Synonyms = synonyms,
      Definition = if(length(definition) > 0) definition else NA_character_
    )

    cat("SNOMED Concept ID:", result$ConceptID, "\n")
    cat("FSN:", result$FSN, "\n")
    cat("Synonyms:", paste(result$Synonyms, collapse = " | "), "\n")
    cat("Definition:", ifelse(is.na(result$Definition), "(not available)", result$Definition), "\n")

    return(invisible(result))
  }
}