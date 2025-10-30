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
app_server <- function(input, output, session) {

  # Initialize login module and get current user
  login_module <- mod_login_server("login")
  current_user <- login_module$user

  # Track if data has been loaded
  data_loaded <- reactiveVal(FALSE)

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

      # Hide certain features for anonymous users
      if (user$role == "Anonymous") {
        # Hide pages for anonymous users
        shinyjs::hide("nav_mapping")
        shinyjs::hide("nav_improvements")
        shinyjs::hide("nav_dev_tools")

        # Hide settings menu items except logout
        shinyjs::hide("settings_item_general")
        shinyjs::hide("settings_item_users")
      } else {
        # Show all navigation for authenticated users
        shinyjs::show("nav_mapping")
        shinyjs::show("nav_improvements")
        shinyjs::show("nav_dev_tools")

        # Show all settings menu items
        shinyjs::show("settings_item_general")
        shinyjs::show("settings_item_users")
      }
    } else {
      shinyjs::show("login_page")
      shinyjs::hide("main_app")
    }
  })

  # Handle logout
  observeEvent(input$logout, {
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

  # Display current user in header
  output$current_user_display <- renderUI({
    user <- current_user()

    if (is.null(user)) {
      return(NULL)
    }

    # Build user display name
    if (!is.null(user$first_name) && nchar(user$first_name) > 0) {
      user_name <- paste(user$first_name, user$last_name)
    } else {
      user_name <- user$login
    }

    # Choose icon based on role
    user_icon <- if (user$role == "Anonymous") {
      "user"
    } else {
      "user-circle"
    }

    tags$div(
      class = "current-user-badge",
      style = "display: flex; align-items: center; gap: 8px; padding: 6px 12px; background: #0f60af; border-radius: 20px; color: white; font-size: 14px;",
      tags$i(class = paste0("fas fa-", user_icon), style = "font-size: 16px;"),
      tags$span(
        style = "font-weight: 500;",
        user_name
      )
    )
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
  vocab_future <- reactiveVal(NULL)

  # Handle manual loading when user clicks button
  observeEvent(input$load_vocab_data, {
    vocab_folder <- get_vocab_folder()

    if (is.null(vocab_folder) || vocab_folder == "" || !dir.exists(vocab_folder)) {
      vocab_loading_status("error")
      return()
    }

    vocab_loading_status("loading")

    # Start loading in background
    future::future({
      # Load packages in the future session
      library(readr)
      library(dplyr)

      vocab_folder_local <- vocab_folder

      tryCatch({
        concept_path <- file.path(vocab_folder_local, "CONCEPT.csv")
        concept_relationship_path <- file.path(vocab_folder_local, "CONCEPT_RELATIONSHIP.csv")
        concept_ancestor_path <- file.path(vocab_folder_local, "CONCEPT_ANCESTOR.csv")

        if (!file.exists(concept_path) || !file.exists(concept_relationship_path) || !file.exists(concept_ancestor_path)) {
          return(NULL)
        }

        # Load all three files in parallel
        concept_future <- future::future({
          readr::read_tsv(
            concept_path,
            col_types = readr::cols(
              concept_id = readr::col_integer(),
              concept_name = readr::col_character(),
              domain_id = readr::col_character(),
              vocabulary_id = readr::col_character(),
              concept_class_id = readr::col_character(),
              standard_concept = readr::col_character(),
              concept_code = readr::col_character(),
              invalid_reason = readr::col_character()
            ),
            show_col_types = FALSE
          )
        })

        concept_relationship_future <- future::future({
          readr::read_tsv(
            concept_relationship_path,
            col_types = readr::cols(
              concept_id_1 = readr::col_integer(),
              concept_id_2 = readr::col_integer(),
              relationship_id = readr::col_character()
            ),
            show_col_types = FALSE
          )
        })

        concept_ancestor_future <- future::future({
          readr::read_tsv(
            concept_ancestor_path,
            col_types = readr::cols(
              ancestor_concept_id = readr::col_integer(),
              descendant_concept_id = readr::col_integer()
            ),
            show_col_types = FALSE
          )
        })

        # Wait for all to complete
        concept <- future::value(concept_future)
        concept_relationship <- future::value(concept_relationship_future)
        concept_ancestor <- future::value(concept_ancestor_future)

        list(
          concept = concept,
          concept_relationship = concept_relationship,
          concept_ancestor = concept_ancestor
        )
      }, error = function(e) {
        message("Error loading OHDSI vocabularies: ", e$message)
        NULL
      })
    }, seed = TRUE) -> future_obj

    vocab_future(future_obj)
  })

  # Poll for completion of async loading
  observe({
    future_obj <- vocab_future()

    if (is.null(future_obj) || vocab_loading_status() != "loading") {
      return()
    }

    invalidateLater(500)  # Check every 500ms

    if (future::resolved(future_obj)) {
      result <- future::value(future_obj)
      if (!is.null(result)) {
        vocabularies(result)
        vocab_loading_status("loaded")
      } else {
        vocab_loading_status("error")
      }
      vocab_future(NULL)
    }
  })

  # Show/hide vocabulary status indicator based on loading status
  observe({
    status <- vocab_loading_status()

    if (status == "loaded") {
      shinyjs::hide("vocab_status_indicator")
    } else {
      shinyjs::show("vocab_status_indicator")
    }
  })

  # Render vocabulary loading status indicator
  output$vocab_status_indicator <- renderUI({
    status <- vocab_loading_status()

    if (status == "not_loaded" || status == "error") {
      tags$span(
        class = "vocab-status vocab-status-error has-tooltip",
        style = "color: #dc3545; font-weight: 600; font-size: 14px;",
        `data-tooltip` = "Please configure the OHDSI Vocabularies folder in General Settings.",
        icon("exclamation-triangle"),
        " Need configuration"
      )
    } else if (status == "loading") {
      tags$span(
        class = "vocab-status vocab-status-loading",
        "Loading OHDSI data"
      )
    } else {
      NULL
    }
  })

  # Track current page
  current_page <- reactiveVal("explorer")
  settings_page_type <- reactiveVal("general")

  # Navigation handlers
  observeEvent(input$nav_explorer, {
    current_page("explorer")
  })

  observeEvent(input$nav_mapping, {
    current_page("mapping")
  })

  observeEvent(input$nav_use_cases, {
    current_page("use_cases")
  })

  observeEvent(input$nav_improvements, {
    current_page("improvements")
  })

  observeEvent(input$nav_dev_tools, {
    current_page("dev_tools")
  })

  observeEvent(input$nav_general_settings, {
    settings_page_type("general")
    current_page("settings")
  })

  observeEvent(input$nav_users, {
    settings_page_type("users")
    current_page("settings")
  })

  # Show/hide page content based on current page using shinyjs
  observeEvent(current_page(), {
    # Hide all pages
    shinyjs::hide("page_explorer")
    shinyjs::hide("page_mapping")
    shinyjs::hide("page_use_cases")
    shinyjs::hide("page_improvements")
    shinyjs::hide("page_dev_tools")
    shinyjs::hide("page_settings")

    # Show selected page
    page <- current_page()
    if (page == "explorer") {
      shinyjs::show("page_explorer")
    } else if (page == "mapping") {
      shinyjs::show("page_mapping")
    } else if (page == "use_cases") {
      shinyjs::show("page_use_cases")
    } else if (page == "improvements") {
      shinyjs::show("page_improvements")
    } else if (page == "dev_tools") {
      shinyjs::show("page_dev_tools")
    } else if (page == "settings") {
      shinyjs::show("page_settings")
    }
  }, ignoreInit = FALSE)

  # Call module servers
  mod_dictionary_explorer_server(
    "dictionary_explorer",
    data = data,
    config = config,
    vocabularies = reactive({ vocabularies() }),
    vocab_loading_status = reactive({ vocab_loading_status() }),
    current_user = current_user
  )

  mod_concept_mapping_server(
    "concept_mapping",
    data = data,
    config = config,
    vocabularies = reactive({ vocabularies() }),
    current_user = current_user
  )

  mod_use_cases_server(
    "use_cases",
    data = data,
    vocabularies = reactive({ vocabularies() }),
    current_user = current_user
  )

  mod_improvements_server(
    "improvements",
    data = data,
    config = config,
    current_user = current_user
  )

  mod_dev_tools_server(
    "dev_tools",
    data = data,
    vocabularies = reactive({ vocabularies() })
  )

  mod_settings_server(
    "settings",
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
    page_type = reactive({ settings_page_type() }),
    current_user = current_user
  )
}
