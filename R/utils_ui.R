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

#' Build FHIR URL for a concept
#'
#' @description Builds a FHIR terminology server URL based on vocabulary.
#'
#' @param vocabulary_id Character: Vocabulary ID (SNOMED, LOINC, etc.)
#' @param concept_code Character: Concept code
#'
#' @return Character: FHIR URL or NULL if not available
#' @noRd
build_fhir_url <- function(vocabulary_id, concept_code) {

  if (is.null(vocabulary_id) || is.null(concept_code) ||
      length(vocabulary_id) == 0 || length(concept_code) == 0 ||
      length(vocabulary_id) > 1 || length(concept_code) > 1) {
    return(NULL)
  }

  if (any(is.na(vocabulary_id)) || any(is.na(concept_code))) {
    return(NULL)
  }

  # FHIR system identifiers
  fhir_systems <- list(
    SNOMED = "http://snomed.info/sct",
    LOINC = "http://loinc.org",
    ICD10 = "http://hl7.org/fhir/sid/icd-10",
    ICD10CM = "http://hl7.org/fhir/sid/icd-10-cm",
    UCUM = "http://unitsofmeasure.org",
    RxNorm = "http://www.nlm.nih.gov/research/umls/rxnorm"
  )

  # Vocabularies without FHIR links
  no_link_vocabs <- c("RxNorm Extension", "OMOP Extension")

  if (vocabulary_id %in% no_link_vocabs) {
    return(NULL)
  }

  system_url <- fhir_systems[[vocabulary_id]]
  if (is.null(system_url)) {
    return(NULL)
  }

  # Build URL to tx.fhir.org

  paste0("https://tx.fhir.org/r4/CodeSystem/$lookup?system=",
         utils::URLencode(system_url, reserved = TRUE),
         "&code=", utils::URLencode(as.character(concept_code), reserved = TRUE))
}

