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
#      ### View & Selection State - Track current view, selected alignment, tab
#      ### Edit Mode State - Manage edit/view mode (if applicable)
#      ### Data Management - Local data (alignments, uploaded data, vocabularies)
#      ### Cascade Triggers - Reactive triggers for cascade pattern
#
#   ## 2) Server - Navigation & Events
#      ### Trigger Updates - Cascade observers that propagate state changes
#      ### Breadcrumb Rendering - Dynamic breadcrumb navigation
#      ### Content Area Rendering - Switch between alignments list and detail views
#      ### Tab Switching - Handle Summary/All Mappings/Evaluate Mappings tabs
#      ### Navigation Handlers - All back button handlers (back_to_alignments, etc.)
#
#   ## 3) Server - Alignments List View
#      ### Alignments Table Rendering - Display alignments table
#      ### Add Alignment Modal - Create new alignment
#          #### Modal UI Handling - Show/hide modal, page navigation
#          #### File Upload & Processing - CSV/Excel upload, parsing
#          #### CSV Options & Column Mapping - Configure import options
#          #### File Preview - Display uploaded file preview
#          #### Save Alignment - Persist new alignment to database
#      ### Edit Alignment - Modify existing alignment
#      ### Delete Alignment - Remove alignment with confirmation
#      ### Open Alignment - Navigate to alignment detail view
#
#   ## 4) Server - Alignment Detail View
#      ### General Concepts Header Rendering - Display alignment header
#      ### Helper Functions - View Renderers - render_mapping_view(), etc.
#
#      ### a) Summary Tab
#          #### Source Concepts Table - Initial Render - Display source concepts (responds to alignment changes)
#          #### Source Concepts Table - Update Data Using Proxy - Preserve state during updates
#          #### General Concepts Table Rendering - Display general concepts
#          #### Concept Mappings Table Rendering - Display mappings for selected concept
#          #### Comments Display - Show ETL comments and guidance
#          #### Modal - Concept Details - Detailed concept information
#          #### Modal - ETL Comments - Fullscreen comments view
#          #### Add/Remove Mapping Actions - Create/delete mappings
#
#      ### b) All Mappings Tab
#          #### All Mappings Table - Initial Render - Display all mappings (responds to alignment changes)
#          #### All Mappings Table - Update Data Using Proxy - Preserve state during updates
#          #### Mapped View Tables - Source concepts and mapped concepts views
#          #### Delete Mapping Actions - Remove mappings
#
#      ### c) Import Mappings Tab
#          #### File Browser Modal Function - Show modal for file selection
#          #### File Path Display - Show selected file path
#          #### Browse Button Handler - Open file browser modal
#          #### Toggle Sort - Switch sort order
#          #### Filter Input - Filter files and folders
#          #### Current Path Display - Show current path in modal
#          #### Sort Icon Display - Show sort direction icon
#          #### Go Home Button - Navigate to home directory
#          #### File Browser Rendering - Display files and folders
#          #### Navigation Handler - Handle folder navigation
#          #### Select File Handler - Handle file selection
#          #### Cancel Browse - Close modal without selection
#          #### Import History Table - Display import history
#          #### Import CSV Handler - Process selected CSV file
#          #### Delete Import - Remove imported mappings
#
#      ### d) Evaluate Mappings Tab
#          #### Evaluate Mappings State - Track evaluation state
#          #### Evaluate Mappings Table - Initial Render - Display evaluation table (responds to alignment changes)
#          #### Evaluate Mappings Table - Update Data Using Proxy - Preserve state during updates
#          #### Projects Compatibility Table - Show project compatibility
#          #### Handle Evaluation Actions - Process votes
#          #### Handle Comment Editing - Double-click to edit comments
#          #### Save Comment - Persist comment changes
#
#      ### Export Alignment - Export functionality

# UI SECTION ====

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
mod_concept_mapping_ui <- function(id, i18n) {
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
          tags$h3(id = ns("alignment_modal_title"), i18n$t("add_alignment")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("alignment_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "flex: 1; overflow: hidden; padding: 20px; display: flex; flex-direction: column;",
          # Page 1: Name and Description
          tags$div(
            id = ns("modal_page_1"),
            tags$div(
              style = "margin-bottom: 20px;",
              tags$label(i18n$t("alignment_name"), style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              textInput(
                ns("alignment_name"),
                label = NULL,
                placeholder = as.character(i18n$t("enter_alignment_name")),
                width = "100%"
              ),
              tags$div(
                id = ns("alignment_name_error"),
                style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                i18n$t("please_enter_alignment_name")
              )
            ),
            tags$div(
              style = "margin-bottom: 20px;",
              tags$label(i18n$t("description"), style = "display: block; font-weight: 600; margin-bottom: 8px;"),
              textAreaInput(
                ns("alignment_description"),
                label = NULL,
                placeholder = as.character(i18n$t("enter_description")),
                width = "100%",
                rows = 4
              )
            )
          ),
          # Page 2: File Upload and Preview (hidden initially)
          tags$div(
            id = ns("modal_page_2"),
            style = "display: none; height: 100%;",
            tags$div(
              style = "display: flex; gap: 20px; height: 100%;",
              # Left: Upload and column mapping
              tags$div(
                style = "flex: 1; min-width: 50%; display: flex; flex-direction: column; overflow-y: auto; gap: 10px;",
                tags$div(
                  style = "background-color: #f8f9fa; border-radius: 4px; overflow: hidden;",
                  tags$div(
                    style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px;",
                    i18n$t("upload_csv_file")
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
                      i18n$t("please_upload_file")
                    )
                  )
                ),
                uiOutput(ns("csv_options")),
                uiOutput(ns("column_mapping_wrapper"))
              ),
              # Right: File preview
              tags$div(
                style = "width: 50%; display: flex; flex-direction: column; overflow: auto;",
                DT::DTOutput(ns("file_preview_table"))
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
              i18n$t("cancel"),
              class = "btn btn-secondary btn-secondary-custom",
              icon = icon("times")
            ),
            actionButton(
              ns("alignment_modal_back"),
              i18n$t("back"),
              class = "btn btn-secondary btn-secondary-custom",
              icon = icon("arrow-left"),
              style = "display: none;"
            ),
            actionButton(
              ns("alignment_modal_next"),
              i18n$t("next"),
              class = "btn-primary-custom",
              icon = icon("arrow-right")
            ),
            actionButton(
              ns("alignment_modal_save"),
              i18n$t("save"),
              class = "btn-success-custom",
              icon = icon("save"),
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
          tags$h3(i18n$t("etl_guidance_comments")),
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
          tags$h3(i18n$t("confirm_deletion")),
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
            i18n$t("delete_alignment_confirm")
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
            tags$i(class = "fas fa-times"),
            paste0(" ", i18n$t("cancel"))
          ),
          actionButton(
            ns("confirm_delete_alignment"),
            i18n$t("delete"),
            class = "btn btn-danger",
            icon = icon("trash")
          )
        )
      )
    ),

    ### Modal - Comments Fullscreen ----
    tags$div(
      id = ns("target_comments_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        tags$div(
          style = "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
          tags$h3(
            style = "margin: 0; color: #0f60af;",
            i18n$t("etl_guidance_comments")
          ),
          actionButton(
            ns("close_target_comments_fullscreen"),
            label = HTML("&times;"),
            class = "modal-close",
            style = "font-size: 28px; font-weight: 300; color: #666; border: none; background: none; cursor: pointer; padding: 0; width: 30px; height: 30px; line-height: 1;"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: auto; padding: 0;",
          uiOutput(ns("target_comments_fullscreen_content"))
        )
      )
    ),

    ### Modal - Eval Comments Fullscreen ----
    tags$div(
      id = ns("eval_comments_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        tags$div(
          style = "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
          tags$h3(
            style = "margin: 0; color: #0f60af;",
            i18n$t("etl_guidance_comments")
          ),
          actionButton(
            ns("close_eval_comments_fullscreen"),
            label = HTML("&times;"),
            class = "modal-close",
            style = "font-size: 28px; font-weight: 300; color: #666; border: none; background: none; cursor: pointer; padding: 0; width: 30px; height: 30px; line-height: 1;"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: auto; padding: 0;",
          uiOutput(ns("eval_comments_fullscreen_content"))
        )
      )
    ),

    ### Modal - Source JSON Fullscreen (Edit Mappings) ----
    tags$div(
      id = ns("source_json_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        tags$div(
          style = paste0(
            "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; ",
            "display: flex; justify-content: space-between; align-items: center; ",
            "box-shadow: 0 2px 4px rgba(0,0,0,0.1);"
          ),
          tags$h3(
            style = "margin: 0; color: #0f60af;",
            "Source Concept - JSON Structure"
          ),
          actionButton(
            ns("close_source_json_fullscreen"),
            label = HTML("&times;"),
            class = "modal-close",
            style = paste0(
              "font-size: 28px; font-weight: 300; color: #666; border: none; ",
              "background: none; cursor: pointer; padding: 0; width: 30px; ",
              "height: 30px; line-height: 1;"
            )
          )
        ),
        tags$div(
          style = "flex: 1; overflow: hidden; display: flex; gap: 0;",
          # Left column: Raw JSON
          tags$div(
            style = paste0(
              "flex: 1; overflow: auto; padding: 20px; background: #fff; ",
              "border-right: 1px solid #ddd;"
            ),
            tags$h4(
              style = "margin: 0 0 15px 0; color: #0f60af; font-size: 14px;",
              "Raw JSON"
            ),
            uiOutput(ns("source_json_fullscreen_content"))
          ),
          # Right column: Tutorial
          tags$div(
            style = "flex: 1; overflow: auto; padding: 20px; background: #f8f9fa;",
            uiOutput(ns("source_json_tutorial"))
          )
        )
      )
    ),

    ### Modal - Eval Source JSON Fullscreen (Evaluate Mappings) ----
    tags$div(
      id = ns("eval_source_json_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        tags$div(
          style = paste0(
            "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; ",
            "display: flex; justify-content: space-between; align-items: center; ",
            "box-shadow: 0 2px 4px rgba(0,0,0,0.1);"
          ),
          tags$h3(
            style = "margin: 0; color: #0f60af;",
            "Source Concept - JSON Structure"
          ),
          actionButton(
            ns("close_eval_source_json_fullscreen"),
            label = HTML("&times;"),
            class = "modal-close",
            style = paste0(
              "font-size: 28px; font-weight: 300; color: #666; border: none; ",
              "background: none; cursor: pointer; padding: 0; width: 30px; ",
              "height: 30px; line-height: 1;"
            )
          )
        ),
        tags$div(
          style = "flex: 1; overflow: hidden; display: flex; gap: 0;",
          # Left column: Raw JSON
          tags$div(
            style = paste0(
              "flex: 1; overflow: auto; padding: 20px; background: #fff; ",
              "border-right: 1px solid #ddd;"
            ),
            tags$h4(
              style = "margin: 0 0 15px 0; color: #0f60af; font-size: 14px;",
              "Raw JSON"
            ),
            uiOutput(ns("eval_source_json_fullscreen_content"))
          ),
          # Right column: Tutorial
          tags$div(
            style = "flex: 1; overflow: auto; padding: 20px; background: #f8f9fa;",
            uiOutput(ns("eval_source_json_tutorial"))
          )
        )
      )
    )

  )
}

# SERVER SECTION ====

