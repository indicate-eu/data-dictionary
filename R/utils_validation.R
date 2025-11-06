#' Input Validation Utilities
#'
#' @description Helper functions for validating user inputs and displaying
#' error messages in Shiny applications
#' @noRd

#' Validate Required Inputs with Error Display
#'
#' @description Validates that required input fields are not empty and shows/hides
#' error messages accordingly. This centralizes the common pattern of checking
#' multiple required fields and displaying validation errors.
#'
#' @param input Shiny input object containing the values to validate
#' @param fields Named list where names are input IDs and values are error element IDs.
#'   Example: list(col_vocabulary_id = "col_vocabulary_id_error", col_concept_code = "col_concept_code_error")
#'
#' @return Logical: TRUE if all fields are valid (not empty), FALSE if any validation fails
#'
#' @details
#' The function performs the following steps:
#' 1. Hides all error messages at the start (clean slate)
#' 2. Checks each field for NULL or empty string values
#' 3. Shows error message for any invalid fields
#' 4. Returns FALSE if any field is invalid, TRUE if all are valid
#'
#' Note: Error element IDs should already be namespaced (e.g., "module-error_id")
#' since shinyjs::show() and shinyjs::hide() work with full DOM IDs.
#'
#' This allows for simple validation patterns like:
#' ```r
#' if (!validate_required_inputs(input, fields)) return()
#' ```
#'
#' @examples
#' \dontrun{
#'   # Basic usage
#'   is_valid <- validate_required_inputs(
#'     input,
#'     fields = list(
#'       alignment_name = "alignment_name_error",
#'       col_vocabulary_id = "col_vocabulary_id_error",
#'       col_concept_code = "col_concept_code_error"
#'     )
#'   )
#'
#'   if (!is_valid) return()
#'
#'   # Continue with valid inputs...
#' }
#'
#' @noRd
validate_required_inputs <- function(input, fields) {
  has_errors <- FALSE

  # Hide all error messages first
  for (error_id in fields) {
    shinyjs::hide(error_id)
  }

  # Check each field
  for (field_id in names(fields)) {
    value <- input[[field_id]]
    if (is.null(value) || value == "") {
      shinyjs::show(fields[[field_id]])
      has_errors <- TRUE
    }
  }

  return(!has_errors)
}
