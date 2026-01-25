#' Login Module
#'
#' @description Module for user authentication
#'
#' @param id Namespace id
#' @param i18n Translator object from shiny.i18n
#'
#' @return Shiny module UI
#' @noRd
mod_login_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    shinyjs::useShinyjs(),
    tags$script(HTML(sprintf("
      $(document).ready(function() {
        setTimeout(function() {
          $('#%s').focus();
        }, 100);

        // Press Enter to login
        $('#%s, #%s').on('keypress', function(e) {
          if (e.which === 13) {
            e.preventDefault();
            // Force Shiny to update input values immediately
            $('#%s').trigger('change');
            $('#%s').trigger('change');
            // Small delay to ensure values are updated before clicking
            setTimeout(function() {
              $('#%s').click();
            }, 50);
          }
        });

        // Toggle password visibility
        $('#%s').on('click', function(e) {
          e.preventDefault();
          var passwordInput = $('#%s');
          var icon = $('#%s');
          if (passwordInput.attr('type') === 'password') {
            passwordInput.attr('type', 'text');
            icon.removeClass('fa-eye').addClass('fa-eye-slash');
          } else {
            passwordInput.attr('type', 'password');
            icon.removeClass('fa-eye-slash').addClass('fa-eye');
          }
        });
      });
    ", ns("login"), ns("login"), ns("password"), ns("login"), ns("password"), ns("login_btn"), ns("toggle_password"), ns("password"), ns("password_icon")))),
    div(
      class = "login-container",
      style = paste0(
        "display: flex; align-items: center; justify-content: center; ",
        "min-height: 100vh; background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);"
      ),
      div(
        class = "login-box",
        style = paste0(
          "background: white; padding: 40px; border-radius: 10px; ",
          "box-shadow: 0 10px 25px rgba(0,0,0,0.2); width: 100%%; ",
          "max-width: 400px;"
        ),
        # Logo and title
        div(
          style = "text-align: center; margin-bottom: 20px;",
          tags$img(
            src = "www/logo.png",
            style = "height: 80px; width: auto; margin-bottom: 15px;"
          ),
          tags$h2(
            i18n$t("app_title"),
            style = "color: #2c3e50; margin: 0 0 15px 0; font-size: 24px;"
          )
        ),

        # Error message
        div(
          id = ns("login_error"),
          style = paste0(
            "display: none; background: #fee; border: 1px solid #fcc; ",
            "color: #c33; padding: 10px; border-radius: 4px; ",
            "margin-bottom: 20px; text-align: center; font-size: 14px;"
          )
        ),

        # Login form
        div(
          style = "margin-bottom: 20px;",
          tags$label(
            i18n$t("username"),
            class = "form-label"
          ),
          textInput(
            ns("login"),
            label = NULL,
            placeholder = as.character(i18n$t("enter_login")),
            width = "100%"
          )
        ),

        div(
          style = "margin-bottom: 25px;",
          tags$label(
            i18n$t("password"),
            class = "form-label"
          ),
          div(
            style = "position: relative;",
            passwordInput(
              ns("password"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_password")),
              width = "100%"
            ),
            tags$button(
              id = ns("toggle_password"),
              type = "button",
              class = "password-toggle-btn",
              style = paste0(
                "position: absolute; right: 10px; top: 50%; ",
                "transform: translateY(-50%); background: none; ",
                "border: none; cursor: pointer; color: #666; padding: 5px;"
              ),
              tags$i(class = "fas fa-eye", id = ns("password_icon"))
            )
          )
        ),

        # Login button
        actionButton(
          ns("login_btn"),
          i18n$t("login_button"),
          class = "btn-primary-custom",
          icon = icon("sign-in-alt"),
          style = "width: 100%; padding: 12px; font-size: 16px;"
        ),

        # Help text
        div(
          style = paste0(
            "margin-top: 20px; text-align: center; ",
            "color: #7f8c8d; font-size: 12px;"
          ),
          tags$p(
            "Default credentials: admin / admin",
            style = "margin: 5px 0;"
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
#' @param i18n Translator object from shiny.i18n
#'
#' @return List containing user reactive and logout function
#' @noRd
mod_login_server <- function(id, i18n) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive value to store current user
    current_user <- reactiveVal(NULL)

    # Handle login button
    observe_event(input$login_btn, {
      # Hide previous error
      shinyjs::hide("login_error")

      # Validate inputs
      login_value <- trimws(input$login)
      password_value <- input$password

      if (is.null(login_value) || login_value == "") {
        shinyjs::html("login_error", as.character(i18n$t("login_required")))
        shinyjs::show("login_error")
        return()
      }

      if (is.null(password_value) || password_value == "") {
        shinyjs::html("login_error", as.character(i18n$t("password_required")))
        shinyjs::show("login_error")
        return()
      }

      # Authenticate user
      user <- authenticate_user(login_value, password_value)

      if (!is.null(user)) {
        # Successful login
        current_user(user)
      } else {
        # Failed login
        shinyjs::html("login_error", as.character(i18n$t("login_error")))
        shinyjs::show("login_error")
      }
    }, ignoreInit = TRUE)

    # Return current user reactive and logout function
    return(list(
      user = reactive({ current_user() }),
      logout = function() {
        current_user(NULL)
      }
    ))
  })
}
