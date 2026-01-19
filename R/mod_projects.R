# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Projects management interface with two main views:
# - Projects List View: Browse and manage projects (full width table)
# - Project Detail View: View and edit project with tabs (Context, Variables)
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Breadcrumb Navigation - Navigation breadcrumbs for multi-level views
#      ### Content Area - Dynamic content based on current view (list/detail)
#         #### List View - projects table (full width)
#         #### Detail View - tabs (Context, Variables)
#   ## UI - Modals
#      ### Modal - Add New Project - Form to create new projects (name + short_description only)
#      ### Modal - Edit Project - Form to edit existing projects
#      ### Modal - Delete Confirmation - Confirm project deletion
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### View State - Track current view (list/detail) and selected project
#      ### Tab State - Track current tab (context/variables)
#      ### Cascade Triggers - Reactive triggers for cascade pattern
#
#   ## 2) Server - Navigation & State Changes
#      ### Primary State Observers - Track changes to data, user, view
#      ### Cascade Observers - Propagate state changes to UI updates
#      ### Button Visibility - Dynamic button visibility based on user role
#
#   ## 3) Server - UI Rendering
#      ### Breadcrumb Rendering - Dynamic breadcrumb navigation
#      ### Content Area Rendering - Switch between list and detail views
#      ### Projects Table - Display projects with concept counts
#      ### Context Tab - Justification and bibliography fields
#      ### Variables Tab - Available and selected concepts tables
#
#   ## 4) Server - User Actions
#      ### Project Management - Add, edit, delete projects
#      ### Context Editing - Save justification and bibliography
#      ### Concept Assignment - Add/remove general concepts to/from projects
#
# UI SECTION ====

