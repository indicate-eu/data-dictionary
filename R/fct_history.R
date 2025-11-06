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
#' @param general_concept_id Integer: ID of the general concept (required for mapped_concept)
#' @param omop_concept_id Integer: ID of the OMOP concept (optional, for mapped_concept)
#' @param custom_concept_id Integer: ID of the custom concept (optional, for mapped_concept)
#' @param username String with user's first and last name
#' @param action_type Character: "insert", "update", or "delete"
#' @param comment Character: Description of the change
#'
#' @return Invisible TRUE on success
#'
#' @importFrom readr read_csv write_csv cols col_integer col_character
#' @importFrom dplyr bind_rows
#' @noRd
log_history_change <- function(
  entity_type,
  general_concept_id,
  username,
  action_type,
  omop_concept_id = NA_integer_,
  custom_concept_id = NA_integer_,
  comment = NA_character_
) {
  # DEBUG
  message(sprintf("[HISTORY DEBUG] log_history_change called: entity_type=%s, general_concept_id=%s, username=%s, action=%s",
                  entity_type, general_concept_id, username, action_type))

  # Determine history file based on entity type
  history_file <- switch(
    entity_type,
    "general_concept" = get_csv_path("general_concepts_history.csv"),
    "mapped_concept" = get_csv_path("general_concepts_details_history.csv"),
    stop("Invalid entity_type. Must be 'general_concept' or 'mapped_concept'")
  )

  # DEBUG
  message(sprintf("[HISTORY DEBUG] History file path: %s", history_file))
  message(sprintf("[HISTORY DEBUG] File exists: %s, File size: %s",
                  file.exists(history_file),
                  if(file.exists(history_file)) file.size(history_file) else "N/A"))

  # Load existing history
  if (file.exists(history_file) && file.size(history_file) > 0) {
    if (entity_type == "general_concept") {
      col_spec <- cols(
        history_id = col_integer(),
        timestamp = col_character(),
        username = col_character(),
        action_type = col_character(),
        general_concept_id = col_integer(),
        comment = col_character()
      )
    } else {
      col_spec <- cols(
        history_id = col_integer(),
        timestamp = col_character(),
        username = col_character(),
        action_type = col_character(),
        general_concept_id = col_integer(),
        custom_concept_id = col_integer(),
        omop_concept_id = col_integer(),
        comment = col_character()
      )
    }

    history <- read_csv(history_file, col_types = col_spec, show_col_types = FALSE)
    message(sprintf("[HISTORY DEBUG] Loaded existing history with %d rows", nrow(history)))
  } else {
    # Create empty history data frame
    if (entity_type == "general_concept") {
      history <- data.frame(
        history_id = integer(),
        timestamp = character(),
        username = character(),
        action_type = character(),
        general_concept_id = integer(),
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
        custom_concept_id = integer(),
        omop_concept_id = integer(),
        comment = character(),
        stringsAsFactors = FALSE
      )
    }
    message("[HISTORY DEBUG] Created new empty history dataframe")
  }

  # Generate new history ID
  new_history_id <- if (nrow(history) == 0) 1 else max(history$history_id, na.rm = TRUE) + 1
  message(sprintf("[HISTORY DEBUG] New history ID: %d", new_history_id))

  # Create new entry
  if (entity_type == "general_concept") {
    new_entry <- data.frame(
      history_id = new_history_id,
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      username = as.character(username),
      action_type = as.character(action_type),
      general_concept_id = as.integer(general_concept_id),
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
      custom_concept_id = as.integer(custom_concept_id),
      omop_concept_id = as.integer(omop_concept_id),
      comment = as.character(comment),
      stringsAsFactors = FALSE
    )
  }

  message(sprintf("[HISTORY DEBUG] New entry created: %s", paste(names(new_entry), collapse=", ")))

  # Append and save
  history <- bind_rows(history, new_entry)
  message(sprintf("[HISTORY DEBUG] About to write %d rows to %s", nrow(history), history_file))

  write_csv(history, history_file)

  message(sprintf("[HISTORY DEBUG] File written. New file size: %d", file.size(history_file)))

  invisible(TRUE)
}

#' Get History
#'
#' @description Generic function to retrieve history
#'
#' @param entity_type Character: "general_concept" or "mapped_concept"
#' @param general_concept_id Optional integer: ID of general concept to filter by
#'
#' @return Data frame with history entries
#'
#' @importFrom readr read_csv cols col_integer col_character
#' @importFrom dplyr filter arrange desc
#' @noRd
get_history <- function(entity_type, general_concept_id = NULL) {
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
        general_concept_id = integer(),
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
        custom_concept_id = integer(),
        omop_concept_id = integer(),
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
      general_concept_id = col_integer(),
      comment = col_character()
    )
  } else {
    col_spec <- cols(
      history_id = col_integer(),
      timestamp = col_character(),
      username = col_character(),
      action_type = col_character(),
      general_concept_id = col_integer(),
      custom_concept_id = col_integer(),
      omop_concept_id = col_integer(),
      comment = col_character()
    )
  }

  history <- read_csv(history_file, col_types = col_spec, show_col_types = FALSE)

  # Filter by general_concept_id if provided
  if (!is.null(general_concept_id)) {
    history <- history %>% filter(general_concept_id == !!general_concept_id)
  }

  # Sort by timestamp descending (most recent first)
  history <- history %>% arrange(desc(timestamp))

  return(history)
}
