# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the application header with navigation.
#
# UI STRUCTURE:
#   ## UI - Header Layout
#      ### Logo and title (left)
#      ### Navigation tabs (center)
#      ### Settings dropdown and user info (right)
#
# SERVER STRUCTURE:
#   ## 1) Server - Navigation
#      ### Route detection
#      ### Tab rendering
#      ### Navigation handlers
#   ## 2) Server - Settings Menu
#      ### Dropdown toggle
#      ### Menu item handlers
#   ## 3) Server - User Display
#      ### Current user badge

# UI SECTION ====

#' Page Header Module - UI
#'
#' @param id Module ID
#' @param i18n Translator object
#'
#' @return Shiny UI elements
#' @noRd
mod_page_header_ui <- function(id, i18n) {
  ns <- NS(id)

  tags$header(
    class = "header",

    # Logo and title (left)
    tags$div(
      class = "header-left",
      actionButton(
        inputId = ns("logo_home"),
        label = tagList(
          tags$img(src = "www/logo.png", class = "header-logo", alt = "INDICATE"),
          tags$span(class = "header-title", i18n$t("app_title"))
        ),
        class = "header-logo-btn"
      )
    ),

    # Navigation tabs (center)
    tags$div(
      class = "header-nav",
      uiOutput(ns("nav_tabs"))
    ),

    # Settings and user info (right)
    tags$div(
      class = "header-right",

      # Current user display
      uiOutput(ns("current_user_display")),

      # Settings dropdown
      tags$div(
        style = "position: relative;",
        actionButton(
          ns("nav_settings"),
          label = icon("cog"),
          class = "nav-tab nav-tab-settings"
        ),

        # Dropdown menu
        tags$div(
          id = ns("settings_dropdown"),
          class = "settings-dropdown",
          style = "display: none;",

          # General settings
          tags$div(
            id = ns("settings_item_general"),
            class = "settings-dropdown-item",
            onclick = sprintf(
              "$('#%s').hide(); Shiny.setInputValue('%s', true, {priority: 'event'});",
              ns("settings_dropdown"), ns("nav_general_settings")
            ),
            tags$i(class = "fas fa-cog", style = "margin-right: 10px;"),
            i18n$t("general_settings")
          ),

          # Dictionary settings
          tags$div(
            id = ns("settings_item_dictionary"),
            class = "settings-dropdown-item",
            onclick = sprintf(
              "$('#%s').hide(); Shiny.setInputValue('%s', true, {priority: 'event'});",
              ns("settings_dropdown"), ns("nav_dictionary_settings")
            ),
            tags$i(class = "fas fa-book", style = "margin-right: 10px;"),
            i18n$t("dictionary_settings")
          ),

          # Users
          tags$div(
            id = ns("settings_item_users"),
            class = "settings-dropdown-item",
            onclick = sprintf(
              "$('#%s').hide(); Shiny.setInputValue('%s', true, {priority: 'event'});",
              ns("settings_dropdown"), ns("nav_users")
            ),
            tags$i(class = "fas fa-users", style = "margin-right: 10px;"),
            i18n$t("users")
          ),

          # Dev Tools
          tags$div(
            id = ns("settings_item_dev_tools"),
            class = "settings-dropdown-item",
            onclick = sprintf(
              "$('#%s').hide(); Shiny.setInputValue('%s', true, {priority: 'event'});",
              ns("settings_dropdown"), ns("nav_dev_tools")
            ),
            tags$i(class = "fas fa-code", style = "margin-right: 10px;"),
            i18n$t("dev_tools")
          ),

          # Logout
          tags$div(
            id = ns("settings_item_logout"),
            class = "settings-dropdown-item",
            onclick = sprintf(
              "$('#%s').hide(); Shiny.setInputValue('%s', true, {priority: 'event'});",
              ns("settings_dropdown"), ns("logout")
            ),
            tags$i(class = "fas fa-sign-out-alt", style = "margin-right: 10px;"),
            i18n$t("logout")
          )
        )
      )
    )
  )
}

