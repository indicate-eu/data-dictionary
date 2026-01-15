#' Application UI
#'
#' @description Main UI function for the INDICATE application
#'
#' @return Shiny UI
#' @noRd
#'
#' @importFrom shiny fluidPage tags uiOutput
#' @importFrom htmltools tagList
#' @importFrom shiny.router router_ui route
app_ui <- function() {
  # Get language from environment variable (set by run_app)
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
      tags$link(
        rel = "icon",
        type = "image/png",
        href = "www/favicon.png"
      ),
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "www/style.css"
      ),
      tags$link(
        rel = "stylesheet",
        href = paste0(
          "https://cdnjs.cloudflare.com/ajax/libs/",
          "font-awesome/6.0.0/css/all.min.css"
        )
      ),
      tags$script(
        src = paste0(
          "https://cdnjs.cloudflare.com/ajax/libs/",
          "jqueryui/1.12.1/jquery-ui.min.js"
        )
      ),
      tags$script(
        src = "https://cdn.datatables.net/plug-ins/2.2.1/filtering/type-based/accent-neutralise.js"
      ),
      tags$script(src = "www/resizable_splitter.js"),
      tags$script(src = "www/folder_display.js"),
      tags$script(src = "www/view_details.js"),
      tags$script(src = "www/settings_menu.js"),
      tags$script(src = "www/prevent_doubleclick_selection.js"),
      tags$script(src = "www/login_handler.js"),
      tags$script(src = "www/users_table.js"),
      tags$script(src = "www/evaluate_mappings.js"),
      tags$script(src = "www/clipboard.js"),
      tags$script(src = "www/copy_menu.js"),
      tags$script(src = "www/comments_scroll_sync.js"),
      tags$script(src = "www/selectize_modal_fix.js")
    ),

    # Login page (shown first)
    div(
      id = "login_page",
      mod_login_ui("login", i18n)
    ),

    # Main application (hidden until authenticated)
    div(
      id = "main_app",
      style = "display: none;",

      # Page header module
      mod_page_header_ui("page_header", i18n),

      # Main content wrapper with router
      tags$div(
        style = "flex: 1; overflow: hidden; display: flex; flex-direction: column;",
        # Router with all routes
        router_ui(
          route("/", create_page_container(mod_dictionary_explorer_ui("dictionary_explorer", i18n))),
          route("projects", create_page_container(mod_projects_ui("projects", i18n))),
          route("mapping", create_page_container(mod_concept_mapping_ui("concept_mapping", i18n))),
          route("improvements", create_page_container(mod_improvements_ui("improvements"))),
          route("dev-tools", create_page_container(mod_dev_tools_ui("dev_tools", i18n))),
          route("general-settings", create_page_container(mod_general_settings_ui("general_settings", i18n))),
          route("dictionary-settings", create_page_container(mod_dictionary_settings_ui("dictionary_settings", i18n))),
          route("users", create_page_container(mod_users_ui("users", i18n)))
        )
      ),

      # Footer
      tags$div(
        class = "app-footer",
        tags$span(
          paste0("INDICATE Data Dictionary v", utils::packageVersion("indicate")),
          style = "margin-right: 15px;"
        ),
        tags$span("|", style = "margin-right: 15px; color: #ccc;"),
        tags$a(
          href = "https://indicate-europe.eu/",
          target = "_blank",
          style = "color: #0f60af; text-decoration: none;",
          "INDICATE Project"
        )
      )
    ) # End main_app div
  )
}

#' Create Page Container
#'
#' @description Helper function to wrap page UI in consistent container
#'
#' @param ui_content UI content for the page
#'
#' @return Wrapped UI
#' @noRd
create_page_container <- function(ui_content) {
  tags$div(
    style = "height: 100%; flex: 1; display: flex; flex-direction: column;",
    ui_content
  )
}
