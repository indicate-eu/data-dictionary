#' History Logging Functions
#'
#' @description Functions to log changes to concepts and mappings
#'
#' @noRd

#' Log Change to History
#'
#' @description Generic function to log changes
#'
#' @param entity_type Character: "general_concept" or "mapped_concept"
#' @param username String with user's first and last name
#' @param action_type Character: "insert", "update", "delete", "recommend", or "unrecommend"
#' @param comment Character: Description of the change
#' @param category Character: Category (for general_concept)
#' @param subcategory Character: Subcategory (for general_concept)
#' @param general_concept_name Character: General concept name (for general_concept)
#' @param general_concept_id Integer: General concept ID (for mapped_concept)
#' @param vocabulary_id Character: Vocabulary ID (for mapped_concept)
#' @param concept_code Character: Concept code (for mapped_concept)
#' @param concept_name Character: Concept name (for mapped_concept)
#'
#' @return Invisible TRUE on success
#'
#' @importFrom readr read_csv write_csv cols col_integer col_character
#' @importFrom dplyr bind_rows
#' @noRd
log_history_change <- function(
  entity_type,
  username,
  action_type,
  comment = NA_character_,
  category = NA_character_,
  subcategory = NA_character_,
  general_concept_name = NA_character_,
  general_concept_id = NA_integer_,
  vocabulary_id = NA_character_,
  concept_code = NA_character_,
  concept_name = NA_character_
) {
  # Determine history file based on entity type
  history_file <- switch(
    entity_type,
    "general_concept" = get_csv_path("general_concepts_history.csv"),
    "mapped_concept" = get_csv_path("general_concepts_details_history.csv"),
    stop("Invalid entity_type. Must be 'general_concept' or 'mapped_concept'")
  )

  # Load existing history
  if (file.exists(history_file) && file.size(history_file) > 0) {
    if (entity_type == "general_concept") {
      col_spec <- cols(
        history_id = col_integer(),
        timestamp = col_character(),
        username = col_character(),
        action_type = col_character(),
        category = col_character(),
        subcategory = col_character(),
        general_concept_name = col_character(),
        comment = col_character()
      )
    } else {
      col_spec <- cols(
        history_id = col_integer(),
        timestamp = col_character(),
        username = col_character(),
        action_type = col_character(),
        general_concept_id = col_integer(),
        vocabulary_id = col_character(),
        concept_code = col_character(),
        concept_name = col_character(),
        comment = col_character()
      )
    }

    history <- read_csv(history_file, col_types = col_spec, show_col_types = FALSE)
  } else {
    # Create empty history data frame
    if (entity_type == "general_concept") {
      history <- data.frame(
        history_id = integer(),
        timestamp = character(),
        username = character(),
        action_type = character(),
        category = character(),
        subcategory = character(),
        general_concept_name = character(),
        comment = character(),
        stringsAsFactors = FALSE
      )
    } else {
      history <- data.frame(
        history_id = integer(),
        timestamp = character(),
        username = character(),
        action_type = character(),
        general_concept_id = integer(),
        vocabulary_id = character(),
        concept_code = character(),
        concept_name = character(),
        comment = character(),
        stringsAsFactors = FALSE
      )
    }
  }

  # Generate new history ID
  new_history_id <- if (nrow(history) == 0) 1 else max(history$history_id, na.rm = TRUE) + 1

  # Create new entry
  if (entity_type == "general_concept") {
    new_entry <- data.frame(
      history_id = new_history_id,
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      username = as.character(username),
      action_type = as.character(action_type),
      category = as.character(category),
      subcategory = as.character(subcategory),
      general_concept_name = as.character(general_concept_name),
      comment = as.character(comment),
      stringsAsFactors = FALSE
    )
  } else {
    new_entry <- data.frame(
      history_id = new_history_id,
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      username = as.character(username),
      action_type = as.character(action_type),
      general_concept_id = as.integer(general_concept_id),
      vocabulary_id = as.character(vocabulary_id),
      concept_code = as.character(concept_code),
      concept_name = as.character(concept_name),
      comment = as.character(comment),
      stringsAsFactors = FALSE
    )
  }

  # Append and save
  history <- bind_rows(history, new_entry)
  write_csv(history, history_file)

  invisible(TRUE)
}

