#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery dbExistsTable
NULL

# CONFIG CRUD ====

#' Get Config Value
#'
#' @description Retrieve a configuration value from the database
#' @param key Configuration key
#' @return Character value or NULL if not found
#' @noRd
get_config_value <- function(key) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT value FROM config WHERE key = ?",
    params = list(key)
  )

  if (nrow(result) == 0) return(NULL)

  result$value[1]
}

#' Set Config Value
#'
#' @description Set a configuration value in the database
#' @param key Configuration key
#' @param value Configuration value
#' @return TRUE if successful
#' @noRd
set_config_value <- function(key, value) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Check if key exists
  existing <- DBI::dbGetQuery(
    con,
    "SELECT key FROM config WHERE key = ?",
    params = list(key)
  )

  if (nrow(existing) > 0) {
    DBI::dbExecute(
      con,
      "UPDATE config SET value = ?, updated_at = ? WHERE key = ?",
      params = list(value, timestamp, key)
    )
  } else {
    DBI::dbExecute(
      con,
      "INSERT INTO config (key, value, created_at, updated_at) VALUES (?, ?, ?, ?)",
      params = list(key, value, timestamp, timestamp)
    )
  }

  TRUE
}

# CONCEPT SETS CRUD ====

#' Add Concept Set
#'
#' @description Create a new concept set
#' @param id Concept set ID (optional, auto-generated if NULL)
#' @param name Concept set name
#' @param description Description
#' @param category Category
#' @param subcategory Subcategory
#' @param long_description Long description
#' @param tags Comma-separated tags
#' @param created_by Username
#' @return Concept set ID
#' @noRd
add_concept_set <- function(id = NULL, name, description = NULL, category = NULL,
                            subcategory = NULL, long_description = NULL, tags = NULL,
                            created_by_first_name = NULL, created_by_last_name = NULL,
                            created_by_profession = NULL, created_by_affiliation = NULL,
                            created_by_orcid = NULL, language = "en") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")

  if (is.null(id)) {
    max_id <- DBI::dbGetQuery(con, "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM concept_sets")
    id <- max_id$next_id[1]
  }

  # Convert NULL to NA for RSQLite compatibility
  null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x

  # Insert into main table (always uses provided values as defaults)
  DBI::dbExecute(
    con,
    "INSERT INTO concept_sets (id, name, description, category, subcategory, long_description, tags,
     created_by_first_name, created_by_last_name, created_by_profession, created_by_affiliation, created_by_orcid,
     created_date, modified_date)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(
      id,
      name,
      null_to_na(description),
      null_to_na(category),
      null_to_na(subcategory),
      null_to_na(long_description),
      null_to_na(tags),
      null_to_na(created_by_first_name),
      null_to_na(created_by_last_name),
      null_to_na(created_by_profession),
      null_to_na(created_by_affiliation),
      null_to_na(created_by_orcid),
      timestamp,
      timestamp
    )
  )

  # Create translations for the current language
  translatable_fields <- list(
    name = name,
    description = description,
    category = category,
    subcategory = subcategory,
    long_description = long_description
  )

  for (field_name in names(translatable_fields)) {
    field_value <- translatable_fields[[field_name]]
    if (!is.null(field_value) && !is.na(field_value) && nchar(field_value) > 0) {
      set_concept_set_translation(id, language, field_name, field_value)
    }
  }

  id
}

#' Delete Concept Set
#'
#' @description Delete a concept set
#' @param concept_set_id Concept set ID
#' @return TRUE if successful
#' @noRd
delete_concept_set <- function(concept_set_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Delete associated concept set items first
  DBI::dbExecute(con, "DELETE FROM concept_set_items WHERE concept_set_id = ?", params = list(concept_set_id))

  # Delete translations
  DBI::dbExecute(con, "DELETE FROM concept_set_translations WHERE concept_set_id = ?", params = list(concept_set_id))

  # Delete the concept set
  DBI::dbExecute(con, "DELETE FROM concept_sets WHERE id = ?", params = list(concept_set_id))

  TRUE
}

#' Get All Concept Sets
#'
#' @description Retrieve all concept sets
#' @param language Language code for translations (not used yet)
#' @return Data frame with concept sets
#' @noRd
get_all_concept_sets <- function(language = "en") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # If language is provided, use translations with fallback to default values
  if (!is.null(language) && language != "en") {
    query <- sprintf("SELECT
      cs.id,
      COALESCE(t_name.value, cs.name) AS name,
      COALESCE(t_desc.value, cs.description) AS description,
      COALESCE(t_cat.value, cs.category) AS category,
      COALESCE(t_subcat.value, cs.subcategory) AS subcategory,
      cs.tags,
      cs.version,
      cs.review_status,
      cs.created_by_first_name,
      cs.created_by_last_name,
      cs.created_by_profession,
      cs.created_by_affiliation,
      cs.created_by_orcid,
      cs.created_date,
      cs.modified_by_first_name,
      cs.modified_by_last_name,
      cs.modified_by_profession,
      cs.modified_by_affiliation,
      cs.modified_by_orcid,
      cs.modified_date,
      COALESCE(item_counts.item_count, 0) AS item_count
    FROM concept_sets cs
    LEFT JOIN concept_set_translations t_name ON cs.id = t_name.concept_set_id AND t_name.language = '%s' AND t_name.field = 'name'
    LEFT JOIN concept_set_translations t_desc ON cs.id = t_desc.concept_set_id AND t_desc.language = '%s' AND t_desc.field = 'description'
    LEFT JOIN concept_set_translations t_cat ON cs.id = t_cat.concept_set_id AND t_cat.language = '%s' AND t_cat.field = 'category'
    LEFT JOIN concept_set_translations t_subcat ON cs.id = t_subcat.concept_set_id AND t_subcat.language = '%s' AND t_subcat.field = 'subcategory'
    LEFT JOIN (
      SELECT concept_set_id, COUNT(*) AS item_count
      FROM concept_set_items
      GROUP BY concept_set_id
    ) item_counts ON cs.id = item_counts.concept_set_id
    ORDER BY COALESCE(t_cat.value, cs.category), COALESCE(t_subcat.value, cs.subcategory), COALESCE(t_name.value, cs.name)", language, language, language, language)
  } else {
    query <- "SELECT
      cs.id,
      cs.name,
      cs.description,
      cs.category,
      cs.subcategory,
      cs.tags,
      cs.version,
      cs.review_status,
      cs.created_by_first_name,
      cs.created_by_last_name,
      cs.created_by_profession,
      cs.created_by_affiliation,
      cs.created_by_orcid,
      cs.created_date,
      cs.modified_by_first_name,
      cs.modified_by_last_name,
      cs.modified_by_profession,
      cs.modified_by_affiliation,
      cs.modified_by_orcid,
      cs.modified_date,
      COALESCE(item_counts.item_count, 0) AS item_count
    FROM concept_sets cs
    LEFT JOIN (
      SELECT concept_set_id, COUNT(*) AS item_count
      FROM concept_set_items
      GROUP BY concept_set_id
    ) item_counts ON cs.id = item_counts.concept_set_id
    ORDER BY cs.category, cs.subcategory, cs.name"
  }

  DBI::dbGetQuery(con, query)
}

