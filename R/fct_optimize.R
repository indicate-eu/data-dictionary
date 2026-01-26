#' Optimize Concept Set
#'
#' @description Optimizes a concept set by finding common ancestors and removing redundant concepts
#'
#' @param concepts Data frame with concept set items (concept_id, include_descendants, include_mapped, is_excluded)
#'
#' @return List with optimized_concepts and removed_concepts data frames
#' @noRd
optimize_concept_set <- function(concepts) {
  if (is.null(concepts) || nrow(concepts) == 0) {
    return(list(
      optimized_concepts = NULL,
      removed_concepts = NULL
    ))
  }

  # Check if DuckDB vocabularies are available
  if (!duckdb_exists()) {
    return(list(
      optimized_concepts = concepts,
      removed_concepts = NULL,
      error = "Vocabularies not loaded"
    ))
  }

  tryCatch({
    con <- get_duckdb_connection()
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

    # STRATEGY 2: Bottom-up optimization (iterative)
    # Repeatedly find and apply parent replacements until no more are found
    current_concepts <- concepts
    all_removed_total <- list()
    all_added_total <- list()
    iteration <- 0
    max_iterations <- 10  # Safety limit

    repeat {
      iteration <- iteration + 1
      if (iteration > max_iterations) break

      # Get all non-excluded concept IDs from current state
      all_concept_ids <- paste(current_concepts$concept_id[!current_concepts$is_excluded], collapse = ",")

      if (all_concept_ids == "") break

      # Find parents that could replace all their children
    query_bottom_up <- sprintf("
      WITH conceptSetConcepts AS (
        SELECT DISTINCT concept_id
        FROM concept
        WHERE concept_id IN (%s)
          AND invalid_reason IS NULL
      ),
      potentialParents AS (
        -- Find ancestors that have at least 2 descendants in the concept set
        SELECT
          ca.ancestor_concept_id,
          COUNT(DISTINCT ca.descendant_concept_id) as children_in_set,
          GROUP_CONCAT(DISTINCT ca.descendant_concept_id) as child_ids
        FROM concept_ancestor ca
        INNER JOIN conceptSetConcepts csc ON ca.descendant_concept_id = csc.concept_id
        WHERE ca.ancestor_concept_id != ca.descendant_concept_id
          AND ca.ancestor_concept_id NOT IN (%s)  -- Parent not already in set
        GROUP BY ca.ancestor_concept_id
        HAVING COUNT(DISTINCT ca.descendant_concept_id) >= 2
      ),
      parentWithAllChildren AS (
        -- Check if parent has ONLY these children (no other descendants)
        SELECT
          pp.ancestor_concept_id,
          pp.children_in_set,
          pp.child_ids,
          COUNT(DISTINCT ca2.descendant_concept_id) as total_descendants
        FROM potentialParents pp
        LEFT JOIN concept_ancestor ca2 ON pp.ancestor_concept_id = ca2.ancestor_concept_id
          AND ca2.ancestor_concept_id != ca2.descendant_concept_id
        GROUP BY pp.ancestor_concept_id, pp.children_in_set, pp.child_ids
        HAVING pp.children_in_set = COUNT(DISTINCT ca2.descendant_concept_id)
      )
      SELECT
        pwac.ancestor_concept_id as parent_id,
        c.concept_name as parent_name,
        pwac.children_in_set,
        pwac.child_ids
      FROM parentWithAllChildren pwac
      JOIN concept c ON pwac.ancestor_concept_id = c.concept_id
      WHERE c.invalid_reason IS NULL
      ORDER BY pwac.children_in_set DESC
    ", all_concept_ids, all_concept_ids)

      parent_suggestions <- DBI::dbGetQuery(con, query_bottom_up)

      # If no parent suggestions found, exit loop
      if (is.null(parent_suggestions) || nrow(parent_suggestions) == 0) {
        break
      }

      # Apply ALL parent suggestions in this iteration
      optimized <- current_concepts
      iteration_had_changes <- FALSE

      for (i in 1:nrow(parent_suggestions)) {
        parent_id <- parent_suggestions$parent_id[i]
        parent_name <- parent_suggestions$parent_name[i]
        child_ids <- as.integer(strsplit(parent_suggestions$child_ids[i], ",")[[1]])

        # Check if children are still in optimized set
        if (all(child_ids %in% optimized$concept_id)) {
          # Remove children
          removed_rows <- optimized[optimized$concept_id %in% child_ids, ]
          optimized <- optimized[!optimized$concept_id %in% child_ids, ]

          # Create parent row with same structure
          parent_row <- concepts[1, ]
          parent_row$concept_id <- parent_id
          parent_row$concept_name <- parent_name
          parent_row$include_descendants <- TRUE
          parent_row$include_mapped <- FALSE
          parent_row$is_excluded <- FALSE

          # Add parent
          optimized <- rbind(optimized, parent_row)

          # Track changes
          all_removed_total[[length(all_removed_total) + 1]] <- removed_rows
          all_added_total[[length(all_added_total) + 1]] <- parent_row
          iteration_had_changes <- TRUE
        }
      }

      # Update current state for next iteration
      current_concepts <- optimized

      # If no changes were made this iteration, exit
      if (!iteration_had_changes) {
        break
      }
    }

    # If we made any optimizations, return results
    if (length(all_removed_total) > 0) {
      removed <- do.call(rbind, all_removed_total)
      added <- do.call(rbind, all_added_total)

      return(list(
        optimized_concepts = current_concepts,
        removed_concepts = removed,
        added_concepts = added,
        removed_count = nrow(removed),
        optimization_type = "bottom_up"
      ))
    }

    # STRATEGY 1: Top-down optimization
    # Remove descendants when parent has include_descendants=TRUE
    candidates <- concepts[!concepts$is_excluded & concepts$include_descendants, ]

    # STRATEGY 1: If no bottom-up optimization, try top-down
    if (nrow(candidates) == 0) {
      return(list(
        optimized_concepts = concepts,
        removed_concepts = NULL
      ))
    }

    all_concept_ids <- paste(concepts$concept_id, collapse = ",")
    descendant_concept_ids <- paste(candidates$concept_id, collapse = ",")

    # ATLAS SQL optimization query (adapted for DuckDB)
    query <- sprintf("
      WITH conceptSetConcepts AS (
        -- All concepts in the concept set
        SELECT DISTINCT concept_id
        FROM concept
        WHERE concept_id IN (%s)
          AND invalid_reason IS NULL
      ), conceptsWithDescendants AS (
        -- Concepts that have include_descendants=TRUE
        SELECT DISTINCT concept_id
        FROM concept
        WHERE concept_id IN (%s)
          AND invalid_reason IS NULL
      ), redundantConcepts AS (
        -- Find concepts that are descendants of concepts with include_descendants=TRUE
        SELECT DISTINCT ca.descendant_concept_id AS concept_id
        FROM concept_ancestor ca
        INNER JOIN conceptsWithDescendants cwd ON ca.ancestor_concept_id = cwd.concept_id
        INNER JOIN conceptSetConcepts csc ON ca.descendant_concept_id = csc.concept_id
        WHERE ca.ancestor_concept_id != ca.descendant_concept_id
      ), conceptSetOptimized AS (
        -- Concepts to keep (not redundant)
        SELECT csc.concept_id, c.concept_name
        FROM conceptSetConcepts csc
        LEFT JOIN redundantConcepts rc ON csc.concept_id = rc.concept_id
        LEFT JOIN concept c ON csc.concept_id = c.concept_id
        WHERE rc.concept_id IS NULL
      ), conceptSetRemoved AS (
        -- Concepts to remove (redundant)
        SELECT rc.concept_id, c.concept_name
        FROM redundantConcepts rc
        LEFT JOIN concept c ON rc.concept_id = c.concept_id
      )
      SELECT *, 0 AS removed
      FROM conceptSetOptimized
      UNION
      SELECT *, 1 AS removed
      FROM conceptSetRemoved
    ", all_concept_ids, descendant_concept_ids)

    result <- DBI::dbGetQuery(con, query)

    if (is.null(result) || nrow(result) == 0) {
      return(list(
        optimized_concepts = concepts,
        removed_concepts = NULL
      ))
    }

    # Separate optimized and removed concepts
    optimized_concept_ids <- result$concept_id[result$removed == 0]
    removed_concept_ids <- result$concept_id[result$removed == 1]

    if (length(removed_concept_ids) == 0) {
      return(list(
        optimized_concepts = concepts,
        removed_concepts = NULL
      ))
    }

    # Build optimized and removed dataframes
    optimized <- concepts[concepts$concept_id %in% optimized_concept_ids, ]
    removed <- concepts[concepts$concept_id %in% removed_concept_ids, ]

    return(list(
      optimized_concepts = optimized,
      removed_concepts = removed,
      removed_count = nrow(removed),
      optimization_type = "top_down"
    ))

  }, error = function(e) {
    return(list(
      optimized_concepts = concepts,
      removed_concepts = NULL,
      error = e$message
    ))
  })
}
