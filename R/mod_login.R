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
    tags$script(HTML(sprintf("
      $(document).ready(function() {
        setTimeout(function() {
          $('#%s').focus();
        }, 100);
      });
    ", ns("login")))),
    div(
      class = "login-container",
      style = "display: flex; align-items: center; justify-content: center; min-height: 100vh;",
      div(
      class = "login-box",
      style = "background: white; padding: 40px; border-radius: 10px; box-shadow: 0 10px 25px rgba(0,0,0,0.2); width: 100%; max-width: 400px;",
      # Logo and title
      div(
        style = "text-align: center; margin-bottom: 20px;",
        tags$img(
          src = "www/logo.png",
          style = "height: 80px; width: auto; margin-bottom: 15px;"
        ),
        tags$h2(
          "INDICATE Data Dictionary",
          style = "color: #2c3e50; margin: 0 0 15px 0; font-size: 24px;"
        ),
        # Language selector (custom dropdown with flags)
        div(
          class = "language-selector",
          tags$div(
            class = "language-dropdown",
            id = ns("language_dropdown"),
            tags$div(
              class = "language-selected",
              id = ns("language_selected"),
              onclick = sprintf("$('#%s').toggleClass('open');", ns("language_dropdown")),
              tags$span(class = "flag flag-en", id = ns("selected_flag")),
              tags$span("English", id = ns("selected_text")),
              tags$i(class = "fas fa-chevron-down dropdown-arrow")
            ),
            tags$div(
              class = "language-options",
              tags$div(
                class = "language-option",
                `data-value` = "en",
                onclick = sprintf("
                  $('#%s').val('en').trigger('change');
                  $('#%s').removeClass('open');
                  $('#%s').attr('class', 'flag flag-en');
                  $('#%s').text('English');
                ", ns("selected_language_hidden"), ns("language_dropdown"), ns("selected_flag"), ns("selected_text")),
                tags$span(class = "flag flag-en"),
                tags$span("English")
              ),
              tags$div(
                class = "language-option",
                `data-value` = "fr",
                onclick = sprintf("
                  $('#%s').val('fr').trigger('change');
                  $('#%s').removeClass('open');
                  $('#%s').attr('class', 'flag flag-fr');
                  $('#%s').text('Fran\u00e7ais');
                ", ns("selected_language_hidden"), ns("language_dropdown"), ns("selected_flag"), ns("selected_text")),
                tags$span(class = "flag flag-fr"),
                tags$span("Fran\u00e7ais")
              )
            )
          ),
          # Hidden input for Shiny binding
          tags$select(
            id = ns("selected_language_hidden"),
            class = "shiny-bound-input",
            style = "display: none;",
            tags$option(value = "en", selected = "selected", "English"),
            tags$option(value = "fr", "Fran\u00e7ais")
          ),
          # JavaScript to close dropdown when clicking outside
          tags$script(HTML(sprintf("
            $(document).on('click', function(e) {
              if (!$(e.target).closest('#%s').length) {
                $('#%s').removeClass('open');
              }
            });
          ", ns("language_dropdown"), ns("language_dropdown"))))
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
#' @return List containing user reactive, logout function, and language reactive
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent req
mod_login_server <- function(id, log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive value to store current user
    current_user <- reactiveVal(NULL)

    # Reactive value to store selected language (default: English)
    selected_language <- reactiveVal("en")

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
    }, ignoreInit = TRUE)

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

    # Handle language selection (from hidden select element)
    observe_event(input$selected_language_hidden, {
      lang <- input$selected_language_hidden
      if (is.null(lang)) return()

      selected_language(lang)
    }, ignoreInit = TRUE)

    # Return current user reactive, logout function, and language reactive
    return(list(
      user = reactive({ current_user() }),
      language = reactive({ selected_language() }),
      logout = function() {
        current_user(NULL)
        # Refresh the page to reset everything
        shinyjs::runjs("location.reload();")
      }
    ))
  })
}
