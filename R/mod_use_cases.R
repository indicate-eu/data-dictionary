# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Use Cases management interface with two main views:
# - Use Cases List View: Browse and manage use cases with details panel
# - Use Case Configuration View: Assign general concepts to use cases
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Breadcrumb Navigation - Navigation breadcrumbs for multi-level views
#      ### Content Area - Dynamic content based on current view (list/config)
#         #### List View - Use cases table (70%) + details panel (30%)
#         #### Config View - Available concepts (50%) + selected concepts (50%)
#   ## UI - Modals
#      ### Modal - Add New Use Case - Form to create new use cases
#      ### Modal - Edit Use Case - Form to edit existing use cases
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### View State - Track current view (list/config) and selected use case
#      ### Data Management - Use cases and general concept assignments
#      ### Cascade Triggers - Reactive triggers for cascade pattern
#
#   ## 2) Server - Navigation & State Changes
#      ### Primary State Observers - Track changes to data, user, view
#      ### Cascade Observers - Propagate state changes to UI updates
#      ### Button Visibility - Dynamic button visibility based on user role
#
#   ## 3) Server - UI Rendering
#      ### Breadcrumb Rendering - Dynamic breadcrumb navigation
#      ### Content Area Rendering - Switch between list and config views
#      ### Use Cases Table - Display use cases with concept counts
#      ### Use Case Details - Show details of selected use case
#      ### Concept Tables - Available and selected concepts tables
#
#   ## 4) Server - User Actions
#      ### Use Case Management - Add, edit, delete, configure use cases
#      ### Concept Assignment - Add/remove general concepts to/from use cases
#      ### Table Row Selection - Select all, unselect all, double-click navigation
#
# UI SECTION ====

