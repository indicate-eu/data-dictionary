#' Dictionary Explorer Module - UI
#'
#' @description UI function for the dictionary explorer module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS fluidRow h3 h4 hr uiOutput
#' @importFrom DT DTOutput
#' @importFrom htmltools tags
mod_dictionary_explorer_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Main application content
    div(class = "main-panel",
        div(class = "main-content",

            # Summary table section
            fluidRow(
              column(12,
                     div(class = "section-header",
                         h3("General Concepts")
                     ),
                     div(class = "table-container summary-container",
                         DTOutput(ns("summary_table"))
                     )
              )
            ),

            hr(),

            # Details section
            fluidRow(class = "lower-section",
                     # Left column: concept list and comments
                     column(6,
                            div(class = "section-header",
                                h3("Concepts List")
                            ),
                            div(class = "table-container details-tables-container",
                                DTOutput(ns("details_table"))
                            ),

                            # Comments section
                            div(class = "comments-section",
                                div(class = "section-header",
                                    h4("Comments")
                                ),
                                div(class = "comments-container",
                                    tags$i(class = "fas fa-info-circle info-icon"),
                                    uiOutput(ns("comments_output"), style = "height: 100%;")
                                )
                            ),
                            style = "height: 100%; overflow: auto;"
                     ),

                     # Right column: detailed concept view
                     column(6, class = "detailed-view-column",
                            div(class = "section-header",
                                h4("Selected Concept Details")
                            ),
                            div(class = "glimpse-container",
                                uiOutput(ns("glimpse_output"))
                            )
                     )
            )
        )
    )
  )
}

