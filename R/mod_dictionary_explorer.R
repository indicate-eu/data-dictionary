#' Dictionary Explorer Module - UI
#'
#' @description UI function for the dictionary explorer module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS uiOutput
#' @importFrom htmltools tags tagList
mod_dictionary_explorer_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Main application content
    div(class = "main-panel",
        div(class = "main-content",
            # Breadcrumb navigation
            uiOutput(ns("breadcrumb")),

            # Dynamic content area
            uiOutput(ns("content_area"))
        )
    )
  )
}

#' Dictionary Explorer Module - Server
#'
#' @description Server function for the dictionary explorer module
#'
#' @param id Module ID
#' @param data Reactive containing the CSV data
#' @param config Configuration list
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive req renderUI observeEvent reactiveVal fluidRow column
#' @importFrom DT renderDT datatable formatStyle styleEqual
#' @importFrom dplyr filter left_join arrange group_by summarise n mutate select
#' @importFrom magrittr %>%
#' @importFrom htmltools HTML tags tagList
#' @importFrom htmlwidgets JS
mod_dictionary_explorer_server <- function(id, data, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Track current view and selected concept
    current_view <- reactiveVal("list")  # "list" or "detail"
    selected_concept_id <- reactiveVal(NULL)

    # Render breadcrumb
    output$breadcrumb <- renderUI({
      if (current_view() == "list") {
        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 0; font-size: 16px; color: #0f60af; font-weight: 600;",
          tags$span("General Concepts")
        )
      } else {
        concept_id <- selected_concept_id()
        req(concept_id)

        concept_info <- data()$general_concepts %>%
          dplyr::filter(general_concept_id == concept_id)

        if (nrow(concept_info) > 0) {
          tags$div(
            class = "breadcrumb-nav",
            style = "padding: 10px 0 15px 0; font-size: 16px;",
            tags$a(
              href = "#",
              onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_list")),
              style = "color: #0f60af; text-decoration: none; cursor: pointer; font-weight: 600;",
              "General Concepts"
            ),
            tags$span(
              style = "margin: 0 8px; color: #999;",
              ">"
            ),
            tags$span(
              style = "color: #333; font-weight: 600;",
              concept_info$general_concept_name[1]
            )
          )
        }
      }
    })

    # Render content area
    output$content_area <- renderUI({
      if (current_view() == "list") {
        # Show General Concepts table
        render_general_concepts_table()
      } else {
        # Show concept details
        render_concept_details()
      }
    })

    # Function to render general concepts table
    render_general_concepts_table <- function() {
      tagList(
        tags$div(
          class = "table-container",
          style = "height: calc(100vh - 180px); overflow: auto;",
          DT::DTOutput(ns("general_concepts_table"))
        )
      )
    }

    # Function to render concept details
    render_concept_details <- function() {
      fluidRow(
        # Left panel: Comments and concept mappings
        column(6,
               tags$div(
                 class = "detail-panel-left",
                 style = "height: calc(100vh - 180px); overflow-y: auto;",
                 # Comments section
                 tags$div(
                   class = "section-header",
                   tags$h4("ETL Guidance & Comments")
                 ),
                 uiOutput(ns("comments_display")),

                 # Concept mappings section
                 tags$div(
                   class = "section-header",
                   style = "margin-top: 20px;",
                   tags$h4("Mapped Concepts")
                 ),
                 DT::DTOutput(ns("concept_mappings_table"))
               )
        ),

        # Right panel: Concept relationships (placeholder for now)
        column(6,
               tags$div(
                 class = "detail-panel-right",
                 style = "height: calc(100vh - 180px); overflow-y: auto;",
                 tags$div(
                   class = "section-header",
                   tags$h4("Concept Relationships")
                 ),
                 tags$div(
                   style = "padding: 20px; background: #f8f9fa; border-radius: 6px; text-align: center;",
                   tags$p(
                     style = "color: #666;",
                     "Select a concept from the left panel to view its relationships and hierarchy."
                   )
                 )
               )
        )
      )
    }

    # Render general concepts table
    output$general_concepts_table <- DT::renderDT({
      general_concepts <- data()$general_concepts
      use_case_counts <- data()$general_concept_use_cases %>%
        dplyr::group_by(general_concept_id) %>%
        dplyr::summarise(use_case_count = dplyr::n(), .groups = "drop")

      table_data <- general_concepts %>%
        dplyr::left_join(use_case_counts, by = "general_concept_id") %>%
        dplyr::mutate(
          use_case_count = ifelse(is.na(use_case_count), 0, use_case_count),
          category = factor(category),
          subcategory = factor(subcategory),
          actions = sprintf(
            '<button class="view-details-btn" data-id="%s">View Details</button>',
            general_concept_id
          )
        ) %>%
        dplyr::select(general_concept_id, category, subcategory, general_concept_name, use_case_count, actions)

      dt <- DT::datatable(
        table_data,
        selection = 'none',
        rownames = FALSE,
        escape = FALSE,
        filter = 'top',
        colnames = c("ID", "Category", "Subcategory", "General Concept Name", "Use Cases", "Actions"),
        options = list(
          pageLength = 25,
          lengthMenu = list(c(10, 25, 50, 100, -1), c('10', '25', '50', '100', 'All')),
          dom = 'lftp',
          columnDefs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 1, width = "150px"),
            list(targets = 2, width = "150px"),
            list(targets = 3, width = "300px"),
            list(targets = 4, width = "100px", className = 'dt-center'),
            list(targets = 5, width = "120px", className = 'dt-center', orderable = FALSE)
          )
        )
      )

      # Add callback to handle button clicks and double-click on rows
      dt$x$options$drawCallback <- htmlwidgets::JS(sprintf("
        function(settings) {
          var table = this.api();

          // Remove existing handlers to avoid duplicates
          $(table.table().node()).off('click', '.view-details-btn');
          $(table.table().node()).off('dblclick', 'tbody tr');

          // Add click handler for View Details button
          $(table.table().node()).on('click', '.view-details-btn', function(e) {
            e.stopPropagation();
            var conceptId = $(this).data('id');
            Shiny.setInputValue('%s', conceptId, {priority: 'event'});
          });

          // Add double-click handler for table rows
          $(table.table().node()).on('dblclick', 'tbody tr', function() {
            var rowData = table.row(this).data();
            if (rowData && rowData[0]) {
              var conceptId = rowData[0];
              Shiny.setInputValue('%s', conceptId, {priority: 'event'});
            }
          });
        }
      ", ns("view_concept_details"), ns("view_concept_details")))

      dt
    }, server = FALSE)

    # Handle "View Details" button click
    observeEvent(input$view_concept_details, {
      concept_id <- input$view_concept_details
      if (!is.null(concept_id)) {
        selected_concept_id(as.integer(concept_id))
        current_view("detail")
      }
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    # Handle back to list
    observeEvent(input$back_to_list, {
      current_view("list")
      selected_concept_id(NULL)
    })

    # Render comments
    output$comments_display <- renderUI({
      concept_id <- selected_concept_id()
      req(concept_id)

      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
        tags$div(
          class = "comments-container",
          style = "background: #e6f3ff; border: 1px solid #0f60af; border-radius: 6px; padding: 15px; margin-bottom: 20px;",
          HTML(concept_info$comments[1])
        )
      } else {
        tags$div(
          style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic;",
          "No comments available for this concept."
        )
      }
    })

    # Render concept mappings table
    output$concept_mappings_table <- DT::renderDT({
      concept_id <- selected_concept_id()
      req(concept_id)

      mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == concept_id) %>%
        dplyr::select(
          concept_name,
          vocabulary_id,
          concept_code,
          omop_concept_id,
          recommended
        )

      DT::datatable(
        mappings,
        selection = 'single',
        rownames = FALSE,
        colnames = c("Concept Name", "Vocabulary", "Code", "OMOP ID", "Recommended"),
        options = list(
          pageLength = 10,
          dom = 'tp',
          columnDefs = list(
            list(targets = 3, visible = FALSE),
            list(targets = 4, width = "100px", className = 'dt-center')
          )
        )
      ) %>%
        DT::formatStyle(
          'recommended',
          target = 'cell',
          backgroundColor = DT::styleEqual(
            c(TRUE, FALSE),
            c('#d4edda', '#f8f9fa')
          ),
          fontWeight = DT::styleEqual(
            c(TRUE, FALSE),
            c('bold', 'normal')
          ),
          color = DT::styleEqual(
            c(TRUE, FALSE),
            c('#155724', '#666')
          )
        )
    }, server = FALSE)
  })
}
