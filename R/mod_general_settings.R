# MODULE STRUCTURE OVERVIEW ====
#
# This module manages general application settings
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### OHDSI Vocabularies - Browse and select vocabulary folder
#      ### DuckDB Database Status - Display database status and controls
#      ### OHDSI Relationships Mappings - Load/Reload mappings from vocabulary relationships
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Folder Browser State - Track current path, selection, sort order
#      ### DuckDB Status - Processing status and messages
#      ### OHDSI Mappings Status - Processing status and last sync time
#
#   ## 2) Server - Folder Browser
#      ### Folder Path Display - Show selected folder path
#      ### Browser Modal - Modal dialog for folder selection
#      ### File Browser Rendering - Display folders and files
#      ### Navigation Handlers - Handle folder navigation and selection
#
#   ## 3) Server - DuckDB Management
#      ### Database Creation - Create DuckDB from CSV files
#      ### Database Recreation - Recreate existing database
#      ### Status Display - Show database status and controls
#
#   ## 4) Server - OHDSI Relationships Mappings
#      ### Load Mappings - Initial load from vocabulary relationships
#      ### Reload Mappings - Reload while preserving recommended status
#      ### Status Display - Show last sync time and controls

# UI SECTION ====

#' General Settings Module - UI
#'
#' @description UI function for general settings
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS fluidRow column h3 h4 p textOutput actionButton uiOutput
#' @importFrom htmltools tags tagList
mod_general_settings_ui <- function(id) {
  ns <- NS(id)

  tagList(
    ## UI - Main Layout ----
    div(class = "main-panel",
      div(class = "main-content",
        fluidRow(
          column(12,
             div(class = "settings-section",
                 style = "background: #fff; padding: 20px; border-radius: 8px; margin-top: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
                 h4(
                   tags$i(class = "fas fa-folder-open", style = "margin-right: 8px;"),
                   "OHDSI Vocabularies"
                 ),
                 p(
                   style = "color: #666; margin-bottom: 15px;",
                   "Browse and select the folder containing your OHDSI Vocabularies files."
                 ),

                 # Browse button and selected folder display
                 tags$div(
                   style = "display: flex; align-items: center; gap: 15px;",
                   actionButton(
                     ns("browse_folder"),
                     label = tagList(
                       tags$i(class = "fas fa-folder-open", style = "margin-right: 6px;"),
                       "Browse..."
                     ),
                     style = "background: #0f60af; color: white; border: none; padding: 10px 20px; border-radius: 6px; font-weight: 500; cursor: pointer;"
                   ),
                   tags$div(
                     style = "flex: 1;",
                     uiOutput(ns("folder_path_display"))
                   )
                 ),

                 tags$div(
                   style = "margin-top: 15px; padding: 12px; background: #e6f3ff; border-left: 4px solid #0f60af; border-radius: 4px;",
                   tags$p(
                     style = "margin: 0; font-size: 13px; color: #333;",
                     tags$i(class = "fas fa-info-circle", style = "margin-right: 6px; color: #0f60af;"),
                     tags$strong("Note:"), " The OHDSI Vocabularies can be downloaded from ",
                     tags$a(
                       href = "https://athena.ohdsi.org/",
                       target = "_blank",
                       "ATHENA",
                       style = "color: #0f60af; text-decoration: underline;"
                     ),
                     " (registration required)."
                   )
                 ),

                 # DuckDB status
                 tags$div(
                   style = "margin-top: 20px; padding: 15px; background: #f8f9fa; border-radius: 6px; border: 1px solid #dee2e6;",
                   tags$div(
                     style = "margin-bottom: 10px;",
                     tags$div(
                       style = "font-weight: 600; font-size: 14px; color: #333; margin-bottom: 5px;",
                       tags$i(class = "fas fa-database", style = "margin-right: 8px; color: #0f60af;"),
                       "DuckDB Database Status"
                     ),
                     tags$p(
                       style = "margin: 0; font-size: 12px; color: #666;",
                       "A DuckDB database is automatically created from ATHENA CSV files for instant loading at startup."
                     )
                   ),
                   uiOutput(ns("duckdb_status"))
                 ),

                 # OHDSI Relationships Mappings
                 tags$div(
                   style = "margin-top: 20px; padding: 15px; background: #f8f9fa; border-radius: 6px; border: 1px solid #dee2e6;",
                   tags$div(
                     style = "margin-bottom: 10px;",
                     tags$div(
                       style = "font-weight: 600; font-size: 14px; color: #333; margin-bottom: 5px;",
                       tags$i(class = "fas fa-project-diagram", style = "margin-right: 8px; color: #0f60af;"),
                       "OHDSI Relationships Mappings"
                     ),
                     tags$p(
                       style = "margin: 0; font-size: 12px; color: #666;",
                       "Load additional concept mappings from OHDSI vocabulary relationships. This enriches the dictionary with related concepts from standard vocabularies."
                     )
                   ),
                   uiOutput(ns("ohdsi_mappings_status"))
                 )
             )
          )
        )
      )
    )
  )
}

