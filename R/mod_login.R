#' Login Module
#'
#' @description Module for user authentication
#'
#' @param id Namespace id
#'
#' @return Shiny module UI
#' @noRd
#'
#' @importFrom shiny NS div textInput passwordInput actionButton tags
#' @importFrom htmltools tagList
mod_login_ui <- function(id) {
  ns <- NS(id)

  tagList(
    shinyjs::useShinyjs(),
    div(
      class = "login-container",
      style = "display: flex; align-items: center; justify-content: center; min-height: 100vh;",
      div(
      class = "login-box",
      style = "background: white; padding: 40px; border-radius: 10px; box-shadow: 0 10px 25px rgba(0,0,0,0.2); width: 100%; max-width: 400px;",
      # Logo and title
      div(
        style = "text-align: center; margin-bottom: 30px;",
        tags$img(
          src = "www/logo.png",
          style = "height: 80px; width: auto; margin-bottom: 15px;"
        ),
        tags$h2(
          "INDICATE Data Dictionary",
          style = "color: #2c3e50; margin: 0; font-size: 24px;"
        )
      ),

      # Error message
      div(
        id = ns("login_error"),
        style = "display: none; background: #fee; border: 1px solid #fcc; color: #c33; padding: 10px; border-radius: 4px; margin-bottom: 20px; text-align: center; font-size: 14px;"
      ),

      # Login form
      div(
        style = "margin-bottom: 20px;",
        textInput(
          ns("login"),
          label = tags$label(
            "Login",
            style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
          ),
          placeholder = "Enter your login",
          width = "100%"
        )
      ),

      div(
        style = "margin-bottom: 25px;",
        tags$label(
          "Password",
          style = "display: block; margin-bottom: 5px; color: #2c3e50; font-weight: 600; font-size: 14px;"
        ),
        div(
          style = "position: relative;",
          passwordInput(
            ns("password"),
            label = NULL,
            placeholder = "Enter your password",
            width = "100%"
          ),
          tags$button(
            id = ns("toggle_password"),
            type = "button",
            class = "password-toggle-btn",
            style = "position: absolute; right: 10px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; color: #666; padding: 5px;",
            tags$i(class = "fas fa-eye", id = ns("password_icon"))
          )
        )
      ),

      # Buttons
      div(
        style = "display: flex; gap: 10px;",
        actionButton(
          ns("login_btn"),
          "Log In",
          class = "btn-primary",
          icon = icon("sign-in-alt"),
          style = "flex: 1; background: #0f60af; color: white; border: none; padding: 12px; border-radius: 4px; font-size: 16px; font-weight: 600; cursor: pointer;"
        ),
        actionButton(
          ns("anonymous_btn"),
          "Anonymous",
          class = "btn-secondary",
          icon = icon("user-slash"),
          style = "flex: 1; background: #6c757d; color: white; border: none; padding: 12px; border-radius: 4px; font-size: 16px; font-weight: 600; cursor: pointer;"
        )
      ),

      # Help text
      div(
        style = "margin-top: 20px; text-align: center; color: #7f8c8d; font-size: 12px;",
        tags$p(
          style = "margin: 5px 0;",
          "Anonymous access has limited permissions"
        )
      )
    )
    )
  )
}

#' Login Module Server
#'
#' @description Server logic for user authentication
#'
#' @param id Namespace id
#'
#' @return Reactive containing authenticated user data or NULL
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent req
mod_login_server <- function(id, log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive value to store current user
    current_user <- reactiveVal(NULL)

    # Handle login button
    observe_event(input$login_btn, {
      # Immediately block UI to prevent multiple clicks
      shinyjs::disable("login")
      shinyjs::disable("password")
      shinyjs::disable("login_btn")
      shinyjs::disable("anonymous_btn")
      shinyjs::hide("login_error")

      # Validate inputs - handle NULL and empty string
      login_value <- input$login
      password_value <- input$password

      # Check for NULL or empty
      if (is.null(login_value) || length(login_value) == 0 || login_value == "" || nchar(trimws(login_value)) == 0) {
        shinyjs::html(
          "login_error",
          "Please enter your login."
        )
        shinyjs::show("login_error")
        # Re-enable UI
        shinyjs::enable("login")
        shinyjs::enable("password")
        shinyjs::enable("login_btn")
        shinyjs::enable("anonymous_btn")
        return()
      }

      if (is.null(password_value) || length(password_value) == 0 || password_value == "" || nchar(password_value) == 0) {
        shinyjs::html(
          "login_error",
          "Please enter your password."
        )
        shinyjs::show("login_error")
        # Re-enable UI
        shinyjs::enable("login")
        shinyjs::enable("password")
        shinyjs::enable("login_btn")
        shinyjs::enable("anonymous_btn")
        return()
      }

      # Proceed with authentication after a delay to allow UI to update
      shinyjs::delay(200, {
        # Authenticate user
        user <- authenticate_user(login_value, password_value)

        if (!is.null(user)) {
          # Successful login
          current_user(user)
        } else {
          # Failed login
          shinyjs::html(
            "login_error",
            "Invalid login or password. Please try again."
          )
          shinyjs::show("login_error")
          # Re-enable UI for retry
          shinyjs::enable("login")
          shinyjs::enable("password")
          shinyjs::enable("login_btn")
          shinyjs::enable("anonymous_btn")
        }
      })
    }, ignoreNULL = FALSE, ignoreInit = TRUE)

    # Handle anonymous login
    observe_event(input$anonymous_btn, {
      # Immediately block UI to prevent multiple clicks
      shinyjs::disable("login")
      shinyjs::disable("password")
      shinyjs::disable("login_btn")
      shinyjs::disable("anonymous_btn")
      shinyjs::hide("login_error")

      # Create anonymous user object after a delay to allow UI to update
      shinyjs::delay(200, {
        anonymous_user <- data.frame(
          user_id = 0,
          login = "anonymous",
          first_name = "Anonymous",
          last_name = "User",
          role = "Anonymous",
          affiliation = "",
          is_active = 1,
          stringsAsFactors = FALSE
        )

        current_user(anonymous_user)
      })
    })

    # Return current user reactive and logout function
    return(list(
      user = reactive({ current_user() }),
      logout = function() {
        current_user(NULL)
        # Refresh the page to reset everything
        shinyjs::runjs("location.reload();")
      }
    ))
  })
}
