# MODULE STRUCTURE OVERVIEW ====
#
# This module manages user accounts and access permissions in the application
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Users Tab - Manage user accounts
#         #### Header with Add User Button
#         #### Users Table
#      ### User Accesses Tab - Manage permission profiles
#         #### Header with Add User Access Button
#         #### User Accesses Table
#         #### Permissions Panel (when a user access is selected)
#   ## UI - Modals
#      ### Modal - Add/Edit User Form
#      ### Modal - Add/Edit User Access Form
#      ### Modal - Delete Confirmation
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Editing State
#      ### Data Management
#      ### Triggers
#
#   ## 2) Server - Users Tab
#      ### Load Users Data
#      ### Render Users Table
#      ### Add/Edit/Delete User Actions
#      ### Save User
#
#   ## 3) Server - User Accesses Tab
#      ### Load User Accesses Data
#      ### Render User Accesses Table
#      ### Render Permissions Panel
#      ### Add/Edit/Delete User Access Actions
#      ### Save User Access
#      ### Toggle Permission

# UI - Main Layout ====

#' Users Management Module
#'
#' @description Module for managing users and access permissions
#'
#' @param id Namespace id
#' @param i18n Translator object from shiny.i18n
#'
#' @return Shiny module UI
#' @noRd
#'
#' @importFrom shiny NS div actionButton uiOutput textInput passwordInput selectInput tabsetPanel tabPanel
#' @importFrom DT DTOutput
#' @importFrom htmltools tagList tags
mod_users_ui <- function(id, i18n) {
  ns <- NS(id)

  div(
    class = "main-panel",
    div(
      class = "main-content",
      tabsetPanel(
        id = ns("users_tabs"),

        ### Users Tab ----
        tabPanel(
          i18n$t("users"),
          value = "users",
          icon = icon("users"),
          tags$div(
            style = "margin-top: 10px; height: calc(100vh - 170px); display: flex; flex-direction: column;",

            ## Header with Add User Button ----
            div(
              style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 15px; flex-shrink: 0;",
              actionButton(
                ns("add_user_btn"),
                i18n$t("add_user"),
                class = "btn-success-custom",
                icon = icon("plus")
              )
            ),

            ## Users Table ----
            div(
              style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); flex: 1; overflow: auto;",
              DTOutput(ns("users_table"))
            )
          )
        ),

        ### User Accesses Tab ----
        tabPanel(
          i18n$t("user_accesses"),
          value = "user_accesses",
          icon = icon("key"),
          tags$div(
            style = "margin-top: 10px; height: calc(100vh - 170px); display: flex; flex-direction: row; gap: 20px;",

            ## Left Panel - User Accesses List ----
            div(
              style = "width: 40%; display: flex; flex-direction: column;",

              # Header with Add Button
              div(
                style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 15px; flex-shrink: 0;",
                actionButton(
                  ns("add_user_access_btn"),
                  i18n$t("add_user_access"),
                  class = "btn-success-custom",
                  icon = icon("plus")
                )
              ),

              # User Accesses Table
              div(
                style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); flex: 1; overflow: auto;",
                DTOutput(ns("user_accesses_table"))
              )
            ),

            ## Right Panel - Permissions ----
            div(
              style = "flex: 1; display: flex; flex-direction: column;",

              # Permissions Header with Check/Uncheck buttons
              div(
                style = "margin-bottom: 15px; flex-shrink: 0;",
                div(
                  style = "display: flex; justify-content: space-between; align-items: center; padding-bottom: 8px; border-bottom: 2px solid #0f60af;",
                  tags$h4(
                    id = ns("permissions_header"),
                    style = "margin: 0; color: #333;",
                    tags$i(class = "fas fa-shield-alt", style = "margin-right: 8px; color: #0f60af;"),
                    i18n$t("permissions")
                  ),
                  div(
                    id = ns("permissions_buttons"),
                    style = "display: none; gap: 8px;",
                    actionButton(
                      ns("check_all_permissions"),
                      i18n$t("check_all"),
                      class = "btn-sm btn-success-custom",
                      icon = icon("check-square")
                    ),
                    actionButton(
                      ns("uncheck_all_permissions"),
                      i18n$t("uncheck_all"),
                      class = "btn-sm btn-secondary-custom",
                      icon = icon("square")
                    ),
                    actionButton(
                      ns("save_permissions"),
                      i18n$t("save"),
                      class = "btn-sm btn-primary-custom",
                      icon = icon("save")
                    )
                  )
                )
              ),

              # Permissions Content
              div(
                style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); flex: 1; overflow: auto;",
                uiOutput(ns("permissions_panel"))
              )
            )
          )
        )
      )
    ),

    ## Modal - Add/Edit User Form ----
    div(
      id = ns("user_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) { Shiny.setInputValue('%s', Math.random()); }", ns("close_modal_overlay")),
      div(
        class = "modal-content",
        class = "max-width-500",

        # Modal header
        div(
          class = "modal-header",
          tags$h3(
            id = ns("modal_title"),
            i18n$t("add_user")
          ),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("user_modal")),
            "×"
          )
        ),

        # Modal body
        div(
          class = "modal-body",
          div(
            class = "mb-15",
            tags$label(
              tagList(i18n$t("login_label"), " *"),
              class = "form-label"
            ),
          textInput(
            ns("user_login"),
            label = NULL,
            placeholder = as.character(i18n$t("enter_login")),
            width = "100%"
          ),
          div(
            id = ns("login_error"),
            class = "input-error-message"
          )
        ),

        div(
          class = "mb-15",
          tags$label(
            tagList(i18n$t("password_label"), " *"),
            class = "form-label"
          ),
          div(
            class = "position-relative",
            passwordInput(
              ns("user_password"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_password")),
              width = "100%"
            ),
            tags$button(
              type = "button",
              class = "password-toggle-btn",
              `data-input` = ns("user_password"),
              `data-icon` = ns("password_icon"),
              style = paste0(
                "position: absolute; right: 10px; top: 50%; ",
                "transform: translateY(-50%); background: none; ",
                "border: none; cursor: pointer; color: #666; padding: 5px;"
              ),
              tags$i(class = "fas fa-eye", id = ns("password_icon"))
            )
          ),
          div(
            id = ns("password_error"),
            class = "input-error-message"
          )
        ),

        div(
          class = "mb-15",
          tags$label(
            tagList(i18n$t("confirm_password"), " *"),
            class = "form-label"
          ),
          div(
            class = "position-relative",
            passwordInput(
              ns("user_password_confirm"),
              label = NULL,
              placeholder = as.character(i18n$t("confirm_password")),
              width = "100%"
            ),
            tags$button(
              type = "button",
              class = "password-toggle-btn",
              `data-input` = ns("user_password_confirm"),
              `data-icon` = ns("password_confirm_icon"),
              style = paste0(
                "position: absolute; right: 10px; top: 50%; ",
                "transform: translateY(-50%); background: none; ",
                "border: none; cursor: pointer; color: #666; padding: 5px;"
              ),
              tags$i(class = "fas fa-eye", id = ns("password_confirm_icon"))
            )
          ),
          div(
            id = ns("password_confirm_error"),
            class = "input-error-message"
          ),
          tags$small(
            id = ns("password_help"),
            style = "color: #7f8c8d; font-size: 12px;",
            i18n$t("leave_empty_password")
          )
        ),

        div(
          class = "mb-15",
          tags$label(
            tagList(i18n$t("first_name"), " *"),
            class = "form-label"
          ),
          textInput(
            ns("user_first_name"),
            label = NULL,
            placeholder = as.character(i18n$t("enter_first_name")),
            width = "100%"
          ),
          div(
            id = ns("first_name_error"),
            class = "input-error-message"
          )
        ),

        div(
          class = "mb-15",
          tags$label(
            tagList(i18n$t("last_name"), " *"),
            class = "form-label"
          ),
          textInput(
            ns("user_last_name"),
            label = NULL,
            placeholder = as.character(i18n$t("enter_last_name")),
            width = "100%"
          ),
          div(
            id = ns("last_name_error"),
            class = "input-error-message"
          )
        ),

        div(
          class = "mb-15",
          tags$label(
            i18n$t("role"),
            class = "form-label"
          ),
          selectInput(
            ns("user_role"),
            label = NULL,
            choices = stats::setNames(
              c("Clinician", "Data scientist", "Engineer"),
              c(as.character(i18n$t("clinician")), as.character(i18n$t("data_scientist")), as.character(i18n$t("engineer")))
            ),
            width = "100%"
          )
        ),

        div(
          class = "mb-15",
          tags$label(
            tagList(i18n$t("user_access"), " *"),
            class = "form-label"
          ),
          selectInput(
            ns("user_user_access"),
            label = NULL,
            choices = c(),
            width = "100%"
          ),
          div(
            id = ns("user_access_error"),
            class = "input-error-message"
          )
        ),

        div(
          class = "mb-20",
          tags$label(
            i18n$t("affiliation"),
            class = "form-label"
          ),
          tags$textarea(
            id = ns("user_affiliation"),
            placeholder = as.character(i18n$t("enter_affiliation")),
            style = "width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px; font-family: inherit; font-size: 14px; resize: vertical; min-height: 60px;"
          )
        )
        ),

        # Modal footer
        div(
          class = "modal-footer",
          tags$button(
            class = "btn btn-secondary btn-secondary-custom",
            onclick = sprintf("$('#%s').hide();", ns("user_modal")),
            tags$i(class = "fas fa-times"),
            " ", i18n$t("cancel")
          ),
          actionButton(
            ns("save_user"),
            i18n$t("save"),
            class = "btn-primary-custom",
            icon = icon("save")
          )
        )
      )
    ),

    ## Modal - Add/Edit User Access Form ----
    div(
      id = ns("user_access_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) { Shiny.setInputValue('%s', Math.random()); }", ns("close_user_access_modal_overlay")),
      div(
        class = "modal-content",
        class = "max-width-500",

        # Modal header
        div(
          class = "modal-header",
          tags$h3(
            id = ns("user_access_modal_title"),
            i18n$t("add_user_access")
          ),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("user_access_modal")),
            "×"
          )
        ),

        # Modal body
        div(
          class = "modal-body",
          div(
            class = "mb-15",
            tags$label(
              tagList(i18n$t("name"), " *"),
              class = "form-label"
            ),
            textInput(
              ns("user_access_name"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_name")),
              width = "100%"
            ),
            div(
              id = ns("user_access_name_error"),
              class = "input-error-message"
            )
          ),

          div(
            class = "mb-20",
            tags$label(
              i18n$t("description"),
              class = "form-label"
            ),
            tags$textarea(
              id = ns("user_access_description"),
              placeholder = as.character(i18n$t("enter_description")),
              style = "width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px; font-family: inherit; font-size: 14px; resize: vertical; min-height: 60px;"
            )
          )
        ),

        # Modal footer
        div(
          class = "modal-footer",
          tags$button(
            class = "btn btn-secondary btn-secondary-custom",
            onclick = sprintf("$('#%s').hide();", ns("user_access_modal")),
            tags$i(class = "fas fa-times"),
            " ", i18n$t("cancel")
          ),
          actionButton(
            ns("save_user_access"),
            i18n$t("save"),
            class = "btn-primary-custom",
            icon = icon("save")
          )
        )
      )
    ),

    ## Modal - Delete Confirmation ----
    tags$div(
      id = ns("delete_confirmation_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("delete_confirmation_modal")),
      tags$div(
        class = "modal-content",
        class = "max-width-500",
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
          class = "p-20",
          tags$p(
            id = ns("delete_confirmation_message"),
            style = "margin-bottom: 20px; font-size: 14px;"
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "display: flex; gap: 10px; justify-content: flex-end; padding: 15px 20px; border-top: 1px solid #dee2e6;",
          actionButton(
            ns("cancel_delete"),
            i18n$t("cancel"),
            class = "btn-secondary-custom",
            icon = icon("times")
          ),
          actionButton(
            ns("confirm_delete"),
            i18n$t("delete"),
            class = "btn-danger-custom",
            icon = icon("trash")
          )
        )
      )
    )
  )
}

