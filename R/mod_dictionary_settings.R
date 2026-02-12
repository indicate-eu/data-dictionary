# MODULE STRUCTURE OVERVIEW ====
#
# This module manages dictionary-specific settings
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### ETL Guidelines Tab - Edit global ETL guidelines (Ace Markdown editor + preview)
#      ### Unit Conversions Tab - Manage unit conversions (fuzzy search + single selection)
#      ### Recommended Units Tab - Manage recommended units (fuzzy search + single selection)
#   ## UI - Modals
#      ### Modal - Load Default Conversions - Offer to load default unit conversions
#      ### Modal - Test Conversion - Test unit conversion with numeric input
#      ### Modal - Delete Confirmation - Confirm deletion of conversion
#      ### Modal - Load Default Recommended Units - Offer to load default recommended units
#      ### Modal - Delete Recommended Unit Confirmation - Confirm deletion
#      ### Modal - Add Recommended Unit (Fullscreen) - Add new recommended unit with OMOP search
#      ### Modal - Add Conversion (Fullscreen) - Add new conversion with OMOP search
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Unit Conversions State - Track conversion data and triggers
#      ### OMOP Search State - Track OMOP table data
#      ### Recommended Units State - Track recommended units data and triggers
#      ### Fuzzy Search - Server-side fuzzy search for both datatables
#
#   ## 2) Server - ETL Guidelines
#      ### Load ETL Guidelines - Initialize textarea with existing content
#      ### Live Preview - Render markdown preview as user types
#      ### Save Handler - Save ETL guidelines to config
#
#   ## 3) Server - Unit Conversions
#      ### Load Conversions - Load from CSV, offer defaults if empty
#      ### DataTable Display - Show conversions with fuzzy search and actions
#      ### Edit Handler - Update conversion factor on cell edit
#      ### Delete Handler - Show confirmation modal
#      ### Confirm Delete Handler - Remove selected conversion
#      ### Confirm Load Default Conversions - Load defaults from CSV
#      ### Test Conversion Modal - Display test modal and calculate result
#      ### Add Conversion Modal - Open modal and handle OMOP search
#      ### Save New Conversion - Validate and save new conversion
#
#   ## 4) Server - Recommended Units
#      ### Load Recommended Units - Load from CSV, offer defaults if empty
#      ### DataTable Display - Show recommended units with fuzzy search and actions
#      ### Confirm Load Default Recommended Units - Load defaults from CSV
#      ### Delete Recommended Unit Handler - Show/confirm deletion
#      ### Add Recommended Unit Modal - Open modal and handle OMOP search
#      ### Save New Recommended Unit - Validate and save
#
#   ## 5) Server - Tab Switching
#      ### Toggle action buttons based on active tab

# UI SECTION ====

