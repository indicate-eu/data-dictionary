#' Development Tools Module - UI
#'
#' @description UI function for the development tools module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS uiOutput tabsetPanel tabPanel actionButton
#' @importFrom htmltools tags tagList
#' @importFrom shinyAce aceEditor
mod_dev_tools_ui <- function(id) {
  ns <- NS(id)

  tagList(
    div(class = "main-panel",
        div(class = "main-content",
            tags$div(
              style = "padding: 10px 0 15px 0; font-size: 16px; color: #0f60af; font-weight: 600;",
              tags$span("Development Tools")
            ),

            tabsetPanel(
              id = ns("dev_tabs"),

              # Data Quality tab
              tabPanel(
                "Data Quality",
                value = "data_quality",
                tags$div(
                  style = "margin-top: 20px;",
                  uiOutput(ns("data_quality_output"))
                )
              ),

              # R Console tab
              tabPanel(
                "R Console",
                value = "r_console",
                tags$div(
                  style = "margin-top: 20px; height: calc(100vh - 240px); display: flex; flex-direction: column;",
                  tags$div(
                    style = "display: flex; gap: 15px; height: 100%;",
                    # Left: Editor
                    tags$div(
                      style = "flex: 1; display: flex; flex-direction: column;",
                      tags$div(
                        class = "section-header",
                        tags$h4("R Code")
                      ),
                      tags$div(
                        style = "margin-bottom: 10px; padding: 10px; background: #e6f3ff; border-left: 3px solid #0f60af; border-radius: 4px; font-size: 12px;",
                        tags$strong("Available objects:"),
                        tags$br(),
                        tags$code("concept"), " - OHDSI concept table",
                        tags$br(),
                        tags$code("concept_relationship"), " - OHDSI concept_relationship table",
                        tags$br(),
                        tags$code("concept_ancestor"), " - OHDSI concept_ancestor table"
                      ),
                      tags$div(
                        style = "flex: 1; border: 1px solid #dee2e6; border-radius: 6px; overflow: hidden;",
                        shinyAce::aceEditor(
                          ns("r_editor"),
                          mode = "r",
                          theme = "chrome",
                          height = "100%",
                          fontSize = 12,
                          value = "# Query vocabularies using dplyr\n# Example:\nconcept %>% \n  filter(concept_id == 3004249)"
                        )
                      ),
                      tags$div(
                        style = "margin-top: 10px;",
                        actionButton(ns("run_code"), "Run Code", class = "btn-primary")
                      )
                    ),
                    # Right: Results
                    tags$div(
                      style = "flex: 1; display: flex; flex-direction: column;",
                      tags$div(
                        class = "section-header",
                        tags$h4("Results")
                      ),
                      tags$div(
                        style = "flex: 1; overflow: auto; background: white; border: 1px solid #dee2e6; border-radius: 6px; padding: 10px;",
                        uiOutput(ns("code_results"))
                      )
                    )
                  )
                )
              )
            )
        )
    )
  )
}