#' Get Concept Set by ID
#'
#' @description Retrieve a specific concept set
#' @param concept_set_id Concept set ID
#' @param language Language code for translations
#' @return List with concept set data, or NULL if not found
#' @noRd
get_concept_set <- function(concept_set_id, language = "en") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  cs <- DBI::dbGetQuery(
    con,
    "SELECT * FROM concept_sets WHERE id = ?",
    params = list(concept_set_id)
  )

  if (nrow(cs) == 0) return(NULL)

  result <- as.list(cs[1, ])

  # If language is not EN, overlay with translations
  if (!is.null(language) && language != "en") {
    translatable_fields <- c("name", "description", "category", "subcategory", "long_description")
    for (field in translatable_fields) {
      translation <- get_concept_set_translation(concept_set_id, language, field)
      if (!is.null(translation) && !is.na(translation)) {
        result[[field]] <- translation
      }
    }
  }

  result
}

#' Get Concept Set Reviews
#'
#' @description Retrieve all reviews for a concept set
#' @param concept_set_id Concept set ID
#' @return Data frame of reviews with reviewer information
#' @noRd
get_concept_set_reviews <- function(concept_set_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT
      r.review_id,
      r.concept_set_id,
      r.concept_set_version AS version,
      r.reviewer_user_id,
      r.status,
      r.comments,
      r.review_date,
      u.first_name || ' ' || u.last_name AS reviewer_name
    FROM concept_set_reviews r
    LEFT JOIN users u ON r.reviewer_user_id = u.user_id
    WHERE r.concept_set_id = ?
    ORDER BY r.review_date DESC",
    params = list(concept_set_id)
  )
}

#' Get Version History
#'
#' @description Retrieve version history for a concept set from changelog
#' @param concept_set_id Concept set ID
#' @return Data frame of version changes
#' @noRd
get_version_history <- function(concept_set_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT
      c.change_id,
      c.concept_set_id,
      c.version_from,
      c.version_to,
      c.changed_by_user_id,
      c.change_date,
      c.change_type,
      c.change_summary,
      u.first_name || ' ' || u.last_name AS changed_by_name
    FROM concept_set_changelog c
    LEFT JOIN users u ON c.changed_by_user_id = u.user_id
    WHERE c.concept_set_id = ? AND c.change_type = 'version_change'
    ORDER BY c.change_date DESC",
    params = list(concept_set_id)
  )
}

#' Add Concept Set Item
#'
#' @description Add a concept to a concept set
#' @param concept_set_id Concept set ID
#' @param concept_id OMOP concept ID
#' @param concept_name Concept name
#' @param vocabulary_id Vocabulary ID
#' @param concept_code Concept code
#' @param domain_id Domain ID
#' @param concept_class_id Concept class ID
#' @param standard_concept Standard concept flag (S, C, or NULL)
#' @param is_excluded Whether concept is excluded (default FALSE)
#' @param include_descendants Whether to include descendants (default TRUE)
#' @param include_mapped Whether to include mapped concepts (default TRUE)
#' @return TRUE if successful
#' @noRd
add_concept_set_item <- function(concept_set_id, concept_id, concept_name,
                                  vocabulary_id = NULL, concept_code = NULL,
                                  domain_id = NULL, concept_class_id = NULL,
                                  standard_concept = NULL, is_excluded = FALSE,
                                  include_descendants = TRUE, include_mapped = TRUE) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Check if already exists
  existing <- DBI::dbGetQuery(
    con,
    "SELECT 1 FROM concept_set_items WHERE concept_set_id = ? AND concept_id = ?",
    params = list(concept_set_id, concept_id)
  )

  if (nrow(existing) > 0) return(FALSE)

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Convert NULL to NA for RSQLite compatibility
  null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x

  DBI::dbExecute(
    con,
    "INSERT INTO concept_set_items (concept_set_id, concept_id, concept_name, vocabulary_id,
     concept_code, domain_id, concept_class_id, standard_concept, is_excluded,
     include_descendants, include_mapped, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(
      concept_set_id,
      concept_id,
      concept_name,
      null_to_na(vocabulary_id),
      null_to_na(concept_code),
      null_to_na(domain_id),
      null_to_na(concept_class_id),
      null_to_na(standard_concept),
      as.integer(is_excluded),
      as.integer(include_descendants),
      as.integer(include_mapped),
      timestamp
    )
  )

  # Update concept set modified_date
  DBI::dbExecute(
    con,
    "UPDATE concept_sets SET modified_date = ? WHERE id = ?",
    params = list(format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"), concept_set_id)
  )

  TRUE
}

#' Add Concept Set Review
#'
#' @description Add a review for a concept set
#' @param concept_set_id Concept set ID
#' @param version Version being reviewed
#' @param reviewer_user_id User ID of reviewer
#' @param status Review status (pending_review, approved, needs_revision)
#' @param comments Review comments
#' @return Review ID
#' @noRd
add_concept_set_review <- function(concept_set_id, version, reviewer_user_id, status, comments = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

  # Helper to convert NULL to NA
  null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x

  DBI::dbExecute(
    con,
    "INSERT INTO concept_set_reviews (concept_set_id, concept_set_version, reviewer_user_id, status, comments, review_date)
     VALUES (?, ?, ?, ?, ?, ?)",
    params = list(concept_set_id, version, reviewer_user_id, status, null_to_na(comments), timestamp)
  )

  # Get the last inserted ID
  review_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id

  review_id
}

#' Delete Concept Set Review
#'
#' @description Delete a review for a concept set
#' @param review_id Review ID to delete
#' @return TRUE if successful
#' @noRd
delete_concept_set_review <- function(review_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM concept_set_reviews WHERE review_id = ?",
    params = list(review_id)
  )

  TRUE
}

