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

  # Initialize router
  shiny.router::router_server(root_page = "/")

  # Current user (for now, a simple guest user)
  current_user <- reactiveVal(list(
    login = "guest",
    first_name = "Guest",
    last_name = "User",
    role = "User"
  ))

  # Initialize header module
  header_result <- mod_page_header_server(
    "page_header",
    i18n = i18n,
    current_user = current_user
  )

  # Handle logout
  observe_event(header_result$logout(), {
    # TODO: Implement logout logic
    showNotification("Logout not implemented yet", type = "message")
  }, ignoreInit = TRUE)

  # Initialize page modules
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
    current_user = current_user
  )
}
