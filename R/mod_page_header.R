#' Page Header Module - UI
#'
#' @description Dynamic header UI that adapts to current route
#'
#' @param id Module ID
#' @param i18n Translator object from shiny.i18n
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS actionButton icon uiOutput
#' @importFrom htmltools tags tagList
mod_page_header_ui <- function(id, i18n) {
  ns <- NS(id)

  div(class = "header",
      # Logo and title section
      div(class = "header-left",
          actionButton(
            inputId = ns("logo_home"),
            label = tagList(
              tags$img(src = "www/logo.png", class = "header-logo"),
              tags$h1(i18n$t("app_title"), class = "header-title")
            ),
            style = "background: none; border: none; padding: 0; cursor: pointer; display: flex; align-items: center; gap: 15px;"
          )
      ),

      # Navigation tabs
      div(class = "header-nav",
          uiOutput(ns("nav_tabs"))
      ),

      # Settings button and user info on the right
      div(class = "header-right",
          # Current user display
          uiOutput(ns("current_user_display")),
          tags$div(
            style = "position: relative;",
            actionButton(
              ns("nav_settings"),
              label = icon("cog"),
              class = "nav-tab nav-tab-settings"
            ),
            # Dropdown menu for settings
            tags$div(
              id = ns("settings_dropdown"),
              class = "settings-dropdown",
              style = "display: none; position: absolute; right: 0; top: 100%; margin-top: 5px; background: #2c3e50; border-radius: 4px; box-shadow: 0 4px 12px rgba(0,0,0,0.3); z-index: 1000; min-width: 200px;",

              # General settings item
              tags$div(
                id = ns("settings_item_general"),
                class = "settings-dropdown-item",
                style = "padding: 12px 20px; cursor: pointer; color: white; border-bottom: 1px solid rgba(255,255,255,0.1); transition: background 0.2s;",
                onclick = sprintf("$('#%s').hide(); Shiny.setInputValue('%s', true, {priority: 'event'});",
                                ns("settings_dropdown"), ns("nav_general_settings")),
                tags$i(class = "fas fa-cog", style = "margin-right: 10px;"),
                i18n$t("general_settings")
              ),

              # Users item
              tags$div(
                id = ns("settings_item_users"),
                class = "settings-dropdown-item",
                style = "padding: 12px 20px; cursor: pointer; color: white; border-bottom: 1px solid rgba(255,255,255,0.1); transition: background 0.2s;",
                onclick = sprintf("$('#%s').hide(); Shiny.setInputValue('%s', true, {priority: 'event'});",
                                ns("settings_dropdown"), ns("nav_users")),
                tags$i(class = "fas fa-users", style = "margin-right: 10px;"),
                i18n$t("users")
              ),

              # Logout item
              tags$div(
                id = ns("settings_item_logout"),
                class = "settings-dropdown-item",
                style = "padding: 12px 20px; cursor: pointer; color: white; transition: background 0.2s;",
                onclick = sprintf("$('#%s').hide(); Shiny.setInputValue('%s', true, {priority: 'event'});",
                                ns("settings_dropdown"), ns("logout")),
                tags$i(class = "fas fa-sign-out-alt", style = "margin-right: 10px;"),
                i18n$t("logout")
              )
            )
          )
      )
  )
}