#' Update Concept Set Review
#'
#' @description Update a review for a concept set
#' @param review_id Review ID to update
#' @param status Review status (approved, needs_revision)
#' @param comments Review comments (markdown)
#' @return TRUE if successful
#' @noRd
update_concept_set_review <- function(review_id, status = NULL, comments = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Helper to convert NULL to NA
  null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x

  # Build dynamic update query
  updates <- list()
  params <- list()

  if (!is.null(status)) {
    updates <- append(updates, "status = ?")
    params <- append(params, status)
  }

  if (!is.null(comments)) {
    updates <- append(updates, "comments = ?")
    params <- append(params, null_to_na(comments))
  }

  if (length(updates) == 0) {
    return(TRUE)
  }

  # Add review_id as last parameter
  params <- append(params, review_id)

  query <- sprintf(
    "UPDATE concept_set_reviews SET %s WHERE review_id = ?",
    paste(updates, collapse = ", ")
  )

  DBI::dbExecute(con, query, params = params)

  TRUE
}

#' Update Concept Set Stats
#'
#' @description Update statistics JSON for a concept set
#' @param concept_set_id Concept set ID
#' @param stats_json JSON string with statistics
#' @return TRUE if successful
#' @noRd
update_concept_set_stats <- function(concept_set_id, stats_json) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

  # Check if stats exist
  existing <- DBI::dbGetQuery(
    con,
    "SELECT concept_set_id FROM concept_set_stats WHERE concept_set_id = ?",
    params = list(concept_set_id)
  )

  if (nrow(existing) > 0) {
    # Update
    DBI::dbExecute(
      con,
      "UPDATE concept_set_stats SET stats = ?, updated_at = ? WHERE concept_set_id = ?",
      params = list(stats_json, timestamp, concept_set_id)
    )
  } else {
    # Insert
    DBI::dbExecute(
      con,
      "INSERT INTO concept_set_stats (concept_set_id, stats, updated_at) VALUES (?, ?, ?)",
      params = list(concept_set_id, stats_json, timestamp)
    )
  }

  TRUE
}

#' Add Changelog Entry
#'
#' @description Add a changelog entry for a concept set version change
#' @param concept_set_id Concept set ID
#' @param version_from Previous version (NULL for initial version)
#' @param version_to New version
#' @param changed_by_user_id User ID who made the change
#' @param change_type Type of change (created, updated, version_change, status_change)
#' @param change_summary Summary of changes
#' @param changes_json JSON blob with detailed changes (optional)
#' @return Changelog ID
#' @noRd
add_changelog_entry <- function(concept_set_id, version_from = NULL, version_to, changed_by_user_id = NULL,
                                change_type = "version_change", change_summary = NULL, changes_json = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

  # Helper to convert NULL to NA
  null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x

  DBI::dbExecute(
    con,
    "INSERT INTO concept_set_changelog (concept_set_id, version_from, version_to, changed_by_user_id, change_date, change_type, change_summary, changes_json)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(
      concept_set_id,
      null_to_na(version_from),
      version_to,
      null_to_na(changed_by_user_id),
      timestamp,
      change_type,
      null_to_na(change_summary),
      null_to_na(changes_json)
    )
  )

  # Get the last inserted ID
  change_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id

  change_id
}

#' Delete Changelog Entry
#'
#' @description Delete a changelog entry
#' @param change_id Changelog entry ID
#' @return TRUE if successful
#' @noRd
delete_changelog_entry <- function(change_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM concept_set_changelog WHERE change_id = ?",
    params = list(change_id)
  )

  TRUE
}

#' Update Changelog Entry
#'
#' @description Update a changelog entry's summary
#' @param change_id Changelog entry ID
#' @param change_summary New summary text
#' @return TRUE if successful
#' @noRd
update_changelog_entry <- function(change_id, change_summary) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Helper to convert NULL to NA
  null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x

  DBI::dbExecute(
    con,
    "UPDATE concept_set_changelog SET change_summary = ? WHERE change_id = ?",
    params = list(null_to_na(change_summary), change_id)
  )

  TRUE
}

#' Delete Concept Set Item
#'
#' @description Remove a concept from a concept set
#' @param concept_set_id Concept set ID
#' @param concept_id Concept ID
#' @return TRUE if successful
#' @noRd
delete_concept_set_item <- function(concept_set_id, concept_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM concept_set_items WHERE concept_set_id = ? AND concept_id = ?",
    params = list(concept_set_id, concept_id)
  )

  # Update concept set modified_date
  DBI::dbExecute(
    con,
    "UPDATE concept_sets SET modified_date = ? WHERE id = ?",
    params = list(format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"), concept_set_id)
  )

  TRUE
}

#' Get Concept Set Items
#'
#' @description Retrieve all concepts in a concept set
#' @param concept_set_id Concept set ID
#' @return Data frame with concept set items
#' @noRd
get_concept_set_items <- function(concept_set_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT
      concept_id,
      concept_name,
      vocabulary_id,
      concept_code,
      domain_id,
      concept_class_id,
      standard_concept,
      is_excluded,
      include_descendants,
      include_mapped
    FROM concept_set_items
    WHERE concept_set_id = ?
    ORDER BY concept_name",
    params = list(concept_set_id)
  )
}

#' Get Concept Set IDs for Projects
#'
#' @description Get unique concept set IDs associated with given project IDs
#' @param project_ids Vector of project IDs
#' @return Integer vector of concept set IDs
#' @noRd
get_concept_set_ids_for_projects <- function(project_ids) {
  if (length(project_ids) == 0) return(integer(0))
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  placeholders <- paste(rep("?", length(project_ids)), collapse = ", ")
  query <- sprintf(
    "SELECT DISTINCT concept_set_id FROM project_concept_sets WHERE project_id IN (%s)",
    placeholders
  )
  result <- DBI::dbGetQuery(con, query, params = as.list(project_ids))
  if (nrow(result) == 0) return(integer(0))
  result$concept_set_id
}

