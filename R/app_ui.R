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
      tags$script(src = "www/resizable_splitter.js"),
      tags$script(src = "www/quadrant_splitter.js"),
      tags$script(src = "www/tab_handler.js"),
      tags$script(src = "www/nav_handler.js"),
      tags$script(src = "www/folder_display.js"),
      tags$script(src = "www/view_details.js")
    ),

    # Application header with navigation
    div(class = "header",
        # Logo and title section
        div(class = "header-left",
            tags$img(src = "www/logo.png", class = "header-logo"),
            tags$h1("INDICATE Data Dictionary", class = "header-title")
        ),

        # Navigation tabs
        div(class = "header-nav",
            actionButton(
              "nav_explorer",
              label = tagList(icon("search"), "Dictionary Explorer"),
              class = "nav-tab nav-tab-active"
            ),
            actionButton(
              "nav_mapping",
              label = tagList(icon("project-diagram"), "Concepts Mapping"),
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
            uiOutput("vocab_status_indicator"),
            actionButton(
              "nav_settings",
              label = icon("cog"),
              class = "nav-tab nav-tab-settings"
            )
        )
    ),

    # Main content area - shows different modules based on navigation
    uiOutput("page_content", style = "height: 100%; flex: 1; display: flex; flex-direction: column;")
  )
}
