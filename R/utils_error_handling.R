#' Enhanced observeEvent with error handling and logging
#'
#' @description A wrapper around shiny's observeEvent that automatically includes
#' error handling via try_catch. Captures expressions and forwards them to try_catch
#' for consistent error handling and logging across the application.
#'
#' @param eventExpr Expression. The event expression to observe.
#' @param handlerExpr Expression. The handler expression to execute when event triggers.
#' @param log Logical. Whether to log events (default: TRUE).
#' @param ... Additional arguments passed to observeEvent.
#'
#' @return Observer object from observeEvent.
#'
#' @examples
#' \dontrun{
#' observe_event(input$button, {
#'   print("Button clicked")
#' })
#' }
#'
#' @noRd
observe_event <- function(eventExpr, handlerExpr, log = TRUE, ...) {

  # Capture expressions and environment
  event_expr <- substitute(eventExpr)
  handler_expr <- substitute(handlerExpr)
  trigger_name <- paste(deparse(event_expr), collapse = " ")

  # Build the call manually
  call_args <- list(
    event_expr,
    substitute(
      try_catch(trigger_name, handler_expr, log),
      list(trigger_name = trigger_name, handler_expr = handler_expr, log = log)
    )
  )

  # Add extra arguments
  call_args <- c(call_args, list(...))

  # Execute the call in the parent environment
  do.call("observeEvent", call_args, envir = parent.frame())
}

#' Enhanced error handling with logging
#'
#' @description Provides comprehensive error handling for Shiny observer functions
#' with automatic logging and user feedback. Handles both event logging and error
#' reporting based on the debug_mode setting.
#'
#' @param trigger Character. Name of the trigger that initiated the code execution.
#' @param code Expression. The code block to execute with error handling.
#' @param log Logical. Whether to log events and errors (default: TRUE).
#'
#' @return Result of code execution, or NULL if error occurs.
#'
#' @details
#' The function automatically imports necessary variables from the parent environment
#' including log_level and module id.
#'
#' Error messages are logged to the console when debug_mode includes "error".
#' Event messages are logged to the console when debug_mode includes "event".
#'
#' @examples
#' \dontrun{
#' try_catch("input$button", {
#'   # Some risky operation
#'   result <- process_data()
#'   return(result)
#' })
#' }
#'
#' @noRd
try_catch <- function(trigger = character(), code, log = TRUE){

  # Import variables from parent environment
  for (obj_name in c("id", "log_level")){
    if (exists(obj_name, envir = parent.frame())){
      assign(obj_name, get(obj_name, envir = parent.frame()))
    }
  }

  # Create log messages with formatted timestamp (without milliseconds)
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  if (exists("id")){
    event_message <- paste0("\n[", timestamp, "] [EVENT] [module_id = ", id, "] event triggered by ", trigger)
    error_message <- paste0("\n[", timestamp, "] [ERROR] [module_id = ", id, "] error with trigger ", trigger, " - error = ")
  }
  else {
    event_message <- paste0("\n[", timestamp, "] [EVENT] event triggered by ", trigger)
    error_message <- paste0("\n[", timestamp, "] [ERROR] error with trigger ", trigger, " - error = ")
  }

  tryCatch({

    # Log event if enabled
    if (log && exists("log_level") && "event" %in% log_level) cat(event_message)

    # Execute code
    code
  }, error = function(e){
    # Log error if enabled
    if (exists("log_level") && "error" %in% log_level){
      cat(paste0(error_message, toString(e)))
    }
  })
}
