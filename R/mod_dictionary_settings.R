# MODULE STRUCTURE OVERVIEW ====
#
# This module manages dictionary-specific settings
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Data Dictionary Tab - Import/export data dictionary folder
#      ### Global Comment Tab - Edit global comment accessible from all Comments panels
#      ### Unit Conversions Tab - Manage unit conversions between concepts
#   ## UI - Modals
#      ### Modal - Test Conversion - Test unit conversion with numeric input
#      ### Modal - Delete Confirmation - Confirm deletion of conversion
#      ### Modal - Add Conversion (Fullscreen) - Add new conversion with OMOP search
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Dictionary Upload State - Track upload status messages
#      ### Unit Conversions State - Track conversion data and triggers
#
#   ## 2) Server - Data Dictionary
#      ### Download Dictionary - Export data_dictionary folder as ZIP
#      ### Upload Dictionary - Import data_dictionary from ZIP
#      ### Upload Status Display - Show upload status and reload button
#
#   ## 3) Server - Global Comment
#      ### Load Global Comment - Initialize textarea with existing comment
#      ### Live Preview - Render markdown preview as user types
#      ### Save Handler - Save comment to file (uses showNotification)
#
#   ## 4) Server - Unit Conversions
#      ### Load Conversions - Load from CSV and enrich with concept names
#      ### DataTable Display - Show conversions with editable factor and actions
#      ### Edit Handler - Update conversion factor on cell edit
#      ### Delete Handler - Show confirmation modal
#      ### Confirm Delete Handler - Remove selected conversion
#      ### Test Conversion Modal - Display test modal and calculate result
#      ### Add Conversion Modal - Open modal and handle OMOP search
#      ### Save New Conversion - Validate and save new conversion

# UI SECTION ====

