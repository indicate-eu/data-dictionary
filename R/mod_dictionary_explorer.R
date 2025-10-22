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
    ),

    # Modal for concept details
    tags$div(
      id = ns("concept_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("concept_modal")),
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h3("Concept Details"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("concept_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          uiOutput(ns("concept_modal_body"))
        )
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
    modal_concept_id <- reactiveVal(NULL)  # Track concept ID for modal display

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
              class = "breadcrumb-link",
              style = "font-weight: 600;",
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

    # Render content area - render both and use shinyjs to show/hide
    output$content_area <- renderUI({
      # Check if a concept is already selected
      concept_id <- selected_concept_id()
      show_details <- !is.null(concept_id) && current_view() == "detail"

      tagList(
        # General Concepts table container
        tags$div(
          id = ns("general_concepts_container"),
          class = "table-container",
          style = if (show_details) "display: none;" else "height: calc(100vh - 130px); overflow: auto;",
          DT::DTOutput(ns("general_concepts_table"))
        ),
        # Concept details container
        tags$div(
          id = ns("concept_details_container"),
          style = if (show_details) "" else "display: none;",
          render_concept_details()
        )
      )
    })

    # Observe current_view to show/hide appropriate content
    observeEvent(current_view(), {
      if (current_view() == "list") {
        shinyjs::show("general_concepts_container")
        shinyjs::hide("concept_details_container")
      } else {
        shinyjs::hide("general_concepts_container")
        shinyjs::show("concept_details_container")
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
              tags$h4(
                "Mapped Concepts",
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = "Concepts presented here are:
• Those selected by INDICATE, marked as 'Recommended'
• Child and same-level concepts, retrieved via ATHENA mappings",
                  "ⓘ"
                )
              )
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
              tags$h4(
                "Selected Concept Details",
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = "Detailed information about the selected concept from Mapped Concepts, including vocabulary, codes, links to ATHENA and FHIR resources",
                  "ⓘ"
                )
              )
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
        # Bottom section: Comments and Relationships
        tags$div(
          class = "bottom-section",
          # Bottom-left: Comments
          tags$div(
            class = "quadrant quadrant-bottom-left",
            tags$div(
              class = "section-header",
              tags$h4(
                "ETL Guidance & Comments",
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = "Expert guidance and comments for ETL (Extract, Transform, Load) processes related to this concept",
                  "ⓘ"
                )
              )
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
              tags$h4(
                "Concept Relationships & Hierarchy",
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = "All related concepts and hierarchical relationships from OHDSI vocabularies, including both standard and non-standard concepts. Double-click a row to see details.",
                  "ⓘ"
                )
              ),
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

      table_data <- general_concepts %>%
        dplyr::mutate(
          category = factor(category),
          subcategory = factor(subcategory),
          actions = sprintf(
            '<button class="view-details-btn" data-id="%s">View Details</button>',
            general_concept_id
          )
        ) %>%
        dplyr::select(general_concept_id, category, subcategory, general_concept_name, actions)

      dt <- DT::datatable(
        table_data,
        selection = 'none',
        rownames = FALSE,
        escape = FALSE,
        filter = 'top',
        colnames = c("ID", "Category", "Subcategory", "General Concept Name", "Actions"),
        options = list(
          pageLength = 20,
          lengthMenu = list(c(10, 20, 25, 50, 100, -1), c('10', '20', '25', '50', '100', 'All')),
          dom = 'ltp',
          columnDefs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 1, width = "150px"),
            list(targets = 2, width = "150px"),
            list(targets = 3, width = "300px"),
            list(targets = 4, width = "120px", className = 'dt-center', orderable = FALSE)
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
        current_mappings(NULL)  # Reset cache when changing concept
      }
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    # Handle back to list
    observeEvent(input$back_to_list, {
      current_view("list")
      selected_concept_id(NULL)
      selected_mapped_concept_id(NULL)
      current_mappings(NULL)
      relationships_tab("related")
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

      # Get CSV mappings (recommended concepts)
      csv_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == concept_id) %>%
        dplyr::select(
          concept_name,
          vocabulary_id,
          concept_code,
          omop_concept_id,
          recommended
        )

      # Get OHDSI vocabulary concepts from recommended concepts
      vocab_data <- vocabularies()

      if (!is.null(vocab_data) && nrow(csv_mappings) > 0) {
        # Get all recommended concept IDs
        recommended_ids <- csv_mappings %>%
          dplyr::filter(recommended == TRUE) %>%
          dplyr::pull(omop_concept_id)

        # Initialize data frames for descendants and related concepts
        all_descendants <- data.frame()
        all_related <- data.frame()

        # For each recommended concept, get descendants and related concepts
        for (rec_id in recommended_ids) {
          if (!is.na(rec_id) && !is.null(rec_id)) {
            # Get descendant concepts (hierarchy)
            descendants <- get_descendant_concepts(rec_id, vocab_data)
            if (nrow(descendants) > 0) {
              all_descendants <- dplyr::bind_rows(all_descendants, descendants)
            }

            # Get same-level concepts (Maps to / Mapped from) - filtered for standard and valid
            same_level <- get_related_concepts_filtered(rec_id, vocab_data)
            if (nrow(same_level) > 0) {
              # Filter only Maps to and Mapped from
              same_level <- same_level %>%
                dplyr::filter(relationship_id %in% c("Maps to", "Mapped from"))
              all_related <- dplyr::bind_rows(all_related, same_level)
            }
          }
        }

        # Remove duplicates and add recommended flag
        if (nrow(all_descendants) > 0) {
          all_descendants <- all_descendants %>%
            dplyr::distinct(omop_concept_id, .keep_all = TRUE) %>%
            dplyr::mutate(recommended = FALSE) %>%
            dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended)
        }

        if (nrow(all_related) > 0) {
          all_related <- all_related %>%
            dplyr::distinct(omop_concept_id, .keep_all = TRUE) %>%
            dplyr::mutate(recommended = FALSE) %>%
            dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended)
        }

        # Combine all sources
        mappings <- dplyr::bind_rows(csv_mappings, all_descendants, all_related) %>%
          dplyr::distinct(omop_concept_id, .keep_all = TRUE) %>%
          dplyr::arrange(dplyr::desc(recommended), concept_name)
      } else {
        mappings <- csv_mappings
      }

      # Get athena_concept_id for marking the general concept
      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)
      athena_concept_id <- concept_info$athena_concept_id[1]

      # Mark the general concept and convert recommended to Yes/No
      if (nrow(mappings) > 0) {
        mappings <- mappings %>%
          dplyr::mutate(
            recommended = ifelse(recommended, "Yes", "No"),
            is_general_concept = if (!is.na(athena_concept_id)) {
              omop_concept_id == athena_concept_id
            } else {
              FALSE
            }
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

      # Cache mappings for selection handling (before converting recommended to Yes/No)
      mappings_for_cache <- mappings %>%
        dplyr::mutate(recommended = recommended == "Yes")
      current_mappings(mappings_for_cache)

      # Load JavaScript callbacks
      callback <- JS(paste(readLines(app_sys("www", "dt_callback.js")), collapse = "\n"))
      keyboard_nav <- paste(readLines(app_sys("www", "keyboard_nav.js")), collapse = "\n")

      dt <- DT::datatable(
        mappings,
        selection = 'none',
        rownames = FALSE,
        extensions = c('Select'),
        colnames = c("Concept Name", "Vocabulary", "Code", "Recommended", "OMOP ID", ""),
        options = list(
          pageLength = 10,
          dom = 'tp',
          select = list(style = 'single', info = FALSE),
          columnDefs = list(
            list(targets = 3, width = "100px", className = 'dt-center'),  # Recommended column
            list(targets = c(4, 5), visible = FALSE)  # OMOP ID and IsGeneral columns hidden
          ),
          initComplete = create_keyboard_nav(keyboard_nav, TRUE, FALSE)
        ),
        callback = callback
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

    # Cache for current mappings to avoid recalculation
    current_mappings <- reactiveVal(NULL)

    # Debounce the table selection to avoid excessive updates when navigating with arrow keys
    debounced_selection <- debounce(
      reactive({
        input$concept_mappings_table_rows_selected
      }),
      300  # Wait 300ms after user stops navigating
    )

    # Observe selection in concept mappings table with debounce
    observeEvent(debounced_selection(), {
      selected_row <- debounced_selection()

      if (!is.null(selected_row) && length(selected_row) > 0) {
        # Use cached mappings if available
        mappings <- current_mappings()

        if (is.null(mappings)) {
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

          current_mappings(mappings)
        }

        # Get the selected concept's OMOP ID
        if (selected_row <= nrow(mappings)) {
          selected_omop_id <- mappings$omop_concept_id[selected_row]
          selected_mapped_concept_id(selected_omop_id)
        }
      }
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

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

      # Get concept details from concept_mappings
      concept_id <- selected_concept_id()
      req(concept_id)

      concept_mapping <- data()$concept_mappings %>%
        dplyr::filter(
          general_concept_id == concept_id,
          omop_concept_id == !!omop_concept_id
        )

      general_concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_mapping) == 0) {
        # If not in concept_mappings, get from OHDSI vocabularies
        vocab_data <- vocabularies()
        if (is.null(vocab_data)) {
          return(tags$div(
            style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic;",
            "Concept details not available."
          ))
        }

        concept_details <- vocab_data$concept %>%
          dplyr::filter(concept_id == omop_concept_id) %>%
          dplyr::collect()

        if (nrow(concept_details) == 0) {
          return(tags$div(
            style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic;",
            "Concept details not found."
          ))
        }

        info <- concept_details[1, ]

        # Build URLs for OHDSI-only concepts
        athena_url <- paste0(config$athena_base_url, "/", info$concept_id)
        fhir_url <- build_fhir_url(info$vocabulary_id, info$concept_code, config)

        # Determine validity and standard
        is_valid <- is.na(info$invalid_reason) || info$invalid_reason == ""
        validity_color <- if (is_valid) "#28a745" else "#dc3545"
        validity_text <- if (is_valid) {
          "Valid"
        } else {
          paste0("Invalid (", info$invalid_reason, ")")
        }

        is_standard <- !is.na(info$standard_concept) && info$standard_concept == "S"
        standard_color <- if (is_standard) "#28a745" else "#dc3545"
        standard_text <- if (is_standard) "Standard" else "Non-standard"

        # Helper function to create detail items
        create_detail_item_ohdsi <- function(label, value, url = NULL, color = NULL) {
          display_value <- if (is.na(value) || is.null(value) || value == "") {
            "/"
          } else {
            as.character(value)
          }

          # Create link if URL provided
          if (!is.null(url) && display_value != "/") {
            display_value <- tags$a(
              href = url,
              target = "_blank",
              style = "color: #0f60af; text-decoration: underline;",
              display_value
            )
          } else if (!is.null(color) && display_value != "/") {
            # Apply color if specified
            display_value <- tags$span(
              style = paste0("color: ", color, "; font-weight: 600;"),
              display_value
            )
          }

          tags$div(
            class = "detail-item",
            tags$strong(label),
            tags$span(display_value)
          )
        }

        # Display full info for OHDSI-only concepts (with "/" for missing EHDEN/LOINC data)
        return(tags$div(
          class = "concept-details-container",
          style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(8, auto); grid-auto-flow: column; gap: 4px 15px;",
          # Column 1
          create_detail_item_ohdsi("Concept Name", info$concept_name),
          create_detail_item_ohdsi("Category",
                                   ifelse(nrow(general_concept_info) > 0,
                                         general_concept_info$category[1], NA)),
          create_detail_item_ohdsi("Sub-category",
                                   ifelse(nrow(general_concept_info) > 0,
                                         general_concept_info$subcategory[1], NA)),
          create_detail_item_ohdsi("EHDEN Data Sources", "/"),
          create_detail_item_ohdsi("EHDEN Rows Count", "/"),
          create_detail_item_ohdsi("LOINC Rank", "/"),
          create_detail_item_ohdsi("Validity", validity_text, color = validity_color),
          create_detail_item_ohdsi("Standard", standard_text, color = standard_color),
          # Column 2 (must have exactly 8 items)
          create_detail_item_ohdsi("Vocabulary ID", info$vocabulary_id),
          create_detail_item_ohdsi("Domain ID", if (!is.na(info$domain_id)) info$domain_id else "/"),
          create_detail_item_ohdsi("Concept Code", info$concept_code),
          create_detail_item_ohdsi("OMOP Concept ID", info$concept_id, url = athena_url),
          if (!is.null(fhir_url)) {
            tags$div(
              class = "detail-item",
              tags$strong("FHIR Resource"),
              tags$a(
                href = fhir_url,
                target = "_blank",
                style = "color: #0f60af; text-decoration: underline;",
                "View"
              )
            )
          } else {
            tags$div(class = "detail-item", style = "visibility: hidden;")
          },
          create_detail_item_ohdsi("Unit Concept Name", "/"),
          create_detail_item_ohdsi("OMOP Unit Concept ID", "/"),
          tags$div(class = "detail-item", style = "visibility: hidden;")
        ))
      }

      # Display full details from concept_mappings
      info <- concept_mapping[1, ]

      # Get validity and standard info from OHDSI vocabularies
      vocab_data <- vocabularies()
      validity_info <- NULL
      if (!is.null(vocab_data)) {
        validity_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == omop_concept_id) %>%
          dplyr::collect()
        if (nrow(validity_info) > 0) {
          validity_info <- validity_info[1, ]
        } else {
          validity_info <- NULL
        }
      }

      # Build URLs
      athena_url <- paste0(config$athena_base_url, "/", info$omop_concept_id)
      fhir_url <- build_fhir_url(info$vocabulary_id, info$concept_code, config)
      athena_unit_url <- if (!is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "") {
        paste0(config$athena_base_url, "/", info$omop_unit_concept_id)
      } else {
        NULL
      }
      unit_fhir_url <- build_unit_fhir_url(info$unit_concept_code, config)

      # Create detail items with proper formatting
      create_detail_item <- function(label, value, format_number = FALSE, url = NULL, color = NULL) {
        display_value <- if (is.na(value) || is.null(value) || value == "") {
          "/"
        } else if (is.logical(value)) {
          if (value) "Yes" else "No"
        } else if (format_number && is.numeric(value)) {
          format(value, big.mark = ",", scientific = FALSE)
        } else {
          as.character(value)
        }

        # Create link if URL provided
        if (!is.null(url) && display_value != "/") {
          display_value <- tags$a(
            href = url,
            target = "_blank",
            style = "color: #0f60af; text-decoration: underline;",
            display_value
          )
        } else if (!is.null(color) && display_value != "/") {
          # Apply color if specified
          display_value <- tags$span(
            style = paste0("color: ", color, "; font-weight: 600;"),
            display_value
          )
        }

        tags$div(
          class = "detail-item",
          tags$strong(label),
          tags$span(display_value)
        )
      }

      # Determine validity and standard from vocab_data
      is_valid <- if (!is.null(validity_info)) {
        is.na(validity_info$invalid_reason) || validity_info$invalid_reason == ""
      } else {
        NA
      }
      validity_color <- if (!is.na(is_valid)) {
        if (is_valid) "#28a745" else "#dc3545"
      } else {
        NULL
      }
      validity_text <- if (!is.na(is_valid)) {
        if (is_valid) {
          "Valid"
        } else {
          if (!is.null(validity_info) && !is.na(validity_info$invalid_reason)) {
            paste0("Invalid (", validity_info$invalid_reason, ")")
          } else {
            "Invalid"
          }
        }
      } else {
        "/"
      }

      is_standard <- if (!is.null(validity_info)) {
        !is.na(validity_info$standard_concept) && validity_info$standard_concept == "S"
      } else {
        NA
      }
      standard_color <- if (!is.na(is_standard)) {
        if (is_standard) "#28a745" else "#dc3545"
      } else {
        NULL
      }
      standard_text <- if (!is.na(is_standard)) {
        if (is_standard) "Standard" else "Non-standard"
      } else {
        "/"
      }

      tags$div(
        class = "concept-details-container",
        style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(8, auto); grid-auto-flow: column; gap: 4px 15px;",
        # Column 1
        create_detail_item("Concept Name", info$concept_name),
        create_detail_item("Category",
                          ifelse(nrow(general_concept_info) > 0,
                                general_concept_info$category[1], NA)),
        create_detail_item("Sub-category",
                          ifelse(nrow(general_concept_info) > 0,
                                general_concept_info$subcategory[1], NA)),
        create_detail_item("EHDEN Data Sources", info$ehden_num_data_sources, format_number = TRUE),
        create_detail_item("EHDEN Rows Count", info$ehden_rows_count, format_number = TRUE),
        create_detail_item("LOINC Rank", info$loinc_rank),
        create_detail_item("Validity", validity_text, color = validity_color),
        create_detail_item("Standard", standard_text, color = standard_color),
        # Column 2 (must have exactly 8 items)
        create_detail_item("Vocabulary ID", info$vocabulary_id),
        create_detail_item("Domain ID", if (!is.null(validity_info) && !is.na(validity_info$domain_id)) validity_info$domain_id else "/"),
        create_detail_item("Concept Code", info$concept_code),
        create_detail_item("OMOP Concept ID", info$omop_concept_id, url = athena_url),
        if (!is.null(fhir_url)) {
          tags$div(
            class = "detail-item",
            tags$strong("FHIR Resource"),
            tags$a(
              href = fhir_url,
              target = "_blank",
              style = "color: #0f60af; text-decoration: underline;",
              "View"
            )
          )
        } else {
          tags$div(class = "detail-item", style = "visibility: hidden;")
        },
        create_detail_item("Unit Concept Name",
                          if (!is.na(info$unit_concept_code) && info$unit_concept_code != "") {
                            info$unit_concept_code
                          } else {
                            "/"
                          }),
        create_detail_item("OMOP Unit Concept ID",
                          if (!is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "") {
                            info$omop_unit_concept_id
                          } else {
                            "/"
                          },
                          url = athena_unit_url)
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
          ),
          initComplete = JS(sprintf("
            function(settings, json) {
              var table = this.api();

              // Add double-click handler for table rows
              $(table.table().node()).on('dblclick', 'tbody tr', function() {
                var rowData = table.row(this).data();
                if (rowData && rowData[4]) {
                  var conceptId = rowData[4];
                  Shiny.setInputValue('%s', conceptId, {priority: 'event'});
                  $('#%s').show();
                }
              });
            }
          ", ns("modal_concept_id"), ns("concept_modal")))
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
          ),
          initComplete = JS(sprintf("
            function(settings, json) {
              var table = this.api();
              $(table.table().node()).on('dblclick', 'tbody tr', function() {
                var rowData = table.row(this).data();
                if (rowData && rowData[4]) {
                  var conceptId = rowData[4];
                  Shiny.setInputValue('%s', conceptId, {priority: 'event'});
                  $('#%s').show();
                }
              });
            }
          ", ns("modal_concept_id"), ns("concept_modal")))
        )
      )
    }, server = FALSE)

    # Observe modal_concept_id input and update reactiveVal
    observeEvent(input$modal_concept_id, {
      modal_concept_id(input$modal_concept_id)
    }, ignoreNULL = TRUE, ignoreInit = FALSE)

    # Modal concept details
    output$concept_modal_body <- renderUI({
      concept_id <- modal_concept_id()

      if (is.null(concept_id)) {
        return(tags$div("No concept selected"))
      }

      vocab_data <- vocabularies()
      if (is.null(vocab_data)) {
        return(tags$div("Vocabulary data not available"))
      }

      # Get concept information from vocabularies
      concept_info <- vocab_data$concept %>%
        dplyr::filter(concept_id == !!concept_id) %>%
        dplyr::collect()

      if (nrow(concept_info) == 0) {
        return(tags$p("Concept not found.", style = "color: #666; font-style: italic;"))
      }

      info <- concept_info[1, ]

      # Build ATHENA URL
      athena_url <- build_athena_url(info$concept_id, config)

      # Build FHIR URL
      fhir_url <- build_fhir_url(info$vocabulary_id, info$concept_code, config)

      # Helper function to create detail items
      create_detail_item <- function(label, value, url = NULL, color = NULL) {
        display_value <- if (is.na(value) || is.null(value) || value == "") {
          "/"
        } else {
          as.character(value)
        }

        # Create link if URL provided
        if (!is.null(url) && display_value != "/") {
          display_value <- tags$a(
            href = url,
            target = "_blank",
            style = "color: #0f60af; text-decoration: underline;",
            display_value
          )
        } else if (!is.null(color)) {
          # Apply color if specified
          display_value <- tags$span(
            style = paste0("color: ", color, "; font-weight: 600;"),
            display_value
          )
        }

        tags$div(
          class = "detail-item",
          tags$strong(label),
          tags$span(display_value)
        )
      }

      # Determine if concept is valid
      is_valid <- is.na(info$invalid_reason) || info$invalid_reason == ""
      validity_color <- if (is_valid) "#28a745" else "#dc3545"
      validity_text <- if (is_valid) "Valid" else paste0("Invalid (", info$invalid_reason, ")")

      # Determine if concept is standard
      is_standard <- !is.na(info$standard_concept) && info$standard_concept == "S"
      standard_color <- if (is_standard) "#28a745" else "#dc3545"
      standard_text <- if (is_standard) "Standard" else "Non-standard"

      tags$div(
        class = "concept-details-container",
        style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(6, auto); grid-auto-flow: column; gap: 4px 15px;",
        # Column 1
        create_detail_item("Concept Name", info$concept_name),
        create_detail_item("Category", info$domain_id),
        create_detail_item("Sub-category", info$concept_class_id),
        create_detail_item("Validity", validity_text, color = validity_color),
        create_detail_item("Standard", standard_text, color = standard_color),
        tags$div(class = "detail-item", style = "visibility: hidden;"),
        # Column 2
        create_detail_item("Vocabulary ID", info$vocabulary_id),
        create_detail_item("Domain ID", info$domain_id),
        create_detail_item("Concept Code", info$concept_code),
        create_detail_item("OMOP Concept ID", info$concept_id, url = athena_url),
        if (!is.null(fhir_url)) {
          tags$div(
            class = "detail-item",
            tags$strong("FHIR Resource"),
            tags$a(
              href = fhir_url,
              target = "_blank",
              style = "color: #0f60af; text-decoration: underline;",
              "View"
            )
          )
        } else {
          tags$div(class = "detail-item", style = "visibility: hidden;")
        },
        tags$div(class = "detail-item", style = "visibility: hidden;")
      )
    })

    # Force Shiny to render output even when hidden
    outputOptions(output, "concept_modal_body", suspendWhenHidden = FALSE)
  })
}
