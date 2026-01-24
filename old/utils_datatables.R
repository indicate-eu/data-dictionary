#' DataTable Utilities
#'
#' Helper functions for DataTable operations and formatting
#'
#' @noRd

#' Generate action buttons HTML for datatables
#'
#' @description Creates a uniform HTML string with action buttons for DataTable columns.
#' All buttons follow the same styling and icon conventions.
#'
#' @param buttons List of button definitions. Each button should be a list with:
#'   \itemize{
#'     \item \code{label}: Button text (character)
#'     \item \code{icon}: FontAwesome icon name without "fa-" prefix (character, optional)
#'     \item \code{type}: Button type - "primary", "warning", "success", or "danger" (character, default: "primary")
#'     \item \code{class}: Additional CSS class for the button (character, optional)
#'     \item \code{data_attr}: Named list of data attributes (list, optional)
#'     \item \code{onclick}: JavaScript onclick handler (character, optional)
#'   }
#'
#' @return HTML string with formatted action buttons
#'
#' @examples
#' \dontrun{
#' # Example 1: Simple buttons with data attributes
#' create_datatable_actions(list(
#'   list(label = "Edit", icon = "edit", type = "warning",
#'        class = "edit-btn", data_attr = list(id = 123)),
#'   list(label = "Delete", icon = "trash", type = "danger",
#'        class = "delete-btn", data_attr = list(id = 123))
#' ))
#'
#' # Example 2: Buttons with onclick handlers
#' create_datatable_actions(list(
#'   list(label = "Open", icon = "folder-open", type = "primary",
#'        onclick = "Shiny.setInputValue('open_item', 123, {priority: 'event'})"),
#'   list(label = "Export", icon = "download", type = "success",
#'        onclick = "Shiny.setInputValue('export_item', 123, {priority: 'event'})")
#' ))
#' }
#'
#' @export
create_datatable_actions <- function(buttons) {
  if (length(buttons) == 0) return("")

  button_html <- sapply(buttons, function(btn) {
    # Determine button type class
    type_class <- switch(
      btn$type %||% "primary",
      "primary" = "",
      "warning" = " dt-action-btn-warning",
      "success" = " dt-action-btn-success",
      "danger" = " dt-action-btn-danger",
      ""
    )

    # Build icon HTML
    icon_html <- if (!is.null(btn$icon) && length(btn$icon) > 0 && btn$icon != "") {
      sprintf('<i class="fas fa-%s"></i> ', btn$icon)
    } else {
      ""
    }

    # Build additional CSS classes
    additional_classes <- if (!is.null(btn$class) && length(btn$class) > 0 && btn$class != "") {
      paste0(" ", btn$class)
    } else {
      ""
    }

    # Build data attributes
    data_attrs <- if (!is.null(btn$data_attr) && length(btn$data_attr) > 0) {
      paste(
        sapply(names(btn$data_attr), function(name) {
          sprintf('data-%s="%s"', name, btn$data_attr[[name]])
        }),
        collapse = " "
      )
    } else {
      ""
    }

    # Build onclick attribute
    onclick_attr <- if (!is.null(btn$onclick) && length(btn$onclick) > 0 && btn$onclick != "") {
      sprintf('onclick="%s"', btn$onclick)
    } else {
      ""
    }

    # Combine all parts
    sprintf(
      '<button class="dt-action-btn%s%s" %s %s>%s%s</button>',
      type_class,
      additional_classes,
      data_attrs,
      onclick_attr,
      icon_html,
      btn$label
    )
  })

  paste(button_html, collapse = "")
}

#' Null coalescing operator
#'
#' @description Returns the left-hand side if not NULL, otherwise the right-hand side
#' @param x Left-hand side value
#' @param y Right-hand side value (default)
#' @return x if not NULL, otherwise y
#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