#' Dictionary Settings Module - UI
#'
#' @description UI function for dictionary settings
#'
#' @param id Module ID
#' @param i18n Translator object from shiny.i18n
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS fluidRow column h3 h4 p textOutput actionButton uiOutput
#' @importFrom htmltools tags tagList
mod_dictionary_settings_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    ## UI - Main Layout ----
    div(class = "main-panel",
      div(class = "main-content",
        tabsetPanel(
          id = ns("dictionary_settings_tabs"),

          ### Data Dictionary Tab ----
          tabPanel(
            i18n$t("data_dictionary"),
            value = "data_dictionary",
            icon = icon("book"),
            tags$div(
              style = "margin-top: 10px; height: calc(100vh - 170px); display: flex; flex-direction: column; gap: 15px;",

              # Export section
              div(
                class = "settings-section",
                style = "flex: 1; display: flex; flex-direction: column; min-height: 0;",
                tags$h4(
                  style = "margin-top: 0; margin-bottom: 15px; color: #333; border-bottom: 2px solid #28a745; padding-bottom: 8px; flex-shrink: 0;",
                  tags$i(class = "fas fa-download", style = "margin-right: 8px; color: #28a745;"),
                  i18n$t("export")
                ),
                tags$p(
                  style = "color: #666; margin-bottom: 15px; flex-shrink: 0;",
                  i18n$t("download_dictionary_desc")
                ),
                tags$div(
                  style = "flex-shrink: 0;",
                  downloadButton(
                    ns("download_dictionary"),
                    label = i18n$t("download_dictionary_zip"),
                    class = "btn-success-custom",
                    icon = icon("download")
                  )
                )
              ),

              # Import section
              div(
                class = "settings-section",
                style = "flex: 1; display: flex; flex-direction: column; min-height: 0;",
                tags$h4(
                  style = "margin-top: 0; margin-bottom: 15px; color: #333; border-bottom: 2px solid #0f60af; padding-bottom: 8px; flex-shrink: 0;",
                  tags$i(class = "fas fa-upload", style = "margin-right: 8px; color: #0f60af;"),
                  i18n$t("import")
                ),
                tags$p(
                  style = "color: #666; margin-bottom: 15px; flex-shrink: 0;",
                  i18n$t("indicate_concepts_desc")
                ),

                # Warning message before file input
                tags$div(
                  style = "margin-bottom: 15px; padding: 12px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px; flex-shrink: 0; width: fit-content;",
                  tags$p(
                    style = "margin: 0; font-size: 13px; color: #333;",
                    tags$i(class = "fas fa-exclamation-triangle", style = "margin-right: 6px; color: #ffc107;"),
                    tags$strong("Warning:"), " ", i18n$t("upload_dictionary_warning")
                  )
                ),

                fileInput(
                  ns("upload_dictionary_file"),
                  label = NULL,
                  accept = ".zip",
                  width = "400px",
                  buttonLabel = tagList(
                    tags$i(class = "fas fa-upload", style = "margin-right: 6px;"),
                    i18n$t("browse")
                  ),
                  placeholder = i18n$t("select_dictionary_zip")
                ),
                uiOutput(ns("dictionary_upload_status"))
              )
            )
          ),

          ### Global Comment Tab ----
          tabPanel(
            i18n$t("global_comment"),
            value = "global_comment",
            icon = icon("comment-dots"),
            tags$div(
              style = "margin-top: 10px; height: calc(100vh - 170px); display: flex; flex-direction: column;",
              div(class = "settings-section", style = "flex: 1; display: flex; flex-direction: column;",

                # Header with description and save button
                tags$div(
                  style = "display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 15px; flex-shrink: 0;",
                  tags$p(
                    style = "color: #666; margin: 0; flex: 1; padding-right: 20px;",
                    i18n$t("global_comment_desc")
                  ),
                  actionButton(
                    ns("save_global_comment_btn"),
                    label = tagList(
                      tags$i(class = "fas fa-save", style = "margin-right: 6px;"),
                      i18n$t("save_global_comment")
                    ),
                    class = "btn-success-custom"
                  )
                ),

                # Split view: textarea on left, preview on right
                tags$div(
                  style = "flex: 1; display: flex; gap: 0; min-height: 0; border: 1px solid #ddd; border-radius: 8px; overflow: hidden;",

                  # Left: textarea editor
                  tags$div(
                    style = "flex: 1; padding: 10px; border-right: 1px solid #ddd; display: flex; flex-direction: column; overflow: hidden;",
                    tags$h4(
                      style = "margin-top: 0; color: #0f60af; font-size: 16px; font-weight: 600; margin-bottom: 15px; flex-shrink: 0;",
                      "Edit"
                    ),
                    tags$div(
                      class = "global-comment-textarea-container",
                      style = "flex: 1; display: flex; flex-direction: column; overflow: hidden;",
                      shiny::textAreaInput(
                        ns("global_comment_input"),
                        label = NULL,
                        value = "",
                        placeholder = "Enter global comment here (supports Markdown)...",
                        width = "100%",
                        height = "100%"
                      )
                    )
                  ),

                  # Right: markdown preview
                  tags$div(
                    style = "flex: 1; padding: 10px; display: flex; flex-direction: column; overflow: hidden;",
                    tags$h4(
                      style = "margin-top: 0; color: #0f60af; font-size: 16px; font-weight: 600; margin-bottom: 15px; flex-shrink: 0;",
                      "Preview"
                    ),
                    tags$div(
                      style = "flex: 1; overflow-y: auto;",
                      uiOutput(ns("global_comment_preview"))
                    )
                  )
                )
              )
            )
          ),

          ### Unit Conversions Tab ----
          tabPanel(
            i18n$t("unit_conversions"),
            value = "unit_conversions",
            icon = icon("exchange-alt"),
            tags$div(
              style = "margin-top: 10px; height: calc(100vh - 170px); display: flex; flex-direction: column;",
              div(class = "settings-section", style = "flex: 1; display: flex; flex-direction: column;",

                # Header with description and add button
                tags$div(
                  style = "display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 15px; flex-shrink: 0;",
                  tags$p(
                    style = "color: #666; margin: 0; flex: 1; padding-right: 20px;",
                    i18n$t("unit_conversions_desc")
                  ),
                  actionButton(
                    ns("add_conversion_btn"),
                    label = tagList(
                      tags$i(class = "fas fa-plus", style = "margin-right: 6px;"),
                      i18n$t("add_conversion")
                    ),
                    class = "btn-primary-custom"
                  )
                ),

                # DataTable container
                tags$div(
                  style = "flex: 1; overflow: auto;",
                  DT::DTOutput(ns("unit_conversions_table"))
                )
              )
            )
          )
        )
      )
    ),

    ## UI - Modals ----

    ### Modal - Test Conversion ----
    tags$div(
      id = ns("test_conversion_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("test_conversion_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 500px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("test_conversion")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("test_conversion_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",

          # Conversion info display
          uiOutput(ns("test_conversion_info")),

          # Input for Concept 1 value with unit on the right
          tags$div(
            style = "margin-top: 20px;",
            tags$label(
              id = ns("test_value_1_label"),
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            tags$div(
              style = "display: flex; align-items: center; gap: 10px;",
              tags$div(
                style = "flex: 1;",
                numericInput(
                  ns("test_value_1"),
                  label = NULL,
                  value = 1,
                  min = 0,
                  step = 0.1,
                  width = "100%"
                )
              ),
              tags$span(
                id = ns("test_unit_1_display"),
                style = "font-weight: 600; color: #666; min-width: 60px;"
              )
            )
          ),

          # Arrow and conversion factor
          tags$div(
            style = "text-align: center; margin: 20px 0; font-size: 24px; color: #0f60af;",
            tags$i(class = "fa fa-arrow-down"),
            tags$span(
              style = "margin-left: 10px; font-size: 14px; color: #666;",
              "×",
              tags$span(id = ns("test_factor_display"), "")
            )
          ),

          # Result for Concept 2 value
          tags$div(
            tags$label(
              id = ns("test_value_2_label"),
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            tags$div(
              id = ns("test_result_display"),
              style = "padding: 12px; background: #e8f4f8; border-radius: 4px; font-size: 18px; font-weight: 600; text-align: center; color: #0f60af;"
            )
          )
        )
      )
    ),

    ### Modal - Delete Confirmation ----
    tags$div(
      id = ns("delete_confirmation_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("delete_confirmation_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 400px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("confirm_deletion")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("delete_confirmation_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$p(
            style = "margin: 0 0 20px 0; color: #333;",
            i18n$t("confirm_delete_conversion")
          ),
          tags$div(
            style = "display: flex; justify-content: flex-end; gap: 10px;",
            tags$button(
              class = "btn-secondary-custom",
              onclick = sprintf("$('#%s').hide();", ns("delete_confirmation_modal")),
              i18n$t("cancel")
            ),
            actionButton(
              ns("confirm_delete_btn"),
              label = i18n$t("delete"),
              class = "btn-danger-custom"
            )
          )
        )
      )
    ),

    ### Modal - Add Conversion (Fullscreen) ----
    tags$div(
      id = ns("add_conversion_modal"),
      class = "modal-overlay",
      style = "display: none; position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0, 0, 0, 0.5); z-index: 9999;",
      onclick = sprintf("if (event.target === this) $('#%s').css('display', 'none');", ns("add_conversion_modal")),
      tags$div(
        style = "position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 95vw; height: 95vh; background: white; border-radius: 8px; display: flex; flex-direction: column;",
        onclick = sprintf("event.stopPropagation(); $('#%s').hide();", ns("add_as_dropdown")),

        # Header
        tags$div(
          style = "padding: 20px; border-bottom: 1px solid #ddd; flex-shrink: 0; background: #f8f9fa; border-radius: 8px 8px 0 0; position: relative;",
          tags$h3(i18n$t("add_conversion"), style = "margin: 0;"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').css('display', 'none');", ns("add_conversion_modal")),
            "\u00D7"
          )
        ),

        # Body
        tags$div(
          style = "flex: 1; min-height: 0; padding: 20px; display: flex; flex-direction: column; gap: 20px;",

          # Top section: Input fields
          tags$div(
            style = "flex-shrink: 0; display: flex; gap: 20px; align-items: flex-end; flex-wrap: wrap;",

            # Concept 1
            tags$div(
              style = "flex: 1; min-width: 150px;",
              tags$label(i18n$t("concept_id_1"), style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              textInput(ns("new_concept_id_1"), label = NULL, value = "", width = "100%"),
              tags$div(id = ns("new_concept_id_1_error"), class = "input-error-message", i18n$t("field_required"))
            ),

            # Unit 1
            tags$div(
              style = "flex: 1; min-width: 150px;",
              tags$label(i18n$t("unit_concept_id_1"), style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              textInput(ns("new_unit_id_1"), label = NULL, value = "", width = "100%"),
              tags$div(id = ns("new_unit_id_1_error"), class = "input-error-message", i18n$t("field_required"))
            ),

            # Conversion Factor
            tags$div(
              style = "flex: 0.5; min-width: 100px;",
              tags$label(i18n$t("conversion_factor"), style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              numericInput(ns("new_conversion_factor"), label = NULL, value = 1, min = 0, step = 0.001, width = "100%"),
              tags$div(id = ns("new_conversion_factor_error"), class = "input-error-message", i18n$t("field_required"))
            ),

            # Concept 2
            tags$div(
              style = "flex: 1; min-width: 150px;",
              tags$label(i18n$t("concept_id_2"), style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              textInput(ns("new_concept_id_2"), label = NULL, value = "", width = "100%"),
              tags$div(id = ns("new_concept_id_2_error"), class = "input-error-message", i18n$t("field_required"))
            ),

            # Unit 2
            tags$div(
              style = "flex: 1; min-width: 150px;",
              tags$label(i18n$t("unit_concept_id_2"), style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              textInput(ns("new_unit_id_2"), label = NULL, value = "", width = "100%"),
              tags$div(id = ns("new_unit_id_2_error"), class = "input-error-message", i18n$t("field_required"))
            )
          ),

          # Conversion preview display
          tags$div(
            id = ns("conversion_preview"),
            style = "flex-shrink: 0; padding: 12px 16px; background: #f0f7ff; border: 1px solid #cce0ff; border-radius: 6px; text-align: center; font-size: 14px; color: #333; display: none;",
            tags$span(id = ns("preview_concept_1"), style = "font-weight: 600;"),
            tags$span("("),
            tags$span(id = ns("preview_unit_1"), style = "color: #666;"),
            tags$span(")"),
            tags$span(id = ns("preview_factor"), style = "color: #0f60af; font-weight: 700; margin: 0 8px;"),
            tags$span("\u2192 "),
            tags$span(id = ns("preview_concept_2"), style = "font-weight: 600;"),
            tags$span("("),
            tags$span(id = ns("preview_unit_2"), style = "color: #666;"),
            tags$span(")")
          ),

          # OMOP Search section
          tags$div(
            style = "flex: 1; min-height: 0; display: flex; flex-direction: column; border: 1px solid #ddd; border-radius: 4px; padding: 15px; background: #fafafa;",
            tags$div(
              style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 10px;",

              # Add as dropdown button
              tags$div(
                class = "dropdown",
                style = "position: relative; display: inline-block;",
                onclick = "event.stopPropagation();",
                tags$button(
                  id = ns("add_as_btn"),
                  class = "btn-primary-custom",
                  style = "display: flex; align-items: center; gap: 6px;",
                  onclick = sprintf("event.stopPropagation(); $('#%s').toggle();", ns("add_as_dropdown")),
                  tags$i(class = "fa fa-plus"),
                  i18n$t("add_as"),
                  tags$i(class = "fa fa-caret-down", style = "margin-left: 4px;")
                ),
                tags$div(
                  id = ns("add_as_dropdown"),
                  style = "display: none; position: absolute; right: 0; top: 100%; background: white; border: 1px solid #ddd; border-radius: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 1000; min-width: 180px;",
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer; border-bottom: 1px solid #eee;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'concept_1', {priority: 'event'}); $('#%s').hide();", ns("add_as_selection"), ns("add_as_dropdown")),
                    i18n$t("concept_id_1")
                  ),
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer; border-bottom: 1px solid #eee;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'unit_1', {priority: 'event'}); $('#%s').hide();", ns("add_as_selection"), ns("add_as_dropdown")),
                    i18n$t("unit_concept_id_1")
                  ),
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer; border-bottom: 1px solid #eee;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'concept_2', {priority: 'event'}); $('#%s').hide();", ns("add_as_selection"), ns("add_as_dropdown")),
                    i18n$t("concept_id_2")
                  ),
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'unit_2', {priority: 'event'}); $('#%s').hide();", ns("add_as_selection"), ns("add_as_dropdown")),
                    i18n$t("unit_concept_id_2")
                  )
                )
              )
            ),
            tags$div(
              style = "flex: 1; min-height: 0; overflow: auto; position: relative;",
              shinycssloaders::withSpinner(
                DT::DTOutput(ns("omop_search_table")),
                type = 4,
                color = "#0f60af",
                size = 0.5
              )
            )
          ),

          # Footer with Save button
          tags$div(
            style = "flex-shrink: 0; display: flex; justify-content: flex-end; gap: 10px; padding-top: 10px; border-top: 1px solid #ddd;",
            tags$button(
              class = "btn-secondary-custom",
              onclick = sprintf("$('#%s').css('display', 'none');", ns("add_conversion_modal")),
              i18n$t("cancel")
            ),
            actionButton(
              ns("save_new_conversion_btn"),
              label = tagList(
                tags$i(class = "fa fa-plus", style = "margin-right: 6px;"),
                i18n$t("add")
              ),
              class = "btn-primary-custom"
            )
          )
        )
      )
    )
  )
}

