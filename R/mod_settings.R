#' Settings Module - UI
#'
#' @description UI function for the settings module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS fluidRow column h3 h4 p selectInput checkboxInput numericInput
#' @importFrom htmltools tags tagList
mod_settings_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Main content for settings
    div(class = "main-panel",
        div(class = "main-content",

            # Page header
            fluidRow(
              column(12,
                     div(class = "section-header",
                         h3("Application Settings")
                     )
              )
            ),

            # Settings sections
            fluidRow(
              column(6,
                     div(class = "settings-section",
                         style = "background: #fff; padding: 20px; border-radius: 8px; margin-top: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
                         h4(tags$i(class = "fas fa-table", style = "margin-right: 8px;"), "Display Settings"),
                         selectInput(
                           ns("page_length"),
                           "Default table page length:",
                           choices = c("5" = 5, "10" = 10, "15" = 15, "20" = 20, "50" = 50, "100" = 100),
                           selected = 10
                         ),
                         checkboxInput(
                           ns("show_row_numbers"),
                           "Show row numbers in tables",
                           value = FALSE
                         ),
                         checkboxInput(
                           ns("enable_keyboard_nav"),
                           "Enable keyboard navigation",
                           value = TRUE
                         )
                     )
              ),
              column(6,
                     div(class = "settings-section",
                         style = "background: #fff; padding: 20px; border-radius: 8px; margin-top: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
                         h4(tags$i(class = "fas fa-link", style = "margin-right: 8px;"), "External Links"),
                         p("Configure external terminology service endpoints:"),
                         tags$div(
                           style = "margin-top: 15px;",
                           tags$label("FHIR Terminology Server:"),
                           tags$p(
                             style = "font-family: monospace; background: #f8f9fa; padding: 8px; border-radius: 4px; font-size: 12px;",
                             "https://tx.fhir.org/r4/"
                           )
                         ),
                         tags$div(
                           style = "margin-top: 15px;",
                           tags$label("OHDSI ATHENA:"),
                           tags$p(
                             style = "font-family: monospace; background: #f8f9fa; padding: 8px; border-radius: 4px; font-size: 12px;",
                             "https://athena.ohdsi.org/search-terms/terms"
                           )
                         )
                     )
              )
            ),

            fluidRow(
              column(12,
                     div(class = "settings-section",
                         style = "background: #fff; padding: 20px; border-radius: 8px; margin-top: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
                         h4(tags$i(class = "fas fa-info-circle", style = "margin-right: 8px;"), "About"),
                         p(style = "margin-top: 15px;",
                           strong("INDICATE Data Dictionary Explorer"), " - Version 0.1.0"
                         ),
                         p("An interactive application to explore the INDICATE Minimal Data Dictionary."),
                         p(
                           "Author: Boris Delange (",
                           tags$a(href = "mailto:boris.delange@univ-rennes.fr", "boris.delange@univ-rennes.fr"),
                           ")"
                         ),
                         p(
                           "License: GPL (>= 3)"
                         ),
                         tags$div(
                           style = "margin-top: 20px; padding-top: 20px; border-top: 1px solid #dee2e6;",
                           p(style = "color: #666; font-size: 14px;",
                             "Part of the INDICATE project for ICU data harmonization in Europe."
                           )
                         )
                     )
              )
            )
        )
    )
  )
}

#' Settings Module - Server
#'
#' @description Server function for the settings module
#'
#' @param id Module ID
#' @param config Configuration list
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observeEvent
mod_settings_server <- function(id, config) {
  moduleServer(id, function(input, output, session) {

    # Placeholder for future implementation
    # This module will handle:
    # - Saving user preferences
    # - Updating configuration settings
    # - Managing application state

    # Return reactive settings that can be used by other modules
    settings <- reactive({
      list(
        page_length = input$page_length,
        show_row_numbers = input$show_row_numbers,
        enable_keyboard_nav = input$enable_keyboard_nav
      )
    })

    return(settings)
  })
}
