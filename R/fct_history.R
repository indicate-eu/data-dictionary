#' History Logging Functions
#'
#' @description Functions to log changes to general concepts and concept mappings
#'
#' @noRd

#' Log General Concept Change
#'
#' @description Records a change to a general concept in the history file
#'
#' @param username String with user's first and last name (e.g., "Boris Delange")
#' @param action_type Character: "insert", "update", or "delete"
#' @param general_concept_id Integer: ID of the general concept
#' @param comment Character: Description of the change
#'
#' @return Invisible TRUE on success
#'
#' @importFrom readr read_csv write_csv cols col_integer col_character
#' @importFrom dplyr bind_rows
log_general_concept_change <- function(
  username,
  action_type,
  general_concept_id,
  comment = NA_character_
) {
  history_file <- get_csv_path("general_concepts_history.csv")

  # Load existing history
  if (file.exists(history_file) && file.size(history_file) > 0) {
    history <- read_csv(
      history_file,
      col_types = cols(
        history_id = col_integer(),
        timestamp = col_character(),
        username = col_character(),
        action_type = col_character(),
        general_concept_id = col_integer(),
        comment = col_character()
      ),
      show_col_types = FALSE
    )
  } else {
    history <- data.frame(
      history_id = integer(),
      timestamp = character(),
      username = character(),
      action_type = character(),
      general_concept_id = integer(),
      comment = character(),
      stringsAsFactors = FALSE
    )
  }

  # Generate new history ID
  new_history_id <- if (nrow(history) == 0) 1 else max(history$history_id, na.rm = TRUE) + 1

  # Create new entry
  new_entry <- data.frame(
    history_id = new_history_id,
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    username = as.character(username),
    action_type = as.character(action_type),
    general_concept_id = as.integer(general_concept_id),
    comment = as.character(comment),
    stringsAsFactors = FALSE
  )

  # Append and save
  history <- bind_rows(history, new_entry)
  write_csv(history, history_file)

  invisible(TRUE)
}

#' Log Concept Mapping Change
#'
#' @description Records a change to a concept mapping in the history file
#'
#' @param username String with user's first and last name (e.g., "Boris Delange")
#' @param action_type Character: "insert", "update", or "delete"
#' @param mapping_id Integer: ID of the concept mapping
#' @param comment Character: Description of the change
#'
#' @return Invisible TRUE on success
#'
#' @importFrom readr read_csv write_csv cols col_integer col_character
#' @importFrom dplyr bind_rows
log_concept_mapping_change <- function(
  username,
  action_type,
  mapping_id,
  comment = NA_character_
) {
  history_file <- get_csv_path("concept_mappings_history.csv")

  # Load existing history
  if (file.exists(history_file) && file.size(history_file) > 0) {
    history <- read_csv(
      history_file,
      col_types = cols(
        history_id = col_integer(),
        timestamp = col_character(),
        username = col_character(),
        action_type = col_character(),
        mapping_id = col_integer(),
        comment = col_character()
      ),
      show_col_types = FALSE
    )
  } else {
    history <- data.frame(
      history_id = integer(),
      timestamp = character(),
      username = character(),
      action_type = character(),
      mapping_id = integer(),
      comment = character(),
      stringsAsFactors = FALSE
    )
  }

  # Generate new history ID
  new_history_id <- if (nrow(history) == 0) 1 else max(history$history_id, na.rm = TRUE) + 1

  # Create new entry
  new_entry <- data.frame(
    history_id = new_history_id,
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    username = as.character(username),
    action_type = as.character(action_type),
    mapping_id = as.integer(mapping_id),
    comment = as.character(comment),
    stringsAsFactors = FALSE
  )

  # Append and save
  history <- bind_rows(history, new_entry)
  write_csv(history, history_file)

  invisible(TRUE)
}

#' Get General Concept History
#'
#' @description Retrieves the history for all general concepts or a specific concept
#'
#' @param general_concept_id Optional integer: ID of specific concept to filter by
#'
#' @return Data frame with history entries
#'
#' @importFrom readr read_csv cols col_integer col_character
#' @importFrom dplyr filter arrange desc
get_general_concept_history <- function(general_concept_id = NULL) {
  history_file <- get_csv_path("general_concepts_history.csv")

  if (!file.exists(history_file) || file.size(history_file) == 0) {
    return(data.frame(
      history_id = integer(),
      timestamp = character(),
      username = character(),
      action_type = character(),
      general_concept_id = integer(),
      comment = character(),
      stringsAsFactors = FALSE
    ))
  }

  history <- read_csv(
    history_file,
    col_types = cols(
      history_id = col_integer(),
      timestamp = col_character(),
      username = col_character(),
      action_type = col_character(),
      general_concept_id = col_integer(),
      comment = col_character()
    ),
    show_col_types = FALSE
  )

  # Filter by general_concept_id if provided
  if (!is.null(general_concept_id)) {
    history <- history %>% filter(general_concept_id == !!general_concept_id)
  }

  # Sort by timestamp descending (most recent first)
  history <- history %>% arrange(desc(timestamp))

  return(history)
}

#' Get Concept Mapping History
#'
#' @description Retrieves the history for all concept mappings or a specific mapping
#'
#' @param mapping_id Optional integer: ID of specific mapping to filter by
#'
#' @return Data frame with history entries
#'
#' @importFrom readr read_csv cols col_integer col_character
#' @importFrom dplyr filter arrange desc
get_concept_mapping_history <- function(mapping_id = NULL) {
  history_file <- get_csv_path("concept_mappings_history.csv")

  if (!file.exists(history_file) || file.size(history_file) == 0) {
    return(data.frame(
      history_id = integer(),
      timestamp = character(),
      username = character(),
      action_type = character(),
      mapping_id = integer(),
      comment = character(),
      stringsAsFactors = FALSE
    ))
  }

  history <- read_csv(
    history_file,
    col_types = cols(
      history_id = col_integer(),
      timestamp = col_character(),
      username = col_character(),
      action_type = col_character(),
      mapping_id = col_integer(),
      comment = col_character()
    ),
    show_col_types = FALSE
  )

  # Filter by mapping_id if provided
  if (!is.null(mapping_id)) {
    history <- history %>% filter(mapping_id == !!mapping_id)
  }

  # Sort by timestamp descending (most recent first)
  history <- history %>% arrange(desc(timestamp))

  return(history)
}
