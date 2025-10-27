#' Development Tools Module - UI
#'
#' @description UI function for the development tools module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS uiOutput tabsetPanel tabPanel actionButton verbatimTextOutput
#' @importFrom htmltools tags tagList
#' @importFrom shinyAce aceEditor
mod_dev_tools_ui <- function(id) {
  ns <- NS(id)

  tagList(
    div(class = "main-panel",
        div(class = "main-content",
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
                  style = "margin-top: 20px; height: calc(100vh - 140px); display: flex; flex-direction: column;",
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
                        style = "flex: 1; border: 1px solid #dee2e6; border-radius: 6px; overflow: hidden;",
                        shinyAce::aceEditor(
                          ns("r_editor"),
                          mode = "r",
                          theme = "chrome",
                          height = "100%",
                          fontSize = 11,
                          value = "# Query vocabularies using dplyr\n# Example:\nconcept %>% \n  filter(concept_id == 3004249)"
                        ),
                        tags$script(HTML(sprintf("
                          $(document).ready(function() {
                            var editor = ace.edit('%s');

                            // CMD/CTRL + SHIFT + ENTER: Run all code
                            editor.commands.addCommand({
                              name: 'runAllCode',
                              bindKey: {win: 'Ctrl-Shift-Enter', mac: 'Command-Shift-Enter'},
                              exec: function(editor) {
                                $('#%s').click();
                              }
                            });

                            // CMD/CTRL + ENTER: Run selection or current line
                            editor.commands.addCommand({
                              name: 'runSelectionOrLine',
                              bindKey: {win: 'Ctrl-Enter', mac: 'Command-Enter'},
                              exec: function(editor) {
                                var selection = editor.getSelectedText();
                                if (selection) {
                                  // Run selection
                                  Shiny.setInputValue('%s', selection, {priority: 'event'});
                                } else {
                                  // Run current line
                                  var cursor = editor.getCursorPosition();
                                  var line = editor.session.getLine(cursor.row);
                                  Shiny.setInputValue('%s', line, {priority: 'event'});
                                }
                              }
                            });
                          });
                        ", ns("r_editor"), ns("run_code"), ns("run_selection"), ns("run_selection"))))
                      ),
                      tags$div(
                        style = "margin-top: 10px; margin-bottom: 10px; padding: 10px; background: #e6f3ff; border-left: 3px solid #0f60af; border-radius: 4px; font-size: 12px;",
                        tags$strong("Available objects:"),
                        tags$br(),
                        tags$code("concept"), " - OHDSI concept table",
                        tags$br(),
                        tags$code("concept_relationship"), " - OHDSI concept_relationship table",
                        tags$br(),
                        tags$code("concept_ancestor"), " - OHDSI concept_ancestor table"
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
                        style = "flex: 1; overflow: auto; background: white; border: 1px solid #dee2e6; border-radius: 6px; padding: 10px; font-size: 11px;",
                        verbatimTextOutput(ns("code_results"))
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
#' @importFrom shiny moduleServer reactive req renderUI observeEvent renderPrint
#' @importFrom DT renderDT datatable DTOutput
#' @importFrom dplyr filter summarise n select
#' @importFrom htmltools tags HTML
mod_dev_tools_server <- function(id, data, vocabularies) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Data Quality output
    output$data_quality_output <- renderUI({
      req(data())

      general_concepts <- data()$general_concepts
      total_concepts <- nrow(general_concepts)

      # Count missing comments
      missing_comments <- sum(is.na(general_concepts$comments) | general_concepts$comments == "")
      pct_missing_comments <- round(missing_comments / total_concepts * 100, 1)

      # Count recommended concepts that are not standard
      vocab_data <- vocabularies()
      concept_mappings <- data()$concept_mappings

      if (!is.null(vocab_data) && !is.null(vocab_data$concept) && !is.null(concept_mappings)) {
        # Get concept data from vocabularies (may be lazy dplyr::tbl)
        concept_standard <- vocab_data$concept %>%
          dplyr::select(concept_id, standard_concept) %>%
          dplyr::collect()

        # Get recommended concepts from mappings
        recommended_mappings <- concept_mappings %>%
          dplyr::filter(recommended == TRUE, !is.na(omop_concept_id))

        recommended_non_standard <- recommended_mappings %>%
          dplyr::left_join(
            concept_standard,
            by = c("omop_concept_id" = "concept_id")
          ) %>%
          dplyr::filter(is.na(standard_concept) | standard_concept != "S") %>%
          nrow()

        total_recommended <- sum(concept_mappings$recommended == TRUE, na.rm = TRUE)
        pct_recommended_non_standard <- if (total_recommended > 0) {
          round(recommended_non_standard / total_recommended * 100, 1)
        } else {
          0
        }
      } else {
        recommended_non_standard <- NA
        total_recommended <- NA
        pct_recommended_non_standard <- NA
      }

      tags$div(
        style = "display: flex; gap: 20px; height: calc(100vh - 140px);",

        # Left side: Summary cards
        tags$div(
          style = "flex: 0 0 50%; display: flex; flex-wrap: wrap; gap: 20px; align-content: flex-start;",

          # Card 1: Comments
          tags$div(
            style = "flex: 0 0 calc(50% - 10px); background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); border-left: 4px solid #ffc107;",
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
          ),

          # Card 3: Recommended Non-Standard
          tags$div(
            style = "flex: 0 0 calc(50% - 10px); background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); border-left: 4px solid #17a2b8;",
            tags$div(
              style = "font-size: 14px; color: #666; margin-bottom: 8px;",
              "Recommended Non-Standard"
            ),
            if (!is.na(recommended_non_standard)) {
              tagList(
                tags$div(
                  style = "font-size: 32px; font-weight: 700; color: #17a2b8; margin-bottom: 5px;",
                  paste0(recommended_non_standard, " / ", total_recommended)
                ),
                tags$div(
                  style = "font-size: 18px; color: #999;",
                  paste0(pct_recommended_non_standard, "%")
                )
              )
            } else {
              tags$div(
                style = "font-size: 14px; color: #999; font-style: italic;",
                "Vocabularies not loaded"
              )
            }
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
                id = ns("tab_missing_comments"),
                onclick = sprintf("Shiny.setInputValue('%s', 'missing_comments', {priority: 'event'})", ns("switch_data_quality_tab")),
                "Missing Comments"
              ),
              tags$button(
                class = "tab-btn",
                id = ns("tab_recommended_non_standard"),
                onclick = sprintf("Shiny.setInputValue('%s', 'recommended_non_standard', {priority: 'event'})", ns("switch_data_quality_tab")),
                "Recommended Non-Standard"
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
    data_quality_tab <- reactiveVal("missing_comments")

    # Observe tab switching
    observeEvent(input$switch_data_quality_tab, {
      data_quality_tab(input$switch_data_quality_tab)
    })

    # Render data quality table based on active tab
    output$data_quality_table_output <- renderUI({
      active_tab <- data_quality_tab()

      if (active_tab == "missing_comments") {
        DT::DTOutput(ns("missing_comments_table"))
      } else if (active_tab == "recommended_non_standard") {
        DT::DTOutput(ns("recommended_non_standard_table"))
      }
    })

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

    # Table of recommended non-standard concepts
    output$recommended_non_standard_table <- DT::renderDT({
      req(data())
      vocab_data <- vocabularies()
      req(vocab_data)
      req(vocab_data$concept)

      # Get concept data (may be lazy dplyr::tbl)
      concept_data <- vocab_data$concept %>%
        dplyr::select(concept_id, standard_concept) %>%
        dplyr::collect()

      # Get recommended mappings
      concept_mappings <- data()$concept_mappings
      recommended_mappings <- concept_mappings %>%
        dplyr::filter(recommended == TRUE, !is.na(omop_concept_id)) %>%
        dplyr::select(general_concept_id, concept_name, omop_concept_id)

      # Join with concept data to check standard status
      recommended_with_standard <- recommended_mappings %>%
        dplyr::left_join(
          concept_data,
          by = c("omop_concept_id" = "concept_id")
        ) %>%
        dplyr::filter(is.na(standard_concept) | standard_concept != "S")

      # Join with general_concepts to get category/subcategory info
      non_standard_data <- recommended_with_standard %>%
        dplyr::left_join(
          data()$general_concepts %>%
            dplyr::select(general_concept_id, category, subcategory, general_concept_name),
          by = "general_concept_id"
        ) %>%
        dplyr::select(category, subcategory, general_concept_name, concept_name, omop_concept_id, standard_concept)

      DT::datatable(
        non_standard_data,
        rownames = FALSE,
        options = list(
          pageLength = 25,
          dom = 'ftp',
          columnDefs = list(
            list(targets = 0, width = "120px"),
            list(targets = 1, width = "120px"),
            list(targets = 2, width = "150px"),
            list(targets = 3, width = "150px")
          )
        ),
        colnames = c("Category", "Subcategory", "General Concept", "OMOP Concept Name", "OMOP Concept ID", "Standard")
      )
    }, server = FALSE)

    # Reactive value to store code results
    code_result <- reactiveVal(NULL)
    code_status <- reactiveVal("initial")  # "initial", "success", "error", "no_code", "no_vocab"
    code_error_msg <- reactiveVal("")

    # Code results output
    output$code_results <- renderPrint({
      status <- code_status()

      if (status == "initial") {
        cat("Run code to see results here")
      } else if (status == "no_code") {
        cat("Warning: Please enter R code to execute.")
      } else if (status == "no_vocab") {
        cat("Error: OHDSI vocabularies not loaded.")
      } else if (status == "error") {
        cat("Error:\n")
        cat(code_error_msg())
      } else if (status == "success") {
        result <- code_result()
        print(result)
      }
    })

    # Execute R code
    # Helper function to execute code
    execute_code <- function(code) {
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
    }

    # Run all code (button click or Ctrl/Cmd + Shift + Enter)
    observeEvent(input$run_code, {
      code <- input$r_editor
      execute_code(code)
    })

    # Run selection or current line (Ctrl/Cmd + Enter)
    observeEvent(input$run_selection, {
      code <- input$run_selection
      execute_code(code)
    })
  })
}
