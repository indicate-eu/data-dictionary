# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Dictionary Explorer interface with two main views:
# - General Concepts Page: Browse and manage general concepts
# - Associated Concepts Page: View and edit associated concepts
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Breadcrumb & Action Buttons Container - Navigation breadcrumbs and action buttons
#      ### Content Area (Tables & Containers) - Main content panels for both views
#   ## UI - Modals
#      ### Modal - Add New General Concept - Form to create new general concepts
#      ### Modal - Add Mapping to General Concept - Search and add concepts
#      ### Modal - Concept Details Viewer - Display detailed concept information
#      ### Modal - Hierarchy Graph Fullscreen - Fullscreen hierarchy visualization
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### View & Selection State - Track current view and selected concepts
#      ### Edit Mode State - Manage edit/view mode and edited data
#      ### Data Management - Local data and configuration
#      ### Cascade Triggers - Reactive triggers for cascade pattern
#
#   ## 2) Server - Navigation & Events
#      ### Trigger Updates - Cascade observers that propagate state changes
#      ### Buttons visibility - Dynamic button visibility based on user/view/mode
#      ### Vocabulary Loading Status - Track OHDSI vocabulary loading
#      ### Breadcrumb Rendering - Dynamic breadcrumb navigation
#      ### Category Filtering - Filter general concepts by category badges
#      ### View Switching (List/Detail/History) - Handle navigation between views
#
#   ## 3) Server - General Concepts Page
#      ### General Concepts Table Rendering - Display general concepts table
#      ### List Edit Mode - Edit general concepts (comments, etc.)
#      ### Delete Concept - Remove general concepts
#      ### Add New Concept - Create new general concepts
#
#   ## 4) Server - General Concept Detail Page
#      #### Save Updates - Save changes to mappings and concept details
#      ### a) Mapped Concepts (Top-Left Panel)
#         #### Mapped Concepts Table Rendering - Display concept mappings
#         #### Add Mapping to Selected Concept - Add new mappings
#      ### b) Selected Mapping Details (Top-Right Panel)
#         #### Selected Mapping Display - Show selected mapping details
#      ### c) ETL Guidance & Comments (Bottom-Left Panel)
#         #### Comments & Statistical Summary Display - Display/edit comments and stats
#      ### d) Concept Relationships & Hierarchy (Bottom-Right Panel)
#         #### Tab Switching - Switch between Related/Hierarchy/Synonyms tabs
#         #### Relationship Tab Outputs - Render relationship tables and graphs
#         #### Hierarchy Graph Fullscreen Modal - Fullscreen hierarchy modal
#         #### Concept Details Modal (Double-click on Related/Hierarchy) - Quick concept details
#
# REACTIVITY OVERVIEW ====
#
# This module uses a CASCADE PATTERN for reactivity management.
# Instead of having observers with multiple triggers like observe_event(c(a(), b(), c())),
# we have:
#   1. PRIMARY STATE REACTIVES: The actual state values (current_view, selected_concept_id, etc.)
#   2. PRIMARY TRIGGERS: Fire when state changes (view_trigger, concept_trigger, etc.)
#   3. CASCADE OBSERVERS: Listen to primary triggers and fire COMPOSITE TRIGGERS
#   4. COMPOSITE TRIGGERS: Aggregated triggers that UI observers listen to
#   5. UI OBSERVERS: Render outputs when their composite trigger fires
#
# This creates a clear, traceable flow: State Change -> Primary Trigger -> Cascade -> Composite Trigger -> UI Update
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ PRIMARY STATE REACTIVES (reactiveVal)                                                           │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │ current_view                  - "list", "detail", "detail_history", "list_history"              │
# │ selected_concept_id           - Currently selected general concept ID                           │
# │ selected_mapped_concept_id    - Currently selected mapping in concept_mappings_table            │
# │ selected_categories           - Category filter badges selection                                │
# │ general_concept_detail_edit_mode - Edit mode for detail page (TRUE/FALSE)                       │
# │ general_concepts_edit_mode    - Edit mode for list page (TRUE/FALSE)                            │
# │ comments_tab                  - "comments" or "statistical_summary"                             │
# │ relationships_tab             - "related", "hierarchy", or "synonyms"                           │
# │ local_data                    - Local copy of CSV data                                          │
# │ deleted_concepts              - Temporary deleted mappings before save                          │
# │ added_concepts                - Temporary added mappings before save                            │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ CASCADE FLOW DIAGRAM                                                                            │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  PRIMARY STATE              PRIMARY TRIGGER           CASCADE OBSERVER           COMPOSITE      │
# │  CHANGE                     (fires)                   (propagates to)            TRIGGERS       │
# │  ─────────────────────────────────────────────────────────────────────────────────────────────  │
# │                                                                                                 │
# │  current_view() ──────────► view_trigger ──────────► observe_event(view_trigger)               │
# │                                                       ├──► breadcrumb_trigger                  │
# │                                                       └──► history_ui_trigger                  │
# │                                                                                                 │
# │  selected_concept_id() ───► concept_trigger ───────► observe_event(concept_trigger)            │
# │                                                       ├──► history_ui_trigger                  │
# │                                                       ├──► comments_display_trigger            │
# │                                                       ├──► concept_mappings_table_trigger      │
# │                                                       └──► selected_mapping_details_trigger    │
# │                                                                                                 │
# │  general_concept_detail     general_concept_detail   observe_event(...)                        │
# │  _edit_mode() ────────────► _edit_mode_trigger ────► ├──► breadcrumb_trigger                   │
# │                                                       ├──► comments_display_trigger            │
# │                                                       ├──► concept_mappings_table_trigger      │
# │                                                       └──► mapped_concepts_header_trigger      │
# │                                                                                                 │
# │  general_concepts           general_concepts         observe_event(...)                        │
# │  _edit_mode() ────────────► _edit_mode_trigger ────► ├──► breadcrumb_trigger                   │
# │                                                       └──► general_concepts_table_trigger      │
# │                                                                                                 │
# │  local_data() ────────────► local_data_trigger ────► observe_event(local_data_trigger)         │
# │                                                       ├──► comments_display_trigger            │
# │                                                       └──► general_concepts_table_trigger      │
# │                                                            (only if view == "list")            │
# │                                                                                                 │
# │  selected_categories() ───► selected_categories     observe_event(...)                         │
# │                             _trigger ──────────────► └──► general_concepts_table_trigger       │
# │                                                                                                 │
# │  comments_tab() ──────────► comments_tab_trigger ──► observe_event(comments_tab_trigger)       │
# │                                                       └──► comments_display_trigger            │
# │                                                                                                 │
# │  selected_mapped            mapped_concept           observe_event(mapped_concept_trigger)     │
# │  _concept_id() ───────────► _trigger ──────────────► ├──► selected_mapping_details_trigger     │
# │                                                       └──► relationship_tab_outputs_trigger    │
# │                                                                                                 │
# │  deleted_concepts() ──────► deleted_concepts        observe_event(...)                         │
# │                             _trigger ──────────────► └──► concept_mappings_table_trigger       │
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ COMPOSITE TRIGGERS → UI OBSERVERS                                                               │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  breadcrumb_trigger ─────────────────► output$breadcrumb (renderUI)                            │
# │                                                                                                 │
# │  history_ui_trigger ─────────────────► output$general_concepts_history_ui (renderUI)           │
# │                                        output$general_concept_detail_history_ui (renderUI)     │
# │                                                                                                 │
# │  general_concepts_table_trigger ─────► output$general_concepts_table (DT::renderDT)            │
# │                                        + restores category filters after render                │
# │                                                                                                 │
# │  concept_mappings_table_trigger ─────► output$concept_mappings_table (DT::renderDT)            │
# │                                                                                                 │
# │  comments_display_trigger ───────────► output$comments_display (renderUI)                      │
# │                                                                                                 │
# │  selected_mapping_details_trigger ───► output$selected_mapping_details (renderUI)              │
# │                                                                                                 │
# │  mapped_concepts_header_trigger ─────► output$mapped_concepts_header_buttons (renderUI)        │
# │                                                                                                 │
# │  relationship_tab_outputs_trigger ───► output$concept_relationships_display (renderUI)         │
# │                                                                                                 │
# │  history_tables_trigger ─────────────► output$general_concepts_history_table (DT::renderDT)    │
# │                                        output$general_concept_detail_history_table (DT::renderDT)│
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ DIRECT OBSERVERS (Not part of cascade - direct user interactions)                               │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  INPUT EVENT                           ACTION                                                   │
# │  ─────────────────────────────────────────────────────────────────────────────────────────────  │
# │  input$view_concept_details ─────────► Sets selected_concept_id(), current_view("detail")      │
# │  input$back_to_list ─────────────────► Sets current_view("list"), resets edit mode             │
# │  input$category_filter ──────────────► Toggles category in selected_categories()               │
# │  input$general_concepts_edit_page ───► Sets general_concepts_edit_mode(TRUE)                   │
# │  input$general_concepts_cancel_edit ─► Restores original data, edit_mode(FALSE)                │
# │  input$general_concepts_save_updates ► Saves changes to CSV, edit_mode(FALSE)                  │
# │  input$general_concept_detail_edit_page ► Sets general_concept_detail_edit_mode(TRUE)          │
# │  input$general_concept_detail_cancel_edit ► Resets temp changes, edit_mode(FALSE)              │
# │  input$general_concept_detail_save_updates ► Saves changes to CSV, edit_mode(FALSE)            │
# │  input$switch_relationships_tab ─────► Sets relationships_tab()                                │
# │  input$switch_comments_tab ──────────► Sets comments_tab()                                     │
# │  input$delete_concept ───────────────► Updates deleted_concepts()                              │
# │  input$mapped_concepts_add_selected ─► Updates added_concepts()                                │
# │  input$general_concepts_show_history ► Sets current_view("list_history")                       │
# │  input$general_concept_detail_show_history ► Sets current_view("detail_history")               │
# │  input$back_to_list_from_history ────► Sets current_view("list")                               │
# │  input$back_to_detail ───────────────► Sets current_view("detail")                             │
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ SPECIAL OBSERVERS                                                                               │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  data() ─────────────────────────────► Initializes local_data() on first load                  │
# │  current_user() ─────────────────────► Updates button visibility (admin vs anonymous)          │
# │  vocab_loading_status() ─────────────► Shows/hides loading, error, or table                    │
# │  relationships_tab() ────────────────► Updates tab styling (CSS classes)                       │
# │  current_view() ─────────────────────► Manages container visibility, triggers view_trigger     │
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ POTENTIAL REDUNDANCIES / AREAS FOR REVIEW                                                       │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  1. history_tables_trigger: Used in observe_event(list(current_view(), history_tables_trigger))│
# │     This uses list() syntax instead of cascade pattern. Could be refactored.                   │
# │                                                                                                 │
# │  2. add_modal_* triggers: add_modal_selected_concept, add_modal_concept_details_trigger,       │
# │     add_modal_omop_table_trigger are used for modal-specific updates but not fully             │
# │     integrated into the cascade pattern.                                                       │
# │                                                                                                 │
# │  3. relationships_tab() has a direct observer that updates CSS classes (line 4864)             │
# │     This could potentially be merged with relationship_tab_outputs_trigger cascade.            │
# │                                                                                                 │
# │  4. Some observers call update_button_visibility() directly instead of through cascade.        │
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘

# UI SECTION ====

