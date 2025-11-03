# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Dictionary Explorer interface with two main views:
# - General Concepts Page: Browse and manage general concepts
# - Mapped Concepts Page: View and edit concept mappings
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
#      ### List Edit Mode - Edit general concepts (recommended, comments, etc.)
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

# UI SECTION ====

#' Dictionary Explorer Module - UI
#'
#' @description UI function for the dictionary explorer module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS uiOutput
#' @importFrom htmltools tags tagList
mod_dictionary_explorer_ui <- function(id) {
  ns <- NS(id)

  tagList(
    ## UI - Main Layout ----
    ### Breadcrumb & Action Buttons Container ----
    div(class = "main-panel",
        div(class = "main-content",
            tags$div(
              style = "display: flex; justify-content: space-between; align-items: center; padding: 10px 0 15px 0;",
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
                    actionButton(ns("show_general_concepts_add_modal"), "Add concept", class = "btn-success-custom"),
                    actionButton(ns("general_concepts_show_history"), "History", class = "btn-secondary-custom"),
                    actionButton(ns("general_concepts_edit_page"), "Edit page", class = "btn-primary-custom")
                  )
                ),
                # General Concepts Page edit buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("general_concepts_edit_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("general_concepts_cancel_edit"), "Cancel", class = "btn-secondary-custom"),
                    actionButton(ns("general_concepts_save_updates"), "Save updates", class = "btn-success-custom")
                  )
                ),
                # General Concept Detail Page normal buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("general_concept_detail_action_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("general_concept_detail_show_history"), "History", class = "btn-secondary-custom"),
                    actionButton(ns("general_concept_detail_edit_page"), "Edit page", class = "btn-toggle")
                  )
                ),
                # General Concept Detail Page edit buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("general_concept_detail_edit_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("general_concept_detail_cancel_edit"), "Cancel", class = "btn-cancel"),
                    actionButton(ns("general_concept_detail_save_updates"), "Save updates", class = "btn-toggle")
                  )
                ),
                # Back buttons (history views)
                shinyjs::hidden(
                  tags$div(
                    id = ns("back_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("back_to_list_from_history"), "Back to List", class = "btn-primary-custom"),
                    actionButton(ns("back_to_detail"), "Back to Details", class = "btn-primary-custom")
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
                style = "height: calc(100vh - 175px); overflow: auto;",

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
                      "Loading OHDSI Vocabularies"
                    ),
                    tags$p(
                      style = "color: #0f60af; font-size: 16px; line-height: 1.5;",
                      "Please wait while the vocabularies database is being loaded..."
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
                        "OHDSI Vocabularies Not Loaded"
                      ),
                      tags$p(
                        style = "color: #721c24; font-size: 16px; margin-bottom: 20px; line-height: 1.5;",
                        "The OHDSI Vocabularies database is required to display concept mappings and terminology details. Please configure the vocabularies folder in settings."
                      ),
                      tags$button(
                        class = "btn btn-primary-custom",
                        onclick = "window.location.hash = '#!/general-settings';",
                        style = "font-size: 16px; padding: 12px 24px;",
                        tags$i(class = "fas fa-cog", style = "margin-right: 8px;"),
                        "Go to Settings"
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
                          tags$h4(
                            style = "margin-right: auto;",
                            "Mapped Concepts",
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = paste0(
                                "Concepts presented here are:\n",
                                "• Those selected by INDICATE, marked as 'Recommended'\n",
                                "• Child and same-level concepts, retrieved via ATHENA mappings\n"),
                              "ⓘ"
                            )
                          ),
                          # Dynamic buttons for edit mode
                          uiOutput(ns("mapped_concepts_header_buttons"))
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
                          tags$h4(
                            "Selected Concept Details",
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = "Detailed information about the selected concept from Mapped Concepts, including vocabulary, codes, links to ATHENA and FHIR resources",
                              "ⓘ"
                            )
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
                            "ETL Guidance & Comments",
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = "Expert guidance and comments for ETL (Extract, Transform, Load) processes related to this concept",
                              "ⓘ"
                            )
                          ),
                          tags$div(
                            class = "section-tabs",
                            tags$button(
                              class = "tab-btn tab-btn-active",
                              id = ns("tab_comments"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'comments', {priority: 'event'})", ns("switch_comments_tab")),
                              "Comments"
                            ),
                            tags$button(
                              class = "tab-btn",
                              id = ns("tab_statistical_summary"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'statistical_summary', {priority: 'event'})", ns("switch_comments_tab")),
                              "Statistical Summary"
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
                            "Concept Relationships & Hierarchy",
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = "All related concepts and hierarchical relationships from OHDSI vocabularies, including both standard and non-standard concepts. Double-click a row to see details.",
                              "ⓘ"
                            )
                          ),
                          tags$div(
                            class = "section-tabs",
                            tags$button(
                              class = "tab-btn tab-btn-active",
                              id = ns("tab_related"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'related', {priority: 'event'})", ns("switch_relationships_tab")),
                              "Related"
                            ),
                            tags$button(
                              class = "tab-btn",
                              id = ns("tab_hierarchy"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'hierarchy', {priority: 'event'})", ns("switch_relationships_tab")),
                              "Hierarchy"
                            ),
                            tags$button(
                              class = "tab-btn",
                              id = ns("tab_synonyms"),
                              onclick = sprintf("Shiny.setInputValue('%s', 'synonyms', {priority: 'event'})", ns("switch_relationships_tab")),
                              "Synonyms"
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
          tags$h3("Add New Concept"),
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
            id = ns("general_concepts_new_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              "General Concept Name",
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            shiny::textInput(
              ns("general_concepts_new_name"),
              label = NULL,
              placeholder = "Enter concept name",
              width = "100%"
            )
          ),
          tags$div(
            id = ns("general_concepts_new_category_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              "Category",
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
                    placeholder = "Select category..."
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
                  placeholder = "Enter new category",
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
            )
          ),
          tags$div(
            id = ns("general_concepts_new_subcategory_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              "Subcategory",
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
                    placeholder = "First select a category..."
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
                  placeholder = "Enter new subcategory",
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
            )
          ),
          tags$div(
            style = "display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; padding-top: 20px; border-top: 1px solid #dee2e6;",
            tags$button(
              class = "btn btn-secondary btn-secondary-custom",
              onclick = sprintf("$('#%s').hide();", ns("general_concepts_add_modal")),
              "Cancel"
            ),
            actionButton(
              ns("general_concepts_add_new"),
              "Add Concept",
              class = "btn-primary-custom"
            )
          )
        )
      )
    ),
    
    
    
    ### Modal - Add Mapping to General Concept ----
    tags$div(
      id = ns("mapped_concepts_add_modal"),
      style = "display: none; position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0, 0, 0, 0.5); z-index: 9999;",
      onclick = sprintf("if (event.target === this) { $('#%s').css('display', 'none'); }", ns("mapped_concepts_add_modal")),
      tags$div(
        style = "position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 95vw; height: 95vh; background: white; border-radius: 8px; display: flex; flex-direction: column;",
        onclick = "event.stopPropagation();",
        
        # Header
        tags$div(
          style = "padding: 20px; border-bottom: 1px solid #ddd; flex-shrink: 0; background: #f8f9fa;",
          tags$h3("Add Concept to Mapping", style = "margin: 0; display: inline-block;"),
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
                "Search OMOP Concepts"
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
                "Add Custom Concept"
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
              style = "margin-top: 15px; height: calc(95vh - 200px); display: flex; flex-direction: column; gap: 15px;",

              # Search Concepts section (top half)
              tags$div(
                style = "flex: 1; min-height: 0; display: flex; flex-direction: column;",
                tags$div(
                  id = ns("omop_table_container"),
                  style = "flex: 1; min-height: 0; position: relative; overflow: hidden;",
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
                style = "flex: 1; min-height: 0; display: flex; gap: 15px;",

                # Concept Details (left)
                tags$div(
                  style = "flex: 1; min-height: 0; display: flex; flex-direction: column; border: 1px solid #ddd; border-radius: 4px; padding: 15px; background: white;",
                  tags$h5("Selected Concept Details", style = "margin-top: 0; margin-bottom: 10px;"),
                  tags$div(
                    style = "flex: 1; min-height: 0; overflow: auto;",
                    uiOutput(ns("mapped_concepts_add_concept_details"))
                  )
                ),

                # Descendants (right)
                tags$div(
                  style = "flex: 1; min-height: 0; display: flex; flex-direction: column; border: 1px solid #ddd; border-radius: 4px; padding: 15px; background: white;",
                  tags$h5("Descendants", style = "margin-top: 0; margin-bottom: 10px;"),
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
                  ns("mapped_concepts_add_include_descendants"),
                  "Include descendants",
                  value = FALSE,
                  width = NULL
                ),
                tags$button(
                  class = "btn btn-default",
                  onclick = sprintf("$('#%s').css('display', 'none');", ns("mapped_concepts_add_modal")),
                  "Cancel"
                ),
                actionButton(
                  ns("mapped_concepts_add_selected"),
                  "Add Concept",
                  class = "btn btn-success"
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
                    "Vocabulary ID ",
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
                      "Vocabulary ID is required"
                    )
                  )
                ),

                tags$div(
                  style = "margin-bottom: 20px;",
                  textInput(
                    ns("custom_concept_code"),
                    "Concept Code",
                    placeholder = "Optional",
                    width = "300px"
                  )
                ),

                tags$div(
                  style = "margin-bottom: 20px;",
                  tags$label(
                    "Concept Name ",
                    tags$span("*", style = "color: #dc3545;")
                  ),
                  textInput(
                    ns("custom_concept_name"),
                    label = NULL,
                    placeholder = "Enter concept name",
                    width = "300px"
                  ),
                  shinyjs::hidden(
                    tags$span(
                      id = ns("custom_concept_name_error"),
                      style = "color: #dc3545; font-size: 12px;",
                      "Concept name is required"
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
                  "Cancel"
                ),
                actionButton(
                  ns("add_custom_concept"),
                  "Add Custom Concept",
                  class = "btn btn-success"
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
          tags$h3("Concept Details"),
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
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
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
mod_dictionary_explorer_server <- function(id, data, config, vocabularies, vocab_loading_status = reactive("not_loaded"), current_user = reactive(NULL), log_level = character()) {
  # Capture module id before entering moduleServer for logging
  module_id <- id

  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Store module id for logging (used by observe_event wrapper)
    id <- module_id

    ## 1) Server - Reactive Values & State ----
    ### View & Selection State ----
    current_view <- reactiveVal("list")  # "list", "detail", "detail_history", or "list_history"
    selected_concept_id <- reactiveVal(NULL)
    selected_mapped_concept_id <- reactiveVal(NULL)  # Track selected concept in mappings table
    relationships_tab <- reactiveVal("related")  # Track active tab: "related", "hierarchy", "synonyms"
    comments_tab <- reactiveVal("comments")  # Track active tab: "comments", "statistical_summary"
    selected_categories <- reactiveVal(character(0))  # Track selected category filters

    ### Edit Mode State ----
    general_concept_detail_edit_mode <- reactiveVal(FALSE)  # Track edit mode for General Concept Detail Page
    saved_table_page <- reactiveVal(0)  # Track datatable page for edit mode restoration
    general_concepts_edit_mode <- reactiveVal(FALSE)  # Track edit mode for General Concepts Page
    saved_table_search <- reactiveVal(NULL)  # Track datatable search state for edit mode
    edited_recommended <- reactiveVal(list())  # Store recommended changes by omop_concept_id
    deleted_concepts <- reactiveVal(list())  # Store deleted concept IDs by general_concept_id
    original_general_concepts <- reactiveVal(NULL)  # Store original state for cancel in list edit mode
    add_modal_selected_concept <- reactiveVal(NULL)  # Store selected concept in add modal

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
    edited_recommended_trigger <- reactiveVal(0)
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

    # Initialize local_data with data from parameter
    observe_event(data(), {
      if (is.null(local_data())) {
        local_data(data())
      }
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

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
      
      # Move "Other" to the end if it exists
      if ("Other" %in% sorted_cats) {
        sorted_cats <- c(setdiff(sorted_cats, "Other"), "Other")
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
      comments_display_trigger(comments_display_trigger() + 1)
      general_concepts_table_trigger(general_concepts_table_trigger() + 1)
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

    # When edited_recommended_trigger fires, update concept_mappings_table
    observe_event(edited_recommended_trigger(), {
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
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
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    ### Vocabulary Loading Status ----
    observe_event(vocab_loading_status(), {
      loading_status <- vocab_loading_status()
      vocab_data <- isolate(vocabularies())

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
      } else if (loading_status == "error") {
        # Show error message
        shinyjs::hide("vocab_loading_message")
        shinyjs::show("vocab_error_message")
        shinyjs::hide("general_concepts_table")
      } else {
        # For 'not_loaded' status, check if vocab folder is configured
        vocab_folder <- get_config_value("vocab_folder_path", default = "")
        duckdb_path <- get_duckdb_path()

        if (vocab_folder == "" || !dir.exists(vocab_folder)) {
          # No folder configured, show error message
          shinyjs::hide("vocab_loading_message")
          shinyjs::show("vocab_error_message")
          shinyjs::hide("general_concepts_table")
        } else if (!file.exists(duckdb_path)) {
          # Folder exists but DuckDB file doesn't exist, show error
          shinyjs::hide("vocab_loading_message")
          shinyjs::show("vocab_error_message")
          shinyjs::hide("general_concepts_table")
        } else {
          # Both folder and DuckDB file exist, show loading message
          shinyjs::show("vocab_loading_message")
          shinyjs::hide("vocab_error_message")
          shinyjs::hide("general_concepts_table")
        }
      }
    }, ignoreNULL = FALSE, ignoreInit = FALSE)


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
            style = "padding: 10px 0 15px 0; display: flex; align-items: center; gap: 15px; justify-content: space-between;",
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
            style = "padding: 10px 0 15px 0; font-size: 16px; display: flex; justify-content: space-between; align-items: center;",
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
                style = "padding: 10px 0 15px 0; font-size: 16px; display: flex; justify-content: space-between; align-items: center;",
                # Left side: breadcrumb
                tags$div(
                  tags$a(
                    href = "#",
                    onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_list")),
                    class = "breadcrumb-link",
                    style = "font-weight: 600;",
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
                Shiny.setInputValue('%s', Math.random(), {priority: 'event'});
                setTimeout(function() {
                  $(window).trigger('resize');
                  Shiny.unbindAll();
                  Shiny.bindAll();
                }, 100);
              ", ns("mapped_concepts_add_modal"), ns("modal_opened")),
              tags$i(class = "fa fa-plus"),
              " Add Concept"
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

    # Update DataTable filter when categories change
    observe_event(selected_categories(), {
      categories <- selected_categories()

      # Create proxy for the DataTable
      proxy <- DT::dataTableProxy("general_concepts_table", session = session)

      if (length(categories) > 0) {
        # Format as JSON array for multi-select filter: ["Category1", "Category2"]
        search_string <- jsonlite::toJSON(categories, auto_unbox = FALSE)

        # Update the search for the Category column (column index 1, 0-based)
        DT::updateSearch(proxy, keywords = list(
          global = NULL,
          columns = list(NULL, as.character(search_string))  # NULL for ID column, JSON array for Category column
        ))
      } else {
        # Clear the filter
        DT::updateSearch(proxy, keywords = list(
          global = NULL,
          columns = list(NULL, NULL)
        ))
      }
    })

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

      # 3. Trigger cascade
      view_trigger(view_trigger() + 1)
    }, ignoreNULL = FALSE)

    # Handle concept selection changes, then trigger cascade
    observe_event(selected_concept_id(), {
      concept_trigger(concept_trigger() + 1)
    }, ignoreNULL = FALSE)

    # Handle General Concept Detail Page edit mode changes, then trigger cascade
    observe_event(general_concept_detail_edit_mode(), {
      general_concept_detail_edit_mode_trigger(general_concept_detail_edit_mode_trigger() + 1)
    }, ignoreNULL = FALSE)

    # Handle General Concepts Page edit mode changes, then trigger cascade
    observe_event(general_concepts_edit_mode(), {
      general_concepts_edit_mode_trigger(general_concepts_edit_mode_trigger() + 1)
    }, ignoreNULL = FALSE)

    # Handle comments tab changes, then trigger cascade
    observe_event(comments_tab(), {
      comments_tab_trigger(comments_tab_trigger() + 1)
    }, ignoreNULL = FALSE)

    # Handle local data changes, then trigger cascade
    observe_event(local_data(), {
      local_data_trigger(local_data_trigger() + 1)
    }, ignoreNULL = FALSE)

    # Handle mapped concept selection changes, then trigger cascade
    observe_event(selected_mapped_concept_id(), {
      mapped_concept_trigger(mapped_concept_trigger() + 1)
    }, ignoreNULL = FALSE)

    # Handle edited_recommended changes, then trigger cascade
    observe_event(edited_recommended(), {
      edited_recommended_trigger(edited_recommended_trigger() + 1)
    }, ignoreNULL = FALSE)

    # Handle deleted_concepts changes, then trigger cascade
    observe_event(deleted_concepts(), {
      deleted_concepts_trigger(deleted_concepts_trigger() + 1)
    }, ignoreNULL = FALSE)

    # Handle selected_categories changes, then trigger cascade
    observe_event(selected_categories(), {
      selected_categories_trigger(selected_categories_trigger() + 1)
    }, ignoreNULL = FALSE)
    
    # Render history UIs when history_ui trigger fires
    observe_event(history_ui_trigger(), {
      view <- current_view()
      concept_id <- selected_concept_id()
      
      # Render list history UI
      if (view == "list_history") {
        output$general_concepts_history_ui <- renderUI({
          tags$div(
            style = "height: calc(100vh - 175px); overflow: auto; padding: 20px;",
            tags$div(
              style = "padding: 20px; background: #f8f9fa; border-radius: 8px; text-align: center; color: #666;",
              tags$p("History view for all general concepts will be implemented here.")
            )
          )
        })
      }
      
      # Render detail history UI
      if (view == "detail_history" && !is.null(concept_id)) {
        output$general_concept_detail_history_ui <- renderUI({
          tags$div(
            style = "height: calc(100vh - 175px); overflow: auto; padding: 20px;",
            tags$div(
              style = "padding: 20px; background: #f8f9fa; border-radius: 8px; text-align: center; color: #666;",
              tags$p("History view will be implemented here.")
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
      # Reset all unsaved changes
      edited_recommended(list())
      deleted_concepts(list())
      # edited_comment(NULL)
      general_concept_detail_edit_mode(FALSE)
      # Reset tab to comments
      comments_tab("comments")
      # Hide edit buttons and show normal action buttons
      shinyjs::hide("general_concept_detail_edit_buttons")
      shinyjs::show("general_concept_detail_action_buttons")
    })
    
    # Observe tab switching for relationships
    observe_event(input$switch_relationships_tab, {
      relationships_tab(input$switch_relationships_tab)
    })
    
    # Observe tab switching for comments
    observe_event(input$switch_comments_tab, {
      comments_tab(input$switch_comments_tab)
    })

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
              '<button class="delete-concept-btn" data-id="%s" style="padding: 4px 12px; background: #dc3545; color: white; border: none; border-radius: 4px; cursor: pointer;">Delete</button>',
              general_concept_id
            )
          } else {
            sprintf(
              '<button class="view-details-btn" data-id="%s">View Details</button>',
              general_concept_id
            )
          }
        )

      # Select columns based on edit mode
      if (general_concepts_edit_mode()) {
        table_data <- table_data %>%
          dplyr::select(general_concept_id, category, subcategory, general_concept_name, actions)
        col_names <- c("ID", "Category", "Subcategory", "General Concept Name", "Actions")
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
        col_names <- c("ID", "Category", "Subcategory", "General Concept Name", "Actions")
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
    }, ignoreNULL = FALSE)

    # Handle "View Details" button click
    observe_event(input$view_concept_details, {
      concept_id <- input$view_concept_details
      if (!is.null(concept_id)) {
        selected_concept_id(as.integer(concept_id))
        current_view("detail")
        current_mappings(NULL)  # Reset cache when changing concept
      }
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

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

      # Save current page number
      if (!is.null(input$general_concepts_table_state)) {
        current_page <- input$general_concepts_table_state$start / input$general_concepts_table_state$length + 1
        saved_table_page(current_page)
      }

      # Save column search filters
      if (!is.null(input$general_concepts_table_search_columns)) {
        saved_table_search(input$general_concepts_table_search_columns)
      }

      general_concepts_edit_mode(TRUE)

      # Update button visibility will be triggered automatically by general_concepts_edit_mode() change
      update_button_visibility()

      # Wait for datatable to re-render, then restore state
      shinyjs::delay(100, {
        if (!general_concepts_edit_mode()) return()

        proxy <- DT::dataTableProxy("general_concepts_table", session = session)

        # Restore column filters
        search_columns <- saved_table_search()
        if (!is.null(search_columns)) {
          DT::updateSearch(proxy, keywords = list(
            global = NULL,
            columns = search_columns
          ))
        }

        # Restore page position
        page_num <- saved_table_page()
        if (!is.null(page_num) && page_num > 0) {
          DT::selectPage(proxy, page_num)
        }
      })
    })

    # Handle list cancel button
    observe_event(input$general_concepts_cancel_edit, {
      # Save current filters and page before exiting edit mode
      if (!is.null(input$general_concepts_table_search_columns)) {
        saved_table_search(input$general_concepts_table_search_columns)
      }
      if (!is.null(input$general_concepts_table_state)) {
        current_page <- input$general_concepts_table_state$start / input$general_concepts_table_state$length + 1
        saved_table_page(current_page)
      }

      # Restore original state
      if (!is.null(original_general_concepts())) {
        data <- local_data()
        data$general_concepts <- original_general_concepts()
        local_data(data)
        original_general_concepts(NULL)
      }
      general_concepts_edit_mode(FALSE)

      # Update button visibility
      update_button_visibility()

      # Wait for datatable to re-render, then restore state
      shinyjs::delay(100, {
        if (general_concepts_edit_mode()) return()

        proxy <- DT::dataTableProxy("general_concepts_table", session = session)

        # Restore column filters
        search_columns <- saved_table_search()
        if (!is.null(search_columns)) {
          DT::updateSearch(proxy, keywords = list(
            global = NULL,
            columns = search_columns
          ))
        }

        # Restore page position
        page_num <- saved_table_page()
        if (!is.null(page_num) && page_num > 0) {
          DT::selectPage(proxy, page_num)
        }
      })
    })
    
    observe_event(input$general_concepts_save_updates, {
      if (!general_concepts_edit_mode()) return()

      # Save current filters and page before exiting edit mode
      if (!is.null(input$general_concepts_table_search_columns)) {
        saved_table_search(input$general_concepts_table_search_columns)
      }
      if (!is.null(input$general_concepts_table_state)) {
        current_page <- input$general_concepts_table_state$start / input$general_concepts_table_state$length + 1
        saved_table_page(current_page)
      }

      # Get current data
      general_concepts <- current_data()$general_concepts

      # Save general_concepts to CSV
      csv_path <- system.file("extdata", "csv", "general_concepts.csv", package = "indicate")

      # If package path doesn't exist, try local development path
      if (!file.exists(csv_path) || csv_path == "") {
        csv_path <- file.path("inst", "extdata", "csv", "general_concepts.csv")
      }

      if (file.exists(csv_path)) {
        readr::write_csv(general_concepts, csv_path)
      }

      general_concepts_edit_mode(FALSE)
      original_general_concepts(NULL)

      # Update button visibility
      update_button_visibility()

      # Wait for datatable to re-render, then restore state
      shinyjs::delay(100, {
        if (general_concepts_edit_mode()) return()

        proxy <- DT::dataTableProxy("general_concepts_table", session = session)

        # Restore column filters
        search_columns <- saved_table_search()
        if (!is.null(search_columns)) {
          DT::updateSearch(proxy, keywords = list(
            global = NULL,
            columns = search_columns
          ))
        }

        # Restore page position
        page_num <- saved_table_page()
        if (!is.null(page_num) && page_num > 0) {
          DT::selectPage(proxy, page_num)
        }
      })
    })

    # Handle cell edits in general concepts table
    observe_event(input$general_concepts_table_cell_edit, {
      if (!general_concepts_edit_mode()) return()

      info <- input$general_concepts_table_cell_edit

      # Get current data
      general_concepts <- current_data()$general_concepts

      # Update the cell value
      row_num <- info$row
      col_num <- info$col + 1  # DT uses 0-based indexing for columns, add 1 for R
      new_value <- info$value

      # Map column number to actual column name
      # Columns: general_concept_id (1), category (2), subcategory (3), general_concept_name (4)
      if (col_num == 2) {
        # Category column
        general_concepts[row_num, "category"] <- new_value
      } else if (col_num == 3) {
        # Subcategory column
        general_concepts[row_num, "subcategory"] <- new_value
      } else if (col_num == 4) {
        # General concept name column
        general_concepts[row_num, "general_concept_name"] <- new_value
      }

      # Update local data
      data <- local_data()
      data$general_concepts <- general_concepts
      local_data(data)
    })

    ### Delete Concept ----
    # Handle delete general concept button
    observe_event(input$delete_general_concept, {
      if (!general_concepts_edit_mode()) return()

      # Save current page number and search filters before deletion
      if (!is.null(input$general_concepts_table_state)) {
        current_page <- input$general_concepts_table_state$start / input$general_concepts_table_state$length + 1
        saved_table_page(current_page)
      }

      # Save column search filters
      if (!is.null(input$general_concepts_table_search_columns)) {
        saved_table_search(input$general_concepts_table_search_columns)
      }

      concept_id <- input$delete_general_concept
      if (!is.null(concept_id)) {
        # Remove from general_concepts
        general_concepts <- current_data()$general_concepts %>%
          dplyr::filter(general_concept_id != as.integer(concept_id))

        # Also remove associated mappings
        concept_mappings <- current_data()$concept_mappings %>%
          dplyr::filter(general_concept_id != as.integer(concept_id))

        # Update local data
        data <- local_data()
        data$general_concepts <- general_concepts
        data$concept_mappings <- concept_mappings
        local_data(data)

        # Wait for datatable to re-render, then restore state
        shinyjs::delay(100, {
          proxy <- DT::dataTableProxy("general_concepts_table", session = session)

          # Restore column filters
          search_columns <- saved_table_search()
          if (!is.null(search_columns)) {
            DT::updateSearch(proxy, keywords = list(
              global = NULL,
              columns = search_columns
            ))
          }

          # Restore page position
          page_num <- saved_table_page()
          if (!is.null(page_num) && page_num > 0) {
            # Check if page still exists after deletion
            total_rows <- nrow(general_concepts)
            page_length <- 25  # Default page length
            max_page <- ceiling(total_rows / page_length)

            # If current page no longer exists, go to last page
            target_page <- min(page_num, max_page)
            DT::selectPage(proxy, target_page)
          }
        })
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

      # Validation with visual feedback
      has_error <- FALSE

      # Reset all borders first
      shinyjs::runjs(sprintf("
        document.getElementById('%s').style.border = '';
        $('#%s').parent().find('.selectize-control .selectize-input').css('border', '');
        document.getElementById('%s').style.border = '';
        $('#%s').parent().find('.selectize-control .selectize-input').css('border', '');
        document.getElementById('%s').style.border = '';
      ", ns("general_concepts_new_name"), ns("general_concepts_new_category"), ns("general_concepts_new_category_text"), ns("general_concepts_new_subcategory"), ns("general_concepts_new_subcategory_text")))

      # Validate concept name
      if (is.null(concept_name) || nchar(trimws(concept_name)) == 0) {
        has_error <- TRUE
        shinyjs::runjs(sprintf("document.getElementById('%s').style.border = '2px solid #dc3545'", ns("general_concepts_new_name")))
      }

      # Validate category - only highlight the visible field
      if (is.null(category) || nchar(trimws(category)) == 0) {
        has_error <- TRUE
        shinyjs::runjs(sprintf("
          var categorySelectContainer = document.getElementById('%s');
          var categoryTextContainer = document.getElementById('%s');
          if (categorySelectContainer.style.display !== 'none') {
            $('#%s').parent().find('.selectize-control .selectize-input').css('border', '2px solid #dc3545');
          } else {
            document.getElementById('%s').style.border = '2px solid #dc3545';
          }
        ", ns("category_select_container"), ns("category_text_container"), ns("general_concepts_new_category"), ns("general_concepts_new_category_text")))
      }

      # Validate subcategory - only highlight the visible field
      if (is.null(subcategory) || nchar(trimws(subcategory)) == 0) {
        has_error <- TRUE
        shinyjs::runjs(sprintf("
          var subcategorySelectContainer = document.getElementById('%s');
          var subcategoryTextContainer = document.getElementById('%s');
          if (subcategorySelectContainer.style.display !== 'none') {
            $('#%s').parent().find('.selectize-control .selectize-input').css('border', '2px solid #dc3545');
          } else {
            document.getElementById('%s').style.border = '2px solid #dc3545';
          }
        ", ns("subcategory_select_container"), ns("subcategory_text_container"), ns("general_concepts_new_subcategory"), ns("general_concepts_new_subcategory_text")))
      }

      if (has_error) {
        return()
      }

      # Get current data
      general_concepts <- current_data()$general_concepts

      # Generate new ID (max + 1)
      new_id <- max(general_concepts$general_concept_id, na.rm = TRUE) + 1

      # Create new row
      new_row <- data.frame(
        general_concept_id = new_id,
        category = trimws(category),
        subcategory = trimws(subcategory),
        general_concept_name = trimws(concept_name),
        comments = NA_character_,
        statistical_summary = NA_character_,
        stringsAsFactors = FALSE
      )

      # Add to general_concepts and sort alphabetically
      general_concepts <- rbind(general_concepts, new_row) %>%
        dplyr::arrange(category, subcategory, general_concept_name)

      # Find the row index of the newly added concept after sorting
      new_concept_row_index <- which(
        general_concepts$general_concept_id == new_id &
        general_concepts$category == trimws(category) &
        general_concepts$subcategory == trimws(subcategory) &
        general_concepts$general_concept_name == trimws(concept_name)
      )[1]

      # Save to CSV
      csv_path <- system.file("extdata", "csv", "general_concepts.csv", package = "indicate")
      if (!file.exists(csv_path) || csv_path == "") {
        csv_path <- file.path("inst", "extdata", "csv", "general_concepts.csv")
      }

      if (file.exists(csv_path)) {
        readr::write_csv(general_concepts, csv_path)

        # Update local data
        data <- local_data()
        data$general_concepts <- general_concepts
        local_data(data)

        # Close modal and reset fields
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("general_concepts_add_modal")))

        # Reset input fields
        shiny::updateTextInput(session, "general_concepts_new_name", value = "")
        shiny::updateTextInput(session, "general_concepts_new_category_text", value = "")
        shiny::updateTextInput(session, "general_concepts_new_subcategory_text", value = "")
        updateSelectizeInput(session, "general_concepts_new_category", selected = character(0))
        updateSelectizeInput(session, "general_concepts_new_subcategory", selected = character(0))

        # Calculate which page the new concept is on (1-indexed for DT::selectPage)
        page_length <- 25  # Default page length from datatable
        target_page <- ceiling(new_concept_row_index / page_length)

        # Use DT proxy to navigate to the correct page after a delay
        # This allows the table to re-render first
        shinyjs::delay(100, {
          proxy <- DT::dataTableProxy("general_concepts_table", session = session)
          DT::selectPage(proxy, target_page)
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
      
      # Get current data
      general_concepts <- current_data()$general_concepts
      concept_mappings <- current_data()$concept_mappings
      custom_concepts <- current_data()$custom_concepts

      # Update comments in general_concepts
      new_comment <- input$comments_input
      if (!is.null(new_comment)) {
        general_concepts <- general_concepts %>%
          dplyr::mutate(
            comments = ifelse(
              general_concept_id == concept_id,
              new_comment,
              comments
            )
          )
      }

      # Update statistical_summary in general_concepts
      new_statistical_summary <- input$statistical_summary_editor
      if (!is.null(new_statistical_summary)) {
        # Save JSON (assuming it's valid)
        general_concepts <- general_concepts %>%
          dplyr::mutate(
            statistical_summary = ifelse(
              general_concept_id == concept_id,
              new_statistical_summary,
              statistical_summary
            )
          )
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
          concept_mappings <- concept_mappings %>%
            dplyr::filter(!(general_concept_id == concept_id & omop_concept_id %in% omop_ids_to_delete))
        }

        # Delete custom concepts from custom_concepts
        if (length(custom_ids_to_delete) > 0 && !is.null(custom_concepts)) {
          custom_concepts <- custom_concepts %>%
            dplyr::filter(!(general_concept_id == concept_id & custom_concept_id %in% custom_ids_to_delete))
        }
      }
      
      # Update recommended values for both OMOP and custom concepts
      recommended_edits <- edited_recommended()

      if (length(recommended_edits) > 0) {
        for (concept_unique_id in names(recommended_edits)) {
          new_rec_value <- recommended_edits[[concept_unique_id]]

          # Determine if this is an OMOP or custom concept
          if (grepl("^omop-", concept_unique_id)) {
            # OMOP concept
            omop_id <- as.integer(sub("^omop-", "", concept_unique_id))

            # Check if this concept already exists in concept_mappings
            existing_row <- concept_mappings %>%
              dplyr::filter(
                general_concept_id == concept_id &
                  omop_concept_id == omop_id
              )

            if (nrow(existing_row) > 0) {
              # Update existing row
              concept_mappings <- concept_mappings %>%
                dplyr::mutate(
                  recommended = ifelse(
                    general_concept_id == concept_id & omop_concept_id == omop_id,
                    new_rec_value,
                    recommended
                  )
                )
            } else if (isTRUE(new_rec_value)) {
              # Add new row only if recommended = TRUE
              # Get concept info from vocabularies or current data
              vocab_data <- vocabularies()

              if (!is.null(vocab_data) && !is.null(vocab_data$concept)) {
                # Filter and collect from DuckDB
                new_concept <- vocab_data$concept %>%
                  dplyr::filter(concept_id == omop_id) %>%
                  dplyr::collect()

                if (nrow(new_concept) > 0) {
                  # Create new row with minimal structure (new schema)
                  if (nrow(concept_mappings) > 0) {
                    # Take first row as template and modify it
                    new_row <- concept_mappings[1, ]
                    new_row$general_concept_id <- as.integer(concept_id)
                    new_row$omop_concept_id <- omop_id
                    new_row$omop_unit_concept_id <- as.character("/")
                    new_row$recommended <- TRUE
                  } else {
                    # Fallback if concept_mappings is empty
                    new_row <- data.frame(
                      general_concept_id = as.integer(concept_id),
                      omop_concept_id = omop_id,
                      omop_unit_concept_id = "/",
                      recommended = TRUE,
                      stringsAsFactors = FALSE
                    )
                  }

                  concept_mappings <- dplyr::bind_rows(concept_mappings, new_row)
                }
              }
            }
          } else if (grepl("^custom-", concept_unique_id)) {
            # Custom concept
            custom_id <- as.integer(sub("^custom-", "", concept_unique_id))

            if (!is.null(custom_concepts)) {
              custom_concepts <- custom_concepts %>%
                dplyr::mutate(
                  recommended = ifelse(
                    general_concept_id == concept_id & custom_concept_id == custom_id,
                    new_rec_value,
                    recommended
                  )
                )
            }
          }
        }
      }
      
      # Write to CSV files
      readr::write_csv(
        general_concepts,
        app_sys("extdata", "csv", "general_concepts.csv")
      )

      readr::write_csv(
        concept_mappings,
        app_sys("extdata", "csv", "concept_mappings.csv")
      )

      # Write custom_concepts.csv if modified
      if (!is.null(custom_concepts)) {
        readr::write_csv(
          custom_concepts,
          app_sys("extdata", "csv", "custom_concepts.csv")
        )
      }

      # Update local data
      updated_data <- list(
        general_concepts = general_concepts,
        concept_mappings = concept_mappings,
        custom_concepts = custom_concepts
      )
      local_data(updated_data)
      
      # Reset edit state
      edited_recommended(list())
      deleted_concepts(list())
      # edited_comment(NULL)
      general_concept_detail_edit_mode(FALSE)
      # Reset tab to comments
      comments_tab("comments")
      # Hide edit buttons and show normal action buttons
      shinyjs::hide("general_concept_detail_edit_buttons")
      shinyjs::show("general_concept_detail_action_buttons")
    })
    
    ### a) Mapped Concepts (Top-Left Panel) ----
    #### Mapped Concepts Table Rendering ----
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

      # Read directly from concept_mappings.csv
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
            concept_code,
            recommended
          ) %>%
          dplyr::mutate(
            omop_concept_id = NA_integer_,
            is_custom = TRUE
          )
      } else {
        custom_concepts <- data.frame(
          custom_concept_id = integer(),
          concept_name = character(),
          vocabulary_id = character(),
          concept_code = character(),
          recommended = logical(),
          omop_concept_id = integer(),
          is_custom = logical()
        )
      }

      # Enrich OMOP concepts with vocabulary data
      vocab_data_for_enrichment <- vocabularies()
      if (!is.null(vocab_data_for_enrichment) && nrow(csv_mappings) > 0) {
        # Get concept details
        concept_ids <- csv_mappings$omop_concept_id
        omop_concepts <- vocab_data_for_enrichment$concept %>%
          dplyr::filter(concept_id %in% concept_ids) %>%
          dplyr::select(concept_id, concept_name, vocabulary_id, concept_code) %>%
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
            is_custom = FALSE,
            custom_concept_id = NA_integer_
          )
      }

      # Combine OMOP and custom concepts
      all_concepts <- dplyr::bind_rows(
        csv_mappings %>%
          dplyr::select(custom_concept_id, concept_name, vocabulary_id, concept_code, omop_concept_id, recommended, is_custom),
        custom_concepts
      )

      # Select final columns and arrange
      mappings <- all_concepts %>%
        dplyr::select(
          custom_concept_id,
          concept_name,
          vocabulary_id,
          concept_code,
          omop_concept_id,
          recommended,
          is_custom
        ) %>%
        dplyr::arrange(dplyr::desc(recommended), concept_name)

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

      # Convert recommended to Yes/No or toggle
      if (nrow(mappings) > 0) {
        # Create toggle HTML for edit mode, or simple Yes/No for view mode
        if (is_editing) {
          mappings <- mappings %>%
            dplyr::mutate(
              # Create unique ID: "omop-{id}" for OMOP concepts, "custom-{id}" for custom concepts
              unique_id = dplyr::case_when(
                is_custom & !is.na(custom_concept_id) ~ paste0("custom-", custom_concept_id),
                !is_custom & !is.na(omop_concept_id) ~ paste0("omop-", omop_concept_id),
                TRUE ~ paste0("unknown-", dplyr::row_number())
              )
            )

          # Create HTML with both data attributes (one will be empty)
          mappings <- mappings %>%
            dplyr::mutate(
              recommended = sprintf(
                '<label class="toggle-switch" data-omop-id="%s" data-custom-id="%s"><input type="checkbox" %s><span class="toggle-slider"></span></label>',
                ifelse(is.na(omop_concept_id), "", omop_concept_id),
                ifelse(is.na(custom_concept_id), "", custom_concept_id),
                ifelse(recommended, 'checked', '')
              ),
              action = sprintf(
                '<i class="fa fa-trash delete-icon" data-omop-id="%s" data-custom-id="%s" style="cursor: pointer; color: #dc3545;"></i>',
                ifelse(is.na(omop_concept_id), "", omop_concept_id),
                ifelse(is.na(custom_concept_id), "", custom_concept_id)
              )
            )
        } else {
          mappings <- mappings %>%
            dplyr::mutate(recommended = ifelse(recommended, "Yes", "No"))
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
          dplyr::select(concept_name, vocabulary_id, concept_code, recommended, action, omop_concept_id)
      } else {
        mappings <- mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, recommended, omop_concept_id)
      }

      # Cache mappings for selection handling (before converting recommended to Yes/No)
      mappings_for_cache <- mappings %>%
        dplyr::mutate(recommended = recommended == "Yes")
      current_mappings(mappings_for_cache)

      # Load JavaScript callbacks
      callback <- JS(paste(readLines(app_sys("www", "dt_callback.js")), collapse = "\n"))
      keyboard_nav <- paste(readLines(app_sys("www", "keyboard_nav.js")), collapse = "\n")

      # Build initComplete callback that includes keyboard nav
      init_complete_js <- create_keyboard_nav(keyboard_nav, TRUE, FALSE)

      # Configure DataTable columns based on edit mode
      if (is_editing) {
        escape_cols <- c(TRUE, TRUE, TRUE, FALSE, FALSE, TRUE)  # Don't escape HTML in recommended and action columns
        col_names <- c("Concept Name", "Vocabulary", "Code", "Recommended", "Action", "OMOP ID")
        col_defs <- list(
          list(targets = 3, width = "100px", className = 'dt-center'),  # Recommended column
          list(targets = 4, width = "60px", className = 'dt-center'),   # Action column
          list(targets = 5, visible = FALSE)  # OMOP ID column hidden
        )
      } else {
        escape_cols <- TRUE
        col_names <- c("Concept Name", "Vocabulary", "Code", "Recommended", "OMOP ID")
        col_defs <- list(
          list(targets = 3, width = "100px", className = 'dt-center'),  # Recommended column
          list(targets = 4, visible = FALSE)  # OMOP ID column hidden
        )
      }

      dt <- DT::datatable(
        mappings,
        selection = 'none',
        rownames = FALSE,
        escape = escape_cols,
        extensions = c('Select'),
        colnames = col_names,
        options = list(
          pageLength = 8,
          dom = 'tip',
          select = list(style = 'single', info = FALSE),
          columnDefs = col_defs,
          initComplete = init_complete_js
        ),
        callback = callback
      )

      # Apply formatStyle only in view mode (not edit mode with toggles)
      if (!is_editing) {
        dt <- dt %>%
          DT::formatStyle(
            'recommended',
            target = 'cell',
            backgroundColor = DT::styleEqual(
              c("Yes", "No"),
              c('#d4edda', '#f8f9fa')
            ),
            fontWeight = DT::styleEqual(
              c("Yes", "No"),
              c('bold', 'normal')
            ),
            color = DT::styleEqual(
              c("Yes", "No"),
              c('#155724', '#666')
            )
          )
      }

          dt
        }, server = FALSE)
      }
    }, ignoreInit = TRUE)

    # Cache for current mappings to avoid recalculation
    current_mappings <- reactiveVal(NULL)
    
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

      if (!is.null(selected_row) && length(selected_row) > 0) {
        # Use cached mappings if available
        mappings <- current_mappings()

        # Get the selected concept's OMOP ID
        if (selected_row <= nrow(mappings)) {
          selected_omop_id <- mappings$omop_concept_id[selected_row]
          selected_mapped_concept_id(selected_omop_id)
        }
      }
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    #### Add Mapping to Selected Concept ----

    # Observer to handle modal opening and force DataTable render
    observe_event(input$modal_opened, {
      outputOptions(output, "mapped_concepts_add_omop_table", suspendWhenHidden = FALSE)
    }, ignoreInit = TRUE)

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

    # Track row selection in OMOP concepts table
    observe_event(input$mapped_concepts_add_omop_table_rows_selected, {
      selected_row <- input$mapped_concepts_add_omop_table_rows_selected

      if (length(selected_row) > 0) {
        all_concepts <- modal_concepts_all()
        if (is.null(all_concepts)) return()

        # Get selected concept
        selected_concept <- all_concepts[selected_row, ]
        add_modal_selected_concept(selected_concept)
      } else {
        add_modal_selected_concept(NULL)
      }
    }, ignoreInit = TRUE)

    # Render OMOP concepts table in add modal
    observe_event(add_modal_selected_concept(), {
      concept <- add_modal_selected_concept()

      # Render concept details
      output$mapped_concepts_add_concept_details <- renderUI({
        if (is.null(concept) || nrow(concept) == 0) {
          return(tags$div(
            style = "padding: 20px; background: #f8f9fa; border-radius: 6px; text-align: center;",
            tags$p(
              style = "color: #666; font-style: italic;",
              "Select a concept from the table to view details."
            )
          ))
        }

        # Use grid layout like Selected Concept Details
        tags$div(
          class = "concept-details-container",
          style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(4, auto); grid-auto-flow: column; gap: 4px 15px;",
          # Column 1
          create_detail_item("Concept Name", concept$concept_name, include_colon = FALSE),
          create_detail_item("Vocabulary ID", concept$vocabulary_id, include_colon = FALSE),
          create_detail_item("Domain ID", concept$domain_id, include_colon = FALSE),
          create_detail_item("Concept Class", concept$concept_class_id, include_colon = FALSE),
          # Column 2
          create_detail_item("OMOP Concept ID", concept$concept_id, include_colon = FALSE),
          create_detail_item("Concept Code", concept$concept_code, include_colon = FALSE),
          create_detail_item("Standard", if (!is.na(concept$standard_concept)) concept$standard_concept else "No", include_colon = FALSE),
          tags$div()  # Empty slot to balance grid
        )
      })

      # Render descendants table
      output$mapped_concepts_add_descendants_table <- DT::renderDT({
        if (is.null(concept) || nrow(concept) == 0) {
          return(DT::datatable(
            data.frame(Message = "Select a concept to view descendants."),
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
            autoWidth = FALSE
          ),
          colnames = c("Concept ID", "Name", "Vocabulary")
        )
      })
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    # Render OMOP concepts table for adding to mapping (server-side processing)
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
        dplyr::select(concept_id, concept_name, vocabulary_id, domain_id, concept_class_id)

      # Convert for better filtering
      display_concepts$concept_id <- as.character(display_concepts$concept_id)
      display_concepts$vocabulary_id <- as.factor(display_concepts$vocabulary_id)
      display_concepts$domain_id <- as.factor(display_concepts$domain_id)
      display_concepts$concept_class_id <- as.factor(display_concepts$concept_class_id)

      # Render DataTable with server-side processing and internal scrolling
      DT::datatable(
        display_concepts,
        rownames = FALSE,
        selection = 'single',
        filter = 'top',
        options = list(
          pageLength = 8,
          dom = 'tp',
          ordering = TRUE,
          autoWidth = FALSE,
          scrollX = FALSE,
          paging = TRUE
        ),
        colnames = c("Concept ID", "Concept Name", "Vocabulary", "Domain", "Concept Class")
      )
    }, server = TRUE)

    # Add selected OMOP concept with optional descendants
    observe_event(input$mapped_concepts_add_selected, {
      if (!general_concept_detail_edit_mode()) return()

      # Get selected concept
      selected_row <- input$mapped_concepts_add_omop_table_rows_selected
      if (is.null(selected_row) || length(selected_row) == 0) return()

      all_concepts <- modal_concepts_all()
      if (is.null(all_concepts)) return()

      selected_concept <- all_concepts[selected_row, ]

      # Get current general concept
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      # Start with the selected concept
      concepts_to_add <- selected_concept$concept_id

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

      # Load current concept_mappings
      concept_mappings_path <- app_sys("extdata", "csv", "concept_mappings.csv")
      if (file.exists(concept_mappings_path)) {
        concept_mappings <- readr::read_csv(concept_mappings_path, show_col_types = FALSE)
      } else {
        concept_mappings <- data.frame(
          general_concept_id = integer(),
          omop_concept_id = integer(),
          omop_unit_concept_id = character(),
          recommended = logical(),
          stringsAsFactors = FALSE
        )
      }

      # Create new mappings
      new_mappings <- data.frame(
        general_concept_id = rep(concept_id, length(concepts_to_add)),
        omop_concept_id = concepts_to_add,
        omop_unit_concept_id = "/",
        recommended = FALSE,
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

      if (nrow(new_mappings) > 0) {
        # Add new mappings
        concept_mappings <- dplyr::bind_rows(concept_mappings, new_mappings)

        # Save to CSV
        readr::write_csv(concept_mappings, concept_mappings_path)

        # Update local data
        data_updated <- local_data()
        data_updated$concept_mappings <- concept_mappings
        local_data(data_updated)

        # Trigger table re-render
        concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
      }

      # Close modal and reset selection
      shinyjs::runjs(sprintf("$('#%s').css('display', 'none');", ns("mapped_concepts_add_modal")))
      add_modal_selected_concept(NULL)
    }, ignoreInit = TRUE)

    # Add custom concept
    observe_event(input$add_custom_concept, {
      if (!general_concept_detail_edit_mode()) return()

      # Reset all error messages
      shinyjs::hide("custom_vocabulary_id_error")
      shinyjs::hide("custom_concept_name_error")

      # Validate vocabulary ID
      vocabulary_id <- trimws(input$custom_vocabulary_id)
      vocab_valid <- !is.null(vocabulary_id) && vocabulary_id != ""

      # Validate concept name
      concept_name <- trimws(input$custom_concept_name)
      name_valid <- !is.null(concept_name) && concept_name != ""

      # Show errors if validation fails
      if (!vocab_valid) {
        shinyjs::show("custom_vocabulary_id_error")
      }
      if (!name_valid) {
        shinyjs::show("custom_concept_name_error")
      }

      # Return if any validation failed
      if (!vocab_valid || !name_valid) {
        return()
      }

      # Get current general concept
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      # Create custom concept code
      concept_code <- trimws(input$custom_concept_code)
      if (concept_code == "" || concept_code == "/") {
        concept_code <- "/"
      }

      # Load or create custom_concepts
      custom_concepts_path <- app_sys("extdata", "csv", "custom_concepts.csv")
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
          recommended = logical(),
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
        recommended = FALSE,
        stringsAsFactors = FALSE
      )

      custom_concepts <- dplyr::bind_rows(custom_concepts, new_custom_concept)

      # Save custom_concepts
      readr::write_csv(custom_concepts, custom_concepts_path)

      # Update local data
      data_updated <- local_data()
      data_updated$custom_concepts <- custom_concepts
      local_data(data_updated)

      # Trigger re-render
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)

      # Close modal and reset form
      shinyjs::runjs(sprintf("$('#%s').css('display', 'none');", ns("mapped_concepts_add_modal")))
      updateTextInput(session, "custom_vocabulary_id", value = "")
      updateTextInput(session, "custom_concept_code", value = "")
      updateTextInput(session, "custom_concept_name", value = "")
      shinyjs::hide("custom_vocabulary_id_error")
      shinyjs::hide("custom_concept_name_error")
    }, ignoreInit = TRUE)
    
    ### b) Selected Mapping Details (Top-Right Panel) ----
    #### Selected Mapping Display ----
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
          create_detail_item("Concept Name", info$concept_name, include_colon = FALSE),
          create_detail_item("Category",
                            ifelse(nrow(general_concept_info) > 0,
                                  general_concept_info$category[1], NA),
                            include_colon = FALSE),
          create_detail_item("Sub-category",
                            ifelse(nrow(general_concept_info) > 0,
                                  general_concept_info$subcategory[1], NA),
                            include_colon = FALSE),
          create_detail_item("EHDEN Data Sources", "/", include_colon = FALSE),
          create_detail_item("EHDEN Rows Count", "/", include_colon = FALSE),
          create_detail_item("LOINC Rank", "/", include_colon = FALSE),
          create_detail_item("Validity", validity_text, color = validity_color, include_colon = FALSE),
          create_detail_item("Standard", standard_text, color = standard_color, include_colon = FALSE),
          # Column 2 (must have exactly 8 items)
          create_detail_item("Vocabulary ID", info$vocabulary_id, include_colon = FALSE),
          create_detail_item("Domain ID", if (!is.na(info$domain_id)) info$domain_id else "/", include_colon = FALSE),
          create_detail_item("Concept Code", info$concept_code, include_colon = FALSE),
          create_detail_item("OMOP Concept ID", info$concept_id, url = athena_url, include_colon = FALSE),
          if (!is.null(fhir_url)) {
            if (fhir_url == "no_link") {
              tags$div(
                class = "detail-item",
                tags$strong("FHIR Resource"),
                tags$span(
                  style = "color: #999; font-style: italic;",
                  "No link available"
                )
              )
            } else {
              tags$div(
                class = "detail-item",
                tags$strong("FHIR Resource"),
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
          create_detail_item("Unit Concept Name", "/", include_colon = FALSE),
          create_detail_item("OMOP Unit Concept ID", "/", include_colon = FALSE),
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

      # Get unit concept code from OMOP if unit concept ID exists
      unit_concept_code <- NULL
      if (!is.null(vocab_data) && !is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "" && info$omop_unit_concept_id != "/") {
        unit_concept_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == as.integer(info$omop_unit_concept_id)) %>%
          dplyr::collect()
        if (nrow(unit_concept_info) > 0) {
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
        create_detail_item("Concept Name", info$concept_name, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("Category",
                          ifelse(nrow(general_concept_info) > 0,
                                general_concept_info$category[1], NA),
                          include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("Sub-category",
                          ifelse(nrow(general_concept_info) > 0,
                                general_concept_info$subcategory[1], NA),
                          include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("EHDEN Data Sources", info$ehden_num_data_sources, format_number = TRUE, editable = TRUE, input_id = "ehden_num_data_sources_input", step = 1, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("EHDEN Rows Count", info$ehden_rows_count, format_number = TRUE, editable = TRUE, input_id = "ehden_rows_count_input", step = 1000, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("LOINC Rank", info$loinc_rank, editable = TRUE, input_id = "loinc_rank_input", step = 1, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("Validity", validity_text, color = validity_color, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("Standard", standard_text, color = standard_color, include_colon = FALSE, is_editing = is_editing, ns = ns),
        # Column 2 (must have exactly 8 items)
        create_detail_item("Vocabulary ID", info$vocabulary_id, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("Domain ID", if (!is.null(validity_info) && !is.na(validity_info$domain_id)) validity_info$domain_id else "/", include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("Concept Code", info$concept_code, include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("OMOP Concept ID", info$omop_concept_id, url = athena_url, include_colon = FALSE, is_editing = is_editing, ns = ns),
        if (!is.null(fhir_url)) {
          if (fhir_url == "no_link") {
            tags$div(
              class = "detail-item",
              tags$strong("FHIR Resource"),
              tags$span(
                style = "color: #999; font-style: italic;",
                "No link available"
              )
            )
          } else {
            tags$div(
              class = "detail-item",
              tags$strong("FHIR Resource"),
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
        create_detail_item("Unit Concept Name",
                          if (!is.null(unit_concept_code) && unit_concept_code != "") {
                            unit_concept_code
                          } else {
                            "/"
                          },
                          include_colon = FALSE, is_editing = is_editing, ns = ns),
        create_detail_item("OMOP Unit Concept ID",
                          if (!is.null(info$omop_unit_concept_id) && !is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "" && info$omop_unit_concept_id != "/") {
                            info$omop_unit_concept_id
                          } else {
                            "/"
                          },
                          url = athena_unit_url, include_colon = FALSE, is_editing = is_editing, ns = ns)
        )
      })
    }, ignoreInit = TRUE)
    
    ### c) ETL Guidance & Comments (Bottom-Left Panel) ----
    #### Comments & Statistical Summary Display ----
    # Render comments or statistical summary based on active tab
    observe_event(comments_display_trigger(), {
      concept_id <- selected_concept_id()
      if (!is.null(concept_id)) {
        output$comments_display <- renderUI({
          is_editing <- general_concept_detail_edit_mode()
          active_tab <- comments_tab()

          concept_info <- current_data()$general_concepts %>%
            dplyr::filter(general_concept_id == concept_id)

          # Display based on active tab
          if (active_tab == "comments") {
            # Comments tab
            if (is_editing) {
              # Edit mode: show textarea
              current_comment <- if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1])) {
                concept_info$comments[1]
              } else {
                ""
              }

              tags$div(
                style = "height: 100%;",
                shiny::textAreaInput(
                  ns("comments_input"),
                  label = NULL,
                  value = current_comment,
                  placeholder = "Enter ETL guidance and comments here...",
                  width = "100%",
                  height = "100%"
                )
              )
            } else {
              # View mode: show formatted comment
              if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
                # Convert markdown-style formatting to HTML
                comment_html <- concept_info$comments[1]
                # Convert **text** to <strong>text</strong>
                comment_html <- gsub("\\*\\*([^*]+)\\*\\*", "<strong>\\1</strong>", comment_html)
                # Convert *text* to <em>text</em>
                comment_html <- gsub("\\*([^*]+)\\*", "<em>\\1</em>", comment_html)
                # Wrap content in paragraph tags
                comment_html <- paste0("<p>", comment_html, "</p>")
                # Convert line breaks to paragraph breaks
                comment_html <- gsub("\n", "</p><p>", comment_html)

                tags$div(
                  class = "comments-container",
                  style = "background: #e6f3ff; border: 1px solid #0f60af; border-radius: 6px; padding: 15px; height: 100%; overflow-y: auto; box-sizing: border-box;",
                  HTML(comment_html)
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
              current_summary <- if (nrow(concept_info) > 0 && !is.na(concept_info$statistical_summary[1])) {
                concept_info$statistical_summary[1]
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
              # View mode: show statistical summary display
              summary_data <- NULL
              if (nrow(concept_info) > 0 && !is.na(concept_info$statistical_summary[1]) && nchar(concept_info$statistical_summary[1]) > 0) {
                summary_data <- jsonlite::fromJSON(concept_info$statistical_summary[1])
              }

              if (!is.null(summary_data)) {
                # Display statistical summary in 2-column layout
                tags$div(
                  style = "height: 100%; overflow-y: auto; padding: 15px; background: #ffffff;",
                  tags$div(
                    style = "display: grid; grid-template-columns: 1fr 1fr; gap: 20px;",

                    # Left Column
                    tags$div(
                      # Data Types Section
                      tags$h5(style = "margin: 0 0 12px 0; color: #0f60af; font-size: 14px; font-weight: 600; border-bottom: 2px solid #0f60af; padding-bottom: 6px;", "Data Types"),
                      if (!is.null(summary_data$data_types) && length(summary_data$data_types) > 0) {
                        tags$div(
                          style = "margin-bottom: 20px;",
                          create_detail_item("Types", paste(summary_data$data_types, collapse = ", "))
                        )
                      } else {
                        tags$p(style = "color: #6c757d; font-style: italic; margin-bottom: 20px;", "No data types specified")
                      },

                      # Statistical Data Section
                      tags$h5(style = "margin: 20px 0 12px 0; color: #0f60af; font-size: 14px; font-weight: 600; border-bottom: 2px solid #0f60af; padding-bottom: 6px;", "Statistical Data"),
                      if (!is.null(summary_data$statistical_data) && length(summary_data$statistical_data) > 0) {
                        tagList(
                          lapply(names(summary_data$statistical_data), function(key) {
                            value <- summary_data$statistical_data[[key]]
                            create_detail_item(gsub("_", " ", tools::toTitleCase(key)), if (is.null(value)) "/" else value)
                          })
                        )
                      } else {
                        tags$p(style = "color: #6c757d; font-style: italic;", "No statistical data available")
                      }
                    ),

                    # Right Column
                    tags$div(
                      # Temporal Information Section
                      tags$h5(style = "margin: 0 0 12px 0; color: #0f60af; font-size: 14px; font-weight: 600; border-bottom: 2px solid #0f60af; padding-bottom: 6px;", "Temporal Information"),
                      if (!is.null(summary_data$temporal_info)) {
                        tagList(
                          if (!is.null(summary_data$temporal_info$frequency_range)) {
                            tagList(
                              create_detail_item("Frequency Min", if (is.null(summary_data$temporal_info$frequency_range$min)) "/" else summary_data$temporal_info$frequency_range$min),
                              create_detail_item("Frequency Max", if (is.null(summary_data$temporal_info$frequency_range$max)) "/" else summary_data$temporal_info$frequency_range$max)
                            )
                          },
                          if (!is.null(summary_data$temporal_info$measurement_period) && length(summary_data$temporal_info$measurement_period) > 0) {
                            create_detail_item("Measurement Period", paste(summary_data$temporal_info$measurement_period, collapse = ", "))
                          } else {
                            create_detail_item("Measurement Period", "/")
                          }
                        )
                      } else {
                        tags$p(style = "color: #6c757d; font-style: italic;", "No temporal information available")
                      },

                      # Possible Values Section
                      tags$h5(style = "margin: 20px 0 12px 0; color: #0f60af; font-size: 14px; font-weight: 600; border-bottom: 2px solid #0f60af; padding-bottom: 6px;", "Possible Values"),
                      if (!is.null(summary_data$possible_values) && length(summary_data$possible_values) > 0) {
                        tags$div(
                          style = "margin-top: 8px;",
                          tags$ul(
                            style = "margin: 0; padding-left: 20px;",
                            lapply(summary_data$possible_values, function(val) {
                              tags$li(style = "color: #212529; padding: 2px 0;", val)
                            })
                          )
                        )
                      } else {
                        tags$p(style = "color: #6c757d; font-style: italic;", "No possible values specified")
                      }
                    )
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
    
    # Handle toggle recommended for mappings in detail edit mode
    observe_event(input$toggle_recommended, {
      if (!general_concept_detail_edit_mode()) return()

      toggle_data <- input$toggle_recommended
      # Create unique ID based on is_custom flag
      if (toggle_data$is_custom) {
        concept_unique_id <- paste0("custom-", toggle_data$custom_id)
      } else {
        concept_unique_id <- paste0("omop-", toggle_data$omop_id)
      }
      new_value <- toggle_data$new_value

      # Store the change in edited_recommended
      current_edits <- edited_recommended()
      current_edits[[concept_unique_id]] <- (new_value == "Yes")
      edited_recommended(current_edits)
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
    #### Tab Switching ----
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
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    #### Relationship Tab Outputs ----
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
        return(DT::datatable(data.frame(Message = "No related concepts found."),
                             options = list(dom = 't'),
                             rownames = FALSE,
                             selection = 'none'))
      }

      # Reorder columns: relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id (hidden)
      related_concepts <- related_concepts %>%
        dplyr::select(relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id)

      DT::datatable(
        related_concepts,
        selection = 'none',
        rownames = FALSE,
        colnames = c("Relationship", "Concept Name", "Vocabulary", "Code", "OMOP ID"),
        options = list(
          pageLength = 6,
          dom = 'tip',
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
              "descendants"
            )
          )
        ),
        actionButton(
          ns("view_hierarchy_graph"),
          "View Graph",
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
        return(DT::datatable(data.frame(Message = "No descendant concepts found in hierarchy."),
                             options = list(dom = 't'),
                             rownames = FALSE,
                             selection = 'none'))
      }

      # Reorder columns: relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id (hidden)
      descendant_concepts <- descendant_concepts %>%
        dplyr::select(relationship_id, concept_name, vocabulary_id, concept_code, omop_concept_id)

      DT::datatable(
        descendant_concepts,
        selection = 'none',
        rownames = FALSE,
        colnames = c("Relationship", "Concept Name", "Vocabulary", "Code", "OMOP ID"),
        options = list(
          pageLength = 6,
          dom = 'tip',
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
        return(DT::datatable(data.frame(Message = "No synonyms found for this concept."),
                             options = list(dom = 't'),
                             rownames = FALSE,
                             selection = 'none'))
      }

      # Select only synonym and language columns (hide language_concept_id)
      synonyms <- synonyms %>%
        dplyr::select(synonym, language, language_concept_id)

      DT::datatable(
        synonyms,
        selection = 'none',
        rownames = FALSE,
        colnames = c("Synonym", "Language", "Language ID"),
        options = list(
          pageLength = 6,
          dom = 'tip',
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
          "Concept Hierarchy:"
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

    #### Hierarchy Graph Fullscreen Modal ----
    # Observe view graph button click
    observe_event(input$view_hierarchy_graph, {
      omop_concept_id <- selected_mapped_concept_id()
      req(omop_concept_id)
      
      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("hierarchy_graph_modal")))
      
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
    
    #### Concept Details Modal (Double-click on Related/Hierarchy) ----
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
        create_detail_item("Concept Name", info$concept_name, include_colon = FALSE),
        create_detail_item("Category", info$domain_id, include_colon = FALSE),
        create_detail_item("Sub-category", info$concept_class_id, include_colon = FALSE),
        create_detail_item("Validity", validity_text, color = validity_color, include_colon = FALSE),
        create_detail_item("Standard", standard_text, color = standard_color, include_colon = FALSE),
        tags$div(class = "detail-item", style = "visibility: hidden;"),
        # Column 2
        create_detail_item("Vocabulary ID", info$vocabulary_id, include_colon = FALSE),
        create_detail_item("Domain ID", info$domain_id, include_colon = FALSE),
        create_detail_item("Concept Code", info$concept_code, include_colon = FALSE),
        create_detail_item("OMOP Concept ID", info$concept_id, url = athena_url, include_colon = FALSE),
        if (!is.null(fhir_url)) {
          if (fhir_url == "no_link") {
            tags$div(
              class = "detail-item",
              tags$strong("FHIR Resource"),
              tags$span(
                style = "color: #999; font-style: italic;",
                "No link available"
              )
            )
          } else {
            tags$div(
              class = "detail-item",
              tags$strong("FHIR Resource"),
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
    }, ignoreNULL = FALSE)
  })
}
