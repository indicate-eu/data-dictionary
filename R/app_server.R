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
#' @importFrom shiny reactive
app_server <- function(input, output, session) {

  # Load configuration
  config <- get_config()

  # Load data
  dataset <- load_indicate_data()

  # Create reactive values for data and comments
  data <- reactive({ dataset$data })
  comments <- reactive({ dataset$comments })

  # Call dictionary explorer module
  mod_dictionary_explorer_server(
    "dictionary_explorer",
    data = data,
    comments = comments,
    config = config
  )
}
