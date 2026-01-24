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

# COLOR PICKER FUNCTION ====

#' Create a Custom Color Picker
#'
#' @description Creates a color picker with predefined modern colors and a custom color option.
#' Uses a dropdown with color swatches and a native color input for custom colors.
#'
#' @param id Character: Input ID for the color picker value
#' @param value Character: Initial color value (hex code, default: "#6c757d")
#' @param ns Function: Namespace function from shiny module
#'
#' @return A shiny.tag div element representing the color picker
#' @noRd
create_color_picker <- function(id, value = "#6c757d", ns = identity) {
  picker_id <- ns(id)

  # Modern color palette (18 colors in 3 rows of 6)
  preset_colors <- c(
    # Row 1: Reds/Oranges/Yellows
    "#ef4444", "#f97316", "#f59e0b", "#eab308", "#84cc16", "#22c55e",
    # Row 2: Greens/Teals/Blues
    "#10b981", "#14b8a6", "#06b6d4", "#0ea5e9", "#3b82f6", "#6366f1",
    # Row 3: Purples/Pinks/Grays
    "#8b5cf6", "#a855f7", "#d946ef", "#ec4899", "#6c757d", "#374151"
  )

  # Generate preset color swatches
  preset_swatches <- lapply(preset_colors, function(color) {
    tags$button(
      type = "button",
      class = paste0("color-preset", if (color == value) " selected" else ""),
      style = paste0("background-color: ", color, ";"),
      `data-color` = color,
      onclick = sprintf("
        var container = this.closest('.color-picker-container');
        var valueInput = container.querySelector('.color-picker-value');
        var preview = container.querySelector('.color-picker-preview');
        var customInput = container.querySelector('.color-picker-custom-input');
        container.querySelectorAll('.color-preset').forEach(function(el) { el.classList.remove('selected'); });
        this.classList.add('selected');
        valueInput.value = '%s';
        preview.style.backgroundColor = '%s';
        customInput.value = '%s';
        Shiny.setInputValue('%s', '%s', {priority: 'event'});
        container.querySelector('.color-picker-dropdown').classList.remove('open');
      ", color, color, color, picker_id, color)
    )
  })

  tags$div(
    class = "color-picker-container",
    # Hidden input to store the value
    tags$input(
      type = "hidden",
      id = picker_id,
      class = "color-picker-value",
      name = picker_id,
      value = value
    ),
    # Trigger button
    tags$button(
      type = "button",
      class = "color-picker-trigger",
      onclick = "
        var dropdown = this.nextElementSibling;
        dropdown.classList.toggle('open');
        event.stopPropagation();
      ",
      tags$span(
        class = "color-picker-preview",
        style = paste0("background-color: ", value, ";")
      )
    ),
    # Dropdown
    tags$div(
      class = "color-picker-dropdown",
      onclick = "event.stopPropagation();",
      # Preset colors grid
      tags$div(
        class = "color-picker-presets",
        preset_swatches
      ),
      # Custom color input
      tags$div(
        class = "color-picker-custom",
        tags$span(class = "color-picker-custom-label", "Custom:"),
        tags$input(
          type = "color",
          class = "color-picker-custom-input",
          value = value,
          onchange = sprintf("
            var container = this.closest('.color-picker-container');
            var valueInput = container.querySelector('.color-picker-value');
            var preview = container.querySelector('.color-picker-preview');
            container.querySelectorAll('.color-preset').forEach(function(el) { el.classList.remove('selected'); });
            valueInput.value = this.value;
            preview.style.backgroundColor = this.value;
            Shiny.setInputValue('%s', this.value, {priority: 'event'});
            container.querySelector('.color-picker-dropdown').classList.remove('open');
          ", picker_id)
        )
      )
    ),
    # Close dropdown when clicking outside
    tags$script(HTML(sprintf("
      document.addEventListener('click', function(e) {
        var container = document.querySelector('#%s').closest('.color-picker-container');
        if (container && !container.contains(e.target)) {
          container.querySelector('.color-picker-dropdown').classList.remove('open');
        }
      });
    ", picker_id)))
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

# MODAL FUNCTIONS ====

#' Create a Modal Dialog
#'
#' @description Creates a standardized modal dialog with overlay, header, body, and footer.
#' The modal closes when clicking outside (on the overlay) or on the close button.
#'
#' @param id Character: Modal ID (will be used for showing/hiding)
#' @param title Character or tag: Modal title
#' @param body Tag or tagList: Modal body content
#' @param footer Tag or tagList: Modal footer content (e.g., action buttons). If NULL, no footer.
#' @param size Character: Modal size ("small", "medium", "large", "fullscreen")
#' @param icon Character: FontAwesome icon class for title (e.g., "fas fa-folder-open")
#' @param ns Function: Namespace function from shiny module (required for proper ID handling)
#'
#' @return A shiny.tag div element representing the modal
#' @noRd
#'
#' @examples
#' # In a module UI function:
#' create_modal(
#'   id = "confirm_modal",
#'   title = "Confirm Action",
#'   body = tags$p("Are you sure you want to proceed?"),
#'   footer = tagList(
#'     actionButton(ns("cancel"), "Cancel", class = "btn-secondary-custom"),
#'     actionButton(ns("confirm"), "Confirm", class = "btn-primary-custom")
#'   ),
#'   size = "small",
#'   ns = ns
#' )
create_modal <- function(id, title, body, footer = NULL, size = "medium",
                         icon = NULL, ns = identity) {
  modal_id <- ns(id)

  size_class <- switch(size,
    "small" = "modal-small",
    "medium" = "modal-medium",
    "large" = "modal-large",
    "fullscreen" = "modal-fullscreen",
    "modal-medium"
  )

  title_content <- if (!is.null(icon)) {
    tags$h3(
      tags$i(class = icon, style = "margin-right: 8px;"),
      title
    )
  } else {
    tags$h3(title)
  }

  tags$div(
    id = modal_id,
    class = "modal-overlay",
    style = "display: none;",
    onclick = sprintf("if(event.target === event.currentTarget) document.getElementById('%s').style.display = 'none';", modal_id),
    tags$div(
      class = paste("modal-content", size_class),
      tags$div(
        class = "modal-header",
        title_content,
        tags$button(
          class = "modal-close",
          onclick = sprintf("document.getElementById('%s').style.display = 'none';", modal_id),
          "\u00D7"
        )
      ),
      tags$div(
        class = "modal-body",
        body
      ),
      if (!is.null(footer)) {
        tags$div(
          class = "modal-footer",
          footer
        )
      }
    )
  )
}

#' Show a Modal Dialog
#'
#' @description Shows a modal dialog by ID using JavaScript.
#'
#' @param modal_id Character: The full modal ID (including namespace)
#'
#' @return NULL (side effect: runs JavaScript)
#' @noRd
show_modal <- function(modal_id) {
  shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'flex';", modal_id))
}

#' Hide a Modal Dialog
#'
#' @description Hides a modal dialog by ID using JavaScript.
#'
#' @param modal_id Character: The full modal ID (including namespace)
#'
#' @return NULL (side effect: runs JavaScript)
#' @noRd
hide_modal <- function(modal_id) {
  shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", modal_id))
}
