# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Data Dictionary interface for browsing concept sets.
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Full-width panel with concept sets DataTable
#
# SERVER STRUCTURE:
#   ## 1) Server - Initialization
#      ### Permissions (calculated once)
#      ### Data loading
#
#   ## 2) Server - Concept Sets Table
#      ### Table rendering
#      ### Row selection
#      ### Actions (view details)

# UI SECTION ====

#' Data Dictionary Module - UI
#'
#' @param id Module ID
#' @param i18n Translator object
#'
#' @return Shiny UI elements
#' @noRd
mod_data_dictionary_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",

        # Main content: Concept Sets table
        create_page_layout(
          "full",
          create_panel(
            title = i18n$t("concept_sets"),
            content = DT::DTOutput(ns("concept_sets_table")),
            tooltip = i18n$t("concept_sets_tooltip"),
            header_extra = shinyjs::hidden(
              actionButton(
                ns("add_concept_set"),
                i18n$t("add_concept_set"),
                class = "btn-success-custom",
                icon = icon("plus")
              )
            )
          )
        )
      )
    )
  )
}

# SERVER SECTION ====

#' Data Dictionary Module - Server
#'
#' @param id Module ID
#' @param i18n Translator object
#' @param current_user Reactive: Current logged-in user
#'
#' @noRd
mod_data_dictionary_server <- function(id, i18n, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Set log level from environment
    log_level <- strsplit(Sys.getenv("INDICATE_DEBUG_MODE", "error"), ",")[[1]]

    # 1) INITIALIZATION ====

    ## Permissions (calculated once at module init) ----
    can_edit <- reactive({
      # For now, allow editing for all users
      # Later: check current_user permissions
      TRUE
    })

    ## Data ----
    concept_sets_data <- reactiveVal(NULL)

    ## Triggers ----
    init_trigger <- reactiveVal(1)

    # 2) INITIALIZATION OBSERVER ====

    observe_event(init_trigger(), {
      # Show/hide buttons based on permissions
      if (can_edit()) {
        shinyjs::show("add_concept_set")
      }

      # Load concept sets data
      data <- get_all_concept_sets()
      concept_sets_data(data)
    }, ignoreInit = FALSE)

    # 3) CONCEPT SETS TABLE ====

    ## Table rendering ----
    output$concept_sets_table <- DT::renderDT({
      data <- concept_sets_data()

      if (is.null(data) || nrow(data) == 0) {
        return(create_empty_datatable(i18n$t("no_concept_sets")))
      }

      # Prepare display data
      display_data <- data %>%
        dplyr::select(
          id,
          name,
          category,
          subcategory,
          description,
          tags,
          item_count
        ) %>%
        dplyr::mutate(
          # Truncate description for display
          description = ifelse(
            nchar(description) > 100,
            paste0(substr(description, 1, 100), "..."),
            description
          ),
          # Action buttons
          actions = create_datatable_actions(list(
            list(
              label = i18n$t("view"),
              icon = "eye",
              type = "primary",
              onclick = sprintf(
                "Shiny.setInputValue('%s', %d, {priority: 'event'})",
                ns("view_concept_set"),
                id
              )
            )
          ))
        )

      create_standard_datatable(
        display_data,
        selection = "single",
        col_names = c(
          "ID",
          i18n$t("name"),
          i18n$t("category"),
          i18n$t("subcategory"),
          i18n$t("description"),
          i18n$t("tags"),
          i18n$t("concepts"),
          i18n$t("actions")
        ),
        col_defs = list(
          list(targets = 0, visible = FALSE),  # Hide ID
          list(targets = 1, width = "20%"),    # Name
          list(targets = 2, width = "12%"),    # Category
          list(targets = 3, width = "12%"),    # Subcategory
          list(targets = 4, width = "30%"),    # Description
          list(targets = 5, width = "10%"),    # Tags
          list(targets = 6, width = "8%", className = "dt-center"),  # Concepts count
          list(targets = 7, width = "8%", className = "dt-center")   # Actions
        ),
        escape = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE)  # Don't escape actions column
      )
    })

    ## Row selection ----
    selected_concept_set_id <- reactive({
      rows <- input$concept_sets_table_rows_selected
      if (is.null(rows) || length(rows) == 0) return(NULL)

      data <- concept_sets_data()
      if (is.null(data)) return(NULL)

      data$id[rows]
    })

    ## View action ----
    observe_event(input$view_concept_set, {
      concept_set_id <- input$view_concept_set
      # TODO: Navigate to detail view or open modal
      showNotification(
        paste("View concept set:", concept_set_id),
        type = "message"
      )
    }, ignoreInit = TRUE)

    ## Add action ----
    observe_event(input$add_concept_set, {
      # TODO: Open add modal
      showNotification("Add concept set (not implemented yet)", type = "message")
    }, ignoreInit = TRUE)

    # Return selected concept set for use by parent
    reactive({
      list(
        selected_id = selected_concept_set_id()
      )
    })
  })
}
