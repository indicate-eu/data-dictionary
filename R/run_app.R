#' Run the INDICATE Shiny Application
#'
#' @description Launch the INDICATE Minimal Data Dictionary Explorer application
#'
#' @param app_folder Path to the folder where application files will be stored.
#'   If NULL (default), uses the user's home directory.
#' @param debug_mode Character vector specifying debug output level.
#'   Can include "event" to log all observer events, "error" to log errors,
#'   or both c("event", "error"). Default is "error" (only log errors).
#' @param ... Additional arguments passed to \code{\link[shiny]{shinyApp}}
#' @param options A named list of options to pass to \code{\link[shiny]{shinyApp}}.
#'   By default, the browser is launched automatically.
#'
#' @return A Shiny app object
#' @export
#'
#' @importFrom shiny shinyApp addResourcePath
#'
#' @examples
#' \dontrun{
#' run_app()
#' run_app(app_folder = "~/Documents/my_indicate_data")
#' run_app(debug_mode = "error")
#' run_app(debug_mode = c("event", "error"))
#' }
run_app <- function(app_folder = NULL, debug_mode = "error", ..., options = list()) {
  # Set app folder for database location
  if (is.null(app_folder)) {
    app_folder <- path.expand("~")
  } else {
    app_folder <- path.expand(app_folder)
  }

  # Store app_folder in an environment variable for use by other functions
  Sys.setenv(INDICATE_APP_FOLDER = app_folder)

  # Store debug_mode in an environment variable for use by server
  if (!is.null(debug_mode)) {
    Sys.setenv(INDICATE_DEBUG_MODE = paste(debug_mode, collapse = ","))
  }

  # Add resource path for www directory
  addResourcePath("www", system.file("www", package = "indicate"))

  # Force browser launch in system default browser
  if (!"launch.browser" %in% names(options)) {
    options$launch.browser <- function(url) {
      # Force open in system default browser (not VSCode)
      system(paste0("open '", url, "'"))
    }
  }

  shinyApp(
    ui = app_ui,
    server = app_server,
    options = options,
    ...
  )
}
