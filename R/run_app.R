#' Run the INDICATE Shiny Application
#'
#' @description Launch the INDICATE Minimal Data Dictionary Explorer application
#'
#' @param language Language to use in the app ("en" or "fr"). Default is "en".
#' @param app_folder Path to the folder where application files will be stored.
#'   If NULL (default), uses the user's home directory.
#' @param debug_mode Character vector specifying debug output level.
#'   Can include "event" to log all observer events, "error" to log errors,
#'   or both c("event", "error"). Default is "error" (only log errors).
#' @param port Port used to run the Shiny app. Default is 3838.
#' @param host Host address to run the app on. Default is "0.0.0.0".
#' @param ... Additional arguments passed to \code{\link[shiny]{shinyApp}}
#' @param options A named list of options to pass to \code{\link[shiny]{shinyApp}}.
#'
#' @return A Shiny app object
#' @export
#'
#' @importFrom shiny shinyApp addResourcePath
#'
#' @examples
#' \dontrun{
#' run_app()
#' run_app(language = "fr")
#' run_app(app_folder = "~/Documents/my_indicate_data")
#' run_app(debug_mode = "error")
#' run_app(debug_mode = c("event", "error"))
#' run_app(port = 8080, host = "127.0.0.1")
#' }
run_app <- function(
    language = "en",
    app_folder = NULL,
    debug_mode = "error",
    port = 3838,
    host = "0.0.0.0",
    ...,
    options = list()
) {

  # Validate language

if (!(language %in% c("en", "fr"))) {
    stop("Language must be 'en' or 'fr'")
  }

  # Store language in environment variable
  Sys.setenv(INDICATE_LANGUAGE = language)

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

  # Set Shiny options for port, host, and browser launch
  base::options(shiny.port = port, shiny.host = host, shiny.launch.browser = TRUE)

  # Add resource path for www directory
  addResourcePath("www", system.file("www", package = "indicate"))

  shinyApp(
    ui = app_ui,
    server = app_server,
    options = options,
    ...
  )
}
