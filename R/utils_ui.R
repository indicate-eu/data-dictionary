#' UI Helper Functions
#'
#' @description Reusable UI utility functions for building interface elements
#' across modules
#' @noRd

#' Create a detail item for displaying concept information
#'
#' @description Creates a formatted HTML div element to display a label-value
#' pair in concept detail views. Supports various display modes including
#' editable numeric inputs, formatted numbers, links, and colored text.
#'
#' @param label Character string for the field label (displayed in bold)
#' @param value The value to display (supports various types: character, numeric, logical)
#' @param format_number Logical; if TRUE, formats numeric values with thousand separators
#' @param url Character; if provided, wraps the value in a link with this URL
#' @param color Character; if provided (e.g., "#28a745"), displays value in this color
#' @param editable Logical; if TRUE and is_editing is TRUE, shows an input field
#' @param input_id Character; Shiny input ID for editable inputs (must be namespaced)
#' @param input_type Character; type of input ("numeric" or "text", default: "numeric")
#' @param step Numeric; step size for numeric inputs (default: 1)
#' @param is_editing Logical; whether the UI is in edit mode (required for editable inputs)
#' @param ns Namespace function from module (required for editable inputs)
#' @param include_colon Logical; if TRUE, adds colon after label (default: TRUE)
#'
#' @return A shiny.tag div element with class "detail-item"
#'
#' @details
#' Value handling:
#' - NULL, NA, empty string: displayed as "/"
#' - Logical: TRUE -> "Yes", FALSE -> "No"
#' - Numeric with format_number=TRUE: formatted with commas
#' - Links take precedence over color formatting
#' - Editable inputs only shown when editable=TRUE AND is_editing=TRUE
#'
#' @examples
#' \dontrun{
#' # Simple label-value pair
#' create_detail_item("Category", "Demographics")
#'
#' # With formatted number
#' create_detail_item("Count", 1234567, format_number = TRUE)
#'
#' # With link
#' create_detail_item("Code", "123456", url = "https://athena.ohdsi.org/search-terms/terms/123456")
#'
#' # With color
#' create_detail_item("Status", "Valid", color = "#28a745")
#'
#' # Editable numeric input
#' create_detail_item("Priority", 5, editable = TRUE, input_id = "priority_input",
#'                   is_editing = TRUE, ns = ns)
#' }
#'
#' @noRd
create_detail_item <- function(label, value,
                               format_number = FALSE,
                               url = NULL,
                               color = NULL,
                               editable = FALSE,
                               input_id = NULL,
                               input_type = "numeric",
                               step = 1,
                               is_editing = FALSE,
                               ns = NULL,
                               include_colon = TRUE) {
  # If editable and in edit mode, show input field
  if (editable && is_editing && !is.null(input_id) && !is.null(ns)) {
    label_text <- if (include_colon) paste0(label, ":") else label

    if (input_type == "text") {
      # Text input
      input_value <- if (is.null(value)) {
        ""
      } else if (length(value) == 0) {
        ""
      } else if (length(value) == 1 && is.na(value)) {
        ""
      } else if (identical(value, "/")) {
        ""
      } else {
        as.character(value)
      }

      return(tags$div(
        class = "detail-item",
        tags$strong(label_text),
        tags$span(
          shiny::textInput(
            ns(input_id),
            label = NULL,
            value = input_value,
            width = "200px"
          )
        )
      ))
    } else {
      # Numeric input
      input_value <- if (is.null(value)) {
        NA
      } else if (length(value) == 0) {
        NA
      } else if (length(value) == 1 && is.na(value)) {
        NA
      } else if (identical(value, "")) {
        NA
      } else if (is.character(value)) {
        suppressWarnings(as.numeric(value))
      } else {
        as.numeric(value)
      }

      return(tags$div(
        class = "detail-item",
        tags$strong(label_text),
        tags$span(
          shiny::numericInput(
            ns(input_id),
            label = NULL,
            value = input_value,
            width = "100px",
            step = step
          )
        )
      ))
    }
  }

  # Otherwise, display as read-only
  display_value <- if (is.null(value)) {
    "/"
  } else if (length(value) == 0) {
    "/"
  } else if (length(value) == 1 && is.na(value)) {
    "/"
  } else if (identical(value, "")) {
    "/"
  } else if (is.logical(value)) {
    if (isTRUE(value)) "Yes" else if (isFALSE(value)) "No" else "/"
  } else if (format_number && is.numeric(value)) {
    format(value, big.mark = ",", scientific = FALSE)
  } else {
    as.character(value)
  }

  # Create link if URL provided (takes precedence over color)
  if (!is.null(url) && display_value != "/") {
    display_value <- tags$a(
      href = url,
      target = "_blank",
      style = "color: #0f60af; text-decoration: underline;",
      display_value
    )
  } else if (!is.null(color) && display_value != "/") {
    # Apply color if specified
    display_value <- tags$span(
      style = paste0("color: ", color, "; font-weight: 600;"),
      display_value
    )
  }

  label_text <- if (include_colon) paste0(label, ":") else label

  tags$div(
    class = "detail-item",
    tags$strong(label_text),
    tags$span(display_value)
  )
}