#' Update Concept Set Item
#'
#' @description Update flags for a concept in a concept set
#' @param concept_set_id Concept set ID
#' @param concept_id Concept ID
#' @param is_excluded Whether concept is excluded
#' @param include_descendants Whether to include descendants
#' @param include_mapped Whether to include mapped concepts
#' @return TRUE if successful
#' @noRd
update_concept_set_item <- function(concept_set_id, concept_id,
                                     is_excluded = NULL, include_descendants = NULL,
                                     include_mapped = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  updates <- list()
  if (!is.null(is_excluded)) updates$is_excluded <- as.integer(is_excluded)
  if (!is.null(include_descendants)) updates$include_descendants <- as.integer(include_descendants)
  if (!is.null(include_mapped)) updates$include_mapped <- as.integer(include_mapped)

  if (length(updates) == 0) return(TRUE)

  set_clauses <- paste0(names(updates), " = ?", collapse = ", ")
  params <- c(unname(updates), concept_set_id, concept_id)

  DBI::dbExecute(
    con,
    paste0("UPDATE concept_set_items SET ", set_clauses, " WHERE concept_set_id = ? AND concept_id = ?"),
    params = params
  )

  # Update concept set modified_date
  DBI::dbExecute(
    con,
    "UPDATE concept_sets SET modified_date = ? WHERE id = ?",
    params = list(format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"), concept_set_id)
  )

  TRUE
}

#' Update Concept Set
#'
#' @description Update an existing concept set
#' @param concept_set_id Concept set ID
#' @param ... Fields to update
#' @return TRUE if successful
#' @noRd
update_concept_set <- function(concept_set_id, ..., language = "en") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  updates <- list(...)
  if (length(updates) == 0) return(TRUE)

  # Convert NULL to NA for RSQLite compatibility
  null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x

  # Separate translatable fields from non-translatable fields
  translatable_fields <- c("name", "description", "category", "subcategory", "long_description")
  translatable_updates <- updates[names(updates) %in% translatable_fields]
  non_translatable_updates <- updates[!names(updates) %in% translatable_fields]

  # Update translations for translatable fields
  for (field_name in names(translatable_updates)) {
    field_value <- translatable_updates[[field_name]]
    set_concept_set_translation(concept_set_id, language, field_name, field_value)
  }

  # Update main table for non-translatable fields (and always update modified_date)
  if (length(non_translatable_updates) > 0 || language == "en") {
    # If language is EN, also update the main table columns
    if (language == "en") {
      all_updates <- c(translatable_updates, non_translatable_updates)
    } else {
      all_updates <- non_translatable_updates
    }

    if (length(all_updates) > 0) {
      all_updates <- lapply(all_updates, null_to_na)
      set_clauses <- paste0(names(all_updates), " = ?", collapse = ", ")
      set_clauses <- paste0(set_clauses, ", modified_date = ?")

      timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
      params <- c(unname(all_updates), timestamp, concept_set_id)

      DBI::dbExecute(
        con,
        paste0("UPDATE concept_sets SET ", set_clauses, " WHERE id = ?"),
        params = params
      )
    } else {
      # Just update modified_date
      timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
      DBI::dbExecute(
        con,
        "UPDATE concept_sets SET modified_date = ? WHERE id = ?",
        params = list(timestamp, concept_set_id)
      )
    }
  }

  TRUE
}

# TAGS CRUD ====

#' Add Tag
#'
#' @description Create a new tag
#' @param name Tag name
#' @param color Tag color (hex code, default: #6c757d)
#' @return Tag ID
#' @noRd
add_tag <- function(name, color = "#6c757d") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "INSERT INTO tags (name, color, created_at, updated_at) VALUES (?, ?, ?, ?)",
    params = list(name, color, timestamp, timestamp)
  )

  # Return the new tag ID
  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")
  result$id[1]
}

#' Delete Tag
#'
#' @description Delete a tag (only if not used by any concept set)
#' @param tag_id Tag ID
#' @return TRUE if deleted, FALSE if tag is in use
#' @noRd
delete_tag <- function(tag_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Get tag name

  tag <- DBI::dbGetQuery(con, "SELECT name FROM tags WHERE tag_id = ?", params = list(tag_id))
  if (nrow(tag) == 0) return(TRUE)

  tag_name <- tag$name[1]

  # Check if tag is used in any concept set
  # Tags are stored as comma-separated values in the tags column
  usage <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS count FROM concept_sets WHERE tags LIKE ? OR tags LIKE ? OR tags LIKE ? OR tags = ?",
    params = list(
      paste0("%,", tag_name, ",%"),
      paste0(tag_name, ",%"),
      paste0("%,", tag_name),
      tag_name
    )
  )

  if (usage$count[1] > 0) {
    return(FALSE)
  }

  DBI::dbExecute(con, "DELETE FROM tags WHERE tag_id = ?", params = list(tag_id))
  TRUE
}

#' Get All Tags
#'
#' @description Retrieve all tags
#' @return Data frame with tags
#' @noRd
get_all_tags <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT tag_id, name, COALESCE(color, '#6c757d') as color, created_at, updated_at FROM tags ORDER BY name"
  )
}

#' Get Tag Usage Count
#'
#' @description Get the number of concept sets using a tag
#' @param tag_name Tag name
#' @return Integer count
#' @noRd
get_tag_usage_count <- function(tag_name) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  usage <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS count FROM concept_sets WHERE tags LIKE ? OR tags LIKE ? OR tags LIKE ? OR tags = ?",
    params = list(
      paste0("%,", tag_name, ",%"),
      paste0(tag_name, ",%"),
      paste0("%,", tag_name),
      tag_name
    )
  )

  usage$count[1]
}

#' Update Tag
#'
#' @description Update a tag name and/or color
#' @param tag_id Tag ID
#' @param name New tag name
#' @param color New tag color (hex code)
#' @return TRUE if successful
#' @noRd
update_tag <- function(tag_id, name, color = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Get old tag name for updating concept sets
  old_tag <- DBI::dbGetQuery(con, "SELECT name FROM tags WHERE tag_id = ?", params = list(tag_id))
  if (nrow(old_tag) == 0) return(FALSE)

  old_name <- old_tag$name[1]
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Update tag name and color
  if (!is.null(color)) {
    DBI::dbExecute(
      con,
      "UPDATE tags SET name = ?, color = ?, updated_at = ? WHERE tag_id = ?",
      params = list(name, color, timestamp, tag_id)
    )
  } else {
    DBI::dbExecute(
      con,
      "UPDATE tags SET name = ?, updated_at = ? WHERE tag_id = ?",
      params = list(name, timestamp, tag_id)
    )
  }

  # Update tag references in concept sets
  # This is a bit complex because tags are comma-separated
  concept_sets <- DBI::dbGetQuery(
    con,
    "SELECT id, tags FROM concept_sets WHERE tags LIKE ? OR tags LIKE ? OR tags LIKE ? OR tags = ?",
    params = list(
      paste0("%,", old_name, ",%"),
      paste0(old_name, ",%"),
      paste0("%,", old_name),
      old_name
    )
  )

  for (i in seq_len(nrow(concept_sets))) {
    tags_list <- strsplit(concept_sets$tags[i], ",")[[1]]
    tags_list <- trimws(tags_list)
    tags_list[tags_list == old_name] <- name
    new_tags <- paste(tags_list, collapse = ",")

    DBI::dbExecute(
      con,
      "UPDATE concept_sets SET tags = ? WHERE id = ?",
      params = list(new_tags, concept_sets$id[i])
    )
  }

  TRUE
}

# PROJECTS CRUD ====

#' Add Project
#'
#' @description Create a new project
#' @param name Project name
#' @param description Project description
#' @param created_by Username who created the project
#' @return Project ID
#' @noRd
add_project <- function(name, description = NULL, created_by = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Convert NULL to NA for RSQLite compatibility
  null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x

  DBI::dbExecute(
    con,
    "INSERT INTO projects (name, description, created_by, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?)",
    params = list(name, null_to_na(description), null_to_na(created_by), timestamp, timestamp)
  )

  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")
  result$id[1]
}

