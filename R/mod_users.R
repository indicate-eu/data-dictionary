# MODULE STRUCTURE OVERVIEW ====
#
# This module manages user accounts and permissions in the application
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Header with Add User Button
#      ### Users Table
#   ## UI - Modals
#      ### Modal - Add/Edit User Form
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Editing State
#      ### Data Management
#
#   ## 2) Server - Data Loading & Rendering
#      ### Load Users Data
#      ### Render Users Table
#
#   ## 3) Server - User Actions
#      ### Add User Modal
#      ### Edit User Modal
#      ### Delete User
#      ### Save User
#      ### Cancel/Close Modal

# UI - Main Layout ====

#' Users Management Module
#'
#' @description Module for managing users
#'
#' @param id Namespace id
#' @param i18n Translator object from shiny.i18n
#'
#' @return Shiny module UI
#' @noRd
#'
#' @importFrom shiny NS div actionButton uiOutput textInput passwordInput selectInput
#' @importFrom DT DTOutput
#' @importFrom htmltools tagList tags
mod_users_ui <- function(id, i18n) {
  ns <- NS(id)

  div(
    class = "users-container",
    style = "padding: 20px; height: 100%;",

    ## Header with Add User Button ----
    div(
      style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 20px;",
      actionButton(
        ns("add_user_btn"),
        i18n$t("add_user"),
        class = "btn-success-custom",
        icon = icon("plus")
      )
    ),

    ## Users Table ----
    div(
      style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); height: calc(100% - 50px);",
      DTOutput(ns("users_table"))
    ),

    ## Modal - Add/Edit User Form ----
    div(
      id = ns("user_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("user_modal")),
      div(
        class = "modal-content",
        style = "max-width: 500px;",

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
            style = "margin-bottom: 15px;",
            tags$label(
              tagList(i18n$t("login_label"), " *"),
              style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
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
          style = "margin-bottom: 15px;",
          tags$label(
            tagList(i18n$t("password_label"), " *"),
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
          ),
          div(
            style = "position: relative;",
            passwordInput(
              ns("user_password"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_password")),
              width = "100%"
            ),
            tags$button(
              id = ns("toggle_password"),
              type = "button",
              class = "password-toggle-btn",
              style = "position: absolute; right: 10px; top: 8px; background: none; border: none; cursor: pointer; color: #7f8c8d;",
              tags$i(class = "fas fa-eye", id = ns("password_icon"))
            )
          ),
          div(
            id = ns("password_error"),
            class = "input-error-message"
          ),
          tags$small(
            id = ns("password_help"),
            style = "color: #7f8c8d; font-size: 12px;",
            i18n$t("leave_empty_password")
          )
        ),

        div(
          style = "margin-bottom: 15px;",
          tags$label(
            tagList(i18n$t("first_name"), " *"),
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
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
          style = "margin-bottom: 15px;",
          tags$label(
            tagList(i18n$t("last_name"), " *"),
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
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
          style = "margin-bottom: 15px;",
          tags$label(
            i18n$t("role"),
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
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
          style = "margin-bottom: 20px;",
          tags$label(
            i18n$t("affiliation"),
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
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

    ## Modal - Delete Confirmation ----
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

    ## 1) Server - Reactive Values & State ====
    
    editing_user_id <- reactiveVal(NULL)
    deleting_user_id <- reactiveVal(NULL)
    users_data <- reactiveVal(NULL)

    ## 2) Server - Data Loading & Rendering ====

    ### Load Users Data ----
    observe_event(TRUE, {
      users <- get_all_users()
      users_data(users)
    })

    ### Render Users Table ----
    observe_event(users_data(), {
      if (is.null(users_data())) return()

      output$users_table <- renderDT({
        users <- users_data()

        # Add action buttons (generate for each row)
        users$Actions <- sapply(users$user_id, function(id) {
          create_datatable_actions(list(
            list(
              label = as.character(i18n$t("edit")),
              icon = "edit",
              type = "warning",
              class = "btn-edit",
              data_attr = list(id = id)
            ),
            list(
              label = as.character(i18n$t("delete")),
              icon = "trash",
              type = "danger",
              class = "btn-delete",
              data_attr = list(id = id)
            )
          ))
        })

        # Select display columns
        display_data <- users[, c("login", "first_name", "last_name", "role", "affiliation", "Actions")]
        colnames(display_data) <- c(
          as.character(i18n$t("login_label")),
          as.character(i18n$t("first_name")),
          as.character(i18n$t("last_name")),
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
          options = list(
            pageLength = 25,
            dom = "tp",
            ordering = TRUE,
            autoWidth = FALSE,
            language = get_datatable_language(),
            columnDefs = list(
              list(width = "200px", targets = 5),
              list(searchable = FALSE, targets = 5),
              list(className = "dt-center", targets = 5)
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
    })

    ## 3) Server - User Actions ====

    ### Add User Modal ----
    observe_event(input$add_user_btn, {
      # Check permissions
      if (is.null(current_user())) return()

      user <- current_user()
      if (user$role == "Anonymous") return()

      # Reset form
      editing_user_id(NULL)
      shinyjs::html("modal_title", as.character(i18n$t("add_user")))
      shinyjs::hide("password_help")
      updateTextInput(session, "user_login", value = "")
      updateTextInput(session, "user_password", value = "")
      updateTextInput(session, "user_first_name", value = "")
      updateTextInput(session, "user_last_name", value = "")
      updateSelectInput(session, "user_role", selected = "Data scientist")

      # Clear textarea using JavaScript
      shinyjs::runjs(sprintf("$('#%s').val('');", ns("user_affiliation")))

      # Hide all error messages
      shinyjs::hide("login_error")
      shinyjs::hide("password_error")
      shinyjs::hide("first_name_error")
      shinyjs::hide("last_name_error")
      shinyjs::show("user_modal")
    })

    ### Edit User Modal ----
    observe_event(input$edit_user, {
      if (is.null(input$edit_user)) return()
      if (is.null(users_data())) return()

      # Check permissions
      if (is.null(current_user())) return()

      user <- current_user()
      if (user$role == "Anonymous") return()

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
      updateTextInput(session, "user_first_name", value = edit_user$first_name)
      updateTextInput(session, "user_last_name", value = edit_user$last_name)
      updateSelectInput(session, "user_role", selected = edit_user$role)

      # Update textarea using JavaScript
      affiliation_value <- if (!is.na(edit_user$affiliation)) edit_user$affiliation else ""
      shinyjs::runjs(sprintf("$('#%s').val('%s');", ns("user_affiliation"),
                             gsub("'", "\\\\'", affiliation_value)))

      # Hide all error messages
      shinyjs::hide("login_error")
      shinyjs::hide("password_error")
      shinyjs::hide("first_name_error")
      shinyjs::hide("last_name_error")
      shinyjs::show("user_modal")
    })

    ### Delete User - Show Confirmation Modal ----
    observe_event(input$delete_user, {
      if (is.null(input$delete_user)) return()

      # Check permissions
      if (is.null(current_user())) return()

      user <- current_user()
      if (user$role == "Anonymous") return()

      # Prevent deleting own account
      if (user$user_id == input$delete_user) return()

      # Find user to get name
      users <- users_data()
      user_to_delete <- users[users$user_id == input$delete_user, ]

      if (nrow(user_to_delete) == 0) return()

      user_to_delete <- user_to_delete[1, ]

      # Set deleting user ID
      deleting_user_id(input$delete_user)

      # Build user name
      user_name <- paste(user_to_delete$first_name, user_to_delete$last_name)
      if (user_name == " ") user_name <- user_to_delete$login

      # Update confirmation message
      shinyjs::html("delete_confirmation_message",
                    sprintf("Are you sure you want to delete user <strong>%s</strong>?", user_name))

      # Show modal
      shinyjs::show("delete_confirmation_modal")
    })

    ### Confirm Delete ----
    observe_event(input$confirm_delete, {
      if (is.null(deleting_user_id())) return()

      # Delete user
      delete_user(deleting_user_id())

      # Reload users
      users <- get_all_users()
      users_data(users)

      # Clear deleting state
      deleting_user_id(NULL)

      # Hide modal
      shinyjs::hide("delete_confirmation_modal")
    })

    ### Cancel Delete ----
    observe_event(input$cancel_delete, {
      deleting_user_id(NULL)
      shinyjs::hide("delete_confirmation_modal")
    })

    ### Save User ----
    observe_event(input$save_user, {
      # Hide all error messages first
      shinyjs::hide("login_error")
      shinyjs::hide("password_error")
      shinyjs::hide("first_name_error")
      shinyjs::hide("last_name_error")

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

      # Check if editing or adding
      if (is.null(editing_user_id())) {
        # Adding new user - password required
        if (is.null(input$user_password) || nchar(input$user_password) == 0) {
          shinyjs::html("password_error", as.character(i18n$t("password_required")))
          shinyjs::show("password_error")
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
          affiliation = input$user_affiliation
        )

        if (is.null(result)) {
          shinyjs::html("login_error", as.character(i18n$t("login_exists")))
          shinyjs::show("login_error")
          return()
        }
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
          affiliation = input$user_affiliation
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

    ### Toggle Password Visibility ----
    observe_event(input$toggle_password, {
      # Get current input type
      shinyjs::runjs(sprintf("
        var input = $('#%s');
        var icon = $('#%s');
        if (input.attr('type') === 'password') {
          input.attr('type', 'text');
          icon.removeClass('fa-eye').addClass('fa-eye-slash');
        } else {
          input.attr('type', 'password');
          icon.removeClass('fa-eye-slash').addClass('fa-eye');
        }
      ", ns("user_password"), ns("password_icon")))
    })
  })
}
