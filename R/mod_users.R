# MODULE STRUCTURE OVERVIEW ====
#
# This module manages user accounts and access levels
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Users Tab - Manage user accounts
#         #### Header with Add User Button
#         #### Users Table
#      ### User Accesses Tab - Manage access levels
#         #### Header with Add User Access Button
#         #### User Accesses Table
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
#      ### Render User Accesses Table
#      ### Add/Edit/Delete User Access Actions
#      ### Save User Access
#
#   ## 4) Server - Delete Confirmation
#      ### Confirm Delete
#      ### Cancel Delete

# UI SECTION ====

#' Users Module - UI
#'
#' @param id Module ID
#' @param i18n Translator object
#'
#' @return Shiny UI elements
#' @noRd
mod_users_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",

        # Main content with tabs and layout-panel
        create_page_layout(
          "full",
          create_panel(
            title = NULL,
            content = tagList(
              # Tabs header with action buttons on the right
              tags$div(
                class = "tabs-with-actions",

                # Tabs wrapper
                tags$div(
                  class = "tabs-wrapper",
                  tabsetPanel(
                    id = ns("users_tabs"),

                    # Users Tab ----
                    tabPanel(
                      i18n$t("users"),
                      value = "users",
                      icon = icon("users"),
                      tags$div(
                        class = "tab-content-panel",
                        tags$div(
                          class = "panel-table-container",
                          DT::DTOutput(ns("users_table"))
                        )
                      )
                    ),

                    # User Accesses Tab ----
                    tabPanel(
                      i18n$t("user_accesses"),
                      value = "user_accesses",
                      icon = icon("key"),
                      tags$div(
                        class = "tab-content-panel",
                        tags$div(
                          class = "panel-table-container",
                          DT::DTOutput(ns("user_accesses_table"))
                        )
                      )
                    )
                  )
                ),

                # Action buttons (positioned on the right of tabs)
                tags$div(
                  class = "tabs-actions",
                  # Add User button (visible when Users tab active)
                  actionButton(
                    ns("add_user_btn"),
                    i18n$t("add_user"),
                    class = "btn-success-custom tabs-action-btn",
                    icon = icon("plus")
                  ),
                  # Add User Access button (hidden by default)
                  shinyjs::hidden(
                    actionButton(
                      ns("add_user_access_btn"),
                      i18n$t("add_user_access"),
                      class = "btn-success-custom tabs-action-btn",
                      icon = icon("plus")
                    )
                  )
                )
              )
            )
          )
        )
      )
    ),

    # Modal - Add/Edit User Form ----
    tags$div(
      id = ns("user_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) { $('#%s').hide(); }", ns("user_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 600px; max-height: 90vh; display: flex; flex-direction: column;",

        # Modal header
        tags$div(
          class = "modal-header",
          tags$h3(id = ns("user_modal_title"), i18n$t("add_user")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("user_modal")),
            HTML("&times;")
          )
        ),

        # Modal body
        tags$div(
          class = "modal-body",
          style = "overflow-y: auto; flex: 1; padding: 20px;",

          # Login field
          tags$div(
            class = "mb-15",
            tags$label(tagList(i18n$t("login_label"), " *"), class = "form-label"),
            textInput(ns("user_login"), label = NULL, placeholder = as.character(i18n$t("enter_login")), width = "100%"),
            tags$div(id = ns("login_error"), class = "input-error-message")
          ),

          # Password fields (side by side)
          tags$div(
            class = "mb-15",
            style = "display: flex; gap: 15px;",
            tags$div(
              style = "flex: 1;",
              tags$label(tagList(i18n$t("password_label"), " *"), class = "form-label"),
              passwordInput(ns("user_password"), label = NULL, placeholder = as.character(i18n$t("enter_password")), width = "100%"),
              tags$div(id = ns("password_error"), class = "input-error-message")
            ),
            tags$div(
              style = "flex: 1;",
              tags$label(tagList(i18n$t("confirm_password"), " *"), class = "form-label"),
              passwordInput(ns("user_password_confirm"), label = NULL, placeholder = as.character(i18n$t("confirm_password")), width = "100%"),
              tags$div(id = ns("password_confirm_error"), class = "input-error-message")
            )
          ),

          # Password help text (shown only when editing)
          tags$small(
            id = ns("password_help"),
            style = "color: #7f8c8d; font-size: 12px; display: none; margin-bottom: 15px;",
            i18n$t("leave_empty_password")
          ),

          # First Name and Last Name (side by side)
          tags$div(
            class = "mb-15",
            style = "display: flex; gap: 15px;",
            tags$div(
              style = "flex: 1;",
              tags$label(tagList(i18n$t("first_name"), " *"), class = "form-label"),
              textInput(ns("user_first_name"), label = NULL, placeholder = as.character(i18n$t("enter_first_name")), width = "100%"),
              tags$div(id = ns("first_name_error"), class = "input-error-message")
            ),
            tags$div(
              style = "flex: 1;",
              tags$label(tagList(i18n$t("last_name"), " *"), class = "form-label"),
              textInput(ns("user_last_name"), label = NULL, placeholder = as.character(i18n$t("enter_last_name")), width = "100%"),
              tags$div(id = ns("last_name_error"), class = "input-error-message")
            )
          ),

          # Role and User Access (side by side)
          tags$div(
            class = "mb-15",
            style = "display: flex; gap: 15px;",
            tags$div(
              style = "flex: 1;",
              tags$label(i18n$t("role"), class = "form-label"),
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
            tags$div(
              style = "flex: 1;",
              tags$label(tagList(i18n$t("user_access"), " *"), class = "form-label"),
              selectInput(ns("user_user_access"), label = NULL, choices = c(), width = "100%"),
              tags$div(id = ns("user_access_error"), class = "input-error-message")
            )
          ),

          # Affiliation
          tags$div(
            class = "mb-15",
            tags$label(i18n$t("affiliation"), class = "form-label"),
            tags$textarea(
              id = ns("user_affiliation"),
              placeholder = as.character(i18n$t("enter_affiliation")),
              style = "width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px; font-family: inherit; font-size: 14px; resize: vertical; min-height: 60px;"
            )
          )
        ),

        # Modal footer
        tags$div(
          class = "modal-footer",
          style = "display: flex; gap: 10px; justify-content: flex-end; padding: 15px 20px; border-top: 1px solid #dee2e6;",
          tags$button(
            class = "btn btn-secondary-custom",
            onclick = sprintf("$('#%s').hide();", ns("user_modal")),
            tags$i(class = "fas fa-times"), " ", i18n$t("cancel")
          ),
          actionButton(ns("save_user"), i18n$t("save"), class = "btn-primary-custom", icon = icon("save"))
        )
      )
    ),

    # Modal - Add/Edit User Access Form ----
    tags$div(
      id = ns("user_access_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) { $('#%s').hide(); }", ns("user_access_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 500px;",

        # Modal header
        tags$div(
          class = "modal-header",
          tags$h3(id = ns("user_access_modal_title"), i18n$t("add_user_access")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("user_access_modal")),
            HTML("&times;")
          )
        ),

        # Modal body
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",

          # Name field
          tags$div(
            class = "mb-15",
            tags$label(tagList(i18n$t("name"), " *"), class = "form-label"),
            textInput(ns("user_access_name"), label = NULL, placeholder = as.character(i18n$t("enter_name")), width = "100%"),
            tags$div(id = ns("user_access_name_error"), class = "input-error-message")
          ),

          # Description field
          tags$div(
            class = "mb-15",
            tags$label(i18n$t("description"), class = "form-label"),
            tags$textarea(
              id = ns("user_access_description"),
              placeholder = as.character(i18n$t("enter_description")),
              style = "width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px; font-family: inherit; font-size: 14px; resize: vertical; min-height: 60px;"
            )
          )
        ),

        # Modal footer
        tags$div(
          class = "modal-footer",
          style = "display: flex; gap: 10px; justify-content: flex-end; padding: 15px 20px; border-top: 1px solid #dee2e6;",
          tags$button(
            class = "btn btn-secondary-custom",
            onclick = sprintf("$('#%s').hide();", ns("user_access_modal")),
            tags$i(class = "fas fa-times"), " ", i18n$t("cancel")
          ),
          actionButton(ns("save_user_access"), i18n$t("save"), class = "btn-primary-custom", icon = icon("save"))
        )
      )
    ),

    # Modal - Delete Confirmation ----
    tags$div(
      id = ns("delete_confirmation_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) { $('#%s').hide(); }", ns("delete_confirmation_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 500px;",

        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("confirm_deletion")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("delete_confirmation_modal")),
            HTML("&times;")
          )
        ),

        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$p(id = ns("delete_confirmation_message"), style = "margin-bottom: 20px; font-size: 14px;")
        ),

        tags$div(
          class = "modal-footer",
          style = "display: flex; gap: 10px; justify-content: flex-end; padding: 15px 20px; border-top: 1px solid #dee2e6;",
          actionButton(ns("cancel_delete"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
          actionButton(ns("confirm_delete"), i18n$t("delete"), class = "btn-danger-custom", icon = icon("trash"))
        )
      )
    )
  )
}

