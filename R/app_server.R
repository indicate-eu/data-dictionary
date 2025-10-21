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
  vocab_loading_status <- reactiveVal("loading")  # "loading", "loaded", "error"

  # Load OHDSI vocabularies in background
  vocab_folder <- get_vocab_folder()

  if (!is.null(vocab_folder) && vocab_folder != "") {
    # Load in isolate to avoid blocking
    isolate({
      # Start loading in background
      future::future({
        # Load packages in the future session
        library(readr)
        library(dplyr)

        vocab_folder_local <- vocab_folder

        if (is.null(vocab_folder_local) || vocab_folder_local == "" || !dir.exists(vocab_folder_local)) {
          return(NULL)
        }

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
      }, seed = TRUE) -> vocab_future

      # Poll for completion
      observe({
        # Only continue polling if still loading
        if (vocab_loading_status() != "loading") {
          return()
        }

        invalidateLater(500)  # Check every 500ms

        if (future::resolved(vocab_future)) {
          result <- future::value(vocab_future)
          if (!is.null(result)) {
            vocabularies(result)
            vocab_loading_status("loaded")
          } else {
            vocab_loading_status("error")
          }
        }
      })
    })
  } else {
    vocab_loading_status("error")
  }

  # Render vocabulary loading status indicator
  output$vocab_status_indicator <- renderUI({
    status <- vocab_loading_status()

    if (status == "loading") {
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

  # Navigation handlers
  observeEvent(input$nav_explorer, {
    current_page("explorer")
  })

  observeEvent(input$nav_mapping, {
    current_page("mapping")
  })

  observeEvent(input$nav_dev_tools, {
    current_page("dev_tools")
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

  mod_dev_tools_server(
    "dev_tools",
    data = data,
    vocabularies = reactive({ vocabularies() })
  )

  mod_settings_server(
    "settings",
    config = config
  )
}