# SERVER SECTION ====

#' General Settings Module - Server
#'
#' @description Server function for general settings
#'
#' @param id Module ID
#' @param config Configuration list
#' @param vocabularies Reactive containing vocabularies data with connection
#' @param reset_vocabularies Function to reset vocabularies to NULL
#' @param set_vocabularies Function to set vocabularies and update loading status
#' @param current_user Reactive containing current user data
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent reactiveVal renderUI showModal modalDialog removeModal observe textInput
mod_general_settings_server <- function(id, config, vocabularies = NULL, reset_vocabularies = NULL, set_vocabularies = NULL, current_user = reactive(NULL), log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ## 1) Server - Reactive Values & State ----

    ### Folder Browser State ----
    current_path <- reactiveVal(path.expand("~"))
    selected_folder <- reactiveVal(NULL)
    sort_order <- reactiveVal("asc")
    filter_text <- reactiveVal("")

    ### DuckDB Status ----
    duckdb_processing <- reactiveVal(FALSE)
    duckdb_message <- reactiveVal(NULL)

    ### OHDSI Mappings Status ----
    ohdsi_mappings_processing <- reactiveVal(FALSE)
    ohdsi_mappings_message <- reactiveVal(NULL)
    ohdsi_mappings_last_sync <- reactiveVal(NULL)

    # Load saved vocab folder from database on initialization
    saved_path <- get_vocab_folder()
    if (!is.null(saved_path) && nchar(saved_path) > 0) {
      selected_folder(saved_path)
    }

    # Load OHDSI mappings last sync time on initialization
    sync_time <- get_ohdsi_mappings_sync()
    ohdsi_mappings_last_sync(sync_time)

    ## 2) Server - Folder Browser ----

    ### Folder Path Display ----

    folder_path_trigger <- reactiveVal(0)

    observe_event(selected_folder(), {
      folder_path_trigger(folder_path_trigger() + 1)
    }, ignoreInit = FALSE)

    observe_event(folder_path_trigger(), {
      folder_path <- selected_folder()

      output$folder_path_display <- renderUI({
        if (is.null(folder_path) || nchar(folder_path) == 0) {
          tags$div(
            style = paste0(
              "font-family: monospace; background: #f8f9fa; ",
              "padding: 10px; border-radius: 4px; font-size: 12px; ",
              "min-height: 40px; display: flex; align-items: center; ",
              "border: 1px solid #dee2e6;"
            ),
            tags$span(
              style = "color: #999;",
              "No folder selected"
            )
          )
        } else {
          tags$div(
            style = paste0(
              "font-family: monospace; background: #e6f3ff; ",
              "padding: 10px; border-radius: 4px; font-size: 12px; ",
              "min-height: 40px; display: flex; align-items: center; ",
              "border: 1px solid #0f60af;"
            ),
            tags$span(
              style = "color: #333;",
              folder_path
            )
          )
        }
      })
    }, ignoreInit = FALSE)

    ### Browser Modal ----

    observe_event(input$browse_folder, {
      # Start at selected folder if it exists, otherwise home
      start_path <- selected_folder()
      if (is.null(start_path) || !dir.exists(start_path)) {
        start_path <- path.expand("~")
      }

      current_path(start_path)
      sort_order("asc")
      filter_text("")
      show_browser_modal()
    }, ignoreInit = FALSE)

    observe_event(input$toggle_sort, {
      if (sort_order() == "asc") {
        sort_order("desc")
      } else {
        sort_order("asc")
      }
    }, ignoreInit = FALSE)

    observe_event(input$filter_input, {
      if (is.null(input$filter_input)) return()
      filter_text(input$filter_input)
    }, ignoreInit = FALSE)

    # Function to show browser modal
    show_browser_modal <- function() {
      showModal(
        modalDialog(
          title = tagList(
            tags$i(class = "fas fa-folder-open", style = "margin-right: 8px;"),
            "Select OHDSI Vocabularies Folder"
          ),
          size = "l",
          easyClose = FALSE,

          # Current path and home button
          tags$div(
            style = "display: flex; align-items: center; gap: 10px; margin-bottom: 10px;",
            tags$div(
              style = "flex: 1; font-family: monospace; background: #f8f9fa; padding: 8px 12px; border-radius: 4px; font-size: 12px; border: 1px solid #dee2e6;",
              uiOutput(ns("current_path"))
            ),
            actionButton(
              ns("go_home"),
              label = tags$i(class = "fas fa-home"),
              style = "padding: 8px 12px; border-radius: 4px; background: #6c757d; color: white; border: none;"
            )
          ),

          # Search filter
          tags$div(
            style = "margin-bottom: 10px;",
            textInput(
              ns("filter_input"),
              label = NULL,
              placeholder = "Search folders and files...",
              width = "100%"
            )
          ),

          # File browser with table header
          tags$div(
            style = paste0(
              "border: 1px solid #dee2e6; border-radius: 4px; ",
              "background: white; height: 400px; overflow-y: auto;"
            ),
            # Table header
            tags$div(
              style = "background: #f8f9fa; border-bottom: 2px solid #dee2e6; position: sticky; top: 0; z-index: 10;",
              tags$div(
                class = "file-browser-header",
                style = "padding: 10px 12px; cursor: pointer; display: flex; align-items: center; gap: 6px; font-weight: 600; color: #333;",
                onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("toggle_sort")),
                tags$span("Nom"),
                uiOutput(ns("sort_icon"), inline = TRUE)
              )
            ),
            # File list
            uiOutput(ns("file_browser"))
          ),

          footer = tagList(
            actionButton(ns("cancel_browse"), "Cancel"),
            tags$span(style = "margin-left: 10px;")
          )
        )
      )
    }

    ### File Browser Rendering ----

    current_path_trigger <- reactiveVal(0)

    observe_event(current_path(), {
      current_path_trigger(current_path_trigger() + 1)
    }, ignoreInit = FALSE)

    observe_event(current_path_trigger(), {
      output$current_path <- renderUI({
        tags$span(current_path())
      })
    }, ignoreInit = FALSE)

    sort_order_trigger <- reactiveVal(0)

    observe_event(sort_order(), {
      sort_order_trigger(sort_order_trigger() + 1)
    }, ignoreInit = FALSE)

    observe_event(sort_order_trigger(), {
      output$sort_icon <- renderUI({
        if (sort_order() == "asc") {
          tags$i(class = "fas fa-sort-alpha-down", title = "Sort A-Z")
        } else {
          tags$i(class = "fas fa-sort-alpha-up", title = "Sort Z-A")
        }
      })
    }, ignoreInit = FALSE)

    observe_event(input$go_home, {
      current_path(path.expand("~"))
    }, ignoreInit = FALSE)

    file_browser_trigger <- reactiveVal(0)

    observe_event(list(current_path(), filter_text(), sort_order()), {
      file_browser_trigger(file_browser_trigger() + 1)
    }, ignoreInit = FALSE)

    observe_event(file_browser_trigger(), {
      path <- current_path()
      filter <- filter_text()
      order <- sort_order()

      output$file_browser <- renderUI({
        items <- list.files(path, full.names = TRUE, include.dirs = TRUE)

        if (length(items) == 0) {
          return(
            tags$div(
              style = "padding: 20px; text-align: center; color: #999;",
              tags$i(class = "fas fa-folder-open", style = "font-size: 32px; margin-bottom: 10px;"),
              tags$p("Empty folder")
            )
          )
        }

        # Separate directories and files
        is_dir <- file.info(items)$isdir
        dirs <- items[is_dir]
        files <- items[!is_dir]

        # Apply filter if present
        if (!is.null(filter) && nchar(filter) > 0) {
          dirs <- dirs[grepl(filter, basename(dirs), ignore.case = TRUE)]
          files <- files[grepl(filter, basename(files), ignore.case = TRUE)]
        }

        # Sort based on order
        if (order == "asc") {
          dirs <- sort(dirs)
          files <- sort(files)
        } else {
          dirs <- sort(dirs, decreasing = TRUE)
          files <- sort(files, decreasing = TRUE)
        }

        # Check if filtered results are empty
        if (length(dirs) == 0 && length(files) == 0) {
          return(
            tags$div(
              style = "padding: 20px; text-align: center; color: #999;",
              tags$i(class = "fas fa-search", style = "font-size: 32px; margin-bottom: 10px;"),
              tags$p("No items match your search")
            )
          )
        }

        # Create list items
        items_ui <- list()

        # Add parent directory link if not at root
        if (path != "/" && path != path.expand("~")) {
          parent_path <- dirname(path)
          items_ui <- append(items_ui, list(
            tags$div(
              class = "file-browser-item",
              style = "padding: 8px 12px; cursor: pointer; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid #f0f0f0;",
              onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("navigate_to"), parent_path),
              tags$i(class = "fas fa-level-up-alt", style = "color: #6c757d; width: 16px;"),
              tags$span("..", style = "font-weight: 500; color: #333;")
            )
          ))
        }

        # Add directories
        for (dir in dirs) {
          dir_name <- basename(dir)
          items_ui <- append(items_ui, list(
            tags$div(
              class = "file-browser-item file-browser-folder",
              style = "padding: 8px 12px; cursor: pointer; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid #f0f0f0;",
              `data-path` = dir,
              tags$i(class = "fas fa-folder", style = "color: #f4c430; width: 16px;"),
              tags$span(dir_name, style = "flex: 1; color: #333;"),
              actionButton(
                ns(paste0("select_", gsub("[^a-zA-Z0-9]", "_", dir))),
                "Select",
                style = "padding: 4px 12px; font-size: 11px; background: #0f60af; color: white; border: none; border-radius: 4px;",
                onclick = sprintf("event.stopPropagation(); Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("select_folder_path"), dir)
              )
            )
          ))
        }

        # Add files (grayed out, non-clickable)
        for (file in files) {
          file_name <- basename(file)
          items_ui <- append(items_ui, list(
            tags$div(
              class = "file-browser-item",
              style = "padding: 8px 12px; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid #f0f0f0; opacity: 0.5;",
              tags$i(class = "fas fa-file", style = "color: #333; width: 16px;"),
              tags$span(file_name, style = "color: #666;")
            )
          ))
        }

        tagList(items_ui)
      })
    }, ignoreInit = FALSE)

    ### Navigation Handlers ----

    observe_event(input$navigate_to, {
      new_path <- input$navigate_to
      if (dir.exists(new_path)) {
        current_path(new_path)
      }
    }, ignoreInit = FALSE)

    observe_event(input$select_folder_path, {
      folder_path <- input$select_folder_path
      if (dir.exists(folder_path)) {
        # Update reactive value
        selected_folder(folder_path)

        # Save to database
        set_vocab_folder(folder_path)

        # Close modal
        removeModal()

        # Check if DuckDB database needs to be created or loaded
        if (!duckdb_exists()) {
          # Set processing status to update UI immediately
          duckdb_processing(TRUE)
          duckdb_message(NULL)

          # Use shinyjs::delay to trigger creation after UI updates
          shinyjs::delay(100, {
            shinyjs::runjs(sprintf(
              "Shiny.setInputValue('%s', Math.random(), {priority: 'event'})",
              session$ns("trigger_duckdb_creation")
            ))
          })
        } else {
          # Database exists - load it immediately
          set_use_duckdb(TRUE)
          vocab_data <- load_vocabularies_from_duckdb()
          if (!is.null(set_vocabularies)) {
            set_vocabularies(vocab_data)
          }
        }
      }
    }, ignoreInit = FALSE)

    ## 3) Server - DuckDB Management ----

    ### Database Creation ----

    observe_event(input$trigger_duckdb_creation, {
      tryCatch({
        vocab_folder <- selected_folder()

        if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
          duckdb_processing(FALSE)
          return()
        }

        # Close DuckDB connection if it exists
        if (!is.null(vocabularies)) {
          vocab_data <- vocabularies()
          if (!is.null(vocab_data) && !is.null(vocab_data$connection)) {
            try(DBI::dbDisconnect(vocab_data$connection, shutdown = TRUE), silent = TRUE)
          }
        }

        # Reset vocabularies to NULL
        if (!is.null(reset_vocabularies)) {
          reset_vocabularies()
        }

        # Try to close all DuckDB connections globally
        tryCatch({
          all_cons <- DBI::dbListConnections(duckdb::duckdb())
          for (con in all_cons) {
            try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
          }
        }, error = function(e) {
          # Ignore errors from dbListConnections
        })

        # Force garbage collection and wait
        gc()
        gc()
        Sys.sleep(1.5)

        # Create DuckDB database
        result <- create_duckdb_database(vocab_folder)

        duckdb_processing(FALSE)

        # Save setting and load vocabularies if successful
        if (result$success) {
          set_use_duckdb(TRUE)
          duckdb_message(NULL)

          # Load vocabularies immediately after creation
          vocab_data <- load_vocabularies_from_duckdb()
          if (!is.null(set_vocabularies)) {
            set_vocabularies(vocab_data)
          }
        } else {
          duckdb_message(result)
        }
      }, error = function(e) {
        # Capture any error and display it to the user
        duckdb_processing(FALSE)
        duckdb_message(list(
          success = FALSE,
          message = paste("Error creating DuckDB database:", e$message)
        ))
      })
    }, ignoreInit = FALSE)

    observe_event(input$cancel_browse, {
      removeModal()
    }, ignoreInit = FALSE)

    ### Database Recreation ----

    observe_event(input$recreate_duckdb, {
      vocab_folder <- selected_folder()

      if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
        return()
      }

      # Set processing status to update UI immediately
      duckdb_processing(TRUE)
      duckdb_message(NULL)

      # Use shinyjs::delay to trigger recreation after UI updates
      shinyjs::delay(100, {
        shinyjs::runjs(sprintf(
          "Shiny.setInputValue('%s', Math.random(), {priority: 'event'})",
          session$ns("trigger_duckdb_recreation")
        ))
      })
    }, ignoreInit = FALSE)

    observe_event(input$trigger_duckdb_recreation, {
      tryCatch({
        vocab_folder <- selected_folder()

        if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
          duckdb_processing(FALSE)
          return()
        }

        # Close DuckDB connection if it exists
        if (!is.null(vocabularies)) {
          vocab_data <- vocabularies()
          if (!is.null(vocab_data) && !is.null(vocab_data$connection)) {
            try(DBI::dbDisconnect(vocab_data$connection, shutdown = TRUE), silent = TRUE)
          }
        }

        # Reset vocabularies to NULL
        if (!is.null(reset_vocabularies)) {
          reset_vocabularies()
        }

        # Try to close all DuckDB connections globally
        tryCatch({
          all_cons <- DBI::dbListConnections(duckdb::duckdb())
          for (con in all_cons) {
            try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
          }
        }, error = function(e) {
          # Ignore errors from dbListConnections
        })

        # Force garbage collection and wait
        gc()
        gc()
        Sys.sleep(1.5)

        # Recreate DuckDB database
        result <- create_duckdb_database(vocab_folder)

        duckdb_processing(FALSE)

        # Save setting and load vocabularies if successful
        if (result$success) {
          set_use_duckdb(TRUE)
          duckdb_message(NULL)

          # Load vocabularies immediately after recreation
          vocab_data <- load_vocabularies_from_duckdb()
          if (!is.null(set_vocabularies)) {
            set_vocabularies(vocab_data)
          }
        } else {
          duckdb_message(result)
        }
      }, error = function(e) {
        # Capture any error and display it to the user
        duckdb_processing(FALSE)
        duckdb_message(list(
          success = FALSE,
          message = paste("Error recreating DuckDB database:", e$message)
        ))
      })
    }, ignoreInit = FALSE)

    ### Status Display ----

    duckdb_status_trigger <- reactiveVal(0)

    observe_event(list(selected_folder(), duckdb_processing(), duckdb_message()), {
      duckdb_status_trigger(duckdb_status_trigger() + 1)
    }, ignoreInit = FALSE)

    observe_event(duckdb_status_trigger(), {
      vocab_folder <- selected_folder()

      output$duckdb_status <- renderUI({
        if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
          return(NULL)
        }

        if (duckdb_processing()) {
          return(
          tags$div(
            style = "padding: 10px; background: #fff3cd; border-left: 3px solid #ffc107; border-radius: 4px; font-size: 12px;",
            tags$i(class = "fas fa-spinner fa-spin", style = "margin-right: 6px;"),
            "Creating DuckDB database... This may take a few minutes."
          )
          )
        }

        # Show error message if there was one
        msg <- duckdb_message()
        if (!is.null(msg) && !msg$success) {
          return(
          tags$div(
            style = "padding: 10px; background: #f8d7da; border-left: 3px solid #dc3545; border-radius: 4px; font-size: 12px;",
            tags$i(class = "fas fa-exclamation-circle", style = "margin-right: 6px; color: #dc3545;"),
            msg$message
          )
          )
        }

        # Show current status
        db_exists <- duckdb_exists()
        if (db_exists) {
          db_path <- get_duckdb_path()
          return(
          tags$div(
            style = "padding: 10px; background: #d4edda; border-left: 3px solid #28a745; border-radius: 4px; font-size: 12px; display: flex; align-items: center; gap: 8px;",
            tags$i(class = "fas fa-check-circle", style = "color: #28a745;"),
            tags$span("Database exists: "),
            tags$code(basename(db_path)),
            actionButton(
              ns("recreate_duckdb"),
              label = tagList(
                tags$i(class = "fas fa-redo", style = "margin-right: 6px;"),
                "Recreate"
              ),
              class = "btn-sm",
              style = "background: #fd7e14; color: white; border: none; padding: 4px 12px; border-radius: 4px; font-size: 12px; cursor: pointer;"
            )
          )
          )
        } else {
          return(
            tags$div(
              style = "padding: 10px; background: #f8d7da; border-left: 3px solid #dc3545; border-radius: 4px; font-size: 12px; display: flex; align-items: center; gap: 8px;",
              tags$i(class = "fas fa-times-circle", style = "color: #dc3545;"),
              tags$span("Database does not exist"),
              actionButton(
                ns("recreate_duckdb"),
                label = tagList(
                  tags$i(class = "fas fa-plus", style = "margin-right: 6px;"),
                  "Create"
                ),
                class = "btn-sm",
                style = "background: #28a745; color: white; border: none; padding: 4px 12px; border-radius: 4px; font-size: 12px; cursor: pointer;"
              )
            )
          )
        }
      })
    }, ignoreInit = FALSE)

    ## 4) Server - OHDSI Relationships Mappings ----

    ### Load/Reload Mappings ----

    observe_event(input$load_ohdsi_mappings, {
      # Check if vocabularies are loaded
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) {
        ohdsi_mappings_message(list(success = FALSE, message = "Please load OHDSI vocabularies first."))
        return()
      }

      # Set processing status
      ohdsi_mappings_processing(TRUE)
      ohdsi_mappings_message(NULL)

      # Delay to update UI
      shinyjs::delay(100, {
        # Read current concept_mappings
        concept_mappings_path <- get_package_dir("extdata", "csv", "concept_mappings.csv")
        concept_mappings <- readr::read_csv(concept_mappings_path, show_col_types = FALSE)

        # Check if this is a reload (preserve recommended status)
        is_reload <- !is.null(ohdsi_mappings_last_sync())

        # Load OHDSI relationships
        tryCatch({
          concept_mappings <- load_ohdsi_relationships(
            vocab_data,
            concept_mappings,
            preserve_recommended = is_reload
          )

          # Save to CSV
          readr::write_csv(concept_mappings, concept_mappings_path)

          # Update last sync time
          sync_time <- Sys.time()
          set_ohdsi_mappings_sync(sync_time)
          ohdsi_mappings_last_sync(sync_time)

          ohdsi_mappings_processing(FALSE)
          ohdsi_mappings_message(list(success = TRUE, message = "OHDSI mappings loaded successfully."))
        }, error = function(e) {
          ohdsi_mappings_processing(FALSE)
          ohdsi_mappings_message(list(success = FALSE, message = paste("Error:", e$message)))
        })
      })
    }, ignoreInit = FALSE)

    ### Status Display ----

    ohdsi_mappings_status_trigger <- reactiveVal(0)

    observe_event(list(ohdsi_mappings_processing(), ohdsi_mappings_message(), ohdsi_mappings_last_sync()), {
      ohdsi_mappings_status_trigger(ohdsi_mappings_status_trigger() + 1)
    }, ignoreInit = FALSE)

    observe_event(ohdsi_mappings_status_trigger(), {
      output$ohdsi_mappings_status <- renderUI({
        # Show processing message
        if (ohdsi_mappings_processing()) {
          return(
            tags$div(
              style = "padding: 10px; background: #fff3cd; border-left: 3px solid #ffc107; border-radius: 4px; font-size: 12px;",
              tags$i(class = "fas fa-spinner fa-spin", style = "margin-right: 6px;"),
              "Loading OHDSI relationships mappings... This may take a few minutes."
            )
          )
        }

        # Show error message if there was one
        msg <- ohdsi_mappings_message()
        if (!is.null(msg) && !msg$success) {
          return(
            tags$div(
              style = "padding: 10px; background: #f8d7da; border-left: 3px solid #dc3545; border-radius: 4px; font-size: 12px;",
              tags$i(class = "fas fa-exclamation-circle", style = "margin-right: 6px; color: #dc3545;"),
              msg$message
            )
          )
        }

        # Show success message
        if (!is.null(msg) && msg$success) {
          return(
            tags$div(
              style = "padding: 10px; background: #d4edda; border-left: 3px solid #28a745; border-radius: 4px; font-size: 12px;",
              tags$i(class = "fas fa-check-circle", style = "margin-right: 6px; color: #28a745;"),
              msg$message
            )
          )
        }

        # Show current status
        last_sync <- ohdsi_mappings_last_sync()
        if (!is.null(last_sync)) {
          formatted_time <- format(last_sync, "%Y-%m-%d %H:%M:%S", tz = Sys.timezone())
          return(
            tags$div(
              style = "padding: 10px; background: #d4edda; border-left: 3px solid #28a745; border-radius: 4px; font-size: 12px; display: flex; align-items: center; gap: 8px;",
              tags$i(class = "fas fa-check-circle", style = "color: #28a745;"),
              tags$span("Last synchronized: "),
              tags$code(formatted_time),
              actionButton(
                ns("load_ohdsi_mappings"),
                label = tagList(
                  tags$i(class = "fas fa-sync-alt", style = "margin-right: 6px;"),
                  "Reload"
                ),
                class = "btn-sm",
                style = "background: #fd7e14; color: white; border: none; padding: 4px 12px; border-radius: 4px; font-size: 12px; cursor: pointer;"
              )
            )
          )
        } else {
          # Never synced - show Load button
          return(
            tags$div(
              style = "padding: 10px; background: #e7f3ff; border-left: 3px solid #0f60af; border-radius: 4px; font-size: 12px; display: flex; align-items: center; gap: 8px;",
              tags$i(class = "fas fa-info-circle", style = "color: #0f60af;"),
              tags$span("OHDSI relationships mappings not loaded."),
              actionButton(
                ns("load_ohdsi_mappings"),
                label = tagList(
                  tags$i(class = "fas fa-download", style = "margin-right: 6px;"),
                  "Load"
                ),
                class = "btn-sm",
                style = "background: #0f60af; color: white; border: none; padding: 4px 12px; border-radius: 4px; font-size: 12px; cursor: pointer;"
              )
            )
          )
        }
      })
    }, ignoreInit = FALSE)

    # Return reactive settings
    settings <- reactive({
      list(
        vocab_folder_path = selected_folder()
      )
    })

    return(settings)
  })
}