#' Page Header Module - Server
#'
#' @description Server logic for dynamic header
#'
#' @param id Module ID
#' @param current_user Reactive containing current user data
#' @param vocab_loading_status Reactive containing vocabulary loading status
#' @param i18n Translator object from shiny.i18n for server-side translations
#'
#' @return NULL
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent renderUI req
#' @importFrom shiny.router get_page change_page
mod_page_header_server <- function(id, current_user, vocab_loading_status, i18n = NULL, log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Get current route reactively
    current_route <- reactive({
      page <- shiny.router::get_page(session)
      if (is.logical(page) && !page) {
        return("")
      }
      # Normalize path: remove leading slash if present
      page <- sub("^/", "", page)
      return(page)
    })

    # Render navigation tabs based on user permissions
    output$nav_tabs <- renderUI({
      user <- current_user()
      route <- current_route()

      # Define base tabs
      tabs <- list(
        list(
          id = "nav_explorer",
          path = "",
          label = tagList(icon("search"), if (!is.null(i18n)) i18n$t("dictionary_explorer") else "Dictionary Explorer"),
          visible = TRUE
        ),
        list(
          id = "nav_use_cases",
          path = "use-cases",
          label = tagList(icon("list-check"), if (!is.null(i18n)) i18n$t("use_cases") else "Use Cases"),
          visible = TRUE
        ),
        list(
          id = "nav_mapping",
          path = "mapping",
          label = tagList(icon("project-diagram"), if (!is.null(i18n)) i18n$t("concepts_mapping") else "Concepts Mapping"),
          visible = !is.null(user) && user$role != "Anonymous"
        ),
        list(
          id = "nav_improvements",
          path = "improvements",
          label = tagList(icon("lightbulb"), if (!is.null(i18n)) i18n$t("improvements") else "Improvements"),
          visible = !is.null(user) && user$role != "Anonymous"
        ),
        list(
          id = "nav_dev_tools",
          path = "dev-tools",
          label = tagList(icon("code"), if (!is.null(i18n)) i18n$t("dev_tools") else "Dev Tools"),
          visible = !is.null(user) && user$role != "Anonymous"
        )
      )

      # Filter visible tabs and create buttons
      tab_buttons <- lapply(tabs, function(tab) {
        if (!tab$visible) return(NULL)

        # Determine if this tab is active
        is_active <- (route == tab$path)
        class_attr <- if (is_active) "nav-tab nav-tab-active" else "nav-tab"

        actionButton(
          inputId = ns(tab$id),
          label = tab$label,
          class = class_attr
        )
      })

      # Remove NULL elements
      tab_buttons <- tab_buttons[!sapply(tab_buttons, is.null)]

      tagList(tab_buttons)
    })

    # Logo click handler
    observe_event(input$logo_home, {
      shiny.router::change_page("/", session = session)
    })

    # Navigation handlers - use change_page from shiny.router
    observe_event(input$nav_explorer, {
      shiny.router::change_page("", session = session)
    })

    observe_event(input$nav_use_cases, {
      shiny.router::change_page("use-cases", session = session)
    })

    observe_event(input$nav_mapping, {
      shiny.router::change_page("mapping", session = session)
    })

    observe_event(input$nav_improvements, {
      shiny.router::change_page("improvements", session = session)
    })

    observe_event(input$nav_dev_tools, {
      shiny.router::change_page("dev-tools", session = session)
    })

    observe_event(input$nav_general_settings, {
      shiny.router::change_page("general-settings", session = session)
    })

    observe_event(input$nav_users, {
      shiny.router::change_page("users", session = session)
    })

    # Hide/show menu items based on user role
    observe_event(current_user(), {
      user <- current_user()

      if (!is.null(user) && user$role == "Anonymous") {
        shinyjs::hide("settings_item_general")
        shinyjs::hide("settings_item_users")
      } else {
        shinyjs::show("settings_item_general")
        shinyjs::show("settings_item_users")
      }
    })

    # Display current user in header
    output$current_user_display <- renderUI({
      user <- current_user()

      if (is.null(user)) {
        return(NULL)
      }

      # Build user display name
      if (!is.null(user$first_name) && nchar(user$first_name) > 0) {
        user_name <- paste(user$first_name, user$last_name)
      } else {
        user_name <- user$login
      }

      # Choose icon based on role
      user_icon <- if (user$role == "Anonymous") {
        "user"
      } else {
        "user-circle"
      }

      tags$div(
        class = "current-user-badge",
        style = "display: flex; align-items: center; gap: 8px; padding: 6px 12px; background: #0f60af; border-radius: 20px; color: white; font-size: 14px;",
        tags$i(class = paste0("fas fa-", user_icon), style = "font-size: 16px;"),
        tags$span(
          style = "font-weight: 500;",
          user_name
        )
      )
    })

    # Return logout event
    return(
      list(
        logout = reactive({ input$logout })
      )
    )
  })
}
