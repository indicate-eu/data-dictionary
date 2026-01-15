#' Server Utilities
#'
#' @description Utility functions for server-side operations including
#' path resolution, environment management, and system configuration
#' @noRd

#' Get Application Directory Path
#'
#' @description Resolves the application directory path using environment variables
#' or default user configuration directory. Handles both development
#' and production environments.
#'
#' @param subdir Character: Subdirectory name (e.g., "concept_mapping").
#'   If NULL, returns the base application directory (indicate_files/).
#' @param create Logical: Create directory if it doesn't exist (default TRUE)
#'
#' @return Character: Full path to the application directory
#' @noRd
#'
#' @examples
#' \dontrun{
#'   # Get base application directory
#'   app_dir <- get_app_dir()
#'
#'   # Get concept mapping directory
#'   mapping_dir <- get_app_dir("concept_mapping")
#'
#'   # Get database directory
#'   db_dir <- get_app_dir()
#'   db_path <- file.path(db_dir, "indicate.db")
#'
#'   # Get path without creating directory
#'   temp_dir <- get_app_dir("temp", create = FALSE)
#' }
get_app_dir <- function(subdir = NULL, create = TRUE) {
  # Check for custom application folder in environment
  app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)

  if (is.na(app_folder) || app_folder == "") {
    # Use default user configuration directory
    base_dir <- rappdirs::user_config_dir("indicate")
  } else {
    # Use custom application folder
    base_dir <- file.path(app_folder, "indicate_files")
  }

  # Append subdirectory if specified
  if (!is.null(subdir)) {
    base_dir <- file.path(base_dir, subdir)
  }

  # Create directory if requested and doesn't exist
  if (create && !dir.exists(base_dir)) {
    dir.create(base_dir, recursive = TRUE, showWarnings = FALSE)
  }

  return(base_dir)
}

#' Get Path to Package Resources
#'
#' @description Get the path to package resources (inst/extdata, inst/www directories)
#' in the installed package directory. Use get_app_dir() for user data files.
#'
#' @param ... Path components to append after the package directory
#'
#' @return Full path to the requested package resource
#' @noRd
get_package_dir <- function(...) {
  system.file(..., package = "indicate")
}

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

    # Show notification to user
    showNotification(
      ui = paste0("An error occurred: ", e$message),
      type = "error",
      duration = 10
    )
  })
}


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

#' Build Concept Details JSON
#'
#' @description Creates a JSON object with detailed information about a concept,
#' including mapping details and vocabulary information
#'
#' @param concept_mapping Data frame: Single row from concept_mappings table
#' @param general_concept_info Data frame: Single row from general_concepts table
#' @param concept_details Data frame: Single row from OMOP vocabularies concept table
#' @param concept_stats Data frame: Unused, kept for backward compatibility
#'
#' @return List: Structured data ready for JSON conversion
#' @noRd
build_concept_details_json <- function(concept_mapping = NULL,
                                       general_concept_info = NULL,
                                       concept_details = NULL,
                                       concept_stats = NULL) {

  json_data <- list()

  if (!is.null(concept_mapping) && nrow(concept_mapping) > 0) {
    info <- concept_mapping[1, ]

    json_data$concept_name <- if (!is.null(concept_details)) concept_details$concept_name else info$concept_name
    json_data$category <- if (!is.null(general_concept_info) && nrow(general_concept_info) > 0) general_concept_info$category[1] else NA
    json_data$subcategory <- if (!is.null(general_concept_info) && nrow(general_concept_info) > 0) general_concept_info$subcategory[1] else NA
    json_data$vocabulary_id <- if (!is.null(concept_details)) concept_details$vocabulary_id else info$vocabulary_id
    json_data$domain_id <- if (!is.null(concept_details)) concept_details$domain_id else NA
    json_data$concept_code <- if (!is.null(concept_details)) concept_details$concept_code else info$concept_code
    json_data$omop_concept_id <- info$omop_concept_id
    json_data$validity <- if (!is.null(concept_details)) {
      if (is.na(concept_details$invalid_reason) || concept_details$invalid_reason == "") "Valid" else paste0("Invalid (", concept_details$invalid_reason, ")")
    } else NA
    json_data$standard <- if (!is.null(concept_details)) {
      if (!is.na(concept_details$standard_concept) && concept_details$standard_concept == "S") "Standard" else "Non-standard"
    } else NA
    json_data$unit_concept_name <- if ("unit" %in% colnames(info) && !is.null(info$unit) && !is.na(info$unit) && info$unit != "") info$unit else NA
    json_data$omop_unit_concept_id <- if ("omop_unit_concept_id" %in% colnames(info) && !is.null(info$omop_unit_concept_id) && !is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "") info$omop_unit_concept_id else NA

  } else if (!is.null(concept_details)) {
    # OHDSI-only concept
    json_data$concept_name <- concept_details$concept_name
    json_data$category <- if (!is.null(general_concept_info) && nrow(general_concept_info) > 0) general_concept_info$category[1] else NA
    json_data$subcategory <- if (!is.null(general_concept_info) && nrow(general_concept_info) > 0) general_concept_info$subcategory[1] else NA
    json_data$vocabulary_id <- concept_details$vocabulary_id
    json_data$domain_id <- concept_details$domain_id
    json_data$concept_code <- concept_details$concept_code
    json_data$omop_concept_id <- concept_details$concept_id
    json_data$validity <- if (is.na(concept_details$invalid_reason) || concept_details$invalid_reason == "") "Valid" else paste0("Invalid (", concept_details$invalid_reason, ")")
    json_data$standard <- if (!is.na(concept_details$standard_concept) && concept_details$standard_concept == "S") "Standard" else "Non-standard"
    json_data$unit_concept_name <- NA
    json_data$omop_unit_concept_id <- NA
  }

  return(json_data)
}