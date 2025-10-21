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
#' @importFrom shiny reactive observeEvent renderUI reactiveVal
app_server <- function(input, output, session) {

  # Load configuration
  config <- get_config()

  # Load data
  data_dictionary <- load_indicate_data()

  # Create reactive values for data and comments
  data <- reactive({
    data_dictionary$data
  })
  comments <- reactive({
    data_dictionary$comments
  })

  # Track current page
  current_page <- reactiveVal("explorer")

  # Navigation handlers
  observeEvent(input$nav_explorer, {
    current_page("explorer")
  })

  observeEvent(input$nav_mapping, {
    current_page("mapping")
  })

  observeEvent(input$nav_settings, {
    current_page("settings")
  })

  # Render page content based on current page
  output$page_content <- renderUI({
    if (current_page() == "explorer") {
      mod_dictionary_explorer_ui("dictionary_explorer")
    } else if (current_page() == "mapping") {
      mod_concepts_mapping_ui("concepts_mapping")
    } else if (current_page() == "settings") {
      mod_settings_ui("settings")
    }
  })

  # Call module servers
  mod_dictionary_explorer_server(
    "dictionary_explorer",
    data = data,
    comments = comments,
    config = config
  )

  mod_concepts_mapping_server(
    "concepts_mapping",
    data = data,
    config = config
  )

  mod_settings_server(
    "settings",
    config = config
  )
}