#' Projects Module - UI
#'
#' @description UI function for the projects management module
#'
#' @param id Module ID
#' @param i18n Translation object
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS actionButton uiOutput textInput textAreaInput
#' @importFrom shiny updateTextInput updateTextAreaInput icon
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
        class = "max-width-700",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("add_project")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("add_project_modal")),
            "\u00d7"
          )
        ),
        tags$div(
          class = "modal-body",
          class = "p-20",
          tags$div(
            id = ns("new_project_name_group"),
            class = "mb-20",
            tags$label(
              tags$span(i18n$t("project_name"), " ", class = "font-weight-600"),
              tags$span("*", class = "text-danger"),
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
            ),
            tags$div(
              id = ns("name_duplicate_error"),
              class = "input-error-message",
              i18n$t("name_already_exists")
            )
          ),
          tags$div(
            class = "mb-20",
            tags$label(
              tags$span(i18n$t("short_description"), " ", class = "font-weight-600"),
              tags$span("*", class = "text-danger"),
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
        class = "max-width-500",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("confirm_deletion")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("delete_confirmation_modal")),
            "\u00d7"
          )
        ),
        tags$div(
          class = "modal-body",
          class = "p-20",
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
        class = "max-width-700",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("edit_project")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("edit_project_modal")),
            "\u00d7"
          )
        ),
        tags$div(
          class = "modal-body",
          class = "p-20",
          tags$div(
            id = ns("edit_project_name_group"),
            class = "mb-20",
            tags$label(
              tags$span(i18n$t("project_name"), " ", class = "font-weight-600"),
              tags$span("*", class = "text-danger"),
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
            ),
            tags$div(
              id = ns("edit_name_duplicate_error"),
              class = "input-error-message",
              i18n$t("name_already_exists")
            )
          ),
          tags$div(
            class = "mb-20",
            tags$label(
              tags$span(i18n$t("short_description"), " ", class = "font-weight-600"),
              tags$span("*", class = "text-danger"),
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
#' @description Renders the main projects list (full width)
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
      # Title
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

    # Full width projects table
    tags$div(
      style = "margin: 10px;",
      tags$div(
        style = paste0(
          "display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        tags$div(
          class = "flex-1", style = "overflow: auto;",
          DT::DTOutput(ns("projects_table"))
        )
      )
    )
  )
}

#' Render Project Detail View with Tabs
#'
#' @description Renders the project detail view with Context and Variables tabs
#'
#' @param ns Namespace function
#' @param i18n Translation object
#'
#' @return UI elements for project detail view
#' @noRd
render_project_detail_ui <- function(ns, i18n) {
  tags$div(
    style = "margin: 0 10px;",
    tabsetPanel(
      id = ns("project_tabs"),

      # Context tab
      tabPanel(
        i18n$t("context"),
        value = "context",
        icon = icon("file-alt"),
        uiOutput(ns("context_tab_content"))
      ),

      # Variables tab
      tabPanel(
        i18n$t("variables"),
        value = "variables",
        icon = icon("list"),
        uiOutput(ns("variables_tab_content"))
      )
    )
  )
}

#' Render Context Tab Content
#'
#' @description Renders the context tab with justification and bibliography fields
#'
#' @param ns Namespace function
#' @param i18n Translation object
#'
#' @return UI elements for context tab
#' @noRd
render_context_tab_ui <- function(ns, i18n) {
  tags$div(
    style = "margin: 10px 0;",
    tags$div(
      style = paste0(
        "background: white; border-radius: 8px; ",
        "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
      ),
      # Justification field
      tags$div(
        class = "mb-20",
        tags$label(
          i18n$t("justification"),
          style = "display: block; font-weight: 600; margin-bottom: 8px; color: #0f60af;"
        ),
        textAreaInput(
          ns("context_justification"),
          label = NULL,
          placeholder = as.character(i18n$t("enter_justification")),
          width = "100%",
          rows = 8
        )
      ),
      # Bibliography field
      tags$div(
        class = "mb-20",
        tags$label(
          i18n$t("bibliography"),
          style = "display: block; font-weight: 600; margin-bottom: 8px; color: #0f60af;"
        ),
        textAreaInput(
          ns("context_bibliography"),
          label = NULL,
          placeholder = as.character(i18n$t("enter_bibliography")),
          width = "100%",
          rows = 6
        )
      ),
      # Save button
      shinyjs::hidden(
        tags$div(
          id = ns("context_save_container"),
          style = "display: flex; justify-content: flex-end; gap: 10px;",
          actionButton(
            ns("save_context"),
            i18n$t("save_context"),
            class = "btn btn-primary",
            icon = icon("save")
          )
        )
      )
    )
  )
}

#' Render Variables Tab Content
#'
#' @description Renders the variables tab with concept selection panels
#'
#' @param ns Namespace function
#' @param i18n Translation object
#'
#' @return UI elements for variables tab
#' @noRd
render_variables_tab_ui <- function(ns, i18n) {
  tagList(
    # Two-panel layout for concept selection
    tags$div(
      style = "display: flex; gap: 20px; flex: 1; min-height: 0; margin: 10px 0;",

      # Left panel: Available general concepts (50% width)
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
          class = "flex-1", style = "overflow: auto;",
          DT::DTOutput(ns("available_general_concepts_table"))
        )
      ),

      # Right panel: Selected general concepts (50% width)
      tags$div(
        style = paste0(
          "flex: 0 0 50%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        # Header with title and download button
        tags$div(
          style = paste0(
            "display: flex; justify-content: space-between; align-items: center; ",
            "margin: 0 0 10px 0; border-bottom: 2px solid #28a745; padding-bottom: 10px;"
          ),
          tags$h4(
            i18n$t("selected_concepts_for_project"),
            style = "margin: 0; color: #28a745;"
          ),
          actionButton(
            ns("download_project_csv"),
            i18n$t("download_csv"),
            class = "btn btn-success btn-sm",
            icon = icon("download")
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
          class = "flex-1", style = "overflow: auto;",
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
#' @param current_user Reactive containing current user info
#' @param i18n Translation object
#' @param log_level Logging level
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

    # Helper function to check if current user has a specific permission
    user_has_permission <- function(category, permission) {
      user_has_permission_for(current_user, category, permission)
    }

    ## 1) Server - Reactive Values & State ====
    ### Reactive Values ----

    current_view <- reactiveVal("list")  # "list" or "detail"
    current_tab <- reactiveVal("context")  # "context" or "variables"
    selected_project <- reactiveVal(NULL)
    projects_reactive <- reactiveVal(NULL)
    project_general_concepts_reactive <- reactiveVal(NULL)
    variables_tables_loaded <- reactiveVal(FALSE)  # Track if concept tables have been loaded for current project
    context_buttons_shown <- reactiveVal(FALSE)  # Track if context buttons have been shown
    variables_buttons_shown <- reactiveVal(FALSE)  # Track if variables buttons have been shown

    ### Trigger Values (for cascade pattern) ----

    data_loaded_trigger <- reactiveVal(0)
    view_changed_trigger <- reactiveVal(0)
    projects_data_changed_trigger <- reactiveVal(0)
    gc_projects_changed_trigger <- reactiveVal(0)

    # Cascade triggers
    breadcrumb_trigger <- reactiveVal(0)
    content_area_trigger <- reactiveVal(0)
    projects_table_trigger <- reactiveVal(0)
    available_concepts_table_trigger <- reactiveVal(0)
    selected_concepts_table_trigger <- reactiveVal(0)

    ### Initialize Data ----

    observe_event(data(), {
      if (is.null(data())) return()

      # Load projects from database
      projects_reactive(get_all_projects())
      project_general_concepts_reactive(get_all_project_general_concepts())
      data_loaded_trigger(data_loaded_trigger() + 1)

      # Show add project button (exists in static UI)
      if (user_has_permission("projects", "add_project")) {
        shinyjs::show("add_project_btn")
      }
    })

    ## 2) Server - Navigation & State Changes ====
    ### Primary State Observers ----

    observe_event(current_view(), {
      view_changed_trigger(view_changed_trigger() + 1)
    })

    observe_event(projects_reactive(), {
      projects_data_changed_trigger(projects_data_changed_trigger() + 1)
    })

    observe_event(project_general_concepts_reactive(), {
      gc_projects_changed_trigger(gc_projects_changed_trigger() + 1)
    })

    ### Cascade Observers ----

    # When view or selected project changes, update breadcrumb and content area
    observe_event(c(view_changed_trigger(), selected_project()), {
      breadcrumb_trigger(breadcrumb_trigger() + 1)
      content_area_trigger(content_area_trigger() + 1)
    }, ignoreInit = TRUE)

    # When projects data changes, update table
    observe_event(projects_data_changed_trigger(), {
      projects_table_trigger(projects_table_trigger() + 1)
    }, ignoreInit = TRUE)

    # When general concept projects change or selected project changes, update concept tables
    observe_event(c(gc_projects_changed_trigger(), selected_project()), {
      available_concepts_table_trigger(available_concepts_table_trigger() + 1)
      selected_concepts_table_trigger(selected_concepts_table_trigger() + 1)
    }, ignoreInit = TRUE)

    ### Helper Functions ----

    # Helper function to get projects with concept counts
    get_projects_with_counts <- reactive({
      projects_data <- projects_reactive()
      gc_data <- project_general_concepts_reactive()

      if (is.null(projects_data) || nrow(projects_data) == 0) {
        return(data.frame(
          project_id = integer(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Count concepts per project
      concept_counts <- if (!is.null(gc_data) && nrow(gc_data) > 0) {
        gc_data %>%
          group_by(project_id) %>%
          summarise(concept_count = n(), .groups = "drop")
      } else {
        data.frame(project_id = integer(0), concept_count = integer(0))
      }

      # Join with projects
      result <- projects_data %>%
        left_join(concept_counts, by = "project_id")

      # Replace NA counts with 0
      result$concept_count[is.na(result$concept_count)] <- 0

      # Format for display
      display_df <- data.frame(
        project_id = result$project_id,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      display_df[[as.character(i18n$t("project_name"))]] <- result$name
      display_df[[as.character(i18n$t("short_description"))]] <- ifelse(
        is.na(result$short_description),
        "",
        result$short_description
      )
      display_df[[as.character(i18n$t("concepts"))]] <- result$concept_count
      display_df[[as.character(i18n$t("created_by"))]] <- paste(
        ifelse(is.na(result$creator_first_name), "", result$creator_first_name),
        ifelse(is.na(result$creator_last_name), "", result$creator_last_name)
      )
      display_df[[as.character(i18n$t("created_at"))]] <- result$created_at

      # Check permissions for action buttons
      can_edit <- user_has_permission("projects", "edit_project")
      can_delete <- user_has_permission("projects", "delete_project")

      # Add action buttons column
      display_df[[as.character(i18n$t("actions"))]] <- sapply(display_df$project_id, function(id) {
        actions_list <- list()

        if (can_edit) {
          actions_list <- c(actions_list, list(list(
            label = "Edit",
            icon = "edit",
            type = "warning",
            class = "project-edit-btn",
            data_attr = list(`project-id` = id)
          )))
        }

        if (can_delete) {
          actions_list <- c(actions_list, list(list(
            label = "Delete",
            icon = "trash",
            type = "danger",
            class = "project-delete-btn",
            data_attr = list(`project-id` = id)
          )))
        }

        if (length(actions_list) > 0) {
          create_datatable_actions(actions_list)
        } else {
          ""
        }
      })

      return(display_df)
    })

    # Helper function to get available general concepts
    get_available_general_concepts <- reactive({
      if (is.null(data())) return(NULL)
      if (is.null(selected_project())) return(NULL)

      general_concepts <- data()$general_concepts
      project <- selected_project()
      gc_data <- project_general_concepts_reactive()

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
      if (!is.null(gc_data) && nrow(gc_data) > 0) {
        selected_gc_ids <- gc_data %>%
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
      gc_data <- project_general_concepts_reactive()

      if (is.null(gc_data) || nrow(gc_data) == 0) {
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
      selected_gc_ids <- gc_data %>%
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
    ### Breadcrumb Rendering ----
    observe_event(breadcrumb_trigger(), {
      view <- current_view()

      output$breadcrumb <- renderUI({
        if (view == "list") {
          return(NULL)
        }

        if (view == "detail") {
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
                "padding: 10px 0 15px 12px; font-size: 16px; ",
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
        } else if (view == "detail") {
          render_project_detail_ui(ns, i18n)
        }
      })

      # When entering detail view, render tab contents and load project data
      if (view == "detail") {
        current_tab("context")

        # Reset flags for buttons visibility (new project = new detail view)
        context_buttons_shown(FALSE)
        variables_buttons_shown(FALSE)
        variables_tables_loaded(FALSE)

        # Render tab contents (once when entering detail view)
        shinyjs::delay(50, {
          output$context_tab_content <- renderUI({
            render_context_tab_ui(ns, i18n)
          })

          output$variables_tab_content <- renderUI({
            render_variables_tab_ui(ns, i18n)
          })

          # Load context data for the selected project
          project <- selected_project()
          if (!is.null(project)) {
            justification <- get_project_metadata_value(project$id, "justification")
            bibliography <- get_project_metadata_value(project$id, "bibliography")

            shinyjs::delay(100, {
              updateTextAreaInput(session, "context_justification", value = ifelse(is.null(justification), "", justification))
              updateTextAreaInput(session, "context_bibliography", value = ifelse(is.null(bibliography), "", bibliography))

              # Show context buttons (first time entering context tab)
              if (!context_buttons_shown()) {
                context_buttons_shown(TRUE)
                if (user_has_permission("projects", "edit_context")) {
                  shinyjs::show("context_save_container")
                }
              }
            })
          }
        })
      }
    })

    ### Tab Switching ----
    observe_event(input$project_tabs, {
      current_tab(input$project_tabs)

      # Load concept tables and show buttons on first visit to Variables tab
      if (input$project_tabs == "variables" && !variables_tables_loaded()) {
        variables_tables_loaded(TRUE)
        available_concepts_table_trigger(available_concepts_table_trigger() + 1)
        selected_concepts_table_trigger(selected_concepts_table_trigger() + 1)

        # Show variables buttons (first time entering variables tab)
        if (!variables_buttons_shown()) {
          variables_buttons_shown(TRUE)
          if (user_has_permission("projects", "assign_concepts")) {
            shinyjs::delay(100, {
              shinyjs::show("available_action_buttons")
              shinyjs::show("selected_action_buttons")
            })
          }
        }
      }
    }, ignoreInit = TRUE)

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

          $(table.table().node()).on('click', '.project-delete-btn', function(e) {
            e.stopPropagation();
            var projectId = $(this).data('project-id');
            Shiny.setInputValue('%s', projectId, {priority: 'event'});
          });
        }
      ",
      session$ns("dblclick_project_id"),
      session$ns("project_edit_clicked"),
      session$ns("project_delete_clicked")
      ))

      # Merge DataTable language with custom empty message
      dt_language <- get_datatable_language()
      dt_language$emptyTable <- as.character(i18n$t("no_projects"))

      output$projects_table <- DT::renderDT({
        datatable(
          df,
          filter = "top",
          selection = "none",
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
              list(targets = 6, orderable = FALSE, width = "180px", searchable = FALSE, className = "dt-center")  # Actions column
            ),
            language = dt_language,
            drawCallback = callback_js
          )
        )
      }, server = FALSE)
    })

    ### Available Concepts Table Rendering ----
    observe_event(available_concepts_table_trigger(), {
      if (current_tab() != "variables") return()

      df <- get_available_general_concepts()

      output$available_general_concepts_table <- DT::renderDT({
        if (is.null(df)) {
          empty_df <- data.frame(
            stringsAsFactors = FALSE,
            check.names = FALSE
          )
          empty_df[[as.character(i18n$t("category"))]] <- character(0)
          empty_df[[as.character(i18n$t("subcategory"))]] <- character(0)
          empty_df[[as.character(i18n$t("general_concept_name"))]] <- character(0)
          return(datatable(
            empty_df,
            filter = "top",
            selection = "multiple",
            rownames = FALSE,
            class = "cell-border stripe hover",
            options = list(
              pageLength = 10,
              dom = "tip",
              ordering = TRUE,
              autoWidth = FALSE,
              language = get_datatable_language()
            )
          ))
        }

        df_display <- df[, -1]  # Remove general_concept_id column
        colnames(df_display) <- c(
          as.character(i18n$t("category")),
          as.character(i18n$t("subcategory")),
          as.character(i18n$t("general_concept_name"))
        )

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
            autoWidth = FALSE,
            language = get_datatable_language()
          )
        )
      }, server = FALSE)
    })

    ### Selected Concepts Table Rendering ----
    observe_event(selected_concepts_table_trigger(), {
      if (current_tab() != "variables") return()

      df <- get_selected_general_concepts()

      # Merge DataTable language with custom empty message
      dt_language <- get_datatable_language()
      dt_language$emptyTable <- as.character(i18n$t("no_concepts_selected"))

      output$selected_general_concepts_table <- DT::renderDT({
        if (is.null(df)) {
          empty_df <- data.frame(
            stringsAsFactors = FALSE,
            check.names = FALSE
          )
          empty_df[[as.character(i18n$t("category"))]] <- character(0)
          empty_df[[as.character(i18n$t("subcategory"))]] <- character(0)
          empty_df[[as.character(i18n$t("general_concept_name"))]] <- character(0)
          return(datatable(
            empty_df,
            filter = "top",
            selection = "multiple",
            rownames = FALSE,
            class = "cell-border stripe hover",
            options = list(
              pageLength = 15,
              dom = "tip",
              ordering = TRUE,
              autoWidth = FALSE,
              language = dt_language
            )
          ))
        }

        df_display <- df[, -1]  # Remove general_concept_id column
        colnames(df_display) <- c(
          as.character(i18n$t("category")),
          as.character(i18n$t("subcategory")),
          as.character(i18n$t("general_concept_name"))
        )

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
            language = dt_language
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

    ### Project Selection (double-click) ----
    observe_event(input$dblclick_project_id, {
      project_id <- input$dblclick_project_id
      if (is.null(project_id)) return()

      # Get project data from database
      project <- get_project(project_id)

      if (!is.null(project)) {
        selected_project(list(
          id = project$project_id,
          name = project$name,
          short_description = project$short_description
        ))
        current_view("detail")
      }
    }, ignoreInit = TRUE)

    ### Project Management - Add ----
    observe_event(input$add_project_btn, {
      if (!user_has_permission("projects", "add_project")) return()
      shinyjs::runjs(sprintf("$('#%s').show();", ns("add_project_modal")))
    }, ignoreInit = TRUE)

    # Store project for deletion and editing
    selected_project_for_delete <- reactiveVal(NULL)
    selected_project_for_edit <- reactiveVal(NULL)

    # Save new project
    observe_event(input$save_project, {
      if (!user_has_permission("projects", "add_project")) return()

      name <- trimws(input$new_project_name)
      short_desc <- trimws(input$new_project_short_description)

      # Validation
      has_error <- FALSE

      if (name == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("name_error")))
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("name_duplicate_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("name_error")))
        # Check for duplicate name via database
        projects_data <- projects_reactive()
        if (!is.null(projects_data) && tolower(name) %in% tolower(projects_data$name)) {
          shinyjs::runjs(sprintf("$('#%s').show();", ns("name_duplicate_error")))
          has_error <- TRUE
        } else {
          shinyjs::runjs(sprintf("$('#%s').hide();", ns("name_duplicate_error")))
        }
      }

      if (short_desc == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("short_desc_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("short_desc_error")))
      }

      if (has_error) return()

      # Get creator info from current user
      user <- current_user()
      creator_first_name <- if (!is.null(user)) user$first_name else ""
      creator_last_name <- if (!is.null(user)) user$last_name else ""

      # Create new project in database
      new_id <- add_project(name, short_desc, creator_first_name, creator_last_name)

      if (!is.null(new_id)) {
        # Reload projects from database
        projects_reactive(get_all_projects())

        # Close modal and reset
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("add_project_modal")))
        updateTextInput(session, "new_project_name", value = "")
        updateTextAreaInput(session, "new_project_short_description", value = "")
      }
    }, ignoreInit = TRUE)

    ### Project Management - Edit ----
    observe_event(input$project_edit_clicked, {
      if (!user_has_permission("projects", "edit_project")) return()

      project_id <- input$project_edit_clicked
      if (is.null(project_id)) return()

      # Get project data from database
      project <- get_project(project_id)
      if (is.null(project)) return()

      # Populate edit modal
      updateTextInput(session, "edit_project_name", value = project$name)
      updateTextAreaInput(session, "edit_project_short_description", value = ifelse(is.na(project$short_description), "", project$short_description))

      # Store the ID for update
      selected_project_for_edit(list(
        id = project$project_id,
        name = project$name
      ))

      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_project_modal")))
    }, ignoreInit = TRUE)

    # Update project button
    observe_event(input$update_project, {
      if (!user_has_permission("projects", "edit_project")) return()

      name <- trimws(input$edit_project_name)
      short_desc <- trimws(input$edit_project_short_description)

      project <- selected_project_for_edit()
      if (is.null(project)) return()

      # Validation
      has_error <- FALSE

      if (name == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_name_error")))
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_name_duplicate_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_name_error")))
        # Check for duplicate name (excluding current project)
        projects_data <- projects_reactive()
        other_projects <- projects_data[projects_data$project_id != project$id, ]
        if (nrow(other_projects) > 0 && tolower(name) %in% tolower(other_projects$name)) {
          shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_name_duplicate_error")))
          has_error <- TRUE
        } else {
          shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_name_duplicate_error")))
        }
      }

      if (short_desc == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_short_desc_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_short_desc_error")))
      }

      if (has_error) return()

      # Update project in database
      update_project(project$id, name = name, short_description = short_desc)

      # Reload projects from database
      projects_reactive(get_all_projects())

      # Close modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_project_modal")))
    }, ignoreInit = TRUE)

    ### Project Management - Delete ----
    observe_event(input$project_delete_clicked, {
      if (!user_has_permission("projects", "delete_project")) return()

      project_id <- input$project_delete_clicked
      if (is.null(project_id)) return()

      selected_project_for_delete(project_id)
      shinyjs::runjs(sprintf("$('#%s').show();", ns("delete_confirmation_modal")))
    }, ignoreInit = TRUE)

    observe_event(input$confirm_delete_project, {
      if (!user_has_permission("projects", "delete_project")) return()

      project_id <- selected_project_for_delete()
      if (is.null(project_id)) return()

      # Delete project from database (cascades to metadata and general concepts)
      delete_project(project_id)

      # Reload data from database
      projects_reactive(get_all_projects())
      project_general_concepts_reactive(get_all_project_general_concepts())

      # Clear stored ID and hide modal
      selected_project_for_delete(NULL)
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_confirmation_modal")))
    }, ignoreInit = TRUE)

    ### Context Editing - Save ----
    observe_event(input$save_context, {
      if (!user_has_permission("projects", "edit_context")) return()

      project <- selected_project()
      if (is.null(project)) return()

      justification <- input$context_justification
      bibliography <- input$context_bibliography

      # Save to database
      set_project_metadata(project$id, "justification", justification)
      set_project_metadata(project$id, "bibliography", bibliography)

      # Show success notification
      showNotification(
        i18n$t("context_saved"),
        type = "message",
        duration = 3
      )
    }, ignoreInit = TRUE)

    ### Concept Assignment - Add Concepts ----
    observe_event(input$add_general_concepts_btn, {
      if (!user_has_permission("projects", "assign_concepts")) return()

      selected_rows <- input$available_general_concepts_table_rows_selected
      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      project <- selected_project()
      if (is.null(project)) return()

      # Get available general concepts and selected ones
      available_df <- get_available_general_concepts()
      selected_gc_ids <- available_df$general_concept_id[selected_rows]

      # Add each concept to database
      for (gc_id in selected_gc_ids) {
        add_project_general_concept(project$id, gc_id)
      }

      # Reload data from database
      project_general_concepts_reactive(get_all_project_general_concepts())

      # Clear selection
      DT::selectRows(DT::dataTableProxy("available_general_concepts_table", session = session), NULL)
    }, ignoreInit = TRUE)

    ### Concept Assignment - Remove Concepts ----
    observe_event(input$remove_general_concepts_btn, {
      if (!user_has_permission("projects", "assign_concepts")) return()

      selected_rows <- input$selected_general_concepts_table_rows_selected
      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      project <- selected_project()
      if (is.null(project)) return()

      # Get selected general concepts
      selected_df <- get_selected_general_concepts()
      gc_ids_to_remove <- selected_df$general_concept_id[selected_rows]

      # Remove each concept from database
      for (gc_id in gc_ids_to_remove) {
        remove_project_general_concept(project$id, gc_id)
      }

      # Reload data from database
      project_general_concepts_reactive(get_all_project_general_concepts())
    }, ignoreInit = TRUE)

    ### Table Row Selection - Select/Unselect All ----
    observe_event(input$select_all_available, {
      df <- get_available_general_concepts()
      if (!is.null(df) && nrow(df) > 0) {
        DT::selectRows(
          DT::dataTableProxy("available_general_concepts_table", session = session),
          1:nrow(df)
        )
      }
    }, ignoreInit = TRUE)

    observe_event(input$unselect_all_available, {
      DT::selectRows(
        DT::dataTableProxy("available_general_concepts_table", session = session),
        NULL
      )
    }, ignoreInit = TRUE)

    observe_event(input$select_all_selected, {
      df <- get_selected_general_concepts()
      if (!is.null(df) && nrow(df) > 0) {
        DT::selectRows(
          DT::dataTableProxy("selected_general_concepts_table", session = session),
          1:nrow(df)
        )
      }
    }, ignoreInit = TRUE)

    observe_event(input$unselect_all_selected, {
      DT::selectRows(
        DT::dataTableProxy("selected_general_concepts_table", session = session),
        NULL
      )
    }, ignoreInit = TRUE)

    ### Download Project CSV ----
    observe_event(input$download_project_csv, {
      project <- selected_project()
      if (is.null(project)) return()

      project_id <- project$id

      tryCatch({
        # Get project name for filename
        project_name <- gsub("[^a-zA-Z0-9_-]", "_", project$name)
        filename <- paste0(project_name, "-", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".csv")

        # Get general concepts assigned to this project
        gc_data <- project_general_concepts_reactive()
        assigned_gc_ids <- gc_data %>%
          dplyr::filter(project_id == !!project_id) %>%
          .$general_concept_id

        if (length(assigned_gc_ids) == 0) {
          # Empty export
          export_data <- data.frame(
            general_concept_id = integer(),
            general_concept_name = character(),
            category = character(),
            subcategory = character(),
            vocabulary_id = character(),
            concept_code = character(),
            concept_name = character(),
            omop_concept_id = integer(),
            omop_unit_concept_id = integer()
          )
        } else {
          # Get general concepts details
          general_concepts <- data()$general_concepts
          gc_details <- general_concepts %>%
            dplyr::filter(general_concept_id %in% assigned_gc_ids)

          # Get concept mappings (OMOP)
          concept_mappings <- data()$concept_mappings

          # Get custom concepts
          custom_concepts <- data()$custom_concepts

          # Join OMOP concept mappings
          omop_data <- gc_details %>%
            dplyr::inner_join(
              concept_mappings %>%
                dplyr::select(general_concept_id, omop_concept_id, omop_unit_concept_id),
              by = "general_concept_id"
            )

          # Enrich OMOP data with vocabulary info from DuckDB
          vocab_data <- vocabularies()
          if (!is.null(vocab_data) && nrow(omop_data) > 0) {
            concept_ids <- unique(omop_data$omop_concept_id[!is.na(omop_data$omop_concept_id)])
            if (length(concept_ids) > 0) {
              omop_concepts <- vocab_data$concept %>%
                dplyr::filter(concept_id %in% concept_ids) %>%
                dplyr::select(concept_id, vocabulary_id, concept_code, concept_name) %>%
                dplyr::collect()

              omop_data <- omop_data %>%
                dplyr::left_join(
                  omop_concepts,
                  by = c("omop_concept_id" = "concept_id")
                )
            } else {
              omop_data <- omop_data %>%
                dplyr::mutate(
                  vocabulary_id = NA_character_,
                  concept_code = NA_character_,
                  concept_name = NA_character_
                )
            }
          } else {
            omop_data <- omop_data %>%
              dplyr::mutate(
                vocabulary_id = NA_character_,
                concept_code = NA_character_,
                concept_name = NA_character_
              )
          }

          # Join custom concepts
          custom_data <- gc_details %>%
            dplyr::inner_join(
              custom_concepts %>%
                dplyr::select(
                  general_concept_id,
                  vocabulary_id,
                  concept_code,
                  concept_name,
                  omop_unit_concept_id
                ),
              by = "general_concept_id"
            ) %>%
            dplyr::mutate(omop_concept_id = NA_integer_)

          # Handle "/" values in custom concepts
          if (nrow(custom_data) > 0) {
            custom_data <- custom_data %>%
              dplyr::mutate(
                concept_code = dplyr::if_else(concept_code == "/", NA_character_, concept_code),
                omop_unit_concept_id = as.integer(dplyr::if_else(
                  as.character(omop_unit_concept_id) == "/",
                  NA_character_,
                  as.character(omop_unit_concept_id)
                ))
              )
          }

          # Ensure omop_data has integer type for omop_unit_concept_id
          if (nrow(omop_data) > 0) {
            omop_data <- omop_data %>%
              dplyr::mutate(omop_unit_concept_id = suppressWarnings(as.integer(omop_unit_concept_id)))
          }

          # Combine OMOP and custom concepts
          export_data <- dplyr::bind_rows(omop_data, custom_data) %>%
            dplyr::select(
              general_concept_id,
              general_concept_name,
              category,
              subcategory,
              vocabulary_id,
              concept_code,
              concept_name,
              omop_concept_id,
              omop_unit_concept_id
            ) %>%
            dplyr::arrange(category, subcategory, general_concept_name, vocabulary_id)
        }

        # Write to temp file and read back for consistent CSV formatting
        temp_csv <- tempfile(fileext = ".csv")
        write.csv(export_data, temp_csv, row.names = FALSE, quote = TRUE, na = "")
        csv_content <- paste(readLines(temp_csv, warn = FALSE), collapse = "\n")
        unlink(temp_csv)

        # Encode and trigger download via JavaScript
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

      }, error = function(e) {
        cat("[ERROR] Export failed:", conditionMessage(e), "\n")
      })
    }, ignoreInit = TRUE)
  })
}