#' Get Default Statistical Summary JSON Template
#'
#' @description Returns the default JSON structure for statistical summary
#' @return Character string containing default JSON template
#' @noRd
get_default_statistical_summary_template <- function() {
  '{
  "profiles": [
    {
      "name_en": "All patients",
      "name_fr": "Tous les patients",
      "description_en": "Default profile for all patients",
      "description_fr": "Profil par defaut pour tous les patients",
      "data_types": [],
      "numeric_data": {
        "min": null,
        "max": null,
        "mean": null,
        "median": null,
        "sd": null,
        "cv": null,
        "p5": null,
        "p25": null,
        "p75": null,
        "p95": null
      },
      "histogram": [],
      "categorical_data": [],
      "measurement_frequency": {
        "typical_interval": null
      }
    }
  ],
  "default_profile_en": "All patients",
  "default_profile_fr": "Tous les patients"
}'
}

#' Get Profile Names from Statistical Summary JSON
#'
#' @description Extracts profile names from JSON data. Supports multilingual format
#' (name_en, name_fr), legacy format (name), and format without profiles.
#' @param json_data Parsed JSON data (list)
#' @param language Character: Language code ("en" or "fr"). Defaults to
#'   INDICATE_LANGUAGE environment variable or "en".
#' @return Character vector of profile names
#' @noRd
get_profile_names <- function(json_data, language = NULL) {
  if (is.null(language)) {
    language <- Sys.getenv("INDICATE_LANGUAGE", "en")
  }
  if (!language %in% c("en", "fr")) language <- "en"

  default_name <- if (language == "fr") "Tous les patients" else "All patients"
  name_field <- paste0("name_", language)

  if (is.null(json_data)) return(c(default_name))

  # New format with profiles
  if (!is.null(json_data$profiles) && length(json_data$profiles) > 0) {
    profiles <- json_data$profiles

    # If profiles is a data.frame (jsonlite behavior with arrays of objects)
    if (is.data.frame(profiles)) {
      # Try multilingual field first, then legacy field
      if (name_field %in% names(profiles)) {
        return(profiles[[name_field]])
      } else if ("name" %in% names(profiles)) {
        return(profiles$name)
      }
      return(c(default_name))
    }

    # If profiles is a list of lists
    if (is.list(profiles)) {
      return(sapply(profiles, function(p) {
        if (is.list(p)) {
          # Try multilingual field first, then legacy field
          if (!is.null(p[[name_field]])) {
            return(p[[name_field]])
          } else if (!is.null(p$name)) {
            return(p$name)
          }
        }
        return("Unknown")
      }))
    }
  }

  # Legacy format without profiles
  return(c(default_name))
}