#' Delete Project
#'
#' @description Delete a project and its concept set associations
#' @param project_id Project ID
#' @return TRUE if successful
#' @noRd
delete_project <- function(project_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Delete concept set associations first
  DBI::dbExecute(
    con,
    "DELETE FROM project_concept_sets WHERE project_id = ?",
    params = list(project_id)
  )

  # Delete the project
  DBI::dbExecute(
    con,
    "DELETE FROM projects WHERE project_id = ?",
    params = list(project_id)
  )

  TRUE
}

#' Get All Projects
#'
#' @description Retrieve all projects with concept set counts
#' @return Data frame with projects
#' @noRd
get_all_projects <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT
      p.project_id,
      p.name,
      p.description,
      p.created_by,
      p.created_at,
      p.updated_at,
      (SELECT COUNT(*) FROM project_concept_sets pcs WHERE pcs.project_id = p.project_id) AS concept_set_count
    FROM projects p
    ORDER BY p.name"
  )
}

#' Get Project by ID
#'
#' @description Retrieve a specific project
#' @param project_id Project ID
#' @return List with project data, or NULL if not found
#' @noRd
get_project <- function(project_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  project <- DBI::dbGetQuery(
    con,
    "SELECT * FROM projects WHERE project_id = ?",
    params = list(project_id)
  )

  if (nrow(project) == 0) return(NULL)

  as.list(project[1, ])
}

#' Update Project
#'
#' @description Update an existing project
#' @param project_id Project ID
#' @param ... Fields to update (name, description)
#' @return TRUE if successful
#' @noRd
update_project <- function(project_id, ...) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  updates <- list(...)
  if (length(updates) == 0) return(TRUE)

  # Convert NULL to NA for RSQLite compatibility
  null_to_na <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else x
  updates <- lapply(updates, null_to_na)

  set_clauses <- paste0(names(updates), " = ?", collapse = ", ")
  set_clauses <- paste0(set_clauses, ", updated_at = ?")

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  params <- c(unname(updates), timestamp, project_id)

  DBI::dbExecute(
    con,
    paste0("UPDATE projects SET ", set_clauses, " WHERE project_id = ?"),
    params = params
  )

  TRUE
}

# PROJECT CONCEPT SETS CRUD ====

#' Add Concept Set to Project
#'
#' @description Associate a concept set with a project
#' @param project_id Project ID
#' @param concept_set_id Concept set ID
#' @return TRUE if successful
#' @noRd
add_project_concept_set <- function(project_id, concept_set_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Check if association already exists
  existing <- DBI::dbGetQuery(
    con,
    "SELECT 1 FROM project_concept_sets WHERE project_id = ? AND concept_set_id = ?",
    params = list(project_id, concept_set_id)
  )

  if (nrow(existing) > 0) return(TRUE)

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "INSERT INTO project_concept_sets (project_id, concept_set_id, created_at)
     VALUES (?, ?, ?)",
    params = list(project_id, concept_set_id, timestamp)
  )

  TRUE
}

#' Remove Concept Set from Project
#'
#' @description Remove association between a concept set and a project
#' @param project_id Project ID
#' @param concept_set_id Concept set ID
#' @return TRUE if successful
#' @noRd
remove_project_concept_set <- function(project_id, concept_set_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM project_concept_sets WHERE project_id = ? AND concept_set_id = ?",
    params = list(project_id, concept_set_id)
  )

  TRUE
}

#' Get Concept Sets for Project
#'
#' @description Get all concept sets associated with a project
#' @param project_id Project ID
#' @return Data frame with concept sets
#' @noRd
get_project_concept_sets <- function(project_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT
      cs.id,
      cs.name,
      cs.description,
      cs.category,
      cs.subcategory,
      cs.tags,
      pcs.created_at AS added_at
    FROM project_concept_sets pcs
    JOIN concept_sets cs ON pcs.concept_set_id = cs.id
    WHERE pcs.project_id = ?
    ORDER BY cs.category, cs.subcategory, cs.name",
    params = list(project_id)
  )
}

#' Get Available Concept Sets for Project
#'
#' @description Get concept sets not yet associated with a project
#' @param project_id Project ID
#' @return Data frame with available concept sets
#' @noRd
get_available_concept_sets_for_project <- function(project_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT
      cs.id,
      cs.name,
      cs.description,
      cs.category,
      cs.subcategory,
      cs.tags
    FROM concept_sets cs
    WHERE cs.id NOT IN (
      SELECT concept_set_id FROM project_concept_sets WHERE project_id = ?
    )
    ORDER BY cs.category, cs.subcategory, cs.name",
    params = list(project_id)
  )
}

# RECOMMENDED UNITS CRUD ====

#' Add Recommended Unit
#'
#' @description Create a new recommended unit mapping
#' @param concept_id OMOP concept ID
#' @param recommended_unit_concept_id Recommended unit concept ID
#' @return Inserted row ID, or FALSE if duplicate
#' @noRd
add_recommended_unit <- function(concept_id, recommended_unit_concept_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  existing <- DBI::dbGetQuery(
    con,
    "SELECT id FROM recommended_units WHERE concept_id = ? AND recommended_unit_concept_id = ?",
    params = list(as.integer(concept_id), as.integer(recommended_unit_concept_id))
  )

  if (nrow(existing) > 0) return(FALSE)

  DBI::dbExecute(
    con,
    "INSERT INTO recommended_units (concept_id, recommended_unit_concept_id, created_at)
     VALUES (?, ?, ?)",
    params = list(as.integer(concept_id), as.integer(recommended_unit_concept_id), timestamp)
  )

  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")
  result$id[1]
}

#' Delete Recommended Unit
#'
#' @description Delete a recommended unit mapping by ID
#' @param id Row ID
#' @return TRUE if successful
#' @noRd
delete_recommended_unit <- function(id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM recommended_units WHERE id = ?",
    params = list(id)
  )

  TRUE
}

#' Get All Recommended Units
#'
#' @description Retrieve all recommended unit mappings
#' @return Data frame with recommended units
#' @noRd
get_all_recommended_units <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT id, concept_id, recommended_unit_concept_id, created_at
     FROM recommended_units
     ORDER BY concept_id"
  )
}