#' Dictionary Explorer Module - Server
#'
#' @description Server function for the dictionary explorer module
#'
#' @param id Module ID
#' @param data Reactive containing the main data dictionary
#' @param comments Reactive containing comments data
#' @param config Configuration list
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive req renderUI
#' @importFrom DT renderDT datatable formatStyle
#' @importFrom dplyr filter group_by summarize mutate select slice across
#' @importFrom magrittr %>%
#' @importFrom htmltools HTML tags
#' @importFrom htmlwidgets JS
mod_dictionary_explorer_server <- function(id, data, comments, config) {
  moduleServer(id, function(input, output, session) {

    # Load JavaScript callbacks
    callback <- JS(paste(readLines(app_sys("www", "dt_callback.js")), collapse = "\n"))
    keyboard_nav <- paste(readLines(app_sys("www", "keyboard_nav.js")), collapse = "\n")

    # Reactive Data Processing

    # Aggregate data for summary table
    aggregated_data <- reactive({
      data() %>%
        group_by(category, subcategory, general_concept_name) %>%
        summarize(
          uc1 = ifelse(any(uc1, na.rm = TRUE), TRUE, FALSE),
          uc2 = ifelse(any(uc2, na.rm = TRUE), TRUE, FALSE),
          uc3 = ifelse(any(uc3, na.rm = TRUE), TRUE, FALSE),
          uc4 = ifelse(any(uc4, na.rm = TRUE), TRUE, FALSE),
          uc5 = ifelse(any(uc5, na.rm = TRUE), TRUE, FALSE),
          uc6 = ifelse(any(uc6, na.rm = TRUE), TRUE, FALSE),
          .groups = 'drop'
        ) %>%
        mutate(across(starts_with("uc"), ~ factor(.x, levels = c(TRUE, FALSE))))
    })

    # Extract selected row from summary table
    selected_category_row <- reactive({
      req(input$summary_table_rows_selected)
      idx <- input$summary_table_rows_selected[1]
      aggregated_data()[idx, ]
    })

    # Filter detailed concepts based on summary table selection
    filtered_details <- reactive({
      req(selected_category_row())
      selected <- selected_category_row()

      data() %>%
        filter(
          category == selected$category,
          subcategory == selected$subcategory,
          general_concept_name == selected$general_concept_name
        ) %>%
        select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended)
    })

    # Extract selected row from details table
    selected_detail_row <- reactive({
      req(input$details_table_rows_selected)
      req(filtered_details())

      idx <- input$details_table_rows_selected[1]
      selected_concept <- filtered_details()[idx, ]
      concept_id <- selected_concept$omop_concept_id

      # Find the matching row from original data (ensure single row)
      data() %>%
        filter(omop_concept_id == concept_id) %>%
        slice(1)
    })

    # Output Rendering

    # Render summary table
    output$summary_table <- renderDT({
      dt_data <- aggregated_data()

      datatable(
        dt_data,
        rownames = FALSE,
        selection = 'none',
        filter = 'top',
        extensions = c('Select'),
        colnames = c("Category", "Sub-category", "General Concept Name",
                     "Use case 1", "Use case 2", "Use case 3",
                     "Use case 4", "Use case 5", "Use case 6"),
        options = list(
          pageLength = 10,
          lengthMenu = list(c(5, 10, 15, 20, 50, 100, -1),
                            c('5', '10', '15', '20', '50', '100', 'All')),
          dom = "ltp",
          columnDefs = list(
            list(targets = c(0, 1, 2), searchable = TRUE),
            list(targets = c(3, 4, 5, 6, 7, 8), width = "80px", className = 'dt-center')
          ),
          select = list(style = 'single', info = FALSE),
          initComplete = create_keyboard_nav(keyboard_nav, TRUE, TRUE)
        ),
        callback = callback
      ) %>%
        formatStyle(
          columns = c('uc1', 'uc2', 'uc3', 'uc4', 'uc5', 'uc6'),
          valueColumns = c('uc1', 'uc2', 'uc3', 'uc4', 'uc5', 'uc6'),
          target = 'cell',
          render = JS("
          function(data, type, row, meta) {
            if (type === 'display') {
              if (data === 'TRUE') {
                return '<span style=\"color: #28a745; font-weight: bold;\">TRUE</span>';
              } else {
                return '<span style=\"color: #dc3545; font-weight: bold;\">FALSE</span>';
              }
            }
            return data;
          }")
        )
    }, server = FALSE)

    # Render details table
    output$details_table <- renderDT({
      datatable(
        filtered_details() %>% mutate(across("recommended", toupper)),
        options = list(
          pageLength = 5,
          dom = "tp",
          select = list(style = 'single', info = FALSE),
          columnDefs = list(
            list(targets = 3, visible = FALSE)
          ),
          initComplete = create_keyboard_nav(keyboard_nav, FALSE, FALSE)
        ),
        selection = 'none',
        rownames = FALSE,
        colnames = c("Concept Name", "Vocabulary ID", "Concept Code",
                     "OMOP Concept ID", "Recommended"),
        extensions = c('Select'),
        callback = callback
      )
    }, server = FALSE)

    # Render detailed view of selected concept
    output$glimpse_output <- renderUI({
      req(selected_detail_row())
      row_data <- selected_detail_row()

      # Validate single row
      if (nrow(row_data) != 1) {
        return(div("Error: Multiple or no concepts selected"))
      }

      # Define columns to skip and pretty names
      cols_to_skip <- c("uc1", "uc2", "uc3", "uc4", "uc5", "uc6",
                        "source_sheet", "data_type", "omop_domain_id",
                        "omop_table", "omop_column")

      pretty_names <- list(
        "concept_name" = "Selected Concept Name",
        "general_concept_name" = "General Concept Name",
        "vocabulary_id" = "Vocabulary ID",
        "concept_code" = "Concept Code",
        "omop_concept_id" = "OMOP Concept ID",
        "unit_concept_name" = "Unit Concept Name",
        "omop_unit_concept_id" = "OMOP Unit Concept ID",
        "recommended" = "Recommended",
        "category" = "Category",
        "subcategory" = "Sub-category",
        "ehden_rows_count" = "EHDEN Rows Count",
        "ehden_num_data_sources" = "EHDEN Data Sources",
        "loinc_rank" = "LOINC Rank"
      )

      # Define display order
      display_order <- c(
        "general_concept_name", "concept_name", "category", "subcategory",
        "vocabulary_id", "concept_code", "omop_concept_id",
        "unit_concept_name", "omop_unit_concept_id", "ehden_rows_count",
        "ehden_num_data_sources", "loinc_rank", "recommended"
      )

      remaining_cols <- setdiff(names(row_data), c(display_order, cols_to_skip))
      display_order <- c(display_order, remaining_cols)

      # Build URLs
      fhir_url <- build_fhir_url(row_data$vocabulary_id, row_data$concept_code, config)
      athena_url <- paste0(config$athena_base_url, "/", row_data$omop_concept_id)
      athena_unit_url <- paste0(config$athena_base_url, "/", row_data$omop_unit_concept_id)
      unit_fhir_url <- build_unit_fhir_url(row_data$unit_concept_name, config)

      # Build table rows
      table_rows <- list()

      for (col in display_order) {
        if (!(col %in% cols_to_skip)) {
          val <- row_data[[col]]
          val_str <- if(is.factor(val)) as.character(val) else format(val, trim=TRUE)

          if(nchar(val_str) > 50) {
            val_str <- paste0(substr(val_str, 1, 50), "...")
          }

          display_name <- if(col %in% names(pretty_names)) pretty_names[[col]] else col

          # Create table row based on column type
          if(col == "omop_concept_id") {
            val_display <- create_link(athena_url, val_str)
            table_rows <- append(table_rows, list(
              tags$tr(
                tags$td(style="padding-right: 15px; color: #0f60af; font-weight: 600;", display_name),
                tags$td(val_display)
              )
            ))

            if (!is.null(fhir_url)) {
              table_rows <- append(table_rows, list(
                tags$tr(
                  tags$td(style="padding-right: 15px; color: #0f60af; font-weight: 600;", "FHIR Resource"),
                  tags$td(create_link(fhir_url, "View FHIR Resource"))
                )
              ))
            }

          } else if(col == "omop_unit_concept_id") {
            if (!is.na(val_str) && val_str != "/" && val_str != "") {
              val_display <- create_link(athena_unit_url, val_str)
            } else {
              val_display <- val_str
            }

            table_rows <- append(table_rows, list(
              tags$tr(
                tags$td(style="padding-right: 15px; color: #0f60af; font-weight: 600;", display_name),
                tags$td(val_display)
              )
            ))

            unit_fhir_display <- if (!is.null(unit_fhir_url)) {
              create_link(unit_fhir_url, "View Unit FHIR Resource")
            } else {
              "/"
            }

            table_rows <- append(table_rows, list(
              tags$tr(
                tags$td(style="padding-right: 15px; color: #0f60af; font-weight: 600;", "Unit FHIR Resource"),
                tags$td(unit_fhir_display)
              )
            ))

          } else if(col == "recommended") {
            recommended_style <- if(val) {
              "color: #28a745; font-weight: bold;"
            } else {
              "color: #dc3545; font-weight: bold;"
            }

            table_rows <- append(table_rows, list(
              tags$tr(
                tags$td(style="padding-right: 15px; color: #0f60af; font-weight: 600;", display_name),
                tags$td(style=recommended_style, val_str)
              )
            ))

          } else if(col %in% c("vocabulary_id", "concept_code")) {
            table_rows <- append(table_rows, list(
              tags$tr(
                tags$td(style="padding-right: 15px; color: #0f60af; font-weight: 600;", display_name),
                tags$td(style="font-weight: bold;", val_str)
              )
            ))

          } else {
            table_rows <- append(table_rows, list(
              tags$tr(
                tags$td(style="padding-right: 15px; color: #0f60af; font-weight: 600;", display_name),
                tags$td(val_str)
              )
            ))
          }
        }
      }

      # Return formatted table
      tags$div(
        style="font-family: 'Consolas', monospace; font-size: 12px; line-height: 1.4;",
        tags$table(
          style="width: 100%; border-collapse: separate; border-spacing: 0 4px;",
          table_rows
        )
      )
    })

    # Render comments
    output$comments_output <- renderUI({
      req(selected_category_row())
      selected <- selected_category_row()

      comment_row <- comments() %>%
        filter(
          tolower(category) == tolower(as.character(selected$category)),
          tolower(general_concept_name) == tolower(selected$general_concept_name)
        )

      comment_text <- if (nrow(comment_row) > 0) {
        comment_row$comments[1]
      } else {
        "No comments available for this concept."
      }

      HTML(comment_text)
    })
  })
}
