#' Dictionary Explorer Helper Functions
#'
#' @description Utility functions for the dictionary explorer module
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
#' @param editable Logical; if TRUE and is_editing is TRUE, shows a numeric input
#' @param input_id Character; Shiny input ID for editable numeric inputs (must be namespaced)
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
                               step = 1,
                               is_editing = FALSE,
                               ns = NULL,
                               include_colon = TRUE) {
  # If editable and in edit mode, show numeric input
  if (editable && is_editing && !is.null(input_id) && !is.null(ns)) {
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

    label_text <- if (include_colon) paste0(label, ":") else label

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
