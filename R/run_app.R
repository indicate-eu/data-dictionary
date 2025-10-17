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
run_app <- function(..., options = list(launch.browser = TRUE)) {
  # Add resource path for www directory
  addResourcePath("www", system.file("www", package = "indicate"))

  shinyApp(
    ui = app_ui,
    server = app_server,
    options = options,
    ...
  )
}
