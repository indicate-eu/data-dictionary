#' Users Management Module
#'
#' @description Module for managing users
#'
#' @param id Namespace id
#'
#' @return Shiny module UI
#' @noRd
#'
#' @importFrom shiny NS div actionButton uiOutput textInput passwordInput selectInput
#' @importFrom DT DTOutput
#' @importFrom htmltools tagList tags
mod_users_ui <- function(id) {
  ns <- NS(id)

  div(
    class = "users-container",
    style = "padding: 20px; height: 100%; overflow-y: auto;",

    # Header with Add User button only
    div(
      style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 20px;",
      actionButton(
        ns("add_user_btn"),
        label = tagList(tags$i(class = "fas fa-plus"), " Add User"),
        class = "btn-primary",
        style = "background: #0f60af; color: white; border: none; padding: 10px 20px; border-radius: 4px; font-size: 14px; cursor: pointer;"
      )
    ),

    # Users table
    div(
      style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
      DTOutput(ns("users_table"))
    ),

    # Add/Edit User Modal (hidden by default)
    div(
      id = ns("user_modal"),
      class = "modal-overlay",
      style = "display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 9999; align-items: center; justify-content: center;",
      div(
        class = "modal-content",
        style = "background: white; padding: 30px; border-radius: 8px; width: 90%; max-width: 500px; max-height: 90vh; overflow-y: auto;",

        # Modal header
        div(
          style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
          tags$h3(
            id = ns("modal_title"),
            "Add User",
            style = "margin: 0; color: #2c3e50;"
          ),
          tags$button(
            id = ns("close_modal"),
            class = "close-button",
            style = "background: none; border: none; font-size: 24px; cursor: pointer; color: #7f8c8d;",
            "×"
          )
        ),

        # Error message
        div(
          id = ns("user_error"),
          style = "display: none; background: #fee; border: 1px solid #fcc; color: #c33; padding: 10px; border-radius: 4px; margin-bottom: 15px; font-size: 14px;"
        ),

        # Success message
        div(
          id = ns("user_success"),
          style = "display: none; background: #efe; border: 1px solid #cfc; color: #3c3; padding: 10px; border-radius: 4px; margin-bottom: 15px; font-size: 14px;"
        ),

        # Form fields
        div(
          style = "margin-bottom: 15px;",
          tags$label(
            "Login *",
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
          ),
          textInput(
            ns("user_login"),
            label = NULL,
            placeholder = "Enter login",
            width = "100%"
          )
        ),

        div(
          style = "margin-bottom: 15px;",
          tags$label(
            "Password *",
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
          ),
          passwordInput(
            ns("user_password"),
            label = NULL,
            placeholder = "Enter password",
            width = "100%"
          ),
          tags$small(
            id = ns("password_help"),
            style = "color: #7f8c8d; font-size: 12px;",
            "Leave empty to keep current password"
          )
        ),

        div(
          style = "margin-bottom: 15px;",
          tags$label(
            "First Name",
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
          ),
          textInput(
            ns("user_first_name"),
            label = NULL,
            placeholder = "Enter first name",
            width = "100%"
          )
        ),

        div(
          style = "margin-bottom: 15px;",
          tags$label(
            "Last Name",
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
          ),
          textInput(
            ns("user_last_name"),
            label = NULL,
            placeholder = "Enter last name",
            width = "100%"
          )
        ),

        div(
          style = "margin-bottom: 15px;",
          tags$label(
            "Role",
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
          ),
          selectInput(
            ns("user_role"),
            label = NULL,
            choices = c(
              "Administrator" = "Administrator",
              "Data Scientist" = "Data Scientist",
              "Clinical Data Manager" = "Clinical Data Manager",
              "Health Data Engineer" = "Health Data Engineer",
              "Researcher" = "Researcher",
              "Clinician" = "Clinician"
            ),
            width = "100%"
          )
        ),

        div(
          style = "margin-bottom: 20px;",
          tags$label(
            "Affiliation",
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
          ),
          textInput(
            ns("user_affiliation"),
            label = NULL,
            placeholder = "Enter institution or organization",
            width = "100%"
          )
        ),

        # Modal footer
        div(
          style = "display: flex; gap: 10px; justify-content: flex-end;",
          actionButton(
            ns("cancel_user"),
            "Cancel",
            style = "background: #6c757d; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer;"
          ),
          actionButton(
            ns("save_user"),
            "Save",
            style = "background: #0f60af; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer;"
          )
        )
      )
    )
  )
}

