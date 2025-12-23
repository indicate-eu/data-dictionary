#' DataTable Functions
#'
#' @description Helper functions for DataTables including state management
#' and business logic helpers
#' @noRd


#' Create Empty DataTable
#'
#' @description Creates a standardized empty DataTable with a message,
#' commonly used when no data is available or no selection has been made.
#'
#' @param message Character: Message to display in the table
#' @param column_name Character: Column name for the message (default "Message")
#'
#' @return DT datatable object with single message row
#'
#' @examples
#' \dontrun{
#'   # No data available
#'   if (nrow(data) == 0) {
#'     return(create_empty_datatable("No data available"))
#'   }
#'
#'   # No selection made
#'   if (is.null(selected_id)) {
#'     return(create_empty_datatable("Select a concept to view details"))
#'   }
#'
#'   # Custom column name
#'   create_empty_datatable("No mappings created yet.", column_name = "Status")
#' }
#'
#' @noRd
create_empty_datatable <- function(message, column_name = "Message") {
  # Create data frame with single column
  df <- data.frame(x = message, stringsAsFactors = FALSE)
  colnames(df) <- column_name
  
  # Return datatable with minimal UI (no pagination, no search)
  DT::datatable(
    df,
    options = list(dom = 't'),
    rownames = FALSE,
    selection = 'none'
  )
}

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

#' Apply Yes/No Boolean Styling to DataTable Column
#'
#' @description Applies standardized styling to Yes/No boolean columns in DataTables.
#' Creates green highlighting for "Yes" values and gray for "No" values with
#' appropriate text colors and font weights.
#'
#' @param dt DT datatable object to modify
#' @param column Character: Column name to style
#' @param yes_color Character: Background color for "Yes" (default "#d4edda" - light green)
#' @param no_color Character: Background color for "No" (default "#f8f9fa" - light gray)
#'
#' @return Modified datatable object with formatting applied
#'
#' @examples
#' \dontrun{
#'   # Style a single column
#'   dt <- datatable(data) %>%
#'     style_yes_no_column("is_required")
#'
#'   # Style multiple columns
#'   dt <- datatable(data) %>%
#'     style_yes_no_column("is_required") %>%
#'     style_yes_no_column("is_active")
#'
#'   # Custom colors
#'   dt <- datatable(data) %>%
#'     style_yes_no_column("status", yes_color = "#c3e6cb", no_color = "#f5c6cb")
#' }
#'
#' @noRd
style_yes_no_column <- function(dt, column,
                                yes_color = "#d4edda",
                                no_color = "#f8f9fa") {
  dt %>%
    DT::formatStyle(
      column,
      target = "cell",
      backgroundColor = DT::styleEqual(
        c("Yes", "No"),
        c(yes_color, no_color)
      ),
      fontWeight = DT::styleEqual(
        c("Yes", "No"),
        c("bold", "normal")
      ),
      color = DT::styleEqual(
        c("Yes", "No"),
        c("#155724", "#666")
      )
    )
}

#' Apply Yes/No Styling with Custom Colors
#'
#' @description Variant of style_yes_no_column for projects like coverage status
#' where "No" should be highlighted with a warning color (red) instead of neutral gray.
#'
#' @param dt DT datatable object to modify
#' @param column Character: Column name to style
#' @param yes_bg Character: Background color for "Yes" (default "#d4edda" - light green)
#' @param no_bg Character: Background color for "No" (default "#f8d7da" - light red)
#' @param yes_text Character: Text color for "Yes" (default "#155724" - dark green)
#' @param no_text Character: Text color for "No" (default "#721c24" - dark red)
#'
#' @return Modified datatable object with formatting applied
#'
#' @examples
#' \dontrun{
#'   # Style coverage column with red for incomplete
#'   dt <- datatable(data) %>%
#'     style_yes_no_custom("covered",
#'                         yes_bg = "#d4edda", no_bg = "#f8d7da",
#'                         yes_text = "#155724", no_text = "#721c24")
#' }
#'
#' @noRd
style_yes_no_custom <- function(dt, column,
                                yes_bg = "#d4edda", no_bg = "#f8d7da",
                                yes_text = "#155724", no_text = "#721c24") {
  dt %>%
    DT::formatStyle(
      column,
      backgroundColor = DT::styleEqual(
        c("Yes", "No"),
        c(yes_bg, no_bg)
      ),
      color = DT::styleEqual(
        c("Yes", "No"),
        c(yes_text, no_text)
      ),
      fontWeight = "bold"
    )
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
