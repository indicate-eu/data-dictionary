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
                # List view normal buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("list_normal_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("show_add_concept_modal"), "Add concept", class = "btn-success-custom"),
                    actionButton(ns("show_list_history"), "History", class = "btn-secondary-custom"),
                    actionButton(ns("list_edit_page"), "Edit page", class = "btn-primary-custom")
                  )
                ),
                # List view edit buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("list_edit_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("list_cancel"), "Cancel", class = "btn-secondary-custom"),
                    actionButton(ns("list_save_updates"), "Save updates", class = "btn-success-custom")
                  )
                ),
                # Detail view normal buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("detail_action_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("show_history"), "History", class = "btn-secondary-custom"),
                    actionButton(ns("edit_page"), "Edit page", class = "btn-toggle")
                  )
                ),
                # Detail view edit buttons
                shinyjs::hidden(
                  tags$div(
                    id = ns("detail_edit_buttons"),
                    style = "display: flex; gap: 10px;",
                    actionButton(ns("cancel_edit"), "Cancel", class = "btn-cancel"),
                    actionButton(ns("save_updates"), "Save updates", class = "btn-toggle")
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
              # General Concepts table container
              tags$div(
                id = ns("general_concepts_container"),
                class = "table-container",
                style = "height: calc(100vh - 175px); overflow: auto;",

                # Loading message
                shinyjs::hidden(
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
                        onclick = "$('#nav_settings').click(); $('#settings_dropdown').show(); setTimeout(function() { $('#settings_dropdown .settings-dropdown-item:first').click(); }, 100);",
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

              # Concept details container
              shinyjs::hidden(
                tags$div(
                  id = ns("concept_details_container"),
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
                            uiOutput(ns("concept_details_display")),
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

              # History container for individual concept
              shinyjs::hidden(
                tags$div(
                  id = ns("history_container"),
                  uiOutput(ns("history_ui"))
                )
              ),

              # List history container for all concepts
              shinyjs::hidden(
                tags$div(
                  id = ns("list_history_container"),
                  uiOutput(ns("list_history_ui"))
                )
              )
            )
        )
    ),

    ## UI - Modals ----
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

    ### Modal - Add New Concept ----
    tags$div(
      id = ns("add_concept_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("add_concept_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 600px;",
        tags$div(
          class = "modal-header",
          tags$h3("Add New Concept"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("add_concept_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$div(
            id = ns("new_concept_name_group"),
            style = "margin-bottom: 20px;",
            tags$label(
              "General Concept Name",
              style = "display: block; font-weight: 600; margin-bottom: 8px;"
            ),
            shiny::textInput(
              ns("new_concept_name"),
              label = NULL,
              placeholder = "Enter concept name",
              width = "100%"
            )
          ),
          tags$div(
            id = ns("new_concept_category_group"),
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
                  ns("new_concept_category"),
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
                  ns("new_concept_category_text"),
                  label = NULL,
                  placeholder = "Enter new category",
                  width = "100%"
                )
              ),
              tags$button(
                id = ns("toggle_category_mode"),
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
                ", ns("category_select_container"), ns("category_text_container"), ns("toggle_category_mode")),
                "+"
              )
            )
          ),
          tags$div(
            id = ns("new_concept_subcategory_group"),
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
                  ns("new_concept_subcategory"),
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
                  ns("new_concept_subcategory_text"),
                  label = NULL,
                  placeholder = "Enter new subcategory",
                  width = "100%"
                )
              ),
              tags$button(
                id = ns("toggle_subcategory_mode"),
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
                ", ns("subcategory_select_container"), ns("subcategory_text_container"), ns("toggle_subcategory_mode")),
                "+"
              )
            )
          ),
          tags$div(
            style = "display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; padding-top: 20px; border-top: 1px solid #dee2e6;",
            tags$button(
              class = "btn btn-secondary btn-secondary-custom",
              onclick = sprintf("$('#%s').hide();", ns("add_concept_modal")),
              "Cancel"
            ),
            actionButton(
              ns("add_new_concept"),
              "Add Concept",
              class = "btn-primary-custom"
            )
          )
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
          visNetwork::visNetworkOutput(ns("hierarchy_graph"), height = "100%", width = "100%")
        )
      )
    ),

    ### Modal - Add Concept to Mapping (OMOP Search) ----
    tags$div(
      id = ns("add_concept_to_mapping_modal"),
      style = "display: none; position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0, 0, 0, 0.5); z-index: 9999;",
      onclick = sprintf("if (event.target === this) { $('#%s').css('display', 'none'); }", ns("add_concept_to_mapping_modal")),
      tags$div(
        style = "position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 95vw; height: 95vh; background: white; border-radius: 8px; display: flex; flex-direction: column;",
        onclick = "event.stopPropagation();",

        # Header
        tags$div(
          style = "padding: 20px; border-bottom: 1px solid #ddd; flex-shrink: 0; background: #f8f9fa;",
          tags$h3("Add Concept to Mapping", style = "margin: 0; display: inline-block;"),
          tags$button(
            style = "float: right; background: none; border: none; font-size: 28px; cursor: pointer;",
            onclick = sprintf("$('#%s').css('display', 'none');", ns("add_concept_to_mapping_modal")),
            "×"
          )
        ),

        # Body
        tags$div(
          style = "flex: 1; min-height: 0; padding: 20px; display: flex; flex-direction: column; gap: 15px;",

          # Search OMOP Concepts section (top half)
          tags$div(
            style = "flex: 1; min-height: 0; display: flex; flex-direction: column;",
            tags$div(
              style = "flex: 1; min-height: 0; overflow: auto;",
              shinycssloaders::withSpinner(
                DT::DTOutput(ns("omop_concepts_table")),
                type = 4,
                color = "#0f60af"
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
                uiOutput(ns("add_modal_concept_details"))
              )
            ),

            # Descendants (right)
            tags$div(
              style = "flex: 1; min-height: 0; display: flex; flex-direction: column; border: 1px solid #ddd; border-radius: 4px; padding: 15px; background: white;",
              tags$h5("Descendants", style = "margin-top: 0; margin-bottom: 10px;"),
              tags$div(
                style = "flex: 1; min-height: 0; overflow: hidden;",
                DT::DTOutput(ns("add_modal_descendants_table"))
              )
            )
          ),

          # Bottom buttons
          tags$div(
            style = "display: flex; justify-content: flex-end; align-items: center; gap: 15px; flex-shrink: 0;",
            tags$div(
              style = "margin-bottom: 0;",
              shiny::checkboxInput(
                ns("add_modal_include_descendants"),
                "Include descendants",
                value = FALSE,
                width = NULL
              )
            ),
            tags$button(
              class = "btn btn-default",
              onclick = sprintf("$('#%s').css('display', 'none');", ns("add_concept_to_mapping_modal")),
              "Cancel"
            ),
            shiny::actionButton(
              ns("add_selected_concept"),
              "Add Concept",
              class = "btn btn-success"
            )
          )
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
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ## Server - Reactive Values & State ----
    ### View & Selection State ----
    current_view <- reactiveVal("list")  # "list", "detail", "detail_history", or "list_history"
    selected_concept_id <- reactiveVal(NULL)
    selected_mapped_concept_id <- reactiveVal(NULL)  # Track selected concept in mappings table
    relationships_tab <- reactiveVal("related")  # Track active tab: "related", "hierarchy", "synonyms"
    comments_tab <- reactiveVal("comments")  # Track active tab: "comments", "statistical_summary"
    modal_concept_id <- reactiveVal(NULL)  # Track concept ID for modal display
    selected_categories <- reactiveVal(character(0))  # Track selected category filters

    ### Edit Mode State ----
    edit_mode <- reactiveVal(FALSE)  # Track edit mode state for detail view
    saved_table_page <- reactiveVal(0)  # Track datatable page for edit mode restoration
    list_edit_mode <- reactiveVal(FALSE)  # Track edit mode state for list view
    saved_table_search <- reactiveVal(NULL)  # Track datatable search state for edit mode
    edited_recommended <- reactiveVal(list())  # Store recommended changes by omop_concept_id
    deleted_concepts <- reactiveVal(list())  # Store deleted concept IDs by general_concept_id
    original_general_concepts <- reactiveVal(NULL)  # Store original state for cancel in list edit mode
    add_modal_selected_concept <- reactiveVal(NULL)  # Store selected concept in add modal

    ### Data Management ----
    local_data <- reactiveVal(NULL)  # Local copy of data that can be updated

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

    ## Server - Navigation & Events ----
    
    ### Buttons visibility ----
    update_button_visibility <- function() {
      user <- current_user()
      view <- current_view()
      
      # Use shinyjs::delay to ensure DOM is ready
      shinyjs::delay(100, {
        # First hide all buttons
        shinyjs::hide("list_normal_buttons")
        shinyjs::hide("list_edit_buttons")
        shinyjs::hide("detail_action_buttons")
        shinyjs::hide("detail_edit_buttons")
        shinyjs::hide("back_buttons")
        
        # Then show only the relevant buttons based on user AND view
        if (!is.null(user) && user$role != "Anonymous") {
          
          if (view == "list") {
            # Show list normal buttons (not edit buttons - those are shown when clicking Edit page)
            if (!list_edit_mode()) {
              shinyjs::show("list_normal_buttons")
            } else {
              shinyjs::show("list_edit_buttons")
            }
          } else if (view == "list_history") {
            # Show back button (first button in back_buttons)
            shinyjs::runjs(sprintf("$('#%s button:first').show();", ns("back_buttons")))
            shinyjs::runjs(sprintf("$('#%s button:last').hide();", ns("back_buttons")))
            shinyjs::show("back_buttons")
          } else if (view == "detail") {
            # Show detail normal buttons (not edit buttons - those are shown when clicking Edit page)
            if (!edit_mode()) {
              shinyjs::show("detail_action_buttons")
            } else {
              shinyjs::show("detail_edit_buttons")
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
      } else if (loading_status == "not_loaded" || loading_status == "error" || is.null(vocab_data)) {
        # Show error message, hide table and loading
        shinyjs::hide("vocab_loading_message")
        shinyjs::show("vocab_error_message")
        shinyjs::hide("general_concepts_table")
      } else {
        # Show table, hide loading and error
        shinyjs::hide("vocab_loading_message")
        shinyjs::hide("vocab_error_message")
        shinyjs::show("general_concepts_table")
      }
    }, ignoreNULL = FALSE, ignoreInit = FALSE)
    
    ### Breadcrumb Rendering ----
    observe_event(c(current_view(), edit_mode(), list_edit_mode()), {
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
    }, ignoreNULL = FALSE)
    
    # Render header buttons for mapped concepts based on edit mode
    observe_event(edit_mode(), {
      output$mapped_concepts_header_buttons <- renderUI({
        if (edit_mode()) {
          tags$div(
            style = "margin-left: auto; display: flex; gap: 5px;",
            tags$button(
              class = "btn btn-success btn-sm",
              onclick = sprintf("$('#%s').css('display', 'flex'); setTimeout(function() { $(window).trigger('resize'); }, 100);", ns("add_concept_to_mapping_modal")),
              tags$i(class = "fa fa-plus"),
              " Add Concept"
            ),
            shiny::actionButton(
              ns("reset_mapped_concepts"),
              label = NULL,
              icon = icon("refresh"),
              class = "btn btn-warning btn-sm",
              title = "Reset mapped concepts for this general concept"
            )
          )
        }
      })
    }, ignoreNULL = FALSE, ignoreInit = FALSE)
    
    ### Category Filtering ----
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
    
    ### View Switching (List/Detail/History) ----
    
    # Define all containers
    all_containers <- c("general_concepts_container", "concept_details_container", "history_container", "list_history_container")
    
    # Map views to their visible containers
    view_containers <- list(
      list = "general_concepts_container",
      detail = "concept_details_container",
      detail_history = "history_container",
      list_history = "list_history_container"
    )
    
    # Handle view changes: update buttons, containers, and render history UIs
    observe_event(current_view(), {
      view <- current_view()
      
      # 1. Update button visibility
      update_button_visibility()
      
      # 2. Hide all containers and show the current one
      lapply(all_containers, function(id) shinyjs::hide(id = id))
      if (!is.null(view_containers[[view]])) {
        shinyjs::show(id = view_containers[[view]])
      }
      
      # 3. Render list history UI if needed
      if (view == "list_history") {
        output$list_history_ui <- renderUI({
          tags$div(
            style = "height: calc(100vh - 175px); overflow: auto; padding: 20px;",
            # Blank content for now
            tags$div(
              style = "padding: 20px; background: #f8f9fa; border-radius: 8px; text-align: center; color: #666;",
              tags$p("History view for all general concepts will be implemented here.")
            )
          )
        })
      }
    }, ignoreNULL = FALSE)

    # Render detail history page when view is detail_history and concept is selected
    observe_event(c(current_view(), selected_concept_id()), {
      if (current_view() == "detail_history" && !is.null(selected_concept_id())) {
        concept_id <- selected_concept_id()
        general_concepts <- current_data()$general_concepts
        concept_info <- general_concepts %>% dplyr::filter(general_concept_id == concept_id)
        
        output$history_ui <- renderUI(
          tags$div(
            style = "height: calc(100vh - 175px); overflow: auto; padding: 20px;",
            # Blank content for now
            tags$div(
              style = "padding: 20px; background: #f8f9fa; border-radius: 8px; text-align: center; color: #666;",
              tags$p("History view will be implemented here.")
            )
          )
        )
      }
    }, ignoreNULL = FALSE)

    ## Server - List View ----
    ### General Concepts Table Rendering ----
    observe_event(c(current_data(), list_edit_mode(), selected_categories()), {
      output$general_concepts_table <- DT::renderDT({

      general_concepts <- current_data()$general_concepts

      # Prepare table data
      table_data <- general_concepts %>%
        dplyr::mutate(
          # Always keep as factor to preserve dropdown filters
          category = factor(category),
          subcategory = factor(subcategory),
          actions = if (list_edit_mode()) {
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
      if (list_edit_mode()) {
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
      dt$x$options$drawCallback <- htmlwidgets::JS(sprintf("
        function(settings) {
          var table = this.api();

          // Remove existing handlers to avoid duplicates
          $(table.table().node()).off('click', '.view-details-btn');
          $(table.table().node()).off('click', '.delete-concept-btn');
          $(table.table().node()).off('dblclick', 'tbody tr');

          // Add click handler for View Details button
          $(table.table().node()).on('click', '.view-details-btn', function(e) {
            e.stopPropagation();
            var conceptId = $(this).data('id');
            Shiny.setInputValue('%s', conceptId, {priority: 'event'});
          });

          // Add click handler for Delete button
          $(table.table().node()).on('click', '.delete-concept-btn', function(e) {
            e.stopPropagation();
            var conceptId = $(this).data('id');
            Shiny.setInputValue('%s', conceptId, {priority: 'event'});
          });

          // Add double-click handler for table rows (only when not in edit mode)
          if (!%s) {
            $(table.table().node()).on('dblclick', 'tbody tr', function() {
              var rowData = table.row(this).data();
              if (rowData && rowData[0]) {
                var conceptId = rowData[0];
                Shiny.setInputValue('%s', conceptId, {priority: 'event'});
              }
            });
          }
        }
      ", ns("view_concept_details"), ns("delete_general_concept"),
         tolower(as.character(list_edit_mode())), ns("view_concept_details")))

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
      edit_mode(FALSE)  # Exit edit mode when going back to list
      list_edit_mode(FALSE)  # Exit list edit mode when going back to list
    })

    # Handle list history button
    observe_event(input$show_list_history, {
      current_view("list_history")
    })

    # Handle back to list from history button
    observe_event(input$back_to_list_from_history, {
      current_view("list")
    })

    # Handle list edit page button
    observe_event(input$list_edit_page, {
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

      list_edit_mode(TRUE)

      # Update button visibility will be triggered automatically by list_edit_mode() change
      update_button_visibility()

      # Wait for datatable to re-render, then restore state
      shiny::observe({
        if (!list_edit_mode()) return()

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
      }) %>% shiny::bindEvent(input$general_concepts_table_state, once = TRUE)
    })

    # Handle list cancel button
    observe_event(input$list_cancel, {
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
      list_edit_mode(FALSE)

      # Update button visibility
      update_button_visibility()

      # Wait for datatable to re-render, then restore state
      shiny::observe({
        if (list_edit_mode()) return()

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
      }) %>% shiny::bindEvent(input$general_concepts_table_state, once = TRUE)
    })

    ### List Edit Mode ----
    observe_event(input$list_save_updates, {
      if (!list_edit_mode()) return()

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

      list_edit_mode(FALSE)
      original_general_concepts(NULL)

      # Update button visibility
      update_button_visibility()

      # Wait for datatable to re-render, then restore state
      shiny::observe({
        if (list_edit_mode()) return()

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
      }) %>% shiny::bindEvent(input$general_concepts_table_state, once = TRUE)
    })

    # Handle cell edits in general concepts table
    observe_event(input$general_concepts_table_cell_edit, {
      if (!list_edit_mode()) return()

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
      if (!list_edit_mode()) return()

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
        shiny::observe({
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
            page_length <- input$general_concepts_table_state$length
            max_page <- ceiling(total_rows / page_length)

            # If current page no longer exists, go to last page
            target_page <- min(page_num, max_page)
            DT::selectPage(proxy, target_page)
          }
        }) %>% shiny::bindEvent(input$general_concepts_table_state, once = TRUE)
      }
    })

    ### Add New Concept Modal ----
    # Handle show add concept modal button
    observe_event(input$show_add_concept_modal, {
      # Update category choices
      general_concepts <- current_data()$general_concepts
      categories <- sort(unique(general_concepts$category))

      updateSelectizeInput(session, "new_concept_category", choices = categories, selected = character(0))
      updateSelectizeInput(session, "new_concept_subcategory", choices = character(0), selected = character(0))

      # Show the custom modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("add_concept_modal")))
    })

    # Update subcategories when category changes in add concept modal
    observe_event(input$new_concept_category, {
      if (is.null(input$new_concept_category) || identical(input$new_concept_category, "")) {
        return()
      }

      general_concepts <- current_data()$general_concepts
      selected_category <- input$new_concept_category

      # Get subcategories for the selected category
      subcategories_for_category <- general_concepts %>%
        dplyr::filter(category == selected_category) %>%
        dplyr::pull(subcategory) %>%
        unique() %>%
        sort()

      # Update subcategory choices
      updateSelectizeInput(
        session,
        "new_concept_subcategory",
        choices = subcategories_for_category,
        server = TRUE
      )
    }, ignoreInit = TRUE)

    # Handle add new concept
    observe_event(input$add_new_concept, {
      # Determine which category/subcategory field is active
      category <- if (!is.null(input$new_concept_category_text) && nchar(trimws(input$new_concept_category_text)) > 0) {
        input$new_concept_category_text
      } else {
        input$new_concept_category
      }

      subcategory <- if (!is.null(input$new_concept_subcategory_text) && nchar(trimws(input$new_concept_subcategory_text)) > 0) {
        input$new_concept_subcategory_text
      } else {
        input$new_concept_subcategory
      }

      concept_name <- input$new_concept_name

      # Validation with visual feedback
      has_error <- FALSE

      # Reset all borders first
      shinyjs::runjs(sprintf("
        document.getElementById('%s').style.border = '';
        $('#%s').parent().find('.selectize-control .selectize-input').css('border', '');
        document.getElementById('%s').style.border = '';
        $('#%s').parent().find('.selectize-control .selectize-input').css('border', '');
        document.getElementById('%s').style.border = '';
      ", ns("new_concept_name"), ns("new_concept_category"), ns("new_concept_category_text"), ns("new_concept_subcategory"), ns("new_concept_subcategory_text")))

      # Validate concept name
      if (is.null(concept_name) || nchar(trimws(concept_name)) == 0) {
        has_error <- TRUE
        shinyjs::runjs(sprintf("document.getElementById('%s').style.border = '2px solid #dc3545'", ns("new_concept_name")))
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
        ", ns("category_select_container"), ns("category_text_container"), ns("new_concept_category"), ns("new_concept_category_text")))
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
        ", ns("subcategory_select_container"), ns("subcategory_text_container"), ns("new_concept_subcategory"), ns("new_concept_subcategory_text")))
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
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("add_concept_modal")))

        # Reset input fields
        shiny::updateTextInput(session, "new_concept_name", value = "")
        shiny::updateTextInput(session, "new_concept_category_text", value = "")
        shiny::updateTextInput(session, "new_concept_subcategory_text", value = "")
        updateSelectizeInput(session, "new_concept_category", selected = character(0))
        updateSelectizeInput(session, "new_concept_subcategory", selected = character(0))

        # Calculate which page the new concept is on (1-indexed for DT::selectPage)
        page_length <- 25  # Default page length from datatable
        target_page <- ceiling(new_concept_row_index / page_length)

        # Use DT proxy to navigate to the correct page after a delay
        # This allows the table to re-render first
        shiny::observe({
          shiny::invalidateLater(100)
          proxy <- DT::dataTableProxy("general_concepts_table", session = session)
          DT::selectPage(proxy, target_page)
        })

        # Highlight the row with green fade effect
        # Row index in DataTable is 0-indexed
        dt_row_index <- new_concept_row_index - 1

        shinyjs::runjs(sprintf("
          setTimeout(function() {
            try {
              var tableElement = $('#%s');
              if (tableElement.length && $.fn.DataTable.isDataTable(tableElement)) {
                var table = tableElement.DataTable();
                var row = table.row(%d).node();
                if (row) {
                  $(row).css({
                    'background-color': '#28a745',
                    'transition': 'background-color 2s ease-out'
                  });

                  // Fade back to normal
                  setTimeout(function() {
                    $(row).css('background-color', '');
                  }, 100);
                }
              }
            } catch(e) {
              console.error('Row highlight error:', e);
            }
          }, 200);
        ", ns("general_concepts_table"), dt_row_index))
      }
    })

    # Handle edit page button
    observe_event(input$edit_page, {
      edit_mode(TRUE)
      update_button_visibility()
    })

    # Handle show history button
    observe_event(input$show_history, {
      current_view("detail_history")
    })

    # Handle back to detail button (from history view)
    observe_event(input$back_to_detail, {
      current_view("detail")
    })

    # Handle cancel edit button
    observe_event(input$cancel_edit, {
      # Reset all unsaved changes
      edited_recommended(list())
      deleted_concepts(list())
      # edited_comment(NULL)
      edit_mode(FALSE)
      # Reset tab to comments
      comments_tab("comments")
      # Hide edit buttons and show normal action buttons
      shinyjs::hide("detail_edit_buttons")
      shinyjs::show("detail_action_buttons")
    })

    ### Save Detail Updates ----
    # Handle save updates button
    observe_event(input$save_updates, {
      if (!edit_mode()) return()

      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      # Get current data
      general_concepts <- current_data()$general_concepts
      concept_mappings <- current_data()$concept_mappings

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
        # Validate JSON before saving
        is_valid_json <- tryCatch({
          jsonlite::fromJSON(new_statistical_summary)
          TRUE
        }, error = function(e) {
          FALSE
        })

        if (is_valid_json) {
          general_concepts <- general_concepts %>%
            dplyr::mutate(
              statistical_summary = ifelse(
                general_concept_id == concept_id,
                new_statistical_summary,
                statistical_summary
              )
            )
        }
      }

      # Apply concept deletions
      concept_deletions <- deleted_concepts()
      concept_key <- as.character(concept_id)

      if (!is.null(concept_deletions[[concept_key]])) {
        deleted_ids <- concept_deletions[[concept_key]]
        concept_mappings <- concept_mappings %>%
          dplyr::filter(!(general_concept_id == concept_id & omop_concept_id %in% deleted_ids))
      }

      # Update recommended values in concept_mappings
      recommended_edits <- edited_recommended()

      if (length(recommended_edits) > 0) {
        for (omop_id in names(recommended_edits)) {
          new_rec_value <- recommended_edits[[omop_id]]

          # Check if this concept already exists in concept_mappings
          existing_row <- concept_mappings %>%
            dplyr::filter(
              general_concept_id == concept_id &
              omop_concept_id == as.integer(omop_id)
            )

          if (nrow(existing_row) > 0) {
            # Update existing row
            concept_mappings <- concept_mappings %>%
              dplyr::mutate(
                recommended = ifelse(
                  general_concept_id == concept_id & omop_concept_id == as.integer(omop_id),
                  new_rec_value,
                  recommended
                )
              )
          } else if (isTRUE(new_rec_value)) {
            # Add new row only if recommended = TRUE
            # Get concept info from vocabularies or current data
            vocab_data <- vocabularies()

            if (!is.null(vocab_data) && !is.null(vocab_data$concept)) {
              tryCatch({
                # Filter and collect from DuckDB
                new_concept <- vocab_data$concept %>%
                  dplyr::filter(concept_id == as.integer(omop_id)) %>%
                  dplyr::collect()  # Materialize the data from DuckDB
              }, error = function(e) {
                new_concept <- data.frame()
              })

              if (nrow(new_concept) > 0) {
                # Create new row with minimal structure (new schema)
                if (nrow(concept_mappings) > 0) {
                  # Take first row as template and modify it
                  new_row <- concept_mappings[1, ]
                  new_row$general_concept_id <- as.integer(concept_id)
                  new_row$omop_concept_id <- as.integer(omop_id)
                  new_row$omop_unit_concept_id <- as.character("/")
                  new_row$recommended <- TRUE
                } else {
                  # Fallback if concept_mappings is empty
                  new_row <- data.frame(
                    general_concept_id = as.integer(concept_id),
                    omop_concept_id = as.integer(omop_id),
                    omop_unit_concept_id = "/",
                    recommended = TRUE,
                    stringsAsFactors = FALSE
                  )
                }

                concept_mappings <- dplyr::bind_rows(concept_mappings, new_row)
              }
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

      # Update local data
      updated_data <- list(
        general_concepts = general_concepts,
        concept_mappings = concept_mappings
      )
      local_data(updated_data)

      # Reset edit state
      edited_recommended(list())
      deleted_concepts(list())
      # edited_comment(NULL)
      edit_mode(FALSE)
      # Reset tab to comments
      comments_tab("comments")
      # Hide edit buttons and show normal action buttons
      shinyjs::hide("detail_edit_buttons")
      shinyjs::show("detail_action_buttons")
    })

    # Handle reset statistical summary button
    observe_event(input$reset_statistical_summary, {
      shinyAce::updateAceEditor(
        session,
        "statistical_summary_editor",
        value = get_default_statistical_summary_template()
      )
    })

    ### Detail Edit Mode ----
    # Handle toggle recommended in edit mode
    observe_event(input$toggle_recommended, {
      if (!edit_mode()) return()

      toggle_data <- input$toggle_recommended
      omop_id <- as.integer(toggle_data$omop_id)
      new_value <- toggle_data$new_value

      # Store the change in edited_recommended
      current_edits <- edited_recommended()
      current_edits[[as.character(omop_id)]] <- (new_value == "Yes")
      edited_recommended(current_edits)
    }, ignoreInit = TRUE)

    # Handle delete concept in edit mode
    observe_event(input$delete_concept, {
      if (!edit_mode()) return()

      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      delete_data <- input$delete_concept
      omop_id <- as.integer(delete_data$omop_id)

      # Track the deletion for this general_concept_id
      current_deletions <- deleted_concepts()
      concept_key <- as.character(concept_id)

      if (is.null(current_deletions[[concept_key]])) {
        current_deletions[[concept_key]] <- c(omop_id)
      } else {
        current_deletions[[concept_key]] <- unique(c(current_deletions[[concept_key]], omop_id))
      }

      deleted_concepts(current_deletions)
    }, ignoreInit = TRUE)

    # # Track comment changes in edit mode
    # observe_event(input$comments_input, {
    #   req(edit_mode())
    #   edited_comment(input$comments_input)
    # }, ignoreInit = TRUE)

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

    ## Server - Detail View ----
    ### Concept Details Rendering ----
    # Render comments or statistical summary based on active tab
    # Render comments display when concept, edit mode or tab changes
    observe_event(c(selected_concept_id(), edit_mode(), comments_tab(), local_data()), {
      concept_id <- selected_concept_id()
      if (!is.null(concept_id)) {
        output$comments_display <- renderUI({
          is_editing <- edit_mode()
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
                tryCatch({
                  summary_data <- jsonlite::fromJSON(concept_info$statistical_summary[1])
                }, error = function(e) {
                  summary_data <<- NULL
                })
              }

              if (!is.null(summary_data)) {
                # Helper function to create detail items
                create_detail_item <- function(label, value) {
                  display_value <- if (is.null(value) || (is.character(value) && value == "")) {
                    "/"
                  } else {
                    as.character(value)
                  }

                  tags$div(
                    class = "detail-item",
                    tags$strong(paste0(label, ":")),
                    tags$span(display_value)
                  )
                }

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
    }, ignoreNULL = FALSE)

    ## Server - Concept Mappings ----
    ### Mappings Table Rendering ----
    # Render concept mappings table when concept or edit mode changes
    observe_event(c(selected_concept_id(), edit_mode(), edited_recommended(), deleted_concepts()), {
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
      is_editing <- edit_mode()

      # Read directly from concept_mappings.csv
      csv_mappings <- current_data()$concept_mappings %>%
        dplyr::filter(general_concept_id == concept_id)

      # Read custom concepts
      custom_concepts_path <- app_sys("extdata", "csv", "custom_concepts.csv")
      if (file.exists(custom_concepts_path)) {
        custom_concepts <- readr::read_csv(custom_concepts_path, show_col_types = FALSE) %>%
          dplyr::filter(general_concept_id == concept_id) %>%
          dplyr::select(
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
        # Get concept details from OMOP
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
          dplyr::mutate(is_custom = FALSE)
      } else {
        # If no vocabulary data, add placeholder columns
        csv_mappings <- csv_mappings %>%
          dplyr::mutate(
            concept_name = NA_character_,
            vocabulary_id = NA_character_,
            concept_code = NA_character_,
            is_custom = FALSE
          )
      }

      # Combine OMOP and custom concepts
      all_concepts <- dplyr::bind_rows(
        csv_mappings %>%
          dplyr::select(concept_name, vocabulary_id, concept_code, omop_concept_id, recommended, is_custom),
        custom_concepts
      )

      # Select final columns and arrange
      mappings <- all_concepts %>%
        dplyr::select(
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
          mappings <- mappings %>%
            dplyr::filter(!omop_concept_id %in% deleted_ids)
        }
      }

      # Convert recommended to Yes/No or toggle
      if (nrow(mappings) > 0) {
        # Create toggle HTML for edit mode, or simple Yes/No for view mode
        if (is_editing) {
          mappings <- mappings %>%
            dplyr::mutate(
              recommended = sprintf(
                '<label class="toggle-switch" data-omop-id="%s"><input type="checkbox" %s><span class="toggle-slider"></span></label>',
                omop_concept_id,
                ifelse(recommended, 'checked', '')
              ),
              action = sprintf('<i class="fa fa-trash delete-icon" data-omop-id="%s" style="cursor: pointer; color: #dc3545;"></i>', omop_concept_id)
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
    }, ignoreNULL = FALSE)

    # Observe tab switching for relationships
    observe_event(input$switch_relationships_tab, {
      relationships_tab(input$switch_relationships_tab)
    })

    # Observe tab switching for comments
    observe_event(input$switch_comments_tab, {
      comments_tab(input$switch_comments_tab)
    })

    # Cache for current mappings to avoid recalculation
    current_mappings <- reactiveVal(NULL)

    # Debounce the table selection to avoid excessive updates when navigating with arrow keys
    debounced_selection <- debounce(
      reactive({
        input$concept_mappings_table_rows_selected
      }),
      300  # Wait 300ms after user stops navigating
    )

    ### Mappings Selection & Details ----
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

    # Render concept details when mapped concept is selected
    observe_event(c(selected_mapped_concept_id(), selected_concept_id()), {
      omop_concept_id <- selected_mapped_concept_id()
      concept_id <- selected_concept_id()

      output$concept_details_display <- renderUI({
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

        # Helper function to create detail items
        create_detail_item_ohdsi <- function(label, value, url = NULL, color = NULL) {
          display_value <- if (is.na(value) || is.null(value) || value == "") {
            "/"
          } else {
            as.character(value)
          }

          # Create link if URL provided
          if (!is.null(url) && display_value != "/") {
            display_value <- tags$a(
              href = url,
              target = "_blank",
              style = "color: #0f60af; text-decoration: underline;",
              display_value
            )
          } else if (!is.null(color) && display_value != "/") {
            # Apply color if specified
            display_value <- tags$span(
              style = paste0("color: ", color, "; font-weight: 600;"),
              display_value
            )
          }

          tags$div(
            class = "detail-item",
            tags$strong(label),
            tags$span(display_value)
          )
        }

        # Display full info for OHDSI-only concepts (with "/" for missing EHDEN/LOINC data)
        return(tags$div(
          class = "concept-details-container",
          style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(8, auto); grid-auto-flow: column; gap: 4px 15px;",
          # Column 1
          create_detail_item_ohdsi("Concept Name", info$concept_name),
          create_detail_item_ohdsi("Category",
                                   ifelse(nrow(general_concept_info) > 0,
                                         general_concept_info$category[1], NA)),
          create_detail_item_ohdsi("Sub-category",
                                   ifelse(nrow(general_concept_info) > 0,
                                         general_concept_info$subcategory[1], NA)),
          create_detail_item_ohdsi("EHDEN Data Sources", "/"),
          create_detail_item_ohdsi("EHDEN Rows Count", "/"),
          create_detail_item_ohdsi("LOINC Rank", "/"),
          create_detail_item_ohdsi("Validity", validity_text, color = validity_color),
          create_detail_item_ohdsi("Standard", standard_text, color = standard_color),
          # Column 2 (must have exactly 8 items)
          create_detail_item_ohdsi("Vocabulary ID", info$vocabulary_id),
          create_detail_item_ohdsi("Domain ID", if (!is.na(info$domain_id)) info$domain_id else "/"),
          create_detail_item_ohdsi("Concept Code", info$concept_code),
          create_detail_item_ohdsi("OMOP Concept ID", info$concept_id, url = athena_url),
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
          create_detail_item_ohdsi("Unit Concept Name", "/"),
          create_detail_item_ohdsi("OMOP Unit Concept ID", "/"),
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
      is_editing <- edit_mode()

      # Create detail items with proper formatting
      create_detail_item <- function(label, value, format_number = FALSE, url = NULL, color = NULL, editable = FALSE, input_id = NULL, step = 1) {
        # If editable and in edit mode, show numeric input
        if (editable && is_editing && !is.null(input_id)) {
          input_value <- if (is.null(value)) {
            NA
          } else if (length(value) == 0) {
            NA
          } else if (length(value) == 1 && is.na(value)) {
            NA
          } else if (identical(value, "")) {
            NA
          } else if (is.character(value)) {
            suppressWarnings(as.numeric(value))
          } else {
            as.numeric(value)
          }

          return(tags$div(
            class = "detail-item",
            tags$strong(label),
            tags$span(
              shiny::numericInput(
                ns(input_id),
                label = NULL,
                value = input_value,
                width = "100px",
                step = step
              )
            )
          ))
        }

        # Otherwise, display as read-only
        display_value <- if (is.null(value)) {
          "/"
        } else if (length(value) == 0) {
          "/"
        } else if (length(value) == 1 && is.na(value)) {
          "/"
        } else if (identical(value, "")) {
          "/"
        } else if (is.logical(value)) {
          if (isTRUE(value)) "Yes" else if (isFALSE(value)) "No" else "/"
        } else if (format_number && is.numeric(value)) {
          format(value, big.mark = ",", scientific = FALSE)
        } else {
          as.character(value)
        }

        # Create link if URL provided
        if (!is.null(url) && display_value != "/") {
          display_value <- tags$a(
            href = url,
            target = "_blank",
            style = "color: #0f60af; text-decoration: underline;",
            display_value
          )
        } else if (!is.null(color) && display_value != "/") {
          # Apply color if specified
          display_value <- tags$span(
            style = paste0("color: ", color, "; font-weight: 600;"),
            display_value
          )
        }

        tags$div(
          class = "detail-item",
          tags$strong(label),
          tags$span(display_value)
        )
      }

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
        create_detail_item("Concept Name", info$concept_name),
        create_detail_item("Category",
                          ifelse(nrow(general_concept_info) > 0,
                                general_concept_info$category[1], NA)),
        create_detail_item("Sub-category",
                          ifelse(nrow(general_concept_info) > 0,
                                general_concept_info$subcategory[1], NA)),
        create_detail_item("EHDEN Data Sources", info$ehden_num_data_sources, format_number = TRUE, editable = TRUE, input_id = "ehden_num_data_sources_input", step = 1),
        create_detail_item("EHDEN Rows Count", info$ehden_rows_count, format_number = TRUE, editable = TRUE, input_id = "ehden_rows_count_input", step = 1000),
        create_detail_item("LOINC Rank", info$loinc_rank, editable = TRUE, input_id = "loinc_rank_input", step = 1),
        create_detail_item("Validity", validity_text, color = validity_color),
        create_detail_item("Standard", standard_text, color = standard_color),
        # Column 2 (must have exactly 8 items)
        create_detail_item("Vocabulary ID", info$vocabulary_id),
        create_detail_item("Domain ID", if (!is.null(validity_info) && !is.na(validity_info$domain_id)) validity_info$domain_id else "/"),
        create_detail_item("Concept Code", info$concept_code),
        create_detail_item("OMOP Concept ID", info$omop_concept_id, url = athena_url),
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
                          }),
        create_detail_item("OMOP Unit Concept ID",
                          if (!is.null(info$omop_unit_concept_id) && !is.na(info$omop_unit_concept_id) && info$omop_unit_concept_id != "" && info$omop_unit_concept_id != "/") {
                            info$omop_unit_concept_id
                          } else {
                            "/"
                          },
                          url = athena_unit_url)
        )
      })
    }, ignoreNULL = FALSE)

    ## Server - Relationships Tab ----
    ### Tab Switching ----
    # Render concept relationships when tab changes
    observe_event(relationships_tab(), {
      output$concept_relationships_display <- renderUI({
        active_tab <- relationships_tab()

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
    }, ignoreNULL = FALSE)

    ### Related Concepts Table ----
    # Render related concepts table when concept is selected
    observe_event(selected_mapped_concept_id(), {
      omop_concept_id <- selected_mapped_concept_id()
      if (!is.null(omop_concept_id)) {
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
      }
    }, ignoreNULL = FALSE)

    ### Statistics Widgets ----
    # Render related concepts statistics widget
    observe_event(selected_mapped_concept_id(), {
      omop_concept_id <- selected_mapped_concept_id()
      if (!is.null(omop_concept_id)) {
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
      }
    }, ignoreNULL = FALSE)

    # Render hierarchy statistics widget
    observe_event(selected_mapped_concept_id(), {
      omop_concept_id <- selected_mapped_concept_id()
      if (!is.null(omop_concept_id)) {
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
      }
    }, ignoreNULL = FALSE)

    ### Hierarchy Concepts Table ----
    # Render hierarchy concepts table
    observe_event(selected_mapped_concept_id(), {
      omop_concept_id <- selected_mapped_concept_id()
      if (!is.null(omop_concept_id)) {
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
      }
    }, ignoreNULL = FALSE)

    ### Synonyms Table ----
    # Render synonyms table
    observe_event(selected_mapped_concept_id(), {
      omop_concept_id <- selected_mapped_concept_id()
      if (!is.null(omop_concept_id)) {
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
      }
    }, ignoreNULL = FALSE)

    ## Server - Modals Management ----
    ### Concept Details Modal ----
    # Observe modal_concept_id input and update reactiveVal
    observe_event(input$modal_concept_id, {
      modal_concept_id(input$modal_concept_id)
    }, ignoreNULL = TRUE, ignoreInit = FALSE)

    # Modal concept details
    # Render concept modal body when concept is selected
    observe_event(modal_concept_id(), {
      concept_id <- modal_concept_id()
      if (!is.null(concept_id)) {
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

      # Helper function to create detail items
      create_detail_item <- function(label, value, url = NULL, color = NULL) {
        display_value <- if (is.na(value) || is.null(value) || value == "") {
          "/"
        } else {
          as.character(value)
        }

        # Create link if URL provided
        if (!is.null(url) && display_value != "/") {
          display_value <- tags$a(
            href = url,
            target = "_blank",
            style = "color: #0f60af; text-decoration: underline;",
            display_value
          )
        } else if (!is.null(color)) {
          # Apply color if specified
          display_value <- tags$span(
            style = paste0("color: ", color, "; font-weight: 600;"),
            display_value
          )
        }

        tags$div(
          class = "detail-item",
          tags$strong(label),
          tags$span(display_value)
        )
      }

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
        create_detail_item("Concept Name", info$concept_name),
        create_detail_item("Category", info$domain_id),
        create_detail_item("Sub-category", info$concept_class_id),
        create_detail_item("Validity", validity_text, color = validity_color),
        create_detail_item("Standard", standard_text, color = standard_color),
        tags$div(class = "detail-item", style = "visibility: hidden;"),
        # Column 2
        create_detail_item("Vocabulary ID", info$vocabulary_id),
        create_detail_item("Domain ID", info$domain_id),
        create_detail_item("Concept Code", info$concept_code),
        create_detail_item("OMOP Concept ID", info$concept_id, url = athena_url),
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
      }
    }, ignoreNULL = FALSE)

    ### Hierarchy Graph ----
    # Render hierarchy graph breadcrumb
    observe_event(selected_mapped_concept_id(), {
      omop_concept_id <- selected_mapped_concept_id()
      if (!is.null(omop_concept_id)) {
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
      }
    }, ignoreNULL = FALSE)

    # Render hierarchy graph
    observe_event(selected_mapped_concept_id(), {
      omop_concept_id <- selected_mapped_concept_id()
      if (!is.null(omop_concept_id)) {
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
    }, ignoreNULL = FALSE)

    ### Hierarchy Graph Modal ----
    # Observe view graph button click
    observe_event(input$view_hierarchy_graph, {
      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("hierarchy_graph_modal")))

      # Fit the graph immediately
      visNetwork::visNetworkProxy(ns("hierarchy_graph")) %>%
        visNetwork::visFit(animation = list(duration = 500))
    })

    ### Add Concept Modal (OMOP Search) ----
    # Reactive value to store selected concept from modal
    modal_selected_concept <- reactiveVal(NULL)

    # Server-side DataTable for OMOP concepts
    output$modal_concepts_table <- DT::renderDT({
      vocab_data <- vocabularies()
      req(vocab_data)

      # Collect data from DuckDB first
      concept_data <- vocab_data$concept %>%
        dplyr::filter(
          vocabulary_id %in% c("RxNorm", "RxNorm Extension", "LOINC", "SNOMED", "ICD10"),
          is.na(invalid_reason)
        ) %>%
        dplyr::select(concept_id, concept_name, vocabulary_id, domain_id, concept_class_id) %>%
        dplyr::collect() %>%
        dplyr::mutate(
          vocabulary_id = factor(vocabulary_id),
          domain_id = factor(domain_id),
          concept_class_id = factor(concept_class_id)
        )

      # Create server-side processing
      DT::datatable(
        concept_data,
        selection = 'single',
        filter = 'top',
        rownames = FALSE,
        colnames = c("ID", "Concept Name", "Vocabulary", "Domain", "Class"),
        options = list(
          pageLength = 10,
          processing = TRUE,
          server = TRUE,
          dom = 'tp',  # Only table and pagination (no global search)
          ordering = TRUE,
          autoWidth = FALSE,
          columnDefs = list(
            list(width = '80px', targets = 0),
            list(width = '300px', targets = 1),
            list(width = '120px', targets = 2),
            list(width = '100px', targets = 3),
            list(width = '150px', targets = 4)
          )
        )
      )
    }, server = TRUE)

    # Observe modal table selection
    observe_event(input$modal_concepts_table_rows_selected, {
      if (is.null(input$modal_concepts_table_rows_selected)) return()

      vocab_data <- vocabularies()
      req(vocab_data)

      # Get selected row
      selected_row <- input$modal_concepts_table_rows_selected

      # Get concept details
      concept_data <- vocab_data$concept %>%
        dplyr::filter(
          vocabulary_id %in% c("RxNorm", "RxNorm Extension", "LOINC", "SNOMED", "ICD10"),
          is.na(invalid_reason)
        ) %>%
        dplyr::select(concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept) %>%
        dplyr::collect()

      if (selected_row <= nrow(concept_data)) {
        selected_concept <- concept_data[selected_row, ]
        modal_selected_concept(selected_concept)
      }
    })

    # Render modal concept details (using same format as Selected Concept Details)
    output$modal_concept_details <- renderUI({
      concept <- modal_selected_concept()

      if (is.null(concept) || nrow(concept) == 0) {
        return(tags$div(
          style = "padding: 20px; background: #f8f9fa; border-radius: 6px; text-align: center;",
          tags$p(
            style = "color: #666; font-style: italic;",
            "Select a concept from the table to view details."
          )
        ))
      }

      # Helper function to create detail items (same as concept_details_display)
      create_detail_item <- function(label, value) {
        display_value <- if (is.na(value) || is.null(value) || value == "") {
          "/"
        } else {
          as.character(value)
        }

        tags$div(
          class = "detail-item",
          tags$strong(label),
          tags$span(display_value)
        )
      }

      # Use grid layout like Selected Concept Details
      tags$div(
        class = "concept-details-container",
        style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(4, auto); grid-auto-flow: column; gap: 4px 15px;",
        # Column 1
        create_detail_item("Concept Name", concept$concept_name),
        create_detail_item("Vocabulary ID", concept$vocabulary_id),
        create_detail_item("Domain ID", concept$domain_id),
        create_detail_item("Concept Class", concept$concept_class_id),
        # Column 2
        create_detail_item("OMOP Concept ID", concept$concept_id),
        create_detail_item("Concept Code", concept$concept_code),
        create_detail_item("Standard", ifelse(is.na(concept$standard_concept), "No", concept$standard_concept)),
        tags$div()  # Empty slot to balance grid
      )
    })

    # Render descendants as DataTable
    output$modal_descendants_table <- DT::renderDT({
      concept <- modal_selected_concept()

      if (is.null(concept) || nrow(concept) == 0) {
        return(DT::datatable(
          data.frame(Message = "Select a concept to view descendants."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      vocab_data <- vocabularies()
      req(vocab_data)

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

      # Get concept details for descendants
      desc_concepts <- vocab_data$concept %>%
        dplyr::filter(
          concept_id %in% descendants$descendant_concept_id,
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
          dom = 'ftp',
          ordering = TRUE,
          autoWidth = FALSE,
          columnDefs = list(
            list(width = '80px', targets = 0),
            list(width = '250px', targets = 1),
            list(width = '100px', targets = 2)
          )
        ),
        colnames = c("ID", "Name", "Vocabulary")
      )
    })

    # Store all modal concepts
    modal_concepts_all <- reactive({
      vocab_data <- vocabularies()
      req(vocab_data)

      # Get ALL OMOP concepts (no limit)
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
          concept_code
        ) %>%
        dplyr::arrange(concept_name) %>%
        dplyr::collect()
    })

    # Render OMOP concepts table for adding to mapping (server-side)
    output$omop_concepts_table <- DT::renderDT({
      concepts <- modal_concepts_all()
      req(concepts)

      # Select only display columns (not concept_code for table)
      display_concepts <- concepts %>%
        dplyr::select(concept_id, concept_name, vocabulary_id, domain_id, concept_class_id)

      # Convert concept_id to character and other columns to factors for filtering
      display_concepts$concept_id <- as.character(display_concepts$concept_id)
      display_concepts$vocabulary_id <- as.factor(display_concepts$vocabulary_id)
      display_concepts$domain_id <- as.factor(display_concepts$domain_id)
      display_concepts$concept_class_id <- as.factor(display_concepts$concept_class_id)

      # Render DataTable with server-side processing
      DT::datatable(
        display_concepts,
        rownames = FALSE,
        selection = 'single',
        filter = 'top',
        options = list(
          pageLength = 8,
          dom = 'tp',
          ordering = TRUE,
          autoWidth = FALSE
        ),
        colnames = c("Concept ID", "Concept Name", "Vocabulary", "Domain", "Concept Class")
      )
    }, server = TRUE)

    # Force rendering even when hidden initially
    outputOptions(output, "omop_concepts_table", suspendWhenHidden = FALSE)

    # Track selected concept in add modal
    observe_event(input$omop_concepts_table_rows_selected, {
      selected_row <- input$omop_concepts_table_rows_selected

      if (length(selected_row) > 0) {
        all_concepts <- modal_concepts_all()
        req(all_concepts)

        # Get selected concept
        selected_concept <- all_concepts[selected_row, ]
        add_modal_selected_concept(selected_concept)
      } else {
        add_modal_selected_concept(NULL)
      }
    }, ignoreInit = TRUE)

    # Render concept details in add modal
    output$add_modal_concept_details <- renderUI({
      concept <- add_modal_selected_concept()

      if (is.null(concept)) {
        return(tags$div(
          style = "padding: 20px; background: #f8f9fa; border-radius: 6px; text-align: center;",
          tags$p(
            style = "color: #666; font-style: italic;",
            "Select a concept from the table to view details."
          )
        ))
      }

      # Helper function to create detail items (same as modal_concept_details)
      create_detail_item <- function(label, value) {
        display_value <- if (is.na(value) || is.null(value) || value == "") {
          "/"
        } else {
          as.character(value)
        }

        tags$div(
          class = "detail-item",
          tags$strong(label),
          tags$span(display_value)
        )
      }

      # Use grid layout like Selected Concept Details
      tags$div(
        class = "concept-details-container",
        style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(4, auto); grid-auto-flow: column; gap: 4px 15px;",
        # Column 1
        create_detail_item("Concept Name", concept$concept_name),
        create_detail_item("Vocabulary ID", concept$vocabulary_id),
        create_detail_item("Domain ID", concept$domain_id),
        create_detail_item("Concept Class", concept$concept_class_id),
        # Column 2
        create_detail_item("OMOP Concept ID", concept$concept_id),
        create_detail_item("Concept Code", concept$concept_code),
        tags$div(),  # Empty slot
        tags$div()   # Empty slot to balance grid
      )
    })

    # Render descendants table in add modal
    output$add_modal_descendants_table <- DT::renderDT({
      concept <- add_modal_selected_concept()

      if (is.null(concept)) {
        return(DT::datatable(
          data.frame(Message = "Select a concept to view descendants."),
          options = list(dom = 't'),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      vocab_data <- vocabularies()
      req(vocab_data)

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

    # Force rendering even when hidden
    outputOptions(output, "add_modal_concept_details", suspendWhenHidden = FALSE)
    outputOptions(output, "add_modal_descendants_table", suspendWhenHidden = FALSE)

    ### Add Mapping from Detail View ----
    # Add selected concept from new modal
    observe_event(input$add_selected_concept, {
      if (!edit_mode()) return()

      # Get selected row from omop_concepts_table
      selected_row <- input$omop_concepts_table_rows_selected
      req(selected_row)

      # Use cached concepts
      all_concepts <- modal_concepts_all()
      req(all_concepts)

      # Get the selected concept
      selected_concept <- all_concepts[selected_row, ]

      # Get current general concept
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      # Get concepts to add (including descendants if checked)
      concepts_to_add <- selected_concept$concept_id

      if (isTRUE(input$add_modal_include_descendants)) {
        vocab_data <- vocabularies()
        req(vocab_data)

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
            dplyr::select(concept_id) %>%
            dplyr::collect()

          concepts_to_add <- c(concepts_to_add, valid_descendants$concept_id)
        }
      }

      # Read current mappings
      concept_mappings_file <- app_sys("extdata", "csv", "concept_mappings.csv")

      if (file.exists(concept_mappings_file)) {
        concept_mappings <- readr::read_csv(concept_mappings_file, show_col_types = FALSE)
        # Rename is_recommended to recommended for consistency with UI
        if ("is_recommended" %in% names(concept_mappings)) {
          names(concept_mappings)[names(concept_mappings) == "is_recommended"] <- "recommended"
        }
      } else {
        concept_mappings <- data.frame(
          general_concept_id = integer(),
          omop_concept_id = integer(),
          recommended = logical()
        )
      }

      # Add new mappings for all concepts
      new_mappings <- data.frame(
        general_concept_id = rep(concept_id, length(concepts_to_add)),
        omop_concept_id = concepts_to_add,
        recommended = FALSE
      )

      concept_mappings <- dplyr::bind_rows(concept_mappings, new_mappings) %>%
        dplyr::distinct()

      # Rename back to is_recommended for CSV
      concept_mappings_to_save <- concept_mappings
      if ("recommended" %in% names(concept_mappings_to_save)) {
        names(concept_mappings_to_save)[names(concept_mappings_to_save) == "recommended"] <- "is_recommended"
      }

      # Save mappings
      readr::write_csv(concept_mappings_to_save, concept_mappings_file)

      # Reload data - update the entire local_data object
      current_data <- local_data()
      current_data$concept_mappings <- concept_mappings
      local_data(current_data)

      # Close modal
      shinyjs::runjs(sprintf("$('#%s').css('display', 'none');", ns("add_concept_to_mapping_modal")))
    }, ignoreInit = TRUE)

    # Confirm add OMOP concept
    observe_event(input$confirm_add_omop_concept, {
      concept <- modal_selected_concept()
      if (is.null(concept)) return()

      selected_concept_row <- selected_concept_reactive()
      req(selected_concept_row)

      general_concept_id <- selected_concept_row$general_concept_id

      vocab_data <- vocabularies()
      req(vocab_data)

      # Get concepts to add
      concepts_to_add <- concept$concept_id

      # Include descendants if checked
      if (isTRUE(input$include_descendants)) {
        descendants <- vocab_data$concept_ancestor %>%
          dplyr::filter(ancestor_concept_id == concept$concept_id) %>%
          dplyr::select(descendant_concept_id) %>%
          dplyr::collect()

        if (nrow(descendants) > 0) {
          # Filter valid descendants
          valid_descendants <- vocab_data$concept %>%
            dplyr::filter(
              concept_id %in% descendants$descendant_concept_id,
              is.na(invalid_reason)
            ) %>%
            dplyr::pull(concept_id) %>%
            unique()

          concepts_to_add <- c(concepts_to_add, valid_descendants)
        }
      }

      # Add to concept_mappings
      concept_mappings <- current_data()$concept_mappings

      new_mappings <- data.frame(
        general_concept_id = general_concept_id,
        omop_concept_id = concepts_to_add,
        omop_unit_concept_id = "/",
        recommended = TRUE,
        stringsAsFactors = FALSE
      )

      # Filter out already existing mappings
      existing_keys <- concept_mappings %>%
        dplyr::mutate(key = paste(general_concept_id, omop_concept_id, sep = "_")) %>%
        dplyr::pull(key)

      new_mappings <- new_mappings %>%
        dplyr::mutate(key = paste(general_concept_id, omop_concept_id, sep = "_")) %>%
        dplyr::filter(!key %in% existing_keys) %>%
        dplyr::select(-key)

      if (nrow(new_mappings) > 0) {
        concept_mappings <- dplyr::bind_rows(concept_mappings, new_mappings)

        # Save to CSV
        readr::write_csv(
          concept_mappings,
          app_sys("extdata", "csv", "concept_mappings.csv")
        )

        # Update local data
        updated_data <- current_data()
        updated_data$concept_mappings <- concept_mappings
        local_data(updated_data)

        shinyjs::hide(ns("add_concept_to_mapping_modal"))
        modal_selected_concept(NULL)
      }
    })

    # Confirm add custom concept
    observe_event(input$confirm_add_custom_concept, {
      # Validate concept name is not empty
      concept_name <- trimws(input$custom_concept_name)
      if (is.null(concept_name) || concept_name == "") {
        shinyjs::show("custom_concept_name_error")
        shinyjs::runjs(sprintf("$('#%s').closest('.form-group').addClass('has-error');", ns("custom_concept_name")))
        return()
      }

      # Hide error if validation passes
      shinyjs::hide("custom_concept_name_error")
      shinyjs::runjs(sprintf("$('#%s').closest('.form-group').removeClass('has-error');", ns("custom_concept_name")))

      general_concept_id <- selected_concept_id()
      req(general_concept_id)

      # Load custom_concepts
      custom_concepts_path <- app_sys("extdata", "csv", "custom_concepts.csv")

      if (file.exists(custom_concepts_path)) {
        custom_concepts <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
      } else {
        custom_concepts <- data.frame(
          general_concept_id = integer(),
          vocabulary_id = character(),
          concept_code = character(),
          concept_name = character(),
          omop_unit_concept_id = character(),
          recommended = logical(),
          stringsAsFactors = FALSE
        )
      }

      # Create new custom concept
      new_custom <- data.frame(
        general_concept_id = general_concept_id,
        vocabulary_id = input$custom_vocabulary_id,
        concept_code = ifelse(nchar(trimws(input$custom_concept_code)) > 0 && trimws(input$custom_concept_code) != "/", trimws(input$custom_concept_code), "/"),
        concept_name = concept_name,
        omop_unit_concept_id = "/",
        recommended = input$custom_recommended,
        stringsAsFactors = FALSE
      )

      # Check for duplicates
      existing <- custom_concepts %>%
        dplyr::filter(
          general_concept_id == new_custom$general_concept_id,
          concept_name == new_custom$concept_name
        )

      if (nrow(existing) > 0) {
        return()
      }

      # Add to custom_concepts
      custom_concepts <- dplyr::bind_rows(custom_concepts, new_custom)

      # Save to CSV
      readr::write_csv(custom_concepts, custom_concepts_path)

      # Close modal and reset
      shinyjs::hide(ns("add_concept_to_mapping_modal"))

      # Reset inputs
      shiny::updateTextInput(session, "custom_concept_name", value = "")
      shiny::updateTextInput(session, "custom_concept_code", value = "/")
    })

    # Reset mapped concepts - re-enrich from recommended concepts
    observe_event(input$reset_mapped_concepts, {
      if (!edit_mode()) return()

      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return()

      vocab_data <- vocabularies()
      if (is.null(vocab_data)) {
        return()
      }

      # Get current concept_mappings
      concept_mappings <- current_data()$concept_mappings

      # Get only the recommended mappings for this concept (these are the source)
      recommended_mappings <- concept_mappings %>%
        dplyr::filter(
          general_concept_id == concept_id,
          recommended == TRUE
        )

      if (nrow(recommended_mappings) == 0) {
        return()
      }

      # Remove all existing mappings for this concept
      concept_mappings <- concept_mappings %>%
        dplyr::filter(general_concept_id != concept_id)

      # Re-add recommended mappings
      concept_mappings <- dplyr::bind_rows(concept_mappings, recommended_mappings)

      # Define allowed vocabularies
      ALLOWED_VOCABS <- c("RxNorm", "RxNorm Extension", "LOINC", "SNOMED", "ICD10")

      # For each recommended mapping, enrich with related concepts
      for (i in seq_len(nrow(recommended_mappings))) {
        mapping <- recommended_mappings[i, ]
        source_concept_id <- mapping$omop_concept_id
        unit_concept_id <- mapping$omop_unit_concept_id

        # Get vocabulary info
        concept_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == source_concept_id) %>%
          dplyr::select(vocabulary_id) %>%
          dplyr::collect()

        if (nrow(concept_info) == 0) next

        source_vocab <- concept_info$vocabulary_id[1]

        if (!(source_vocab %in% ALLOWED_VOCABS)) next

        # Get relationships and descendants
        step1_rels <- vocab_data$concept_relationship %>%
          dplyr::filter(
            concept_id_1 == source_concept_id,
            relationship_id %in% c("Maps to", "Mapped from")
          ) %>%
          dplyr::select(concept_id_2) %>%
          dplyr::collect()

        step1_descs <- vocab_data$concept_ancestor %>%
          dplyr::filter(ancestor_concept_id == source_concept_id) %>%
          dplyr::select(descendant_concept_id) %>%
          dplyr::collect()

        step1_concepts <- unique(c(step1_rels$concept_id_2, step1_descs$descendant_concept_id))

        # Filter to same vocabulary and valid concepts
        if (length(step1_concepts) > 0) {
          step1_filtered <- vocab_data$concept %>%
            dplyr::filter(
              concept_id %in% step1_concepts,
              vocabulary_id == source_vocab,
              is.na(invalid_reason)
            ) %>%
            dplyr::filter(domain_id != "Drug" | concept_class_id == "Clinical Drug") %>%
            dplyr::select(concept_id) %>%
            dplyr::collect() %>%
            dplyr::pull(concept_id)
        } else {
          step1_filtered <- integer(0)
        }

        new_concept_ids <- step1_filtered

        # Create new mappings
        if (length(new_concept_ids) > 0) {
          new_rows <- data.frame(
            general_concept_id = concept_id,
            omop_concept_id = new_concept_ids,
            omop_unit_concept_id = unit_concept_id,
            recommended = FALSE,
            stringsAsFactors = FALSE
          )

          # Filter out already existing mappings
          existing_keys <- concept_mappings %>%
            dplyr::mutate(key = paste(general_concept_id, omop_concept_id, sep = "_")) %>%
            dplyr::pull(key)

          new_rows <- new_rows %>%
            dplyr::mutate(key = paste(general_concept_id, omop_concept_id, sep = "_")) %>%
            dplyr::filter(!key %in% existing_keys) %>%
            dplyr::select(-key)

          if (nrow(new_rows) > 0) {
            concept_mappings <- dplyr::bind_rows(concept_mappings, new_rows)
          }
        }
      }

      # Save to CSV
      readr::write_csv(
        concept_mappings,
        app_sys("extdata", "csv", "concept_mappings.csv")
      )

      # Update local data
      updated_data <- current_data()
      updated_data$concept_mappings <- concept_mappings
      local_data(updated_data)
    })

    # Handle mode switching in Add Concept modal
    observe_event(input$concept_source_mode, {
      if (input$concept_source_mode == "omop") {
        shinyjs::runjs(sprintf("
          $('#%s').css('display', 'flex');
          $('#%s').css('display', 'none');
        ", ns("omop_mode_content"), ns("custom_mode_content")))
      } else {
        shinyjs::runjs(sprintf("
          $('#%s').css('display', 'none');
          $('#%s').css('display', 'block');
        ", ns("omop_mode_content"), ns("custom_mode_content")))
      }
    })

    # Cancel buttons
    observe_event(input$cancel_add_concept_mapping, {
      shinyjs::hide(ns("add_concept_to_mapping_modal"))
      modal_selected_concept(NULL)
    })

    observe_event(input$cancel_add_custom_concept_mapping, {
      shinyjs::hide(ns("add_concept_to_mapping_modal"))
      shiny::updateTextInput(session, "custom_concept_name", value = "")
      shiny::updateTextInput(session, "custom_concept_code", value = "/")
    })

    # Note: outputOptions moved inside observe_event blocks where outputs are created
    # to avoid errors when outputs don't exist yet
  })
}
