#' Shiny Helper Functions
#'
#' @description Helper functions for Shiny applications including
#' code execution and UI visibility management
#'
#' @noRd

#' Execute R Code Safely
#'
#' @description Executes R code in a controlled environment with error handling.
#' Returns a structured result with status, result value, and error message.
#'
#' @param code Character string containing R code to execute
#' @param env Environment in which to evaluate the code (default: new environment)
#'
#' @return List with:
#'   - status: "success", "error", "no_code"
#'   - result: The result of evaluation (NULL if error or no code)
#'   - error_message: Error message if status is "error" (NULL otherwise)
#'
#' @examples
#' \dontrun{
#'   # Successful execution
#'   result <- execute_r_code_safely("1 + 1")
#'   # result$status == "success"
#'   # result$result == 2
#'
#'   # Error handling
#'   result <- execute_r_code_safely("stop('test error')")
#'   # result$status == "error"
#'   # result$error_message contains the error
#'
#'   # Empty code
#'   result <- execute_r_code_safely("")
#'   # result$status == "no_code"
#' }
#'
#' @noRd
execute_r_code_safely <- function(code, env = new.env(parent = globalenv())) {
  # Check for empty or NULL code
  if (is.null(code) || nchar(trimws(code)) == 0) {
    return(list(
      status = "no_code",
      result = NULL,
      error_message = NULL
    ))
  }

  # Evaluate the code with error handling
  result <- tryCatch(
    {
      eval(parse(text = code), envir = env)
    },
    error = function(e) {
      return(list(
        status = "error",
        result = NULL,
        error_message = as.character(e$message)
      ))
    }
  )

  # Check if tryCatch returned an error structure

if (is.list(result) && !is.null(result$status) && result$status == "error") {
    return(result)
  }

  # Success
  return(list(
    status = "success",
    result = result,
    error_message = NULL
  ))
}

#' Determine Button Visibility Based on User Role
#'
#' @description Determines which buttons should be visible based on user role
#' and current view state. Returns a list of button IDs and their visibility.
#'
#' @param user List with user information including 'role' field
#' @param view Character string indicating current view ("list", "detail", etc.)
#' @param edit_mode Logical indicating if currently in edit mode
#' @param button_config Named list mapping view states to button group IDs
#'
#' @return Named list with button IDs as names and TRUE/FALSE for visibility
#'
#' @examples
#' \dontrun{
#'   config <- list(
#'     list_normal = "general_concepts_normal_buttons",
#'     list_edit = "general_concepts_edit_buttons",
#'     detail_normal = "general_concept_detail_action_buttons",
#'     detail_edit = "general_concept_detail_edit_buttons"
#'   )
#'
#'   visibility <- get_button_visibility(
#'     user = list(role = "Administrator"),
#'     view = "list",
#'     edit_mode = FALSE,
#'     button_config = config
#'   )
#'   # visibility$general_concepts_normal_buttons == TRUE
#'   # visibility$general_concepts_edit_buttons == FALSE
#' }
#'
#' @noRd
get_button_visibility <- function(user, view, edit_mode, button_config) {
  # Initialize all buttons as hidden
  visibility <- lapply(button_config, function(x) FALSE)
  names(visibility) <- unlist(button_config)

  # If user is anonymous or NULL, all buttons remain hidden
  if (is.null(user) || user$role == "Anonymous") {
    return(visibility)
  }

  # Determine which buttons to show based on view and edit mode
  if (view == "list") {
    if (!edit_mode) {
      visibility[[button_config$list_normal]] <- TRUE
    } else {
      visibility[[button_config$list_edit]] <- TRUE
    }
  } else if (view == "detail") {
    if (!edit_mode) {
      visibility[[button_config$detail_normal]] <- TRUE
    } else {
      visibility[[button_config$detail_edit]] <- TRUE
    }
  } else if (view %in% c("list_history", "detail_history")) {
    if (!is.null(button_config$back)) {
      visibility[[button_config$back]] <- TRUE
    }
  }

  return(visibility)
}
