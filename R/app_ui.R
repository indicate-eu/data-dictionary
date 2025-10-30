#' Application UI
#'
#' @description Main UI function for the INDICATE application
#'
#' @return Shiny UI
#' @noRd
#'
#' @importFrom shiny fluidPage tags uiOutput actionButton icon
#' @importFrom htmltools tagList
app_ui <- function() {
  fluidPage(
    # Initialize shinyjs
    shinyjs::useShinyjs(),

    # CSS and JavaScript dependencies
    tags$head(
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "www/style.css"
      ),
      tags$link(
        rel = "stylesheet",
        href = paste0(
          "https://cdnjs.cloudflare.com/ajax/libs/",
          "font-awesome/6.0.0/css/all.min.css"
        )
      ),
      tags$script(
        src = paste0(
          "https://cdnjs.cloudflare.com/ajax/libs/",
          "jqueryui/1.12.1/jquery-ui.min.js"
        )
      ),
      tags$script(
        src = "https://cdn.datatables.net/plug-ins/2.2.1/filtering/type-based/accent-neutralise.js"
      ),
      tags$script(src = "www/resizable_splitter.js"),
      tags$script(src = "www/tab_handler.js"),
      tags$script(src = "www/nav_handler.js"),
      tags$script(src = "www/folder_display.js"),
      tags$script(src = "www/view_details.js"),
      tags$script(src = "www/settings_menu.js"),
      tags$script(src = "www/prevent_doubleclick_selection.js"),
      tags$script(src = "www/recommended_toggle.js"),
      tags$script(src = "www/login_handler.js"),
      tags$script(src = "www/users_table.js")
    ),

    # Login page (shown first)
    div(
      id = "login_page",
      mod_login_ui("login")
    ),

    # Main application (hidden until authenticated)
    div(
      id = "main_app",
      style = "display: none;",

      # Application header with navigation
    div(class = "header",
        # Logo and title section
        div(class = "header-left",
            tags$a(
              href = "#",
              onclick = "$('#nav_explorer').click(); return false;",
              style = "text-decoration: none; display: flex; align-items: center; gap: 15px; cursor: pointer;",
              tags$img(src = "www/logo.png", class = "header-logo"),
              tags$h1("INDICATE Data Dictionary", class = "header-title")
            )
        ),

        # Navigation tabs
        div(class = "header-nav",
            actionButton(
              "nav_explorer",
              label = tagList(icon("search"), "Dictionary Explorer"),
              class = "nav-tab nav-tab-active"
            ),
            actionButton(
              "nav_use_cases",
              label = tagList(icon("list-check"), "Use Cases"),
              class = "nav-tab"
            ),
            actionButton(
              "nav_mapping",
              label = tagList(icon("project-diagram"), "Concepts Mapping"),
              class = "nav-tab"
            ),
            actionButton(
              "nav_improvements",
              label = tagList(icon("lightbulb"), "Improvements"),
              class = "nav-tab"
            ),
            actionButton(
              "nav_dev_tools",
              label = tagList(icon("code"), "Dev Tools"),
              class = "nav-tab"
            )
        ),

        # Settings button and loading status on the right
        div(class = "header-right",
            # Current user display
            uiOutput("current_user_display"),
            uiOutput("vocab_status_indicator"),
            tags$div(
              style = "position: relative;",
              actionButton(
                "nav_settings",
                label = icon("cog"),
                class = "nav-tab nav-tab-settings"
              ),
              # Dropdown menu for settings
              tags$div(
                id = "settings_dropdown",
                class = "settings-dropdown",
                style = "display: none; position: absolute; right: 0; top: 100%; margin-top: 5px; background: #2c3e50; border-radius: 4px; box-shadow: 0 4px 12px rgba(0,0,0,0.3); z-index: 1000; min-width: 200px;",
                tags$div(
                  class = "settings-dropdown-item",
                  style = "padding: 12px 20px; cursor: pointer; color: white; border-bottom: 1px solid rgba(255,255,255,0.1); transition: background 0.2s;",
                  onclick = "$('#settings_dropdown').hide(); Shiny.setInputValue('nav_general_settings', true, {priority: 'event'});",
                  tags$i(class = "fas fa-cog", style = "margin-right: 10px;"),
                  "General settings"
                ),
                tags$div(
                  class = "settings-dropdown-item",
                  style = "padding: 12px 20px; cursor: pointer; color: white; border-bottom: 1px solid rgba(255,255,255,0.1); transition: background 0.2s;",
                  onclick = "$('#settings_dropdown').hide(); Shiny.setInputValue('nav_users', true, {priority: 'event'});",
                  tags$i(class = "fas fa-users", style = "margin-right: 10px;"),
                  "Users"
                ),
                tags$div(
                  class = "settings-dropdown-item",
                  style = "padding: 12px 20px; cursor: pointer; color: white; transition: background 0.2s;",
                  onclick = "$('#settings_dropdown').hide(); Shiny.setInputValue('logout', true, {priority: 'event'});",
                  tags$i(class = "fas fa-sign-out-alt", style = "margin-right: 10px;"),
                  "Logout"
                )
              )
            )
        )
    ),

    # Main content wrapper
    tags$div(
      style = "flex: 1; overflow: hidden; display: flex; flex-direction: column;",
      # Main content area - all modules are created and shown/hidden with CSS
      tags$div(
        id = "page_explorer",
        style = "height: 100%; flex: 1; display: flex; flex-direction: column;",
        mod_dictionary_explorer_ui("dictionary_explorer")
      ),
      tags$div(
        id = "page_mapping",
        style = "height: 100%; flex: 1; display: none; flex-direction: column;",
        mod_concept_mapping_ui("concept_mapping")
      ),
      tags$div(
        id = "page_use_cases",
        style = "height: 100%; flex: 1; display: none; flex-direction: column;",
        mod_use_cases_ui("use_cases")
      ),
      tags$div(
        id = "page_improvements",
        style = "height: 100%; flex: 1; display: none; flex-direction: column;",
        mod_improvements_ui("improvements")
      ),
      tags$div(
        id = "page_dev_tools",
        style = "height: 100%; flex: 1; display: none; flex-direction: column;",
        mod_dev_tools_ui("dev_tools")
      ),
      tags$div(
        id = "page_settings",
        style = "height: 100%; flex: 1; display: none; flex-direction: column;",
        mod_settings_ui("settings")
      )
    ),

      # Footer
      tags$div(
        class = "app-footer",
        style = "background: #f8f9fa; border-top: 1px solid #e0e0e0; padding: 10px 20px; text-align: center; color: #666; font-size: 13px; flex-shrink: 0;",
        tags$span(
          paste0("INDICATE Data Dictionary v", utils::packageVersion("indicate")),
          style = "margin-right: 15px;"
        ),
        tags$span("|", style = "margin-right: 15px; color: #ccc;"),
        tags$a(
          href = "https://indicate-europe.eu/",
          target = "_blank",
          style = "color: #0f60af; text-decoration: none;",
          "INDICATE Project"
        )
      )
    ) # End main_app div
  )
}
