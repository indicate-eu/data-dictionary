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

  # Get vocabulary folder and DuckDB setting
  vocab_folder <- get_vocab_folder()
  use_duckdb <- get_use_duckdb()

  # If DuckDB is enabled and exists, load synchronously immediately
  if (!is.null(vocab_folder) && vocab_folder != "" && use_duckdb && duckdb_exists(vocab_folder)) {
    isolate({
      tryCatch({
        vocab_data <- load_vocabularies_from_duckdb(vocab_folder)
        vocabularies(vocab_data)
        vocab_loading_status("loaded")
      }, error = function(e) {
        message("Error loading from DuckDB: ", e$message)
        vocab_loading_status("error")
      })
    })
  }

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

  # Render vocabulary loading status indicator
  output$vocab_status_indicator <- renderUI({
    status <- vocab_loading_status()

    if (status == "not_loaded") {
      actionButton(
        "load_vocab_data",
        label = "Load OHDSI Data",
        class = "btn-action"
      )
    } else if (status == "loading") {
      tags$span(
        class = "vocab-status vocab-status-loading",
        "Loading OHDSI data"
      )
    } else if (status == "loaded") {
      tags$span(
        class = "vocab-status vocab-status-loaded",
        icon("check"),
        "OHDSI data loaded"
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

  # Render page content based on current page
  output$page_content <- renderUI({
    if (current_page() == "explorer") {
      mod_dictionary_explorer_ui("dictionary_explorer")
    } else if (current_page() == "mapping") {
      mod_concepts_mapping_ui("concepts_mapping")
    } else if (current_page() == "use_cases") {
      mod_use_cases_ui("use_cases")
    } else if (current_page() == "improvements") {
      mod_improvements_ui("improvements")
    } else if (current_page() == "dev_tools") {
      mod_dev_tools_ui("dev_tools")
    } else if (current_page() == "settings") {
      mod_settings_ui("settings")
    }
  })

  # Call module servers
  mod_dictionary_explorer_server(
    "dictionary_explorer",
    data = data,
    config = config,
    vocabularies = reactive({ vocabularies() })
  )

  mod_concepts_mapping_server(
    "concepts_mapping",
    data = data,
    config = config
  )

  mod_use_cases_server(
    "use_cases",
    data = data
  )

  mod_improvements_server(
    "improvements",
    data = data,
    config = config
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
    page_type = reactive({ settings_page_type() })
  )
}
