# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Projects management interface with two main views:
# - Projects List View: Browse and manage projects with details panel
# - Project Configuration View: Assign general concepts to projects
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Breadcrumb Navigation - Navigation breadcrumbs for multi-level views
#      ### Content Area - Dynamic content based on current view (list/config)
#         #### List View - projects table (70%) + details panel (30%)
#         #### Config View - Available concepts (50%) + selected concepts (50%)
#   ## UI - Modals
#      ### Modal - Add New Project - Form to create new projects
#      ### Modal - Edit Project - Form to edit existing projects
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### View State - Track current view (list/config) and selected project
#      ### Data Management - projects and general concept assignments
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
#      ### Projects Table - Display projects with concept counts
#      ### Project Details - Show details of selected project
#      ### Concept Tables - Available and selected concepts tables
#
#   ## 4) Server - User Actions
#      ### Project Management - Add, edit, delete, configure projects
#      ### Concept Assignment - Add/remove general concepts to/from projects
#      ### Table Row Selection - Select all, unselect all, double-click navigation
#
# UI SECTION ====

#' Projects Module - UI
#'
#' @description UI function for the projects management module
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
mod_projects_ui <- function(id, i18n) {
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
    ### Modal - Add New Project ----
    tags$div(
      id = ns("add_project_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("add_project_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 700px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("add_project")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("add_project_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$div(
            id = ns("new_project_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span(i18n$t("project_name"), " ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textInput(
              ns("new_project_name"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_name")),
              width = "100%"
            ),
            tags$div(
              id = ns("name_error"),
              class = "input-error-message",
              i18n$t("name_required")
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span(i18n$t("short_description"), " ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textAreaInput(
              ns("new_project_short_description"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_short_description")),
              width = "100%",
              rows = 3
            ),
            tags$div(
              id = ns("short_desc_error"),
              class = "input-error-message",
              i18n$t("short_description_required")
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              i18n$t("long_description"),
              style = paste0(
                "display: block; font-weight: 600; ",
                "margin-bottom: 8px;"
              )
            ),
            textAreaInput(
              ns("new_project_long_description"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_long_description")),
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
                ns("add_project_modal")
              ),
              tags$i(class = "fas fa-times"),
              " ", i18n$t("cancel")
            ),
            actionButton(
              ns("save_project"),
              i18n$t("add_project"),
              class = "btn btn-primary",
              icon = icon("plus")
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
          tags$h3(i18n$t("confirm_deletion")),
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
            i18n$t("delete_project_confirm")
          ),
          tags$p(
            style = "font-size: 14px; color: #dc3545; margin-bottom: 20px;",
            tags$strong("Note:"),
            " ", i18n$t("delete_project_note")
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
              tags$i(class = "fas fa-times"),
              " ", i18n$t("cancel")
            ),
            actionButton(
              ns("confirm_delete_project"),
              i18n$t("delete"),
              class = "btn btn-danger",
              icon = icon("trash")
            )
          )
        )
      )
    ),

    ### Modal - Edit Project ----
    tags$div(
      id = ns("edit_project_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("edit_project_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 700px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("edit_project")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("edit_project_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$div(
            id = ns("edit_project_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span(i18n$t("project_name"), " ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textInput(
              ns("edit_project_name"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_name")),
              width = "100%"
            ),
            tags$div(
              id = ns("edit_name_error"),
              class = "input-error-message",
              i18n$t("name_required")
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span(i18n$t("short_description"), " ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textAreaInput(
              ns("edit_project_short_description"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_short_description")),
              width = "100%",
              rows = 3
            ),
            tags$div(
              id = ns("edit_short_desc_error"),
              class = "input-error-message",
              i18n$t("short_description_required")
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              i18n$t("long_description"),
              style = paste0(
                "display: block; font-weight: 600; ",
                "margin-bottom: 8px;"
              )
            ),
            textAreaInput(
              ns("edit_project_long_description"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_long_description")),
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
                ns("edit_project_modal")
              ),
              tags$i(class = "fas fa-times"),
              " ", i18n$t("cancel")
            ),
            actionButton(
              ns("update_project"),
              i18n$t("update_project"),
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

#' Render Projects List View
#'
#' @description Renders the main projects list with split panel
#'
#' @param ns Namespace function
#' @param i18n Translation object
#'
#' @return UI elements for projects list view
#' @noRd
render_projects_list_ui <- function(ns, i18n) {
  tagList(
    # Action buttons bar
    tags$div(
      style = paste0(
        "margin: 5px 0 15px 10px; display: flex; ",
        "justify-content: space-between; align-items: center;"
      ),
      # Title (matching dictionary explorer style)
      tags$div(
        class = "section-title",
        tags$span(i18n$t("projects"))
      ),
      tags$div(
        style = "display: flex; gap: 10px;",
        shinyjs::hidden(
          actionButton(
            ns("add_project_btn"),
            i18n$t("add_project"),
            class = "btn-success-custom",
            icon = icon("plus")
          )
        )
      )
    ),

    # Split panel layout
    tags$div(
      style = "display: flex; gap: 20px; height: calc(100vh - 175px); margin: 10px;",

      # Left panel: projects table (70%)
      tags$div(
        style = paste0(
          "flex: 0 0 70%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        tags$h4(
          i18n$t("projects"),
          style = paste0(
            "margin: 0 0 15px 0; color: #0f60af; ",
            "border-bottom: 2px solid #0f60af; padding-bottom: 10px;"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: auto;",
          DT::DTOutput(ns("projects_table"))
        )
      ),

      # Right panel: project details (30%)
      tags$div(
        style = paste0(
          "flex: 0 0 30%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        tags$h4(
          i18n$t("project_details"),
          style = paste0(
            "margin: 0 0 15px 0; color: #0f60af; ",
            "border-bottom: 2px solid #0f60af; padding-bottom: 10px;"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: auto;",
          uiOutput(ns("project_details"))
        )
      )
    )
  )
}

#' Render Project Configuration View
#'
#' @description Renders the project configuration view with 3 panels
#'
#' @param ns Namespace function
#' @param i18n Translation object
#'
#' @return UI elements for project configuration view
#' @noRd
render_project_config_ui <- function(ns, i18n) {
  tagList(
    # Two-panel layout for concept selection
    tags$div(
      style = "display: flex; gap: 20px; height: calc(100vh - 175px); margin: 10px;",

      # Left panel: Available general concepts (50% width, 100% height)
      tags$div(
        style = paste0(
          "flex: 0 0 50%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        # Header with title
        tags$h4(
          i18n$t("available_concepts"),
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
              i18n$t("add_selected_concepts"),
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
          i18n$t("selected_concepts_for_project"),
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
              i18n$t("remove_selected_concepts"),
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

#' Projects Module - Server
#'
#' @description Server function for the projects management module
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
mod_projects_server <- function(id, data, vocabularies = reactive({ NULL }), current_user = reactive(NULL), i18n, log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ## 1) Server - Reactive Values & State ====
    ### Reactive Values ----

    current_view <- reactiveVal("list")  # "list" or "config"
    selected_project <- reactiveVal(NULL)
    selected_project_row <- reactiveVal(NULL)  # For displaying details
    projects_reactive <- reactiveVal(NULL)
    general_concept_projects_reactive <- reactiveVal(NULL)

    ### Trigger Values (for cascade pattern) ----

    data_loaded_trigger <- reactiveVal(0)
    view_changed_trigger <- reactiveVal(0)
    user_changed_trigger <- reactiveVal(0)
    projects_data_changed_trigger <- reactiveVal(0)
    gc_projects_changed_trigger <- reactiveVal(0)

    # Cascade triggers
    button_visibility_trigger <- reactiveVal(0)
    breadcrumb_trigger <- reactiveVal(0)
    content_area_trigger <- reactiveVal(0)
    projects_table_trigger <- reactiveVal(0)
    project_details_trigger <- reactiveVal(0)
    available_concepts_table_trigger <- reactiveVal(0)
    selected_concepts_table_trigger <- reactiveVal(0)

    ### Initialize Data ----

    observe_event(data(), {
      if (is.null(data())) return()

      projects_reactive(data()$projects)
      general_concept_projects_reactive(data()$general_concept_projects)
      data_loaded_trigger(data_loaded_trigger() + 1)
    })

    ## 2) Server - Navigation & State Changes ====
    ### Primary State Observers ----

    observe_event(current_user(), {
      user_changed_trigger(user_changed_trigger() + 1)
    })

    observe_event(current_view(), {
      view_changed_trigger(view_changed_trigger() + 1)
    })

    observe_event(projects_reactive(), {
      projects_data_changed_trigger(projects_data_changed_trigger() + 1)
    })

    observe_event(general_concept_projects_reactive(), {
      gc_projects_changed_trigger(gc_projects_changed_trigger() + 1)
    })

    observe_event(selected_project_row(), {
      project_details_trigger(project_details_trigger() + 1)
    })

    ### Cascade Observers ----

    # When data, user, or view changes, update button visibility
    observe_event(c(data_loaded_trigger(), user_changed_trigger(), view_changed_trigger()), {
      button_visibility_trigger(button_visibility_trigger() + 1)
    }, ignoreInit = TRUE)

    # When view or selected project changes, update breadcrumb and content area
    observe_event(c(view_changed_trigger(), selected_project()), {
      breadcrumb_trigger(breadcrumb_trigger() + 1)
      content_area_trigger(content_area_trigger() + 1)
    }, ignoreInit = TRUE)

    # When projects data or concept assignments change, update table
    observe_event(c(projects_data_changed_trigger(), gc_projects_changed_trigger()), {
      projects_table_trigger(projects_table_trigger() + 1)
    }, ignoreInit = TRUE)

    # When general concept projects change or view changes, update concept tables
    observe_event(c(gc_projects_changed_trigger(), view_changed_trigger(), selected_project()), {
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
          shinyjs::show("add_project_btn")
          shinyjs::show("available_action_buttons")
          shinyjs::show("selected_action_buttons")
        } else {
          shinyjs::hide("add_project_btn")
          shinyjs::hide("available_action_buttons")
          shinyjs::hide("selected_action_buttons")
        }
      })
    }

    # Helper function to get projects with concept counts
    get_projects_with_counts <- reactive({
      projects_data <- projects_reactive()
      gc_uc_data <- general_concept_projects_reactive()

      if (is.null(projects_data) || is.null(gc_uc_data)) {
        return(data.frame(
          Name = character(0),
          `Short Description` = character(0),
          Concepts = integer(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Count concepts per project
      concept_counts <- gc_uc_data %>%
        group_by(project_id) %>%
        summarise(concept_count = n(), .groups = "drop")

      # Join with projects
      result <- projects_data %>%
        left_join(concept_counts, by = "project_id")

      # Replace NA counts with 0
      result$concept_count[is.na(result$concept_count)] <- 0

      # Format for display (include project_id as first column, will be hidden)
      display_df <- data.frame(
        project_id = result$project_id,
        Name = result$project_name,
        `Short Description` = ifelse(
          is.na(result$short_description),
          "",
          result$short_description
        ),
        Concepts = result$concept_count,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )

      # Add action buttons column (generate for each row)
      display_df$Actions <- sapply(display_df$project_id, function(id) {
        create_datatable_actions(list(
          list(
            label = "Edit",
            icon = "edit",
            type = "warning",
            class = "project-edit-btn",
            data_attr = list(`project-id` = id)
          ),
          list(
            label = "Configure",
            icon = "cog",
            type = "primary",
            class = "project-configure-btn",
            data_attr = list(`project-id` = id)
          ),
          list(
            label = "Delete",
            icon = "trash",
            type = "danger",
            class = "project-delete-btn",
            data_attr = list(`project-id` = id)
          )
        ))
      })

      return(display_df)
    })

    # Helper function to get available general concepts (excluding already selected ones)
    get_available_general_concepts <- reactive({
      if (is.null(data())) return(NULL)
      if (is.null(selected_project())) return(NULL)

      general_concepts <- data()$general_concepts
      project <- selected_project()
      gc_uc_data <- general_concept_projects_reactive()

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

      # Get IDs of concepts already selected for this project
      selected_gc_ids <- c()
      if (!is.null(gc_uc_data)) {
        selected_gc_ids <- gc_uc_data %>%
          filter(project_id == project$id) %>%
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

    # Helper function to get selected general concepts for current project
    get_selected_general_concepts <- reactive({
      if (is.null(selected_project())) return(NULL)
      if (is.null(data())) return(NULL)

      project <- selected_project()
      general_concepts <- data()$general_concepts
      gc_uc_data <- general_concept_projects_reactive()

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

      # Filter general concepts for this project
      selected_gc_ids <- gc_uc_data %>%
        filter(project_id == project$id) %>%
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
    })

    ### Breadcrumb Rendering ----
    observe_event(breadcrumb_trigger(), {
      view <- current_view()

      output$breadcrumb <- renderUI({
        if (view == "list") {
          return(NULL)
        }

        if (view == "config") {
          project <- selected_project()
          project_name <- if (!is.null(project)) {
            project$name
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
                  i18n$t("projects")
                ),
                tags$span(
                  style = "margin: 0 8px; color: #999;",
                  ">"
                ),
                tags$span(
                  style = "color: #333; font-weight: 600;",
                  project_name
                )
              )
            )
          )
        }
      })
    })

    ### Content Area Rendering ----
    observe_event(content_area_trigger(), {
      view <- current_view()

      output$content_area <- renderUI({
        if (view == "list") {
          render_projects_list_ui(ns, i18n)
        } else if (view == "config") {
          render_project_config_ui(ns, i18n)
        }
      })
    })

    ### Projects Table Rendering ----
    observe_event(projects_table_trigger(), {
      df <- get_projects_with_counts()

      # Create callback for action buttons and double-click
      callback_js <- JS(sprintf("
        function(settings) {
          var table = this.api();

          // Remove any existing handlers to avoid duplicates
          $(table.table().node()).off('dblclick', 'tbody tr');
          $(table.table().node()).off('click', '.project-edit-btn');
          $(table.table().node()).off('click', '.project-configure-btn');
          $(table.table().node()).off('click', '.project-delete-btn');

          // Add double-click handler for table rows
          $(table.table().node()).on('dblclick', 'tbody tr', function() {
            var rowData = table.row(this).data();
            if (rowData && rowData[0]) {
              var projectId = rowData[0];
              Shiny.setInputValue('%s', projectId, {priority: 'event'});
            }
          });

          // Add click handlers for action buttons
          $(table.table().node()).on('click', '.project-edit-btn', function(e) {
            e.stopPropagation();
            var projectId = $(this).data('project-id');
            Shiny.setInputValue('%s', projectId, {priority: 'event'});
          });

          $(table.table().node()).on('click', '.project-configure-btn', function(e) {
            e.stopPropagation();
            var projectId = $(this).data('project-id');
            Shiny.setInputValue('%s', projectId, {priority: 'event'});
          });

          $(table.table().node()).on('click', '.project-delete-btn', function(e) {
            e.stopPropagation();
            var projectId = $(this).data('project-id');
            Shiny.setInputValue('%s', projectId, {priority: 'event'});
          });
        }
      ",
      session$ns("dblclick_project_id"),
      session$ns("project_edit_clicked"),
      session$ns("project_configure_clicked"),
      session$ns("project_delete_clicked")
      ))

      output$projects_table <- DT::renderDT({
        datatable(
          df,
          filter = "top",
          selection = "single",
          rownames = FALSE,
          escape = FALSE,
          class = "cell-border stripe hover",
          options = list(
            pageLength = 25,
            dom = "tip",
            ordering = TRUE,
            autoWidth = FALSE,
            columnDefs = list(
              list(targets = 0, visible = FALSE),  # Hide project_id column
              list(targets = 4, orderable = FALSE, width = "280px", searchable = FALSE, className = "dt-center")  # Actions column
            ),
            language = list(
              emptyTable = "No projects found. Click 'Add Project' to create one."
            ),
            drawCallback = callback_js
          )
        )
      }, server = FALSE)
    })

    ### Project Action Buttons Handlers ----
    # Store the project for deletion and editing
    selected_project_for_delete <- reactiveVal(NULL)
    selected_project_for_edit <- reactiveVal(NULL)

    # Handler for Edit button in datatable
    observe_event(input$project_edit_clicked, {
      project_id <- input$project_edit_clicked
      if (is.null(project_id)) return()

      # Get project data
      projects_data <- projects_reactive()
      selected_uc <- projects_data[projects_data$project_id == project_id, ]

      if (nrow(selected_uc) == 0) return()

      # Populate edit modal
      updateTextInput(
        session,
        "edit_project_name",
        value = selected_uc$project_name
      )
      updateTextAreaInput(
        session,
        "edit_project_short_description",
        value = ifelse(
          is.na(selected_uc$short_description),
          "",
          selected_uc$short_description
        )
      )
      updateTextAreaInput(
        session,
        "edit_project_long_description",
        value = ifelse(
          is.na(selected_uc$long_description),
          "",
          selected_uc$long_description
        )
      )

      # Store the ID for update (do NOT use selected_project as it triggers view change)
      selected_project_for_edit(list(
        id = selected_uc$project_id,
        name = selected_uc$project_name,
        short_description = selected_uc$short_description,
        long_description = selected_uc$long_description
      ))

      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_project_modal")))
    }, ignoreInit = TRUE)

    # Handler for Configure button in datatable
    observe_event(input$project_configure_clicked, {
      project_id <- input$project_configure_clicked
      if (is.null(project_id)) return()

      # Get project data
      projects_data <- projects_reactive()
      selected_uc <- projects_data[projects_data$project_id == project_id, ]

      if (nrow(selected_uc) == 0) return()

      selected_project(list(
        id = selected_uc$project_id,
        name = selected_uc$project_name,
        short_description = selected_uc$short_description,
        long_description = selected_uc$long_description
      ))
      current_view("config")
    }, ignoreInit = TRUE)

    # Handler for Delete button in datatable
    observe_event(input$project_delete_clicked, {
      project_id <- input$project_delete_clicked
      if (is.null(project_id)) return()

      # Store the project ID for deletion
      selected_project_for_delete(project_id)

      # Show confirmation modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("delete_confirmation_modal")))
    }, ignoreInit = TRUE)

    ### Project Details Rendering ----
    observe_event(project_details_trigger(), {
      output$project_details <- renderUI({
        selected_row <- selected_project_row()

        if (is.null(selected_row)) {
          return(
            tags$div(
              style = "text-align: center; padding: 40px; color: #6c757d;",
              tags$i(
                class = "fas fa-info-circle",
                style = "font-size: 48px; margin-bottom: 15px;"
              ),
              tags$p("Select a project to view its details")
            )
          )
        }

        projects_data <- projects_reactive()
        selected_uc <- projects_data[selected_row, ]

        tagList(
          tags$div(
            style = "margin-bottom: 20px;",
            tags$h5(
              selected_uc$project_name,
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
    })

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
    })

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
                  "No general concepts selected for this project. ",
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
                "No general concepts selected for this project. ",
                "Select general concepts from the left panel ",
                "and click 'Add Selected Concepts'."
              )
            )
          )
        )
      }, server = FALSE)
    })

    ## 4) Server - User Actions ====
    ### Breadcrumb Navigation ----
    observe_event(input$back_to_list, {
      current_view("list")
      selected_project(NULL)
    }, ignoreInit = TRUE)

    ### Project Management - Add ----
    observe_event(input$add_project_btn, {
      shinyjs::runjs(sprintf("$('#%s').show();", ns("add_project_modal")))
    }, ignoreInit = TRUE)

    # Save new project
    observe_event(input$save_project, {
      name <- trimws(input$new_project_name)
      short_desc <- trimws(input$new_project_short_description)

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

      # Get current projects
      projects_data <- projects_reactive()
      long_desc <- trimws(input$new_project_long_description)

      # Create new project
      new_id <- get_next_project_id(projects_data)
      new_project <- data.frame(
        project_id = new_id,
        project_name = name,
        short_description = short_desc,
        long_description = if (long_desc == "") NA_character_ else long_desc,
        stringsAsFactors = FALSE
      )

      # Add to projects
      projects_data <- rbind(projects_data, new_project)

      save_projects_csv(projects_data)
      projects_reactive(projects_data)

      # Close modal and reset
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("add_project_modal")))
      updateTextInput(session, "new_project_name", value = "")
      updateTextAreaInput(session, "new_project_short_description", value = "")
      updateTextAreaInput(session, "new_project_long_description", value = "")
    }, ignoreInit = TRUE)

    ### Project Management - Edit ----
    # Now handled by project_edit_clicked observer

    # Update project button (from edit modal)
    observe_event(input$update_project, {
      name <- trimws(input$edit_project_name)
      short_desc <- trimws(input$edit_project_short_description)

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

      # Get current project from edit reactive
      project <- selected_project_for_edit()
      if (is.null(project)) return()

      # Get projects data
      projects_data <- projects_reactive()
      long_desc <- trimws(input$edit_project_long_description)

      # Update the project
      projects_data$project_name[
        projects_data$project_id == project$id
      ] <- name
      projects_data$short_description[
        projects_data$project_id == project$id
      ] <- short_desc
      projects_data$long_description[
        projects_data$project_id == project$id
      ] <- if (long_desc == "") NA_character_ else long_desc

      save_projects_csv(projects_data)
      projects_reactive(projects_data)

      # Close modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_project_modal")))
    }, ignoreInit = TRUE)

    ### Project Management - Delete Confirmation ----
    # Confirm delete project
    observe_event(input$confirm_delete_project, {
      project_id <- selected_project_for_delete()

      if (is.null(project_id)) return()

      # Get projects data
      projects_data <- projects_reactive()

      # Remove from projects
      projects_data <- projects_data[
        projects_data$project_id != project_id,
      ]

      # Remove from general_concept_projects
      gc_uc_data <- general_concept_projects_reactive()
      gc_uc_data <- gc_uc_data[
        gc_uc_data$project_id != project_id,
      ]

      save_projects_csv(projects_data)
      save_general_concept_projects_csv(gc_uc_data)
      projects_reactive(projects_data)
      general_concept_projects_reactive(gc_uc_data)

      # Clear stored ID
      selected_project_for_delete(NULL)

      # Hide modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_confirmation_modal")))
    }, ignoreInit = TRUE)

    observe_event(input$dblclick_project_id, {
      project_id <- input$dblclick_project_id
      if (is.null(project_id)) return()

      # Get project data by ID
      projects_data <- projects_reactive()
      selected_uc <- projects_data[projects_data$project_id == project_id, ]

      if (nrow(selected_uc) == 1) {
        selected_project(list(
          id = selected_uc$project_id,
          name = selected_uc$project_name,
          short_description = selected_uc$short_description,
          long_description = selected_uc$long_description
        ))
        current_view("config")
      }
    }, ignoreInit = TRUE)

    # Configure project - now handled by project_configure_clicked observer

    ### Project Details Selection ----
    observe_event(input$projects_table_rows_selected, {
      selected_rows <- input$projects_table_rows_selected
      if (!is.null(selected_rows) && length(selected_rows) == 1) {
        selected_project_row(selected_rows)
      } else {
        selected_project_row(NULL)
      }
    })

    ### Concept Assignment - Add Concepts ----
    observe_event(input$add_general_concepts_btn, {
      selected_rows <- input$available_general_concepts_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      # Get selected project
      project <- selected_project()
      if (is.null(project)) return()

      # Get available general concepts and selected ones
      available_df <- get_available_general_concepts()
      selected_gc_ids <- available_df$general_concept_id[selected_rows]

      # Get current mappings
      gc_uc_data <- general_concept_projects_reactive()

      # Create new mappings
      new_mappings <- data.frame(
        project_id = rep(project$id, length(selected_gc_ids)),
        general_concept_id = selected_gc_ids,
        stringsAsFactors = FALSE
      )

      # Filter out already existing mappings
      existing_pairs <- paste(
        gc_uc_data$project_id,
        gc_uc_data$general_concept_id
      )
      new_pairs <- paste(
        new_mappings$project_id,
        new_mappings$general_concept_id
      )
      new_mappings <- new_mappings[!new_pairs %in% existing_pairs, ]

      if (nrow(new_mappings) > 0) {
        gc_uc_data <- rbind(gc_uc_data, new_mappings)

        save_general_concept_projects_csv(gc_uc_data)
        general_concept_projects_reactive(gc_uc_data)

        DT::selectRows(DT::dataTableProxy("available_general_concepts_table", session = session), NULL)
      }
    }, ignoreInit = TRUE)

    ### Concept Assignment - Remove Concepts ----
    observe_event(input$remove_general_concepts_btn, {
      selected_rows <- input$selected_general_concepts_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      # Get selected project
      project <- selected_project()
      if (is.null(project)) return()

      # Get selected general concepts
      selected_df <- get_selected_general_concepts()
      gc_ids_to_remove <- selected_df$general_concept_id[selected_rows]

      gc_uc_data <- general_concept_projects_reactive()
      gc_uc_data <- gc_uc_data[!(
        gc_uc_data$general_concept_id %in% gc_ids_to_remove &
          gc_uc_data$project_id == project$id
      ), ]

      save_general_concept_projects_csv(gc_uc_data)
      general_concept_projects_reactive(gc_uc_data)
    }, ignoreInit = TRUE)

    ### Table Row Selection - Available Concepts ----
    observe_event(input$select_all_available, {
      df <- get_available_general_concepts()
      if (!is.null(df) && nrow(df) > 0) {
        DT::selectRows(
          DT::dataTableProxy("available_general_concepts_table", session = session),
          1:nrow(df)
        )
      }
    }, ignoreInit = TRUE)

    # Unselect all rows in available general concepts table
    observe_event(input$unselect_all_available, {
      DT::selectRows(
        DT::dataTableProxy("available_general_concepts_table", session = session),
        NULL
      )
    }, ignoreInit = TRUE)

    ### Table Row Selection - Selected Concepts ----
    observe_event(input$select_all_selected, {
      df <- get_selected_general_concepts()
      if (!is.null(df) && nrow(df) > 0) {
        DT::selectRows(
          DT::dataTableProxy("selected_general_concepts_table", session = session),
          1:nrow(df)
        )
      }
    }, ignoreInit = TRUE)

    # Unselect all rows in selected general concepts table
    observe_event(input$unselect_all_selected, {
      DT::selectRows(
        DT::dataTableProxy("selected_general_concepts_table", session = session),
        NULL
      )
    }, ignoreInit = TRUE)
  })
}
