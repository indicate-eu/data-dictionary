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
  # Get language from environment variable
  language <- Sys.getenv("INDICATE_LANGUAGE", "en")

  # Initialize i18n translator
  translations_path <- system.file("translations", package = "indicate")
  if (translations_path == "" || !dir.exists(translations_path)) {
    translations_path <- "inst/translations"
  }

  i18n <- suppressWarnings(
    shiny.i18n::Translator$new(translation_csvs_path = translations_path)
  )
  i18n$set_translation_language(language)

  fluidPage(
    # Initialize shinyjs
    shinyjs::useShinyjs(),

    # CSS and JavaScript dependencies
    tags$head(
      tags$title("INDICATE Data Dictionary"),
      tags$link(rel = "icon", type = "image/png", href = "www/favicon.png"),
      tags$link(rel = "stylesheet", type = "text/css", href = "www/style.css"),
      tags$link(
        rel = "stylesheet",
        href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css"
      )
    ),

    # Main application (no login for now - simplified)
    tags$div(
      id = "main_app",
      class = "app-container",

      # Header
      tags$header(
        class = "header",
        tags$div(
          class = "header-left",
          tags$img(src = "www/logo.png", class = "header-logo", alt = "INDICATE"),
          tags$span(class = "header-title", "INDICATE Data Dictionary")
        )
      ),

      # Main content
      tags$div(
        class = "main-wrapper",
        style = "flex: 1; overflow: hidden; display: flex; flex-direction: column;",
        mod_data_dictionary_ui("data_dictionary", i18n)
      ),

      # Footer
      tags$footer(
        class = "app-footer",
        tags$span("INDICATE Data Dictionary v0.1.0")
      )
    )
  )
}

#' Create Page Container
#'
#' @description Helper function to wrap page UI in consistent container
#' @param ui_content UI content for the page
#' @return Wrapped UI
#' @noRd
create_page_container <- function(ui_content) {
  tags$div(
    style = "height: 100%; flex: 1; display: flex; flex-direction: column;",
    ui_content
  )
}
