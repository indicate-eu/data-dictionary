#' Use Cases Functions
#'
#' @description Functions to manage use cases
#' @noRd

#' Get Next Use Case ID
#'
#' @description Get the next available use case ID
#'
#' @param use_cases_data Current use cases data frame
#'
#' @return Integer representing next ID
#' @noRd
get_next_use_case_id <- function(use_cases_data) {
  if (nrow(use_cases_data) == 0) {
    return(1)
  }
  return(max(use_cases_data$use_case_id, na.rm = TRUE) + 1)
}