#' Dictionary Explorer Module - UI
#'
#' @description UI function for the dictionary explorer module
#'
#' @param id Module ID
#' @param i18n Translator object from shiny.i18n
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS uiOutput
#' @importFrom htmltools tags tagList
mod_dictionary_explorer_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    ## UI - Main Layout ----
    ### Breadcrumb & Action Buttons Container ----
    div(class = "main-panel",
        div(class = "main-content",
            tags$div(
              style = "display: flex; justify-content: space-between; align-items: center; margin: 0 10px;",
              # Breadcrumb navigation
              uiOutput(ns("breadcrumb")),

              # Action buttons
              tags$div(
                style = "display: flex; gap: 10px;",
                # General Concepts Page normal buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("general_concepts_normal_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("show_general_concepts_add_modal"), i18n$t("add_concept"), class = "btn-success-custom", icon = icon("plus")),
                    actionButton(ns("general_concepts_show_history"), i18n$t("history"), class = "btn-secondary-custom", icon = icon("history")),
                    actionButton(ns("general_concepts_edit_page"), i18n$t("edit_page"), class = "btn-primary-custom", icon = icon("edit"))
                  )
                ),
                # General Concepts Page edit buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("general_concepts_edit_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("general_concepts_cancel_edit"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
                    actionButton(ns("general_concepts_save_updates"), i18n$t("save_updates"), class = "btn-success-custom", icon = icon("save"))
                  )
                ),
                # General Concept Detail Page normal buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("general_concept_detail_action_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("general_concept_detail_show_history"), i18n$t("history"), class = "btn-secondary-custom", icon = icon("history")),
                    actionButton(ns("general_concept_detail_edit_page"), i18n$t("edit_page"), class = "btn-toggle", icon = icon("edit"))
                  )
                ),
                # General Concept Detail Page edit buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("general_concept_detail_edit_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("general_concept_detail_cancel_edit"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
                    actionButton(ns("general_concept_detail_save_updates"), i18n$t("save_updates"), class = "btn-toggle", icon = icon("save"))
                  )
                ),
                # Back buttons (history views)
                shinyjs::hidden(
                  tags$div(
                    id = ns("back_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("back_to_list_from_history"), i18n$t("back_to_list"), class = "btn-primary-custom", icon = icon("arrow-left")),
                    actionButton(ns("back_to_detail"), i18n$t("back_to_details"), class = "btn-primary-custom", icon = icon("arrow-left"))
                  )
                )
              )
            ),

            ### Content Area (Tables & Containers) ----
            tagList(
              #### General Concepts container ----
              tags$div(
                id = ns("general_concepts_container"),
                class = "card-container card-container-flex",
                style = "flex: 1; min-height: 0; overflow: auto; margin: 0 10px 10px 5px;",

                # Loading message (visible by default)
                tags$div(
                  id = ns("vocab_loading_message"),
                  style = "display: flex; align-items: center; justify-content: center; height: 100%; flex-direction: column; gap: 20px;",
                  tags$div(
                    style = "text-align: center; padding: 40px; background: #e6f3ff; border: 2px solid #0f60af; border-radius: 8px; max-width: 600px;",
                    tags$div(
                      style = "color: #0f60af; font-size: 48px; margin-bottom: 15px;",
                      tags$i(class = "fas fa-spinner fa-spin")
                    ),
                    tags$h3(
                      style = "color: #0f60af; margin-bottom: 15px; font-size: 24px;",
                      i18n$t("loading_ohdsi_vocabularies")
                    ),
                    tags$p(
                      style = "color: #0f60af; font-size: 16px; line-height: 1.5;",
                      i18n$t("please_wait_vocabularies")
                    )
                  )
                ),

                # Error message
                shinyjs::hidden(
                  tags$div(
                    id = ns("vocab_error_message"),
                    style = "display: flex; align-items: center; justify-content: center; height: 100%; flex-direction: column; gap: 20px;",
                    tags$div(
                      style = "text-align: center; padding: 40px; background: #f8d7da; border: 2px solid #dc3545; border-radius: 8px; max-width: 600px;",
                      tags$div(
                        style = "color: #dc3545; font-size: 48px; margin-bottom: 15px;",
                        tags$i(class = "fas fa-exclamation-triangle")
                      ),
                      tags$h3(
                        style = "color: #dc3545; margin-bottom: 15px; font-size: 24px;",
                        i18n$t("ohdsi_vocabularies_not_loaded")
                      ),
                      tags$p(
                        style = "color: #721c24; font-size: 16px; margin-bottom: 20px; line-height: 1.5;",
                        i18n$t("ohdsi_vocabularies_required")
                      ),
                      tags$button(
                        class = "btn btn-primary-custom",
                        onclick = "window.location.hash = '#!/general-settings';",
                        style = "font-size: 16px; padding: 12px 24px;",
                        tags$i(class = "fas fa-cog", style = "margin-right: 8px;"),
                        i18n$t("go_to_settings")
                      )
                    )
                  )
                ),

                # DataTable
                DT::DTOutput(ns("general_concepts_table"))
              ),

              #### General Concept Detail Page Container ----
              shinyjs::hidden(
                tags$div(
                  id = ns("general_concept_detail_container"),
                  tags$div(
                    class = "quadrant-layout",
                    # Top section: Mapped Concepts and Selected Concept Details
                    tags$div(
                      class = "top-section",
                      # Top-left: Mapped Concepts
                      tags$div(
                        class = "quadrant quadrant-top-left",
                        tags$div(
                          class = "section-header",
                          style = "display: flex; align-items: center; justify-content: space-between; height: 40px;",
                          tags$div(
                            style = "display: flex; align-items: center; flex: 1;",
                            tags$h4(
                              style = "margin: 0;",
                              i18n$t("associated_concepts")
                            ),
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = as.character(i18n$t("associated_concepts_tooltip")),
                              "ⓘ"
                            )
                          ),
                          tags$div(
                            style = "display: flex; align-items: center; gap: 8px;",
                            # Copy button with dropdown menu
                            tags$div(
                              class = "copy-dropdown-container",
                              style = "position: relative;",
                              actionButton(
                                ns("copy_general_concept_menu"),
                                label = NULL,
                                icon = icon("copy"),
                                class = "btn-icon-only copy-menu-trigger has-tooltip",
                                style = "background: transparent; border: none; color: #666; padding: 0; cursor: pointer; flex-shrink: 0;",
                                `data-tooltip` = as.character(i18n$t("copy_concept_details")),
                                `data-copied-text` = as.character(i18n$t("copied"))
                              ),
                              # Dropdown menu
                              tags$div(
                                id = ns("copy_menu_dropdown"),
                                class = "copy-dropdown-menu",
                                style = "display: none; position: absolute; top: 100%; right: 0; background: white; border: 1px solid #ddd; border-radius: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 1000; min-width: 180px; margin-top: 4px;",
                                tags$div(
                                  class = "copy-menu-item",
                                  id = ns("copy_as_json"),
                                  style = "padding: 10px 15px; cursor: pointer; border-bottom: 1px solid #eee;",
                                  tags$i(class = "fa fa-code", style = "margin-right: 8px; color: #0f60af;"),
                                  i18n$t("copy_as_json")
                                ),
                                tags$div(
                                  class = "copy-menu-item",
                                  id = ns("copy_as_omop_sql"),
                                  style = "padding: 10px 15px; cursor: pointer;",
                                  tags$i(class = "fa fa-database", style = "margin-right: 8px; color: #0f60af;"),
                                  i18n$t("copy_omop_sql")
                                )
                              )
                            ),
                            # Dynamic buttons for edit mode
                            uiOutput(ns("mapped_concepts_header_buttons"))
                          )
                        ),
                        tags$div(
                          class = "quadrant-content",
                          shinycssloaders::withSpinner(
                            DT::DTOutput(ns("concept_mappings_table")),
                            type = 4,
                            color = "#0f60af",
                            size = 0.5
                          )
                        )
                      ),
                      # Top-right: Selected Concept Details
                      tags$div(
                        class = "quadrant quadrant-top-right",
                        tags$div(
                          class = "section-header",
                          style = "display: flex; justify-content: space-between; align-items: center;",
                          tags$div(
                            style = "display: flex; align-items: center; flex: 1;",
                            tags$h4(
                              style = "margin: 0;",
                              i18n$t("selected_concept_details")
                            ),
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = as.character(i18n$t("selected_concept_details_tooltip")),
                              "ⓘ"
                            )
                          ),
                          actionButton(
                            ns("copy_concept_json"),
                            label = NULL,
                            icon = icon("copy"),
                            class = "btn-icon-only",
                            style = "background: transparent; border: none; color: #666; padding: 0; cursor: pointer; flex-shrink: 0;",
                            `data-tooltip` = as.character(i18n$t("copy_as_json"))
                          )
                        ),
                        tags$div(
                          class = "quadrant-content",
                          shinycssloaders::withSpinner(
                            uiOutput(ns("selected_mapping_details")),
                            type = 4,
                            color = "#0f60af",
                            size = 0.5
                          )
                        )
                      )
                    ),
                    # Bottom section: Comments and Relationships
                    tags$div(
                      class = "bottom-section",
                      # Bottom-left: Comments
                      tags$div(
                        class = "quadrant quadrant-bottom-left",
                        tags$div(
                          class = "section-header section-header-with-tabs",
                          tags$h4(
                            style = "margin: 0;",
                            i18n$t("etl_guidance_comments"),
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = as.character(i18n$t("etl_guidance_comments_tooltip")),
                              "ⓘ"
                            )
                          ),
                          tags$div(
                            class = "section-tabs",
                            tags$button(
                              class = "tab-btn tab-btn-active",
                              id = ns("tab_comments"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'comments', {priority: 'event'})", ns("switch_comments_tab")),
                              i18n$t("comments")
                            ),
                            tags$button(
                              class = "tab-btn",
                              id = ns("tab_statistical_summary"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'statistical_summary', {priority: 'event'})", ns("switch_comments_tab")),
                              i18n$t("statistical_summary")
                            )
                          )
                        ),
                        tags$div(
                          class = "quadrant-content",
                          shinycssloaders::withSpinner(
                            uiOutput(ns("comments_display")),
                            type = 4,
                            color = "#0f60af",
                            size = 0.5
                          )
                        )
                      ),
                      # Bottom-right: Concept Relationships
                      tags$div(
                        class = "quadrant quadrant-bottom-right",
                        tags$div(
                          class = "section-header section-header-with-tabs",
                          tags$h4(
                            i18n$t("concept_relationships_hierarchy"),
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = as.character(i18n$t("concept_relationships_tooltip")),
                              "ⓘ"
                            )
                          ),
                          tags$div(
                            class = "section-tabs",
                            tags$button(
                              class = "tab-btn tab-btn-active",
                              id = ns("tab_related"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'related', {priority: 'event'})", ns("switch_relationships_tab")),
                              i18n$t("related")
                            ),
                            tags$button(
                              class = "tab-btn",
                              id = ns("tab_hierarchy"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'hierarchy', {priority: 'event'})", ns("switch_relationships_tab")),
                              i18n$t("hierarchy")
                            ),
                            tags$button(
                              class = "tab-btn",
                              id = ns("tab_synonyms"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'synonyms', {priority: 'event'})", ns("switch_relationships_tab")),
                              i18n$t("synonyms")
                            )
                          )
                        ),
                        tags$div(
                          class = "quadrant-content",
                          shinycssloaders::withSpinner(
                            uiOutput(ns("concept_relationships_display")),
                            type = 4,
                            color = "#0f60af",
                            size = 0.5
                          )
                        )
                      )
                    )
                  )
                )
              ),

              # History container for General Concept Detail Page
              shinyjs::hidden(
                tags$div(
                  id = ns("general_concept_detail_history_container"),
                  uiOutput(ns("general_concept_detail_history_ui"))
                )
              ),

              # History container for General Concepts Page
              shinyjs::hidden(
                tags$div(
                  id = ns("general_concepts_history_container"),
                  uiOutput(ns("general_concepts_history_ui"))
                )
              )
            )
        )
    ),

    ## UI - Modals ----
    
    ### Modal - Add New General Concept ----
    tags$div(
      id = ns("general_concepts_add_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("general_concepts_add_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 600px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("add_new_concept")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("general_concepts_add_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$div(
            id = ns("duplicate_concept_error"),
            style = "display: none; background-color: #f8d7da; color: #721c24; padding: 12px; border-radius: 4px; margin-bottom: 20px; text-align: center; border: 1px solid #f5c6cb;",
            tags$strong(i18n$t("duplicate_concept")),
            tags$br(),
            tags$span(id = ns("duplicate_concept_error_text"), "")
          ),
          tags$div(
            id = ns("general_concepts_new_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              i18n$t("general_concept_name"),
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            shiny::textInput(
              ns("general_concepts_new_name"),
              label = NULL,
              placeholder = as.character(i18n$t("enter_concept_name")),
              width = "100%"
            ),
            shinyjs::hidden(
              tags$span(
                id = ns("general_concepts_new_name_error"),
                class = "input-error-message",
                i18n$t("concept_name_required")
              )
            )
          ),
          tags$div(
            id = ns("general_concepts_new_category_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              i18n$t("category"),
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            tags$div(
              style = "display: flex; gap: 10px; align-items: flex-start;",
              tags$div(
                id = ns("category_select_container"),
                style = "flex: 1;",
                selectizeInput(
                  ns("general_concepts_new_category"),
                  label = NULL,
                  choices = character(0),
                  selected = character(0),
                  options = list(
                    placeholder = as.character(i18n$t("select_category"))
                  ),
                  width = "100%"
                )
              ),
              tags$div(
                id = ns("category_text_container"),
                style = "flex: 1; display: none;",
                shiny::textInput(
                  ns("general_concepts_new_category_text"),
                  label = NULL,
                  placeholder = as.character(i18n$t("enter_new_category")),
                  width = "100%"
                )
              ),
              tags$button(
                id = ns("general_concepts_toggle_category_mode"),
                class = "btn-toggle",
                onclick = sprintf("
                  var selectContainer = document.getElementById('%s');
                  var textContainer = document.getElementById('%s');
                  var btn = document.getElementById('%s');
                  if (selectContainer.style.display === 'none') {
                    selectContainer.style.display = 'block';
                    textContainer.style.display = 'none';
                    btn.innerHTML = '+';
                    btn.classList.remove('active');
                  } else {
                    selectContainer.style.display = 'none';
                    textContainer.style.display = 'block';
                    btn.innerHTML = '×';
                    btn.classList.add('active');
                  }
                ", ns("category_select_container"), ns("category_text_container"), ns("general_concepts_toggle_category_mode")),
                "+"
              )
            ),
            shinyjs::hidden(
              tags$span(
                id = ns("general_concepts_new_category_error"),
                class = "input-error-message",
                i18n$t("category_required")
              )
            )
          ),
          tags$div(
            id = ns("general_concepts_new_subcategory_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              i18n$t("subcategory"),
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            tags$div(
              style = "display: flex; gap: 10px; align-items: flex-start;",
              tags$div(
                id = ns("subcategory_select_container"),
                style = "flex: 1;",
                selectizeInput(
                  ns("general_concepts_new_subcategory"),
                  label = NULL,
                  choices = character(0),
                  selected = character(0),
                  options = list(
                    placeholder = as.character(i18n$t("first_select_category"))
                  ),
                  width = "100%"
                )
              ),
              tags$div(
                id = ns("subcategory_text_container"),
                style = "flex: 1; display: none;",
                shiny::textInput(
                  ns("general_concepts_new_subcategory_text"),
                  label = NULL,
                  placeholder = as.character(i18n$t("enter_new_subcategory")),
                  width = "100%"
                )
              ),
              tags$button(
                id = ns("general_concepts_toggle_subcategory_mode"),
                class = "btn-toggle",
                onclick = sprintf("
                  var selectContainer = document.getElementById('%s');
                  var textContainer = document.getElementById('%s');
                  var btn = document.getElementById('%s');
                  if (selectContainer.style.display === 'none') {
                    selectContainer.style.display = 'block';
                    textContainer.style.display = 'none';
                    btn.innerHTML = '+';
                    btn.classList.remove('active');
                  } else {
                    selectContainer.style.display = 'none';
                    textContainer.style.display = 'block';
                    btn.innerHTML = '×';
                    btn.classList.add('active');
                  }
                ", ns("subcategory_select_container"), ns("subcategory_text_container"), ns("general_concepts_toggle_subcategory_mode")),
                "+"
              )
            ),
            shinyjs::hidden(
              tags$span(
                id = ns("general_concepts_new_subcategory_error"),
                class = "input-error-message",
                i18n$t("subcategory_required")
              )
            )
          ),
          tags$div(
            style = "display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; padding-top: 20px; border-top: 1px solid #dee2e6;",
            tags$button(
              class = "btn btn-secondary btn-secondary-custom",
              onclick = sprintf("$('#%s').hide();", ns("general_concepts_add_modal")),
              tags$i(class = "fas fa-times"),
              paste0(" ", i18n$t("cancel"))
            ),
            actionButton(
              ns("general_concepts_add_new"),
              i18n$t("add_concept"),
              class = "btn-primary-custom",
              icon = icon("plus")
            )
          )
        )
      )
    ),
    
    
    
    ### Modal - Add Mapping to General Concept ----
    tags$div(
      id = ns("mapped_concepts_add_modal"),
      class = "modal-overlay",
      style = "display: none; position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0, 0, 0, 0.5); z-index: 9999;",
      onclick = sprintf("if (event.target === this) { $('#%s').css('display', 'none'); }", ns("mapped_concepts_add_modal")),
      tags$div(
        id = ns("mapped_concepts_add_modal_dialog"),
        style = "position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 95vw; height: 95vh; background: white; border-radius: 8px; display: flex; flex-direction: column;",
        onclick = "event.stopPropagation();",

        # Header
        tags$div(
          style = "padding: 20px; border-bottom: 1px solid #ddd; flex-shrink: 0; background: #f8f9fa; border-radius: 8px 8px 0 0;",
          tags$h3(i18n$t("add_concepts_to_mapping"), style = "margin: 0; display: inline-block;"),
          tags$button(
            style = "float: right; background: none; border: none; font-size: 28px; cursor: pointer;",
            onclick = sprintf("$('#%s').css('display', 'none');", ns("mapped_concepts_add_modal")),
            "×"
          )
        ),
        
        # Body
        tags$div(
          style = "flex: 1; min-height: 0; padding: 20px; display: flex; flex-direction: column;",

          # Custom tabs (styled like Shiny tabs but without URL changes)
          tags$ul(
            class = "nav nav-tabs",
            role = "tablist",
            style = "margin-bottom: 0;",
            tags$li(
              class = "active",
              role = "presentation",
              tags$a(
                href = "#",
                onclick = sprintf("
                  $('#%s').show();
                  $('#%s').hide();
                  $(this).parent().addClass('active');
                  $(this).parent().siblings().removeClass('active');
                  return false;
                ", ns("omop_tab_content"), ns("custom_tab_content")),
                i18n$t("search_omop_concepts")
              )
            ),
            tags$li(
              role = "presentation",
              tags$a(
                href = "#",
                onclick = sprintf("
                  $('#%s').show();
                  $('#%s').hide();
                  $(this).parent().addClass('active');
                  $(this).parent().siblings().removeClass('active');
                  return false;
                ", ns("custom_tab_content"), ns("omop_tab_content")),
                i18n$t("add_custom_concept")
              )
            )
          ),

          # Tab content container
          tags$div(
            class = "tab-content",
            style = "flex: 1; min-height: 0; display: flex; flex-direction: column;",

            # OMOP Concepts Tab
            tags$div(
              id = ns("omop_tab_content"),
              class = "tab-pane active",
              style = "margin-top: 15px; flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 15px;",

              # Search Concepts section (top half)
              tags$div(
                style = "flex: 1; min-height: 0; display: flex; flex-direction: column;",
                tags$div(
                  id = ns("omop_table_container"),
                  style = "flex: 1; min-height: 0; position: relative; overflow: auto;",
                  shinycssloaders::withSpinner(
                    DT::DTOutput(ns("mapped_concepts_add_omop_table")),
                    type = 4,
                    color = "#0f60af",
                    size = 0.4
                  )
                )
              ),

              # Bottom section: Concept Details (left) and Descendants (right)
              tags$div(
                id = ns("omop_details_section"),
                style = "flex: 1; min-height: 0; display: flex; gap: 15px;",

                # Concept Details (left)
                tags$div(
                  style = "flex: 1; min-height: 0; display: flex; flex-direction: column; border: 1px solid #ddd; border-radius: 4px; padding: 15px; background: white;",
                  tags$h5(i18n$t("selected_concept_details_modal"), style = "margin-top: 0; margin-bottom: 10px;"),
                  tags$div(
                    style = "flex: 1; min-height: 0; overflow: auto;",
                    uiOutput(ns("mapped_concepts_add_concept_details"))
                  )
                ),

                # Descendants (right)
                tags$div(
                  style = "flex: 1; min-height: 0; display: flex; flex-direction: column; border: 1px solid #ddd; border-radius: 4px; padding: 15px; background: white;",
                  tags$h5(i18n$t("descendants"), style = "margin-top: 0; margin-bottom: 10px;"),
                  tags$div(
                    style = "flex: 1; min-height: 0; overflow: hidden;",
                    DT::DTOutput(ns("mapped_concepts_add_descendants_table"))
                  )
                )
              ),

              # Bottom buttons for OMOP mode
              tags$div(
                style = "display: flex; justify-content: flex-end; align-items: center; gap: 10px; flex-shrink: 0;",
                checkboxInput(
                  ns("mapped_concepts_add_multiple_select"),
                  i18n$t("multiple_selection"),
                  value = FALSE,
                  width = NULL
                ),
                checkboxInput(
                  ns("mapped_concepts_add_include_descendants"),
                  i18n$t("include_descendants"),
                  value = FALSE,
                  width = NULL
                ),
                actionButton(
                  ns("mapped_concepts_add_selected"),
                  i18n$t("add_concepts"),
                  class = "btn-success-custom",
                  icon = icon("plus")
                )
              )
            ),

            # Custom Concept Tab
            tags$div(
              id = ns("custom_tab_content"),
              class = "tab-pane",
              style = "display: none; margin-top: 15px; height: calc(95vh - 200px); flex-direction: column; gap: 15px;",

              # Custom concept form
              tags$div(
                style = "flex: 1; min-height: 0; overflow: auto; padding: 40px; border: 1px solid #ddd; border-radius: 4px; background: white;",

                tags$div(
                  style = "margin-bottom: 20px;",
                  tags$label(
                    i18n$t("vocabulary_id"), " ",
                    tags$span("*", style = "color: #dc3545;")
                  ),
                  textInput(
                    ns("custom_vocabulary_id"),
                    label = NULL,
                    placeholder = "e.g., Custom, Local, Institution-specific",
                    width = "300px"
                  ),
                  shinyjs::hidden(
                    tags$span(
                      id = ns("custom_vocabulary_id_error"),
                      style = "color: #dc3545; font-size: 12px;",
                      i18n$t("vocabulary_id_required")
                    )
                  )
                ),

                tags$div(
                  style = "margin-bottom: 20px;",
                  textInput(
                    ns("custom_concept_code"),
                    i18n$t("concept_code"),
                    placeholder = as.character(i18n$t("optional")),
                    width = "300px"
                  )
                ),

                tags$div(
                  style = "margin-bottom: 20px;",
                  tags$label(
                    i18n$t("concept_name"), " ",
                    tags$span("*", style = "color: #dc3545;")
                  ),
                  textInput(
                    ns("custom_concept_name"),
                    label = NULL,
                    placeholder = as.character(i18n$t("enter_concept_name")),
                    width = "300px"
                  ),
                  shinyjs::hidden(
                    tags$span(
                      id = ns("custom_concept_name_error"),
                      style = "color: #dc3545; font-size: 12px;",
                      i18n$t("concept_name_required")
                    )
                  )
                )
              ),

              # Bottom buttons for custom mode
              tags$div(
                style = "display: flex; justify-content: flex-end; gap: 10px; flex-shrink: 0;",
                tags$button(
                  class = "btn btn-default",
                  onclick = sprintf("$('#%s').css('display', 'none');", ns("mapped_concepts_add_modal")),
                  tags$i(class = "fas fa-times"),
                  paste0(" ", i18n$t("cancel"))
                ),
                actionButton(
                  ns("add_custom_concept"),
                  i18n$t("add_custom_concept"),
                  class = "btn btn-success",
                  icon = icon("plus")
                )
              )
            )
          )
        )
      )
    ),
    
    ### Modal - Concept Details Viewer ----
    tags$div(
      id = ns("concept_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("concept_modal")),
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("concept_details")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("concept_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          uiOutput(ns("concept_modal_body"))
        )
      )
    ),

    ### Modal - Hierarchy Graph Fullscreen ----
    tags$div(
      id = ns("hierarchy_graph_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "height: 100%; display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100%; display: flex; flex-direction: column;",
        # Header with breadcrumb and close button
        tags$div(
          style = "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
          tags$div(
            style = "display: flex; align-items: center; gap: 15px;",
            uiOutput(ns("hierarchy_graph_breadcrumb"))
          ),
          tags$button(
            class = "modal-close-graph",
            onclick = sprintf("$('#%s').hide();", ns("hierarchy_graph_modal")),
            style = "font-size: 28px; font-weight: 300; color: #666; border: none; background: none; cursor: pointer; padding: 0; width: 30px; height: 30px; line-height: 1;",
            "×"
          )
        ),
        # Graph content
        tags$div(
          style = "flex: 1; overflow: hidden; padding: 20px;",
          visNetwork::visNetworkOutput(ns("hierarchy_graph_modal_content"), height = "100%", width = "100%")
        )
      )
    ),

    ### Modal - Comments Fullscreen ----
    tags$div(
      id = ns("comments_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100%; display: flex; flex-direction: column;",
        tags$div(
          style = "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
          tags$h3(
            style = "margin: 0; color: #0f60af;",
            i18n$t("etl_guidance_comments")
          ),
          actionButton(
            ns("close_fullscreen_modal"),
            label = HTML("×"),
            class = "modal-close",
            style = "font-size: 28px; font-weight: 300; color: #666; border: none; background: none; cursor: pointer; padding: 0; width: 30px; height: 30px; line-height: 1;"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: hidden; padding: 0;",
          uiOutput(ns("comments_fullscreen_content"))
        ),
        tags$style(HTML(sprintf("
          #%s {
            height: 100%% !important;
          }
        ", ns("comments_fullscreen_content"))))
      )
    )
  )
}

# SERVER SECTION ====

#' Dictionary Explorer Module - Server
#'
#' @description Server function for the dictionary explorer module
#'
#' @param id Module ID
#' @param data Reactive containing the CSV data
#' @param config Configuration list
#' @param vocabularies Reactive containing preloaded OHDSI vocabularies
#' @param i18n Translator object from shiny.i18n for server-side translations
#'
#' @return Module server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive req renderUI observe_event reactiveVal fluidRow column
#' @importFrom DT renderDT datatable formatStyle styleEqual
#' @importFrom dplyr filter left_join arrange group_by summarise n mutate select
#' @importFrom magrittr %>%
#' @importFrom htmltools HTML tags tagList
#' @importFrom htmlwidgets JS
mod_dictionary_explorer_server <- function(id, data, config, vocabularies, vocab_loading_status = reactive("not_loaded"), current_user = reactive(NULL), i18n = NULL, log_level = character()) {
  # Capture module id before entering moduleServer for logging
  module_id <- id

  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Store module id for logging (used by observe_event wrapper)
    id <- module_id

    # Helper function to get current language from environment variable
    current_language <- function() {
      lang <- Sys.getenv("INDICATE_LANGUAGE", "en")
      if (!lang %in% c("en", "fr")) lang <- "en"
      return(lang)
    }

    ## 1) Server - Reactive Values & State ----
    ### View & Selection State ----
    current_view <- reactiveVal("list")  # "list", "detail", "detail_history", or "list_history"
    selected_concept_id <- reactiveVal(NULL)
    selected_mapped_concept_id <- reactiveVal(NULL)  # Track selected concept in mappings table
    relationships_tab <- reactiveVal("related")  # Track active tab: "related", "hierarchy", "synonyms"
    comments_tab <- reactiveVal("comments")  # Track active tab: "comments", "statistical_summary"
    statistical_summary_sub_tab <- reactiveVal("summary")  # Track sub-tab: "summary", "distribution"
    selected_profile <- reactiveVal(NULL)  # Track selected profile for statistical summary
    selected_categories <- reactiveVal(character(0))  # Track selected category filters

    ### Edit Mode State ----
    general_concept_detail_edit_mode <- reactiveVal(FALSE)  # Track edit mode for General Concept Detail Page
    saved_table_page <- reactiveVal(0)  # Track datatable page for edit mode restoration
    general_concepts_edit_mode <- reactiveVal(FALSE)  # Track edit mode for General Concepts Page
    saved_table_search <- reactiveVal(NULL)  # Track datatable search state for edit mode
    saved_general_history_page <- reactiveVal(0)  # Track page for general concepts history table
    saved_general_history_search <- reactiveVal(NULL)  # Track search for general concepts history table
    saved_detail_history_page <- reactiveVal(0)  # Track page for detail history table
    saved_detail_history_search <- reactiveVal(NULL)  # Track search for detail history table
    deleted_concepts <- reactiveVal(list())  # Store deleted concept IDs by general_concept_id
    deleted_general_concepts <- reactiveVal(list())  # Store deleted general concept IDs to be removed on save
    original_general_concepts <- reactiveVal(NULL)  # Store original state for cancel in list edit mode
    add_modal_selected_concept <- reactiveVal(NULL)  # Store selected concept in add modal
    add_modal_concept_details_trigger <- reactiveVal(0)  # Trigger to refresh concept details in add modal
    newly_added_concept_id <- reactiveVal(NULL)  # Track newly added concept ID for navigation
    add_modal_omop_table_trigger <- reactiveVal(0)  # Trigger to control OMOP table rendering
    added_concepts <- reactiveVal(list())  # Store newly added concept mappings temporarily until save
    edited_mapping_details <- reactiveVal(list())  # Store temporary edits to mapping details (keyed by omop_concept_id)

    ### Data Management ----
    local_data <- reactiveVal(NULL)  # Local copy of data that can be updated

    ### Cascade Triggers ----
    # These reactiveVal triggers are used to create a cascade pattern for observers
    # Instead of having observers with multiple triggers like observe_event(c(a(), b(), c())),
    # we have primary observers that update these triggers, and cascade observers that listen to them

    # Primary state triggers
    view_trigger <- reactiveVal(0)
    concept_trigger <- reactiveVal(0)
    general_concept_detail_edit_mode_trigger <- reactiveVal(0)
    general_concepts_edit_mode_trigger <- reactiveVal(0)
    comments_tab_trigger <- reactiveVal(0)
    local_data_trigger <- reactiveVal(0)
    mapped_concept_trigger <- reactiveVal(0)
    deleted_concepts_trigger <- reactiveVal(0)
    selected_categories_trigger <- reactiveVal(0)

    # Composite triggers (for observers that need multiple conditions)
    breadcrumb_trigger <- reactiveVal(0)
    history_ui_trigger <- reactiveVal(0)
    general_concepts_table_trigger <- reactiveVal(0)
    comments_display_trigger <- reactiveVal(0)
    concept_mappings_table_trigger <- reactiveVal(0)
    selected_mapping_details_trigger <- reactiveVal(0)
    mapped_concepts_header_trigger <- reactiveVal(0)
    relationship_tab_outputs_trigger <- reactiveVal(0)
    history_tables_trigger <- reactiveVal(0)

    # Initialize local_data with data from parameter
    observe_event(data(), {
      if (is.null(local_data())) {
        local_data(data())
      }
    })

    # Create a reactive that uses local_data if available, otherwise data
    current_data <- reactive({
      if (!is.null(local_data())) {
        local_data()
      } else {
        data()
      }
    })
    
    categories_list <- reactive({
      req(current_data())
      unique_cats <- unique(current_data()$general_concepts$category)
      sorted_cats <- sort(unique_cats[!is.na(unique_cats)])

      # Move "Other" or "Autres" (French) to the end if they exist
      other_cats <- c("Other", "Autres")
      found_other <- intersect(sorted_cats, other_cats)
      if (length(found_other) > 0) {
        sorted_cats <- c(setdiff(sorted_cats, found_other), found_other)
      }

      sorted_cats
    })

    ## 2) Server - Navigation & Events ----
    
    ### Trigger Updates ----
    # These observers update composite triggers in true cascade style
    # Each primary trigger has its own observer that updates relevant composite triggers

    # When view_trigger fires, update breadcrumb and history_ui
    observe_event(view_trigger(), {
      breadcrumb_trigger(breadcrumb_trigger() + 1)
      history_ui_trigger(history_ui_trigger() + 1)
    }, ignoreInit = TRUE)

    # When general_concept_detail_edit_mode_trigger fires, update breadcrumb, comments_display, concept_mappings_table, and mapped_concepts_header
    observe_event(general_concept_detail_edit_mode_trigger(), {
      breadcrumb_trigger(breadcrumb_trigger() + 1)
      comments_display_trigger(comments_display_trigger() + 1)
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
      mapped_concepts_header_trigger(mapped_concepts_header_trigger() + 1)
    }, ignoreInit = TRUE)

    # When general_concepts_edit_mode_trigger fires, update breadcrumb and general_concepts_table
    observe_event(general_concepts_edit_mode_trigger(), {
      breadcrumb_trigger(breadcrumb_trigger() + 1)
      general_concepts_table_trigger(general_concepts_table_trigger() + 1)
    }, ignoreInit = TRUE)

    # When concept_trigger fires, update history_ui, comments_display, concept_mappings_table, and selected_mapping_details
    observe_event(concept_trigger(), {
      history_ui_trigger(history_ui_trigger() + 1)
      comments_display_trigger(comments_display_trigger() + 1)
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
      selected_mapping_details_trigger(selected_mapping_details_trigger() + 1)
    }, ignoreInit = TRUE)

    # When local_data_trigger fires, update comments_display and general_concepts_table
    observe_event(local_data_trigger(), {
      view <- current_view()

      comments_display_trigger(comments_display_trigger() + 1)
      # Only reload general_concepts table if we're in list view
      # This prevents losing category filter when saving from detail view
      if (view == "list") {
        general_concepts_table_trigger(general_concepts_table_trigger() + 1)
      }
    }, ignoreInit = TRUE)

    # When selected_categories_trigger fires, update general_concepts_table
    observe_event(selected_categories_trigger(), {
      general_concepts_table_trigger(general_concepts_table_trigger() + 1)
    }, ignoreInit = TRUE)

    # When comments_tab_trigger fires, update tab styling and comments_display
    observe_event(comments_tab_trigger(), {
      active_tab <- comments_tab()

      # Update tab button styling
      shinyjs::removeCssClass(id = "tab_comments", class = "tab-btn-active")
      shinyjs::removeCssClass(id = "tab_statistical_summary", class = "tab-btn-active")

      if (active_tab == "comments") {
        shinyjs::addCssClass(id = "tab_comments", class = "tab-btn-active")
      } else if (active_tab == "statistical_summary") {
        shinyjs::addCssClass(id = "tab_statistical_summary", class = "tab-btn-active")
      }

      # Trigger cascade
      comments_display_trigger(comments_display_trigger() + 1)
    }, ignoreInit = TRUE)

    # Handle stats summary sub-tab selection
    observe_event(input$stats_summary_tab_selected, {
      stats_summary_tab(input$stats_summary_tab_selected)
      comments_display_trigger(comments_display_trigger() + 1)
    }, ignoreInit = TRUE)

    # When deleted_concepts_trigger fires, update concept_mappings_table
    observe_event(deleted_concepts_trigger(), {
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
    }, ignoreInit = TRUE)

    # When mapped_concept_trigger fires, update selected_mapping_details and relationship_tab_outputs
    observe_event(mapped_concept_trigger(), {
      selected_mapping_details_trigger(selected_mapping_details_trigger() + 1)
      relationship_tab_outputs_trigger(relationship_tab_outputs_trigger() + 1)
    }, ignoreInit = TRUE)
    
    ### Buttons visibility ----
    update_button_visibility <- function() {
      user <- current_user()
      view <- current_view()
      
      # Use shinyjs::delay to ensure DOM is ready
      shinyjs::delay(100, {
        # First hide all buttons
        shinyjs::hide("general_concepts_normal_buttons")
        shinyjs::hide("general_concepts_edit_buttons")
        shinyjs::hide("general_concept_detail_action_buttons")
        shinyjs::hide("general_concept_detail_edit_buttons")
        shinyjs::hide("back_buttons")
        
        # Then show only the relevant buttons based on user AND view
        if (!is.null(user) && user$role != "Anonymous") {
          
          if (view == "list") {
            # Show list normal buttons (not edit buttons - those are shown when clicking Edit page)
            if (!general_concepts_edit_mode()) {
              shinyjs::show("general_concepts_normal_buttons")
            } else {
              shinyjs::show("general_concepts_edit_buttons")
            }
          } else if (view == "list_history") {
            # Show back button (first button in back_buttons)
            shinyjs::runjs(sprintf("$('#%s button:first').show();", ns("back_buttons")))
            shinyjs::runjs(sprintf("$('#%s button:last').hide();", ns("back_buttons")))
            shinyjs::show("back_buttons")
          } else if (view == "detail") {
            # Show detail normal buttons (not edit buttons - those are shown when clicking Edit page)
            if (!general_concept_detail_edit_mode()) {
              shinyjs::show("general_concept_detail_action_buttons")
            } else {
              shinyjs::show("general_concept_detail_edit_buttons")
            }
          } else if (view == "detail_history") {
            # Show back to detail button (second button in back_buttons)
            shinyjs::runjs(sprintf("$('#%s button:first').hide();", ns("back_buttons")))
            shinyjs::runjs(sprintf("$('#%s button:last').show();", ns("back_buttons")))
            shinyjs::show("back_buttons")
          }
        }
      })
    }
    
    observe_event(current_user(), {
      update_button_visibility()
    })

    ### Vocabulary Loading Status ----
    # Listen to both vocab_loading_status AND vocabularies changes
    observe_event(list(vocab_loading_status(), vocabularies()), {
      loading_status <- vocab_loading_status()
      vocab_data <- vocabularies()

      if (loading_status == "loading") {
        # Show loading message, hide table and error
        shinyjs::show("vocab_loading_message")
        shinyjs::hide("vocab_error_message")
        shinyjs::hide("general_concepts_table")
      } else if (loading_status == "loaded" && !is.null(vocab_data)) {
        # Show table, hide loading and error
        shinyjs::hide("vocab_loading_message")
        shinyjs::hide("vocab_error_message")
        shinyjs::show("general_concepts_table")

        # Trigger OMOP table rendering for the add modal (only once when vocabularies load)
        add_modal_omop_table_trigger(add_modal_omop_table_trigger() + 1)
      } else if (loading_status == "error") {
        # Show error message
        shinyjs::hide("vocab_loading_message")
        shinyjs::show("vocab_error_message")
        shinyjs::hide("general_concepts_table")
      } else {
        # For 'not_loaded' status, check if DuckDB database file exists (independent of vocab folder)
        duckdb_path <- get_duckdb_path()

        if (file.exists(duckdb_path)) {
          # DuckDB file exists, show loading message (vocabularies will be loaded)
          shinyjs::show("vocab_loading_message")
          shinyjs::hide("vocab_error_message")
          shinyjs::hide("general_concepts_table")
        } else {
          # DuckDB file doesn't exist, show error message
          shinyjs::hide("vocab_loading_message")
          shinyjs::show("vocab_error_message")
          shinyjs::hide("general_concepts_table")
        }
      }
    }, ignoreNULL = FALSE)


    ### Breadcrumb Rendering ----
    # Render breadcrumb when breadcrumb trigger fires (cascade observer)
    observe_event(breadcrumb_trigger(), {
      view <- current_view()

      output$breadcrumb <- renderUI({
        if (view == "list") {
          categories <- categories_list()
          selected <- selected_categories()
          
          tags$div(
            class = "breadcrumb-nav",
            style = "padding: 10px 0 15px 12px; display: flex; align-items: center; gap: 15px; justify-content: space-between;",
            # Left side: Title and category badges
            tags$div(
              style = "display: flex; align-items: center; gap: 15px; flex: 1;",
              # Title
              tags$div(
                class = "section-title",
                tags$span("General Concepts")
              ),
              # Category badges
              tags$div(
                class = "category-filters",
                style = "display: flex; flex-wrap: wrap; gap: 8px; flex: 1;",
                lapply(categories, function(cat) {
                  is_selected <- cat %in% selected
                  tags$span(
                    class = if (is_selected) "category-badge selected" else "category-badge",
                    onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("category_filter"), cat),
                    cat
                  )
                })
              )
            )
          )
        } else if (view == "list_history") {
          # Breadcrumb for list history view
          tags$div(
            class = "breadcrumb-nav",
            style = "padding: 10px 0 15px 12px; font-size: 16px; display: flex; justify-content: space-between; align-items: center;",
            # Left side: title
            tags$div(
              class = "section-title",
              "General Concepts"
            )
          )
        } else {
          concept_id <- selected_concept_id()
          if (!is.null(concept_id)) {
            concept_info <- current_data()$general_concepts %>%
              dplyr::filter(general_concept_id == concept_id)
            
            if (nrow(concept_info) > 0) {
              tags$div(
                class = "breadcrumb-nav",
                style = "padding: 10px 0 15px 12px; font-size: 16px; display: flex; justify-content: space-between; align-items: center;",
                # Left side: breadcrumb
                tags$div(
                  tags$a(
                    href = "#",
                    onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_list")),
                    class = "breadcrumb-link",
                    "General Concepts"
                  ),
                  tags$span(
                    style = "margin: 0 8px; color: #999;",
                    ">"
                  ),
                  tags$span(
                    style = "color: #333; font-weight: 600;",
                    concept_info$general_concept_name[1]
                  )
                )
              )
            }
          }
        }
      })
    }, ignoreInit = TRUE)

    # Render header buttons for mapped concepts when mapped_concepts_header trigger fires (cascade observer)
    observe_event(mapped_concepts_header_trigger(), {
      output$mapped_concepts_header_buttons <- renderUI({
        if (general_concept_detail_edit_mode()) {
          tags$div(
            style = "margin-left: auto; display: flex; gap: 5px;",
            tags$button(
              class = "btn btn-success btn-sm",
              onclick = sprintf("
                $('#%s').css('display', 'flex');
                setTimeout(function() {
                  $(window).trigger('resize');
                  Shiny.unbindAll();
                  Shiny.bindAll();
                }, 100);
              ", ns("mapped_concepts_add_modal")),
              tags$i(class = "fa fa-plus"),
              paste0(" ", i18n$t("add_concepts"))
            )
          )
        }
      })
    }, ignoreInit = TRUE)
    
    ### Category Filtering ----
    # Handle category badge clicks
    observe_event(input$category_filter, {
      category <- input$category_filter
      current_selected <- selected_categories()

      if (category %in% current_selected) {
        # Remove category
        selected_categories(setdiff(current_selected, category))
      } else {
        # Add category
        selected_categories(c(current_selected, category))
      }
    })

    # Note: Category filter updates are handled by the restore filter observer below (line 1374)
    # which runs after table re-rendering, eliminating the need for a separate observer here

    # Restore category filters after table is re-rendered
    observe_event(general_concepts_table_trigger(), {
      categories <- selected_categories()

      if (length(categories) > 0) {
        # Use delayed execution to ensure DataTable is fully rendered
        # Increased delay to ensure table is ready after view changes
        shinyjs::delay(200, {
          proxy <- DT::dataTableProxy("general_concepts_table", session = session)
          search_string <- jsonlite::toJSON(categories, auto_unbox = FALSE)

          DT::updateSearch(proxy, keywords = list(
            global = NULL,
            columns = list(NULL, as.character(search_string))
          ))
        })
      }
    }, ignoreInit = TRUE)

    ### View Switching ----
    
    # Define all containers
    all_containers <- c("general_concepts_container", "general_concept_detail_container", "general_concept_detail_history_container", "general_concepts_history_container")

    # Map views to their visible containers
    view_containers <- list(
      list = "general_concepts_container",
      detail = "general_concept_detail_container",
      detail_history = "general_concept_detail_history_container",
      list_history = "general_concepts_history_container"
    )
    
    # Handle list history button
    observe_event(input$general_concepts_show_history, {
      current_view("list_history")
    })
    
    # Handle back to list from history button
    observe_event(input$back_to_list_from_history, {
      current_view("list")
    })

    # Handle view changes: update buttons and containers, then trigger cascade
    observe_event(current_view(), {
      view <- current_view()

      # 1. Update button visibility
      update_button_visibility()

      # 2. Hide all containers and show the current one
      lapply(all_containers, function(id) shinyjs::hide(id = id))
      if (!is.null(view_containers[[view]])) {
        shinyjs::show(id = view_containers[[view]])
      }

      # 3. Reload general_concepts table when returning to list view
      # The existing filter restoration system will preserve category filters
      if (view == "list") {
        general_concepts_table_trigger(general_concepts_table_trigger() + 1)
      }

      # 4. Trigger cascade
      view_trigger(view_trigger() + 1)
    })

    # Handle concept selection changes, then trigger cascade
    observe_event(selected_concept_id(), {
      # Reset page position when changing concepts
      concept_mappings_current_page(0)
      concept_trigger(concept_trigger() + 1)
    })

    # Handle General Concept Detail Page edit mode changes, then trigger cascade
    observe_event(general_concept_detail_edit_mode(), {
      general_concept_detail_edit_mode_trigger(general_concept_detail_edit_mode_trigger() + 1)
    })

    # Handle General Concepts Page edit mode changes, then trigger cascade
    observe_event(general_concepts_edit_mode(), {
      general_concepts_edit_mode_trigger(general_concepts_edit_mode_trigger() + 1)
    })

    # Handle comments tab changes, then trigger cascade
    observe_event(comments_tab(), {
      comments_tab_trigger(comments_tab_trigger() + 1)
    })

    # Handle local data changes, then trigger cascade
    observe_event(local_data(), {
      local_data_trigger(local_data_trigger() + 1)
    })

    # Handle mapped concept selection changes, then trigger cascade
    observe_event(selected_mapped_concept_id(), {
      mapped_concept_trigger(mapped_concept_trigger() + 1)
    })

    # Handle deleted_concepts changes, then trigger cascade
    observe_event(deleted_concepts(), {
      deleted_concepts_trigger(deleted_concepts_trigger() + 1)
    })

    # Handle selected_categories changes, then trigger cascade
    observe_event(selected_categories(), {
      selected_categories_trigger(selected_categories_trigger() + 1)
    })
    
    # Render history UIs when history_ui trigger fires
    observe_event(history_ui_trigger(), {
      view <- current_view()
      concept_id <- selected_concept_id()
      
      # Render list history UI
      if (view == "list_history") {
        output$general_concepts_history_ui <- renderUI({
          tags$div(
            class = "card-container card-container-flex",
            style = "flex: 1; min-height: 0; overflow: auto; padding: 20px; margin: 10px;",

            tags$div(
              class = "table-container",
              style = "height: 100%;",
              shinycssloaders::withSpinner(
                DT::DTOutput(ns("general_concepts_history_table")),
                type = 4,
                color = "#0f60af",
                size = 0.5
              )
            )
          )
        })
      }
      
      # Render detail history UI
      if (view == "detail_history" && !is.null(concept_id)) {
        output$general_concept_detail_history_ui <- renderUI({
          tags$div(
            class = "card-container card-container-flex",
            style = "flex: 1; min-height: 0; overflow: auto; padding: 20px; margin: 10px;",

            tags$div(
              class = "table-container",
              style = "height: 100%;",
              shinycssloaders::withSpinner(
                DT::DTOutput(ns("general_concept_detail_history_table")),
                type = 4,
                color = "#0f60af",
                size = 0.5
              )
            )
          )
        })
      }
    }, ignoreInit = TRUE)
    
    # Handle edit page button
    observe_event(input$general_concept_detail_edit_page, {
      general_concept_detail_edit_mode(TRUE)
      update_button_visibility()
    })

    # Handle show history button
    observe_event(input$general_concept_detail_show_history, {
      current_view("detail_history")
    })

    # Handle back to detail button (from history view)
    observe_event(input$back_to_detail, {
      current_view("detail")
    })

    # Handle cancel edit button
    observe_event(input$general_concept_detail_cancel_edit, {
      # Reset all unsaved changes in memory
      deleted_concepts(list())
      added_concepts(list())
      edited_mapping_details(list())  # Reset temporary mapping detail edits
      general_concept_detail_edit_mode(FALSE)
      # Reset tab to comments
      comments_tab("comments")
      # Hide edit buttons and show normal action buttons
      shinyjs::hide("general_concept_detail_edit_buttons")
      shinyjs::show("general_concept_detail_action_buttons")

      # Temporary changes are stored in deleted_concepts(), added_concepts(), and edited_mapping_details()
      # which are applied during table rendering. Resetting these lists is enough.
      # Just trigger table re-render to show original data
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
      selected_mapping_details_trigger(selected_mapping_details_trigger() + 1)
    })
    
    # Observe tab switching for relationships
    observe_event(input$switch_relationships_tab, {
      relationships_tab(input$switch_relationships_tab)
    })
    
    # Observe tab switching for comments
    observe_event(input$switch_comments_tab, {
      comments_tab(input$switch_comments_tab)
    })

    ### History Tables Rendering ----
    # Render general concepts history table (all concepts)
    observe_event(list(current_view(), history_tables_trigger()), {
      if (current_view() == "list_history") {
        output$general_concepts_history_table <- DT::renderDT({

          # Load history data
          history <- get_history("general_concept")

          if (nrow(history) == 0) {
            return(create_empty_datatable(as.character(i18n$t("no_history_available"))))
          }

          # Prepare display data
          table_data <- history %>%
            dplyr::select(history_id, timestamp, username, action_type, general_concept_name, comment) %>%
            dplyr::mutate(
              action_type = paste0(toupper(substr(action_type, 1, 1)), substr(action_type, 2, nchar(action_type))),
              username = factor(username),
              action_type = factor(action_type),
              comment = ifelse(is.na(comment) | comment == "NA", "/", comment)
            )

          # Add Delete button column
          table_data$Actions <- sapply(table_data$history_id, function(id) {
            create_datatable_actions(list(
              list(
                label = "Delete",
                icon = "trash",
                type = "danger",
                class = "btn-delete-history",
                data_attr = list(id = id)
              )
            ))
          })

          # Remove history_id from display
          table_data <- table_data %>% dplyr::select(-history_id)

          dt <- DT::datatable(
            table_data,
            selection = 'none',
            rownames = FALSE,
            filter = 'top',
            escape = FALSE,
            colnames = c(
              as.character(i18n$t("timestamp")),
              as.character(i18n$t("user")),
              as.character(i18n$t("action")),
              as.character(i18n$t("concept")),
              as.character(i18n$t("comment")),
              as.character(i18n$t("actions"))
            ),
            options = list(
              pageLength = 20,
              lengthMenu = list(c(10, 20, 50, 100, -1), c('10', '20', '50', '100', 'All')),
              dom = 'ltip',
              language = get_datatable_language(),
              order = list(list(0, 'desc')),
              columnDefs = list(
                list(targets = 0, width = "140px"),
                list(targets = 1, width = "120px"),
                list(targets = 2, width = "80px"),
                list(targets = 3, width = "250px"),
                list(targets = 4, width = "350px"),
                list(targets = 5, width = "100px", searchable = FALSE, className = "dt-center")
              )
            ),
            class = 'cell-border stripe hover'
          ) %>%
            DT::formatStyle(
              'action_type',
              backgroundColor = DT::styleEqual(
                c('Insert', 'Update', 'Delete'),
                c('#d4edda', '#fff3cd', '#f8d7da')
              ),
              fontWeight = 'bold'
            )

          # Add button handlers
          dt <- add_button_handlers(
            dt,
            handlers = list(
              list(selector = ".btn-delete-history", input_id = ns("delete_general_history"))
            )
          )

          dt
        })
      }
    })

    # Render general concept detail history table (mapped concepts history for this general concept)
    observe_event(list(current_view(), history_tables_trigger()), {
      if (current_view() == "detail_history") {
        concept_id <- selected_concept_id()
        if (!is.null(concept_id)) {
          output$general_concept_detail_history_table <- DT::renderDT({
            # Get all mapped concepts history and filter by general_concept_id
            history <- get_history("mapped_concept") %>%
              dplyr::filter(general_concept_id == concept_id)

            if (nrow(history) == 0) {
              return(create_empty_datatable(as.character(i18n$t("no_history_available_concept"))))
            }

            # Format columns (excluding general_concept_id since we're already filtered on it)
            table_data <- history %>%
              dplyr::select(history_id, timestamp, username, action_type, vocabulary_id, concept_code, concept_name, comment) %>%
              dplyr::mutate(
                action_type = paste0(toupper(substr(action_type, 1, 1)), substr(action_type, 2, nchar(action_type))),
                username = factor(username),
                action_type = factor(action_type),
                vocabulary_id = ifelse(is.na(vocabulary_id) | vocabulary_id == "NA", "/", vocabulary_id),
                concept_code = ifelse(is.na(concept_code) | concept_code == "NA", "/", concept_code),
                concept_name = ifelse(is.na(concept_name) | concept_name == "NA", "/", concept_name),
                comment = ifelse(
                  is.na(comment) | comment == "NA",
                  "/",
                  sprintf('<div title="%s" style="max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">%s</div>',
                    gsub('"', '&quot;', comment),
                    ifelse(nchar(comment) > 100, paste0(substr(comment, 1, 100), "..."), comment)
                  )
                )
              )

            # Add Delete button column
            table_data$Actions <- sapply(table_data$history_id, function(id) {
              create_datatable_actions(list(
                list(
                  label = "Delete",
                  icon = "trash",
                  type = "danger",
                  class = "btn-delete-detail-history",
                  data_attr = list(id = id)
                )
              ))
            })

            # Remove history_id from display
            table_data <- table_data %>% dplyr::select(-history_id)

            dt <- DT::datatable(
              table_data,
              selection = 'none',
              rownames = FALSE,
              colnames = c(
                as.character(i18n$t("timestamp")),
                as.character(i18n$t("user")),
                as.character(i18n$t("action")),
                as.character(i18n$t("vocabulary")),
                as.character(i18n$t("code")),
                as.character(i18n$t("concept")),
                as.character(i18n$t("comment")),
                as.character(i18n$t("actions"))
              ),
              escape = FALSE,
              class = 'cell-border stripe hover',
              filter = 'top',
              options = list(
                pageLength = 20,
                lengthMenu = list(c(10, 20, 50, 100, -1), c('10', '20', '50', '100', 'All')),
                dom = 'ltip',
                language = get_datatable_language(),
                order = list(list(0, 'desc')),
                columnDefs = list(
                  list(targets = 0, width = "140px"),  # timestamp
                  list(targets = 1, width = "120px"),  # username
                  list(targets = 2, width = "100px"),  # action_type
                  list(targets = 3, width = "100px"),  # vocabulary_id
                  list(targets = 4, width = "100px"),  # concept_code
                  list(targets = 5, width = "200px"),  # concept_name
                  list(targets = 6, width = "250px"),  # comment
                  list(targets = 7, width = "100px", searchable = FALSE, className = "dt-center")  # Actions
                )
              )
            ) %>%
              DT::formatStyle(
                'action_type',
                backgroundColor = DT::styleEqual(
                  c('Insert', 'Update', 'Delete', 'Recommend', 'Unrecommend'),
                  c('#d4edda', '#fff3cd', '#f8d7da', '#cfe2ff', '#f8f9fa')
                ),
                fontWeight = 'bold'
              )

            # Add button handlers
            dt <- add_button_handlers(
              dt,
              handlers = list(
                list(selector = ".btn-delete-detail-history", input_id = ns("delete_detail_history"))
              )
            )

            dt
          })
        }
      }
    })

    # Delete general concepts history entry
    observe_event(input$delete_general_history, {
      history_id <- input$delete_general_history
      if (is.null(history_id)) return()

      # Save datatable state before deletion
      save_datatable_state(input, "general_concepts_history_table", saved_general_history_page, saved_general_history_search)

      # Delete the history entry
      success <- delete_history_entry("general_concept", history_id)

      if (success) {
        # Trigger history tables re-render
        history_tables_trigger(history_tables_trigger() + 1)

        # Restore datatable state after re-render
        restore_datatable_state("general_concepts_history_table", saved_general_history_page, saved_general_history_search, session)
      }
    }, ignoreInit = TRUE)

    # Delete detail history entry
    observe_event(input$delete_detail_history, {
      history_id <- input$delete_detail_history
      if (is.null(history_id)) return()

      # Save datatable state before deletion
      save_datatable_state(input, "general_concept_detail_history_table", saved_detail_history_page, saved_detail_history_search)

      # Delete the history entry
      success <- delete_history_entry("mapped_concept", history_id)

      if (success) {
        # Trigger history tables re-render
        history_tables_trigger(history_tables_trigger() + 1)

        # Restore datatable state after re-render
        restore_datatable_state("general_concept_detail_history_table", saved_detail_history_page, saved_detail_history_search, session)
      }
    }, ignoreInit = TRUE)


    ## 3) Server - General Concepts Page ----
    ### General Concepts Table Rendering ----
    # Render general concepts table when general_concepts_table trigger fires (cascade observer)
    observe_event(general_concepts_table_trigger(), {
      output$general_concepts_table <- DT::renderDT({

      general_concepts <- current_data()$general_concepts

      # Prepare table data
      table_data <- general_concepts %>%
        dplyr::mutate(
          # Always keep as factor to preserve dropdown filters
          category = factor(category),
          subcategory = factor(subcategory),
          actions = if (general_concepts_edit_mode()) {
            sprintf(
              '<button class="delete-concept-btn" data-id="%s" style="padding: 4px 12px; background: #dc3545; color: white; border: none; border-radius: 4px; cursor: pointer;">%s</button>',
              general_concept_id,
              as.character(i18n$t("delete"))
            )
          } else {
            sprintf(
              '<button class="view-details-btn" data-id="%s">%s</button>',
              general_concept_id,
              as.character(i18n$t("view_details"))
            )
          }
        )

      # Select columns based on edit mode
      col_names <- c(
        "ID",
        as.character(i18n$t("category")),
        as.character(i18n$t("subcategory")),
        as.character(i18n$t("general_concept_name")),
        as.character(i18n$t("actions"))
      )

      if (general_concepts_edit_mode()) {
        table_data <- table_data %>%
          dplyr::select(general_concept_id, category, subcategory, general_concept_name, actions)
        col_defs <- list(
          list(targets = 0, visible = FALSE),
          list(targets = 1, width = "150px"),
          list(targets = 2, width = "150px"),
          list(targets = 3, width = "300px"),
          list(targets = 4, width = "120px", className = 'dt-center', orderable = FALSE, searchable = FALSE)
        )
        editable_cols <- list(target = 'cell', disable = list(columns = c(0, 4)))
      } else {
        table_data <- table_data %>%
          dplyr::select(general_concept_id, category, subcategory, general_concept_name, actions)
        col_defs <- list(
          list(targets = 0, visible = FALSE),
          list(targets = 1, width = "150px"),
          list(targets = 2, width = "150px"),
          list(targets = 3, width = "350px"),
          list(targets = 4, width = "120px", className = 'dt-center', orderable = FALSE, searchable = FALSE)
        )
        editable_cols <- FALSE
      }

      dt <- DT::datatable(
        table_data,
        selection = 'none',
        rownames = FALSE,
        escape = FALSE,
        filter = 'top',
        editable = editable_cols,
        colnames = col_names,
        options = list(
          pageLength = 20,
          lengthMenu = list(c(10, 15, 20, 25, 50, 100, -1), c('10', '15', '20', '25', '50', '100', 'All')),
          dom = 'ltip',
          language = get_datatable_language(),
          columnDefs = col_defs
        )
      )

      # Add callback to handle button clicks and double-click on rows
      dt <- add_combined_handlers(
        dt,
        button_handlers = list(
          list(selector = ".view-details-btn", input_id = ns("view_concept_details")),
          list(selector = ".delete-concept-btn", input_id = ns("delete_general_concept"))
        ),
        doubleclick_input_id = ns("view_concept_details"),
        doubleclick_column = 0,
        doubleclick_condition = sprintf("!%s", tolower(as.character(general_concepts_edit_mode())))
      )

        dt
      }, server = FALSE)
    })

    # Handle "View Details" button click
    observe_event(input$view_concept_details, {
      concept_id <- input$view_concept_details
      if (!is.null(concept_id)) {
        selected_concept_id(as.integer(concept_id))
        current_view("detail")
        current_mappings(NULL)  # Reset cache when changing concept
      }
    }, ignoreInit = TRUE)

    # Handle back to list
    observe_event(input$back_to_list, {
      current_view("list")
      selected_concept_id(NULL)
      selected_mapped_concept_id(NULL)
      current_mappings(NULL)
      relationships_tab("related")
      general_concept_detail_edit_mode(FALSE)  # Exit edit mode when going back to list
      general_concepts_edit_mode(FALSE)  # Exit list edit mode when going back to list
    })
    
    ### List Edit Mode ----

    # Handle list edit page button
    observe_event(input$general_concepts_edit_page, {
      # Save current state for cancel functionality
      original_general_concepts(current_data()$general_concepts)

      # Clear any previous deletion list
      deleted_general_concepts(list())

      # Save datatable state
      save_datatable_state(input, "general_concepts_table", saved_table_page, saved_table_search)

      general_concepts_edit_mode(TRUE)

      # Update button visibility will be triggered automatically by general_concepts_edit_mode() change
      update_button_visibility()

      # Restore datatable state after re-render
      restore_datatable_state("general_concepts_table", saved_table_page, saved_table_search, session)
    })

    # Handle list cancel button
    observe_event(input$general_concepts_cancel_edit, {
      # Save datatable state before exiting edit mode
      save_datatable_state(input, "general_concepts_table", saved_table_page, saved_table_search)

      # Restore original data
      if (!is.null(original_general_concepts())) {
        data <- local_data()
        data$general_concepts <- original_general_concepts()
        local_data(data)
        original_general_concepts(NULL)
      }

      # Clear deletion list (cancel all pending deletions)
      deleted_general_concepts(list())

      general_concepts_edit_mode(FALSE)

      # Update button visibility
      update_button_visibility()

      # Restore datatable state after re-render
      restore_datatable_state("general_concepts_table", saved_table_page, saved_table_search, session)
    })
    
    observe_event(input$general_concepts_save_updates, {
      if (!general_concepts_edit_mode()) return()

      # Save datatable state before exiting edit mode
      save_datatable_state(input, "general_concepts_table", saved_table_page, saved_table_search)

      # Get current data
      general_concepts <- current_data()$general_concepts
      original_data <- original_general_concepts()

      # Apply general concept deletions
      deleted_list <- deleted_general_concepts()
      if (length(deleted_list) > 0) {
        concept_mappings <- current_data()$concept_mappings
        custom_concepts <- current_data()$custom_concepts
        general_concept_projects <- current_data()$general_concept_projects

        for (deleted_id_str in names(deleted_list)) {
          deleted_id <- as.integer(deleted_id_str)

          # Get concept info for logging
          concept_info <- original_data %>%
            dplyr::filter(general_concept_id == deleted_id)

          # Log the deletion
          if (nrow(concept_info) > 0) {
            user <- current_user()
            if (!is.null(user) && !is.null(user$first_name) && !is.null(user$last_name)) {
              username <- paste(user$first_name, user$last_name)
              log_history_change("general_concept",
                username = username,
                action_type = "delete",
                category = concept_info$category[1],
                subcategory = concept_info$subcategory[1],
                general_concept_name = concept_info$general_concept_name[1],
                comment = sprintf("Deleted concept '%s' from category '%s' > '%s'",
                                concept_info$general_concept_name[1],
                                concept_info$category[1],
                                concept_info$subcategory[1])
              )
            }
          }

          # Remove associated mappings (cascade delete)
          concept_mappings <- concept_mappings %>%
            dplyr::filter(general_concept_id != deleted_id)

          # Remove associated custom concepts (cascade delete)
          custom_concepts <- custom_concepts %>%
            dplyr::filter(is.na(general_concept_id) | general_concept_id != deleted_id)

          # Remove from project assignments (cascade delete)
          if (!is.null(general_concept_projects)) {
            general_concept_projects <- general_concept_projects %>%
              dplyr::filter(general_concept_id != deleted_id)
          }
        }

        # Save updated mappings and custom concepts to CSV
        csv_path_mappings <- get_csv_path("general_concepts_details.csv")
        if (file.exists(csv_path_mappings)) {
          readr::write_csv(concept_mappings, csv_path_mappings)
        }

        csv_path_custom <- get_csv_path("custom_concepts.csv")
        if (file.exists(csv_path_custom)) {
          readr::write_csv(custom_concepts, csv_path_custom)
        }

        # Save updated project assignments to CSV
        csv_path_projects <- get_csv_path("general_concepts_projects.csv")
        if (file.exists(csv_path_projects) && !is.null(general_concept_projects)) {
          readr::write_csv(general_concept_projects, csv_path_projects)
        }

        # Remove from stats file (general_concepts_stats.csv)
        csv_path_stats <- get_csv_path("general_concepts_stats.csv")
        if (file.exists(csv_path_stats)) {
          stats_data <- readr::read_csv(csv_path_stats, show_col_types = FALSE)
          deleted_ids <- as.integer(names(deleted_list))
          stats_data <- stats_data %>%
            dplyr::filter(!general_concept_id %in% deleted_ids)
          readr::write_csv(stats_data, csv_path_stats)
        }

        # Update local data with deleted associations
        data <- local_data()
        data$concept_mappings <- concept_mappings
        data$custom_concepts <- custom_concepts
        data$general_concept_projects <- general_concept_projects
        local_data(data)

        # Clear deletion list
        deleted_general_concepts(list())
      }

      # Save general_concepts to CSV (language-specific file)
      lang <- current_language()
      general_concepts_file <- paste0("general_concepts_", lang, ".csv")
      csv_path <- get_csv_path(general_concepts_file)

      if (file.exists(csv_path)) {
        readr::write_csv(general_concepts, csv_path)

        # Log changes made during edit session
        if (!is.null(original_data)) {
          user <- current_user()
          if (!is.null(user) && !is.null(user$first_name) && !is.null(user$last_name)) {
            username <- paste(user$first_name, user$last_name)

            # Compare original and current data to find changes
            for (i in 1:nrow(general_concepts)) {
              concept_id <- general_concepts$general_concept_id[i]
              original_row <- original_data[original_data$general_concept_id == concept_id, ]

              if (nrow(original_row) > 0) {
                # Check each field for changes
                if (!identical(general_concepts$category[i], original_row$category[1])) {
                  log_history_change("general_concept",
                    username = username,
                    action_type = "update",
                    category = general_concepts$category[i],
                    subcategory = general_concepts$subcategory[i],
                    general_concept_name = general_concepts$general_concept_name[i],
                    comment = sprintf("Updated category from '%s' to '%s'",
                                    original_row$category[1], general_concepts$category[i])
                  )
                }
                if (!identical(general_concepts$subcategory[i], original_row$subcategory[1])) {
                  log_history_change("general_concept",
                    username = username,
                    action_type = "update",
                    category = general_concepts$category[i],
                    subcategory = general_concepts$subcategory[i],
                    general_concept_name = general_concepts$general_concept_name[i],
                    comment = sprintf("Updated subcategory from '%s' to '%s'",
                                    original_row$subcategory[1], general_concepts$subcategory[i])
                  )
                }
                if (!identical(general_concepts$general_concept_name[i], original_row$general_concept_name[1])) {
                  log_history_change("general_concept",
                    username = username,
                    action_type = "update",
                    category = general_concepts$category[i],
                    subcategory = general_concepts$subcategory[i],
                    general_concept_name = general_concepts$general_concept_name[i],
                    comment = sprintf("Updated general_concept_name from '%s' to '%s'",
                                    original_row$general_concept_name[1], general_concepts$general_concept_name[i])
                  )
                }
              }
            }
          }
        }
      }

      general_concepts_edit_mode(FALSE)
      original_general_concepts(NULL)

      # Update button visibility
      update_button_visibility()

      # Restore datatable state after re-render
      restore_datatable_state("general_concepts_table", saved_table_page, saved_table_search, session)
    })

    # Handle cell edits in general concepts table
    observe_event(input$general_concepts_table_cell_edit, {
      if (!general_concepts_edit_mode()) return()

      # Save datatable state before any changes
      save_datatable_state(input, "general_concepts_table", saved_table_page, saved_table_search)

      info <- input$general_concepts_table_cell_edit

      # Get current data
      general_concepts <- current_data()$general_concepts

      # Update the cell value
      row_num <- info$row
      col_num <- info$col + 1  # DT uses 0-based indexing for columns, add 1 for R
      new_value <- info$value

      # Get concept ID for reference
      concept_id <- general_concepts[row_num, "general_concept_id"]

      # Map column number to actual column name and update value
      # Columns: general_concept_id (1), category (2), subcategory (3), general_concept_name (4)
      if (col_num == 2) {
        # Category column
        general_concepts[row_num, "category"] <- new_value
      } else if (col_num == 3) {
        # Subcategory column
        general_concepts[row_num, "subcategory"] <- new_value
      } else if (col_num == 4) {
        # General concept name column
        # Check for duplicates
        category <- general_concepts[row_num, "category"]
        subcategory <- general_concepts[row_num, "subcategory"]

        duplicate_exists <- general_concepts %>%
          dplyr::filter(
            general_concept_id != concept_id,  # Exclude current row
            category == !!category,
            subcategory == !!subcategory,
            general_concept_name == trimws(new_value)
          ) %>%
          nrow() > 0

        if (duplicate_exists) {
          # Show error message - concept already exists
          showNotification(
            sprintf("A concept named '%s' already exists in category '%s' > '%s'.",
                   trimws(new_value), category, subcategory),
            type = "error",
            duration = 5
          )

          # Don't update the value - keep general_concepts as is (from current_data)
          # Update local_data to trigger table re-render without the change
          data <- local_data()
          data$general_concepts <- general_concepts  # This still has the old value
          local_data(data)

          # Restore datatable state after re-render
          restore_datatable_state("general_concepts_table", saved_table_page, saved_table_search, session)

          return()
        }

        general_concepts[row_num, "general_concept_name"] <- new_value
      }

      # Update local data (logging will happen on save)
      data <- local_data()
      data$general_concepts <- general_concepts
      local_data(data)

      # Restore datatable state after re-render
      restore_datatable_state("general_concepts_table", saved_table_page, saved_table_search, session)
    })

    ### Delete Concept ----
    # Handle delete general concept button
    observe_event(input$delete_general_concept, {
      if (!general_concepts_edit_mode()) return()

      # Save datatable state before deletion
      save_datatable_state(input, "general_concepts_table", saved_table_page, saved_table_search)

      concept_id <- input$delete_general_concept
      if (!is.null(concept_id)) {
        # Mark concept for deletion (will be applied on Save updates)
        current_deleted <- deleted_general_concepts()
        current_deleted[[as.character(concept_id)]] <- TRUE
        deleted_general_concepts(current_deleted)

        # Remove from local display immediately (but not from CSV yet)
        general_concepts <- current_data()$general_concepts %>%
          dplyr::filter(general_concept_id != as.integer(concept_id))

        # Update local data for display
        data <- local_data()
        data$general_concepts <- general_concepts
        local_data(data)

        # Restore datatable state after re-render
        restore_datatable_state("general_concepts_table", saved_table_page, saved_table_search, session)
      }
    })

    ### Add New Concept  ----
    # Handle show add concept modal button
    observe_event(input$show_general_concepts_add_modal, {
      # Update category choices
      general_concepts <- current_data()$general_concepts
      categories <- sort(unique(general_concepts$category))

      updateSelectizeInput(session, "general_concepts_new_category", choices = categories, selected = character(0))
      updateSelectizeInput(session, "general_concepts_new_subcategory", choices = character(0), selected = character(0))

      # Hide all error messages
      shinyjs::hide("duplicate_concept_error")
      shinyjs::hide("general_concepts_new_name_error")
      shinyjs::hide("general_concepts_new_category_error")
      shinyjs::hide("general_concepts_new_subcategory_error")

      # Show the custom modal
      shinyjs::show("general_concepts_add_modal")
    })

    # Update subcategories when category changes in add concept modal
    observe_event(input$general_concepts_new_category, {
      if (is.null(input$general_concepts_new_category) || identical(input$general_concepts_new_category, "")) {
        return()
      }

      general_concepts <- current_data()$general_concepts
      selected_category <- input$general_concepts_new_category

      # Get subcategories for the selected category
      subcategories_for_category <- general_concepts %>%
        dplyr::filter(category == selected_category) %>%
        dplyr::pull(subcategory) %>%
        unique() %>%
        sort()

      # Update subcategory choices
      updateSelectizeInput(
        session,
        "general_concepts_new_subcategory",
        choices = subcategories_for_category,
        server = TRUE
      )
    }, ignoreInit = TRUE)

    # Handle add new concept
    observe_event(input$general_concepts_add_new, {
      # Save datatable state before adding concept
      save_datatable_state(input, "general_concepts_table", saved_table_page, saved_table_search)

      # Hide all error messages first
      shinyjs::hide("general_concepts_new_name_error")
      shinyjs::hide("general_concepts_new_category_error")
      shinyjs::hide("general_concepts_new_subcategory_error")

      # Determine which category/subcategory field is active
      category <- if (!is.null(input$general_concepts_new_category_text) && nchar(trimws(input$general_concepts_new_category_text)) > 0) {
        input$general_concepts_new_category_text
      } else {
        input$general_concepts_new_category
      }

      subcategory <- if (!is.null(input$general_concepts_new_subcategory_text) && nchar(trimws(input$general_concepts_new_subcategory_text)) > 0) {
        input$general_concepts_new_subcategory_text
      } else {
        input$general_concepts_new_subcategory
      }

      concept_name <- input$general_concepts_new_name

      # Validate all required fields
      has_error <- FALSE

      if (is.null(concept_name) || nchar(trimws(concept_name)) == 0) {
        shinyjs::show("general_concepts_new_name_error")
        has_error <- TRUE
      }

      if (is.null(category) || nchar(trimws(category)) == 0) {
        shinyjs::show("general_concepts_new_category_error")
        has_error <- TRUE
      }

      if (is.null(subcategory) || nchar(trimws(subcategory)) == 0) {
        shinyjs::show("general_concepts_new_subcategory_error")
        has_error <- TRUE
      }

      if (has_error) {
        return()
      }

      # Get current data
      general_concepts <- current_data()$general_concepts

      # Store trimmed values for comparison
      category_trimmed <- trimws(category)
      subcategory_trimmed <- trimws(subcategory)
      concept_name_trimmed <- trimws(concept_name)

      # Check if concept already exists (same category, subcategory, and name)
      duplicate_exists <- general_concepts %>%
        dplyr::filter(
          .data$category == category_trimmed,
          .data$subcategory == subcategory_trimmed,
          .data$general_concept_name == concept_name_trimmed
        ) %>%
        nrow() > 0

      if (duplicate_exists) {
        # Show error message in modal
        error_text <- sprintf("A concept named '%s' already exists in category '%s' > '%s'. Please choose a different name or category.",
                             concept_name_trimmed, category_trimmed, subcategory_trimmed)
        shinyjs::html("duplicate_concept_error_text", error_text)
        shinyjs::show("duplicate_concept_error")
        return()
      }

      # Hide error message if validation passes
      shinyjs::hide("duplicate_concept_error")

      # Generate new ID (max + 1)
      new_id <- max(general_concepts$general_concept_id, na.rm = TRUE) + 1

      # Create new row
      new_row <- data.frame(
        general_concept_id = new_id,
        category = category_trimmed,
        subcategory = subcategory_trimmed,
        general_concept_name = concept_name_trimmed,
        comments = NA_character_,
        statistical_summary = NA_character_,
        stringsAsFactors = FALSE
      )

      # Add to general_concepts and sort alphabetically for display
      general_concepts_display <- rbind(general_concepts, new_row) %>%
        dplyr::arrange(category, subcategory, general_concept_name)

      # Find the row index of the newly added concept after sorting
      new_concept_row_index <- which(
        general_concepts_display$general_concept_id == new_id &
        general_concepts_display$category == category_trimmed &
        general_concepts_display$subcategory == subcategory_trimmed &
        general_concepts_display$general_concept_name == concept_name_trimmed
      )[1]

      # Save to CSV sorted by ID (for easier version control)
      lang <- current_language()
      general_concepts_file <- paste0("general_concepts_", lang, ".csv")
      csv_path <- get_csv_path(general_concepts_file)

      if (file.exists(csv_path)) {
        general_concepts_to_save <- general_concepts_display %>%
          dplyr::arrange(general_concept_id)
        readr::write_csv(general_concepts_to_save, csv_path)

        # Log the insertion
        user <- current_user()
        if (!is.null(user) && !is.null(user$first_name) && !is.null(user$last_name)) {
          username <- paste(user$first_name, user$last_name)
          log_history_change("general_concept",
            username = username,
            action_type = "insert",
            category = category_trimmed,
            subcategory = subcategory_trimmed,
            general_concept_name = concept_name_trimmed,
            comment = sprintf("Created concept '%s' in category '%s' > '%s'",
                            concept_name_trimmed, category_trimmed, subcategory_trimmed)
          )
        }

        # Close modal and reset fields first
        shinyjs::hide("general_concepts_add_modal")

        # Reset input fields
        shiny::updateTextInput(session, "general_concepts_new_name", value = "")
        shiny::updateTextInput(session, "general_concepts_new_category_text", value = "")
        shiny::updateTextInput(session, "general_concepts_new_subcategory_text", value = "")
        updateSelectizeInput(session, "general_concepts_new_category", selected = character(0))
        updateSelectizeInput(session, "general_concepts_new_subcategory", selected = character(0))

        # Update local data (this triggers table re-render via local_data_trigger)
        data <- local_data()
        data$general_concepts <- general_concepts_display
        local_data(data)

        # Show success notification
        showNotification(
          sprintf("Concept '%s' added successfully", concept_name_trimmed),
          type = "message",
          duration = 3
        )

        # Restore datatable state after re-render (with delay to ensure table is ready)
        shinyjs::delay(300, {
          restore_datatable_state("general_concepts_table", saved_table_page, saved_table_search, session)
        })
      }
    })

    ## 4) Server - General Concept Detail Page ----
    
    #### Save Updates ----
    # Handle detail save updates button
    observe_event(input$general_concept_detail_save_updates, {
      if (!general_concept_detail_edit_mode()) return()

      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      # Get current data from CSV (not from current_data() which has temporary changes)
      lang <- current_language()
      general_concepts_file <- paste0("general_concepts_", lang, ".csv")
      general_concepts_path <- get_csv_path(general_concepts_file)
      concept_mappings_path <- get_csv_path("general_concepts_details.csv")
      custom_concepts_path <- get_csv_path("custom_concepts.csv")

      general_concepts <- readr::read_csv(general_concepts_path, show_col_types = FALSE)
      concept_mappings <- readr::read_csv(concept_mappings_path, show_col_types = FALSE)
      custom_concepts <- if (file.exists(custom_concepts_path)) {
        readr::read_csv(custom_concepts_path, show_col_types = FALSE)
      } else {
        NULL
      }

      # Get current concept info for comparison
      current_concept <- general_concepts %>%
        dplyr::filter(general_concept_id == concept_id) %>%
        dplyr::slice(1)

      # Get user info for history logging
      user <- current_user()
      username <- if (!is.null(user) && !is.null(user$first_name) && !is.null(user$last_name)) {
        paste(user$first_name, user$last_name)
      } else {
        "Unknown User"
      }

      # Update comments in general_concepts and log changes
      # Comments are stored in the language-specific CSV file (general_concepts_en.csv or general_concepts_fr.csv)
      new_comment <- input$comments_input
      lang <- current_language()

      if (!is.null(new_comment) && nrow(current_concept) > 0) {
        # Get old comment
        old_comment <- if ("comments" %in% names(current_concept) && !is.na(current_concept$comments[1])) {
          current_concept$comments[1]
        } else {
          ""
        }

        # Check if comment has changed
        if (old_comment != new_comment) {
          # Update the comments column
          general_concepts$comments <- ifelse(
            general_concepts$general_concept_id == concept_id,
            new_comment,
            general_concepts$comments
          )

          # Get concept name for history
          concept_name <- if (!is.na(current_concept$general_concept_name[1])) {
            current_concept$general_concept_name[1]
          } else {
            paste0("ID: ", concept_id)
          }

          # Log the change with language info
          lang_code <- toupper(lang)
          log_history_change(
            entity_type = "mapped_concept",
            username = username,
            action_type = "update",
            general_concept_id = concept_id,
            vocabulary_id = NA,
            concept_code = NA,
            concept_name = concept_name,
            comment = paste0("Updated ETL guidance comment (", lang_code, "): ", new_comment)
          )
        }
      }

      # Update statistical_summary in general_concepts and log changes
      new_statistical_summary <- input$statistical_summary_editor
      if (!is.null(new_statistical_summary) && nrow(current_concept) > 0) {
        old_statistical_summary <- if ("statistical_summary" %in% names(current_concept) &&
                                       !is.null(current_concept$statistical_summary[1]) &&
                                       !is.na(current_concept$statistical_summary[1])) {
          current_concept$statistical_summary[1]
        } else {
          ""
        }

        # Check if statistical summary has changed
        if (old_statistical_summary != new_statistical_summary) {
          # Update statistical_summary in memory (general_concepts has it joined from stats file)
          if ("statistical_summary" %in% names(general_concepts)) {
            general_concepts <- general_concepts %>%
              dplyr::mutate(
                statistical_summary = ifelse(
                  general_concept_id == concept_id,
                  new_statistical_summary,
                  statistical_summary
                )
              )
          } else {
            # Add the column if it doesn't exist
            general_concepts <- general_concepts %>%
              dplyr::mutate(statistical_summary = NA_character_)
            general_concepts$statistical_summary[general_concepts$general_concept_id == concept_id] <- new_statistical_summary
          }

          # Get concept name for history
          concept_name <- if (!is.na(current_concept$general_concept_name[1])) {
            current_concept$general_concept_name[1]
          } else {
            paste0("ID: ", concept_id)
          }

          # Log the change
          log_history_change(
            entity_type = "mapped_concept",
            username = username,
            action_type = "update",
            general_concept_id = concept_id,
            vocabulary_id = NA,
            concept_code = NA,
            concept_name = concept_name,
            comment = paste0("Updated statistical summary JSON: ", new_statistical_summary)
          )
        }
      }

      # Update mapping details from edited_mapping_details()
      # - omop_unit_concept_id is stored in general_concepts_details.csv (concept_mappings)
      # - loinc_rank, ehden_rows_count, ehden_num_data_sources are stored in general_concepts_details_statistics.csv (concept_statistics)
      all_edits <- edited_mapping_details()
      if (length(all_edits) > 0) {
        # Load concept_statistics for updating statistics fields
        concept_statistics_path <- get_csv_path("general_concepts_details_statistics.csv")
        concept_statistics <- if (file.exists(concept_statistics_path)) {
          df <- readr::read_csv(concept_statistics_path, show_col_types = FALSE)
          # Ensure correct column types for binding
          df$omop_concept_id <- as.integer(df$omop_concept_id)
          df$loinc_rank <- as.integer(df$loinc_rank)
          df$ehden_rows_count <- as.integer(df$ehden_rows_count)
          df$ehden_num_data_sources <- as.integer(df$ehden_num_data_sources)
          df
        } else {
          data.frame(
            omop_concept_id = integer(),
            loinc_rank = integer(),
            ehden_rows_count = integer(),
            ehden_num_data_sources = integer(),
            stringsAsFactors = FALSE
          )
        }

        stats_changed <- FALSE

        # Iterate over all edited mappings
        for (mapped_id_str in names(all_edits)) {
          mapped_id <- as.integer(mapped_id_str)
          edits <- all_edits[[mapped_id_str]]

          # Track changes for history logging
          changes_made <- character(0)

          # Find the row in concept_statistics to update (indexed by omop_concept_id only)
          stats_row_idx <- which(concept_statistics$omop_concept_id == mapped_id)

          # If no row exists for this concept, create one
          if (length(stats_row_idx) == 0) {
            new_stats_row <- data.frame(
              omop_concept_id = as.integer(mapped_id),
              loinc_rank = NA_integer_,
              ehden_rows_count = NA_integer_,
              ehden_num_data_sources = NA_integer_,
              stringsAsFactors = FALSE
            )
            concept_statistics <- dplyr::bind_rows(concept_statistics, new_stats_row)
            stats_row_idx <- nrow(concept_statistics)
          } else {
            stats_row_idx <- stats_row_idx[1]
          }

          # Update loinc_rank if provided
          if (!is.null(edits$loinc_rank)) {
            old_val <- concept_statistics$loinc_rank[stats_row_idx]
            new_val <- if (is.na(edits$loinc_rank)) NA_integer_ else as.integer(edits$loinc_rank)
            old_val_int <- if (is.na(old_val)) NA_integer_ else as.integer(old_val)
            if (!identical(new_val, old_val_int)) {
              concept_statistics$loinc_rank[stats_row_idx] <- new_val
              changes_made <- c(changes_made, paste0("LOINC Rank: ", old_val_int, " -> ", new_val))
              stats_changed <- TRUE
            }
          }

          # Update ehden_rows_count if provided
          if (!is.null(edits$ehden_rows_count)) {
            old_val <- concept_statistics$ehden_rows_count[stats_row_idx]
            new_val <- if (is.na(edits$ehden_rows_count)) NA_integer_ else as.integer(edits$ehden_rows_count)
            old_val_int <- if (is.na(old_val)) NA_integer_ else as.integer(old_val)
            if (!identical(new_val, old_val_int)) {
              concept_statistics$ehden_rows_count[stats_row_idx] <- new_val
              changes_made <- c(changes_made, paste0("EHDEN Rows Count: ", old_val_int, " -> ", new_val))
              stats_changed <- TRUE
            }
          }

          # Update ehden_num_data_sources if provided
          if (!is.null(edits$ehden_num_data_sources)) {
            old_val <- concept_statistics$ehden_num_data_sources[stats_row_idx]
            new_val <- if (is.na(edits$ehden_num_data_sources)) NA_integer_ else as.integer(edits$ehden_num_data_sources)
            old_val_int <- if (is.na(old_val)) NA_integer_ else as.integer(old_val)
            if (!identical(new_val, old_val_int)) {
              concept_statistics$ehden_num_data_sources[stats_row_idx] <- new_val
              changes_made <- c(changes_made, paste0("EHDEN Data Sources: ", old_val_int, " -> ", new_val))
              stats_changed <- TRUE
            }
          }

          # Update omop_unit_concept_id in concept_mappings (general_concepts_details.csv)
          if (!is.null(edits$omop_unit_concept_id)) {
            mapping_row_idx <- which(
              concept_mappings$general_concept_id == concept_id &
              concept_mappings$omop_concept_id == mapped_id
            )

            if (length(mapping_row_idx) > 0) {
              mapping_row_idx <- mapping_row_idx[1]
              old_omop_unit_concept_id <- concept_mappings$omop_unit_concept_id[mapping_row_idx]

              new_val <- if (is.na(edits$omop_unit_concept_id)) "/" else as.character(edits$omop_unit_concept_id)
              old_val <- if (is.na(old_omop_unit_concept_id) || old_omop_unit_concept_id == "") "/" else as.character(old_omop_unit_concept_id)
              if (new_val != old_val) {
                concept_mappings$omop_unit_concept_id[mapping_row_idx] <- new_val
                changes_made <- c(changes_made, paste0("OMOP Unit Concept ID: ", old_val, " -> ", new_val))
              }
            }
          }

          # Log changes if any were made for this mapping
          if (length(changes_made) > 0) {
            # Get concept info from vocabulary for logging
            vocab_data <- vocabularies()
            concept_info <- NULL
            if (!is.null(vocab_data) && !is.null(vocab_data$concept)) {
              concept_info <- vocab_data$concept %>%
                dplyr::filter(concept_id == !!mapped_id) %>%
                dplyr::collect() %>%
                dplyr::slice(1)
            }

            log_history_change(
              entity_type = "mapped_concept",
              username = username,
              action_type = "update",
              general_concept_id = concept_id,
              vocabulary_id = if (!is.null(concept_info) && nrow(concept_info) > 0) as.character(concept_info$vocabulary_id[1]) else NA,
              concept_code = if (!is.null(concept_info) && nrow(concept_info) > 0) as.character(concept_info$concept_code[1]) else NA,
              concept_name = if (!is.null(concept_info) && nrow(concept_info) > 0) as.character(concept_info$concept_name[1]) else NA,
              comment = paste0("Updated mapping details: ", paste(changes_made, collapse = "; "))
            )
          }
        }

        # Save concept_statistics if any statistics fields changed
        if (stats_changed) {
          readr::write_csv(concept_statistics, concept_statistics_path)
        }

        # Update local_data with new concept_statistics
        if (stats_changed) {
          updated_local <- local_data()
          if (!is.null(updated_local)) {
            updated_local$concept_statistics <- concept_statistics
            local_data(updated_local)
          }
        }
      }

      # Apply concept deletions
      concept_deletions <- deleted_concepts()
      concept_key <- as.character(concept_id)

      if (!is.null(concept_deletions[[concept_key]])) {
        deleted_ids <- concept_deletions[[concept_key]]

        # Parse deleted IDs to separate OMOP and custom concepts
        omop_ids_to_delete <- integer()
        custom_ids_to_delete <- integer()

        for (id_str in deleted_ids) {
          if (grepl("^omop-", id_str)) {
            omop_id <- as.integer(sub("^omop-", "", id_str))
            omop_ids_to_delete <- c(omop_ids_to_delete, omop_id)
          } else if (grepl("^custom-", id_str)) {
            custom_id <- as.integer(sub("^custom-", "", id_str))
            custom_ids_to_delete <- c(custom_ids_to_delete, custom_id)
          }
        }

        # Delete OMOP concepts from concept_mappings
        if (length(omop_ids_to_delete) > 0) {
          # Get concept info before deletion for logging
          user <- current_user()
          if (!is.null(user) && !is.null(user$first_name) && !is.null(user$last_name)) {
            username <- paste(user$first_name, user$last_name)
            vocab_data <- vocabularies()

            for (omop_id in omop_ids_to_delete) {
              # Get concept info from vocabulary
              if (!is.null(vocab_data) && !is.null(vocab_data$concept)) {
                concept_info <- vocab_data$concept %>%
                  dplyr::filter(concept_id == !!omop_id) %>%
                  dplyr::collect() %>%
                  dplyr::slice(1)

                if (nrow(concept_info) > 0) {
                  log_history_change(
                    entity_type = "mapped_concept",
                    username = username,
                    action_type = "delete",
                    general_concept_id = concept_id,
                    vocabulary_id = as.character(concept_info$vocabulary_id[1]),
                    concept_code = as.character(concept_info$concept_code[1]),
                    concept_name = as.character(concept_info$concept_name[1]),
                    comment = "Deleted OMOP concept mapping"
                  )
                }
              }
            }
          }

          # Now delete from concept_mappings
          concept_mappings <- concept_mappings %>%
            dplyr::filter(!(general_concept_id == concept_id & omop_concept_id %in% omop_ids_to_delete))
        }

        # Delete custom concepts from custom_concepts
        if (length(custom_ids_to_delete) > 0 && !is.null(custom_concepts)) {
          # Get concept info before deletion for logging
          user <- current_user()
          if (!is.null(user) && !is.null(user$first_name) && !is.null(user$last_name)) {
            username <- paste(user$first_name, user$last_name)
            for (custom_id in custom_ids_to_delete) {
              concept_info <- custom_concepts %>%
                dplyr::filter(general_concept_id == concept_id & custom_concept_id == custom_id) %>%
                dplyr::slice(1)

              if (nrow(concept_info) > 0) {
                log_history_change(
                  entity_type = "mapped_concept",
                  username = username,
                  action_type = "delete",
                  general_concept_id = concept_id,
                  vocabulary_id = as.character(concept_info$vocabulary_id[1]),
                  concept_code = as.character(concept_info$concept_code[1]),
                  concept_name = as.character(concept_info$concept_name[1]),
                  comment = "Deleted custom concept mapping"
                )
              }
            }
          }

          # Now delete from custom_concepts
          custom_concepts <- custom_concepts %>%
            dplyr::filter(!(general_concept_id == concept_id & custom_concept_id %in% custom_ids_to_delete))
        }
      }

      # Add newly added concepts to concept_mappings before saving
      added_list <- added_concepts()
      if (length(added_list) > 0) {
        # Convert list to data frame
        new_mappings_df <- dplyr::bind_rows(added_list)

        # Log history for each new mapping
        user <- current_user()
        if (!is.null(user) && !is.null(user$first_name) && !is.null(user$last_name)) {
          username <- paste(user$first_name, user$last_name)
          vocab_data <- vocabularies()

          for (i in 1:nrow(new_mappings_df)) {
            # Get concept info from vocabulary
            if (!is.null(vocab_data) && !is.null(vocab_data$concept)) {
              omop_id <- as.integer(new_mappings_df$omop_concept_id[i])

              concept_info <- vocab_data$concept %>%
                dplyr::filter(concept_id == !!omop_id) %>%
                dplyr::collect() %>%
                dplyr::slice(1)

              if (nrow(concept_info) > 0) {
                log_history_change(
                  entity_type = "mapped_concept",
                  username = username,
                  action_type = "insert",
                  general_concept_id = new_mappings_df$general_concept_id[i],
                  vocabulary_id = as.character(concept_info$vocabulary_id[1]),
                  concept_code = as.character(concept_info$concept_code[1]),
                  concept_name = as.character(concept_info$concept_name[1]),
                  comment = "Added OMOP concept mapping"
                )
              }
            }
          }
        }

        # Add new mappings to concept_mappings
        concept_mappings <- dplyr::bind_rows(concept_mappings, new_mappings_df)
      }

      # Write to CSV files (language-specific for general_concepts + stats file)
      lang <- current_language()
      save_general_concepts_csv(general_concepts, language = lang)

      readr::write_csv(
        concept_mappings,
        get_csv_path("general_concepts_details.csv")
      )

      # Write custom_concepts.csv if modified
      if (!is.null(custom_concepts)) {
        readr::write_csv(
          custom_concepts,
          get_csv_path("custom_concepts.csv")
        )
      }

      # Update local data (preserve concept_statistics from earlier update or from current data)
      current_local <- local_data()
      updated_data <- list(
        general_concepts = general_concepts,
        concept_mappings = concept_mappings,
        custom_concepts = custom_concepts,
        concept_statistics = if (!is.null(current_local$concept_statistics)) current_local$concept_statistics else current_data()$concept_statistics
      )
      local_data(updated_data)
      
      # Reset edit state
      deleted_concepts(list())
      added_concepts(list())
      edited_mapping_details(list())  # Reset temporary mapping detail edits
      general_concept_detail_edit_mode(FALSE)
      # Reset tab to comments
      comments_tab("comments")
      # Hide edit buttons and show normal action buttons
      shinyjs::hide("general_concept_detail_edit_buttons")
      shinyjs::show("general_concept_detail_action_buttons")
    })
    
    ### a) Mapped Concepts (Top-Left Panel) ----
    ##### Mapped Concepts Table Rendering ----
    # Render concept mappings table when concept_mappings_table trigger fires (cascade observer)
    observe_event(concept_mappings_table_trigger(), {
      concept_id <- selected_concept_id()
      if (!is.null(concept_id)) {
        output$concept_mappings_table <- DT::renderDT({

      # Check if OHDSI vocabularies are loaded
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) {
        return(DT::datatable(
          data.frame(Message = "OHDSI vocabularies not loaded. Please configure the ATHENA folder in Settings."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Force re-render when edit_mode changes
      is_editing <- general_concept_detail_edit_mode()

      # Read directly from general_concepts_details.csv
      csv_mappings <- current_data()$concept_mappings %>%
        dplyr::filter(general_concept_id == concept_id)

      # Read custom concepts from current_data()
      if (!is.null(current_data()$custom_concepts) && nrow(current_data()$custom_concepts) > 0) {
        custom_concepts <- current_data()$custom_concepts %>%
          dplyr::filter(general_concept_id == concept_id) %>%
          dplyr::select(
            custom_concept_id,
            concept_name,
            vocabulary_id,
            concept_code
          ) %>%
          dplyr::mutate(
            omop_concept_id = NA_integer_,
            standard_concept = NA_character_,
            is_custom = TRUE
          )
      } else {
        custom_concepts <- data.frame(
          custom_concept_id = integer(),
          concept_name = character(),
          vocabulary_id = character(),
          concept_code = character(),
          omop_concept_id = integer(),
          standard_concept = character(),
          is_custom = logical()
        )
      }

      # Enrich OMOP concepts with vocabulary data
      vocab_data_for_enrichment <- vocabularies()
      if (!is.null(vocab_data_for_enrichment) && nrow(csv_mappings) > 0) {
        # Get concept details including standard_concept
        concept_ids <- csv_mappings$omop_concept_id
        omop_concepts <- vocab_data_for_enrichment$concept %>%
          dplyr::filter(concept_id %in% concept_ids) %>%
          dplyr::select(concept_id, concept_name, vocabulary_id, concept_code, standard_concept) %>%
          dplyr::collect()

        # Join with csv_mappings
        csv_mappings <- csv_mappings %>%
          dplyr::left_join(
            omop_concepts,
            by = c("omop_concept_id" = "concept_id")
          ) %>%
          dplyr::mutate(
            is_custom = FALSE,
            custom_concept_id = NA_integer_
          )
      } else {
        # If no vocabulary data, add placeholder columns
        csv_mappings <- csv_mappings %>%
          dplyr::mutate(
            concept_name = NA_character_,
            vocabulary_id = NA_character_,
            concept_code = NA_character_,
            standard_concept = NA_character_,
            is_custom = FALSE,
            custom_concept_id = NA_integer_
          )
      }

      # Add custom_concept_id column to csv_mappings if it doesn't exist
      if (!"custom_concept_id" %in% names(csv_mappings)) {
        csv_mappings <- csv_mappings %>%
          dplyr::mutate(custom_concept_id = NA_integer_)
      }

      # Combine OMOP and custom concepts
      all_concepts <- dplyr::bind_rows(
        csv_mappings %>%
          dplyr::select(custom_concept_id, concept_name, vocabulary_id, concept_code, omop_concept_id, standard_concept, is_custom),
        custom_concepts
      )

      # Select final columns and arrange by standard_concept (S first, then C, then NULL)
      mappings <- all_concepts %>%
        dplyr::select(
          custom_concept_id,
          concept_name,
          vocabulary_id,
          concept_code,
          omop_concept_id,
          standard_concept,
          is_custom
        ) %>%
        dplyr::mutate(
          vocabulary_id = factor(vocabulary_id),
          # Create sort order: S=1, C=2, NULL/NA=3
          sort_order = dplyr::case_when(
            standard_concept == "S" ~ 1,
            standard_concept == "C" ~ 2,
            TRUE ~ 3
          )
        ) %>%
        dplyr::arrange(sort_order, concept_name) %>%
        dplyr::select(-sort_order)

      # Filter out deleted concepts in edit mode
      if (is_editing) {
        current_deletions <- deleted_concepts()
        concept_key <- as.character(concept_id)
        if (!is.null(current_deletions[[concept_key]])) {
          deleted_ids <- current_deletions[[concept_key]]
          # Create unique_id for filtering (before adding HTML columns)
          mappings <- mappings %>%
            dplyr::mutate(
              unique_id_filter = dplyr::case_when(
                is_custom & !is.na(custom_concept_id) ~ paste0("custom-", custom_concept_id),
                !is_custom & !is.na(omop_concept_id) ~ paste0("omop-", omop_concept_id),
                TRUE ~ "unknown"
              )
            )

          mappings <- mappings %>%
            dplyr::filter(!unique_id_filter %in% deleted_ids) %>%
            dplyr::select(-unique_id_filter)
        }
      }

      # Convert standard_concept to badge display
      if (nrow(mappings) > 0) {
        if (is_editing) {
          # In edit mode: add unique ID and action column (no toggle for standard_concept)
          mappings <- mappings %>%
            dplyr::mutate(
              # Create unique ID: "omop-{id}" for OMOP concepts, "custom-{id}" for custom concepts
              unique_id = dplyr::case_when(
                is_custom & !is.na(custom_concept_id) ~ paste0("custom-", custom_concept_id),
                !is_custom & !is.na(omop_concept_id) ~ paste0("omop-", omop_concept_id),
                TRUE ~ paste0("unknown-", dplyr::row_number())
              )
            )

          # Cache mappings BEFORE converting to HTML (for selection handling)
          mappings_for_cache <- mappings %>%
            dplyr::select(concept_name, vocabulary_id, concept_code, standard_concept, omop_concept_id)
          current_mappings(mappings_for_cache)

          # Create HTML for standard_concept badge and delete action
          mappings <- mappings %>%
            dplyr::mutate(
              standard_concept = dplyr::case_when(
                standard_concept == "S" ~ '<span class="badge-status badge-success">Standard</span>',
                standard_concept == "C" ~ '<span class="badge-status badge-secondary">Classification</span>',
                TRUE ~ '<span class="badge-status badge-danger">Non-standard</span>'
              ),
              action = sprintf(
                '<i class="fa fa-trash delete-icon" data-omop-id="%s" data-custom-id="%s" style="cursor: pointer; color: #dc3545;"></i>',
                ifelse(is.na(omop_concept_id), "", omop_concept_id),
                ifelse(is.na(custom_concept_id), "", custom_concept_id)
              )
            )
        } else {
          # View mode: convert standard_concept to badge
          mappings <- mappings %>%
            dplyr::mutate(
              standard_concept = dplyr::case_when(
                standard_concept == "S" ~ '<span class="badge-status badge-success">Standard</span>',
                standard_concept == "C" ~ '<span class="badge-status badge-secondary">Classification</span>',
                TRUE ~ '<span class="badge-status badge-danger">Non-standard</span>'
              )
            )

          # Cache mappings for selection handling
          mappings_for_cache <- mappings %>%
            dplyr::mutate(standard_concept = dplyr::case_when(
              grepl("Standard", standard_concept) & !grepl("Non-standard", standard_concept) ~ "S",
              grepl("Classification", standard_concept) ~ "C",
              TRUE ~ NA_character_
            ))
          current_mappings(mappings_for_cache)
        }
      } else {
        # If no concepts, show empty table
        return(DT::datatable(
          data.frame(Message = "No concepts found."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Reorder columns
      if (is_editing) {
        mappings <- mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, standard_concept, action, omop_concept_id)
      } else {
        mappings <- mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, standard_concept, omop_concept_id)
      }

      # Reset selection tracker when table is re-rendered
      last_processed_selection(NULL)

      # Load JavaScript callbacks
      base_callback <- paste(readLines(get_package_dir("www", "dt_callback.js")), collapse = "\n")
      keyboard_nav <- paste(readLines(get_package_dir("www", "keyboard_nav.js")), collapse = "\n")

      # Add callback to track page changes
      page_tracking_code <- sprintf("
        table.on('page.dt', function() {
          var info = table.page.info();
          Shiny.setInputValue('%s', info.start, {priority: 'event'});
        });
      ", session$ns("concept_mappings_page_start"))

      # Combine callbacks
      callback <- JS(paste(base_callback, page_tracking_code, sep = "\n"))

      # Build initComplete callback that includes keyboard nav
      init_complete_js <- create_keyboard_nav(keyboard_nav, TRUE, FALSE)

      # Configure DataTable columns based on edit mode
      if (is_editing) {
        escape_cols <- c(TRUE, TRUE, TRUE, FALSE, FALSE, TRUE)  # Don't escape HTML in standard_concept and action columns
        col_names <- c("Concept Name", "Vocabulary", "Code", "Standard", "Action", "OMOP ID")
        col_defs <- list(
          list(targets = 3, width = "120px", className = 'dt-center'),  # Standard column
          list(targets = 4, width = "60px", className = 'dt-center'),   # Action column
          list(targets = 5, visible = FALSE)  # OMOP ID column hidden
        )
      } else {
        escape_cols <- c(TRUE, TRUE, TRUE, FALSE, TRUE)  # Don't escape HTML in standard_concept column
        col_names <- c("Concept Name", "Vocabulary", "Code", "Standard", "OMOP ID")
        col_defs <- list(
          list(targets = 3, width = "120px", className = 'dt-center'),  # Standard column
          list(targets = 4, visible = FALSE)  # OMOP ID column hidden
        )
      }

      # Get current page to restore after refresh
      current_page_start <- concept_mappings_current_page()

      dt <- DT::datatable(
        mappings,
        selection = 'none',
        rownames = FALSE,
        escape = escape_cols,
        extensions = c('Select'),
        colnames = col_names,
        filter = 'top',
        options = list(
          pageLength = 6,
          dom = 'tip',
          language = get_datatable_language(),
          select = list(style = 'single', info = FALSE),
          columnDefs = col_defs,
          displayStart = current_page_start,
          initComplete = init_complete_js
        ),
        callback = callback
      )

          dt
        }, server = FALSE)
      }
    }, ignoreInit = TRUE)

    # Cache for current mappings to avoid recalculation
    current_mappings <- reactiveVal(NULL)

    # Track last processed selection to avoid reprocessing same selection
    last_processed_selection <- reactiveVal(NULL)

    # Track current page of concept mappings table to restore after refresh
    concept_mappings_current_page <- reactiveVal(0)

    # Observer to save page position when user changes pages
    observe_event(input$concept_mappings_page_start, {
      concept_mappings_current_page(input$concept_mappings_page_start)
    }, ignoreInit = TRUE)

    # Debounce the table selection to avoid excessive updates when navigating with arrow keys
    debounced_selection <- debounce(
      reactive({
        input$concept_mappings_table_rows_selected
      }),
      300  # Wait 300ms after user stops navigating
    )

    # Observe selection in concept mappings table with debounce
    observe_event(debounced_selection(), {
      selected_row <- debounced_selection()

      if (is.null(selected_row) || length(selected_row) == 0) return()

      # Check if this is the same selection we already processed
      if (identical(selected_row, last_processed_selection())) {
        return()
      }

      # Update last processed selection
      last_processed_selection(selected_row)

      # Use cached mappings if available
      mappings <- current_mappings()
      if (is.null(mappings) || nrow(mappings) == 0) return()

      # Get the selected concept's OMOP ID
      if (selected_row <= nrow(mappings)) {
        selected_omop_id <- mappings$omop_concept_id[selected_row]
        selected_mapped_concept_id(selected_omop_id)
      }
    })

    ##### Add Mapping to Selected Concept ----

    # Observer to handle modal opening and force DataTable render
    # No need for modal_opened observer - datatable renders when modal first opens

    # Load all OMOP concepts for modal search
    modal_concepts_all <- reactive({
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) return(NULL)

      # Get ALL OMOP concepts from allowed vocabularies
      vocab_data$concept %>%
        dplyr::filter(
          vocabulary_id %in% c("RxNorm", "RxNorm Extension", "LOINC", "SNOMED", "ICD10"),
          is.na(invalid_reason)
        ) %>%
        dplyr::select(
          concept_id,
          concept_name,
          vocabulary_id,
          domain_id,
          concept_class_id,
          concept_code,
          standard_concept
        ) %>%
        dplyr::arrange(concept_name) %>%
        dplyr::collect()
    })

    # Debounce the OMOP table selection to avoid excessive updates when navigating with arrow keys
    debounced_omop_selection <- debounce(
      reactive({
        input$mapped_concepts_add_omop_table_rows_selected
      }),
      300  # Wait 300ms after user stops navigating
    )

    # Show/hide details section based on multiple selection checkbox
    observe_event(input$mapped_concepts_add_multiple_select, {
      if (isTRUE(input$mapped_concepts_add_multiple_select)) {
        shinyjs::hide("omop_details_section")
      } else {
        shinyjs::show("omop_details_section")
      }
    }, ignoreInit = FALSE)

    # Track row selection in OMOP concepts table with debounce
    observe_event(debounced_omop_selection(), {
      selected_rows <- debounced_omop_selection()
      is_multiple <- isTRUE(input$mapped_concepts_add_multiple_select)

      # Only show details in single selection mode
      if (!is_multiple && length(selected_rows) == 1) {
        all_concepts <- modal_concepts_all()
        if (is.null(all_concepts)) return()

        # Get selected concept
        selected_concept <- all_concepts[selected_rows[1], ]
        add_modal_selected_concept(selected_concept)
      } else {
        add_modal_selected_concept(NULL)
      }
    })

    # Render OMOP concepts table in add modal
    observe_event(list(add_modal_selected_concept(), add_modal_concept_details_trigger()), {
      concept <- add_modal_selected_concept()

      # Render concept details
      output$mapped_concepts_add_concept_details <- renderUI({
        if (is.null(concept) || nrow(concept) == 0) {
          return(tags$div(
            style = "padding: 20px; background: #f8f9fa; border-radius: 6px; text-align: center;",
            tags$p(
              style = "color: #666; font-style: italic;",
              i18n$t("select_concept_table_details")
            )
          ))
        }

        # Check if concept is already mapped to current general concept
        concept_id <- selected_concept_id()
        is_already_added <- FALSE
        if (!is.null(concept_id)) {
          # Check in saved mappings
          existing_mappings <- current_data()$concept_mappings
          if (!is.null(existing_mappings)) {
            is_already_added <- any(
              existing_mappings$general_concept_id == concept_id &
              existing_mappings$omop_concept_id == concept$concept_id
            )
          }

          # Also check in pending mappings (edit mode - concepts added but not saved yet)
          if (!is_already_added) {
            pending_adds <- added_concepts()
            if (!is.null(pending_adds) && length(pending_adds) > 0) {
              # Create key for current concept
              key <- paste(concept_id, concept$concept_id, sep = "_")
              is_already_added <- key %in% names(pending_adds)
            }
          }
        }

        # Use grid layout like Selected Concept Details
        tags$div(
          tags$div(
            class = "concept-details-container",
            style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(4, auto); grid-auto-flow: column; gap: 4px 15px;",
            # Column 1
            create_detail_item(i18n$t("concept_name"), concept$concept_name, include_colon = FALSE),
            create_detail_item(i18n$t("vocabulary_id"), concept$vocabulary_id, include_colon = FALSE),
            create_detail_item(i18n$t("domain_id"), concept$domain_id, include_colon = FALSE),
            create_detail_item(i18n$t("concept_class"), concept$concept_class_id, include_colon = FALSE),
            # Column 2
            create_detail_item(i18n$t("omop_concept_id"), concept$concept_id, include_colon = FALSE),
            create_detail_item(i18n$t("concept_code"), concept$concept_code, include_colon = FALSE),
            create_detail_item(i18n$t("standard"), if (!is.na(concept$standard_concept)) concept$standard_concept else "No", include_colon = FALSE),
            tags$div()  # Empty slot to balance grid
          ),
          if (is_already_added) {
            tags$div(
              style = "margin-top: 15px; padding: 8px 12px; background: #28a745; color: white; border-radius: 4px; text-align: center; font-weight: bold;",
              paste0("\u2713 ", i18n$t("already_added"))
            )
          }
        )
      })

      # Render descendants table
      output$mapped_concepts_add_descendants_table <- DT::renderDT({
        if (is.null(concept) || nrow(concept) == 0) {
          return(DT::datatable(
            data.frame(Message = as.character(i18n$t("select_concept_descendants"))),
            options = list(dom = 't'),
            rownames = FALSE,
            selection = 'none'
          ))
        }

        vocab_data <- vocabularies()
        if (is.null(vocab_data)) {
          return(DT::datatable(
            data.frame(Message = "Vocabularies not loaded."),
            options = list(dom = 't'),
            rownames = FALSE,
            selection = 'none'
          ))
        }

        # Get descendants
        descendants <- vocab_data$concept_ancestor %>%
          dplyr::filter(ancestor_concept_id == concept$concept_id) %>%
          dplyr::select(descendant_concept_id) %>%
          dplyr::collect()

        if (nrow(descendants) == 0) {
          return(DT::datatable(
            data.frame(Message = "No descendants found."),
            options = list(dom = 't'),
            rownames = FALSE,
            selection = 'none'
          ))
        }

        # Get concept details for descendants (exclude the concept itself)
        desc_concepts <- vocab_data$concept %>%
          dplyr::filter(
            concept_id %in% descendants$descendant_concept_id,
            concept_id != concept$concept_id,
            is.na(invalid_reason)
          ) %>%
          dplyr::select(concept_id, concept_name, vocabulary_id) %>%
          dplyr::collect()

        # Render DataTable with 8 rows per page
        DT::datatable(
          desc_concepts,
          rownames = FALSE,
          selection = 'none',
          options = list(
            pageLength = 8,
            dom = 'tp',
            ordering = TRUE,
            autoWidth = FALSE,
            language = get_datatable_language()
          ),
          colnames = c("Concept ID", "Name", "Vocabulary")
        )
      })
    })

    # Render OMOP concepts table for adding to mapping (server-side processing)
    observe_event(list(add_modal_omop_table_trigger(), input$mapped_concepts_add_multiple_select), {
      output$mapped_concepts_add_omop_table <- DT::renderDT({
        concepts <- modal_concepts_all()

        # Show loading message if vocabularies not loaded
        if (is.null(concepts)) {
          return(DT::datatable(
            data.frame(Message = "Loading OMOP vocabularies..."),
            options = list(dom = 't', ordering = FALSE),
            rownames = FALSE,
            selection = 'none'
          ))
        }

        # Show message if no concepts found
        if (nrow(concepts) == 0) {
          return(DT::datatable(
            data.frame(Message = "No OMOP concepts found in vocabularies."),
            options = list(dom = 't', ordering = FALSE),
            rownames = FALSE,
            selection = 'none'
          ))
        }

        # Select only display columns
        display_concepts <- concepts %>%
          dplyr::select(concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, standard_concept)

        # Convert for better filtering
        display_concepts$concept_id <- as.character(display_concepts$concept_id)
        display_concepts$vocabulary_id <- as.factor(display_concepts$vocabulary_id)
        display_concepts$domain_id <- as.factor(display_concepts$domain_id)
        display_concepts$concept_class_id <- as.factor(display_concepts$concept_class_id)

        # Convert standard_concept to readable labels with HTML styling
        display_concepts <- display_concepts %>%
          dplyr::mutate(
            standard_concept = dplyr::case_when(
              standard_concept == "S" ~ '<span class="badge-status badge-success">Standard</span>',
              standard_concept == "C" ~ '<span class="badge-status badge-secondary">Classification</span>',
              TRUE ~ '<span class="badge-status badge-danger">Non-standard</span>'
            )
          )

        # Check if multiple selection is enabled
        is_multiple <- isTRUE(input$mapped_concepts_add_multiple_select)
        selection_mode <- if (is_multiple) 'multiple' else 'single'
        page_length <- if (is_multiple) 20 else 5

        # Render DataTable with server-side processing
        DT::datatable(
          display_concepts,
          rownames = FALSE,
          selection = selection_mode,
          filter = 'top',
          escape = FALSE,
          options = list(
            pageLength = page_length,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100, 200, 500), c('5', '10', '15', '20', '50', '100', '200', '500')),
            dom = 'ltip',  # l=length, t=table, i=info, p=pagination
            language = get_datatable_language(),
            ordering = TRUE,
            autoWidth = FALSE,
            paging = TRUE,
            columnDefs = list(
              list(targets = 5, width = '100px', className = 'dt-center')  # Standard column (index 5)
            )
          ),
          colnames = c("Concept ID", "Concept Name", "Vocabulary", "Domain", "Concept Class", "Standard")
        )
      }, server = TRUE)
    }, ignoreInit = FALSE)

    # Add selected OMOP concept(s) with optional descendants
    observe_event(input$mapped_concepts_add_selected, {
      if (!general_concept_detail_edit_mode()) return()

      # Get selected row(s)
      selected_rows <- input$mapped_concepts_add_omop_table_rows_selected
      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      all_concepts <- modal_concepts_all()
      if (is.null(all_concepts)) return()

      # Get current general concept
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      # Collect all concepts to add from all selected rows
      concepts_to_add <- c()

      for (row_idx in selected_rows) {
        selected_concept <- all_concepts[row_idx, ]

        # Start with the selected concept
        concepts_to_add <- c(concepts_to_add, selected_concept$concept_id)

        # Add descendants if checkbox is checked
        if (isTRUE(input$mapped_concepts_add_include_descendants)) {
          vocab_data <- vocabularies()
          if (!is.null(vocab_data)) {
            descendants <- vocab_data$concept_ancestor %>%
              dplyr::filter(ancestor_concept_id == selected_concept$concept_id) %>%
              dplyr::select(descendant_concept_id) %>%
              dplyr::collect()

            if (nrow(descendants) > 0) {
              # Filter to keep only valid concepts
              valid_descendants <- vocab_data$concept %>%
                dplyr::filter(
                  concept_id %in% descendants$descendant_concept_id,
                  is.na(invalid_reason)
                ) %>%
                dplyr::pull(concept_id)

              concepts_to_add <- c(concepts_to_add, valid_descendants)
            }
          }
        }
      }

      # Track counts for notification
      total_concepts <- length(concepts_to_add)

      # Load current general_concepts_details
      concept_mappings_path <- get_csv_path("general_concepts_details.csv")
      if (file.exists(concept_mappings_path)) {
        concept_mappings <- readr::read_csv(concept_mappings_path, show_col_types = FALSE)
      } else {
        concept_mappings <- data.frame(
          general_concept_id = integer(),
          omop_concept_id = integer(),
          omop_unit_concept_id = character(),
          stringsAsFactors = FALSE
        )
      }

      # Create new mappings
      new_mappings <- data.frame(
        general_concept_id = rep(concept_id, length(concepts_to_add)),
        omop_concept_id = concepts_to_add,
        omop_unit_concept_id = "/",
        source = "manual",
        stringsAsFactors = FALSE
      )

      # Remove duplicates
      existing_keys <- concept_mappings %>%
        dplyr::mutate(key = paste(general_concept_id, omop_concept_id, sep = "_")) %>%
        dplyr::pull(key)

      new_mappings <- new_mappings %>%
        dplyr::mutate(key = paste(general_concept_id, omop_concept_id, sep = "_")) %>%
        dplyr::filter(!key %in% existing_keys) %>%
        dplyr::select(-key)

      # Calculate counts
      num_added <- nrow(new_mappings)
      num_already_present <- total_concepts - num_added

      if (nrow(new_mappings) > 0) {
        # Store new mappings temporarily (don't save to CSV yet)
        current_added <- added_concepts()
        if (is.null(current_added)) current_added <- list()

        # Add new mappings to the temporary list
        for (i in 1:nrow(new_mappings)) {
          key <- paste(new_mappings$general_concept_id[i], new_mappings$omop_concept_id[i], sep = "_")
          current_added[[key]] <- new_mappings[i, ]
        }
        added_concepts(current_added)

        # Update local data to show new concepts immediately in the table
        data_updated <- local_data()
        # Append to existing concept_mappings (which already includes previous additions)
        data_updated$concept_mappings <- dplyr::bind_rows(data_updated$concept_mappings, new_mappings)
        local_data(data_updated)

        # Trigger table re-render
        concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
      }

      # Show notification with results
      if (num_added > 0 && num_already_present > 0) {
        showNotification(
          sprintf("%d concept%s added | %d already present",
                  num_added,
                  if (num_added > 1) "s" else "",
                  num_already_present),
          type = "message",
          duration = 4
        )
      } else if (num_added > 0) {
        showNotification(
          sprintf("%d concept%s added",
                  num_added,
                  if (num_added > 1) "s" else ""),
          type = "message",
          duration = 3
        )
      } else if (num_already_present > 0) {
        showNotification(
          sprintf("All %d concept%s already present",
                  num_already_present,
                  if (num_already_present > 1) "s were" else " was"),
          type = "warning",
          duration = 3
        )
      }

      # Update concept details to show "Already Added" indicator if needed
      add_modal_concept_details_trigger(add_modal_concept_details_trigger() + 1)

      # Reset datatable selection
      proxy <- DT::dataTableProxy("mapped_concepts_add_omop_table", session = session)
      DT::selectRows(proxy, NULL)
    }, ignoreInit = TRUE)

    # Add custom concept
    observe_event(input$add_custom_concept, {
      if (!general_concept_detail_edit_mode()) return()

      # Validate required inputs
      is_valid <- validate_required_inputs(
        input,
        fields = list(
          custom_vocabulary_id = "custom_vocabulary_id_error",
          custom_concept_name = "custom_concept_name_error"
        )
      )
      if (!is_valid) return()

      # Get validated values
      vocabulary_id <- trimws(input$custom_vocabulary_id)
      concept_name <- trimws(input$custom_concept_name)

      # Get current general concept
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      # Create custom concept code
      concept_code <- trimws(input$custom_concept_code)
      if (concept_code == "" || concept_code == "/") {
        concept_code <- "/"
      }

      # Load or create custom_concepts
      custom_concepts_path <- get_csv_path("custom_concepts.csv")
      if (file.exists(custom_concepts_path)) {
        custom_concepts <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
      } else {
        custom_concepts <- data.frame(
          custom_concept_id = integer(),
          general_concept_id = integer(),
          vocabulary_id = character(),
          concept_code = character(),
          concept_name = character(),
          omop_unit_concept_id = character(),
          stringsAsFactors = FALSE
        )
      }

      # Generate new custom_concept_id
      if (nrow(custom_concepts) > 0 && "custom_concept_id" %in% names(custom_concepts)) {
        max_id <- max(custom_concepts$custom_concept_id, na.rm = TRUE)
        new_id <- if (is.finite(max_id)) max_id + 1 else 1
      } else {
        new_id <- 1
      }

      # Add new custom concept
      new_custom_concept <- data.frame(
        custom_concept_id = new_id,
        general_concept_id = concept_id,
        vocabulary_id = vocabulary_id,
        concept_code = concept_code,
        concept_name = concept_name,
        omop_unit_concept_id = "/",
        stringsAsFactors = FALSE
      )

      custom_concepts <- dplyr::bind_rows(custom_concepts, new_custom_concept)

      # Save custom_concepts
      readr::write_csv(custom_concepts, custom_concepts_path)

      # Log history
      user <- current_user()
      if (!is.null(user) && !is.null(user$first_name) && !is.null(user$last_name)) {
        username <- paste(user$first_name, user$last_name)
        log_history_change(
          entity_type = "mapped_concept",
          username = username,
          action_type = "insert",
          general_concept_id = concept_id,
          vocabulary_id = as.character(new_custom_concept$vocabulary_id[1]),
          concept_code = as.character(new_custom_concept$concept_code[1]),
          concept_name = as.character(new_custom_concept$concept_name[1]),
          comment = "Added custom concept mapping"
        )
      }

      # Update local data
      data_updated <- local_data()
      data_updated$custom_concepts <- custom_concepts
      local_data(data_updated)

      # Trigger re-render
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)

      # Close modal and reset form
      shinyjs::hide("mapped_concepts_add_modal")
      updateTextInput(session, "custom_vocabulary_id", value = "")
      updateTextInput(session, "custom_concept_code", value = "")
      updateTextInput(session, "custom_concept_name", value = "")
      shinyjs::hide("custom_vocabulary_id_error")
      shinyjs::hide("custom_concept_name_error")
    }, ignoreInit = TRUE)
    
    ### b) Selected Mapping Details (Top-Right Panel) ----
    ##### Selected Mapping Display ----
    # Render selected mapping details when selected_mapping_details trigger fires (cascade observer)
    observe_event(selected_mapping_details_trigger(), {
      omop_concept_id <- selected_mapped_concept_id()
      concept_id <- selected_concept_id()

      output$selected_mapping_details <- renderUI({
        if (is.null(omop_concept_id)) {
          return(tags$div(
            style = "padding: 20px; background: #f8f9fa; border-radius: 6px; text-align: center;",
            tags$p(
              style = "color: #666; font-style: italic;",
              "Select a concept from the Mapped Concepts table to view its details."
            )
          ))
        }

        if (is.null(concept_id)) return()

      concept_mapping <- current_data()$concept_mappings %>%
        dplyr::filter(
          general_concept_id == concept_id,
          omop_concept_id == !!omop_concept_id
        )

      general_concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_mapping) == 0) {
        # If not in concept_mappings, get from OHDSI vocabularies
        vocab_data <- vocabularies()
        if (is.null(vocab_data)) {
          return(tags$div(
            style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic;",
            "Concept details not available."
          ))
        }

        concept_details <- vocab_data$concept %>%
          dplyr::filter(concept_id == omop_concept_id) %>%
          dplyr::collect()

        if (nrow(concept_details) == 0) {
          return(tags$div(
            style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic;",
            "Concept details not found."
          ))
        }

        info <- concept_details[1, ]

        # Build URLs for OHDSI-only concepts
        athena_url <- paste0(config$athena_base_url, "/", info$concept_id)
        fhir_url <- build_fhir_url(info$vocabulary_id, info$concept_code, config)

        # Determine validity and standard
        is_valid <- is.na(info$invalid_reason) || info$invalid_reason == ""
        validity_color <- if (is_valid) "#28a745" else "#dc3545"
        validity_text <- if (is_valid) {
          "Valid"
        } else {
          paste0("Invalid (", info$invalid_reason, ")")
        }

        is_standard <- !is.na(info$standard_concept) && info$standard_concept == "S"
        standard_color <- if (is_standard) "#28a745" else "#dc3545"
        standard_text <- if (is_standard) "Standard" else "Non-standard"

        # Display full info for OHDSI-only concepts (with "/" for missing EHDEN/LOINC data)
        return(tags$div(
          class = "concept-details-container",
          style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(8, auto); grid-auto-flow: column; gap: 4px 15px;",
          # Column 1
          create_detail_item(i18n$t("concept_name"), info$concept_name, include_colon = FALSE),
          create_detail_item(i18n$t("category"),
                            ifelse(nrow(general_concept_info) > 0,
                                  general_concept_info$category[1], NA),
                            include_colon = FALSE),
          create_detail_item(i18n$t("subcategory"),
                            ifelse(nrow(general_concept_info) > 0,
                                  general_concept_info$subcategory[1], NA),
                            include_colon = FALSE),
          create_detail_item(i18n$t("ehden_data_sources"), "/", include_colon = FALSE),
          create_detail_item(i18n$t("ehden_rows_count"), "/", include_colon = FALSE),
          create_detail_item(i18n$t("loinc_rank"), "/", include_colon = FALSE),
          create_detail_item(i18n$t("validity"), validity_text, color = validity_color, include_colon = FALSE),
          create_detail_item(i18n$t("standard"), standard_text, color = standard_color, include_colon = FALSE),
          # Column 2 (must have exactly 8 items)
          create_detail_item(i18n$t("vocabulary_id"), info$vocabulary_id, include_colon = FALSE),
          create_detail_item(i18n$t("domain_id"), if (!is.na(info$domain_id)) info$domain_id else "/", include_colon = FALSE),
          create_detail_item(i18n$t("concept_code"), info$concept_code, include_colon = FALSE),
          create_detail_item(i18n$t("omop_concept_id"), info$concept_id, url = athena_url, include_colon = FALSE),
          if (!is.null(fhir_url)) {
            if (fhir_url == "no_link") {
              tags$div(
                class = "detail-item",
                tags$strong(i18n$t("fhir_resource")),
                tags$span(
                  style = "color: #999; font-style: italic;",
                  "No link available"
                )
              )
            } else {
              tags$div(
                class = "detail-item",
                tags$strong(i18n$t("fhir_resource")),
                tags$a(
                  href = fhir_url,
                  target = "_blank",
                  style = "color: #0f60af; text-decoration: underline;",
                  "View"
                )
              )
            }
          } else {
            tags$div(class = "detail-item", style = "visibility: hidden;")
          },
          create_detail_item(i18n$t("unit_concept_name"), "/", include_colon = FALSE),
          create_detail_item(i18n$t("omop_unit_concept_id"), "/", include_colon = FALSE),
          tags$div(class = "detail-item", style = "visibility: hidden;"),
          tags$div(class = "detail-item", style = "visibility: hidden;")
        ))
      }

      # Display full details from concept_mappings
      info <- concept_mapping[1, ]

      # Get concept details from OHDSI vocabularies (for concept_name, vocabulary_id, concept_code)
      vocab_data <- vocabularies()
      validity_info <- NULL
      if (!is.null(vocab_data)) {
        validity_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == omop_concept_id) %>%
          dplyr::collect()
        if (nrow(validity_info) > 0) {
          validity_info <- validity_info[1, ]
          # Enrich info with OMOP data
          info$concept_name <- validity_info$concept_name
          info$vocabulary_id <- validity_info$vocabulary_id
          info$concept_code <- validity_info$concept_code
        } else {
          validity_info <- NULL
        }
      }

      # Get statistics from concept_statistics
      concept_stats_data <- current_data()$concept_statistics
      if (!is.null(concept_stats_data)) {
        concept_stats <- concept_stats_data %>%
          dplyr::filter(omop_concept_id == !!omop_concept_id)
      } else {
        concept_stats <- data.frame()
      }

      if (nrow(concept_stats) > 0) {
        info$ehden_num_data_sources <- concept_stats$ehden_num_data_sources[1]
        info$ehden_rows_count <- concept_stats$ehden_rows_count[1]
        info$loinc_rank <- concept_stats$loinc_rank[1]
      } else {
        info$ehden_num_data_sources <- NA
        info$ehden_rows_count <- NA
        info$loinc_rank <- NA
      }

      # Build URLs
      athena_url <- paste0(config$athena_base_url, "/", info$omop_concept_id)
      fhir_url <- if (!is.null(info$vocabulary_id) && !is.null(info$concept_code)) {
        build_fhir_url(info$vocabulary_id, info$concept_code, config)
      } else {
        NULL
      }
      athena_unit_url <- if (!is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "" && info$omop_unit_concept_id != "/") {
        paste0(config$athena_base_url, "/", info$omop_unit_concept_id)
      } else {
        NULL
      }

      # Get unit concept name and code from OMOP if unit concept ID exists
      unit_concept_name <- NULL
      unit_concept_code <- NULL
      if (!is.null(vocab_data) && !is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "" && info$omop_unit_concept_id != "/") {
        unit_concept_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == as.integer(info$omop_unit_concept_id)) %>%
          dplyr::collect()
        if (nrow(unit_concept_info) > 0) {
          unit_concept_name <- unit_concept_info$concept_name[1]
          unit_concept_code <- unit_concept_info$concept_code[1]
        }
      }

      unit_fhir_url <- if (!is.null(unit_concept_code)) {
        build_unit_fhir_url(unit_concept_code, config)
      } else {
        NULL
      }

      # Get edit mode status
      is_editing <- general_concept_detail_edit_mode()

      # Determine validity and standard from vocab_data
      is_valid <- if (!is.null(validity_info)) {
        is.na(validity_info$invalid_reason) || validity_info$invalid_reason == ""
      } else {
        NA
      }
      validity_color <- if (!is.na(is_valid)) {
        if (is_valid) "#28a745" else "#dc3545"
      } else {
        NULL
      }
      validity_text <- if (!is.na(is_valid)) {
        if (is_valid) {
          "Valid"
        } else {
          if (!is.null(validity_info) && !is.na(validity_info$invalid_reason)) {
            paste0("Invalid (", validity_info$invalid_reason, ")")
          } else {
            "Invalid"
          }
        }
      } else {
        "/"
      }

      is_standard <- if (!is.null(validity_info)) {
        !is.na(validity_info$standard_concept) && validity_info$standard_concept == "S"
      } else {
        NA
      }
      standard_color <- if (!is.na(is_standard)) {
        if (is_standard) "#28a745" else "#dc3545"
      } else {
        NULL
      }
      standard_text <- if (!is.na(is_standard)) {
        if (is_standard) "Standard" else "Non-standard"
      } else {
        "/"
      }

      tags$div(
        class = "concept-details-container",
        style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(8, auto); grid-auto-flow: column; gap: 4px 15px;",
        # Column 1
        create_detail_item(i18n$t("concept_name"), info$concept_name, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("category"),
                          ifelse(nrow(general_concept_info) > 0,
                                general_concept_info$category[1], NA),
                          include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("subcategory"),
                          ifelse(nrow(general_concept_info) > 0,
                                general_concept_info$subcategory[1], NA),
                          include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("ehden_data_sources"), info$ehden_num_data_sources, format_number = TRUE, editable = TRUE, input_id = "ehden_num_data_sources_input", step = 1, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("ehden_rows_count"), info$ehden_rows_count, format_number = TRUE, editable = TRUE, input_id = "ehden_rows_count_input", step = 1000, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("loinc_rank"), info$loinc_rank, editable = TRUE, input_id = "loinc_rank_input", step = 1, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("validity"), validity_text, color = validity_color, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("standard"), standard_text, color = standard_color, include_colon = FALSE, is_editing = is_editing, ns = ns),
        # Column 2 (must have exactly 8 items)
        create_detail_item(i18n$t("vocabulary_id"), info$vocabulary_id, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("domain_id"), if (!is.null(validity_info) && !is.na(validity_info$domain_id)) validity_info$domain_id else "/", include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("concept_code"), info$concept_code, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item(i18n$t("omop_concept_id"), info$omop_concept_id, url = athena_url, include_colon = FALSE, is_editing = is_editing, ns = ns),
        if (!is.null(fhir_url)) {
          if (fhir_url == "no_link") {
            tags$div(
              class = "detail-item",
              tags$strong(i18n$t("fhir_resource")),
              tags$span(
                style = "color: #999; font-style: italic;",
                "No link available"
              )
            )
          } else {
            tags$div(
              class = "detail-item",
              tags$strong(i18n$t("fhir_resource")),
              tags$a(
                href = fhir_url,
                target = "_blank",
                style = "color: #0f60af; text-decoration: underline;",
                "View"
              )
            )
          }
        } else {
          tags$div(class = "detail-item", style = "visibility: hidden;")
        },
        create_detail_item(i18n$t("unit_concept_name"),
                          if (!is.null(unit_concept_name) && unit_concept_name != "") {
                            unit_concept_name
                          } else {
                            "/"
                          },
                          include_colon = FALSE),
        create_detail_item(i18n$t("omop_unit_concept_id"),
                          if (!is.null(info$omop_unit_concept_id) && !is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "" && info$omop_unit_concept_id != "/") {
                            as.integer(info$omop_unit_concept_id)
                          } else {
                            NA
                          },
                          editable = TRUE, input_id = "omop_unit_concept_id_input", step = 1,
                          url = athena_unit_url, include_colon = FALSE, is_editing = is_editing, ns = ns),
        if (!is.null(unit_fhir_url)) {
          tags$div(
            class = "detail-item",
            tags$strong("Unit FHIR Resource"),
            tags$a(
              href = unit_fhir_url,
              target = "_blank",
              style = "color: #0f60af; text-decoration: underline;",
              "View"
            )
          )
        } else {
          tags$div(class = "detail-item", style = "visibility: hidden;")
        }
        )
      })
    }, ignoreInit = TRUE)

    # Update inputs with temporary values when switching between mappings
    # This runs after the UI is rendered, to restore any previously edited values
    observe_event(selected_mapped_concept_id(), {
      mapped_id <- selected_mapped_concept_id()
      if (is.null(mapped_id)) return()
      if (!general_concept_detail_edit_mode()) return()

      # Check for temporary edits to this mapping
      temp_edits <- edited_mapping_details()
      key <- as.character(mapped_id)
      if (!is.null(temp_edits[[key]])) {
        edits <- temp_edits[[key]]
        # Use delay to ensure inputs exist before updating
        shinyjs::delay(100, {
          if (!is.null(edits$omop_unit_concept_id)) {
            updateNumericInput(session, "omop_unit_concept_id_input", value = edits$omop_unit_concept_id)
          }
          if (!is.null(edits$loinc_rank)) {
            updateNumericInput(session, "loinc_rank_input", value = edits$loinc_rank)
          }
          if (!is.null(edits$ehden_rows_count)) {
            updateNumericInput(session, "ehden_rows_count_input", value = edits$ehden_rows_count)
          }
          if (!is.null(edits$ehden_num_data_sources)) {
            updateNumericInput(session, "ehden_num_data_sources_input", value = edits$ehden_num_data_sources)
          }
        })
      }
    }, ignoreInit = TRUE)

    # Capture edits to mapping detail fields and store temporarily
    # These observers store changes in edited_mapping_details() keyed by omop_concept_id
    observe_event(input$omop_unit_concept_id_input, {
      if (!general_concept_detail_edit_mode()) return()
      mapped_id <- selected_mapped_concept_id()
      if (is.null(mapped_id)) return()

      current_edits <- edited_mapping_details()
      key <- as.character(mapped_id)
      if (is.null(current_edits[[key]])) current_edits[[key]] <- list()
      current_edits[[key]]$omop_unit_concept_id <- input$omop_unit_concept_id_input
      edited_mapping_details(current_edits)
    }, ignoreInit = TRUE)

    observe_event(input$loinc_rank_input, {
      if (!general_concept_detail_edit_mode()) return()
      mapped_id <- selected_mapped_concept_id()
      if (is.null(mapped_id)) return()

      current_edits <- edited_mapping_details()
      key <- as.character(mapped_id)
      if (is.null(current_edits[[key]])) current_edits[[key]] <- list()
      current_edits[[key]]$loinc_rank <- input$loinc_rank_input
      edited_mapping_details(current_edits)
    }, ignoreInit = TRUE)

    observe_event(input$ehden_rows_count_input, {
      if (!general_concept_detail_edit_mode()) return()
      mapped_id <- selected_mapped_concept_id()
      if (is.null(mapped_id)) return()

      current_edits <- edited_mapping_details()
      key <- as.character(mapped_id)
      if (is.null(current_edits[[key]])) current_edits[[key]] <- list()
      current_edits[[key]]$ehden_rows_count <- input$ehden_rows_count_input
      edited_mapping_details(current_edits)
    }, ignoreInit = TRUE)

    observe_event(input$ehden_num_data_sources_input, {
      if (!general_concept_detail_edit_mode()) return()
      mapped_id <- selected_mapped_concept_id()
      if (is.null(mapped_id)) return()

      current_edits <- edited_mapping_details()
      key <- as.character(mapped_id)
      if (is.null(current_edits[[key]])) current_edits[[key]] <- list()
      current_edits[[key]]$ehden_num_data_sources <- input$ehden_num_data_sources_input
      edited_mapping_details(current_edits)
    }, ignoreInit = TRUE)

    # Handle copy concept JSON button
    observe_event(input$copy_concept_json, {
      omop_concept_id <- selected_mapped_concept_id()
      concept_id <- selected_concept_id()

      if (is.null(omop_concept_id) || is.null(concept_id)) return()

      # Get concept mapping
      concept_mapping <- current_data()$concept_mappings %>%
        dplyr::filter(
          general_concept_id == concept_id,
          omop_concept_id == !!omop_concept_id
        )

      # Get general concept info
      general_concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      # Get concept details from vocabularies
      vocab_data <- vocabularies()
      concept_details <- NULL
      if (!is.null(vocab_data)) {
        concept_details <- vocab_data$concept %>%
          dplyr::filter(concept_id == omop_concept_id) %>%
          dplyr::collect()
        if (nrow(concept_details) > 0) {
          concept_details <- concept_details[1, ]
        } else {
          concept_details <- NULL
        }
      }

      # Get statistics
      concept_stats_data <- current_data()$concept_statistics
      concept_stats <- NULL
      if (!is.null(concept_stats_data)) {
        concept_stats <- concept_stats_data %>%
          dplyr::filter(omop_concept_id == !!omop_concept_id)
        if (nrow(concept_stats) > 0) {
          concept_stats <- concept_stats[1, ]
        } else {
          concept_stats <- NULL
        }
      }

      # Build JSON object using helper function
      json_data <- build_concept_details_json(
        concept_mapping = if (nrow(concept_mapping) > 0) concept_mapping else NULL,
        general_concept_info = general_concept_info,
        concept_details = concept_details,
        concept_stats = concept_stats
      )

      if (length(json_data) == 0) return()

      # Convert to JSON
      json_string <- jsonlite::toJSON(json_data, pretty = TRUE, auto_unbox = TRUE, na = "null")

      # Copy to clipboard using JavaScript
      session$sendCustomMessage("copyToClipboard", list(
        text = as.character(json_string),
        buttonId = session$ns("copy_concept_json")
      ))
    })

    # Handle copy general concept with all mappings JSON button
    observe_event(input$copy_general_concept_json, {
      concept_id <- selected_concept_id()

      if (is.null(concept_id)) return()

      # Get general concept info
      general_concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(general_concept_info) == 0) return()

      # Get all concept mappings for this general concept
      all_mappings <- current_data()$concept_mappings %>%
        dplyr::filter(general_concept_id == concept_id)

      # Get vocabularies and statistics
      vocab_data <- vocabularies()
      concept_stats_data <- current_data()$concept_statistics

      # Build array of mapped concepts
      mapped_concepts <- list()

      if (nrow(all_mappings) > 0) {
        for (i in 1:nrow(all_mappings)) {
          mapping <- all_mappings[i, ]

          # Get concept details from vocabularies
          concept_details <- NULL
          if (!is.null(vocab_data)) {
            concept_details <- vocab_data$concept %>%
              dplyr::filter(concept_id == mapping$omop_concept_id) %>%
              dplyr::collect()
            if (nrow(concept_details) > 0) {
              concept_details <- concept_details[1, ]
            } else {
              concept_details <- NULL
            }
          }

          # Get statistics
          concept_stats <- NULL
          if (!is.null(concept_stats_data)) {
            concept_stats <- concept_stats_data %>%
              dplyr::filter(omop_concept_id == mapping$omop_concept_id)
            if (nrow(concept_stats) > 0) {
              concept_stats <- concept_stats[1, ]
            } else {
              concept_stats <- NULL
            }
          }

          # Build JSON for this concept using helper function
          concept_json <- build_concept_details_json(
            concept_mapping = mapping,
            general_concept_info = general_concept_info,
            concept_details = concept_details,
            concept_stats = concept_stats
          )

          if (length(concept_json) > 0) {
            mapped_concepts[[length(mapped_concepts) + 1]] <- concept_json
          }
        }
      }

      # Build final JSON structure
      json_data <- list(
        general_concept_id = general_concept_info$general_concept_id[1],
        general_concept_name = general_concept_info$general_concept_name[1],
        category = general_concept_info$category[1],
        subcategory = general_concept_info$subcategory[1],
        mapped_concepts = mapped_concepts
      )

      # Convert to JSON
      json_string <- jsonlite::toJSON(json_data, pretty = TRUE, auto_unbox = TRUE, na = "null")

      # Copy to clipboard using JavaScript
      session$sendCustomMessage("copyToClipboard", list(
        text = as.character(json_string),
        buttonId = session$ns("copy_general_concept_json")
      ))
    })

    # Handle copy as JSON from dropdown menu
    observe_event(input$copy_as_json, {
      concept_id <- selected_concept_id()

      if (is.null(concept_id)) return()

      # Get general concept info
      general_concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(general_concept_info) == 0) return()

      # Get all concept mappings for this general concept
      all_mappings <- current_data()$concept_mappings %>%
        dplyr::filter(general_concept_id == concept_id)

      # Get vocabularies and statistics
      vocab_data <- vocabularies()
      concept_stats_data <- current_data()$concept_statistics

      # Build array of mapped concepts
      mapped_concepts <- list()

      if (nrow(all_mappings) > 0) {
        for (i in 1:nrow(all_mappings)) {
          mapping <- all_mappings[i, ]

          # Get concept details from vocabularies
          concept_details <- NULL
          if (!is.null(vocab_data)) {
            concept_details <- vocab_data$concept %>%
              dplyr::filter(concept_id == mapping$omop_concept_id) %>%
              dplyr::collect()
            if (nrow(concept_details) > 0) {
              concept_details <- concept_details[1, ]
            } else {
              concept_details <- NULL
            }
          }

          # Get statistics
          concept_stats <- NULL
          if (!is.null(concept_stats_data)) {
            concept_stats <- concept_stats_data %>%
              dplyr::filter(omop_concept_id == mapping$omop_concept_id)
            if (nrow(concept_stats) > 0) {
              concept_stats <- concept_stats[1, ]
            } else {
              concept_stats <- NULL
            }
          }

          # Build JSON for this concept using helper function
          concept_json <- build_concept_details_json(
            concept_mapping = mapping,
            general_concept_info = general_concept_info,
            concept_details = concept_details,
            concept_stats = concept_stats
          )

          if (length(concept_json) > 0) {
            mapped_concepts[[length(mapped_concepts) + 1]] <- concept_json
          }
        }
      }

      # Build final JSON structure
      json_data <- list(
        general_concept_id = general_concept_info$general_concept_id[1],
        general_concept_name = general_concept_info$general_concept_name[1],
        category = general_concept_info$category[1],
        subcategory = general_concept_info$subcategory[1],
        mapped_concepts = mapped_concepts
      )

      # Convert to JSON
      json_string <- jsonlite::toJSON(json_data, pretty = TRUE, auto_unbox = TRUE, na = "null")

      # Copy to clipboard using JavaScript
      session$sendCustomMessage("copyToClipboard", list(
        text = as.character(json_string),
        buttonId = session$ns("copy_as_json")
      ))

      # Show success notification
      showNotification("Concept details copied as JSON", type = "message", duration = 2)
    })

    # Handle copy as OMOP SQL from dropdown menu
    observe_event(input$copy_as_omop_sql, {
      concept_id <- selected_concept_id()

      if (is.null(concept_id)) return()

      # Get general concept info
      general_concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(general_concept_info) == 0) return()

      # Get all concept mappings for this general concept
      all_mappings <- current_data()$concept_mappings %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(all_mappings) == 0) {
        showNotification("No mapped concepts found", type = "warning", duration = 3)
        return()
      }

      # Get vocabularies to retrieve domain_id
      vocab_data <- vocabularies()

      if (is.null(vocab_data)) {
        showNotification("OHDSI vocabularies not loaded", type = "error", duration = 3)
        return()
      }

      # Group concepts by domain_id with standard_concept status
      concepts_by_domain <- list()

      for (i in 1:nrow(all_mappings)) {
        omop_id <- all_mappings$omop_concept_id[i]

        # Get concept details to find domain_id and standard_concept
        concept_details <- vocab_data$concept %>%
          dplyr::filter(concept_id == omop_id) %>%
          dplyr::select(concept_id, concept_name, domain_id, standard_concept) %>%
          dplyr::collect()

        if (nrow(concept_details) > 0) {
          domain <- concept_details$domain_id[1]
          concept_name <- concept_details$concept_name[1]
          standard_concept <- concept_details$standard_concept[1]

          if (is.null(concepts_by_domain[[domain]])) {
            concepts_by_domain[[domain]] <- list()
          }

          concepts_by_domain[[domain]][[length(concepts_by_domain[[domain]]) + 1]] <- list(
            id = omop_id,
            name = concept_name,
            standard_concept = standard_concept
          )
        }
      }

      # Generate SQL queries for each domain
      sql_parts <- c()

      # Domain to table and column mapping (OMOP CDM v5.4)
      # Source: https://ohdsi.github.io/CommonDataModel/cdm54.html
      domain_mapping <- list(
        "Measurement" = list(
          table = "measurement",
          concept_column = "measurement_concept_id",
          columns = c("measurement_id", "person_id", "measurement_concept_id", "measurement_date",
                     "measurement_datetime", "measurement_time", "measurement_type_concept_id",
                     "operator_concept_id", "value_as_number", "value_as_concept_id", "unit_concept_id",
                     "range_low", "range_high", "provider_id", "visit_occurrence_id", "visit_detail_id",
                     "measurement_source_value", "measurement_source_concept_id", "unit_source_value",
                     "unit_source_concept_id", "value_source_value", "measurement_event_id", "meas_event_field_concept_id")
        ),
        "Procedure" = list(
          table = "procedure_occurrence",
          concept_column = "procedure_concept_id",
          columns = c("procedure_occurrence_id", "person_id", "procedure_concept_id", "procedure_date",
                     "procedure_datetime", "procedure_end_date", "procedure_end_datetime", "procedure_type_concept_id",
                     "modifier_concept_id", "quantity", "provider_id", "visit_occurrence_id", "visit_detail_id",
                     "procedure_source_value", "procedure_source_concept_id", "modifier_source_value")
        ),
        "Drug" = list(
          table = "drug_exposure",
          concept_column = "drug_concept_id",
          columns = c("drug_exposure_id", "person_id", "drug_concept_id", "drug_exposure_start_date",
                     "drug_exposure_start_datetime", "drug_exposure_end_date", "drug_exposure_end_datetime",
                     "verbatim_end_date", "drug_type_concept_id", "stop_reason", "refills", "quantity",
                     "days_supply", "sig", "route_concept_id", "lot_number", "provider_id", "visit_occurrence_id",
                     "visit_detail_id", "drug_source_value", "drug_source_concept_id", "route_source_value", "dose_unit_source_value")
        ),
        "Condition" = list(
          table = "condition_occurrence",
          concept_column = "condition_concept_id",
          columns = c("condition_occurrence_id", "person_id", "condition_concept_id", "condition_start_date",
                     "condition_start_datetime", "condition_end_date", "condition_end_datetime", "condition_type_concept_id",
                     "condition_status_concept_id", "stop_reason", "provider_id", "visit_occurrence_id", "visit_detail_id",
                     "condition_source_value", "condition_source_concept_id", "condition_status_source_value")
        ),
        "Observation" = list(
          table = "observation",
          concept_column = "observation_concept_id",
          columns = c("observation_id", "person_id", "observation_concept_id", "observation_date",
                     "observation_datetime", "observation_type_concept_id", "value_as_number", "value_as_string",
                     "value_as_concept_id", "qualifier_concept_id", "unit_concept_id", "provider_id",
                     "visit_occurrence_id", "visit_detail_id", "observation_source_value", "observation_source_concept_id",
                     "unit_source_value", "qualifier_source_value", "value_source_value", "observation_event_id", "obs_event_field_concept_id")
        ),
        "Device" = list(
          table = "device_exposure",
          concept_column = "device_concept_id",
          columns = c("device_exposure_id", "person_id", "device_concept_id", "device_exposure_start_date",
                     "device_exposure_start_datetime", "device_exposure_end_date", "device_exposure_end_datetime",
                     "device_type_concept_id", "unique_device_id", "production_id", "quantity", "provider_id",
                     "visit_occurrence_id", "visit_detail_id", "device_source_value", "device_source_concept_id",
                     "unit_concept_id", "unit_source_value", "unit_source_concept_id")
        ),
        "Specimen" = list(
          table = "specimen",
          concept_column = "specimen_concept_id",
          columns = c("specimen_id", "person_id", "specimen_concept_id", "specimen_type_concept_id",
                     "specimen_date", "specimen_datetime", "quantity", "unit_concept_id", "anatomic_site_concept_id",
                     "disease_status_concept_id", "specimen_source_id", "specimen_source_value", "unit_source_value",
                     "anatomic_site_source_value", "disease_status_source_value")
        )
      )

      for (domain in names(concepts_by_domain)) {
        if (!domain %in% names(domain_mapping)) next

        mapping <- domain_mapping[[domain]]
        concepts <- concepts_by_domain[[domain]]

        # Separate concepts by standard_concept status
        standard_concepts <- Filter(function(c) !is.na(c$standard_concept) && c$standard_concept == "S", concepts)
        classification_concepts <- Filter(function(c) !is.na(c$standard_concept) && c$standard_concept == "C", concepts)
        non_standard_concepts <- Filter(function(c) is.na(c$standard_concept) || !c$standard_concept %in% c("S", "C"), concepts)

        # Build concept lists with comments
        concept_list_parts <- c()

        if (length(standard_concepts) > 0) {
          standard_list <- sapply(standard_concepts, function(c) {
            sprintf("    %s, -- %s", c$id, c$name)
          })
          concept_list_parts <- c(concept_list_parts, "    -- Standard concepts", standard_list)
        }

        if (length(classification_concepts) > 0) {
          classification_list <- sapply(classification_concepts, function(c) {
            sprintf("    %s, -- %s", c$id, c$name)
          })
          if (length(standard_concepts) > 0) {
            concept_list_parts <- c(concept_list_parts, "")
          }
          concept_list_parts <- c(concept_list_parts, "    -- Classification concepts", classification_list)
        }

        if (length(non_standard_concepts) > 0) {
          non_standard_list <- sapply(non_standard_concepts, function(c) {
            sprintf("    %s, -- %s", c$id, c$name)
          })
          if (length(standard_concepts) > 0 || length(classification_concepts) > 0) {
            concept_list_parts <- c(concept_list_parts, "")
          }
          concept_list_parts <- c(concept_list_parts, "    -- Non-standard concepts", non_standard_list)
        }

        # Remove trailing comma from last concept
        if (length(concept_list_parts) > 0) {
          last_idx <- length(concept_list_parts)
          concept_list_parts[last_idx] <- sub(",$", "", concept_list_parts[last_idx])
        }

        # Build SELECT clause with all columns
        select_clause <- sprintf("SELECT\n    %s", paste(mapping$columns, collapse = ",\n    "))

        # Build query
        query <- sprintf(
          "%s\nFROM %s\nWHERE %s IN (\n%s\n)",
          select_clause,
          mapping$table,
          mapping$concept_column,
          paste(concept_list_parts, collapse = "\n")
        )

        sql_parts <- c(sql_parts, query)
      }

      # Combine with UNION
      if (length(sql_parts) == 0) {
        showNotification("No valid domains found for SQL generation", type = "warning", duration = 3)
        return()
      }

      final_sql <- paste(sql_parts, collapse = "\n\nUNION\n\n")

      # Add header comment with category
      concept_path <- paste(general_concept_info$category[1], general_concept_info$general_concept_name[1], sep = " > ")
      final_sql <- sprintf(
        "-- OMOP SQL Query for: %s\n-- Generated: %s\n-- OMOP CDM Version: 5.4\n-- Source: https://ohdsi.github.io/CommonDataModel/cdm54.html\n\n%s",
        concept_path,
        format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        final_sql
      )

      # Copy to clipboard using JavaScript
      session$sendCustomMessage("copyToClipboard", list(
        text = as.character(final_sql),
        buttonId = session$ns("copy_as_omop_sql")
      ))

      # Show success notification
      showNotification("OMOP SQL query copied to clipboard", type = "message", duration = 2)
    })

    ### c) ETL Guidance & Comments (Bottom-Left Panel) ----
    ##### Comments & Statistical Summary Display ----
    # Helper function to get comment for current concept
    # Each language has its own CSV file with a 'comments' column
    get_comment_for_language <- function(concept_info, lang) {
      if (nrow(concept_info) == 0) return("")

      # Use 'comments' column - each language file has its own comments
      if ("comments" %in% names(concept_info) && !is.na(concept_info$comments[1])) {
        concept_info$comments[1]
      } else {
        ""
      }
    }

    # Render comments or statistical summary based on active tab
    observe_event(comments_display_trigger(), {
      concept_id <- selected_concept_id()
      if (!is.null(concept_id)) {
        output$comments_display <- renderUI({
          is_editing <- general_concept_detail_edit_mode()
          active_tab <- comments_tab()
          lang <- current_language()

          concept_info <- current_data()$general_concepts %>%
            dplyr::filter(general_concept_id == concept_id)

          # Display based on active tab
          if (active_tab == "comments") {
            # Comments tab
            if (is_editing) {
              # Edit mode: show textarea with fullscreen button
              current_comment <- get_comment_for_language(concept_info, lang)

              tags$div(
                style = "height: 100%; position: relative;",
                tags$div(
                  style = "position: absolute; top: 0; left: 0; z-index: 100;",
                  actionButton(
                    session$ns("expand_comments_edit"),
                    label = NULL,
                    icon = icon("expand"),
                    class = "btn-icon-only comments-expand-btn",
                    style = "background: rgba(255, 255, 255, 0.95); border: 1px solid #ddd; color: #666; padding: 4px 7px; cursor: pointer; border-radius: 0 0 4px 0; font-size: 12px;",
                    `data-tooltip` = "Edit in fullscreen"
                  )
                ),
                shiny::textAreaInput(
                  ns("comments_input"),
                  label = NULL,
                  value = current_comment,
                  placeholder = "Enter ETL guidance and comments here...",
                  width = "100%",
                  height = "100%"
                ),
                tags$style(HTML(sprintf("
                  #%s {
                    padding-left: 30px !important;
                  }
                ", ns("comments_input"))))
              )
            } else {
              # View mode: show formatted comment using markdown
              current_comment <- get_comment_for_language(concept_info, lang)
              if (nchar(current_comment) > 0) {
                tags$div(
                  class = "comments-container",
                  style = "background: #ffffff; border: 1px solid #ccc; border-radius: 6px; height: 100%; overflow-y: auto; box-sizing: border-box; position: relative;",
                  tags$div(
                    style = "position: sticky; top: -1px; left: -1px; z-index: 100; height: 0;",
                    actionButton(
                      session$ns("expand_comments"),
                      label = NULL,
                      icon = icon("expand"),
                      class = "btn-icon-only comments-expand-btn",
                      style = "background: rgba(255, 255, 255, 0.95); border: none; border-right: 1px solid #ccc; border-bottom: 1px solid #ccc; color: #0f60af; padding: 4px 7px; cursor: pointer; border-radius: 5px 0 0 0; font-size: 12px;",
                      `data-tooltip` = "View in fullscreen"
                    )
                  ),
                  tags$div(
                    class = "markdown-content",
                    style = "padding-left: 30px;",
                    shiny::markdown(current_comment)
                  )
                )
              } else {
                tags$div(
                  style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic; height: 100%; overflow-y: auto; box-sizing: border-box;",
                  "No comments available for this concept."
                )
              }
            }
      } else {
            # Statistical Summary tab
            if (is_editing) {
              # Edit mode: show JSON editor with aceEditor
              stat_summary_edit <- if (nrow(concept_info) > 0) concept_info$statistical_summary[1] else NA
              current_summary <- if (!is.null(stat_summary_edit) && !is.na(stat_summary_edit) && nchar(stat_summary_edit) > 0) {
                stat_summary_edit
              } else {
                get_default_statistical_summary_template()
              }

              tags$div(
                style = "height: 100%; display: flex; flex-direction: column;",
                tags$div(
                  style = "padding: 10px; background: #f8f9fa; border-bottom: 1px solid #dee2e6; display: flex; justify-content: space-between; align-items: center;",
                  tags$span(
                    style = "font-weight: 600; color: #495057;",
                    "JSON Editor"
                  ),
                  actionButton(
                    ns("reset_statistical_summary"),
                    "Reset to Template",
                    class = "btn btn-sm",
                    style = "background: #6c757d; color: white; border: none; padding: 4px 12px; border-radius: 4px;"
                  )
                ),
                tags$div(
                  style = "flex: 1; min-height: 0;",
                  shinyAce::aceEditor(
                    ns("statistical_summary_editor"),
                    value = current_summary,
                    mode = "json",
                    theme = "chrome",
                    height = "100%",
                    fontSize = 11,
                    showLineNumbers = TRUE,
                    highlightActiveLine = TRUE,
                    tabSize = 2
                  )
                )
              )
            } else {
              # View mode: show statistical summary with tabs (Summary/Distribution) and profile selector
              raw_summary_data <- NULL
              json_error <- NULL
              stat_summary <- concept_info$statistical_summary[1]
              if (nrow(concept_info) > 0 && !is.null(stat_summary) && !is.na(stat_summary) && nchar(stat_summary) > 0) {
                tryCatch({
                  raw_summary_data <- jsonlite::fromJSON(concept_info$statistical_summary[1])
                }, error = function(e) {
                  json_error <<- e$message
                })
              }

              # Show error message if JSON parsing failed
              if (!is.null(json_error)) {
                tags$div(
                  style = "padding: 15px; background: #fff3cd; border: 1px solid #ffc107; border-radius: 6px; color: #856404;",
                  tags$strong("JSON Error: "),
                  tags$span(json_error),
                  tags$br(),
                  tags$span(style = "font-size: 12px; margin-top: 10px; display: block;",
                           "Switch to Edit Mode to fix the JSON.")
                )
              } else if (!is.null(raw_summary_data)) {
                # Get profile names and current selection
                profile_names <- get_profile_names(raw_summary_data)
                # Filter out NA values from profile names
                profile_names <- profile_names[!is.na(profile_names)]
                if (length(profile_names) == 0) {
                  profile_names <- c(if (Sys.getenv("INDICATE_LANGUAGE", "en") == "fr") "Tous les patients" else "All patients")
                }
                current_profile <- selected_profile()
                if (is.null(current_profile) || is.na(current_profile) || !(current_profile %in% profile_names)) {
                  current_profile <- get_default_profile_name(raw_summary_data)
                  if (is.null(current_profile) || is.na(current_profile)) {
                    current_profile <- profile_names[1]
                  }
                }

                # Get data for selected profile
                profile_data <- get_profile_data(raw_summary_data, current_profile)
                current_sub_tab <- statistical_summary_sub_tab()

                # Main UI with tabs and profile selector
                tags$div(
                  style = "height: 100%; display: flex; flex-direction: column;",
                  # Header with tabs on left and profile dropdown on right
                  tags$div(
                    style = "display: flex; justify-content: space-between; align-items: center; padding: 5px 0; border-bottom: 1px solid #dee2e6; margin-bottom: 10px;",
                    # Tabs (override position:absolute from .section-tabs CSS)
                    tags$div(
                      class = "section-tabs",
                      style = "position: static; transform: none; display: flex; gap: 5px;",
                      tags$button(
                        class = paste("tab-btn", if (current_sub_tab == "summary") "tab-btn-active" else ""),
                        onclick = sprintf("Shiny.setInputValue('%s', 'summary', {priority: 'event'})", ns("stat_summary_sub_tab_click")),
                        "Summary"
                      ),
                      tags$button(
                        class = paste("tab-btn", if (current_sub_tab == "distribution") "tab-btn-active" else ""),
                        onclick = sprintf("Shiny.setInputValue('%s', 'distribution', {priority: 'event'})", ns("stat_summary_sub_tab_click")),
                        "Distribution"
                      )
                    ),
                    # Profile dropdown (only show if multiple profiles)
                    if (length(profile_names) > 1) {
                      tags$div(
                        style = "display: flex; align-items: center; gap: 8px;",
                        tags$span(style = "font-size: 11px; color: #666;", paste0(i18n$t("profile"), " :")),
                        tags$select(
                          id = ns("stat_profile_select"),
                          style = "font-size: 11px; padding: 2px 6px; border: 1px solid #ccc; border-radius: 4px;",
                          onchange = sprintf("Shiny.setInputValue('%s', this.value, {priority: 'event'})", ns("stat_profile_change")),
                          lapply(profile_names, function(pn) {
                            is_selected <- !is.na(pn) && !is.na(current_profile) && pn == current_profile
                            tags$option(value = pn, selected = if (is_selected) "selected" else NULL, pn)
                          })
                        )
                      )
                    }
                  ),
                  # Tab content using shared render functions
                  tags$div(
                    style = "flex: 1; overflow-y: auto;",
                    if (current_sub_tab == "summary") {
                      render_stats_summary_panel(profile_data)
                    } else {
                      render_stats_distribution_panel(profile_data)
                    }
                  )
                )
              } else {
                tags$div(
                  style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic; height: 100%; overflow-y: auto; box-sizing: border-box;",
                  "No statistical summary available for this concept."
                )
              }
            }
          }
        })
      }
    }, ignoreInit = TRUE)
    
    # Handle reset statistical summary button
    observe_event(input$reset_statistical_summary, {
      shinyAce::updateAceEditor(
        session,
        "statistical_summary_editor",
        value = get_default_statistical_summary_template()
      )
    })

    # Handle statistical summary sub-tab change
    observe_event(input$stat_summary_sub_tab_click, {
      new_tab <- input$stat_summary_sub_tab_click
      if (!is.null(new_tab) && new_tab %in% c("summary", "distribution")) {
        statistical_summary_sub_tab(new_tab)
        # Trigger re-render
        comments_display_trigger(comments_display_trigger() + 1)
      }
    }, ignoreInit = TRUE)

    # Handle statistical summary profile change
    observe_event(input$stat_profile_change, {
      new_profile <- input$stat_profile_change
      if (!is.null(new_profile)) {
        selected_profile(new_profile)
        # Trigger re-render
        comments_display_trigger(comments_display_trigger() + 1)
      }
    }, ignoreInit = TRUE)

    # Handle expand comments button to show fullscreen modal
    observe_event(input$expand_comments, {
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      shinyjs::show("comments_fullscreen_modal")
    }, ignoreInit = TRUE)

    # Handle expand comments edit button (from small textfield) to show fullscreen modal
    observe_event(input$expand_comments_edit, {
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      shinyjs::show("comments_fullscreen_modal")
    }, ignoreInit = TRUE)

    # Render fullscreen comments content - split view if editing, markdown only if viewing
    observe_event(c(input$expand_comments, input$expand_comments_edit), {
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      output$comments_fullscreen_content <- renderUI({
        concept_info <- current_data()$general_concepts %>%
          dplyr::filter(general_concept_id == concept_id)

        lang <- current_language()

        # Use value from small textfield if available, otherwise use saved value
        current_comment <- if (!is.null(input$comments_input) && nchar(input$comments_input) > 0) {
          input$comments_input
        } else {
          get_comment_for_language(concept_info, lang)
        }

        # Check if we're in edit mode
        is_edit_mode <- general_concept_detail_edit_mode()

        if (is_edit_mode) {
          # Edit mode: show split view with text field on left, markdown preview on right
          tagList(
            tags$div(
              style = "height: 100%; display: flex; gap: 0;",

              # Left half: text editor
              tags$div(
                style = "flex: 1; padding: 10px; border-right: 1px solid #ddd; display: flex; flex-direction: column; overflow: hidden;",
                tags$h4(
                  style = "margin-top: 0; color: #0f60af; font-size: 16px; font-weight: 600; margin-bottom: 15px; flex-shrink: 0;",
                  "Edit Comment"
                ),
                tags$div(
                  style = "flex: 1; overflow: hidden;",
                  shiny::textAreaInput(
                    session$ns("fullscreen_comments_input"),
                    label = NULL,
                    value = current_comment,
                    placeholder = "Enter ETL guidance and comments here...",
                    width = "100%",
                    height = "100%"
                  )
                )
              ),

              # Right half: markdown preview
              tags$div(
                style = "flex: 1; padding: 10px; display: flex; flex-direction: column; overflow: hidden;",
                tags$h4(
                  style = "margin-top: 0; color: #0f60af; font-size: 16px; font-weight: 600; margin-bottom: 15px; flex-shrink: 0;",
                  "Preview"
                ),
                tags$div(
                  style = "flex: 1; overflow-y: auto;",
                  uiOutput(session$ns("fullscreen_markdown_preview"))
                )
              )
            )
          )
        } else {
          # View mode: show markdown only with same styling as preview
          tags$div(
            style = "height: 100%; padding: 10px; overflow-y: auto; background: #f8f9fa;",
            if (!is.null(current_comment) && nchar(current_comment) > 0) {
              tags$div(
                class = "markdown-content",
                style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.1); height: 100%; overflow-y: auto;",
                shiny::markdown(current_comment)
              )
            } else {
              tags$div(
                style = "background: white; padding: 20px; border-radius: 8px; color: #999; font-style: italic; text-align: center; height: 100%;",
                "No comments available for this concept."
              )
            }
          )
        }
      })
    }, ignoreInit = TRUE)

    # Render markdown preview - always update as user types
    observe_event(input$fullscreen_comments_input, {
      output$fullscreen_markdown_preview <- renderUI({
        text <- input$fullscreen_comments_input
        if (is.null(text) || nchar(text) == 0) {
          tags$div(
            style = "color: #999; font-style: italic; margin: 5px;",
            "Preview will appear here as you type..."
          )
        } else {
          tags$div(
            class = "markdown-content",
            style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.1); margin: 5px; height: 100%; overflow-y: auto;",
            shiny::markdown(text)
          )
        }
      })
    }, ignoreInit = FALSE)

    # Handle modal close - update small textfield with fullscreen value
    observe_event(input$close_fullscreen_modal, {
      # Update small textfield if in edit mode
      if (general_concept_detail_edit_mode() && !is.null(input$fullscreen_comments_input)) {
        updateTextAreaInput(session, "comments_input", value = input$fullscreen_comments_input)
      }

      # Close the modal
      shinyjs::hide("comments_fullscreen_modal")
    }, ignoreInit = TRUE)

    # Handle delete mapping in detail edit mode
    observe_event(input$delete_concept, {
      if (!general_concept_detail_edit_mode()) return()

      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      delete_data <- input$delete_concept
      # Create unique ID based on is_custom flag
      if (delete_data$is_custom) {
        concept_unique_id <- paste0("custom-", delete_data$custom_id)
      } else {
        concept_unique_id <- paste0("omop-", delete_data$omop_id)
      }

      # Track the deletion for this general_concept_id
      current_deletions <- deleted_concepts()
      concept_key <- as.character(concept_id)

      if (is.null(current_deletions[[concept_key]])) {
        current_deletions[[concept_key]] <- c(concept_unique_id)
      } else {
        current_deletions[[concept_key]] <- unique(c(current_deletions[[concept_key]], concept_unique_id))
      }

      deleted_concepts(current_deletions)
    }, ignoreInit = TRUE)

    ### d) Concept Relationships & Hierarchy (Bottom-Right Panel) ----
    ##### Tab Switching ----
    # Render concept relationships and update button styling when tab changes
    observe_event(relationships_tab(), {
      active_tab <- relationships_tab()

      # 1. Update tab button styling
      # Remove active class from all tabs
      shinyjs::removeCssClass(id = "tab_related", class = "tab-btn-active")
      shinyjs::removeCssClass(id = "tab_hierarchy", class = "tab-btn-active")
      shinyjs::removeCssClass(id = "tab_synonyms", class = "tab-btn-active")

      # Add active class to the current tab
      if (active_tab == "related") {
        shinyjs::addCssClass(id = "tab_related", class = "tab-btn-active")
      } else if (active_tab == "hierarchy") {
        shinyjs::addCssClass(id = "tab_hierarchy", class = "tab-btn-active")
      } else if (active_tab == "synonyms") {
        shinyjs::addCssClass(id = "tab_synonyms", class = "tab-btn-active")
      }

      # 2. Render content based on active tab
      output$concept_relationships_display <- renderUI({
        # Render DT output based on active tab
        if (active_tab == "related") {
          tags$div(
            uiOutput(ns("related_stats_widget")),
            DT::DTOutput(ns("related_concepts_table"))
          )
        } else if (active_tab == "hierarchy") {
          tags$div(
            uiOutput(ns("hierarchy_stats_widget")),
            DT::DTOutput(ns("hierarchy_concepts_table"))
          )
        } else if (active_tab == "synonyms") {
          DT::DTOutput(ns("synonyms_table"))
        }
      })
    })

    ##### Relationship Tab Outputs ----
    # Render all relationship tab outputs when relationship_tab_outputs trigger fires (cascade observer)
    observe_event(relationship_tab_outputs_trigger(), {
      omop_concept_id <- selected_mapped_concept_id()
      if (!is.null(omop_concept_id)) {
        # 1. Related concepts table
        output$related_concepts_table <- DT::renderDT({
          vocab_data <- vocabularies()
          if (is.null(vocab_data)) return()

      related_concepts <- get_related_concepts(omop_concept_id, vocab_data)

      # Remove the selected concept itself from the results
      if (nrow(related_concepts) > 0) {
        related_concepts <- related_concepts %>%
          dplyr::filter(omop_concept_id != !!omop_concept_id)
      }

      if (nrow(related_concepts) == 0) {
        return(create_empty_datatable(as.character(i18n$t("no_related_concepts"))))
      }

      # Reorder columns: relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id (hidden)
      related_concepts <- related_concepts %>%
        dplyr::select(relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id)

      DT::datatable(
        related_concepts,
        selection = 'none',
        rownames = FALSE,
        colnames = c(
          as.character(i18n$t("relationship")),
          as.character(i18n$t("concept_name")),
          as.character(i18n$t("vocabulary")),
          as.character(i18n$t("code")),
          "OMOP ID"
        ),
        options = list(
          pageLength = 6,
          dom = 'tip',
          language = get_datatable_language(),
          columnDefs = list(
            list(targets = 4, visible = FALSE),  # OMOP ID hidden
            list(targets = 0, width = "150px")   # Relationship column width
          ),
          initComplete = JS(sprintf("
            function(settings, json) {
              var table = this.api();

              // Add double-click handler for table rows
              $(table.table().node()).on('dblclick', 'tbody tr', function() {
                var rowData = table.row(this).data();
                if (rowData && rowData[4]) {
                  var conceptId = rowData[4];
                  Shiny.setInputValue('%s', conceptId, {priority: 'event'});
                  $('#%s').show();
                }
              });
            }
          ", ns("modal_concept_id"), ns("concept_modal")))
        )
      )
            }, server = FALSE)

        # 2. Related concepts statistics widget
        output$related_stats_widget <- renderUI({
          vocab_data <- vocabularies()
          if (is.null(vocab_data)) return()

      related_concepts <- get_related_concepts(omop_concept_id, vocab_data)

      # Remove the selected concept itself from the results
      if (nrow(related_concepts) > 0) {
        related_concepts <- related_concepts %>%
          dplyr::filter(omop_concept_id != !!omop_concept_id)
      }

      if (nrow(related_concepts) == 0) {
        return(NULL)
      }

      # Count relationship types
      rel_counts <- related_concepts %>%
        dplyr::count(relationship_id, sort = TRUE)

      # Get top 4 relationships
      top_4 <- rel_counts %>%
        dplyr::slice_head(n = 4)

      # Calculate "Other" count
      other_count <- if (nrow(rel_counts) > 4) {
        sum(rel_counts$n[5:nrow(rel_counts)])
      } else {
        0
      }

      # Build stat items
      stat_items <- lapply(1:nrow(top_4), function(i) {
        tags$div(
          style = "display: flex; align-items: center; gap: 8px;",
          tags$span(
            style = "font-weight: bold; color: #333;",
            top_4$n[i]
          ),
          tags$span(
            style = "color: #666; font-size: 13px;",
            top_4$relationship_id[i]
          )
        )
      })

      # Add "Other" if needed
      if (other_count > 0) {
        stat_items <- c(stat_items, list(
          tags$div(
            style = "display: flex; align-items: center; gap: 8px;",
            tags$span(
              style = "font-weight: bold; color: #333;",
              other_count
            ),
            tags$span(
              style = "color: #666; font-size: 13px;",
              "Other"
            )
          )
        ))
      }

      tags$div(
        class = "related-stats-widget",
        style = "padding: 10px; margin-bottom: 10px; background: #f8f9fa; border-radius: 6px;",
        tags$div(
          style = "display: flex; gap: 20px; flex-wrap: wrap;",
          stat_items
          )
        )
        })

        # 3. Hierarchy statistics widget
        output$hierarchy_stats_widget <- renderUI({
          vocab_data <- vocabularies()
          if (is.null(vocab_data)) return()

      # Get hierarchy graph data to extract stats
      hierarchy_data <- get_concept_hierarchy_graph(omop_concept_id, vocab_data)

      if (is.null(hierarchy_data$stats)) {
        return(NULL)
      }

      stats <- hierarchy_data$stats

      tags$div(
        class = "hierarchy-stats-widget",
        style = "padding: 10px; margin-bottom: 10px; background: #f8f9fa; border-radius: 6px; display: flex; justify-content: space-between; align-items: center;",
        tags$div(
          style = "display: flex; gap: 20px;",
          tags$div(
            style = "display: flex; align-items: center; gap: 8px;",
            tags$span(
              style = "font-size: 18px; color: #6c757d;",
              "⬆"
            ),
            tags$span(
              style = "font-weight: bold; color: #333;",
              stats$total_ancestors
            ),
            tags$span(
              style = "color: #666; font-size: 13px;",
              "ancestors"
            )
          ),
          tags$div(
            style = "display: flex; align-items: center; gap: 8px;",
            tags$span(
              style = "font-size: 18px; color: #28a745;",
              "⬇"
            ),
            tags$span(
              style = "font-weight: bold; color: #333;",
              stats$total_descendants
            ),
            tags$span(
              style = "color: #666; font-size: 13px;",
              tolower(i18n$t("descendants"))
            )
          )
        ),
        actionButton(
          ns("view_hierarchy_graph"),
          i18n$t("view_graph"),
          class = "btn-view-graph",
          style = "padding: 8px 16px; background: #0f60af; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: 500;"
          )
        )
        })

        # 4. Hierarchy concepts table
        output$hierarchy_concepts_table <- DT::renderDT({
          vocab_data <- vocabularies()
          if (is.null(vocab_data)) return(

          DT::datatable(
            data.frame(Message = "OHDSI Vocabularies not loaded."),
            options = list(dom = 't'),
            rownames = FALSE,
            selection = 'none'
          ))

          descendant_concepts <- get_descendant_concepts(omop_concept_id, vocab_data)

      # Remove the selected concept itself from the results
      if (nrow(descendant_concepts) > 0) {
        descendant_concepts <- descendant_concepts %>%
          dplyr::filter(omop_concept_id != !!omop_concept_id)
      }

      if (nrow(descendant_concepts) == 0) {
        return(create_empty_datatable(as.character(i18n$t("no_descendant_concepts"))))
      }

      # Reorder columns: relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id (hidden)
      descendant_concepts <- descendant_concepts %>%
        dplyr::select(relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id)

      DT::datatable(
        descendant_concepts,
        selection = 'none',
        rownames = FALSE,
        colnames = c(
          as.character(i18n$t("relationship")),
          as.character(i18n$t("concept_name")),
          as.character(i18n$t("vocabulary")),
          as.character(i18n$t("code")),
          "OMOP ID"
        ),
        options = list(
          pageLength = 6,
          dom = 'tip',
          language = get_datatable_language(),
          columnDefs = list(
            list(targets = 4, visible = FALSE),  # OMOP ID hidden
            list(targets = 0, width = "150px")   # Relationship column width
          ),
          initComplete = JS(sprintf("
            function(settings, json) {
              var table = this.api();
              $(table.table().node()).on('dblclick', 'tbody tr', function() {
                var rowData = table.row(this).data();
                if (rowData && rowData[4]) {
                  var conceptId = rowData[4];
                  Shiny.setInputValue('%s', conceptId, {priority: 'event'});
                  $('#%s').show();
                }
              });
            }
          ", ns("modal_concept_id"), ns("concept_modal")))
          )
        )
        }, server = FALSE)

        # 5. Synonyms table
        output$synonyms_table <- DT::renderDT({
          vocab_data <- vocabularies()
          if (is.null(vocab_data)) return()

          # Get synonyms
          synonyms <- get_concept_synonyms(omop_concept_id, vocab_data)

      if (nrow(synonyms) == 0) {
        return(create_empty_datatable(as.character(i18n$t("no_synonyms_found"))))
      }

      # Select only synonym and language columns (hide language_concept_id)
      synonyms <- synonyms %>%
        dplyr::select(synonym, language, language_concept_id)

      DT::datatable(
        synonyms,
        selection = 'none',
        rownames = FALSE,
        colnames = c(
          as.character(i18n$t("synonym")),
          as.character(i18n$t("language")),
          "Language ID"
        ),
        options = list(
          pageLength = 6,
          dom = 'tip',
          language = get_datatable_language(),
          columnDefs = list(
            list(targets = 2, visible = FALSE)  # Language ID hidden
          )
                )
        )
        }, server = FALSE)

        # 6. Hierarchy graph breadcrumb
        output$hierarchy_graph_breadcrumb <- renderUI({
          vocab_data <- vocabularies()
          if (is.null(vocab_data)) return()

      # Get concept details
      concept_info <- vocab_data$concept %>%
        dplyr::filter(concept_id == omop_concept_id) %>%
        dplyr::collect()

      if (nrow(concept_info) == 0) {
        return(NULL)
      }

      tags$div(
        style = "display: flex; align-items: center; gap: 10px;",
        tags$span(
          style = "font-weight: 600; color: #333; font-size: 16px;",
          i18n$t("concept_hierarchy")
        ),
        tags$span(
          style = "color: #0f60af; font-size: 16px; font-weight: 500;",
          concept_info$concept_name
        ),
        tags$span(
          style = "color: #999; font-size: 14px;",
          paste0("(", concept_info$vocabulary_id, " - ", concept_info$concept_code, ")")
          )
        )
        })

        # 7. Hierarchy graph
        output$hierarchy_graph <- visNetwork::renderVisNetwork({
          vocab_data <- vocabularies()
          if (is.null(vocab_data)) return()

      # Get hierarchy graph data
      hierarchy_data <- get_concept_hierarchy_graph(omop_concept_id, vocab_data,
                                                     max_levels_up = 5,
                                                     max_levels_down = 5)

      if (nrow(hierarchy_data$nodes) == 0) {
        return(NULL)
      }

      # Create visNetwork graph
      visNetwork::visNetwork(
        hierarchy_data$nodes,
        hierarchy_data$edges,
        height = "100%",
        width = "100%"
      ) %>%
        visNetwork::visHierarchicalLayout(
          direction = "UD",
          sortMethod = "directed",
          levelSeparation = 150,
          nodeSpacing = 200,
          treeSpacing = 250,
          blockShifting = TRUE,
          edgeMinimization = TRUE,
          parentCentralization = TRUE
        ) %>%
        visNetwork::visNodes(
          shadow = list(enabled = TRUE, size = 5),
          borderWidth = 2,
          margin = 10,
          widthConstraint = list(maximum = 250)
        ) %>%
        visNetwork::visEdges(
          smooth = list(type = "cubicBezier", roundness = 0.5),
          color = list(
            color = "#999",
            highlight = "#0f60af",
            hover = "#0f60af"
          )
        ) %>%
        visNetwork::visInteraction(
          navigationButtons = TRUE,
          hover = TRUE,
          zoomView = TRUE,
          dragView = TRUE,
          tooltipDelay = 100,
          hideEdgesOnDrag = FALSE,
          hideEdgesOnZoom = FALSE
        ) %>%
        visNetwork::visOptions(
          highlightNearest = list(
            enabled = TRUE,
            degree = 1,
            hover = TRUE,
            algorithm = "hierarchical"
          )
        ) %>%
          visNetwork::visPhysics(enabled = FALSE) %>%
          visNetwork::visLayout(randomSeed = 123)
        })
      }
    }, ignoreInit = TRUE)

    ##### Hierarchy Graph Fullscreen Modal ----
    # Observe view graph button click
    observe_event(input$view_hierarchy_graph, {
      omop_concept_id <- selected_mapped_concept_id()
      req(omop_concept_id)

      # Show modal
      shinyjs::show("hierarchy_graph_modal")
      
      # Re-render the graph for the modal with explicit dimensions
      output$hierarchy_graph_modal_content <- visNetwork::renderVisNetwork({
        vocab_data <- vocabularies()
        if (is.null(vocab_data)) return()
        
        # Get hierarchy graph data
        hierarchy_data <- get_concept_hierarchy_graph(omop_concept_id, vocab_data,
                                                      max_levels_up = 5,
                                                      max_levels_down = 5)
        
        if (nrow(hierarchy_data$nodes) == 0) {
          return(NULL)
        }
        
        # Create visNetwork graph with explicit dimensions for modal
        visNetwork::visNetwork(
          hierarchy_data$nodes,
          hierarchy_data$edges,
          height = "calc(100vh - 100px)",
          width = "100%"
        ) %>%
          visNetwork::visHierarchicalLayout(
            direction = "UD",
            sortMethod = "directed",
            levelSeparation = 150,
            nodeSpacing = 200,
            treeSpacing = 250,
            blockShifting = TRUE,
            edgeMinimization = TRUE,
            parentCentralization = TRUE
          ) %>%
          visNetwork::visNodes(
            shadow = list(enabled = TRUE, size = 5),
            borderWidth = 2,
            margin = 10,
            widthConstraint = list(maximum = 250)
          ) %>%
          visNetwork::visEdges(
            smooth = list(type = "cubicBezier", roundness = 0.5),
            color = list(
              color = "#999",
              highlight = "#0f60af",
              hover = "#0f60af"
            )
          ) %>%
          visNetwork::visInteraction(
            navigationButtons = TRUE,
            hover = TRUE,
            zoomView = TRUE,
            dragView = TRUE,
            tooltipDelay = 100,
            hideEdgesOnDrag = FALSE,
            hideEdgesOnZoom = FALSE
          ) %>%
          visNetwork::visOptions(
            highlightNearest = list(
              enabled = TRUE,
              degree = 1,
              hover = TRUE,
              algorithm = "hierarchical"
            )
          ) %>%
          visNetwork::visPhysics(enabled = FALSE) %>%
          visNetwork::visLayout(randomSeed = 123)
      })
      
      # Force Shiny to render this output even when hidden
      outputOptions(output, "hierarchy_graph_modal_content", suspendWhenHidden = FALSE)
      
      # Fit the graph after a short delay to allow modal to render
      shinyjs::delay(300, {
        visNetwork::visNetworkProxy(ns("hierarchy_graph_modal_content")) %>%
          visNetwork::visFit(animation = list(duration = 500))
      })
    })
    
    ##### Concept Details Modal (Double-click on Related/Hierarchy) ----
    # Render concept modal body when concept is selected
    observe_event(input$modal_concept_id, {
      concept_id <- input$modal_concept_id
      req(concept_id)
        output$concept_modal_body <- renderUI({
          vocab_data <- vocabularies()
          if (is.null(vocab_data)) {
            return(tags$div("Vocabulary data not available"))
          }

      # Get concept information from vocabularies
      concept_info <- vocab_data$concept %>%
        dplyr::filter(concept_id == !!concept_id) %>%
        dplyr::collect()

      if (nrow(concept_info) == 0) {
        return(tags$p("Concept not found.", style = "color: #666; font-style: italic;"))
      }

      info <- concept_info[1, ]

      # Build ATHENA URL
      athena_url <- build_athena_url(info$concept_id, config)

      # Build FHIR URL
      fhir_url <- build_fhir_url(info$vocabulary_id, info$concept_code, config)

      # Determine if concept is valid
      is_valid <- is.na(info$invalid_reason) || info$invalid_reason == ""
      validity_color <- if (is_valid) "#28a745" else "#dc3545"
      validity_text <- if (is_valid) "Valid" else paste0("Invalid (", info$invalid_reason, ")")

      # Determine if concept is standard
      is_standard <- !is.na(info$standard_concept) && info$standard_concept == "S"
      standard_color <- if (is_standard) "#28a745" else "#dc3545"
      standard_text <- if (is_standard) "Standard" else "Non-standard"

      tags$div(
        class = "concept-details-container",
        style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(6, auto); grid-auto-flow: column; gap: 4px 15px;",
        # Column 1
        create_detail_item(i18n$t("concept_name"), info$concept_name, include_colon = FALSE),
        create_detail_item(i18n$t("category"), info$domain_id, include_colon = FALSE),
        create_detail_item(i18n$t("subcategory"), info$concept_class_id, include_colon = FALSE),
        create_detail_item(i18n$t("validity"), validity_text, color = validity_color, include_colon = FALSE),
        create_detail_item(i18n$t("standard"), standard_text, color = standard_color, include_colon = FALSE),
        tags$div(class = "detail-item", style = "visibility: hidden;"),
        # Column 2
        create_detail_item(i18n$t("vocabulary_id"), info$vocabulary_id, include_colon = FALSE),
        create_detail_item(i18n$t("domain_id"), info$domain_id, include_colon = FALSE),
        create_detail_item(i18n$t("concept_code"), info$concept_code, include_colon = FALSE),
        create_detail_item(i18n$t("omop_concept_id"), info$concept_id, url = athena_url, include_colon = FALSE),
        if (!is.null(fhir_url)) {
          if (fhir_url == "no_link") {
            tags$div(
              class = "detail-item",
              tags$strong(i18n$t("fhir_resource")),
              tags$span(
                style = "color: #999; font-style: italic;",
                "No link available"
              )
            )
          } else {
            tags$div(
              class = "detail-item",
              tags$strong(i18n$t("fhir_resource")),
              tags$a(
                href = fhir_url,
                target = "_blank",
                style = "color: #0f60af; text-decoration: underline;",
                "View"
              )
            )
          }
        } else {
          tags$div(class = "detail-item", style = "visibility: hidden;")
        },
          tags$div(class = "detail-item", style = "visibility: hidden;")
        )
        })
    })
  })
}
