#' Application Server
#'
#' @description Main server function for the INDICATE application
#'
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#'
#' @return Server logic
#' @noRd
#'
#' @importFrom shiny reactive reactiveVal
app_server <- function(input, output, session) {

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

  # Initialize login module
  login_result <- mod_login_server("login", i18n)
  current_user <- login_result$user

  # Show/hide main app based on login state
  observe_event(current_user(), {
    user <- current_user()

    if (!is.null(user)) {
      # User logged in - show main app, hide login
      shinyjs::hide("login_page")
      shinyjs::show("main_app")
    } else {
      # User logged out - show login, hide main app
      shinyjs::show("login_page")
      shinyjs::hide("main_app")
    }
  }, ignoreNULL = FALSE)

  # Load OHDSI vocabularies from DuckDB (if available)
  vocabularies <- reactive({
    load_vocabularies_from_duckdb()
  })

  # Initialize router - must be called once at app startup
  shiny.router::router_server(root_page = "/")

  # Initialize header module
  header_result <- mod_page_header_server(
    "page_header",
    i18n = i18n,
    current_user = current_user
  )

  # Handle logout
  observe_event(header_result$logout(), {
    current_user(NULL)
    session$reload()
  }, ignoreInit = TRUE)

  # Initialize all page modules
  mod_data_dictionary_server(
    "data_dictionary",
    i18n = i18n,
    current_user = current_user
  )

  mod_projects_server(
    "projects",
    i18n = i18n,
    current_user = current_user
  )

  mod_concept_mapping_server(
    "concept_mapping",
    i18n = i18n,
    current_user = current_user
  )

  mod_general_settings_server(
    "general_settings",
    i18n = i18n,
    current_user = current_user
  )

  mod_dictionary_settings_server(
    "dictionary_settings",
    i18n = i18n,
    current_user = current_user
  )

  mod_users_server(
    "users",
    i18n = i18n,
    current_user = current_user
  )

  mod_dev_tools_server(
    "dev_tools",
    i18n = i18n,
    vocabularies = vocabularies,
    current_user = current_user
  )
}
