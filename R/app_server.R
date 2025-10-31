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
#' @importFrom shiny reactive observeEvent renderUI reactiveVal tags icon observe isolate invalidateLater
#' @importFrom shiny.router router_server
app_server <- function(input, output, session) {

  # Initialize router
  shiny.router::router_server(root_page = "/")

  # Set up debug mode from environment variable
  debug_env <- Sys.getenv("INDICATE_DEBUG_MODE", "")
  log_level <- if (debug_env != "") {
    strsplit(debug_env, ",")[[1]]
  } else {
    character(0)
  }

  # Initialize login module and get current user
  login_module <- mod_login_server("login", log_level = log_level)
  current_user <- login_module$user

  # Track if data has been loaded
  data_loaded <- reactiveVal(FALSE)

  # Track which modules have been initialized
  modules_initialized <- reactiveValues(
    dictionary_explorer = FALSE,
    concept_mapping = FALSE,
    use_cases = FALSE,
    improvements = FALSE,
    dev_tools = FALSE,
    general_settings = FALSE,
    users = FALSE
  )

  # Show main app when user is authenticated and load data
  observe({
    user <- current_user()

    if (!is.null(user)) {
      shinyjs::hide("login_page")
      shinyjs::show("main_app")

      # Load DuckDB data AFTER login (only once)
      if (!data_loaded()) {
        # Get vocabulary folder and DuckDB setting
        vocab_folder <- get_vocab_folder()
        use_duckdb <- get_use_duckdb()

        # If DuckDB is enabled and exists, load asynchronously after UI update
        if (!is.null(vocab_folder) && vocab_folder != "" && use_duckdb && duckdb_exists()) {
          # Set loading status immediately
          vocab_loading_status("loading")

          # Use shinyjs::delay to load after UI has updated
          shinyjs::delay(300, {
            tryCatch({
              vocab_data <- load_vocabularies_from_duckdb()
              vocabularies(vocab_data)
              vocab_loading_status("loaded")
            }, error = function(e) {
              message("Error loading from DuckDB: ", e$message)
              vocab_loading_status("error")
            })
          })
        }

        data_loaded(TRUE)
      }

      # Initialize dictionary_explorer module immediately after login (default page)
      if (!modules_initialized$dictionary_explorer) {
        mod_dictionary_explorer_server(
          "dictionary_explorer",
          data = data,
          config = config,
          vocabularies = reactive({ vocabularies() }),
          vocab_loading_status = reactive({ vocab_loading_status() }),
          current_user = current_user,
          log_level = log_level
        )
        modules_initialized$dictionary_explorer <- TRUE
      }
    } else {
      shinyjs::show("login_page")
      shinyjs::hide("main_app")
    }
  })

  # Observe route changes and initialize modules on demand
  observe({
    # Get current route from shiny.router
    current_route <- session$clientData$url_hash

    # Skip if user not authenticated
    if (is.null(current_user())) return()

    # Initialize modules based on route
    if (!is.null(current_route)) {
      if (grepl("mapping", current_route) && !modules_initialized$concept_mapping) {
        mod_concept_mapping_server(
          "concept_mapping",
          data = data,
          config = config,
          vocabularies = reactive({ vocabularies() }),
          current_user = current_user,
          log_level = log_level
        )
        modules_initialized$concept_mapping <- TRUE
      }

      if (grepl("use-cases", current_route) && !modules_initialized$use_cases) {
        mod_use_cases_server(
          "use_cases",
          data = data,
          vocabularies = reactive({ vocabularies() }),
          current_user = current_user,
          log_level = log_level
        )
        modules_initialized$use_cases <- TRUE
      }

      if (grepl("improvements", current_route) && !modules_initialized$improvements) {
        mod_improvements_server(
          "improvements",
          data = data,
          config = config,
          current_user = current_user,
          log_level = log_level
        )
        modules_initialized$improvements <- TRUE
      }

      if (grepl("dev-tools", current_route) && !modules_initialized$dev_tools) {
        mod_dev_tools_server(
          "dev_tools",
          data = data,
          vocabularies = reactive({ vocabularies() }),
          log_level = log_level
        )
        modules_initialized$dev_tools <- TRUE
      }

      if (grepl("general-settings", current_route) && !modules_initialized$general_settings) {
        mod_general_settings_server(
          "general_settings",
          config = config,
          vocabularies = reactive({ vocabularies() }),
          reset_vocabularies = function() {
            vocabularies(NULL)
            vocab_loading_status("not_loaded")
          },
          set_vocabularies = function(vocab_data) {
            vocabularies(vocab_data)
            vocab_loading_status("loaded")
          },
          current_user = current_user,
          log_level = log_level
        )
        modules_initialized$general_settings <- TRUE
      }

      if (grepl("users", current_route) && !modules_initialized$users) {
        mod_users_server(
          "users",
          current_user = current_user,
          log_level = log_level
        )
        modules_initialized$users <- TRUE
      }
    }
  })

  # Initialize page header module
  header_module <- mod_page_header_server(
    "page_header",
    current_user = current_user,
    vocab_loading_status = reactive({ vocab_loading_status() }),
    log_level = log_level
  )

  # Handle logout from header
  observeEvent(header_module$logout(), {
    req(header_module$logout())

    # Call logout function from login module
    login_module$logout()

    # Reset data loaded flag
    data_loaded(FALSE)

    # Close DuckDB connection if exists
    if (!is.null(vocabularies())) {
      vocab_data <- vocabularies()
      if (!is.null(vocab_data$connection)) {
        tryCatch({
          DBI::dbDisconnect(vocab_data$connection, shutdown = TRUE)
        }, error = function(e) {
          message("Error closing DuckDB connection: ", e$message)
        })
      }
    }

    # Reset vocabularies
    vocabularies(NULL)
    vocab_loading_status("not_loaded")

    # Show login page, hide main app
    shinyjs::show("login_page")
    shinyjs::hide("main_app")
  })

  # Load configuration
  config <- get_config()

  # Load CSV data
  csv_data <- load_csv_data()

  # Create reactive value for data
  data <- reactive({
    csv_data
  })

  # Reactive value to track vocabulary loading status
  vocabularies <- reactiveVal(NULL)
  vocab_loading_status <- reactiveVal("not_loaded")  # "not_loaded", "loading", "loaded", "error"

  # Handle manual loading when user clicks button
  observeEvent(input$load_vocab_data, {
    vocab_folder <- get_vocab_folder()

    if (is.null(vocab_folder) || vocab_folder == "" ||
        !dir.exists(vocab_folder)) {
      vocab_loading_status("error")
      return()
    }

    vocab_loading_status("loading")

    # Load vocabularies synchronously
    result <- load_ohdsi_vocabularies(vocab_folder)

    if (!is.null(result)) {
      vocabularies(result)
      vocab_loading_status("loaded")
    } else {
      vocab_loading_status("error")
    }
  })
}
