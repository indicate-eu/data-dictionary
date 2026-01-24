# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Projects interface.
# TODO: Implement full functionality

# UI SECTION ====

#' Projects Module - UI
#'
#' @param id Module ID
#' @param i18n Translator object
#'
#' @return Shiny UI elements
#' @noRd
mod_projects_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",

        # Main content
        create_page_layout(
          "full",
          create_panel(
            title = i18n$t("projects"),
            content = tags$div(
              style = "padding: 40px; text-align: center;",
              tags$p(i18n$t("coming_soon"))
            )
          )
        )
      )
    )
  )
}

# SERVER SECTION ====

#' Projects Module - Server
#'
#' @param id Module ID
#' @param i18n Translator object
#' @param current_user Reactive: Current logged-in user
#'
#' @noRd
mod_projects_server <- function(id, i18n, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    log_level <- strsplit(Sys.getenv("INDICATE_DEBUG_MODE", "error"), ",")[[1]]

    # TODO: Implement projects functionality
  })
}
