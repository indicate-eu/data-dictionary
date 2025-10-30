#' Use Cases Module - UI
#'
#' @description UI function for the use cases management module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS actionButton uiOutput textInput textAreaInput
#' @importFrom shiny updateTextInput updateTextAreaInput selectizeInput icon
#' @importFrom htmltools tags tagList
#' @importFrom DT DTOutput
mod_use_cases_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Initialize shinyjs
    shinyjs::useShinyjs(),

    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",
        # Breadcrumb navigation
        uiOutput(ns("breadcrumb")),

        # Dynamic content area
        uiOutput(ns("content_area"))
      )
    ),

    # Modal for adding new use case
    tags$div(
      id = ns("add_use_case_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("add_use_case_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 700px;",
        tags$div(
          class = "modal-header",
          tags$h3("Add New Use Case"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("add_use_case_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$div(
            id = ns("new_use_case_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span("Name ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textInput(
              ns("new_use_case_name"),
              label = NULL,
              placeholder = "Enter use case name (required)",
              width = "100%"
            ),
            tags$div(
              id = ns("name_error"),
              style = paste0(
                "color: #dc3545; font-size: 0.95rem; ",
                "margin-top: 5px; display: none;"
              ),
              "Use case name is required"
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span("Short Description ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textAreaInput(
              ns("new_use_case_short_description"),
              label = NULL,
              placeholder = "Enter short description (1-2 sentences, required)",
              width = "100%",
              rows = 3
            ),
            tags$div(
              id = ns("short_desc_error"),
              style = paste0(
                "color: #dc3545; font-size: 0.95rem; ",
                "margin-top: 5px; display: none;"
              ),
              "Short description is required"
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              "Long Description",
              style = paste0(
                "display: block; font-weight: 600; ",
                "margin-bottom: 8px;"
              )
            ),
            textAreaInput(
              ns("new_use_case_long_description"),
              label = NULL,
              placeholder = "Enter detailed description (optional)",
              width = "100%",
              rows = 5
            )
          ),
          tags$div(
            style = paste0(
              "display: flex; justify-content: flex-end; ",
              "gap: 10px; margin-top: 20px;"
            ),
            tags$button(
              class = "btn btn-secondary",
              onclick = sprintf(
                "$('#%s').hide();",
                ns("add_use_case_modal")
              ),
              "Cancel"
            ),
            actionButton(
              ns("save_use_case"),
              "Save Use Case",
              class = "btn btn-primary",
              icon = icon("save")
            )
          )
        )
      )
    ),

    # Modal for editing use case
    tags$div(
      id = ns("edit_use_case_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("edit_use_case_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 700px;",
        tags$div(
          class = "modal-header",
          tags$h3("Edit Use Case"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("edit_use_case_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$div(
            id = ns("edit_use_case_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span("Name ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textInput(
              ns("edit_use_case_name"),
              label = NULL,
              placeholder = "Enter use case name (required)",
              width = "100%"
            ),
            tags$div(
              id = ns("edit_name_error"),
              style = paste0(
                "color: #dc3545; font-size: 0.95rem; ",
                "margin-top: 5px; display: none;"
              ),
              "Use case name is required"
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              tags$span("Short Description ", style = "font-weight: 600;"),
              tags$span("*", style = "color: #dc3545;"),
              style = "display: block; margin-bottom: 8px;"
            ),
            textAreaInput(
              ns("edit_use_case_short_description"),
              label = NULL,
              placeholder = "Enter short description (1-2 sentences, required)",
              width = "100%",
              rows = 3
            ),
            tags$div(
              id = ns("edit_short_desc_error"),
              style = paste0(
                "color: #dc3545; font-size: 0.95rem; ",
                "margin-top: 5px; display: none;"
              ),
              "Short description is required"
            )
          ),
          tags$div(
            style = "margin-bottom: 20px;",
            tags$label(
              "Long Description",
              style = paste0(
                "display: block; font-weight: 600; ",
                "margin-bottom: 8px;"
              )
            ),
            textAreaInput(
              ns("edit_use_case_long_description"),
              label = NULL,
              placeholder = "Enter detailed description (optional)",
              width = "100%",
              rows = 5
            )
          ),
          tags$div(
            style = paste0(
              "display: flex; justify-content: flex-end; ",
              "gap: 10px; margin-top: 20px;"
            ),
            tags$button(
              class = "btn btn-secondary",
              onclick = sprintf(
                "$('#%s').hide();",
                ns("edit_use_case_modal")
              ),
              "Cancel"
            ),
            actionButton(
              ns("update_use_case"),
              "Update Use Case",
              class = "btn btn-primary",
              icon = icon("save")
            )
          )
        )
      )
    )
  )
}

#' Render Use Cases List View
#'
#' @description Renders the main use cases list with split panel
#'
#' @param ns Namespace function
#'
#' @return UI elements for use cases list view
#' @noRd
render_use_cases_list_ui <- function(ns) {
  tagList(
    # Action buttons bar
    tags$div(
      style = paste0(
        "margin: 5px 0 15px 0; display: flex; ",
        "justify-content: space-between; align-items: center;"
      ),
      # Title (matching dictionary explorer style)
      tags$div(
        class = "section-title",
        tags$span("Use Cases")
      ),
      tags$div(
        style = "display: flex; gap: 10px;",
        shinyjs::hidden(
          actionButton(
            ns("add_use_case_btn"),
            "Add Use Case",
            class = "btn btn-primary",
            icon = icon("plus")
          )
        ),
        shinyjs::hidden(
          actionButton(
            ns("edit_name_description_btn"),
            "Edit",
            class = "btn btn-secondary",
            icon = icon("edit")
          )
        ),
        shinyjs::hidden(
          actionButton(
            ns("configure_use_case_btn"),
            "Configure",
            class = "btn btn-secondary",
            icon = icon("cog")
          )
        ),
        shinyjs::hidden(
          actionButton(
            ns("delete_selected_btn"),
            "Delete",
            class = "btn btn-danger",
            icon = icon("trash")
          )
        )
      )
    ),

    # Split panel layout
    tags$div(
      style = "display: flex; gap: 20px; height: calc(100vh - 175px);",

      # Left panel: Use cases table (70%)
      tags$div(
        style = paste0(
          "flex: 0 0 70%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        tags$h4(
          "Use Cases",
          style = paste0(
            "margin: 0 0 15px 0; color: #0f60af; ",
            "border-bottom: 2px solid #0f60af; padding-bottom: 10px;"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: auto;",
          DT::DTOutput(ns("use_cases_table"))
        )
      ),

      # Right panel: Use case details (30%)
      tags$div(
        style = paste0(
          "flex: 0 0 30%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        tags$h4(
          "Use Case Details",
          style = paste0(
            "margin: 0 0 15px 0; color: #0f60af; ",
            "border-bottom: 2px solid #0f60af; padding-bottom: 10px;"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: auto;",
          uiOutput(ns("use_case_details"))
        )
      )
    )
  )
}

#' Render Use Case Configuration View
#'
#' @description Renders the use case configuration view with 3 panels
#'
#' @param ns Namespace function
#'
#' @return UI elements for use case configuration view
#' @noRd
render_use_case_config_ui <- function(ns) {
  tagList(
    # Two-panel layout for concept selection
    tags$div(
      style = "display: flex; gap: 20px; height: calc(100vh - 175px);",

      # Left panel: Available general concepts (50% width, 100% height)
      tags$div(
        style = paste0(
          "flex: 0 0 50%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        # Header with title
        tags$h4(
          "Available Concepts",
          style = paste0(
            "margin: 0 0 10px 0; color: #0f60af; ",
            "border-bottom: 2px solid #0f60af; padding-bottom: 10px;"
          )
        ),
        # Buttons row
        shinyjs::hidden(
          tags$div(
            id = ns("available_action_buttons"),
            style = "display: flex; gap: 10px; margin-bottom: 15px;",
            actionButton(
              ns("add_general_concepts_btn"),
              "Add Selected Concepts",
              class = "btn btn-primary btn-sm",
              icon = icon("arrow-right")
            ),
            tags$div(
              style = "display: flex; gap: 3px;",
              actionButton(
                ns("select_all_available"),
                NULL,
                class = "btn btn-sm btn-secondary",
                icon = icon("check-square"),
                title = "Select all rows"
              ),
              actionButton(
                ns("unselect_all_available"),
                NULL,
                class = "btn btn-sm btn-secondary",
                icon = icon("square"),
                title = "Unselect all rows"
              )
            )
          )
        ),
        # DataTable
        tags$div(
          style = "flex: 1; overflow: auto;",
          DT::DTOutput(ns("available_general_concepts_table"))
        )
      ),

      # Right panel: Selected general concepts (50% width, 100% height)
      tags$div(
        style = paste0(
          "flex: 0 0 50%; display: flex; flex-direction: column; ",
          "background: white; border-radius: 8px; ",
          "box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px;"
        ),
        # Header with title
        tags$h4(
          "Selected Concepts for Use Case",
          style = paste0(
            "margin: 0 0 10px 0; color: #28a745; ",
            "border-bottom: 2px solid #28a745; padding-bottom: 10px;"
          )
        ),
        # Buttons row
        shinyjs::hidden(
          tags$div(
            id = ns("selected_action_buttons"),
            style = "display: flex; gap: 10px; margin-bottom: 15px;",
            actionButton(
              ns("remove_general_concepts_btn"),
              "Remove Selected Concepts",
              class = "btn btn-danger btn-sm",
              icon = icon("times")
            ),
            tags$div(
              style = "display: flex; gap: 3px;",
              actionButton(
                ns("select_all_selected"),
                NULL,
                class = "btn btn-sm btn-secondary",
                icon = icon("check-square"),
                title = "Select all rows"
              ),
              actionButton(
                ns("unselect_all_selected"),
                NULL,
                class = "btn btn-sm btn-secondary",
                icon = icon("square"),
                title = "Unselect all rows"
              )
            )
          )
        ),
        # DataTable
        tags$div(
          style = "flex: 1; overflow: auto;",
          DT::DTOutput(ns("selected_general_concepts_table"))
        )
      )
    )
  )
}

#' Use Cases Module - Server
#'
#' @description Server function for the use cases management module
#'
#' @param id Module ID
#' @param data Reactive containing the application data
#' @param vocabularies Reactive containing OHDSI vocabulary data
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive req renderUI observeEvent showModal
#' @importFrom shiny reactiveVal updateTextInput updateTextAreaInput modalDialog
#' @importFrom shiny removeModal
#' @importFrom htmltools tags tagList HTML
#' @importFrom DT renderDT datatable formatStyle styleEqual
#' @importFrom dplyr left_join group_by summarise n filter inner_join select collect
mod_use_cases_server <- function(id, data, vocabularies = reactive({ NULL }), current_user = reactive(NULL)) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    current_view <- reactiveVal("list")  # "list" or "config"
    selected_use_case <- reactiveVal(NULL)
    selected_use_case_row <- reactiveVal(NULL)  # For displaying details
    use_cases_reactive <- reactiveVal(NULL)
    general_concept_use_cases_reactive <- reactiveVal(NULL)

    # Initialize data on load
    observe({
      req(data())
      use_cases_reactive(data()$use_cases)
      general_concept_use_cases_reactive(data()$general_concept_use_cases)
    })

    # Function to update button visibility based on user role
    update_button_visibility <- function() {
      user <- current_user()

      # Use shinyjs::delay to ensure DOM is ready
      shinyjs::delay(100, {
        if (!is.null(user) && user$role != "Anonymous") {
          shinyjs::show("add_use_case_btn")
          shinyjs::show("edit_name_description_btn")
          shinyjs::show("configure_use_case_btn")
          shinyjs::show("delete_selected_btn")
          shinyjs::show("available_action_buttons")
          shinyjs::show("selected_action_buttons")
        } else {
          shinyjs::hide("add_use_case_btn")
          shinyjs::hide("edit_name_description_btn")
          shinyjs::hide("configure_use_case_btn")
          shinyjs::hide("delete_selected_btn")
          shinyjs::hide("available_action_buttons")
          shinyjs::hide("selected_action_buttons")
        }
      })
    }

    # Update visibility when user changes
    observeEvent(current_user(), {
      update_button_visibility()
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    # Update visibility when view changes (page navigation)
    observeEvent(current_view(), {
      update_button_visibility()
    })

    # Update visibility when data is loaded (module initialization)
    observeEvent(data(), {
      update_button_visibility()
    }, once = TRUE)

    # Render breadcrumb navigation
    output$breadcrumb <- renderUI({
      view <- current_view()

      if (view == "list") {
        return(NULL)
      }

      if (view == "config") {
        use_case <- selected_use_case()
        use_case_name <- if (!is.null(use_case)) {
          use_case$name
        } else {
          "Unknown"
        }

        return(
          tags$div(
            class = "breadcrumb-nav",
            style = paste0(
              "padding: 10px 0 15px 0; font-size: 16px; ",
              "display: flex; justify-content: space-between; align-items: center;"
            ),
            # Left side: breadcrumb
            tags$div(
              tags$a(
                href = "#",
                onclick = sprintf(
                  "Shiny.setInputValue('%s', true, {priority: 'event'})",
                  ns("back_to_list")
                ),
                class = "breadcrumb-link",
                style = "font-weight: 600;",
                "Use Cases"
              ),
              tags$span(
                style = "margin: 0 8px; color: #999;",
                ">"
              ),
              tags$span(
                style = "color: #333; font-weight: 600;",
                use_case_name
              )
            )
          )
        )
      }
    })

    # Handle breadcrumb navigation (back to list)
    observeEvent(input$back_to_list, {
      current_view("list")
      selected_use_case(NULL)
    })

    # Render content area based on current view
    output$content_area <- renderUI({
      view <- current_view()

      if (view == "list") {
        render_use_cases_list_ui(ns)
      } else if (view == "config") {
        render_use_case_config_ui(ns)
      }
    })

    # Show add use case modal
    observeEvent(input$add_use_case_btn, {
      shinyjs::runjs(sprintf("$('#%s').show();", ns("add_use_case_modal")))
    })

    # Save new use case
    observeEvent(input$save_use_case, {
      name <- trimws(input$new_use_case_name)
      short_desc <- trimws(input$new_use_case_short_description)

      # Validation
      has_error <- FALSE
      if (name == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("name_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("name_error")))
      }

      if (short_desc == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("short_desc_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("short_desc_error")))
      }

      if (has_error) return()

      # Get current use cases
      use_cases_data <- use_cases_reactive()
      long_desc <- trimws(input$new_use_case_long_description)

      # Create new use case
      new_id <- get_next_use_case_id(use_cases_data)
      new_use_case <- data.frame(
        use_case_id = new_id,
        use_case_name = name,
        short_description = short_desc,
        long_description = if (long_desc == "") NA_character_ else long_desc,
        stringsAsFactors = FALSE
      )

      # Add to use cases
      use_cases_data <- rbind(use_cases_data, new_use_case)

      tryCatch({
        save_use_cases_csv(use_cases_data)
        use_cases_reactive(use_cases_data)
      }, error = function(e) {
      })

      # Close modal and reset
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("add_use_case_modal")))
      updateTextInput(session, "new_use_case_name", value = "")
      updateTextAreaInput(session, "new_use_case_short_description", value = "")
      updateTextAreaInput(session, "new_use_case_long_description", value = "")
    })

    observeEvent(input$edit_name_description_btn, {
      selected_rows <- input$use_cases_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) {
        return()
      }

      if (length(selected_rows) > 1) {
        return()
      }

      # Get selected use case data
      use_cases_data <- use_cases_reactive()
      selected_uc <- use_cases_data[selected_rows, ]

      # Populate edit modal
      updateTextInput(
        session,
        "edit_use_case_name",
        value = selected_uc$use_case_name
      )
      updateTextAreaInput(
        session,
        "edit_use_case_short_description",
        value = ifelse(
          is.na(selected_uc$short_description),
          "",
          selected_uc$short_description
        )
      )
      updateTextAreaInput(
        session,
        "edit_use_case_long_description",
        value = ifelse(
          is.na(selected_uc$long_description),
          "",
          selected_uc$long_description
        )
      )

      # Store the ID for update
      selected_use_case(list(
        id = selected_uc$use_case_id,
        name = selected_uc$use_case_name,
        short_description = selected_uc$short_description,
        long_description = selected_uc$long_description
      ))

      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_use_case_modal")))
    })

    # Update use case button (from edit modal)
    observeEvent(input$update_use_case, {
      name <- trimws(input$edit_use_case_name)
      short_desc <- trimws(input$edit_use_case_short_description)

      # Validation
      has_error <- FALSE
      if (name == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_name_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_name_error")))
      }

      if (short_desc == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("edit_short_desc_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_short_desc_error")))
      }

      if (has_error) return()

      # Get current use case
      use_case <- selected_use_case()
      if (is.null(use_case)) {
        return()
      }

      # Get use cases data
      use_cases_data <- use_cases_reactive()
      long_desc <- trimws(input$edit_use_case_long_description)

      # Update the use case
      use_cases_data$use_case_name[
        use_cases_data$use_case_id == use_case$id
      ] <- name
      use_cases_data$short_description[
        use_cases_data$use_case_id == use_case$id
      ] <- short_desc
      use_cases_data$long_description[
        use_cases_data$use_case_id == use_case$id
      ] <- if (long_desc == "") NA_character_ else long_desc

      tryCatch({
        save_use_cases_csv(use_cases_data)
        use_cases_reactive(use_cases_data)
      }, error = function(e) {
      })

      # Close modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("edit_use_case_modal")))
    })

    # Handle double-click on use case row
    observeEvent(input$dblclick_use_case_id, {
      use_case_id <- input$dblclick_use_case_id
      req(use_case_id)

      # Get use case data by ID
      use_cases_data <- use_cases_reactive()
      selected_uc <- use_cases_data[use_cases_data$use_case_id == use_case_id, ]

      if (nrow(selected_uc) == 1) {
        selected_use_case(list(
          id = selected_uc$use_case_id,
          name = selected_uc$use_case_name,
          short_description = selected_uc$short_description,
          long_description = selected_uc$long_description
        ))
        current_view("config")
      }
    })

    observeEvent(input$configure_use_case_btn, {
      selected_rows <- input$use_cases_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) {
        return()
      }

      if (length(selected_rows) > 1) {
        return()
      }

      # Get selected use case data
      use_cases_data <- use_cases_reactive()
      selected_uc <- use_cases_data[selected_rows, ]

      selected_use_case(list(
        id = selected_uc$use_case_id,
        name = selected_uc$use_case_name,
        short_description = selected_uc$short_description,
        long_description = selected_uc$long_description
      ))
      current_view("config")
    })

    observeEvent(input$delete_selected_btn, {
      selected_rows <- input$use_cases_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) {
        return()
      }

      # Get IDs to delete
      use_cases_data <- use_cases_reactive()
      ids_to_delete <- use_cases_data$use_case_id[selected_rows]

      # Remove from use cases
      use_cases_data <- use_cases_data[
        !use_cases_data$use_case_id %in% ids_to_delete,
      ]

      # Remove from general_concept_use_cases
      gc_uc_data <- general_concept_use_cases_reactive()
      gc_uc_data <- gc_uc_data[
        !gc_uc_data$use_case_id %in% ids_to_delete,
      ]

      tryCatch({
        save_use_cases_csv(use_cases_data)
        save_general_concept_use_cases_csv(gc_uc_data)
        use_cases_reactive(use_cases_data)
        general_concept_use_cases_reactive(gc_uc_data)
      }, error = function(e) {
      })
    })

    # Add general concepts to use case
    observeEvent(input$add_general_concepts_btn, {
      selected_rows <- input$available_general_concepts_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) {
        return()
      }

      # Get selected use case
      use_case <- selected_use_case()
      if (is.null(use_case)) {
        return()
      }

      # Get available general concepts and selected ones
      available_df <- get_available_general_concepts()
      selected_gc_ids <- available_df$general_concept_id[selected_rows]

      # Get current mappings
      gc_uc_data <- general_concept_use_cases_reactive()

      # Create new mappings
      new_mappings <- data.frame(
        use_case_id = rep(use_case$id, length(selected_gc_ids)),
        general_concept_id = selected_gc_ids,
        stringsAsFactors = FALSE
      )

      # Filter out already existing mappings
      existing_pairs <- paste(
        gc_uc_data$use_case_id,
        gc_uc_data$general_concept_id
      )
      new_pairs <- paste(
        new_mappings$use_case_id,
        new_mappings$general_concept_id
      )
      new_mappings <- new_mappings[!new_pairs %in% existing_pairs, ]

      if (nrow(new_mappings) > 0) {
        gc_uc_data <- rbind(gc_uc_data, new_mappings)

        tryCatch({
          save_general_concept_use_cases_csv(gc_uc_data)
          general_concept_use_cases_reactive(gc_uc_data)

          DT::selectRows(DT::dataTableProxy("available_general_concepts_table", session = session), NULL)
        }, error = function(e) {
        })
      }
    })

    # Remove general concepts from use case
    observeEvent(input$remove_general_concepts_btn, {
      selected_rows <- input$selected_general_concepts_table_rows_selected

      if (is.null(selected_rows) || length(selected_rows) == 0) {
        return()
      }

      # Get selected use case
      use_case <- selected_use_case()
      if (is.null(use_case)) {
        return()
      }

      # Get selected general concepts
      selected_df <- get_selected_general_concepts()
      gc_ids_to_remove <- selected_df$general_concept_id[selected_rows]

      gc_uc_data <- general_concept_use_cases_reactive()
      gc_uc_data <- gc_uc_data[!(
        gc_uc_data$general_concept_id %in% gc_ids_to_remove &
          gc_uc_data$use_case_id == use_case$id
      ), ]

      tryCatch({
        save_general_concept_use_cases_csv(gc_uc_data)
        general_concept_use_cases_reactive(gc_uc_data)
      }, error = function(e) {
      })
    })

    # Helper function to get use cases with concept counts
    get_use_cases_with_counts <- reactive({
      use_cases_data <- use_cases_reactive()
      gc_uc_data <- general_concept_use_cases_reactive()

      if (is.null(use_cases_data) || is.null(gc_uc_data)) {
        return(data.frame(
          Name = character(0),
          `Short Description` = character(0),
          Concepts = integer(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Count concepts per use case
      concept_counts <- gc_uc_data %>%
        group_by(use_case_id) %>%
        summarise(concept_count = n(), .groups = "drop")

      # Join with use cases
      result <- use_cases_data %>%
        left_join(concept_counts, by = "use_case_id")

      # Replace NA counts with 0
      result$concept_count[is.na(result$concept_count)] <- 0

      # Format for display (include use_case_id as first column, will be hidden)
      display_df <- data.frame(
        use_case_id = result$use_case_id,
        Name = result$use_case_name,
        `Short Description` = ifelse(
          is.na(result$short_description),
          "",
          result$short_description
        ),
        Concepts = result$concept_count,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )

      return(display_df)
    })

    # Helper function to get available general concepts (excluding already selected ones)
    get_available_general_concepts <- reactive({
      req(data())
      req(selected_use_case())

      general_concepts <- data()$general_concepts
      use_case <- selected_use_case()
      gc_uc_data <- general_concept_use_cases_reactive()

      if (is.null(general_concepts)) {
        return(data.frame(
          general_concept_id = integer(0),
          Category = character(0),
          Subcategory = character(0),
          Concept = character(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Get IDs of concepts already selected for this use case
      selected_gc_ids <- c()
      if (!is.null(gc_uc_data)) {
        selected_gc_ids <- gc_uc_data %>%
          filter(use_case_id == use_case$id) %>%
          .$general_concept_id
      }

      # Filter out already selected concepts
      available_concepts <- general_concepts %>%
        filter(!general_concept_id %in% selected_gc_ids)

      # Format for display with factors for Category and Subcategory
      display_df <- data.frame(
        general_concept_id = available_concepts$general_concept_id,
        Category = factor(available_concepts$category),
        Subcategory = factor(available_concepts$subcategory),
        Concept = available_concepts$general_concept_name,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )

      return(display_df)
    })

    # Helper function to get selected general concepts for current use case
    get_selected_general_concepts <- reactive({
      req(selected_use_case())
      req(data())

      use_case <- selected_use_case()
      general_concepts <- data()$general_concepts
      gc_uc_data <- general_concept_use_cases_reactive()

      if (is.null(gc_uc_data)) {
        return(data.frame(
          general_concept_id = integer(0),
          Category = character(0),
          Subcategory = character(0),
          Concept = character(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Filter general concepts for this use case
      selected_gc_ids <- gc_uc_data %>%
        filter(use_case_id == use_case$id) %>%
        .$general_concept_id

      if (length(selected_gc_ids) == 0) {
        return(data.frame(
          general_concept_id = integer(0),
          Category = character(0),
          Subcategory = character(0),
          Concept = character(0),
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }

      # Get general concept details
      gc_details <- general_concepts %>%
        filter(general_concept_id %in% selected_gc_ids)

      # Format for display with factors for Category and Subcategory
      display_df <- data.frame(
        general_concept_id = gc_details$general_concept_id,
        Category = factor(gc_details$category),
        Subcategory = factor(gc_details$subcategory),
        Concept = gc_details$general_concept_name,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )

      return(display_df)
    })

    # Render use cases table
    output$use_cases_table <- renderDT({
      df <- get_use_cases_with_counts()

      # Create double-click callback
      double_click_js <- JS(sprintf("
        function(settings) {
          var table = this.api();

          // Remove any existing handler to avoid duplicates
          $(table.table().node()).off('dblclick', 'tbody tr');

          // Add double-click handler for table rows
          $(table.table().node()).on('dblclick', 'tbody tr', function() {
            var rowData = table.row(this).data();

            if (rowData && rowData[0]) {
              // Get the use case ID from the first column (hidden)
              var useCaseId = rowData[0];

              // Send the use case ID directly to Shiny
              Shiny.setInputValue('%s', useCaseId, {priority: 'event'});
            }
          });
        }
      ", session$ns("dblclick_use_case_id")))

      datatable(
        df,
        filter = "top",
        selection = "single",
        rownames = FALSE,
        class = "cell-border stripe hover",
        options = list(
          pageLength = 25,
          dom = "tip",
          ordering = TRUE,
          autoWidth = FALSE,
          columnDefs = list(
            list(targets = 0, visible = FALSE)  # Hide use_case_id column
          ),
          language = list(
            emptyTable = "No use cases found. Click 'Add Use Case' to create one."
          ),
          drawCallback = double_click_js
        )
      )
    }, server = FALSE)

    # Update selected use case details when row is selected
    observeEvent(input$use_cases_table_rows_selected, {
      selected_rows <- input$use_cases_table_rows_selected
      if (!is.null(selected_rows) && length(selected_rows) == 1) {
        selected_use_case_row(selected_rows)
      } else {
        selected_use_case_row(NULL)
      }
    })

    # Render use case details panel
    output$use_case_details <- renderUI({
      selected_row <- selected_use_case_row()

      if (is.null(selected_row)) {
        return(
          tags$div(
            style = "text-align: center; padding: 40px; color: #6c757d;",
            tags$i(
              class = "fas fa-info-circle",
              style = "font-size: 48px; margin-bottom: 15px;"
            ),
            tags$p("Select a use case to view its details")
          )
        )
      }

      use_cases_data <- use_cases_reactive()
      selected_uc <- use_cases_data[selected_row, ]

      tagList(
        tags$div(
          style = "margin-bottom: 20px;",
          tags$h5(
            selected_uc$use_case_name,
            style = "color: #0f60af; margin-bottom: 10px; font-weight: 600;"
          ),
          tags$div(
            style = paste0(
              "background: #f8f9fa; padding: 15px; ",
              "border-radius: 6px; margin-bottom: 15px;"
            ),
            tags$strong("Short Description:"),
            tags$p(
              style = "margin-top: 8px; margin-bottom: 0;",
              if (is.na(selected_uc$short_description)) {
                tags$em("No short description")
              } else {
                selected_uc$short_description
              }
            )
          ),
          if (!is.na(selected_uc$long_description) &&
              selected_uc$long_description != "") {
            tags$div(
              style = paste0(
                "background: #fff; padding: 15px; border: 1px solid #dee2e6; ",
                "border-radius: 6px;"
              ),
              tags$strong("Detailed Description:"),
              tags$p(
                style = "margin-top: 8px; margin-bottom: 0; line-height: 1.6;",
                selected_uc$long_description
              )
            )
          }
        )
      )
    })

    # Render available general concepts table
    output$available_general_concepts_table <- renderDT({
      df <- get_available_general_concepts()
      df_display <- df[, -1]  # Remove general_concept_id column

      datatable(
        df_display,
        filter = "top",
        selection = "multiple",
        rownames = FALSE,
        class = "cell-border stripe hover",
        options = list(
          pageLength = 10,
          dom = "tip",
          ordering = TRUE,
          autoWidth = FALSE
        )
      )
    }, server = FALSE)

    # Render selected general concepts table
    output$selected_general_concepts_table <- renderDT({
      df <- get_selected_general_concepts()
      df_display <- df[, -1]  # Remove general_concept_id column

      datatable(
        df_display,
        filter = "top",
        selection = "multiple",
        rownames = FALSE,
        class = "cell-border stripe hover",
        options = list(
          pageLength = 15,
          dom = "tip",
          ordering = TRUE,
          autoWidth = FALSE,
          language = list(
            emptyTable = paste0(
              "No general concepts selected for this use case. ",
              "Select general concepts from the left panel ",
              "and click 'Add Selected Concepts'."
            )
          )
        )
      )
    }, server = FALSE)

    # Select all rows in available general concepts table
    observeEvent(input$select_all_available, {
      df <- get_available_general_concepts()
      if (nrow(df) > 0) {
        DT::selectRows(
          DT::dataTableProxy("available_general_concepts_table", session = session),
          1:nrow(df)
        )
      }
    })

    # Unselect all rows in available general concepts table
    observeEvent(input$unselect_all_available, {
      DT::selectRows(
        DT::dataTableProxy("available_general_concepts_table", session = session),
        NULL
      )
    })

    # Select all rows in selected general concepts table
    observeEvent(input$select_all_selected, {
      df <- get_selected_general_concepts()
      if (nrow(df) > 0) {
        DT::selectRows(
          DT::dataTableProxy("selected_general_concepts_table", session = session),
          1:nrow(df)
        )
      }
    })

    # Unselect all rows in selected general concepts table
    observeEvent(input$unselect_all_selected, {
      DT::selectRows(
        DT::dataTableProxy("selected_general_concepts_table", session = session),
        NULL
      )
    })
  })
}