# Server Logic ====

#' Users Management Module Server
#'
#' @description Server logic for user management
#'
#' @param id Namespace id
#' @param current_user Reactive containing current user data
#' @param i18n Translator object from shiny.i18n
#'
#' @return NULL
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent req renderUI updateTextInput updateSelectInput
#' @importFrom DT renderDT datatable formatStyle styleEqual
mod_users_server <- function(id, current_user, i18n, log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Helper function to check if current user has a specific permission
    user_has_permission <- function(category, permission) {
      user_has_permission_for(current_user, category, permission)
    }

    ## 1) Server - Reactive Values & State ====

    # Users state
    editing_user_id <- reactiveVal(NULL)
    deleting_user_id <- reactiveVal(NULL)
    users_data <- reactiveVal(NULL)

    # User Accesses state
    editing_user_access_id <- reactiveVal(NULL)
    deleting_user_access_id <- reactiveVal(NULL)
    user_accesses_data <- reactiveVal(NULL)
    selected_user_access_id <- reactiveVal(NULL)
    selected_user_access_permissions <- reactiveVal(NULL)
    pending_permissions <- reactiveVal(NULL)

    # Delete type: "user" or "user_access"
    delete_type <- reactiveVal(NULL)

    # Triggers
    users_table_trigger <- reactiveVal(0)
    user_accesses_table_trigger <- reactiveVal(0)
    permissions_panel_trigger <- reactiveVal(0)

    ### Update Button Visibility Based on Permissions ----
    update_button_visibility <- function() {
      user <- current_user()

      # Users tab buttons
      can_add_user <- user_has_permission("users", "add_user")
      can_edit_user <- user_has_permission("users", "edit_user")
      can_delete_user <- user_has_permission("users", "delete_user")

      # User Accesses tab buttons
      can_add_user_access <- user_has_permission("user_accesses", "add_user_access")
      can_edit_user_access <- user_has_permission("user_accesses", "edit_user_access")
      can_delete_user_access <- user_has_permission("user_accesses", "delete_user_access")
      can_edit_permissions <- user_has_permission("user_accesses", "edit_permissions")

      shinyjs::delay(100, {
        if (!is.null(user) && user$role != "Anonymous") {
          # Add User button
          if (can_add_user) shinyjs::show("add_user_btn") else shinyjs::hide("add_user_btn")

          # Add User Access button
          if (can_add_user_access) shinyjs::show("add_user_access_btn") else shinyjs::hide("add_user_access_btn")

          # Permissions buttons (only if edit_permissions)
          if (can_edit_permissions) {
            # Show will be controlled by select_user_access
          } else {
            shinyjs::runjs(sprintf("$('#%s').hide();", ns("permissions_buttons")))
          }
        } else {
          # Hide all edit buttons for anonymous users
          shinyjs::hide("add_user_btn")
          shinyjs::hide("add_user_access_btn")
          shinyjs::runjs(sprintf("$('#%s').hide();", ns("permissions_buttons")))
        }
      })

      # Trigger table refresh to update action buttons
      users_table_trigger(users_table_trigger() + 1)
      user_accesses_table_trigger(user_accesses_table_trigger() + 1)
    }

    # Call update_button_visibility when current_user changes
    observe_event(current_user(), {
      update_button_visibility()
    }, ignoreNULL = FALSE)

    ## 2) Server - Users Tab ====

    ### Load Users Data ----
    observe_event(TRUE, {
      users <- get_all_users()
      users_data(users)

      # Also load user accesses for the dropdown
      user_accesses <- get_all_user_accesses()
      user_accesses_data(user_accesses)

      # Update select input choices
      if (nrow(user_accesses) > 0) {
        choices <- stats::setNames(user_accesses$user_access_id, user_accesses$name)
        updateSelectInput(session, "user_user_access", choices = choices)
      }
    })

    ### Render Users Table ----
    observe_event(users_data(), {
      users_table_trigger(users_table_trigger() + 1)
    })

    observe_event(users_table_trigger(), {
      if (is.null(users_data())) return()

      output$users_table <- renderDT({
        users <- users_data()

        # Check permissions for action buttons
        can_edit <- user_has_permission("users", "edit_user")
        can_delete <- user_has_permission("users", "delete_user")
        current_user_id <- if (!is.null(current_user())) current_user()$user_id else NULL

        # Store user_id as first hidden column for double-click handler
        users_with_id <- users

        # Add action buttons (generate for each row based on permissions)
        users_with_id$Actions <- sapply(users$user_id, function(id) {
          actions <- list()

          if (can_edit) {
            actions <- c(actions, list(list(
              label = as.character(i18n$t("edit")),
              icon = "edit",
              type = "warning",
              class = "btn-edit",
              data_attr = list(id = id)
            )))
          }

          # Only show delete button if user has permission and it's not their own account
          if (can_delete && (is.null(current_user_id) || id != current_user_id)) {
            actions <- c(actions, list(list(
              label = as.character(i18n$t("delete")),
              icon = "trash",
              type = "danger",
              class = "btn-delete",
              data_attr = list(id = id)
            )))
          }

          if (length(actions) == 0) return("")
          create_datatable_actions(actions)
        })

        # Select display columns with user_id first (hidden)
        display_data <- users_with_id[, c("user_id", "login", "first_name", "last_name", "user_access_name", "role", "affiliation", "Actions")]
        colnames(display_data) <- c(
          "user_id",
          as.character(i18n$t("login_label")),
          as.character(i18n$t("first_name")),
          as.character(i18n$t("last_name")),
          as.character(i18n$t("user_access")),
          as.character(i18n$t("role")),
          as.character(i18n$t("affiliation")),
          as.character(i18n$t("actions"))
        )

        dt <- datatable(
          display_data,
          selection = "none",
          rownames = FALSE,
          escape = FALSE,
          filter = "top",
          class = "cell-border stripe hover",
          callback = JS(sprintf("
            table.on('dblclick', 'tbody tr', function() {
              var data = table.row(this).data();
              if (data) {
                var userId = data[0];
                Shiny.setInputValue('%s', userId, {priority: 'event'});
              }
            });
          ", ns("edit_user"))),
          options = list(
            pageLength = 25,
            dom = "tip",
            ordering = TRUE,
            autoWidth = FALSE,
            language = get_datatable_language(),
            columnDefs = list(
              list(visible = FALSE, targets = 0),
              list(width = "200px", targets = 7),
              list(searchable = FALSE, targets = 7),
              list(className = "dt-center", targets = 7)
            )
          )
        )

        # Add button handlers
        dt <- add_button_handlers(
          dt,
          handlers = list(
            list(selector = ".btn-edit", input_id = ns("edit_user")),
            list(selector = ".btn-delete", input_id = ns("delete_user"))
          )
        )

        dt
      })
    }, ignoreInit = FALSE)

    ### Add User Modal ----
    observe_event(input$add_user_btn, {
      # Check permissions
      if (!user_has_permission("users", "add_user")) return()

      # Set add mode (not editing)
      editing_user_id(NULL)
      shinyjs::html("modal_title", as.character(i18n$t("add_user")))
      shinyjs::hide("password_help")

      # Reset form fields
      updateTextInput(session, "user_login", value = "")
      updateTextInput(session, "user_password", value = "")
      updateTextInput(session, "user_password_confirm", value = "")
      updateTextInput(session, "user_first_name", value = "")
      updateTextInput(session, "user_last_name", value = "")
      updateSelectInput(session, "user_role", selected = "Data scientist")
      shinyjs::runjs(sprintf("$('#%s').val('');", ns("user_affiliation")))

      # Set default user access
      user_accesses <- user_accesses_data()
      if (!is.null(user_accesses) && nrow(user_accesses) > 0) {
        # Default to "Read only" if available, otherwise first one
        read_only_id <- user_accesses$user_access_id[user_accesses$name == "Read only"]
        if (length(read_only_id) > 0) {
          updateSelectInput(session, "user_user_access", selected = read_only_id[1])
        } else {
          updateSelectInput(session, "user_user_access", selected = user_accesses$user_access_id[1])
        }
      }

      # Hide all error messages
      shinyjs::hide("login_error")
      shinyjs::hide("password_error")
      shinyjs::hide("password_confirm_error")
      shinyjs::hide("first_name_error")
      shinyjs::hide("last_name_error")
      shinyjs::hide("user_access_error")
      shinyjs::show("user_modal")
    })

    ### Edit User Modal ----
    observe_event(input$edit_user, {
      if (is.null(input$edit_user)) return()
      if (is.null(users_data())) return()

      # Check permissions
      if (!user_has_permission("users", "edit_user")) return()

      # Find user
      users <- users_data()
      edit_user <- users[users$user_id == input$edit_user, ]

      if (nrow(edit_user) == 0) return()

      edit_user <- edit_user[1, ]

      # Set editing mode
      editing_user_id(edit_user$user_id)
      shinyjs::html("modal_title", as.character(i18n$t("edit_user")))
      shinyjs::show("password_help")

      # Populate form
      updateTextInput(session, "user_login", value = edit_user$login)
      updateTextInput(session, "user_password", value = "")
      updateTextInput(session, "user_password_confirm", value = "")
      updateTextInput(session, "user_first_name", value = edit_user$first_name)
      updateTextInput(session, "user_last_name", value = edit_user$last_name)
      updateSelectInput(session, "user_role", selected = edit_user$role)

      # Set user access
      if (!is.na(edit_user$user_access_id)) {
        updateSelectInput(session, "user_user_access", selected = edit_user$user_access_id)
      }

      # Update textarea using JavaScript
      affiliation_value <- if (!is.na(edit_user$affiliation)) edit_user$affiliation else ""
      shinyjs::runjs(sprintf("$('#%s').val('%s');", ns("user_affiliation"),
                             gsub("'", "\\\\'", affiliation_value)))

      # Reset password field types and icons
      shinyjs::runjs(sprintf("
        $('#%s').attr('type', 'password');
        $('#%s').removeClass('fa-eye-slash').addClass('fa-eye');
        $('#%s').attr('type', 'password');
        $('#%s').removeClass('fa-eye-slash').addClass('fa-eye');
      ", ns("user_password"), ns("password_icon"), ns("user_password_confirm"), ns("password_confirm_icon")))

      # Hide all error messages
      shinyjs::hide("login_error")
      shinyjs::hide("password_error")
      shinyjs::hide("password_confirm_error")
      shinyjs::hide("first_name_error")
      shinyjs::hide("last_name_error")
      shinyjs::hide("user_access_error")
      shinyjs::show("user_modal")
    })

    ### Delete User - Show Confirmation Modal ----
    observe_event(input$delete_user, {
      if (is.null(input$delete_user)) return()

      # Check permissions
      if (!user_has_permission("users", "delete_user")) return()

      # Prevent deleting own account
      user <- current_user()
      if (!is.null(user) && user$user_id == input$delete_user) return()

      # Find user to get name
      users <- users_data()
      user_to_delete <- users[users$user_id == input$delete_user, ]

      if (nrow(user_to_delete) == 0) return()

      user_to_delete <- user_to_delete[1, ]

      # Set deleting user ID and type
      deleting_user_id(input$delete_user)
      delete_type("user")

      # Build user name
      user_name <- paste(user_to_delete$first_name, user_to_delete$last_name)
      if (user_name == " ") user_name <- user_to_delete$login

      # Update confirmation message
      shinyjs::html("delete_confirmation_message",
                    sprintf("Are you sure you want to delete user <strong>%s</strong>?", user_name))

      # Show modal
      shinyjs::show("delete_confirmation_modal")
    })

    ### Save User ----
    observe_event(input$save_user, {
      # Check permissions - need add_user for new users or edit_user for existing
      if (is.null(editing_user_id())) {
        if (!user_has_permission("users", "add_user")) return()
      } else {
        if (!user_has_permission("users", "edit_user")) return()
      }

      # Hide all error messages first
      shinyjs::hide("login_error")
      shinyjs::hide("password_error")
      shinyjs::hide("password_confirm_error")
      shinyjs::hide("first_name_error")
      shinyjs::hide("last_name_error")
      shinyjs::hide("user_access_error")

      has_errors <- FALSE

      # Validate login
      if (is.null(input$user_login) || nchar(input$user_login) == 0) {
        shinyjs::html("login_error", as.character(i18n$t("login_required")))
        shinyjs::show("login_error")
        has_errors <- TRUE
      }

      # Validate first name
      if (is.null(input$user_first_name) || nchar(trimws(input$user_first_name)) == 0) {
        shinyjs::html("first_name_error", as.character(i18n$t("first_name_required")))
        shinyjs::show("first_name_error")
        has_errors <- TRUE
      }

      # Validate last name
      if (is.null(input$user_last_name) || nchar(trimws(input$user_last_name)) == 0) {
        shinyjs::html("last_name_error", as.character(i18n$t("last_name_required")))
        shinyjs::show("last_name_error")
        has_errors <- TRUE
      }

      # Validate user access
      if (is.null(input$user_user_access) || input$user_user_access == "") {
        shinyjs::html("user_access_error", as.character(i18n$t("user_access_required")))
        shinyjs::show("user_access_error")
        has_errors <- TRUE
      }

      # Check if editing or adding
      if (is.null(editing_user_id())) {
        # Adding new user - password required
        if (is.null(input$user_password) || nchar(input$user_password) == 0) {
          shinyjs::html("password_error", as.character(i18n$t("password_required")))
          shinyjs::show("password_error")
          has_errors <- TRUE
        }
      }

      # Validate password confirmation if password is provided
      password_provided <- !is.null(input$user_password) && nchar(input$user_password) > 0
      if (password_provided) {
        password_confirm <- if (is.null(input$user_password_confirm)) "" else input$user_password_confirm
        if (input$user_password != password_confirm) {
          shinyjs::html("password_confirm_error", as.character(i18n$t("passwords_do_not_match")))
          shinyjs::show("password_confirm_error")
          has_errors <- TRUE
        }
      }

      # Stop if there are validation errors
      if (has_errors) return()

      # Check for duplicate login
      users <- users_data()
      login_to_check <- trimws(input$user_login)

      if (is.null(editing_user_id())) {
        # Adding new user - check if login already exists
        if (tolower(login_to_check) %in% tolower(users$login)) {
          shinyjs::html("login_error", as.character(i18n$t("login_exists")))
          shinyjs::show("login_error")
          return()
        }

        # Add user
        result <- add_user(
          login = login_to_check,
          password = input$user_password,
          first_name = input$user_first_name,
          last_name = input$user_last_name,
          role = input$user_role,
          affiliation = input$user_affiliation,
          user_access_id = as.integer(input$user_user_access)
        )

        if (is.null(result)) {
          shinyjs::html("login_error", as.character(i18n$t("login_exists")))
          shinyjs::show("login_error")
          return()
        }

        # Reset form after successful add
        updateTextInput(session, "user_login", value = "")
        updateTextInput(session, "user_password", value = "")
        updateTextInput(session, "user_password_confirm", value = "")
        updateTextInput(session, "user_first_name", value = "")
        updateTextInput(session, "user_last_name", value = "")
        updateSelectInput(session, "user_role", selected = "Data scientist")
        shinyjs::runjs(sprintf("$('#%s').val('');", ns("user_affiliation")))

        # Reset password field types and icons
        shinyjs::runjs(sprintf("
          $('#%s').attr('type', 'password');
          $('#%s').removeClass('fa-eye-slash').addClass('fa-eye');
          $('#%s').attr('type', 'password');
          $('#%s').removeClass('fa-eye-slash').addClass('fa-eye');
        ", ns("user_password"), ns("password_icon"), ns("user_password_confirm"), ns("password_confirm_icon")))
      } else {
        # Editing existing user - check if login already exists for other users
        other_users <- users[users$user_id != editing_user_id(), ]
        if (tolower(login_to_check) %in% tolower(other_users$login)) {
          shinyjs::html("login_error", as.character(i18n$t("login_exists")))
          shinyjs::show("login_error")
          return()
        }

        # Editing existing user
        update_params <- list(
          user_id = editing_user_id(),
          login = login_to_check,
          first_name = input$user_first_name,
          last_name = input$user_last_name,
          role = input$user_role,
          affiliation = input$user_affiliation,
          user_access_id = as.integer(input$user_user_access)
        )

        # Add password if provided
        if (!is.null(input$user_password) && nchar(input$user_password) > 0) {
          update_params$password <- input$user_password
        }

        do.call(update_user, update_params)
      }

      # Reload users
      users <- get_all_users()
      users_data(users)

      # Close modal immediately
      shinyjs::hide("user_modal")
    })

    ### Close Modal on Overlay Click ----
    observe_event(input$close_modal_overlay, {
      # Just close the modal without resetting form fields
      shinyjs::hide("user_modal")
    })

    ## 3) Server - User Accesses Tab ====

    ### Render User Accesses Table ----
    observe_event(user_accesses_data(), {
      user_accesses_table_trigger(user_accesses_table_trigger() + 1)
    })

    observe_event(user_accesses_table_trigger(), {
      if (is.null(user_accesses_data())) return()

      output$user_accesses_table <- renderDT({
        user_accesses <- user_accesses_data()

        # Check permissions for action buttons
        can_edit <- user_has_permission("user_accesses", "edit_user_access")
        can_delete <- user_has_permission("user_accesses", "delete_user_access")

        # Add action buttons (generate for each row based on permissions)
        user_accesses$Actions <- sapply(user_accesses$user_access_id, function(id) {
          actions <- list()

          if (can_edit) {
            actions <- c(actions, list(list(
              label = as.character(i18n$t("edit")),
              icon = "edit",
              type = "warning",
              class = "btn-edit-ua",
              data_attr = list(id = id)
            )))
          }

          if (can_delete) {
            actions <- c(actions, list(list(
              label = as.character(i18n$t("delete")),
              icon = "trash",
              type = "danger",
              class = "btn-delete-ua",
              data_attr = list(id = id)
            )))
          }

          if (length(actions) == 0) return("")
          create_datatable_actions(actions)
        })

        # Select display columns
        display_data <- user_accesses[, c("user_access_id", "name", "description", "Actions")]
        colnames(display_data) <- c(
          "user_access_id",
          as.character(i18n$t("name")),
          as.character(i18n$t("description")),
          as.character(i18n$t("actions"))
        )

        dt <- datatable(
          display_data,
          selection = "single",
          rownames = FALSE,
          escape = FALSE,
          class = "cell-border stripe hover",
          callback = JS(sprintf("
            table.on('click', 'tbody tr', function() {
              var data = table.row(this).data();
              if (data) {
                var userAccessId = data[0];
                Shiny.setInputValue('%s', userAccessId, {priority: 'event'});
              }
            });
          ", ns("select_user_access"))),
          options = list(
            pageLength = 25,
            dom = "tip",
            ordering = TRUE,
            autoWidth = FALSE,
            language = get_datatable_language(),
            columnDefs = list(
              list(visible = FALSE, targets = 0),
              list(width = "150px", targets = 3),
              list(searchable = FALSE, targets = 3),
              list(className = "dt-center", targets = 3)
            )
          )
        )

        # Add button handlers
        dt <- add_button_handlers(
          dt,
          handlers = list(
            list(selector = ".btn-edit-ua", input_id = ns("edit_user_access")),
            list(selector = ".btn-delete-ua", input_id = ns("delete_user_access"))
          )
        )

        dt
      })
    }, ignoreInit = FALSE)

    ### Select User Access - Load Permissions ----
    observe_event(input$select_user_access, {
      if (is.null(input$select_user_access)) return()

      selected_user_access_id(input$select_user_access)

      # Load permissions for this user access
      permissions <- get_user_access_permissions(input$select_user_access)
      selected_user_access_permissions(permissions)

      # Initialize pending permissions as a copy of current permissions
      pending <- permissions
      pending_permissions(pending)

      # Only show the check/uncheck/save buttons if user can edit permissions
      if (user_has_permission("user_accesses", "edit_permissions")) {
        shinyjs::runjs(sprintf("$('#%s').css('display', 'flex');", ns("permissions_buttons")))
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("permissions_buttons")))
      }

      permissions_panel_trigger(permissions_panel_trigger() + 1)
    })

    ### Render Permissions Panel ----
    observe_event(permissions_panel_trigger(), {
      output$permissions_panel <- renderUI({
        user_access_id <- selected_user_access_id()

        if (is.null(user_access_id)) {
          return(
            tags$div(
              style = "display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100%; color: #999;",
              tags$i(class = "fas fa-shield-alt", style = "font-size: 48px; margin-bottom: 15px;"),
              tags$p(i18n$t("select_user_access_to_view_permissions"))
            )
          )
        }

        # Use pending permissions for display
        permissions <- pending_permissions()
        if (is.null(permissions) || nrow(permissions) == 0) {
          return(
            tags$div(
              style = "color: #999; text-align: center; padding: 20px;",
              i18n$t("no_permissions_defined")
            )
          )
        }

        # Get user access name for header
        user_accesses <- user_accesses_data()
        user_access <- user_accesses[user_accesses$user_access_id == user_access_id, ]
        user_access_name <- if (nrow(user_access) > 0) user_access$name[1] else ""

        # Update header
        shinyjs::html("permissions_header", paste0(
          '<i class="fas fa-shield-alt" style="margin-right: 8px; color: #0f60af;"></i>',
          i18n$t("permissions"), " - ", user_access_name
        ))

        # Get permission definitions for display names
        perm_defs <- get_all_permission_definitions()
        categories <- get_permission_categories()

        # Check if user can edit permissions
        can_edit_permissions <- user_has_permission("user_accesses", "edit_permissions")

        # Group permissions by category
        categories_ui <- lapply(unique(categories$category), function(cat) {
          cat_permissions <- permissions[permissions$category == cat, ]
          if (nrow(cat_permissions) == 0) return(NULL)

          cat_display_name <- categories$display_name[categories$category == cat]

          # Create permission toggles for this category
          perm_toggles <- lapply(seq_len(nrow(cat_permissions)), function(i) {
            perm <- cat_permissions[i, ]
            perm_def <- perm_defs[perm_defs$category == perm$category & perm_defs$permission == perm$permission, ]
            perm_description <- if (nrow(perm_def) > 0) perm_def$description[1] else perm$permission

            is_full_access <- perm$access_level == "full_access"

            # Build toggle or read-only indicator based on permissions
            if (can_edit_permissions) {
              toggle_element <- tags$label(
                class = paste0("toggle-switch toggle-small", if (!is_full_access) " toggle-exclude" else ""),
                tags$input(
                  type = "checkbox",
                  checked = if (is_full_access) "checked" else NULL,
                  onclick = sprintf(
                    "Shiny.setInputValue('%s', {user_access_id: %s, category: '%s', permission: '%s', checked: this.checked}, {priority: 'event'})",
                    ns("toggle_permission"),
                    user_access_id,
                    perm$category,
                    perm$permission
                  )
                ),
                tags$span(class = "toggle-slider")
              )
            } else {
              # Read-only indicator
              toggle_element <- tags$span(
                style = paste0(
                  "font-size: 12px; padding: 2px 8px; border-radius: 4px; ",
                  if (is_full_access) "background-color: #d4edda; color: #155724;" else "background-color: #f8d7da; color: #721c24;"
                ),
                if (is_full_access) i18n$t("yes") else i18n$t("no")
              )
            }

            tags$div(
              style = "display: flex; align-items: center; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f0f0f0;",
              tags$span(
                style = "font-size: 13px; color: #333;",
                perm_description
              ),
              toggle_element
            )
          })

          tags$div(
            style = "margin-bottom: 20px;",
            tags$div(
              style = "font-weight: 600; font-size: 14px; color: #0f60af; margin-bottom: 10px; padding-bottom: 5px; border-bottom: 2px solid #e6f3ff;",
              tags$i(class = "fas fa-folder", style = "margin-right: 8px;"),
              cat_display_name
            ),
            tagList(perm_toggles)
          )
        })

        tagList(categories_ui)
      })
    }, ignoreInit = FALSE)

    ### Toggle Permission ----
    observe_event(input$toggle_permission, {
      if (is.null(input$toggle_permission)) return()

      # Check permissions
      if (!user_has_permission("user_accesses", "edit_permissions")) return()

      data <- input$toggle_permission
      new_access_level <- if (data$checked) "full_access" else "read_only"

      # Update pending permissions locally (not in database)
      current_pending <- pending_permissions()
      if (!is.null(current_pending)) {
        idx <- which(current_pending$category == data$category & current_pending$permission == data$permission)
        if (length(idx) > 0) {
          current_pending$access_level[idx] <- new_access_level
          pending_permissions(current_pending)
        }
      }
    })

    ### Check All Permissions ----
    observe_event(input$check_all_permissions, {
      # Check permissions
      if (!user_has_permission("user_accesses", "edit_permissions")) return()

      user_access_id <- selected_user_access_id()
      if (is.null(user_access_id)) return()

      # Update all pending permissions to full_access locally
      current_pending <- pending_permissions()
      if (!is.null(current_pending)) {
        current_pending$access_level <- "full_access"
        pending_permissions(current_pending)
        permissions_panel_trigger(permissions_panel_trigger() + 1)
      }
    })

    ### Uncheck All Permissions ----
    observe_event(input$uncheck_all_permissions, {
      # Check permissions
      if (!user_has_permission("user_accesses", "edit_permissions")) return()

      user_access_id <- selected_user_access_id()
      if (is.null(user_access_id)) return()

      # Update all pending permissions to read_only locally
      current_pending <- pending_permissions()
      if (!is.null(current_pending)) {
        current_pending$access_level <- "read_only"
        pending_permissions(current_pending)
        permissions_panel_trigger(permissions_panel_trigger() + 1)
      }
    })

    ### Save Permissions ----
    observe_event(input$save_permissions, {
      # Check permissions
      if (!user_has_permission("user_accesses", "edit_permissions")) return()

      user_access_id <- selected_user_access_id()
      if (is.null(user_access_id)) return()

      current_pending <- pending_permissions()
      if (is.null(current_pending)) return()

      # Save all pending permissions to database
      for (i in seq_len(nrow(current_pending))) {
        update_user_access_permission(
          user_access_id = user_access_id,
          category = current_pending$category[i],
          permission = current_pending$permission[i],
          access_level = current_pending$access_level[i]
        )
      }

      # Reload permissions from database to confirm save
      permissions <- get_user_access_permissions(user_access_id)
      selected_user_access_permissions(permissions)
      pending_permissions(permissions)

      # Show success notification
      showNotification(
        i18n$t("permissions_saved"),
        type = "message",
        duration = 3
      )
    })

    ### Add User Access Modal ----
    observe_event(input$add_user_access_btn, {
      # Check permissions
      if (!user_has_permission("user_accesses", "add_user_access")) return()

      # Set add mode
      editing_user_access_id(NULL)
      shinyjs::html("user_access_modal_title", as.character(i18n$t("add_user_access")))

      # Reset form fields
      updateTextInput(session, "user_access_name", value = "")
      shinyjs::runjs(sprintf("$('#%s').val('');", ns("user_access_description")))

      # Hide error messages
      shinyjs::hide("user_access_name_error")
      shinyjs::show("user_access_modal")
    })

    ### Edit User Access Modal ----
    observe_event(input$edit_user_access, {
      if (is.null(input$edit_user_access)) return()
      if (is.null(user_accesses_data())) return()

      # Check permissions
      if (!user_has_permission("user_accesses", "edit_user_access")) return()

      # Find user access
      user_accesses <- user_accesses_data()
      edit_ua <- user_accesses[user_accesses$user_access_id == input$edit_user_access, ]

      if (nrow(edit_ua) == 0) return()

      edit_ua <- edit_ua[1, ]

      # Set editing mode
      editing_user_access_id(edit_ua$user_access_id)
      shinyjs::html("user_access_modal_title", as.character(i18n$t("edit_user_access")))

      # Populate form
      updateTextInput(session, "user_access_name", value = edit_ua$name)

      # Update textarea using JavaScript
      description_value <- if (!is.na(edit_ua$description)) edit_ua$description else ""
      shinyjs::runjs(sprintf("$('#%s').val('%s');", ns("user_access_description"),
                             gsub("'", "\\\\'", description_value)))

      # Hide error messages
      shinyjs::hide("user_access_name_error")
      shinyjs::show("user_access_modal")
    })

    ### Delete User Access - Show Confirmation Modal ----
    observe_event(input$delete_user_access, {
      if (is.null(input$delete_user_access)) return()

      # Check permissions
      if (!user_has_permission("user_accesses", "delete_user_access")) return()

      # Find user access to get name
      user_accesses <- user_accesses_data()
      ua_to_delete <- user_accesses[user_accesses$user_access_id == input$delete_user_access, ]

      if (nrow(ua_to_delete) == 0) return()

      ua_to_delete <- ua_to_delete[1, ]

      # Set deleting user access ID and type
      deleting_user_access_id(input$delete_user_access)
      delete_type("user_access")

      # Update confirmation message
      shinyjs::html("delete_confirmation_message",
                    sprintf("Are you sure you want to delete user access <strong>%s</strong>?<br><br><small>Note: You cannot delete a user access that is still assigned to users.</small>", ua_to_delete$name))

      # Show modal
      shinyjs::show("delete_confirmation_modal")
    })

    ### Save User Access ----
    observe_event(input$save_user_access, {
      # Check permissions - need add_user_access for new or edit_user_access for existing
      if (is.null(editing_user_access_id())) {
        if (!user_has_permission("user_accesses", "add_user_access")) return()
      } else {
        if (!user_has_permission("user_accesses", "edit_user_access")) return()
      }

      # Hide error messages
      shinyjs::hide("user_access_name_error")

      has_errors <- FALSE

      # Validate name
      if (is.null(input$user_access_name) || nchar(trimws(input$user_access_name)) == 0) {
        shinyjs::html("user_access_name_error", as.character(i18n$t("name_required")))
        shinyjs::show("user_access_name_error")
        has_errors <- TRUE
      }

      if (has_errors) return()

      name_to_check <- trimws(input$user_access_name)
      user_accesses <- user_accesses_data()

      if (is.null(editing_user_access_id())) {
        # Adding new user access - check if name already exists
        if (tolower(name_to_check) %in% tolower(user_accesses$name)) {
          shinyjs::html("user_access_name_error", as.character(i18n$t("name_exists")))
          shinyjs::show("user_access_name_error")
          return()
        }

        # Add user access
        result <- add_user_access(
          name = name_to_check,
          description = input$user_access_description
        )

        if (is.null(result)) {
          shinyjs::html("user_access_name_error", as.character(i18n$t("name_exists")))
          shinyjs::show("user_access_name_error")
          return()
        }
      } else {
        # Editing existing user access - check if name already exists for other user accesses
        other_uas <- user_accesses[user_accesses$user_access_id != editing_user_access_id(), ]
        if (tolower(name_to_check) %in% tolower(other_uas$name)) {
          shinyjs::html("user_access_name_error", as.character(i18n$t("name_exists")))
          shinyjs::show("user_access_name_error")
          return()
        }

        # Update user access
        update_user_access(
          user_access_id = editing_user_access_id(),
          name = name_to_check,
          description = input$user_access_description
        )
      }

      # Reload user accesses
      user_accesses <- get_all_user_accesses()
      user_accesses_data(user_accesses)

      # Update select input choices for users
      if (nrow(user_accesses) > 0) {
        choices <- stats::setNames(user_accesses$user_access_id, user_accesses$name)
        updateSelectInput(session, "user_user_access", choices = choices)
      }

      # Close modal
      shinyjs::hide("user_access_modal")
    })

    ### Close User Access Modal on Overlay Click ----
    observe_event(input$close_user_access_modal_overlay, {
      shinyjs::hide("user_access_modal")
    })

    ## 4) Server - Delete Confirmation ====

    ### Confirm Delete ----
    observe_event(input$confirm_delete, {
      if (delete_type() == "user") {
        if (is.null(deleting_user_id())) return()

        # Delete user
        delete_user(deleting_user_id())

        # Reload users
        users <- get_all_users()
        users_data(users)

        # Clear deleting state
        deleting_user_id(NULL)
      } else if (delete_type() == "user_access") {
        if (is.null(deleting_user_access_id())) return()

        # Try to delete user access
        result <- delete_user_access(deleting_user_access_id())

        if (!result) {
          # Cannot delete - users are still assigned
          shinyjs::html("delete_confirmation_message",
                        "Cannot delete this user access because users are still assigned to it. Please reassign those users first.")
          return()
        }

        # Reload user accesses
        user_accesses <- get_all_user_accesses()
        user_accesses_data(user_accesses)

        # Update select input choices for users
        if (nrow(user_accesses) > 0) {
          choices <- stats::setNames(user_accesses$user_access_id, user_accesses$name)
          updateSelectInput(session, "user_user_access", choices = choices)
        }

        # Clear selection if deleted
        if (selected_user_access_id() == deleting_user_access_id()) {
          selected_user_access_id(NULL)
          selected_user_access_permissions(NULL)
          permissions_panel_trigger(permissions_panel_trigger() + 1)
        }

        # Clear deleting state
        deleting_user_access_id(NULL)
      }

      delete_type(NULL)

      # Hide modal
      shinyjs::hide("delete_confirmation_modal")
    })

    ### Cancel Delete ----
    observe_event(input$cancel_delete, {
      deleting_user_id(NULL)
      deleting_user_access_id(NULL)
      delete_type(NULL)
      shinyjs::hide("delete_confirmation_modal")
    })
  })
}
