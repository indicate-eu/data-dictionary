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
    concept_synonym_path <- file.path(vocab_folder, "CONCEPT_SYNONYM.csv")

    if (!file.exists(concept_path) || !file.exists(concept_relationship_path) || !file.exists(concept_ancestor_path)) {
      message("Required vocabulary files not found in: ", vocab_folder)
      return(NULL)
    }

    # Load files in parallel using future
    message("  Loading CONCEPT, CONCEPT_RELATIONSHIP, CONCEPT_ANCESTOR, and CONCEPT_SYNONYM in parallel from CSV...")

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

    # Load CONCEPT_SYNONYM if file exists
    concept_synonym_future <- if (file.exists(concept_synonym_path)) {
      future::future({
        readr::read_tsv(
          concept_synonym_path,
          col_types = readr::cols(
            concept_id = readr::col_integer(),
            concept_synonym_name = readr::col_character(),
            language_concept_id = readr::col_integer()
          ),
          show_col_types = FALSE
        )
      })
    } else {
      NULL
    }

    # Wait for all futures to complete
    concept <- future::value(concept_future)
    concept_relationship <- future::value(concept_relationship_future)
    concept_ancestor <- future::value(concept_ancestor_future)
    concept_synonym <- if (!is.null(concept_synonym_future)) {
      future::value(concept_synonym_future)
    } else {
      NULL
    }

    message("  OHDSI vocabularies loaded successfully from CSV!")

    return(list(
      concept = concept,
      concept_relationship = concept_relationship,
      concept_ancestor = concept_ancestor,
      concept_synonym = concept_synonym
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

#' Get concept synonyms from concept_synonym table
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
    message("Error querying concept synonyms: ", e$message)
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

    # Get relationships between limited concepts
    relationships <- vocabularies$concept_relationship %>%
      dplyr::filter(
        concept_id_1 %in% limited_concept_ids,
        concept_id_2 %in% limited_concept_ids,
        relationship_id %in% c("Is a", "Subsumes", "Contained in panel", "Panel contains")
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
    edges <- relationships %>%
      dplyr::mutate(
        from = dplyr::if_else(
          relationship_id %in% c("Is a", "Contained in panel"),
          concept_id_2,
          concept_id_1
        ),
        to = dplyr::if_else(
          relationship_id %in% c("Is a", "Contained in panel"),
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
    message("Error building hierarchy graph: ", e$message)
    return(list(nodes = data.frame(), edges = data.frame()))
  })
}