#' Load Default Recommended Units
#'
#' @description Load default recommended units from bundled CSV into the database.
#'   Replaces all existing recommended units.
#' @return Number of rows loaded, or FALSE on failure
#' @noRd
load_default_recommended_units <- function(csv_path = NULL) {
  if (is.null(csv_path) || !file.exists(csv_path)) return(FALSE)

  data <- read.csv(csv_path, stringsAsFactors = FALSE)
  if (nrow(data) == 0) return(0L)

  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(con, "DELETE FROM recommended_units")

  for (i in seq_len(nrow(data))) {
    DBI::dbExecute(
      con,
      "INSERT INTO recommended_units (concept_id, recommended_unit_concept_id, created_at)
       VALUES (?, ?, ?)",
      params = list(
        as.integer(data$concept_id[i]),
        as.integer(data$recommended_unit_concept_id[i]),
        timestamp
      )
    )
  }

  nrow(data)
}

# UNIT CONVERSIONS CRUD ====

#' Add Unit Conversion
#'
#' @description Create a new unit conversion
#' @param omop_concept_id_1 OMOP concept ID for first measurement
#' @param unit_concept_id_1 Unit concept ID for first measurement
#' @param conversion_factor Numeric conversion factor
#' @param omop_concept_id_2 OMOP concept ID for second measurement
#' @param unit_concept_id_2 Unit concept ID for second measurement
#' @return Inserted row ID, or FALSE if duplicate
#' @noRd
add_unit_conversion <- function(omop_concept_id_1, unit_concept_id_1, conversion_factor,
                                omop_concept_id_2, unit_concept_id_2) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  existing <- DBI::dbGetQuery(
    con,
    "SELECT id FROM unit_conversions
     WHERE omop_concept_id_1 = ? AND unit_concept_id_1 = ?
       AND omop_concept_id_2 = ? AND unit_concept_id_2 = ?",
    params = list(
      as.integer(omop_concept_id_1), as.integer(unit_concept_id_1),
      as.integer(omop_concept_id_2), as.integer(unit_concept_id_2)
    )
  )

  if (nrow(existing) > 0) return(FALSE)

  DBI::dbExecute(
    con,
    "INSERT INTO unit_conversions (omop_concept_id_1, unit_concept_id_1, conversion_factor,
       omop_concept_id_2, unit_concept_id_2, created_at)
     VALUES (?, ?, ?, ?, ?, ?)",
    params = list(
      as.integer(omop_concept_id_1),
      as.integer(unit_concept_id_1),
      as.numeric(conversion_factor),
      as.integer(omop_concept_id_2),
      as.integer(unit_concept_id_2),
      timestamp
    )
  )

  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")
  result$id[1]
}

#' Delete Unit Conversion
#'
#' @description Delete a unit conversion by ID
#' @param id Row ID
#' @return TRUE if successful
#' @noRd
delete_unit_conversion <- function(id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "DELETE FROM unit_conversions WHERE id = ?",
    params = list(id)
  )

  TRUE
}

#' Get All Unit Conversions
#'
#' @description Retrieve all unit conversions
#' @return Data frame with unit conversions
#' @noRd
get_all_unit_conversions <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT id, omop_concept_id_1, unit_concept_id_1, conversion_factor,
       omop_concept_id_2, unit_concept_id_2, created_at
     FROM unit_conversions
     ORDER BY omop_concept_id_1, unit_concept_id_1"
  )
}

#' Load Default Unit Conversions
#'
#' @description Load default unit conversions from bundled CSV into the database.
#'   Replaces all existing unit conversions.
#' @return Number of rows loaded, or FALSE on failure
#' @noRd
load_default_unit_conversions <- function(csv_path = NULL) {
  if (is.null(csv_path) || !file.exists(csv_path)) return(FALSE)

  data <- read.csv(csv_path, stringsAsFactors = FALSE)
  if (nrow(data) == 0) return(0L)

  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(con, "DELETE FROM unit_conversions")

  for (i in seq_len(nrow(data))) {
    DBI::dbExecute(
      con,
      "INSERT INTO unit_conversions (omop_concept_id_1, unit_concept_id_1, conversion_factor,
         omop_concept_id_2, unit_concept_id_2, created_at)
       VALUES (?, ?, ?, ?, ?, ?)",
      params = list(
        as.integer(data$omop_concept_id_1[i]),
        as.integer(data$unit_concept_id_1[i]),
        as.numeric(data$conversion_factor[i]),
        as.integer(data$omop_concept_id_2[i]),
        as.integer(data$unit_concept_id_2[i]),
        timestamp
      )
    )
  }

  nrow(data)
}

#' Update Unit Conversion Factor
#'
#' @description Update the conversion factor for an existing unit conversion
#' @param id Row ID
#' @param conversion_factor New conversion factor
#' @return TRUE if successful
#' @noRd
update_unit_conversion <- function(id, conversion_factor) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "UPDATE unit_conversions SET conversion_factor = ? WHERE id = ?",
    params = list(as.numeric(conversion_factor), id)
  )

  TRUE
}

# DATABASE CONNECTION ====

#' Get Application Directory Path
#'
#' @description Resolves the application directory path using environment variables
#' or default user home directory. Handles both development and production environments.
#' The application data is stored in ~/indicate_files/ by default.
#'
#' @param subdir Character: Subdirectory name (e.g., "concept_mapping").
#'   If NULL, returns the base application directory (indicate_files/).
#' @param create Logical: Create directory if it doesn't exist (default TRUE)
#'
#' @return Character: Full path to the application directory
#' @noRd
get_app_dir <- function(subdir = NULL, create = TRUE) {
  # Check for custom application folder in environment
  app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)

  if (is.na(app_folder) || app_folder == "") {
    # Use default: home directory with indicate_files subfolder
    base_dir <- file.path(path.expand("~"), "indicate_files")
  } else {
    # Use custom application folder
    if (basename(app_folder) == "indicate_files") {
      base_dir <- app_folder
    } else {
      base_dir <- file.path(app_folder, "indicate_files")
    }
  }

  # Append subdirectory if specified
  if (!is.null(subdir)) {
    base_dir <- file.path(base_dir, subdir)
  }

  # Create directory if requested and doesn't exist
  if (create && !dir.exists(base_dir)) {
    dir.create(base_dir, recursive = TRUE, showWarnings = FALSE)
  }

  base_dir
}

#' Get Database Connection
#'
#' @description Create or get connection to the application SQLite database
#' @return DBI connection object
#' @noRd
get_db_connection <- function() {
  db_dir <- get_app_dir()
  db_path <- file.path(db_dir, "indicate.db")

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  init_database(con)

  con
}