#' Render OMOP Concept Details UI
#'
#' @description Creates a standardized UI for displaying OMOP concept details.
#' This function is reusable across different parts of the application.
#' Fields are organized in 2 columns with logical ordering.
#'
#' @param concept Data frame row or list containing concept information
#' @param i18n Translation object for labels
#' @param empty_message Character: Message to show when no concept is selected
#' @param show_already_added Logical: Whether to show "already added" badge
#' @param is_already_added Logical: Whether concept is already added
#'
#' @return A shiny.tag div element
#' @noRd
render_concept_details <- function(concept, i18n, empty_message = NULL,
                                   show_already_added = FALSE, is_already_added = FALSE) {
  # Handle empty/NULL concept
  if (is.null(concept) || (is.data.frame(concept) && nrow(concept) == 0)) {
    msg <- if (!is.null(empty_message)) empty_message else as.character(i18n$t("no_concept_selected"))
    return(tags$div(
      class = "no-content-message",
      msg
    ))
  }

  # Build URLs

  athena_url <- paste0("https://athena.ohdsi.org/search-terms/terms/", concept$concept_id)
  fhir_url <- build_fhir_url(concept$vocabulary_id, concept$concept_code)

  # Determine validity
  is_valid <- is.null(concept$invalid_reason) ||
              length(concept$invalid_reason) == 0 ||
              all(is.na(concept$invalid_reason)) ||
              all(concept$invalid_reason == "")
  validity_text <- if (is_valid) "Valid" else paste0("Invalid (", concept$invalid_reason[1], ")")
  validity_color <- if (is_valid) "#28a745" else "#dc3545"

  # Determine standard concept display
  standard_text <- if (!is.null(concept$standard_concept) &&
                       length(concept$standard_concept) > 0 &&
                       !all(is.na(concept$standard_concept)) &&
                       all(concept$standard_concept != "")) {
    switch(concept$standard_concept,
      "S" = "Standard",
      "C" = "Classification",
      "Non-standard"
    )
  } else {
    "Non-standard"
  }
  standard_color <- switch(standard_text,
    "Standard" = "#28a745",      # Green for standard
    "Classification" = "#6c757d", # Gray for classification
    "#dc3545"                     # Red for non-standard
  )

  # FHIR resource display
  fhir_display <- if (!is.null(fhir_url)) {
    fhir_url
  } else {
    NULL
  }

  # Build details grid - 2 columns
  # Left column: concept_name, vocabulary_id, concept_code, domain_id, concept_class_id
  # Right column: omop_concept_id (Athena), fhir_resource, standard, validity
  details_ui <- tags$div(
    class = "concept-details-grid",
    # Row 1: concept_name | omop_concept_id (with Athena link)
    create_detail_item(as.character(i18n$t("concept_name")), concept$concept_name),
    create_detail_item(as.character(i18n$t("view_in_athena")), concept$concept_id, url = athena_url),
    # Row 2: vocabulary_id | fhir_resource
    create_detail_item(as.character(i18n$t("vocabulary_id")), concept$vocabulary_id),
    create_detail_item(
      as.character(i18n$t("fhir_resource")),
      if (!is.null(fhir_url)) concept$vocabulary_id else as.character(i18n$t("no_link_available")),
      url = fhir_url
    ),
    # Row 3: concept_code | standard
    create_detail_item(as.character(i18n$t("concept_code")), concept$concept_code),
    create_detail_item(as.character(i18n$t("standard")), standard_text, color = standard_color),
    # Row 4: domain_id | validity
    create_detail_item(as.character(i18n$t("domain_id")), concept$domain_id),
    create_detail_item(as.character(i18n$t("validity")), validity_text, color = validity_color),
    # Row 5: concept_class_id | empty
    create_detail_item(as.character(i18n$t("concept_class_id")), concept$concept_class_id),
    tags$div()
  )

  # Add "already added" badge if needed
  if (show_already_added && is_already_added) {
    details_ui <- tagList(
      details_ui,
      tags$div(
        class = "concept-already-added-badge",
        paste0("\u2713 ", as.character(i18n$t("already_added")))
      )
    )
  }

  tags$div(class = "concept-details-container", details_ui)
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

# COLOR PICKER ====

#' Get Text Color for Background
#'
#' @description Calculates whether white or black text should be used based on background color luminance
#'
#' @param bg_color Character: Background color in hex format (e.g., "#ff0000")
#'
#' @return Character: "#ffffff" (white) or "#000000" (black)
#' @noRd
get_text_color_for_bg <- function(bg_color) {
  # Remove # if present
  color <- gsub("#", "", bg_color)

  # Convert to RGB
  r <- strtoi(substr(color, 1, 2), base = 16)
  g <- strtoi(substr(color, 3, 4), base = 16)
  b <- strtoi(substr(color, 5, 6), base = 16)

  # Calculate relative luminance (perceived brightness)
  # Formula from WCAG 2.0
  luminance <- (0.299 * r + 0.587 * g + 0.114 * b) / 255

  # Return white text for dark backgrounds, black for light backgrounds
  if (luminance > 0.5) "#000000" else "#ffffff"
}

#' Create Color Picker with Predefined Palette
#'
#' @description Creates a color picker with predefined palette and automatic text color
#'
#' @param id Character: Input ID (will be namespaced)
#' @param value Character: Initial color value (hex code)
#' @param ns Function: Namespace function from module
#'
#' @return A shiny.tag div element
#' @noRd
create_color_picker <- function(id, value = "#6c757d", ns) {
  # Predefined color palette with text colors
  # Format: c(bg_color, text_color)
  colors <- list(
    # Light colors (dark text)
    c("#e3f2fd", "#000000"), # Light Blue
    c("#f3e5f5", "#000000"), # Light Purple
    c("#e8f5e9", "#000000"), # Light Green
    c("#fff3e0", "#000000"), # Light Orange
    c("#fce4ec", "#000000"), # Light Pink
    c("#f1f8e9", "#000000"), # Light Lime
    c("#e0f7fa", "#000000"), # Light Cyan
    c("#fff9c4", "#000000"), # Light Yellow

    # Medium colors (dark text)
    c("#90caf9", "#000000"), # Medium Blue
    c("#ce93d8", "#000000"), # Medium Purple
    c("#a5d6a7", "#000000"), # Medium Green
    c("#ffcc80", "#000000"), # Medium Orange
    c("#f48fb1", "#000000"), # Medium Pink
    c("#dce775", "#000000"), # Medium Lime
    c("#80deea", "#000000"), # Medium Cyan
    c("#fff59d", "#000000"), # Medium Yellow

    # Dark colors (white text)
    c("#42a5f5", "#ffffff"), # Dark Blue
    c("#ab47bc", "#ffffff"), # Dark Purple
    c("#66bb6a", "#ffffff"), # Dark Green
    c("#ffa726", "#ffffff"), # Dark Orange
    c("#ec407a", "#ffffff"), # Dark Pink
    c("#d4e157", "#000000"), # Dark Lime
    c("#26c6da", "#ffffff"), # Dark Cyan
    c("#ffee58", "#000000"), # Dark Yellow

    # Very dark colors (white text)
    c("#1e88e5", "#ffffff"), # Very Dark Blue
    c("#8e24aa", "#ffffff"), # Very Dark Purple
    c("#43a047", "#ffffff"), # Very Dark Green
    c("#fb8c00", "#ffffff"), # Very Dark Orange
    c("#d81b60", "#ffffff"), # Very Dark Pink
    c("#9e9d24", "#ffffff"), # Very Dark Lime
    c("#00acc1", "#ffffff"), # Very Dark Cyan
    c("#fdd835", "#000000"), # Very Dark Yellow

    # Grays
    c("#f5f5f5", "#000000"), # Very Light Gray
    c("#e0e0e0", "#000000"), # Light Gray
    c("#bdbdbd", "#000000"), # Gray
    c("#9e9e9e", "#ffffff"), # Medium Gray
    c("#757575", "#ffffff"), # Dark Gray
    c("#616161", "#ffffff"), # Very Dark Gray
    c("#424242", "#ffffff"), # Almost Black
    c("#212121", "#ffffff")  # Black
  )

  # Generate color swatches
  swatches <- lapply(colors, function(color_pair) {
    bg_color <- color_pair[1]
    is_selected <- (bg_color == value)
    swatch_class <- if (is_selected) "color-swatch selected" else "color-swatch"

    tags$div(
      class = swatch_class,
      `data-color` = bg_color,
      style = sprintf("background-color: %s;", bg_color),
      onclick = sprintf("
        var container = this.closest('.color-picker');
        container.querySelectorAll('.color-swatch').forEach(function(el) {
          el.classList.remove('selected');
        });
        this.classList.add('selected');
        Shiny.setInputValue('%s', '%s', {priority: 'event'});
      ", ns(id), bg_color)
    )
  })

  tags$div(
    class = "color-picker",
    tags$div(
      class = "color-swatches",
      swatches
    ),
    # Hidden input to store the selected color
    tags$input(
      type = "hidden",
      id = ns(id),
      value = value
    )
  )
}
