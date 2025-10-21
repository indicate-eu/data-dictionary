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
#' @param vocabularies Reactive containing preloaded OHDSI vocabularies
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
mod_dictionary_explorer_server <- function(id, data, config, vocabularies) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Track current view and selected concept
    current_view <- reactiveVal("list")  # "list" or "detail"
    selected_concept_id <- reactiveVal(NULL)
    selected_mapped_concept_id <- reactiveVal(NULL)  # Track selected concept in mappings table
    relationships_tab <- reactiveVal("related")  # Track active tab: "related", "hierarchy", "synonyms"

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
      tags$div(
        class = "quadrant-layout",
        # Top section: Mapped Concepts and Selected Concept Details
        tags$div(
          class = "top-section",
          # Top-left: Mapped Concepts
          tags$div(
            class = "quadrant quadrant-top-left",
            tags$div(
              class = "section-header",
              tags$h4("Mapped Concepts")
            ),
            tags$div(
              class = "quadrant-content",
              shinycssloaders::withSpinner(
                DT::DTOutput(ns("concept_mappings_table")),
                type = 4,
                color = "#0f60af",
                size = 0.5
              )
            )
          ),
          # Top-right: Selected Concept Details
          tags$div(
            class = "quadrant quadrant-top-right",
            tags$div(
              class = "section-header",
              tags$h4("Selected Concept Details")
            ),
            tags$div(
              class = "quadrant-content",
              shinycssloaders::withSpinner(
                uiOutput(ns("concept_details_display")),
                type = 4,
                color = "#0f60af",
                size = 0.5
              )
            )
          )
        ),
        # Horizontal splitter
        tags$div(class = "splitter splitter-h"),
        # Bottom section: Comments and Relationships
        tags$div(
          class = "bottom-section",
          # Bottom-left: Comments
          tags$div(
            class = "quadrant quadrant-bottom-left",
            tags$div(
              class = "section-header",
              tags$h4("ETL Guidance & Comments")
            ),
            tags$div(
              class = "quadrant-content",
              shinycssloaders::withSpinner(
                uiOutput(ns("comments_display")),
                type = 4,
                color = "#0f60af",
                size = 0.5
              )
            )
          ),
          # Bottom-right: Concept Relationships
          tags$div(
            class = "quadrant quadrant-bottom-right",
            tags$div(
              class = "section-header section-header-with-tabs",
              tags$h4("Concept Relationships & Hierarchy"),
              tags$div(
                class = "section-tabs",
                tags$button(
                  class = "tab-btn tab-btn-active",
                  id = ns("tab_related"),
                  onclick = sprintf("Shiny.setInputValue('%s', 'related', {priority: 'event'})", ns("switch_relationships_tab")),
                  "Related"
                ),
                tags$button(
                  class = "tab-btn",
                  id = ns("tab_hierarchy"),
                  onclick = sprintf("Shiny.setInputValue('%s', 'hierarchy', {priority: 'event'})", ns("switch_relationships_tab")),
                  "Hierarchy"
                ),
                tags$button(
                  class = "tab-btn",
                  id = ns("tab_synonyms"),
                  onclick = sprintf("Shiny.setInputValue('%s', 'synonyms', {priority: 'event'})", ns("switch_relationships_tab")),
                  "Synonyms"
                )
              )
            ),
            tags$div(
              class = "quadrant-content",
              shinycssloaders::withSpinner(
                uiOutput(ns("concept_relationships_display")),
                type = 4,
                color = "#0f60af",
                size = 0.5
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
          language = list(search = ""),
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

      # Get CSV mappings
      csv_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == concept_id) %>%
        dplyr::select(
          concept_name,
          vocabulary_id,
          concept_code,
          omop_concept_id,
          recommended
        )

      # Get athena_concept_id for this general concept
      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      athena_concept_id <- concept_info$athena_concept_id[1]

      # Get concepts from OHDSI vocabularies
      if (!is.na(athena_concept_id) && !is.null(athena_concept_id)) {
        vocab_data <- vocabularies()

        if (!is.null(vocab_data)) {
          # Get descendant concepts (hierarchy)
          descendants <- get_descendant_concepts(athena_concept_id, vocab_data)
          if (nrow(descendants) > 0) {
            descendants <- descendants %>%
              dplyr::mutate(recommended = FALSE) %>%
              dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended)
          }

          # Get same-level concepts (Maps to / Mapped from)
          same_level <- get_related_concepts(athena_concept_id, vocab_data)
          if (nrow(same_level) > 0) {
            # Filter only Maps to and Mapped from
            same_level <- same_level %>%
              dplyr::filter(relationship_id %in% c("Maps to", "Mapped from")) %>%
              dplyr::mutate(recommended = FALSE) %>%
              dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended)
          }

          # Combine all sources
          all_concepts <- dplyr::bind_rows(csv_mappings, descendants, same_level) %>%
            dplyr::distinct(omop_concept_id, .keep_all = TRUE) %>%
            dplyr::arrange(dplyr::desc(recommended), concept_name)

          mappings <- all_concepts
        } else {
          mappings <- csv_mappings
        }
      } else {
        mappings <- csv_mappings
      }

      # Mark the general concept and convert recommended to Yes/No
      if (nrow(mappings) > 0) {
        mappings <- mappings %>%
          dplyr::mutate(
            recommended = ifelse(recommended, "Yes", "No"),
            is_general_concept = omop_concept_id == athena_concept_id
          )
      } else {
        # If no concepts, show empty table
        return(DT::datatable(
          data.frame(Message = "No concepts found."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Reorder columns to put is_general_concept at the end and hide OMOP ID
      mappings <- mappings %>%
        dplyr::select(concept_name, vocabulary_id, concept_code, recommended, omop_concept_id, is_general_concept)

      dt <- DT::datatable(
        mappings,
        selection = 'single',
        rownames = FALSE,
        colnames = c("Concept Name", "Vocabulary", "Code", "Recommended", "OMOP ID", ""),
        options = list(
          pageLength = 10,
          dom = 'tp',
          columnDefs = list(
            list(targets = 3, width = "100px", className = 'dt-center'),  # Recommended column
            list(targets = c(4, 5), visible = FALSE)  # OMOP ID and IsGeneral columns hidden
          )
        )
      ) %>%
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
        ) %>%
        DT::formatStyle(
          0,  # First column (concept_name)
          valueColumns = 'is_general_concept',
          fontWeight = DT::styleEqual(c(TRUE, FALSE), c('bold', 'normal')),
          color = DT::styleEqual(c(TRUE, FALSE), c('#000', '#333'))
        )

      dt
    }, server = FALSE)

    # Observe tab switching for relationships
    observeEvent(input$switch_relationships_tab, {
      relationships_tab(input$switch_relationships_tab)
    })

    # Observe selection in concept mappings table
    observeEvent(input$concept_mappings_table_rows_selected, {
      selected_row <- input$concept_mappings_table_rows_selected
      if (!is.null(selected_row) && length(selected_row) > 0) {
        concept_id <- selected_concept_id()
        req(concept_id)

        # Get the mappings data
        csv_mappings <- data()$concept_mappings %>%
          dplyr::filter(general_concept_id == concept_id) %>%
          dplyr::select(
            concept_name,
            vocabulary_id,
            concept_code,
            omop_concept_id,
            recommended
          )

        concept_info <- data()$general_concepts %>%
          dplyr::filter(general_concept_id == concept_id)
        athena_concept_id <- concept_info$athena_concept_id[1]

        if (!is.na(athena_concept_id) && !is.null(athena_concept_id)) {
          vocab_data <- vocabularies()
          if (!is.null(vocab_data)) {
            athena_concepts <- get_all_related_concepts(
              athena_concept_id,
              vocab_data,
              csv_mappings
            )
            if (nrow(athena_concepts) > 0) {
              mappings <- dplyr::bind_rows(csv_mappings, athena_concepts) %>%
                dplyr::distinct(omop_concept_id, .keep_all = TRUE) %>%
                dplyr::arrange(dplyr::desc(recommended), concept_name)
            } else {
              mappings <- csv_mappings
            }
          } else {
            mappings <- csv_mappings
          }
        } else {
          mappings <- csv_mappings
        }

        # Get the selected concept's OMOP ID
        if (selected_row <= nrow(mappings)) {
          selected_omop_id <- mappings$omop_concept_id[selected_row]
          selected_mapped_concept_id(selected_omop_id)
        }
      }
    })

    # Render concept details (top-right quadrant)
    output$concept_details_display <- renderUI({
      omop_concept_id <- selected_mapped_concept_id()

      if (is.null(omop_concept_id)) {
        return(tags$div(
          style = "padding: 20px; background: #f8f9fa; border-radius: 6px; text-align: center;",
          tags$p(
            style = "color: #666; font-style: italic;",
            "Select a concept from the Mapped Concepts table to view its details."
          )
        ))
      }

      vocab_data <- vocabularies()

      if (is.null(vocab_data)) {
        return(tags$div(
          style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic;",
          "OHDSI vocabularies not loaded."
        ))
      }

      # Get concept details from OHDSI vocabularies
      concept_details <- vocab_data$concept %>%
        dplyr::filter(concept_id == omop_concept_id)

      if (nrow(concept_details) == 0) {
        return(tags$div(
          style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic;",
          "Concept details not found in OHDSI vocabularies."
        ))
      }

      info <- concept_details[1, ]

      tags$div(
        class = "concept-details-container",
        tags$div(
          class = "detail-item",
          tags$strong("Concept Name: "),
          tags$span(ifelse(is.na(info$concept_name), "/", info$concept_name))
        ),
        tags$div(
          class = "detail-item",
          tags$strong("Domain ID: "),
          tags$span(ifelse(is.na(info$domain_id), "/", info$domain_id))
        ),
        tags$div(
          class = "detail-item",
          tags$strong("Concept Class ID: "),
          tags$span(ifelse(is.na(info$concept_class_id), "/", info$concept_class_id))
        ),
        tags$div(
          class = "detail-item",
          tags$strong("Vocabulary ID: "),
          tags$span(ifelse(is.na(info$vocabulary_id), "/", info$vocabulary_id))
        ),
        tags$div(
          class = "detail-item",
          tags$strong("Concept ID: "),
          tags$span(ifelse(is.na(info$concept_id), "/", as.character(info$concept_id)))
        ),
        tags$div(
          class = "detail-item",
          tags$strong("Concept Code: "),
          tags$span(ifelse(is.na(info$concept_code), "/", info$concept_code))
        )
      )
    })

    # Render concept relationships (bottom-right quadrant)
    output$concept_relationships_display <- renderUI({
      active_tab <- relationships_tab()

      # Render DT output based on active tab
      if (active_tab == "related") {
        DT::DTOutput(ns("related_concepts_table"))
      } else if (active_tab == "hierarchy") {
        DT::DTOutput(ns("hierarchy_concepts_table"))
      } else if (active_tab == "synonyms") {
        tags$div(
          style = "padding: 20px; background: #f8f9fa; border-radius: 6px; text-align: center;",
          tags$p(
            style = "color: #666; font-style: italic;",
            "Synonyms functionality coming soon."
          )
        )
      }
    })

    # Render related concepts table
    output$related_concepts_table <- DT::renderDT({
      omop_concept_id <- selected_mapped_concept_id()
      req(omop_concept_id)

      vocab_data <- vocabularies()
      req(vocab_data)

      related_concepts <- get_related_concepts(omop_concept_id, vocab_data)

      # Remove the selected concept itself from the results
      if (nrow(related_concepts) > 0) {
        related_concepts <- related_concepts %>%
          dplyr::filter(omop_concept_id != !!omop_concept_id)
      }

      if (nrow(related_concepts) == 0) {
        return(DT::datatable(data.frame(Message = "No related concepts found."),
                             options = list(dom = 't'),
                             rownames = FALSE,
                             selection = 'none'))
      }

      # Reorder columns: relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id (hidden)
      related_concepts <- related_concepts %>%
        dplyr::select(relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id)

      DT::datatable(
        related_concepts,
        selection = 'none',
        rownames = FALSE,
        colnames = c("Relationship", "Concept Name", "Vocabulary", "Code", "OMOP ID"),
        options = list(
          pageLength = 10,
          dom = 'tp',
          columnDefs = list(
            list(targets = 4, visible = FALSE),  # OMOP ID hidden
            list(targets = 0, width = "150px")   # Relationship column width
          )
        )
      )
    }, server = FALSE)

    # Render hierarchy concepts table
    output$hierarchy_concepts_table <- DT::renderDT({
      omop_concept_id <- selected_mapped_concept_id()
      req(omop_concept_id)

      vocab_data <- vocabularies()
      req(vocab_data)

      descendant_concepts <- get_descendant_concepts(omop_concept_id, vocab_data)

      # Remove the selected concept itself from the results
      if (nrow(descendant_concepts) > 0) {
        descendant_concepts <- descendant_concepts %>%
          dplyr::filter(omop_concept_id != !!omop_concept_id)
      }

      if (nrow(descendant_concepts) == 0) {
        return(DT::datatable(data.frame(Message = "No descendant concepts found in hierarchy."),
                             options = list(dom = 't'),
                             rownames = FALSE,
                             selection = 'none'))
      }

      # Reorder columns: relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id (hidden)
      descendant_concepts <- descendant_concepts %>%
        dplyr::select(relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id)

      DT::datatable(
        descendant_concepts,
        selection = 'none',
        rownames = FALSE,
        colnames = c("Relationship", "Concept Name", "Vocabulary", "Code", "OMOP ID"),
        options = list(
          pageLength = 10,
          dom = 'tp',
          columnDefs = list(
            list(targets = 4, visible = FALSE),  # OMOP ID hidden
            list(targets = 0, width = "150px")   # Relationship column width
          )
        )
      )
    }, server = FALSE)
  })
}