#' Initialize Database Tables
#'
#' @description Create necessary tables if they don't exist
#' @param con DBI connection object
#' @return NULL (invisible)
#' @noRd
init_database <- function(con) {
  # Config table
  if (!DBI::dbExistsTable(con, "config")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE config (
        key TEXT PRIMARY KEY,
        value TEXT,
        created_at TEXT,
        updated_at TEXT
      )"
    )
  }

  # Concept Sets table
  if (!DBI::dbExistsTable(con, "concept_sets")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE concept_sets (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        version TEXT DEFAULT '1.0.0',
        review_status TEXT DEFAULT 'draft',
        category TEXT,
        subcategory TEXT,
        long_description TEXT,
        tags TEXT,
        created_by_first_name TEXT,
        created_by_last_name TEXT,
        created_by_profession TEXT,
        created_by_affiliation TEXT,
        created_by_orcid TEXT,
        created_date TEXT,
        modified_by_first_name TEXT,
        modified_by_last_name TEXT,
        modified_by_profession TEXT,
        modified_by_affiliation TEXT,
        modified_by_orcid TEXT,
        modified_date TEXT
      )"
    )
  }

  # Concept set translations table
  if (!DBI::dbExistsTable(con, "concept_set_translations")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE concept_set_translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concept_set_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        field TEXT NOT NULL,
        value TEXT,
        FOREIGN KEY (concept_set_id) REFERENCES concept_sets(id) ON DELETE CASCADE,
        UNIQUE(concept_set_id, language, field)
      )"
    )
  }

  # Tags table
  if (!DBI::dbExistsTable(con, "tags")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE tags (
        tag_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT DEFAULT '#6c757d',
        created_at TEXT,
        updated_at TEXT
      )"
    )
  } else {
    # Migration: add color column if it doesn't exist
    cols <- DBI::dbGetQuery(con, "PRAGMA table_info(tags)")
    if (!("color" %in% cols$name)) {
      DBI::dbExecute(con, "ALTER TABLE tags ADD COLUMN color TEXT DEFAULT '#6c757d'")
    }
  }

  # User Accesses table
  if (!DBI::dbExistsTable(con, "user_accesses")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE user_accesses (
        user_access_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT,
        updated_at TEXT
      )"
    )

    # Insert default user accesses
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    DBI::dbExecute(
      con,
      "INSERT INTO user_accesses (name, description, created_at, updated_at) VALUES
        ('Admin', 'Full access to all features', ?, ?),
        ('Editor', 'Can edit content but not manage users', ?, ?),
        ('Read only', 'Can only view content', ?, ?)",
      params = list(timestamp, timestamp, timestamp, timestamp, timestamp, timestamp)
    )
  }

  # Users table
  if (!DBI::dbExistsTable(con, "users")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        login TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        first_name TEXT,
        last_name TEXT,
        profession TEXT,
        affiliation TEXT,
        orcid TEXT,
        user_access_id INTEGER,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (user_access_id) REFERENCES user_accesses(user_access_id)
      )"
    )

    # Insert default admin user (password: admin)
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    admin_hash <- bcrypt::hashpw("admin", bcrypt::gensalt(12))
    DBI::dbExecute(
      con,
      "INSERT INTO users (login, password_hash, first_name, last_name, profession, user_access_id, created_at, updated_at)
       VALUES ('admin', ?, 'Admin', 'User', 'Administrator', 1, ?, ?)",
      params = list(admin_hash, timestamp, timestamp)
    )
  } else {
    # Migration: rename role to profession and add orcid if needed
    cols <- DBI::dbGetQuery(con, "PRAGMA table_info(users)")
    if ("role" %in% cols$name && !("profession" %in% cols$name)) {
      # Create new table with correct schema
      DBI::dbExecute(con, "ALTER TABLE users RENAME TO users_old")
      DBI::dbExecute(
        con,
        "CREATE TABLE users (
          user_id INTEGER PRIMARY KEY AUTOINCREMENT,
          login TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          first_name TEXT,
          last_name TEXT,
          profession TEXT,
          affiliation TEXT,
          orcid TEXT,
          user_access_id INTEGER,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (user_access_id) REFERENCES user_accesses(user_access_id)
        )"
      )
      DBI::dbExecute(con, "INSERT INTO users SELECT user_id, login, password_hash, first_name, last_name, role, affiliation, NULL, user_access_id, created_at, updated_at FROM users_old")
      DBI::dbExecute(con, "DROP TABLE users_old")
    } else if (!("orcid" %in% cols$name)) {
      DBI::dbExecute(con, "ALTER TABLE users ADD COLUMN orcid TEXT")
    }
  }

  # Projects table
  if (!DBI::dbExistsTable(con, "projects")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE projects (
        project_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        justification TEXT,
        bibliography TEXT,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )"
    )
  } else {
    # Add missing columns for existing databases
    existing_cols <- DBI::dbListFields(con, "projects")
    if (!"justification" %in% existing_cols) {
      DBI::dbExecute(con, "ALTER TABLE projects ADD COLUMN justification TEXT")
    }
    if (!"bibliography" %in% existing_cols) {
      DBI::dbExecute(con, "ALTER TABLE projects ADD COLUMN bibliography TEXT")
    }
  }

  # Project-Concept Sets association table
  if (!DBI::dbExistsTable(con, "project_concept_sets")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE project_concept_sets (
        project_id INTEGER NOT NULL,
        concept_set_id INTEGER NOT NULL,
        created_at TEXT,
        PRIMARY KEY (project_id, concept_set_id),
        FOREIGN KEY (project_id) REFERENCES projects(project_id),
        FOREIGN KEY (concept_set_id) REFERENCES concept_sets(id)
      )"
    )
  }

  # Concept Set Items table (concepts in a concept set)
  if (!DBI::dbExistsTable(con, "concept_set_items")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE concept_set_items (
        concept_set_id INTEGER NOT NULL,
        concept_id INTEGER NOT NULL,
        concept_name TEXT,
        vocabulary_id TEXT,
        concept_code TEXT,
        domain_id TEXT,
        concept_class_id TEXT,
        standard_concept TEXT,
        is_excluded INTEGER DEFAULT 0,
        include_descendants INTEGER DEFAULT 1,
        include_mapped INTEGER DEFAULT 1,
        created_at TEXT,
        PRIMARY KEY (concept_set_id, concept_id),
        FOREIGN KEY (concept_set_id) REFERENCES concept_sets(id)
      )"
    )
  } else {
    # Add missing columns to existing table (migration)
    existing_cols <- DBI::dbGetQuery(con, "PRAGMA table_info(concept_set_items)")$name
    if (!"domain_id" %in% existing_cols) {
      DBI::dbExecute(con, "ALTER TABLE concept_set_items ADD COLUMN domain_id TEXT")
    }
    if (!"concept_class_id" %in% existing_cols) {
      DBI::dbExecute(con, "ALTER TABLE concept_set_items ADD COLUMN concept_class_id TEXT")
    }
  }

  # Concept Set Reviews table
  if (!DBI::dbExistsTable(con, "concept_set_reviews")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE concept_set_reviews (
        review_id INTEGER PRIMARY KEY AUTOINCREMENT,
        concept_set_id INTEGER NOT NULL,
        concept_set_version TEXT,
        reviewer_user_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        comments TEXT,
        review_date TEXT,
        FOREIGN KEY (concept_set_id) REFERENCES concept_sets(id),
        FOREIGN KEY (reviewer_user_id) REFERENCES users(user_id)
      )"
    )
  }

  # Concept Set Changelog table
  if (!DBI::dbExistsTable(con, "concept_set_changelog")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE concept_set_changelog (
        change_id INTEGER PRIMARY KEY AUTOINCREMENT,
        concept_set_id INTEGER NOT NULL,
        version_from TEXT,
        version_to TEXT,
        changed_by_user_id INTEGER,
        change_date TEXT,
        change_type TEXT,
        change_summary TEXT,
        changes_json TEXT,
        FOREIGN KEY (concept_set_id) REFERENCES concept_sets(id),
        FOREIGN KEY (changed_by_user_id) REFERENCES users(user_id)
      )"
    )
  }

  # Concept Set Stats table
  if (!DBI::dbExistsTable(con, "concept_set_stats")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE concept_set_stats (
        concept_set_id INTEGER PRIMARY KEY,
        stats TEXT,
        updated_at TEXT,
        FOREIGN KEY (concept_set_id) REFERENCES concept_sets(id)
      )"
    )
  }

  # Recommended Units table
  if (!DBI::dbExistsTable(con, "recommended_units")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE recommended_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concept_id INTEGER NOT NULL,
        recommended_unit_concept_id INTEGER NOT NULL,
        created_at TEXT,
        UNIQUE(concept_id, recommended_unit_concept_id)
      )"
    )

    # Auto-migrate from CSV if it exists
    app_dir <- get_app_dir(create = FALSE)
    if (!is.null(app_dir)) {
      csv_path <- file.path(app_dir, "recommended_units.csv")
      if (file.exists(csv_path)) {
        data <- read.csv(csv_path, stringsAsFactors = FALSE)
        timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        for (i in seq_len(nrow(data))) {
          DBI::dbExecute(
            con,
            "INSERT OR IGNORE INTO recommended_units (concept_id, recommended_unit_concept_id, created_at)
             VALUES (?, ?, ?)",
            params = list(
              as.integer(data$concept_id[i]),
              as.integer(data$recommended_unit_concept_id[i]),
              timestamp
            )
          )
        }
      }
    }
  }

  # Unit Conversions table
  if (!DBI::dbExistsTable(con, "unit_conversions")) {
    DBI::dbExecute(
      con,
      "CREATE TABLE unit_conversions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        omop_concept_id_1 INTEGER NOT NULL,
        unit_concept_id_1 INTEGER NOT NULL,
        conversion_factor REAL NOT NULL,
        omop_concept_id_2 INTEGER NOT NULL,
        unit_concept_id_2 INTEGER NOT NULL,
        created_at TEXT,
        UNIQUE(omop_concept_id_1, unit_concept_id_1, omop_concept_id_2, unit_concept_id_2)
      )"
    )

    # Auto-migrate from CSV if it exists
    app_dir <- get_app_dir(create = FALSE)
    if (!is.null(app_dir)) {
      csv_path <- file.path(app_dir, "unit_conversions.csv")
      if (file.exists(csv_path)) {
        data <- read.csv(csv_path, stringsAsFactors = FALSE)
        timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        for (i in seq_len(nrow(data))) {
          DBI::dbExecute(
            con,
            "INSERT OR IGNORE INTO unit_conversions (omop_concept_id_1, unit_concept_id_1,
               conversion_factor, omop_concept_id_2, unit_concept_id_2, created_at)
             VALUES (?, ?, ?, ?, ?, ?)",
            params = list(
              as.integer(data$omop_concept_id_1[i]),
              as.integer(data$unit_concept_id_1[i]),
              as.numeric(data$conversion_factor[i]),
              as.integer(data$omop_concept_id_2[i]),
              as.integer(data$unit_concept_id_2[i]),
              timestamp
            )
          )
        }
      }
    }
  }

  invisible(NULL)
}


