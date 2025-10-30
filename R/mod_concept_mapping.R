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
              shiny::textAreaInput(
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
              style = "display: flex; gap: 20px; height: 60vh;",
              # Left: Upload and column mapping
              tags$div(
                style = "flex: 1; display: flex; flex-direction: column;",
                tags$div(
                  style = "margin-bottom: 20px;",
                  tags$label("Upload CSV File", style = "display: block; font-weight: 600; margin-bottom: 8px;"),
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
                ),
                tags$div(
                  style = "flex: 1; display: flex; flex-direction: column; gap: 15px; overflow-y: auto;",
                  uiOutput(ns("column_mapping_title")),
                  uiOutput(ns("column_mapping_controls"))
                )
              ),
              # Right: File preview
              tags$div(
                style = "flex: 1; display: flex; flex-direction: column;",
                tags$div(
                  style = "flex: 1; overflow: auto; border: 1px solid #dee2e6; border-radius: 4px;",
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
            tags$button(
              class = "btn btn-secondary btn-secondary-custom",
              onclick = sprintf("$('#%s').hide();", ns("alignment_modal")),
              "Cancel"
            ),
            actionButton(
              ns("alignment_modal_back"),
              "Back",
              class = "btn-secondary-custom",
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
#' @importFrom shiny moduleServer reactive req renderUI observeEvent reactiveVal
#' @importFrom DT renderDT datatable formatStyle DTOutput
#' @importFrom dplyr filter select mutate arrange
#' @importFrom htmltools tags tagList HTML
mod_concept_mapping_server <- function(id, data, config, vocabularies) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Track current view and navigation state
    current_view <- reactiveVal("alignments")  # "alignments" or "mapping"
    selected_alignment_id <- reactiveVal(NULL)  # Track selected alignment for mapping
    mapping_view <- reactiveVal("general")  # "general" or "mapped" - for nested navigation
    selected_general_concept_id <- reactiveVal(NULL)  # Track selected general concept
    modal_page <- reactiveVal(1)  # Track modal page (1 or 2)
    modal_mode <- reactiveVal("add")  # "add" or "edit"
    alignment_to_delete <- reactiveVal(NULL)  # Track alignment ID to delete

    # Load existing alignments from database
    initial_alignments <- get_all_alignments()

    # Store alignments data
    alignments_data <- reactiveVal(initial_alignments)

    # Store uploaded file data for current alignment
    uploaded_alignment_data <- reactiveVal(NULL)

    # Render breadcrumb navigation
    output$breadcrumb <- renderUI({
      if (current_view() == "alignments") {
        NULL
      } else if (current_view() == "mapping") {
        req(selected_alignment_id())
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
              style = "font-size: 16px; color: #333; font-weight: 600;",
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
                style = "font-size: 16px; color: #0f60af; font-weight: 600;",
                "Mapped Concepts"
              )
            )
          }
        )
      }
    })

    # Render main content area
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

    # Render General Concepts header with breadcrumb
    output$general_concepts_header <- renderUI({
      # Only show in mapping view with general view
      if (current_view() != "mapping" || mapping_view() != "general") return(NULL)

      # Check if a general concept is selected
      if (is.null(selected_general_concept_id())) {
        # No selection: show simple title
        tags$div(
          class = "section-header",
          style = "height: 40px;",
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
        req(data())

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
          style = "height: 40px; justify-content: space-between;",
          tags$div(
            style = "display: flex; align-items: center; gap: 10px;",
            tags$a(
              class = "breadcrumb-link",
              style = "font-size: 14px; cursor: pointer;",
              onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_general_list")),
              "General Concepts"
            ),
            tags$span(style = "color: #6c757d; font-size: 14px;", ">"),
            tags$span(
              style = "font-size: 14px; color: #333; font-weight: 600;",
              concept_name
            )
          ),
          # Add Mapping button
          actionButton(
            ns("add_mapping_from_general"),
            "Add Mapping",
            class = "btn-success-custom",
            style = "height: 32px; padding: 5px 15px; font-size: 14px; display: none;"
          )
        )
      }
    })

    # Render right table (general concepts or mapped concepts)
    output$right_table_output <- renderUI({
      if (current_view() != "mapping" || mapping_view() != "general") return(NULL)

      if (is.null(selected_general_concept_id())) {
        # Show general concepts table
        DT::DTOutput(ns("general_concepts_table"))
      } else {
        # Show mapped concepts table
        DT::DTOutput(ns("concept_mappings_table"))
      }
    })

    # View 1: Alignments management
    render_alignments_view <- function() {
      tags$div(
        style = "padding: 20px;",
        # Title and button header
        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 0; display: flex; align-items: center; gap: 15px; justify-content: space-between;",
          # Left side: Title
          tags$div(
            style = "font-size: 16px; color: #0f60af; font-weight: 600;",
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
          style = "background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
          DT::DTOutput(ns("alignments_table"))
        )
      )
    }

    # View 2: Mapping realization interface
    render_mapping_view <- function() {
      tags$div(
        style = "display: flex; flex-direction: column; height: calc(100vh - 185px); gap: 15px;",
        # Top section: Source concepts (left) and target concepts (right)
        tags$div(
          style = "flex: 1; display: flex; gap: 15px; min-height: 0;",
          # Left: Source concepts to map
          tags$div(
            style = "flex: 1; display: flex; flex-direction: column; background: white; border-radius: 8px; padding: 15px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
            tags$div(
              class = "section-header",
              style = "height: 40px;",
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
              style = "flex: 1; min-height: 0; overflow: hidden;",
              DT::DTOutput(ns("source_concepts_table"))
            )
          ),
          # Right: Target concepts (general concepts or mapped concepts)
          tags$div(
            style = "flex: 1; display: flex; flex-direction: column; background: white; border-radius: 8px; padding: 15px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
            uiOutput(ns("general_concepts_header")),
            tags$div(
              style = "flex: 1; min-height: 0; overflow: hidden;",
              uiOutput(ns("right_table_output"))
            )
          )
        ),
        # Bottom section: Realized mappings
        tags$div(
          style = "flex: 0 0 40%; display: flex; flex-direction: column; background: white; border-radius: 8px; padding: 15px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
          tags$div(
            class = "section-header",
            style = "height: 40px;",
            tags$h4(
              "Realized Mappings",
              tags$span(
                class = "info-icon",
                `data-tooltip` = "Mappings between your source concepts and INDICATE concepts that you have created",
                "ⓘ"
              )
            )
          ),
          tags$div(
            style = "flex: 1; min-height: 0; overflow: hidden;",
            DT::DTOutput(ns("realized_mappings_table"))
          )
        )
      )
    }

    # Nested view: Mapped concepts for selected general concept
    render_mapped_concepts_view <- function() {
      tags$div(
        style = "display: flex; flex-direction: column; height: calc(100vh - 185px); gap: 15px;",
        # Top section: Source concepts (left) and mapped concepts (right)
        tags$div(
          style = "flex: 1; display: flex; gap: 15px; min-height: 0;",
          # Left: Source concepts to map
          tags$div(
            style = "flex: 1; display: flex; flex-direction: column; background: white; border-radius: 8px; padding: 15px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
            tags$div(
              class = "section-header",
              style = "height: 40px;",
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
              style = "flex: 1; min-height: 0; overflow: hidden;",
              DT::DTOutput(ns("source_concepts_table_mapped"))
            )
          ),
          # Right: Mapped concepts (OMOP concepts for selected general concept)
          tags$div(
            style = "flex: 1; display: flex; flex-direction: column; background: white; border-radius: 8px; padding: 15px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
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
        # Bottom section: Realized mappings
        tags$div(
          style = "flex: 0 0 40%; display: flex; flex-direction: column; background: white; border-radius: 8px; padding: 15px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
          tags$div(
            class = "section-header",
            style = "height: 40px;",
            tags$h4(
              "Realized Mappings",
              tags$span(
                class = "info-icon",
                `data-tooltip` = "Mappings between your source concepts and INDICATE concepts that you have created",
                "ⓘ"
              )
            )
          ),
          tags$div(
            style = "flex: 1; min-height: 0; overflow: hidden;",
            DT::DTOutput(ns("realized_mappings_table_mapped"))
          )
        )
      )
    }

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
             <button class="btn btn-sm btn-danger" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Delete</button>',
            ns("open_alignment"), alignment_id,
            ns("edit_alignment"), alignment_id,
            ns("delete_alignment"), alignment_id
          )
        ) %>%
        dplyr::select(name, description, created_formatted, Actions)

      datatable(
        alignments_display,
        escape = FALSE,
        rownames = FALSE,
        selection = 'none',
        options = list(
          pageLength = 25,
          dom = 'ftp',
          columnDefs = list(
            list(targets = 3, orderable = FALSE, width = "220px")
          )
        ),
        colnames = c("Name", "Description", "Created", "Actions")
      )
    }, server = FALSE)

    # Handle navigation: back to alignments list
    observeEvent(input$back_to_alignments, {
      current_view("alignments")
      selected_alignment_id(NULL)
      mapping_view("general")
      selected_general_concept_id(NULL)
    })

    # Handle navigation: back to general concepts in mapping view
    observeEvent(input$back_to_general, {
      mapping_view("general")
      selected_general_concept_id(NULL)
    })

    # Handle double-click on general concept (show mapped concepts in same view)
    observeEvent(input$view_mapped_concepts, {
      general_concept_id <- input$view_mapped_concepts
      selected_general_concept_id(general_concept_id)
      # Stay in mapping_view("general"), just change selected_general_concept_id
    })

    # Handle back to general concepts list
    observeEvent(input$back_to_general_list, {
      selected_general_concept_id(NULL)
    })

    # Handle open alignment (navigate to mapping view)
    observeEvent(input$open_alignment, {
      selected_alignment_id(input$open_alignment)
      current_view("mapping")
      mapping_view("general")
    })

    # Hide error message when user starts typing
    observeEvent(input$alignment_name, {
      if (!is.null(input$alignment_name) && input$alignment_name != "") {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_name_error")))
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))
      }
    })

    # Handle add alignment button
    observeEvent(input$add_alignment, {

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
    observeEvent(input$edit_alignment, {
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

        # Show modal
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal")))
      }
    })

    # Handle delete alignment button
    observeEvent(input$delete_alignment, {
      alignment_id <- input$delete_alignment
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
    observeEvent(input$confirm_delete_alignment, {
      req(alignment_to_delete())

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


    # Render column mapping title only when file is uploaded
    output$column_mapping_title <- renderUI({
      req(input$alignment_file)
      tags$h5("Column Mapping", style = "margin: 0;")
    })

    # Render column mapping controls based on uploaded file
    output$column_mapping_controls <- renderUI({
      req(input$alignment_file)

      # Read file to get column names
      file_path <- input$alignment_file$datapath
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext == "csv") {
        df <- read.csv(file_path, nrows = 1)
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
          style = "display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 15px;",
          # Column 1
          tags$div(
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
          style = "display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 15px;",
          # Column 1
          tags$div(
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
          style = "margin-bottom: 15px;",
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

    # Render file preview
    output$file_preview_table <- DT::renderDT({
      req(input$alignment_file)

      file_path <- input$alignment_file$datapath
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext == "csv") {
        df <- read.csv(file_path)
      } else if (file_ext %in% c("xlsx", "xls")) {
        df <- readxl::read_excel(file_path)
      } else {
        return(NULL)
      }

      datatable(
        df,
        options = list(
          pageLength = 10,
          dom = 'tp',
          scrollX = TRUE,
          ordering = FALSE
        ),
        rownames = FALSE,
        selection = 'none',
        filter = 'none',
        class = 'display'
      )
    }, server = FALSE)

    # Handle modal navigation
    observeEvent(input$alignment_modal_next, {
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

        # Change modal width for page 2
        shinyjs::runjs(sprintf("$('#%s').css('max-width', '90vw');", ns("alignment_modal_dialog")))

        # Update buttons and indicator
        shinyjs::runjs(sprintf("$('#%s').text('Page 2 of 2');", ns("modal_page_indicator")))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_back")))
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_next")))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_save")))
      }
    })

    observeEvent(input$alignment_modal_back, {
      if (modal_page() == 2) {
        # Move back to page 1
        modal_page(1)

        # Show page 1, hide page 2
        shinyjs::show(id = "modal_page_1")
        shinyjs::hide(id = "modal_page_2")

        # Change modal width back for page 1
        shinyjs::runjs(sprintf("$('#%s').css('max-width', '600px');", ns("alignment_modal_dialog")))

        # Update buttons and indicator
        shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 2');", ns("modal_page_indicator")))
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_back")))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_next")))
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_save")))
      }
    })

    # Hide file upload error when file is uploaded
    observeEvent(input$alignment_file, {
      if (!is.null(input$alignment_file)) {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_file_error")))
      }
    })

    # Hide column mapping errors when selections are made
    observeEvent(input$col_vocabulary_id, {
      if (!is.null(input$col_vocabulary_id) && input$col_vocabulary_id != "") {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("col_vocabulary_id_error")))
      }
    })

    observeEvent(input$col_concept_code, {
      if (!is.null(input$col_concept_code) && input$col_concept_code != "") {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("col_concept_code_error")))
      }
    })

    observeEvent(input$col_concept_name, {
      if (!is.null(input$col_concept_name) && input$col_concept_name != "") {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("col_concept_name_error")))
      }
    })

    observeEvent(input$alignment_modal_save, {

      # Validate all inputs and show error messages
      has_errors <- FALSE

      if (is.null(input$alignment_name) || input$alignment_name == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_name_error")))
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '#dc3545');", ns("alignment_name")))
        has_errors <- TRUE
      }

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

      if (has_errors) {
        return()
      }

      # Save alignment
      if (modal_mode() == "add") {

        # Read uploaded file
        file_path <- input$alignment_file$datapath
        file_ext <- tools::file_ext(input$alignment_file$name)

        if (file_ext == "csv") {
          df <- read.csv(file_path, stringsAsFactors = FALSE)
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
      shinyjs::runjs(sprintf("$('#%s').css('max-width', '600px');", ns("alignment_modal_dialog")))

      # Reset modal button visibility
      shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 2');", ns("modal_page_indicator")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_back")))
      shinyjs::runjs(sprintf("$('#%s').show();", ns("alignment_modal_next")))
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("alignment_modal_save")))
    })

    # Source Concepts table - load from CSV
    output$source_concepts_table <- DT::renderDT({
      req(selected_alignment_id())
      req(mapping_view() == "general")  # Only load in general view

      # Get the alignment data
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      req(nrow(alignment) == 1)

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
      other_cols <- setdiff(colnames(df), standard_cols)
      df <- df[, c(available_standard, other_cols), drop = FALSE]

      datatable(
        df,
        filter = 'top',
        options = list(
          pageLength = 8,
          dom = 'tp',
          scrollX = TRUE
        ),
        rownames = FALSE,
        selection = 'single'
      )
    }, server = FALSE)

    output$general_concepts_table <- DT::renderDT({
      req(data())

      # Only show when in general view
      req(mapping_view() == "general")

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
          dom = 'tp',
          scrollX = TRUE,
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
      dt$x$options$drawCallback <- htmlwidgets::JS(sprintf("
        function(settings) {
          var table = settings.oInstance.api();
          $(table.table().node()).off('dblclick', 'tbody tr');
          $(table.table().node()).on('dblclick', 'tbody tr', function() {
            var rowData = table.row(this).data();
            if (rowData && rowData[0]) {
              var conceptId = rowData[0];
              Shiny.setInputValue('%s', conceptId, {priority: 'event'});
            }
          });
        }
      ", ns("view_mapped_concepts")))

      dt
    }, server = FALSE)

    output$realized_mappings_table <- DT::renderDT({
      req(selected_alignment_id())

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

      # Build display dataframe
      display_df <- mapped_rows %>%
        dplyr::mutate(
          Source = paste0(concept_name, " (", vocabulary_id, ": ", concept_code, ")"),
          Target = paste0(target_general_concept_name, " (", target_category, " / ", target_subcategory, ")"),
          Actions = sprintf(
            '<button class="btn btn-sm btn-danger" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
            ns("remove_mapping"), dplyr::row_number()
          )
        ) %>%
        dplyr::select(Source, Target, Actions)

      datatable(
        display_df,
        escape = FALSE,
        options = list(pageLength = 10, dom = 'tp'),
        rownames = FALSE,
        selection = 'none',
        colnames = c("Source Concept", "Target Concept", "Actions")
      )
    }, server = FALSE)

    # Concept mappings table for general view (when a general concept is selected)
    output$concept_mappings_table <- DT::renderDT({
      req(selected_general_concept_id())
      req(data())
      req(vocabularies())

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

      # Join with vocabularies to get concept details
      vocabs <- vocabularies()

      # Get concept details from vocabularies
      concept_ids <- concept_mappings$omop_concept_id
      vocab_concepts <- vocabs %>%
        dplyr::filter(concept_id %in% concept_ids) %>%
        dplyr::select(concept_id, concept_name, concept_code, vocabulary_id, standard_concept) %>%
        dplyr::collect()

      mapped_with_details <- concept_mappings %>%
        dplyr::left_join(
          vocab_concepts,
          by = c("omop_concept_id" = "concept_id")
        ) %>%
        dplyr::select(omop_concept_id, concept_name, concept_code, vocabulary_id, standard_concept, recommended) %>%
        dplyr::arrange(dplyr::desc(recommended), concept_name)

      datatable(
        mapped_with_details,
        filter = 'top',
        options = list(
          pageLength = 8,
          dom = 'tp',
          scrollX = TRUE
        ),
        rownames = FALSE,
        selection = 'single',
        colnames = c("OMOP Concept ID", "Concept Name", "Concept Code", "Vocabulary", "Standard", "Recommended")
      )
    }, server = FALSE)

    output$mapped_concepts_table <- DT::renderDT({
      req(selected_general_concept_id())
      req(data())
      req(vocabularies())

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
        filter = 'top',
        options = list(
          pageLength = 25,
          dom = 'tp',
          scrollX = TRUE
        ),
        rownames = FALSE,
        selection = 'single',
        colnames = c("OMOP Concept ID", "Concept Name", "Concept Code", "Vocabulary", "Standard", "Recommended")
      )
    }, server = FALSE)

    # Source concepts table for mapped view (copy of original)
    output$source_concepts_table_mapped <- DT::renderDT({
      req(selected_alignment_id())

      # Get the alignment data
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      req(nrow(alignment) == 1)

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
      other_cols <- setdiff(colnames(df), standard_cols)
      df <- df[, c(available_standard, other_cols), drop = FALSE]

      datatable(
        df,
        filter = 'top',
        options = list(
          pageLength = 8,
          dom = 'tp',
          scrollX = TRUE
        ),
        rownames = FALSE,
        selection = 'single'
      )
    }, server = FALSE)

    # Realized mappings table for mapped view (copy of original)
    output$realized_mappings_table_mapped <- DT::renderDT({
      req(selected_alignment_id())

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

      mapped_rows <- df %>%
        dplyr::filter(!is.na(target_omop_concept_id))

      if (nrow(mapped_rows) == 0) {
        return(datatable(
          data.frame(Message = "No mappings created yet. Select a source concept and a mapped concept, then click 'Add Mapping'."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Join with vocabularies to get target concept details
      req(vocabularies())
      vocabs <- vocabularies()

      display_df <- mapped_rows %>%
        dplyr::left_join(
          vocabs %>% dplyr::select(concept_id, concept_name, vocabulary_id),
          by = c("target_omop_concept_id" = "concept_id")
        ) %>%
        dplyr::mutate(
          Source = paste0(concept_name.x, " (", vocabulary_id.x, ": ", concept_code, ")"),
          Target = paste0(concept_name.y, " (", target_omop_concept_id, ")"),
          Actions = sprintf(
            '<button class="btn btn-sm btn-danger" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
            ns("remove_mapping"), dplyr::row_number()
          )
        ) %>%
        dplyr::select(Source, Target, Actions)

      datatable(
        display_df,
        escape = FALSE,
        options = list(pageLength = 10, dom = 'tp'),
        rownames = FALSE,
        selection = 'none',
        colnames = c("Source Concept", "Target Concept", "Actions")
      )
    }, server = FALSE)

    # Handle Add Mapping button for specific OMOP concept
    observeEvent(input$add_mapping_specific, {
      # Get selected rows from source and mapped concepts tables
      source_row <- input$source_concepts_table_mapped_rows_selected
      mapped_row <- input$mapped_concepts_table_rows_selected

      # Validate selections
      if (is.null(source_row) || is.null(mapped_row)) {
        return()
      }

      # Get alignment info
      req(selected_alignment_id())
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      req(nrow(alignment) == 1)

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
      req(selected_general_concept_id())
      req(data())
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

      # Update the selected row with mapping info
      df$target_general_concept_id[source_row] <- selected_general_concept_id()
      df$target_omop_concept_id[source_row] <- target_mapping$omop_concept_id

      # Save CSV
      write.csv(df, csv_path, row.names = FALSE)

      # Refresh tables will happen automatically due to file change
    })

    # Show/hide Add Mapping button based on selections (for general view with concept mappings)
    observe({
      source_selected <- !is.null(input$source_concepts_table_rows_selected)
      mapped_selected <- !is.null(input$concept_mappings_table_rows_selected)

      if (source_selected && mapped_selected && !is.null(selected_general_concept_id())) {
        shinyjs::show("add_mapping_from_general")
      } else {
        shinyjs::hide("add_mapping_from_general")
      }
    })

    # Handle Add Mapping from general view
    observeEvent(input$add_mapping_from_general, {
      # Get selected rows
      source_row <- input$source_concepts_table_rows_selected
      mapped_row <- input$concept_mappings_table_rows_selected

      # Validate selections
      if (is.null(source_row) || is.null(mapped_row)) {
        return()
      }

      # Get alignment info
      req(selected_alignment_id())
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      req(nrow(alignment) == 1)

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
      req(selected_general_concept_id())
      req(data())
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

      # Update the selected row with mapping info
      df$target_general_concept_id[source_row] <- selected_general_concept_id()
      df$target_omop_concept_id[source_row] <- target_mapping$omop_concept_id

      # Save CSV
      write.csv(df, csv_path, row.names = FALSE)

      # Refresh tables will happen automatically due to file change
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
