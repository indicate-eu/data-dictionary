#' Run the INDICATE Shiny Application
#'
#' @description Launch the INDICATE Minimal Data Dictionary Explorer application
#'
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
#' }
run_app <- function(..., options = list()) {
  # Add resource path for www directory
  addResourcePath("www", system.file("www", package = "indicate"))

  # Force browser launch
  if (!"launch.browser" %in% names(options)) {
    options$launch.browser <- function(url) {
      message("Opening application in browser: ", url)
      utils::browseURL(url)
    }
  }

  shinyApp(
    ui = app_ui,
    server = app_server,
    options = options,
    ...
  )
}
