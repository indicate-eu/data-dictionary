# MODULE STRUCTURE OVERVIEW ====
#
# This module manages general application settings
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Terminologies Tab
#         #### OHDSI Vocabularies Section - Browse and select OHDSI vocabulary folder
#      ### Backup & Restore Tab - Download/upload application data backup (ZIP)
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Folder Browser State (OHDSI)
#      ### Backup & Restore State
#
#   ## 2) Server - Terminologies Tab
#      ### Folder Path Display
#      ### Browser Modal
#      ### File Browser Rendering
#      ### Navigation Handlers
#
#   ## 3) Server - Backup & Restore Tab
#      ### Download Backup Handler
#      ### Upload Restore Handler

# UI SECTION ====

#' General Settings Module - UI
#'
#' @param id Module ID
#' @param i18n Translator object
#'
#' @return Shiny UI elements
#' @noRd
mod_general_settings_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",

        # Main content with tabs and layout-panel
        create_page_layout(
          "full",
          create_panel(
            title = NULL,
            content = tagList(
              # Tabs header
              tags$div(
                class = "tabs-with-actions",

                # Tabs wrapper
                tags$div(
                  class = "tabs-wrapper",
                  tabsetPanel(
                    id = ns("settings_tabs"),

                    # Terminologies Tab ----
                    tabPanel(
                      i18n$t("terminologies"),
                      value = "terminologies",
                      icon = icon("book-medical"),
                      tags$div(
                        class = "tab-content-panel",

                        tags$div(
                          class = "settings-backup-container",

                          # OHDSI Vocabularies Section
                          tags$div(
                            class = "settings-section settings-backup-section",
                            tags$h4(
                              class = "settings-section-title",
                              tags$i(class = "fas fa-language", style = "margin-right: 8px; color: #0f60af;"),
                              i18n$t("ohdsi_vocabularies")
                            ),
                            tags$p(
                              class = "settings-section-desc",
                              i18n$t("ohdsi_vocabularies_desc")
                            ),

                            # Browse folder button and path display
                            tags$div(
                              class = "settings-browse-row",
                              actionButton(
                                ns("browse_folder"),
                                label = tagList(
                                  tags$i(class = "fas fa-folder-open", style = "margin-right: 6px;"),
                                  i18n$t("browse")
                                ),
                                class = "btn-primary-custom"
                              ),
                              tags$div(
                                class = "settings-path-display",
                                uiOutput(ns("folder_path_display"))
                              )
                            ),

                            # Info note about ATHENA
                            tags$div(
                              class = "settings-info-box",
                              tags$p(
                                tags$i(class = "fas fa-info-circle", style = "margin-right: 6px; color: #0f60af;"),
                                i18n$t("athena_note")
                              )
                            ),

                            # DuckDB status
                            tags$div(
                              class = "settings-status-box",
                              tags$div(
                                class = "settings-status-header",
                                tags$i(class = "fas fa-database", style = "margin-right: 8px; color: #0f60af;"),
                                i18n$t("database_status")
                              ),
                              tags$p(
                                class = "settings-status-desc",
                                i18n$t("database_status_desc")
                              ),
                              uiOutput(ns("duckdb_status"))
                            )
                          )
                        )
                      )
                    ),

                    # Backup & Restore Tab ----
                    tabPanel(
                      i18n$t("backup_restore"),
                      value = "backup_restore",
                      icon = icon("database"),
                      tags$div(
                        class = "tab-content-panel",

                        tags$div(
                          class = "settings-backup-container",

                          # Download Backup Section
                          tags$div(
                            class = "settings-section settings-backup-section",
                            tags$h4(
                              class = "settings-section-title settings-section-title-success",
                              tags$i(class = "fas fa-download", style = "margin-right: 8px; color: #28a745;"),
                              i18n$t("download_backup")
                            ),
                            tags$p(
                              class = "settings-section-desc",
                              i18n$t("download_backup_desc")
                            ),
                            downloadButton(
                              ns("download_backup"),
                              label = i18n$t("download_backup_zip"),
                              class = "btn-success-custom",
                              icon = icon("download")
                            )
                          ),

                          # Restore from Backup Section
                          tags$div(
                            class = "settings-section settings-backup-section",
                            tags$h4(
                              class = "settings-section-title",
                              tags$i(class = "fas fa-upload", style = "margin-right: 8px; color: #0f60af;"),
                              i18n$t("restore_from_backup")
                            ),

                            # Warning message
                            tags$div(
                              class = "settings-warning-box",
                              tags$p(
                                tags$i(class = "fas fa-exclamation-triangle", style = "margin-right: 6px; color: #ffc107;"),
                                tags$strong("Warning:"), " ", i18n$t("restore_warning")
                              )
                            ),

                            fileInput(
                              ns("upload_backup_file"),
                              label = NULL,
                              accept = ".zip",
                              width = "400px",
                              buttonLabel = tagList(
                                tags$i(class = "fas fa-upload", style = "margin-right: 6px;"),
                                i18n$t("browse")
                              ),
                              placeholder = i18n$t("select_backup_file")
                            ),

                            # Import options container (hidden by default)
                            shinyjs::hidden(
                              tags$div(
                                id = ns("import_options_container"),
                                class = "settings-import-options",
                                tags$div(
                                  class = "settings-import-header",
                                  i18n$t("select_what_to_import")
                                ),
                                checkboxInput(
                                  ns("import_config_users"),
                                  label = tagList(
                                    tags$span(i18n$t("configuration_users"), class = "import-option-label"),
                                    tags$span(" (config, users)", class = "import-option-desc")
                                  ),
                                  value = TRUE,
                                  width = "100%"
                                ),
                                checkboxInput(
                                  ns("import_dictionary"),
                                  label = tagList(
                                    tags$span(i18n$t("dictionary"), class = "import-option-label"),
                                    tags$span(" (concept sets)", class = "import-option-desc")
                                  ),
                                  value = TRUE,
                                  width = "100%"
                                ),
                                tags$div(
                                  class = "settings-import-buttons",
                                  actionButton(
                                    ns("confirm_restore"),
                                    label = i18n$t("confirm_restore"),
                                    class = "btn-primary-custom",
                                    icon = icon("check")
                                  ),
                                  actionButton(
                                    ns("cancel_restore"),
                                    label = i18n$t("cancel"),
                                    class = "btn-secondary-custom",
                                    icon = icon("times")
                                  )
                                )
                              )
                            ),
                            uiOutput(ns("backup_restore_status"))
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    ),

    # Modal - Folder Browser (OHDSI) ----
    tags$div(
      id = ns("folder_browser_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if(event.target === event.currentTarget) document.getElementById('%s').style.display = 'none';", ns("folder_browser_modal")),
      tags$div(
        class = "modal-content modal-large",
        tags$div(
          class = "modal-header",
          tags$h3(
            tags$i(class = "fas fa-folder-open", style = "margin-right: 8px;"),
            i18n$t("select_vocabulary_folder")
          ),
          tags$button(
            class = "modal-close",
            onclick = sprintf("document.getElementById('%s').style.display = 'none';", ns("folder_browser_modal")),
            "\u00D7"
          )
        ),
        tags$div(
          class = "modal-body",

          # Current path and home button
          tags$div(
            class = "folder-browser-toolbar",
            tags$div(
              class = "folder-browser-path",
              uiOutput(ns("current_path"))
            ),
            actionButton(
              ns("go_home"),
              label = tags$i(class = "fas fa-home"),
              class = "btn-secondary-custom btn-sm"
            )
          ),

          # Search filter
          tags$div(
            class = "folder-browser-search",
            textInput(
              ns("filter_input"),
              label = NULL,
              placeholder = i18n$t("search_folders"),
              width = "100%"
            )
          ),

          # File browser
          tags$div(
            class = "folder-browser-list",
            # Header
            tags$div(
              class = "folder-browser-header",
              onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("toggle_sort")),
              tags$span(i18n$t("name")),
              uiOutput(ns("sort_icon"), inline = TRUE)
            ),
            # File list
            uiOutput(ns("file_browser"))
          )
        ),
        tags$div(
          class = "modal-footer",
          actionButton(ns("cancel_browse"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
          actionButton(ns("select_current_folder"), i18n$t("select"), class = "btn-primary-custom", icon = icon("check"))
        )
      )
    )
  )
}

# SERVER SECTION ====

#' General Settings Module - Server
#'
#' @param id Module ID
#' @param i18n Translator object
#' @param current_user Reactive: Current logged-in user
#'
#' @noRd
mod_general_settings_server <- function(id, i18n, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Enable event logging for debugging
    log_level <- c("event", "error")

    ## 1) Server - Reactive Values & State ====

    ### Folder Browser State ----
    current_path <- reactiveVal(path.expand("~"))
    selected_folder <- reactiveVal(NULL)
    sort_order <- reactiveVal("asc")
    filter_text <- reactiveVal("")

    ### Backup & Restore State ----
    backup_restore_message <- reactiveVal(NULL)
    temp_extract_dir <- reactiveVal(NULL)

    ### DuckDB State ----
    duckdb_processing <- reactiveVal(FALSE)
    duckdb_message <- reactiveVal(NULL)

    ### Triggers ----
    folder_path_trigger <- reactiveVal(1)
    duckdb_status_trigger <- reactiveVal(1)
    backup_restore_status_trigger <- reactiveVal(1)
    file_browser_trigger <- reactiveVal(0)

    ### Initialize from Database ----
    saved_path <- get_config_value("vocab_folder")
    if (!is.null(saved_path) && nchar(saved_path) > 0 && dir.exists(saved_path)) {
      selected_folder(saved_path)
    }

    ## 2) Server - Terminologies Tab ====

    ### Folder Path Display ----

    observe_event(selected_folder(), {
      folder_path_trigger(folder_path_trigger() + 1)
    })

    observe_event(folder_path_trigger(), {
      folder_path <- selected_folder()

      output$folder_path_display <- renderUI({
        if (is.null(folder_path) || nchar(folder_path) == 0) {
          tags$div(
            class = "path-display path-display-empty",
            tags$span(i18n$t("no_folder_selected"))
          )
        } else {
          tags$div(
            class = "path-display path-display-selected",
            tags$span(folder_path)
          )
        }
      })

      # Update DuckDB status when folder changes
      duckdb_status_trigger(duckdb_status_trigger() + 1)
    }, ignoreInit = FALSE)

    ### DuckDB Status Display ----

    observe_event(list(selected_folder(), duckdb_processing(), duckdb_message()), {
      duckdb_status_trigger(duckdb_status_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(duckdb_status_trigger(), {
      vocab_folder <- selected_folder()

      output$duckdb_status <- renderUI({
        # Show processing status
        if (duckdb_processing()) {
          return(
            tags$div(
              class = "status-box status-warning",
              tags$i(class = "fas fa-spinner fa-spin", style = "margin-right: 6px;"),
              i18n$t("creating_duckdb_database")
            )
          )
        }

        # Show error message if there was one
        msg <- duckdb_message()
        if (!is.null(msg) && !msg$success) {
          return(
            tags$div(
              class = "status-box status-error",
              tags$i(class = "fas fa-exclamation-circle", style = "margin-right: 6px;"),
              msg$message
            )
          )
        }

        # Check if DuckDB database file exists
        db_exists <- duckdb_exists()
        has_vocab_folder <- !is.null(vocab_folder) && nchar(vocab_folder) > 0

        if (db_exists) {
          db_path <- get_duckdb_path()
          return(
            tags$div(
              class = "status-box status-success",
              style = "display: flex; align-items: center; gap: 8px;",
              tags$i(class = "fas fa-check-circle", style = "margin-right: 6px;"),
              tags$span(i18n$t("database_exists")),
              tags$code(basename(db_path)),
              actionButton(
                ns("recreate_duckdb"),
                label = tagList(
                  tags$i(class = "fas fa-redo"),
                  i18n$t("recreate")
                ),
                class = "btn-inline btn-warning",
                disabled = if (!has_vocab_folder) "disabled" else NULL,
                title = if (!has_vocab_folder) i18n$t("select_vocabulary_folder_first") else i18n$t("recreate_database_tooltip")
              )
            )
          )
        } else {
          # Database does not exist
          if (has_vocab_folder) {
            # Check if vocabulary files exist
            required_files <- c("CONCEPT.csv", "CONCEPT_RELATIONSHIP.csv")
            missing_files <- required_files[!file.exists(file.path(vocab_folder, required_files))]

            if (length(missing_files) > 0) {
              return(
                tags$div(
                  class = "status-box status-warning",
                  tags$i(class = "fas fa-exclamation-triangle", style = "margin-right: 6px;"),
                  i18n$t("missing_vocabulary_files"), ": ", paste(missing_files, collapse = ", ")
                )
              )
            }

            # Vocab folder is configured with files, show Create button
            return(
              tags$div(
                class = "status-box status-error",
                style = "display: flex; align-items: center; gap: 8px;",
                tags$i(class = "fas fa-times-circle", style = "margin-right: 6px;"),
                tags$span(i18n$t("database_does_not_exist")),
                actionButton(
                  ns("create_duckdb"),
                  label = tagList(
                    tags$i(class = "fas fa-plus"),
                    i18n$t("create")
                  ),
                  class = "btn-inline btn-success"
                )
              )
            )
          } else {
            # No vocab folder configured
            return(
              tags$div(
                class = "status-box status-info",
                tags$i(class = "fas fa-info-circle", style = "margin-right: 6px;"),
                i18n$t("no_vocabulary_folder_selected")
              )
            )
          }
        }
      })
    }, ignoreInit = FALSE)

    ### DuckDB Creation Handler ----

    observe_event(input$create_duckdb, {
      vocab_folder <- selected_folder()
      if (is.null(vocab_folder) || nchar(vocab_folder) == 0) return()

      duckdb_processing(TRUE)
      duckdb_message(NULL)

      shinyjs::delay(100, {
        shinyjs::runjs(sprintf(
          "Shiny.setInputValue('%s', Math.random(), {priority: 'event'})",
          ns("trigger_duckdb_creation")
        ))
      })
    })

    observe_event(input$trigger_duckdb_creation, {
      tryCatch({
        vocab_folder <- selected_folder()

        if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
          duckdb_processing(FALSE)
          return()
        }

        # Force garbage collection
        gc()
        gc()
        Sys.sleep(0.5)

        # Create DuckDB database
        result <- create_duckdb_database(vocab_folder)

        duckdb_processing(FALSE)

        if (result$success) {
          duckdb_message(NULL)
        } else {
          duckdb_message(result)
        }
      }, error = function(e) {
        duckdb_processing(FALSE)
        duckdb_message(list(
          success = FALSE,
          message = paste(i18n$t("error_creating_duckdb"), e$message)
        ))
      })
    })

    ### DuckDB Recreation Handler ----

    observe_event(input$recreate_duckdb, {
      vocab_folder <- selected_folder()
      if (is.null(vocab_folder) || nchar(vocab_folder) == 0) return()

      duckdb_processing(TRUE)
      duckdb_message(NULL)

      shinyjs::delay(100, {
        shinyjs::runjs(sprintf(
          "Shiny.setInputValue('%s', Math.random(), {priority: 'event'})",
          ns("trigger_duckdb_recreation")
        ))
      })
    })

    observe_event(input$trigger_duckdb_recreation, {
      tryCatch({
        vocab_folder <- selected_folder()

        if (is.null(vocab_folder) || nchar(vocab_folder) == 0) {
          duckdb_processing(FALSE)
          return()
        }

        # Force garbage collection
        gc()
        gc()
        Sys.sleep(0.5)

        # Recreate DuckDB database
        result <- create_duckdb_database(vocab_folder)

        duckdb_processing(FALSE)

        if (result$success) {
          duckdb_message(NULL)
        } else {
          duckdb_message(result)
        }
      }, error = function(e) {
        duckdb_processing(FALSE)
        duckdb_message(list(
          success = FALSE,
          message = paste(i18n$t("error_creating_duckdb"), e$message)
        ))
      })
    })

    ### Browser Modal ----

    observe_event(input$browse_folder, {
      # Start at selected folder if it exists, otherwise home
      start_path <- selected_folder()
      if (is.null(start_path) || !dir.exists(start_path)) {
        start_path <- path.expand("~")
      }

      # Update reactive values
      current_path(start_path)
      sort_order("asc")
      filter_text("")

      # Trigger file browser update
      file_browser_trigger(file_browser_trigger() + 1)

      # Show modal
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'flex';", ns("folder_browser_modal")))
    })

    observe_event(input$cancel_browse, {
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", ns("folder_browser_modal")))
    })

    observe_event(input$go_home, {
      current_path(path.expand("~"))
    })

    observe_event(input$toggle_sort, {
      if (sort_order() == "asc") {
        sort_order("desc")
      } else {
        sort_order("asc")
      }
    })

    observe_event(input$filter_input, {
      if (is.null(input$filter_input)) return()
      filter_text(input$filter_input)
    }, ignoreInit = TRUE)

    ### Current Path Display ----

    output$current_path <- renderUI({
      tags$span(current_path())
    })
    outputOptions(output, "current_path", suspendWhenHidden = FALSE)

    ### Sort Icon Display ----

    output$sort_icon <- renderUI({
      if (sort_order() == "asc") {
        tags$i(class = "fas fa-sort-alpha-down", title = "Sort A-Z")
      } else {
        tags$i(class = "fas fa-sort-alpha-up", title = "Sort Z-A")
      }
    })
    outputOptions(output, "sort_icon", suspendWhenHidden = FALSE)

    ### File Browser Rendering ----

    # Update file browser when dependencies change
    observe_event(list(current_path(), filter_text(), sort_order()), {
      file_browser_trigger(file_browser_trigger() + 1)
    }, ignoreInit = TRUE)

    # Define file_browser output - uses reactive trigger for updates
    output$file_browser <- renderUI({
      # Depend on trigger for updates
      file_browser_trigger()

      path <- current_path()
      filter <- filter_text()
      order <- sort_order()

      if (!dir.exists(path)) {
        return(
          tags$div(
            class = "folder-browser-empty",
            tags$i(class = "fas fa-exclamation-triangle"),
            tags$p(i18n$t("folder_not_found"))
          )
        )
      }

      items <- list.files(path, full.names = TRUE, include.dirs = TRUE)

      if (length(items) == 0) {
        return(
          tags$div(
            class = "folder-browser-empty",
            tags$i(class = "fas fa-folder-open"),
            tags$p(i18n$t("empty_folder"))
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
            class = "folder-browser-empty",
            tags$i(class = "fas fa-search"),
            tags$p(i18n$t("no_items_match"))
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
            class = "folder-browser-item",
            onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("navigate_to"), parent_path),
            tags$i(class = "fas fa-level-up-alt folder-icon-parent"),
            tags$span("..", class = "folder-name")
          )
        ))
      }

      # Add directories
      for (dir in dirs) {
        dir_name <- basename(dir)
        escaped_path <- gsub("'", "\\\\'", dir)
        items_ui <- append(items_ui, list(
          tags$div(
            class = "folder-browser-item folder-browser-folder",
            `data-path` = dir,
            onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("navigate_to"), escaped_path),
            tags$i(class = "fas fa-folder folder-icon"),
            tags$span(dir_name, class = "folder-name"),
            actionButton(
              ns(paste0("select_", gsub("[^a-zA-Z0-9]", "_", dir))),
              i18n$t("select"),
              class = "btn-primary-custom btn-xs",
              onclick = sprintf("event.stopPropagation(); Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("select_folder_path"), escaped_path)
            )
          )
        ))
      }

      # Add files (grayed out, non-clickable)
      for (file in files) {
        file_name <- basename(file)
        items_ui <- append(items_ui, list(
          tags$div(
            class = "folder-browser-item folder-browser-file",
            tags$i(class = "fas fa-file file-icon"),
            tags$span(file_name, class = "file-name")
          )
        ))
      }

      tagList(items_ui)
    })

    # Force file_browser output to render even when hidden
    outputOptions(output, "file_browser", suspendWhenHidden = FALSE)

    ### Navigation Handlers ----

    observe_event(input$navigate_to, {
      new_path <- input$navigate_to
      if (dir.exists(new_path)) {
        current_path(new_path)
      }
    })

    observe_event(input$select_folder_path, {
      folder_path <- input$select_folder_path
      if (dir.exists(folder_path)) {
        selected_folder(folder_path)
        set_config_value("vocab_folder", folder_path)
        shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", ns("folder_browser_modal")))
      }
    })

    observe_event(input$select_current_folder, {
      folder_path <- current_path()
      if (dir.exists(folder_path)) {
        selected_folder(folder_path)
        set_config_value("vocab_folder", folder_path)
        shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", ns("folder_browser_modal")))
      }
    })

    ## 3) Server - Backup & Restore Tab ====

    ### Download Backup Handler ----

    output$download_backup <- downloadHandler(
      filename = function() {
        paste0("indicate_backup_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".zip")
      },
      content = function(file) {
        app_dir <- get_app_dir()

        # Get all files in app_dir except large binary files
        all_files <- list.files(app_dir, recursive = TRUE, full.names = TRUE)
        files_to_backup <- all_files[!grepl("\\.duckdb$", all_files)]

        # Create a temporary directory for the backup
        temp_dir <- file.path(tempdir(), "indicate_backup")
        if (dir.exists(temp_dir)) {
          unlink(temp_dir, recursive = TRUE)
        }
        dir.create(temp_dir, recursive = TRUE)

        # Copy files preserving directory structure
        for (f in files_to_backup) {
          rel_path <- sub(paste0("^", normalizePath(app_dir), "/?"), "", normalizePath(f))
          dest_path <- file.path(temp_dir, rel_path)
          dest_dir <- dirname(dest_path)
          if (!dir.exists(dest_dir)) {
            dir.create(dest_dir, recursive = TRUE)
          }
          file.copy(f, dest_path, overwrite = TRUE)
        }

        # Create ZIP file
        old_wd <- getwd()
        setwd(temp_dir)
        zip(file, files = list.files(".", recursive = TRUE), flags = "-q")
        setwd(old_wd)

        # Clean up
        unlink(temp_dir, recursive = TRUE)
      },
      contentType = "application/zip"
    )

    ### Upload Restore Handler ----

    observe_event(input$upload_backup_file, {
      file <- input$upload_backup_file
      if (is.null(file)) return()

      tryCatch({
        # Create a temporary directory for extraction
        extract_dir <- file.path(tempdir(), "indicate_restore")
        if (dir.exists(extract_dir)) {
          unlink(extract_dir, recursive = TRUE)
        }
        dir.create(extract_dir, recursive = TRUE)

        # Extract ZIP file
        unzip(file$datapath, exdir = extract_dir)

        # Get list of extracted files
        extracted_files <- list.files(extract_dir, recursive = TRUE, full.names = TRUE)

        if (length(extracted_files) == 0) {
          backup_restore_message(list(
            success = FALSE,
            message = i18n$t("backup_empty_or_invalid")
          ))
          unlink(extract_dir, recursive = TRUE)
          return()
        }

        # Store the extraction directory path
        temp_extract_dir(extract_dir)

        # Show import options
        shinyjs::show("import_options_container")
        backup_restore_message(NULL)

      }, error = function(e) {
        backup_restore_message(list(
          success = FALSE,
          message = paste(i18n$t("error_reading_backup"), e$message)
        ))
      })
    })

    ### Cancel Restore Handler ----

    observe_event(input$cancel_restore, {
      # Clean up temp directory
      extract_dir <- temp_extract_dir()
      if (!is.null(extract_dir) && dir.exists(extract_dir)) {
        unlink(extract_dir, recursive = TRUE)
      }

      # Reset state
      temp_extract_dir(NULL)

      # Hide options
      shinyjs::hide("import_options_container")

      # Reset file input
      shinyjs::reset("upload_backup_file")
    })

    ### Confirm Restore Handler ----

    observe_event(input$confirm_restore, {
      extract_dir <- temp_extract_dir()
      if (is.null(extract_dir) || !dir.exists(extract_dir)) {
        backup_restore_message(list(
          success = FALSE,
          message = i18n$t("no_backup_to_restore")
        ))
        return()
      }

      # Check if at least one category is selected
      import_config <- isTRUE(input$import_config_users)
      import_dictionary <- isTRUE(input$import_dictionary)

      if (!import_config && !import_dictionary) {
        backup_restore_message(list(
          success = FALSE,
          message = i18n$t("select_at_least_one_category")
        ))
        return()
      }

      app_dir <- get_app_dir()

      tryCatch({
        # Import from backup database if it exists
        backup_db_path <- file.path(extract_dir, "indicate.db")

        if (file.exists(backup_db_path)) {
          backup_con <- DBI::dbConnect(RSQLite::SQLite(), backup_db_path)
          on.exit(DBI::dbDisconnect(backup_con), add = TRUE)

          con <- get_db_connection()
          on.exit(DBI::dbDisconnect(con), add = TRUE)

          # 1) Configuration & Users
          if (import_config) {
            # Import config
            if (DBI::dbExistsTable(backup_con, "config")) {
              DBI::dbExecute(con, "DELETE FROM config")
              config_data <- DBI::dbReadTable(backup_con, "config")
              if (nrow(config_data) > 0) {
                DBI::dbWriteTable(con, "config", config_data, append = TRUE)
              }
            }

            # Import user_accesses
            if (DBI::dbExistsTable(backup_con, "user_accesses")) {
              DBI::dbExecute(con, "DELETE FROM users")
              DBI::dbExecute(con, "DELETE FROM user_accesses")
              user_accesses_data <- DBI::dbReadTable(backup_con, "user_accesses")
              if (nrow(user_accesses_data) > 0) {
                DBI::dbWriteTable(con, "user_accesses", user_accesses_data, append = TRUE)
              }
            }

            # Import users
            if (DBI::dbExistsTable(backup_con, "users")) {
              users_data <- DBI::dbReadTable(backup_con, "users")
              if (nrow(users_data) > 0) {
                DBI::dbWriteTable(con, "users", users_data, append = TRUE)
              }
            }
          }

          # 2) Dictionary (concept_sets)
          if (import_dictionary) {
            if (DBI::dbExistsTable(backup_con, "concept_sets")) {
              DBI::dbExecute(con, "DELETE FROM concept_sets")
              concept_sets_data <- DBI::dbReadTable(backup_con, "concept_sets")
              if (nrow(concept_sets_data) > 0) {
                DBI::dbWriteTable(con, "concept_sets", concept_sets_data, append = TRUE)
              }
            }
          }
        }

        # Clean up
        unlink(extract_dir, recursive = TRUE)
        temp_extract_dir(NULL)

        # Hide options
        shinyjs::hide("import_options_container")
        shinyjs::reset("upload_backup_file")

        # Show success message
        categories_imported <- c()
        if (import_config) categories_imported <- c(categories_imported, i18n$t("configuration_users"))
        if (import_dictionary) categories_imported <- c(categories_imported, i18n$t("dictionary"))

        backup_restore_message(list(
          success = TRUE,
          message = paste0(i18n$t("successfully_restored"), ": ", paste(categories_imported, collapse = ", "), "."),
          reload_message = i18n$t("reload_to_apply_changes")
        ))

      }, error = function(e) {
        backup_restore_message(list(
          success = FALSE,
          message = paste(i18n$t("error_restoring_backup"), e$message)
        ))
      })
    })

    ### Backup Restore Status Display ----

    observe_event(backup_restore_message(), {
      backup_restore_status_trigger(backup_restore_status_trigger() + 1)
    })

    observe_event(backup_restore_status_trigger(), {
      output$backup_restore_status <- renderUI({
        msg <- backup_restore_message()

        if (is.null(msg)) {
          return(NULL)
        }

        if (msg$success) {
          tags$div(
            tags$div(
              class = "status-box status-success",
              tags$i(class = "fas fa-check-circle", style = "margin-right: 6px;"),
              msg$message,
              " ",
              tags$strong(msg$reload_message)
            ),
            tags$div(
              style = "margin-top: 10px;",
              actionButton(
                ns("reload_application"),
                i18n$t("reload_application"),
                class = "btn-primary-custom",
                icon = icon("sync-alt"),
                onclick = "location.reload();"
              )
            )
          )
        } else {
          tags$div(
            class = "status-box status-error",
            tags$i(class = "fas fa-exclamation-circle", style = "margin-right: 6px;"),
            msg$message
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
