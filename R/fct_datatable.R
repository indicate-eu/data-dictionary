#' DataTable Functions
#'
#' @description Helper functions for creating standardized DataTables
#' @noRd

#' Null coalescing operator
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Create DataTable Action Buttons
#'
#' @description Generate action buttons HTML for DataTable cells.
#'
#' @param buttons List of button definitions with: label, icon, type, class, data_attr, onclick
#'
#' @return HTML string
#' @noRd
create_datatable_actions <- function(buttons) {
  if (length(buttons) == 0) return("")

  button_html <- sapply(buttons, function(btn) {
    type_class <- switch(
      btn$type %||% "primary",
      "primary" = "",
      "warning" = " dt-action-btn-warning",
      "success" = " dt-action-btn-success",
      "danger" = " dt-action-btn-danger",
      ""
    )

    icon_html <- if (!is.null(btn$icon) && btn$icon != "") {
      sprintf('<i class="fas fa-%s"></i> ', btn$icon)
    } else ""

    additional_classes <- if (!is.null(btn$class) && btn$class != "") {
      paste0(" ", btn$class)
    } else ""

    data_attrs <- if (!is.null(btn$data_attr) && length(btn$data_attr) > 0) {
      paste(sapply(names(btn$data_attr), function(name) {
        sprintf('data-%s="%s"', name, btn$data_attr[[name]])
      }), collapse = " ")
    } else ""

    onclick_attr <- if (!is.null(btn$onclick) && btn$onclick != "") {
      sprintf('onclick="%s"', btn$onclick)
    } else ""

    sprintf(
      '<button class="dt-action-btn%s%s" %s %s>%s%s</button>',
      type_class, additional_classes, data_attrs, onclick_attr, icon_html, btn$label
    )
  })

  paste(button_html, collapse = "")
}

#' Create Empty DataTable
#'
#' @description Creates a standardized empty DataTable with a message.
#'
#' @param message Character: Message to display
#' @param column_name Character: Column name for the message
#'
#' @return DT datatable object
#' @noRd
create_empty_datatable <- function(message, column_name = "Message") {
  df <- data.frame(x = message, stringsAsFactors = FALSE)
  colnames(df) <- column_name

  DT::datatable(
    df,
    options = list(dom = "t"),
    rownames = FALSE,
    selection = "none"
  )
}

#' Create Standard DataTable
#'
#' @description Factory function to create DataTables with consistent defaults.
#'
#' @param data Data frame to display
#' @param selection Selection mode: "single", "multiple", or "none"
#' @param filter Filter position: "top", "bottom", or "none"
#' @param page_length Number of rows per page (default: 15)
#' @param dom DataTables dom string (default: "ltip")
#' @param col_names Column names (optional)
#' @param col_defs Column definitions list (optional)
#' @param escape Which columns to escape (TRUE/FALSE or vector)
#' @param callback JavaScript callback (optional)
#' @param class CSS class for table
#' @param fuzzy_search Logical: Enable fuzzy search (default: FALSE)
#'
#' @return DT datatable object
#' @noRd
create_standard_datatable <- function(
    data,
    selection = "single",
    filter = "top",
    page_length = 15,
    dom = "ltip",
    col_names = NULL,
    col_defs = NULL,
    escape = TRUE,
    callback = NULL,
    class = "cell-border stripe hover",
    fuzzy_search = FALSE
) {
  options <- list(
    pageLength = page_length,
    lengthMenu = list(c(10, 15, 25, 50, 100), c("10", "15", "25", "50", "100")),
    dom = dom,
    language = get_datatable_language(),
    ordering = TRUE,
    autoWidth = FALSE,
    paging = TRUE
  )

  # Add fuzzy search configuration
  if (fuzzy_search) {
    options$search <- list(
      smart = TRUE,
      regex = FALSE,
      caseInsensitive = TRUE
    )
  }

  if (!is.null(col_defs)) {
    options$columnDefs <- col_defs
  }

  dt_args <- list(
    data = data,
    selection = selection,
    rownames = FALSE,
    escape = escape,
    class = class,
    options = options
  )

  if (filter != "none") {
    dt_args$filter <- filter
  }

  if (!is.null(col_names)) {
    dt_args$colnames <- col_names
  }

  if (!is.null(callback)) {
    dt_args$callback <- callback
  }

  do.call(DT::datatable, dt_args)
}