#' Get History
#'
#' @description Generic function to retrieve history
#'
#' @param entity_type Character: "general_concept" or "mapped_concept"
#'
#' @return Data frame with history entries
#'
#' @importFrom readr read_csv cols col_integer col_character
#' @importFrom dplyr filter arrange desc
#' @noRd
get_history <- function(entity_type) {
  # Determine history file based on entity type
  history_file <- switch(
    entity_type,
    "general_concept" = get_csv_path("general_concepts_history.csv"),
    "mapped_concept" = get_csv_path("general_concepts_details_history.csv"),
    stop("Invalid entity_type. Must be 'general_concept' or 'mapped_concept'")
  )

  # Return empty data frame if file doesn't exist
  if (!file.exists(history_file) || file.size(history_file) == 0) {
    if (entity_type == "general_concept") {
      return(data.frame(
        history_id = integer(),
        timestamp = character(),
        username = character(),
        action_type = character(),
        category = character(),
        subcategory = character(),
        general_concept_name = character(),
        comment = character(),
        stringsAsFactors = FALSE
      ))
    } else {
      return(data.frame(
        history_id = integer(),
        timestamp = character(),
        username = character(),
        action_type = character(),
        general_concept_id = integer(),
        vocabulary_id = character(),
        concept_code = character(),
        concept_name = character(),
        comment = character(),
        stringsAsFactors = FALSE
      ))
    }
  }

  # Read history file
  if (entity_type == "general_concept") {
    col_spec <- cols(
      history_id = col_integer(),
      timestamp = col_character(),
      username = col_character(),
      action_type = col_character(),
      category = col_character(),
      subcategory = col_character(),
      general_concept_name = col_character(),
      comment = col_character()
    )
  } else {
    col_spec <- cols(
      history_id = col_integer(),
      timestamp = col_character(),
      username = col_character(),
      action_type = col_character(),
      general_concept_id = col_integer(),
      vocabulary_id = col_character(),
      concept_code = col_character(),
      concept_name = col_character(),
      comment = col_character()
    )
  }

  history <- read_csv(history_file, col_types = col_spec, show_col_types = FALSE)

  # Sort by timestamp descending (most recent first)
  history <- history %>% arrange(desc(timestamp))

  return(history)
}

#' Delete History Entry
#'
#' @description Delete a history entry by history_id
#'
#' @param entity_type Character: "general_concept" or "mapped_concept"
#' @param history_id Integer: The history_id to delete
#'
#' @return Invisible TRUE on success, FALSE if entry not found
#'
#' @importFrom readr read_csv write_csv cols col_integer col_character
#' @importFrom dplyr filter
#' @noRd
delete_history_entry <- function(entity_type, history_id) {
  # Determine history file based on entity type
  history_file <- switch(
    entity_type,
    "general_concept" = get_csv_path("general_concepts_history.csv"),
    "mapped_concept" = get_csv_path("general_concepts_details_history.csv"),
    stop("Invalid entity_type. Must be 'general_concept' or 'mapped_concept'")
  )

  # Return FALSE if file doesn't exist
  if (!file.exists(history_file) || file.size(history_file) == 0) {
    return(invisible(FALSE))
  }

  # Read history file
  if (entity_type == "general_concept") {
    col_spec <- cols(
      history_id = col_integer(),
      timestamp = col_character(),
      username = col_character(),
      action_type = col_character(),
      category = col_character(),
      subcategory = col_character(),
      general_concept_name = col_character(),
      comment = col_character()
    )
  } else {
    col_spec <- cols(
      history_id = col_integer(),
      timestamp = col_character(),
      username = col_character(),
      action_type = col_character(),
      general_concept_id = col_integer(),
      vocabulary_id = col_character(),
      concept_code = col_character(),
      concept_name = col_character(),
      comment = col_character()
    )
  }

  history <- read_csv(history_file, col_types = col_spec, show_col_types = FALSE)

  # Check if entry exists
  if (!history_id %in% history$history_id) {
    return(invisible(FALSE))
  }

  # Remove entry with matching history_id
  history <- history %>% filter(history_id != !!history_id)

  # Save updated history
  write_csv(history, history_file)

  return(invisible(TRUE))
}
