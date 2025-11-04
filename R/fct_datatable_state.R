#' DataTable State Management Functions
#'
#' @description Helper functions to save and restore DataTable state (pagination, filters)
#'
#' @noRd

#' Save DataTable State
#'
#' @description Saves the current page number and column search filters of a DataTable
#'
#' @param input Shiny input object
#' @param table_id Character: ID of the datatable (without namespace)
#' @param saved_page reactiveVal to store page number
#' @param saved_search reactiveVal to store search column filters
#'
#' @return Invisible NULL
#'
#' @examples
#' \dontrun{
#' saved_page <- reactiveVal(1)
#' saved_search <- reactiveVal(NULL)
#' save_datatable_state(input, "my_table", saved_page, saved_search)
#' }
save_datatable_state <- function(input, table_id, saved_page, saved_search) {
  state_name <- paste0(table_id, "_state")
  search_name <- paste0(table_id, "_search_columns")

  # Save current page number
  if (!is.null(input[[state_name]])) {
    current_page <- input[[state_name]]$start / input[[state_name]]$length + 1
    saved_page(current_page)
  }

  # Save column search filters
  if (!is.null(input[[search_name]])) {
    saved_search(input[[search_name]])
  }

  invisible(NULL)
}

#' Restore DataTable State
#'
#' @description Restores previously saved page number and column search filters to a DataTable
#'
#' @param table_id Character: ID of the datatable (without namespace)
#' @param saved_page reactiveVal with stored page number
#' @param saved_search reactiveVal with stored search column filters
#' @param session Shiny session object
#' @param delay_ms Numeric: Delay in milliseconds before restoring (default 100ms)
#'
#' @return Invisible NULL
#'
#' @examples
#' \dontrun{
#' restore_datatable_state("my_table", saved_page, saved_search, session)
#' }
restore_datatable_state <- function(table_id, saved_page, saved_search, session, delay_ms = 100) {
  shinyjs::delay(delay_ms, {
    proxy <- DT::dataTableProxy(table_id, session = session)

    # Restore column filters
    search_columns <- saved_search()
    if (!is.null(search_columns)) {
      DT::updateSearch(proxy, keywords = list(
        global = NULL,
        columns = search_columns
      ))
    }

    # Restore page position
    page_num <- saved_page()
    if (!is.null(page_num) && page_num > 0) {
      DT::selectPage(proxy, page_num)
    }
  })

  invisible(NULL)
}

#' Save and Restore DataTable State (Combined)
#'
#' @description Convenience function that saves state, executes an action, then restores state
#'
#' @param input Shiny input object
#' @param table_id Character: ID of the datatable (without namespace)
#' @param saved_page reactiveVal to store page number
#' @param saved_search reactiveVal to store search column filters
#' @param session Shiny session object
#' @param action Function to execute between save and restore
#' @param delay_ms Numeric: Delay in milliseconds before restoring (default 100ms)
#'
#' @return Result of the action function
#'
#' @examples
#' \dontrun{
#' with_datatable_state(input, "my_table", saved_page, saved_search, session, {
#'   # Modify data
#'   data <- local_data()
#'   data$my_table <- updated_data
#'   local_data(data)
#' })
#' }
with_datatable_state <- function(input, table_id, saved_page, saved_search, session, action, delay_ms = 100) {
  # Save state before action
  save_datatable_state(input, table_id, saved_page, saved_search)

  # Execute action
  result <- action

  # Restore state after action
  restore_datatable_state(table_id, saved_page, saved_search, session, delay_ms)

  invisible(result)
}
