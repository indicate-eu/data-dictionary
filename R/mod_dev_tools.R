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
#' @param i18n Translator object from shiny.i18n
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS uiOutput tabsetPanel tabPanel actionButton verbatimTextOutput
#' @importFrom htmltools tags tagList
#' @importFrom shinyAce aceEditor
mod_dev_tools_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    ## UI - Main Layout ----
    div(class = "main-panel",
        div(class = "main-content",
            tabsetPanel(
              id = ns("dev_tabs"),

              ### Data Quality Tab ----
              tabPanel(
                i18n$t("data_quality"),
                value = "data_quality",
                tags$div(
                  style = "margin-top: 10px; height: 100%;",
                  uiOutput(ns("data_quality_output"))
                )
              ),

              ### R Console Tab ----
              tabPanel(
                i18n$t("r_console"),
                value = "r_console",
                tags$div(
                  style = "margin-top: 10px; height: calc(100% - 10px); display: flex; flex-direction: column;",
                  tags$div(
                    style = "display: flex; gap: 15px; height: 100%;",
                    # Left: Editor
                    tags$div(
                      style = "flex: 1; height: 100%; display: flex; flex-direction: column;",
                      tags$div(
                        class = "section-header",
                        tags$h4(i18n$t("r_code"))
                      ),
                      tags$div(
                        style = paste0(
                          "flex: 1; height: 100%; border: 1px solid #dee2e6; ",
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
                        tags$strong(i18n$t("available_objects")),
                        tags$br(),
                        tags$code("concept"), " - ", i18n$t("concept_table"),
                        tags$br(),
                        tags$code("concept_relationship"), " - ", i18n$t("concept_relationship_table"),
                        tags$br(),
                        tags$code("concept_ancestor"), " - ", i18n$t("concept_ancestor_table")
                      ),
                      tags$div(
                        style = "margin-top: 10px;",
                        actionButton(ns("run_code"), i18n$t("run_code"), class = "btn-primary", icon = icon("play"))
                      )
                    ),
                    # Right: Results
                    tags$div(
                      style = "flex: 1; height: 100%; display: flex; flex-direction: column;",
                      tags$div(
                        class = "section-header",
                        tags$h4(i18n$t("results"))
                      ),
                      tags$div(
                        style = "flex: 1; height: 100%; overflow: auto; background: white; border: 1px solid #dee2e6; border-radius: 6px; padding: 10px; font-size: 11px;",
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
#' @param i18n Translator object from shiny.i18n
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive req renderUI observeEvent renderPrint
#' @importFrom DT renderDT datatable DTOutput
#' @importFrom dplyr filter summarise n select
#' @importFrom htmltools tags HTML
mod_dev_tools_server <- function(id, data, vocabularies, i18n, log_level = character()) {
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
    })

    # Data Quality output
    observe_event(data_quality_trigger(), {
      if (is.null(data())) return()

      general_concepts <- data()$general_concepts
      total_concepts <- nrow(general_concepts)

      # Count missing comments
      missing_comments <- sum(is.na(general_concepts$comments) |
                             general_concepts$comments == "")
      pct_missing_comments <- round(missing_comments / total_concepts * 100, 1)

      # Count concepts that are not standard
      vocab_data <- vocabularies()
      concept_mappings <- data()$concept_mappings

      if (!is.null(vocab_data) && !is.null(vocab_data$concept) &&
          !is.null(concept_mappings)) {
        # Get concept data from vocabularies (may be lazy dplyr::tbl)
        concept_standard <- vocab_data$concept %>%
          dplyr::select(concept_id, standard_concept) %>%
          dplyr::collect()

        # Get all mappings with OMOP concept IDs
        all_mappings <- concept_mappings %>%
          dplyr::filter(!is.na(omop_concept_id))

        non_standard_count <- all_mappings %>%
          dplyr::left_join(
            concept_standard,
            by = c("omop_concept_id" = "concept_id")
          ) %>%
          dplyr::filter(is.na(standard_concept) |
                       standard_concept != "S") %>%
          nrow()

        total_mappings <- nrow(all_mappings)
        pct_non_standard <- if (total_mappings > 0) {
          round(non_standard_count / total_mappings * 100, 1)
        } else {
          0
        }
      } else {
        non_standard_count <- NA
        total_mappings <- NA
        pct_non_standard <- NA
      }

      output$data_quality_output <- renderUI({
        tags$div(
        style = "display: flex; gap: 20px; flex: 1; min-height: 0;",

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
              i18n$t("missing_comments")
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

          # Card 3: Non-Standard Concepts
          tags$div(
            style = paste0(
              "flex: 0 0 calc(50% - 10px); background: white; ",
              "border-radius: 8px; padding: 20px; ",
              "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
              "border-left: 4px solid #17a2b8;"
            ),
            tags$div(
              style = "font-size: 14px; color: #666; margin-bottom: 8px;",
              i18n$t("non_standard_concepts")
            ),
            if (!is.na(non_standard_count)) {
              tagList(
                tags$div(
                  style = paste0(
                    "font-size: 32px; font-weight: 700; color: #17a2b8; ",
                    "margin-bottom: 5px;"
                  ),
                  paste0(non_standard_count, " / ", total_mappings)
                ),
                tags$div(
                  style = "font-size: 18px; color: #999;",
                  paste0(pct_non_standard, "%")
                )
              )
            } else {
              tags$div(
                style = "font-size: 14px; color: #999; font-style: italic;",
                i18n$t("vocabularies_not_loaded")
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
            tags$h4(i18n$t("missing_data_details")),
            tags$div(
              class = "section-tabs",
              tags$button(
                class = "tab-btn tab-btn-active",
                id = ns("tab_missing_comments"),
                onclick = sprintf(
                  "Shiny.setInputValue('%s', 'missing_comments', {priority: 'event'})",
                  ns("switch_data_quality_tab")
                ),
                i18n$t("missing_comments")
              ),
              tags$button(
                class = "tab-btn",
                id = ns("tab_non_standard"),
                onclick = sprintf(
                  "Shiny.setInputValue('%s', 'non_standard', {priority: 'event'})",
                  ns("switch_data_quality_tab")
                ),
                i18n$t("non_standard")
              )
            )
          ),
          tags$div(
            style = paste0(
              "flex: 1; overflow: auto; ",
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
            # Non-Standard Table
            shinyjs::hidden(
              tags$div(
                id = ns("non_standard_container"),
                style = "width: 100%; height: 100%;",
                DT::DTOutput(ns("non_standard_table"))
              )
            )
          )
        )
      )
      })
    })

    ### Data Quality Tab Switching ----

    observe_event(input$switch_data_quality_tab, {
      if (is.null(input$switch_data_quality_tab)) return()
      data_quality_tab(input$switch_data_quality_tab)
    })

    observe_event(data_quality_tab(), {
      active_tab <- data_quality_tab()

      # Update visual tab states
      if (active_tab == "missing_comments") {
        shinyjs::addClass("tab_missing_comments", "tab-btn-active")
        shinyjs::removeClass("tab_non_standard", "tab-btn-active")
        shinyjs::show("missing_comments_container")
        shinyjs::hide("non_standard_container")
      } else if (active_tab == "non_standard") {
        shinyjs::removeClass("tab_missing_comments", "tab-btn-active")
        shinyjs::addClass("tab_non_standard", "tab-btn-active")
        shinyjs::hide("missing_comments_container")
        shinyjs::show("non_standard_container")
      }
    })

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
            dom = "ltip",
            columnDefs = list(
              list(targets = 0, width = "150px"),
              list(targets = 1, width = "150px")
            )
          ),
          colnames = c(
            as.character(i18n$t("category")),
            as.character(i18n$t("subcategory")),
            as.character(i18n$t("general_concept_name"))
          )
        )
      }, server = FALSE)
    }, once = TRUE)

    # Load non-standard table once
    observe_event(list(data(), vocabularies()), {
      if (is.null(data())) return()
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) return()
      if (is.null(vocab_data$concept)) return()

      # Get concept data (may be lazy dplyr::tbl)
      concept_data <- vocab_data$concept %>%
        dplyr::select(concept_id, concept_name, standard_concept) %>%
        dplyr::collect()

      # Get all concept mappings
      concept_mappings <- data()$concept_mappings
      all_mappings <- concept_mappings %>%
        dplyr::filter(!is.na(omop_concept_id)) %>%
        dplyr::select(general_concept_id, omop_concept_id)

      # Join with concept data to get concept_name and check standard status
      mappings_with_standard <- all_mappings %>%
        dplyr::left_join(
          concept_data,
          by = c("omop_concept_id" = "concept_id")
        ) %>%
        dplyr::filter(is.na(standard_concept) | standard_concept != "S")

      # Join with general_concepts to get category/subcategory info
      non_standard_data <- mappings_with_standard %>%
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

      output$non_standard_table <- DT::renderDT({
        DT::datatable(
          non_standard_data,
          rownames = FALSE,
          selection = "none",
          filter = "top",
          options = list(
            pageLength = 15,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100),
                             c("5", "10", "15", "20", "50", "100")),
            dom = "ltip",
            columnDefs = list(
              list(targets = 0, width = "120px"),
              list(targets = 1, width = "120px"),
              list(targets = 2, width = "150px"),
              list(targets = 3, width = "150px")
            )
          ),
          colnames = c(
            as.character(i18n$t("category")),
            as.character(i18n$t("subcategory")),
            as.character(i18n$t("general_concept")),
            as.character(i18n$t("omop_concept_name")),
            as.character(i18n$t("omop_concept_id")),
            as.character(i18n$t("standard"))
          )
        )
      }, server = FALSE)
    }, once = TRUE)

    ## 3) Server - R Console ----

    ### Code Results Display ----

    code_results_trigger <- reactiveVal(0)

    observe_event(code_status(), {
      code_results_trigger(code_results_trigger() + 1)
    })

    observe_event(code_results_trigger(), {
      output$code_results <- renderPrint({
        status <- code_status()

        if (status == "initial") {
          cat(as.character(i18n$t("run_code_results")))
        } else if (status == "no_code") {
          cat(paste0("Warning: ", as.character(i18n$t("enter_r_code"))))
        } else if (status == "no_vocab") {
          cat(paste0("Error: ", as.character(i18n$t("vocabularies_not_loaded"))))
        } else if (status == "error") {
          cat("Error:\n")
          cat(code_error_msg())
        } else if (status == "success") {
          result <- code_result()
          print(result)
        }
      })
    })

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
    })

    # Run all code (Ctrl/Cmd + Shift + Enter hotkey)
    observe_event(input$r_editor_runAllKey, {
      if (is.null(input$r_editor)) return()
      code <- input$r_editor
      execute_code(code)
    })

    # Run selection or current line (Ctrl/Cmd + Enter hotkey)
    observe_event(input$r_editor_runSelectionKey, {
      if (is.null(input$r_editor_runSelectionKey)) return()
      code <- input$r_editor_runSelectionKey
      execute_code(code)
    })
  })
}
