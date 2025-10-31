#' DataTable Callback Utilities
#'
#' @description Helper functions for creating DataTable callbacks with
#' consistent event handling patterns across the application.
#' @noRd

#' Add double-click handler to DataTable
#'
#' @description Creates a JavaScript drawCallback that handles double-click
#' events on DataTable rows, extracting the ID from the first column and
#' triggering a Shiny input event.
#'
#' @param dt DT datatable object to modify
#' @param input_id Namespaced Shiny input ID to trigger on double-click
#' @param column_index Column index (0-based) containing the ID value (default: 0)
#'
#' @return Modified datatable object with drawCallback configured
#'
#' @examples
#' \dontrun{
#' dt <- datatable(data)
#' dt <- add_doubleclick_handler(dt, ns("select_row"))
#' }
#'
#' @noRd
add_doubleclick_handler <- function(dt, input_id, column_index = 0) {
  dt$x$options$drawCallback <- htmlwidgets::JS(sprintf("
    function(settings) {
      var table = settings.oInstance.api();
      $(table.table().node()).off('dblclick', 'tbody tr');
      $(table.table().node()).on('dblclick', 'tbody tr', function() {
        var rowData = table.row(this).data();
        if (rowData && rowData[%d]) {
          var id = rowData[%d];
          Shiny.setInputValue('%s', id, {priority: 'event'});
        }
      });
    }
  ", column_index, column_index, input_id))

  return(dt)
}

#' Add button click handlers to DataTable
#'
#' @description Creates a JavaScript drawCallback that handles click events
#' on buttons within DataTable cells, extracting data-id attributes and
#' triggering Shiny input events.
#'
#' @param dt DT datatable object to modify
#' @param handlers Named list of handlers with structure:
#'   list(
#'     list(selector = ".btn-class", input_id = "namespaced_id"),
#'     ...
#'   )
#'
#' @return Modified datatable object with drawCallback configured
#'
#' @examples
#' \dontrun{
#' dt <- datatable(data)
#' dt <- add_button_handlers(dt, list(
#'   list(selector = ".view-btn", input_id = ns("view")),
#'   list(selector = ".delete-btn", input_id = ns("delete"))
#' ))
#' }
#'
#' @noRd
add_button_handlers <- function(dt, handlers) {
  # Build off() calls to remove existing handlers
  off_calls <- sapply(handlers, function(h) {
    sprintf("$(table.table().node()).off('click', '%s');", h$selector)
  })

  # Build on() calls to add new handlers
  on_calls <- sapply(handlers, function(h) {
    sprintf("
          $(table.table().node()).on('click', '%s', function(e) {
            e.stopPropagation();
            var id = $(this).data('id');
            Shiny.setInputValue('%s', id, {priority: 'event'});
          });", h$selector, h$input_id)
  })

  js_code <- sprintf("
    function(settings) {
      var table = this.api();

      // Remove existing handlers to avoid duplicates
      %s

      // Add click handlers
      %s
    }
  ", paste(off_calls, collapse = "\n      "),
     paste(on_calls, collapse = "\n"))

  dt$x$options$drawCallback <- htmlwidgets::JS(js_code)

  return(dt)
}

#' Add combined button and double-click handlers to DataTable
#'
#' @description Creates a JavaScript drawCallback that handles both button
#' clicks and double-click events on DataTable rows. Useful for tables with
#' action buttons that also support double-click navigation.
#'
#' @param dt DT datatable object to modify
#' @param button_handlers Named list of button handlers (see add_button_handlers)
#' @param doubleclick_input_id Namespaced Shiny input ID for double-click events
#' @param doubleclick_column Column index for double-click ID (default: 0)
#' @param doubleclick_condition JavaScript boolean expression to conditionally
#'   enable double-click (e.g., "!editMode"). Use NULL to always enable.
#'
#' @return Modified datatable object with drawCallback configured
#'
#' @examples
#' \dontrun{
#' dt <- datatable(data)
#' dt <- add_combined_handlers(
#'   dt,
#'   button_handlers = list(
#'     list(selector = ".view-btn", input_id = ns("view")),
#'     list(selector = ".delete-btn", input_id = ns("delete"))
#'   ),
#'   doubleclick_input_id = ns("open"),
#'   doubleclick_condition = "!editMode"
#' )
#' }
#'
#' @noRd
add_combined_handlers <- function(dt, button_handlers = list(),
                                   doubleclick_input_id = NULL,
                                   doubleclick_column = 0,
                                   doubleclick_condition = NULL) {
  # Build button handler code
  button_off_calls <- ""
  button_on_calls <- ""

  if (length(button_handlers) > 0) {
    button_off_calls <- paste(sapply(button_handlers, function(h) {
      sprintf("$(table.table().node()).off('click', '%s');", h$selector)
    }), collapse = "\n      ")

    button_on_calls <- paste(sapply(button_handlers, function(h) {
      sprintf("
          $(table.table().node()).on('click', '%s', function(e) {
            e.stopPropagation();
            var id = $(this).data('id');
            Shiny.setInputValue('%s', id, {priority: 'event'});
          });", h$selector, h$input_id)
    }), collapse = "\n")
  }

  # Build double-click handler code
  doubleclick_off_call <- ""
  doubleclick_on_call <- ""

  if (!is.null(doubleclick_input_id)) {
    doubleclick_off_call <- "$(table.table().node()).off('dblclick', 'tbody tr');"

    doubleclick_code <- sprintf("
            $(table.table().node()).on('dblclick', 'tbody tr', function() {
              var rowData = table.row(this).data();
              if (rowData && rowData[%d]) {
                var id = rowData[%d];
                Shiny.setInputValue('%s', id, {priority: 'event'});
              }
            });", doubleclick_column, doubleclick_column, doubleclick_input_id)

    if (!is.null(doubleclick_condition)) {
      doubleclick_on_call <- sprintf("
          if (%s) {
          %s
          }", doubleclick_condition, doubleclick_code)
    } else {
      doubleclick_on_call <- doubleclick_code
    }
  }

  js_code <- sprintf("
    function(settings) {
      var table = this.api();

      // Remove existing handlers to avoid duplicates
      %s
      %s

      // Add handlers
      %s
      %s
    }
  ", button_off_calls, doubleclick_off_call, button_on_calls, doubleclick_on_call)

  dt$x$options$drawCallback <- htmlwidgets::JS(js_code)

  return(dt)
}
