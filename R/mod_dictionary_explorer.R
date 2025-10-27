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
    ),

    # Modal for adding new concept
    tags$div(
      id = ns("add_concept_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("add_concept_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 600px;",
        tags$div(
          class = "modal-header",
          tags$h3("Add New Concept"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("add_concept_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$div(
            id = ns("new_concept_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              "General Concept Name",
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            shiny::textInput(
              ns("new_concept_name"),
              label = NULL,
              placeholder = "Enter concept name",
              width = "100%"
            )
          ),
          tags$div(
            id = ns("new_concept_category_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              "Category",
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            tags$div(
              style = "display: flex; gap: 10px; align-items: flex-start;",
              tags$div(
                id = ns("category_select_container"),
                style = "flex: 1;",
                selectizeInput(
                  ns("new_concept_category"),
                  label = NULL,
                  choices = character(0),
                  selected = character(0),
                  options = list(
                    placeholder = "Select category..."
                  ),
                  width = "100%"
                )
              ),
              tags$div(
                id = ns("category_text_container"),
                style = "flex: 1; display: none;",
                shiny::textInput(
                  ns("new_concept_category_text"),
                  label = NULL,
                  placeholder = "Enter new category",
                  width = "100%"
                )
              ),
              tags$button(
                id = ns("toggle_category_mode"),
                class = "btn-toggle",
                onclick = sprintf("
                  var selectContainer = document.getElementById('%s');
                  var textContainer = document.getElementById('%s');
                  var btn = document.getElementById('%s');
                  if (selectContainer.style.display === 'none') {
                    selectContainer.style.display = 'block';
                    textContainer.style.display = 'none';
                    btn.innerHTML = '+';
                    btn.classList.remove('active');
                  } else {
                    selectContainer.style.display = 'none';
                    textContainer.style.display = 'block';
                    btn.innerHTML = '×';
                    btn.classList.add('active');
                  }
                ", ns("category_select_container"), ns("category_text_container"), ns("toggle_category_mode")),
                "+"
              )
            )
          ),
          tags$div(
            id = ns("new_concept_subcategory_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              "Subcategory",
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            tags$div(
              style = "display: flex; gap: 10px; align-items: flex-start;",
              tags$div(
                id = ns("subcategory_select_container"),
                style = "flex: 1;",
                selectizeInput(
                  ns("new_concept_subcategory"),
                  label = NULL,
                  choices = character(0),
                  selected = character(0),
                  options = list(
                    placeholder = "First select a category..."
                  ),
                  width = "100%"
                )
              ),
              tags$div(
                id = ns("subcategory_text_container"),
                style = "flex: 1; display: none;",
                shiny::textInput(
                  ns("new_concept_subcategory_text"),
                  label = NULL,
                  placeholder = "Enter new subcategory",
                  width = "100%"
                )
              ),
              tags$button(
                id = ns("toggle_subcategory_mode"),
                class = "btn-toggle",
                onclick = sprintf("
                  var selectContainer = document.getElementById('%s');
                  var textContainer = document.getElementById('%s');
                  var btn = document.getElementById('%s');
                  if (selectContainer.style.display === 'none') {
                    selectContainer.style.display = 'block';
                    textContainer.style.display = 'none';
                    btn.innerHTML = '+';
                    btn.classList.remove('active');
                  } else {
                    selectContainer.style.display = 'none';
                    textContainer.style.display = 'block';
                    btn.innerHTML = '×';
                    btn.classList.add('active');
                  }
                ", ns("subcategory_select_container"), ns("subcategory_text_container"), ns("toggle_subcategory_mode")),
                "+"
              )
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              "Athena Concept ID",
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            shiny::textInput(
              ns("new_concept_athena_id"),
              label = NULL,
              placeholder = "Enter Athena Concept ID (optional)",
              width = "100%"
            )
          ),
          tags$div(
            style = "display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; padding-top: 20px; border-top: 1px solid #dee2e6;",
            tags$button(
              class = "btn btn-secondary btn-secondary-custom",
              onclick = sprintf("$('#%s').hide();", ns("add_concept_modal")),
              "Cancel"
            ),
            actionButton(
              ns("add_new_concept"),
              "Add Concept",
              class = "btn-primary-custom"
            )
          )
        )
      )
    ),

    # Modal for fullscreen hierarchy graph
    tags$div(
      id = ns("hierarchy_graph_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none; background: white; z-index: 9999;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        # Header with breadcrumb and close button
        tags$div(
          style = "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
          tags$div(
            style = "display: flex; align-items: center; gap: 15px;",
            uiOutput(ns("hierarchy_graph_breadcrumb"))
          ),
          tags$button(
            class = "modal-close-graph",
            onclick = sprintf("$('#%s').hide();", ns("hierarchy_graph_modal")),
            style = "font-size: 28px; font-weight: 300; color: #666; border: none; background: none; cursor: pointer; padding: 0; width: 30px; height: 30px; line-height: 1;",
            "×"
          )
        ),
        # Graph content
        tags$div(
          style = "flex: 1; overflow: hidden; padding: 20px;",
          visNetwork::visNetworkOutput(ns("hierarchy_graph"), height = "100%", width = "100%")
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
    comments_tab <- reactiveVal("comments")  # Track active tab: "comments", "statistical_summary"
    modal_concept_id <- reactiveVal(NULL)  # Track concept ID for modal display
    selected_categories <- reactiveVal(character(0))  # Track selected category filters
    edit_mode <- reactiveVal(FALSE)  # Track edit mode state for detail view
    saved_table_page <- reactiveVal(0)  # Track datatable page for edit mode restoration
    list_edit_mode <- reactiveVal(FALSE)  # Track edit mode state for list view
    saved_table_search <- reactiveVal(NULL)  # Track datatable search state for edit mode

    # Track temporary edits in edit mode
    edited_recommended <- reactiveVal(list())  # Store recommended changes by omop_concept_id
    # edited_comment <- reactiveVal(NULL)  # Store comment changes
    original_general_concepts <- reactiveVal(NULL)  # Store original state for cancel in list edit mode

    # Create a local copy of data that can be updated
    local_data <- reactiveVal(NULL)

    # Initialize local_data with data from parameter
    observe({
      if (is.null(local_data())) {
        local_data(data())
      }
    })

    # Create a reactive that uses local_data if available, otherwise data
    current_data <- reactive({
      if (!is.null(local_data())) {
        local_data()
      } else {
        data()
      }
    })

    # Get unique categories from data
    categories_list <- reactive({
      req(current_data())
      unique_cats <- unique(current_data()$general_concepts$category)
      sorted_cats <- sort(unique_cats[!is.na(unique_cats)])

      # Move "Other" to the end if it exists
      if ("Other" %in% sorted_cats) {
        sorted_cats <- c(setdiff(sorted_cats, "Other"), "Other")
      }

      sorted_cats
    })

    # Observe category selection
    observeEvent(input$category_filter, {
      category <- input$category_filter
      current_selected <- selected_categories()

      if (category %in% current_selected) {
        # Remove category
        selected_categories(setdiff(current_selected, category))
      } else {
        # Add category
        selected_categories(c(current_selected, category))
      }
    })

    # Render breadcrumb
    output$breadcrumb <- renderUI({
      # Force re-render when edit modes change
      edit_mode()
      list_edit_mode()

      if (current_view() == "list") {
        categories <- categories_list()
        selected <- selected_categories()

        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 0; display: flex; align-items: center; gap: 15px; justify-content: space-between;",
          # Left side: Title and category badges
          tags$div(
            style = "display: flex; align-items: center; gap: 15px; flex: 1;",
            # Title
            tags$div(
              style = "font-size: 16px; color: #0f60af; font-weight: 600;",
              tags$span("General Concepts")
            ),
            # Category badges
            tags$div(
              class = "category-filters",
              style = "display: flex; flex-wrap: wrap; gap: 8px; flex: 1;",
              lapply(categories, function(cat) {
                is_selected <- cat %in% selected
                tags$span(
                  class = "category-badge",
                  style = sprintf(
                    "padding: 6px 14px; border-radius: 20px; font-size: 13px; cursor: pointer; transition: all 0.2s; %s",
                    if (is_selected) {
                      "background: #ff8c00; color: white; font-weight: 500;"
                    } else {
                      "background: #e9ecef; color: #6c757d;"
                    }
                  ),
                  onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("category_filter"), cat),
                  cat
                )
              })
            )
          ),
          # Right side: Edit/Cancel/Save/Add buttons
          tags$div(
            style = "display: flex; gap: 10px;",
            if (!list_edit_mode()) {
              tagList(
                actionButton(
                  ns("show_add_concept_modal"),
                  "Add concept",
                  class = "btn-success-custom"
                ),
                actionButton(
                  ns("list_edit_page"),
                  "Edit page",
                  class = "btn-primary-custom"
                )
              )
            } else {
              tagList(
                actionButton(
                  ns("list_cancel"),
                  "Cancel",
                  class = "btn-secondary-custom"
                ),
                actionButton(
                  ns("list_save_updates"),
                  "Save updates",
                  class = "btn-success-custom"
                )
              )
            }
          )
        )
      } else {
        concept_id <- selected_concept_id()
        req(concept_id)

        concept_info <- current_data()$general_concepts %>%
          dplyr::filter(general_concept_id == concept_id)

        if (nrow(concept_info) > 0) {
          tags$div(
            class = "breadcrumb-nav",
            style = "padding: 10px 0 15px 0; font-size: 16px; display: flex; justify-content: space-between; align-items: center;",
            # Left side: breadcrumb
            tags$div(
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
            ),
            # Right side: edit buttons
            tags$div(
              style = "display: flex; gap: 10px;",
              if (!edit_mode()) {
                actionButton(
                  ns("edit_page"),
                  "Edit page",
                  class = "btn-toggle"
                )
              } else {
                tagList(
                  actionButton(
                    ns("cancel_edit"),
                    "Cancel",
                    class = "btn-cancel"
                  ),
                  actionButton(
                    ns("save_updates"),
                    "Save updates",
                    class = "btn-toggle"
                  )
                )
              }
            )
          )
        }
      }
    })

    # Render content area once - both containers are created and shown/hidden
    output$content_area <- renderUI({
      tagList(
        # General Concepts table container
        tags$div(
          id = ns("general_concepts_container"),
          class = "table-container",
          style = "height: calc(100vh - 130px); overflow: auto;",
          DT::DTOutput(ns("general_concepts_table"))
        ),
        # Concept details container
        tags$div(
          id = ns("concept_details_container"),
          style = "display: none;",
          uiOutput(ns("concept_details_ui"))
        )
      )
    })

    # Render concept details when needed
    output$concept_details_ui <- renderUI({
      req(current_view() == "detail")
      req(selected_concept_id())
      # Force re-render when edit_mode changes
      edit_mode()
      render_concept_details()
    })

    # Observe current_view to show/hide appropriate content
    observeEvent(current_view(), {
      view <- current_view()
      if (view == "list") {
        shinyjs::show(id = "general_concepts_container")
        shinyjs::hide(id = "concept_details_container")
      } else {
        shinyjs::hide(id = "general_concepts_container")
        shinyjs::show(id = "concept_details_container")
      }
    })

    # Function to render general concepts table
    render_general_concepts_table <- function() {
      tagList(
        # Edit/Cancel/Save buttons
        tags$div(
          style = "padding: 10px 0 15px 0; display: flex; justify-content: flex-end; gap: 10px;",
          if (!list_edit_mode()) {
            actionButton(
              ns("list_edit_page"),
              "Edit page",
              class = "btn-toggle"
            )
          } else {
            tagList(
              actionButton(
                ns("list_cancel"),
                "Cancel",
                class = "btn-cancel"
              ),
              actionButton(
                ns("list_save_updates"),
                "Save updates",
                class = "btn-toggle"
              )
            )
          }
        ),
        tags$div(
          class = "table-container",
          style = "height: calc(100vh - 220px); overflow: auto;",
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
              style = if (edit_mode()) "display: flex; align-items: center;" else NULL,
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
              class = "section-header section-header-with-tabs",
              tags$h4(
                "ETL Guidance & Comments",
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = "Expert guidance and comments for ETL (Extract, Transform, Load) processes related to this concept",
                  "ⓘ"
                )
              ),
              tags$div(
                class = "section-tabs",
                tags$button(
                  class = "tab-btn tab-btn-active",
                  id = ns("tab_comments"),
                  onclick = sprintf("Shiny.setInputValue('%s', 'comments', {priority: 'event'})", ns("switch_comments_tab")),
                  "Comments"
                ),
                tags$button(
                  class = "tab-btn",
                  id = ns("tab_statistical_summary"),
                  onclick = sprintf("Shiny.setInputValue('%s', 'statistical_summary', {priority: 'event'})", ns("switch_comments_tab")),
                  "Statistical Summary"
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
      # Force re-render when edit mode changes
      list_edit_mode()

      general_concepts <- current_data()$general_concepts

      # Prepare table data
      table_data <- general_concepts %>%
        dplyr::mutate(
          # Always keep as factor to preserve dropdown filters
          category = factor(category),
          subcategory = factor(subcategory),
          athena_concept_id = as.character(athena_concept_id),
          actions = if (list_edit_mode()) {
            sprintf(
              '<button class="delete-concept-btn" data-id="%s" style="padding: 4px 12px; background: #dc3545; color: white; border: none; border-radius: 4px; cursor: pointer;">Delete</button>',
              general_concept_id
            )
          } else {
            sprintf(
              '<button class="view-details-btn" data-id="%s">View Details</button>',
              general_concept_id
            )
          }
        )

      # Select columns based on edit mode
      if (list_edit_mode()) {
        table_data <- table_data %>%
          dplyr::select(general_concept_id, category, subcategory, general_concept_name, athena_concept_id, actions)
        col_names <- c("ID", "Category", "Subcategory", "General Concept Name", "Athena Concept ID", "Actions")
        col_defs <- list(
          list(targets = 0, visible = FALSE),
          list(targets = 1, width = "150px"),
          list(targets = 2, width = "150px"),
          list(targets = 3, width = "300px"),
          list(targets = 4, width = "150px"),
          list(targets = 5, width = "120px", className = 'dt-center', orderable = FALSE)
        )
        editable_cols <- list(target = 'cell', disable = list(columns = c(0, 5)))
      } else {
        table_data <- table_data %>%
          dplyr::select(general_concept_id, category, subcategory, general_concept_name, actions)
        col_names <- c("ID", "Category", "Subcategory", "General Concept Name", "Actions")
        col_defs <- list(
          list(targets = 0, visible = FALSE),
          list(targets = 1, width = "150px"),
          list(targets = 2, width = "150px"),
          list(targets = 3, width = "350px"),
          list(targets = 4, width = "120px", className = 'dt-center', orderable = FALSE)
        )
        editable_cols <- FALSE
      }

      dt <- DT::datatable(
        table_data,
        selection = 'none',
        rownames = FALSE,
        escape = FALSE,
        filter = 'top',
        editable = editable_cols,
        colnames = col_names,
        options = list(
          pageLength = 20,
          lengthMenu = list(c(10, 20, 25, 50, 100, -1), c('10', '20', '25', '50', '100', 'All')),
          dom = 'ltip',
          columnDefs = col_defs
        )
      )

      # Add callback to handle button clicks and double-click on rows
      dt$x$options$drawCallback <- htmlwidgets::JS(sprintf("
        function(settings) {
          var table = this.api();

          // Remove existing handlers to avoid duplicates
          $(table.table().node()).off('click', '.view-details-btn');
          $(table.table().node()).off('click', '.delete-concept-btn');
          $(table.table().node()).off('dblclick', 'tbody tr');

          // Add click handler for View Details button
          $(table.table().node()).on('click', '.view-details-btn', function(e) {
            e.stopPropagation();
            var conceptId = $(this).data('id');
            Shiny.setInputValue('%s', conceptId, {priority: 'event'});
          });

          // Add click handler for Delete button
          $(table.table().node()).on('click', '.delete-concept-btn', function(e) {
            e.stopPropagation();
            var conceptId = $(this).data('id');
            Shiny.setInputValue('%s', conceptId, {priority: 'event'});
          });

          // Add double-click handler for table rows (only when not in edit mode)
          if (!%s) {
            $(table.table().node()).on('dblclick', 'tbody tr', function() {
              var rowData = table.row(this).data();
              if (rowData && rowData[0]) {
                var conceptId = rowData[0];
                Shiny.setInputValue('%s', conceptId, {priority: 'event'});
              }
            });
          }
        }
      ", ns("view_concept_details"), ns("delete_general_concept"),
         tolower(as.character(list_edit_mode())), ns("view_concept_details")))

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
      edit_mode(FALSE)  # Exit edit mode when going back to list
      list_edit_mode(FALSE)  # Exit list edit mode when going back to list
    })

    # Handle list edit page button
    observeEvent(input$list_edit_page, {
      # Save current state for cancel functionality
      original_general_concepts(current_data()$general_concepts)

      # Save current page number
      if (!is.null(input$general_concepts_table_state)) {
        current_page <- input$general_concepts_table_state$start / input$general_concepts_table_state$length + 1
        saved_table_page(current_page)
      }

      # Save column search filters
      if (!is.null(input$general_concepts_table_search_columns)) {
        saved_table_search(input$general_concepts_table_search_columns)
      }

      list_edit_mode(TRUE)

      # Wait for datatable to re-render, then restore state
      shiny::observe({
        req(list_edit_mode())

        proxy <- DT::dataTableProxy("general_concepts_table", session = session)

        # Restore column filters
        search_columns <- saved_table_search()
        if (!is.null(search_columns)) {
          DT::updateSearch(proxy, keywords = list(
            global = NULL,
            columns = search_columns
          ))
        }

        # Restore page position
        page_num <- saved_table_page()
        if (!is.null(page_num) && page_num > 0) {
          DT::selectPage(proxy, page_num)
        }
      }) %>% shiny::bindEvent(input$general_concepts_table_state, once = TRUE)
    })

    # Handle list cancel button
    observeEvent(input$list_cancel, {
      # Save current filters and page before exiting edit mode
      if (!is.null(input$general_concepts_table_search_columns)) {
        saved_table_search(input$general_concepts_table_search_columns)
      }
      if (!is.null(input$general_concepts_table_state)) {
        current_page <- input$general_concepts_table_state$start / input$general_concepts_table_state$length + 1
        saved_table_page(current_page)
      }

      # Restore original state
      if (!is.null(original_general_concepts())) {
        data <- local_data()
        data$general_concepts <- original_general_concepts()
        local_data(data)
        original_general_concepts(NULL)
      }
      list_edit_mode(FALSE)

      # Wait for datatable to re-render, then restore state
      shiny::observe({
        req(!list_edit_mode())

        proxy <- DT::dataTableProxy("general_concepts_table", session = session)

        # Restore column filters
        search_columns <- saved_table_search()
        if (!is.null(search_columns)) {
          DT::updateSearch(proxy, keywords = list(
            global = NULL,
            columns = search_columns
          ))
        }

        # Restore page position
        page_num <- saved_table_page()
        if (!is.null(page_num) && page_num > 0) {
          DT::selectPage(proxy, page_num)
        }
      }) %>% shiny::bindEvent(input$general_concepts_table_state, once = TRUE)
    })

    # Handle list save updates button
    observeEvent(input$list_save_updates, {
      req(list_edit_mode())

      # Save current filters and page before exiting edit mode
      if (!is.null(input$general_concepts_table_search_columns)) {
        saved_table_search(input$general_concepts_table_search_columns)
      }
      if (!is.null(input$general_concepts_table_state)) {
        current_page <- input$general_concepts_table_state$start / input$general_concepts_table_state$length + 1
        saved_table_page(current_page)
      }

      # Get current data
      general_concepts <- current_data()$general_concepts

      # Save general_concepts to CSV
      csv_path <- system.file("extdata", "csv", "general_concepts.csv", package = "indicate")

      # If package path doesn't exist, try local development path
      if (!file.exists(csv_path) || csv_path == "") {
        csv_path <- file.path("inst", "extdata", "csv", "general_concepts.csv")
      }

      if (file.exists(csv_path)) {
        readr::write_csv(general_concepts, csv_path)
        shiny::showNotification(
          "General concepts updated successfully!",
          type = "message",
          duration = 10
        )
      } else {
        shiny::showNotification(
          "Error: Could not find general_concepts.csv file",
          type = "error",
          duration = 10
        )
      }

      list_edit_mode(FALSE)
      original_general_concepts(NULL)

      # Wait for datatable to re-render, then restore state
      shiny::observe({
        req(!list_edit_mode())

        proxy <- DT::dataTableProxy("general_concepts_table", session = session)

        # Restore column filters
        search_columns <- saved_table_search()
        if (!is.null(search_columns)) {
          DT::updateSearch(proxy, keywords = list(
            global = NULL,
            columns = search_columns
          ))
        }

        # Restore page position
        page_num <- saved_table_page()
        if (!is.null(page_num) && page_num > 0) {
          DT::selectPage(proxy, page_num)
        }
      }) %>% shiny::bindEvent(input$general_concepts_table_state, once = TRUE)
    })

    # Handle cell edits in general concepts table
    observeEvent(input$general_concepts_table_cell_edit, {
      req(list_edit_mode())

      info <- input$general_concepts_table_cell_edit

      # Get current data
      general_concepts <- current_data()$general_concepts

      # Update the cell value
      row_num <- info$row
      col_num <- info$col + 1  # DT uses 0-based indexing for columns, add 1 for R
      new_value <- info$value

      # Map column number to actual column name
      # Columns: general_concept_id (1), category (2), subcategory (3), general_concept_name (4), athena_concept_id (5)
      if (col_num == 2) {
        # Category column
        general_concepts[row_num, "category"] <- new_value
      } else if (col_num == 3) {
        # Subcategory column
        general_concepts[row_num, "subcategory"] <- new_value
      } else if (col_num == 4) {
        # General concept name column
        general_concepts[row_num, "general_concept_name"] <- new_value
      } else if (col_num == 5) {
        # Athena concept ID column
        general_concepts[row_num, "athena_concept_id"] <- as.integer(new_value)
      }

      # Update local data
      data <- local_data()
      data$general_concepts <- general_concepts
      local_data(data)
    })

    # Handle delete general concept button
    observeEvent(input$delete_general_concept, {
      req(list_edit_mode())

      # Save current page number before deletion
      if (!is.null(input$general_concepts_table_state)) {
        current_page <- input$general_concepts_table_state$start / input$general_concepts_table_state$length + 1
        saved_table_page(current_page)
      }

      concept_id <- input$delete_general_concept
      if (!is.null(concept_id)) {
        # Remove from general_concepts
        general_concepts <- current_data()$general_concepts %>%
          dplyr::filter(general_concept_id != as.integer(concept_id))

        # Also remove associated mappings
        concept_mappings <- current_data()$concept_mappings %>%
          dplyr::filter(general_concept_id != as.integer(concept_id))

        # Update local data
        data <- local_data()
        data$general_concepts <- general_concepts
        data$concept_mappings <- concept_mappings
        local_data(data)

        # Restore page position
        page_num <- saved_table_page()
        if (!is.null(page_num) && page_num > 0) {
          # Check if page still exists after deletion
          total_rows <- nrow(general_concepts)
          page_length <- 25
          max_page <- ceiling(total_rows / page_length)

          # If current page no longer exists, go to last page
          target_page <- min(page_num, max_page)

          proxy <- DT::dataTableProxy("general_concepts_table", session = session)
          DT::selectPage(proxy, target_page)
        }

        shiny::showNotification(
          "Concept deleted",
          type = "message",
          duration = 5
        )
      }
    })

    # Handle show add concept modal button
    observeEvent(input$show_add_concept_modal, {
      # Update category choices
      general_concepts <- current_data()$general_concepts
      categories <- sort(unique(general_concepts$category))

      updateSelectizeInput(session, "new_concept_category", choices = categories, selected = character(0))
      updateSelectizeInput(session, "new_concept_subcategory", choices = character(0), selected = character(0))

      # Show the custom modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("add_concept_modal")))
    })

    # Update subcategories when category changes in add concept modal
    observeEvent(input$new_concept_category, {
      if (is.null(input$new_concept_category) || identical(input$new_concept_category, "")) {
        return()
      }

      general_concepts <- current_data()$general_concepts
      selected_category <- input$new_concept_category

      # Get subcategories for the selected category
      subcategories_for_category <- general_concepts %>%
        dplyr::filter(category == selected_category) %>%
        dplyr::pull(subcategory) %>%
        unique() %>%
        sort()

      # Update subcategory choices
      updateSelectizeInput(
        session,
        "new_concept_subcategory",
        choices = subcategories_for_category,
        server = TRUE
      )
    }, ignoreInit = TRUE)

    # Handle add new concept
    observeEvent(input$add_new_concept, {
      # Determine which category/subcategory field is active
      category <- if (!is.null(input$new_concept_category_text) && nchar(trimws(input$new_concept_category_text)) > 0) {
        input$new_concept_category_text
      } else {
        input$new_concept_category
      }

      subcategory <- if (!is.null(input$new_concept_subcategory_text) && nchar(trimws(input$new_concept_subcategory_text)) > 0) {
        input$new_concept_subcategory_text
      } else {
        input$new_concept_subcategory
      }

      concept_name <- input$new_concept_name
      athena_id <- input$new_concept_athena_id

      # Validation with visual feedback
      has_error <- FALSE

      # Reset all borders first
      shinyjs::runjs(sprintf("
        document.getElementById('%s').style.border = '';
        $('#%s').parent().find('.selectize-control .selectize-input').css('border', '');
        document.getElementById('%s').style.border = '';
        $('#%s').parent().find('.selectize-control .selectize-input').css('border', '');
        document.getElementById('%s').style.border = '';
      ", ns("new_concept_name"), ns("new_concept_category"), ns("new_concept_category_text"), ns("new_concept_subcategory"), ns("new_concept_subcategory_text")))

      # Validate concept name
      if (is.null(concept_name) || nchar(trimws(concept_name)) == 0) {
        has_error <- TRUE
        shinyjs::runjs(sprintf("document.getElementById('%s').style.border = '2px solid #dc3545'", ns("new_concept_name")))
      }

      # Validate category - only highlight the visible field
      if (is.null(category) || nchar(trimws(category)) == 0) {
        has_error <- TRUE
        shinyjs::runjs(sprintf("
          var categorySelectContainer = document.getElementById('%s');
          var categoryTextContainer = document.getElementById('%s');
          if (categorySelectContainer.style.display !== 'none') {
            $('#%s').parent().find('.selectize-control .selectize-input').css('border', '2px solid #dc3545');
          } else {
            document.getElementById('%s').style.border = '2px solid #dc3545';
          }
        ", ns("category_select_container"), ns("category_text_container"), ns("new_concept_category"), ns("new_concept_category_text")))
      }

      # Validate subcategory - only highlight the visible field
      if (is.null(subcategory) || nchar(trimws(subcategory)) == 0) {
        has_error <- TRUE
        shinyjs::runjs(sprintf("
          var subcategorySelectContainer = document.getElementById('%s');
          var subcategoryTextContainer = document.getElementById('%s');
          if (subcategorySelectContainer.style.display !== 'none') {
            $('#%s').parent().find('.selectize-control .selectize-input').css('border', '2px solid #dc3545');
          } else {
            document.getElementById('%s').style.border = '2px solid #dc3545';
          }
        ", ns("subcategory_select_container"), ns("subcategory_text_container"), ns("new_concept_subcategory"), ns("new_concept_subcategory_text")))
      }

      if (has_error) {
        return()
      }

      # Get current data
      general_concepts <- current_data()$general_concepts

      # Generate new ID (max + 1)
      new_id <- max(general_concepts$general_concept_id, na.rm = TRUE) + 1

      # Process athena_id (convert to integer if valid number, otherwise NA)
      athena_id_value <- if (is.null(athena_id) || nchar(trimws(athena_id)) == 0) {
        NA_integer_
      } else {
        as_int <- suppressWarnings(as.integer(trimws(athena_id)))
        if (is.na(as_int)) NA_integer_ else as_int
      }

      # Create new row
      new_row <- data.frame(
        general_concept_id = new_id,
        category = trimws(category),
        subcategory = trimws(subcategory),
        general_concept_name = trimws(concept_name),
        athena_concept_id = athena_id_value,
        comments = NA_character_,
        stringsAsFactors = FALSE
      )

      # Add to general_concepts and sort alphabetically
      general_concepts <- rbind(general_concepts, new_row) %>%
        dplyr::arrange(category, subcategory, general_concept_name)

      # Find the row index of the newly added concept after sorting
      new_concept_row_index <- which(
        general_concepts$general_concept_id == new_id &
        general_concepts$category == trimws(category) &
        general_concepts$subcategory == trimws(subcategory) &
        general_concepts$general_concept_name == trimws(concept_name)
      )[1]

      # Save to CSV
      csv_path <- system.file("extdata", "csv", "general_concepts.csv", package = "indicate")
      if (!file.exists(csv_path) || csv_path == "") {
        csv_path <- file.path("inst", "extdata", "csv", "general_concepts.csv")
      }

      if (file.exists(csv_path)) {
        readr::write_csv(general_concepts, csv_path)

        # Update local data
        data <- local_data()
        data$general_concepts <- general_concepts
        local_data(data)

        # Close modal and reset fields
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("add_concept_modal")))

        # Reset input fields
        shiny::updateTextInput(session, "new_concept_name", value = "")
        shiny::updateTextInput(session, "new_concept_athena_id", value = "")
        shiny::updateTextInput(session, "new_concept_category_text", value = "")
        shiny::updateTextInput(session, "new_concept_subcategory_text", value = "")
        updateSelectizeInput(session, "new_concept_category", selected = character(0))
        updateSelectizeInput(session, "new_concept_subcategory", selected = character(0))

        # Calculate which page the new concept is on (1-indexed for DT::selectPage)
        page_length <- 25  # Default page length from datatable
        target_page <- ceiling(new_concept_row_index / page_length)

        # Use DT proxy to navigate to the correct page
        proxy <- DT::dataTableProxy("general_concepts_table", session = session)
        DT::selectPage(proxy, target_page)

        # Highlight the row with green fade effect
        # Row index in DataTable is 0-indexed
        dt_row_index <- new_concept_row_index - 1

        shinyjs::runjs(sprintf("
          setTimeout(function() {
            try {
              var tableElement = $('#%s');
              if (tableElement.length && $.fn.DataTable.isDataTable(tableElement)) {
                var table = tableElement.DataTable();
                var row = table.row(%d).node();
                if (row) {
                  $(row).css({
                    'background-color': '#28a745',
                    'transition': 'background-color 2s ease-out'
                  });

                  // Fade back to normal
                  setTimeout(function() {
                    $(row).css('background-color', '');
                  }, 100);
                }
              }
            } catch(e) {
              console.error('Row highlight error:', e);
            }
          }, 200);
        ", ns("general_concepts_table"), dt_row_index))

        shiny::showNotification(
          "Concept added successfully!",
          type = "message",
          duration = 10
        )
      } else {
        shiny::showNotification(
          "Error: Could not find general_concepts.csv file",
          type = "error",
          duration = 10
        )
      }
    })

    # Handle edit page button
    observeEvent(input$edit_page, {
      edit_mode(TRUE)
    })

    # Handle cancel edit button
    observeEvent(input$cancel_edit, {
      # Reset all unsaved changes
      edited_recommended(list())
      # edited_comment(NULL)
      edit_mode(FALSE)
      # Reset tab to comments
      comments_tab("comments")
    })

    # Handle save updates button
    observeEvent(input$save_updates, {
      req(edit_mode())

      concept_id <- selected_concept_id()
      req(concept_id)

      # Get current data
      general_concepts <- current_data()$general_concepts
      concept_mappings <- current_data()$concept_mappings

      # Update comments in general_concepts
      new_comment <- input$comments_input
      if (!is.null(new_comment)) {
        general_concepts <- general_concepts %>%
          dplyr::mutate(
            comments = ifelse(
              general_concept_id == concept_id,
              new_comment,
              comments
            )
          )
      }

      # Update statistical_summary in general_concepts
      new_statistical_summary <- input$statistical_summary_editor
      if (!is.null(new_statistical_summary)) {
        # Validate JSON before saving
        is_valid_json <- tryCatch({
          jsonlite::fromJSON(new_statistical_summary)
          TRUE
        }, error = function(e) {
          FALSE
        })

        if (is_valid_json) {
          general_concepts <- general_concepts %>%
            dplyr::mutate(
              statistical_summary = ifelse(
                general_concept_id == concept_id,
                new_statistical_summary,
                statistical_summary
              )
            )
        } else {
          # Show error notification for invalid JSON
          shiny::showNotification(
            "Invalid JSON in Statistical Summary. Changes not saved.",
            type = "error",
            duration = 5
          )
        }
      }

      # Update EHDEN and LOINC values in concept_mappings for selected concept
      selected_omop_id <- selected_mapped_concept_id()
      if (!is.null(selected_omop_id)) {
        # Update ehden_num_data_sources
        new_ehden_data_sources <- input$ehden_num_data_sources_input
        if (!is.null(new_ehden_data_sources)) {
          concept_mappings <- concept_mappings %>%
            dplyr::mutate(
              ehden_num_data_sources = ifelse(
                general_concept_id == concept_id & omop_concept_id == selected_omop_id,
                as.character(new_ehden_data_sources),
                ehden_num_data_sources
              )
            )
        }

        # Update ehden_rows_count
        new_ehden_rows <- input$ehden_rows_count_input
        if (!is.null(new_ehden_rows)) {
          concept_mappings <- concept_mappings %>%
            dplyr::mutate(
              ehden_rows_count = ifelse(
                general_concept_id == concept_id & omop_concept_id == selected_omop_id,
                as.integer(new_ehden_rows),
                ehden_rows_count
              )
            )
        }

        # Update loinc_rank
        new_loinc_rank <- input$loinc_rank_input
        if (!is.null(new_loinc_rank)) {
          concept_mappings <- concept_mappings %>%
            dplyr::mutate(
              loinc_rank = ifelse(
                general_concept_id == concept_id & omop_concept_id == selected_omop_id,
                as.integer(new_loinc_rank),
                loinc_rank
              )
            )
        }
      }

      # Update recommended values in concept_mappings
      recommended_edits <- edited_recommended()

      if (length(recommended_edits) > 0) {
        for (omop_id in names(recommended_edits)) {
          new_rec_value <- recommended_edits[[omop_id]]

          # Check if this concept already exists in concept_mappings
          existing_row <- concept_mappings %>%
            dplyr::filter(
              general_concept_id == concept_id &
              omop_concept_id == as.integer(omop_id)
            )

          if (nrow(existing_row) > 0) {
            # Update existing row
            concept_mappings <- concept_mappings %>%
              dplyr::mutate(
                recommended = ifelse(
                  general_concept_id == concept_id & omop_concept_id == as.integer(omop_id),
                  new_rec_value,
                  recommended
                )
              )
          } else if (isTRUE(new_rec_value)) {
            # Add new row only if recommended = TRUE
            # Get concept info from vocabularies or current data
            vocab_data <- vocabularies()

            if (!is.null(vocab_data) && !is.null(vocab_data$concept)) {
              tryCatch({
                # Filter and collect from DuckDB
                new_concept <- vocab_data$concept %>%
                  dplyr::filter(concept_id == as.integer(omop_id)) %>%
                  dplyr::collect()  # Materialize the data from DuckDB
              }, error = function(e) {
                new_concept <- data.frame()
              })

              if (nrow(new_concept) > 0) {
                # Create new row with minimal structure (new schema)
                if (nrow(concept_mappings) > 0) {
                  # Take first row as template and modify it
                  new_row <- concept_mappings[1, ]
                  new_row$general_concept_id <- as.integer(concept_id)
                  new_row$omop_concept_id <- as.integer(omop_id)
                  new_row$omop_unit_concept_id <- as.character("/")
                  new_row$recommended <- TRUE
                } else {
                  # Fallback if concept_mappings is empty
                  new_row <- data.frame(
                    general_concept_id = as.integer(concept_id),
                    omop_concept_id = as.integer(omop_id),
                    omop_unit_concept_id = "/",
                    recommended = TRUE,
                    stringsAsFactors = FALSE
                  )
                }

                concept_mappings <- dplyr::bind_rows(concept_mappings, new_row)
              }
            }
          }
        }
      }

      # Write to CSV files
      tryCatch({
        readr::write_csv(
          general_concepts,
          app_sys("extdata", "csv", "general_concepts.csv")
        )

        readr::write_csv(
          concept_mappings,
          app_sys("extdata", "csv", "concept_mappings.csv")
        )

        # Update local data
        updated_data <- list(
          general_concepts = general_concepts,
          concept_mappings = concept_mappings
        )
        local_data(updated_data)

        # Reset edit state
        edited_recommended(list())
        # edited_comment(NULL)
        edit_mode(FALSE)
        # Reset tab to comments
        comments_tab("comments")

        # Show success message
        shiny::showNotification(
          "Changes saved successfully!",
          type = "message",
          duration = 10
        )
      }, error = function(e) {
        shiny::showNotification(
          paste("Error saving changes:", e$message),
          type = "error",
          duration = 5
        )
      })
    })

    # Handle reset statistical summary button
    observeEvent(input$reset_statistical_summary, {
      shinyAce::updateAceEditor(
        session,
        "statistical_summary_editor",
        value = get_default_statistical_summary_template()
      )
    })

    # Handle toggle recommended in edit mode
    observeEvent(input$toggle_recommended, {
      req(edit_mode())

      toggle_data <- input$toggle_recommended
      omop_id <- as.integer(toggle_data$omop_id)
      new_value <- toggle_data$new_value

      # Store the change in edited_recommended
      current_edits <- edited_recommended()
      current_edits[[as.character(omop_id)]] <- (new_value == "Yes")
      edited_recommended(current_edits)
    }, ignoreInit = TRUE)

    # Handle delete concept in edit mode
    observeEvent(input$delete_concept, {
      req(edit_mode())

      concept_id <- selected_concept_id()
      req(concept_id)

      delete_data <- input$delete_concept
      omop_id <- as.integer(delete_data$omop_id)

      # Get current data
      concept_mappings <- current_data()$concept_mappings

      # Remove the row from concept_mappings
      concept_mappings <- concept_mappings %>%
        dplyr::filter(!(general_concept_id == concept_id & omop_concept_id == omop_id))

      # Update local data immediately
      updated_data <- list(
        general_concepts = current_data()$general_concepts,
        concept_mappings = concept_mappings
      )
      local_data(updated_data)

      # Show confirmation message
      shiny::showNotification(
        "Concept removed from mappings",
        type = "message",
        duration = 10
      )
    }, ignoreInit = TRUE)

    # # Track comment changes in edit mode
    # observeEvent(input$comments_input, {
    #   req(edit_mode())
    #   edited_comment(input$comments_input)
    # }, ignoreInit = TRUE)

    # Update DataTable filter when categories change
    observeEvent(selected_categories(), {
      categories <- selected_categories()

      # Create proxy for the DataTable
      proxy <- DT::dataTableProxy("general_concepts_table", session = session)

      if (length(categories) > 0) {
        # Format as JSON array for multi-select filter: ["Category1", "Category2"]
        search_string <- jsonlite::toJSON(categories, auto_unbox = FALSE)

        # Update the search for the Category column (column index 1, 0-based)
        DT::updateSearch(proxy, keywords = list(
          global = NULL,
          columns = list(NULL, as.character(search_string))  # NULL for ID column, JSON array for Category column
        ))
      } else {
        # Clear the filter
        DT::updateSearch(proxy, keywords = list(
          global = NULL,
          columns = list(NULL, NULL)
        ))
      }
    })

    # Render comments or statistical summary based on active tab
    output$comments_display <- renderUI({
      concept_id <- selected_concept_id()
      req(concept_id)

      # Force re-render when edit_mode or tab changes
      is_editing <- edit_mode()
      active_tab <- comments_tab()
      local_data()  # Add dependency to trigger re-render when data updates

      concept_info <- current_data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      # Display based on active tab
      if (active_tab == "comments") {
        # Comments tab
        if (is_editing) {
          # Edit mode: show textarea
          current_comment <- if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1])) {
            concept_info$comments[1]
          } else {
            ""
          }

          tags$div(
            style = "height: 100%;",
            shiny::textAreaInput(
              ns("comments_input"),
              label = NULL,
              value = current_comment,
              placeholder = "Enter ETL guidance and comments here...",
              width = "100%",
              height = "100%"
            )
          )
        } else {
          # View mode: show formatted comment
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
        }
      } else {
        # Statistical Summary tab
        if (is_editing) {
          # Edit mode: show JSON editor with aceEditor
          current_summary <- if (nrow(concept_info) > 0 && !is.na(concept_info$statistical_summary[1])) {
            concept_info$statistical_summary[1]
          } else {
            get_default_statistical_summary_template()
          }

          tags$div(
            style = "height: 100%; display: flex; flex-direction: column;",
            tags$div(
              style = "padding: 10px; background: #f8f9fa; border-bottom: 1px solid #dee2e6; display: flex; justify-content: space-between; align-items: center;",
              tags$span(
                style = "font-weight: 600; color: #495057;",
                "JSON Editor"
              ),
              actionButton(
                ns("reset_statistical_summary"),
                "Reset to Template",
                class = "btn btn-sm",
                style = "background: #6c757d; color: white; border: none; padding: 4px 12px; border-radius: 4px;"
              )
            ),
            tags$div(
              style = "flex: 1; min-height: 0;",
              shinyAce::aceEditor(
                ns("statistical_summary_editor"),
                value = current_summary,
                mode = "json",
                theme = "chrome",
                height = "100%",
                fontSize = 11,
                showLineNumbers = TRUE,
                highlightActiveLine = TRUE,
                tabSize = 2
              )
            )
          )
        } else {
          # View mode: show statistical summary display
          summary_data <- NULL
          if (nrow(concept_info) > 0 && !is.na(concept_info$statistical_summary[1]) && nchar(concept_info$statistical_summary[1]) > 0) {
            tryCatch({
              summary_data <- jsonlite::fromJSON(concept_info$statistical_summary[1])
            }, error = function(e) {
              summary_data <<- NULL
            })
          }

          if (!is.null(summary_data)) {
            # Helper function to create detail items
            create_detail_item <- function(label, value) {
              display_value <- if (is.null(value) || (is.character(value) && value == "")) {
                "/"
              } else {
                as.character(value)
              }

              tags$div(
                class = "detail-item",
                tags$strong(paste0(label, ":")),
                tags$span(display_value)
              )
            }

            # Display statistical summary in 2-column layout
            tags$div(
              style = "height: 100%; overflow-y: auto; padding: 15px; background: #ffffff;",
              tags$div(
                style = "display: grid; grid-template-columns: 1fr 1fr; gap: 20px;",

                # Left Column
                tags$div(
                  # Data Types Section
                  tags$h5(style = "margin: 0 0 12px 0; color: #0f60af; font-size: 14px; font-weight: 600; border-bottom: 2px solid #0f60af; padding-bottom: 6px;", "Data Types"),
                  if (!is.null(summary_data$data_types) && length(summary_data$data_types) > 0) {
                    tags$div(
                      style = "margin-bottom: 20px;",
                      create_detail_item("Types", paste(summary_data$data_types, collapse = ", "))
                    )
                  } else {
                    tags$p(style = "color: #6c757d; font-style: italic; margin-bottom: 20px;", "No data types specified")
                  },

                  # Statistical Data Section
                  tags$h5(style = "margin: 20px 0 12px 0; color: #0f60af; font-size: 14px; font-weight: 600; border-bottom: 2px solid #0f60af; padding-bottom: 6px;", "Statistical Data"),
                  if (!is.null(summary_data$statistical_data) && length(summary_data$statistical_data) > 0) {
                    tagList(
                      lapply(names(summary_data$statistical_data), function(key) {
                        value <- summary_data$statistical_data[[key]]
                        create_detail_item(gsub("_", " ", tools::toTitleCase(key)), if (is.null(value)) "/" else value)
                      })
                    )
                  } else {
                    tags$p(style = "color: #6c757d; font-style: italic;", "No statistical data available")
                  }
                ),

                # Right Column
                tags$div(
                  # Temporal Information Section
                  tags$h5(style = "margin: 0 0 12px 0; color: #0f60af; font-size: 14px; font-weight: 600; border-bottom: 2px solid #0f60af; padding-bottom: 6px;", "Temporal Information"),
                  if (!is.null(summary_data$temporal_info)) {
                    tagList(
                      if (!is.null(summary_data$temporal_info$frequency_range)) {
                        tagList(
                          create_detail_item("Frequency Min", if (is.null(summary_data$temporal_info$frequency_range$min)) "/" else summary_data$temporal_info$frequency_range$min),
                          create_detail_item("Frequency Max", if (is.null(summary_data$temporal_info$frequency_range$max)) "/" else summary_data$temporal_info$frequency_range$max)
                        )
                      },
                      if (!is.null(summary_data$temporal_info$measurement_period) && length(summary_data$temporal_info$measurement_period) > 0) {
                        create_detail_item("Measurement Period", paste(summary_data$temporal_info$measurement_period, collapse = ", "))
                      } else {
                        create_detail_item("Measurement Period", "/")
                      }
                    )
                  } else {
                    tags$p(style = "color: #6c757d; font-style: italic;", "No temporal information available")
                  },

                  # Possible Values Section
                  tags$h5(style = "margin: 20px 0 12px 0; color: #0f60af; font-size: 14px; font-weight: 600; border-bottom: 2px solid #0f60af; padding-bottom: 6px;", "Possible Values"),
                  if (!is.null(summary_data$possible_values) && length(summary_data$possible_values) > 0) {
                    tags$div(
                      style = "margin-top: 8px;",
                      tags$ul(
                        style = "margin: 0; padding-left: 20px;",
                        lapply(summary_data$possible_values, function(val) {
                          tags$li(style = "color: #212529; padding: 2px 0;", val)
                        })
                      )
                    )
                  } else {
                    tags$p(style = "color: #6c757d; font-style: italic;", "No possible values specified")
                  }
                )
              )
            )
          } else {
            tags$div(
              style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic; height: 100%; overflow-y: auto; box-sizing: border-box;",
              "No statistical summary available for this concept."
            )
          }
        }
      }
    })

    # Render concept mappings table
    output$concept_mappings_table <- DT::renderDT({
      concept_id <- selected_concept_id()
      req(concept_id)

      # Check if OHDSI vocabularies are loaded
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) {
        return(DT::datatable(
          data.frame(Message = "OHDSI vocabularies not loaded. Please configure the ATHENA folder in Settings."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Force re-render when edit_mode changes
      is_editing <- edit_mode()

      # Get concept category
      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)
      category <- concept_info$category[1]

      # For Drug concepts, use new approach with Clinical Drugs from Ingredient
      if (category == "Drug") {
        # Get athena_concept_id (Ingredient or Multiple Ingredients)
        athena_concept_id <- concept_info$athena_concept_id[1]

        vocab_data <- vocabularies()

        if (!is.null(vocab_data) && !is.na(athena_concept_id)) {
          # Get Clinical Drug descendants from the Ingredient
          clinical_drugs <- get_clinical_drugs_from_ingredient(
            athena_concept_id,
            vocab_data
          )

          if (nrow(clinical_drugs) > 0) {
            # Format as mappings table with all Clinical Drugs marked as recommended
            mappings <- clinical_drugs %>%
              dplyr::rename(omop_concept_id = concept_id) %>%
              dplyr::mutate(recommended = TRUE, source = "OHDSI") %>%
              dplyr::select(
                concept_name,
                vocabulary_id,
                concept_code,
                omop_concept_id,
                recommended,
                source
              )
          } else {
            # No Clinical Drugs found
            mappings <- data.frame(
              concept_name = character(),
              vocabulary_id = character(),
              concept_code = character(),
              omop_concept_id = integer(),
              recommended = logical(),
              source = character()
            )
          }
        } else {
          # No vocabulary data or no athena_concept_id
          mappings <- data.frame(
            concept_name = character(),
            vocabulary_id = character(),
            concept_code = character(),
            omop_concept_id = integer(),
            recommended = logical(),
            source = character()
          )
        }
      } else {
        # For non-Drug concepts, use original approach with CSV mappings
        csv_mappings <- current_data()$concept_mappings %>%
          dplyr::filter(general_concept_id == concept_id) %>%
          dplyr::mutate(source = "CSV")

        # Enrich with OMOP data (concept_name, vocabulary_id, concept_code)
        vocab_data_for_enrichment <- vocabularies()
        if (!is.null(vocab_data_for_enrichment) && nrow(csv_mappings) > 0) {
          # Get concept details from OMOP
          concept_ids <- csv_mappings$omop_concept_id
          omop_concepts <- vocab_data_for_enrichment$concept %>%
            dplyr::filter(concept_id %in% concept_ids) %>%
            dplyr::select(concept_id, concept_name, vocabulary_id, concept_code) %>%
            dplyr::collect()

          # Join with csv_mappings
          csv_mappings <- csv_mappings %>%
            dplyr::left_join(
              omop_concepts,
              by = c("omop_concept_id" = "concept_id")
            )
        }

        # Select final columns
        csv_mappings <- csv_mappings %>%
          dplyr::select(
            concept_name,
            vocabulary_id,
            concept_code,
            omop_concept_id,
            recommended,
            source
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

          # Remove duplicates and add recommended flag and source
          if (nrow(all_descendants) > 0) {
            all_descendants <- all_descendants %>%
              dplyr::distinct(omop_concept_id, .keep_all = TRUE) %>%
              dplyr::mutate(recommended = FALSE, source = "OHDSI") %>%
              dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended, source)
          }

          if (nrow(all_related) > 0) {
            all_related <- all_related %>%
              dplyr::distinct(omop_concept_id, .keep_all = TRUE) %>%
              dplyr::mutate(recommended = FALSE, source = "OHDSI") %>%
              dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended, source)
          }

          # Combine all sources
          # For duplicates, csv_mappings values take priority (especially for recommended flag)
          all_concepts <- dplyr::bind_rows(all_descendants, all_related)

          # Only process if there are concepts from OHDSI
          if (nrow(all_concepts) > 0) {
            all_concepts <- all_concepts %>%
              dplyr::distinct(omop_concept_id, .keep_all = TRUE)

            # Merge with csv_mappings, updating recommended flag and source from CSV where it exists
            mappings <- all_concepts %>%
              dplyr::left_join(
                csv_mappings %>% dplyr::select(omop_concept_id, recommended, source),
                by = "omop_concept_id",
                suffix = c("_auto", "_csv")
              ) %>%
              dplyr::mutate(
                recommended = dplyr::coalesce(recommended_csv, recommended_auto),
                source = dplyr::coalesce(source_csv, source_auto)
              ) %>%
              dplyr::select(-recommended_auto, -recommended_csv, -source_auto, -source_csv) %>%
              dplyr::bind_rows(
                # Add CSV concepts that aren't in descendants/related
                csv_mappings %>%
                  dplyr::anti_join(all_concepts, by = "omop_concept_id")
              ) %>%
              dplyr::distinct(omop_concept_id, .keep_all = TRUE) %>%
              dplyr::arrange(dplyr::desc(recommended), concept_name)
          } else {
            # No OHDSI concepts, just use csv_mappings
            mappings <- csv_mappings
          }
        } else {
          mappings <- csv_mappings
        }
      }

      # Get athena_concept_id for marking the general concept
      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)
      athena_concept_id <- concept_info$athena_concept_id[1]

      # Mark the general concept and convert recommended to Yes/No or toggle
      if (nrow(mappings) > 0) {
        mappings <- mappings %>%
          dplyr::mutate(
            is_general_concept = if (!is.na(athena_concept_id)) {
              omop_concept_id == athena_concept_id
            } else {
              FALSE
            }
          )

        # Create toggle HTML for edit mode, or simple Yes/No for view mode
        # For Drug concepts, don't show recommended/action columns
        if (is_editing && category != "Drug") {
          mappings <- mappings %>%
            dplyr::mutate(
              recommended = sprintf(
                '<label class="toggle-switch" data-omop-id="%s"><input type="checkbox" %s><span class="toggle-slider"></span></label>',
                omop_concept_id,
                ifelse(recommended, 'checked', '')
              ),
              action = ifelse(
                source == "CSV",
                sprintf('<i class="fa fa-trash delete-icon" data-omop-id="%s" style="cursor: pointer; color: #dc3545;"></i>', omop_concept_id),
                ""
              )
            )
        } else if (!is_editing) {
          mappings <- mappings %>%
            dplyr::mutate(recommended = ifelse(recommended, "Yes", "No"))
        }
      } else {
        # If no concepts, show empty table
        return(DT::datatable(
          data.frame(Message = "No concepts found."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Reorder columns - for Drug in edit mode, exclude recommended/action/source
      if (is_editing && category != "Drug") {
        mappings <- mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, recommended, source, action, omop_concept_id, is_general_concept)
      } else if (is_editing && category == "Drug") {
        mappings <- mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, is_general_concept)
      } else {
        mappings <- mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, recommended, omop_concept_id, is_general_concept)
      }

      # Cache mappings for selection handling (before converting recommended to Yes/No)
      # For Drug concepts, the recommended column doesn't exist in edit mode
      if (is_editing && category == "Drug") {
        mappings_for_cache <- mappings
      } else {
        mappings_for_cache <- mappings %>%
          dplyr::mutate(recommended = recommended == "Yes")
      }
      current_mappings(mappings_for_cache)

      # Load JavaScript callbacks
      callback <- JS(paste(readLines(app_sys("www", "dt_callback.js")), collapse = "\n"))
      keyboard_nav <- paste(readLines(app_sys("www", "keyboard_nav.js")), collapse = "\n")

      # Build initComplete callback that includes keyboard nav
      init_complete_js <- create_keyboard_nav(keyboard_nav, TRUE, FALSE)

      # Configure DataTable columns based on edit mode and category
      if (is_editing && category != "Drug") {
        escape_cols <- c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE)  # Don't escape HTML in recommended and action columns
        col_names <- c("Concept Name", "Vocabulary", "Code", "Recommended", "Source", "Action", "OMOP ID", "")
        col_defs <- list(
          list(targets = 3, width = "100px", className = 'dt-center'),  # Recommended column
          list(targets = 4, width = "80px", className = 'dt-center'),   # Source column
          list(targets = 5, width = "60px", className = 'dt-center'),   # Action column
          list(targets = c(6, 7), visible = FALSE)  # OMOP ID and IsGeneral columns hidden
        )
      } else if (is_editing && category == "Drug") {
        escape_cols <- TRUE
        col_names <- c("Concept Name", "Vocabulary", "Code", "OMOP ID", "")
        col_defs <- list(
          list(targets = c(3, 4), visible = FALSE)  # OMOP ID and IsGeneral columns hidden
        )
      } else {
        escape_cols <- TRUE
        col_names <- c("Concept Name", "Vocabulary", "Code", "Recommended", "OMOP ID", "")
        col_defs <- list(
          list(targets = 3, width = "100px", className = 'dt-center'),  # Recommended column
          list(targets = c(4, 5), visible = FALSE)  # OMOP ID and IsGeneral columns hidden
        )
      }

      dt <- DT::datatable(
        mappings,
        selection = 'none',
        rownames = FALSE,
        escape = escape_cols,
        extensions = c('Select'),
        colnames = col_names,
        options = list(
          pageLength = 8,
          dom = 'tip',
          select = list(style = 'single', info = FALSE),
          columnDefs = col_defs,
          initComplete = init_complete_js
        ),
        callback = callback
      )

      # Apply formatStyle only in view mode (not edit mode with toggles)
      if (!is_editing) {
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
      }

      dt <- dt %>%
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

    # Observe tab switching for comments
    observeEvent(input$switch_comments_tab, {
      comments_tab(input$switch_comments_tab)
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
          csv_mappings <- current_data()$concept_mappings %>%
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

      concept_mapping <- current_data()$concept_mappings %>%
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
            if (fhir_url == "no_link") {
              tags$div(
                class = "detail-item",
                tags$strong("FHIR Resource"),
                tags$span(
                  style = "color: #999; font-style: italic;",
                  "No link available"
                )
              )
            } else {
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
            }
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

      # Get concept details from OHDSI vocabularies (for concept_name, vocabulary_id, concept_code)
      vocab_data <- vocabularies()
      validity_info <- NULL
      if (!is.null(vocab_data)) {
        validity_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == omop_concept_id) %>%
          dplyr::collect()
        if (nrow(validity_info) > 0) {
          validity_info <- validity_info[1, ]
          # Enrich info with OMOP data
          info$concept_name <- validity_info$concept_name
          info$vocabulary_id <- validity_info$vocabulary_id
          info$concept_code <- validity_info$concept_code
        } else {
          validity_info <- NULL
        }
      }

      # Get statistics from concept_statistics
      concept_stats <- current_data()$concept_statistics %>%
        dplyr::filter(omop_concept_id == !!omop_concept_id)

      if (nrow(concept_stats) > 0) {
        info$ehden_num_data_sources <- concept_stats$ehden_num_data_sources[1]
        info$ehden_rows_count <- concept_stats$ehden_rows_count[1]
        info$loinc_rank <- concept_stats$loinc_rank[1]
      } else {
        info$ehden_num_data_sources <- NA
        info$ehden_rows_count <- NA
        info$loinc_rank <- NA
      }

      # Build URLs
      athena_url <- paste0(config$athena_base_url, "/", info$omop_concept_id)
      fhir_url <- if (!is.null(info$vocabulary_id) && !is.null(info$concept_code)) {
        build_fhir_url(info$vocabulary_id, info$concept_code, config)
      } else {
        NULL
      }
      athena_unit_url <- if (!is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "" && info$omop_unit_concept_id != "/") {
        paste0(config$athena_base_url, "/", info$omop_unit_concept_id)
      } else {
        NULL
      }

      # Get unit concept code from OMOP if unit concept ID exists
      unit_concept_code <- NULL
      if (!is.null(vocab_data) && !is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "" && info$omop_unit_concept_id != "/") {
        unit_concept_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == as.integer(info$omop_unit_concept_id)) %>%
          dplyr::collect()
        if (nrow(unit_concept_info) > 0) {
          unit_concept_code <- unit_concept_info$concept_code[1]
        }
      }

      unit_fhir_url <- if (!is.null(unit_concept_code)) {
        build_unit_fhir_url(unit_concept_code, config)
      } else {
        NULL
      }

      # Get edit mode status
      is_editing <- edit_mode()

      # Create detail items with proper formatting
      create_detail_item <- function(label, value, format_number = FALSE, url = NULL, color = NULL, editable = FALSE, input_id = NULL, step = 1) {
        # If editable and in edit mode, show numeric input
        if (editable && is_editing && !is.null(input_id)) {
          input_value <- if (is.null(value)) {
            NA
          } else if (length(value) == 0) {
            NA
          } else if (length(value) == 1 && is.na(value)) {
            NA
          } else if (identical(value, "")) {
            NA
          } else if (is.character(value)) {
            suppressWarnings(as.numeric(value))
          } else {
            as.numeric(value)
          }

          return(tags$div(
            class = "detail-item",
            tags$strong(label),
            tags$span(
              shiny::numericInput(
                ns(input_id),
                label = NULL,
                value = input_value,
                width = "100px",
                step = step
              )
            )
          ))
        }

        # Otherwise, display as read-only
        display_value <- if (is.null(value)) {
          "/"
        } else if (length(value) == 0) {
          "/"
        } else if (length(value) == 1 && is.na(value)) {
          "/"
        } else if (identical(value, "")) {
          "/"
        } else if (is.logical(value)) {
          if (isTRUE(value)) "Yes" else if (isFALSE(value)) "No" else "/"
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
        create_detail_item("EHDEN Data Sources", info$ehden_num_data_sources, format_number = TRUE, editable = TRUE, input_id = "ehden_num_data_sources_input", step = 1),
        create_detail_item("EHDEN Rows Count", info$ehden_rows_count, format_number = TRUE, editable = TRUE, input_id = "ehden_rows_count_input", step = 1000),
        create_detail_item("LOINC Rank", info$loinc_rank, editable = TRUE, input_id = "loinc_rank_input", step = 1),
        create_detail_item("Validity", validity_text, color = validity_color),
        create_detail_item("Standard", standard_text, color = standard_color),
        # Column 2 (must have exactly 8 items)
        create_detail_item("Vocabulary ID", info$vocabulary_id),
        create_detail_item("Domain ID", if (!is.null(validity_info) && !is.na(validity_info$domain_id)) validity_info$domain_id else "/"),
        create_detail_item("Concept Code", info$concept_code),
        create_detail_item("OMOP Concept ID", info$omop_concept_id, url = athena_url),
        if (!is.null(fhir_url)) {
          if (fhir_url == "no_link") {
            tags$div(
              class = "detail-item",
              tags$strong("FHIR Resource"),
              tags$span(
                style = "color: #999; font-style: italic;",
                "No link available"
              )
            )
          } else {
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
          }
        } else {
          tags$div(class = "detail-item", style = "visibility: hidden;")
        },
        create_detail_item("Unit Concept Name",
                          if (!is.null(unit_concept_code) && unit_concept_code != "") {
                            unit_concept_code
                          } else {
                            "/"
                          }),
        create_detail_item("OMOP Unit Concept ID",
                          if (!is.null(info$omop_unit_concept_id) && !is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "" && info$omop_unit_concept_id != "/") {
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
        tags$div(
          uiOutput(ns("related_stats_widget")),
          DT::DTOutput(ns("related_concepts_table"))
        )
      } else if (active_tab == "hierarchy") {
        tags$div(
          uiOutput(ns("hierarchy_stats_widget")),
          DT::DTOutput(ns("hierarchy_concepts_table"))
        )
      } else if (active_tab == "synonyms") {
        DT::DTOutput(ns("synonyms_table"))
      }
    })

    # Render related concepts table
    output$related_concepts_table <- DT::renderDT({
      omop_concept_id <- selected_mapped_concept_id()

      # Show instruction message if no concept is selected
      if (is.null(omop_concept_id)) {
        return(DT::datatable(
          data.frame(Message = "Select a concept from the Mapped Concepts table to view its details."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

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
          pageLength = 8,
          dom = 'tip',
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

    # Render related concepts statistics widget
    output$related_stats_widget <- renderUI({
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
        return(NULL)
      }

      # Count relationship types
      rel_counts <- related_concepts %>%
        dplyr::count(relationship_id, sort = TRUE)

      # Get top 4 relationships
      top_4 <- rel_counts %>%
        dplyr::slice_head(n = 4)

      # Calculate "Other" count
      other_count <- if (nrow(rel_counts) > 4) {
        sum(rel_counts$n[5:nrow(rel_counts)])
      } else {
        0
      }

      # Build stat items
      stat_items <- lapply(1:nrow(top_4), function(i) {
        tags$div(
          style = "display: flex; align-items: center; gap: 8px;",
          tags$span(
            style = "font-weight: bold; color: #333;",
            top_4$n[i]
          ),
          tags$span(
            style = "color: #666; font-size: 13px;",
            top_4$relationship_id[i]
          )
        )
      })

      # Add "Other" if needed
      if (other_count > 0) {
        stat_items <- c(stat_items, list(
          tags$div(
            style = "display: flex; align-items: center; gap: 8px;",
            tags$span(
              style = "font-weight: bold; color: #333;",
              other_count
            ),
            tags$span(
              style = "color: #666; font-size: 13px;",
              "Other"
            )
          )
        ))
      }

      tags$div(
        class = "related-stats-widget",
        style = "padding: 10px; margin-bottom: 10px; background: #f8f9fa; border-radius: 6px;",
        tags$div(
          style = "display: flex; gap: 20px; flex-wrap: wrap;",
          stat_items
        )
      )
    })

    # Render hierarchy statistics widget
    output$hierarchy_stats_widget <- renderUI({
      omop_concept_id <- selected_mapped_concept_id()
      req(omop_concept_id)

      vocab_data <- vocabularies()
      req(vocab_data)

      # Get hierarchy graph data to extract stats
      hierarchy_data <- get_concept_hierarchy_graph(omop_concept_id, vocab_data)

      if (is.null(hierarchy_data$stats)) {
        return(NULL)
      }

      stats <- hierarchy_data$stats

      tags$div(
        class = "hierarchy-stats-widget",
        style = "padding: 10px; margin-bottom: 10px; background: #f8f9fa; border-radius: 6px; display: flex; justify-content: space-between; align-items: center;",
        tags$div(
          style = "display: flex; gap: 20px;",
          tags$div(
            style = "display: flex; align-items: center; gap: 8px;",
            tags$span(
              style = "font-size: 18px; color: #6c757d;",
              "⬆"
            ),
            tags$span(
              style = "font-weight: bold; color: #333;",
              stats$total_ancestors
            ),
            tags$span(
              style = "color: #666; font-size: 13px;",
              "ancestors"
            )
          ),
          tags$div(
            style = "display: flex; align-items: center; gap: 8px;",
            tags$span(
              style = "font-size: 18px; color: #28a745;",
              "⬇"
            ),
            tags$span(
              style = "font-weight: bold; color: #333;",
              stats$total_descendants
            ),
            tags$span(
              style = "color: #666; font-size: 13px;",
              "descendants"
            )
          )
        ),
        actionButton(
          ns("view_hierarchy_graph"),
          "View Graph",
          class = "btn-view-graph",
          style = "padding: 8px 16px; background: #0f60af; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: 500;"
        )
      )
    })

    # Render hierarchy concepts table
    output$hierarchy_concepts_table <- DT::renderDT({
      omop_concept_id <- selected_mapped_concept_id()

      # Show instruction message if no concept is selected
      if (is.null(omop_concept_id)) {
        return(DT::datatable(
          data.frame(Message = "Select a concept from the Mapped Concepts table to view its details."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

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
          pageLength = 8,
          dom = 'tip',
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

    # Render synonyms table
    output$synonyms_table <- DT::renderDT({
      omop_concept_id <- selected_mapped_concept_id()

      # Show instruction message if no concept is selected
      if (is.null(omop_concept_id)) {
        return(DT::datatable(
          data.frame(Message = "Select a concept from the Mapped Concepts table to view its details."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      vocab_data <- vocabularies()
      req(vocab_data)

      synonyms <- get_concept_synonyms(omop_concept_id, vocab_data)

      if (nrow(synonyms) == 0) {
        return(DT::datatable(data.frame(Message = "No synonyms found for this concept."),
                             options = list(dom = 't'),
                             rownames = FALSE,
                             selection = 'none'))
      }

      # Select only synonym and language columns (hide language_concept_id)
      synonyms <- synonyms %>%
        dplyr::select(synonym, language, language_concept_id)

      DT::datatable(
        synonyms,
        selection = 'none',
        rownames = FALSE,
        colnames = c("Synonym", "Language", "Language ID"),
        options = list(
          pageLength = 8,
          dom = 'tip',
          columnDefs = list(
            list(targets = 2, visible = FALSE)  # Language ID hidden
          )
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
          if (fhir_url == "no_link") {
            tags$div(
              class = "detail-item",
              tags$strong("FHIR Resource"),
              tags$span(
                style = "color: #999; font-style: italic;",
                "No link available"
              )
            )
          } else {
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
          }
        } else {
          tags$div(class = "detail-item", style = "visibility: hidden;")
        },
        tags$div(class = "detail-item", style = "visibility: hidden;")
      )
    })

    # Render hierarchy graph breadcrumb
    output$hierarchy_graph_breadcrumb <- renderUI({
      omop_concept_id <- selected_mapped_concept_id()
      req(omop_concept_id)

      vocab_data <- vocabularies()
      req(vocab_data)

      # Get concept details
      concept_info <- vocab_data$concept %>%
        dplyr::filter(concept_id == omop_concept_id) %>%
        dplyr::collect()

      if (nrow(concept_info) == 0) {
        return(NULL)
      }

      tags$div(
        style = "display: flex; align-items: center; gap: 10px;",
        tags$span(
          style = "font-weight: 600; color: #333; font-size: 16px;",
          "Concept Hierarchy:"
        ),
        tags$span(
          style = "color: #0f60af; font-size: 16px; font-weight: 500;",
          concept_info$concept_name
        ),
        tags$span(
          style = "color: #999; font-size: 14px;",
          paste0("(", concept_info$vocabulary_id, " - ", concept_info$concept_code, ")")
        )
      )
    })

    # Render hierarchy graph
    output$hierarchy_graph <- visNetwork::renderVisNetwork({
      omop_concept_id <- selected_mapped_concept_id()
      req(omop_concept_id)

      vocab_data <- vocabularies()
      req(vocab_data)

      # Get hierarchy graph data
      hierarchy_data <- get_concept_hierarchy_graph(omop_concept_id, vocab_data,
                                                     max_levels_up = 5,
                                                     max_levels_down = 5)

      if (nrow(hierarchy_data$nodes) == 0) {
        return(NULL)
      }

      # Create visNetwork graph
      visNetwork::visNetwork(
        hierarchy_data$nodes,
        hierarchy_data$edges,
        height = "100%",
        width = "100%"
      ) %>%
        visNetwork::visHierarchicalLayout(
          direction = "UD",
          sortMethod = "directed",
          levelSeparation = 150,
          nodeSpacing = 200,
          treeSpacing = 250,
          blockShifting = TRUE,
          edgeMinimization = TRUE,
          parentCentralization = TRUE
        ) %>%
        visNetwork::visNodes(
          shadow = list(enabled = TRUE, size = 5),
          borderWidth = 2,
          margin = 10,
          widthConstraint = list(maximum = 250)
        ) %>%
        visNetwork::visEdges(
          smooth = list(type = "cubicBezier", roundness = 0.5),
          color = list(
            color = "#999",
            highlight = "#0f60af",
            hover = "#0f60af"
          )
        ) %>%
        visNetwork::visInteraction(
          navigationButtons = TRUE,
          hover = TRUE,
          zoomView = TRUE,
          dragView = TRUE,
          tooltipDelay = 100,
          hideEdgesOnDrag = FALSE,
          hideEdgesOnZoom = FALSE
        ) %>%
        visNetwork::visOptions(
          highlightNearest = list(
            enabled = TRUE,
            degree = 1,
            hover = TRUE,
            algorithm = "hierarchical"
          )
        ) %>%
        visNetwork::visPhysics(enabled = FALSE) %>%
        visNetwork::visLayout(randomSeed = 123)
    })

    # Observe view graph button click
    observeEvent(input$view_hierarchy_graph, {
      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("hierarchy_graph_modal")))

      # Fit the graph immediately
      visNetwork::visNetworkProxy(ns("hierarchy_graph")) %>%
        visNetwork::visFit(animation = list(duration = 500))
    })

    # Force Shiny to render output even when hidden
    outputOptions(output, "concept_modal_body", suspendWhenHidden = FALSE)
    outputOptions(output, "hierarchy_graph", suspendWhenHidden = FALSE)
    outputOptions(output, "hierarchy_graph_breadcrumb", suspendWhenHidden = FALSE)
  })
}
