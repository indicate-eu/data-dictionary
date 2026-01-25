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
#' By default includes: paging, length menu, info, and column visibility button.
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
#' @param show_colvis Logical: Show column visibility button (default: TRUE)
#' @param extensions Character vector of DataTables extensions to use
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
    fuzzy_search = FALSE,
    show_colvis = TRUE,
    extensions = character(0)
) {
  # Wrap ip (info + pagination) in a flex-row container to keep them on the same line
  # DataTables dom syntax: <"class"...> wraps elements in a div with that class
  if (grepl("ip", dom)) {
    dom <- sub("ip", '<"dt-bottom-row"ip>', dom)
  }

  # If show_colvis is TRUE, add Buttons extension and modify dom
  if (show_colvis) {
    extensions <- unique(c(extensions, "Buttons"))
    # Wrap B and l in a flex-row container to keep them on the same line
    if (grepl("^l", dom)) {
      # Replace leading 'l' with '<"dt-top-row"Bl>'
      dom <- sub("^l", '<"dt-top-row"Bl>', dom)
    } else if (!grepl("B", dom)) {
      dom <- paste0("B", dom)
    }
  }

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

  # Add colvis button configuration
  if (show_colvis) {
    options$buttons <- list(
      list(
        extend = "colvis",
        text = "Columns",
        className = "btn-colvis"
      )
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

  # Add extensions if any
  if (length(extensions) > 0) {
    dt_args$extensions <- extensions
  }

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

#' Select or Unselect All Rows in DataTable
#'
#' @description Helper function to select or unselect all rows in a DataTable.
#' Uses the DT proxy to manipulate row selection.
#'
#' @param proxy DT proxy object created with DT::dataTableProxy()
#' @param select Logical: TRUE to select all rows, FALSE to unselect all
#' @param data Optional data frame to determine row count (needed for select = TRUE)
#'
#' @return Invisible NULL (side effect: modifies table selection)
#' @noRd
datatable_select_rows <- function(proxy, select = TRUE, data = NULL) {

  if (select && !is.null(data)) {
    # Select all rows
    DT::selectRows(proxy, seq_len(nrow(data)))
  } else {
    # Unselect all rows
    DT::selectRows(proxy, NULL)
  }
  invisible(NULL)
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

#' Create Toggle HTML for Concept Set Options
#'
#' @description Creates HTML toggle switches for is_excluded, include_descendants,
#' and include_mapped flags in concept set DataTables.
#'
#' @param concept_id The concept ID for this row
#' @param field The field name (is_excluded, include_descendants, include_mapped)
#' @param checked Whether the toggle is checked
#' @param ns Shiny namespace function
#' @param input_id Input ID for the toggle change event
#' @param is_exclude Whether this is the exclude toggle (uses different styling)
#'
#' @return HTML string for the toggle
#' @noRd
create_concept_toggle <- function(concept_id, field, checked, ns, input_id, is_exclude = FALSE) {
  toggle_class <- if (is_exclude) "toggle-switch toggle-small toggle-exclude" else "toggle-switch toggle-small"
  checked_attr <- if (isTRUE(checked)) "checked" else ""


  sprintf(
    '<label class="%s"><input type="checkbox" data-concept-id="%s" data-field="%s" %s onchange="Shiny.setInputValue(\'%s\', {concept_id: %s, field: \'%s\', value: this.checked}, {priority: \'event\'})"><span class="toggle-slider"></span></label>',
    toggle_class, concept_id, field, checked_attr, ns(input_id), concept_id, field
  )
}

#' Prepare Concept Set Data for DataTable Display
#'
#' @description Prepares concept set data with HTML toggle switches for
#' is_excluded, include_descendants, and include_mapped columns. Used for
#' consistent display in concept set DataTables in edit mode.
#'
#' @param data Data frame with concept set items containing columns:
#'   concept_id, concept_name, vocabulary_id, etc., and optionally
#'   is_excluded, include_descendants, include_mapped
#' @param ns Shiny namespace function
#' @param toggle_input_id Character: Input ID for toggle change events
#'
#' @return Data frame with additional toggle HTML columns
#' @noRd
prepare_concept_set_toggles <- function(data, ns, toggle_input_id = "toggle_concept_option") {
  if (nrow(data) == 0) return(data)

  # Ensure boolean columns exist with defaults
  if (!"is_excluded" %in% names(data)) data$is_excluded <- FALSE
  if (!"include_descendants" %in% names(data)) data$include_descendants <- TRUE
  if (!"include_mapped" %in% names(data)) data$include_mapped <- TRUE

  # Convert to logical
  data$is_excluded <- as.logical(data$is_excluded)
  data$include_descendants <- as.logical(data$include_descendants)
  data$include_mapped <- as.logical(data$include_mapped)

  # Replace NA with defaults
  data$is_excluded[is.na(data$is_excluded)] <- FALSE
  data$include_descendants[is.na(data$include_descendants)] <- TRUE
  data$include_mapped[is.na(data$include_mapped)] <- TRUE

  # Create toggle HTML columns
  data$exclude_toggle <- mapply(
    create_concept_toggle,
    concept_id = data$concept_id,
    field = "is_excluded",
    checked = data$is_excluded,
    MoreArgs = list(ns = ns, input_id = toggle_input_id, is_exclude = TRUE),
    SIMPLIFY = TRUE
  )

  data$descendants_toggle <- mapply(
    create_concept_toggle,
    concept_id = data$concept_id,
    field = "include_descendants",
    checked = data$include_descendants,
    MoreArgs = list(ns = ns, input_id = toggle_input_id, is_exclude = FALSE),
    SIMPLIFY = TRUE
  )

  data$mapped_toggle <- mapply(
    create_concept_toggle,
    concept_id = data$concept_id,
    field = "include_mapped",
    checked = data$include_mapped,
    MoreArgs = list(ns = ns, input_id = toggle_input_id, is_exclude = FALSE),
    SIMPLIFY = TRUE
  )

  data
}

#' Apply Standard Concept Column Styling
#'
#' @description Apply consistent styling to standard_concept columns in DataTables.
#' Colors: Standard (green), Classification (gray), Non-standard (red).
#'
#' @param dt DT datatable object to modify
#' @param column Character: Column name to style
#'
#' @return DT datatable with styling applied
#' @noRd
style_standard_concept_column <- function(dt, column) {
  dt %>%
    DT::formatStyle(
      column,
      backgroundColor = DT::styleEqual(
        c("Standard", "Classification", "Non-standard"),
        c("#d4edda", "#e2e3e5", "#f8d7da")
      ),
      fontWeight = DT::styleEqual(
        c("Standard", "Classification", "Non-standard"),
        c("bold", "bold", "bold")
      ),
      color = DT::styleEqual(
        c("Standard", "Classification", "Non-standard"),
        c("#155724", "#383d41", "#721c24")
      )
    )
}

#' Apply Validity Column Styling
#'
#' @description Apply consistent styling to validity columns in DataTables.
#' Colors: Valid (green), Invalid (red).
#'
#' @param dt DT datatable object to modify
#' @param column Character: Column name to style
#'
#' @return DT datatable with styling applied
#' @noRd
style_validity_column <- function(dt, column) {
  dt %>%
    DT::formatStyle(
      column,
      backgroundColor = DT::styleEqual(
        c("Valid", "Invalid"),
        c("#d4edda", "#f8d7da")
      ),
      fontWeight = DT::styleEqual(
        c("Valid", "Invalid"),
        c("bold", "bold")
      ),
      color = DT::styleEqual(
        c("Valid", "Invalid"),
        c("#155724", "#721c24")
      )
    )
}
