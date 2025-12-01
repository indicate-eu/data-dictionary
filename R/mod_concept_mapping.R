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
#      ### c) Evaluate Mappings Tab
#          #### Evaluate Mappings State - Track evaluation state
#          #### Evaluate Mappings Table - Initial Render - Display evaluation table (responds to alignment changes)
#          #### Evaluate Mappings Table - Update Data Using Proxy - Preserve state during updates
#          #### Use Cases Compatibility Table - Show use case compatibility
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
              class = "btn btn-secondary btn-secondary-custom",
              icon = icon("times")
            ),
            actionButton(
              ns("alignment_modal_back"),
              "Back",
              class = "btn btn-secondary btn-secondary-custom",
              icon = icon("arrow-left"),
              style = "display: none;"
            ),
            actionButton(
              ns("alignment_modal_next"),
              "Next",
              class = "btn-primary-custom",
              icon = icon("arrow-right")
            ),
            actionButton(
              ns("alignment_modal_save"),
              "Save",
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
            tags$i(class = "fas fa-times"),
            " Cancel"
          ),
          actionButton(
            ns("confirm_delete_alignment"),
            "Delete",
            class = "btn btn-danger",
            icon = icon("trash")
          )
        )
      )
    ),

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
    selected_eval_mapping_id <- reactiveVal(NULL)  # Track selected evaluation mapping for comment editing

    # Cascade triggers for selected_alignment_id() changes
    selected_alignment_id_trigger <- reactiveVal(0)  # Primary trigger when alignment selection changes
    all_mappings_table_trigger <- reactiveVal(0)  # Trigger for Summary tab table
    source_concepts_table_mapped_trigger <- reactiveVal(0)  # Trigger for Mapped view table
    source_concepts_table_general_trigger <- reactiveVal(0)  # Trigger for General view Edit Mappings table (alignment changes only)
    evaluate_mappings_table_trigger <- reactiveVal(0)  # Trigger for Evaluate Mappings tab table

    # Separate trigger for source concepts table updates (used by mapping operations)
    source_concepts_table_trigger <- reactiveVal(0)  # Trigger for Edit Mappings table (mapping changes)

    # Cascade triggers for selected_general_concept_id() changes
    selected_general_concept_id_trigger <- reactiveVal(0)  # Primary trigger when general concept selection changes
    mapped_concepts_table_trigger <- reactiveVal(0)  # Trigger for Mapped view table
    concept_mappings_table_trigger <- reactiveVal(0)  # Trigger for Edit Mappings concept mappings table

    # Cascade triggers for summary_trigger() changes
    summary_content_trigger <- reactiveVal(0)  # Trigger for summary content rendering
    use_cases_compatibility_table_trigger <- reactiveVal(0)  # Trigger for use cases compatibility table

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
      use_cases_compatibility_table_trigger(use_cases_compatibility_table_trigger() + 1)
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

        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 0; display: flex; align-items: center; gap: 10px;",
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

    ### Tab Switching ----
    # Tab switching handled implicitly through Shiny's tabsetPanel
    # No explicit observers needed for current implementation

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
      shinyjs::hide("comments_display_container")
    })

    observe_event(input$show_comments, {
      concept_mappings_view("comments")

      shinyjs::hide("concept_mappings_table_container")
      shinyjs::show("comments_display_container")
    })

    observe_event(input$back_to_mappings, {
      concept_mappings_view("table")

      shinyjs::show("concept_mappings_table_container")
      shinyjs::hide("comments_display_container")
    })

    observe_event(input$view_mapped_concepts, {
      general_concept_id <- input$view_mapped_concepts
      selected_general_concept_id(general_concept_id)

      shinyjs::hide("general_concepts_table_container")
      shinyjs::show("concept_mappings_table_container")
      shinyjs::hide("comments_display_container")

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
        return(create_empty_datatable("No alignments yet. Click 'Add Alignment' to create one."))
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
          columnDefs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 4, orderable = FALSE, width = "300px", searchable = FALSE, className = "dt-center")
          )
        ),
        colnames = c("ID", "Name", "Description", "Created", "Actions")
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
          style = "display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 10px;",
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
      updateSelectInput(session, "col_statistical_summary", selected = "")
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
          statistical_summary = input$col_statistical_summary
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
        showNotification("No mapping file found for this alignment", type = "error")
        return()
      }
      
      df <- read.csv(csv_path, stringsAsFactors = FALSE)
      
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
      custom_concepts_path <- get_package_dir("extdata", "csv", "custom_concepts.csv")
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
        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 0; display: flex; align-items: center; gap: 15px; justify-content: space-between;",
          tags$div(
            class = "section-title",
            "Concept Mappings"
          ),
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

    render_mapping_view <- function() {
      tags$div(
        class = "panel-container-full",
        style = "display: flex; flex-direction: column; height: 100%;",

        tabsetPanel(
          id = ns("mapping_tabs"),

          tabPanel(
            "Summary",
            value = "summary",
            tags$div(
              style = "margin-top: 20px;",
              uiOutput(ns("summary_content"))
            )
          ),

          tabPanel(
            "All Mappings",
            value = "all_mappings",
            tags$div(
              class = "card-container",
              style = "margin: 10px; height: calc(100vh - 230px); overflow: auto;",
              DT::DTOutput(ns("all_mappings_table_main"))
            )
          ),

          tabPanel(
            "Edit Mappings",
            value = "edit_mappings",
            tags$div(
              style = "margin-top: 20px; height: calc(100vh - 230px); display: flex; flex-direction: column;",
            tags$div(
              style = "height: 100%; display: flex; gap: 15px; min-height: 0;",
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
                    icon = icon("plus"),
                    style = "height: 32px; padding: 5px 15px; font-size: 14px; display: none;"
                  )
                ),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto;",
                  DT::DTOutput(ns("source_concepts_table"))
                )
              ),
              tags$div(
                class = "card-container card-container-flex",
                style = "flex: 1; min-width: 0;",
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
                  ),
                  tags$div(
                    id = ns("comments_display_container"),
                    style = "display: none;",
                    uiOutput(ns("comments_display"))
                  )
                )
              )
            )
            )
          ),

          tabPanel(
            "Evaluate Mappings",
            value = "evaluate_mappings",
            tags$div(
              class = "card-container",
              style = "margin: 10px; height: calc(100vh - 230px); overflow: auto;",
              DT::DTOutput(ns("evaluate_mappings_table")),
              shinyjs::hidden(
                tags$div(
                  id = ns("eval_comment_modal"),
                  class = "modal-overlay",
                  tags$div(
                    class = "modal-content",
                    style = "width: 600px;",
                    tags$div(
                      class = "modal-header",
                      tags$h3("Edit Evaluation Comment"),
                      tags$button(
                        class = "modal-close",
                        onclick = sprintf("$('#%s').hide();", ns("eval_comment_modal")),
                        "×"
                      )
                    ),
                    tags$div(
                      class = "modal-body",
                      tags$div(
                        style = "margin-bottom: 15px;",
                        tags$strong("Mapping:"),
                        tags$div(
                          id = ns("eval_comment_mapping_info"),
                          style = "margin-top: 5px; padding: 10px; background: #f8f9fa; border-radius: 4px;"
                        )
                      ),
                      tags$div(
                        style = "margin-bottom: 15px;",
                        tags$label("Comment:", style = "display: block; margin-bottom: 5px;"),
                        tags$textarea(
                          id = ns("eval_comment_text"),
                          style = "width: 100%; min-height: 100px; padding: 8px; border: 1px solid #ddd; border-radius: 4px;",
                          placeholder = "Enter your comment here..."
                        )
                      ),
                      tags$div(
                        style = "display: flex; gap: 10px; justify-content: flex-end;",
                        tags$button(
                          class = "btn-secondary-custom",
                          onclick = sprintf("$('#%s').hide();", ns("eval_comment_modal")),
                          tags$i(class = "fas fa-times"),
                          " Cancel"
                        ),
                        actionButton(
                          ns("save_eval_comment"),
                          "Save Comment",
                          class = "btn-primary-custom",
                          icon = icon("save")
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
              icon = icon("comment"),
              style = "height: 32px; padding: 5px 15px; font-size: 14px;"
            )
          } else {
            actionButton(
              ns("back_to_mappings"),
              "Back to Mapped Concepts",
              class = "btn-secondary-custom",
              style = "height: 32px; padding: 5px 15px; font-size: 14px;",
              icon = icon("arrow-left")
            )
          }
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

      # Check if file exists
      if (!file.exists(csv_path)) {
        output$summary_content <- renderUI({
          tags$div("CSV file not found")
        })
        return()
      }

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Calculate statistics
      total_source_concepts <- nrow(df)
      mapped_source_concepts <- sum(!is.na(df$target_general_concept_id))
      pct_mapped_source <- if (total_source_concepts > 0) {
        round((mapped_source_concepts / total_source_concepts) * 100, 1)
      } else {
        0
      }

      # Get all general concepts mapped
      mapped_general_concept_ids <- unique(df$target_general_concept_id[!is.na(df$target_general_concept_id)])
      total_general_concepts <- length(mapped_general_concept_ids)

      # Calculate percentage of dictionary coverage
      total_dictionary_concepts <- nrow(data()$general_concepts)
      pct_general_concepts <- if (total_dictionary_concepts > 0) {
        round((total_general_concepts / total_dictionary_concepts) * 100, 1)
      } else {
        0
      }

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
          style = "height: calc(100vh - 230px);",

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
                "Mapped Concepts"
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
                "General Concepts Mapped"
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
                "Evaluated Mappings"
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

          # Use Cases Compatibility Section
          tags$div(
            tags$div(
              class = "card-container",
              style = "margin: 20px 10px 10px 10px; height: calc(100vh - 400px); overflow: auto;",
              tags$div(
                class = "section-header",
                style = "background: none; border-bottom: none; padding: 0 0 0 5px;",
                tags$span(
                  class = "section-title",
                  "Use Cases Compatibility"
                )
              ),
              DT::DTOutput(ns("use_cases_compatibility_table"))
            )
          )
        )
      })
    })

    #### Use Cases Compatibility Table ----
    observe_event(use_cases_compatibility_table_trigger(), {
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()

      output$use_cases_compatibility_table <- DT::renderDT({
        # Get use cases and concept assignments
        use_cases <- data()$use_cases
        general_concept_use_cases <- data()$general_concept_use_cases

        if (is.null(use_cases) || nrow(use_cases) == 0) {
          return(create_empty_datatable("No use cases defined"))
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

        # Build use case compatibility table
        uc_compat <- use_cases %>%
          dplyr::rowwise() %>%
          dplyr::mutate(
            total_concepts = {
              if (is.null(general_concept_use_cases)) {
                0L
              } else {
                current_uc_id <- use_case_id
                nrow(general_concept_use_cases %>%
                  dplyr::filter(use_case_id == current_uc_id))
              }
            },
            mapped_concepts = {
              if (is.null(general_concept_use_cases)) {
                0L
              } else {
                current_uc_id <- use_case_id
                required_gc_ids <- general_concept_use_cases %>%
                  dplyr::filter(use_case_id == current_uc_id) %>%
                  dplyr::pull(general_concept_id)
                sum(required_gc_ids %in% mapped_general_concept_ids)
              }
            },
            covered = ifelse(total_concepts > 0 && mapped_concepts == total_concepts, "Yes", "No")
          ) %>%
          dplyr::ungroup() %>%
          dplyr::select(use_case_name, short_description, total_concepts, mapped_concepts, covered)

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
            columnDefs = list(
              list(targets = 2, width = "100px", className = "dt-center"),
              list(targets = 3, width = "100px", className = "dt-center"),
              list(targets = 4, width = "80px", className = "dt-center")
            )
          ),
          colnames = c("Name", "Description", "Total Concepts", "Mapped Concepts", "Covered")
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

      # Prepare all data outside renderDT
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) {
        output$all_mappings_table_main <- DT::renderDT({
          create_empty_datatable("No alignment selected")
        }, server = TRUE)
        return()
      }

      file_id <- alignment$file_id[1]

      # Get CSV path
      mapping_dir <- get_app_dir("concept_mapping")
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Check if file exists
      if (!file.exists(csv_path)) {
        output$all_mappings_table_main <- DT::renderDT({
          create_empty_datatable("CSV file not found")
        }, server = TRUE)
        return()
      }

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Filter only rows with mappings
      if (!"target_general_concept_id" %in% colnames(df)) {
        output$all_mappings_table_main <- DT::renderDT({
          create_empty_datatable("No mappings created yet.")
        }, server = TRUE)
        return()
      }

      # Rename source columns to avoid conflicts with joined data
      df <- df %>%
        dplyr::rename(
          concept_name_source = concept_name,
          vocabulary_id_source = vocabulary_id,
          concept_code_source = concept_code
        )

      # Rename mapping_id to csv_mapping_id to avoid conflict with db mapping_id
      if ("mapping_id" %in% colnames(df)) {
        df <- df %>% dplyr::rename(csv_mapping_id = mapping_id)
      }

      mapped_rows <- df %>%
        dplyr::filter(!is.na(target_general_concept_id))

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

      # Get vote statistics from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (file.exists(db_path)) {
        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        # First get mapping_id from database by matching csv_file_path and csv_mapping_id
        mapping_ids_query <- "
          SELECT
            cm.mapping_id as db_mapping_id,
            cm.csv_mapping_id
          FROM concept_mappings cm
          WHERE cm.alignment_id = ? AND cm.csv_file_path = ?
        "
        db_mappings <- DBI::dbGetQuery(con, mapping_ids_query, params = list(selected_alignment_id(), csv_path))

        # Join to get the database mapping_id using the csv_mapping_id column from CSV
        enriched_rows <- enriched_rows %>%
          dplyr::left_join(db_mappings, by = "csv_mapping_id")

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
          Target = paste0(
            general_concept_name, " > ",
            concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"
          ),
          Upvotes = ifelse(is.na(upvotes), 0L, as.integer(upvotes)),
          Downvotes = ifelse(is.na(downvotes), 0L, as.integer(downvotes)),
          Uncertain = ifelse(is.na(uncertain_votes), 0L, as.integer(uncertain_votes)),
          Actions = sprintf(
            '<button class="dt-action-btn dt-action-btn-danger delete-mapping-btn" data-id="%d">Delete</button>',
            db_mapping_id
          )
        ) %>%
        dplyr::select(Source, Target, Upvotes, Downvotes, Uncertain, Actions)

      # Render table with prepared data
      output$all_mappings_table_main <- DT::renderDT({
        dt <- datatable(
          display_df,
          escape = FALSE,
          filter = 'top',
          options = list(
            pageLength = 15,
            lengthMenu = c(10, 15, 20, 50, 100, 200),
            dom = 'ltp',
            columnDefs = list(
              list(targets = 2, width = "60px", className = "dt-center"),
              list(targets = 3, width = "60px", className = "dt-center"),
              list(targets = 4, width = "60px", className = "dt-center"),
              list(targets = 5, searchable = FALSE, orderable = FALSE, className = "dt-center")
            )
          ),
          rownames = FALSE,
          selection = 'none',
          colnames = c("Source Concept", "Target Concept", "Upvotes", "Downvotes", "Uncertain", "Actions")
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

      # Prepare updated data (same logic as initial render)
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      mapping_dir <- get_app_dir("concept_mapping")

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      if (!file.exists(csv_path)) return()

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      if (!"target_general_concept_id" %in% colnames(df)) return()

      # Rename source columns to avoid conflicts with joined data
      df <- df %>%
        dplyr::rename(
          concept_name_source = concept_name,
          vocabulary_id_source = vocabulary_id,
          concept_code_source = concept_code
        )

      # Rename mapping_id to csv_mapping_id to avoid conflict with db mapping_id
      if ("mapping_id" %in% colnames(df)) {
        df <- df %>% dplyr::rename(csv_mapping_id = mapping_id)
      }

      mapped_rows <- df %>%
        dplyr::filter(!is.na(target_general_concept_id))

      if (nrow(mapped_rows) == 0) {
        # Force full re-render when table becomes empty
        all_mappings_table_trigger(all_mappings_table_trigger() + 1)
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

      # Get vote statistics from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (file.exists(db_path)) {
        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        # First get mapping_id from database by matching csv_file_path and csv_mapping_id
        mapping_ids_query <- "
          SELECT
            cm.mapping_id as db_mapping_id,
            cm.csv_mapping_id
          FROM concept_mappings cm
          WHERE cm.alignment_id = ? AND cm.csv_file_path = ?
        "
        db_mappings <- DBI::dbGetQuery(con, mapping_ids_query, params = list(selected_alignment_id(), csv_path))

        # Join to get the database mapping_id using the csv_mapping_id column from CSV
        enriched_rows <- enriched_rows %>%
          dplyr::left_join(db_mappings, by = "csv_mapping_id")

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
          Target = paste0(
            general_concept_name, " > ",
            concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"
          ),
          Upvotes = ifelse(is.na(upvotes), 0L, as.integer(upvotes)),
          Downvotes = ifelse(is.na(downvotes), 0L, as.integer(downvotes)),
          Uncertain = ifelse(is.na(uncertain_votes), 0L, as.integer(uncertain_votes)),
          Actions = sprintf(
            '<button class="dt-action-btn dt-action-btn-danger delete-mapping-btn" data-id="%d">Delete</button>',
            db_mapping_id
          )
        ) %>%
        dplyr::select(Source, Target, Upvotes, Downvotes, Uncertain, Actions)

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
            dom = 'ltp'
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
        dplyr::select(omop_concept_id, concept_name, concept_code, vocabulary_id, standard_concept, recommended)

      # Render table with prepared data only
      output$mapped_concepts_table <- DT::renderDT({
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
        custom_concepts_path <- get_package_dir("extdata", "csv", "custom_concepts.csv")
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
            columnDefs = list(
              list(targets = 2, className = "dt-center")
            )
          ),
          rownames = FALSE,
          selection = 'none',
          colnames = c("Source Concept", "Target Concept", "Actions")
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
      if (!is.null(input$mapping_tabs) && input$mapping_tabs != "edit_mappings") return()
      
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
      
      standard_cols <- c("vocabulary_id", "concept_code", "concept_name", "statistical_summary")
      available_standard <- standard_cols[standard_cols %in% colnames(df)]
      target_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id", "mapping_id")
      other_cols <- setdiff(colnames(df), c(standard_cols, target_cols, "Mapped"))
      df_display <- df[, c(available_standard, other_cols, "Mapped"), drop = FALSE]
      
      nice_names <- colnames(df_display)
      nice_names[nice_names == "vocabulary_id"] <- "Vocabulary"
      nice_names[nice_names == "concept_code"] <- "Code"
      nice_names[nice_names == "concept_name"] <- "Name"
      nice_names[nice_names == "statistical_summary"] <- "Summary"
      
      mapped_col_index <- which(colnames(df_display) == "Mapped") - 1
      
      # Render table with prepared data only
      output$source_concepts_table <- DT::renderDT({
        dt <- datatable(
          df_display,
          filter = "top",
          extensions = "Buttons",
          options = list(
            pageLength = 15,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100), c("5", "10", "15", "20", "50", "100")),
            dom = "Bltp",
            buttons = list(
              list(
                extend = "colvis",
                text = "Show/Hide Columns"
              )
            ),
            columnDefs = list(
              list(targets = mapped_col_index, width = "80px", className = "dt-center")
            )
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
    observe_event(data(), {
      # Check visibility first
      if (is.null(data())) return()
      if (mapping_view() != "general") return()
      if (!is.null(input$mapping_tabs) && input$mapping_tabs != "edit_mappings") return()
      
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
            columnDefs = list(
              list(targets = 0, visible = FALSE),
              list(targets = 1, width = "200px")
            )
          ),
          rownames = FALSE,
          selection = "single",
          colnames = c("ID", "Category", "Subcategory", "General Concept")
        )
        
        dt <- add_doubleclick_handler(dt, ns("view_mapped_concepts"))
        
        dt
      }, server = TRUE)
    })
    
    #### Concept Mappings Table Rendering ----
    observe_event(concept_mappings_table_trigger(), {
      # Check visibility first
      if (is.null(selected_general_concept_id())) return()
      if (is.null(data())) return()
      if (!is.null(input$mapping_tabs) && input$mapping_tabs != "edit_mappings") return()
      
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
          recommended = logical(),
          is_custom = logical()
        )
      }
      
      custom_concepts_path <- get_package_dir("extdata", "csv", "custom_concepts.csv")
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
      
      if (nrow(concept_mappings) > 0) {
        omop_for_bind <- concept_mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended, is_custom)
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
          recommended,
          is_custom
        ) %>%
        dplyr::arrange(dplyr::desc(recommended), concept_name) %>%
        dplyr::mutate(
          omop_concept_id = as.character(omop_concept_id),
          recommended = ifelse(recommended, "Yes", "No")
        )
      
      # Render table with prepared data
      output$concept_mappings_table <- DT::renderDT({
        dt <- datatable(
          mappings,
          options = list(
            pageLength = 15,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100), c("5", "10", "15", "20", "50", "100")),
            dom = "ltp",
            columnDefs = list(
              list(targets = 4, width = "100px", className = "dt-center"),
              list(targets = 5, visible = FALSE)
            )
          ),
          rownames = FALSE,
          selection = "single",
          colnames = c("Concept Name", "Vocabulary", "Code", "OMOP ID", "Recommended", "Custom")
        )
        
        dt <- dt %>%
          style_yes_no_column("recommended")

        dt
      }, server = TRUE)
    })

    #### Comments Display ----
    output$comments_display <- renderUI({
      if (is.null(selected_general_concept_id())) return()
      if (is.null(data())) return()

      concept_id <- selected_general_concept_id()
      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
        tags$div(
          class = "comments-container",
          style = "background: #e6f3ff; border: 1px solid #0f60af; border-radius: 6px; height: 100%; overflow-y: auto; box-sizing: border-box;",
          tags$div(
            class = "markdown-content",
            style = "padding: 0 15px 15px 15px;",
            shiny::markdown(concept_info$comments[1])
          )
        )
      } else {
        tags$div(
          style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic; height: 100%; overflow-y: auto; box-sizing: border-box;",
          "No comments available for this concept."
        )
      }
    })
    
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
        
        concept_mappings_omop <- data()$concept_mappings %>%
          dplyr::filter(general_concept_id == target_general_concept_id)
        
        custom_concepts_path <- get_package_dir("extdata", "csv", "custom_concepts.csv")
        custom_concepts_filtered <- data.frame()
        if (file.exists(custom_concepts_path)) {
          custom_concepts_all <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
          custom_concepts_filtered <- custom_concepts_all %>%
            dplyr::filter(general_concept_id == target_general_concept_id)
        }
        
        total_omop <- nrow(concept_mappings_omop)
        total_custom <- nrow(custom_concepts_filtered)
        total_concepts <- total_omop + total_custom
        
        if (mapping_row > total_concepts) return()
        
        if (mapping_row <= total_omop) {
          target_omop_concept_id <- concept_mappings_omop$omop_concept_id[mapping_row]
          target_custom_concept_id <- NA_integer_
        } else {
          custom_row <- mapping_row - total_omop
          target_omop_concept_id <- NA_integer_
          target_custom_concept_id <- custom_concepts_filtered$custom_concept_id[custom_row]
        }
      } else {
        general_concepts <- data()$general_concepts
        target_general_concept_id <- general_concepts$general_concept_id[general_row]
        
        if (is.na(target_general_concept_id)) return()
        
        concept_mappings_dict <- data()$concept_mappings %>%
          dplyr::filter(general_concept_id == target_general_concept_id, recommended == TRUE)
        
        target_omop_concept_id <- NA_integer_
        target_custom_concept_id <- NA_integer_
        if (nrow(concept_mappings_dict) > 0) {
          target_omop_concept_id <- concept_mappings_dict$omop_concept_id[1]
        }
      }
      
      csv_mapping_id <- df$mapping_id[source_row]
      
      con <- get_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)
      
      existing <- DBI::dbGetQuery(
        con,
        "SELECT mapping_id FROM concept_mappings WHERE csv_file_path = ? AND csv_mapping_id = ?",
        params = list(csv_path, csv_mapping_id)
      )
      
      mapping_datetime <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      user_id <- if (!is.null(current_user())) current_user()$user_id else NA_integer_
      
      if (nrow(existing) > 0) {
        DBI::dbExecute(
          con,
          "UPDATE concept_mappings SET
            target_general_concept_id = ?,
            target_omop_concept_id = ?,
            target_custom_concept_id = ?,
            mapped_by_user_id = ?,
            mapping_datetime = ?
          WHERE csv_file_path = ? AND csv_mapping_id = ?",
          params = list(
            target_general_concept_id,
            target_omop_concept_id,
            target_custom_concept_id,
            user_id,
            mapping_datetime,
            csv_path,
            csv_mapping_id
          )
        )
      } else {
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
      }
      
      if (!"target_general_concept_id" %in% colnames(df)) df$target_general_concept_id <- NA_integer_
      if (!"target_omop_concept_id" %in% colnames(df)) df$target_omop_concept_id <- NA_integer_
      if (!"target_custom_concept_id" %in% colnames(df)) df$target_custom_concept_id <- NA_integer_
      if (!"mapped_by_user_id" %in% colnames(df)) df$mapped_by_user_id <- NA_integer_
      if (!"mapping_datetime" %in% colnames(df)) df$mapping_datetime <- NA_character_
      
      df$target_general_concept_id[source_row] <- target_general_concept_id
      df$target_omop_concept_id[source_row] <- target_omop_concept_id
      df$target_custom_concept_id[source_row] <- target_custom_concept_id
      df$mapped_by_user_id[source_row] <- user_id
      df$mapping_datetime[source_row] <- mapping_datetime
      write.csv(df, csv_path, row.names = FALSE)

      source_concepts_table_trigger(source_concepts_table_trigger() + 1)
      all_mappings_table_trigger(all_mappings_table_trigger() + 1)
      evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
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

        # Read CSV to get source concept names
        csv_path <- mappings_db$csv_file_path[1]
        if (!file.exists(csv_path)) return()

        df <- read.csv(csv_path, stringsAsFactors = FALSE)

        # Enrich with source concept information
        enriched_data <- mappings_db %>%
          dplyr::rowwise() %>%
          dplyr::mutate(
            source_concept_name = {
              if (csv_mapping_id <= nrow(df)) {
                df$concept_name[csv_mapping_id]
              } else {
                NA_character_
              }
            },
            source_concept_code = {
              if (csv_mapping_id <= nrow(df)) {
                df$concept_code[csv_mapping_id]
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
              is.na(is_approved) ~ "Not Evaluated",
              is_approved == 1 ~ "Approved",
              is_approved == 0 ~ "Rejected",
              is_approved == -1 ~ "Uncertain",
              TRUE ~ "Not Evaluated"
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
            Source = paste0(source_concept_name, " (", source_concept_code, ")"),
            Target = paste0(
              target_general_concept_name, " > ",
              concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"
            ),
            status = factor(status, levels = c("Not Evaluated", "Approved", "Rejected", "Uncertain"))
          ) %>%
          dplyr::select(
            mapping_id,
            Source,
            Target,
            status,
            Actions
          )

      # Render table with prepared data
      output$evaluate_mappings_table <- DT::renderDT({
        dt <- DT::datatable(
          display_data,
          rownames = FALSE,
          selection = "none",
          escape = FALSE,
          filter = "top",
          options = list(
            pageLength = 15,
            lengthMenu = c(10, 15, 20, 50, 100, 200),
            dom = "ltp",
            ordering = TRUE,
            autoWidth = FALSE,
            columnDefs = list(
              list(targets = 0, visible = FALSE),
              list(targets = 1, width = "35%"),
              list(targets = 2, width = "35%"),
              list(targets = 3, width = "12%"),
              list(targets = 4, width = "18%", orderable = FALSE, searchable = FALSE, className = "dt-center")
            ),
            drawCallback = DT::JS("
              function(settings) {
                console.log('DataTable drawn, buttons should be visible');
              }
            ")
          ),
          colnames = c(
            "ID",
            "Source Concept",
            "Target Concept",
            "Status",
            "Actions"
          )
        ) %>%
          DT::formatStyle(
            "status",
            backgroundColor = DT::styleEqual(
              c("Approved", "Rejected", "Uncertain", "Not Evaluated"),
              c("#d4edda", "#f8d7da", "#fff3cd", "#e7e7e7")
            ),
            color = DT::styleEqual(
              c("Approved", "Rejected", "Uncertain", "Not Evaluated"),
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

      # Read CSV to get source concept names
      csv_path <- mappings_db$csv_file_path[1]
      if (!file.exists(csv_path)) return()

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Enrich with source concept information
      enriched_data <- mappings_db %>%
        dplyr::rowwise() %>%
        dplyr::mutate(
          source_concept_name = {
            if (csv_mapping_id <= nrow(df)) {
              df$concept_name[csv_mapping_id]
            } else {
              NA_character_
            }
          },
          source_concept_code = {
            if (csv_mapping_id <= nrow(df)) {
              df$concept_code[csv_mapping_id]
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
            is.na(is_approved) ~ "Not Evaluated",
            is_approved == 1 ~ "Approved",
            is_approved == 0 ~ "Rejected",
            is_approved == -1 ~ "Uncertain",
            TRUE ~ "Not Evaluated"
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

      # Build display columns
      display_data <- enriched_data %>%
        dplyr::mutate(
          Source = paste0(source_concept_name, " (", source_concept_code, ")"),
          Target = paste0(
            target_general_concept_name, " > ",
            concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"
          ),
          status = factor(status, levels = c("Not Evaluated", "Approved", "Rejected", "Uncertain"))
        ) %>%
        dplyr::select(
          mapping_id,
          Source,
          Target,
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

    #### Handle Comment Editing ----
    observe_event(input$eval_table_dblclick, {
      if (is.null(input$eval_table_dblclick)) return()

      mapping_id <- input$eval_table_dblclick$mapping_id
      source_text <- input$eval_table_dblclick$source
      target_text <- input$eval_table_dblclick$target

      selected_eval_mapping_id(mapping_id)

      # Update modal info
      shinyjs::html("eval_comment_mapping_info", sprintf(
        "<strong>Source:</strong> %s<br><strong>Target:</strong> %s",
        source_text, target_text
      ))

      # Get current comment from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (file.exists(db_path)) {
        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        existing_comment <- DBI::dbGetQuery(
          con,
          "SELECT comment FROM mapping_evaluations
           WHERE mapping_id = ? AND evaluator_user_id = ?",
          params = list(mapping_id, current_user()$user_id)
        )

        comment_value <- if (nrow(existing_comment) > 0 && !is.na(existing_comment$comment[1])) {
          existing_comment$comment[1]
        } else {
          ""
        }

        updateTextAreaInput(session, "eval_comment_text", value = comment_value)
      }

      # Show modal
      shinyjs::show("eval_comment_modal")
    }, ignoreInit = TRUE)

    #### Save Comment ----
    observe_event(input$save_eval_comment, {
      if (is.null(selected_eval_mapping_id())) return()
      if (is.null(current_user())) return()

      mapping_id <- selected_eval_mapping_id()
      user_id <- current_user()$user_id
      comment_text <- input$eval_comment_text
      timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

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
           SET comment = ?, evaluated_at = ?
           WHERE mapping_id = ? AND evaluator_user_id = ?",
          params = list(comment_text, timestamp, mapping_id, user_id)
        )
      } else {
        # Insert new evaluation with comment only
        DBI::dbExecute(
          con,
          "INSERT INTO mapping_evaluations
           (alignment_id, mapping_id, evaluator_user_id, comment, evaluated_at)
           VALUES (?, ?, ?, ?, ?)",
          params = list(selected_alignment_id(), mapping_id, user_id, comment_text, timestamp)
        )
      }

      # Hide modal
      shinyjs::hide("eval_comment_modal")

      # Trigger refresh
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    }, ignoreInit = TRUE)
  })
}