#' Dictionary Settings Module - UI
#'
#' @param id Module ID
#' @param i18n Translator object
#'
#' @return Shiny UI elements
#' @noRd
mod_dictionary_settings_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",

        ## UI - Main Layout ----
        create_page_layout(
          "full",
          create_panel(
            title = NULL,
            content = tagList(
              tags$div(
                class = "tabs-with-actions",

                # Save button (top-right, ETL guidelines only)
                tags$div(
                  class = "tabs-actions",
                  tags$div(
                    id = ns("save_btn_container"),
                    actionButton(
                      ns("save_etl_guidelines_btn"),
                      label = tagList(
                        icon("save"),
                        i18n$t("save")
                      ),
                      class = "btn-primary-custom tabs-action-btn"
                    )
                  )
                ),

                tags$div(
                  class = "tabs-wrapper",
                  tabsetPanel(
                    id = ns("dictionary_settings_tabs"),

                    ### ETL Guidelines Tab ----
                    tabPanel(
                      i18n$t("etl_guidelines"),
                      value = "etl_guidelines",
                      icon = icon("comment-dots"),
                      tags$div(
                        class = "tab-content-panel",
                        # Split view: editor on left, preview on right
                        tags$div(
                          class = "settings-backup-container concepts-layout",
                          # Left: Markdown editor
                          tags$div(
                            class = "settings-section settings-backup-section expandable-section",
                            tags$h4(
                              class = "settings-section-title",
                              tags$i(class = "fas fa-edit", style = "margin-right: 8px; color: #0f60af;"),
                              i18n$t("markdown_editor")
                            ),
                            tags$div(
                              style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                              tags$div(
                                style = "flex: 1; overflow: hidden;",
                                shinyAce::aceEditor(
                                  ns("etl_guidelines_editor"),
                                  mode = "markdown",
                                  theme = "chrome",
                                  height = "100%",
                                  fontSize = 12,
                                  debounce = 100,
                                  autoScrollEditorIntoView = TRUE
                                )
                              )
                            )
                          ),
                          # Right: Preview
                          tags$div(
                            class = "settings-section settings-backup-section expandable-section",
                            tags$h4(
                              class = "settings-section-title",
                              tags$i(class = "fas fa-eye", style = "margin-right: 8px; color: #0f60af;"),
                              i18n$t("preview")
                            ),
                            tags$div(
                              style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                              tags$div(
                                style = "flex: 1; overflow: auto; padding: 10px;",
                                uiOutput(ns("etl_guidelines_preview"))
                              )
                            )
                          )
                        )
                      )
                    ),

                    ### Unit Conversions Tab ----
                    tabPanel(
                      i18n$t("unit_conversions"),
                      value = "unit_conversions",
                      icon = icon("exchange-alt"),
                      tags$div(
                        class = "tab-content-panel",
                        tags$div(
                          class = "settings-section",
                          style = "flex: 1; display: flex; flex-direction: column; height: calc(100vh - 230px);",

                          # Content container (no-content message or DataTable)
                          tags$div(
                            style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                            tags$div(
                              id = ns("conversions_fuzzy_search_container"),
                              style = "position: absolute; top: 0; right: 0; z-index: 10; display: flex; align-items: center; gap: 8px;",
                              fuzzy_search_ui("conversions_fuzzy_search", ns = ns, i18n = i18n),
                              actionButton(
                                ns("add_conversion_btn"),
                                label = tagList(
                                  tags$i(class = "fas fa-plus mr-6"),
                                  i18n$t("add_conversion")
                                ),
                                class = "btn-success-custom",
                                style = "height: 26px; padding: 0 10px; font-size: 12px; display: flex; align-items: center; white-space: nowrap;"
                              )
                            ),
                            tags$div(
                              id = ns("no_conversions_message"),
                              class = "no-content-message",
                              tags$p(i18n$t("no_unit_conversions"))
                            ),
                            shinyjs::hidden(
                              tags$div(
                                id = ns("conversions_table_container"),
                                style = "flex: 1; overflow: auto;",
                                DT::DTOutput(ns("unit_conversions_table"))
                              )
                            )
                          )
                        )
                      )
                    ),

                    ### Recommended Units Tab ----
                    tabPanel(
                      i18n$t("recommended_units"),
                      value = "recommended_units",
                      icon = icon("balance-scale"),
                      tags$div(
                        class = "tab-content-panel",
                        tags$div(
                          class = "settings-section",
                          style = "flex: 1; display: flex; flex-direction: column; height: calc(100vh - 230px);",

                          # Content container (no-content message or DataTable)
                          tags$div(
                            style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                            tags$div(
                              id = ns("recommended_units_fuzzy_search_container"),
                              style = "position: absolute; top: 0; right: 0; z-index: 10; display: flex; align-items: center; gap: 8px;",
                              fuzzy_search_ui("recommended_units_fuzzy_search", ns = ns, i18n = i18n),
                              actionButton(
                                ns("add_recommended_unit_btn"),
                                label = tagList(
                                  tags$i(class = "fas fa-plus mr-6"),
                                  i18n$t("add_recommended_unit")
                                ),
                                class = "btn-success-custom",
                                style = "height: 26px; padding: 0 10px; font-size: 12px; display: flex; align-items: center; white-space: nowrap;"
                              )
                            ),
                            tags$div(
                              id = ns("no_recommended_units_message"),
                              class = "no-content-message",
                              tags$p(i18n$t("no_recommended_units"))
                            ),
                            shinyjs::hidden(
                              tags$div(
                                id = ns("recommended_units_table_container"),
                                style = "flex: 1; overflow: auto;",
                                DT::DTOutput(ns("recommended_units_table"))
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    ),

    ## UI - Modals ----

    ### Modal - Load Default Conversions ----
    create_modal(
      id = "load_default_conversions_modal",
      title = i18n$t("no_unit_conversions"),
      body = tagList(
        tags$p(
          i18n$t("load_default_conversions_count"),
          style = "margin-bottom: 15px;"
        ),
        tags$p(
          i18n$t("load_default_conversions_question"),
          style = "font-weight: 600; margin-top: 10px;"
        )
      ),
      footer = tagList(
        actionButton(ns("cancel_load_default_conversions"), i18n$t("no"), class = "btn-secondary-custom", icon = icon("times")),
        actionButton(ns("confirm_load_default_conversions"), i18n$t("yes_load"), class = "btn-primary-custom", icon = icon("download"))
      ),
      size = "medium",
      icon = "fas fa-info-circle",
      ns = ns
    ),

    ### Modal - Test Conversion ----
    create_modal(
      id = "test_conversion_modal",
      title = i18n$t("test_conversion"),
      icon = "fas fa-calculator",
      size = "small",
      ns = ns,
      body = tagList(
        # Conversion info display
        uiOutput(ns("test_conversion_info")),

        # Input for Concept 1 value with unit on the right
        tags$div(
          style = "margin-top: 20px;",
          tags$label(
            id = ns("test_value_1_label"),
            class = "form-label"
          ),
          tags$div(
            style = "display: flex; align-items: center; gap: 10px;",
            tags$div(
              style = "flex: 1;",
              numericInput(
                ns("test_value_1"),
                label = NULL,
                value = 1,
                min = 0,
                step = 0.1,
                width = "100%"
              )
            ),
            tags$span(
              id = ns("test_unit_1_display"),
              style = "font-weight: 600; color: #666; min-width: 60px;"
            )
          )
        ),

        # Arrow and conversion factor
        tags$div(
          style = "text-align: center; margin: 20px 0; font-size: 24px; color: #0f60af;",
          tags$i(class = "fa fa-arrow-down"),
          tags$span(
            style = "margin-left: 10px; font-size: 14px; color: #666;",
            "\u00D7",
            tags$span(id = ns("test_factor_display"), "")
          )
        ),

        # Result for Concept 2 value
        tags$div(
          tags$label(
            id = ns("test_value_2_label"),
            class = "form-label"
          ),
          tags$div(
            id = ns("test_result_display"),
            style = "padding: 12px; background: #e8f4f8; border-radius: 4px; font-size: 18px; font-weight: 600; text-align: center; color: #0f60af;"
          )
        )
      )
    ),

    ### Modal - Delete Confirmation ----
    create_modal(
      id = "delete_confirmation_modal",
      title = i18n$t("confirm_deletion"),
      icon = "fas fa-exclamation-triangle",
      size = "small",
      ns = ns,
      body = tags$p(
        style = "margin: 0 0 20px 0; color: #333;",
        i18n$t("confirm_delete_conversion")
      ),
      footer = tagList(
        tags$button(
          class = "btn-secondary-custom",
          onclick = sprintf("$('#%s').hide();", ns("delete_confirmation_modal")),
          i18n$t("cancel")
        ),
        actionButton(
          ns("confirm_delete_btn"),
          label = i18n$t("delete"),
          class = "btn-danger-custom"
        )
      )
    ),

    ### Modal - Load Default Recommended Units ----
    create_modal(
      id = "load_default_recommended_units_modal",
      title = i18n$t("no_recommended_units"),
      body = tagList(
        tags$p(
          i18n$t("load_default_recommended_units_count"),
          style = "margin-bottom: 15px;"
        ),
        tags$p(
          i18n$t("load_default_recommended_units_question"),
          style = "font-weight: 600; margin-top: 10px;"
        )
      ),
      footer = tagList(
        actionButton(ns("cancel_load_default_recommended_units"), i18n$t("no"), class = "btn-secondary-custom", icon = icon("times")),
        actionButton(ns("confirm_load_default_recommended_units"), i18n$t("yes_load"), class = "btn-primary-custom", icon = icon("download"))
      ),
      size = "medium",
      icon = "fas fa-info-circle",
      ns = ns
    ),

    ### Modal - Delete Recommended Unit Confirmation ----
    create_modal(
      id = "delete_recommended_unit_modal",
      title = i18n$t("confirm_deletion"),
      icon = "fas fa-exclamation-triangle",
      size = "small",
      ns = ns,
      body = tags$p(
        style = "margin: 0 0 20px 0; color: #333;",
        i18n$t("confirm_delete_recommended_unit")
      ),
      footer = tagList(
        tags$button(
          class = "btn-secondary-custom",
          onclick = sprintf("$('#%s').hide();", ns("delete_recommended_unit_modal")),
          i18n$t("cancel")
        ),
        actionButton(
          ns("confirm_delete_recommended_unit_btn"),
          label = i18n$t("delete"),
          class = "btn-danger-custom"
        )
      )
    ),

    ### Modal - Add Recommended Unit (Fullscreen) ----
    tags$div(
      id = ns("add_recommended_unit_modal"),
      class = "modal-fs",

      # Header
      tags$div(
        class = "modal-fs-header",
        tags$h3(i18n$t("add_recommended_unit")),
        tags$button(
          id = ns("close_add_recommended_unit_modal"),
          class = "modal-fs-close",
          onclick = sprintf("document.getElementById('%s').style.display = 'none';", ns("add_recommended_unit_modal")),
          HTML("&times;")
        )
      ),

      # Body
      tags$div(
        class = "modal-fs-body",

        # Top section: Input fields
        tags$div(
          class = "modal-fs-section",
          style = "flex: 0 0 auto;",
          tags$div(
            class = "modal-fs-input-row-narrow",

            # Concept ID (measurement)
            tags$div(
              class = "flex-input-field",
              tags$label(i18n$t("concept_id_field"), class = "form-label"),
              textInput(ns("new_ru_concept_id"), label = NULL, value = "", width = "100%"),
              tags$div(class = "input-error-placeholder",
                tags$div(id = ns("new_ru_concept_id_error"), class = "input-error-message", i18n$t("field_required"))
              )
            ),

            # Unit Concept ID
            tags$div(
              class = "flex-input-field",
              tags$label(i18n$t("unit_concept_id_field"), class = "form-label"),
              textInput(ns("new_ru_unit_concept_id"), label = NULL, value = "", width = "100%"),
              tags$div(class = "input-error-placeholder",
                tags$div(id = ns("new_ru_unit_concept_id_error"), class = "input-error-message", i18n$t("field_required"))
              )
            )
          ),

          # Preview display
          tags$div(
            id = ns("ru_preview"),
            style = "padding: 12px 16px; background: #f0f7ff; border: 1px solid #cce0ff; border-radius: 6px; text-align: center; font-size: 14px; color: #333; display: none; margin-top: 15px;",
            tags$span(id = ns("ru_preview_concept"), class = "font-weight-600"),
            tags$span(" \u2192 "),
            tags$span(id = ns("ru_preview_unit"), class = "font-weight-600", style = "color: #0f60af;")
          )
        ),

        # OMOP Search section
        tags$div(
          class = "modal-fs-section",
          tags$div(
            class = "modal-fs-section-inner",
            fuzzy_search_ui(
              "ru_omop_fuzzy_search",
              ns = ns,
              i18n = i18n,
              limit_checkbox = TRUE,
              limit_checkbox_id = "ru_omop_limit_10k",
              settings_btn = TRUE,
              settings_btn_id = "ru_omop_filters_btn"
            ),
            tags$div(
              style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 10px;",

              # Add as dropdown button
              tags$div(
                class = "dropdown",
                style = "position: relative; display: inline-block;",
                onclick = "event.stopPropagation();",
                tags$button(
                  id = ns("ru_add_as_btn"),
                  class = "btn-primary-custom",
                  style = "display: flex; align-items: center; gap: 6px;",
                  onclick = sprintf("event.stopPropagation(); $('#%s').toggle();", ns("ru_add_as_dropdown")),
                  tags$i(class = "fa fa-plus"),
                  i18n$t("add_as"),
                  tags$i(class = "fa fa-caret-down", style = "margin-left: 4px;")
                ),
                tags$div(
                  id = ns("ru_add_as_dropdown"),
                  style = "display: none; position: absolute; right: 0; top: 100%; background: white; border: 1px solid #ddd; border-radius: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 1000; min-width: 180px;",
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer; border-bottom: 1px solid #eee;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'concept', {priority: 'event'}); $('#%s').hide();", ns("ru_add_as_selection"), ns("ru_add_as_dropdown")),
                    i18n$t("concept_id_field")
                  ),
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'unit', {priority: 'event'}); $('#%s').hide();", ns("ru_add_as_selection"), ns("ru_add_as_dropdown")),
                    i18n$t("unit_concept_id_field")
                  )
                )
              )
            ),
            DT::DTOutput(ns("ru_omop_search_table"))
          )
        ),

        # Footer
        tags$div(
          class = "modal-fs-footer",
          tags$div(),
          tags$div(
            class = "flex-center-gap-8",
            actionButton(
              ns("save_new_recommended_unit_btn"),
              label = tagList(
                tags$i(class = "fa fa-plus mr-6"),
                i18n$t("add")
              ),
              class = "btn-success-custom"
            )
          )
        )
      )
    ),

    ### Modal - Add Conversion (Fullscreen) ----
    tags$div(
      id = ns("add_conversion_modal"),
      class = "modal-fs",

      # Header
      tags$div(
        class = "modal-fs-header",
        tags$h3(i18n$t("add_conversion")),
        tags$button(
          id = ns("close_add_conversion_modal"),
          class = "modal-fs-close",
          onclick = sprintf("document.getElementById('%s').style.display = 'none';", ns("add_conversion_modal")),
          HTML("&times;")
        )
      ),

      # Body
      tags$div(
        class = "modal-fs-body",

        # Top section: Input fields
        tags$div(
          class = "modal-fs-section",
          style = "flex: 0 0 auto;",
          tags$div(
            class = "modal-fs-input-row-narrow",

            # Concept 1
            tags$div(
              class = "flex-input-field",
              tags$label(i18n$t("concept_id_1"), class = "form-label"),
              textInput(ns("new_concept_id_1"), label = NULL, value = "", width = "100%"),
              tags$div(class = "input-error-placeholder",
                tags$div(id = ns("new_concept_id_1_error"), class = "input-error-message", i18n$t("field_required"))
              )
            ),

            # Unit 1
            tags$div(
              class = "flex-input-field",
              tags$label(i18n$t("unit_concept_id_1"), class = "form-label"),
              textInput(ns("new_unit_id_1"), label = NULL, value = "", width = "100%"),
              tags$div(class = "input-error-placeholder",
                tags$div(id = ns("new_unit_id_1_error"), class = "input-error-message", i18n$t("field_required"))
              )
            ),

            # Conversion Factor
            tags$div(
              class = "flex-input-field",
              tags$label(i18n$t("conversion_factor"), class = "form-label"),
              numericInput(ns("new_conversion_factor"), label = NULL, value = 1, min = 0, step = 1, width = "100%"),
              tags$div(class = "input-error-placeholder",
                tags$div(id = ns("new_conversion_factor_error"), class = "input-error-message", i18n$t("field_required"))
              )
            ),

            # Concept 2
            tags$div(
              class = "flex-input-field",
              tags$label(i18n$t("concept_id_2"), class = "form-label"),
              textInput(ns("new_concept_id_2"), label = NULL, value = "", width = "100%"),
              tags$div(class = "input-error-placeholder",
                tags$div(id = ns("new_concept_id_2_error"), class = "input-error-message", i18n$t("field_required"))
              )
            ),

            # Unit 2
            tags$div(
              class = "flex-input-field",
              tags$label(i18n$t("unit_concept_id_2"), class = "form-label"),
              textInput(ns("new_unit_id_2"), label = NULL, value = "", width = "100%"),
              tags$div(class = "input-error-placeholder",
                tags$div(id = ns("new_unit_id_2_error"), class = "input-error-message", i18n$t("field_required"))
              )
            )
          ),

          # Conversion preview display
          tags$div(
            id = ns("conversion_preview"),
            style = "padding: 12px 16px; background: #f0f7ff; border: 1px solid #cce0ff; border-radius: 6px; text-align: center; font-size: 14px; color: #333; display: none; margin-top: 15px;",
            tags$span(id = ns("preview_concept_1"), class = "font-weight-600"),
            tags$span("("),
            tags$span(id = ns("preview_unit_1"), class = "text-secondary"),
            tags$span(")"),
            tags$span(id = ns("preview_factor"), style = "color: #0f60af; font-weight: 700; margin: 0 8px;"),
            tags$span("\u2192 "),
            tags$span(id = ns("preview_concept_2"), class = "font-weight-600"),
            tags$span("("),
            tags$span(id = ns("preview_unit_2"), class = "text-secondary"),
            tags$span(")")
          )
        ),

        # OMOP Search section
        tags$div(
          class = "modal-fs-section",
          tags$div(
            class = "modal-fs-section-inner",
            fuzzy_search_ui(
              "conv_omop_fuzzy_search",
              ns = ns,
              i18n = i18n,
              limit_checkbox = TRUE,
              limit_checkbox_id = "conv_omop_limit_10k",
              settings_btn = TRUE,
              settings_btn_id = "conv_omop_filters_btn"
            ),
            tags$div(
              style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 10px;",

              # Add as dropdown button
              tags$div(
                class = "dropdown",
                style = "position: relative; display: inline-block;",
                onclick = "event.stopPropagation();",
                tags$button(
                  id = ns("add_as_btn"),
                  class = "btn-primary-custom",
                  style = "display: flex; align-items: center; gap: 6px;",
                  onclick = sprintf("event.stopPropagation(); $('#%s').toggle();", ns("add_as_dropdown")),
                  tags$i(class = "fa fa-plus"),
                  i18n$t("add_as"),
                  tags$i(class = "fa fa-caret-down", style = "margin-left: 4px;")
                ),
                tags$div(
                  id = ns("add_as_dropdown"),
                  style = "display: none; position: absolute; right: 0; top: 100%; background: white; border: 1px solid #ddd; border-radius: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 1000; min-width: 180px;",
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer; border-bottom: 1px solid #eee;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'concept_1', {priority: 'event'}); $('#%s').hide();", ns("add_as_selection"), ns("add_as_dropdown")),
                    i18n$t("concept_id_1")
                  ),
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer; border-bottom: 1px solid #eee;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'unit_1', {priority: 'event'}); $('#%s').hide();", ns("add_as_selection"), ns("add_as_dropdown")),
                    i18n$t("unit_concept_id_1")
                  ),
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer; border-bottom: 1px solid #eee;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'concept_2', {priority: 'event'}); $('#%s').hide();", ns("add_as_selection"), ns("add_as_dropdown")),
                    i18n$t("concept_id_2")
                  ),
                  tags$div(
                    class = "dropdown-item",
                    style = "padding: 10px 15px; cursor: pointer;",
                    onclick = sprintf("Shiny.setInputValue('%s', 'unit_2', {priority: 'event'}); $('#%s').hide();", ns("add_as_selection"), ns("add_as_dropdown")),
                    i18n$t("unit_concept_id_2")
                  )
                )
              )
            ),
            DT::DTOutput(ns("omop_search_table"))
          )
        ),

        # Footer
        tags$div(
          class = "modal-fs-footer",
          tags$div(),
          tags$div(
            class = "flex-center-gap-8",
            actionButton(
              ns("save_new_conversion_btn"),
              label = tagList(
                tags$i(class = "fa fa-plus mr-6"),
                i18n$t("add")
              ),
              class = "btn-success-custom"
            )
          )
        )
      )
    ),

    ## UI - Limit 10K & Filters Modals ----

    ### Conversion Modal - Limit 10K Confirmation ----
    limit_10k_modal_ui(
      modal_id = "conv_omop_limit_10k_confirmation_modal",
      checkbox_id = "conv_omop_limit_10k",
      confirm_btn_id = "confirm_conv_omop_limit_10k",
      ns = ns,
      i18n = i18n
    ),

    ### Conversion Modal - OMOP Advanced Filters ----
    omop_filters_modal_ui(
      prefix = "conv_omop_filters",
      ns = ns,
      i18n = i18n
    ),

    ### Recommended Units Modal - Limit 10K Confirmation ----
    limit_10k_modal_ui(
      modal_id = "ru_omop_limit_10k_confirmation_modal",
      checkbox_id = "ru_omop_limit_10k",
      confirm_btn_id = "confirm_ru_omop_limit_10k",
      ns = ns,
      i18n = i18n
    ),

    ### Recommended Units Modal - OMOP Advanced Filters ----
    omop_filters_modal_ui(
      prefix = "ru_omop_filters",
      ns = ns,
      i18n = i18n
    )
  )
}

# SERVER SECTION ====

#' Dictionary Settings Module - Server
#'
#' @param id Module ID
#' @param i18n Translator object
#' @param current_user Reactive: Current logged-in user
#' @param vocabularies Reactive: OHDSI vocabularies data (lazy tbl objects)
#'
#' @noRd
mod_dictionary_settings_server <- function(id, i18n, current_user = NULL, vocabularies = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    log_level <- strsplit(Sys.getenv("INDICATE_DEBUG_MODE", "error"), ",")[[1]]

    ## 1) Server - Reactive Values & State ----

    ### Unit Conversions State ----
    unit_conversions_data <- reactiveVal(NULL)
    unit_conversions_trigger <- reactiveVal(0)

    ### Recommended Units State ----
    recommended_units_data <- reactiveVal(NULL)
    recommended_units_trigger <- reactiveVal(0)

    ### OMOP Search State (Conversion Modal) ----
    omop_table_trigger <- reactiveVal(0)
    omop_concepts_cache <- reactiveVal(NULL)

    ### OMOP Search State (Recommended Units Modal) ----
    ru_omop_table_trigger <- reactiveVal(0)
    ru_omop_concepts_cache <- reactiveVal(NULL)

    ### Test Conversion State ----
    test_conversion_row <- reactiveVal(NULL)
    test_unit_code_2 <- reactiveVal("")

    ### Delete State ----
    delete_row_index <- reactiveVal(NULL)

    ### Preview Trigger ----
    preview_trigger <- reactiveVal(0)

    ### Recommended Units Preview Trigger ----
    ru_preview_trigger <- reactiveVal(0)

    ### Recommended Units Delete State ----
    ru_delete_row_index <- reactiveVal(NULL)

    ## Fuzzy Search (main datatables) ----
    conversions_fuzzy <- fuzzy_search_server("conversions_fuzzy_search", input, session, trigger_rv = unit_conversions_trigger, ns = ns)
    recommended_units_fuzzy <- fuzzy_search_server("recommended_units_fuzzy_search", input, session, trigger_rv = recommended_units_trigger, ns = ns)

    ## Fuzzy Search (conversion modal) ----
    conv_omop_fuzzy <- fuzzy_search_server("conv_omop_fuzzy_search", input, session, trigger_rv = omop_table_trigger, ns = ns)

    ## Limit 10K (conversion modal) ----
    conv_omop_limit_10k <- limit_10k_server(
      checkbox_id = "conv_omop_limit_10k",
      modal_id = "conv_omop_limit_10k_confirmation_modal",
      confirm_btn_id = "confirm_conv_omop_limit_10k",
      input = input,
      session = session,
      on_change = function(limit) {
        omop_table_trigger(omop_table_trigger() + 1)
      },
      ns = ns
    )

    ## OMOP Filters (conversion modal) ----
    conv_omop_filters <- omop_filters_server(
      prefix = "conv_omop_filters",
      input = input,
      session = session,
      vocabularies = function() if (!is.null(vocabularies)) vocabularies() else NULL,
      settings_btn_id = "conv_omop_filters_btn",
      limit_checkbox_id = "conv_omop_limit_10k",
      on_apply = function(filters) {
        omop_table_trigger(omop_table_trigger() + 1)
      },
      on_clear = function() {
        omop_table_trigger(omop_table_trigger() + 1)
      },
      ns = ns
    )

    ## Show OMOP Filters Modal (conversion modal) ----
    observe_event(input$conv_omop_filters_btn, {
      conv_omop_filters$show()
    }, ignoreInit = TRUE)

    ## Fuzzy Search (recommended units modal) ----
    ru_omop_fuzzy <- fuzzy_search_server("ru_omop_fuzzy_search", input, session, trigger_rv = ru_omop_table_trigger, ns = ns)

    ## Limit 10K (recommended units modal) ----
    ru_omop_limit_10k <- limit_10k_server(
      checkbox_id = "ru_omop_limit_10k",
      modal_id = "ru_omop_limit_10k_confirmation_modal",
      confirm_btn_id = "confirm_ru_omop_limit_10k",
      input = input,
      session = session,
      on_change = function(limit) {
        ru_omop_table_trigger(ru_omop_table_trigger() + 1)
      },
      ns = ns
    )

    ## OMOP Filters (recommended units modal) ----
    ru_omop_filters <- omop_filters_server(
      prefix = "ru_omop_filters",
      input = input,
      session = session,
      vocabularies = function() if (!is.null(vocabularies)) vocabularies() else NULL,
      settings_btn_id = "ru_omop_filters_btn",
      limit_checkbox_id = "ru_omop_limit_10k",
      on_apply = function(filters) {
        ru_omop_table_trigger(ru_omop_table_trigger() + 1)
      },
      on_clear = function() {
        ru_omop_table_trigger(ru_omop_table_trigger() + 1)
      },
      ns = ns
    )

    ## Show OMOP Filters Modal (recommended units modal) ----
    observe_event(input$ru_omop_filters_btn, {
      ru_omop_filters$show()
    }, ignoreInit = TRUE)

    ## 2) Server - ETL Guidelines ----

    ### Fix Ace Editor Display on Tab Switch ----
    observe_event(input$dictionary_settings_tabs, {
      shinyjs::runjs("window.dispatchEvent(new Event('resize'));")
    }, ignoreInit = TRUE)

    ### Load ETL Guidelines on Init ----
    etl_content <- get_config_value("etl_guidelines")
    if (!is.null(etl_content) && nchar(etl_content) > 0) {
      shinyAce::updateAceEditor(session, "etl_guidelines_editor", value = etl_content)
    }

    ### Live Preview of ETL Guidelines ----
    observe_event(input$etl_guidelines_editor, {
      output$etl_guidelines_preview <- renderUI({
        text <- input$etl_guidelines_editor
        if (is.null(text) || nchar(text) == 0) {
          tags$div(
            style = "color: #999; font-style: italic; margin: 5px;",
            as.character(i18n$t("preview_placeholder"))
          )
        } else {
          html_content <- tryCatch({
            markdown::markdownToHTML(
              text = text,
              fragment.only = TRUE,
              options = c("use_xhtml", "smartypants", "base64_images", "mathjax", "highlight_code")
            )
          }, error = function(e) {
            paste0("<p style='color: red;'>Error rendering markdown: ", e$message, "</p>")
          })
          tags$div(class = "markdown-body", HTML(html_content))
        }
      })
    }, ignoreInit = FALSE)

    ### Save ETL Guidelines Handler ----
    observe_event(input$save_etl_guidelines_btn, {
      content_text <- input$etl_guidelines_editor
      if (is.null(content_text)) content_text <- ""
      set_config_value("etl_guidelines", content_text)
      showNotification(as.character(i18n$t("etl_guidelines_saved")), type = "message")
    }, ignoreInit = TRUE)

    ## 3) Server - Unit Conversions ----

    ### Load Conversions on Init ----
    conversions <- get_all_unit_conversions()
    unit_conversions_data(conversions)

    if (nrow(conversions) == 0) {
      default_csv <- system.file("extdata/concept_sets/unit_conversions.csv", package = "indicate")
      if (default_csv == "" || !file.exists(default_csv)) {
        default_csv <- "inst/extdata/concept_sets/unit_conversions.csv"
      }
      if (file.exists(default_csv)) {
        show_modal(ns("load_default_conversions_modal"))
      }
    }
    unit_conversions_trigger(1)

    ### DataTable Display ----
    observe_event(unit_conversions_trigger(), {
      conversions <- unit_conversions_data()

      # Toggle between no-content message and table
      if (is.null(conversions) || nrow(conversions) == 0) {
        shinyjs::show("no_conversions_message")
        shinyjs::hide("conversions_table_container")
        shinyjs::hide("conversions_fuzzy_search_container")
        return()
      }

      shinyjs::hide("no_conversions_message")
      shinyjs::show("conversions_table_container")
      shinyjs::show("conversions_fuzzy_search_container")

      output$unit_conversions_table <- DT::renderDT({
        conversions <- unit_conversions_data()
        if (is.null(conversions) || nrow(conversions) == 0) return(NULL)

        # Get concept names from vocabularies if available
        vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL

        # Prepare display data
        display_data <- conversions

        if (!is.null(vocab_data)) {
          # Get concept names for concept ID 1
          concept_ids_1 <- unique(conversions$omop_concept_id_1)
          concept_names_1 <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% concept_ids_1) %>%
            dplyr::select(concept_id, concept_name) %>%
            dplyr::collect()

          # Get concept names for concept ID 2
          concept_ids_2 <- unique(conversions$omop_concept_id_2)
          concept_names_2 <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% concept_ids_2) %>%
            dplyr::select(concept_id, concept_name) %>%
            dplyr::collect()

          # Get unit concept names
          unit_ids <- unique(c(conversions$unit_concept_id_1, conversions$unit_concept_id_2))
          unit_names <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% unit_ids) %>%
            dplyr::select(concept_id, concept_name) %>%
            dplyr::collect()

          # Merge names
          display_data <- conversions %>%
            dplyr::left_join(concept_names_1, by = c("omop_concept_id_1" = "concept_id")) %>%
            dplyr::rename(concept_name_1 = concept_name) %>%
            dplyr::left_join(concept_names_2, by = c("omop_concept_id_2" = "concept_id")) %>%
            dplyr::rename(concept_name_2 = concept_name) %>%
            dplyr::left_join(unit_names, by = c("unit_concept_id_1" = "concept_id")) %>%
            dplyr::rename(unit_name_1 = concept_name) %>%
            dplyr::left_join(unit_names, by = c("unit_concept_id_2" = "concept_id")) %>%
            dplyr::rename(unit_name_2 = concept_name)

          # Replace NA names with IDs
          display_data$concept_name_1 <- ifelse(
            is.na(display_data$concept_name_1),
            paste0("Concept ", display_data$omop_concept_id_1),
            display_data$concept_name_1
          )
          display_data$concept_name_2 <- ifelse(
            is.na(display_data$concept_name_2),
            paste0("Concept ", display_data$omop_concept_id_2),
            display_data$concept_name_2
          )
          display_data$unit_name_1 <- ifelse(
            is.na(display_data$unit_name_1),
            paste0("Unit ", display_data$unit_concept_id_1),
            display_data$unit_name_1
          )
          display_data$unit_name_2 <- ifelse(
            is.na(display_data$unit_name_2),
            paste0("Unit ", display_data$unit_concept_id_2),
            display_data$unit_name_2
          )
        } else {
          # No vocabulary data - use IDs as names
          display_data$concept_name_1 <- paste0("Concept ", conversions$omop_concept_id_1)
          display_data$concept_name_2 <- paste0("Concept ", conversions$omop_concept_id_2)
          display_data$unit_name_1 <- paste0("Unit ", conversions$unit_concept_id_1)
          display_data$unit_name_2 <- paste0("Unit ", conversions$unit_concept_id_2)
        }

        # Track original row indices before fuzzy search
        display_data$orig_row <- seq_len(nrow(display_data))

        # Apply fuzzy search filter
        query <- conversions_fuzzy$query()
        if (!is.null(query) && query != "" && nrow(display_data) > 0) {
          display_data <- fuzzy_search_df(display_data, query, "concept_name_1", max_dist = 3)
        }

        if (nrow(display_data) == 0) return(create_empty_datatable(as.character(i18n$t("no_unit_conversions"))))

        # Add action buttons using original row index
        display_data$actions <- sapply(seq_len(nrow(display_data)), function(i) {
          orig_i <- display_data$orig_row[i]
          create_datatable_actions(list(
            list(label = as.character(i18n$t("test")), icon = "calculator", type = "warning", class = "test-conversion-btn", data_attr = list(id = orig_i)),
            list(label = as.character(i18n$t("delete")), icon = "trash", type = "danger", class = "delete-conversion-btn", data_attr = list(id = orig_i))
          ))
        })

        # Select and order columns for display
        table_data <- display_data %>%
          dplyr::select(
            omop_concept_id_1,
            concept_name_1,
            unit_name_1,
            conversion_factor,
            omop_concept_id_2,
            concept_name_2,
            unit_name_2,
            actions
          )

        dt <- create_standard_datatable(
          table_data,
          selection = "single",
          filter = "top",
          escape = FALSE,
          page_length = 20,
          col_defs = list(
            list(width = "100px", targets = 0),
            list(width = "200px", targets = 1),
            list(width = "100px", targets = 2),
            list(width = "100px", targets = 3, className = "dt-center"),
            list(width = "100px", targets = 4),
            list(width = "200px", targets = 5),
            list(width = "100px", targets = 6),
            list(width = "160px", targets = 7, className = "dt-center", searchable = FALSE)
          ),
          col_names = c(
            as.character(i18n$t("concept_id_1")),
            as.character(i18n$t("concept_name_1")),
            as.character(i18n$t("unit_1")),
            as.character(i18n$t("conversion_factor")),
            as.character(i18n$t("concept_id_2")),
            as.character(i18n$t("concept_name_2")),
            as.character(i18n$t("unit_2")),
            as.character(i18n$t("actions"))
          )
        )

        add_button_handlers(dt, handlers = list(
          list(selector = ".test-conversion-btn", input_id = ns("test_conversion_click")),
          list(selector = ".delete-conversion-btn", input_id = ns("delete_conversion_click"))
        ))
      })
    }, ignoreInit = FALSE)

    ### Edit Handler - Update conversion factor on cell edit ----
    observe_event(input$unit_conversions_table_cell_edit, {
      info <- input$unit_conversions_table_cell_edit
      if (is.null(info)) return()

      # Only allow editing conversion_factor column (index 3, 0-based)
      if (info$col != 3) return()

      row <- info$row
      new_value <- as.numeric(info$value)

      if (is.na(new_value) || new_value <= 0) {
        showNotification(as.character(i18n$t("invalid_conversion_factor")), type = "error")
        return()
      }

      # Update the data
      conversions <- unit_conversions_data()
      if (!is.null(conversions) && row <= nrow(conversions)) {
        row_id <- conversions$id[row]
        conversions$conversion_factor[row] <- new_value

        # Save to database
        update_unit_conversion(row_id, new_value)

        unit_conversions_data(conversions)
        showNotification(as.character(i18n$t("conversion_factor_updated")), type = "message")
      }
    }, ignoreInit = TRUE)

    ### Delete Handler - Show confirmation modal ----
    observe_event(input$delete_conversion_click, {
      row_index <- input$delete_conversion_click
      if (is.null(row_index) || row_index < 1) return()

      conversions <- unit_conversions_data()
      if (!is.null(conversions) && row_index <= nrow(conversions)) {
        delete_row_index(row_index)
        show_modal(ns("delete_confirmation_modal"))
      }
    }, ignoreInit = TRUE)

    ### Confirm Delete Handler - Remove selected conversion ----
    observe_event(input$confirm_delete_btn, {
      row_index <- delete_row_index()
      if (is.null(row_index) || row_index < 1) return()

      conversions <- unit_conversions_data()
      if (!is.null(conversions) && row_index <= nrow(conversions)) {
        row_id <- conversions$id[row_index]

        # Delete from database
        delete_unit_conversion(row_id)

        # Refresh from database
        conversions <- get_all_unit_conversions()
        unit_conversions_data(conversions)
        unit_conversions_trigger(unit_conversions_trigger() + 1)

        # Close modal and show notification
        hide_modal(ns("delete_confirmation_modal"))
        showNotification(as.character(i18n$t("conversion_deleted")), type = "message")
      }

      # Reset the delete row index
      delete_row_index(NULL)
    }, ignoreInit = TRUE)

    ### Confirm Load Default Conversions ----
    observe_event(input$confirm_load_default_conversions, {
      result <- load_default_unit_conversions()

      if (is.numeric(result) && result > 0) {
        conversions <- get_all_unit_conversions()
        unit_conversions_data(conversions)
        unit_conversions_trigger(unit_conversions_trigger() + 1)

        message_text <- gsub("\\{count\\}", as.character(result), as.character(i18n$t("load_default_conversions_success")))
        showNotification(message_text, type = "message", duration = 5)
      } else {
        showNotification(as.character(i18n$t("load_default_conversions_failed")), type = "error", duration = 5)
      }

      hide_modal(ns("load_default_conversions_modal"))
    }, ignoreInit = TRUE)

    ### Cancel Load Default Conversions ----
    observe_event(input$cancel_load_default_conversions, {
      hide_modal(ns("load_default_conversions_modal"))
    }, ignoreInit = TRUE)

    ### Test Conversion Modal ----
    observe_event(input$test_conversion_click, {
      row_index <- input$test_conversion_click
      if (is.null(row_index) || row_index < 1) return()

      conversions <- unit_conversions_data()
      if (!is.null(conversions) && row_index <= nrow(conversions)) {
        test_conversion_row(conversions[row_index, ])
        show_modal(ns("test_conversion_modal"))
      }
    }, ignoreInit = TRUE)

    # Display conversion info
    observe_event(test_conversion_row(), {
      conv <- test_conversion_row()
      if (is.null(conv)) return()

      # Get concept names and unit codes from vocabulary
      vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL
      concept_name_1 <- paste0("Concept ", conv$omop_concept_id_1)
      concept_name_2 <- paste0("Concept ", conv$omop_concept_id_2)
      unit_code_1 <- ""
      unit_code_2 <- ""

      if (!is.null(vocab_data)) {
        concept_info <- vocab_data$concept %>%
          dplyr::filter(concept_id %in% c(conv$omop_concept_id_1, conv$omop_concept_id_2, conv$unit_concept_id_1, conv$unit_concept_id_2)) %>%
          dplyr::select(concept_id, concept_name, concept_code) %>%
          dplyr::collect()

        c1 <- concept_info[concept_info$concept_id == conv$omop_concept_id_1, ]
        c2 <- concept_info[concept_info$concept_id == conv$omop_concept_id_2, ]
        u1 <- concept_info[concept_info$concept_id == conv$unit_concept_id_1, ]
        u2 <- concept_info[concept_info$concept_id == conv$unit_concept_id_2, ]

        if (nrow(c1) > 0) concept_name_1 <- c1$concept_name[1]
        if (nrow(c2) > 0) concept_name_2 <- c2$concept_name[1]
        if (nrow(u1) > 0) unit_code_1 <- u1$concept_code[1]
        if (nrow(u2) > 0) unit_code_2 <- u2$concept_code[1]
      }

      # Store unit 2 for result display
      test_unit_code_2(unit_code_2)

      output$test_conversion_info <- renderUI({
        tags$div(
          style = "background: #f8f9fa; padding: 15px; border-radius: 4px;",
          tags$p(
            style = "margin: 0; font-size: 14px;",
            tags$strong(concept_name_1), if (unit_code_1 != "") paste0(" (", unit_code_1, ")") else "",
            tags$span(style = "margin: 0 10px;", "\u2192"),
            tags$strong(concept_name_2), if (unit_code_2 != "") paste0(" (", unit_code_2, ")") else ""
          )
        )
      })

      # Update labels
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_value_1_label"), concept_name_1))
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_value_2_label"), concept_name_2))
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_unit_1_display"), unit_code_1))
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_factor_display"), conv$conversion_factor))

      # Trigger initial calculation
      input_val <- input$test_value_1
      if (is.null(input_val) || is.na(input_val)) input_val <- 1
      result <- input_val * conv$conversion_factor
      result_text <- paste0(round(result, 6), " ", unit_code_2)
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_result_display"), result_text))
    }, ignoreInit = TRUE)

    # Calculate result when value changes
    observe_event(input$test_value_1, {
      conv <- test_conversion_row()
      if (is.null(conv)) return()

      input_val <- input$test_value_1
      if (is.null(input_val) || is.na(input_val)) input_val <- 0

      result <- input_val * conv$conversion_factor
      unit_code_2 <- test_unit_code_2()
      result_text <- paste0(round(result, 6), " ", unit_code_2)
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("test_result_display"), result_text))
    }, ignoreInit = FALSE)

    ### Add Conversion Modal ----

    # Open modal
    observe_event(input$add_conversion_btn, {
      # Reset fields
      updateTextInput(session, "new_concept_id_1", value = "")
      updateTextInput(session, "new_unit_id_1", value = "")
      updateNumericInput(session, "new_conversion_factor", value = 1)
      updateTextInput(session, "new_concept_id_2", value = "")
      updateTextInput(session, "new_unit_id_2", value = "")

      # Hide error messages
      shinyjs::runjs(sprintf("$('#%s, #%s, #%s, #%s, #%s').hide();",
        ns("new_concept_id_1_error"),
        ns("new_unit_id_1_error"),
        ns("new_conversion_factor_error"),
        ns("new_concept_id_2_error"),
        ns("new_unit_id_2_error")
      ))

      # Hide conversion preview
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("conversion_preview")))

      # Clear fuzzy search
      conv_omop_fuzzy$clear()

      # Show fullscreen modal
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'flex';", ns("add_conversion_modal")))

      # Trigger OMOP table rendering after modal is visible
      shinyjs::delay(300, {
        omop_table_trigger(omop_table_trigger() + 1)
      })

      # Force Shiny to detect the output is now visible and render it
      shinyjs::delay(500, {
        shinyjs::runjs(sprintf("
          $(window).trigger('resize');
          var $el = $('#%s');
          if ($el.length) {
            $el.trigger('shown');
            Shiny.bindAll($el.parent());
          }
        ", ns("omop_search_table")))
      })
    }, ignoreInit = TRUE)

    # Initialize OMOP search table (required for outputOptions)
    output$omop_search_table <- DT::renderDT({
      create_empty_datatable("")
    })
    outputOptions(output, "omop_search_table", suspendWhenHidden = FALSE)

    # OMOP Concepts Table in Conversion Modal
    observe_event(omop_table_trigger(), {
      vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL

      if (is.null(vocab_data)) {
        output$omop_search_table <- DT::renderDT({
          create_empty_datatable(as.character(i18n$t("loading_vocabularies")))
        })
        return()
      }

      # Get fuzzy query
      fuzzy_query <- conv_omop_fuzzy$query()
      fuzzy_active <- !is.null(fuzzy_query) && fuzzy_query != ""

      # Get filters
      filters <- conv_omop_filters$filters()

      # Get limit setting
      use_limit <- isTRUE(conv_omop_limit_10k())
      row_limit <- if (use_limit) 10000 else 1000000

      # Build query
      base_query <- vocab_data$concept %>%
        dplyr::select(
          concept_id,
          concept_name,
          vocabulary_id,
          domain_id,
          concept_class_id,
          concept_code,
          standard_concept,
          invalid_reason
        )

      # Apply filters
      if (length(filters$vocabulary_id) > 0) {
        base_query <- base_query %>% dplyr::filter(vocabulary_id %in% !!filters$vocabulary_id)
      }
      if (length(filters$domain_id) > 0) {
        base_query <- base_query %>% dplyr::filter(domain_id %in% !!filters$domain_id)
      }
      if (length(filters$concept_class_id) > 0) {
        base_query <- base_query %>% dplyr::filter(concept_class_id %in% !!filters$concept_class_id)
      }
      if (length(filters$standard_concept) > 0) {
        std_values <- filters$standard_concept
        std_values <- gsub("NS", "", std_values)
        base_query <- base_query %>%
          dplyr::filter(standard_concept %in% !!std_values | (is.na(standard_concept) & "" %in% !!std_values))
      }
      if (length(filters$validity) > 0) {
        if ("Valid" %in% filters$validity && !"Invalid" %in% filters$validity) {
          base_query <- base_query %>% dplyr::filter(is.na(invalid_reason) | invalid_reason == "")
        } else if ("Invalid" %in% filters$validity && !"Valid" %in% filters$validity) {
          base_query <- base_query %>% dplyr::filter(!is.na(invalid_reason) & invalid_reason != "")
        }
      }

      # Apply fuzzy search if active
      if (fuzzy_active) {
        query_escaped <- gsub("'", "''", tolower(fuzzy_query))
        concepts <- base_query %>%
          dplyr::mutate(
            fuzzy_score = dplyr::sql(sprintf(
              "jaro_winkler_similarity(lower(concept_name), '%s')",
              query_escaped
            ))
          ) %>%
          dplyr::filter(fuzzy_score > 0.75) %>%
          dplyr::arrange(dplyr::desc(fuzzy_score)) %>%
          utils::head(row_limit) %>%
          dplyr::collect()
      } else {
        concepts <- base_query %>%
          dplyr::arrange(concept_name) %>%
          utils::head(row_limit) %>%
          dplyr::collect()
      }

      # Cache concepts for selection
      omop_concepts_cache(concepts)

      if (nrow(concepts) == 0) {
        output$omop_search_table <- DT::renderDT({
          create_empty_datatable(as.character(i18n$t("no_matching_concepts")))
        })
        return()
      }

      # Prepare display data
      display_concepts <- concepts %>%
        dplyr::select(concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept)

      display_concepts$concept_id <- as.character(display_concepts$concept_id)
      display_concepts$vocabulary_id <- as.factor(display_concepts$vocabulary_id)
      display_concepts$domain_id <- as.factor(display_concepts$domain_id)
      display_concepts$concept_class_id <- as.factor(display_concepts$concept_class_id)

      output$omop_search_table <- DT::renderDT({
        create_standard_datatable(
          display_concepts,
          selection = "single",
          page_length = 20,
          col_names = c(
            as.character(i18n$t("concept_id")),
            as.character(i18n$t("concept_name")),
            as.character(i18n$t("vocabulary")),
            as.character(i18n$t("domain")),
            as.character(i18n$t("concept_class")),
            as.character(i18n$t("code")),
            "S"
          ),
          col_defs = list(
            list(targets = 0, width = "80px"),
            list(targets = 1, width = "250px"),
            list(targets = 2, width = "100px"),
            list(targets = 3, width = "100px"),
            list(targets = 4, width = "120px"),
            list(targets = 5, width = "100px"),
            list(targets = 6, width = "50px", className = "dt-center")
          )
        )
      }, server = TRUE)
    }, ignoreInit = TRUE)

    # Handle "Add as" dropdown selection
    observe_event(input$add_as_selection, {
      selection <- input$add_as_selection
      selected_rows <- input$omop_search_table_rows_selected

      if (is.null(selection) || length(selected_rows) == 0) {
        showNotification(as.character(i18n$t("select_concept_first")), type = "warning")
        return()
      }

      data <- omop_concepts_cache()
      if (is.null(data)) return()
      if (selected_rows[1] > nrow(data)) return()

      selected_concept <- data[selected_rows[1], ]
      concept_id <- as.character(selected_concept$concept_id)

      if (selection == "concept_1") {
        updateTextInput(session, "new_concept_id_1", value = concept_id)
      } else if (selection == "unit_1") {
        updateTextInput(session, "new_unit_id_1", value = concept_id)
      } else if (selection == "concept_2") {
        updateTextInput(session, "new_concept_id_2", value = concept_id)
      } else if (selection == "unit_2") {
        updateTextInput(session, "new_unit_id_2", value = concept_id)
      }

      # Trigger preview update
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    # Update preview when text inputs change manually
    observe_event(input$new_concept_id_1, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(input$new_unit_id_1, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(input$new_concept_id_2, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(input$new_unit_id_2, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(input$new_conversion_factor, {
      preview_trigger(preview_trigger() + 1)
    }, ignoreInit = TRUE)

    # Helper function to get concept name from ID
    get_concept_name <- function(concept_id_str) {
      if (is.null(concept_id_str) || concept_id_str == "") return("")

      concept_id_num <- suppressWarnings(as.integer(concept_id_str))
      if (is.na(concept_id_num)) return("")

      vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL
      if (is.null(vocab_data)) return("")

      concept_info <- vocab_data$concept %>%
        dplyr::filter(concept_id == concept_id_num) %>%
        dplyr::select(concept_name) %>%
        dplyr::collect()

      if (nrow(concept_info) > 0) {
        return(concept_info$concept_name[1])
      }
      return(as.character(i18n$t("concept_not_found")))
    }

    # Update conversion preview display
    observe_event(preview_trigger(), {
      concept_1 <- get_concept_name(input$new_concept_id_1)
      unit_1 <- get_concept_name(input$new_unit_id_1)
      concept_2 <- get_concept_name(input$new_concept_id_2)
      unit_2 <- get_concept_name(input$new_unit_id_2)
      factor <- input$new_conversion_factor

      # Check if at least one field has content
      has_content <- any(c(concept_1, unit_1, concept_2, unit_2) != "")

      if (has_content) {
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("preview_concept_1"), if (concept_1 != "") concept_1 else "?"))
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("preview_unit_1"), if (unit_1 != "") unit_1 else "?"))
        shinyjs::runjs(sprintf("$('#%s').text('\u00D7 %s');", ns("preview_factor"), if (!is.null(factor) && !is.na(factor)) factor else "1"))
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("preview_concept_2"), if (concept_2 != "") concept_2 else "?"))
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("preview_unit_2"), if (unit_2 != "") unit_2 else "?"))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("conversion_preview")))
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("conversion_preview")))
      }
    }, ignoreInit = TRUE)

    ### Save New Conversion ----
    observe_event(input$save_new_conversion_btn, {
      # Get values
      concept_id_1 <- input$new_concept_id_1
      unit_id_1 <- input$new_unit_id_1
      conversion_factor <- input$new_conversion_factor
      concept_id_2 <- input$new_concept_id_2
      unit_id_2 <- input$new_unit_id_2

      # Validate
      has_error <- FALSE

      if (is.null(concept_id_1) || concept_id_1 == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_concept_id_1_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_concept_id_1_error")))
      }

      if (is.null(unit_id_1) || unit_id_1 == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_unit_id_1_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_unit_id_1_error")))
      }

      if (is.null(conversion_factor) || is.na(conversion_factor) || conversion_factor <= 0) {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_conversion_factor_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_conversion_factor_error")))
      }

      if (is.null(concept_id_2) || concept_id_2 == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_concept_id_2_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_concept_id_2_error")))
      }

      if (is.null(unit_id_2) || unit_id_2 == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_unit_id_2_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_unit_id_2_error")))
      }

      if (has_error) return()

      # Add to database
      result <- add_unit_conversion(
        omop_concept_id_1 = as.integer(concept_id_1),
        unit_concept_id_1 = as.integer(unit_id_1),
        conversion_factor = as.numeric(conversion_factor),
        omop_concept_id_2 = as.integer(concept_id_2),
        unit_concept_id_2 = as.integer(unit_id_2)
      )

      if (identical(result, FALSE)) {
        showNotification(as.character(i18n$t("conversion_already_exists")), type = "warning")
        return()
      }

      # Refresh from database
      conversions <- get_all_unit_conversions()
      unit_conversions_data(conversions)
      unit_conversions_trigger(unit_conversions_trigger() + 1)

      # Close fullscreen modal
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", ns("add_conversion_modal")))
      showNotification(as.character(i18n$t("conversion_added")), type = "message")
    }, ignoreInit = TRUE)

    ## 4) Server - Recommended Units ----

    ### Load Recommended Units on Init ----
    ru_data <- get_all_recommended_units()
    recommended_units_data(ru_data)

    if (nrow(ru_data) == 0) {
      default_ru_csv <- system.file("extdata/concept_sets/recommended_units.csv", package = "indicate")
      if (default_ru_csv == "" || !file.exists(default_ru_csv)) {
        default_ru_csv <- "inst/extdata/concept_sets/recommended_units.csv"
      }
      if (file.exists(default_ru_csv)) {
        show_modal(ns("load_default_recommended_units_modal"))
      }
    }
    recommended_units_trigger(1)

    ### Recommended Units DataTable Display ----
    observe_event(recommended_units_trigger(), {
      ru <- recommended_units_data()

      if (is.null(ru) || nrow(ru) == 0) {
        shinyjs::show("no_recommended_units_message")
        shinyjs::hide("recommended_units_table_container")
        shinyjs::hide("recommended_units_fuzzy_search_container")
        return()
      }

      shinyjs::hide("no_recommended_units_message")
      shinyjs::show("recommended_units_table_container")
      shinyjs::show("recommended_units_fuzzy_search_container")

      output$recommended_units_table <- DT::renderDT({
        ru <- recommended_units_data()
        if (is.null(ru) || nrow(ru) == 0) return(NULL)

        vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL
        display_data <- ru

        if (!is.null(vocab_data)) {
          concept_ids <- unique(c(ru$concept_id, ru$recommended_unit_concept_id))
          concept_info <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% concept_ids) %>%
            dplyr::select(concept_id, concept_name, concept_code) %>%
            dplyr::collect()

          display_data <- ru %>%
            dplyr::left_join(concept_info, by = "concept_id") %>%
            dplyr::rename(measurement_name = concept_name, measurement_code = concept_code) %>%
            dplyr::left_join(concept_info, by = c("recommended_unit_concept_id" = "concept_id")) %>%
            dplyr::rename(unit_name = concept_name, unit_code = concept_code)

          display_data$measurement_name <- ifelse(
            is.na(display_data$measurement_name),
            paste0("Concept ", display_data$concept_id),
            display_data$measurement_name
          )
          display_data$unit_name <- ifelse(
            is.na(display_data$unit_name),
            paste0("Unit ", display_data$recommended_unit_concept_id),
            display_data$unit_name
          )
          display_data$unit_code <- ifelse(is.na(display_data$unit_code), "", display_data$unit_code)
          display_data$measurement_code <- ifelse(is.na(display_data$measurement_code), "", display_data$measurement_code)
        } else {
          display_data$measurement_name <- paste0("Concept ", ru$concept_id)
          display_data$measurement_code <- ""
          display_data$unit_name <- paste0("Unit ", ru$recommended_unit_concept_id)
          display_data$unit_code <- ""
        }

        # Track original row indices before fuzzy search
        display_data$orig_row <- seq_len(nrow(display_data))

        # Apply fuzzy search filter
        query <- recommended_units_fuzzy$query()
        if (!is.null(query) && query != "" && nrow(display_data) > 0) {
          display_data <- fuzzy_search_df(display_data, query, "measurement_name", max_dist = 3)
        }

        if (nrow(display_data) == 0) return(create_empty_datatable(as.character(i18n$t("no_recommended_units"))))

        # Add action buttons using original row index
        display_data$actions <- sapply(seq_len(nrow(display_data)), function(i) {
          orig_i <- display_data$orig_row[i]
          create_datatable_actions(list(
            list(label = as.character(i18n$t("delete")), icon = "trash", type = "danger", class = "delete-recommended-unit-btn", data_attr = list(id = orig_i))
          ))
        })

        table_data <- display_data %>%
          dplyr::select(
            concept_id,
            measurement_name,
            measurement_code,
            recommended_unit_concept_id,
            unit_name,
            unit_code,
            actions
          )

        dt <- create_standard_datatable(
          table_data,
          selection = "single",
          filter = "top",
          escape = FALSE,
          page_length = 20,
          col_defs = list(
            list(width = "80px", targets = 0),
            list(width = "300px", targets = 1),
            list(width = "100px", targets = 2),
            list(width = "80px", targets = 3),
            list(width = "200px", targets = 4),
            list(width = "100px", targets = 5),
            list(width = "100px", targets = 6, className = "dt-center", searchable = FALSE)
          ),
          col_names = c(
            as.character(i18n$t("concept_id")),
            as.character(i18n$t("measurement")),
            as.character(i18n$t("code")),
            as.character(i18n$t("unit_concept_id")),
            as.character(i18n$t("unit")),
            as.character(i18n$t("unit_code")),
            as.character(i18n$t("actions"))
          )
        )

        add_button_handlers(dt, handlers = list(
          list(selector = ".delete-recommended-unit-btn", input_id = ns("delete_recommended_unit_click"))
        ))
      })
    }, ignoreInit = FALSE)

    ### Confirm Load Default Recommended Units ----
    observe_event(input$confirm_load_default_recommended_units, {
      result <- load_default_recommended_units()

      if (is.numeric(result) && result > 0) {
        ru <- get_all_recommended_units()
        recommended_units_data(ru)
        recommended_units_trigger(recommended_units_trigger() + 1)

        message_text <- gsub("\\{count\\}", as.character(result), as.character(i18n$t("load_default_recommended_units_success")))
        showNotification(message_text, type = "message", duration = 5)
      } else {
        showNotification(as.character(i18n$t("load_default_recommended_units_failed")), type = "error", duration = 5)
      }

      hide_modal(ns("load_default_recommended_units_modal"))
    }, ignoreInit = TRUE)

    ### Cancel Load Default Recommended Units ----
    observe_event(input$cancel_load_default_recommended_units, {
      hide_modal(ns("load_default_recommended_units_modal"))
    }, ignoreInit = TRUE)

    ### Delete Recommended Unit Handler ----
    observe_event(input$delete_recommended_unit_click, {
      row_index <- input$delete_recommended_unit_click
      if (is.null(row_index) || row_index < 1) return()

      ru <- recommended_units_data()
      if (!is.null(ru) && row_index <= nrow(ru)) {
        ru_delete_row_index(row_index)
        show_modal(ns("delete_recommended_unit_modal"))
      }
    }, ignoreInit = TRUE)

    ### Confirm Delete Recommended Unit ----
    observe_event(input$confirm_delete_recommended_unit_btn, {
      row_index <- ru_delete_row_index()
      if (is.null(row_index) || row_index < 1) return()

      ru <- recommended_units_data()
      if (!is.null(ru) && row_index <= nrow(ru)) {
        row_id <- ru$id[row_index]

        # Delete from database
        delete_recommended_unit(row_id)

        # Refresh from database
        ru <- get_all_recommended_units()
        recommended_units_data(ru)
        recommended_units_trigger(recommended_units_trigger() + 1)

        hide_modal(ns("delete_recommended_unit_modal"))
        showNotification(as.character(i18n$t("recommended_unit_deleted")), type = "message")
      }

      ru_delete_row_index(NULL)
    }, ignoreInit = TRUE)

    ### Add Recommended Unit Modal ----

    # Open modal
    observe_event(input$add_recommended_unit_btn, {
      # Reset fields
      updateTextInput(session, "new_ru_concept_id", value = "")
      updateTextInput(session, "new_ru_unit_concept_id", value = "")

      # Hide error messages
      shinyjs::runjs(sprintf("$('#%s, #%s').hide();",
        ns("new_ru_concept_id_error"),
        ns("new_ru_unit_concept_id_error")
      ))

      # Hide preview
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("ru_preview")))

      # Clear fuzzy search
      ru_omop_fuzzy$clear()

      # Show fullscreen modal
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'flex';", ns("add_recommended_unit_modal")))

      # Trigger OMOP table rendering after modal is visible
      shinyjs::delay(300, {
        ru_omop_table_trigger(ru_omop_table_trigger() + 1)
      })

      # Force Shiny to detect the output is now visible and render it
      shinyjs::delay(500, {
        shinyjs::runjs(sprintf("
          $(window).trigger('resize');
          var $el = $('#%s');
          if ($el.length) {
            $el.trigger('shown');
            Shiny.bindAll($el.parent());
          }
        ", ns("ru_omop_search_table")))
      })
    }, ignoreInit = TRUE)

    # Initialize RU OMOP search table (required for outputOptions)
    output$ru_omop_search_table <- DT::renderDT({
      create_empty_datatable("")
    })
    outputOptions(output, "ru_omop_search_table", suspendWhenHidden = FALSE)

    # OMOP Concepts Table in Recommended Units Modal
    observe_event(ru_omop_table_trigger(), {
      vocab_data <- if (!is.null(vocabularies)) vocabularies() else NULL

      if (is.null(vocab_data)) {
        output$ru_omop_search_table <- DT::renderDT({
          create_empty_datatable(as.character(i18n$t("loading_vocabularies")))
        })
        return()
      }

      # Get fuzzy query
      fuzzy_query <- ru_omop_fuzzy$query()
      fuzzy_active <- !is.null(fuzzy_query) && fuzzy_query != ""

      # Get filters
      filters <- ru_omop_filters$filters()

      # Get limit setting
      use_limit <- isTRUE(ru_omop_limit_10k())
      row_limit <- if (use_limit) 10000 else 1000000

      # Build query
      base_query <- vocab_data$concept %>%
        dplyr::select(
          concept_id,
          concept_name,
          vocabulary_id,
          domain_id,
          concept_class_id,
          concept_code,
          standard_concept,
          invalid_reason
        )

      # Apply filters
      if (length(filters$vocabulary_id) > 0) {
        base_query <- base_query %>% dplyr::filter(vocabulary_id %in% !!filters$vocabulary_id)
      }
      if (length(filters$domain_id) > 0) {
        base_query <- base_query %>% dplyr::filter(domain_id %in% !!filters$domain_id)
      }
      if (length(filters$concept_class_id) > 0) {
        base_query <- base_query %>% dplyr::filter(concept_class_id %in% !!filters$concept_class_id)
      }
      if (length(filters$standard_concept) > 0) {
        std_values <- filters$standard_concept
        std_values <- gsub("NS", "", std_values)
        base_query <- base_query %>%
          dplyr::filter(standard_concept %in% !!std_values | (is.na(standard_concept) & "" %in% !!std_values))
      }
      if (length(filters$validity) > 0) {
        if ("Valid" %in% filters$validity && !"Invalid" %in% filters$validity) {
          base_query <- base_query %>% dplyr::filter(is.na(invalid_reason) | invalid_reason == "")
        } else if ("Invalid" %in% filters$validity && !"Valid" %in% filters$validity) {
          base_query <- base_query %>% dplyr::filter(!is.na(invalid_reason) & invalid_reason != "")
        }
      }

      # Apply fuzzy search if active
      if (fuzzy_active) {
        query_escaped <- gsub("'", "''", tolower(fuzzy_query))
        concepts <- base_query %>%
          dplyr::mutate(
            fuzzy_score = dplyr::sql(sprintf(
              "jaro_winkler_similarity(lower(concept_name), '%s')",
              query_escaped
            ))
          ) %>%
          dplyr::filter(fuzzy_score > 0.75) %>%
          dplyr::arrange(dplyr::desc(fuzzy_score)) %>%
          utils::head(row_limit) %>%
          dplyr::collect()
      } else {
        concepts <- base_query %>%
          dplyr::arrange(concept_name) %>%
          utils::head(row_limit) %>%
          dplyr::collect()
      }

      # Cache concepts for selection
      ru_omop_concepts_cache(concepts)

      if (nrow(concepts) == 0) {
        output$ru_omop_search_table <- DT::renderDT({
          create_empty_datatable(as.character(i18n$t("no_matching_concepts")))
        })
        return()
      }

      # Prepare display data
      display_concepts <- concepts %>%
        dplyr::select(concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept)

      display_concepts$concept_id <- as.character(display_concepts$concept_id)
      display_concepts$vocabulary_id <- as.factor(display_concepts$vocabulary_id)
      display_concepts$domain_id <- as.factor(display_concepts$domain_id)
      display_concepts$concept_class_id <- as.factor(display_concepts$concept_class_id)

      output$ru_omop_search_table <- DT::renderDT({
        create_standard_datatable(
          display_concepts,
          selection = "single",
          page_length = 20,
          col_names = c(
            as.character(i18n$t("concept_id")),
            as.character(i18n$t("concept_name")),
            as.character(i18n$t("vocabulary")),
            as.character(i18n$t("domain")),
            as.character(i18n$t("concept_class")),
            as.character(i18n$t("code")),
            "S"
          ),
          col_defs = list(
            list(targets = 0, width = "80px"),
            list(targets = 1, width = "250px"),
            list(targets = 2, width = "100px"),
            list(targets = 3, width = "100px"),
            list(targets = 4, width = "120px"),
            list(targets = 5, width = "100px"),
            list(targets = 6, width = "50px", className = "dt-center")
          )
        )
      }, server = TRUE)
    }, ignoreInit = TRUE)

    # Handle "Add as" dropdown selection for recommended units
    observe_event(input$ru_add_as_selection, {
      selection <- input$ru_add_as_selection
      selected_rows <- input$ru_omop_search_table_rows_selected

      if (is.null(selection) || length(selected_rows) == 0) {
        showNotification(as.character(i18n$t("select_concept_first")), type = "warning")
        return()
      }

      data <- ru_omop_concepts_cache()
      if (is.null(data)) return()
      if (selected_rows[1] > nrow(data)) return()

      selected_concept <- data[selected_rows[1], ]
      concept_id <- as.character(selected_concept$concept_id)

      if (selection == "concept") {
        updateTextInput(session, "new_ru_concept_id", value = concept_id)
      } else if (selection == "unit") {
        updateTextInput(session, "new_ru_unit_concept_id", value = concept_id)
      }

      ru_preview_trigger(ru_preview_trigger() + 1)
    }, ignoreInit = TRUE)

    # Update preview when text inputs change
    observe_event(input$new_ru_concept_id, {
      ru_preview_trigger(ru_preview_trigger() + 1)
    }, ignoreInit = TRUE)

    observe_event(input$new_ru_unit_concept_id, {
      ru_preview_trigger(ru_preview_trigger() + 1)
    }, ignoreInit = TRUE)

    # Update recommended unit preview display
    observe_event(ru_preview_trigger(), {
      concept_name <- get_concept_name(input$new_ru_concept_id)
      unit_name <- get_concept_name(input$new_ru_unit_concept_id)

      has_content <- any(c(concept_name, unit_name) != "")

      if (has_content) {
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("ru_preview_concept"), if (concept_name != "") concept_name else "?"))
        shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("ru_preview_unit"), if (unit_name != "") unit_name else "?"))
        shinyjs::runjs(sprintf("$('#%s').show();", ns("ru_preview")))
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("ru_preview")))
      }
    }, ignoreInit = TRUE)

    ### Save New Recommended Unit ----
    observe_event(input$save_new_recommended_unit_btn, {
      concept_id <- input$new_ru_concept_id
      unit_concept_id <- input$new_ru_unit_concept_id

      has_error <- FALSE

      if (is.null(concept_id) || concept_id == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_ru_concept_id_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_ru_concept_id_error")))
      }

      if (is.null(unit_concept_id) || unit_concept_id == "") {
        shinyjs::runjs(sprintf("$('#%s').show();", ns("new_ru_unit_concept_id_error")))
        has_error <- TRUE
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("new_ru_unit_concept_id_error")))
      }

      if (has_error) return()

      # Add to database
      result <- add_recommended_unit(
        concept_id = as.integer(concept_id),
        recommended_unit_concept_id = as.integer(unit_concept_id)
      )

      if (identical(result, FALSE)) {
        showNotification(as.character(i18n$t("recommended_unit_already_exists")), type = "warning")
        return()
      }

      # Refresh from database
      ru <- get_all_recommended_units()
      recommended_units_data(ru)
      recommended_units_trigger(recommended_units_trigger() + 1)

      # Close fullscreen modal
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", ns("add_recommended_unit_modal")))
      showNotification(as.character(i18n$t("recommended_unit_added")), type = "message")
    }, ignoreInit = TRUE)

    ## 5) Server - Tab Switching ----

    ### Toggle action buttons based on active tab ----
    observe_event(input$dictionary_settings_tabs, {
      active_tab <- input$dictionary_settings_tabs
      if (is.null(active_tab)) return()

      if (active_tab == "etl_guidelines") {
        shinyjs::show("save_btn_container")
      } else {
        shinyjs::hide("save_btn_container")
      }
    }, ignoreInit = FALSE)
  })
}
