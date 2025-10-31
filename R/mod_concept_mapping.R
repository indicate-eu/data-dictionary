# MODULE STRUCTURE OVERVIEW ====
#
# This module manages concept mapping - aligning user-provided concepts
# (custom concepts from CSV files) with standardized INDICATE dictionary concepts.
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Breadcrumb Navigation
#      ### Dynamic Content Area (switches between views)
#   ## UI - Modals
#      ### Modal - Alignment Editor (2-page form: name/description → file upload/mapping)
#      ### Modal - Concept Details Viewer
#      ### Modal - ETL Comments Display
#      ### Modal - Delete Confirmation Dialog
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### View & Selection State - current_view, selected_alignment_id, mapping_view, etc.
#      ### Data Management - alignments_data, uploaded_alignment_data
#      ### Triggers - mappings_refresh_trigger, mapping_tab
#
#   ## 2) Server - Navigation & Events
#      ### Tab Switching - summary/edit_mappings/evaluate_mappings tabs
#
#   ## 3) Server - Outputs & Rendering
#      ### Breadcrumb Rendering - Dynamic breadcrumb navigation
#      ### Content Area Rendering - Main view switching (alignments/mapping)
#      ### General Concepts Header Rendering - Header for general concepts section
#      ### Helper Functions - View Renderers - render_alignments_view(), render_mapping_view(), etc.
#      ### Tab Content Outputs - summary_content and tab-specific outputs
#      ### Table Outputs - All DataTables (alignments, use_case_alignment, etc.)
#
#   ## 4) Server - Navigation Handlers
#      ### Back button handlers - back_to_alignments, back_to_general, etc.
#
#   ## 5) Server - Alignment Management
#      ### Add/Edit Alignment Modal - Modal handlers for creating/editing alignments
#      ### Delete Alignment - Delete confirmation and execution
#      ### File Upload & Processing - CSV/Excel upload, parsing, column mapping
#
#   ## 6) Server - Concept Mapping Interface
#      ### Source Concepts Display - source_concepts_table
#      ### General Concepts Table - general_concepts_table
#      ### Realized Mappings Table - realized_mappings_table (both views)
#      ### Concept Mappings Table (Detailed View) - concept_mappings_table
#      ### Comments Display - comments_display
#      ### Modal Renderings - concept_detail_modal_body, etl_comments_modal_body
#      ### Mapped View Tables - source_concepts_table_mapped, mapped_concepts_table
#
#   ## 7) Server - Table Interaction Handlers
#      ### Mapping Creation & Deletion - add_mapping, remove_mapping handlers
#      ### Export Functionality - export_alignment handler

