#' Application UI
#'
#' @description Main UI function for the INDICATE application
#'
#' @return Shiny UI
#' @noRd
#'
#' @importFrom shiny fluidPage tags
#' @importFrom htmltools tagList
app_ui <- function() {
  fluidPage(
    # CSS and JavaScript dependencies
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "www/style.css"),
      tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.12.1/jquery-ui.min.js"),
      tags$script(src = "www/resizable_splitter.js")
    ),

    # Dictionary Explorer Module
    mod_dictionary_explorer_ui("dictionary_explorer")
  )
}