# SERVER SECTION ====

#' Dictionary Settings Module - Server
#'
#' @description Server function for dictionary settings
#'
#' @param id Module ID
#' @param config Application configuration
#' @param current_user Reactive containing current user data
#' @param vocabularies Reactive containing OHDSI vocabularies data
#' @param i18n Translator object for internationalization
#' @param log_level Log level for debugging
#'
#' @return NULL
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent renderUI req downloadHandler
mod_dictionary_settings_server <- function(id, config, current_user, vocabularies = NULL, i18n = NULL, log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ## 1) Server - Reactive Values & State ----

    ### Dictionary Upload State ----
    dictionary_upload_message <- reactiveVal(NULL)

    ### Unit Conversions State ----
    unit_conversions_data <- reactiveVal(NULL)
    unit_conversions_trigger <- reactiveVal(0)

    ## 2) Server - Data Dictionary ----

    ### Download Dictionary Handler ----

    output$download_dictionary <- downloadHandler(
      filename = function() {
        paste0("indicate_dictionary_", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".zip")
      },
      content = function(file) {
        data_dict_dir <- get_user_data_dictionary_dir()

        # Get all files in data_dictionary folder
        all_files <- list.files(data_dict_dir, recursive = TRUE, full.names = TRUE)

        if (length(all_files) == 0) {
          # Create empty zip if no files
          file.create(file)
          return()
        }

        # Create a temporary directory for the export
        temp_dir <- file.path(tempdir(), "indicate_dictionary_export")
        if (dir.exists(temp_dir)) {
          unlink(temp_dir, recursive = TRUE)
        }
        dir.create(temp_dir, recursive = TRUE)

        # Copy files preserving directory structure
        for (f in all_files) {
          rel_path <- sub(paste0("^", normalizePath(data_dict_dir), "/?"), "", normalizePath(f))
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

    ### Upload Dictionary Handler ----

    observe_event(input$upload_dictionary_file, {
      file <- input$upload_dictionary_file
      if (is.null(file)) return()

      tryCatch({
        # Create a temporary directory for extraction
        extract_dir <- file.path(tempdir(), "indicate_dictionary_import")
        if (dir.exists(extract_dir)) {
          unlink(extract_dir, recursive = TRUE)
        }
        dir.create(extract_dir, recursive = TRUE)

        # Extract ZIP file
        unzip(file$datapath, exdir = extract_dir)

        # Get list of extracted files
        extracted_files <- list.files(extract_dir, recursive = TRUE, full.names = TRUE)

        if (length(extracted_files) == 0) {
          dictionary_upload_message(list(
            success = FALSE,
            message = "The ZIP file appears to be empty or invalid."
          ))
          unlink(extract_dir, recursive = TRUE)
          return()
        }

        # Check for expected CSV files
        csv_files <- list.files(extract_dir, pattern = "\\.csv$", recursive = TRUE)
        expected_files <- c("general_concepts_en.csv", "general_concepts_details.csv")
        found_expected <- sum(basename(csv_files) %in% expected_files)

        if (found_expected == 0) {
          dictionary_upload_message(list(
            success = FALSE,
            message = "No valid dictionary files found. Expected files like general_concepts_en.csv, general_concepts_details.csv"
          ))
          unlink(extract_dir, recursive = TRUE)
          return()
        }

        # Get target directory
        data_dict_dir <- get_user_data_dictionary_dir()

        # Copy files to data_dictionary folder
        for (f in extracted_files) {
          rel_path <- sub(paste0("^", normalizePath(extract_dir), "/?"), "", normalizePath(f))
          dest_path <- file.path(data_dict_dir, rel_path)
          dest_dir <- dirname(dest_path)
          if (!dir.exists(dest_dir)) {
            dir.create(dest_dir, recursive = TRUE)
          }
          file.copy(f, dest_path, overwrite = TRUE)
        }

        # Clean up
        unlink(extract_dir, recursive = TRUE)

        # Show success message
        dictionary_upload_message(list(
          success = TRUE,
          message = paste(length(extracted_files), "files imported successfully."),
          reload_required = TRUE
        ))

      }, error = function(e) {
        dictionary_upload_message(list(
          success = FALSE,
          message = paste("Error importing dictionary:", e$message)
        ))
      })
    })

    ### Dictionary Upload Status Display ----

    dictionary_upload_status_trigger <- reactiveVal(0)

    observe_event(dictionary_upload_message(), {
      dictionary_upload_status_trigger(dictionary_upload_status_trigger() + 1)
    })

    observe_event(dictionary_upload_status_trigger(), {
      output$dictionary_upload_status <- renderUI({
        msg <- dictionary_upload_message()

        if (is.null(msg)) {
          return(NULL)
        }

        if (msg$success) {
          tags$div(
            tags$div(
              style = "margin-top: 10px; padding: 10px; background: #d4edda; border-left: 3px solid #28a745; border-radius: 4px; font-size: 12px;",
              tags$i(class = "fas fa-check-circle", style = "margin-right: 6px; color: #28a745;"),
              msg$message,
              if (isTRUE(msg$reload_required)) {
                tagList(
                  " ",
                  tags$strong("Please reload the application to apply changes.")
                )
              }
            ),
            if (isTRUE(msg$reload_required)) {
              tags$div(
                style = "margin-top: 10px;",
                actionButton(
                  ns("reload_after_dictionary_import"),
                  "Reload application",
                  class = "btn-primary-custom",
                  icon = icon("sync-alt"),
                  onclick = "location.reload();"
                )
              )
            }
          )
        } else {
          tags$div(
            style = "margin-top: 10px; padding: 10px; background: #f8d7da; border-left: 3px solid #dc3545; border-radius: 4px; font-size: 12px;",
            tags$i(class = "fas fa-exclamation-circle", style = "margin-right: 6px; color: #dc3545;"),
            msg$message
          )
        }
      })
    }, ignoreInit = FALSE)

    ## 3) Server - Global Comment ----

    ### Load Global Comment on Init ----
    observe({
      comment <- get_global_comment()
      if (!is.null(comment) && nchar(comment) > 0) {
        updateTextAreaInput(session, "global_comment_input", value = comment)
      }
    }, priority = 100)

    ### Live Preview of Global Comment ----
    observe_event(input$global_comment_input, {
      output$global_comment_preview <- renderUI({
        text <- input$global_comment_input
        if (is.null(text) || nchar(text) == 0) {
          tags$div(
            style = "color: #999; font-style: italic; margin: 5px;",
            "Preview will appear here as you type..."
          )
        } else {
          tags$div(
            class = "markdown-content",
            style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.1); margin: 5px; height: 100%; overflow-y: auto;",
            shiny::markdown(text)
          )
        }
      })
    }, ignoreInit = FALSE)

    ### Save Global Comment Handler ----
    observe_event(input$save_global_comment_btn, {
      comment_text <- input$global_comment_input

      # Handle NULL or empty input
      if (is.null(comment_text)) {
        comment_text <- ""
      }

      # Save to file
      data_dict_dir <- get_user_data_dictionary_dir()
      file_path <- file.path(data_dict_dir, "global_comment.txt")
      writeLines(comment_text, file_path)

      showNotification(i18n$t("global_comment_saved"), type = "message")
    })

    ## 4) Server - Unit Conversions ----

    ### Load Conversions on Init ----
    # Load data immediately at module initialization
    csv_dir <- get_user_data_dictionary_dir()
    file_path <- file.path(csv_dir, "unit_conversions.csv")

    if (file.exists(file_path)) {
      conversions <- read.csv(file_path, stringsAsFactors = FALSE)
      unit_conversions_data(conversions)
    } else {
      unit_conversions_data(data.frame(
        omop_concept_id_1 = integer(),
        unit_concept_id_1 = integer(),
        conversion_factor = numeric(),
        omop_concept_id_2 = integer(),
        unit_concept_id_2 = integer()
      ))
    }
    unit_conversions_trigger(1)

    ### DataTable Display ----
    observe_event(unit_conversions_trigger(), {
      output$unit_conversions_table <- DT::renderDT({
        conversions <- unit_conversions_data()
        if (is.null(conversions) || nrow(conversions) == 0) {
          return(DT::datatable(
            data.frame(Message = i18n$t("no_unit_conversions")),
            options = list(dom = 't'),
            rownames = FALSE,
            selection = 'none'
          ))
        }

        # Get concept names from vocabularies if available
        vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL

        # Prepare display data
        display_data <- conversions

        if (!is.null(vocab_data)) {
          # Get concept names for concept ID 1
          concept_ids_1 <- unique(conversions$omop_concept_id_1)
          concept_names_1 <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% concept_ids_1) %>%
            dplyr::select(concept_id, concept_name) %>%
            dplyr::collect()

          # Get concept names for concept ID 2
          concept_ids_2 <- unique(conversions$omop_concept_id_2)
          concept_names_2 <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% concept_ids_2) %>%
            dplyr::select(concept_id, concept_name) %>%
            dplyr::collect()

          # Get unit concept names
          unit_ids <- unique(c(conversions$unit_concept_id_1, conversions$unit_concept_id_2))
          unit_names <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% unit_ids) %>%
            dplyr::select(concept_id, concept_name) %>%
            dplyr::collect()

          # Merge names
          display_data <- conversions %>%
            dplyr::left_join(concept_names_1, by = c("omop_concept_id_1" = "concept_id")) %>%
            dplyr::rename(concept_name_1 = concept_name) %>%
            dplyr::left_join(concept_names_2, by = c("omop_concept_id_2" = "concept_id")) %>%
            dplyr::rename(concept_name_2 = concept_name) %>%
            dplyr::left_join(unit_names, by = c("unit_concept_id_1" = "concept_id")) %>%
            dplyr::rename(unit_name_1 = concept_name) %>%
            dplyr::left_join(unit_names, by = c("unit_concept_id_2" = "concept_id")) %>%
            dplyr::rename(unit_name_2 = concept_name)

          # Replace NA names with IDs
          display_data$concept_name_1 <- ifelse(
            is.na(display_data$concept_name_1),
            paste0("Concept ", display_data$omop_concept_id_1),
            display_data$concept_name_1
          )
          display_data$concept_name_2 <- ifelse(
            is.na(display_data$concept_name_2),
            paste0("Concept ", display_data$omop_concept_id_2),
            display_data$concept_name_2
          )
          display_data$unit_name_1 <- ifelse(
            is.na(display_data$unit_name_1),
            paste0("Unit ", display_data$unit_concept_id_1),
            display_data$unit_name_1
          )
          display_data$unit_name_2 <- ifelse(
            is.na(display_data$unit_name_2),
            paste0("Unit ", display_data$unit_concept_id_2),
            display_data$unit_name_2
          )
        } else {
          # No vocabulary data - use IDs as names
          display_data$concept_name_1 <- paste0("Concept ", conversions$omop_concept_id_1)
          display_data$concept_name_2 <- paste0("Concept ", conversions$omop_concept_id_2)
          display_data$unit_name_1 <- paste0("Unit ", conversions$unit_concept_id_1)
          display_data$unit_name_2 <- paste0("Unit ", conversions$unit_concept_id_2)
        }

        # Add row index for deletion
        display_data$row_index <- seq_len(nrow(display_data))

        # Create action buttons HTML (Test + Delete) with CSS classes for hover
        test_label <- i18n$t("test")
        delete_label <- i18n$t("delete")
        display_data$actions <- sapply(seq_len(nrow(display_data)), function(i) {
          sprintf(
            '<button class="btn-action-test test-conversion-btn" data-row="%d">%s</button><button class="btn-action-delete delete-conversion-btn" data-row="%d">%s</button>',
            i,
            test_label,
            i,
            delete_label
          )
        })

        # Select and order columns for display
        table_data <- display_data %>%
          dplyr::select(
            omop_concept_id_1,
            concept_name_1,
            unit_name_1,
            conversion_factor,
            omop_concept_id_2,
            concept_name_2,
            unit_name_2,
            actions
          )

        DT::datatable(
          table_data,
          selection = 'none',
          rownames = FALSE,
          escape = FALSE,
          filter = 'top',
          class = 'cell-border stripe hover',
          extensions = 'Buttons',
          editable = list(target = 'cell', disable = list(columns = c(0, 1, 2, 4, 5, 6, 7))),
          callback = DT::JS(sprintf("
            table.on('click', '.delete-conversion-btn', function() {
              var row = $(this).data('row');
              Shiny.setInputValue('%s', row, {priority: 'event'});
            });
            table.on('click', '.test-conversion-btn', function() {
              var row = $(this).data('row');
              Shiny.setInputValue('%s', row, {priority: 'event'});
            });
          ", ns("delete_conversion_click"), ns("test_conversion_click"))),
          options = list(
            pageLength = 20,
            lengthMenu = list(c(10, 20, 50, 100, -1), c('10', '20', '50', '100', 'All')),
            dom = 'Bltip',
            buttons = list(
              list(
                extend = 'colvis',
                text = i18n$t("columns")
              )
            ),
            ordering = TRUE,
            language = get_datatable_language(),
            columnDefs = list(
              list(width = "100px", targets = 0),
              list(width = "200px", targets = 1),
              list(width = "100px", targets = 2),
              list(width = "100px", targets = 3, className = "dt-center"),
              list(width = "100px", targets = 4),
              list(width = "200px", targets = 5),
              list(width = "100px", targets = 6),
              list(width = "160px", targets = 7, className = "dt-center", searchable = FALSE)
            )
          ),
          colnames = c(
            i18n$t("concept_id_1"),
            i18n$t("concept_name_1"),
            i18n$t("unit_1"),
            i18n$t("conversion_factor"),
            i18n$t("concept_id_2"),
            i18n$t("concept_name_2"),
            i18n$t("unit_2"),
            i18n$t("actions")
          )
        )
      })
    }, ignoreInit = FALSE)

    ### Edit Handler - Update conversion factor on cell edit ----
    observe_event(input$unit_conversions_table_cell_edit, {
      info <- input$unit_conversions_table_cell_edit
      if (is.null(info)) return()

      # Only allow editing conversion_factor column (index 3, 0-based)
      if (info$col != 3) return()

      row <- info$row
      new_value <- as.numeric(info$value)

      if (is.na(new_value) || new_value <= 0) {
        showNotification(i18n$t("invalid_conversion_factor"), type = "error")
        return()
      }

      # Update the data
      conversions <- unit_conversions_data()
      if (!is.null(conversions) && row <= nrow(conversions)) {
        conversions$conversion_factor[row] <- new_value

        # Save to CSV
        csv_dir <- get_user_data_dictionary_dir()
        file_path <- file.path(csv_dir, "unit_conversions.csv")
        write.csv(conversions, file_path, row.names = FALSE)

        unit_conversions_data(conversions)
        showNotification(i18n$t("conversion_factor_updated"), type = "message")
      }
    })

    ### Delete Handler - Show confirmation modal ----
    delete_row_index <- reactiveVal(NULL)

    observe_event(input$delete_conversion_click, {
      row_index <- input$delete_conversion_click
      if (is.null(row_index) || row_index < 1) return()

      conversions <- unit_conversions_data()
      if (!is.null(conversions) && row_index <= nrow(conversions)) {
        delete_row_index(row_index)
        shinyjs::runjs(sprintf("$('#%s').show();", ns("delete_confirmation_modal")))
      }
    })

    ### Confirm Delete Handler - Remove selected conversion ----
    observe_event(input$confirm_delete_btn, {
      row_index <- delete_row_index()
      if (is.null(row_index) || row_index < 1) return()

      conversions <- unit_conversions_data()
      if (!is.null(conversions) && row_index <= nrow(conversions)) {
        # Remove the row
        conversions <- conversions[-row_index, ]

        # Save to CSV
        csv_dir <- get_user_data_dictionary_dir()
        file_path <- file.path(csv_dir, "unit_conversions.csv")
        write.csv(conversions, file_path, row.names = FALSE)

        unit_conversions_data(conversions)
        unit_conversions_trigger(unit_conversions_trigger() + 1)

        # Close modal and show notification
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_confirmation_modal")))
        showNotification(i18n$t("conversion_deleted"), type = "message")
      }

      # Reset the delete row index
      delete_row_index(NULL)
    })

    ### Test Conversion Modal ----
    test_conversion_row <- reactiveVal(NULL)

    observe_event(input$test_conversion_click, {
      row_index <- input$test_conversion_click
      if (is.null(row_index) || row_index < 1) return()

      conversions <- unit_conversions_data()
      if (!is.null(conversions) && row_index <= nrow(conversions)) {
        test_conversion_row(conversions[row_index, ])
        shinyjs::runjs(sprintf("$('#%s').show();", ns("test_conversion_modal")))
      }
    })

    # Store unit codes for result display
    test_unit_code_2 <- reactiveVal("")

    # Display conversion info
    observe_event(test_conversion_row(), {
      conv <- test_conversion_row()
      if (is.null(conv)) return()

      # Get concept names and unit codes from vocabulary
      vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL
      concept_name_1 <- paste0("Concept ", conv$omop_concept_id_1)
      concept_name_2 <- paste0("Concept ", conv$omop_concept_id_2)
      unit_code_1 <- ""
      unit_code_2 <- ""

      if (!is.null(vocab_data)) {
        concept_info <- vocab_data$concept %>%
          dplyr::filter(concept_id %in% c(conv$omop_concept_id_1, conv$omop_concept_id_2, conv$unit_concept_id_1, conv$unit_concept_id_2)) %>%
          dplyr::select(concept_id, concept_name, concept_code) %>%
          dplyr::collect()

        c1 <- concept_info[concept_info$concept_id == conv$omop_concept_id_1, ]
        c2 <- concept_info[concept_info$concept_id == conv$omop_concept_id_2, ]
        u1 <- concept_info[concept_info$concept_id == conv$unit_concept_id_1, ]
        u2 <- concept_info[concept_info$concept_id == conv$unit_concept_id_2, ]

        if (nrow(c1) > 0) concept_name_1 <- c1$concept_name[1]
        if (nrow(c2) > 0) concept_name_2 <- c2$concept_name[1]
        if (nrow(u1) > 0) unit_code_1 <- u1$concept_code[1]
        if (nrow(u2) > 0) unit_code_2 <- u2$concept_code[1]
      }

      # Store unit 2 for result display
      test_unit_code_2(unit_code_2)

      output$test_conversion_info <- renderUI({
        tags$div(
          style = "background: #f8f9fa; padding: 15px; border-radius: 4px;",
          tags$p(
            style = "margin: 0; font-size: 14px;",
            tags$strong(concept_name_1), if (unit_code_1 != "") paste0(" (", unit_code_1, ")") else "",
            tags$span(style = "margin: 0 10px;", "→"),
            tags$strong(concept_name_2), if (unit_code_2 != "") paste0(" (", unit_code_2, ")") else ""
          )
        )
      })

      # Update labels (concept name for concepts)
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_value_1_label"), concept_name_1))
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_value_2_label"), concept_name_2))
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_unit_1_display"), unit_code_1))
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_factor_display"), conv$conversion_factor))

      # Trigger initial calculation
      input_val <- input$test_value_1
      if (is.null(input_val) || is.na(input_val)) input_val <- 1
      result <- input_val * conv$conversion_factor
      result_text <- paste0(round(result, 6), " ", unit_code_2)
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_result_display"), result_text))
    }, ignoreInit = TRUE)

    # Calculate result when value changes
    observe_event(input$test_value_1, {
      conv <- test_conversion_row()
      if (is.null(conv)) return()

      input_val <- input$test_value_1
      if (is.null(input_val) || is.na(input_val)) input_val <- 0

      result <- input_val * conv$conversion_factor
      unit_code_2 <- test_unit_code_2()
      result_text <- paste0(round(result, 6), " ", unit_code_2)
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_result_display"), result_text))
    }, ignoreInit = FALSE)

    ### Add Conversion Modal ----

    # Trigger for OMOP search table refresh
    omop_search_trigger <- reactiveVal(0)

    # Store OMOP search data for row selection
    omop_search_data <- reactiveVal(NULL)

    # Open modal
    observe_event(input$add_conversion_btn, {
      # Reset fields
      updateTextInput(session, "new_concept_id_1", value = "")
      updateTextInput(session, "new_unit_id_1", value = "")
      updateNumericInput(session, "new_conversion_factor", value = 1)
      updateTextInput(session, "new_concept_id_2", value = "")
      updateTextInput(session, "new_unit_id_2", value = "")

      # Hide error messages
      shinyjs::runjs(sprintf("$('#%s, #%s, #%s, #%s, #%s').hide();",
        ns("new_concept_id_1_error"),
        ns("new_unit_id_1_error"),
        ns("new_conversion_factor_error"),
        ns("new_concept_id_2_error"),
        ns("new_unit_id_2_error")
      ))

      # Hide conversion preview
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("conversion_preview")))

      shinyjs::runjs(sprintf("$('#%s').css('display', 'flex');", ns("add_conversion_modal")))

      # Trigger table refresh after modal is visible
      omop_search_trigger(omop_search_trigger() + 1)
    })

    # OMOP Search DataTable for Add Modal - only loads data when trigger > 0
    output$omop_search_table <- DT::renderDT({
      # Wait for modal to open (trigger > 0)
      trigger_val <- omop_search_trigger()
      if (trigger_val == 0) {
        omop_search_data(NULL)
        return(NULL)
      }

      vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL

      # Show loading message if vocabularies not loaded
      if (is.null(vocab_data)) {
        omop_search_data(NULL)
        return(DT::datatable(
          data.frame(Message = i18n$t("loading_vocabularies")),
          options = list(dom = 't', ordering = FALSE),
          rownames = FALSE,
          selection = 'single'
        ))
      }

      data <- vocab_data$concept %>%
        dplyr::filter(is.na(invalid_reason)) %>%
        dplyr::select(
          concept_id,
          concept_name,
          vocabulary_id,
          domain_id,
          concept_class_id,
          concept_code,
          standard_concept
        ) %>%
        dplyr::collect()

      # Show message if no concepts found
      if (nrow(data) == 0) {
        omop_search_data(NULL)
        return(DT::datatable(
          data.frame(Message = i18n$t("no_vocabularies_loaded")),
          options = list(dom = 't', ordering = FALSE),
          rownames = FALSE,
          selection = 'single'
        ))
      }

      # Convert for better filtering
      data$concept_id <- as.character(data$concept_id)
      data$vocabulary_id <- as.factor(data$vocabulary_id)
      data$domain_id <- as.factor(data$domain_id)
      data$concept_class_id <- as.factor(data$concept_class_id)

      # Store data for row selection
      omop_search_data(data)

      DT::datatable(
        data,
        selection = 'single',
        rownames = FALSE,
        filter = 'top',
        class = 'cell-border stripe hover compact',
        options = list(
          pageLength = 15,
          lengthMenu = list(c(10, 15, 25, 50, -1), c('10', '15', '25', '50', 'All')),
          dom = 'ltip',
          language = get_datatable_language(),
          ordering = TRUE,
          autoWidth = FALSE,
          paging = TRUE,
          columnDefs = list(
            list(width = "80px", targets = 0),
            list(width = "250px", targets = 1),
            list(width = "100px", targets = 2),
            list(width = "100px", targets = 3),
            list(width = "120px", targets = 4),
            list(width = "100px", targets = 5),
            list(width = "50px", targets = 6, className = "dt-center")
          )
        ),
        colnames = c(
          i18n$t("concept_id"),
          i18n$t("concept_name"),
          i18n$t("vocabulary"),
          i18n$t("domain"),
          i18n$t("concept_class"),
          i18n$t("code"),
          "S"
        )
      )
    }, server = FALSE)

    # Handle "Add as" dropdown selection
    observe_event(input$add_as_selection, {
      selection <- input$add_as_selection
      selected_rows <- input$omop_search_table_rows_selected

      if (is.null(selection) || length(selected_rows) == 0) {
        showNotification(i18n$t("select_concept_first"), type = "warning")
        return()
      }

      # Get stored data from reactive
      data <- omop_search_data()
      if (is.null(data)) return()
      if (selected_rows[1] > nrow(data)) return()

      selected_concept <- data[selected_rows[1], ]
      concept_id <- as.character(selected_concept$concept_id)

      if (selection == "concept_1") {
        updateTextInput(session, "new_concept_id_1", value = concept_id)
      } else if (selection == "unit_1") {
        updateTextInput(session, "new_unit_id_1", value = concept_id)
      } else if (selection == "concept_2") {
        updateTextInput(session, "new_concept_id_2", value = concept_id)
      } else if (selection == "unit_2") {
        updateTextInput(session, "new_unit_id_2", value = concept_id)
      }

      # Trigger preview update
      preview_trigger(preview_trigger() + 1)
    })

    # Trigger for preview updates
    preview_trigger <- reactiveVal(0)

    # Update preview when text inputs change manually
    observe_event(input$new_concept_id_1, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(input$new_unit_id_1, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(input$new_concept_id_2, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(input$new_unit_id_2, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(input$new_conversion_factor, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    # Helper function to get concept name from ID
    get_concept_name <- function(concept_id_str) {
      if (is.null(concept_id_str) || concept_id_str == "") return("")

      concept_id_num <- suppressWarnings(as.integer(concept_id_str))
      if (is.na(concept_id_num)) return("")

      vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL
      if (is.null(vocab_data)) return("")

      concept_info <- vocab_data$concept %>%
        dplyr::filter(concept_id == concept_id_num) %>%
        dplyr::select(concept_name) %>%
        dplyr::collect()

      if (nrow(concept_info) > 0) {
        return(concept_info$concept_name[1])
      }
      return(i18n$t("concept_not_found"))
    }

    # Update conversion preview display
    observe_event(preview_trigger(), {
      concept_1 <- get_concept_name(input$new_concept_id_1)
      unit_1 <- get_concept_name(input$new_unit_id_1)
      concept_2 <- get_concept_name(input$new_concept_id_2)
      unit_2 <- get_concept_name(input$new_unit_id_2)
      factor <- input$new_conversion_factor

      # Check if at least one field has content
      has_content <- any(c(concept_1, unit_1, concept_2, unit_2) != "")

      if (has_content) {
        # Update preview content
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("preview_concept_1"), if (concept_1 != "") concept_1 else "?"))
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("preview_unit_1"), if (unit_1 != "") unit_1 else "?"))
        shinyjs::runjs(sprintf("$('#%s').text('\u00D7 %s');", ns("preview_factor"), if (!is.null(factor) && !is.na(factor)) factor else "1"))
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("preview_concept_2"), if (concept_2 != "") concept_2 else "?"))
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("preview_unit_2"), if (unit_2 != "") unit_2 else "?"))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("conversion_preview")))
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("conversion_preview")))
      }
    }, ignoreInit = TRUE)

    # Save new conversion
    observe_event(input$save_new_conversion_btn, {
      # Get values
      concept_id_1 <- input$new_concept_id_1
      unit_id_1 <- input$new_unit_id_1
      conversion_factor <- input$new_conversion_factor
      concept_id_2 <- input$new_concept_id_2
      unit_id_2 <- input$new_unit_id_2

      # Validate
      has_error <- FALSE

      if (is.null(concept_id_1) || concept_id_1 == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_concept_id_1_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_concept_id_1_error")))
      }

      if (is.null(unit_id_1) || unit_id_1 == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_unit_id_1_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_unit_id_1_error")))
      }

      if (is.null(conversion_factor) || is.na(conversion_factor) || conversion_factor <= 0) {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_conversion_factor_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_conversion_factor_error")))
      }

      if (is.null(concept_id_2) || concept_id_2 == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_concept_id_2_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_concept_id_2_error")))
      }

      if (is.null(unit_id_2) || unit_id_2 == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_unit_id_2_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_unit_id_2_error")))
      }

      if (has_error) return()

      # Create new row
      new_row <- data.frame(
        omop_concept_id_1 = as.integer(concept_id_1),
        unit_concept_id_1 = as.integer(unit_id_1),
        conversion_factor = as.numeric(conversion_factor),
        omop_concept_id_2 = as.integer(concept_id_2),
        unit_concept_id_2 = as.integer(unit_id_2),
        stringsAsFactors = FALSE
      )

      # Add to existing data
      conversions <- unit_conversions_data()
      if (is.null(conversions) || nrow(conversions) == 0) {
        conversions <- new_row
      } else {
        conversions <- rbind(conversions, new_row)
      }

      # Save to CSV
      csv_dir <- get_user_data_dictionary_dir()
      file_path <- file.path(csv_dir, "unit_conversions.csv")
      write.csv(conversions, file_path, row.names = FALSE)

      unit_conversions_data(conversions)
      unit_conversions_trigger(unit_conversions_trigger() + 1)

      # Close modal
      shinyjs::runjs(sprintf("$('#%s').css('display', 'none');", ns("add_conversion_modal")))
      showNotification(i18n$t("conversion_added"), type = "message")
    })
  })
}