# SERVER SECTION ====

#' Page Header Module - Server
#'
#' @param id Module ID
#' @param i18n Translator object
#' @param current_user Reactive: Current logged-in user
#'
#' @return List with logout reactive
#' @noRd
mod_page_header_server <- function(id, i18n, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Set log level from environment
    log_level <- strsplit(Sys.getenv("INDICATE_DEBUG_MODE", "error"), ",")[[1]]

    # 1) NAVIGATION ====

    ## Get current route ----
    current_route <- reactive({
      page <- shiny.router::get_page(session)
      if (is.logical(page) && !page) return("")
      sub("^/", "", page)
    })

    ## Render navigation tabs ----
    output$nav_tabs <- renderUI({
      route <- current_route()

      # Define navigation tabs
      tabs <- list(
        list(id = "nav_data_dictionary", path = "", label = i18n$t("data_dictionary"), icon = "book"),
        list(id = "nav_projects", path = "projects", label = i18n$t("projects"), icon = "list-check"),
        list(id = "nav_mapping", path = "mapping", label = i18n$t("concept_mapping"), icon = "project-diagram")
      )

      # Create tab buttons
      tab_buttons <- lapply(tabs, function(tab) {
        is_active <- (route == tab$path)
        class_attr <- if (is_active) "nav-tab nav-tab-active" else "nav-tab"

        actionButton(
          inputId = ns(tab$id),
          label = tagList(
            icon(tab$icon),
            tags$span(class = "nav-tab-text", tab$label)
          ),
          class = class_attr
        )
      })

      tagList(tab_buttons)
    })

    ## Navigation handlers ----
    observe_event(input$logo_home, {
      shiny.router::change_page("/", session = session)
    }, ignoreInit = TRUE)

    observe_event(input$nav_data_dictionary, {
      shiny.router::change_page("", session = session)
    }, ignoreInit = TRUE)

    observe_event(input$nav_projects, {
      shiny.router::change_page("projects", session = session)
    }, ignoreInit = TRUE)

    observe_event(input$nav_mapping, {
      shiny.router::change_page("mapping", session = session)
    }, ignoreInit = TRUE)

    observe_event(input$nav_general_settings, {
      shiny.router::change_page("general-settings", session = session)
    }, ignoreInit = TRUE)

    observe_event(input$nav_dictionary_settings, {
      shiny.router::change_page("dictionary-settings", session = session)
    }, ignoreInit = TRUE)

    observe_event(input$nav_users, {
      shiny.router::change_page("users", session = session)
    }, ignoreInit = TRUE)

    observe_event(input$nav_dev_tools, {
      shiny.router::change_page("dev-tools", session = session)
    }, ignoreInit = TRUE)

    # 2) USER DISPLAY ====

    output$current_user_display <- renderUI({
      user <- if (!is.null(current_user)) current_user() else NULL

      if (is.null(user)) {
        return(tags$div(
          class = "current-user-badge",
          tags$i(class = "fas fa-user"),
          tags$span("Guest")
        ))
      }

      user_name <- if (!is.null(user$first_name) && nchar(user$first_name) > 0) {
        paste(user$first_name, user$last_name)
      } else {
        user$login
      }

      user_icon <- if (user$role == "Admin") "user-shield" else "user-circle"

      tags$div(
        class = "current-user-badge",
        tags$i(class = paste0("fas fa-", user_icon)),
        tags$span(user_name)
      )
    })

    # 3) PERMISSIONS ====

    # TODO: Implement permissions logic later
    # observe_event(current_user(), {
    #   user <- current_user()
    #   if (!is.null(user) && user$role == "Admin") {
    #     shinyjs::show("settings_item_users")
    #     shinyjs::show("settings_item_dev_tools")
    #   } else {
    #     shinyjs::hide("settings_item_users")
    #     shinyjs::hide("settings_item_dev_tools")
    #   }
    # }, ignoreNULL = FALSE, ignoreInit = FALSE)

    # Return logout event
    return(
      list(
        logout = reactive({ input$logout })
      )
    )
  })
}