#' Add Button Click Handlers to DataTable
#'
#' @description Creates a JavaScript drawCallback that handles click events
#' on buttons within DataTable cells, extracting data-id attributes and
#' triggering Shiny input events. Optionally adds double-click handler on rows.
#'
#' @param dt DT datatable object to modify
#' @param handlers List of handlers with structure:
#'   list(list(selector = ".btn-class", input_id = "namespaced_id"), ...)
#' @param dblclick_input_id Optional: Shiny input ID for double-click on row.
#'   If provided, double-clicking a row triggers this input with the first column value (ID).
#' @param id_column_index Index of the column containing the row ID for double-click (default: 0)
#'
#' @return Modified datatable object with drawCallback configured
#' @noRd
add_button_handlers <- function(dt, handlers, dblclick_input_id = NULL, id_column_index = 0) {
  off_calls <- sapply(handlers, function(h) {
    sprintf("$(table.table().node()).off('click', '%s');", h$selector)
  })

  on_calls <- sapply(handlers, function(h) {
    sprintf("
      $(table.table().node()).on('click', '%s', function(e) {
        e.stopPropagation();
        var id = $(this).data('id');
        Shiny.setInputValue('%s', id, {priority: 'event'});
      });", h$selector, h$input_id)
  })

  # Add double-click handler if specified
  dblclick_js <- ""
  if (!is.null(dblclick_input_id)) {
    dblclick_js <- sprintf("
      $(table.table().node()).off('dblclick', 'tbody tr');
      $(table.table().node()).on('dblclick', 'tbody tr', function() {
        var rowData = table.row(this).data();
        if (rowData && rowData[%d]) {
          var rowId = rowData[%d];
          Shiny.setInputValue('%s', rowId, {priority: 'event'});
        }
      });", id_column_index, id_column_index, dblclick_input_id)
  }

  js_code <- sprintf("
    function(settings) {
      var table = this.api();
      %s
      %s
      %s
    }
  ", paste(off_calls, collapse = "\n      "),
     paste(on_calls, collapse = "\n"),
     dblclick_js)

  dt$x$options$drawCallback <- htmlwidgets::JS(js_code)

  dt
}

#' Get DataTable Language Options
#'
#' @description Returns language options for DataTables based on current language.
#'
#' @param language Character: Language code ("en" or "fr")
#'
#' @return List of language options
#' @noRd
get_datatable_language <- function(language = NULL) {
  if (is.null(language)) {
    language <- Sys.getenv("INDICATE_LANGUAGE", "en")
  }

  if (language == "fr") {
    list(
      processing = "Traitement en cours...",
      search = "Rechercher :",
      lengthMenu = "Afficher _MENU_ \u00e9l\u00e9ments",
      info = "Affichage de _START_ \u00e0 _END_ sur _TOTAL_ \u00e9l\u00e9ments",
      infoEmpty = "Affichage de 0 \u00e0 0 sur 0 \u00e9l\u00e9ments",
      infoFiltered = "(filtr\u00e9 de _MAX_ \u00e9l\u00e9ments au total)",
      loadingRecords = "Chargement en cours...",
      zeroRecords = "Aucun \u00e9l\u00e9ment \u00e0 afficher",
      emptyTable = "Aucune donn\u00e9e disponible dans le tableau",
      paginate = list(
        first = "Premier",
        previous = "Pr\u00e9c\u00e9dent",
        `next` = "Suivant",
        last = "Dernier"
      )
    )
  } else {
    list(
      processing = "Processing...",
      search = "Search:",
      lengthMenu = "Show _MENU_ entries",
      info = "Showing _START_ to _END_ of _TOTAL_ entries",
      infoEmpty = "Showing 0 to 0 of 0 entries",
      infoFiltered = "(filtered from _MAX_ total entries)",
      loadingRecords = "Loading...",
      zeroRecords = "No matching records found",
      emptyTable = "No data available in table",
      paginate = list(
        first = "First",
        previous = "Previous",
        `next` = "Next",
        last = "Last"
      )
    )
  }
}
