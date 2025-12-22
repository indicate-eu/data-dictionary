#' Projects Functions
#'
#' @description Functions to manage projects
#' @noRd

#' Get Next Project ID
#'
#' @description Get the next available project ID
#'
#' @param projects_data Current projects data frame
#'
#' @return Integer representing next ID
#' @noRd
get_next_project_id <- function(projects_data) {
  if (nrow(projects_data) == 0) {
    return(1)
  }
  return(max(projects_data$project_id, na.rm = TRUE) + 1)
}