#' Get All Translations for a Concept Set
#'
#' @description Retrieves all translations for a given concept set
#'
#' @param concept_set_id Concept set ID
#' @return Data frame with translations or NULL
#' @noRd
get_all_concept_set_translations <- function(concept_set_id) {
  tryCatch({
    con <- get_db_connection()
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    translations <- DBI::dbGetQuery(
      con,
      "SELECT language, field, value FROM concept_set_translations WHERE concept_set_id = ?",
      params = list(concept_set_id)
    )

    if (nrow(translations) == 0) return(NULL)
    translations
  }, error = function(e) {
    message("Error getting translations: ", e$message)
    NULL
  })
}


#' Get Concept Set Translation for Specific Language and Field
#'
#' @description Retrieves a specific translation value
#'
#' @param concept_set_id Concept set ID
#' @param language Language code (e.g., 'en', 'fr')
#' @param field Field name (e.g., 'name', 'description', 'category', 'subcategory', 'long_description')
#' @return Translation value or NULL
#' @noRd
get_concept_set_translation <- function(concept_set_id, language, field) {
  tryCatch({
    con <- get_db_connection()
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    result <- DBI::dbGetQuery(
      con,
      "SELECT value FROM concept_set_translations WHERE concept_set_id = ? AND language = ? AND field = ?",
      params = list(concept_set_id, language, field)
    )

    if (nrow(result) == 0) return(NULL)
    result$value[1]
  }, error = function(e) {
    message("Error getting translation: ", e$message)
    NULL
  })
}


#' Set Concept Set Translation
#'
#' @description Sets or updates a translation value
#'
#' @param concept_set_id Concept set ID
#' @param language Language code (e.g., 'en', 'fr')
#' @param field Field name (e.g., 'name', 'description', 'category', 'subcategory', 'long_description')
#' @param value Translation value
#' @return TRUE on success, FALSE on failure
#' @noRd
set_concept_set_translation <- function(concept_set_id, language, field, value) {
  tryCatch({
    con <- get_db_connection()
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    # Convert NULL to NA for RSQLite compatibility
    value <- if (is.null(value) || length(value) == 0) NA_character_ else value

    # Use INSERT OR REPLACE for upsert functionality
    DBI::dbExecute(
      con,
      "INSERT OR REPLACE INTO concept_set_translations (concept_set_id, language, field, value)
       VALUES (?, ?, ?, ?)",
      params = list(concept_set_id, language, field, value)
    )

    TRUE
  }, error = function(e) {
    message("Error setting translation: ", e$message)
    FALSE
  })
}
