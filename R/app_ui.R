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
      ),
      # Settings dropdown toggle script
      tags$script(HTML("
        $(document).ready(function() {
          $(document).on('click', '[id$=\"nav_settings\"]', function(e) {
            e.stopPropagation();
            var dropdown = $(this).siblings('.settings-dropdown');
            dropdown.toggle();
          });
          $(document).on('click', function(e) {
            if (!$(e.target).closest('.settings-dropdown, [id$=\"nav_settings\"]').length) {
              $('.settings-dropdown').hide();
            }
          });
        });
      "))
    ),

    # Main application container
    tags$div(
      id = "main_app",
      class = "app-container",

      # Header with navigation
      mod_page_header_ui("page_header", i18n),

      # Main content with router
      tags$div(
        class = "main-wrapper",
        style = "flex: 1; overflow: hidden; display: flex; flex-direction: column;",
        shiny.router::router_ui(
          shiny.router::route("/", create_page_container(mod_data_dictionary_ui("data_dictionary", i18n))),
          shiny.router::route("projects", create_page_container(mod_projects_ui("projects", i18n))),
          shiny.router::route("mapping", create_page_container(mod_concept_mapping_ui("concept_mapping", i18n))),
          shiny.router::route("general-settings", create_page_container(mod_general_settings_ui("general_settings", i18n))),
          shiny.router::route("dictionary-settings", create_page_container(mod_dictionary_settings_ui("dictionary_settings", i18n))),
          shiny.router::route("users", create_page_container(mod_users_ui("users", i18n))),
          shiny.router::route("dev-tools", create_page_container(mod_dev_tools_ui("dev_tools", i18n)))
        )
      ),

      # Footer
      tags$footer(
        class = "app-footer",
        tags$span("INDICATE Data Dictionary v0.2.0.9001")
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
