#' DataTable Helper Functions
#'
#' @description Business logic helper functions for creating and styling
#' DataTables across the application
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
