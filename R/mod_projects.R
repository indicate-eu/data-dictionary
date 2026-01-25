# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Projects management interface with two main views:
# - Projects List View: Browse and manage projects (full width table)
# - Project Detail View: View and edit project with tabs (Context, Variables)
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### List View - Projects table with header and add button
#      ### Detail View - Header with back button, tabs (Context, Variables)
#   ## UI - Modals
#      ### Modal - Add/Edit Project
#      ### Modal - Delete Confirmation
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### View State - Track current view (list/detail) and selected project
#      ### Triggers - Reactive triggers for cascade pattern
#
#   ## 2) Server - Data Loading
#      ### Load Projects
#
#   ## 3) Server - UI Rendering
#      ### View Switching - Show/hide list and detail views
#      ### Projects Table - Display projects with concept counts
#      ### Context Tab - Justification and bibliography fields
#      ### Variables Tab - Available and selected concept sets
#
#   ## 4) Server - CRUD Operations
#      ### Add/Edit/Delete Project
#      ### Context Editing - Save justification and bibliography
#      ### Concept Set Assignment - Add/remove concept sets

# UI SECTION ====

#' Projects Module - UI
#'
#' @param id Module ID
#' @param i18n Translator object
#'
#' @return Shiny UI elements
#' @noRd
mod_projects_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",

        ## UI - List View ----
        tags$div(
          id = ns("list_view"),
          style = "height: 100%;",
          create_page_layout(
            "full",
            create_panel(
              title = i18n$t("projects"),
              content = uiOutput(ns("projects_table_container")),
              tooltip = i18n$t("projects_tooltip"),
              header_extra = shinyjs::hidden(
                actionButton(
                  ns("add_project"),
                  i18n$t("add_project"),
                  class = "btn-success-custom",
                  icon = icon("plus")
                )
              )
            )
          )
        ),

        ## UI - Detail View ----
        shinyjs::hidden(
          tags$div(
            id = ns("detail_view"),
            style = "height: 100%;",
            create_page_layout(
              "full",
              create_panel(
                title = NULL,
                content = tagList(
                  # Header with back button + project name on left, custom tabs on right
                  tags$div(
                    class = "detail-header",

                    # Left side: back button + project name + save button
                    tags$div(
                      class = "detail-header-left",
                      actionButton(
                        ns("back_to_list"),
                        label = NULL,
                        icon = icon("arrow-left"),
                        class = "btn-back-discrete",
                        title = i18n$t("projects")
                      ),
                      tags$span(
                        id = ns("detail_project_name"),
                        class = "project-name-badge",
                        title = "",
                        ""
                      ),
                      actionButton(
                        ns("save_context"),
                        label = NULL,
                        icon = icon("save"),
                        class = "btn-save-icon has-tooltip",
                        `data-tooltip` = i18n$t("save_context")
                      )
                    ),

                    # Right side: custom tabs
                    tags$div(
                      class = "detail-header-tabs",
                      actionButton(
                        ns("tab_context"),
                        label = tagList(tags$i(class = "fas fa-file-alt"), i18n$t("context")),
                        class = "tab-btn-blue active"
                      ),
                      actionButton(
                        ns("tab_variables"),
                        label = tagList(tags$i(class = "fas fa-list"), i18n$t("variables")),
                        class = "tab-btn-blue"
                      )
                    )
                  ),

                  # Tab content panels
                  tags$div(
                    class = "detail-tab-content",

                    # Context Tab Panel
                    tags$div(
                      id = ns("panel_context"),
                      class = "detail-tab-panel active",
                      tags$div(
                        class = "settings-backup-container",

                        # Justification Section
                        tags$div(
                          class = "settings-section settings-backup-section",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-flask", style = "margin-right: 8px; color: #0f60af;"),
                            i18n$t("justification")
                          ),
                          tags$p(
                            class = "settings-section-desc",
                            "Scientific rationale and objectives of the study"
                          ),
                          textAreaInput(
                            ns("context_justification"),
                            label = NULL,
                            placeholder = as.character(i18n$t("enter_justification")),
                            width = "100%",
                            height = "100%"
                          )
                        ),

                        # Bibliography Section
                        tags$div(
                          class = "settings-section settings-backup-section",
                          tags$h4(
                            class = "settings-section-title settings-section-title-success",
                            tags$i(class = "fas fa-book", style = "margin-right: 8px; color: #28a745;"),
                            i18n$t("bibliography")
                          ),
                          tags$p(
                            class = "settings-section-desc",
                            "Key references and citations"
                          ),
                          textAreaInput(
                            ns("context_bibliography"),
                            label = NULL,
                            placeholder = as.character(i18n$t("enter_bibliography")),
                            width = "100%",
                            height = "100%"
                          )
                        )
                      )
                    ),

                    # Variables Tab Panel
                    tags$div(
                      id = ns("panel_variables"),
                      class = "detail-tab-panel",
                      tags$div(
                        class = "settings-backup-container",

                        # Available Concept Sets Section
                        tags$div(
                          class = "settings-section settings-backup-section",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-list", style = "margin-right: 8px; color: #0f60af;"),
                            i18n$t("available_concept_sets")
                          ),
                          tags$div(
                            style = "display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px;",
                            tags$p(
                              class = "settings-section-desc",
                              style = "margin: 0;",
                              i18n$t("available_concept_sets_tooltip")
                            ),
                            actionButton(
                              ns("add_concept_sets_btn"),
                              i18n$t("add_selected"),
                              class = "btn-success-custom btn-xs",
                              icon = icon("arrow-right")
                            )
                          ),
                          tags$div(
                            id = ns("available_concept_sets_empty"),
                            class = "no-content-message",
                            style = "display: none;",
                            i18n$t("all_concept_sets_added")
                          ),
                          shinyjs::hidden(
                            tags$div(
                              id = ns("available_concept_sets_table_container"),
                              DT::DTOutput(ns("available_concept_sets_table"))
                            )
                          )
                        ),

                        # Selected Concept Sets Section
                        tags$div(
                          class = "settings-section settings-backup-section",
                          tags$h4(
                            class = "settings-section-title settings-section-title-success",
                            tags$i(class = "fas fa-check-circle", style = "margin-right: 8px; color: #28a745;"),
                            i18n$t("selected_concept_sets")
                          ),
                          tags$div(
                            style = "display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px;",
                            tags$p(
                              class = "settings-section-desc",
                              style = "margin: 0;",
                              i18n$t("selected_concept_sets_tooltip")
                            ),
                            actionButton(
                              ns("remove_concept_sets_btn"),
                              i18n$t("remove_selected"),
                              class = "btn-danger-custom btn-xs",
                              icon = icon("times")
                            )
                          ),
                          tags$div(
                            id = ns("selected_concept_sets_empty"),
                            class = "no-content-message",
                            style = "display: none;",
                            i18n$t("no_concept_sets_assigned")
                          ),
                          shinyjs::hidden(
                            tags$div(
                              id = ns("selected_concept_sets_table_container"),
                              DT::DTOutput(ns("selected_concept_sets_table"))
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
        )
      )
    ),

    ## UI - Modals ----

    ### Modal - Add/Edit Project ----
    create_modal(
      id = "project_modal",
      title = i18n$t("add_project"),
      body = tagList(
        shinyjs::hidden(
          textInput(ns("editing_project_id"), label = NULL, value = "")
        ),
        # Name (required)
        tags$div(
          class = "mb-15",
          tags$label(class = "form-label", i18n$t("name"), tags$span(class = "text-danger", " *")),
          textInput(ns("project_name"), label = NULL, placeholder = i18n$t("enter_name")),
          tags$div(id = ns("name_error"), class = "input-error-message", style = "display: none;")
        ),
        # Short description (optional)
        tags$div(
          class = "mb-15",
          tags$label(class = "form-label", i18n$t("short_description")),
          textInput(ns("project_short_description"), label = NULL, placeholder = i18n$t("enter_short_description"), width = "100%")
        )
      ),
      footer = tagList(
        actionButton(ns("cancel_project"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
        actionButton(ns("save_project"), i18n$t("save"), class = "btn-primary-custom", icon = icon("save"))
      ),
      size = "medium",
      icon = "fas fa-folder-open",
      ns = ns
    ),

    ### Modal - Delete Confirmation ----
    create_modal(
      id = "delete_project_modal",
      title = i18n$t("confirm_deletion"),
      body = tagList(
        shinyjs::hidden(
          textInput(ns("deleting_project_id"), label = NULL, value = "")
        ),
        tags$p(id = ns("delete_confirmation_message")),
        tags$p(
          style = "color: #dc3545; margin-top: 10px;",
          tags$strong("Note:"), " ", i18n$t("delete_project_note")
        )
      ),
      footer = tagList(
        actionButton(ns("cancel_delete_project"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
        actionButton(ns("confirm_delete_project"), i18n$t("delete"), class = "btn-danger-custom", icon = icon("trash"))
      ),
      size = "small",
      icon = "fas fa-exclamation-triangle",
      ns = ns
    )
  )
}

# SERVER SECTION ====

#' Projects Module - Server
#'
#' @param id Module ID
#' @param i18n Translator object
#' @param current_user Reactive: Current logged-in user
#'
#' @noRd
mod_projects_server <- function(id, i18n, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    log_level <- strsplit(Sys.getenv("INDICATE_DEBUG_MODE", "error"), ",")[[1]]

    # 1) REACTIVE VALUES & STATE ====

    ## View State ----
    current_view <- reactiveVal("list")
    selected_project <- reactiveVal(NULL)

    ## Permissions ----
    can_edit <- reactive({ TRUE })

    ## Data ----
    projects_data <- reactiveVal(NULL)

    ## Triggers ----
    projects_table_trigger <- reactiveVal(0)
    available_table_trigger <- reactiveVal(0)
    selected_table_trigger <- reactiveVal(0)

    ## Edit State ----
    editing_id <- reactiveVal(NULL)
    deleting_id <- reactiveVal(NULL)

    # 2) DATA LOADING ====

    ## Load Projects (initialization) ----
    projects_data(get_all_projects())

    # Initial table render
    projects_table_trigger(1)

    ## Show Add Button (based on permissions) ----
    observe_event(can_edit(), {
      if (can_edit()) {
        shinyjs::show("add_project")
      } else {
        shinyjs::hide("add_project")
      }
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    # 3) UI RENDERING ====

    ## Projects Table Container ----
    observe_event(projects_table_trigger(), {
      output$projects_table_container <- renderUI({
        data <- projects_data()

        if (is.null(data) || nrow(data) == 0) {
          return(tags$div(
            class = "no-content-message",
            tags$p(i18n$t("no_projects"))
          ))
        }

        DT::DTOutput(ns("projects_table"))
      })

      ## Projects Table ----
      output$projects_table <- DT::renderDT({
        data <- projects_data()

        if (is.null(data) || nrow(data) == 0) return(NULL)

        # Prepare display data
        display_data <- data.frame(
          id = data$project_id,
          name = data$name,
          description = ifelse(is.na(data$description), "", data$description),
          concept_sets = data$concept_set_count,
          created_by = ifelse(is.na(data$created_by), "", data$created_by),
          created_at = format_date(data$created_at),
          stringsAsFactors = FALSE
        )

        # Add action buttons
        display_data$actions <- sapply(display_data$id, function(row_id) {
          create_datatable_actions(list(
            list(
              label = as.character(i18n$t("view")),
              icon = "eye",
              type = "primary",
              class = "btn-view",
              data_attr = list(id = row_id)
            ),
            list(
              label = as.character(i18n$t("edit")),
              icon = "edit",
              type = "warning",
              class = "btn-edit",
              data_attr = list(id = row_id)
            ),
            list(
              label = as.character(i18n$t("delete")),
              icon = "trash",
              type = "danger",
              class = "btn-delete",
              data_attr = list(id = row_id)
            )
          ))
        })

        dt <- create_standard_datatable(
          display_data,
          selection = "none",
          col_names = c(
            "ID",
            as.character(i18n$t("name")),
            as.character(i18n$t("short_description")),
            as.character(i18n$t("concept_sets")),
            as.character(i18n$t("created_by")),
            as.character(i18n$t("created_at")),
            as.character(i18n$t("actions"))
          ),
          col_defs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 1, width = "20%"),
            list(targets = 2, width = "30%"),
            list(targets = 3, width = "10%", className = "dt-center"),
            list(targets = 4, width = "15%"),
            list(targets = 5, width = "10%"),
            list(targets = 6, width = "15%", className = "dt-center")
          ),
          escape = FALSE
        )

        add_button_handlers(
          dt,
          handlers = list(
            list(selector = ".btn-view", input_id = ns("view_project")),
            list(selector = ".btn-edit", input_id = ns("edit_project")),
            list(selector = ".btn-delete", input_id = ns("delete_project"))
          ),
          dblclick_input_id = ns("view_project"),
          id_column_index = 0
        )
      })
    }, ignoreInit = FALSE)

    ## Custom Tab Handlers ----
    observe_event(input$tab_context, {
      # Switch to context tab
      shinyjs::runjs(sprintf("
        document.querySelectorAll('#%s .tab-btn-blue').forEach(function(btn) { btn.classList.remove('active'); });
        document.getElementById('%s').classList.add('active');
        document.querySelectorAll('#%s .detail-tab-panel').forEach(function(panel) { panel.classList.remove('active'); });
        document.getElementById('%s').classList.add('active');
      ", ns("detail_view"), ns("tab_context"), ns("detail_view"), ns("panel_context")))

      # Enable save button and restore tooltip for context tab
      shinyjs::enable("save_context")
      shinyjs::runjs(sprintf("
        var btn = document.getElementById('%s');
        btn.setAttribute('data-tooltip', '%s');
        btn.classList.remove('btn-disabled');
      ", ns("save_context"), i18n$t("save_context")))
    }, ignoreInit = TRUE)

    observe_event(input$tab_variables, {
      # Switch to variables tab
      shinyjs::runjs(sprintf("
        document.querySelectorAll('#%s .tab-btn-blue').forEach(function(btn) { btn.classList.remove('active'); });
        document.getElementById('%s').classList.add('active');
        document.querySelectorAll('#%s .detail-tab-panel').forEach(function(panel) { panel.classList.remove('active'); });
        document.getElementById('%s').classList.add('active');
      ", ns("detail_view"), ns("tab_variables"), ns("detail_view"), ns("panel_variables")))

      # Disable save button and update tooltip to show auto-save message
      shinyjs::disable("save_context")
      shinyjs::runjs(sprintf("
        var btn = document.getElementById('%s');
        btn.setAttribute('data-tooltip', '%s');
        btn.classList.add('btn-disabled');
      ", ns("save_context"), i18n$t("auto_save_enabled")))

      # Trigger table renders
      available_table_trigger(available_table_trigger() + 1)
      selected_table_trigger(selected_table_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Available Concept Sets Table ----
    # Initialize empty table (required for outputOptions to work)
    output$available_concept_sets_table <- DT::renderDT({
      create_empty_datatable("")
    })

    observe_event(available_table_trigger(), {
      project <- selected_project()
      if (is.null(project)) return()

      data <- get_available_concept_sets_for_project(project$project_id)

      if (is.null(data) || nrow(data) == 0) {
        # Show empty message, hide table
        shinyjs::show("available_concept_sets_empty")
        shinyjs::hide("available_concept_sets_table_container")
        return()
      }

      # Hide empty message, show table
      shinyjs::hide("available_concept_sets_empty")
      shinyjs::show("available_concept_sets_table_container")

      output$available_concept_sets_table <- DT::renderDT({
        # Prepare display data
        display_data <- data.frame(
          id = data$id,
          name = data$name,
          category = ifelse(is.na(data$category), "", data$category),
          subcategory = ifelse(is.na(data$subcategory), "", data$subcategory),
          stringsAsFactors = FALSE
        )

        create_standard_datatable(
          display_data,
          selection = "multiple",
          col_names = c(
            as.character(i18n$t("name")),
            as.character(i18n$t("category")),
            as.character(i18n$t("subcategory"))
          ),
          col_defs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 1, width = "40%"),
            list(targets = 2, width = "30%"),
            list(targets = 3, width = "30%")
          ),
          page_length = 10
        )
      })
    }, ignoreInit = TRUE)

    ## Selected Concept Sets Table ----
    # Initialize empty table (required for outputOptions to work)
    output$selected_concept_sets_table <- DT::renderDT({
      create_empty_datatable("")
    })

    observe_event(selected_table_trigger(), {
      project <- selected_project()
      if (is.null(project)) return()

      data <- get_project_concept_sets(project$project_id)

      if (is.null(data) || nrow(data) == 0) {
        # Show empty message, hide table
        shinyjs::show("selected_concept_sets_empty")
        shinyjs::hide("selected_concept_sets_table_container")
        return()
      }

      # Hide empty message, show table
      shinyjs::hide("selected_concept_sets_empty")
      shinyjs::show("selected_concept_sets_table_container")

      output$selected_concept_sets_table <- DT::renderDT({
        # Prepare display data
        display_data <- data.frame(
          id = data$id,
          name = data$name,
          category = ifelse(is.na(data$category), "", data$category),
          subcategory = ifelse(is.na(data$subcategory), "", data$subcategory),
          stringsAsFactors = FALSE
        )

        create_standard_datatable(
          display_data,
          selection = "multiple",
          col_names = c(
            "ID",
            as.character(i18n$t("name")),
            as.character(i18n$t("category")),
            as.character(i18n$t("subcategory"))
          ),
          col_defs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 1, width = "40%"),
            list(targets = 2, width = "30%"),
            list(targets = 3, width = "30%")
          ),
          page_length = 10
        )
      })
    }, ignoreInit = TRUE)

    # Force render even when hidden (tables are in hidden tab initially)
    outputOptions(output, "available_concept_sets_table", suspendWhenHidden = FALSE)
    outputOptions(output, "selected_concept_sets_table", suspendWhenHidden = FALSE)

    # 4) CRUD OPERATIONS ====

    ## Navigation ----

    # Back to list
    observe_event(input$back_to_list, {
      current_view("list")
      selected_project(NULL)
      shinyjs::hide("detail_view")
      shinyjs::show("list_view")
    }, ignoreInit = TRUE)

    # View project detail
    observe_event(input$view_project, {
      project_id <- input$view_project
      if (is.null(project_id)) return()

      project <- get_project(project_id)
      if (!is.null(project)) {
        selected_project(project)
        current_view("detail")

        # Update project name in header (text content and tooltip)
        escaped_name <- gsub("'", "\\\\'", project$name)
        shinyjs::runjs(sprintf(
          "var el = document.getElementById('%s'); el.textContent = '%s'; el.title = '%s';",
          ns("detail_project_name"),
          escaped_name,
          escaped_name
        ))

        # Populate context fields
        updateTextAreaInput(session, "context_justification",
          value = if (!is.null(project$justification) && !is.na(project$justification)) project$justification else "")
        updateTextAreaInput(session, "context_bibliography",
          value = if (!is.null(project$bibliography) && !is.na(project$bibliography)) project$bibliography else "")

        # Switch views
        shinyjs::hide("list_view")
        shinyjs::show("detail_view")

        # Reset to context tab and show save button
        shinyjs::runjs(sprintf("
          document.querySelectorAll('#%s .tab-btn-blue').forEach(function(btn) { btn.classList.remove('active'); });
          document.getElementById('%s').classList.add('active');
          document.querySelectorAll('#%s .detail-tab-panel').forEach(function(panel) { panel.classList.remove('active'); });
          document.getElementById('%s').classList.add('active');
        ", ns("detail_view"), ns("tab_context"), ns("detail_view"), ns("panel_context")))
        shinyjs::show("save_context")
      }
    }, ignoreInit = TRUE)

    ## Add Project ----
    observe_event(input$add_project, {
      # Reset form
      editing_id(NULL)
      updateTextInput(session, "editing_project_id", value = "")
      updateTextInput(session, "project_name", value = "")
      updateTextInput(session, "project_short_description", value = "")

      # Hide errors
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", ns("name_error")))

      # Update modal title
      shinyjs::runjs(sprintf(
        "document.querySelector('#%s .modal-header h3').textContent = '%s';",
        ns("project_modal"),
        as.character(i18n$t("add_project"))
      ))

      show_modal(ns("project_modal"))
    }, ignoreInit = TRUE)

    ## Edit Project (from table) ----
    observe_event(input$edit_project, {
      project_id <- input$edit_project
      if (is.null(project_id)) return()
      open_edit_modal(project_id)
    }, ignoreInit = TRUE)

    # Helper to open edit modal
    open_edit_modal <- function(project_id) {
      project <- get_project(project_id)
      if (is.null(project)) return()

      editing_id(project_id)
      updateTextInput(session, "editing_project_id", value = as.character(project_id))
      updateTextInput(session, "project_name", value = project$name)
      updateTextInput(session, "project_short_description",
        value = if (!is.null(project$description) && !is.na(project$description)) project$description else "")

      # Hide errors
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", ns("name_error")))

      # Update modal title
      shinyjs::runjs(sprintf(
        "document.querySelector('#%s .modal-header h3').textContent = '%s';",
        ns("project_modal"),
        as.character(i18n$t("edit_project"))
      ))

      show_modal(ns("project_modal"))
    }

    ## Save Project ----
    observe_event(input$save_project, {
      name <- trimws(input$project_name)
      description <- trimws(input$project_short_description)
      edit_id <- editing_id()

      # Validation - name required
      if (name == "") {
        shinyjs::runjs(sprintf(
          "document.getElementById('%s').style.display = 'block'; document.getElementById('%s').textContent = '%s';",
          ns("name_error"), ns("name_error"), as.character(i18n$t("name_required"))
        ))
        return()
      }

      # Check for duplicate name
      all_projects <- projects_data()
      if (!is.null(all_projects) && nrow(all_projects) > 0) {
        existing <- all_projects[tolower(all_projects$name) == tolower(name), ]
        if (!is.null(edit_id)) {
          existing <- existing[existing$project_id != edit_id, ]
        }
        if (nrow(existing) > 0) {
          shinyjs::runjs(sprintf(
            "document.getElementById('%s').style.display = 'block'; document.getElementById('%s').textContent = '%s';",
            ns("name_error"), ns("name_error"), as.character(i18n$t("name_already_exists"))
          ))
          return()
        }
      }

      # Hide errors
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", ns("name_error")))

      # Get current user for created_by field
      user <- if (!is.null(current_user)) current_user() else NULL
      created_by <- if (!is.null(user)) paste(user$first_name, user$last_name) else NULL

      if (is.null(edit_id)) {
        # Create new project
        add_project(
          name = name,
          description = if (description == "") NULL else description,
          created_by = created_by
        )
        showNotification(i18n$t("project_added"), type = "message")
      } else {
        # Update existing project
        update_project(
          project_id = edit_id,
          name = name,
          description = if (description == "") NULL else description
        )
        showNotification(i18n$t("project_updated"), type = "message")

        # Update selected project and header if in detail view
        if (current_view() == "detail") {
          selected_project(get_project(edit_id))
          escaped_name <- gsub("'", "\\\\'", name)
          shinyjs::runjs(sprintf(
            "var el = document.getElementById('%s'); el.textContent = '%s'; el.title = '%s';",
            ns("detail_project_name"),
            escaped_name,
            escaped_name
          ))
        }
      }

      # Refresh data
      projects_data(get_all_projects())
      projects_table_trigger(projects_table_trigger() + 1)

      # Close modal
      hide_modal(ns("project_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Project Modal ----
    observe_event(input$cancel_project, {
      hide_modal(ns("project_modal"))
    }, ignoreInit = TRUE)

    ## Delete Project (from table) ----
    observe_event(input$delete_project, {
      project_id <- input$delete_project
      if (is.null(project_id)) return()
      open_delete_modal(project_id)
    }, ignoreInit = TRUE)

    # Helper to open delete modal
    open_delete_modal <- function(project_id) {
      project <- get_project(project_id)
      if (is.null(project)) return()

      deleting_id(project_id)
      updateTextInput(session, "deleting_project_id", value = as.character(project_id))

      # Update confirmation message
      message <- paste0(i18n$t("confirm_delete_project"), " \"", project$name, "\"?")
      shinyjs::runjs(sprintf(
        "document.getElementById('%s').textContent = '%s';",
        ns("delete_confirmation_message"),
        gsub("'", "\\\\'", message)
      ))

      show_modal(ns("delete_project_modal"))
    }

    ## Confirm Delete Project ----
    observe_event(input$confirm_delete_project, {
      project_id <- deleting_id()
      if (is.null(project_id)) return()

      delete_project(project_id)
      showNotification(i18n$t("project_deleted"), type = "message")

      # If in detail view, go back to list
      if (current_view() == "detail") {
        current_view("list")
        selected_project(NULL)
        shinyjs::hide("detail_view")
        shinyjs::show("list_view")
      }

      # Refresh data
      projects_data(get_all_projects())
      projects_table_trigger(projects_table_trigger() + 1)

      # Close modal
      hide_modal(ns("delete_project_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Delete ----
    observe_event(input$cancel_delete_project, {
      hide_modal(ns("delete_project_modal"))
    }, ignoreInit = TRUE)

    ## Save Context ----
    observe_event(input$save_context, {
      project <- selected_project()
      if (is.null(project)) return()

      justification <- trimws(input$context_justification)
      bibliography <- trimws(input$context_bibliography)

      update_project(
        project_id = project$project_id,
        justification = if (justification == "") NULL else justification,
        bibliography = if (bibliography == "") NULL else bibliography
      )

      # Update selected project
      selected_project(get_project(project$project_id))

      showNotification(i18n$t("context_saved"), type = "message")
    }, ignoreInit = TRUE)

    ## Add Concept Sets to Project ----
    observe_event(input$add_concept_sets_btn, {
      project <- selected_project()
      if (is.null(project)) return()

      selected_rows <- input$available_concept_sets_table_rows_selected
      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      # Get available concept sets data
      available_data <- get_available_concept_sets_for_project(project$project_id)
      if (is.null(available_data) || nrow(available_data) == 0) return()

      # Add each selected concept set
      concept_set_ids <- available_data$id[selected_rows]
      for (cs_id in concept_set_ids) {
        add_project_concept_set(project$project_id, cs_id)
      }

      # Refresh tables
      available_table_trigger(available_table_trigger() + 1)
      selected_table_trigger(selected_table_trigger() + 1)

      # Update projects data to refresh counts
      projects_data(get_all_projects())

      showNotification(i18n$t("concept_sets_added"), type = "message")
    }, ignoreInit = TRUE)

    ## Remove Concept Sets from Project ----
    observe_event(input$remove_concept_sets_btn, {
      project <- selected_project()
      if (is.null(project)) return()

      selected_rows <- input$selected_concept_sets_table_rows_selected
      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      # Get selected concept sets data
      selected_data <- get_project_concept_sets(project$project_id)
      if (is.null(selected_data) || nrow(selected_data) == 0) return()

      # Remove each selected concept set
      concept_set_ids <- selected_data$id[selected_rows]
      for (cs_id in concept_set_ids) {
        remove_project_concept_set(project$project_id, cs_id)
      }

      # Refresh tables
      available_table_trigger(available_table_trigger() + 1)
      selected_table_trigger(selected_table_trigger() + 1)

      # Update projects data to refresh counts
      projects_data(get_all_projects())

      showNotification(i18n$t("concept_sets_removed"), type = "message")
    }, ignoreInit = TRUE)
  })
}

# HELPER FUNCTIONS ====

#' Format date for display
#'
#' @param date_str Date string or vector of date strings
#' @return Formatted date string or vector
#' @noRd
format_date <- function(date_str) {
  sapply(date_str, function(d) {
    if (is.null(d) || length(d) == 0 || is.na(d) || d == "") return("")
    tryCatch({
      date_obj <- as.POSIXct(d, format = "%Y-%m-%d %H:%M:%S")
      format(date_obj, "%Y-%m-%d")
    }, error = function(e) {
      as.character(d)
    })
  }, USE.NAMES = FALSE)
}
