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
    concept_mappings_view <- reactiveVal("table")  # "table" or "comments" - for right panel when general concept is selected

    # Load existing alignments from database
    initial_alignments <- get_all_alignments()

    # Store alignments data
    alignments_data <- reactiveVal(initial_alignments)

    # Store uploaded file data for current alignment
    uploaded_alignment_data <- reactiveVal(NULL)

    # Trigger to force refresh of realized mappings table
    mappings_refresh_trigger <- reactiveVal(0)

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
          style = "height: 40px;",
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
            tagList(
              actionButton(
                ns("add_mapping_from_general"),
                "Add Mapping",
                class = "btn-success-custom",
                style = "height: 32px; padding: 5px 15px; font-size: 14px; margin-right: 8px;"
              ),
              actionButton(
                ns("show_comments"),
                "Comments",
                class = "btn-secondary-custom",
                style = "height: 32px; padding: 5px 15px; font-size: 14px;"
              )
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


    # View 1: Alignments management
    render_alignments_view <- function() {
      tags$div(
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
                style = "height: 100%; display: none;",
                uiOutput(ns("comments_display"))
              )
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
        dplyr::select(alignment_id, name, description, created_formatted, Actions)

      dt <- datatable(
        alignments_display,
        escape = FALSE,
        rownames = FALSE,
        selection = 'none',
        filter = 'top',
        options = list(
          pageLength = 25,
          dom = 'tp',
          columnDefs = list(
            list(targets = 0, visible = FALSE),  # Hide alignment_id column
            list(targets = 4, orderable = FALSE, width = "220px", searchable = FALSE)
          )
        ),
        colnames = c("ID", "Name", "Description", "Created", "Actions")
      )

      # Add JavaScript callback for double-click
      dt$x$options$drawCallback <- htmlwidgets::JS(sprintf("
        function(settings) {
          var table = settings.oInstance.api();
          $(table.table().node()).off('dblclick', 'tbody tr');
          $(table.table().node()).on('dblclick', 'tbody tr', function() {
            var rowData = table.row(this).data();
            if (rowData && rowData[0]) {
              var alignmentId = rowData[0];
              Shiny.setInputValue('%s', alignmentId, {priority: 'event'});
            }
          });
        }
      ", ns("open_alignment")))

      dt
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

    # Handle back to general concepts list
    observeEvent(input$back_to_general_list, {
      selected_general_concept_id(NULL)
      concept_mappings_view("table")  # Reset to table view

      # Show/hide appropriate tables
      shinyjs::show("general_concepts_table_container")
      shinyjs::hide("concept_mappings_table_container")
      shinyjs::hide("comments_display_container")
    })

    # Show comments view
    observeEvent(input$show_comments, {
      concept_mappings_view("comments")

      # Show/hide appropriate tables
      shinyjs::hide("concept_mappings_table_container")
      shinyjs::show("comments_display_container")
    })

    # Back to mapped concepts table
    observeEvent(input$back_to_mappings, {
      concept_mappings_view("table")

      # Show/hide appropriate tables
      shinyjs::show("concept_mappings_table_container")
      shinyjs::hide("comments_display_container")
    })

    # Handle when a general concept is selected (show mappings table)
    observeEvent(input$view_mapped_concepts, {
      general_concept_id <- input$view_mapped_concepts
      selected_general_concept_id(general_concept_id)

      # Show/hide appropriate tables
      shinyjs::hide("general_concepts_table_container")
      shinyjs::show("concept_mappings_table_container")
      shinyjs::hide("comments_display_container")

      # Disable Add Mapping button until selections are made
      shinyjs::disable("add_mapping_from_general")
    })

    # Disable Add Mapping button when general concept is selected for the first time
    observeEvent(selected_general_concept_id(), {
      if (!is.null(selected_general_concept_id())) {
        shinyjs::disable("add_mapping_from_general")
      }
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
      target_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_vocabulary_id", "target_concept_code", "target_concept_name")
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
          dom = 'tp',
          scrollX = TRUE,
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
          pageLength = 6,
          dom = 'tp',
          scrollX = TRUE,
          scrollY = TRUE,
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
      req(data())
      general_concepts <- data()$general_concepts

      # Join with general concepts to get names
      enriched_rows <- mapped_rows %>%
        dplyr::left_join(
          general_concepts %>%
            dplyr::select(general_concept_id, general_concept_name, category, subcategory),
          by = c("target_general_concept_id" = "general_concept_id")
        )

      # Use target concept info from CSV (supports both OMOP and custom concepts)
      if ("target_concept_name" %in% colnames(enriched_rows)) {
        enriched_rows <- enriched_rows %>%
          dplyr::rename(
            concept_name_target = target_concept_name,
            vocabulary_id_target = target_vocabulary_id,
            concept_code_target = target_concept_code
          )
      } else {
        # Fallback: enrich with OMOP concept info from vocabularies (for old CSV files)
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
    }, server = TRUE)

    # Concept mappings table for general view (when a general concept is selected)
    output$concept_mappings_table <- DT::renderDT({
      req(selected_general_concept_id())
      req(data())

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
        filter = 'top',
        options = list(
          pageLength = 6,
          dom = 'tp',
          scrollX = TRUE,
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
    output$comments_display <- renderUI({
      req(selected_general_concept_id())
      req(data())

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

      # Use target concept info from CSV (supports both OMOP and custom concepts)
      if ("target_concept_name" %in% colnames(mapped_rows)) {
        display_df <- mapped_rows %>%
          dplyr::mutate(
            Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
            Target = paste0(target_concept_name, " (", target_vocabulary_id, ": ", target_concept_code, ")"),
            Actions = sprintf(
              '<button class="btn btn-sm btn-danger" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
              ns("remove_mapping_mapped"), dplyr::row_number()
            )
          ) %>%
          dplyr::select(Source, Target, Actions)
      } else {
        # Fallback: join with vocabularies to get target concept details (for old CSV files)
        req(vocabularies())
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
              '<button class="btn btn-sm btn-danger" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
              ns("remove_mapping_mapped"), dplyr::row_number()
            )
          ) %>%
          dplyr::select(Source, Target, Actions)
      }

      datatable(
        display_df,
        escape = FALSE,
        options = list(pageLength = 10, dom = 'tp'),
        rownames = FALSE,
        selection = 'none',
        colnames = c("Source Concept", "Target Concept", "Actions")
      )
    }, server = TRUE)

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

      # Force refresh of realized mappings table and source concepts table
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)

      # Deselect rows in concept_mappings_table using DT proxy
      proxy <- DT::dataTableProxy("concept_mappings_table", session)
      DT::selectRows(proxy, NULL)
    })

    # Handle Remove Mapping
    observeEvent(input$remove_mapping, {
      # Get the row number
      row_num <- input$remove_mapping

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

    # Observe mappings_refresh_trigger and reload datatables using proxy
    observeEvent(mappings_refresh_trigger(), {
      # Skip initial trigger
      if (mappings_refresh_trigger() == 0) return()

      req(selected_alignment_id())

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
            target_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_vocabulary_id", "target_concept_code", "target_concept_name")
            other_cols <- setdiff(colnames(df), c(standard_cols, target_cols, "Mapped"))
            df_display <- df[, c(available_standard, other_cols, "Mapped"), drop = FALSE]

            # Update data via proxy
            proxy_source <- DT::dataTableProxy("source_concepts_table", session)
            DT::replaceData(proxy_source, df_display, resetPaging = FALSE, rownames = FALSE)
          }
        }
      }

      # Always reload Realized Mappings table
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

              # Use target concept info from CSV (supports both OMOP and custom concepts)
              if ("target_concept_name" %in% colnames(enriched_rows)) {
                enriched_rows <- enriched_rows %>%
                  dplyr::rename(
                    concept_name_target = target_concept_name,
                    vocabulary_id_target = target_vocabulary_id,
                    concept_code_target = target_concept_code
                  )
              } else {
                # Fallback: enrich with OMOP concept info from vocabularies (for old CSV files)
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
                    '<button class="btn btn-sm btn-danger" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
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

    # Enable/disable Add Mapping button based on selections (for general view with concept mappings)
    observe({
      if (is.null(selected_general_concept_id()) || concept_mappings_view() != "table") {
        return()
      }

      source_selected <- !is.null(input$source_concepts_table_rows_selected)
      mapped_selected <- !is.null(input$concept_mappings_table_rows_selected)

      # Enable/disable button based on selections
      if (source_selected && mapped_selected) {
        shinyjs::enable("add_mapping_from_general")
      } else {
        shinyjs::disable("add_mapping_from_general")
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

      # Get mapped concept info (need to reconstruct the same combined dataframe as in the renderDT)
      req(selected_general_concept_id())
      req(data())

      # Get OMOP concept mappings
      concept_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == selected_general_concept_id())

      # Enrich OMOP concepts with vocabulary data
      vocab_data <- vocabularies()
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

      all_concepts <- dplyr::bind_rows(omop_for_bind, custom_concepts) %>%
        dplyr::arrange(dplyr::desc(recommended), concept_name)

      # Get the selected concept from the combined list
      target_mapping <- all_concepts[mapped_row, ]

      # Add mapping columns if they don't exist
      if (!"target_general_concept_id" %in% colnames(df)) {
        df$target_general_concept_id <- NA_integer_
      }
      if (!"target_omop_concept_id" %in% colnames(df)) {
        df$target_omop_concept_id <- NA_integer_
      }
      if (!"target_vocabulary_id" %in% colnames(df)) {
        df$target_vocabulary_id <- NA_character_
      }
      if (!"target_concept_code" %in% colnames(df)) {
        df$target_concept_code <- NA_character_
      }
      if (!"target_concept_name" %in% colnames(df)) {
        df$target_concept_name <- NA_character_
      }

      # Update the selected row with mapping info
      df$target_general_concept_id[source_row] <- selected_general_concept_id()
      df$target_omop_concept_id[source_row] <- ifelse(is.na(target_mapping$omop_concept_id), NA_integer_, target_mapping$omop_concept_id)
      df$target_vocabulary_id[source_row] <- as.character(target_mapping$vocabulary_id)
      df$target_concept_code[source_row] <- as.character(target_mapping$concept_code)
      df$target_concept_name[source_row] <- as.character(target_mapping$concept_name)

      # Save CSV
      write.csv(df, csv_path, row.names = FALSE)

      # Deselect rows in both tables
      proxy_source <- DT::dataTableProxy("source_concepts_table", session)
      DT::selectRows(proxy_source, NULL)

      proxy_mappings <- DT::dataTableProxy("concept_mappings_table", session)
      DT::selectRows(proxy_mappings, NULL)

      # Force refresh of realized mappings table and source concepts table
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