# SERVER SECTION ====

#' Users Module - Server
#'
#' @param id Module ID
#' @param i18n Translator object
#' @param current_user Reactive: Current logged-in user
#'
#' @noRd
mod_users_server <- function(id, i18n, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ## 1) Server - Reactive Values & State ====

    # Users state
    editing_user_id <- reactiveVal(NULL)
    deleting_user_id <- reactiveVal(NULL)
    users_data <- reactiveVal(NULL)

    # User Accesses state
    editing_user_access_id <- reactiveVal(NULL)
    deleting_user_access_id <- reactiveVal(NULL)
    user_accesses_data <- reactiveVal(NULL)

    # Delete type: "user" or "user_access"
    delete_type <- reactiveVal(NULL)

    # Triggers
    users_table_trigger <- reactiveVal(0)
    user_accesses_table_trigger <- reactiveVal(0)

    ### Tab Change Handler ----
    observe_event(input$users_tabs, {
      if (input$users_tabs == "users") {
        shinyjs::show("add_user_btn")
        shinyjs::hide("add_user_access_btn")
      } else if (input$users_tabs == "user_accesses") {
        shinyjs::hide("add_user_btn")
        shinyjs::show("add_user_access_btn")
      }
    }, ignoreInit = TRUE)

    ## 2) Server - Users Tab ====

    ### Load Users Data ----
    observe_event(TRUE, {
      users <- get_all_users()
      users_data(users)

      user_accesses <- get_all_user_accesses()
      user_accesses_data(user_accesses)

      # Update select input choices
      if (nrow(user_accesses) > 0) {
        choices <- stats::setNames(user_accesses$user_access_id, user_accesses$name)
        updateSelectInput(session, "user_user_access", choices = choices)
      }
    }, ignoreInit = FALSE)

    ### Render Users Table ----
    observe_event(users_data(), {
      users_table_trigger(users_table_trigger() + 1)
    }, ignoreNULL = FALSE)

    observe_event(users_table_trigger(), {
      output$users_table <- DT::renderDT({
        users <- users_data()
        if (is.null(users) || nrow(users) == 0) {
          return(create_empty_datatable(as.character(i18n$t("no_users_found"))))
        }

        current_user_id <- if (!is.null(current_user) && is.function(current_user)) {
          cu <- current_user()
          if (!is.null(cu)) cu$user_id else NULL
        } else NULL

        # Add action buttons
        users$Actions <- sapply(users$user_id, function(id) {
          actions <- list(
            list(label = as.character(i18n$t("edit")), icon = "edit", type = "warning", class = "btn-edit", data_attr = list(id = id))
          )

          # Only show delete button if not the current user
          if (is.null(current_user_id) || id != current_user_id) {
            actions <- c(actions, list(list(
              label = as.character(i18n$t("delete")), icon = "trash", type = "danger", class = "btn-delete", data_attr = list(id = id)
            )))
          }

          create_datatable_actions(actions)
        })

        # Select display columns
        display_data <- users[, c("user_id", "login", "first_name", "last_name", "user_access_name", "role", "affiliation", "Actions")]
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

        dt <- create_standard_datatable(
          display_data,
          selection = "none",
          filter = "top",
          escape = FALSE,
          col_defs = list(
            list(visible = FALSE, targets = 0),
            list(width = "180px", targets = 7),
            list(searchable = FALSE, targets = 7),
            list(className = "dt-center", targets = 7)
          )
        )

        add_button_handlers(dt, handlers = list(
          list(selector = ".btn-edit", input_id = ns("edit_user")),
          list(selector = ".btn-delete", input_id = ns("delete_user"))
        ))
      })
    }, ignoreInit = FALSE)

    ### Add User Modal ----
    observe_event(input$add_user_btn, {
      editing_user_id(NULL)
      shinyjs::html("user_modal_title", as.character(i18n$t("add_user")))
      shinyjs::hide("password_help")

      # Reset form fields
      updateTextInput(session, "user_login", value = "")
      updateTextInput(session, "user_password", value = "")
      updateTextInput(session, "user_password_confirm", value = "")
      updateTextInput(session, "user_first_name", value = "")
      updateTextInput(session, "user_last_name", value = "")
      updateSelectInput(session, "user_role", selected = "Data scientist")
      shinyjs::runjs(sprintf("$('#%s').val('');", ns("user_affiliation")))

      # Set default user access to "Read only" if available
      user_accesses <- user_accesses_data()
      if (!is.null(user_accesses) && nrow(user_accesses) > 0) {
        read_only_id <- user_accesses$user_access_id[user_accesses$name == "Read only"]
        if (length(read_only_id) > 0) {
          updateSelectInput(session, "user_user_access", selected = read_only_id[1])
        } else {
          updateSelectInput(session, "user_user_access", selected = user_accesses$user_access_id[1])
        }
      }

      # Hide error messages
      shinyjs::hide("login_error")
      shinyjs::hide("password_error")
      shinyjs::hide("password_confirm_error")
      shinyjs::hide("first_name_error")
      shinyjs::hide("last_name_error")
      shinyjs::hide("user_access_error")

      shinyjs::show("user_modal")
    }, ignoreInit = TRUE)

    ### Edit User Modal ----
    observe_event(input$edit_user, {
      if (is.null(input$edit_user)) return()

      users <- users_data()
      if (is.null(users)) return()

      edit_user <- users[users$user_id == input$edit_user, ]
      if (nrow(edit_user) == 0) return()

      edit_user <- edit_user[1, ]

      editing_user_id(edit_user$user_id)
      shinyjs::html("user_modal_title", as.character(i18n$t("edit_user")))
      shinyjs::show("password_help")

      # Populate form
      updateTextInput(session, "user_login", value = edit_user$login)
      updateTextInput(session, "user_password", value = "")
      updateTextInput(session, "user_password_confirm", value = "")
      updateTextInput(session, "user_first_name", value = edit_user$first_name)
      updateTextInput(session, "user_last_name", value = edit_user$last_name)
      updateSelectInput(session, "user_role", selected = edit_user$role)

      if (!is.na(edit_user$user_access_id)) {
        updateSelectInput(session, "user_user_access", selected = edit_user$user_access_id)
      }

      affiliation_value <- if (!is.na(edit_user$affiliation)) edit_user$affiliation else ""
      shinyjs::runjs(sprintf("$('#%s').val('%s');", ns("user_affiliation"), gsub("'", "\\\\'", affiliation_value)))

      # Hide error messages
      shinyjs::hide("login_error")
      shinyjs::hide("password_error")
      shinyjs::hide("password_confirm_error")
      shinyjs::hide("first_name_error")
      shinyjs::hide("last_name_error")
      shinyjs::hide("user_access_error")

      shinyjs::show("user_modal")
    }, ignoreInit = TRUE)

    ### Delete User - Show Confirmation Modal ----
    observe_event(input$delete_user, {
      if (is.null(input$delete_user)) return()

      # Prevent deleting own account
      current_user_id <- if (!is.null(current_user) && is.function(current_user)) {
        cu <- current_user()
        if (!is.null(cu)) cu$user_id else NULL
      } else NULL

      if (!is.null(current_user_id) && current_user_id == input$delete_user) return()

      users <- users_data()
      user_to_delete <- users[users$user_id == input$delete_user, ]
      if (nrow(user_to_delete) == 0) return()

      user_to_delete <- user_to_delete[1, ]

      deleting_user_id(input$delete_user)
      delete_type("user")

      user_name <- paste(user_to_delete$first_name, user_to_delete$last_name)
      if (trimws(user_name) == "") user_name <- user_to_delete$login

      shinyjs::html("delete_confirmation_message",
                    sprintf("%s <strong>%s</strong>?", as.character(i18n$t("confirm_delete_user")), user_name))

      shinyjs::show("delete_confirmation_modal")
    }, ignoreInit = TRUE)

    ### Save User ----
    observe_event(input$save_user, {
      # Hide error messages
      shinyjs::hide("login_error")
      shinyjs::hide("password_error")
      shinyjs::hide("password_confirm_error")
      shinyjs::hide("first_name_error")
      shinyjs::hide("last_name_error")
      shinyjs::hide("user_access_error")

      has_errors <- FALSE

      # Validate login
      if (is.null(input$user_login) || nchar(trimws(input$user_login)) == 0) {
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

      # Password validation
      if (is.null(editing_user_id())) {
        # Adding new user - password required
        if (is.null(input$user_password) || nchar(input$user_password) == 0) {
          shinyjs::html("password_error", as.character(i18n$t("password_required")))
          shinyjs::show("password_error")
          has_errors <- TRUE
        }
      }

      # Validate password confirmation
      password_provided <- !is.null(input$user_password) && nchar(input$user_password) > 0
      if (password_provided) {
        password_confirm <- if (is.null(input$user_password_confirm)) "" else input$user_password_confirm
        if (input$user_password != password_confirm) {
          shinyjs::html("password_confirm_error", as.character(i18n$t("passwords_do_not_match")))
          shinyjs::show("password_confirm_error")
          has_errors <- TRUE
        }
      }

      if (has_errors) return()

      # Check for duplicate login
      users <- users_data()
      login_to_check <- trimws(input$user_login)

      if (is.null(editing_user_id())) {
        # Adding new user
        if (tolower(login_to_check) %in% tolower(users$login)) {
          shinyjs::html("login_error", as.character(i18n$t("login_exists")))
          shinyjs::show("login_error")
          return()
        }

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
      } else {
        # Editing existing user
        other_users <- users[users$user_id != editing_user_id(), ]
        if (tolower(login_to_check) %in% tolower(other_users$login)) {
          shinyjs::html("login_error", as.character(i18n$t("login_exists")))
          shinyjs::show("login_error")
          return()
        }

        update_params <- list(
          user_id = editing_user_id(),
          login = login_to_check,
          first_name = input$user_first_name,
          last_name = input$user_last_name,
          role = input$user_role,
          affiliation = input$user_affiliation,
          user_access_id = as.integer(input$user_user_access)
        )

        if (!is.null(input$user_password) && nchar(input$user_password) > 0) {
          update_params$password <- input$user_password
        }

        do.call(update_user, update_params)
      }

      # Reload users
      users <- get_all_users()
      users_data(users)

      shinyjs::hide("user_modal")
    }, ignoreInit = TRUE)

    ## 3) Server - User Accesses Tab ====

    ### Render User Accesses Table ----
    observe_event(user_accesses_data(), {
      user_accesses_table_trigger(user_accesses_table_trigger() + 1)
    }, ignoreNULL = FALSE)

    observe_event(user_accesses_table_trigger(), {
      output$user_accesses_table <- DT::renderDT({
        user_accesses <- user_accesses_data()
        if (is.null(user_accesses) || nrow(user_accesses) == 0) {
          return(create_empty_datatable(as.character(i18n$t("no_user_accesses_found"))))
        }

        # Add action buttons
        user_accesses$Actions <- sapply(user_accesses$user_access_id, function(id) {
          create_datatable_actions(list(
            list(label = as.character(i18n$t("edit")), icon = "edit", type = "warning", class = "btn-edit-ua", data_attr = list(id = id)),
            list(label = as.character(i18n$t("delete")), icon = "trash", type = "danger", class = "btn-delete-ua", data_attr = list(id = id))
          ))
        })

        # Select display columns
        display_data <- user_accesses[, c("user_access_id", "name", "description", "Actions")]
        colnames(display_data) <- c(
          "user_access_id",
          as.character(i18n$t("name")),
          as.character(i18n$t("description")),
          as.character(i18n$t("actions"))
        )

        dt <- create_standard_datatable(
          display_data,
          selection = "none",
          filter = "none",
          escape = FALSE,
          col_defs = list(
            list(visible = FALSE, targets = 0),
            list(width = "150px", targets = 3),
            list(searchable = FALSE, targets = 3),
            list(className = "dt-center", targets = 3)
          )
        )

        add_button_handlers(dt, handlers = list(
          list(selector = ".btn-edit-ua", input_id = ns("edit_user_access")),
          list(selector = ".btn-delete-ua", input_id = ns("delete_user_access"))
        ))
      })
    }, ignoreInit = FALSE)

    ### Add User Access Modal ----
    observe_event(input$add_user_access_btn, {
      editing_user_access_id(NULL)
      shinyjs::html("user_access_modal_title", as.character(i18n$t("add_user_access")))

      # Reset form fields
      updateTextInput(session, "user_access_name", value = "")
      shinyjs::runjs(sprintf("$('#%s').val('');", ns("user_access_description")))

      shinyjs::hide("user_access_name_error")
      shinyjs::show("user_access_modal")
    }, ignoreInit = TRUE)

    ### Edit User Access Modal ----
    observe_event(input$edit_user_access, {
      if (is.null(input$edit_user_access)) return()

      user_accesses <- user_accesses_data()
      if (is.null(user_accesses)) return()

      edit_ua <- user_accesses[user_accesses$user_access_id == input$edit_user_access, ]
      if (nrow(edit_ua) == 0) return()

      edit_ua <- edit_ua[1, ]

      editing_user_access_id(edit_ua$user_access_id)
      shinyjs::html("user_access_modal_title", as.character(i18n$t("edit_user_access")))

      # Populate form
      updateTextInput(session, "user_access_name", value = edit_ua$name)

      description_value <- if (!is.na(edit_ua$description)) edit_ua$description else ""
      shinyjs::runjs(sprintf("$('#%s').val('%s');", ns("user_access_description"), gsub("'", "\\\\'", description_value)))

      shinyjs::hide("user_access_name_error")
      shinyjs::show("user_access_modal")
    }, ignoreInit = TRUE)

    ### Delete User Access - Show Confirmation Modal ----
    observe_event(input$delete_user_access, {
      if (is.null(input$delete_user_access)) return()

      user_accesses <- user_accesses_data()
      ua_to_delete <- user_accesses[user_accesses$user_access_id == input$delete_user_access, ]
      if (nrow(ua_to_delete) == 0) return()

      ua_to_delete <- ua_to_delete[1, ]

      deleting_user_access_id(input$delete_user_access)
      delete_type("user_access")

      shinyjs::html("delete_confirmation_message",
                    sprintf("%s <strong>%s</strong>?<br><br><small>%s</small>",
                            as.character(i18n$t("confirm_delete_user_access")),
                            ua_to_delete$name,
                            as.character(i18n$t("cannot_delete_assigned_user_access"))))

      shinyjs::show("delete_confirmation_modal")
    }, ignoreInit = TRUE)

    ### Save User Access ----
    observe_event(input$save_user_access, {
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
        # Adding new user access
        if (tolower(name_to_check) %in% tolower(user_accesses$name)) {
          shinyjs::html("user_access_name_error", as.character(i18n$t("name_exists")))
          shinyjs::show("user_access_name_error")
          return()
        }

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
        # Editing existing user access
        other_uas <- user_accesses[user_accesses$user_access_id != editing_user_access_id(), ]
        if (tolower(name_to_check) %in% tolower(other_uas$name)) {
          shinyjs::html("user_access_name_error", as.character(i18n$t("name_exists")))
          shinyjs::show("user_access_name_error")
          return()
        }

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

      shinyjs::hide("user_access_modal")
    }, ignoreInit = TRUE)

    ## 4) Server - Delete Confirmation ====

    ### Confirm Delete ----
    observe_event(input$confirm_delete, {
      if (delete_type() == "user") {
        if (is.null(deleting_user_id())) return()

        delete_user(deleting_user_id())

        users <- get_all_users()
        users_data(users)

        deleting_user_id(NULL)
      } else if (delete_type() == "user_access") {
        if (is.null(deleting_user_access_id())) return()

        result <- delete_user_access(deleting_user_access_id())

        if (!result) {
          shinyjs::html("delete_confirmation_message", as.character(i18n$t("cannot_delete_users_assigned")))
          return()
        }

        user_accesses <- get_all_user_accesses()
        user_accesses_data(user_accesses)

        if (nrow(user_accesses) > 0) {
          choices <- stats::setNames(user_accesses$user_access_id, user_accesses$name)
          updateSelectInput(session, "user_user_access", choices = choices)
        }

        deleting_user_access_id(NULL)
      }

      delete_type(NULL)
      shinyjs::hide("delete_confirmation_modal")
    }, ignoreInit = TRUE)

    ### Cancel Delete ----
    observe_event(input$cancel_delete, {
      deleting_user_id(NULL)
      deleting_user_access_id(NULL)
      delete_type(NULL)
      shinyjs::hide("delete_confirmation_modal")
    }, ignoreInit = TRUE)
  })
}