#' Development Tools Module - Server
#'
#' @description Server function for the development tools module
#'
#' @param id Module ID
#' @param data Reactive containing the CSV data
#' @param vocabularies Reactive containing preloaded OHDSI vocabularies
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive req renderUI observeEvent
#' @importFrom DT renderDT datatable DTOutput
#' @importFrom dplyr filter summarise n select
#' @importFrom htmltools tags HTML
#' @importFrom DBI dbConnect dbDisconnect dbWriteTable dbGetQuery
#' @importFrom RSQLite SQLite
mod_dev_tools_server <- function(id, data, vocabularies) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Data Quality output
    output$data_quality_output <- renderUI({
      req(data())

      general_concepts <- data()$general_concepts

      # Count missing athena_concept_id
      missing_athena <- sum(is.na(general_concepts$athena_concept_id))
      total_concepts <- nrow(general_concepts)
      pct_missing_athena <- round(missing_athena / total_concepts * 100, 1)

      # Count missing comments
      missing_comments <- sum(is.na(general_concepts$comments) | general_concepts$comments == "")
      pct_missing_comments <- round(missing_comments / total_concepts * 100, 1)

      tags$div(
        style = "display: flex; gap: 20px; height: calc(100vh - 260px);",

        # Left side: Summary cards
        tags$div(
          style = "width: 50%; flex-shrink: 0; display: flex; flex-direction: column; gap: 20px;",

          # Card 1: Athena Concept ID
          tags$div(
            style = "background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); border-left: 4px solid #dc3545;",
            tags$div(
              style = "font-size: 14px; color: #666; margin-bottom: 8px;",
              "Missing Athena Concept ID"
            ),
            tags$div(
              style = "font-size: 32px; font-weight: 700; color: #dc3545; margin-bottom: 5px;",
              paste0(missing_athena, " / ", total_concepts)
            ),
            tags$div(
              style = "font-size: 18px; color: #999;",
              paste0(pct_missing_athena, "%")
            )
          ),

          # Card 2: Comments
          tags$div(
            style = "background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); border-left: 4px solid #ffc107;",
            tags$div(
              style = "font-size: 14px; color: #666; margin-bottom: 8px;",
              "Missing Comments"
            ),
            tags$div(
              style = "font-size: 32px; font-weight: 700; color: #ffc107; margin-bottom: 5px;",
              paste0(missing_comments, " / ", total_concepts)
            ),
            tags$div(
              style = "font-size: 18px; color: #999;",
              paste0(pct_missing_comments, "%")
            )
          )
        ),

        # Right side: Detailed table with tabs
        tags$div(
          style = "flex: 1; display: flex; flex-direction: column; min-width: 0;",
          tags$div(
            class = "section-header section-header-with-tabs",
            tags$h4("Missing Data Details"),
            tags$div(
              class = "section-tabs",
              tags$button(
                class = "tab-btn tab-btn-active",
                id = ns("tab_missing_athena"),
                onclick = sprintf("Shiny.setInputValue('%s', 'missing_athena', {priority: 'event'})", ns("switch_data_quality_tab")),
                "Missing Athena ID"
              ),
              tags$button(
                class = "tab-btn",
                id = ns("tab_missing_comments"),
                onclick = sprintf("Shiny.setInputValue('%s', 'missing_comments', {priority: 'event'})", ns("switch_data_quality_tab")),
                "Missing Comments"
              )
            )
          ),
          tags$div(
            style = "flex: 1; margin-top: 10px; overflow: auto; background: white; border-radius: 6px; padding: 10px;",
            uiOutput(ns("data_quality_table_output"))
          )
        )
      )
    })

    # Track active data quality tab
    data_quality_tab <- reactiveVal("missing_athena")

    # Observe tab switching
    observeEvent(input$switch_data_quality_tab, {
      data_quality_tab(input$switch_data_quality_tab)
    })

    # Render data quality table based on active tab
    output$data_quality_table_output <- renderUI({
      active_tab <- data_quality_tab()

      if (active_tab == "missing_athena") {
        DT::DTOutput(ns("missing_athena_table"))
      } else {
        DT::DTOutput(ns("missing_comments_table"))
      }
    })

    # Table of concepts missing athena_concept_id
    output$missing_athena_table <- DT::renderDT({
      req(data())

      missing_data <- data()$general_concepts %>%
        dplyr::filter(is.na(athena_concept_id)) %>%
        dplyr::select(category, subcategory, general_concept_name)

      DT::datatable(
        missing_data,
        rownames = FALSE,
        options = list(
          pageLength = 25,
          dom = 'ftp',
          columnDefs = list(
            list(targets = 0, width = "150px"),
            list(targets = 1, width = "150px")
          )
        ),
        colnames = c("Category", "Subcategory", "General Concept Name")
      )
    }, server = FALSE)

    # Table of concepts missing comments
    output$missing_comments_table <- DT::renderDT({
      req(data())

      missing_data <- data()$general_concepts %>%
        dplyr::filter(is.na(comments) | comments == "") %>%
        dplyr::select(category, subcategory, general_concept_name)

      DT::datatable(
        missing_data,
        rownames = FALSE,
        options = list(
          pageLength = 25,
          dom = 'ftp',
          columnDefs = list(
            list(targets = 0, width = "150px"),
            list(targets = 1, width = "150px")
          )
        ),
        colnames = c("Category", "Subcategory", "General Concept Name")
      )
    }, server = FALSE)

    # Reactive value to store code results
    code_result <- reactiveVal(NULL)
    code_status <- reactiveVal("initial")  # "initial", "success", "error", "no_code", "no_vocab"
    code_error_msg <- reactiveVal("")

    # Code results UI
    output$code_results <- renderUI({
      status <- code_status()

      if (status == "initial") {
        return(tags$div(
          style = "padding: 20px; text-align: center; color: #999; font-style: italic;",
          "Run code to see results here"
        ))
      } else if (status == "no_code") {
        return(tags$div(
          style = "padding: 20px; background: #fff3cd; border: 1px solid #ffc107; border-radius: 6px; color: #856404;",
          tags$strong("Warning: "),
          "Please enter R code to execute."
        ))
      } else if (status == "no_vocab") {
        return(tags$div(
          style = "padding: 20px; background: #f8d7da; border: 1px solid #dc3545; border-radius: 6px; color: #721c24;",
          tags$strong("Error: "),
          "OHDSI vocabularies not loaded."
        ))
      } else if (status == "error") {
        return(tags$div(
          style = "padding: 20px; background: #f8d7da; border: 1px solid #dc3545; border-radius: 6px; color: #721c24;",
          tags$strong("Error: "),
          tags$pre(
            style = "margin-top: 10px; background: #fff; padding: 10px; border-radius: 4px; overflow-x: auto;",
            code_error_msg()
          )
        ))
      } else if (status == "success") {
        result <- code_result()
        if (is.data.frame(result)) {
          return(DT::DTOutput(ns("code_table")))
        } else {
          # For non-data.frame results, show as text
          return(tags$div(
            tags$div(
              style = "margin-bottom: 10px; color: #28a745; font-weight: 600;",
              sprintf("Result (class: %s)", paste(class(result), collapse = ", "))
            ),
            tags$pre(
              style = "background: #f8f9fa; padding: 15px; border-radius: 4px; overflow-x: auto; max-height: 600px;",
              paste(capture.output(print(result)), collapse = "\n")
            )
          ))
        }
      }
    })

    # Render code result table
    output$code_table <- DT::renderDT({
      result <- code_result()
      req(result)
      req(is.data.frame(result))

      DT::datatable(
        result,
        rownames = FALSE,
        options = list(
          pageLength = 25,
          dom = 'ftp',
          scrollX = TRUE
        )
      )
    }, server = FALSE)

    # Execute R code
    observeEvent(input$run_code, {
      code <- input$r_editor

      if (is.null(code) || nchar(trimws(code)) == 0) {
        code_status("no_code")
        return()
      }

      vocab_data <- vocabularies()

      if (is.null(vocab_data)) {
        code_status("no_vocab")
        return()
      }

      # Execute code
      tryCatch({
        # Make vocabularies available as objects
        concept <- vocab_data$concept
        concept_relationship <- vocab_data$concept_relationship
        concept_ancestor <- vocab_data$concept_ancestor

        # Evaluate the code
        result <- eval(parse(text = code))

        # Store results
        code_result(result)
        code_status("success")

      }, error = function(e) {
        code_error_msg(as.character(e$message))
        code_status("error")
      })
    })
  })
}