#' Get Profile Data from Statistical Summary JSON
#'
#' @description Extracts data for a specific profile. Supports multilingual format
#' (name_en, name_fr), legacy format (name), and format without profiles.
#' @param json_data Parsed JSON data (list)
#' @param profile_name Name of the profile to extract (default: NULL uses default_profile or first)
#' @param language Character: Language code ("en" or "fr"). Defaults to
#'   INDICATE_LANGUAGE environment variable or "en".
#' @return List containing profile data (numeric_data, histogram, categorical_data, etc.)
#' @noRd
get_profile_data <- function(json_data, profile_name = NULL, language = NULL) {
  if (is.null(json_data)) return(NULL)

  if (is.null(language)) {
    language <- Sys.getenv("INDICATE_LANGUAGE", "en")
  }
  if (!language %in% c("en", "fr")) language <- "en"

  name_field <- paste0("name_", language)
  default_profile_field <- paste0("default_profile_", language)

  # New format with profiles
  if (!is.null(json_data$profiles) && length(json_data$profiles) > 0) {
    profiles <- json_data$profiles

    # Determine default profile name (try multilingual then legacy)
    if (is.null(profile_name) || profile_name == "") {
      profile_name <- json_data[[default_profile_field]]
      if (is.null(profile_name)) {
        profile_name <- json_data$default_profile
      }
    }

    # If profiles is a data.frame (jsonlite behavior with arrays of objects)
    if (is.data.frame(profiles)) {
      # Find the row matching the profile name (check multilingual then legacy)
      if (!is.null(profile_name)) {
        if (name_field %in% names(profiles)) {
          idx <- which(profiles[[name_field]] == profile_name)
          if (length(idx) > 0) {
            return(as.list(profiles[idx[1], ]))
          }
        }
        if ("name" %in% names(profiles)) {
          idx <- which(profiles$name == profile_name)
          if (length(idx) > 0) {
            return(as.list(profiles[idx[1], ]))
          }
        }
      }
      # Fallback to first row
      return(as.list(profiles[1, ]))
    }

    # If profiles is a list of lists
    if (is.list(profiles)) {
      # Set default profile name if not specified
      if (is.null(profile_name)) {
        first_profile <- profiles[[1]]
        profile_name <- first_profile[[name_field]]
        if (is.null(profile_name)) {
          profile_name <- first_profile$name
        }
      }

      # Find the matching profile (check multilingual then legacy)
      for (profile in profiles) {
        if (is.list(profile)) {
          profile_match_name <- profile[[name_field]]
          if (is.null(profile_match_name)) {
            profile_match_name <- profile$name
          }
          if (!is.null(profile_match_name) && profile_match_name == profile_name) {
            return(profile)
          }
        }
      }

      # Fallback to first profile
      return(profiles[[1]])
    }
  }

  # Legacy format without profiles - return data directly
  return(json_data)
}

#' Get Default Profile Name from Statistical Summary JSON
#'
#' @description Gets the default profile name from JSON data, supporting multilingual format.
#' @param json_data Parsed JSON data (list)
#' @param language Character: Language code ("en" or "fr"). Defaults to
#'   INDICATE_LANGUAGE environment variable or "en".
#' @return Character: Default profile name, or first profile name, or localized "All patients"
#' @noRd
get_default_profile_name <- function(json_data, language = NULL) {
  if (is.null(language)) {
    language <- Sys.getenv("INDICATE_LANGUAGE", "en")
  }
  if (!language %in% c("en", "fr")) language <- "en"

  default_name <- if (language == "fr") "Tous les patients" else "All patients"
  default_profile_field <- paste0("default_profile_", language)

  if (is.null(json_data)) return(default_name)

  # Try multilingual field first
  if (!is.null(json_data[[default_profile_field]])) {
    return(json_data[[default_profile_field]])
  }

  # Try legacy field
  if (!is.null(json_data$default_profile)) {
    return(json_data$default_profile)
  }

  # Fallback to first profile name
  profile_names <- get_profile_names(json_data, language)
  if (length(profile_names) > 0) {
    return(profile_names[1])
  }

  return(default_name)
}
