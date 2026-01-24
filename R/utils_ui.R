#' UI Helper Functions
#'
#' @description Reusable UI utility functions for layouts and components
#' @noRd

# LAYOUT FUNCTIONS ====
#
# Available layouts:
#   - "full": Single panel filling entire space
#   - "left-right": Two vertical columns (50/50)
#   - "top-bottom": Two horizontal rows (50/50)
#   - "left-wide": Left panel wide (66%), right panel narrow (33%)
#   - "right-wide": Left panel narrow (33%), right panel wide (66%)
#   - "quadrant": Four equal panels (2x2 grid)

#' Create a Page Layout Container
#'
#' @description Creates a standardized layout container with 1 to 4 panels.
#'
#' @param layout Character: Layout type
#' @param ... Panel contents
#' @param splitter Logical: Whether to add resizable splitters
#'
#' @return A shiny.tag div element
#' @noRd
create_page_layout <- function(layout = "full", ..., splitter = TRUE) {
  panels <- list(...)

  expected_panels <- switch(layout,
    "full" = 1,
    "left-right" = 2,
    "top-bottom" = 2,
    "left-wide" = 2,
    "right-wide" = 2,
    "quadrant" = 4,
    stop("Unknown layout: ", layout)
  )

  if (length(panels) != expected_panels) {
    stop("Layout '", layout, "' expects ", expected_panels, " panels, got ", length(panels))
  }

  switch(layout,
    "full" = build_full_layout(panels[[1]]),
    "left-right" = build_two_column_layout(panels[[1]], panels[[2]], splitter, "50%", "50%"),
    "top-bottom" = build_two_row_layout(panels[[1]], panels[[2]], splitter),
    "left-wide" = build_two_column_layout(panels[[1]], panels[[2]], splitter, "66%", "33%"),
    "right-wide" = build_two_column_layout(panels[[1]], panels[[2]], splitter, "33%", "66%"),
    "quadrant" = build_quadrant_layout(panels[[1]], panels[[2]], panels[[3]], panels[[4]], splitter)
  )
}

#' Create a Panel with Header
#'
#' @description Creates a panel with optional header for use in layouts.
#'
#' @param title Character: Panel title (NULL for no header)
#' @param content Tag or tagList: Panel content
#' @param header_extra Tag: Extra content in header (e.g., buttons)
#' @param class Character: Additional CSS classes
#' @param id Character: Panel ID (optional)
#' @param tooltip Character: Tooltip text for info icon
#'
#' @return A shiny.tag div element
#' @noRd
create_panel <- function(title = NULL, content, header_extra = NULL,
                         class = NULL, id = NULL, tooltip = NULL) {
  panel_class <- paste(c("layout-panel", class), collapse = " ")

  header <- if (!is.null(title)) {
    tags$div(
      class = "panel-header",
      tags$div(
        class = "panel-header-left",
        tags$h4(title, class = "panel-title"),
        if (!is.null(tooltip)) {
          tags$span(class = "info-icon", `data-tooltip` = tooltip, "i")
        }
      ),
      if (!is.null(header_extra)) {
        tags$div(class = "panel-header-right", header_extra)
      }
    )
  }

  tags$div(
    class = panel_class,
    id = id,
    header,
    tags$div(class = "panel-content", content)
  )
}

# Internal layout builders ====

build_full_layout <- function(panel) {
  tags$div(class = "layout-container layout-full", panel)
}

build_two_column_layout <- function(left, right, splitter, left_width, right_width) {
  tags$div(
    class = "layout-container layout-columns",
    tags$div(
      class = "layout-column layout-column-left",
      style = paste0("width: ", left_width, ";"),
      left
    ),
    if (splitter) tags$div(class = "layout-splitter layout-splitter-vertical"),
    tags$div(
      class = "layout-column layout-column-right",
      style = paste0("width: ", right_width, ";"),
      right
    )
  )
}

build_two_row_layout <- function(top, bottom, splitter) {
  tags$div(
    class = "layout-container layout-rows",
    tags$div(class = "layout-row layout-row-top", top),
    if (splitter) tags$div(class = "layout-splitter layout-splitter-horizontal"),
    tags$div(class = "layout-row layout-row-bottom", bottom)
  )
}

build_quadrant_layout <- function(top_left, top_right, bottom_left, bottom_right, splitter) {
  tags$div(
    class = "layout-container layout-quadrant",
    tags$div(
      class = "layout-row layout-row-top",
      tags$div(class = "layout-quadrant-panel layout-quadrant-tl", top_left),
      if (splitter) tags$div(class = "layout-splitter layout-splitter-vertical"),
      tags$div(class = "layout-quadrant-panel layout-quadrant-tr", top_right)
    ),
    if (splitter) tags$div(class = "layout-splitter layout-splitter-horizontal"),
    tags$div(
      class = "layout-row layout-row-bottom",
      tags$div(class = "layout-quadrant-panel layout-quadrant-bl", bottom_left),
      if (splitter) tags$div(class = "layout-splitter layout-splitter-vertical"),
      tags$div(class = "layout-quadrant-panel layout-quadrant-br", bottom_right)
    )
  )
}

# DETAIL ITEM FUNCTION ====

#' Create a Detail Item
#'
#' @description Creates a label-value pair for displaying concept information.
#'
#' @param label Character: Field label
#' @param value Value to display
#' @param format_number Logical: Format as number with separators
#' @param url Character: Make value a link
#' @param color Character: Text color
#'
#' @return A shiny.tag div element
#' @noRd
create_detail_item <- function(label, value, format_number = FALSE, url = NULL, color = NULL) {
  display_value <- if (is.null(value) || length(value) == 0 || (length(value) == 1 && is.na(value)) || identical(value, "")) {
    "/"
  } else if (is.logical(value)) {
    if (isTRUE(value)) "Yes" else if (isFALSE(value)) "No" else "/"
  } else if (format_number && is.numeric(value)) {
    format(value, big.mark = ",", scientific = FALSE)
  } else {
    as.character(value)
  }

  if (!is.null(url) && display_value != "/") {
    display_value <- tags$a(
      href = url,
      target = "_blank",
      style = "color: #0f60af; text-decoration: underline;",
      display_value
    )
  } else if (!is.null(color) && display_value != "/") {
    display_value <- tags$span(
      style = paste0("color: ", color, "; font-weight: 600;"),
      display_value
    )
  }

  tags$div(
    class = "detail-item",
    tags$strong(paste0(label, ":")),
    tags$span(display_value)
  )
}
