#' DataTable Helper Functions
#'
#' @description Business logic helper functions for creating and styling
#' DataTables across the application
#' @noRd

# EMPTY DATATABLE ====

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

# BOOLEAN COLUMN STYLING ====

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
#'     style_yes_no_column("recommended")
#'
#'   # Style multiple columns
#'   dt <- datatable(data) %>%
#'     style_yes_no_column("recommended") %>%
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
#' @description Variant of style_yes_no_column for use cases like coverage status
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