#' Use Cases Module - UI
#'
#' @description UI function for the use cases management module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS actionButton uiOutput textInput textAreaInput
#' @importFrom shiny updateTextInput updateTextAreaInput selectizeInput icon
#' @importFrom htmltools tags tagList
#' @importFrom DT DTOutput
mod_use_cases_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Initialize shinyjs
    shinyjs::useShinyjs(),

    ## UI - Main Layout ----
    ### Breadcrumb & Content Area ----
    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",
        # Breadcrumb navigation
        uiOutput(ns("breadcrumb")),

        # Dynamic content area
        uiOutput(ns("content_area"))
      )
    ),

    ## UI - Modals ----
    ### Modal - Add New Use Case ----
    tags$div(
      id = ns("add_use_case_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("add_use_case_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 700px;",
        tags$div(
          class = "modal-header",
          tags$h3("Add New Use Case"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("add_use_case_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$div(
            id = ns("new_use_case_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span("Name ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textInput(
              ns("new_use_case_name"),
              label = NULL,
              placeholder = "Enter use case name (required)",
              width = "100%"
            ),
            tags$div(
              id = ns("name_error"),
              class = "input-error-message",
              "Use case name is required"
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span("Short Description ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textAreaInput(
              ns("new_use_case_short_description"),
              label = NULL,
              placeholder = "Enter short description (1-2 sentences, required)",
              width = "100%",
              rows = 3
            ),
            tags$div(
              id = ns("short_desc_error"),
              class = "input-error-message",
              "Short description is required"
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              "Long Description",
              style = paste0(
                "display: block; font-weight: 600; ",
                "margin-bottom: 8px;"
              )
            ),
            textAreaInput(
              ns("new_use_case_long_description"),
              label = NULL,
              placeholder = "Enter detailed description (optional)",
              width = "100%",
              rows = 5
            )
          ),
          tags$div(
            style = paste0(
              "display: flex; justify-content: flex-end; ",
              "gap: 10px; margin-top: 20px;"
            ),
            tags$button(
              class = "btn btn-secondary",
              onclick = sprintf(
                "$('#%s').hide();",
                ns("add_use_case_modal")
              ),
              "Cancel"
            ),
            actionButton(
              ns("save_use_case"),
              "Add Use Case",
              class = "btn btn-primary"
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
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("delete_confirmation_modal")
      ),
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
          style = "padding: 20px;",
          tags$p(
            style = "font-size: 14px; margin-bottom: 20px;",
            "Are you sure you want to delete the selected use case(s)? This action cannot be undone."
          ),
          tags$p(
            style = "font-size: 14px; color: #dc3545; margin-bottom: 20px;",
            tags$strong("Note:"),
            " All concept assignments for this use case will also be removed."
          ),
          tags$div(
            style = paste0(
              "display: flex; justify-content: flex-end; ",
              "gap: 10px; margin-top: 20px;"
            ),
            tags$button(
              class = "btn btn-secondary",
              onclick = sprintf(
                "$('#%s').hide();",
                ns("delete_confirmation_modal")
              ),
              "Cancel"
            ),
            actionButton(
              ns("confirm_delete_use_case"),
              "Delete",
              class = "btn btn-danger"
            )
          )
        )
      )
    ),

    ### Modal - Edit Use Case ----
    tags$div(
      id = ns("edit_use_case_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("edit_use_case_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 700px;",
        tags$div(
          class = "modal-header",
          tags$h3("Edit Use Case"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("edit_use_case_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$div(
            id = ns("edit_use_case_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span("Name ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textInput(
              ns("edit_use_case_name"),
              label = NULL,
              placeholder = "Enter use case name (required)",
              width = "100%"
            ),
            tags$div(
              id = ns("edit_name_error"),
              class = "input-error-message",
              "Use case name is required"
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span("Short Description ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textAreaInput(
              ns("edit_use_case_short_description"),
              label = NULL,
              placeholder = "Enter short description (1-2 sentences, required)",
              width = "100%",
              rows = 3
            ),
            tags$div(
              id = ns("edit_short_desc_error"),
              class = "input-error-message",
              "Short description is required"
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              "Long Description",
              style = paste0(
                "display: block; font-weight: 600; ",
                "margin-bottom: 8px;"
              )
            ),
            textAreaInput(
              ns("edit_use_case_long_description"),
              label = NULL,
              placeholder = "Enter detailed description (optional)",
              width = "100%",
              rows = 5
            )
          ),
          tags$div(
            style = paste0(
              "display: flex; justify-content: flex-end; ",
              "gap: 10px; margin-top: 20px;"
            ),
            tags$button(
              class = "btn btn-secondary",
              onclick = sprintf(
                "$('#%s').hide();",
                ns("edit_use_case_modal")
              ),
              "Cancel"
            ),
            actionButton(
              ns("update_use_case"),
              "Update Use Case",
              class = "btn btn-primary",
              icon = icon("save")
            )
          )
        )
      )
    )
  )
}

# HELPER UI FUNCTIONS ====

#' Render Use Cases List View
#'
#' @description Renders the main use cases list with split panel
#'
#' @param ns Namespace function
#'
#' @return UI elements for use cases list view
#' @noRd
render_use_cases_list_ui <- function(ns) {
  tagList(
    # Action buttons bar
    tags$div(
      style = paste0(
        "margin: 5px 0 15px 0; display: flex; ",
        "justify-content: space-between; align-items: center;"
      ),
      # Title (matching dictionary explorer style)
      tags$div(
        class = "section-title",
        tags$span("Use Cases")
      ),
      tags$div(
        style = "display: flex; gap: 10px;",
        shinyjs::hidden(
          actionButton(
            ns("add_use_case_btn"),
            "Add Use Case",
            class = "btn btn-primary",
            icon = icon("plus")
          )
        ),
        shinyjs::hidden(
          actionButton(
            ns("edit_name_description_btn"),
            "Edit",
            class = "btn btn-secondary",
            icon = icon("edit")
          )
        ),
        shinyjs::hidden(
          actionButton(
            ns("configure_use_case_btn"),
            "Configure",
            class = "btn btn-secondary",
            icon = icon("cog")
          )
        ),
        shinyjs::hidden(
          actionButton(
            ns("delete_selected_btn"),
            "Delete",
            class = "btn btn-danger",
            icon = icon("trash")
          )
        )
      )
    ),

    # Split panel layout
    tags$div(
      style = "display: flex; gap: 20px; height: calc(100vh - 175px);",

      # Left panel: Use cases table (70%)
      tags$div(
        style = paste0(
          "flex: 0 0 70%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        tags$h4(
          "Use Cases",
          style = paste0(
            "margin: 0 0 15px 0; color: #0f60af; ",
            "border-bottom: 2px solid #0f60af; padding-bottom: 10px;"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: auto;",
          DT::DTOutput(ns("use_cases_table"))
        )
      ),

      # Right panel: Use case details (30%)
      tags$div(
        style = paste0(
          "flex: 0 0 30%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        tags$h4(
          "Use Case Details",
          style = paste0(
            "margin: 0 0 15px 0; color: #0f60af; ",
            "border-bottom: 2px solid #0f60af; padding-bottom: 10px;"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: auto;",
          uiOutput(ns("use_case_details"))
        )
      )
    )
  )
}

#' Render Use Case Configuration View
#'
#' @description Renders the use case configuration view with 3 panels
#'
#' @param ns Namespace function
#'
#' @return UI elements for use case configuration view
#' @noRd
render_use_case_config_ui <- function(ns) {
  tagList(
    # Two-panel layout for concept selection
    tags$div(
      style = "display: flex; gap: 20px; height: calc(100vh - 175px);",

      # Left panel: Available general concepts (50% width, 100% height)
      tags$div(
        style = paste0(
          "flex: 0 0 50%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        # Header with title
        tags$h4(
          "Available Concepts",
          style = paste0(
            "margin: 0 0 10px 0; color: #0f60af; ",
            "border-bottom: 2px solid #0f60af; padding-bottom: 10px;"
          )
        ),
        # Buttons row
        shinyjs::hidden(
          tags$div(
            id = ns("available_action_buttons"),
            style = "display: flex; gap: 10px; margin-bottom: 15px;",
            actionButton(
              ns("add_general_concepts_btn"),
              "Add Selected Concepts",
              class = "btn btn-primary btn-sm",
              icon = icon("arrow-right")
            ),
            tags$div(
              style = "display: flex; gap: 3px;",
              actionButton(
                ns("select_all_available"),
                NULL,
                class = "btn btn-sm btn-secondary",
                icon = icon("check-square"),
                title = "Select all rows"
              ),
              actionButton(
                ns("unselect_all_available"),
                NULL,
                class = "btn btn-sm btn-secondary",
                icon = icon("square"),
                title = "Unselect all rows"
              )
            )
          )
        ),
        # DataTable
        tags$div(
          style = "flex: 1; overflow: auto;",
          DT::DTOutput(ns("available_general_concepts_table"))
        )
      ),

      # Right panel: Selected general concepts (50% width, 100% height)
      tags$div(
        style = paste0(
          "flex: 0 0 50%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        # Header with title
        tags$h4(
          "Selected Concepts for Use Case",
          style = paste0(
            "margin: 0 0 10px 0; color: #28a745; ",
            "border-bottom: 2px solid #28a745; padding-bottom: 10px;"
          )
        ),
        # Buttons row
        shinyjs::hidden(
          tags$div(
            id = ns("selected_action_buttons"),
            style = "display: flex; gap: 10px; margin-bottom: 15px;",
            actionButton(
              ns("remove_general_concepts_btn"),
              "Remove Selected Concepts",
              class = "btn btn-danger btn-sm",
              icon = icon("times")
            ),
            tags$div(
              style = "display: flex; gap: 3px;",
              actionButton(
                ns("select_all_selected"),
                NULL,
                class = "btn btn-sm btn-secondary",
                icon = icon("check-square"),
                title = "Select all rows"
              ),
              actionButton(
                ns("unselect_all_selected"),
                NULL,
                class = "btn btn-sm btn-secondary",
                icon = icon("square"),
                title = "Unselect all rows"
              )
            )
          )
        ),
        # DataTable
        tags$div(
          style = "flex: 1; overflow: auto;",
          DT::DTOutput(ns("selected_general_concepts_table"))
        )
      )
    )
  )
}

# SERVER SECTION ====

#' Use Cases Module - Server
#'
#' @description Server function for the use cases management module
#'
#' @param id Module ID
#' @param data Reactive containing the application data
#' @param vocabularies Reactive containing OHDSI vocabulary data
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent showModal
#' @importFrom shiny reactiveVal updateTextInput updateTextAreaInput modalDialog
#' @importFrom shiny removeModal
#' @importFrom htmltools tags tagList HTML
#' @importFrom DT renderDT datatable formatStyle styleEqual
#' @importFrom dplyr left_join group_by summarise n filter inner_join select collect
mod_use_cases_server <- function(id, data, vocabularies = reactive({ NULL }), current_user = reactive(NULL), log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ## 1) Server - Reactive Values & State ====
    ### Reactive Values ----

    current_view <- reactiveVal("list")  # "list" or "config"
    selected_use_case <- reactiveVal(NULL)
    selected_use_case_row <- reactiveVal(NULL)  # For displaying details
    use_cases_reactive <- reactiveVal(NULL)
    general_concept_use_cases_reactive <- reactiveVal(NULL)

    ### Trigger Values (for cascade pattern) ----

    data_loaded_trigger <- reactiveVal(0)
    view_changed_trigger <- reactiveVal(0)
    user_changed_trigger <- reactiveVal(0)
    use_cases_data_changed_trigger <- reactiveVal(0)
    gc_use_cases_changed_trigger <- reactiveVal(0)

    # Cascade triggers
    button_visibility_trigger <- reactiveVal(0)
    breadcrumb_trigger <- reactiveVal(0)
    content_area_trigger <- reactiveVal(0)
    use_cases_table_trigger <- reactiveVal(0)
    use_case_details_trigger <- reactiveVal(0)
    available_concepts_table_trigger <- reactiveVal(0)
    selected_concepts_table_trigger <- reactiveVal(0)

    ### Initialize Data ----

    observe_event(data(), {
      if (is.null(data())) return()

      use_cases_reactive(data()$use_cases)
      general_concept_use_cases_reactive(data()$general_concept_use_cases)
      data_loaded_trigger(data_loaded_trigger() + 1)
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    ## 2) Server - Navigation & State Changes ====
    ### Primary State Observers ----

    observe_event(current_user(), {
      user_changed_trigger(user_changed_trigger() + 1)
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    observe_event(current_view(), {
      view_changed_trigger(view_changed_trigger() + 1)
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    observe_event(use_cases_reactive(), {
      use_cases_data_changed_trigger(use_cases_data_changed_trigger() + 1)
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    observe_event(general_concept_use_cases_reactive(), {
      gc_use_cases_changed_trigger(gc_use_cases_changed_trigger() + 1)
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    observe_event(selected_use_case_row(), {
      use_case_details_trigger(use_case_details_trigger() + 1)
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    ### Cascade Observers ----

    # When data, user, or view changes, update button visibility
    observe_event(c(data_loaded_trigger(), user_changed_trigger(), view_changed_trigger()), {
      button_visibility_trigger(button_visibility_trigger() + 1)
    }, ignoreInit = TRUE)

    # When view or selected use case changes, update breadcrumb and content area
    observe_event(c(view_changed_trigger(), selected_use_case()), {
      breadcrumb_trigger(breadcrumb_trigger() + 1)
      content_area_trigger(content_area_trigger() + 1)
    }, ignoreInit = TRUE)

    # When use cases data or concept assignments change, update table
    observe_event(c(use_cases_data_changed_trigger(), gc_use_cases_changed_trigger()), {
      use_cases_table_trigger(use_cases_table_trigger() + 1)
    }, ignoreInit = TRUE)

    # When general concept use cases change or view changes, update concept tables
    observe_event(c(gc_use_cases_changed_trigger(), view_changed_trigger(), selected_use_case()), {
      available_concepts_table_trigger(available_concepts_table_trigger() + 1)
      selected_concepts_table_trigger(selected_concepts_table_trigger() + 1)
    }, ignoreInit = TRUE)

    ### Helper Functions ----

    # Function to update button visibility based on user role
    update_button_visibility <- function() {
      user <- current_user()

      # Use shinyjs::delay to ensure DOM is ready
      shinyjs::delay(100, {
        if (!is.null(user) && user$role != "Anonymous") {
          shinyjs::show("add_use_case_btn")
          shinyjs::show("edit_name_description_btn")
          shinyjs::show("configure_use_case_btn")
          shinyjs::show("delete_selected_btn")
          shinyjs::show("available_action_buttons")
          shinyjs::show("selected_action_buttons")
        } else {
          shinyjs::hide("add_use_case_btn")
          shinyjs::hide("edit_name_description_btn")
          shinyjs::hide("configure_use_case_btn")
          shinyjs::hide("delete_selected_btn")
          shinyjs::hide("available_action_buttons")
          shinyjs::hide("selected_action_buttons")
        }
      })
    }

    # Helper function to get use cases with concept counts
    get_use_cases_with_counts <- reactive({
      use_cases_data <- use_cases_reactive()
      gc_uc_data <- general_concept_use_cases_reactive()

      if (is.null(use_cases_data) || is.null(gc_uc_data)) {
        return(data.frame(
          Name = character(0),
          `Short Description` = character(0),
          Concepts = integer(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Count concepts per use case
      concept_counts <- gc_uc_data %>%
        group_by(use_case_id) %>%
        summarise(concept_count = n(), .groups = "drop")

      # Join with use cases
      result <- use_cases_data %>%
        left_join(concept_counts, by = "use_case_id")

      # Replace NA counts with 0
      result$concept_count[is.na(result$concept_count)] <- 0

      # Format for display (include use_case_id as first column, will be hidden)
      display_df <- data.frame(
        use_case_id = result$use_case_id,
        Name = result$use_case_name,
        `Short Description` = ifelse(
          is.na(result$short_description),
          "",
          result$short_description
        ),
        Concepts = result$concept_count,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )

      return(display_df)
    })

    # Helper function to get available general concepts (excluding already selected ones)
    get_available_general_concepts <- reactive({
      if (is.null(data())) return(NULL)
      if (is.null(selected_use_case())) return(NULL)

      general_concepts <- data()$general_concepts
      use_case <- selected_use_case()
      gc_uc_data <- general_concept_use_cases_reactive()

      if (is.null(general_concepts)) {
        return(data.frame(
          general_concept_id = integer(0),
          Category = character(0),
          Subcategory = character(0),
          Concept = character(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Get IDs of concepts already selected for this use case
      selected_gc_ids <- c()
      if (!is.null(gc_uc_data)) {
        selected_gc_ids <- gc_uc_data %>%
          filter(use_case_id == use_case$id) %>%
          .$general_concept_id
      }

      # Filter out already selected concepts
      available_concepts <- general_concepts %>%
        filter(!general_concept_id %in% selected_gc_ids)

      # Format for display with factors for Category and Subcategory
      display_df <- data.frame(
        general_concept_id = available_concepts$general_concept_id,
        Category = factor(available_concepts$category),
        Subcategory = factor(available_concepts$subcategory),
        Concept = available_concepts$general_concept_name,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )

      return(display_df)
    })

    # Helper function to get selected general concepts for current use case
    get_selected_general_concepts <- reactive({
      if (is.null(selected_use_case())) return(NULL)
      if (is.null(data())) return(NULL)

      use_case <- selected_use_case()
      general_concepts <- data()$general_concepts
      gc_uc_data <- general_concept_use_cases_reactive()

      if (is.null(gc_uc_data)) {
        return(data.frame(
          general_concept_id = integer(0),
          Category = character(0),
          Subcategory = character(0),
          Concept = character(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Filter general concepts for this use case
      selected_gc_ids <- gc_uc_data %>%
        filter(use_case_id == use_case$id) %>%
        .$general_concept_id

      if (length(selected_gc_ids) == 0) {
        return(data.frame(
          general_concept_id = integer(0),
          Category = character(0),
          Subcategory = character(0),
          Concept = character(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Get general concept details
      gc_details <- general_concepts %>%
        filter(general_concept_id %in% selected_gc_ids)

      # Format for display with factors for Category and Subcategory
      display_df <- data.frame(
        general_concept_id = gc_details$general_concept_id,
        Category = factor(gc_details$category),
        Subcategory = factor(gc_details$subcategory),
        Concept = gc_details$general_concept_name,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )

      return(display_df)
    })

    ## 3) Server - UI Rendering ====
    ### Button Visibility ----

    # Update button visibility
    observe_event(button_visibility_trigger(), {
      update_button_visibility()
    }, ignoreInit = FALSE)

    ### Breadcrumb Rendering ----
    observe_event(breadcrumb_trigger(), {
      view <- current_view()

      output$breadcrumb <- renderUI({
        if (view == "list") {
          return(NULL)
        }

        if (view == "config") {
          use_case <- selected_use_case()
          use_case_name <- if (!is.null(use_case)) {
            use_case$name
          } else {
            "Unknown"
          }

          return(
            tags$div(
              class = "breadcrumb-nav",
              style = paste0(
                "padding: 10px 0 15px 0; font-size: 16px; ",
                "display: flex; justify-content: space-between; align-items: center;"
              ),
              # Left side: breadcrumb
              tags$div(
                tags$a(
                  href = "#",
                  onclick = sprintf(
                    "Shiny.setInputValue('%s', true, {priority: 'event'})",
                    ns("back_to_list")
                  ),
                  class = "breadcrumb-link",
                  style = "font-weight: 600;",
                  "Use Cases"
                ),
                tags$span(
                  style = "margin: 0 8px; color: #999;",
                  ">"
                ),
                tags$span(
                  style = "color: #333; font-weight: 600;",
                  use_case_name
                )
              )
            )
          )
        }
      })
    }, ignoreInit = FALSE)

    ### Content Area Rendering ----
    observe_event(content_area_trigger(), {
      view <- current_view()

      output$content_area <- renderUI({
        if (view == "list") {
          render_use_cases_list_ui(ns)
        } else if (view == "config") {
          render_use_case_config_ui(ns)
        }
      })
    }, ignoreInit = FALSE)

    ### Use Cases Table Rendering ----
    observe_event(use_cases_table_trigger(), {
      df <- get_use_cases_with_counts()

      # Create double-click callback
      double_click_js <- JS(sprintf("
        function(settings) {
          var table = this.api();

          // Remove any existing handler to avoid duplicates
          $(table.table().node()).off('dblclick', 'tbody tr');

          // Add double-click handler for table rows
          $(table.table().node()).on('dblclick', 'tbody tr', function() {
            var rowData = table.row(this).data();

            if (rowData && rowData[0]) {
              // Get the use case ID from the first column (hidden)
              var useCaseId = rowData[0];

              // Send the use case ID directly to Shiny
              Shiny.setInputValue('%s', useCaseId, {priority: 'event'});
            }
          });
        }
      ", session$ns("dblclick_use_case_id")))

      output$use_cases_table <- DT::renderDT({
        datatable(
          df,
          filter = "top",
          selection = "single",
          rownames = FALSE,
          class = "cell-border stripe hover",
          options = list(
            pageLength = 25,
            dom = "tip",
            ordering = TRUE,
            autoWidth = FALSE,
            columnDefs = list(
              list(targets = 0, visible = FALSE)  # Hide use_case_id column
            ),
            language = list(
              emptyTable = "No use cases found. Click 'Add Use Case' to create one."
            ),
            drawCallback = double_click_js
          )
        )
      }, server = FALSE)
    }, ignoreInit = FALSE)

    ### Use Case Details Rendering ----
    observe_event(use_case_details_trigger(), {
      output$use_case_details <- renderUI({
        selected_row <- selected_use_case_row()

        if (is.null(selected_row)) {
          return(
            tags$div(
              style = "text-align: center; padding: 40px; color: #6c757d;",
              tags$i(
                class = "fas fa-info-circle",
                style = "font-size: 48px; margin-bottom: 15px;"
              ),
              tags$p("Select a use case to view its details")
            )
          )
        }

        use_cases_data <- use_cases_reactive()
        selected_uc <- use_cases_data[selected_row, ]

        tagList(
          tags$div(
            style = "margin-bottom: 20px;",
            tags$h5(
              selected_uc$use_case_name,
              style = "color: #0f60af; margin-bottom: 10px; font-weight: 600;"
            ),
            tags$div(
              style = paste0(
                "background: #f8f9fa; padding: 15px; ",
                "border-radius: 6px; margin-bottom: 15px;"
              ),
              tags$strong("Short Description:"),
              tags$p(
                style = "margin-top: 8px; margin-bottom: 0;",
                if (is.na(selected_uc$short_description)) {
                  tags$em("No short description")
                } else {
                  selected_uc$short_description
                }
              )
            ),
            if (!is.na(selected_uc$long_description) &&
                selected_uc$long_description != "") {
              tags$div(
                style = paste0(
                  "background: #fff; padding: 15px; border: 1px solid #dee2e6; ",
                  "border-radius: 6px;"
                ),
                tags$strong("Detailed Description:"),
                tags$p(
                  style = "margin-top: 8px; margin-bottom: 0; line-height: 1.6;",
                  selected_uc$long_description
                )
              )
            }
          )
        )
      })
    }, ignoreInit = FALSE)

    ### Available Concepts Table Rendering ----
    observe_event(available_concepts_table_trigger(), {
      df <- get_available_general_concepts()

      output$available_general_concepts_table <- DT::renderDT({
        if (is.null(df)) {
          return(datatable(
            data.frame(
              Category = character(0),
              Subcategory = character(0),
              Concept = character(0),
              stringsAsFactors = FALSE,
              check.names = FALSE
            ),
            filter = "top",
            selection = "multiple",
            rownames = FALSE,
            class = "cell-border stripe hover",
            options = list(
              pageLength = 10,
              dom = "tip",
              ordering = TRUE,
              autoWidth = FALSE
            )
          ))
        }

        df_display <- df[, -1]  # Remove general_concept_id column

        datatable(
          df_display,
          filter = "top",
          selection = "multiple",
          rownames = FALSE,
          class = "cell-border stripe hover",
          options = list(
            pageLength = 10,
            dom = "tip",
            ordering = TRUE,
            autoWidth = FALSE
          )
        )
      }, server = FALSE)
    }, ignoreInit = FALSE)

    ### Selected Concepts Table Rendering ----
    observe_event(selected_concepts_table_trigger(), {
      df <- get_selected_general_concepts()

      output$selected_general_concepts_table <- DT::renderDT({
        if (is.null(df)) {
          return(datatable(
            data.frame(
              Category = character(0),
              Subcategory = character(0),
              Concept = character(0),
              stringsAsFactors = FALSE,
              check.names = FALSE
            ),
            filter = "top",
            selection = "multiple",
            rownames = FALSE,
            class = "cell-border stripe hover",
            options = list(
              pageLength = 15,
              dom = "tip",
              ordering = TRUE,
              autoWidth = FALSE,
              language = list(
                emptyTable = paste0(
                  "No general concepts selected for this use case. ",
                  "Select general concepts from the left panel ",
                  "and click 'Add Selected Concepts'."
                )
              )
            )
          ))
        }

        df_display <- df[, -1]  # Remove general_concept_id column

        datatable(
          df_display,
          filter = "top",
          selection = "multiple",
          rownames = FALSE,
          class = "cell-border stripe hover",
          options = list(
            pageLength = 15,
            dom = "tip",
            ordering = TRUE,
            autoWidth = FALSE,
            language = list(
              emptyTable = paste0(
                "No general concepts selected for this use case. ",
                "Select general concepts from the left panel ",
                "and click 'Add Selected Concepts'."
              )
            )
          )
        )
      }, server = FALSE)
    }, ignoreInit = FALSE)

    ## 4) Server - User Actions ====
    ### Breadcrumb Navigation ----
    observe_event(input$back_to_list, {
      current_view("list")
      selected_use_case(NULL)
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    ### Use Case Management - Add ----
    observe_event(input$add_use_case_btn, {
      shinyjs::runjs(sprintf("$('#%s').show();", ns("add_use_case_modal")))
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    # Save new use case
    observe_event(input$save_use_case, {
      name <- trimws(input$new_use_case_name)
      short_desc <- trimws(input$new_use_case_short_description)

      # Validation
      has_error <- FALSE
      if (name == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("name_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("name_error")))
      }

      if (short_desc == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("short_desc_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("short_desc_error")))
      }

      if (has_error) return()

      # Get current use cases
      use_cases_data <- use_cases_reactive()
      long_desc <- trimws(input$new_use_case_long_description)

      # Create new use case
      new_id <- get_next_use_case_id(use_cases_data)
      new_use_case <- data.frame(
        use_case_id = new_id,
        use_case_name = name,
        short_description = short_desc,
        long_description = if (long_desc == "") NA_character_ else long_desc,
        stringsAsFactors = FALSE
      )

      # Add to use cases
      use_cases_data <- rbind(use_cases_data, new_use_case)

      save_use_cases_csv(use_cases_data)
      use_cases_reactive(use_cases_data)

      # Close modal and reset
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("add_use_case_modal")))
      updateTextInput(session, "new_use_case_name", value = "")
      updateTextAreaInput(session, "new_use_case_short_description", value = "")
      updateTextAreaInput(session, "new_use_case_long_description", value = "")
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    ### Use Case Management - Edit ----
    observe_event(input$edit_name_description_btn, {
      selected_rows <- input$use_cases_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) return()
      if (length(selected_rows) > 1) return()

      # Get selected use case data
      use_cases_data <- use_cases_reactive()
      selected_uc <- use_cases_data[selected_rows, ]

      # Populate edit modal
      updateTextInput(
        session,
        "edit_use_case_name",
        value = selected_uc$use_case_name
      )
      updateTextAreaInput(
        session,
        "edit_use_case_short_description",
        value = ifelse(
          is.na(selected_uc$short_description),
          "",
          selected_uc$short_description
        )
      )
      updateTextAreaInput(
        session,
        "edit_use_case_long_description",
        value = ifelse(
          is.na(selected_uc$long_description),
          "",
          selected_uc$long_description
        )
      )

      # Store the ID for update
      selected_use_case(list(
        id = selected_uc$use_case_id,
        name = selected_uc$use_case_name,
        short_description = selected_uc$short_description,
        long_description = selected_uc$long_description
      ))

      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_use_case_modal")))
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    # Update use case button (from edit modal)
    observe_event(input$update_use_case, {
      name <- trimws(input$edit_use_case_name)
      short_desc <- trimws(input$edit_use_case_short_description)

      # Validation
      has_error <- FALSE
      if (name == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_name_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_name_error")))
      }

      if (short_desc == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_short_desc_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_short_desc_error")))
      }

      if (has_error) return()

      # Get current use case
      use_case <- selected_use_case()
      if (is.null(use_case)) return()

      # Get use cases data
      use_cases_data <- use_cases_reactive()
      long_desc <- trimws(input$edit_use_case_long_description)

      # Update the use case
      use_cases_data$use_case_name[
        use_cases_data$use_case_id == use_case$id
      ] <- name
      use_cases_data$short_description[
        use_cases_data$use_case_id == use_case$id
      ] <- short_desc
      use_cases_data$long_description[
        use_cases_data$use_case_id == use_case$id
      ] <- if (long_desc == "") NA_character_ else long_desc

      save_use_cases_csv(use_cases_data)
      use_cases_reactive(use_cases_data)

      # Close modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_use_case_modal")))
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    ### Use Case Management - Configure & Delete ----

    # Show delete confirmation modal
    observe_event(input$delete_selected_btn, {
      selected_rows <- input$use_cases_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      # Show confirmation modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("delete_confirmation_modal")))
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    # Confirm delete use case
    observe_event(input$confirm_delete_use_case, {
      selected_rows <- input$use_cases_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      # Get IDs to delete
      use_cases_data <- use_cases_reactive()
      ids_to_delete <- use_cases_data$use_case_id[selected_rows]

      # Remove from use cases
      use_cases_data <- use_cases_data[
        !use_cases_data$use_case_id %in% ids_to_delete,
      ]

      # Remove from general_concept_use_cases
      gc_uc_data <- general_concept_use_cases_reactive()
      gc_uc_data <- gc_uc_data[
        !gc_uc_data$use_case_id %in% ids_to_delete,
      ]

      save_use_cases_csv(use_cases_data)
      save_general_concept_use_cases_csv(gc_uc_data)
      use_cases_reactive(use_cases_data)
      general_concept_use_cases_reactive(gc_uc_data)

      # Hide modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_confirmation_modal")))
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    observe_event(input$dblclick_use_case_id, {
      use_case_id <- input$dblclick_use_case_id
      if (is.null(use_case_id)) return()

      # Get use case data by ID
      use_cases_data <- use_cases_reactive()
      selected_uc <- use_cases_data[use_cases_data$use_case_id == use_case_id, ]

      if (nrow(selected_uc) == 1) {
        selected_use_case(list(
          id = selected_uc$use_case_id,
          name = selected_uc$use_case_name,
          short_description = selected_uc$short_description,
          long_description = selected_uc$long_description
        ))
        current_view("config")
      }
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    # Configure use case button
    observe_event(input$configure_use_case_btn, {
      selected_rows <- input$use_cases_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) return()
      if (length(selected_rows) > 1) return()

      # Get selected use case data
      use_cases_data <- use_cases_reactive()
      selected_uc <- use_cases_data[selected_rows, ]

      selected_use_case(list(
        id = selected_uc$use_case_id,
        name = selected_uc$use_case_name,
        short_description = selected_uc$short_description,
        long_description = selected_uc$long_description
      ))
      current_view("config")
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    ### Use Case Details Selection ----
    observe_event(input$use_cases_table_rows_selected, {
      selected_rows <- input$use_cases_table_rows_selected
      if (!is.null(selected_rows) && length(selected_rows) == 1) {
        selected_use_case_row(selected_rows)
      } else {
        selected_use_case_row(NULL)
      }
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    ### Concept Assignment - Add Concepts ----
    observe_event(input$add_general_concepts_btn, {
      selected_rows <- input$available_general_concepts_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      # Get selected use case
      use_case <- selected_use_case()
      if (is.null(use_case)) return()

      # Get available general concepts and selected ones
      available_df <- get_available_general_concepts()
      selected_gc_ids <- available_df$general_concept_id[selected_rows]

      # Get current mappings
      gc_uc_data <- general_concept_use_cases_reactive()

      # Create new mappings
      new_mappings <- data.frame(
        use_case_id = rep(use_case$id, length(selected_gc_ids)),
        general_concept_id = selected_gc_ids,
        stringsAsFactors = FALSE
      )

      # Filter out already existing mappings
      existing_pairs <- paste(
        gc_uc_data$use_case_id,
        gc_uc_data$general_concept_id
      )
      new_pairs <- paste(
        new_mappings$use_case_id,
        new_mappings$general_concept_id
      )
      new_mappings <- new_mappings[!new_pairs %in% existing_pairs, ]

      if (nrow(new_mappings) > 0) {
        gc_uc_data <- rbind(gc_uc_data, new_mappings)

        save_general_concept_use_cases_csv(gc_uc_data)
        general_concept_use_cases_reactive(gc_uc_data)

        DT::selectRows(DT::dataTableProxy("available_general_concepts_table", session = session), NULL)
      }
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    ### Concept Assignment - Remove Concepts ----
    observe_event(input$remove_general_concepts_btn, {
      selected_rows <- input$selected_general_concepts_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      # Get selected use case
      use_case <- selected_use_case()
      if (is.null(use_case)) return()

      # Get selected general concepts
      selected_df <- get_selected_general_concepts()
      gc_ids_to_remove <- selected_df$general_concept_id[selected_rows]

      gc_uc_data <- general_concept_use_cases_reactive()
      gc_uc_data <- gc_uc_data[!(
        gc_uc_data$general_concept_id %in% gc_ids_to_remove &
          gc_uc_data$use_case_id == use_case$id
      ), ]

      save_general_concept_use_cases_csv(gc_uc_data)
      general_concept_use_cases_reactive(gc_uc_data)
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    ### Table Row Selection - Available Concepts ----
    observe_event(input$select_all_available, {
      df <- get_available_general_concepts()
      if (!is.null(df) && nrow(df) > 0) {
        DT::selectRows(
          DT::dataTableProxy("available_general_concepts_table", session = session),
          1:nrow(df)
        )
      }
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    # Unselect all rows in available general concepts table
    observe_event(input$unselect_all_available, {
      DT::selectRows(
        DT::dataTableProxy("available_general_concepts_table", session = session),
        NULL
      )
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    ### Table Row Selection - Selected Concepts ----
    observe_event(input$select_all_selected, {
      df <- get_selected_general_concepts()
      if (!is.null(df) && nrow(df) > 0) {
        DT::selectRows(
          DT::dataTableProxy("selected_general_concepts_table", session = session),
          1:nrow(df)
        )
      }
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    # Unselect all rows in selected general concepts table
    observe_event(input$unselect_all_selected, {
      DT::selectRows(
        DT::dataTableProxy("selected_general_concepts_table", session = session),
        NULL
      )
    }, ignoreNULL = TRUE, ignoreInit = TRUE)
  })
}
