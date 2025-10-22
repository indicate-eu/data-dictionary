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

               # DuckDB option
               tags$div(
                 style = "margin-top: 20px; padding: 15px; background: #f8f9fa; border-radius: 6px; border: 1px solid #dee2e6;",
                 tags$div(
                   style = "margin-bottom: 10px;",
                   tags$div(
                     style = "font-weight: 600; font-size: 14px; color: #333; margin-bottom: 5px;",
                     tags$i(class = "fas fa-database", style = "margin-right: 8px; color: #0f60af;"),
                     "DuckDB Database"
                   ),
                   tags$p(
                     style = "margin: 0; font-size: 12px; color: #666;",
                     "Creates a DuckDB database from CSV files for instant loading at startup."
                   )
                 ),
                 tags$div(
                   style = "display: flex; align-items: center; gap: 15px;",
                   uiOutput(ns("duckdb_status")),
                   uiOutput(ns("duckdb_button"))
                 )
               )
           )
    )
  )
}

# Helper function for Users content
users_ui <- function(ns) {
  fluidRow(
    column(12,
           div(class = "users-placeholder",
               style = "padding: 40px; text-align: center; background: #f8f9fa; border-radius: 8px; margin-top: 20px;",
               tags$i(class = "fas fa-users", style = "font-size: 64px; color: #0f60af; margin-bottom: 20px;"),
               tags$h3("User Management", style = "color: #0f60af;"),
               tags$p("Manage user profiles for tracking contributions and improvements to the dictionary."),
               tags$p(style = "color: #666;", "Features coming soon:"),
               tags$ul(
                 style = "list-style: none; padding: 0; color: #666;",
                 tags$li(tags$i(class = "fas fa-check", style = "color: #28a745; margin-right: 8px;"), "Add and edit user profiles"),
                 tags$li(tags$i(class = "fas fa-check", style = "color: #28a745; margin-right: 8px;"), "Assign roles and permissions"),
                 tags$li(tags$i(class = "fas fa-check", style = "color: #28a745; margin-right: 8px;"), "Track user contributions"),
                 tags$li(tags$i(class = "fas fa-check", style = "color: #28a745; margin-right: 8px;"), "Export user activity reports")
               )
           )
    )
  )
}

#' Settings Module - Server
#'
#' @description Server function for the settings module
#'
#' @param id Module ID
#' @param config Configuration list
#' @param vocabularies Reactive containing vocabularies data with connection
#' @param reset_vocabularies Function to reset vocabularies to NULL
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent reactiveVal renderUI showModal modalDialog removeModal observe textInput
mod_settings_server <- function(id, config, vocabularies = NULL, reset_vocabularies = NULL, page_type = reactive("general")) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

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

    # Render DuckDB button
    output$duckdb_button <- renderUI({
      vocab_folder <- selected_folder()

      if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
        return(NULL)
      }

      # Check if processing
      if (duckdb_processing()) {
        return(NULL)
      }

      db_exists <- duckdb_exists(vocab_folder)

      if (db_exists) {
        # Delete button (red)
        actionButton(
          ns("delete_duckdb"),
          label = tagList(
            tags$i(class = "fas fa-trash", style = "margin-right: 6px;"),
            "Delete Database"
          ),
          class = "btn-duckdb-delete",
          style = "background: #dc3545; color: white; border: none; padding: 8px 16px; border-radius: 4px; font-size: 13px; cursor: pointer; transition: background-color 0.2s ease; font-weight: 500;"
        )
      } else {
        # Create button (blue)
        actionButton(
          ns("create_duckdb"),
          label = tagList(
            tags$i(class = "fas fa-plus-circle", style = "margin-right: 6px;"),
            "Create Database"
          ),
          class = "btn-duckdb-create",
          style = "background: #0f60af; color: white; border: none; padding: 8px 16px; border-radius: 4px; font-size: 13px; cursor: pointer; transition: background-color 0.2s ease; font-weight: 500;"
        )
      }
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
      }
    })

    # Handle cancel
    observeEvent(input$cancel_browse, {
      removeModal()
    })

    # Reactive value to track DuckDB processing
    duckdb_processing <- reactiveVal(FALSE)
    duckdb_message <- reactiveVal(NULL)

    # Handle DuckDB creation button
    observeEvent(input$create_duckdb, {
      vocab_folder <- selected_folder()

      if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
        return()
      }

      duckdb_processing(TRUE)
      duckdb_message(NULL)

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

      # Force garbage collection and wait for file to be released
      gc()
      Sys.sleep(1.0)  # Increased delay to ensure file is unlocked

      # Create DuckDB database
      result <- tryCatch({
        create_duckdb_database(vocab_folder)
      }, error = function(e) {
        list(success = FALSE, message = paste("Error:", e$message))
      })

      duckdb_processing(FALSE)

      # Save setting
      if (result$success) {
        tryCatch({
          set_use_duckdb(TRUE)
        }, error = function(e) {
          message("Error saving DuckDB option: ", e$message)
        })
        duckdb_message(NULL)
      } else {
        duckdb_message(result)
      }
    })

    # Handle DuckDB deletion button
    observeEvent(input$delete_duckdb, {
      vocab_folder <- selected_folder()

      if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
        return()
      }

      duckdb_processing(TRUE)
      duckdb_message(NULL)

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

      # Delete DuckDB database
      result <- tryCatch({
        delete_duckdb_database(vocab_folder)
      }, error = function(e) {
        list(success = FALSE, message = paste("Error:", e$message))
      })

      duckdb_processing(FALSE)

      # Save setting
      if (result$success) {
        tryCatch({
          set_use_duckdb(FALSE)
        }, error = function(e) {
          message("Error saving DuckDB option: ", e$message)
        })
        duckdb_message(NULL)
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
            style = "margin-top: 10px; padding: 10px; background: #fff3cd; border-left: 3px solid #ffc107; border-radius: 4px; font-size: 12px;",
            tags$i(class = "fas fa-spinner fa-spin", style = "margin-right: 6px;"),
            if (input$use_duckdb) {
              "Creating DuckDB database... This may take a few minutes."
            } else {
              "Deleting DuckDB database..."
            }
          )
        )
      }

      # Show error message if there was one
      msg <- duckdb_message()
      if (!is.null(msg) && !msg$success) {
        return(
          tags$div(
            style = "margin-top: 10px; padding: 10px; background: #f8d7da; border-left: 3px solid #dc3545; border-radius: 4px; font-size: 12px;",
            tags$i(class = "fas fa-exclamation-circle", style = "margin-right: 6px; color: #dc3545;"),
            msg$message
          )
        )
      }

      # Show current status: green if exists, red if doesn't exist
      db_exists <- duckdb_exists(vocab_folder)
      if (db_exists) {
        db_path <- get_duckdb_path(vocab_folder)
        return(
          tags$div(
            style = "padding: 10px; background: #d4edda; border-left: 3px solid #28a745; border-radius: 4px; font-size: 12px;",
            tags$i(class = "fas fa-check-circle", style = "margin-right: 6px; color: #28a745;"),
            "Database exists: ", tags$code(basename(db_path))
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
