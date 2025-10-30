#' Settings Module - UI
#'
#' @description UI function for the settings module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS fluidRow column h3 h4 p textOutput actionButton uiOutput
#' @importFrom htmltools tags tagList
mod_settings_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Main content for settings
    div(class = "main-panel",
        div(class = "main-content",
            uiOutput(ns("settings_content"))
        )
    )
  )
}

# Helper function for General Settings content
general_settings_ui <- function(ns) {
  fluidRow(
    column(12,
           div(class = "settings-section",
               style = "background: #fff; padding: 20px; border-radius: 8px; margin-top: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
               h4(
                 tags$i(class = "fas fa-folder-open", style = "margin-right: 8px;"),
                 "OHDSI Vocabularies Location"
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

               # DuckDB status (no manual creation button anymore)
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
               )
           )
    )
  )
}

# Helper function for Users content
users_ui <- function(ns) {
  mod_users_ui(ns("users"))
}

#' Settings Module - Server
#'
#' @description Server function for the settings module
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
mod_settings_server <- function(id, config, vocabularies = NULL, reset_vocabularies = NULL, set_vocabularies = NULL, page_type = reactive("general"), current_user = reactive(NULL)) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Call users module server
    mod_users_server("users", current_user = current_user)

    # Render settings content based on page type
    output$settings_content <- renderUI({
      type <- page_type()

      if (type == "general") {
        general_settings_ui(ns)
      } else if (type == "users") {
        users_ui(ns)
      } else {
        general_settings_ui(ns)
      }
    })

    # Store current browsing path, selected folder, sort order and filter
    current_path <- reactiveVal(path.expand("~"))
    selected_folder <- reactiveVal(NULL)
    sort_order <- reactiveVal("asc")
    filter_text <- reactiveVal("")

    # Load saved vocab folder from database on initialization
    observe({
      tryCatch({
        saved_path <- get_vocab_folder()

        if (!is.null(saved_path) && nchar(saved_path) > 0) {
          selected_folder(saved_path)
        }
      }, error = function(e) {
        message("Error loading vocab folder: ", e$message)
      })
    })


    # Render folder path display
    output$folder_path_display <- renderUI({
      folder_path <- selected_folder()

      if (is.null(folder_path) || nchar(folder_path) == 0) {
        tags$div(
          style = "font-family: monospace; background: #f8f9fa; padding: 10px; border-radius: 4px; font-size: 12px; min-height: 40px; display: flex; align-items: center; border: 1px solid #dee2e6;",
          tags$span(
            style = "color: #999;",
            "No folder selected"
          )
        )
      } else {
        tags$div(
          style = "font-family: monospace; background: #e6f3ff; padding: 10px; border-radius: 4px; font-size: 12px; min-height: 40px; display: flex; align-items: center; border: 1px solid #0f60af;",
          tags$span(
            style = "color: #333;",
            folder_path
          )
        )
      }
    })

    # Show folder browser modal
    observeEvent(input$browse_folder, {
      # Start at selected folder if it exists, otherwise home
      start_path <- selected_folder()
      if (is.null(start_path) || !dir.exists(start_path)) {
        start_path <- path.expand("~")
      }

      current_path(start_path)
      sort_order("asc")
      filter_text("")
      show_browser_modal()
    })

    # Toggle sort order
    observeEvent(input$toggle_sort, {
      if (sort_order() == "asc") {
        sort_order("desc")
      } else {
        sort_order("asc")
      }
    })

    # Update filter text
    observeEvent(input$filter_input, {
      filter_text(input$filter_input)
    })

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
            style = "border: 1px solid #dee2e6; border-radius: 4px; background: white; max-height: 600px; overflow-y: auto;",
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

    # Render current path
    output$current_path <- renderUI({
      tags$span(current_path())
    })

    # Render sort icon
    output$sort_icon <- renderUI({
      if (sort_order() == "asc") {
        tags$i(class = "fas fa-sort-alpha-down", title = "Sort A-Z")
      } else {
        tags$i(class = "fas fa-sort-alpha-up", title = "Sort Z-A")
      }
    })

    # Go to home directory
    observeEvent(input$go_home, {
      current_path(path.expand("~"))
    })

    # Render file browser
    output$file_browser <- renderUI({
      path <- current_path()
      filter <- filter_text()
      order <- sort_order()

      # Get list of files and directories
      tryCatch({
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

      }, error = function(e) {
        tags$div(
          style = "padding: 20px; text-align: center; color: #dc3545;",
          tags$i(class = "fas fa-exclamation-triangle", style = "font-size: 32px; margin-bottom: 10px;"),
          tags$p("Error reading folder"),
          tags$p(style = "font-size: 12px;", as.character(e$message))
        )
      })
    })

    # Handle navigation to folder
    observeEvent(input$navigate_to, {
      new_path <- input$navigate_to
      if (dir.exists(new_path)) {
        current_path(new_path)
      }
    })

    # Handle folder selection
    observeEvent(input$select_folder_path, {
      folder_path <- input$select_folder_path
      if (dir.exists(folder_path)) {
        # Update reactive value (this will trigger renderUI to update)
        selected_folder(folder_path)

        # Save to database
        tryCatch({
          set_vocab_folder(folder_path)
        }, error = function(e) {
          message("Error saving vocab folder: ", e$message)
          showModal(
            modalDialog(
              title = "Error",
              tags$p(
                style = "color: #dc3545;",
                "Failed to save folder path to database: ", e$message
              ),
              easyClose = TRUE
            )
          )
          return()
        })

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
          tryCatch({
            set_use_duckdb(TRUE)
            vocab_data <- load_vocabularies_from_duckdb()
            if (!is.null(set_vocabularies)) {
              set_vocabularies(vocab_data)
            }
          }, error = function(e) {
            message("Error loading existing DuckDB: ", e$message)
            duckdb_message(list(
              success = FALSE,
              message = paste("Failed to load database:", e$message)
            ))
          })
        }
      }
    })

    # Observer to actually create DuckDB database (triggered after UI update)
    observeEvent(input$trigger_duckdb_creation, {
      vocab_folder <- selected_folder()

      if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
        duckdb_processing(FALSE)
        return()
      }

      # Close DuckDB connection if it exists
      if (!is.null(vocabularies)) {
        vocab_data <- vocabularies()
        if (!is.null(vocab_data) && !is.null(vocab_data$connection)) {
          tryCatch({
            DBI::dbDisconnect(vocab_data$connection, shutdown = TRUE)
          }, error = function(e) {
            message("Error closing DuckDB connection: ", e$message)
          })
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
        # Ignore errors
      })

      # Force garbage collection and wait
      gc()
      gc()
      Sys.sleep(1.5)

      # Create DuckDB database
      result <- tryCatch({
        create_duckdb_database(vocab_folder)
      }, error = function(e) {
        list(success = FALSE, message = paste("Error:", e$message))
      })

      duckdb_processing(FALSE)

      # Save setting and load vocabularies if successful
      if (result$success) {
        tryCatch({
          set_use_duckdb(TRUE)
        }, error = function(e) {
          message("Error saving DuckDB option: ", e$message)
        })
        duckdb_message(NULL)

        # Load vocabularies immediately after creation
        tryCatch({
          vocab_data <- load_vocabularies_from_duckdb()
          if (!is.null(set_vocabularies)) {
            set_vocabularies(vocab_data)
          }
        }, error = function(e) {
          message("Error loading vocabularies after creation: ", e$message)
          duckdb_message(list(
            success = FALSE,
            message = paste("Database created but failed to load:", e$message)
          ))
        })
      } else {
        duckdb_message(result)
      }
    })

    # Handle cancel
    observeEvent(input$cancel_browse, {
      removeModal()
    })

    # Reactive value to track DuckDB processing
    duckdb_processing <- reactiveVal(FALSE)
    duckdb_message <- reactiveVal(NULL)

    # Handle DuckDB recreation button
    observeEvent(input$recreate_duckdb, {
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
    })

    # Observer to actually recreate DuckDB database (triggered after UI update)
    observeEvent(input$trigger_duckdb_recreation, {
      vocab_folder <- selected_folder()

      if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
        duckdb_processing(FALSE)
        return()
      }

      # Close DuckDB connection if it exists
      if (!is.null(vocabularies)) {
        vocab_data <- vocabularies()
        if (!is.null(vocab_data) && !is.null(vocab_data$connection)) {
          tryCatch({
            DBI::dbDisconnect(vocab_data$connection, shutdown = TRUE)
          }, error = function(e) {
            message("Error closing DuckDB connection: ", e$message)
          })
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
        # Ignore errors
      })

      # Force garbage collection and wait
      gc()
      gc()
      Sys.sleep(1.5)

      # Recreate DuckDB database (will delete existing one)
      result <- tryCatch({
        create_duckdb_database(vocab_folder)
      }, error = function(e) {
        list(success = FALSE, message = paste("Error:", e$message))
      })

      duckdb_processing(FALSE)

      # Save setting and load vocabularies if successful
      if (result$success) {
        tryCatch({
          set_use_duckdb(TRUE)
        }, error = function(e) {
          message("Error saving DuckDB option: ", e$message)
        })
        duckdb_message(NULL)

        # Load vocabularies immediately after recreation
        tryCatch({
          vocab_data <- load_vocabularies_from_duckdb()
          if (!is.null(set_vocabularies)) {
            set_vocabularies(vocab_data)
          }
        }, error = function(e) {
          message("Error loading vocabularies after recreation: ", e$message)
          duckdb_message(list(
            success = FALSE,
            message = paste("Database recreated but failed to load:", e$message)
          ))
        })
      } else {
        duckdb_message(result)
      }
    })


    # Render DuckDB status
    output$duckdb_status <- renderUI({
      vocab_folder <- selected_folder()

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

      # Show current status: green if exists, red if doesn't exist
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
            style = "padding: 10px; background: #f8d7da; border-left: 3px solid #dc3545; border-radius: 4px; font-size: 12px;",
            tags$i(class = "fas fa-times-circle", style = "margin-right: 6px; color: #dc3545;"),
            "Database does not exist"
          )
        )
      }
    })

    # Return reactive settings
    settings <- reactive({
      list(
        vocab_folder_path = selected_folder()
      )
    })

    return(settings)
  })
}