#' Users Management Module Server
#'
#' @description Server logic for user management
#'
#' @param id Namespace id
#' @param current_user Reactive containing current user data
#'
#' @return NULL
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent req renderUI updateTextInput updateSelectInput
#' @importFrom DT renderDT datatable formatStyle styleEqual
mod_users_server <- function(id, current_user) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Track editing state
    editing_user_id <- reactiveVal(NULL)

    # Reactive to load users
    users_data <- reactiveVal(NULL)

    # Load users on start
    observe({
      users <- get_all_users()
      users_data(users)
    })

    # Render users table
    output$users_table <- renderDT({
      req(users_data())

      users <- users_data()

      # Add action buttons with correct namespacing
      users$Actions <- sprintf(
        '<button class="btn-edit" data-user-id="%d"><i class="fas fa-edit"></i></button>
         <button class="btn-delete" data-user-id="%d"><i class="fas fa-trash"></i></button>',
        users$user_id,
        users$user_id
      )

      # Format active status
      users$Status <- ifelse(users$is_active == 1, "Active", "Inactive")

      # Select display columns
      display_data <- users[, c("login", "first_name", "last_name", "role", "affiliation", "Status", "Actions")]
      colnames(display_data) <- c("Login", "First Name", "Last Name", "Role", "Affiliation", "Status", "Actions")

      datatable(
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
          columnDefs = list(
            list(width = "120px", targets = 6),
            list(searchable = FALSE, targets = 6)
          )
        )
      ) %>%
        formatStyle(
          "Status",
          backgroundColor = styleEqual(
            c("Active", "Inactive"),
            c("#d4edda", "#f8d7da")
          ),
          color = styleEqual(
            c("Active", "Inactive"),
            c("#155724", "#721c24")
          )
        )
    })

    # Show add user modal
    observeEvent(input$add_user_btn, {
      # Check permissions
      req(current_user())
      user <- current_user()

      if (user$role == "Anonymous") {
        shinyjs::html("user_error", "You must be logged in to add users.")
        shinyjs::show("user_error")
        return()
      }

      # Reset form
      editing_user_id(NULL)
      shinyjs::html("modal_title", "Add User")
      shinyjs::hide("password_help")
      updateTextInput(session, "user_login", value = "")
      updateTextInput(session, "user_password", value = "")
      updateTextInput(session, "user_first_name", value = "")
      updateTextInput(session, "user_last_name", value = "")
      updateSelectInput(session, "user_role", selected = "Data Scientist")
      updateTextInput(session, "user_affiliation", value = "")

      shinyjs::hide("user_error")
      shinyjs::hide("user_success")
      shinyjs::show("user_modal")
    })

    # Show edit user modal
    observeEvent(input$edit_user, {
      req(input$edit_user, users_data())

      # Check permissions
      req(current_user())
      user <- current_user()

      if (user$role == "Anonymous") {
        shinyjs::html("user_error", "You must be logged in to edit users.")
        shinyjs::show("user_error")
        return()
      }

      # Find user
      users <- users_data()
      edit_user <- users[users$user_id == input$edit_user, ]

      if (nrow(edit_user) == 0) {
        return()
      }

      edit_user <- edit_user[1, ]

      # Set editing mode
      editing_user_id(edit_user$user_id)
      shinyjs::html("modal_title", "Edit User")
      shinyjs::show("password_help")

      # Populate form
      updateTextInput(session, "user_login", value = edit_user$login)
      updateTextInput(session, "user_password", value = "")
      updateTextInput(session, "user_first_name", value = edit_user$first_name)
      updateTextInput(session, "user_last_name", value = edit_user$last_name)
      updateSelectInput(session, "user_role", selected = edit_user$role)
      updateTextInput(session, "user_affiliation", value = edit_user$affiliation)

      shinyjs::hide("user_error")
      shinyjs::hide("user_success")
      shinyjs::show("user_modal")
    })

    # Delete user
    observeEvent(input$delete_user, {
      req(input$delete_user)

      # Check permissions
      req(current_user())
      user <- current_user()

      if (user$role == "Anonymous") {
        return()
      }

      # Prevent deleting own account
      if (user$user_id == input$delete_user) {
        return()
      }

      # Show confirmation and delete
      if (input$delete_user > 0) {
        delete_user(input$delete_user)

        # Reload users
        users <- get_all_users()
        users_data(users)
      }
    })

    # Save user
    observeEvent(input$save_user, {
      # Validate
      if (is.null(input$user_login) || nchar(input$user_login) == 0) {
        shinyjs::html("user_error", "Login is required.")
        shinyjs::show("user_error")
        return()
      }

      # Check if editing or adding
      if (is.null(editing_user_id())) {
        # Adding new user - password required
        if (is.null(input$user_password) || nchar(input$user_password) == 0) {
          shinyjs::html("user_error", "Password is required for new users.")
          shinyjs::show("user_error")
          return()
        }

        # Add user
        result <- add_user(
          login = input$user_login,
          password = input$user_password,
          first_name = input$user_first_name,
          last_name = input$user_last_name,
          role = input$user_role,
          affiliation = input$user_affiliation
        )

        if (is.null(result)) {
          shinyjs::html("user_error", "Login already exists. Please choose a different login.")
          shinyjs::show("user_error")
          return()
        }

        # Success
        shinyjs::html("user_success", "User created successfully.")
        shinyjs::show("user_success")
      } else {
        # Editing existing user
        update_params <- list(
          user_id = editing_user_id(),
          login = input$user_login,
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

        # Success
        shinyjs::html("user_success", "User updated successfully.")
        shinyjs::show("user_success")
      }

      # Reload users
      users <- get_all_users()
      users_data(users)

      # Close modal after short delay
      shinyjs::delay(1500, shinyjs::hide("user_modal"))
    })

    # Cancel user modal
    observeEvent(input$cancel_user, {
      shinyjs::hide("user_modal")
    })

    # Close modal button
    observeEvent(input$close_modal, {
      shinyjs::hide("user_modal")
    })
  })
}