#' Concept Mapping Module - UI
#'
#' @description UI function for the concept mapping module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS fluidRow column actionButton uiOutput textInput numericInput
#' @importFrom htmltools tags tagList
#' @importFrom DT DTOutput
mod_concept_mapping_ui <- function(id) {
  ns <- NS(id)

  tagList(
    shinyjs::useShinyjs(),

    # Main content for concept mapping
    div(class = "main-panel",
        div(class = "main-content",
            # Breadcrumb navigation
            uiOutput(ns("breadcrumb")),

            # Dynamic content area
            uiOutput(ns("content_area"))
        )
    ),

    # Modal for adding/editing alignment (2 pages)
    tags$div(
      id = ns("alignment_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("alignment_modal")),
      tags$div(
        id = ns("alignment_modal_dialog"),
        class = "modal-content",
        style = "max-width: 600px; max-height: 90vh; display: flex; flex-direction: column;",
        tags$div(
          class = "modal-header",
          tags$h3(id = ns("alignment_modal_title"), "Add Alignment"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("alignment_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "flex: 1; overflow: auto; padding: 20px;",
          # Page 1: Name and Description
          tags$div(
            id = ns("modal_page_1"),
            tags$div(
              style = "margin-bottom: 20px;",
              tags$label("Alignment Name", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              textInput(
                ns("alignment_name"),
                label = NULL,
                placeholder = "Enter alignment name",
                width = "100%"
              ),
              tags$div(
                id = ns("alignment_name_error"),
                style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                "Please enter an alignment name"
              )
            ),
            tags$div(
              style = "margin-bottom: 20px;",
              tags$label("Description", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              textAreaInput(
                ns("alignment_description"),
                label = NULL,
                placeholder = "Enter description",
                width = "100%",
                rows = 4
              )
            )
          ),
          # Page 2: File Upload and Preview (hidden initially)
          tags$div(
            id = ns("modal_page_2"),
            style = "display: none;",
            tags$div(
              style = "display: flex; gap: 20px; overflow: hidden;",
              # Left: Upload and column mapping
              tags$div(
                style = "flex: 1; min-width: 50%; display: flex; flex-direction: column; overflow-y: auto; gap: 10px;",
                tags$div(
                  style = "background-color: #f8f9fa; border-radius: 4px; overflow: hidden;",
                  tags$div(
                    style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px;",
                    "Upload CSV File"
                  ),
                  tags$div(
                    style = "padding: 15px;",
                    fileInput(
                      ns("alignment_file"),
                      label = NULL,
                      accept = c(".csv", ".xlsx", ".xls")
                    ),
                    tags$div(
                      id = ns("alignment_file_error"),
                      style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                      "Please upload a file"
                    )
                  )
                ),
                uiOutput(ns("csv_options")),
                uiOutput(ns("column_mapping_wrapper"))
              ),
              # Right: File preview
              tags$div(
                style = "width: 50%; display: flex; flex-direction: column; overflow-x: auto;",
                tags$div(
                  style = "margin-right: 20px;",
                  DT::DTOutput(ns("file_preview_table"))
                )
              )
            )
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "padding: 15px 20px; border-top: 1px solid #dee2e6; display: flex; align-items: center;",
          tags$div(
            id = ns("modal_page_indicator"),
            style = "color: #666; font-size: 14px;",
            "Page 1 of 2"
          ),
          tags$div(
            style = "flex: 1;"
          ),
          tags$div(
            style = "display: flex; gap: 10px;",
            actionButton(
              ns("alignment_modal_cancel"),
              "Cancel",
              class = "btn btn-secondary btn-secondary-custom"
            ),
            actionButton(
              ns("alignment_modal_back"),
              "Back",
              class = "btn btn-secondary btn-secondary-custom",
              style = "display: none;"
            ),
            actionButton(
              ns("alignment_modal_next"),
              "Next",
              class = "btn-primary-custom"
            ),
            actionButton(
              ns("alignment_modal_save"),
              "Save",
              class = "btn-success-custom",
              style = "display: none;"
            )
          )
        )
      )
    ),

    # Modal for concept details
    tags$div(
      id = ns("concept_detail_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("concept_detail_modal")),
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h3("Concept Details"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("concept_detail_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          uiOutput(ns("concept_detail_modal_body"))
        )
      )
    ),

    # Modal for ETL guidance and comments
    tags$div(
      id = ns("etl_comments_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("etl_comments_modal")),
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h3("ETL Guidance & Comments"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("etl_comments_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          uiOutput(ns("etl_comments_modal_body"))
        )
      )
    ),

    # Modal for delete confirmation
    tags$div(
      id = ns("delete_confirmation_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("delete_confirmation_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 500px;",
        tags$div(
          class = "modal-header",
          tags$h3("Confirm Deletion"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("delete_confirmation_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          tags$p(
            style = "margin-bottom: 20px;",
            "Are you sure you want to delete this alignment? This action cannot be undone."
          ),
          tags$div(
            id = ns("delete_alignment_name_display"),
            style = "font-weight: bold; margin-bottom: 20px; padding: 10px; background-color: #f8f9fa; border-radius: 4px;"
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "display: flex; justify-content: flex-end; gap: 10px;",
          tags$button(
            class = "btn btn-secondary",
            onclick = sprintf("$('#%s').hide();", ns("delete_confirmation_modal")),
            "Cancel"
          ),
          actionButton(
            ns("confirm_delete_alignment"),
            "Delete",
            class = "btn btn-danger"
          )
        )
      )
    )
  )
}

#' Concept Mapping Module - Server
#'
#' @description Server function for the concept mapping module
#'
#' @param id Module ID
#' @param data Reactive containing the main data dictionary
#' @param config Configuration list
#' @param vocabularies Reactive containing preloaded OHDSI vocabularies
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive req renderUI observe_event reactiveVal
#' @importFrom DT renderDT datatable formatStyle DTOutput
#' @importFrom dplyr filter select mutate arrange
#' @importFrom htmltools tags tagList HTML
mod_concept_mapping_server <- function(id, data, config, vocabularies, current_user = reactive(NULL), log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ## 1) Server - Reactive Values & State ----
    ### View & Selection State ----
    # Track current view and navigation state
    current_view <- reactiveVal("alignments")  # "alignments" or "mapping"
    selected_alignment_id <- reactiveVal(NULL)  # Track selected alignment for mapping
    mapping_view <- reactiveVal("general")  # "general" or "mapped" - for nested navigation
    selected_general_concept_id <- reactiveVal(NULL)  # Track selected general concept
    modal_page <- reactiveVal(1)  # Track modal page (1 or 2)
    modal_mode <- reactiveVal("add")  # "add" or "edit"
    alignment_to_delete <- reactiveVal(NULL)  # Track alignment ID to delete
    concept_mappings_view <- reactiveVal("table")  # "table" or "comments" - for right panel when general concept is selected
    file_preview_data <- reactiveVal(NULL)  # Store file preview data

    ### Data Management ----
    # Load existing alignments from database
    initial_alignments <- get_all_alignments()

    # Store alignments data
    alignments_data <- reactiveVal(initial_alignments)

    # Store uploaded file data for current alignment
    uploaded_alignment_data <- reactiveVal(NULL)

    ### Triggers ----
    # Trigger to force refresh of completed mappings table
    mappings_refresh_trigger <- reactiveVal(0)

    # Track active mapping tab
    mapping_tab <- reactiveVal("summary")  # "summary", "edit_mappings", or "evaluate_mappings"

    ## 2) Server - Navigation & Events ----

    ## 3) Server - Outputs & Rendering ----
    ### Breadcrumb Rendering ----
    output$breadcrumb <- renderUI({
      if (current_view() == "alignments") {
        NULL
      } else if (current_view() == "mapping") {
        if (is.null(selected_alignment_id())) return()
        alignment_name <- alignments_data() %>%
          dplyr::filter(alignment_id == selected_alignment_id()) %>%
          dplyr::pull(name)

        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 0; display: flex; align-items: center; gap: 10px;",
          tags$a(
            class = "breadcrumb-link",
            style = "font-size: 16px; cursor: pointer;",
            onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_alignments")),
            "Concept Mappings"
          ),
          tags$span(style = "color: #6c757d; font-size: 16px;", ">"),
          if (mapping_view() == "general") {
            tags$span(
              class = "section-title",
              style = "color: #333;",
              alignment_name
            )
          } else {
            tagList(
              tags$a(
                class = "breadcrumb-link",
                style = "font-size: 16px; cursor: pointer; color: #333;",
                onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_general")),
                alignment_name
              ),
              tags$span(style = "color: #6c757d; font-size: 16px; margin: 0 10px;", ">"),
              tags$span(
                class = "section-title",
                "Mapped Concepts"
              )
            )
          }
        )
      }
    })

    ### Content Area Rendering ----
    output$content_area <- renderUI({
      if (current_view() == "alignments") {
        render_alignments_view()
      } else if (current_view() == "mapping") {
        if (mapping_view() == "general") {
          render_mapping_view()
        } else {
          render_mapped_concepts_view()
        }
      }
    })

    ### General Concepts Header Rendering ----
    output$general_concepts_header <- renderUI({
      # Only show in mapping view with general view
      if (current_view() != "mapping" || mapping_view() != "general") return(NULL)

      # Check if a general concept is selected
      if (is.null(selected_general_concept_id())) {
        # No selection: show simple title
        tags$div(
          class = "section-header",
          tags$h4(
            "General Concepts",
            tags$span(
              class = "info-icon",
              `data-tooltip` = "General concepts from the INDICATE Minimal Data Dictionary. Double-click a row to view mapped concepts.",
              "ⓘ"
            )
          )
        )
      } else {
        # Selection: show breadcrumb
        if (is.null(data())) return()

        # Get the general concept name
        general_concepts <- data()$general_concepts
        selected_concept <- general_concepts[general_concepts$general_concept_id == selected_general_concept_id(), ]

        if (nrow(selected_concept) > 0) {
          concept_name <- selected_concept$general_concept_name[1]
        } else {
          concept_name <- "Unknown"
        }

        tags$div(
          class = "section-header",
          tags$div(
            style = "flex: 1;",
            tags$a(
              class = "breadcrumb-link",
              style = "cursor: pointer;",
              onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_general_list")),
              "General Concepts"
            ),
            tags$span(style = "color: #6c757d; margin: 0 8px;", ">"),
            tags$span(concept_name)
          ),
          # Buttons based on view
          if (concept_mappings_view() == "table") {
            actionButton(
              ns("show_comments"),
              "Comments",
              class = "btn-secondary-custom",
              style = "height: 32px; padding: 5px 15px; font-size: 14px;"
            )
          } else {
            actionButton(
              ns("back_to_mappings"),
              "Back to Mapped Concepts",
              class = "btn-secondary-custom",
              style = "height: 32px; padding: 5px 15px; font-size: 14px;"
            )
          }
        )
      }
    })

    ### Helper Functions - View Renderers ----
    # View 1: Alignments management
    render_alignments_view <- function() {
      tags$div(
        # Title and button header
        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 0; display: flex; align-items: center; gap: 15px; justify-content: space-between;",
          # Left side: Title
          tags$div(
            class = "section-title",
            "Concept Mappings"
          ),
          # Right side: Add button
          tags$div(
            style = "display: flex; gap: 10px;",
            actionButton(
              ns("add_alignment"),
              "Add Alignment",
              class = "btn-success-custom",
              icon = icon("plus")
            )
          )
        ),
        tags$div(
          class = "card-container",
          style = "padding: 20px;",
          DT::DTOutput(ns("alignments_table"))
        )
      )
    }

    # View 2: Mapping realization interface
    render_mapping_view <- function() {
      tags$div(
        class = "panel-container-full",
        style = "display: flex; flex-direction: column; height: 100%;",

        tabsetPanel(
          id = ns("mapping_tabs"),

          # Summary tab
          tabPanel(
            "Summary",
            value = "summary",
            tags$div(
              style = "margin-top: 20px;",
              uiOutput(ns("summary_content"))
            )
          ),

          # Edit mappings tab
          tabPanel(
            "Edit Mappings",
            value = "edit_mappings",
            tags$div(
              style = "margin-top: 20px; height: calc(100vh - 185px); display: flex; flex-direction: column;",
            # Top section: Source concepts (left) and target concepts (right)
            tags$div(
              style = "height: 70%; display: flex; gap: 15px; min-height: 0;",
              # Left: Source concepts to map
              tags$div(
                class = "card-container card-container-flex",
                style = "flex: 1; min-width: 0;",
                tags$div(
                  class = "section-header",
                  tags$div(
                    style = "flex: 1;",
                    tags$h4(
                      style = "margin: 0;",
                      "Source Concepts",
                      tags$span(
                        class = "info-icon",
                        `data-tooltip` = "Concepts from your uploaded CSV file to be mapped to INDICATE concepts",
                        "ⓘ"
                      )
                    )
                  ),
                  actionButton(
                    ns("add_mapping_from_general"),
                    "Add Mapping",
                    class = "btn-success-custom",
                    style = "height: 32px; padding: 5px 15px; font-size: 14px; display: none;"
                  )
                ),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto;",
                  DT::DTOutput(ns("source_concepts_table"))
                )
              ),
              # Right: Target concepts (general concepts or mapped concepts)
              tags$div(
                class = "card-container card-container-flex",
                style = "flex: 1; min-width: 0;",
                uiOutput(ns("general_concepts_header")),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto;",
                  # General concepts table - always present, just hidden
                  tags$div(
                    id = ns("general_concepts_table_container"),
                    style = "height: 100%;",
                    DT::DTOutput(ns("general_concepts_table"))
                  ),
                  # Concept mappings table - always present, just hidden
                  tags$div(
                    id = ns("concept_mappings_table_container"),
                    style = "height: 100%; display: none;",
                    DT::DTOutput(ns("concept_mappings_table"))
                  ),
                  # Comments display - always present, just hidden
                  tags$div(
                    id = ns("comments_display_container"),
                    style = "display: none;",
                    uiOutput(ns("comments_display"))
                  )
                )
              )
            ),
            # Bottom section: Completed mappings
            tags$div(
              class = "card-container",
              style = "height: 30%; display: flex; flex-direction: column; margin-top: 15px;",
              tags$div(
                class = "section-header",

                tags$h4(
                  "Completed Mappings",
                  tags$span(
                    class = "info-icon",
                    `data-tooltip` = "Mappings between your source concepts and INDICATE concepts that you have created",
                    "ⓘ"
                  )
                )
              ),
              tags$div(
                style = "flex: 1; min-height: 0; overflow: auto;",
                DT::DTOutput(ns("realized_mappings_table"))
              )
            )
            )
          ),

          # Evaluate mappings tab
          tabPanel(
            "Evaluate Mappings",
            value = "evaluate_mappings",
            tags$div(
              style = "margin-top: 20px;",
              tags$div(
                style = "padding: 40px; text-align: center; color: #999;",
                tags$p(
                  style = "font-size: 18px;",
                  "Evaluate Mappings functionality coming soon..."
                )
              )
            )
          )
        )
      )
    }

    # Nested view: Mapped concepts for selected general concept
    render_mapped_concepts_view <- function() {
      tags$div(
        class = "panel-container-full",
        style = "display: flex; flex-direction: column; height: 100%;",
        # Top section: Source concepts (left) and mapped concepts (right)
        tags$div(
          style = "height: 70%; display: flex; gap: 15px; min-height: 0;",
          # Left: Source concepts to map
          tags$div(
            class = "card-container card-container-flex",
            tags$div(
              class = "section-header",
              
              tags$h4(
                "Source Concepts",
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = "Concepts from your uploaded CSV file to be mapped to INDICATE concepts",
                  "ⓘ"
                )
              )
            ),
            tags$div(
              style = "flex: 1; min-height: 0; overflow: auto;",
              DT::DTOutput(ns("source_concepts_table_mapped"))
            )
          ),
          # Right: Mapped concepts (OMOP concepts for selected general concept)
          tags$div(
            class = "card-container card-container-flex",
            tags$div(
              class = "section-header",
              style = "height: 40px; display: flex; justify-content: space-between; align-items: center;",
              tags$h4(
                style = "margin: 0;",
                "Mapped Concepts",
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = "Specific OMOP concepts mapped to the selected general concept",
                  "ⓘ"
                )
              ),
              actionButton(
                ns("add_mapping_specific"),
                "Add Mapping",
                class = "btn-success-custom",
                style = "height: 32px; padding: 5px 15px; font-size: 14px; display: none;"
              )
            ),
            tags$div(
              style = "flex: 1; min-height: 0; overflow: hidden;",
              DT::DTOutput(ns("mapped_concepts_table"))
            )
          )
        ),
        # Bottom section: Completed mappings
        tags$div(
          class = "card-container",
          style = "height: 30%; display: flex; flex-direction: column; margin-top: 15px;",
          tags$div(
            class = "section-header",
            
            tags$h4(
              "Completed Mappings",
              tags$span(
                class = "info-icon",
                `data-tooltip` = "Mappings between your source concepts and INDICATE concepts that you have created",
                "ⓘ"
              )
            )
          ),
          tags$div(
            style = "flex: 1; min-height: 0; overflow: auto;",
            DT::DTOutput(ns("realized_mappings_table_mapped"))
          )
        )
      )
    }

    ### Tab Content Outputs ----
    output$summary_content <- renderUI({
      tags$div(
        style = "display: flex; align-items: center; justify-content: center; height: 300px;",
        tags$div(
          style = "text-align: center; color: #6c757d;",
          tags$h3("Summary Tab"),
          tags$p("This feature is coming soon...")
        )
      )
    })

    # Old summary content - commented out
    output$summary_content_OLD <- renderUI({
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) {
        return(tags$div("No alignment selected"))
      }

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Check if file exists
      if (!file.exists(csv_path)) {
        return(tags$div("CSV file not found"))
      }

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Calculate statistics
      total_source_concepts <- nrow(df)
      mapped_source_concepts <- sum(!is.na(df$target_general_concept_id))
      pct_mapped_source <- round((mapped_source_concepts / total_source_concepts) * 100, 1)

      # Get all general concepts mapped
      mapped_general_concept_ids <- unique(df$target_general_concept_id[!is.na(df$target_general_concept_id)])
      total_dictionary_concepts <- nrow(data()$general_concepts)
      mapped_dictionary_concepts <- length(mapped_general_concept_ids)
      pct_mapped_dictionary <- round((mapped_dictionary_concepts / total_dictionary_concepts) * 100, 1)

      # Calculate use case alignment
      use_cases <- data()$use_cases
      general_concept_use_cases <- data()$general_concept_use_cases

      use_case_stats <- use_cases %>%
        dplyr::rowwise() %>%
        dplyr::mutate(
          required_concepts = {
            req_concepts <- general_concept_use_cases %>%
              dplyr::filter(use_case_id == id) %>%
              dplyr::pull(general_concept_id)
            length(req_concepts)
          },
          mapped_concepts = {
            req_concepts <- general_concept_use_cases %>%
              dplyr::filter(use_case_id == id) %>%
              dplyr::pull(general_concept_id)
            sum(req_concepts %in% mapped_general_concept_ids)
          },
          pct_aligned = ifelse(required_concepts > 0, round((mapped_concepts / required_concepts) * 100, 1), 0)
        ) %>%
        dplyr::ungroup() %>%
        dplyr::select(name, short_name, required_concepts, mapped_concepts, pct_aligned) %>%
        dplyr::arrange(dplyr::desc(pct_aligned))

      # Render UI
      tags$div(
        style = "display: flex; gap: 20px; height: 100%;",

        # Left side: Summary cards
        tags$div(
          style = "flex: 0 0 50%; display: flex; flex-wrap: wrap; gap: 20px; align-content: flex-start;",

          # Card 1: Source concepts mapped
          tags$div(
            style = "flex: 0 0 calc(50% - 10px); background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); border-left: 4px solid #28a745;",
            tags$div(
              style = "font-size: 14px; color: #666; margin-bottom: 8px;",
              "Source Concepts Mapped"
            ),
            tags$div(
              style = "font-size: 32px; font-weight: 700; color: #28a745; margin-bottom: 5px;",
              paste0(mapped_source_concepts, " / ", total_source_concepts)
            ),
            tags$div(
              style = "font-size: 18px; color: #999;",
              paste0(pct_mapped_source, "%")
            )
          ),

          # Card 2: Dictionary concepts used
          tags$div(
            style = "flex: 0 0 calc(50% - 10px); background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); border-left: 4px solid #17a2b8;",
            tags$div(
              style = "font-size: 14px; color: #666; margin-bottom: 8px;",
              "Dictionary Concepts Used"
            ),
            tags$div(
              style = "font-size: 32px; font-weight: 700; color: #17a2b8; margin-bottom: 5px;",
              paste0(mapped_dictionary_concepts, " / ", total_dictionary_concepts)
            ),
            tags$div(
              style = "font-size: 18px; color: #999;",
              paste0(pct_mapped_dictionary, "%")
            )
          )
        ),

        # Right side: Use case alignment table
        tags$div(
          style = "flex: 1; display: flex; flex-direction: column; min-width: 0;",
          tags$div(
            class = "section-header",
            tags$h4("Use Case Alignment")
          ),
          tags$div(
            style = "flex: 1; margin-top: 10px; overflow: auto; background: white; border-radius: 6px; padding: 10px;",
            DT::DTOutput(ns("use_case_alignment_table"))
          )
        )
      )
    })

    # Render use case alignment table
    output$use_case_alignment_table <- DT::renderDT({
    ### Table Outputs ----
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) {
        return(datatable(data.frame()))
      }

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      if (!file.exists(csv_path)) {
        return(datatable(data.frame()))
      }

      df <- read.csv(csv_path, stringsAsFactors = FALSE)
      mapped_general_concept_ids <- unique(df$target_general_concept_id[!is.na(df$target_general_concept_id)])

      use_cases <- data()$use_cases
      general_concept_use_cases <- data()$general_concept_use_cases

      use_case_stats <- use_cases %>%
        dplyr::rowwise() %>%
        dplyr::mutate(
          required_concepts = {
            req_concepts <- general_concept_use_cases %>%
              dplyr::filter(use_case_id == id) %>%
              dplyr::pull(general_concept_id)
            length(req_concepts)
          },
          mapped_concepts = {
            req_concepts <- general_concept_use_cases %>%
              dplyr::filter(use_case_id == id) %>%
              dplyr::pull(general_concept_id)
            sum(req_concepts %in% mapped_general_concept_ids)
          },
          pct_aligned = ifelse(required_concepts > 0, round((mapped_concepts / required_concepts) * 100, 1), 0)
        ) %>%
        dplyr::ungroup() %>%
        dplyr::select(Use_Case = name, Required = required_concepts, Mapped = mapped_concepts, Alignment = pct_aligned) %>%
        dplyr::arrange(dplyr::desc(Alignment))

      dt <- datatable(
        use_case_stats,
        options = list(
          pageLength = 10,
          dom = 'tp',
          ordering = TRUE
        ),
        rownames = FALSE,
        selection = 'none'
      )

      # Add background color based on alignment percentage
      dt <- dt %>%
        DT::formatStyle(
          'Alignment',
          target = 'row',
          backgroundColor = DT::styleInterval(
            c(99.9),
            c('#ffcccc', '#ccffcc')
          )
        ) %>%
        DT::formatString('Alignment', suffix = '%')

      dt
    }, server = FALSE)

    # Render alignments table
    output$alignments_table <- DT::renderDT({
      alignments <- alignments_data()

      if (nrow(alignments) == 0) {
        # Show placeholder when no alignments
        return(datatable(
          data.frame(Message = "No alignments yet. Click 'Add Alignment' to create one."),
          options = list(dom = 't', ordering = FALSE),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Format created_date to show date and time
      alignments_display <- alignments %>%
        dplyr::mutate(
          created_formatted = format(as.POSIXct(created_date), "%Y-%m-%d %H:%M"),
          Actions = sprintf(
            '<button class="btn btn-sm btn-primary" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Open</button>
             <button class="btn btn-sm btn-warning" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Edit</button>
             <button class="btn btn-sm btn-success" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Export</button>
             <button class="btn btn-sm btn-danger" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Delete</button>',
            ns("open_alignment"), alignment_id,
            ns("edit_alignment"), alignment_id,
            ns("export_alignment"), alignment_id,
            ns("delete_alignment"), alignment_id
          )
        ) %>%
        dplyr::select(alignment_id, name, description, created_formatted, Actions)

      dt <- datatable(
        alignments_display,
        escape = FALSE,
        rownames = FALSE,
        selection = 'none',
        options = list(
          pageLength = 25,
          dom = 'tp',
          columnDefs = list(
            list(targets = 0, visible = FALSE),  # Hide alignment_id column
            list(targets = 4, orderable = FALSE, width = "300px", searchable = FALSE)
          )
        ),
        colnames = c("ID", "Name", "Description", "Created", "Actions")
      )

      # Add JavaScript callback for double-click
      dt <- add_doubleclick_handler(dt, ns("open_alignment"))

      dt
    }, server = FALSE)

    # Handle navigation: back to alignments list

    ## 4) Server - Navigation Handlers ----
    observe_event(input$back_to_alignments, {
      current_view("alignments")
      selected_alignment_id(NULL)
      mapping_view("general")
      selected_general_concept_id(NULL)
    })

    # Handle navigation: back to general concepts in mapping view
    observe_event(input$back_to_general, {
      mapping_view("general")
      selected_general_concept_id(NULL)
    })

    # Handle back to general concepts list
    observe_event(input$back_to_general_list, {
      selected_general_concept_id(NULL)
      concept_mappings_view("table")  # Reset to table view

      # Show/hide appropriate tables
      shinyjs::show("general_concepts_table_container")
      shinyjs::hide("concept_mappings_table_container")
      shinyjs::hide("comments_display_container")
    })

    # Show comments view
    observe_event(input$show_comments, {
      concept_mappings_view("comments")

      # Show/hide appropriate tables
      shinyjs::hide("concept_mappings_table_container")
      shinyjs::show("comments_display_container")
    })

    # Back to mapped concepts table
    observe_event(input$back_to_mappings, {
      concept_mappings_view("table")

      # Show/hide appropriate tables
      shinyjs::show("concept_mappings_table_container")
      shinyjs::hide("comments_display_container")
    })

    # Handle when a general concept is selected (show mappings table)
    observe_event(input$view_mapped_concepts, {
      general_concept_id <- input$view_mapped_concepts
      selected_general_concept_id(general_concept_id)

      # Show/hide appropriate tables
      shinyjs::hide("general_concepts_table_container")
      shinyjs::show("concept_mappings_table_container")
      shinyjs::hide("comments_display_container")

      # Hide Add Mapping button until selections are made
      shinyjs::hide("add_mapping_from_general")
    })

    # Hide Add Mapping button when general concept is selected for the first time
    observe_event(selected_general_concept_id(), {
      if (!is.null(selected_general_concept_id())) {
        shinyjs::hide("add_mapping_from_general")
      }
    })

    # Handle open alignment (navigate to mapping view)
    observe_event(input$open_alignment, {
      selected_alignment_id(input$open_alignment)
      current_view("mapping")
      mapping_view("general")
    })

    # Hide error message when user starts typing

    ## 5) Server - Alignment Management ----
    observe_event(input$alignment_name, {
      if (!is.null(input$alignment_name) && input$alignment_name != "") {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_name_error")))
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))
      }
    })

    # Handle add alignment button
    observe_event(input$add_alignment, {
    ### Add/Edit Alignment Modal ----

      modal_mode("add")
      modal_page(1)

      # Reset modal inputs
      updateTextInput(session, "alignment_name", value = "")
      updateTextInput(session, "alignment_description", value = "")

      # Hide any error messages
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_name_error")))
      shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))

      # Update modal title
      shinyjs::runjs(sprintf("$('#%s').text('Add Alignment');", ns("alignment_modal_title")))

      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal")))
    })

    # Handle edit alignment button
    observe_event(input$edit_alignment, {
      alignment_id <- input$edit_alignment
      alignment <- alignments_data() %>% filter(alignment_id == !!alignment_id)

      if (nrow(alignment) > 0) {
        modal_mode("edit")
        modal_page(1)
        selected_alignment_id(alignment_id)

        # Populate modal with existing data
        updateTextInput(session, "alignment_name", value = alignment$name)
        updateTextInput(session, "alignment_description", value = alignment$description)

        # Update modal title
        shinyjs::runjs(sprintf("$('#%s').text('Edit Alignment');", ns("alignment_modal_title")))

        # In edit mode: hide Next button, show Save button, keep page 1 only
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_next")))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_save")))

        # Show modal
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal")))
      }
    })

    # Handle delete alignment button
    observe_event(input$delete_alignment, {
      alignment_id <- input$delete_alignment
    ### Delete Alignment ----
      alignment_to_delete(alignment_id)

      # Get alignment name for display
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == !!alignment_id)

      if (nrow(alignment) == 1) {
        alignment_name <- alignment$name[1]
        shinyjs::html("delete_alignment_name_display", alignment_name)
      }

      # Show confirmation modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("delete_confirmation_modal")))
    })

    # Handle confirmed deletion
    observe_event(input$confirm_delete_alignment, {
      if (is.null(alignment_to_delete())) return()

      # Get alignment info before deletion to get file_id
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == alignment_to_delete())

      if (nrow(alignment) == 1) {
        file_id <- alignment$file_id[1]

        # Delete CSV file
        app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
        if (is.na(app_folder) || app_folder == "") {
          mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
        } else {
          mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
        }

        csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
        if (file.exists(csv_path)) {
          file.remove(csv_path)
        }
      }

      # Delete from database
      delete_alignment(alignment_to_delete())

      # Reload alignments from database
      alignments_data(get_all_alignments())

      # Hide modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_confirmation_modal")))

      # Reset
      alignment_to_delete(NULL)
    })

    ### File Upload & Processing ----
    # Render CSV options only for CSV files
    output$csv_options <- renderUI({
      if (is.null(input$alignment_file)) return()
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext != "csv") {
        return(NULL)
      }

      tags$div(
        style = "background-color: #f8f9fa; border-radius: 4px; overflow: hidden;",
        tags$div(
          style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px;",
          "CSV Options"
        ),
        tags$div(
          style = "padding: 15px;",
          tags$div(
            style = "display: flex; flex-wrap: wrap; gap: 15px;",
            tags$div(
              style = "flex: 1; min-width: 150px;",
              tags$label("Delimiter", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              selectInput(
                ns("csv_delimiter"),
                label = NULL,
                choices = c(
                  "Auto-detect" = "auto",
                  "Comma (,)" = ",",
                  "Semicolon (;)" = ";",
                  "Tab" = "\t",
                  "Pipe (|)" = "|"
                ),
                selected = "auto"
              )
            ),
            tags$div(
              style = "flex: 1; min-width: 150px;",
              tags$label("Encoding", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              selectInput(
                ns("csv_encoding"),
                label = NULL,
                choices = c(
                  "UTF-8" = "UTF-8",
                  "Latin1 (ISO-8859-1)" = "Latin1",
                  "Windows-1252" = "Windows-1252"
                ),
                selected = "UTF-8"
              )
            )
          )
        )
      )
    })

    # Render column mapping wrapper (only shows when file is uploaded)
    output$column_mapping_wrapper <- renderUI({
      if (is.null(input$alignment_file)) return()

      tags$div(
        style = "background-color: #f8f9fa; border-radius: 4px;",
        uiOutput(ns("column_mapping_title")),
        tags$div(
          style = "padding: 15px;",
          uiOutput(ns("column_mapping_controls"))
        )
      )
    })

    # Render column mapping title only when file is uploaded
    output$column_mapping_title <- renderUI({
      if (is.null(input$alignment_file)) return()
      tags$div(
        style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px; border-radius: 4px 4px 0 0;",
        "Column Mapping"
      )
    })

    # Render column mapping controls based on uploaded file
    output$column_mapping_controls <- renderUI({
      if (is.null(input$alignment_file)) return()

      # Read file to get column names
      file_path <- input$alignment_file$datapath
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext == "csv") {
        # Get delimiter and encoding
        delimiter <- if (!is.null(input$csv_delimiter) && input$csv_delimiter != "auto") {
          input$csv_delimiter
        } else {
          NULL
        }
        encoding <- if (!is.null(input$csv_encoding)) input$csv_encoding else "UTF-8"

        df <- vroom::vroom(
          file_path,
          delim = delimiter,
          locale = vroom::locale(encoding = encoding),
          show_col_types = FALSE,
          n_max = 1
        )
        df <- as.data.frame(df)
      } else if (file_ext %in% c("xlsx", "xls")) {
        df <- readxl::read_excel(file_path, n_max = 1)
      } else {
        return(tags$p("Unsupported file format", style = "color: red;"))
      }

      col_names <- colnames(df)
      choices <- c("", col_names)

      tagList(
        # Two-column layout for dropdowns
        tags$div(
          style = "display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 10px;",
          # Column 1
          tags$div(
            style = "flex: 1; min-width: 150px;",
            tags$label("Vocabulary ID Column", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
            selectInput(
              ns("col_vocabulary_id"),
              label = NULL,
              choices = choices,
              selected = ""
            ),
            tags$div(
              id = ns("col_vocabulary_id_error"),
              style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
              "Please select Vocabulary ID column"
            )
          ),
          # Column 2
          tags$div(
            style = "flex: 1; min-width: 150px;",
            tags$label("Concept Code Column", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
            selectInput(
              ns("col_concept_code"),
              label = NULL,
              choices = choices,
              selected = ""
            ),
            tags$div(
              id = ns("col_concept_code_error"),
              style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
              "Please select Concept Code column"
            )
          )
        ),
        tags$div(
          style = "display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 10px;",
          # Column 1
          tags$div(
            style = "flex: 1; min-width: 150px;",
            tags$label("Concept Name Column", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
            selectInput(
              ns("col_concept_name"),
              label = NULL,
              choices = choices,
              selected = ""
            ),
            tags$div(
              id = ns("col_concept_name_error"),
              style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
              "Please select Concept Name column"
            )
          ),
          # Column 2
          tags$div(
            style = "flex: 1; min-width: 150px;",
            tags$label("Statistical Summary Column", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
            selectInput(
              ns("col_statistical_summary"),
              label = NULL,
              choices = choices,
              selected = ""
            )
          )
        ),
        # Full width for additional columns
        tags$div(
          style = "margin-bottom: 0px;",
          tags$label("Additional Columns to Keep", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
          selectizeInput(
            ns("col_additional"),
            label = NULL,
            choices = col_names,
            selected = NULL,
            multiple = TRUE
          )
        )
      )
    })

    # Update file preview data when file changes
    observe_event(input$alignment_file, {
      if (is.null(input$alignment_file)) {
        file_preview_data(NULL)
        return()
      }

      file_path <- input$alignment_file$datapath
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext == "csv") {
        # Get delimiter
        delimiter <- if (!is.null(input$csv_delimiter) && input$csv_delimiter != "auto") {
          input$csv_delimiter
        } else {
          NULL  # Auto-detect
        }

        # Get encoding
        encoding <- if (!is.null(input$csv_encoding)) {
          input$csv_encoding
        } else {
          "UTF-8"
        }

        df <- vroom::vroom(
          file_path,
          delim = delimiter,
          locale = vroom::locale(encoding = encoding),
          show_col_types = FALSE
        )
      } else if (file_ext %in% c("xlsx", "xls")) {
        df <- readxl::read_excel(file_path)
      } else {
        file_preview_data(NULL)
        return()
      }

      # Convert to regular dataframe and remove duplicate rows
      df <- as.data.frame(df) %>% dplyr::distinct()
      file_preview_data(df)
    })

    # Render file preview based on reactive data
    output$file_preview_table <- DT::renderDT({
      df <- file_preview_data()

      # If no data, return empty datatable
      if (is.null(df)) {
        return(datatable(
          data.frame(),
          options = list(
            pageLength = 8,
            dom = 'tp',
            ordering = TRUE
          ),
          rownames = FALSE,
          selection = 'none',
          filter = 'none',
          class = 'display'
        ))
      }

      datatable(
        df,
        options = list(
          pageLength = 8,
          dom = 'tp',
          ordering = TRUE
        ),
        rownames = FALSE,
        selection = 'none',
        filter = 'none',
        class = 'display'
      )
    }, server = TRUE)

    # Handle modal navigation
    observe_event(input$alignment_modal_next, {
      if (modal_page() == 1) {
        # Validate page 1
        if (is.null(input$alignment_name) || input$alignment_name == "") {
          # Show error message under the input field
          shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_name_error")))
          shinyjs::runjs(sprintf("$('#%s input').css('border-color', '#dc3545');", ns("alignment_name")))
          return()
        }

        # Hide error message if validation passes
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_name_error")))
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))

        # Move to page 2
        modal_page(2)

        # Show page 2, hide page 1
        shinyjs::hide(id = "modal_page_1")
        shinyjs::show(id = "modal_page_2")

        # Change modal width and height for page 2
        shinyjs::runjs(sprintf("$('#%s').css({'max-width': '90vw', 'height': '80vh', 'max-height': '80vh'});", ns("alignment_modal_dialog")))

        # Update buttons and indicator
        shinyjs::runjs(sprintf("$('#%s').text('Page 2 of 2');", ns("modal_page_indicator")))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_back")))
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_next")))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_save")))
      }
    })

    observe_event(input$alignment_modal_back, {
      if (modal_page() == 2) {
        # Move back to page 1
        modal_page(1)

        # Show page 1, hide page 2
        shinyjs::show(id = "modal_page_1")
        shinyjs::hide(id = "modal_page_2")

        # Change modal width and height back for page 1
        shinyjs::runjs(sprintf("$('#%s').css({'max-width': '600px', 'height': 'auto', 'max-height': '90vh'});", ns("alignment_modal_dialog")))

        # Update buttons and indicator
        shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 2');", ns("modal_page_indicator")))
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_back")))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_next")))
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_save")))
      }
    })

    # Handle Cancel button - reset all fields and close modal
    observe_event(input$alignment_modal_cancel, {
      # Close modal first
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal")))

      # Then reset everything (after modal is closed)
      # Reset page 1 inputs
      updateTextInput(session, "alignment_name", value = "")
      updateTextAreaInput(session, "alignment_description", value = "")

      # Force datatable to clear before resetting file input
      file_preview_data(NULL)

      # Reset file input using shinyjs
      shinyjs::reset("alignment_file")

      # Reset page 2 dropdowns
      updateSelectInput(session, "csv_delimiter", selected = "auto")
      updateSelectInput(session, "csv_encoding", selected = "UTF-8")
      updateSelectInput(session, "col_vocabulary_id", selected = "")
      updateSelectInput(session, "col_concept_code", selected = "")
      updateSelectInput(session, "col_concept_name", selected = "")
      updateSelectInput(session, "col_statistical_summary", selected = "")
      updateSelectInput(session, "col_additional", selected = character(0))

      # Hide CSV Options and Column Mapping sections
      shinyjs::runjs(sprintf("$('#%s').html('');", ns("csv_options")))
      shinyjs::runjs(sprintf("$('#%s').html('');", ns("column_mapping_wrapper")))

      # Hide all error messages
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_name_error")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_file_error")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("col_vocabulary_id_error")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("col_concept_code_error")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("col_concept_name_error")))

      # Reset to page 1
      modal_page(1)

      # Reset modal UI to page 1
      shinyjs::show(id = "modal_page_1")
      shinyjs::hide(id = "modal_page_2")
      shinyjs::runjs(sprintf("$('#%s').css({'max-width': '600px', 'height': 'auto', 'max-height': '90vh'});", ns("alignment_modal_dialog")))

      # Reset modal button visibility
      shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 2');", ns("modal_page_indicator")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_back")))
      shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_next")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_save")))
    })

    # Hide file upload error when file is uploaded
    observe_event(input$alignment_file, {
      if (!is.null(input$alignment_file)) {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_file_error")))
      }
    })

    # Hide column mapping errors when selections are made
    observe_event(input$col_vocabulary_id, {
      if (!is.null(input$col_vocabulary_id) && input$col_vocabulary_id != "") {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("col_vocabulary_id_error")))
      }
    })

    observe_event(input$col_concept_code, {
      if (!is.null(input$col_concept_code) && input$col_concept_code != "") {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("col_concept_code_error")))
      }
    })

    observe_event(input$col_concept_name, {
      if (!is.null(input$col_concept_name) && input$col_concept_name != "") {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("col_concept_name_error")))
      }
    })

    observe_event(input$alignment_modal_save, {

      # Validate all inputs and show error messages
      has_errors <- FALSE

      # Name is always required
      if (is.null(input$alignment_name) || input$alignment_name == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_name_error")))
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '#dc3545');", ns("alignment_name")))
        has_errors <- TRUE
      }

      # File and columns are only required in add mode (not in edit mode)
      if (modal_mode() == "add") {
        if (is.null(input$alignment_file)) {
          shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_file_error")))
          has_errors <- TRUE
        }

        if (is.null(input$col_vocabulary_id) || input$col_vocabulary_id == "") {
          shinyjs::runjs(sprintf("$('#%s').show();", ns("col_vocabulary_id_error")))
          has_errors <- TRUE
        }

        if (is.null(input$col_concept_code) || input$col_concept_code == "") {
          shinyjs::runjs(sprintf("$('#%s').show();", ns("col_concept_code_error")))
          has_errors <- TRUE
        }

        if (is.null(input$col_concept_name) || input$col_concept_name == "") {
          shinyjs::runjs(sprintf("$('#%s').show();", ns("col_concept_name_error")))
          has_errors <- TRUE
        }
      }

      if (has_errors) {
        return()
      }

      # Save alignment
      if (modal_mode() == "add") {

        # Read uploaded file
        file_path <- input$alignment_file$datapath
        file_ext <- tools::file_ext(input$alignment_file$name)

        if (file_ext == "csv") {
          # Get delimiter and encoding from user inputs
          delimiter <- if (!is.null(input$csv_delimiter) && input$csv_delimiter != "auto") {
            input$csv_delimiter
          } else {
            NULL
          }
          encoding <- if (!is.null(input$csv_encoding)) input$csv_encoding else "UTF-8"

          df <- vroom::vroom(
            file_path,
            delim = delimiter,
            locale = vroom::locale(encoding = encoding),
            show_col_types = FALSE
          )
          df <- as.data.frame(df)
        } else if (file_ext %in% c("xlsx", "xls")) {
          df <- readxl::read_excel(file_path)
        } else {
          return()
        }

        # Rename columns according to mapping
        col_mapping <- list(
          vocabulary_id = input$col_vocabulary_id,
          concept_code = input$col_concept_code,
          concept_name = input$col_concept_name,
          statistical_summary = input$col_statistical_summary
        )

        # Keep additional columns
        additional_cols <- input$col_additional
        if (is.null(additional_cols)) {
          additional_cols <- character(0)
        }

        # Build list of columns to include in new dataframe
        new_cols <- list()

        # Add mapped columns
        for (new_name in names(col_mapping)) {
          old_name <- col_mapping[[new_name]]
          if (!is.null(old_name) && old_name != "" && old_name %in% colnames(df)) {
            new_cols[[new_name]] <- df[[old_name]]
          }
        }

        # Add additional columns, resolving conflicts
        for (col in additional_cols) {
          if (col %in% colnames(df) && !col %in% names(col_mapping)) {
            final_name <- col
            suffix <- 2
            # Check for conflicts with already renamed columns
            while (final_name %in% names(new_cols)) {
              final_name <- paste0(col, "_", suffix)
              suffix <- suffix + 1
            }
            new_cols[[final_name]] <- df[[col]]
          }
        }

        # Create dataframe from list
        new_df <- as.data.frame(new_cols, stringsAsFactors = FALSE)

        # Remove duplicate rows
        new_df <- new_df %>% dplyr::distinct()

        # Add tracking columns
        new_df$mapping_id <- sapply(1:nrow(new_df), function(i) {
          paste0("mapping_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sprintf("%04d", i))
        })
        new_df$mapped_by_user_id <- NA_integer_
        new_df$mapping_datetime <- NA_character_

        # Generate unique file ID
        file_id <- paste0("alignment_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))

        # Get app folder and create concept_mapping directory
        app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
        if (is.na(app_folder) || app_folder == "") {
          mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
        } else {
          mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
        }

        if (!dir.exists(mapping_dir)) {
          dir.create(mapping_dir, recursive = TRUE, showWarnings = FALSE)
        }

        # Save formatted CSV
        csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
        write.csv(new_df, csv_path, row.names = FALSE)


        # Add to database
        new_id <- add_alignment(
          name = input$alignment_name,
          description = ifelse(is.null(input$alignment_description), "", input$alignment_description),
          file_id = file_id,
          original_filename = input$alignment_file$name
        )


        # Reload alignments from database
        alignments_data(get_all_alignments())
      } else if (modal_mode() == "edit") {
        # Update in database
        update_alignment(
          alignment_id = selected_alignment_id(),
          name = input$alignment_name,
          description = ifelse(is.null(input$alignment_description), "", input$alignment_description)
        )

        # Reload alignments from database
        alignments_data(get_all_alignments())

      }

      # Close modal and reset to page 1
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal")))
      modal_page(1)

      # Reset modal UI to page 1
      shinyjs::show(id = "modal_page_1")
      shinyjs::hide(id = "modal_page_2")
      shinyjs::runjs(sprintf("$('#%s').css({'max-width': '600px', 'height': 'auto', 'max-height': '90vh'});", ns("alignment_modal_dialog")))

      # Reset modal button visibility
      shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 2');", ns("modal_page_indicator")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_back")))
      shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_next")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_save")))
    })


    ## 6) Server - Concept Mapping Interface ----
    # Source Concepts table - load from CSV
    ### Source Concepts Display ----
    output$source_concepts_table <- DT::renderDT({
      if (is.null(selected_alignment_id())) return()
      if (mapping_view() != "general") return()  # Only load in general view

      # Get the alignment data
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Check if file exists
      if (!file.exists(csv_path)) {
        return(datatable(
          data.frame(Error = "CSV file not found"),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Convert vocabulary_id to factor if it exists
      if ("vocabulary_id" %in% colnames(df)) {
        df <- df %>%
          dplyr::mutate(vocabulary_id = as.factor(vocabulary_id))
      }

      # Add Mapped column based on target columns
      has_target_cols <- "target_general_concept_id" %in% colnames(df)
      if (has_target_cols) {
        df <- df %>%
          dplyr::mutate(
            Mapped = factor(ifelse(!is.na(target_general_concept_id), "Yes", "No"), levels = c("Yes", "No"))
          )
      } else {
        df <- df %>%
          dplyr::mutate(Mapped = factor("No", levels = c("Yes", "No")))
      }

      # Select and reorder columns, excluding target columns
      standard_cols <- c("vocabulary_id", "concept_code", "concept_name", "statistical_summary")
      available_standard <- standard_cols[standard_cols %in% colnames(df)]
      target_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id", "mapping_id")
      other_cols <- setdiff(colnames(df), c(standard_cols, target_cols, "Mapped"))
      df_display <- df[, c(available_standard, other_cols, "Mapped"), drop = FALSE]

      # Create nice column names
      nice_names <- colnames(df_display)
      nice_names[nice_names == "vocabulary_id"] <- "Vocabulary"
      nice_names[nice_names == "concept_code"] <- "Code"
      nice_names[nice_names == "concept_name"] <- "Name"
      nice_names[nice_names == "statistical_summary"] <- "Summary"

      dt <- datatable(
        df_display,
        filter = 'top',
        options = list(
          pageLength = 8,
          lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c('5', '8', '10', '15', '20', '50', '100')),
          dom = 'ltp',
          columnDefs = list(
            list(targets = which(colnames(df_display) == "Mapped") - 1, width = "80px", className = 'dt-center')
          )
        ),
        colnames = nice_names,
        rownames = FALSE,
        selection = 'single'
      )

      # Apply formatStyle for Mapped column
      dt <- dt %>%
        DT::formatStyle(
          'Mapped',
          target = 'cell',
          backgroundColor = DT::styleEqual(
            c("Yes", "No"),
            c('#d4edda', '#f8f9fa')
          ),
          fontWeight = DT::styleEqual(
            c("Yes", "No"),
            c('bold', 'normal')
          ),
          color = DT::styleEqual(
            c("Yes", "No"),
            c('#155724', '#666')
          )
        )

      dt
    }, server = TRUE)

    ### General Concepts Table ----
    output$general_concepts_table <- DT::renderDT({
      if (is.null(data())) return()

      # Only show when in general view
      if (mapping_view() != "general") return()

      general_concepts <- data()$general_concepts

      # Build the data frame with explicit column selection
      general_concepts_display <- data.frame(
        general_concept_id = general_concepts$general_concept_id,
        category = as.factor(general_concepts$category),
        subcategory = as.factor(general_concepts$subcategory),
        general_concept_name = general_concepts$general_concept_name,
        stringsAsFactors = FALSE
      )

      dt <- datatable(
        general_concepts_display,
        filter = 'top',
        options = list(
          pageLength = 8,
          lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c('5', '8', '10', '15', '20', '50', '100')),
          dom = 'ltp',
          columnDefs = list(
            list(targets = 0, visible = FALSE),  # Hide general_concept_id column
            list(targets = 1, width = "200px")
          )
        ),
        rownames = FALSE,
        selection = 'single',
        colnames = c("ID", "Category", "Subcategory", "General Concept")
      )

      # Add JavaScript callback for double-click
      dt <- add_doubleclick_handler(dt, ns("view_mapped_concepts"))

      dt
    }, server = FALSE)

    output$realized_mappings_table <- DT::renderDT({
    ### Realized Mappings Table ----
      if (is.null(selected_alignment_id())) return()

      # Get alignment info
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) {
        return(datatable(
          data.frame(Message = "No alignment selected"),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Check if file exists
      if (!file.exists(csv_path)) {
        return(datatable(
          data.frame(Message = "CSV file not found"),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Filter only rows with mappings
      if (!"target_general_concept_id" %in% colnames(df)) {
        # No mappings yet
        return(datatable(
          data.frame(Message = "No mappings created yet. Select a source and target concept, then click 'Add Mapping'."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Rename source columns to avoid conflicts with joined data
      df <- df %>%
        dplyr::rename(
          concept_name_source = concept_name,
          vocabulary_id_source = vocabulary_id,
          concept_code_source = concept_code
        )

      mapped_rows <- df %>%
        dplyr::filter(!is.na(target_general_concept_id))

      if (nrow(mapped_rows) == 0) {
        return(datatable(
          data.frame(Message = "No mappings created yet. Select a source and target concept, then click 'Add Mapping'."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Enrich with general concept information
      if (is.null(data())) return()
      general_concepts <- data()$general_concepts

      # Join with general concepts to get names
      enriched_rows <- mapped_rows %>%
        dplyr::left_join(
          general_concepts %>%
            dplyr::select(general_concept_id, general_concept_name, category, subcategory),
          by = c("target_general_concept_id" = "general_concept_id")
        )

      # Enrich with target concept info (OMOP or custom)
      if ("target_custom_concept_id" %in% colnames(enriched_rows)) {
        # New approach: use target_custom_concept_id or target_omop_concept_id

        # Enrich OMOP concepts
        vocab_data <- vocabularies()
        if (!is.null(vocab_data)) {
          omop_rows <- enriched_rows %>% dplyr::filter(!is.na(target_omop_concept_id))
          if (nrow(omop_rows) > 0) {
            concept_ids <- omop_rows$target_omop_concept_id
            omop_concepts <- vocab_data$concept %>%
              dplyr::filter(concept_id %in% concept_ids) %>%
              dplyr::select(
                concept_id,
                concept_name_target = concept_name,
                vocabulary_id_target = vocabulary_id,
                concept_code_target = concept_code
              ) %>%
              dplyr::collect()

            enriched_rows <- enriched_rows %>%
              dplyr::left_join(
                omop_concepts,
                by = c("target_omop_concept_id" = "concept_id")
              )
          } else {
            enriched_rows <- enriched_rows %>%
              dplyr::mutate(
                concept_name_target = NA_character_,
                vocabulary_id_target = NA_character_,
                concept_code_target = NA_character_
              )
          }
        } else {
          enriched_rows <- enriched_rows %>%
            dplyr::mutate(
              concept_name_target = NA_character_,
              vocabulary_id_target = NA_character_,
              concept_code_target = NA_character_
            )
        }

        # Enrich custom concepts
        custom_concepts_path <- app_sys("extdata", "csv", "custom_concepts.csv")
        if (file.exists(custom_concepts_path)) {
          custom_rows <- enriched_rows %>% dplyr::filter(!is.na(target_custom_concept_id))
          if (nrow(custom_rows) > 0) {
            custom_concepts_all <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
            custom_concept_ids <- custom_rows$target_custom_concept_id

            custom_concepts_info <- custom_concepts_all %>%
              dplyr::filter(custom_concept_id %in% custom_concept_ids) %>%
              dplyr::select(
                custom_concept_id,
                concept_name_custom = concept_name,
                vocabulary_id_custom = vocabulary_id,
                concept_code_custom = concept_code
              )

            # For custom concepts, fill in the target columns
            enriched_rows <- enriched_rows %>%
              dplyr::left_join(
                custom_concepts_info,
                by = c("target_custom_concept_id" = "custom_concept_id")
              ) %>%
              dplyr::mutate(
                concept_name_target = ifelse(is.na(concept_name_target), concept_name_custom, concept_name_target),
                vocabulary_id_target = ifelse(is.na(vocabulary_id_target), vocabulary_id_custom, vocabulary_id_target),
                concept_code_target = ifelse(is.na(concept_code_target), concept_code_custom, concept_code_target)
              ) %>%
              dplyr::select(-concept_name_custom, -vocabulary_id_custom, -concept_code_custom)
          }
        }
      } else {
        # Fallback: old CSV format without target_custom_concept_id
        vocab_data <- vocabularies()
        if (!is.null(vocab_data) && nrow(enriched_rows) > 0) {
          concept_ids <- enriched_rows$target_omop_concept_id
          omop_concepts <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% concept_ids) %>%
            dplyr::select(
              concept_id,
              concept_name_target = concept_name,
              vocabulary_id_target = vocabulary_id,
              concept_code_target = concept_code
            ) %>%
            dplyr::collect()

          enriched_rows <- enriched_rows %>%
            dplyr::left_join(
              omop_concepts,
              by = c("target_omop_concept_id" = "concept_id")
            )
        } else {
          enriched_rows <- enriched_rows %>%
            dplyr::mutate(
              concept_name_target = NA_character_,
              vocabulary_id_target = NA_character_,
              concept_code_target = NA_character_
            )
        }
      }

      # Build display dataframe
      display_df <- enriched_rows %>%
        dplyr::mutate(
          Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
          Target = paste0(
            general_concept_name, " > ",
            concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"
          ),
          Actions = sprintf(
            '<button class="btn btn-sm btn-danger" style="padding: 2px 8px; font-size: 11px; line-height: 1.2;" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
            ns("remove_mapping"), dplyr::row_number()
          )
        ) %>%
        dplyr::select(Source, Target, Actions)

      datatable(
        display_df,
        escape = FALSE,
        options = list(pageLength = 6, dom = 'tp'),
        rownames = FALSE,
        selection = 'none',
        colnames = c("Source Concept", "Target Concept", "Actions")
      )
    }, server = TRUE)

    # Concept mappings table for general view (when a general concept is selected)
    output$concept_mappings_table <- DT::renderDT({
    ### Concept Mappings Table (Detailed View) ----
      if (is.null(selected_general_concept_id())) return()
      if (is.null(data())) return()

      # Check if OHDSI vocabularies are loaded
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) {
        return(datatable(
          data.frame(Message = "OHDSI vocabularies not loaded. Please configure the ATHENA folder in Settings."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Get mapped concepts for the selected general concept
      concept_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == selected_general_concept_id())

      # Enrich OMOP concepts with vocabulary data
      if (!is.null(vocab_data) && nrow(concept_mappings) > 0) {
        # Get concept details from OMOP
        concept_ids <- concept_mappings$omop_concept_id
        omop_concepts <- vocab_data$concept %>%
          dplyr::filter(concept_id %in% concept_ids) %>%
          dplyr::select(concept_id, concept_name, vocabulary_id, concept_code) %>%
          dplyr::collect()

        # Join with concept_mappings
        concept_mappings <- concept_mappings %>%
          dplyr::left_join(
            omop_concepts,
            by = c("omop_concept_id" = "concept_id")
          ) %>%
          dplyr::mutate(is_custom = FALSE)
      } else if (nrow(concept_mappings) > 0) {
        # If no vocabulary data but we have mappings, add placeholder columns
        concept_mappings <- concept_mappings %>%
          dplyr::mutate(
            concept_name = NA_character_,
            vocabulary_id = NA_character_,
            concept_code = NA_character_,
            is_custom = FALSE
          )
      } else {
        # No OMOP concept mappings, create empty dataframe with correct structure
        concept_mappings <- data.frame(
          concept_name = character(),
          vocabulary_id = character(),
          concept_code = character(),
          omop_concept_id = integer(),
          recommended = logical(),
          is_custom = logical()
        )
      }

      # Read custom concepts
      custom_concepts_path <- app_sys("extdata", "csv", "custom_concepts.csv")
      if (file.exists(custom_concepts_path)) {
        custom_concepts <- readr::read_csv(custom_concepts_path, show_col_types = FALSE) %>%
          dplyr::filter(general_concept_id == selected_general_concept_id()) %>%
          dplyr::select(
            custom_concept_id,
            concept_name,
            vocabulary_id,
            concept_code,
            recommended
          ) %>%
          dplyr::mutate(
            omop_concept_id = NA_integer_,
            is_custom = TRUE
          )
      } else {
        custom_concepts <- data.frame(
          custom_concept_id = integer(),
          concept_name = character(),
          vocabulary_id = character(),
          concept_code = character(),
          recommended = logical(),
          omop_concept_id = integer(),
          is_custom = logical()
        )
      }

      # Combine OMOP and custom concepts
      if (nrow(concept_mappings) > 0) {
        omop_for_bind <- concept_mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended, is_custom)
      } else {
        omop_for_bind <- concept_mappings
      }

      all_concepts <- dplyr::bind_rows(omop_for_bind, custom_concepts)

      # Check if we have any concepts (OMOP or custom)
      if (nrow(all_concepts) == 0) {
        return(datatable(
          data.frame(Message = "No mapped concepts found for this general concept."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Select final columns and arrange
      mappings <- all_concepts %>%
        dplyr::select(
          concept_name,
          vocabulary_id,
          concept_code,
          omop_concept_id,
          recommended,
          is_custom
        ) %>%
        dplyr::arrange(dplyr::desc(recommended), concept_name) %>%
        dplyr::mutate(
          omop_concept_id = as.character(omop_concept_id),
          recommended = ifelse(recommended, "Yes", "No")
        )

      dt <- datatable(
        mappings,
        options = list(
          pageLength = 6,
          dom = 'tp',
          columnDefs = list(
            list(targets = 4, width = "100px", className = 'dt-center'),  # Recommended column
            list(targets = 5, visible = FALSE)  # is_custom column hidden
          )
        ),
        rownames = FALSE,
        selection = 'single',
        colnames = c("Concept Name", "Vocabulary", "Code", "OMOP ID", "Recommended", "Custom")
      )

      # Apply formatStyle for recommended column
      dt <- dt %>%
        DT::formatStyle(
          'recommended',
          target = 'cell',
          backgroundColor = DT::styleEqual(
            c("Yes", "No"),
            c('#d4edda', '#f8f9fa')
          ),
          fontWeight = DT::styleEqual(
            c("Yes", "No"),
            c('bold', 'normal')
          ),
          color = DT::styleEqual(
            c("Yes", "No"),
            c('#155724', '#666')
          )
        )

      dt
    }, server = TRUE)

    # Comments display for general concept
    ### Comments Display ----
    output$comments_display <- renderUI({
      if (is.null(selected_general_concept_id())) return()
      if (is.null(data())) return()

      concept_id <- selected_general_concept_id()
      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      # Show formatted comment
      if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
        # Convert markdown-style formatting to HTML
        comment_html <- concept_info$comments[1]
        # Convert **text** to <strong>text</strong>
        comment_html <- gsub("\\*\\*([^*]+)\\*\\*", "<strong>\\1</strong>", comment_html)
        # Convert *text* to <em>text</em>
        comment_html <- gsub("\\*([^*]+)\\*", "<em>\\1</em>", comment_html)
        # Wrap content in paragraph tags
        comment_html <- paste0("<p>", comment_html, "</p>")
        # Convert line breaks to paragraph breaks
        comment_html <- gsub("\n", "</p><p>", comment_html)

        tags$div(
          class = "comments-container",
          style = "background: #e6f3ff; border: 1px solid #0f60af; border-radius: 6px; padding: 15px; height: 100%; overflow-y: auto; box-sizing: border-box;",
          HTML(comment_html)
        )
      } else {
        tags$div(
          style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic; height: 100%; overflow-y: auto; box-sizing: border-box;",
          "No comments available for this concept."
        )
      }
    })

    output$mapped_concepts_table <- DT::renderDT({
      if (is.null(selected_general_concept_id())) return()
      if (is.null(data())) return()
      if (is.null(vocabularies())) return()

      # Get mapped concepts for the selected general concept
      concept_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == selected_general_concept_id())

      if (nrow(concept_mappings) == 0) {
        return(datatable(
          data.frame(Message = "No mapped concepts found for this general concept."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

    ### Modal Renderings ----
      # Join with vocabularies to get concept details
      vocabs <- vocabularies()
      mapped_with_details <- concept_mappings %>%
        dplyr::left_join(
          vocabs %>% dplyr::select(concept_id, concept_name, concept_code, vocabulary_id, standard_concept),
          by = c("omop_concept_id" = "concept_id")
        ) %>%
        dplyr::select(omop_concept_id, concept_name, concept_code, vocabulary_id, standard_concept, recommended)

      datatable(
        mapped_with_details,
        options = list(
          pageLength = 10,
          lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c('5', '8', '10', '15', '20', '50', '100')),
          dom = 'ltp'
        ),
        rownames = FALSE,
        selection = 'single',
        colnames = c("OMOP Concept ID", "Concept Name", "Concept Code", "Vocabulary", "Standard", "Recommended")
      )
    }, server = FALSE)

    # Source concepts table for mapped view (copy of original)
    output$source_concepts_table_mapped <- DT::renderDT({
    ### Mapped View Tables ----
      if (is.null(selected_alignment_id())) return()

      # Get the alignment data
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Check if file exists
      if (!file.exists(csv_path)) {
        return(datatable(
          data.frame(Error = "CSV file not found"),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Reorder columns to show standard ones first
      standard_cols <- c("vocabulary_id", "concept_code", "concept_name", "statistical_summary")
      available_standard <- standard_cols[standard_cols %in% colnames(df)]
      excluded_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id", "mapping_id")
      other_cols <- setdiff(colnames(df), c(standard_cols, excluded_cols))
      df <- df[, c(available_standard, other_cols), drop = FALSE]

      datatable(
        df,
        options = list(
          pageLength = 8,
          lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c('5', '8', '10', '15', '20', '50', '100')),
          dom = 'ltp'
        ),
        rownames = FALSE,
        selection = 'single'
      )
    }, server = FALSE)

    # Completed mappings table for mapped view (copy of original)
    output$realized_mappings_table_mapped <- DT::renderDT({
      if (is.null(selected_alignment_id())) return()

      # Get alignment info
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) {
        return(datatable(
          data.frame(Message = "No alignment selected"),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Check if file exists
      if (!file.exists(csv_path)) {
        return(datatable(
          data.frame(Message = "CSV file not found"),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Filter only rows with mappings
      if (!"target_omop_concept_id" %in% colnames(df)) {
        # No mappings yet
        return(datatable(
          data.frame(Message = "No mappings created yet. Select a source concept and a mapped concept, then click 'Add Mapping'."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Rename source columns to avoid conflicts
      df <- df %>%
        dplyr::rename(
          concept_name_source = concept_name,
          vocabulary_id_source = vocabulary_id,
          concept_code_source = concept_code
        )

      mapped_rows <- df %>%
        dplyr::filter(!is.na(target_general_concept_id))

      if (nrow(mapped_rows) == 0) {
        return(datatable(
          data.frame(Message = "No mappings created yet. Select a source concept and a mapped concept, then click 'Add Mapping'."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Enrich with target concept info (OMOP or custom)
      if ("target_custom_concept_id" %in% colnames(mapped_rows)) {
        # Enrich OMOP concepts
        vocab_data <- vocabularies()
        if (!is.null(vocab_data)) {
          omop_rows <- mapped_rows %>% dplyr::filter(!is.na(target_omop_concept_id))
          if (nrow(omop_rows) > 0) {
            concept_ids <- omop_rows$target_omop_concept_id
            omop_concepts <- vocab_data$concept %>%
              dplyr::filter(concept_id %in% concept_ids) %>%
              dplyr::select(
                concept_id,
                concept_name_target = concept_name,
                vocabulary_id_target = vocabulary_id,
                concept_code_target = concept_code
              ) %>%
              dplyr::collect()

            mapped_rows <- mapped_rows %>%
              dplyr::left_join(
                omop_concepts,
                by = c("target_omop_concept_id" = "concept_id")
              )
          } else {
            mapped_rows <- mapped_rows %>%
              dplyr::mutate(
                concept_name_target = NA_character_,
                vocabulary_id_target = NA_character_,
                concept_code_target = NA_character_
              )
          }
        } else {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(
              concept_name_target = NA_character_,
              vocabulary_id_target = NA_character_,
              concept_code_target = NA_character_
            )
        }

        # Enrich custom concepts
        custom_concepts_path <- app_sys("extdata", "csv", "custom_concepts.csv")
        if (file.exists(custom_concepts_path)) {
          custom_rows <- mapped_rows %>% dplyr::filter(!is.na(target_custom_concept_id))
          if (nrow(custom_rows) > 0) {
            custom_concepts_all <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
            custom_concept_ids <- custom_rows$target_custom_concept_id

            custom_concepts_info <- custom_concepts_all %>%
              dplyr::filter(custom_concept_id %in% custom_concept_ids) %>%
              dplyr::select(
                custom_concept_id,
                concept_name_custom = concept_name,
                vocabulary_id_custom = vocabulary_id,
                concept_code_custom = concept_code
              )

            mapped_rows <- mapped_rows %>%
              dplyr::left_join(
                custom_concepts_info,
                by = c("target_custom_concept_id" = "custom_concept_id")
              ) %>%
              dplyr::mutate(
                concept_name_target = ifelse(is.na(concept_name_target), concept_name_custom, concept_name_target),
                vocabulary_id_target = ifelse(is.na(vocabulary_id_target), vocabulary_id_custom, vocabulary_id_target),
                concept_code_target = ifelse(is.na(concept_code_target), concept_code_custom, concept_code_target)
              ) %>%
              dplyr::select(-concept_name_custom, -vocabulary_id_custom, -concept_code_custom)
          }
        }

        display_df <- mapped_rows %>%
          dplyr::mutate(
            Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
            Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
            Actions = sprintf(
              '<button class="btn btn-sm btn-danger" style="padding: 2px 8px; font-size: 11px; line-height: 1.2;" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
              ns("remove_mapping_mapped"), dplyr::row_number()
            )
          ) %>%
          dplyr::select(Source, Target, Actions)
      } else {
        # Fallback: old CSV format
        if (is.null(vocabularies())) return()
        vocabs <- vocabularies()

        display_df <- mapped_rows %>%
          dplyr::left_join(
            vocabs$concept %>%
              dplyr::select(concept_id, concept_name, vocabulary_id, concept_code) %>%
              dplyr::collect(),
            by = c("target_omop_concept_id" = "concept_id")
          ) %>%
          dplyr::mutate(
            Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
            Target = paste0(concept_name, " (", vocabulary_id, ": ", concept_code, ")"),
            Actions = sprintf(
              '<button class="btn btn-sm btn-danger" style="padding: 2px 8px; font-size: 11px; line-height: 1.2;" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
              ns("remove_mapping_mapped"), dplyr::row_number()
            )
          ) %>%
          dplyr::select(Source, Target, Actions)
      }

      datatable(
        display_df,
        escape = FALSE,
        options = list(pageLength = 6, dom = 'tp'),
        rownames = FALSE,
        selection = 'none',
        colnames = c("Source Concept", "Target Concept", "Actions")
      )
    }, server = TRUE)

    # Handle Add Mapping button for specific OMOP concept

    ## 7) Server - Table Interaction Handlers ----
    ### Mapping Creation & Deletion ----
    observe_event(input$add_mapping_specific, {
      # Get selected rows from source and mapped concepts tables
      source_row <- input$source_concepts_table_mapped_rows_selected
      mapped_row <- input$mapped_concepts_table_rows_selected

      # Validate selections
      if (is.null(source_row) || is.null(mapped_row)) {
        return()
      }

      # Get alignment info
      if (is.null(selected_alignment_id())) return()
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Read CSV
      if (!file.exists(csv_path)) {
        return()
      }

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Get mapped concept info
      if (is.null(selected_general_concept_id())) return()
      if (is.null(data())) return()
      concept_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == selected_general_concept_id())

      target_mapping <- concept_mappings[mapped_row, ]

      # Add mapping columns if they don't exist
      if (!"target_general_concept_id" %in% colnames(df)) {
        df$target_general_concept_id <- NA_integer_
      }
      if (!"target_omop_concept_id" %in% colnames(df)) {
        df$target_omop_concept_id <- NA_integer_
      }
      if (!"mapping_datetime" %in% colnames(df)) {
        df$mapping_datetime <- NA_character_
      }
      if (!"mapped_by_user_id" %in% colnames(df)) {
        df$mapped_by_user_id <- NA_integer_
      }

      # Update the selected row with mapping info
      df$target_general_concept_id[source_row] <- selected_general_concept_id()
      df$target_omop_concept_id[source_row] <- target_mapping$omop_concept_id
      df$mapping_datetime[source_row] <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      df$mapped_by_user_id[source_row] <- if (!is.null(current_user())) current_user()$user_id else NA_integer_

      # Save CSV
      write.csv(df, csv_path, row.names = FALSE)

      # Deselect only the source concepts table
      proxy_source <- DT::dataTableProxy("source_concepts_table_mapped", session)
      DT::selectRows(proxy_source, NULL)

      # Keep the selection in mapped_concepts_table so user can add multiple mappings

      # Force refresh of completed mappings table and source concepts table
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    })

    # Handle Remove Mapping
    observe_event(input$remove_mapping, {
      # Get the row number
      row_num <- input$remove_mapping

      # Get alignment info
      if (is.null(selected_alignment_id())) return()
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Read CSV
      if (!file.exists(csv_path)) {
        return()
      }

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Find the mapped rows
      if (!"target_general_concept_id" %in% colnames(df)) {
        return()
      }

      mapped_rows_indices <- which(!is.na(df$target_general_concept_id))

      if (row_num > length(mapped_rows_indices)) {
        return()
      }

      # Get the actual row index in the dataframe
      actual_row <- mapped_rows_indices[row_num]

      # Remove the mapping by setting target columns to NA
      df$target_general_concept_id[actual_row] <- NA_integer_
      df$target_omop_concept_id[actual_row] <- NA_integer_

      # Save CSV
      write.csv(df, csv_path, row.names = FALSE)

      # Force refresh
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    })

    # Handle Export Alignment (SOURCE_TO_CONCEPT_MAP format)
    ### Export Functionality ----
    observe_event(input$export_alignment, {
      # Get alignment info
      alignment_id <- input$export_alignment
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == !!alignment_id)

      if (nrow(alignment) == 0) return()

      file_id <- alignment$file_id[1]
      alignment_name <- alignment$name[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Read CSV
      if (!file.exists(csv_path)) {
        showNotification("No mapping file found for this alignment", type = "error")
        return()
      }

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Find all mapped rows
      if (!"target_general_concept_id" %in% colnames(df)) {
        showNotification("No mappings found in this alignment", type = "warning")
        return()
      }

      mapped_rows <- df %>%
        dplyr::filter(!is.na(target_general_concept_id))

      if (nrow(mapped_rows) == 0) {
        showNotification("No mappings found in this alignment", type = "warning")
        return()
      }

      # Get vocabulary data for target concept enrichment
      vocab_data <- vocabularies()

      # Build SOURCE_TO_CONCEPT_MAP format for all mappings
      export_data <- data.frame(
        source_code = character(),
        source_concept_id = integer(),
        source_code_description = character(),
        source_vocabulary_id = character(),
        target_concept_id = integer(),
        target_vocabulary_id = character(),
        valid_start_date = character(),
        valid_end_date = character(),
        invalid_reason = character(),
        stringsAsFactors = FALSE
      )

      # Process each mapped row
      for (i in 1:nrow(mapped_rows)) {
        mapped_concept <- mapped_rows[i, ]

        # For target_concept_id: only use target_omop_concept_id, if NA/0 then 0
        target_concept_id <- 0
        target_vocabulary_id <- NA_character_

        if (!is.na(mapped_concept$target_omop_concept_id) && mapped_concept$target_omop_concept_id != 0) {
          # OMOP concept
          target_concept_id <- mapped_concept$target_omop_concept_id
          if (!is.null(vocab_data)) {
            target_info <- vocab_data$concept %>%
              dplyr::filter(concept_id == mapped_concept$target_omop_concept_id) %>%
              dplyr::select(concept_id, vocabulary_id) %>%
              dplyr::collect()

            if (nrow(target_info) > 0) {
              target_vocabulary_id <- target_info$vocabulary_id[1]
            }
          }
        }

        # Get valid_start_date from mapping_datetime or use default
        valid_start_date <- "1970-01-01"
        if ("mapping_datetime" %in% colnames(mapped_concept) && !is.na(mapped_concept$mapping_datetime)) {
          valid_start_date <- format(as.Date(as.POSIXct(mapped_concept$mapping_datetime)), "%Y-%m-%d")
        }

        # Create complete row with all columns (using correct CSV column names)
        export_row <- data.frame(
          source_code = as.character(mapped_concept$concept_code),
          source_concept_id = 0L,
          source_code_description = as.character(mapped_concept$concept_name),
          source_vocabulary_id = as.character(mapped_concept$vocabulary_id),
          target_concept_id = as.integer(target_concept_id),
          target_vocabulary_id = as.character(target_vocabulary_id),
          valid_start_date = valid_start_date,
          valid_end_date = "2099-12-31",
          invalid_reason = NA_character_,
          stringsAsFactors = FALSE
        )

        export_data <- rbind(export_data, export_row)
      }

      # Create download filename with timestamp
      safe_name <- gsub("[^a-zA-Z0-9_-]", "_", alignment_name)
      timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
      filename <- paste0(safe_name, "_source_to_concept_map_", timestamp, ".csv")

      # Convert to CSV string
      csv_lines <- c(
        paste(colnames(export_data), collapse = ","),
        apply(export_data, 1, function(row) paste(row, collapse = ","))
      )
      csv_content <- paste(csv_lines, collapse = "\n")

      # Create data URI for download
      csv_encoded <- base64enc::base64encode(charToRaw(csv_content))
      download_js <- sprintf(
        "var link = document.createElement('a');
         link.href = 'data:text/csv;base64,%s';
         link.download = '%s';
         link.click();",
        csv_encoded,
        filename
      )

      # Trigger download
      shinyjs::runjs(download_js)
    })

    # Observe mappings_refresh_trigger and reload datatables using proxy
    observe_event(mappings_refresh_trigger(), {
      # Skip initial trigger
      if (mappings_refresh_trigger() == 0) return()

      if (is.null(selected_alignment_id())) return()

      # Reload Source Concepts table if in general view
      if (mapping_view() == "general") {
        # Get alignment data
        alignments <- alignments_data()
        alignment <- alignments %>%
          dplyr::filter(alignment_id == selected_alignment_id())

        if (nrow(alignment) == 1) {
          file_id <- alignment$file_id[1]
          app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
          if (is.na(app_folder) || app_folder == "") {
            mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
          } else {
            mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
          }

          csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

          if (file.exists(csv_path)) {
            df <- read.csv(csv_path, stringsAsFactors = FALSE)

            # Add Mapped column
            has_target_cols <- "target_general_concept_id" %in% colnames(df)
            if (has_target_cols) {
              df <- df %>%
                dplyr::mutate(
                  Mapped = factor(ifelse(!is.na(target_general_concept_id), "Yes", "No"), levels = c("Yes", "No"))
                )
            } else {
              df <- df %>%
                dplyr::mutate(Mapped = factor("No", levels = c("Yes", "No")))
            }

            # Select columns for display
            standard_cols <- c("vocabulary_id", "concept_code", "concept_name", "statistical_summary")
            available_standard <- standard_cols[standard_cols %in% colnames(df)]
            target_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id", "mapping_id")
            other_cols <- setdiff(colnames(df), c(standard_cols, target_cols, "Mapped"))
            df_display <- df[, c(available_standard, other_cols, "Mapped"), drop = FALSE]

            # Update data via proxy
            proxy_source <- DT::dataTableProxy("source_concepts_table", session)
            DT::replaceData(proxy_source, df_display, resetPaging = FALSE, rownames = FALSE)
          }
        }
      }

      # Always reload Completed Mappings table
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) == 1) {
        file_id <- alignment$file_id[1]
        app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
        if (is.na(app_folder) || app_folder == "") {
          mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
        } else {
          mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
        }

        csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

        if (file.exists(csv_path)) {
          df <- read.csv(csv_path, stringsAsFactors = FALSE)

          if ("target_general_concept_id" %in% colnames(df)) {
            # Rename source columns
            df <- df %>%
              dplyr::rename(
                concept_name_source = concept_name,
                vocabulary_id_source = vocabulary_id,
                concept_code_source = concept_code
              )

            mapped_rows <- df %>%
              dplyr::filter(!is.na(target_general_concept_id))

            if (nrow(mapped_rows) > 0) {
              # Enrich with general concept info
              general_concepts <- data()$general_concepts
              enriched_rows <- mapped_rows %>%
                dplyr::left_join(
                  general_concepts %>%
                    dplyr::select(general_concept_id, general_concept_name, category, subcategory),
                  by = c("target_general_concept_id" = "general_concept_id")
                )

              # Enrich with target concept info (OMOP or custom)
              if ("target_custom_concept_id" %in% colnames(enriched_rows)) {
                # Enrich OMOP concepts
                vocab_data <- vocabularies()
                if (!is.null(vocab_data)) {
                  omop_rows <- enriched_rows %>% dplyr::filter(!is.na(target_omop_concept_id))
                  if (nrow(omop_rows) > 0) {
                    concept_ids <- omop_rows$target_omop_concept_id
                    omop_concepts <- vocab_data$concept %>%
                      dplyr::filter(concept_id %in% concept_ids) %>%
                      dplyr::select(
                        concept_id,
                        concept_name_target = concept_name,
                        vocabulary_id_target = vocabulary_id,
                        concept_code_target = concept_code
                      ) %>%
                      dplyr::collect()

                    enriched_rows <- enriched_rows %>%
                      dplyr::left_join(
                        omop_concepts,
                        by = c("target_omop_concept_id" = "concept_id")
                      )
                  } else {
                    enriched_rows <- enriched_rows %>%
                      dplyr::mutate(
                        concept_name_target = NA_character_,
                        vocabulary_id_target = NA_character_,
                        concept_code_target = NA_character_
                      )
                  }
                } else {
                  enriched_rows <- enriched_rows %>%
                    dplyr::mutate(
                      concept_name_target = NA_character_,
                      vocabulary_id_target = NA_character_,
                      concept_code_target = NA_character_
                    )
                }

                # Enrich custom concepts
                custom_concepts_path <- app_sys("extdata", "csv", "custom_concepts.csv")
                if (file.exists(custom_concepts_path)) {
                  custom_rows <- enriched_rows %>% dplyr::filter(!is.na(target_custom_concept_id))
                  if (nrow(custom_rows) > 0) {
                    custom_concepts_all <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
                    custom_concept_ids <- custom_rows$target_custom_concept_id

                    custom_concepts_info <- custom_concepts_all %>%
                      dplyr::filter(custom_concept_id %in% custom_concept_ids) %>%
                      dplyr::select(
                        custom_concept_id,
                        concept_name_custom = concept_name,
                        vocabulary_id_custom = vocabulary_id,
                        concept_code_custom = concept_code
                      )

                    enriched_rows <- enriched_rows %>%
                      dplyr::left_join(
                        custom_concepts_info,
                        by = c("target_custom_concept_id" = "custom_concept_id")
                      ) %>%
                      dplyr::mutate(
                        concept_name_target = ifelse(is.na(concept_name_target), concept_name_custom, concept_name_target),
                        vocabulary_id_target = ifelse(is.na(vocabulary_id_target), vocabulary_id_custom, vocabulary_id_target),
                        concept_code_target = ifelse(is.na(concept_code_target), concept_code_custom, concept_code_target)
                      ) %>%
                      dplyr::select(-concept_name_custom, -vocabulary_id_custom, -concept_code_custom)
                  }
                }
              } else {
                # Fallback: old CSV format
                vocab_data <- vocabularies()
                if (!is.null(vocab_data) && nrow(enriched_rows) > 0) {
                  concept_ids <- enriched_rows$target_omop_concept_id
                  omop_concepts <- vocab_data$concept %>%
                    dplyr::filter(concept_id %in% concept_ids) %>%
                    dplyr::select(
                      concept_id,
                      concept_name_target = concept_name,
                      vocabulary_id_target = vocabulary_id,
                      concept_code_target = concept_code
                    ) %>%
                    dplyr::collect()

                  enriched_rows <- enriched_rows %>%
                    dplyr::left_join(
                      omop_concepts,
                      by = c("target_omop_concept_id" = "concept_id")
                    )
                } else {
                  enriched_rows <- enriched_rows %>%
                    dplyr::mutate(
                      concept_name_target = NA_character_,
                      vocabulary_id_target = NA_character_,
                      concept_code_target = NA_character_
                    )
                }
              }

              # Build display dataframe
              display_df <- enriched_rows %>%
                dplyr::mutate(
                  Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
                  Target = paste0(
                    general_concept_name, " > ",
                    concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"
                  ),
                  Actions = sprintf(
                    '<button class="btn btn-sm btn-danger" style="padding: 2px 8px; font-size: 11px; line-height: 1.2;" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
                    ns("remove_mapping"), dplyr::row_number()
                  )
                ) %>%
                dplyr::select(Source, Target, Actions)

              # Update data via proxy
              proxy_realized <- DT::dataTableProxy("realized_mappings_table", session)
              DT::replaceData(proxy_realized, display_df, resetPaging = FALSE, rownames = FALSE)
            }
          }
        }
      }
    })

    # Show/hide Add Mapping button based on selections
    observe({
      # Only show in general view (not when viewing mapped concepts)
      if (mapping_view() != "general") {
        shinyjs::hide("add_mapping_from_general")
        return()
      }

      source_selected <- !is.null(input$source_concepts_table_rows_selected)
      general_selected <- !is.null(input$general_concepts_table_rows_selected)

      # Show button when both a source concept and a general concept are selected
      if (source_selected && general_selected) {
        shinyjs::show("add_mapping_from_general")
      } else {
        shinyjs::hide("add_mapping_from_general")
      }
    })

    # Handle Add Mapping from general view
    observe_event(input$add_mapping_from_general, {
      # Get selected rows
      source_row <- input$source_concepts_table_rows_selected
      general_row <- input$general_concepts_table_rows_selected

      # Validate selections
      if (is.null(source_row) || is.null(general_row)) return()

      # Get alignment info
      if (is.null(selected_alignment_id())) return()

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      app_folder <- Sys.getenv("INDICATE_APP_FOLDER", unset = NA)
      if (is.na(app_folder) || app_folder == "") {
        mapping_dir <- file.path(rappdirs::user_config_dir("indicate"), "concept_mapping")
      } else {
        mapping_dir <- file.path(app_folder, "indicate_files", "concept_mapping")
      }

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Read CSV
      if (!file.exists(csv_path)) return()

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Get general_concept_id from selected row in general_concepts_table
      if (is.null(data())) return()

      general_concepts <- data()$general_concepts
      target_general_concept_id <- general_concepts$general_concept_id[general_row]

      if (is.na(target_general_concept_id)) return()

      # Get first recommended OMOP concept mapping for this general concept (if available)
      concept_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == target_general_concept_id, recommended == TRUE)

      target_omop_concept_id <- NA_integer_
      if (nrow(concept_mappings) > 0) {
        target_omop_concept_id <- concept_mappings$omop_concept_id[1]
      }

      # Add mapping columns if they don't exist
      if (!"target_general_concept_id" %in% colnames(df)) {
        df$target_general_concept_id <- NA_integer_
      }
      if (!"target_omop_concept_id" %in% colnames(df)) {
        df$target_omop_concept_id <- NA_integer_
      }
      if (!"target_custom_concept_id" %in% colnames(df)) {
        df$target_custom_concept_id <- NA_integer_
      }
      if (!"mapping_datetime" %in% colnames(df)) {
        df$mapping_datetime <- NA_character_
      }
      if (!"mapped_by_user_id" %in% colnames(df)) {
        df$mapped_by_user_id <- NA_integer_
      }

      # Update the selected row with mapping info
      df$target_general_concept_id[source_row] <- target_general_concept_id
      df$target_omop_concept_id[source_row] <- target_omop_concept_id
      df$target_custom_concept_id[source_row] <- NA_integer_
      df$mapping_datetime[source_row] <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      df$mapped_by_user_id[source_row] <- if (!is.null(current_user())) current_user()$user_id else NA_integer_

      # Save CSV
      write.csv(df, csv_path, row.names = FALSE)

      # Deselect only the source concepts table (keep general concepts selection)
      proxy_source <- DT::dataTableProxy("source_concepts_table", session)
      DT::selectRows(proxy_source, NULL)

      # Force refresh of completed mappings table and source concepts table
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    })

    # Show/hide Add Mapping button based on selections (for mapped view)
    observe({
      source_selected <- !is.null(input$source_concepts_table_mapped_rows_selected)
      mapped_selected <- !is.null(input$mapped_concepts_table_rows_selected)

      if (source_selected && mapped_selected) {
        shinyjs::show("add_mapping_specific")
      } else {
        shinyjs::hide("add_mapping_specific")
      }
    })
  })
}