#' Concept Mapping Module - Server
#'
#' @description Server function for the concept mapping module
#'
#' @param id Module ID
#' @param data Reactive list containing application data
#' @param config Reactive list containing configuration
#' @param vocabularies Reactive containing OHDSI vocabularies
#' @param current_user Reactive containing current user information
#' @param log_level Character vector specifying logging level
#'
#' @return Server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observe observeEvent req
#' @importFrom DT renderDT datatable formatStyle
mod_concept_mapping_server <- function(id, data, config, vocabularies, current_user = reactive(NULL), i18n = NULL, log_level = character()) {
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

    ### Edit Mode State ----
    # No edit mode currently implemented for this module

    ### Data Management ----
    # Load existing alignments from database
    initial_alignments <- get_all_alignments()

    # Store alignments data
    alignments_data <- reactiveVal(initial_alignments)

    # Store uploaded file data for current alignment
    uploaded_alignment_data <- reactiveVal(NULL)

    ### Cascade Triggers ----
    # Trigger to force refresh of completed mappings table
    mappings_refresh_trigger <- reactiveVal(0)

    # Track active mapping tab
    mapping_tab <- reactiveVal("summary")  # "summary", "edit_mappings", or "evaluate_mappings"

    # Evaluate mappings state
    # Note: Table state (page, search, length) is now managed by stateSave option in DataTables
    selected_eval_mapping_id <- reactiveVal(NULL)  # Track selected evaluation mapping for row selection
    eval_selected_row_data <- reactiveVal(NULL)  # Full row data for selected evaluation mapping
    eval_source_json <- reactiveVal(NULL)  # Source concept JSON data for evaluate mappings
    eval_source_row <- reactiveVal(NULL)  # Source concept row data for evaluate mappings
    eval_target_concept_id <- reactiveVal(NULL)  # Target general concept ID for evaluate mappings
    eval_target_json <- reactiveVal(NULL)  # Target concept JSON data for evaluate mappings
    eval_target_mapping <- reactiveVal(NULL)  # Target mapping data for evaluate mappings
    eval_source_tab <- reactiveVal("summary")  # Selected tab for source concept details
    eval_target_detail_tab <- reactiveVal("statistical_summary")  # Main tab: "comments" or "statistical_summary"
    eval_target_stats_sub_tab <- reactiveVal("summary")  # Sub-tab: "summary" or "distribution"
    eval_target_selected_profile <- reactiveVal(NULL)  # Selected profile name for evaluate target

    # Cascade triggers for selected_alignment_id() changes
    selected_alignment_id_trigger <- reactiveVal(0)  # Primary trigger when alignment selection changes
    all_mappings_table_trigger <- reactiveVal(0)  # Trigger for Summary tab table
    source_concepts_table_mapped_trigger <- reactiveVal(0)  # Trigger for Mapped view table
    source_concepts_table_general_trigger <- reactiveVal(0)  # Trigger for General view Edit Mappings table (alignment changes only)
    evaluate_mappings_table_trigger <- reactiveVal(0)  # Trigger for Evaluate Mappings tab table
    import_history_trigger <- reactiveVal(0)  # Trigger for Import Mappings history table

    # Import file browser state
    import_current_path <- reactiveVal(path.expand("~"))
    import_selected_file <- reactiveVal(NULL)
    import_sort_order <- reactiveVal("asc")
    import_filter_text <- reactiveVal("")
    import_message <- reactiveVal(NULL)

    # Separate trigger for source concepts table updates (used by mapping operations)
    source_concepts_table_trigger <- reactiveVal(0)  # Trigger for Edit Mappings table (mapping changes)

    # Cascade triggers for selected_general_concept_id() changes
    selected_general_concept_id_trigger <- reactiveVal(0)  # Primary trigger when general concept selection changes
    mapped_concepts_table_trigger <- reactiveVal(0)  # Trigger for Mapped view table
    concept_mappings_table_trigger <- reactiveVal(0)  # Trigger for Edit Mappings concept mappings table
    general_concepts_table_trigger <- reactiveVal(0)  # Trigger for General Concepts table in Edit Mappings

    # Cascade triggers for summary_trigger() changes
    summary_content_trigger <- reactiveVal(0)  # Trigger for summary content rendering
    projects_compatibility_table_trigger <- reactiveVal(0)  # Trigger for projects compatibility table

    ## 2) Server - Navigation & Events ----
    ### Trigger Updates ----
    # Summary tab reactive trigger
    summary_trigger <- reactiveVal(0)

    observe_event(c(selected_alignment_id(), data(), mappings_refresh_trigger()), {
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()
      summary_trigger(summary_trigger() + 1)
    }, ignoreInit = TRUE)

    ### Cascade Observer for summary_trigger() ----
    # Cascade observer: Fires all summary-specific triggers
    observe_event(summary_trigger(), {
      summary_content_trigger(summary_content_trigger() + 1)
      projects_compatibility_table_trigger(projects_compatibility_table_trigger() + 1)
    }, ignoreInit = TRUE)

    ### Cascade Observers for selected_alignment_id() ----
    # Primary observer: Fires main trigger when alignment selection changes
    observe_event(selected_alignment_id(), {
      selected_alignment_id_trigger(selected_alignment_id_trigger() + 1)
    }, ignoreInit = TRUE)

    # Cascade observer: Fires all table-specific triggers
    observe_event(selected_alignment_id_trigger(), {
      all_mappings_table_trigger(all_mappings_table_trigger() + 1)
      source_concepts_table_mapped_trigger(source_concepts_table_mapped_trigger() + 1)
      source_concepts_table_general_trigger(source_concepts_table_general_trigger() + 1)
      general_concepts_table_trigger(general_concepts_table_trigger() + 1)
      evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)
    }, ignoreInit = TRUE)

    ### Cascade Observers for selected_general_concept_id() ----
    # Primary observer: Fires main trigger when general concept selection changes
    observe_event(selected_general_concept_id(), {
      selected_general_concept_id_trigger(selected_general_concept_id_trigger() + 1)
    }, ignoreInit = TRUE)

    # Cascade observer: Fires all table-specific triggers
    observe_event(selected_general_concept_id_trigger(), {
      mapped_concepts_table_trigger(mapped_concepts_table_trigger() + 1)
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
    }, ignoreInit = TRUE)

    ### Breadcrumb Rendering ----
    output$breadcrumb <- renderUI({
      if (current_view() == "alignments") {
        NULL
      } else if (current_view() == "mapping") {
        if (is.null(selected_alignment_id())) return()
        alignment_name <- alignments_data() %>%
          dplyr::filter(alignment_id == selected_alignment_id()) %>%
          dplyr::pull(name)

        current_tab <- mapping_tab()

        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 12px; display: flex; align-items: center; justify-content: space-between;",
          # Left side: breadcrumb path
          tags$div(
            style = "display: flex; align-items: center; gap: 10px;",
            tags$a(
              class = "breadcrumb-link",
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
                  onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_general")),
                  alignment_name
                ),
                tags$span(style = "color: #6c757d; font-size: 16px; margin: 0 10px;", ">"),
                tags$span(
                  class = "section-title",
                  i18n$t("mapped_concepts")
                )
              )
            }
          ),
          # Right side: tabs navigation
          tags$div(
            style = "display: flex; gap: 5px;",
            tags$button(
              class = paste("tab-btn", if (current_tab == "summary") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'summary', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("summary")
            ),
            tags$button(
              class = paste("tab-btn", if (current_tab == "all_mappings") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'all_mappings', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("all_mappings")
            ),
            tags$button(
              class = paste("tab-btn", if (current_tab == "import_mappings") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'import_mappings', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("import_mappings")
            ),
            tags$button(
              class = paste("tab-btn", if (current_tab == "edit_mappings") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'edit_mappings', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("edit_mappings")
            ),
            tags$button(
              class = paste("tab-btn", if (current_tab == "evaluate_mappings") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'evaluate_mappings', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("evaluate_mappings")
            )
          )
        )
      }
    })

    # Handle tab clicks from breadcrumb
    observe_event(input$mapping_tab_click, {
      mapping_tab(input$mapping_tab_click)
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

    ### Tab Switching ----
    # Show/hide panels based on selected tab
    observe_event(mapping_tab(), {
      tab <- mapping_tab()

      # Hide all panels first
      shinyjs::hide("panel_summary")
      shinyjs::hide("panel_all_mappings")
      shinyjs::hide("panel_edit_mappings")
      shinyjs::hide("panel_import_mappings")
      shinyjs::hide("panel_evaluate_mappings")

      # Reset evaluate mappings selection state when leaving the tab
      shinyjs::hide("eval_details_container")
      eval_selected_row_data(NULL)
      eval_source_json(NULL)
      eval_source_row(NULL)
      eval_target_concept_id(NULL)
      eval_target_json(NULL)
      eval_target_mapping(NULL)

      # Show the selected panel
      if (tab == "summary") {
        shinyjs::show("panel_summary")
      } else if (tab == "all_mappings") {
        shinyjs::show("panel_all_mappings")
      } else if (tab == "edit_mappings") {
        shinyjs::show("panel_edit_mappings")
        # Trigger table rendering for Edit Mappings tab
        source_concepts_table_general_trigger(source_concepts_table_general_trigger() + 1)
        general_concepts_table_trigger(general_concepts_table_trigger() + 1)
      } else if (tab == "import_mappings") {
        shinyjs::show("panel_import_mappings")
        # Trigger import history table rendering
        import_history_trigger(import_history_trigger() + 1)
      } else if (tab == "evaluate_mappings") {
        shinyjs::show("panel_evaluate_mappings")
        shinyjs::runjs(sprintf("$('#%s').css('display', 'flex');", ns("panel_evaluate_mappings")))
      }
    }, ignoreNULL = FALSE)

    ### Navigation Handlers ----
    observe_event(input$back_to_alignments, {
      current_view("alignments")
      selected_alignment_id(NULL)
      mapping_view("general")
      selected_general_concept_id(NULL)
    })

    observe_event(input$back_to_general, {
      mapping_view("general")
      selected_general_concept_id(NULL)
    })

    observe_event(input$back_to_general_list, {
      selected_general_concept_id(NULL)
      concept_mappings_view("table")

      shinyjs::show("general_concepts_table_container")
      shinyjs::hide("concept_mappings_table_container")
    })

    observe_event(input$view_mapped_concepts, {
      general_concept_id <- input$view_mapped_concepts
      selected_general_concept_id(general_concept_id)

      shinyjs::hide("general_concepts_table_container")
      shinyjs::show("concept_mappings_table_container")

      shinyjs::hide("add_mapping_from_general")
    })

    observe_event(input$open_alignment, {
      selected_alignment_id(input$open_alignment)
      current_view("mapping")
      mapping_view("general")
    })

    ## 3) Server - Alignments List View ----
    ### Alignments Table Rendering ----
    output$alignments_table <- DT::renderDT({
      alignments <- alignments_data()

      if (nrow(alignments) == 0) {
        return(create_empty_datatable(i18n$t("no_alignments_yet")))
      }

      alignments_display <- alignments %>%
        dplyr::mutate(
          created_formatted = format(as.POSIXct(created_date), "%Y-%m-%d %H:%M")
        ) %>%
        dplyr::select(alignment_id, name, description, created_formatted)

      # Add action buttons (generate for each row)
      alignments_display$Actions <- sapply(alignments_display$alignment_id, function(id) {
        create_datatable_actions(list(
          list(
            label = "Open",
            icon = "folder-open",
            type = "primary",
            onclick = sprintf("Shiny.setInputValue('%s', %d, {priority: 'event'})", ns("open_alignment"), id)
          ),
          list(
            label = "Edit",
            icon = "edit",
            type = "warning",
            onclick = sprintf("Shiny.setInputValue('%s', %d, {priority: 'event'})", ns("edit_alignment"), id)
          ),
          list(
            label = "Export",
            icon = "download",
            type = "success",
            onclick = sprintf("Shiny.setInputValue('%s', %d, {priority: 'event'})", ns("export_alignment"), id)
          ),
          list(
            label = "Delete",
            icon = "trash",
            type = "danger",
            onclick = sprintf("Shiny.setInputValue('%s', %d, {priority: 'event'})", ns("delete_alignment"), id)
          )
        ))
      })

      dt <- datatable(
        alignments_display,
        escape = FALSE,
        rownames = FALSE,
        selection = 'none',
        options = list(
          pageLength = 25,
          dom = 'tp',
          language = get_datatable_language(),
          columnDefs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 4, orderable = FALSE, width = "300px", searchable = FALSE, className = "dt-center")
          )
        ),
        colnames = c(
          "ID",
          as.character(i18n$t("project_name")),
          as.character(i18n$t("description")),
          as.character(i18n$t("created")),
          as.character(i18n$t("actions"))
        )
      )

      dt <- add_doubleclick_handler(dt, ns("open_alignment"))
      dt
    }, server = TRUE)

    ### Add Alignment Modal ----
    #### Modal UI Handling ----
    observe_event(input$add_alignment, {
      modal_mode("add")
      modal_page(1)

      updateTextInput(session, "alignment_name", value = "")
      updateTextInput(session, "alignment_description", value = "")

      shinyjs::hide("alignment_name_error")
      shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))

      shinyjs::runjs(sprintf("$('#%s').text('Add Alignment');", ns("alignment_modal_title")))

      shinyjs::show("alignment_modal")
    })

    observe_event(input$alignment_name, {
      if (!is.null(input$alignment_name) && input$alignment_name != "") {
        shinyjs::hide("alignment_name_error")
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))
      }
    }, ignoreInit = TRUE)

    ### Edit Alignment ----
    observe_event(input$edit_alignment, {
      alignment_id <- input$edit_alignment
      alignment <- alignments_data() %>% filter(alignment_id == !!alignment_id)

      if (nrow(alignment) > 0) {
        modal_mode("edit")
        modal_page(1)
        selected_alignment_id(alignment_id)

        updateTextInput(session, "alignment_name", value = alignment$name)
        updateTextInput(session, "alignment_description", value = alignment$description)

        shinyjs::runjs(sprintf("$('#%s').text('Edit Alignment');", ns("alignment_modal_title")))

        shinyjs::hide("alignment_modal_next")
        shinyjs::show("alignment_modal_save")

        shinyjs::show("alignment_modal")
      }
    })

    #### File Upload & Processing ----
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

    #### CSV Options & Column Mapping ----
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

    output$column_mapping_title <- renderUI({
      if (is.null(input$alignment_file)) return()
      tags$div(
        style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px; border-radius: 4px 4px 0 0;",
        "Column Mapping"
      )
    })

    output$column_mapping_controls <- renderUI({
      if (is.null(input$alignment_file)) return()

      file_path <- input$alignment_file$datapath
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext == "csv") {
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
        tags$div(
          style = "margin-bottom: 10px;",
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
        tags$div(
          style = "display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 10px;",
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
          ),
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
          )
        ),
        tags$div(
          style = "display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 10px;",
          tags$div(
            style = "flex: 1; min-width: 150px;",
            tags$label("JSON Column", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
            selectInput(
              ns("col_json"),
              label = NULL,
              choices = choices,
              selected = ""
            )
          ),
          tags$div(
            style = "flex: 1; min-width: 150px;",
            tags$label("Additional Columns", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
            selectizeInput(
              ns("col_additional"),
              label = NULL,
              choices = col_names,
              selected = NULL,
              multiple = TRUE
            )
          )
        )
      )
    })

    #### File Preview ----
    observe_event(input$alignment_file, {
      if (is.null(input$alignment_file)) {
        file_preview_data(NULL)
        return()
      }

      file_path <- input$alignment_file$datapath
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext == "csv") {
        delimiter <- if (!is.null(input$csv_delimiter) && input$csv_delimiter != "auto") {
          input$csv_delimiter
        } else {
          NULL
        }

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

      df <- as.data.frame(df) %>% dplyr::distinct()
      file_preview_data(df)
    })

    output$file_preview_table <- DT::renderDT({
      df <- file_preview_data()

      if (is.null(df)) {
        return(datatable(
          data.frame(),
          options = list(
            pageLength = 8,
            dom = 'tp',
            ordering = TRUE,
            language = get_datatable_language()
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
          ordering = TRUE,
          language = get_datatable_language()
        ),
        rownames = FALSE,
        selection = 'none',
        filter = 'none',
        class = 'display'
      )
    }, server = TRUE)

    #### Modal Navigation & Save Handling ----
    observe_event(input$alignment_modal_next, {
      if (modal_page() == 1) {
        # Validate alignment name before proceeding to page 2
        is_valid <- validate_required_inputs(
          input,
          fields = list(alignment_name = "alignment_name_error")
        )

        if (!is_valid) {
          shinyjs::runjs(sprintf("$('#%s input').css('border-color', '#dc3545');", ns("alignment_name")))
          return()
        }

        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))

        modal_page(2)

        shinyjs::hide(id = "modal_page_1")
        shinyjs::show(id = "modal_page_2")

        shinyjs::runjs(sprintf("$('#%s').css({'max-width': '90vw', 'height': '80vh', 'max-height': '80vh'});", ns("alignment_modal_dialog")))

        shinyjs::runjs(sprintf("$('#%s').text('Page 2 of 2');", ns("modal_page_indicator")))
        shinyjs::show("alignment_modal_back")
        shinyjs::hide("alignment_modal_next")
        shinyjs::show("alignment_modal_save")
      }
    })

    observe_event(input$alignment_modal_back, {
      if (modal_page() == 2) {
        modal_page(1)

        shinyjs::show(id = "modal_page_1")
        shinyjs::hide(id = "modal_page_2")

        shinyjs::runjs(sprintf("$('#%s').css({'max-width': '600px', 'height': 'auto', 'max-height': '90vh'});", ns("alignment_modal_dialog")))

        shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 2');", ns("modal_page_indicator")))
        shinyjs::hide("alignment_modal_back")
        shinyjs::show("alignment_modal_next")
        shinyjs::hide("alignment_modal_save")
      }
    })

    observe_event(input$alignment_modal_cancel, {
      shinyjs::hide("alignment_modal")

      updateTextInput(session, "alignment_name", value = "")
      updateTextAreaInput(session, "alignment_description", value = "")

      file_preview_data(NULL)

      shinyjs::reset("alignment_file")

      updateSelectInput(session, "csv_delimiter", selected = "auto")
      updateSelectInput(session, "csv_encoding", selected = "UTF-8")
      updateSelectInput(session, "col_vocabulary_id", selected = "")
      updateSelectInput(session, "col_concept_code", selected = "")
      updateSelectInput(session, "col_concept_name", selected = "")
      updateSelectInput(session, "col_json", selected = "")
      updateSelectInput(session, "col_additional", selected = character(0))

      shinyjs::runjs(sprintf("$('#%s').html('');", ns("csv_options")))
      shinyjs::runjs(sprintf("$('#%s').html('');", ns("column_mapping_wrapper")))

      shinyjs::hide("alignment_name_error")
      shinyjs::hide("alignment_file_error")
      shinyjs::hide("col_vocabulary_id_error")
      shinyjs::hide("col_concept_code_error")
      shinyjs::hide("col_concept_name_error")

      modal_page(1)

      shinyjs::show(id = "modal_page_1")
      shinyjs::hide(id = "modal_page_2")
      shinyjs::runjs(sprintf("$('#%s').css({'max-width': '600px', 'height': 'auto', 'max-height': '90vh'});", ns("alignment_modal_dialog")))

      shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 2');", ns("modal_page_indicator")))
      shinyjs::hide("alignment_modal_back")
      shinyjs::show("alignment_modal_next")
      shinyjs::hide("alignment_modal_save")
    })

    observe_event(input$alignment_file, {
      if (!is.null(input$alignment_file)) {
        shinyjs::hide("alignment_file_error")
      }
    })

    observe_event(input$col_vocabulary_id, {
      if (!is.null(input$col_vocabulary_id) && input$col_vocabulary_id != "") {
        shinyjs::hide("col_vocabulary_id_error")
      }
    })

    observe_event(input$col_concept_code, {
      if (!is.null(input$col_concept_code) && input$col_concept_code != "") {
        shinyjs::hide("col_concept_code_error")
      }
    })

    observe_event(input$col_concept_name, {
      if (!is.null(input$col_concept_name) && input$col_concept_name != "") {
        shinyjs::hide("col_concept_name_error")
      }
    })

    #### Save Alignment ----
    observe_event(input$alignment_modal_save, {
      # Validate alignment name (required for both add and edit modes)
      is_valid <- validate_required_inputs(
        input,
        fields = list(alignment_name = "alignment_name_error")
      )

      if (!is_valid) {
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '#dc3545');", ns("alignment_name")))
        return()
      } else {
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))
      }

      # Validate file upload and column mappings (only for add mode)
      if (modal_mode() == "add") {
        # Check file upload separately (not a text input)
        if (is.null(input$alignment_file)) {
          shinyjs::show("alignment_file_error")
          return()
        }

        # Validate required column mappings
        is_valid <- validate_required_inputs(
          input,
          fields = list(
            col_vocabulary_id = "col_vocabulary_id_error",
            col_concept_code = "col_concept_code_error",
            col_concept_name = "col_concept_name_error"
          )
        )

        if (!is_valid) return()
      }

      if (modal_mode() == "add") {
        file_path <- input$alignment_file$datapath
        file_ext <- tools::file_ext(input$alignment_file$name)

        if (file_ext == "csv") {
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

        col_mapping <- list(
          vocabulary_id = input$col_vocabulary_id,
          concept_code = input$col_concept_code,
          concept_name = input$col_concept_name,
          json = input$col_json
        )

        additional_cols <- input$col_additional
        if (is.null(additional_cols)) {
          additional_cols <- character(0)
        }

        new_cols <- list()

        for (new_name in names(col_mapping)) {
          old_name <- col_mapping[[new_name]]
          if (!is.null(old_name) && old_name != "" && old_name %in% colnames(df)) {
            new_cols[[new_name]] <- df[[old_name]]
          }
        }

        for (col in additional_cols) {
          if (col %in% colnames(df) && !col %in% names(col_mapping)) {
            final_name <- col
            suffix <- 2
            while (final_name %in% names(new_cols)) {
              final_name <- paste0(col, "_", suffix)
              suffix <- suffix + 1
            }
            new_cols[[final_name]] <- df[[col]]
          }
        }

        new_df <- as.data.frame(new_cols, stringsAsFactors = FALSE)

        new_df <- new_df %>% dplyr::distinct()

        new_df <- cbind(mapping_id = seq_len(nrow(new_df)), new_df, stringsAsFactors = FALSE)

        file_id <- paste0("alignment_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))

        mapping_dir <- get_app_dir("concept_mapping")

        if (!dir.exists(mapping_dir)) {
          dir.create(mapping_dir, recursive = TRUE, showWarnings = FALSE)
        }

        csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
        write.csv(new_df, csv_path, row.names = FALSE)

        new_id <- add_alignment(
          name = input$alignment_name,
          description = ifelse(is.null(input$alignment_description), "", input$alignment_description),
          file_id = file_id,
          original_filename = input$alignment_file$name
        )

        alignments_data(get_all_alignments())
      } else if (modal_mode() == "edit") {
        update_alignment(
          alignment_id = selected_alignment_id(),
          name = input$alignment_name,
          description = ifelse(is.null(input$alignment_description), "", input$alignment_description)
        )

        alignments_data(get_all_alignments())
      }

      shinyjs::hide("alignment_modal")
      modal_page(1)

      shinyjs::show(id = "modal_page_1")
      shinyjs::hide(id = "modal_page_2")
      shinyjs::runjs(sprintf("$('#%s').css({'max-width': '600px', 'height': 'auto', 'max-height': '90vh'});", ns("alignment_modal_dialog")))

      shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 2');", ns("modal_page_indicator")))
      shinyjs::hide("alignment_modal_back")
      shinyjs::show("alignment_modal_next")
      shinyjs::hide("alignment_modal_save")
    })

    ### Delete Alignment ----
    observe_event(input$delete_alignment, {
      alignment_id <- input$delete_alignment
      alignment_to_delete(alignment_id)

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == !!alignment_id)

      if (nrow(alignment) == 1) {
        alignment_name <- alignment$name[1]
        shinyjs::html("delete_alignment_name_display", alignment_name)
      }

      shinyjs::show("delete_confirmation_modal")
    })

    observe_event(input$confirm_delete_alignment, {
      if (is.null(alignment_to_delete())) return()

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == alignment_to_delete())

      if (nrow(alignment) == 1) {
        file_id <- alignment$file_id[1]

        mapping_dir <- get_app_dir("concept_mapping")

        csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
        if (file.exists(csv_path)) {
          file.remove(csv_path)
        }
      }

      delete_alignment(alignment_to_delete())
      alignments_data(get_all_alignments())

      shinyjs::hide("delete_confirmation_modal")
      alignment_to_delete(NULL)
    })
    
    
    ### Export Alignment ----
    observe_event(input$export_alignment, {
      alignment_id <- input$export_alignment
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == !!alignment_id)
      
      if (nrow(alignment) == 0) return()
      
      file_id <- alignment$file_id[1]
      alignment_name <- alignment$name[1]
      
      mapping_dir <- get_app_dir("concept_mapping")
      
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
      
      if (!file.exists(csv_path)) {
        showNotification(i18n$t("no_mapping_file_found"), type = "error")
        return()
      }
      
      df <- read.csv(csv_path, stringsAsFactors = FALSE)
      
      if (!"target_general_concept_id" %in% colnames(df)) {
        showNotification(i18n$t("no_mappings_found"), type = "warning")
        return()
      }
      
      mapped_rows <- df %>%
        dplyr::filter(!is.na(target_general_concept_id))
      
      if (nrow(mapped_rows) == 0) {
        showNotification(i18n$t("no_mappings_found"), type = "warning")
        return()
      }
      
      vocab_data <- vocabularies()
      
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
      
      for (i in 1:nrow(mapped_rows)) {
        mapped_concept <- mapped_rows[i, ]
        
        target_concept_id <- 0
        target_vocabulary_id <- NA_character_
        
        if (!is.na(mapped_concept$target_omop_concept_id) && mapped_concept$target_omop_concept_id != 0) {
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
        
        valid_start_date <- "1970-01-01"
        if ("mapping_datetime" %in% colnames(mapped_concept) && !is.na(mapped_concept$mapping_datetime)) {
          valid_start_date <- format(as.Date(as.POSIXct(mapped_concept$mapping_datetime)), "%Y-%m-%d")
        }
        
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
      
      safe_name <- gsub("[^a-zA-Z0-9_-]", "_", alignment_name)
      timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
      filename <- paste0(safe_name, "_source_to_concept_map_", timestamp, ".csv")
      
      temp_csv <- tempfile(fileext = ".csv")
      write.csv(export_data, temp_csv, row.names = FALSE, quote = TRUE, na = "")
      csv_content <- paste(readLines(temp_csv, warn = FALSE), collapse = "\n")
      unlink(temp_csv)
      
      csv_encoded <- base64enc::base64encode(charToRaw(csv_content))
      download_js <- sprintf(
        "var link = document.createElement('a');
         link.href = 'data:text/csv;base64,%s';
         link.download = '%s';
         link.click();",
        csv_encoded,
        filename
      )
      
      shinyjs::runjs(download_js)
    })

    ## 4) Server - Alignment Detail View ----
    ### Helper Functions - View Renderers ----
    
    
    # Function to enrich data with target concept information (OMOP and custom)
    enrich_target_concepts <- function(enriched_data, vocabularies_data, data_obj) {
      # Enrich OMOP concepts
      vocab_data <- vocabularies_data
      if (!is.null(vocab_data)) {
        omop_rows <- enriched_data %>% dplyr::filter(!is.na(target_omop_concept_id))
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
          
          enriched_data <- enriched_data %>%
            dplyr::left_join(
              omop_concepts,
              by = c("target_omop_concept_id" = "concept_id")
            )
        } else {
          enriched_data <- enriched_data %>%
            dplyr::mutate(
              concept_name_target = NA_character_,
              vocabulary_id_target = NA_character_,
              concept_code_target = NA_character_
            )
        }
      } else {
        enriched_data <- enriched_data %>%
          dplyr::mutate(
            concept_name_target = NA_character_,
            vocabulary_id_target = NA_character_,
            concept_code_target = NA_character_
          )
      }
      
      # Enrich custom concepts
      custom_concepts_path <- get_csv_path("custom_concepts.csv")
      if (file.exists(custom_concepts_path)) {
        custom_rows <- enriched_data %>% dplyr::filter(!is.na(target_custom_concept_id))
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
          enriched_data <- enriched_data %>%
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
      
      return(enriched_data)
    }
    
    render_alignments_view <- function() {
      tags$div(
        style = "height: 100%; display: flex; flex-direction: column;",
        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 12px; display: flex; align-items: center; gap: 15px; justify-content: space-between;",
          tags$div(
            class = "section-title",
            "Concept Mappings"
          ),
          tags$div(
            style = "display: flex; gap: 10px;",
            actionButton(
              ns("add_alignment"),
              i18n$t("add_alignment"),
              class = "btn-success-custom",
              icon = icon("plus")
            )
          )
        ),
        tags$div(
          class = "card-container",
          style = "padding: 20px; flex: 1; min-height: 0; overflow: auto; margin: 0 10px 10px 10px;",
          DT::DTOutput(ns("alignments_table"))
        )
      )
    }

    render_mapping_view <- function() {
      tags$div(
        class = "panel-container-full",
        style = "display: flex; flex-direction: column; height: 100%;",

        # Summary panel
        tags$div(
          id = ns("panel_summary"),
          style = "height: 100%; display: flex; flex-direction: column;",
          uiOutput(ns("summary_content"))
        ),

        # All Mappings panel
        tags$div(
          id = ns("panel_all_mappings"),
          class = "card-container",
          style = "margin: 0 10px 10px 10px; height: calc(100% - 10px); min-height: 0; overflow: auto; display: none;",
          DT::DTOutput(ns("all_mappings_table_main"))
        ),

        # Edit Mappings panel
        tags$div(
          id = ns("panel_edit_mappings"),
          style = "display: none; height: calc(100% - 60px); min-height: 0; margin: 0 10px 10px 10px;",
          tags$div(
            style = "height: 100%; display: flex; gap: 15px; min-height: 0;",
            # Left column: Source Concepts (top) + Concept Details (bottom)
            tags$div(
              style = "flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 15px;",
              # Top-left: Source Concepts table
              tags$div(
                class = "card-container card-container-flex",
                style = "flex: 1; min-height: 0;",
                tags$div(
                  class = "section-header",
                  tags$div(
                    style = "flex: 1;",
                    tags$h4(
                      style = "margin: 0;",
                      i18n$t("source_concepts"),
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
                    icon = icon("plus"),
                    style = "height: 32px; padding: 5px 15px; font-size: 14px; display: none;"
                  )
                ),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto;",
                  DT::DTOutput(ns("source_concepts_table"))
                )
              ),
              # Bottom-left: Concept Details with tabs for JSON visualization
              tags$div(
                id = ns("concept_details_panel"),
                class = "card-container card-container-flex",
                style = "flex: 1; min-height: 0; display: none;",
                tags$div(
                  class = "section-header",
                  style = "margin-bottom: 0;",
                  tags$h4(style = "margin: 0;", i18n$t("source_concept_details")),
                  actionButton(
                    ns("view_source_json"),
                    label = NULL,
                    icon = icon("code"),
                    class = "btn-icon-only has-tooltip",
                    style = paste0(
                      "background: transparent; border: none; color: #333; ",
                      "padding: 4px 7px; cursor: pointer; font-size: 12px; ",
                      "margin-left: auto;"
                    ),
                    `data-tooltip` = i18n$t("view_raw_json")
                  )
                ),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto; padding: 0 10px 10px 10px;",
                  # Tabs for different JSON views
                  tags$div(
                    style = "display: flex; gap: 5px; margin-bottom: 10px;",
                    tags$button(
                      id = ns("detail_tab_summary"),
                      class = "tab-btn tab-btn-active",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'summary', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("summary")
                    ),
                    tags$button(
                      id = ns("detail_tab_distribution"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'distribution', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("distribution")
                    ),
                    tags$button(
                      id = ns("detail_tab_temporal"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'temporal', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("temporal")
                    ),
                    tags$button(
                      id = ns("detail_tab_units"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'units', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("hospital_units")
                    ),
                    tags$button(
                      id = ns("detail_tab_other"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'other', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("other")
                    )
                  ),
                  # Content area for selected tab
                  uiOutput(ns("concept_details_content"))
                )
              )
            ),
            # Right column: General Concepts (top) + Target Concept Details (bottom)
            tags$div(
              style = "flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 10px;",
              # Top-right: General Concepts table
              tags$div(
                id = ns("general_concepts_panel"),
                class = "card-container card-container-flex",
                style = "flex: 1; min-height: 0;",
                uiOutput(ns("general_concepts_header")),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto;",
                  tags$div(
                    id = ns("general_concepts_table_container"),
                    style = "height: 100%;",
                    DT::DTOutput(ns("general_concepts_table"))
                  ),
                  tags$div(
                    id = ns("concept_mappings_table_container"),
                    style = "height: 100%; display: none;",
                    DT::DTOutput(ns("concept_mappings_table"))
                  )
                )
              ),
              # Bottom-right: Target Concept Details with tabs in header (no gray background)
              tags$div(
                id = ns("target_concept_details_panel"),
                class = "card-container card-container-flex",
                style = "flex: 1; min-height: 0; display: none;",
                tags$div(
                  class = "section-header",
                  style = "position: relative;",
                  tags$h4(
                    style = "margin: 0;",
                    "Target Concept Details",
                    tags$span(
                      class = "info-icon",
                      `data-tooltip` = "Details of the selected target concept from the dictionary",
                      "ⓘ"
                    )
                  ),
                  # Main tabs: Comments + Statistical Summary (top-right)
                  tags$div(
                    class = "section-tabs",
                    tags$button(
                      id = ns("target_detail_tab_comments"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s > .section-header > .section-tabs .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'comments', {priority: 'event'});
                      ", ns("target_concept_details_panel"), ns("target_detail_tab_selected")),
                      "Comments"
                    ),
                    tags$button(
                      id = ns("target_detail_tab_statistical_summary"),
                      class = "tab-btn tab-btn-active",
                      onclick = sprintf("
                        document.querySelectorAll('#%s > .section-header > .section-tabs .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'statistical_summary', {priority: 'event'});
                      ", ns("target_concept_details_panel"), ns("target_detail_tab_selected")),
                      "Statistical Summary"
                    )
                  )
                ),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto;",
                  uiOutput(ns("target_concept_details_content"))
                )
              )
            )
          )
        ),

        # Import Mappings panel
        tags$div(
          id = ns("panel_import_mappings"),
          class = "import-mappings-panel",
          style = "margin: 0 10px 10px 10px; height: calc(100% - 10px); min-height: 0; display: none; flex-direction: column;",

          # Import from CSV widget
          tags$div(
            class = "card-container",
            style = "height: 50%; overflow: auto; padding: 20px;",
            # Header with title and import button on same line
            tags$div(
              style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;",
              tags$h4(style = "margin: 0; color: #0f60af;", i18n$t("import_mappings_from_csv")),
              tags$div(
                style = "display: flex; align-items: center; gap: 10px;",
                actionButton(
                  ns("do_import_mappings"),
                  i18n$t("import_mappings"),
                  class = "btn-primary-custom",
                  icon = icon("file-import")
                ),
                uiOutput(ns("import_status_message"), inline = TRUE)
              )
            ),
            tags$p(
              style = "margin-bottom: 10px; color: #666;",
              i18n$t("import_mappings_csv_desc")
            ),
            tags$ul(
              style = "margin-bottom: 20px; color: #666; padding-left: 20px;",
              tags$li(tags$code(i18n$t("source_code_col")), " - ", i18n$t("source_code_desc")),
              tags$li(tags$code(i18n$t("source_vocabulary_id_col")), " - ", i18n$t("source_vocabulary_id_desc")),
              tags$li(tags$code(i18n$t("target_concept_id_col")), " - ", i18n$t("target_concept_id_desc"))
            ),

            # Browse button and file path display
            tags$div(
              tags$label(style = "display: block; margin-bottom: 5px; font-weight: 500;", i18n$t("select_csv_file")),
              tags$div(
                style = "display: flex; align-items: center; gap: 15px;",
                actionButton(
                  ns("browse_import_file"),
                  label = tagList(
                    tags$i(class = "fas fa-folder-open", style = "margin-right: 6px;"),
                    i18n$t("browse")
                  ),
                  style = "background: #0f60af; color: white; border: none; padding: 8px 16px; border-radius: 6px; font-weight: 500; cursor: pointer;"
                ),
                tags$div(
                  style = "flex: 1;",
                  uiOutput(ns("import_file_path_display"))
                )
              )
            )
          ),

          # Import History widget
          tags$div(
            class = "card-container",
            style = "margin-top: 10px; height: calc(50% - 10px); overflow: auto; padding: 20px;",
            tags$h4(style = "margin-bottom: 15px; color: #0f60af;", i18n$t("import_history")),
            DT::DTOutput(ns("import_history_table"))
          )
        ),

        # Evaluate Mappings panel
        tags$div(
          id = ns("panel_evaluate_mappings"),
          style = "margin: 0 10px 10px 10px; height: calc(100% - 10px); min-height: 0; display: none; flex-direction: column; gap: 10px;",
          # Top: Mappings table
          tags$div(
            class = "card-container",
            style = "flex: 1; min-height: 0; overflow: auto;",
            DT::DTOutput(ns("evaluate_mappings_table"))
          ),
          # Bottom: Source and Target Concept Details side by side
          tags$div(
            id = ns("eval_details_container"),
            style = "display: none; flex-direction: row; gap: 10px; flex: 1; min-height: 0;",
            # Left: Source Concept Details
            tags$div(
              id = ns("eval_source_concept_details_panel"),
              class = "card-container card-container-flex",
              style = "flex: 1; min-width: 0;",
              tags$div(
                class = "section-header",
                style = "margin-bottom: 0;",
                tags$h4(style = "margin: 0;", i18n$t("source_concept_details")),
                actionButton(
                  ns("view_eval_source_json"),
                  label = NULL,
                  icon = icon("code"),
                  class = "btn-icon-only has-tooltip",
                  style = paste0(
                    "background: transparent; border: none; color: #333; ",
                    "padding: 4px 7px; cursor: pointer; font-size: 12px; ",
                    "margin-left: auto;"
                  ),
                  `data-tooltip` = i18n$t("view_raw_json")
                )
              ),
              tags$div(
                style = "flex: 1; min-height: 0; overflow: auto; padding: 0 10px 10px 10px;",
                # Tabs for different views
                tags$div(
                  style = "display: flex; gap: 5px; margin-bottom: 10px;",
                  tags$button(
                    id = ns("eval_source_tab_summary"),
                    class = "tab-btn tab-btn-active",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'summary', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("summary")
                  ),
                  tags$button(
                    id = ns("eval_source_tab_distribution"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'distribution', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("distribution")
                  ),
                  tags$button(
                    id = ns("eval_source_tab_temporal"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'temporal', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("temporal")
                  ),
                  tags$button(
                    id = ns("eval_source_tab_units"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'units', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("hospital_units")
                  ),
                  tags$button(
                    id = ns("eval_source_tab_other"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'other', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("other")
                  )
                ),
                # Content area for selected tab
                uiOutput(ns("eval_source_concept_details_content"))
              )
            ),
            # Right: Target Concept Details (matching Edit Mappings structure)
            tags$div(
              id = ns("eval_target_concept_details_panel"),
              class = "card-container card-container-flex",
              style = "flex: 1; min-width: 0;",
              tags$div(
                class = "section-header",
                style = "position: relative;",
                tags$h4(
                  style = "margin: 0;",
                  "Target Concept Details",
                  tags$span(
                    class = "info-icon",
                    `data-tooltip` = "Details of the selected target concept from the dictionary",
                    "ⓘ"
                  )
                ),
                # Main tabs: Comments + Statistical Summary (top-right)
                tags$div(
                  class = "section-tabs",
                  tags$button(
                    id = ns("eval_target_detail_tab_comments"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s > .section-header > .section-tabs .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'comments', {priority: 'event'});
                    ", ns("eval_target_concept_details_panel"), ns("eval_target_detail_tab_selected")),
                    "Comments"
                  ),
                  tags$button(
                    id = ns("eval_target_detail_tab_statistical_summary"),
                    class = "tab-btn tab-btn-active",
                    onclick = sprintf("
                      document.querySelectorAll('#%s > .section-header > .section-tabs .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'statistical_summary', {priority: 'event'});
                    ", ns("eval_target_concept_details_panel"), ns("eval_target_detail_tab_selected")),
                    "Statistical Summary"
                  )
                )
              ),
              tags$div(
                style = "flex: 1; min-height: 0; overflow: auto;",
                uiOutput(ns("eval_target_concept_details_content"))
              )
            )
          )
        )
      )
    }

    render_mapped_concepts_view <- function() {
      tags$div(
        class = "panel-container-full",
        style = "display: flex; flex-direction: column; height: 100%;",
        tags$div(
          style = "height: 70%; display: flex; gap: 15px; min-height: 0;",
          tags$div(
            class = "card-container card-container-flex",
            tags$div(
              class = "section-header",

              tags$h4(
                i18n$t("source_concepts"),
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
          tags$div(
            class = "card-container card-container-flex",
            tags$div(
              class = "section-header",
              style = "height: 40px; display: flex; justify-content: space-between; align-items: center;",
              tags$h4(
                style = "margin: 0;",
                i18n$t("mapped_concepts"),
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = i18n$t("mapped_concepts_tooltip"),
                  "ⓘ"
                )
              ),
              actionButton(
                ns("add_mapping_specific"),
                "Add Mapping",
                class = "btn-success-custom",
                icon = icon("plus"),
                style = "height: 32px; padding: 5px 15px; font-size: 14px; display: none;"
              )
            ),
            tags$div(
              style = "flex: 1; min-height: 0; overflow: auto;",
              DT::DTOutput(ns("mapped_concepts_table"))
            )
          )
        ),
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
            i18n$t("general_concepts"),
            tags$span(
              class = "info-icon",
              `data-tooltip` = i18n$t("general_concepts_tooltip"),
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
              i18n$t("general_concepts")
            ),
            tags$span(style = "color: #6c757d; margin: 0 8px;", ">"),
            tags$span(concept_name)
          )
        )
      }
    })

    ### a) Summary Tab ----
    #### Summary Content Rendering ----
    observe_event(summary_content_trigger(), {
      if (is.null(selected_alignment_id())) {
        output$summary_content <- renderUI({
          tags$div("No alignment selected")
        })
        return()
      }

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) {
        output$summary_content <- renderUI({
          tags$div("No alignment selected")
        })
        return()
      }

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      mapping_dir <- get_app_dir("concept_mapping")
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Get database path
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        output$summary_content <- renderUI({
          tags$div("Database not found")
        })
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get total source concepts from CSV (if exists)
      total_source_concepts <- 0
      if (file.exists(csv_path)) {
        df <- read.csv(csv_path, stringsAsFactors = FALSE)
        total_source_concepts <- nrow(df)
      }

      # Count unique source concepts that have mappings (includes both manual and imported)
      mappings_query <- "
        SELECT COUNT(DISTINCT csv_mapping_id) as unique_source_concepts
        FROM concept_mappings
        WHERE alignment_id = ?
      "
      mappings_result <- DBI::dbGetQuery(con, mappings_query, params = list(selected_alignment_id()))
      mapped_source_concepts <- mappings_result$unique_source_concepts[1]

      pct_mapped_source <- if (total_source_concepts > 0) {
        round((mapped_source_concepts / total_source_concepts) * 100, 1)
      } else {
        0
      }

      # Get all general concepts mapped from database
      # First get all mappings with their target IDs
      all_mappings_query <- "
        SELECT DISTINCT target_general_concept_id, target_omop_concept_id
        FROM concept_mappings
        WHERE alignment_id = ?
      "
      all_mappings <- DBI::dbGetQuery(con, all_mappings_query, params = list(selected_alignment_id()))

      # For mappings with target_general_concept_id, use it directly
      direct_general_ids <- all_mappings$target_general_concept_id[!is.na(all_mappings$target_general_concept_id)]

      # For imported mappings (target_general_concept_id is NULL but target_omop_concept_id is set),
      # look up the general concept from the dictionary data
      imported_omop_ids <- all_mappings$target_omop_concept_id[
        is.na(all_mappings$target_general_concept_id) & !is.na(all_mappings$target_omop_concept_id)
      ]

      # Look up general concepts from dictionary for imported OMOP concept IDs
      dictionary_mappings <- data()$concept_mappings
      if (!is.null(dictionary_mappings) && length(imported_omop_ids) > 0) {
        lookup_general_ids <- dictionary_mappings$general_concept_id[
          dictionary_mappings$omop_concept_id %in% imported_omop_ids
        ]
        lookup_general_ids <- unique(lookup_general_ids[!is.na(lookup_general_ids)])
      } else {
        lookup_general_ids <- integer(0)
      }

      # Combine both sources
      mapped_general_concept_ids <- unique(c(direct_general_ids, lookup_general_ids))
      total_general_concepts <- length(mapped_general_concept_ids)

      # Calculate percentage of dictionary coverage
      total_dictionary_concepts <- nrow(data()$general_concepts)
      pct_general_concepts <- if (total_dictionary_concepts > 0) {
        round((total_general_concepts / total_dictionary_concepts) * 100, 1)
      } else {
        0
      }

      # Count evaluated concepts (concepts with at least one evaluation)
      evaluated_query <- "
        SELECT COUNT(DISTINCT cm.mapping_id) as evaluated_count
        FROM concept_mappings cm
        INNER JOIN mapping_evaluations me ON cm.mapping_id = me.mapping_id
        WHERE cm.alignment_id = ?
      "
      evaluated_result <- DBI::dbGetQuery(con, evaluated_query, params = list(selected_alignment_id()))
      evaluated_count <- evaluated_result$evaluated_count[1]

      pct_evaluated <- if (mapped_source_concepts > 0) {
        round((evaluated_count / mapped_source_concepts) * 100, 1)
      } else {
        0
      }

      # Render UI
      output$summary_content <- renderUI({
        tags$div(
          style = "height: 100%; min-height: 0; display: flex; flex-direction: column;",

          # Summary cards
          tags$div(
            style = paste0(
              "display: flex; flex-wrap: wrap; ",
              "gap: 20px; align-content: flex-start; ",
              "margin: 0 10px;"
            ),

            # Card 1: Mapped concepts in alignment
            tags$div(
              style = paste0(
                "flex: 1 1 300px; background: white; ",
                "border-radius: 8px; padding: 20px; ",
                "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                "border-left: 4px solid #28a745;"
              ),
              tags$div(
                style = "font-size: 14px; color: #666; margin-bottom: 8px;",
                i18n$t("mapped_concepts")
              ),
              tags$div(
                style = paste0(
                  "font-size: 32px; font-weight: 700; color: #28a745; ",
                  "margin-bottom: 5px;"
                ),
                paste0(mapped_source_concepts, " / ", total_source_concepts)
              ),
              tags$div(
                style = "font-size: 18px; color: #999;",
                paste0(pct_mapped_source, "%")
              )
            ),

            # Card 2: General concepts mapped
            tags$div(
              style = paste0(
                "flex: 1 1 300px; background: white; ",
                "border-radius: 8px; padding: 20px; ",
                "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                "border-left: 4px solid #17a2b8;"
              ),
              tags$div(
                style = "font-size: 14px; color: #666; margin-bottom: 8px;",
                i18n$t("general_concepts_mapped")
              ),
              tags$div(
                style = paste0(
                  "font-size: 32px; font-weight: 700; color: #17a2b8; ",
                  "margin-bottom: 5px;"
                ),
                paste0(total_general_concepts, " / ", total_dictionary_concepts)
              ),
              tags$div(
                style = "font-size: 18px; color: #999;",
                paste0(pct_general_concepts, "%")
              )
            ),

            # Card 3: Evaluated mappings
            tags$div(
              style = paste0(
                "flex: 1 1 300px; background: white; ",
                "border-radius: 8px; padding: 20px; ",
                "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                "border-left: 4px solid #ffc107;"
              ),
              tags$div(
                style = "font-size: 14px; color: #666; margin-bottom: 8px;",
                i18n$t("evaluated_mappings")
              ),
              tags$div(
                style = paste0(
                  "font-size: 32px; font-weight: 700; color: #ffc107; ",
                  "margin-bottom: 5px;"
                ),
                paste0(evaluated_count, " / ", mapped_source_concepts)
              ),
              tags$div(
                style = "font-size: 18px; color: #999;",
                paste0(pct_evaluated, "%")
              )
            )
          ),

          # Projects Compatibility Section
          tags$div(
            style = "flex: 1; min-height: 0;",
            tags$div(
              class = "card-container",
              style = "margin: 10px 10px 10px 10px; height: calc(100% - 20px); overflow: auto;",
              tags$div(
                class = "section-header",
                style = "background: none; border-bottom: none; padding: 0 0 0 5px;",
                tags$span(
                  class = "section-title",
                  i18n$t("projects_compatibility")
                )
              ),
              DT::DTOutput(ns("projects_compatibility_table"))
            )
          )
        )
      })
    })

    #### Projects Compatibility Table ----
    observe_event(projects_compatibility_table_trigger(), {
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()

      output$projects_compatibility_table <- DT::renderDT({
        # Get projects and concept assignments
        projects <- data()$projects
        general_concept_projects <- data()$general_concept_projects

        if (is.null(projects) || nrow(projects) == 0) {
          return(create_empty_datatable("No projects defined"))
        }

        # Get alignment mappings
        alignments <- alignments_data()
        alignment <- alignments %>%
          dplyr::filter(alignment_id == selected_alignment_id())

        if (nrow(alignment) != 1) return()

        file_id <- alignment$file_id[1]

        # Get CSV path
        mapping_dir <- get_app_dir("concept_mapping")

        csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

        if (!file.exists(csv_path)) {
          return(create_empty_datatable("CSV file not found"))
        }

        # Read CSV to get mapped general concepts
        df <- read.csv(csv_path, stringsAsFactors = FALSE)
        mapped_general_concept_ids <- unique(df$target_general_concept_id[!is.na(df$target_general_concept_id)])

        # Build project compatibility table
        uc_compat <- projects %>%
          dplyr::rowwise() %>%
          dplyr::mutate(
            total_concepts = {
              if (is.null(general_concept_projects)) {
                0L
              } else {
                current_uc_id <- project_id
                nrow(general_concept_projects %>%
                  dplyr::filter(project_id == current_uc_id))
              }
            },
            mapped_concepts = {
              if (is.null(general_concept_projects)) {
                0L
              } else {
                current_uc_id <- project_id
                required_gc_ids <- general_concept_projects %>%
                  dplyr::filter(project_id == current_uc_id) %>%
                  dplyr::pull(general_concept_id)
                sum(required_gc_ids %in% mapped_general_concept_ids)
              }
            },
            covered = ifelse(total_concepts > 0 && mapped_concepts == total_concepts, "Yes", "No")
          ) %>%
          dplyr::ungroup() %>%
          dplyr::select(project_name, short_description, total_concepts, mapped_concepts, covered)

        # Create datatable
        dt <- datatable(
          uc_compat,
          rownames = FALSE,
          selection = 'none',
          filter = 'top',
          options = list(
            pageLength = 10,
            lengthMenu = c(5, 10, 15, 20, 50),
            dom = 'ltp',
            ordering = TRUE,
            autoWidth = FALSE,
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 2, width = "100px", className = "dt-center"),
              list(targets = 3, width = "100px", className = "dt-center"),
              list(targets = 4, width = "80px", className = "dt-center")
            )
          ),
          colnames = c(
            as.character(i18n$t("name")),
            as.character(i18n$t("description")),
            as.character(i18n$t("total_concepts")),
            as.character(i18n$t("mapped_concepts")),
            as.character(i18n$t("covered"))
          )
        ) %>%
          style_yes_no_custom("covered")

        dt
      }, server = TRUE)
    })

    ### b) All Mappings Tab ----
    #### All Mappings Table Rendering ----
    # Render table when trigger fires
    observe_event(all_mappings_table_trigger(), {
      # Check visibility and prerequisites first
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()

      # Get mappings from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        output$all_mappings_table_main <- DT::renderDT({
          create_empty_datatable("Database not found")
        }, server = TRUE)
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings for this alignment from database
      mappings_db <- DBI::dbGetQuery(
        con,
        "SELECT
          cm.mapping_id,
          cm.csv_file_path,
          cm.csv_mapping_id,
          cm.source_concept_index,
          cm.target_general_concept_id,
          cm.target_omop_concept_id,
          cm.target_custom_concept_id,
          cm.imported_mapping_id
        FROM concept_mappings cm
        WHERE cm.alignment_id = ?",
        params = list(selected_alignment_id())
      )

      if (nrow(mappings_db) == 0) {
        output$all_mappings_table_main <- DT::renderDT({
          create_empty_datatable("No mappings created yet.")
        }, server = TRUE)
        return()
      }

      # Try to read source CSV for concept names (optional)
      csv_path <- mappings_db$csv_file_path[1]
      source_df <- NULL
      if (file.exists(csv_path)) {
        source_df <- read.csv(csv_path, stringsAsFactors = FALSE)
      }

      # Enrich with source concept information by matching on mapping_id
      if (!is.null(source_df) && "mapping_id" %in% colnames(source_df)) {
        # Join on mapping_id column from CSV
        source_cols <- c("mapping_id")
        if ("concept_name" %in% colnames(source_df)) source_cols <- c(source_cols, "concept_name")
        if ("concept_code" %in% colnames(source_df)) source_cols <- c(source_cols, "concept_code")
        if ("vocabulary_id" %in% colnames(source_df)) source_cols <- c(source_cols, "vocabulary_id")

        source_join_df <- source_df[, source_cols, drop = FALSE]
        colnames(source_join_df) <- c("csv_mapping_id",
          if ("concept_name" %in% colnames(source_df)) "concept_name_source" else NULL,
          if ("concept_code" %in% colnames(source_df)) "concept_code_source" else NULL,
          if ("vocabulary_id" %in% colnames(source_df)) "vocabulary_id_source" else NULL
        )

        mapped_rows <- mappings_db %>%
          dplyr::left_join(source_join_df, by = "csv_mapping_id")

        # Fill in defaults for missing columns
        if (!"concept_name_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_name_source = paste0("Source concept #", source_concept_index))
        } else {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_name_source = dplyr::if_else(
              is.na(concept_name_source),
              paste0("Source concept #", source_concept_index),
              concept_name_source
            ))
        }
        if (!"concept_code_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_code_source = NA_character_)
        }
        if (!"vocabulary_id_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(vocabulary_id_source = NA_character_)
        }
      } else {
        # Fallback for CSV without mapping_id column
        mapped_rows <- mappings_db %>%
          dplyr::mutate(
            concept_name_source = paste0("Source concept #", source_concept_index),
            concept_code_source = NA_character_,
            vocabulary_id_source = NA_character_
          )
      }

      if (nrow(mapped_rows) == 0) {
        output$all_mappings_table_main <- DT::renderDT({
          create_empty_datatable("No mappings created yet.")
        }, server = TRUE)
        return()
      }

      # Enrich with general concept information
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
        enriched_rows <- enrich_target_concepts(enriched_rows, vocabularies(), data())
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

      # We already have mapping_id from the initial database query, rename it to db_mapping_id
      enriched_rows <- enriched_rows %>%
        dplyr::rename(db_mapping_id = mapping_id)

      # Get vote statistics from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (file.exists(db_path)) {
        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        # Get vote counts for each mapping
        vote_query <- "
          SELECT
            cm.mapping_id,
            COUNT(CASE WHEN me.is_approved = 1 THEN 1 END) as upvotes,
            COUNT(CASE WHEN me.is_approved = 0 THEN 1 END) as downvotes,
            COUNT(CASE WHEN me.is_approved = -1 THEN 1 END) as uncertain_votes
          FROM concept_mappings cm
          LEFT JOIN mapping_evaluations me ON cm.mapping_id = me.mapping_id
          WHERE cm.alignment_id = ?
          GROUP BY cm.mapping_id
        "
        vote_stats <- DBI::dbGetQuery(con, vote_query, params = list(selected_alignment_id()))

        # Join vote stats with enriched_rows using the db mapping_id
        enriched_rows <- enriched_rows %>%
          dplyr::left_join(vote_stats, by = c("db_mapping_id" = "mapping_id"))
      } else {
        # No database, set vote columns to 0
        enriched_rows <- enriched_rows %>%
          dplyr::mutate(
            upvotes = 0L,
            downvotes = 0L,
            uncertain_votes = 0L
          )
      }

      # Build display dataframe
      display_df <- enriched_rows %>%
        dplyr::mutate(
          Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
          Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
          Origin = dplyr::if_else(
            is.na(imported_mapping_id),
            sprintf('<span style="background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("manual")),
            sprintf('<span style="background: #0f60af; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("imported"))
          ),
          Upvotes = ifelse(is.na(upvotes), 0L, as.integer(upvotes)),
          Downvotes = ifelse(is.na(downvotes), 0L, as.integer(downvotes)),
          Uncertain = ifelse(is.na(uncertain_votes), 0L, as.integer(uncertain_votes)),
          Actions = sprintf(
            '<button class="dt-action-btn dt-action-btn-danger delete-mapping-btn" data-id="%d">%s</button>',
            db_mapping_id,
            i18n$t("delete")
          )
        ) %>%
        dplyr::select(Source, Target, Origin, Upvotes, Downvotes, Uncertain, Actions)

      # Render table with prepared data (All Mappings)
      output$all_mappings_table_main <- DT::renderDT({
        dt <- datatable(
          display_df,
          escape = FALSE,
          filter = 'top',
          options = list(
            pageLength = 15,
            lengthMenu = c(10, 15, 20, 50, 100, 200),
            dom = 'ltp',
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 2, width = "80px", className = "dt-center"),
              list(targets = 3, width = "60px", className = "dt-center"),
              list(targets = 4, width = "60px", className = "dt-center"),
              list(targets = 5, width = "60px", className = "dt-center"),
              list(targets = 6, searchable = FALSE, orderable = FALSE, className = "dt-center")
            )
          ),
          rownames = FALSE,
          selection = 'none',
          colnames = c(
            as.character(i18n$t("source_concept")),
            as.character(i18n$t("target_concept")),
            as.character(i18n$t("origin")),
            as.character(i18n$t("upvotes")),
            as.character(i18n$t("downvotes")),
            as.character(i18n$t("uncertain")),
            as.character(i18n$t("actions"))
          )
        )

        # Add button handlers
        dt <- add_button_handlers(
          dt,
          handlers = list(
            list(selector = ".delete-mapping-btn", input_id = ns("delete_mapping_main"))
          )
        )

        dt
      }, server = TRUE)
    })

    #### Update All Mappings Table Data Using Proxy ----
    # Update data without re-rendering when mappings change
    observe_event(mappings_refresh_trigger(), {
      if (mappings_refresh_trigger() == 0) return()
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()

      # Get mappings from database (same logic as initial render)
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings for this alignment from database
      mappings_db <- DBI::dbGetQuery(
        con,
        "SELECT
          cm.mapping_id,
          cm.csv_file_path,
          cm.csv_mapping_id,
          cm.source_concept_index,
          cm.target_general_concept_id,
          cm.target_omop_concept_id,
          cm.target_custom_concept_id,
          cm.imported_mapping_id
        FROM concept_mappings cm
        WHERE cm.alignment_id = ?",
        params = list(selected_alignment_id())
      )

      if (nrow(mappings_db) == 0) {
        # Force full re-render when table becomes empty
        all_mappings_table_trigger(all_mappings_table_trigger() + 1)
        return()
      }

      # Try to read source CSV for concept names (optional)
      csv_path <- mappings_db$csv_file_path[1]
      source_df <- NULL
      if (file.exists(csv_path)) {
        source_df <- read.csv(csv_path, stringsAsFactors = FALSE)
      }

      # Enrich with source concept information by matching on mapping_id
      if (!is.null(source_df) && "mapping_id" %in% colnames(source_df)) {
        # Join on mapping_id column from CSV
        source_cols <- c("mapping_id")
        if ("concept_name" %in% colnames(source_df)) source_cols <- c(source_cols, "concept_name")
        if ("concept_code" %in% colnames(source_df)) source_cols <- c(source_cols, "concept_code")
        if ("vocabulary_id" %in% colnames(source_df)) source_cols <- c(source_cols, "vocabulary_id")

        source_join_df <- source_df[, source_cols, drop = FALSE]
        colnames(source_join_df) <- c("csv_mapping_id",
          if ("concept_name" %in% colnames(source_df)) "concept_name_source" else NULL,
          if ("concept_code" %in% colnames(source_df)) "concept_code_source" else NULL,
          if ("vocabulary_id" %in% colnames(source_df)) "vocabulary_id_source" else NULL
        )

        mapped_rows <- mappings_db %>%
          dplyr::left_join(source_join_df, by = "csv_mapping_id")

        # Fill in defaults for missing columns
        if (!"concept_name_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_name_source = paste0("Source concept #", source_concept_index))
        } else {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_name_source = dplyr::if_else(
              is.na(concept_name_source),
              paste0("Source concept #", source_concept_index),
              concept_name_source
            ))
        }
        if (!"concept_code_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_code_source = NA_character_)
        }
        if (!"vocabulary_id_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(vocabulary_id_source = NA_character_)
        }
      } else {
        # Fallback for CSV without mapping_id column
        mapped_rows <- mappings_db %>%
          dplyr::mutate(
            concept_name_source = paste0("Source concept #", source_concept_index),
            concept_code_source = NA_character_,
            vocabulary_id_source = NA_character_
          )
      }

      # Enrich with general concept information
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
        enriched_rows <- enrich_target_concepts(enriched_rows, vocabularies(), data())
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

      # Rename mapping_id to db_mapping_id
      enriched_rows <- enriched_rows %>%
        dplyr::rename(db_mapping_id = mapping_id)

      # Get vote counts for each mapping
      vote_query <- "
        SELECT
          cm.mapping_id,
          COUNT(CASE WHEN me.is_approved = 1 THEN 1 END) as upvotes,
          COUNT(CASE WHEN me.is_approved = 0 THEN 1 END) as downvotes,
          COUNT(CASE WHEN me.is_approved = -1 THEN 1 END) as uncertain_votes
        FROM concept_mappings cm
        LEFT JOIN mapping_evaluations me ON cm.mapping_id = me.mapping_id
        WHERE cm.alignment_id = ?
        GROUP BY cm.mapping_id
      "
      vote_stats <- DBI::dbGetQuery(con, vote_query, params = list(selected_alignment_id()))

      # Join vote stats with enriched_rows using the db mapping_id
      enriched_rows <- enriched_rows %>%
        dplyr::left_join(vote_stats, by = c("db_mapping_id" = "mapping_id"))

      # Build display dataframe
      display_df <- enriched_rows %>%
        dplyr::mutate(
          Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
          Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
          Origin = dplyr::if_else(
            is.na(imported_mapping_id),
            sprintf('<span style="background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("manual")),
            sprintf('<span style="background: #0f60af; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("imported"))
          ),
          Upvotes = ifelse(is.na(upvotes), 0L, as.integer(upvotes)),
          Downvotes = ifelse(is.na(downvotes), 0L, as.integer(downvotes)),
          Uncertain = ifelse(is.na(uncertain_votes), 0L, as.integer(uncertain_votes)),
          Actions = sprintf(
            '<button class="dt-action-btn dt-action-btn-danger delete-mapping-btn" data-id="%d">%s</button>',
            db_mapping_id,
            i18n$t("delete")
          )
        ) %>%
        dplyr::select(Source, Target, Origin, Upvotes, Downvotes, Uncertain, Actions)

      # Update table data using proxy (preserves state)
      shinyjs::delay(100, {
        proxy <- DT::dataTableProxy("all_mappings_table_main", session = session)
        DT::replaceData(proxy, display_df, resetPaging = FALSE, rownames = FALSE)
      })
    }, ignoreInit = TRUE)

    #### Delete Mapping Actions ----
    observe_event(input$delete_mapping_main, {
      if (is.null(input$delete_mapping_main)) return()
      if (is.null(selected_alignment_id())) return()

      # Get the mapping_id directly from button click (data-id attribute)
      mapping_id_to_delete <- as.integer(input$delete_mapping_main)

      if (is.na(mapping_id_to_delete)) return()

      # Get mapping details from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get mapping details
      mapping_to_delete <- DBI::dbGetQuery(
        con,
        "SELECT csv_file_path, csv_mapping_id FROM concept_mappings WHERE mapping_id = ?",
        params = list(mapping_id_to_delete)
      )

      if (nrow(mapping_to_delete) == 0) return()

      # Delete from database
      delete_concept_mapping(mapping_id_to_delete)

      # Update CSV file to remove the mapping
      csv_path <- mapping_to_delete$csv_file_path[1]
      csv_mapping_id <- mapping_to_delete$csv_mapping_id[1]

      if (!is.na(csv_path) && !is.na(csv_mapping_id) && file.exists(csv_path)) {
        df <- read.csv(csv_path, stringsAsFactors = FALSE)

        # Find the row with this mapping_id
        row_to_clear <- which(df$mapping_id == csv_mapping_id)

        if (length(row_to_clear) > 0) {
          # Clear mapping columns
          if ("target_general_concept_id" %in% colnames(df)) df$target_general_concept_id[row_to_clear] <- NA_integer_
          if ("target_omop_concept_id" %in% colnames(df)) df$target_omop_concept_id[row_to_clear] <- NA_integer_
          if ("target_custom_concept_id" %in% colnames(df)) df$target_custom_concept_id[row_to_clear] <- NA_integer_
          if ("mapped_by_user_id" %in% colnames(df)) df$mapped_by_user_id[row_to_clear] <- NA_integer_
          if ("mapping_datetime" %in% colnames(df)) df$mapping_datetime[row_to_clear] <- NA_character_

          write.csv(df, csv_path, row.names = FALSE)
        }
      }

      # Trigger refresh
      source_concepts_table_trigger(source_concepts_table_trigger() + 1)
      source_concepts_table_general_trigger(source_concepts_table_general_trigger() + 1)
      evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    }, ignoreInit = TRUE)

    #### Mapped View Tables ----
    observe_event(source_concepts_table_mapped_trigger(), {
      # Check visibility first
      if (is.null(selected_alignment_id())) return()
      if (mapping_view() != "mapped") return()

      # Prepare all data outside renderDT
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]

      mapping_dir <- get_app_dir("concept_mapping")

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      if (!file.exists(csv_path)) {
        output$source_concepts_table_mapped <- DT::renderDT({
          datatable(
            data.frame(Error = "CSV file not found"),
            options = list(dom = 't'),
            rownames = FALSE,
            selection = 'none'
          )
        }, server = TRUE)
        return()
      }

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      standard_cols <- c("vocabulary_id", "concept_code", "concept_name", "statistical_summary")
      available_standard <- standard_cols[standard_cols %in% colnames(df)]
      excluded_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id", "mapping_id")
      other_cols <- setdiff(colnames(df), c(standard_cols, excluded_cols))
      df_final <- df[, c(available_standard, other_cols), drop = FALSE]

      # Render table with prepared data only
      output$source_concepts_table_mapped <- DT::renderDT({
        datatable(
          df_final,
          options = list(
            pageLength = 8,
            lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c('5', '8', '10', '15', '20', '50', '100')),
            dom = 'ltp',
            language = get_datatable_language()
          ),
          rownames = FALSE,
          selection = 'single'
        )
      }, server = TRUE)
    })

    observe_event(mapped_concepts_table_trigger(), {
      # Check visibility first
      if (is.null(selected_general_concept_id())) return()
      if (is.null(data())) return()
      if (is.null(vocabularies())) return()
      if (mapping_view() != "mapped") return()

      # Prepare all data outside renderDT
      concept_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == selected_general_concept_id())

      if (nrow(concept_mappings) == 0) {
        output$mapped_concepts_table <- DT::renderDT({
          create_empty_datatable("No mapped concepts found for this general concept.")
        }, server = TRUE)
        return()
      }

      vocabs <- vocabularies()
      mapped_with_details <- concept_mappings %>%
        dplyr::left_join(
          vocabs$concept %>% dplyr::select(concept_id, concept_name, concept_code, vocabulary_id, standard_concept) %>% dplyr::collect(),
          by = c("omop_concept_id" = "concept_id")
        ) %>%
        dplyr::select(omop_concept_id, concept_name, concept_code, vocabulary_id, standard_concept)

      # Render table with prepared data only
      output$mapped_concepts_table <- DT::renderDT({
        datatable(
          mapped_with_details,
          options = list(
            pageLength = 10,
            lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c('5', '8', '10', '15', '20', '50', '100')),
            dom = 'ltp',
            language = get_datatable_language()
          ),
          rownames = FALSE,
          selection = 'single',
          colnames = c(
            as.character(i18n$t("omop_concept_id")),
            as.character(i18n$t("concept_name")),
            as.character(i18n$t("concept_code")),
            as.character(i18n$t("vocabulary")),
            as.character(i18n$t("standard"))
          )
        )
      }, server = TRUE)
    })

    observe_event(mappings_refresh_trigger(), {
      # Check visibility first
      if (is.null(selected_alignment_id())) return()
      if (mapping_view() != "mapped") return()

      # Prepare data outside renderDT
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) {
        return(create_empty_datatable("No alignment selected"))
      }

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      mapping_dir <- get_app_dir("concept_mapping")

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Check if file exists
      if (!file.exists(csv_path)) {
        return(create_empty_datatable("CSV file not found"))
      }

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Filter only rows with mappings
      if (!"target_omop_concept_id" %in% colnames(df)) {
        # No mappings yet
        return(create_empty_datatable("No mappings created yet. Select a source concept and a mapped concept, then click 'Add Mapping'."))
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
        return(create_empty_datatable("No mappings created yet. Select a source concept and a mapped concept, then click 'Add Mapping'."))
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
        custom_concepts_path <- get_csv_path("custom_concepts.csv")
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

      # Render table with prepared data
      output$realized_mappings_table_mapped <- DT::renderDT({
        datatable(
          display_df,
          escape = FALSE,
          options = list(
            pageLength = 6,
            dom = 'tp',
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 2, className = "dt-center")
            )
          ),
          rownames = FALSE,
          selection = 'none',
          colnames = c(
            as.character(i18n$t("source_concept")),
            as.character(i18n$t("target_concept")),
            as.character(i18n$t("actions"))
          )
        )
      }, server = TRUE)
    })

    ### c) Edit Mappings Tab ----
    #### Source Concepts Table Rendering ----
    # Render table when trigger fires (alignment changes)
    observe_event(source_concepts_table_general_trigger(), {
      # Check visibility first
      if (is.null(selected_alignment_id())) return()
      if (mapping_view() != "general") return()
      if (mapping_tab() != "edit_mappings") return()

      # Prepare all data outside renderDT
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      
      if (nrow(alignment) != 1) return()
      
      file_id <- alignment$file_id[1]
      
      mapping_dir <- get_app_dir("concept_mapping")
      
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
      
      if (!file.exists(csv_path)) {
        output$source_concepts_table <- DT::renderDT({
          datatable(
            data.frame(Error = "CSV file not found"),
            options = list(dom = "t"),
            rownames = FALSE,
            selection = "none"
          )
        }, server = FALSE)
        return()
      }

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      if ("vocabulary_id" %in% colnames(df)) {
        df <- df %>%
          dplyr::mutate(vocabulary_id = as.factor(vocabulary_id))
      }

      # Add row index for matching with database mappings
      df <- df %>%
        dplyr::mutate(row_index = dplyr::row_number())

      # Check database for mappings (includes imported mappings)
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")
      db_mapped_indices <- integer(0)

      if (file.exists(db_path)) {
        con_db <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        db_mappings <- DBI::dbGetQuery(
          con_db,
          "SELECT DISTINCT csv_mapping_id FROM concept_mappings WHERE alignment_id = ?",
          params = list(selected_alignment_id())
        )
        db_mapped_indices <- db_mappings$csv_mapping_id
        DBI::dbDisconnect(con_db)
      }

      has_target_cols <- "target_general_concept_id" %in% colnames(df)
      has_omop_cols <- "target_omop_concept_id" %in% colnames(df)

      # Consider mapped if: CSV has target columns set OR concept exists in database mappings
      # Build mapped status based on available columns (avoid referencing non-existent columns)
      csv_mapped <- rep(FALSE, nrow(df))
      if (has_target_cols) {
        csv_mapped <- csv_mapped | !is.na(df$target_general_concept_id)
      }
      if (has_omop_cols) {
        csv_mapped <- csv_mapped | !is.na(df$target_omop_concept_id)
      }
      db_mapped <- df$row_index %in% db_mapped_indices

      df <- df %>%
        dplyr::mutate(
          Mapped = factor(
            ifelse(csv_mapped | db_mapped, "Yes", "No"),
            levels = c("Yes", "No")
          )
        ) %>%
        dplyr::select(-row_index)

      standard_cols <- c("vocabulary_id", "concept_code", "concept_name", "statistical_summary")
      available_standard <- standard_cols[standard_cols %in% colnames(df)]
      target_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id", "mapping_id")
      other_cols <- setdiff(colnames(df), c(standard_cols, target_cols, "Mapped"))
      df_display <- df[, c(available_standard, other_cols, "Mapped"), drop = FALSE]

      nice_names <- colnames(df_display)
      nice_names[nice_names == "vocabulary_id"] <- as.character(i18n$t("vocabulary"))
      nice_names[nice_names == "concept_code"] <- as.character(i18n$t("concept_code"))
      nice_names[nice_names == "concept_name"] <- as.character(i18n$t("name"))
      nice_names[nice_names == "statistical_summary"] <- as.character(i18n$t("summary"))
      nice_names[nice_names == "Mapped"] <- as.character(i18n$t("mapped"))

      mapped_col_index <- which(colnames(df_display) == "Mapped") - 1

      # Find JSON column index to hide by default
      json_col_index <- which(colnames(df_display) == "json") - 1

      # Build columnDefs list
      column_defs <- list(
        list(targets = mapped_col_index, width = "80px", className = "dt-center")
      )

      # Hide JSON column by default if it exists
      if (length(json_col_index) > 0) {
        column_defs <- c(column_defs, list(
          list(targets = json_col_index, visible = FALSE)
        ))
      }

      # Render table with prepared data only
      output$source_concepts_table <- DT::renderDT({
        dt <- datatable(
          df_display,
          filter = "top",
          extensions = "Buttons",
          options = list(
            pageLength = 8,
            lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c("5", "8", "10", "15", "20", "50", "100")),
            dom = "Bltp",
            language = get_datatable_language(),
            buttons = list(
              list(
                extend = "colvis",
                text = as.character(i18n$t("show_hide_columns"))
              )
            ),
            columnDefs = column_defs
          ),
          colnames = nice_names,
          rownames = FALSE,
          selection = "single"
        )
        
        dt <- dt %>%
          style_yes_no_column("Mapped")

        dt
      }, server = TRUE)
    })

    #### Update Source Concepts Table Data Using Proxy ----
    # Update data without re-rendering when mappings change
    observe_event(source_concepts_table_trigger(), {
      if (source_concepts_table_trigger() == 0) return()
      if (is.null(selected_alignment_id())) return()
      
      # Prepare updated data (same logic as initial render)
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      
      if (nrow(alignment) != 1) return()
      
      file_id <- alignment$file_id[1]
      
      mapping_dir <- get_app_dir("concept_mapping")

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      if (!file.exists(csv_path)) return()

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      if ("vocabulary_id" %in% colnames(df)) {
        df <- df %>%
          dplyr::mutate(vocabulary_id = as.factor(vocabulary_id))
      }

      # Add row index for matching with database mappings
      df <- df %>%
        dplyr::mutate(row_index = dplyr::row_number())

      # Check database for mappings (includes imported mappings)
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")
      db_mapped_indices <- integer(0)

      if (file.exists(db_path)) {
        con_db <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        db_mappings <- DBI::dbGetQuery(
          con_db,
          "SELECT DISTINCT csv_mapping_id FROM concept_mappings WHERE alignment_id = ?",
          params = list(selected_alignment_id())
        )
        db_mapped_indices <- db_mappings$csv_mapping_id
        DBI::dbDisconnect(con_db)
      }

      has_target_cols <- "target_general_concept_id" %in% colnames(df)
      has_omop_cols <- "target_omop_concept_id" %in% colnames(df)

      # Consider mapped if: CSV has target columns set OR concept exists in database mappings
      # Build mapped status based on available columns (avoid referencing non-existent columns)
      csv_mapped <- rep(FALSE, nrow(df))
      if (has_target_cols) {
        csv_mapped <- csv_mapped | !is.na(df$target_general_concept_id)
      }
      if (has_omop_cols) {
        csv_mapped <- csv_mapped | !is.na(df$target_omop_concept_id)
      }
      db_mapped <- df$row_index %in% db_mapped_indices

      df <- df %>%
        dplyr::mutate(
          Mapped = factor(
            ifelse(csv_mapped | db_mapped, "Yes", "No"),
            levels = c("Yes", "No")
          )
        ) %>%
        dplyr::select(-row_index)

      standard_cols <- c("vocabulary_id", "concept_code", "concept_name", "statistical_summary")
      available_standard <- standard_cols[standard_cols %in% colnames(df)]
      target_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id", "mapping_id")
      other_cols <- setdiff(colnames(df), c(standard_cols, target_cols, "Mapped"))
      df_display <- df[, c(available_standard, other_cols, "Mapped"), drop = FALSE]

      # Update table data using proxy (preserves state)
      shinyjs::delay(100, {
        proxy <- DT::dataTableProxy("source_concepts_table", session = session)
        DT::replaceData(proxy, df_display, resetPaging = FALSE, rownames = FALSE)
      })
    }, ignoreInit = TRUE)
    
    #### General Concepts Table Rendering ----
    observe_event(c(data(), general_concepts_table_trigger()), {
      # Check visibility first
      if (is.null(data())) return()
      if (mapping_view() != "general") return()
      if (mapping_tab() != "edit_mappings") return()

      # Prepare data outside renderDT
      general_concepts <- data()$general_concepts

      general_concepts_display <- data.frame(
        general_concept_id = general_concepts$general_concept_id,
        category = as.factor(general_concepts$category),
        subcategory = as.factor(general_concepts$subcategory),
        general_concept_name = general_concepts$general_concept_name,
        stringsAsFactors = FALSE
      )

      # Render table with prepared data
      output$general_concepts_table <- DT::renderDT({
        dt <- datatable(
          general_concepts_display,
          filter = "top",
          options = list(
            pageLength = 15,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100), c("5", "10", "15", "20", "50", "100")),
            dom = "ltp",
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 0, visible = FALSE),
              list(targets = 1, width = "200px")
            )
          ),
          rownames = FALSE,
          selection = "single",
          colnames = c("ID", as.character(i18n$t("category")), as.character(i18n$t("subcategory")), as.character(i18n$t("general_concept")))
        )

        dt <- add_doubleclick_handler(dt, ns("view_mapped_concepts"))

        dt
      }, server = TRUE)
    }, ignoreNULL = FALSE)
    
    #### Concept Mappings Table Rendering ----
    observe_event(concept_mappings_table_trigger(), {
      # Check visibility first
      if (is.null(selected_general_concept_id())) return()
      if (is.null(data())) return()
      if (mapping_tab() != "edit_mappings") return()
      
      # Prepare data outside renderDT
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) {
        output$concept_mappings_table <- DT::renderDT({
          create_empty_datatable("OHDSI vocabularies not loaded. Please configure the ATHENA folder in Settings.")
        }, server = TRUE)
        return()
      }
      
      concept_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == selected_general_concept_id())
      
      if (!is.null(vocab_data) && nrow(concept_mappings) > 0) {
        concept_ids <- concept_mappings$omop_concept_id
        omop_concepts <- vocab_data$concept %>%
          dplyr::filter(concept_id %in% concept_ids) %>%
          dplyr::select(concept_id, concept_name, vocabulary_id, concept_code) %>%
          dplyr::collect()
        
        concept_mappings <- concept_mappings %>%
          dplyr::left_join(
            omop_concepts,
            by = c("omop_concept_id" = "concept_id")
          ) %>%
          dplyr::mutate(is_custom = FALSE)
      } else if (nrow(concept_mappings) > 0) {
        concept_mappings <- concept_mappings %>%
          dplyr::mutate(
            concept_name = NA_character_,
            vocabulary_id = NA_character_,
            concept_code = NA_character_,
            is_custom = FALSE
          )
      } else {
        concept_mappings <- data.frame(
          concept_name = character(),
          vocabulary_id = character(),
          concept_code = character(),
          omop_concept_id = integer(),
          omop_unit_concept_id = character(),
          is_custom = logical()
        )
      }

      custom_concepts_path <- get_csv_path("custom_concepts.csv")
      if (file.exists(custom_concepts_path)) {
        custom_concepts <- readr::read_csv(custom_concepts_path, show_col_types = FALSE) %>%
          dplyr::filter(general_concept_id == selected_general_concept_id()) %>%
          dplyr::select(
            custom_concept_id,
            concept_name,
            vocabulary_id,
            concept_code
          ) %>%
          dplyr::mutate(
            omop_concept_id = NA_integer_,
            omop_unit_concept_id = NA_character_,
            is_custom = TRUE
          )
      } else {
        custom_concepts <- data.frame(
          custom_concept_id = integer(),
          concept_name = character(),
          vocabulary_id = character(),
          concept_code = character(),
          omop_concept_id = integer(),
          omop_unit_concept_id = character(),
          is_custom = logical()
        )
      }

      if (nrow(concept_mappings) > 0) {
        omop_for_bind <- concept_mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, omop_unit_concept_id, is_custom)
      } else {
        omop_for_bind <- concept_mappings
      }

      all_concepts <- dplyr::bind_rows(omop_for_bind, custom_concepts)

      if (nrow(all_concepts) == 0) {
        output$concept_mappings_table <- DT::renderDT({
          create_empty_datatable("No mapped concepts found for this general concept.")
        }, server = TRUE)
        return()
      }

      mappings <- all_concepts %>%
        dplyr::select(
          concept_name,
          vocabulary_id,
          concept_code,
          omop_concept_id,
          omop_unit_concept_id,
          is_custom
        ) %>%
        dplyr::arrange(concept_name)

      # Store the sorted data for row selection lookups
      concept_mappings_table_data(mappings)

      # For display, convert omop_concept_id to character
      mappings_display <- mappings %>%
        dplyr::mutate(omop_concept_id = as.character(omop_concept_id))

      # Render table with prepared data
      output$concept_mappings_table <- DT::renderDT({
        dt <- datatable(
          mappings_display,
          options = list(
            pageLength = 15,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100), c("5", "10", "15", "20", "50", "100")),
            dom = "ltp",
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = c(4, 5), visible = FALSE)  # Hide omop_unit_concept_id and is_custom
            )
          ),
          rownames = FALSE,
          selection = "single",
          filter = "top",
          colnames = c(
            as.character(i18n$t("concept_name")),
            as.character(i18n$t("vocabulary")),
            as.character(i18n$t("code")),
            as.character(i18n$t("omop_id")),
            as.character(i18n$t("unit_id")),
            as.character(i18n$t("custom"))
          )
        )

        dt
      }, server = TRUE)
    })

    #### Concept Details Panel ----
    # Reactive to store selected source concept JSON data
    selected_source_json <- reactiveVal(NULL)
    selected_source_row <- reactiveVal(NULL)  # Store full row data for rows_count, patients_count
    detail_tab <- reactiveVal("summary")

    # Show/hide concept details panel based on row selection
    observe_event(input$source_concepts_table_rows_selected, {
      if (mapping_tab() != "edit_mappings") return()

      row_selected <- input$source_concepts_table_rows_selected

      if (is.null(row_selected) || length(row_selected) == 0) {
        shinyjs::hide("concept_details_panel")
        selected_source_json(NULL)
        return()
      }

      # Get the selected row data
      if (is.null(selected_alignment_id())) return()

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]
      mapping_dir <- get_app_dir("concept_mapping")
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      if (!file.exists(csv_path)) return()

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      if (row_selected > nrow(df)) return()

      # Store the full row data
      row_data <- df[row_selected, ]
      selected_source_row(row_data)

      # Check if json column exists
      if ("json" %in% colnames(df)) {
        json_str <- df$json[row_selected]
        if (!is.null(json_str) && !is.na(json_str) && json_str != "") {
          json_data <- tryCatch(
            jsonlite::fromJSON(json_str),
            error = function(e) NULL
          )
          selected_source_json(json_data)
          shinyjs::show("concept_details_panel")
        } else {
          selected_source_json(NULL)
          shinyjs::hide("concept_details_panel")
        }
      } else {
        selected_source_json(NULL)
        shinyjs::hide("concept_details_panel")
      }
    }, ignoreNULL = FALSE)

    # Handle tab selection
    observe_event(input$detail_tab_selected, {
      detail_tab(input$detail_tab_selected)
    })

    # Render concept details content based on selected tab
    output$concept_details_content <- renderUI({
      json_data <- selected_source_json()
      row_data <- selected_source_row()
      tab <- detail_tab()

      if (is.null(json_data)) {
        return(tags$div(
          style = "color: #999; font-style: italic;",
          "No JSON data available for this concept."
        ))
      }

      if (tab == "summary") {
        render_json_summary(json_data, row_data)
      } else if (tab == "distribution") {
        render_json_distribution(json_data)
      } else if (tab == "temporal") {
        render_json_temporal(json_data)
      } else if (tab == "units") {
        render_json_units(json_data)
      } else if (tab == "other") {
        render_source_other_columns(row_data, json_data)
      } else {
        tags$div("Unknown tab")
      }
    })

    # Helper function to render summary tab
    render_json_summary <- function(json_data, row_data = NULL) {
      left_items <- list()
      right_items <- list()

      # Left column: Metadata (rows, patients, unit, missing, frequency)

      # Rows count
      if (!is.null(row_data) && !is.null(row_data$rows_count) && !is.na(row_data$rows_count)) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            style = "margin-bottom: 6px;",
            tags$span(style = "font-weight: 600; color: #666;", "Rows:"),
            tags$span(class = "detail-value", format(row_data$rows_count, big.mark = " "))
          )
        ))
      }

      # Patients count
      if (!is.null(row_data) && !is.null(row_data$patients_count) && !is.na(row_data$patients_count)) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            style = "margin-bottom: 6px;",
            tags$span(style = "font-weight: 600; color: #666;", "Patients:"),
            tags$span(class = "detail-value", format(row_data$patients_count, big.mark = " "))
          )
        ))
      }

      # Unit info
      if (!is.null(json_data$unit) && !is.null(json_data$unit$name) && !is.na(json_data$unit$name)) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            style = "margin-bottom: 6px;",
            tags$span(style = "font-weight: 600; color: #666;", "Unit:"),
            tags$span(class = "detail-value", json_data$unit$name)
          )
        ))
      }

      # Missing rate
      if (!is.null(json_data$missing_rate)) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            style = "margin-bottom: 6px;",
            tags$span(style = "font-weight: 600; color: #666;", "Missing:"),
            tags$span(class = "detail-value", paste0(json_data$missing_rate, "%"))
          )
        ))
      }

      # Measurement frequency
      if (!is.null(json_data$measurement_frequency)) {
        mf <- json_data$measurement_frequency
        if (!is.null(mf$typical_interval) && !is.na(mf$typical_interval)) {
          left_items <- c(left_items, list(
            tags$div(
              class = "detail-item",
              style = "margin-bottom: 6px;",
              tags$span(style = "font-weight: 600; color: #666;", "Interval:"),
              tags$span(class = "detail-value", gsub("_", " ", mf$typical_interval))
            )
          ))
        }
        if (!is.null(mf$average_per_patient_per_day) && !is.na(mf$average_per_patient_per_day)) {
          left_items <- c(left_items, list(
            tags$div(
              class = "detail-item",
              style = "margin-bottom: 6px;",
              tags$span(style = "font-weight: 600; color: #666;", "Per day:"),
              tags$span(class = "detail-value", round(mf$average_per_patient_per_day, 1))
            )
          ))
        }
      }

      # Right column: Numeric data summary (mean, median, sd, range)
      if (!is.null(json_data$numeric_data)) {
        nd <- json_data$numeric_data
        if (!is.null(nd$mean) && !is.na(nd$mean)) {
          right_items <- c(right_items, list(
            tags$div(
              class = "detail-item",
              style = "margin-bottom: 6px;",
              tags$span(style = "font-weight: 600; color: #666;", "Mean:"),
              tags$span(class = "detail-value", round(nd$mean, 2))
            ),
            tags$div(
              class = "detail-item",
              style = "margin-bottom: 6px;",
              tags$span(style = "font-weight: 600; color: #666;", "Median:"),
              tags$span(class = "detail-value", round(nd$median, 2))
            ),
            tags$div(
              class = "detail-item",
              style = "margin-bottom: 6px;",
              tags$span(style = "font-weight: 600; color: #666;", "SD:"),
              tags$span(class = "detail-value", round(nd$sd, 2))
            ),
            tags$div(
              class = "detail-item",
              style = "margin-bottom: 6px;",
              tags$span(style = "font-weight: 600; color: #666;", "Range:"),
              tags$span(class = "detail-value", paste(nd$min, "-", nd$max))
            )
          ))
        }
      }

      if (length(left_items) == 0 && length(right_items) == 0) {
        return(tags$div(
          style = "color: #999; font-style: italic;",
          "No summary data available."
        ))
      }

      tags$div(
        style = "display: flex; gap: 30px;",
        tags$div(
          style = "flex: 1;",
          left_items
        ),
        tags$div(
          style = "flex: 1;",
          right_items
        )
      )
    }

    # Helper function to render distribution tab (boxplot visualization)
    render_json_distribution <- function(json_data) {
      if (!is.null(json_data$numeric_data)) {
        nd <- json_data$numeric_data
        if (!is.null(nd$p25) && !is.na(nd$p25) && !is.null(nd$p75) && !is.na(nd$p75)) {
          # Create data for ggplot boxplot using quantiles
          min_val <- if (!is.null(nd$min) && !is.na(nd$min)) nd$min else nd$p5
          max_val <- if (!is.null(nd$max) && !is.na(nd$max)) nd$max else nd$p95
          median_val <- if (!is.null(nd$median) && !is.na(nd$median)) nd$median else (nd$p25 + nd$p75) / 2
          lower_val <- if (!is.null(nd$p5) && !is.na(nd$p5)) nd$p5 else min_val
          upper_val <- if (!is.null(nd$p95) && !is.na(nd$p95)) nd$p95 else max_val

          # Create horizontal boxplot with ggplot2
          p <- ggplot2::ggplot() +
            ggplot2::geom_boxplot(
              ggplot2::aes(x = "", ymin = lower_val, lower = nd$p25, middle = median_val,
                           upper = nd$p75, ymax = upper_val),
              stat = "identity",
              fill = "#0f60af",
              color = "#333",
              width = 0.5,
              fatten = 0  # Hide default median line
            ) +
            # Add white median line
            ggplot2::geom_segment(
              ggplot2::aes(x = 0.75, xend = 1.25, y = median_val, yend = median_val),
              color = "white",
              linewidth = 1
            ) +
            ggplot2::coord_flip() +
            ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.02))) +
            ggplot2::labs(x = NULL, y = NULL) +
            ggplot2::theme_minimal(base_size = 11) +
            ggplot2::theme(
              panel.grid.major.y = ggplot2::element_blank(),
              panel.grid.minor = ggplot2::element_blank(),
              axis.text.y = ggplot2::element_blank(),
              axis.text.x = ggplot2::element_text(size = 9),
              plot.margin = ggplot2::margin(5, 10, 5, 10)
            )

          # Check if histogram data exists - render as line plot
          histogram_plot <- NULL
          if (!is.null(json_data$histogram) && length(json_data$histogram) > 0) {
            hist_df <- as.data.frame(json_data$histogram)
            # Support both formats: new "x" format and legacy "bin_start/bin_end" format
            if (nrow(hist_df) > 0 && "count" %in% colnames(hist_df)) {
              if ("x" %in% colnames(hist_df)) {
                hist_df$bin_mid <- hist_df$x
              } else if ("bin_start" %in% colnames(hist_df) && "bin_end" %in% colnames(hist_df)) {
                hist_df$bin_mid <- (hist_df$bin_start + hist_df$bin_end) / 2
              } else {
                hist_df <- NULL
              }
            } else {
              hist_df <- NULL
            }

            if (!is.null(hist_df) && nrow(hist_df) > 0) {
              # Calculate percentages
              total_count <- sum(hist_df$count, na.rm = TRUE)
              hist_df$percentage <- if (total_count > 0) hist_df$count / total_count * 100 else 0

              p_hist <- ggplot2::ggplot(hist_df, ggplot2::aes(x = bin_mid, y = percentage)) +
                ggplot2::geom_area(fill = "#0f60af", alpha = 0.3) +
                ggplot2::geom_line(color = "#0f60af", linewidth = 1.2) +
                ggplot2::geom_point(color = "#0f60af", size = 2) +
                ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.02))) +
                ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.05)), labels = function(x) paste0(x, "%")) +
                ggplot2::labs(x = NULL, y = NULL) +
                ggplot2::theme_minimal(base_size = 10) +
                ggplot2::theme(
                  panel.grid.minor = ggplot2::element_blank(),
                  panel.grid.major.x = ggplot2::element_blank(),
                  axis.text = ggplot2::element_text(size = 8),
                  plot.margin = ggplot2::margin(5, 10, 5, 10)
                )

              histogram_plot <- renderPlot({ p_hist }, height = 120, width = "auto")
            }
          }

          return(tags$div(
            tags$div(
              style = "display: flex; gap: 20px;",
              # Left: statistics
              tags$div(
                style = "flex: 1;",
                tags$div(
                  style = "display: grid; grid-template-columns: 70px 1fr; gap: 4px; font-size: 12px;",
                  tags$span(style = "font-weight: 600; color: #666;", "Min:"), tags$span(round(min_val, 2)),
                  tags$span(style = "font-weight: 600; color: #666;", "P5:"), tags$span(if (!is.null(nd$p5)) round(nd$p5, 2) else "-"),
                  tags$span(style = "font-weight: 600; color: #666;", "P25:"), tags$span(round(nd$p25, 2)),
                  tags$span(style = "font-weight: 600; color: #0f60af;", "Median:"), tags$span(style = "font-weight: 600;", round(median_val, 2)),
                  tags$span(style = "font-weight: 600; color: #666;", "P75:"), tags$span(round(nd$p75, 2)),
                  tags$span(style = "font-weight: 600; color: #666;", "P95:"), tags$span(if (!is.null(nd$p95)) round(nd$p95, 2) else "-"),
                  tags$span(style = "font-weight: 600; color: #666;", "Max:"), tags$span(round(max_val, 2))
                )
              ),
              # Right: boxplot
              tags$div(
                style = "flex: 1.5;",
                renderPlot({ p }, height = 80, width = "auto")
              )
            ),
            # Histogram below
            if (!is.null(histogram_plot)) {
              tags$div(
                style = "margin-top: 10px;",
                histogram_plot
              )
            }
          ))
        }
      }

      # Categorical distribution
      if (!is.null(json_data$categorical_data) && length(json_data$categorical_data) > 0) {
        cat_df <- as.data.frame(json_data$categorical_data)
        if (nrow(cat_df) > 0 && "value" %in% colnames(cat_df) && "percentage" %in% colnames(cat_df)) {
          rows <- lapply(seq_len(nrow(cat_df)), function(i) {
            tags$div(
              style = "display: flex; align-items: center; margin-bottom: 5px;",
              tags$span(style = "width: 120px; font-size: 13px;", cat_df$value[i]),
              tags$div(
                style = sprintf("width: %s%%; background: #0f60af; height: 18px; border-radius: 3px; margin-right: 8px;", cat_df$percentage[i])
              ),
              tags$span(style = "font-size: 12px; color: #666;", paste0(cat_df$percentage[i], "%"))
            )
          })
          return(tags$div(
            tags$h5(style = "margin-bottom: 10px;", "Categorical Distribution"),
            rows
          ))
        }
      }

      tags$div(
        style = "color: #999; font-style: italic;",
        "No distribution data available."
      )
    }

    # Helper function to render temporal tab
    render_json_temporal <- function(json_data) {
      items <- list()

      # Temporal coverage (start/end dates)
      # Check both temporal_coverage (old format) and temporal_distribution (new format)
      tc <- NULL
      if (!is.null(json_data$temporal_coverage)) {
        tc <- json_data$temporal_coverage
      } else if (!is.null(json_data$temporal_distribution) &&
                 !is.null(json_data$temporal_distribution$start_date)) {
        tc <- json_data$temporal_distribution
      }

      if (!is.null(tc) && !is.null(tc$start_date)) {
        items <- c(items, list(
          tags$div(
            style = "display: flex; gap: 20px; margin-bottom: 15px;",
            tags$div(
              class = "detail-item",
              tags$span(class = "detail-label", "Start:"),
              tags$span(class = "detail-value", tc$start_date)
            ),
            tags$div(
              class = "detail-item",
              tags$span(class = "detail-label", "End:"),
              tags$span(class = "detail-value", tc$end_date)
            )
          )
        ))
      }

      # Temporal distribution by year (or other interval) - ggplot bar chart
      if (!is.null(json_data$temporal_distribution) &&
          length(json_data$temporal_distribution) > 0) {
        # Handle nested structure with by_year array
        td <- json_data$temporal_distribution
        if (!is.null(td$by_year) && length(td$by_year) > 0) {
          year_df <- as.data.frame(td$by_year)
        } else if (is.list(td) && length(td) > 0 && !is.null(td[[1]]$year)) {
          # Fallback: direct array format
          year_df <- as.data.frame(td)
        } else {
          year_df <- data.frame()
        }

        # Determine x-axis column (year, month, quarter, etc.)
        x_col <- NULL
        x_label <- NULL
        if ("year" %in% colnames(year_df)) {
          x_col <- "year"
          x_label <- "Year"
        } else if ("month" %in% colnames(year_df)) {
          x_col <- "month"
          x_label <- "Month"
        } else if ("quarter" %in% colnames(year_df)) {
          x_col <- "quarter"
          x_label <- "Quarter"
        }

        if (!is.null(x_col) && nrow(year_df) > 0 &&
            "percentage" %in% colnames(year_df)) {
          year_df$x_val <- as.factor(year_df[[x_col]])

          p <- ggplot2::ggplot(year_df, ggplot2::aes(x = x_val, y = percentage)) +
            ggplot2::geom_col(fill = "#0f60af", width = 0.7) +
            ggplot2::labs(x = x_label, y = "%") +
            ggplot2::theme_minimal(base_size = 11) +
            ggplot2::theme(
              panel.grid.major.x = ggplot2::element_blank(),
              panel.grid.minor = ggplot2::element_blank(),
              axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 9),
              axis.text.y = ggplot2::element_text(size = 9),
              axis.title.y = ggplot2::element_text(size = 10),
              plot.margin = ggplot2::margin(5, 10, 5, 5)
            )

          items <- c(items, list(
            renderPlot({ p }, height = 150, width = "auto")
          ))
        }
      }

      if (length(items) == 0) {
        return(tags$div(
          style = "color: #999; font-style: italic;",
          "No temporal data available."
        ))
      }

      tags$div(items)
    }

    # Helper function to render units tab
    render_json_units <- function(json_data) {
      # Distribution by hospital unit - horizontal bar chart
      if (!is.null(json_data$hospital_units) && length(json_data$hospital_units) > 0) {
        unit_df <- as.data.frame(json_data$hospital_units)
        if (nrow(unit_df) > 0 && "unit" %in% colnames(unit_df) && "percentage" %in% colnames(unit_df)) {
          # Order by percentage descending
          unit_df <- unit_df[order(-unit_df$percentage), ]
          # Truncate names if too long
          unit_df$unit_label <- ifelse(nchar(unit_df$unit) > 20,
            paste0(substr(unit_df$unit, 1, 18), "..."),
            unit_df$unit)
          unit_df$unit_label <- factor(unit_df$unit_label, levels = rev(unit_df$unit_label))

          # Calculate height based on number of units
          plot_height <- max(100, min(250, nrow(unit_df) * 25))

          p <- ggplot2::ggplot(unit_df, ggplot2::aes(x = unit_label, y = percentage)) +
            ggplot2::geom_col(fill = "#0f60af", width = 0.7) +
            ggplot2::coord_flip() +
            ggplot2::labs(x = NULL, y = "%") +
            ggplot2::theme_minimal(base_size = 11) +
            ggplot2::theme(
              panel.grid.major.y = ggplot2::element_blank(),
              panel.grid.minor = ggplot2::element_blank(),
              axis.text.x = ggplot2::element_text(size = 9),
              axis.text.y = ggplot2::element_text(size = 9),
              axis.title.x = ggplot2::element_text(size = 10),
              plot.margin = ggplot2::margin(5, 10, 5, 5)
            )

          return(tags$div(
            renderPlot({ p }, height = plot_height, width = "auto")
          ))
        }
      }

      tags$div(
        style = "color: #999; font-style: italic;",
        "No unit distribution data available."
      )
    }

    # Helper function to render additional columns from source concept
    render_source_other_columns <- function(row_data, json_data = NULL) {
      # Standard columns that are not displayed in the "Other" tab
      standard_cols <- c(
        "mapping_id", "vocabulary_id", "concept_code", "concept_name", "json"
      )

      # Standard JSON fields that are displayed in other tabs
      standard_json_fields <- c(
        "data_types", "numeric_data", "histogram", "categorical_data",
        "measurement_frequency", "missing_rate", "temporal_distribution",
        "hospital_units", "unit"
      )

      if (is.null(row_data)) {
        return(tags$div(
          style = "color: #999; font-style: italic;",
          i18n$t("no_data_available")
        ))
      }

      items <- list()

      # Get additional columns from row_data
      all_cols <- colnames(row_data)
      additional_cols <- setdiff(all_cols, standard_cols)

      # Build display items for each additional column
      for (col in additional_cols) {
        value <- row_data[[col]]
        if (is.null(value) || is.na(value) || value == "") {
          display_value <- "/"
        } else {
          display_value <- as.character(value)
        }

        items <- c(items, list(tags$div(
          class = "detail-item",
          style = "margin-bottom: 8px; display: flex; gap: 8px;",
          tags$span(
            style = "font-weight: 600; color: #666; min-width: 120px;",
            paste0(col, ":")
          ),
          tags$span(
            class = "detail-value",
            style = "word-break: break-word;",
            display_value
          )
        )))
      }

      # Get additional fields from JSON
      if (!is.null(json_data) && is.list(json_data)) {
        json_fields <- names(json_data)
        additional_json_fields <- setdiff(json_fields, standard_json_fields)

        for (field in additional_json_fields) {
          value <- json_data[[field]]
          if (is.null(value) || (is.atomic(value) && is.na(value))) {
            display_value <- "/"
          } else if (is.list(value) || is.vector(value) && length(value) > 1) {
            display_value <- tryCatch({
              jsonlite::toJSON(value, auto_unbox = TRUE)
            }, error = function(e) as.character(value))
          } else {
            display_value <- as.character(value)
          }

          items <- c(items, list(tags$div(
            class = "detail-item",
            style = "margin-bottom: 8px; display: flex; gap: 8px;",
            tags$span(
              style = "font-weight: 600; color: #666; min-width: 120px;",
              paste0(field, " (JSON):")
            ),
            tags$span(
              class = "detail-value",
              style = "word-break: break-word;",
              display_value
            )
          )))
        }
      }

      if (length(items) == 0) {
        return(tags$div(
          style = "color: #999; font-style: italic;",
          i18n$t("no_additional_columns")
        ))
      }

      tags$div(
        style = "padding: 5px 0;",
        items
      )
    }

    # Helper function to render JSON tutorial
    render_json_tutorial <- function(language = "en") {
      if (language == "fr") {
        tutorial_md <- '
## Guide de structure JSON

Ce JSON décrit les statistiques d\'un concept source importé.

### Structure principale

```json
{
  "data_types": "numeric",
  "numeric_data": { ... },
  "histogram": [ ... ],
  "measurement_frequency": { ... },
  "missing_rate": 5.2,
  "temporal_distribution": { ... },
  "hospital_units": [ ... ]
}
```

### Type de données (`data_types`)

Indique le(s) type(s) de données. Peut être une valeur unique ou un tableau.

```json
{
  "data_types": "numeric"
}
```

Ou plusieurs types :

```json
{
  "data_types": ["numeric", "categorical"]
}
```

Valeurs possibles : `"numeric"`, `"categorical"`

### Données numériques (`numeric_data`)

Statistiques descriptives pour les variables numériques.

```json
{
  "numeric_data": {
    "mean": 120.5,
    "sd": 15.3,
    "min": 60,
    "max": 250,
    "p5": 95,
    "p25": 110,
    "median": 118,
    "p75": 130,
    "p95": 150
  }
}
```

| Champ | Description |
|-------|-------------|
| `mean` | Moyenne |
| `sd` | Écart-type |
| `min`, `max` | Valeurs extrêmes |
| `p5`, `p25`, `median`, `p75`, `p95` | Percentiles |

### Histogramme (`histogram`)

Distribution des valeurs (pour données numériques). Chaque élément contient `x` (valeur) et `count` (nombre d\'occurrences).

```json
{
  "histogram": [
    {"x": 60, "count": 150},
    {"x": 80, "count": 2500},
    {"x": 100, "count": 5000},
    {"x": 120, "count": 4200},
    {"x": 140, "count": 1800},
    {"x": 160, "count": 600},
    {"x": 180, "count": 200}
  ]
}
```

### Données catégorielles (`categorical_data`)

Distribution des catégories (pour variables catégorielles).

```json
{
  "data_types": "categorical",
  "categorical_data": [
    {"category": "Normal", "count": 45000, "percentage": 52.3},
    {"category": "Low", "count": 18500, "percentage": 21.5},
    {"category": "High", "count": 15200, "percentage": 17.7},
    {"category": "Critical", "count": 7300, "percentage": 8.5}
  ]
}
```

### Fréquence de mesure (`measurement_frequency`)

Intervalle typique entre les mesures.

```json
{
  "measurement_frequency": {
    "typical_interval": "4 hours",
    "min_interval": "1 hour",
    "max_interval": "24 hours"
  }
}
```

### Taux de données manquantes (`missing_rate`)

Pourcentage de valeurs manquantes.

```json
{
  "missing_rate": 5.2
}
```

### Distribution temporelle (`temporal_distribution`)

Couverture et répartition des données par année.

```json
{
  "temporal_distribution": {
    "start_date": "2018-01-15",
    "end_date": "2024-06-30",
    "by_year": [
      {"year": 2018, "percentage": 8.5},
      {"year": 2019, "percentage": 12.3},
      {"year": 2020, "percentage": 15.1},
      {"year": 2021, "percentage": 18.7},
      {"year": 2022, "percentage": 20.4},
      {"year": 2023, "percentage": 16.8},
      {"year": 2024, "percentage": 8.2}
    ]
  }
}
```

### Distribution par service (`hospital_units`)

Répartition des données par service hospitalier.

```json
{
  "hospital_units": [
    {"unit": "MICU", "percentage": 22.5},
    {"unit": "SICU", "percentage": 18.3},
    {"unit": "CCU", "percentage": 15.7},
    {"unit": "NICU", "percentage": 12.1},
    {"unit": "PICU", "percentage": 8.9},
    {"unit": "Neuro ICU", "percentage": 7.2},
    {"unit": "Burn ICU", "percentage": 5.4},
    {"unit": "Cardiac ICU", "percentage": 4.8},
    {"unit": "Trauma ICU", "percentage": 3.2},
    {"unit": "Step-down", "percentage": 1.9}
  ]
}
```

### Exemple complet (numérique)

```json
{
  "data_types": "numeric",
  "numeric_data": {
    "mean": 120.5,
    "sd": 15.3,
    "min": 60,
    "max": 250,
    "p5": 95,
    "p25": 110,
    "median": 118,
    "p75": 130,
    "p95": 150
  },
  "histogram": [
    {"x": 60, "count": 150},
    {"x": 80, "count": 2500},
    {"x": 100, "count": 5000},
    {"x": 120, "count": 4200},
    {"x": 140, "count": 1800}
  ],
  "measurement_frequency": {
    "typical_interval": "4 hours"
  },
  "missing_data": {
    "missing_rate": 5.2
  },
  "temporal_distribution": {
    "start_date": "2018-01-15",
    "end_date": "2024-06-30",
    "by_year": [
      {"year": 2020, "percentage": 25.1},
      {"year": 2021, "percentage": 28.7},
      {"year": 2022, "percentage": 30.4},
      {"year": 2023, "percentage": 15.8}
    ]
  },
  "hospital_units": [
    {"unit": "MICU", "percentage": 22.5},
    {"unit": "SICU", "percentage": 18.3},
    {"unit": "CCU", "percentage": 15.7},
    {"unit": "NICU", "percentage": 12.1},
    {"unit": "PICU", "percentage": 8.9},
    {"unit": "Neuro ICU", "percentage": 7.2},
    {"unit": "Burn ICU", "percentage": 5.4},
    {"unit": "Cardiac ICU", "percentage": 4.8},
    {"unit": "Trauma ICU", "percentage": 3.2},
    {"unit": "Step-down", "percentage": 1.9}
  ]
}
```
'
      } else {
        tutorial_md <- '
## JSON Structure Guide

This JSON describes statistics for an imported source concept.

### Main Structure

```json
{
  "data_types": "numeric",
  "numeric_data": { ... },
  "histogram": [ ... ],
  "measurement_frequency": { ... },
  "missing_rate": 5.2,
  "temporal_distribution": { ... },
  "hospital_units": [ ... ]
}
```

### Data Type (`data_types`)

Indicates the data type(s). Can be a single value or an array.

```json
{
  "data_types": "numeric"
}
```

Or multiple types:

```json
{
  "data_types": ["numeric", "categorical"]
}
```

Possible values: `"numeric"`, `"categorical"`

### Numeric Data (`numeric_data`)

Descriptive statistics for numeric variables.

```json
{
  "numeric_data": {
    "mean": 120.5,
    "sd": 15.3,
    "min": 60,
    "max": 250,
    "p5": 95,
    "p25": 110,
    "median": 118,
    "p75": 130,
    "p95": 150
  }
}
```

| Field | Description |
|-------|-------------|
| `mean` | Mean value |
| `sd` | Standard deviation |
| `min`, `max` | Extreme values |
| `p5`, `p25`, `median`, `p75`, `p95` | Percentiles |

### Histogram (`histogram`)

Value distribution (for numeric data). Each element contains `x` (value) and `count` (number of occurrences).

```json
{
  "histogram": [
    {"x": 60, "count": 150},
    {"x": 80, "count": 2500},
    {"x": 100, "count": 5000},
    {"x": 120, "count": 4200},
    {"x": 140, "count": 1800},
    {"x": 160, "count": 600},
    {"x": 180, "count": 200}
  ]
}
```

### Categorical Data (`categorical_data`)

Category distribution (for categorical variables).

```json
{
  "data_types": "categorical",
  "categorical_data": [
    {"category": "Normal", "count": 45000, "percentage": 52.3},
    {"category": "Low", "count": 18500, "percentage": 21.5},
    {"category": "High", "count": 15200, "percentage": 17.7},
    {"category": "Critical", "count": 7300, "percentage": 8.5}
  ]
}
```

### Measurement Frequency (`measurement_frequency`)

Typical interval between measurements.

```json
{
  "measurement_frequency": {
    "typical_interval": "4 hours",
    "min_interval": "1 hour",
    "max_interval": "24 hours"
  }
}
```

### Missing Rate (`missing_rate`)

Percentage of missing values.

```json
{
  "missing_rate": 5.2
}
```

### Temporal Distribution (`temporal_distribution`)

Data coverage and distribution by year.

```json
{
  "temporal_distribution": {
    "start_date": "2018-01-15",
    "end_date": "2024-06-30",
    "by_year": [
      {"year": 2018, "percentage": 8.5},
      {"year": 2019, "percentage": 12.3},
      {"year": 2020, "percentage": 15.1},
      {"year": 2021, "percentage": 18.7},
      {"year": 2022, "percentage": 20.4},
      {"year": 2023, "percentage": 16.8},
      {"year": 2024, "percentage": 8.2}
    ]
  }
}
```

### Hospital Units Distribution (`hospital_units`)

Data distribution by hospital unit/ward.

```json
{
  "hospital_units": [
    {"unit": "MICU", "percentage": 22.5},
    {"unit": "SICU", "percentage": 18.3},
    {"unit": "CCU", "percentage": 15.7},
    {"unit": "NICU", "percentage": 12.1},
    {"unit": "PICU", "percentage": 8.9},
    {"unit": "Neuro ICU", "percentage": 7.2},
    {"unit": "Burn ICU", "percentage": 5.4},
    {"unit": "Cardiac ICU", "percentage": 4.8},
    {"unit": "Trauma ICU", "percentage": 3.2},
    {"unit": "Step-down", "percentage": 1.9}
  ]
}
```

### Complete Example (numeric)

```json
{
  "data_types": "numeric",
  "numeric_data": {
    "mean": 120.5,
    "sd": 15.3,
    "min": 60,
    "max": 250,
    "p5": 95,
    "p25": 110,
    "median": 118,
    "p75": 130,
    "p95": 150
  },
  "histogram": [
    {"x": 60, "count": 150},
    {"x": 80, "count": 2500},
    {"x": 100, "count": 5000},
    {"x": 120, "count": 4200},
    {"x": 140, "count": 1800}
  ],
  "measurement_frequency": {
    "typical_interval": "4 hours"
  },
  "missing_rate": 5.2,
  "temporal_distribution": {
    "start_date": "2018-01-15",
    "end_date": "2024-06-30",
    "by_year": [
      {"year": 2020, "percentage": 25.1},
      {"year": 2021, "percentage": 28.7},
      {"year": 2022, "percentage": 30.4},
      {"year": 2023, "percentage": 15.8}
    ]
  },
  "hospital_units": [
    {"unit": "MICU", "percentage": 22.5},
    {"unit": "SICU", "percentage": 18.3},
    {"unit": "CCU", "percentage": 15.7},
    {"unit": "NICU", "percentage": 12.1},
    {"unit": "PICU", "percentage": 8.9},
    {"unit": "Neuro ICU", "percentage": 7.2},
    {"unit": "Burn ICU", "percentage": 5.4},
    {"unit": "Cardiac ICU", "percentage": 4.8},
    {"unit": "Trauma ICU", "percentage": 3.2},
    {"unit": "Step-down", "percentage": 1.9}
  ]
}
```
'
      }

      # Render markdown to HTML
      tags$div(
        class = "markdown-content",
        style = "font-size: 13px; line-height: 1.6;",
        HTML(markdown::markdownToHTML(
          text = tutorial_md,
          fragment.only = TRUE,
          options = c("fragment_only", "base64_images", "smartypants")
        ))
      )
    }

    #### Target Concept Details Panel ----
    # Reactive to store the concept mappings table data (sorted as displayed)
    concept_mappings_table_data <- reactiveVal(NULL)

    # Reactive to store selected target concept data
    selected_target_concept_id <- reactiveVal(NULL)
    selected_target_json <- reactiveVal(NULL)
    selected_target_mapping <- reactiveVal(NULL)
    target_detail_tab <- reactiveVal("statistical_summary")  # "comments" or "statistical_summary"
    target_stats_sub_tab <- reactiveVal("summary")  # "summary" or "distribution"
    target_selected_profile <- reactiveVal(NULL)  # Selected profile name

    # Show/hide target concept details panel based on concept mapping selection (specific/detailed concept)
    observe_event(input$concept_mappings_table_rows_selected, {
      if (mapping_tab() != "edit_mappings") return()

      row_selected <- input$concept_mappings_table_rows_selected

      if (is.null(row_selected) || length(row_selected) == 0) {
        shinyjs::hide("target_concept_details_panel")
        selected_target_concept_id(NULL)
        selected_target_json(NULL)
        selected_target_mapping(NULL)
        return()
      }

      # Get selected concept mapping from stored table data (sorted as displayed)
      if (is.null(data())) return()
      if (is.null(selected_general_concept_id())) return()

      # Use the stored table data which matches the displayed order
      mappings_data <- concept_mappings_table_data()

      if (is.null(mappings_data) || nrow(mappings_data) == 0) return()
      if (row_selected > nrow(mappings_data)) return()

      selected_row <- mappings_data[row_selected, ]
      selected_target_mapping(selected_row)

      # Get the general concept info for this mapping
      gc_data <- data()$general_concepts
      if (is.null(gc_data) || nrow(gc_data) == 0) return()

      selected_gc <- gc_data %>%
        dplyr::filter(general_concept_id == selected_general_concept_id())

      if (nrow(selected_gc) == 0) return()

      selected_target_concept_id(selected_gc$general_concept_id[1])

      # Create JSON-like data from general concept info for visualization
      # Only generalizable fields are kept (no unit - comes from DuckDB, no temporal/hospital distributions)
      target_json <- list(
        data_types = NULL,
        numeric_data = NULL,
        histogram = NULL,
        categorical_data = NULL,
        measurement_frequency = NULL,
        missing_rate = NULL
      )

      # If the general concept has a statistical_summary JSON, parse it
      if ("statistical_summary" %in% names(selected_gc) && !is.null(selected_gc$statistical_summary[1]) && !is.na(selected_gc$statistical_summary[1]) && selected_gc$statistical_summary[1] != "") {
        target_json <- tryCatch(
          jsonlite::fromJSON(selected_gc$statistical_summary[1]),
          error = function(e) target_json
        )
      }

      selected_target_json(target_json)
      shinyjs::show("target_concept_details_panel")
    }, ignoreNULL = FALSE)

    # Handle target tab selection
    observe_event(input$target_detail_tab_selected, {
      target_detail_tab(input$target_detail_tab_selected)
    })

    # Handle sub-tab selection for statistical summary
    observe_event(input$target_stats_sub_tab_click, {
      new_tab <- input$target_stats_sub_tab_click
      if (!is.null(new_tab) && new_tab %in% c("summary", "distribution")) {
        target_stats_sub_tab(new_tab)
      }
    }, ignoreInit = TRUE)

    # Handle profile selection for statistical summary
    observe_event(input$target_profile_change, {
      new_profile <- input$target_profile_change
      if (!is.null(new_profile)) {
        target_selected_profile(new_profile)
      }
    }, ignoreInit = TRUE)

    # Render target concept details content based on selected tab
    output$target_concept_details_content <- renderUI({
      json_data <- selected_target_json()
      concept_id <- selected_target_concept_id()
      tab <- target_detail_tab()
      sub_tab <- target_stats_sub_tab()
      current_profile <- target_selected_profile()

      if (is.null(concept_id)) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          "Select a general concept to see target details."
        ))
      }

      if (tab == "comments") {
        # Display comments for the selected general concept
        render_target_comments(concept_id)
      } else if (tab == "statistical_summary") {
        # Statistical Summary tab with sub-tabs and profile dropdown
        ns <- session$ns

        # Get profile names from JSON
        profile_names <- get_profile_names(json_data)

        # Set default profile if not set
        if (is.null(current_profile) || !current_profile %in% profile_names) {
          current_profile <- get_default_profile_name(json_data)
          target_selected_profile(current_profile)
        }

        # Get profile data for selected profile
        profile_data <- get_profile_data(json_data, current_profile)

        if (is.null(profile_data) || (is.null(profile_data$numeric_data) && is.null(profile_data$categorical_data))) {
          return(tags$div(
            style = "color: #999; font-style: italic; padding: 15px;",
            "No statistical data available for this concept."
          ))
        }

        tags$div(
          style = "height: 100%; display: flex; flex-direction: column;",
          # Header with sub-tabs (left) and profile dropdown (right)
          tags$div(
            style = "display: flex; justify-content: space-between; align-items: center; padding: 8px 10px; border-bottom: 1px solid #eee;",
            # Sub-tabs (Summary / Distribution) - top-left
            tags$div(
              class = "section-tabs",
              style = "position: static; transform: none; display: flex; gap: 5px;",
              tags$button(
                class = if (sub_tab == "summary") "tab-btn tab-btn-active" else "tab-btn",
                onclick = sprintf("Shiny.setInputValue('%s', 'summary', {priority: 'event'})", ns("target_stats_sub_tab_click")),
                "Summary"
              ),
              tags$button(
                class = if (sub_tab == "distribution") "tab-btn tab-btn-active" else "tab-btn",
                onclick = sprintf("Shiny.setInputValue('%s', 'distribution', {priority: 'event'})", ns("target_stats_sub_tab_click")),
                "Distribution"
              )
            ),
            # Profile dropdown (right) - only show if multiple profiles
            if (length(profile_names) > 1) {
              tags$div(
                style = "display: flex; align-items: center; gap: 8px;",
                tags$span(style = "font-size: 11px; color: #666;", paste0(i18n$t("profile"), " :")),
                tags$select(
                  id = ns("target_profile_select"),
                  style = "font-size: 11px; padding: 2px 6px; border: 1px solid #ccc; border-radius: 4px;",
                  onchange = sprintf("Shiny.setInputValue('%s', this.value, {priority: 'event'})", ns("target_profile_change")),
                  lapply(profile_names, function(pn) {
                    is_selected <- !is.na(pn) && !is.na(current_profile) && pn == current_profile
                    tags$option(value = pn, selected = if (is_selected) "selected" else NULL, pn)
                  })
                )
              )
            }
          ),
          # Content area
          tags$div(
            style = "flex: 1; overflow-y: auto; padding: 10px;",
            if (sub_tab == "summary") {
              render_target_summary(profile_data, concept_id)
            } else {
              render_target_distribution(profile_data)
            }
          )
        )
      } else {
        tags$div("Unknown tab")
      }
    })

    # Helper function to render comments with fullscreen button
    # Factorized for use in both Edit Mappings and Evaluate Mappings tabs
    render_comments_panel <- function(concept_id, expand_button_id) {
      if (is.null(data())) return(tags$div(style = "color: #999;", "No data available."))

      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
        tags$div(
          class = "comments-container",
          style = "background: #ffffff; border: 1px solid #ccc; border-radius: 6px; height: 100%; overflow-y: auto; box-sizing: border-box; position: relative;",
          tags$div(
            style = "position: sticky; top: -1px; left: -1px; z-index: 100; height: 0;",
            actionButton(
              session$ns(expand_button_id),
              label = NULL,
              icon = icon("expand"),
              class = "btn-icon-only comments-expand-btn",
              style = "background: rgba(255, 255, 255, 0.95); border: none; border-right: 1px solid #ccc; border-bottom: 1px solid #ccc; color: #0f60af; padding: 4px 7px; cursor: pointer; border-radius: 5px 0 0 0; font-size: 12px;",
              `data-tooltip` = "View in fullscreen"
            )
          ),
          tags$div(
            class = "markdown-content",
            style = "padding-left: 30px;",
            shiny::markdown(concept_info$comments[1])
          )
        )
      } else {
        tags$div(
          style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic; height: 100%; overflow-y: auto; box-sizing: border-box;",
          "No comments available for this concept."
        )
      }
    }

    # Wrapper for Edit Mappings tab
    render_target_comments <- function(concept_id) {
      render_comments_panel(concept_id, "expand_target_comments")
    }

    # Handle expand comments button for target
    observe_event(input$expand_target_comments, {
      shinyjs::show("target_comments_fullscreen_modal")
    })

    # Handle close fullscreen comments modal
    observe_event(input$close_target_comments_fullscreen, {
      shinyjs::hide("target_comments_fullscreen_modal")
    })

    # Render fullscreen comments content
    output$target_comments_fullscreen_content <- renderUI({
      concept_id <- selected_target_concept_id()
      if (is.null(concept_id)) return(NULL)
      if (is.null(data())) return(NULL)

      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
        tags$div(
          style = "height: 100%; overflow-y: auto; padding: 20px;",
          tags$div(
            class = "markdown-content",
            shiny::markdown(concept_info$comments[1])
          )
        )
      } else {
        tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No comments available for this concept."
        )
      }
    })

    # Handle expand eval comments button
    observe_event(input$expand_eval_comments, {
      shinyjs::show("eval_comments_fullscreen_modal")
    })

    # Handle close eval fullscreen comments modal
    observe_event(input$close_eval_comments_fullscreen, {
      shinyjs::hide("eval_comments_fullscreen_modal")
    })

    # Render eval fullscreen comments content
    output$eval_comments_fullscreen_content <- renderUI({
      concept_id <- eval_target_concept_id()
      if (is.null(concept_id)) return(NULL)
      if (is.null(data())) return(NULL)

      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
        tags$div(
          style = "height: 100%; overflow-y: auto; padding: 20px;",
          tags$div(
            class = "markdown-content",
            shiny::markdown(concept_info$comments[1])
          )
        )
      } else {
        tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No comments available for this concept."
        )
      }
    })

    # Handle view source JSON button (Edit Mappings)
    observe_event(input$view_source_json, {
      shinyjs::show("source_json_fullscreen_modal")
    })

    # Handle close source JSON fullscreen modal
    observe_event(input$close_source_json_fullscreen, {
      shinyjs::hide("source_json_fullscreen_modal")
    })

    # Render source JSON fullscreen content (Edit Mappings)
    output$source_json_fullscreen_content <- renderUI({
      json_data <- selected_source_json()
      if (is.null(json_data)) {
        return(tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No JSON data available."
        ))
      }

      # Pretty print the JSON
      json_text <- tryCatch({
        jsonlite::toJSON(json_data, pretty = TRUE, auto_unbox = TRUE)
      }, error = function(e) {
        as.character(json_data)
      })

      tags$pre(
        style = paste0(
          "margin: 0; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; ",
          "font-size: 11px; line-height: 1.5; white-space: pre-wrap; ",
          "word-wrap: break-word; color: #333;"
        ),
        as.character(json_text)
      )
    })

    # Render source JSON tutorial (Edit Mappings)
    output$source_json_tutorial <- renderUI({
      render_json_tutorial(Sys.getenv("INDICATE_LANGUAGE", "en"))
    })

    # Handle view eval source JSON button (Evaluate Mappings)
    observe_event(input$view_eval_source_json, {
      shinyjs::show("eval_source_json_fullscreen_modal")
    })

    # Handle close eval source JSON fullscreen modal
    observe_event(input$close_eval_source_json_fullscreen, {
      shinyjs::hide("eval_source_json_fullscreen_modal")
    })

    # Render eval source JSON fullscreen content (Evaluate Mappings)
    output$eval_source_json_fullscreen_content <- renderUI({
      json_data <- eval_source_json()
      if (is.null(json_data)) {
        return(tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No JSON data available."
        ))
      }

      # Pretty print the JSON
      json_text <- tryCatch({
        jsonlite::toJSON(json_data, pretty = TRUE, auto_unbox = TRUE)
      }, error = function(e) {
        as.character(json_data)
      })

      tags$pre(
        style = paste0(
          "margin: 0; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; ",
          "font-size: 11px; line-height: 1.5; white-space: pre-wrap; ",
          "word-wrap: break-word; color: #333;"
        ),
        as.character(json_text)
      )
    })

    # Render eval source JSON tutorial (Evaluate Mappings)
    output$eval_source_json_tutorial <- renderUI({
      render_json_tutorial(Sys.getenv("INDICATE_LANGUAGE", "en"))
    })

    # Target summary render - uses shared render_stats_summary_panel from fct_statistics_display.R
    # profile_data: Profile data from target (already extracted via get_profile_data)
    # source_json: Raw source JSON (will extract profile data internally)
    render_summary_panel <- function(profile_data, concept_id, mapping_data, source_row, source_json) {
      vocab_data <- vocabularies()
      target_unit_name <- NULL
      source_unit_name <- NULL

      # Extract source profile data
      source_profile <- if (!is.null(source_json)) get_profile_data(source_json) else NULL

      # Get target unit name from vocabulary
      if (!is.null(mapping_data) && "omop_unit_concept_id" %in% names(mapping_data)) {
        unit_concept_id <- mapping_data$omop_unit_concept_id
        if (!is.null(unit_concept_id) && !is.na(unit_concept_id) && unit_concept_id != "" && unit_concept_id != "/") {
          if (!is.null(vocab_data) && !is.null(vocab_data$concept)) {
            unit_info <- vocab_data$concept %>%
              dplyr::filter(concept_id == as.integer(unit_concept_id)) %>%
              head(1) %>%
              dplyr::collect()
            if (nrow(unit_info) > 0 && !is.null(unit_info$concept_name)) {
              target_unit_name <- unit_info$concept_name
            }
          }
        }
      }

      # Get source unit name for comparison
      if (!is.null(source_row) && "unit" %in% names(source_row)) {
        source_unit <- source_row$unit
        if (!is.null(source_unit) && !is.na(source_unit) && source_unit != "" && source_unit != "/") {
          source_unit_name <- source_unit
        }
      }

      # Use the shared render function from fct_statistics_display.R
      render_stats_summary_panel(
        profile_data = profile_data,
        source_data = source_profile,
        row_data = NULL,  # Concept Mapping doesn't have row/patient counts
        target_unit_name = target_unit_name,
        source_unit_name = source_unit_name
      )
    }

    # Wrapper for Edit Mappings tab
    render_target_summary <- function(profile_data, concept_id) {
      render_summary_panel(profile_data, concept_id, selected_target_mapping(), selected_source_row(), selected_source_json())
    }

    # Factorized helper function for parsing histogram data (supports both x and bin_start/bin_end formats)
    parse_histogram_data <- function(histogram_list) {
      if (is.null(histogram_list) || length(histogram_list) == 0) return(NULL)
      hist_df <- as.data.frame(histogram_list)
      if (nrow(hist_df) == 0 || !"count" %in% colnames(hist_df)) return(NULL)

      if ("x" %in% colnames(hist_df)) {
        hist_df$bin_mid <- hist_df$x
      } else if ("bin_start" %in% colnames(hist_df) && "bin_end" %in% colnames(hist_df)) {
        hist_df$bin_mid <- (hist_df$bin_start + hist_df$bin_end) / 2
      } else {
        return(NULL)
      }

      total_count <- sum(hist_df$count, na.rm = TRUE)
      hist_df$percentage <- if (total_count > 0) hist_df$count / total_count * 100 else 0
      hist_df
    }

    # Wrapper for Edit Mappings tab (uses selected_source_json)
    # Uses shared render_stats_distribution_panel from fct_statistics_display.R
    render_target_distribution <- function(profile_data) {
      source_profile <- if (!is.null(selected_source_json())) get_profile_data(selected_source_json()) else NULL
      render_stats_distribution_panel(profile_data, source_profile)
    }

    # Wrapper for Evaluate Mappings tab (uses eval_source_json)
    # Uses shared render_stats_distribution_panel from fct_statistics_display.R
    render_eval_target_distribution <- function(profile_data) {
      source_profile <- if (!is.null(eval_source_json())) get_profile_data(eval_source_json()) else NULL
      render_stats_distribution_panel(profile_data, source_profile)
    }

    #### Modal - Concept Details ----
    #### Modal - ETL Comments ----
    #### Add/Remove Mapping Actions ----
    observe_event(c(mapping_view(), selected_general_concept_id(), input$source_concepts_table_rows_selected, input$concept_mappings_table_rows_selected), {
      if (mapping_view() != "general") {
        shinyjs::hide("add_mapping_from_general")
        return()
      }
      
      if (is.null(selected_general_concept_id())) {
        shinyjs::hide("add_mapping_from_general")
        return()
      }
      
      source_selected <- !is.null(input$source_concepts_table_rows_selected)
      mapping_selected <- !is.null(input$concept_mappings_table_rows_selected)
      
      if (source_selected && mapping_selected) {
        shinyjs::show("add_mapping_from_general")
      } else {
        shinyjs::hide("add_mapping_from_general")
      }
    })
    
    observe_event(input$add_mapping_from_general, {
      source_row <- input$source_concepts_table_rows_selected
      
      if (!is.null(selected_general_concept_id())) {
        mapping_row <- input$concept_mappings_table_rows_selected
        
        if (is.null(source_row) || is.null(mapping_row)) return()
      } else {
        general_row <- input$general_concepts_table_rows_selected
        
        if (is.null(source_row) || is.null(general_row)) return()
      }
      
      if (is.null(selected_alignment_id())) return()
      
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      
      if (nrow(alignment) != 1) return()
      
      file_id <- alignment$file_id[1]
      
      mapping_dir <- get_app_dir("concept_mapping")
      
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
      
      if (!file.exists(csv_path)) return()
      
      df <- read.csv(csv_path, stringsAsFactors = FALSE)
      
      if (is.null(data())) return()

      if (!is.null(selected_general_concept_id())) {
        target_general_concept_id <- selected_general_concept_id()

        # Use stored table data which matches displayed order
        mappings_data <- concept_mappings_table_data()

        if (is.null(mappings_data) || nrow(mappings_data) == 0) return()
        if (mapping_row > nrow(mappings_data)) return()

        selected_mapping <- mappings_data[mapping_row, ]

        # Determine if it's a custom concept or OMOP concept
        if (isTRUE(selected_mapping$is_custom)) {
          target_omop_concept_id <- NA_integer_
          # For custom concepts, we need to get the custom_concept_id
          # The custom_concept_id is not in the displayed data, so look it up
          custom_concepts_path <- get_csv_path("custom_concepts.csv")
          if (file.exists(custom_concepts_path)) {
            custom_concepts_all <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
            custom_match <- custom_concepts_all %>%
              dplyr::filter(
                general_concept_id == target_general_concept_id,
                concept_name == selected_mapping$concept_name
              )
            if (nrow(custom_match) > 0) {
              target_custom_concept_id <- custom_match$custom_concept_id[1]
            } else {
              target_custom_concept_id <- NA_integer_
            }
          } else {
            target_custom_concept_id <- NA_integer_
          }
        } else {
          target_omop_concept_id <- selected_mapping$omop_concept_id
          target_custom_concept_id <- NA_integer_
        }
      } else {
        general_concepts <- data()$general_concepts
        target_general_concept_id <- general_concepts$general_concept_id[general_row]
        
        if (is.na(target_general_concept_id)) return()
        
        concept_mappings_dict <- data()$concept_mappings %>%
          dplyr::filter(general_concept_id == target_general_concept_id)
        
        target_omop_concept_id <- NA_integer_
        target_custom_concept_id <- NA_integer_
        if (nrow(concept_mappings_dict) > 0) {
          target_omop_concept_id <- concept_mappings_dict$omop_concept_id[1]
        }
      }
      
      csv_mapping_id <- df$mapping_id[source_row]

      con <- get_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Check if this exact mapping already exists (same source + same target)
      # Use source_concept_index to match both manual and imported mappings
      existing_exact <- DBI::dbGetQuery(
        con,
        "SELECT mapping_id FROM concept_mappings
         WHERE alignment_id = ?
           AND source_concept_index = ?
           AND target_general_concept_id = ?
           AND (target_omop_concept_id = ? OR (target_omop_concept_id IS NULL AND ? IS NULL))
           AND (target_custom_concept_id = ? OR (target_custom_concept_id IS NULL AND ? IS NULL))",
        params = list(
          selected_alignment_id(),
          source_row,
          target_general_concept_id,
          target_omop_concept_id, target_omop_concept_id,
          target_custom_concept_id, target_custom_concept_id
        )
      )

      if (nrow(existing_exact) > 0) {
        showNotification(
          i18n$t("mapping_already_exists"),
          type = "warning",
          duration = 3
        )
        return()
      }

      mapping_datetime <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      user_id <- if (!is.null(current_user())) current_user()$user_id else NA_integer_

      # Always insert new mapping (multiple mappings per source concept are allowed)
      DBI::dbExecute(
        con,
        "INSERT INTO concept_mappings (
          alignment_id,
          csv_file_path,
          csv_mapping_id,
          source_concept_index,
          target_general_concept_id,
          target_omop_concept_id,
          target_custom_concept_id,
          mapped_by_user_id,
          mapping_datetime
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        params = list(
          selected_alignment_id(),
          csv_path,
          csv_mapping_id,
          source_row,
          target_general_concept_id,
          target_omop_concept_id,
          target_custom_concept_id,
          user_id,
          mapping_datetime
        )
      )

      # Show success notification
      showNotification(
        i18n$t("mapping_added_successfully"),
        type = "message",
        duration = 2
      )

      # Refresh tables
      source_concepts_table_trigger(source_concepts_table_trigger() + 1)
      all_mappings_table_trigger(all_mappings_table_trigger() + 1)
      evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)

      # Reselect the source row after data refresh
      shinyjs::delay(200, {
        proxy <- DT::dataTableProxy("source_concepts_table", session = session)
        DT::selectRows(proxy, source_row)
      })
    })
    
    observe_event(input$remove_mapping, {
      row_num <- input$remove_mapping
      
      if (is.null(selected_alignment_id())) return()
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      if (nrow(alignment) != 1) return()
      
      file_id <- alignment$file_id[1]
      
      mapping_dir <- get_app_dir("concept_mapping")
      
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
      
      if (!file.exists(csv_path)) {
        return()
      }
      
      df <- read.csv(csv_path, stringsAsFactors = FALSE)
      
      if (!"target_general_concept_id" %in% colnames(df)) {
        return()
      }
      
      mapped_rows_indices <- which(!is.na(df$target_general_concept_id))
      
      if (row_num > length(mapped_rows_indices)) {
        return()
      }
      
      actual_row <- mapped_rows_indices[row_num]
      
      df$target_general_concept_id[actual_row] <- NA_integer_
      df$target_omop_concept_id[actual_row] <- NA_integer_
      
      write.csv(df, csv_path, row.names = FALSE)

      source_concepts_table_trigger(source_concepts_table_trigger() + 1)
      all_mappings_table_trigger(all_mappings_table_trigger() + 1)
      evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    })
    
    ### d) Evaluate Mappings Tab ----
    #### Evaluate Mappings Table Rendering ----
    # Render table when trigger fires
    observe_event(evaluate_mappings_table_trigger(), {
      # Check prerequisites first
      if (is.null(selected_alignment_id())) return()
      if (is.null(current_user())) return()

      # Prepare data outside renderDT
      db_dir <- get_app_dir()
        db_path <- file.path(db_dir, "indicate.db")

        if (!file.exists(db_path)) return()

        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        # Get all mappings with evaluation status for current user
        query <- "
          SELECT
            cm.mapping_id,
            cm.source_concept_index,
            cm.target_general_concept_id,
            cm.target_omop_concept_id,
            cm.target_custom_concept_id,
            cm.csv_file_path,
            cm.csv_mapping_id,
            cm.imported_mapping_id,
            cm.mapping_datetime,
            me.is_approved,
            me.comment
          FROM concept_mappings cm
          LEFT JOIN mapping_evaluations me
            ON cm.mapping_id = me.mapping_id
            AND me.evaluator_user_id = ?
          WHERE cm.alignment_id = ?
        "

        mappings_db <- DBI::dbGetQuery(
          con,
          query,
          params = list(current_user()$user_id, selected_alignment_id())
        )

        if (nrow(mappings_db) == 0) {
          output$evaluate_mappings_table <- DT::renderDT({
            create_empty_datatable("No mappings created yet.")
          }, server = TRUE)
          return()
        }

        # Read CSV to get source concept names (if file exists)
        csv_path <- mappings_db$csv_file_path[1]
        df <- NULL
        if (file.exists(csv_path)) {
          df <- read.csv(csv_path, stringsAsFactors = FALSE)
        }

        # Enrich with source concept information by matching on mapping_id
        if (!is.null(df) && "mapping_id" %in% colnames(df)) {
          # Join on mapping_id column from CSV
          source_cols <- c("mapping_id")
          if ("concept_name" %in% colnames(df)) source_cols <- c(source_cols, "concept_name")
          if ("concept_code" %in% colnames(df)) source_cols <- c(source_cols, "concept_code")
          if ("vocabulary_id" %in% colnames(df)) source_cols <- c(source_cols, "vocabulary_id")

          source_df <- df[, source_cols, drop = FALSE]
          colnames(source_df) <- c("csv_mapping_id",
            if ("concept_name" %in% colnames(df)) "source_concept_name" else NULL,
            if ("concept_code" %in% colnames(df)) "source_concept_code" else NULL,
            if ("vocabulary_id" %in% colnames(df)) "source_vocabulary_id" else NULL
          )

          enriched_data <- mappings_db %>%
            dplyr::left_join(source_df, by = "csv_mapping_id")

          # Fill in defaults for missing columns
          if (!"source_concept_name" %in% colnames(enriched_data)) {
            enriched_data <- enriched_data %>%
              dplyr::mutate(source_concept_name = paste0("Source concept #", source_concept_index))
          } else {
            enriched_data <- enriched_data %>%
              dplyr::mutate(source_concept_name = dplyr::if_else(
                is.na(source_concept_name),
                paste0("Source concept #", source_concept_index),
                source_concept_name
              ))
          }
          if (!"source_concept_code" %in% colnames(enriched_data)) {
            enriched_data <- enriched_data %>%
              dplyr::mutate(source_concept_code = NA_character_)
          }
          if (!"source_vocabulary_id" %in% colnames(enriched_data)) {
            enriched_data <- enriched_data %>%
              dplyr::mutate(source_vocabulary_id = NA_character_)
          }
        } else {
          # Fallback for CSV without mapping_id column
          enriched_data <- mappings_db %>%
            dplyr::mutate(
              source_concept_name = paste0("Source concept #", source_concept_index),
              source_concept_code = NA_character_,
              source_vocabulary_id = NA_character_
            )
        }

        # Enrich with target general concept information
        general_concepts <- data()$general_concepts
        enriched_data <- enriched_data %>%
          dplyr::left_join(
            general_concepts %>%
              dplyr::select(general_concept_id, target_general_concept_name = general_concept_name),
            by = c("target_general_concept_id" = "general_concept_id")
          )

        # Enrich with target concept info (OMOP or custom)
        enriched_data <- enrich_target_concepts(enriched_data, vocabularies(), data())

        # Add status column
        enriched_data <- enriched_data %>%
          dplyr::mutate(
            status = dplyr::case_when(
              is.na(is_approved) ~ as.character(i18n$t("not_evaluated")),
              is_approved == 1 ~ as.character(i18n$t("approved")),
              is_approved == 0 ~ as.character(i18n$t("rejected")),
              is_approved == -1 ~ as.character(i18n$t("uncertain")),
              TRUE ~ as.character(i18n$t("not_evaluated"))
            )
          )

        # Add row index for actions
        enriched_data <- enriched_data %>%
          dplyr::mutate(row_index = dplyr::row_number())

        # Create action buttons HTML
        enriched_data <- enriched_data %>%
          dplyr::mutate(
            Actions = sprintf(
              '<div style="display: flex; gap: 5px; justify-content: center;">
                <button class="btn-eval-action" data-action="approve" data-row="%d" data-mapping-id="%d" title="Approve">
                  <i class="fas fa-check"></i>
                </button>
                <button class="btn-eval-action" data-action="reject" data-row="%d" data-mapping-id="%d" title="Reject">
                  <i class="fas fa-times"></i>
                </button>
                <button class="btn-eval-action" data-action="uncertain" data-row="%d" data-mapping-id="%d" title="Uncertain">
                  <i class="fas fa-question"></i>
                </button>
                <button class="btn-eval-action" data-action="clear" data-row="%d" data-mapping-id="%d" title="Clear Evaluation">
                  <i class="fas fa-redo"></i>
                </button>
              </div>',
              row_index, mapping_id,
              row_index, mapping_id,
              row_index, mapping_id,
              row_index, mapping_id
            )
          )

        # Build display columns like in All Completed Mappings
        display_data <- enriched_data %>%
          dplyr::mutate(
            Source = paste0(source_concept_name, " (", source_vocabulary_id, ": ", source_concept_code, ")"),
            Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
            status = factor(status, levels = c(
              as.character(i18n$t("not_evaluated")),
              as.character(i18n$t("approved")),
              as.character(i18n$t("rejected")),
              as.character(i18n$t("uncertain"))
            )),
            Origin = dplyr::if_else(
              is.na(imported_mapping_id),
              sprintf('<span style="background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("manual")),
              sprintf('<span style="background: #0f60af; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("imported"))
            ),
            Added = dplyr::if_else(
              is.na(mapping_datetime) | mapping_datetime == "",
              "/",
              mapping_datetime
            )
          ) %>%
          dplyr::select(
            mapping_id,
            source_concept_index,
            csv_mapping_id,
            csv_file_path,
            target_general_concept_id,
            target_omop_concept_id,
            Source,
            Target,
            Origin,
            Added,
            status,
            Actions
          )

      # Render table with prepared data
      # Using selection = "none" to handle row selection manually via JavaScript
      # This prevents action button clicks from affecting row selection
      output$evaluate_mappings_table <- DT::renderDT({
        dt <- DT::datatable(
          display_data,
          rownames = FALSE,
          selection = "none",
          escape = FALSE,
          filter = "top",
          options = list(
            pageLength = 8,
            lengthMenu = c(5, 8, 10, 15, 20, 50, 100),
            dom = "ltp",
            ordering = TRUE,
            autoWidth = FALSE,
            stateSave = TRUE,
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 0:5, visible = FALSE),
              list(targets = 6, width = "25%"),
              list(targets = 7, width = "25%"),
              list(targets = 8, width = "8%", className = "dt-center"),
              list(targets = 9, width = "12%"),
              list(targets = 10, width = "10%"),
              list(targets = 11, width = "20%", orderable = FALSE, searchable = FALSE, className = "dt-center no-select")
            )
          ),
          colnames = c(
            "ID",
            "source_concept_index",
            "csv_mapping_id",
            "csv_file_path",
            "target_general_concept_id",
            "target_omop_concept_id",
            as.character(i18n$t("source_concept")),
            as.character(i18n$t("target_concept")),
            as.character(i18n$t("origin")),
            as.character(i18n$t("added")),
            as.character(i18n$t("status")),
            as.character(i18n$t("actions"))
          )
        ) %>%
          DT::formatStyle(
            "status",
            backgroundColor = DT::styleEqual(
              c(i18n$t("approved"), i18n$t("rejected"), i18n$t("uncertain"), i18n$t("not_evaluated")),
              c("#d4edda", "#f8d7da", "#fff3cd", "#e7e7e7")
            ),
            color = DT::styleEqual(
              c(i18n$t("approved"), i18n$t("rejected"), i18n$t("uncertain"), i18n$t("not_evaluated")),
              c("#155724", "#721c24", "#856404", "#666666")
            ),
            fontWeight = "bold"
          )

        dt
      }, server = TRUE)
    })

    #### Update Table Data Using Proxy ----
    # Update data without re-rendering when mappings change
    observe_event(mappings_refresh_trigger(), {
      if (mappings_refresh_trigger() == 0) return()
      if (is.null(selected_alignment_id())) return()
      if (is.null(current_user())) return()

      # Prepare updated data (same logic as initial render)
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings with evaluation status for current user
      query <- "
        SELECT
          cm.mapping_id,
          cm.source_concept_index,
          cm.target_general_concept_id,
          cm.target_omop_concept_id,
          cm.target_custom_concept_id,
          cm.csv_file_path,
          cm.csv_mapping_id,
          cm.imported_mapping_id,
          cm.mapping_datetime,
          me.is_approved,
          me.comment
        FROM concept_mappings cm
        LEFT JOIN mapping_evaluations me
          ON cm.mapping_id = me.mapping_id
          AND me.evaluator_user_id = ?
        WHERE cm.alignment_id = ?
      "

      mappings_db <- DBI::dbGetQuery(
        con,
        query,
        params = list(current_user()$user_id, selected_alignment_id())
      )

      if (nrow(mappings_db) == 0) return()

      # Read CSV to get source concept names (if file exists)
      csv_path <- mappings_db$csv_file_path[1]
      df <- NULL
      if (file.exists(csv_path)) {
        df <- read.csv(csv_path, stringsAsFactors = FALSE)
      }

      # Enrich with source concept information
      enriched_data <- mappings_db %>%
        dplyr::rowwise() %>%
        dplyr::mutate(
          source_concept_name = {
            if (!is.null(df) && csv_mapping_id <= nrow(df) && "concept_name" %in% colnames(df)) {
              df$concept_name[csv_mapping_id]
            } else {
              paste0("Source concept #", source_concept_index)
            }
          },
          source_concept_code = {
            if (!is.null(df) && csv_mapping_id <= nrow(df) && "concept_code" %in% colnames(df)) {
              df$concept_code[csv_mapping_id]
            } else {
              NA_character_
            }
          },
          source_vocabulary_id = {
            if (!is.null(df) && csv_mapping_id <= nrow(df) && "vocabulary_id" %in% colnames(df)) {
              df$vocabulary_id[csv_mapping_id]
            } else {
              NA_character_
            }
          }
        ) %>%
        dplyr::ungroup()

      # Enrich with target general concept information
      general_concepts <- data()$general_concepts
      enriched_data <- enriched_data %>%
        dplyr::left_join(
          general_concepts %>%
            dplyr::select(general_concept_id, target_general_concept_name = general_concept_name),
          by = c("target_general_concept_id" = "general_concept_id")
        )

      # Enrich with target concept info (OMOP or custom)
      enriched_data <- enrich_target_concepts(enriched_data, vocabularies(), data())

      # Add status column
      enriched_data <- enriched_data %>%
        dplyr::mutate(
          status = dplyr::case_when(
            is.na(is_approved) ~ as.character(i18n$t("not_evaluated")),
            is_approved == 1 ~ as.character(i18n$t("approved")),
            is_approved == 0 ~ as.character(i18n$t("rejected")),
            is_approved == -1 ~ as.character(i18n$t("uncertain")),
            TRUE ~ as.character(i18n$t("not_evaluated"))
          )
        )

      # Add row index for actions
      enriched_data <- enriched_data %>%
        dplyr::mutate(row_index = dplyr::row_number())

      # Create action buttons HTML
      enriched_data <- enriched_data %>%
        dplyr::mutate(
          Actions = sprintf(
            '<div style="display: flex; gap: 5px; justify-content: center;">
              <button class="btn-eval-action" data-action="approve" data-row="%%d" data-mapping-id="%%d" title="%s">
                <i class="fas fa-check"></i>
              </button>
              <button class="btn-eval-action" data-action="reject" data-row="%%d" data-mapping-id="%%d" title="%s">
                <i class="fas fa-times"></i>
              </button>
              <button class="btn-eval-action" data-action="uncertain" data-row="%%d" data-mapping-id="%%d" title="%s">
                <i class="fas fa-question"></i>
              </button>
              <button class="btn-eval-action" data-action="clear" data-row="%%d" data-mapping-id="%%d" title="%s">
                <i class="fas fa-redo"></i>
              </button>
            </div>',
            i18n$t("approved"), i18n$t("rejected"), i18n$t("uncertain"), i18n$t("clear_evaluation")
          ) %>% sprintf(
            row_index, mapping_id,
            row_index, mapping_id,
            row_index, mapping_id,
            row_index, mapping_id
          )
        )

      # Build display columns
      display_data <- enriched_data %>%
        dplyr::mutate(
          Source = paste0(source_concept_name, " (", source_vocabulary_id, ": ", source_concept_code, ")"),
          Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
          status = factor(status, levels = c(
            as.character(i18n$t("not_evaluated")),
            as.character(i18n$t("approved")),
            as.character(i18n$t("rejected")),
            as.character(i18n$t("uncertain"))
          )),
          Origin = dplyr::if_else(
            is.na(imported_mapping_id),
            sprintf('<span style="background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("manual")),
            sprintf('<span style="background: #0f60af; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("imported"))
          ),
          Added = dplyr::if_else(
            is.na(mapping_datetime) | mapping_datetime == "",
            "/",
            mapping_datetime
          )
        ) %>%
        dplyr::select(
          mapping_id,
          source_concept_index,
          csv_mapping_id,
          csv_file_path,
          target_general_concept_id,
          target_omop_concept_id,
          Source,
          Target,
          Origin,
          Added,
          status,
          Actions
        )

      # Update table data using proxy (preserves state)
      # Add small delay to ensure table is ready
      shinyjs::delay(100, {
        proxy <- DT::dataTableProxy("evaluate_mappings_table", session = session)
        DT::replaceData(proxy, display_data, resetPaging = FALSE, rownames = FALSE)
      })
    }, ignoreInit = TRUE)

    #### Handle Evaluation Actions ----
    observe_event(input$eval_action, {
      if (is.null(input$eval_action)) return()
      if (is.null(current_user())) return()

      action_data <- input$eval_action
      action <- action_data$action
      row_index <- as.integer(action_data$row)

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings for this alignment
      query <- "
        SELECT mapping_id
        FROM concept_mappings
        WHERE alignment_id = ?
      "
      mappings_db <- DBI::dbGetQuery(con, query, params = list(selected_alignment_id()))

      if (row_index < 1 || row_index > nrow(mappings_db)) return()

      mapping_id <- mappings_db$mapping_id[row_index]
      user_id <- current_user()$user_id
      timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

      # Determine is_approved value based on action
      is_approved <- switch(
        action,
        "approve" = 1L,
        "reject" = 0L,
        "uncertain" = -1L,
        "clear" = NA_integer_
      )

      if (action == "clear") {
        # Delete evaluation
        DBI::dbExecute(
          con,
          "DELETE FROM mapping_evaluations
           WHERE mapping_id = ? AND evaluator_user_id = ?",
          params = list(mapping_id, user_id)
        )
      } else {
        # Check if evaluation exists
        existing <- DBI::dbGetQuery(
          con,
          "SELECT evaluation_id FROM mapping_evaluations
           WHERE mapping_id = ? AND evaluator_user_id = ?",
          params = list(mapping_id, user_id)
        )

        if (nrow(existing) > 0) {
          # Update existing evaluation
          DBI::dbExecute(
            con,
            "UPDATE mapping_evaluations
             SET is_approved = ?, evaluated_at = ?
             WHERE mapping_id = ? AND evaluator_user_id = ?",
            params = list(is_approved, timestamp, mapping_id, user_id)
          )
        } else {
          # Insert new evaluation
          DBI::dbExecute(
            con,
            "INSERT INTO mapping_evaluations
             (alignment_id, mapping_id, evaluator_user_id, is_approved, evaluated_at)
             VALUES (?, ?, ?, ?, ?)",
            params = list(selected_alignment_id(), mapping_id, user_id, is_approved, timestamp)
          )
        }
      }

      # Trigger refresh to update the table
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    }, ignoreInit = TRUE)

    #### Handle Evaluate Mappings Row Selection ----
    # Using manual row selection input from JavaScript (selection = "none" in datatable)
    observe_event(input$evaluate_mappings_table_row_selected, {
      if (mapping_tab() != "evaluate_mappings") return()

      row_selected <- input$evaluate_mappings_table_row_selected

      if (is.null(row_selected) || length(row_selected) == 0) {
        shinyjs::hide("eval_details_container")
        eval_selected_row_data(NULL)
        eval_source_json(NULL)
        eval_source_row(NULL)
        eval_target_concept_id(NULL)
        eval_target_json(NULL)
        eval_target_mapping(NULL)
        return()
      }

      # Get database connection to fetch mapping data
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings for this alignment
      query <- "
        SELECT
          cm.mapping_id,
          cm.source_concept_index,
          cm.target_general_concept_id,
          cm.target_omop_concept_id,
          cm.csv_file_path,
          cm.csv_mapping_id
        FROM concept_mappings cm
        WHERE cm.alignment_id = ?
      "
      mappings_db <- DBI::dbGetQuery(con, query, params = list(selected_alignment_id()))

      if (row_selected < 1 || row_selected > nrow(mappings_db)) return()

      selected_mapping <- mappings_db[row_selected, ]
      eval_selected_row_data(selected_mapping)

      # Load source concept JSON data
      csv_path <- selected_mapping$csv_file_path
      csv_mapping_id <- selected_mapping$csv_mapping_id

      if (!is.null(csv_path) && file.exists(csv_path)) {
        df <- read.csv(csv_path, stringsAsFactors = FALSE)

        if (csv_mapping_id <= nrow(df)) {
          row_data <- df[csv_mapping_id, ]
          eval_source_row(row_data)

          # Check if json column exists
          if ("json" %in% colnames(df)) {
            json_str <- df$json[csv_mapping_id]
            if (!is.null(json_str) && !is.na(json_str) && json_str != "") {
              json_data <- tryCatch(
                jsonlite::fromJSON(json_str),
                error = function(e) NULL
              )
              eval_source_json(json_data)
            } else {
              eval_source_json(NULL)
            }
          } else {
            eval_source_json(NULL)
          }
        }
      }

      # Load target concept data
      target_gc_id <- selected_mapping$target_general_concept_id
      if (!is.null(target_gc_id) && !is.na(target_gc_id)) {
        eval_target_concept_id(target_gc_id)

        # Get general concept info
        gc_data <- data()$general_concepts
        if (!is.null(gc_data)) {
          selected_gc <- gc_data %>%
            dplyr::filter(general_concept_id == target_gc_id)

          if (nrow(selected_gc) > 0) {
            # Create JSON-like data from general concept info
            target_json <- list(
              data_types = NULL,
              numeric_data = NULL,
              histogram = NULL,
              categorical_data = NULL,
              measurement_frequency = NULL,
              missing_rate = NULL
            )

            # If the general concept has a statistical_summary JSON, parse it
            if ("statistical_summary" %in% names(selected_gc) &&
                !is.null(selected_gc$statistical_summary[1]) &&
                !is.na(selected_gc$statistical_summary[1]) &&
                selected_gc$statistical_summary[1] != "") {
              target_json <- tryCatch(
                jsonlite::fromJSON(selected_gc$statistical_summary[1]),
                error = function(e) target_json
              )
            }
            eval_target_json(target_json)
          }
        }

        # Get target mapping data (concept mappings for this general concept)
        target_omop_id <- selected_mapping$target_omop_concept_id
        if (!is.null(target_omop_id) && !is.na(target_omop_id)) {
          mappings_data <- data()$concept_mappings %>%
            dplyr::filter(
              general_concept_id == target_gc_id,
              omop_concept_id == target_omop_id
            )

          if (nrow(mappings_data) > 0) {
            eval_target_mapping(mappings_data[1, ])
          }
        }
      }

      # Show the details container
      shinyjs::show("eval_details_container")
      shinyjs::runjs(sprintf("$('#%s').css('display', 'flex');", ns("eval_details_container")))
    }, ignoreNULL = FALSE)

    #### Handle Evaluate Source Tab Selection ----
    observe_event(input$eval_source_tab_selected, {
      eval_source_tab(input$eval_source_tab_selected)
    })

    #### Handle Evaluate Target Tab Selection ----
    observe_event(input$eval_target_detail_tab_selected, {
      eval_target_detail_tab(input$eval_target_detail_tab_selected)
    })

    #### Handle Evaluate Target Stats Sub-Tab Selection ----
    observe_event(input$eval_target_stats_sub_tab_selected, {
      eval_target_stats_sub_tab(input$eval_target_stats_sub_tab_selected)
    })

    #### Handle Evaluate Target Profile Selection ----
    observe_event(input$eval_target_profile_selected, {
      eval_target_selected_profile(input$eval_target_profile_selected)
    })

    #### Render Evaluate Source Concept Details ----
    output$eval_source_concept_details_content <- renderUI({
      json_data <- eval_source_json()
      row_data <- eval_source_row()
      tab <- eval_source_tab()

      if (is.null(eval_selected_row_data())) {
        return(tags$div(
          style = "color: #999; font-style: italic;",
          "Select a mapping to see source details."
        ))
      }

      if (is.null(json_data)) {
        return(tags$div(
          style = "color: #999; font-style: italic;",
          "No JSON data available for this source concept."
        ))
      }

      if (tab == "summary") {
        render_json_summary(json_data, row_data)
      } else if (tab == "distribution") {
        render_json_distribution(json_data)
      } else if (tab == "temporal") {
        render_json_temporal(json_data)
      } else if (tab == "units") {
        render_json_units(json_data)
      } else if (tab == "other") {
        render_source_other_columns(row_data, json_data)
      } else {
        tags$div("Unknown tab")
      }
    })

    #### Render Evaluate Target Concept Details ----
    output$eval_target_concept_details_content <- renderUI({
      json_data <- eval_target_json()
      concept_id <- eval_target_concept_id()
      main_tab <- eval_target_detail_tab()
      sub_tab <- eval_target_stats_sub_tab()
      selected_profile <- eval_target_selected_profile()

      ns <- session$ns

      if (is.null(eval_selected_row_data())) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          "Select a mapping to see target details."
        ))
      }

      if (is.null(concept_id)) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          "No target concept available."
        ))
      }

      if (main_tab == "comments") {
        # Display comments for the selected general concept
        render_eval_target_comments(concept_id)
      } else if (main_tab == "statistical_summary") {
        # Statistical Summary tab with sub-tabs and profile dropdown
        profile_names <- get_profile_names(json_data)
        has_profiles <- length(profile_names) > 0

        # Auto-select first profile if none selected
        if (has_profiles && (is.null(selected_profile) || !selected_profile %in% profile_names)) {
          selected_profile <- profile_names[1]
          eval_target_selected_profile(selected_profile)
        }

        # Extract profile data based on selection
        profile_data <- get_profile_data(json_data, selected_profile)

        if (is.null(profile_data) || (is.null(profile_data$numeric_data) && is.null(profile_data$categorical_data))) {
          return(tags$div(
            style = "color: #999; font-style: italic; padding: 15px;",
            "No statistical data available for this concept."
          ))
        }

        # Render sub-tabs header with profile dropdown
        tags$div(
          style = "padding: 10px;",
          # Sub-tabs and profile dropdown row
          tags$div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
            # Sub-tabs (left)
            tags$div(
              style = "display: flex; gap: 5px;",
              tags$button(
                id = ns("eval_target_stats_sub_tab_summary"),
                class = if (sub_tab == "summary") "tab-btn tab-btn-active" else "tab-btn",
                onclick = sprintf("
                  document.getElementById('%s').classList.remove('tab-btn-active');
                  document.getElementById('%s').classList.remove('tab-btn-active');
                  this.classList.add('tab-btn-active');
                  Shiny.setInputValue('%s', 'summary', {priority: 'event'});
                ", ns("eval_target_stats_sub_tab_summary"), ns("eval_target_stats_sub_tab_distribution"), ns("eval_target_stats_sub_tab_selected")),
                "Summary"
              ),
              tags$button(
                id = ns("eval_target_stats_sub_tab_distribution"),
                class = if (sub_tab == "distribution") "tab-btn tab-btn-active" else "tab-btn",
                onclick = sprintf("
                  document.getElementById('%s').classList.remove('tab-btn-active');
                  document.getElementById('%s').classList.remove('tab-btn-active');
                  this.classList.add('tab-btn-active');
                  Shiny.setInputValue('%s', 'distribution', {priority: 'event'});
                ", ns("eval_target_stats_sub_tab_summary"), ns("eval_target_stats_sub_tab_distribution"), ns("eval_target_stats_sub_tab_selected")),
                "Distribution"
              )
            ),
            # Profile dropdown (right) - only show if multiple profiles
            if (has_profiles && length(profile_names) > 1) {
              tags$div(
                style = "display: flex; align-items: center; gap: 8px;",
                tags$span(style = "font-size: 11px; color: #666;", paste0(i18n$t("profile"), " :")),
                tags$select(
                  id = ns("eval_target_profile_select"),
                  style = "font-size: 11px; padding: 2px 6px; border: 1px solid #ccc; border-radius: 4px;",
                  onchange = sprintf("Shiny.setInputValue('%s', this.value, {priority: 'event'})", ns("eval_target_profile_selected")),
                  lapply(profile_names, function(p) {
                    if (p == selected_profile) {
                      tags$option(value = p, selected = "selected", p)
                    } else {
                      tags$option(value = p, p)
                    }
                  })
                )
              )
            }
          ),
          # Content based on sub-tab
          if (sub_tab == "summary") {
            render_eval_target_summary(profile_data, concept_id)
          } else if (sub_tab == "distribution") {
            render_eval_target_distribution(profile_data)
          } else {
            tags$div("Unknown sub-tab")
          }
        )
      } else {
        tags$div("Unknown tab")
      }
    })

    #### Render Evaluate Target Comments ----
    # Uses factorized render_comments_panel function
    render_eval_target_comments <- function(concept_id) {
      render_comments_panel(concept_id, "expand_eval_comments")
    }

    #### Render Evaluate Target Summary ----
    # Wrapper for Evaluate Mappings tab (profile_data already extracted)
    render_eval_target_summary <- function(profile_data, concept_id) {
      render_summary_panel(profile_data, concept_id, eval_target_mapping(), eval_source_row(), eval_source_json())
    }

    ### c) Import Mappings Tab ----

    #### File Browser Modal Function ----
    show_import_browser_modal <- function() {
      showModal(
        modalDialog(
          title = tagList(
            tags$i(class = "fas fa-folder-open", style = "margin-right: 8px;"),
            "Select CSV File to Import"
          ),
          size = "l",
          easyClose = FALSE,

          # Current path and home button
          tags$div(
            style = "display: flex; align-items: center; gap: 10px; margin-bottom: 10px;",
            tags$div(
              style = "flex: 1; font-family: monospace; background: #f8f9fa; padding: 8px 12px; border-radius: 4px; font-size: 12px; border: 1px solid #dee2e6;",
              uiOutput(ns("import_browser_current_path"))
            ),
            actionButton(
              ns("import_go_home"),
              label = tags$i(class = "fas fa-home"),
              style = "padding: 8px 12px; border-radius: 4px; background: #6c757d; color: white; border: none;"
            )
          ),

          # Search filter
          tags$div(
            style = "margin-bottom: 10px;",
            textInput(
              ns("import_filter_input"),
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
                onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("import_toggle_sort")),
                tags$span("Name"),
                uiOutput(ns("import_sort_icon"), inline = TRUE)
              )
            ),
            # File list
            uiOutput(ns("import_file_browser"))
          ),

          footer = tagList(
            actionButton(ns("import_cancel_browse"), "Cancel", class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("import_select_file"), "Select", class = "btn-primary-custom", icon = icon("check"), style = "margin-left: 10px;")
          )
        )
      )
    }

    #### File Path Display ----
    import_file_path_trigger <- reactiveVal(0)

    observe_event(import_selected_file(), {
      import_file_path_trigger(import_file_path_trigger() + 1)
    })

    observe_event(import_file_path_trigger(), {
      file_path <- import_selected_file()

      output$import_file_path_display <- renderUI({
        if (is.null(file_path) || nchar(file_path) == 0) {
          tags$div(
            style = paste0(
              "font-family: monospace; background: #f8f9fa; ",
              "padding: 10px; border-radius: 4px; font-size: 12px; ",
              "min-height: 40px; display: flex; align-items: center; ",
              "border: 1px solid #dee2e6;"
            ),
            tags$span(
              style = "color: #999;",
              i18n$t("no_file_selected")
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
              file_path
            )
          )
        }
      })
    }, ignoreInit = FALSE)

    #### Browse Button Handler ----
    observe_event(input$browse_import_file, {
      # Start at home directory
      start_path <- path.expand("~")
      import_current_path(start_path)
      import_sort_order("asc")
      import_filter_text("")
      show_import_browser_modal()
    }, ignoreInit = TRUE)

    #### Toggle Sort ----
    observe_event(input$import_toggle_sort, {
      if (import_sort_order() == "asc") {
        import_sort_order("desc")
      } else {
        import_sort_order("asc")
      }
    }, ignoreInit = TRUE)

    #### Filter Input ----
    observe_event(input$import_filter_input, {
      if (is.null(input$import_filter_input)) return()
      import_filter_text(input$import_filter_input)
    }, ignoreInit = TRUE)

    #### Current Path Display ----
    import_browser_path_trigger <- reactiveVal(0)

    observe_event(import_current_path(), {
      import_browser_path_trigger(import_browser_path_trigger() + 1)
    })

    observe_event(import_browser_path_trigger(), {
      output$import_browser_current_path <- renderUI({
        tags$span(import_current_path())
      })
    }, ignoreInit = FALSE)

    #### Sort Icon Display ----
    import_sort_icon_trigger <- reactiveVal(0)

    observe_event(import_sort_order(), {
      import_sort_icon_trigger(import_sort_icon_trigger() + 1)
    })

    observe_event(import_sort_icon_trigger(), {
      output$import_sort_icon <- renderUI({
        if (import_sort_order() == "asc") {
          tags$i(class = "fas fa-sort-alpha-down", title = "Sort A-Z")
        } else {
          tags$i(class = "fas fa-sort-alpha-up", title = "Sort Z-A")
        }
      })
    }, ignoreInit = FALSE)

    #### Go Home Button ----
    observe_event(input$import_go_home, {
      import_current_path(path.expand("~"))
    }, ignoreInit = TRUE)

    #### File Browser Rendering ----
    import_file_browser_trigger <- reactiveVal(0)

    observe_event(list(import_current_path(), import_filter_text(), import_sort_order()), {
      import_file_browser_trigger(import_file_browser_trigger() + 1)
    })

    observe_event(import_file_browser_trigger(), {
      path <- import_current_path()
      filter <- import_filter_text()
      order <- import_sort_order()

      output$import_file_browser <- renderUI({
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

        # Filter to show only CSV files
        files <- files[grepl("\\.csv$", files, ignore.case = TRUE)]

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
              onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("import_navigate_to"), parent_path),
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
              onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("import_navigate_to"), dir),
              tags$i(class = "fas fa-folder", style = "color: #f4c430; width: 16px;"),
              tags$span(dir_name, style = "flex: 1; color: #333;")
            )
          ))
        }

        # Add CSV files (clickable to select)
        for (file in files) {
          file_name <- basename(file)
          items_ui <- append(items_ui, list(
            tags$div(
              class = "file-browser-item",
              style = "padding: 8px 12px; cursor: pointer; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid #f0f0f0;",
              `data-path` = file,
              onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("import_select_file_path"), file),
              tags$i(class = "fas fa-file-csv", style = "color: #28a745; width: 16px;"),
              tags$span(file_name, style = "flex: 1; color: #333;")
            )
          ))
        }

        tagList(items_ui)
      })
    }, ignoreInit = FALSE)

    #### Navigation Handler ----
    observe_event(input$import_navigate_to, {
      new_path <- input$import_navigate_to
      if (dir.exists(new_path)) {
        import_current_path(new_path)
      }
    }, ignoreInit = TRUE)

    #### Select File Handler ----
    observe_event(input$import_select_file_path, {
      file_path <- input$import_select_file_path
      if (file.exists(file_path)) {
        import_selected_file(file_path)
        removeModal()
      }
    }, ignoreInit = TRUE)

    #### Cancel Browse ----
    observe_event(input$import_cancel_browse, {
      removeModal()
    }, ignoreInit = TRUE)

    #### Import History Table ----
    observe_event(import_history_trigger(), {
      alignment_id <- selected_alignment_id()
      if (is.null(alignment_id)) return()

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        output$import_history_table <- DT::renderDT({
          DT::datatable(
            data.frame(Message = "No import history available"),
            options = list(dom = "t"),
            rownames = FALSE
          )
        })
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get import history for this alignment
      import_history <- DBI::dbGetQuery(
        con,
        "SELECT im.import_id, im.original_filename, im.import_mode, im.concepts_count,
                im.imported_at, u.first_name || ' ' || u.last_name AS imported_by
         FROM imported_mappings im
         LEFT JOIN users u ON im.imported_by_user_id = u.user_id
         WHERE im.alignment_id = ?
         ORDER BY im.imported_at DESC",
        params = list(alignment_id)
      )

      if (nrow(import_history) == 0) {
        output$import_history_table <- DT::renderDT({
          DT::datatable(
            data.frame(Message = as.character(i18n$t("no_imports_yet"))),
            options = list(dom = "t"),
            rownames = FALSE
          )
        })
        return()
      }

      # Add delete button column
      import_history <- import_history %>%
        dplyr::mutate(
          Actions = sprintf(
            '<button class="btn-danger-custom btn-sm" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">
              <i class="fas fa-trash"></i> Delete
            </button>',
            ns("delete_import"), import_id
          )
        ) %>%
        dplyr::select(
          `File` = original_filename,
          `Concepts` = concepts_count,
          `Imported At` = imported_at,
          `Imported By` = imported_by,
          Actions
        )

      output$import_history_table <- DT::renderDT({
        DT::datatable(
          import_history,
          escape = FALSE,
          rownames = FALSE,
          options = list(
            dom = "t",
            pageLength = 10,
            ordering = FALSE,
            language = get_datatable_language()
          )
        )
      })
    }, ignoreInit = FALSE)

    #### Import CSV Handler ----
    observe_event(input$do_import_mappings, {
      selected_file <- import_selected_file()
      if (is.null(selected_file) || nchar(selected_file) == 0) {
        showNotification(i18n$t("please_select_csv_file"), type = "warning")
        return()
      }

      if (!file.exists(selected_file)) {
        showNotification(i18n$t("selected_file_no_longer_exists"), type = "error")
        return()
      }

      alignment_id <- selected_alignment_id()
      if (is.null(alignment_id)) {
        showNotification(i18n$t("no_alignment_selected_error"), type = "error")
        return()
      }

      if (is.null(current_user())) {
        showNotification(i18n$t("must_be_logged_in_import"), type = "error")
        return()
      }

      # Read the CSV file
      import_data <- tryCatch({
        read.csv(selected_file, stringsAsFactors = FALSE)
      }, error = function(e) {
        showNotification(paste(i18n$t("error_reading_csv"), e$message), type = "error")
        return(NULL)
      })

      if (is.null(import_data)) return()

      # Validate required columns
      required_cols <- c("source_code", "target_concept_id")
      missing_cols <- setdiff(required_cols, colnames(import_data))
      if (length(missing_cols) > 0) {
        showNotification(
          paste(i18n$t("missing_required_columns"), paste(missing_cols, collapse = ", ")),
          type = "error"
        )
        return()
      }

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        showNotification(i18n$t("database_not_found"), type = "error")
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get the alignment's CSV file path
      alignment_info <- DBI::dbGetQuery(
        con,
        "SELECT file_id FROM concept_alignments WHERE alignment_id = ?",
        params = list(alignment_id)
      )

      if (nrow(alignment_info) == 0) {
        showNotification(i18n$t("alignment_not_found"), type = "error")
        return()
      }

      file_id <- alignment_info$file_id[1]
      csv_file_path <- file.path(get_app_dir(), "uploads", paste0(file_id, ".csv"))

      # Check if alignment source file exists - if not, we'll work without it
      has_source_file <- file.exists(csv_file_path)
      source_data <- NULL
      if (has_source_file) {
        source_data <- read.csv(csv_file_path, stringsAsFactors = FALSE)
      }

      # Start transaction
      DBI::dbBegin(con)

      tryCatch({
        # Always use merge mode (only import new mappings that don't already exist)
        import_mode <- "merge"
        timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        user_id <- current_user()$user_id
        imported_count <- 0

        # Create import record
        original_filename <- basename(selected_file)
        DBI::dbExecute(
          con,
          "INSERT INTO imported_mappings (alignment_id, original_filename, import_mode, concepts_count, imported_by_user_id, imported_at)
           VALUES (?, ?, ?, 0, ?, ?)",
          params = list(alignment_id, original_filename, import_mode, user_id, timestamp)
        )

        import_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]

        # Process each row in the import file
        skipped_count <- 0
        for (i in seq_len(nrow(import_data))) {
          row <- import_data[i, ]
          source_code <- as.character(row$source_code)
          target_concept_id <- as.integer(row$target_concept_id)

          # Use source_code as the unique identifier for the concept
          # Generate a hash-based index from source_code for consistency
          source_concept_index <- i

          # If we have source data, try to find matching index
          if (!is.null(source_data)) {
            matching_indices <- which(
              source_data$concept_code == source_code |
              (if ("source_code" %in% colnames(source_data)) source_data$source_code == source_code else FALSE)
            )

            if (length(matching_indices) == 0 && "source_code_description" %in% colnames(row)) {
              source_desc <- as.character(row$source_code_description)
              matching_indices <- which(
                source_data$concept_name == source_desc |
                (if ("source_code_description" %in% colnames(source_data)) source_data$source_code_description == source_desc else FALSE)
              )
            }

            if (length(matching_indices) > 0) {
              source_concept_index <- matching_indices[1]
            }
          }

          # Check if this exact mapping already exists (same source + same target)
          existing_exact <- DBI::dbGetQuery(
            con,
            "SELECT mapping_id FROM concept_mappings
             WHERE alignment_id = ? AND csv_file_path = ? AND source_concept_index = ?
               AND target_omop_concept_id = ?",
            params = list(alignment_id, csv_file_path, source_concept_index, target_concept_id)
          )

          if (nrow(existing_exact) > 0) {
            # Skip if exact mapping already exists (same source + same target)
            skipped_count <- skipped_count + 1
            next
          }

          # Create unique csv_mapping_id
          max_id <- DBI::dbGetQuery(
            con,
            "SELECT COALESCE(MAX(csv_mapping_id), 0) as max_id FROM concept_mappings WHERE csv_file_path = ?",
            params = list(csv_file_path)
          )$max_id[1]

          # Insert new mapping (allows multiple mappings per source)
          DBI::dbExecute(
            con,
            "INSERT INTO concept_mappings (alignment_id, csv_file_path, csv_mapping_id, source_concept_index,
                                           target_omop_concept_id, imported_mapping_id, mapping_datetime)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            params = list(alignment_id, csv_file_path, max_id + 1, source_concept_index, target_concept_id, import_id, timestamp)
          )

          imported_count <- imported_count + 1
        }

        # Update import record with actual count
        DBI::dbExecute(
          con,
          "UPDATE imported_mappings SET concepts_count = ? WHERE import_id = ?",
          params = list(imported_count, import_id)
        )

        DBI::dbCommit(con)

        # Build notification message
        msg <- gsub("\\{count\\}", imported_count, i18n$t("successfully_imported_mappings"))
        if (skipped_count > 0) {
          skipped_msg <- gsub("\\{count\\}", skipped_count, i18n$t("duplicates_skipped"))
          msg <- paste0(msg, " (", skipped_msg, ")")
        }
        showNotification(msg, type = "message")

        # Reset selected file after successful import
        import_selected_file(NULL)

        # Trigger refresh
        import_history_trigger(import_history_trigger() + 1)
        mappings_refresh_trigger(mappings_refresh_trigger() + 1)

      }, error = function(e) {
        DBI::dbRollback(con)
        showNotification(paste(i18n$t("import_failed"), e$message), type = "error")
      })
    }, ignoreInit = TRUE)

    #### Delete Import ----
    observe_event(input$delete_import, {
      import_id <- input$delete_import
      if (is.null(import_id)) return()

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      DBI::dbBegin(con)

      tryCatch({
        # Delete mappings associated with this import
        DBI::dbExecute(
          con,
          "DELETE FROM concept_mappings WHERE imported_mapping_id = ?",
          params = list(import_id)
        )

        # Delete the import record
        DBI::dbExecute(
          con,
          "DELETE FROM imported_mappings WHERE import_id = ?",
          params = list(import_id)
        )

        DBI::dbCommit(con)

        showNotification(i18n$t("import_deleted_successfully"), type = "message")

        # Trigger refresh
        import_history_trigger(import_history_trigger() + 1)
        mappings_refresh_trigger(mappings_refresh_trigger() + 1)

      }, error = function(e) {
        DBI::dbRollback(con)
        showNotification(paste(i18n$t("delete_failed"), e$message), type = "error")
      })
    }, ignoreInit = TRUE)
  })
}
