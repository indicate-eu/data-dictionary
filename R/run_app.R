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
  # Set up future plan for parallel processing
  future::plan(future::multisession, workers = 3)

  # Add resource path for www directory
  addResourcePath("www", system.file("www", package = "indicate"))

  # Force browser launch in system default browser
  if (!"launch.browser" %in% names(options)) {
    options$launch.browser <- function(url) {
      message("Opening application in browser: ", url)
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
