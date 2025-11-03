# MODULE STRUCTURE OVERVIEW ====
#
# This module provides development and debugging tools for the application
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Data Quality Tab - Data quality metrics and detailed tables
#      ### R Console Tab - Interactive R code editor and results
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Data Quality Tab State - Track active data quality tab
#      ### Code Execution State - Manage code execution and results
#
#   ## 2) Server - Data Quality
#      ### Data Quality Overview - Render summary cards
#      ### Data Quality Tab Switching - Handle tab navigation
#      ### Data Quality Tables - Render detailed data tables
#
#   ## 3) Server - R Console
#      ### Code Results Display - Render code execution results
#      ### Code Execution - Execute R code and handle errors

# UI SECTION ====

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
    ## UI - Main Layout ----
    div(class = "main-panel",
        div(class = "main-content",
            tabsetPanel(
              id = ns("dev_tabs"),

              ### Data Quality Tab ----
              tabPanel(
                "Data Quality",
                value = "data_quality",
                tags$div(
                  style = "margin-top: 20px;",
                  uiOutput(ns("data_quality_output"))
                )
              ),

              ### R Console Tab ----
              tabPanel(
                "R Console",
                value = "r_console",
                tags$div(
                  style = "margin-top: 20px; height: calc(100vh - 185px); display: flex; flex-direction: column;",
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
                        style = paste0(
                          "flex: 1; border: 1px solid #dee2e6; ",
                          "border-radius: 6px; overflow: hidden;"
                        ),
                        shinyAce::aceEditor(
                          ns("r_editor"),
                          mode = "r",
                          theme = "chrome",
                          height = "100%",
                          fontSize = 11,
                          value = paste(
                            "# Query vocabularies using dplyr",
                            "# Example:",
                            "concept %>%",
                            "  filter(concept_id == 3004249)",
                            sep = "\n"
                          ),
                          hotkeys = list(
                            runAllKey = list(
                              win = "Ctrl-Shift-Enter",
                              mac = "Command-Shift-Enter"
                            ),
                            runSelectionKey = list(
                              win = "Ctrl-Enter",
                              mac = "Command-Enter"
                            )
                          )
                        )
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

# SERVER SECTION ====

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
mod_dev_tools_server <- function(id, data, vocabularies, log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ## 1) Server - Reactive Values & State ----

    ### Data Quality Tab State ----
    data_quality_tab <- reactiveVal("missing_comments")

    ### Code Execution State ----
    code_result <- reactiveVal(NULL)
    code_status <- reactiveVal("initial")
    code_error_msg <- reactiveVal("")

    ## 2) Server - Data Quality ----

    ### Data Quality Overview ----
    data_quality_trigger <- reactiveVal(0)

    observe_event(data(), {
      if (is.null(data())) return()
      data_quality_trigger(data_quality_trigger() + 1)
    }, ignoreInit = FALSE)

    # Data Quality output
    observe_event(data_quality_trigger(), {
      if (is.null(data())) return()

      general_concepts <- data()$general_concepts
      total_concepts <- nrow(general_concepts)

      # Count missing comments
      missing_comments <- sum(is.na(general_concepts$comments) |
                             general_concepts$comments == "")
      pct_missing_comments <- round(missing_comments / total_concepts * 100, 1)

      # Count recommended concepts that are not standard
      vocab_data <- vocabularies()
      concept_mappings <- data()$concept_mappings

      if (!is.null(vocab_data) && !is.null(vocab_data$concept) &&
          !is.null(concept_mappings)) {
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
          dplyr::filter(is.na(standard_concept) |
                       standard_concept != "S") %>%
          nrow()

        total_recommended <- sum(concept_mappings$recommended == TRUE,
                                na.rm = TRUE)
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

      output$data_quality_output <- renderUI({
        tags$div(
        style = "display: flex; gap: 20px; height: calc(100vh - 185px);",

        # Left side: Summary cards
        tags$div(
          style = paste0(
            "flex: 0 0 50%; display: flex; flex-wrap: wrap; ",
            "gap: 20px; align-content: flex-start;"
          ),

          # Card 1: Comments
          tags$div(
            style = paste0(
              "flex: 0 0 calc(50% - 10px); background: white; ",
              "border-radius: 8px; padding: 20px; ",
              "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
              "border-left: 4px solid #ffc107;"
            ),
            tags$div(
              style = "font-size: 14px; color: #666; margin-bottom: 8px;",
              "Missing Comments"
            ),
            tags$div(
              style = paste0(
                "font-size: 32px; font-weight: 700; color: #ffc107; ",
                "margin-bottom: 5px;"
              ),
              paste0(missing_comments, " / ", total_concepts)
            ),
            tags$div(
              style = "font-size: 18px; color: #999;",
              paste0(pct_missing_comments, "%")
            )
          ),

          # Card 3: Recommended Non-Standard
          tags$div(
            style = paste0(
              "flex: 0 0 calc(50% - 10px); background: white; ",
              "border-radius: 8px; padding: 20px; ",
              "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
              "border-left: 4px solid #17a2b8;"
            ),
            tags$div(
              style = "font-size: 14px; color: #666; margin-bottom: 8px;",
              "Recommended Non-Standard"
            ),
            if (!is.na(recommended_non_standard)) {
              tagList(
                tags$div(
                  style = paste0(
                    "font-size: 32px; font-weight: 700; color: #17a2b8; ",
                    "margin-bottom: 5px;"
                  ),
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
          style = paste0(
            "flex: 1; display: flex; flex-direction: column; ",
            "min-width: 0;"
          ),
          tags$div(
            class = "section-header section-header-with-tabs",
            tags$h4("Missing Data Details"),
            tags$div(
              class = "section-tabs",
              tags$button(
                class = "tab-btn tab-btn-active",
                id = ns("tab_missing_comments"),
                onclick = sprintf(
                  "Shiny.setInputValue('%s', 'missing_comments', {priority: 'event'})",
                  ns("switch_data_quality_tab")
                ),
                "Missing Comments"
              ),
              tags$button(
                class = "tab-btn",
                id = ns("tab_recommended_non_standard"),
                onclick = sprintf(
                  "Shiny.setInputValue('%s', 'recommended_non_standard', {priority: 'event'})",
                  ns("switch_data_quality_tab")
                ),
                "Recommended Non-Standard"
              )
            )
          ),
          tags$div(
            style = paste0(
              "flex: 1; margin-top: 10px; overflow: auto; ",
              "background: white; border-radius: 6px; padding: 10px; ",
              "position: relative;"
            ),
            class = "card-container",
            # Missing Comments Table
            tags$div(
              id = ns("missing_comments_container"),
              style = "width: 100%; height: 100%;",
              DT::DTOutput(ns("missing_comments_table"))
            ),
            # Recommended Non-Standard Table
            shinyjs::hidden(
              tags$div(
                id = ns("recommended_non_standard_container"),
                style = "width: 100%; height: 100%;",
                DT::DTOutput(ns("recommended_non_standard_table"))
              )
            )
          )
        )
      )
      })
    }, ignoreInit = FALSE)

    ### Data Quality Tab Switching ----

    observe_event(input$switch_data_quality_tab, {
      if (is.null(input$switch_data_quality_tab)) return()
      data_quality_tab(input$switch_data_quality_tab)
    }, ignoreInit = FALSE)

    observe_event(data_quality_tab(), {
      active_tab <- data_quality_tab()

      # Update visual tab states
      if (active_tab == "missing_comments") {
        shinyjs::addClass("tab_missing_comments", "tab-btn-active")
        shinyjs::removeClass("tab_recommended_non_standard", "tab-btn-active")
        shinyjs::show("missing_comments_container")
        shinyjs::hide("recommended_non_standard_container")
      } else if (active_tab == "recommended_non_standard") {
        shinyjs::removeClass("tab_missing_comments", "tab-btn-active")
        shinyjs::addClass("tab_recommended_non_standard", "tab-btn-active")
        shinyjs::hide("missing_comments_container")
        shinyjs::show("recommended_non_standard_container")
      }
    }, ignoreInit = FALSE)

    ### Data Quality Tables ----

    # Load missing comments table once
    observe_event(data(), {
      if (is.null(data())) return()

      missing_data <- data()$general_concepts %>%
        dplyr::filter(is.na(comments) | comments == "") %>%
        dplyr::select(category, subcategory, general_concept_name) %>%
        dplyr::mutate(
          category = as.factor(category),
          subcategory = as.factor(subcategory)
        )

      output$missing_comments_table <- DT::renderDT({
        DT::datatable(
          missing_data,
          rownames = FALSE,
          selection = "none",
          filter = "top",
          options = list(
            pageLength = 15,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100),
                             c("5", "10", "15", "20", "50", "100")),
            dom = "ltp",
            columnDefs = list(
              list(targets = 0, width = "150px"),
              list(targets = 1, width = "150px")
            )
          ),
          colnames = c("Category", "Subcategory", "General Concept Name")
        )
      }, server = FALSE)
    }, ignoreInit = FALSE, once = TRUE)

    # Load recommended non-standard table once
    observe_event(list(data(), vocabularies()), {
      if (is.null(data())) return()
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) return()
      if (is.null(vocab_data$concept)) return()

      # Get concept data (may be lazy dplyr::tbl)
      concept_data <- vocab_data$concept %>%
        dplyr::select(concept_id, concept_name, standard_concept) %>%
        dplyr::collect()

      # Get recommended mappings
      concept_mappings <- data()$concept_mappings
      recommended_mappings <- concept_mappings %>%
        dplyr::filter(recommended == TRUE, !is.na(omop_concept_id)) %>%
        dplyr::select(general_concept_id, omop_concept_id)

      # Join with concept data to get concept_name and check standard status
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
            dplyr::select(
              general_concept_id,
              category,
              subcategory,
              general_concept_name
            ),
          by = "general_concept_id"
        ) %>%
        dplyr::select(
          category,
          subcategory,
          general_concept_name,
          concept_name,
          omop_concept_id,
          standard_concept
        ) %>%
        dplyr::mutate(
          category = as.factor(category),
          subcategory = as.factor(subcategory),
          omop_concept_id = as.character(omop_concept_id)
        )

      output$recommended_non_standard_table <- DT::renderDT({
        DT::datatable(
          non_standard_data,
          rownames = FALSE,
          selection = "none",
          filter = "top",
          options = list(
            pageLength = 15,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100),
                             c("5", "10", "15", "20", "50", "100")),
            dom = "ltp",
            columnDefs = list(
              list(targets = 0, width = "120px"),
              list(targets = 1, width = "120px"),
              list(targets = 2, width = "150px"),
              list(targets = 3, width = "150px")
            )
          ),
          colnames = c(
            "Category",
            "Subcategory",
            "General Concept",
            "OMOP Concept Name",
            "OMOP Concept ID",
            "Standard"
          )
        )
      }, server = FALSE)
    }, ignoreInit = FALSE, once = TRUE)

    ## 3) Server - R Console ----

    ### Code Results Display ----

    code_results_trigger <- reactiveVal(0)

    observe_event(code_status(), {
      code_results_trigger(code_results_trigger() + 1)
    }, ignoreInit = FALSE)

    observe_event(code_results_trigger(), {
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
    }, ignoreInit = FALSE)

    ### Code Execution ----

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

      # Make vocabularies available as objects
      concept <- vocab_data$concept
      concept_relationship <- vocab_data$concept_relationship
      concept_ancestor <- vocab_data$concept_ancestor

      # Evaluate the code
      result <- tryCatch(
        {
          eval(parse(text = code))
        },
        error = function(e) {
          code_error_msg(as.character(e$message))
          code_status("error")
          return(NULL)
        }
      )

      # Store results if successful
      if (code_status() != "error") {
        code_result(result)
        code_status("success")
      }
    }

    # Run all code (button click)
    observe_event(input$run_code, {
      if (is.null(input$r_editor)) return()
      code <- input$r_editor
      execute_code(code)
    }, ignoreInit = FALSE)

    # Run all code (Ctrl/Cmd + Shift + Enter hotkey)
    observe_event(input$r_editor_runAllKey, {
      if (is.null(input$r_editor)) return()
      code <- input$r_editor
      execute_code(code)
    }, ignoreInit = FALSE)

    # Run selection or current line (Ctrl/Cmd + Enter hotkey)
    observe_event(input$r_editor_runSelectionKey, {
      if (is.null(input$r_editor_runSelectionKey)) return()
      code <- input$r_editor_runSelectionKey
      execute_code(code)
    }, ignoreInit = FALSE)
  })
}
