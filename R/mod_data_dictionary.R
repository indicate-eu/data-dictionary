# MODULE STRUCTURE OVERVIEW ====
#
# This module provides the Data Dictionary interface for browsing and managing concept sets.
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Full-width panel with concept sets DataTable
#   ## UI - Modals
#      ### Modal - Add/Edit Concept Set
#      ### Modal - Delete Confirmation
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### Permissions
#      ### Data
#      ### Triggers
#      ### Edit State
#
#   ## 2) Server - Data Loading
#      ### Load Concept Sets
#
#   ## 3) Server - Table Rendering
#      ### Concept Sets Table
#
#   ## 4) Server - CRUD Operations
#      ### Add Concept Set
#      ### Edit Concept Set
#      ### Delete Concept Set

# UI SECTION ====

#' Data Dictionary Module - UI
#'
#' @param id Module ID
#' @param i18n Translator object
#'
#' @return Shiny UI elements
#' @noRd
mod_data_dictionary_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    tags$div(
      class = "main-panel",
      tags$div(
        class = "main-content",

        ## UI - Main Layout ----

        ### Concept Sets List Container ----
        tags$div(
          id = ns("concept_sets_list_container"),
          style = "height: 100%;",
          create_page_layout(
            "full",
            create_panel(
              title = i18n$t("concept_sets"),
              content = tags$div(
                style = "position: relative; height: 100%; display: flex; flex-direction: column;",
                tags$div(
                  id = ns("concept_sets_fuzzy_search_container"),
                  fuzzy_search_ui("fuzzy_search", ns = ns, i18n = i18n)
                ),
                uiOutput(ns("concept_sets_table_container"), style = "flex: 1;"),
                # Hidden download link for export all
                tags$div(
                  style = "position: absolute; left: -9999px;",
                  downloadLink(ns("download_all_concept_sets"), "Download")
                )
              ),
              tooltip = i18n$t("concept_sets_tooltip"),
              header_extra = tagList(
                shinyjs::hidden(
                  actionButton(
                    ns("import_concept_sets"),
                    i18n$t("import_zip"),
                    class = "btn-purple-custom",
                    icon = icon("upload"),
                    title = i18n$t("import_zip_tooltip")
                  )
                ),
                shinyjs::hidden(
                  actionButton(
                    ns("export_all_concept_sets"),
                    i18n$t("export_all"),
                    class = "btn-primary-custom",
                    icon = icon("download"),
                    title = i18n$t("export_all_tooltip")
                  )
                ),
                shinyjs::hidden(
                  actionButton(
                    ns("filter_concept_sets"),
                    i18n$t("filters"),
                    class = "btn-secondary-custom",
                    icon = icon("filter")
                  )
                ),
                shinyjs::hidden(
                  actionButton(
                    ns("add_concept_set"),
                    i18n$t("add_concept_set"),
                    class = "btn-success-custom ",
                    icon = icon("plus")
                  )
                )
              )
            )
          )
        ),

        ### Concept Set Details Container ----
        shinyjs::hidden(
          tags$div(
            id = ns("concept_set_details_container"),
            style = "height: 100%;",
            create_page_layout(
              "full",
              create_panel(
                title = NULL,
                content = tagList(
                  # Header with back button + concept set name on left, tabs on right
                  tags$div(
                    class = "detail-header",

                    # Left side: back button + concept set name + edit button
                    tags$div(
                      class = "detail-header-left",
                      actionButton(
                        ns("back_to_list"),
                        label = NULL,
                        icon = icon("arrow-left"),
                        class = "btn-back-discrete",
                        title = i18n$t("concept_sets")
                      ),
                      tags$span(
                        id = ns("concept_set_detail_title"),
                        class = "project-name-badge",
                        title = "",
                        ""
                      ),
                      # Version and status badges (next to title)
                      tags$span(
                        id = ns("concept_set_badges"),
                        class = "concept-set-badges",
                        ""
                      ),
                      # Export button (visible by default in view mode)
                      shinyjs::hidden(
                        actionButton(
                          ns("export_concept_set_btn"),
                          i18n$t("export"),
                          icon = icon("download"),
                          class = "btn-primary-custom"
                        )
                      ),
                      # Edit button (visible by default in view mode)
                      shinyjs::hidden(
                        actionButton(
                          ns("edit_concepts_btn"),
                          i18n$t("edit_page"),
                          icon = icon("edit"),
                          class = "btn-secondary-custom"
                        )
                      ),
                      # Save and Cancel buttons (hidden by default, shown in edit mode)
                      shinyjs::hidden(
                        tags$div(
                          id = ns("edit_mode_buttons"),
                          class = "flex-gap-8",
                          actionButton(
                            ns("cancel_edit_concepts"),
                            i18n$t("cancel"),
                            class = "btn-secondary-custom ",
                            icon = icon("times")
                          ),
                          actionButton(
                            ns("save_edit_concepts"),
                            i18n$t("save"),
                            class = "btn-primary-custom ",
                            icon = icon("save")
                          )
                        )
                      )
                    ),

                    # Right side: custom tabs (blue style)
                    tags$div(
                      class = "detail-header-tabs",
                      actionButton(
                        ns("tab_concepts"),
                        label = tagList(tags$i(class = "fas fa-list"), i18n$t("concepts")),
                        class = "tab-btn-blue active"
                      ),
                      actionButton(
                        ns("tab_comments"),
                        label = tagList(tags$i(class = "fas fa-comment"), i18n$t("comments")),
                        class = "tab-btn-blue"
                      ),
                      actionButton(
                        ns("tab_stats"),
                        label = tagList(tags$i(class = "fas fa-chart-bar"), i18n$t("statistics")),
                        class = "tab-btn-blue"
                      ),
                      actionButton(
                        ns("tab_review"),
                        label = tagList(tags$i(class = "fas fa-clipboard-check"), i18n$t("review")),
                        class = "tab-btn-blue"
                      )
                    )
                  ),

                  # Tab content panels
                  tags$div(
                    class = "detail-tab-content",

                    # Concepts Tab Panel (active by default)
                    tags$div(
                      id = ns("panel_concepts"),
                      class = "detail-tab-panel active",
                      tags$div(
                        class = "settings-backup-container concepts-layout",

                        # Left: Concepts section
                        tags$div(
                          id = ns("concepts_section_left"),
                          class = "settings-section settings-backup-section expandable-section",
                          # Section header with title and action buttons
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-list", style = "margin-right: 8px; color: #0f60af;"),
                            i18n$t("concepts"),
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = as.character(i18n$t("concepts_in_set_tooltip")),
                              HTML("&#x3f;")
                            ),
                            # Action buttons (hidden by default, shown in edit mode)
                            shinyjs::hidden(
                              tags$span(
                                id = ns("concepts_edit_buttons"),
                                class = "flex-gap-5",
                                style = "float: right;",
                                actionButton(
                                  ns("select_all_concepts"),
                                  NULL,
                                  class = "btn-secondary-custom btn-sm",
                                  icon = icon("check-square"),
                                  title = "Select all"
                                ),
                                actionButton(
                                  ns("unselect_all_concepts"),
                                  NULL,
                                  class = "btn-secondary-custom btn-sm",
                                  icon = icon("square"),
                                  title = "Unselect all"
                                ),
                                actionButton(
                                  ns("delete_selected_concepts"),
                                  i18n$t("delete"),
                                  class = "btn-danger-custom btn-sm",
                                  icon = icon("trash")
                                ),
                                actionButton(
                                  ns("add_concepts_btn"),
                                  i18n$t("add_concepts"),
                                  class = "btn-success-custom btn-sm",
                                  icon = icon("plus")
                                )
                              )
                            ),
                            # Fullscreen toggle button
                            tags$button(
                              id = ns("expand_concepts"),
                              class = "btn-expand-section",
                              title = "Expand",
                              tags$i(class = "fas fa-expand")
                            )
                          ),
                          tags$div(
                            style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                            tags$div(
                              id = ns("concepts_fuzzy_search_container"),
                              fuzzy_search_ui("concepts_fuzzy_search", ns = ns, i18n = i18n)
                            ),
                            uiOutput(ns("concepts_table_container"))
                          )
                        ),

                        # Top-right: Selected concept details
                        tags$div(
                          id = ns("concepts_section_details"),
                          class = "settings-section settings-backup-section expandable-section",
                          tags$h4(
                            class = "settings-section-title settings-section-title-success",
                            tags$i(class = "fas fa-info-circle", style = "margin-right: 8px; color: #28a745;"),
                            i18n$t("selected_concept_details"),
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = as.character(i18n$t("selected_concept_details_tooltip")),
                              HTML("&#x3f;")
                            ),
                            # Fullscreen toggle button
                            tags$button(
                              id = ns("expand_details"),
                              class = "btn-expand-section",
                              title = "Expand",
                              tags$i(class = "fas fa-expand")
                            )
                          ),
                          tags$div(
                            style = "flex: 1; overflow: auto;",
                            uiOutput(ns("selected_concept_details"))
                          )
                        ),

                        # Bottom-right: Related concepts with sub-tabs
                        tags$div(
                          id = ns("concepts_section_related"),
                          class = "settings-section settings-backup-section expandable-section",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-link", style = "margin-right: 8px; color: #0f60af;"),
                            i18n$t("related_concepts"),
                            tags$span(
                              class = "info-icon",
                              `data-tooltip` = as.character(i18n$t("related_concepts_tooltip")),
                              HTML("&#x3f;")
                            ),
                            tags$span(
                              class = "section-tabs",
                              actionButton(
                                ns("subtab_related"),
                                i18n$t("related"),
                                class = "tab-btn-blue active"
                              ),
                              actionButton(
                                ns("subtab_hierarchy"),
                                i18n$t("hierarchy"),
                                class = "tab-btn-blue"
                              ),
                              actionButton(
                                ns("subtab_synonyms"),
                                i18n$t("synonyms"),
                                class = "tab-btn-blue"
                              ),
                              # Fullscreen toggle button (inside section-tabs)
                              tags$button(
                                id = ns("expand_related"),
                                class = "btn-expand-section",
                                title = "Expand",
                                tags$i(class = "fas fa-expand")
                              )
                            )
                          ),
                          # Related tab content
                          tags$div(
                            id = ns("related_tab_content"),
                            style = "flex: 1; overflow: auto;",
                            uiOutput(ns("related_display"))
                          ),
                          # Hierarchy tab content (hidden by default)
                          shinyjs::hidden(
                            tags$div(
                              id = ns("hierarchy_tab_content"),
                              style = "flex: 1; overflow: visible;",
                              uiOutput(ns("hierarchy_display"))
                            )
                          ),
                          # Synonyms tab content (hidden by default)
                          shinyjs::hidden(
                            tags$div(
                              id = ns("synonyms_tab_content"),
                              style = "flex: 1; overflow: auto;",
                              uiOutput(ns("synonyms_display"))
                            )
                          )
                        )
                      )
                    ),

                    # Comments Tab Panel
                    tags$div(
                      id = ns("panel_comments"),
                      class = "detail-tab-panel",
                      tags$div(
                        class = "settings-backup-container",
                        # View mode section
                        tags$div(
                          id = ns("comments_view_section"),
                          class = "settings-section settings-backup-section",
                          style = "width: 100%; max-width: 100%;",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-comment", style = "margin-right: 8px; color: #0f60af;"),
                            i18n$t("comments")
                          ),
                          uiOutput(ns("comments_display"))
                        ),
                        # Edit mode sections
                        tags$div(
                          id = ns("comments_edit_section"),
                          class = "settings-backup-container concepts-layout",
                          style = "display: none;",
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
                                  ns("comments_editor"),
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
                              "Preview"
                            ),
                            tags$div(
                              style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                              tags$div(
                                style = "flex: 1; overflow: auto; padding: 10px;",
                                uiOutput(ns("comments_preview"))
                              )
                            )
                          )
                        )
                      )
                    ),

                    # Statistics Tab Panel
                    tags$div(
                      id = ns("panel_stats"),
                      class = "detail-tab-panel",
                      # View mode section - Grid layout (3 panels)
                      tags$div(
                        id = ns("stats_view_section"),
                        class = "settings-backup-container statistics-layout",

                        # Top-left: Distribution (boxplot + stats)
                        tags$div(
                          id = ns("stats_distribution_panel"),
                          class = "settings-section settings-backup-section expandable-section",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-chart-bar", style = "margin-right: 8px; color: #0f60af;"),
                            "Distribution",
                            # Profile selector (will be populated dynamically)
                            uiOutput(ns("stats_profile_selector"), inline = TRUE)
                          ),
                          tags$div(
                            style = "flex: 1; overflow: auto;",
                            uiOutput(ns("stats_distribution_content"))
                          )
                        ),

                        # Top-right: Histogram
                        tags$div(
                          id = ns("stats_histogram_panel"),
                          class = "settings-section settings-backup-section expandable-section",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-chart-area", style = "margin-right: 8px; color: #0f60af;"),
                            "Histogram"
                          ),
                          tags$div(
                            style = "flex: 1; overflow: auto;",
                            uiOutput(ns("stats_histogram_content"))
                          )
                        ),

                        # Bottom-left: Other information (formerly Summary)
                        tags$div(
                          id = ns("stats_info_panel"),
                          class = "settings-section settings-backup-section expandable-section",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-info-circle", style = "margin-right: 8px; color: #0f60af;"),
                            "Other information"
                          ),
                          tags$div(
                            style = "flex: 1; overflow: auto;",
                            uiOutput(ns("stats_info_content"))
                          )
                        )
                      ),
                      # Edit mode section
                      tags$div(
                        id = ns("stats_edit_section"),
                        class = "settings-backup-container",
                        style = "display: none;",
                        # Error message
                        tags$div(
                          id = ns("stats_json_error"),
                          class = "input-error-message",
                          style = "display: none; margin-bottom: 10px;"
                        ),
                        # JSON editor
                        tags$div(
                          class = "settings-section settings-backup-section expandable-section",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-code", style = "margin-right: 8px; color: #0f60af;"),
                            "JSON Editor"
                          ),
                          tags$div(
                            style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                            tags$div(
                              style = "flex: 1; overflow: hidden;",
                              shinyAce::aceEditor(
                                ns("stats_editor"),
                                mode = "json",
                                theme = "chrome",
                                height = "100%",
                                fontSize = 12,
                                autoScrollEditorIntoView = TRUE
                              )
                            )
                          )
                        )
                      )
                    ),

                    # Review Tab Panel
                    tags$div(
                      id = ns("panel_review"),
                      class = "detail-tab-panel",
                      tags$div(
                        class = "settings-backup-container",
                        tags$div(
                          class = "settings-section settings-backup-section",
                          style = "width: 100%; max-width: 100%;",
                          tags$h4(
                            class = "settings-section-title",
                            style = "display: flex; align-items: center; justify-content: space-between;",
                            tags$span(
                              style = "display: flex; align-items: center;",
                              tags$i(class = "fas fa-clipboard-check", style = "margin-right: 8px; color: #0f60af;"),
                              i18n$t("review"),
                              tags$span(
                                class = "info-icon",
                                `data-tooltip` = as.character(i18n$t("review_desc")),
                                HTML("&#x3f;")
                              )
                            ),
                            actionButton(
                              ns("add_review_btn"),
                              i18n$t("add_review"),
                              class = "tab-btn-green",
                              icon = icon("plus")
                            )
                          ),
                          # Review list
                          tags$div(
                            uiOutput(ns("reviews_table_container"))
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

        ### Modal - Add/Edit Concept Set ----
        create_modal(
          id = "concept_set_modal",
          title = i18n$t("add_concept_set"),
          body = tagList(
            # Hidden field to store editing ID
            shinyjs::hidden(
              textInput(ns("editing_concept_set_id"), label = NULL, value = "")
            ),
            # Name (required)
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("name"), tags$span(class = "text-danger", " *")),
              textInput(ns("concept_set_name"), label = NULL, placeholder = i18n$t("enter_name")),
              tags$div(id = ns("name_error"), class = "input-error-message", style = "display: none;")
            ),
            # Description (single line, full width)
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("description")),
              textInput(ns("concept_set_description"), label = NULL, placeholder = i18n$t("enter_description"))
            ),
            # Category and Subcategory (side by side with toggle for new)
            tags$div(
              class = "mb-15 category-subcategory-row",
              # Category
              tags$div(
                class = "category-subcategory-col",
                tags$label(class = "form-label", i18n$t("category")),
                tags$div(
                  class = "input-with-toggle",
                  tags$div(
                    id = ns("category_select_container"),
                    class = "input-container",
                    selectizeInput(
                      ns("concept_set_category"),
                      label = NULL,
                      choices = character(0),
                      selected = character(0),
                      options = list(placeholder = as.character(i18n$t("select_category")))
                    )
                  ),
                  tags$div(
                    id = ns("category_text_container"),
                    class = "input-container",
                    style = "display: none;",
                    textInput(ns("concept_set_category_new"), label = NULL, placeholder = i18n$t("enter_new_category"))
                  ),
                  # Button to switch to add mode (visible when dropdown is shown)
                  tags$button(
                    id = ns("category_show_add"),
                    class = "btn-toggle-input",
                    title = as.character(i18n$t("add")),
                    onclick = sprintf("
                      document.getElementById('%s').style.display = 'none';
                      document.getElementById('%s').style.display = 'block';
                      document.getElementById('%s').style.display = 'none';
                      document.getElementById('%s').style.display = 'flex';
                      document.getElementById('%s').querySelector('input').focus();
                    ", ns("category_select_container"), ns("category_text_container"),
                       ns("category_show_add"), ns("category_add_buttons"), ns("category_text_container")),
                    "+"
                  ),
                  # Buttons for add mode (hidden initially)
                  tags$div(
                    id = ns("category_add_buttons"),
                    class = "toggle-buttons-group",
                    style = "display: none;",
                    tags$button(
                      id = ns("category_confirm_add"),
                      class = "btn-toggle-input btn-toggle-confirm",
                      title = as.character(i18n$t("add")),
                      onclick = sprintf("Shiny.setInputValue('%s', Date.now(), {priority: 'event'});", ns("confirm_add_category")),
                      "+"
                    ),
                    tags$button(
                      id = ns("category_cancel_add"),
                      class = "btn-toggle-input btn-toggle-cancel",
                      title = as.character(i18n$t("cancel")),
                      onclick = sprintf("
                        document.getElementById('%s').style.display = 'block';
                        document.getElementById('%s').style.display = 'none';
                        document.getElementById('%s').style.display = 'block';
                        document.getElementById('%s').style.display = 'none';
                        document.getElementById('%s').querySelector('input').value = '';
                        Shiny.setInputValue('%s', '', {priority: 'event'});
                      ", ns("category_select_container"), ns("category_text_container"),
                         ns("category_show_add"), ns("category_add_buttons"),
                         ns("category_text_container"), ns("concept_set_category_new")),
                      HTML("&times;")
                    )
                  )
                )
              ),
              # Subcategory
              tags$div(
                class = "category-subcategory-col",
                tags$label(class = "form-label", i18n$t("subcategory")),
                tags$div(
                  class = "input-with-toggle",
                  tags$div(
                    id = ns("subcategory_select_container"),
                    class = "input-container",
                    selectizeInput(
                      ns("concept_set_subcategory"),
                      label = NULL,
                      choices = character(0),
                      selected = character(0),
                      options = list(placeholder = as.character(i18n$t("first_select_category")))
                    )
                  ),
                  tags$div(
                    id = ns("subcategory_text_container"),
                    class = "input-container",
                    style = "display: none;",
                    textInput(ns("concept_set_subcategory_new"), label = NULL, placeholder = i18n$t("enter_new_subcategory"))
                  ),
                  # Button to switch to add mode (visible when dropdown is shown)
                  tags$button(
                    id = ns("subcategory_show_add"),
                    class = "btn-toggle-input",
                    title = as.character(i18n$t("add")),
                    onclick = sprintf("
                      document.getElementById('%s').style.display = 'none';
                      document.getElementById('%s').style.display = 'block';
                      document.getElementById('%s').style.display = 'none';
                      document.getElementById('%s').style.display = 'flex';
                      document.getElementById('%s').querySelector('input').focus();
                    ", ns("subcategory_select_container"), ns("subcategory_text_container"),
                       ns("subcategory_show_add"), ns("subcategory_add_buttons"), ns("subcategory_text_container")),
                    "+"
                  ),
                  # Buttons for add mode (hidden initially)
                  tags$div(
                    id = ns("subcategory_add_buttons"),
                    class = "toggle-buttons-group",
                    style = "display: none;",
                    tags$button(
                      id = ns("subcategory_confirm_add"),
                      class = "btn-toggle-input btn-toggle-confirm",
                      title = as.character(i18n$t("add")),
                      onclick = sprintf("Shiny.setInputValue('%s', Date.now(), {priority: 'event'});", ns("confirm_add_subcategory")),
                      "+"
                    ),
                    tags$button(
                      id = ns("subcategory_cancel_add"),
                      class = "btn-toggle-input btn-toggle-cancel",
                      title = as.character(i18n$t("cancel")),
                      onclick = sprintf("
                        document.getElementById('%s').style.display = 'block';
                        document.getElementById('%s').style.display = 'none';
                        document.getElementById('%s').style.display = 'block';
                        document.getElementById('%s').style.display = 'none';
                        document.getElementById('%s').querySelector('input').value = '';
                        Shiny.setInputValue('%s', '', {priority: 'event'});
                      ", ns("subcategory_select_container"), ns("subcategory_text_container"),
                         ns("subcategory_show_add"), ns("subcategory_add_buttons"),
                         ns("subcategory_text_container"), ns("concept_set_subcategory_new")),
                      HTML("&times;")
                    )
                  )
                )
              )
            ),
            # Tags (dropdown with badges)
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("tags")),
              tags$div(
                class = "input-with-toggle",
                tags$div(
                  class = "input-container",
                  selectizeInput(
                    ns("concept_set_tags"),
                    label = NULL,
                    choices = character(0),
                    selected = character(0),
                    multiple = TRUE,
                    options = list(
                      placeholder = as.character(i18n$t("select_tags")),
                      plugins = list("remove_button")
                    )
                  )
                ),
                tags$button(
                  id = ns("manage_tags_btn"),
                  class = "btn-toggle-input btn-toggle-settings",
                  title = as.character(i18n$t("manage_tags")),
                  onclick = sprintf("Shiny.setInputValue('%s', Date.now(), {priority: 'event'});", ns("open_manage_tags")),
                  tags$i(class = "fas fa-cog")
                )
              )
            )
          ),
          footer = tagList(
            actionButton(ns("cancel_concept_set"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("save_concept_set"), i18n$t("add"), class = "btn-primary-custom", icon = icon("plus"))
          ),
          size = "medium",
          icon = "fas fa-folder-open",
          ns = ns
        ),

        ### Modal - Manage Tags ----
        create_modal(
          id = "manage_tags_modal",
          title = i18n$t("manage_tags"),
          body = tagList(
            # Add new tag
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("add_new_tag")),
              tags$div(
                class = "add-tag-row",
                tags$div(
                  class = "add-tag-name",
                  textInput(ns("new_tag_name"), label = NULL, placeholder = i18n$t("enter_tag_name"))
                ),
                tags$div(
                  class = "add-tag-color",
                  create_color_picker(id = "new_tag_color", value = "#6c757d", ns = ns)
                ),
                actionButton(ns("add_new_tag"), i18n$t("add"), class = "btn-success-custom", icon = icon("plus"))
              ),
              tags$div(id = ns("new_tag_error"), class = "input-error-message", style = "display: none;")
            ),
            # Existing tags list
            tags$div(
              tags$label(class = "form-label", i18n$t("existing_tags")),
              DT::DTOutput(ns("tags_table"))
            )
          ),
          footer = tagList(
            actionButton(ns("close_manage_tags"), i18n$t("close"), class = "btn-secondary-custom", icon = icon("times"))
          ),
          size = "medium",
          icon = "fas fa-tags",
          ns = ns
        ),

        ### Modal - Edit Tag ----
        create_modal(
          id = "edit_tag_modal",
          title = i18n$t("edit_tag"),
          body = tagList(
            shinyjs::hidden(
              textInput(ns("editing_tag_id"), label = NULL, value = "")
            ),
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("tag_name")),
              tags$div(
                class = "edit-tag-row",
                tags$div(
                  class = "edit-tag-name",
                  textInput(ns("edit_tag_name"), label = NULL, placeholder = i18n$t("enter_tag_name"))
                ),
                tags$div(
                  class = "edit-tag-color",
                  create_color_picker(id = "edit_tag_color", value = "#6c757d", ns = ns)
                )
              ),
              tags$div(id = ns("edit_tag_error"), class = "input-error-message", style = "display: none;")
            )
          ),
          footer = tagList(
            actionButton(ns("cancel_edit_tag"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("save_edit_tag"), i18n$t("save"), class = "btn-primary-custom", icon = icon("save"))
          ),
          size = "small",
          icon = "fas fa-tag",
          ns = ns
        ),

        ### Modal - Delete Tag Confirmation ----
        create_modal(
          id = "delete_tag_modal",
          title = i18n$t("confirm_deletion"),
          body = tagList(
            shinyjs::hidden(
              textInput(ns("deleting_tag_id"), label = NULL, value = "")
            ),
            tags$p(id = ns("delete_tag_message"))
          ),
          footer = tagList(
            actionButton(ns("cancel_delete_tag"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_delete_tag"), i18n$t("delete"), class = "btn-danger-custom", icon = icon("trash"))
          ),
          size = "small",
          icon = "fas fa-exclamation-triangle",
          ns = ns
        ),

        ### Modal - Delete Confirmation ----
        create_modal(
          id = "delete_concept_set_modal",
          title = i18n$t("confirm_deletion"),
          body = tagList(
            shinyjs::hidden(
              textInput(ns("deleting_concept_set_id"), label = NULL, value = "")
            ),
            tags$p(id = ns("delete_confirmation_message"))
          ),
          footer = tagList(
            actionButton(ns("cancel_delete_concept_set"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_delete_concept_set"), i18n$t("delete"), class = "btn-danger-custom", icon = icon("trash"))
          ),
          size = "small",
          icon = "fas fa-exclamation-triangle",
          ns = ns
        ),

        ### Modal - Load Default Concept Sets ----
        create_modal(
          id = "load_default_modal",
          title = i18n$t("no_concept_sets"),
          body = tagList(
            tags$p(
              id = ns("load_default_message"),
              style = "margin-bottom: 15px;"
            ),
            tags$p(
              i18n$t("load_default_question"),
              style = "font-weight: 600; margin-top: 10px;"
            )
          ),
          footer = tagList(
            actionButton(ns("cancel_load_default"), i18n$t("no"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_load_default"), i18n$t("yes_load"), class = "btn-primary-custom", icon = icon("download"))
          ),
          size = "medium",
          icon = "fas fa-info-circle",
          ns = ns
        ),

        ### Modal - Add Concepts to Concept Set ----
        tags$div(
          id = ns("add_concepts_modal"),
          class = "modal-fs",

          # Header
          tags$div(
            class = "modal-fs-header",
            tags$h3(i18n$t("add_concepts_to_set")),
            tags$button(
              id = ns("close_add_concepts_modal"),
              class = "modal-fs-close",
              onclick = sprintf("document.getElementById('%s').style.display = 'none';", ns("add_concepts_modal")),
              HTML("&times;")
            )
          ),

          # Body
          tags$div(
            class = "modal-fs-body",

            # Top section - Search & DataTable
            tags$div(
              class = "modal-fs-section",
              tags$div(
                class = "modal-fs-section-inner",
                fuzzy_search_ui(
                  "omop_fuzzy_search",
                  ns = ns,
                  i18n = i18n,
                  limit_checkbox = TRUE,
                  limit_checkbox_id = "omop_limit_10k",
                  settings_btn = TRUE,
                  settings_btn_id = "omop_filters_btn"
                ),
                DT::DTOutput(ns("omop_concepts_table"))
              )
            ),

            # Bottom section - Details & Descendants
            tags$div(
              id = ns("add_modal_details_section"),
              class = "modal-fs-section-row",

              # Concept Details (left)
              tags$div(
                class = "modal-fs-panel settings-section section-blue",
                tags$h4(
                  class = "settings-section-title",
                  tags$i(class = "fas fa-info-circle", style = "margin-right: 8px;"),
                  i18n$t("selected_concept_details_modal")
                ),
                tags$div(
                  class = "modal-fs-panel-content",
                  uiOutput(ns("add_modal_concept_details"))
                )
              ),

              # Descendants (right)
              tags$div(
                class = "modal-fs-panel settings-section section-green",
                tags$h4(
                  class = "settings-section-title",
                  tags$i(class = "fas fa-sitemap", style = "margin-right: 8px;"),
                  i18n$t("descendants")
                ),
                tags$div(
                  class = "modal-fs-panel-content",
                  uiOutput(ns("add_modal_descendants_container"))
                )
              )
            ),

            # Footer - Buttons
            tags$div(
              class = "modal-fs-footer",
              # Left side: Multiple selection toggle
              tags$div(
                class = "flex-center-gap-8",
                tags$label(
                  class = "toggle-with-label",
                  tags$span(
                    class = "toggle-switch toggle-small toggle-blue",
                    tags$input(type = "checkbox", id = ns("add_modal_multiple_select")),
                    tags$span(class = "toggle-slider")
                  ),
                  tags$span(i18n$t("multiple_selection"), class = "toggle-label-text")
                )
              ),
              # Right side: Toggles and Add button
              tags$div(
                class = "flex-center-gap-8",
                # Exclude toggle
                tags$label(
                  class = "toggle-with-label",
                  tags$span(
                    class = "toggle-switch toggle-small toggle-exclude",
                    tags$input(type = "checkbox", id = ns("add_modal_is_excluded")),
                    tags$span(class = "toggle-slider")
                  ),
                  tags$span(i18n$t("exclude"), class = "toggle-label-text")
                ),
                # Descendants toggle
                tags$label(
                  class = "toggle-with-label",
                  style = "margin-left: 15px;",
                  tags$span(
                    class = "toggle-switch toggle-small",
                    tags$input(type = "checkbox", id = ns("add_modal_include_descendants"), checked = "checked"),
                    tags$span(class = "toggle-slider")
                  ),
                  tags$span(i18n$t("include_descendants"), class = "toggle-label-text")
                ),
                # Mapped toggle
                tags$label(
                  class = "toggle-with-label",
                  style = "margin-left: 15px;",
                  tags$span(
                    class = "toggle-switch toggle-small",
                    tags$input(type = "checkbox", id = ns("add_modal_include_mapped"), checked = "checked"),
                    tags$span(class = "toggle-slider")
                  ),
                  tags$span(i18n$t("include_mapped"), class = "toggle-label-text")
                ),
                actionButton(
                  ns("add_omop_concepts"),
                  i18n$t("add_concept"),
                  class = "btn-success-custom",
                  style = "margin-left: 15px;",
                  icon = icon("plus")
                )
              )
            )
          )
        ),

        ### Modal - Limit 10K Confirmation ----
        limit_10k_modal_ui(
          modal_id = "omop_limit_10k_confirmation_modal",
          checkbox_id = "omop_limit_10k",
          confirm_btn_id = "confirm_omop_limit_10k",
          ns = ns,
          i18n = i18n
        ),

        ### Modal - OMOP Advanced Filters ----
        omop_filters_modal_ui(
          prefix = "omop_filters",
          ns = ns,
          i18n = i18n
        ),

        ### Modal - Remove Concept Confirmation ----
        create_modal(
          id = "remove_concept_modal",
          title = i18n$t("confirm_deletion"),
          body = tagList(
            shinyjs::hidden(
              textInput(ns("removing_concept_id"), label = NULL, value = "")
            ),
            tags$p(i18n$t("confirm_remove_concept"))
          ),
          footer = tagList(
            actionButton(ns("cancel_remove_concept"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_remove_concept"), i18n$t("remove_concept"), class = "btn-danger-custom", icon = icon("trash"))
          ),
          size = "small",
          icon = "fas fa-exclamation-triangle",
          ns = ns
        ),

        ### Modal - Delete Selected Concepts Confirmation ----
        create_modal(
          id = "delete_selected_concepts_modal",
          title = i18n$t("confirm_deletion"),
          body = tagList(
            tags$p(id = ns("delete_concepts_message_text"), i18n$t("confirm_delete_selected_concepts"))
          ),
          footer = tagList(
            actionButton(ns("cancel_delete_selected_concepts"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_delete_selected_concepts"), i18n$t("delete"), class = "btn-danger-custom", icon = icon("trash"))
          ),
          size = "small",
          icon = "fas fa-exclamation-triangle",
          ns = ns
        ),

        ### Modal - Export Concept Set ----
        create_modal(
          id = "export_concept_set_modal",
          title = i18n$t("export_concept_set"),
          body = tagList(
            tags$div(
              class = "export-options-container",

              # Option 1: OHDSI JSON (clipboard)
              tags$div(
                class = "export-option",
                onclick = sprintf("Shiny.setInputValue('%s', 'json_clipboard', {priority: 'event'});", ns("export_action")),
                tags$div(
                  class = "export-option-icon",
                  tags$i(class = "fas fa-clipboard", style = "color: #0f60af;")
                ),
                tags$div(
                  class = "export-option-content",
                  tags$h5(class = "export-option-title", i18n$t("export_json_clipboard")),
                  tags$p(class = "export-option-subtitle", i18n$t("export_json_clipboard_desc"))
                )
              ),

              # Option 2: OHDSI JSON (file)
              tags$div(
                class = "export-option",
                onclick = sprintf("Shiny.setInputValue('%s', 'json_file', {priority: 'event'});", ns("export_action")),
                tags$div(
                  class = "export-option-icon",
                  tags$i(class = "fas fa-file-download", style = "color: #28a745;")
                ),
                tags$div(
                  class = "export-option-content",
                  tags$h5(class = "export-option-title", i18n$t("export_json_file")),
                  tags$p(class = "export-option-subtitle", i18n$t("export_json_file_desc"))
                )
              ),

              # Option 3: Concept list (comma separated)
              tags$div(
                class = "export-option",
                onclick = sprintf("Shiny.setInputValue('%s', 'concept_list', {priority: 'event'});", ns("export_action")),
                tags$div(
                  class = "export-option-icon",
                  tags$i(class = "fas fa-list", style = "color: #7c3aed;")
                ),
                tags$div(
                  class = "export-option-content",
                  tags$h5(class = "export-option-title", i18n$t("export_concept_list")),
                  tags$p(class = "export-option-subtitle", i18n$t("export_concept_list_desc"))
                )
              ),

              # Option 4: SQL query
              tags$div(
                class = "export-option",
                onclick = sprintf("Shiny.setInputValue('%s', 'sql_query', {priority: 'event'});", ns("export_action")),
                tags$div(
                  class = "export-option-icon",
                  tags$i(class = "fas fa-database", style = "color: #ffc107;")
                ),
                tags$div(
                  class = "export-option-content",
                  tags$h5(class = "export-option-title", i18n$t("export_sql")),
                  tags$p(class = "export-option-subtitle", i18n$t("export_sql_desc"))
                )
              )
            )
          ),
          footer = tagList(
            actionButton(ns("cancel_export"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times"))
          ),
          size = "medium",
          icon = "fas fa-download",
          ns = ns
        ),

        ### Modal - Import Concept Sets ----
        create_modal(
          id = "import_concept_sets_modal",
          title = i18n$t("import_concept_sets"),
          body = tagList(
            # File upload
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("select_zip_file")),
              tags$div(
                style = "width: 100%;",
                fileInput(
                  ns("import_zip_file"),
                  label = NULL,
                  accept = ".zip",
                  buttonLabel = i18n$t("browse"),
                  placeholder = "No file selected",
                  width = "100%"
                )
              )
            ),
            # Import mode
            tags$div(
              class = "mb-15",
              tags$div(
                class = "import-options-container",
                # Add mode
                tags$div(
                  class = "import-option selected",
                  id = ns("import_option_add"),
                  onclick = sprintf("$('.import-option').removeClass('selected'); $(this).addClass('selected'); Shiny.setInputValue('%s', 'add', {priority: 'event'});", ns("import_mode")),
                  tags$div(
                    class = "import-option-content",
                    tags$h5(class = "import-option-title", i18n$t("import_mode_add")),
                    tags$p(class = "import-option-subtitle", i18n$t("import_mode_add_desc"))
                  )
                ),
                # Replace mode
                tags$div(
                  class = "import-option",
                  id = ns("import_option_replace"),
                  onclick = sprintf("$('.import-option').removeClass('selected'); $(this).addClass('selected'); Shiny.setInputValue('%s', 'replace', {priority: 'event'});", ns("import_mode")),
                  tags$div(
                    class = "import-option-content",
                    tags$h5(class = "import-option-title", i18n$t("import_mode_replace")),
                    tags$p(
                      class = "import-option-subtitle text-danger",
                      style = "font-weight: 600;",
                      i18n$t("import_mode_replace_desc")
                    )
                  )
                )
              )
            ),
            # Progress/status message
            tags$div(
              id = ns("import_status_message"),
              style = "display: none; padding: 10px; border-radius: 4px; margin-top: 15px;"
            )
          ),
          footer = tagList(
            actionButton(ns("cancel_import"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_import"), i18n$t("import"), class = "btn-primary-custom", icon = icon("upload"))
          ),
          size = "medium",
          icon = "fas fa-upload",
          ns = ns
        ),

        ### Modal - Filter Concept Sets ----
        create_modal(
          id = "filters_modal",
          title = i18n$t("filters"),
          body = tagList(
            # Category filter
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("category")),
              selectizeInput(
                ns("filter_category"),
                label = NULL,
                choices = character(0),
                multiple = TRUE,
                options = list(placeholder = as.character(i18n$t("select_or_type")))
              )
            ),
            # Subcategory filter
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("subcategory")),
              selectizeInput(
                ns("filter_subcategory"),
                label = NULL,
                choices = character(0),
                multiple = TRUE,
                options = list(placeholder = as.character(i18n$t("select_or_type")))
              )
            ),
            # Status filter
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("review_status")),
              selectizeInput(
                ns("filter_status"),
                label = NULL,
                choices = character(0),
                multiple = TRUE,
                options = list(placeholder = as.character(i18n$t("select_or_type")))
              )
            ),
            # Tags filter
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("tags")),
              selectizeInput(
                ns("filter_tags"),
                label = NULL,
                choices = character(0),
                multiple = TRUE,
                options = list(placeholder = as.character(i18n$t("select_or_type")))
              )
            )
          ),
          footer = tagList(
            actionButton(ns("reset_filters"), i18n$t("reset_filters"), class = "btn-secondary-custom", icon = icon("eraser")),
            actionButton(ns("apply_filters"), i18n$t("apply"), class = "btn-primary-custom", icon = icon("check"))
          ),
          size = "medium",
          icon = "fas fa-filter",
          ns = ns
        ),

        ### Modal - Change Status ----
        create_modal(
          id = "change_status_modal",
          title = "Change Status",
          body = tagList(
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("review_status")),
              selectInput(
                ns("new_status_input"),
                label = NULL,
                choices = character(0)
              )
            )
          ),
          footer = tagList(
            actionButton(ns("cancel_change_status"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_change_status"), i18n$t("save"), class = "btn-primary-custom", icon = icon("check"))
          ),
          size = "small",
          icon = "fas fa-exchange-alt",
          ns = ns
        ),

        ### Modal - New Version ----
        create_modal(
          id = "new_version_modal",
          title = "Create New Version",
          body = tagList(
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("version")),
              textInput(
                ns("new_version_number"),
                label = NULL,
                placeholder = "e.g., 1.1.0"
              )
            ),
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("change_summary")),
              textAreaInput(
                ns("version_change_summary"),
                label = NULL,
                placeholder = as.character(i18n$t("enter_description")),
                rows = 3,
                width = "100%"
              )
            ),
            tags$div(
              style = "margin-top: 20px;",
              tags$h4(
                style = "margin-bottom: 10px; font-size: 14px; font-weight: 600;",
                "Version History"
              ),
              DT::DTOutput(ns("version_history_table"))
            )
          ),
          footer = tagList(
            actionButton(ns("cancel_new_version"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_new_version"), i18n$t("create"), class = "btn-primary-custom", icon = icon("check"))
          ),
          size = "medium",
          icon = "fas fa-code-branch",
          ns = ns
        ),

        ### Modal - Add Review (Fullscreen with Markdown Editor) ----
        tags$div(
          id = ns("add_review_modal"),
          class = "modal-fs",

          # Header with buttons
          tags$div(
            class = "modal-fs-header",
            tags$h3(i18n$t("add_review")),
            tags$div(
              style = "display: flex; gap: 10px; align-items: center;",
              tags$div(
                style = "display: flex; gap: 8px; align-items: center;",
                tags$label(
                  style = "margin: 0; font-size: 13px; color: #666; white-space: nowrap;",
                  "Review Status:"
                ),
                tags$div(
                  style = "height: 32px;",
                  selectInput(
                    ns("review_status_modal"),
                    label = NULL,
                    choices = c(
                      "Select status..." = "",
                      "Approved" = "approved",
                      "Needs Revision" = "needs_revision"
                    ),
                    selected = "",
                    width = "180px"
                  )
                )
              ),
              actionButton(ns("submit_add_review"), i18n$t("submit_review"), class = "btn-success-custom btn-sm", icon = icon("check")),
              tags$button(
                id = ns("close_add_review_modal"),
                class = "modal-fs-close",
                onclick = sprintf("document.getElementById('%s').style.display = 'none';", ns("add_review_modal")),
                HTML("&times;")
              )
            )
          ),

          # Body - Two columns side by side
          tags$div(
            class = "modal-fs-body",
            style = "display: flex; flex-direction: row; gap: 0; padding: 0; height: 100%;",

            # Left: Markdown editor
            tags$div(
              class = "settings-section settings-backup-section expandable-section",
              style = "flex: 1; display: flex; flex-direction: column; border-right: 1px solid #dee2e6; margin: 5px;",
              tags$h4(
                class = "settings-section-title",
                tags$i(class = "fas fa-edit", style = "margin-right: 8px; color: #0f60af;"),
                "Markdown Editor"
              ),
              tags$div(
                style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                tags$div(
                  style = "flex: 1; overflow: hidden;",
                  shinyAce::aceEditor(
                    ns("review_markdown_editor"),
                    mode = "markdown",
                    theme = "chrome",
                    height = "100%",
                    fontSize = 12,
                    debounce = 100,
                    autoScrollEditorIntoView = TRUE,
                    value = "# Review Comments\n\nEnter your review comments here using Markdown syntax.\n\n## Suggestions\n\n- Item 1\n- Item 2\n"
                  )
                )
              )
            ),

            # Right: Markdown preview
            tags$div(
              class = "settings-section settings-backup-section expandable-section",
              style = "flex: 1; display: flex; flex-direction: column; margin: 5px;",
              tags$h4(
                class = "settings-section-title",
                tags$i(class = "fas fa-eye", style = "margin-right: 8px; color: #0f60af;"),
                "Preview"
              ),
              tags$div(
                style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                tags$div(
                  style = "flex: 1; overflow: auto;",
                  uiOutput(ns("review_markdown_preview"))
                )
              )
            )
          )
        ),

        ### Modal - Edit Version Summary ----
        create_modal(
          id = "edit_version_summary_modal",
          title = "Edit Change Summary",
          body = tagList(
            tags$div(
              class = "mb-15",
              tags$label(class = "form-label", i18n$t("change_summary")),
              textAreaInput(
                ns("edit_version_summary_input"),
                label = NULL,
                rows = 4,
                placeholder = as.character(i18n$t("enter_description")),
                width = "100%"
              )
            ),
            # Hidden input to store the change_id being edited
            shinyjs::hidden(textInput(ns("editing_change_id"), label = NULL, value = ""))
          ),
          footer = tagList(
            actionButton(ns("cancel_edit_version_summary"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("save_edit_version_summary"), i18n$t("save"), class = "btn-primary-custom", icon = icon("check"))
          ),
          size = "medium",
          icon = "fas fa-edit",
          ns = ns
        ),

        ### Modal - Delete Version Confirmation ----
        create_modal(
          id = "delete_version_modal",
          title = "Confirm Deletion",
          body = tagList(
            tags$p("Are you sure you want to delete this version entry?"),
            tags$p(
              style = "color: #dc3545; font-weight: 600;",
              "This action cannot be undone."
            ),
            # Hidden input to store the change_id being deleted
            shinyjs::hidden(textInput(ns("deleting_change_id"), label = NULL, value = ""))
          ),
          footer = tagList(
            actionButton(ns("cancel_delete_version"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_delete_version_final"), i18n$t("delete"), class = "btn-danger-custom", icon = icon("trash"))
          ),
          size = "small",
          icon = "fas fa-exclamation-triangle",
          ns = ns
        ),

        ### Modal - Edit Review (Fullscreen) ----
        tags$div(
          id = ns("edit_review_modal"),
          class = "modal-fs",

          # Header with buttons
          tags$div(
            class = "modal-fs-header",
            tags$h3("Edit Review"),
            tags$div(
              style = "display: flex; gap: 10px; align-items: center;",
              tags$div(
                style = "display: flex; gap: 8px; align-items: center;",
                tags$label(
                  style = "margin: 0; font-size: 13px; color: #666; white-space: nowrap;",
                  "Review Status:"
                ),
                tags$div(
                  style = "height: 32px;",
                  selectInput(
                    ns("edit_review_status_input"),
                    label = NULL,
                    choices = c(
                      "Select status..." = "",
                      "Approved" = "approved",
                      "Needs Revision" = "needs_revision"
                    ),
                    selected = "",
                    width = "180px"
                  )
                )
              ),
              actionButton(ns("confirm_edit_review"), i18n$t("save"), class = "btn-primary-custom btn-sm", icon = icon("save")),
              tags$button(
                id = ns("close_edit_review_modal"),
                class = "modal-fs-close",
                onclick = sprintf("document.getElementById('%s').style.display = 'none';", ns("edit_review_modal")),
                HTML("&times;")
              )
            )
          ),

          # Body - Two columns side by side
          tags$div(
            class = "modal-fs-body",
            style = "display: flex; flex-direction: row; gap: 0; padding: 0; height: 100%;",

            # Left: Markdown editor
            tags$div(
              class = "settings-section settings-backup-section expandable-section",
              style = "flex: 1; display: flex; flex-direction: column; border-right: 1px solid #dee2e6; margin: 5px;",
              tags$h4(
                class = "settings-section-title",
                tags$i(class = "fas fa-edit", style = "margin-right: 8px; color: #0f60af;"),
                "Markdown Editor"
              ),
              tags$div(
                style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                tags$div(
                  style = "flex: 1; overflow: hidden;",
                  shinyAce::aceEditor(
                    ns("edit_review_markdown_editor"),
                    mode = "markdown",
                    theme = "chrome",
                    height = "100%",
                    fontSize = 12,
                    debounce = 100,
                    autoScrollEditorIntoView = TRUE,
                    value = ""
                  )
                )
              )
            ),

            # Right: Markdown preview
            tags$div(
              class = "settings-section settings-backup-section expandable-section",
              style = "flex: 1; display: flex; flex-direction: column; margin: 5px;",
              tags$h4(
                class = "settings-section-title",
                tags$i(class = "fas fa-eye", style = "margin-right: 8px; color: #0f60af;"),
                "Preview"
              ),
              tags$div(
                style = "position: relative; flex: 1; display: flex; flex-direction: column; min-height: 0;",
                tags$div(
                  style = "flex: 1; overflow: auto;",
                  uiOutput(ns("edit_review_markdown_preview"))
                )
              )
            )
          ),

          # Hidden input to store the review_id being edited
          shinyjs::hidden(textInput(ns("editing_review_id"), label = NULL, value = ""))
        ),

        ### Modal - View Review (Fullscreen) ----
        tags$div(
          id = ns("view_review_modal"),
          class = "modal-fs",

          # Header with review metadata
          tags$div(
            class = "modal-fs-header",
            tags$h3("Review Details"),
            tags$div(
              style = "display: flex; gap: 15px; align-items: center;",
              tags$div(
                id = ns("view_review_header_info"),
                style = "display: flex; gap: 15px; align-items: center; font-size: 13px; color: #666;"
              ),
              tags$button(
                id = ns("close_view_review_modal"),
                class = "modal-fs-close",
                onclick = sprintf("document.getElementById('%s').style.display = 'none';", ns("view_review_modal")),
                HTML("&times;")
              )
            )
          ),

          # Body - Rendered markdown
          tags$div(
            class = "modal-fs-body",
            style = "padding: 0; height: 100%; overflow: hidden;",
            tags$div(
              style = "height: 100%; overflow: auto; padding: 0 20px 20px 20px;",
              uiOutput(ns("view_review_content"))
            )
          )
        ),

        ### Modal - Delete Review Confirmation ----
        create_modal(
          id = "delete_review_modal",
          title = "Confirm Deletion",
          body = tagList(
            tags$p("Are you sure you want to delete this review?"),
            tags$p(
              style = "color: #dc3545; font-weight: 600;",
              "This action cannot be undone."
            ),
            # Hidden input to store the review_id being deleted
            shinyjs::hidden(textInput(ns("deleting_review_id"), label = NULL, value = ""))
          ),
          footer = tagList(
            actionButton(ns("cancel_delete_review"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_delete_review_final"), i18n$t("delete"), class = "btn-danger-custom", icon = icon("trash"))
          ),
          size = "small",
          icon = "fas fa-exclamation-triangle",
          ns = ns
        ),

        # JavaScript for expand section buttons
        tags$script(HTML(sprintf("
          $(document).ready(function() {
            // Generic handler for all expand buttons
            $('.btn-expand-section').on('click', function() {
              var container = $(this).closest('.settings-backup-container');
              var section = $(this).closest('.expandable-section');
              var buttonId = $(this).attr('id');

              if (section.hasClass('expanded')) {
                // Collapse
                section.removeClass('expanded');
                container.removeClass('has-expanded');
                $(this).removeClass('expanded');
                $(this).attr('title', 'Expand');

                // Notify Shiny if this is the related section (contains hierarchy graph)
                if (buttonId === '%s') {
                  setTimeout(function() {
                    Shiny.setInputValue('%s', {expanded: false, time: Date.now()}, {priority: 'event'});
                  }, 100);
                }
              } else {
                // Expand - hide others
                container.find('.expandable-section').removeClass('expanded');
                container.find('.btn-expand-section').removeClass('expanded');
                section.addClass('expanded');
                container.addClass('has-expanded');
                $(this).addClass('expanded');
                $(this).attr('title', 'Collapse');

                // Notify Shiny if this is the related section (contains hierarchy graph)
                if (buttonId === '%s') {
                  setTimeout(function() {
                    Shiny.setInputValue('%s', {expanded: true, time: Date.now()}, {priority: 'event'});
                  }, 100);
                }
              }
            });
          });
        ", ns("expand_related"), ns("related_expanded_toggle"), ns("expand_related"), ns("related_expanded_toggle"))))
      )
    )
  )
}

# SERVER SECTION ====

#' Data Dictionary Module - Server
#'
#' @param id Module ID
#' @param i18n Translator object
#' @param current_user Reactive: Current logged-in user
#'
#' @noRd
mod_data_dictionary_server <- function(id, i18n, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # 1) REACTIVE VALUES & STATE ====

    ## Permissions ----
    can_edit <- reactive({
      # For now, allow editing for all users
      # Later: check current_user permissions
      TRUE
    })

    ## Data ----
    concept_sets_data <- reactiveVal(NULL)
    tags_data <- reactiveVal(NULL)
    reviews_data <- reactiveVal(NULL)

    ## Triggers ----
    table_trigger <- reactiveVal(0)
    tags_trigger <- reactiveVal(0)
    hierarchy_graph_trigger <- reactiveVal(0)
    reviews_trigger <- reactiveVal(0)

    ## Fullscreen State ----
    related_section_expanded <- reactiveVal(FALSE)

    ## Edit State ----
    editing_id <- reactiveVal(NULL)
    deleting_id <- reactiveVal(NULL)
    editing_tag_id <- reactiveVal(NULL)
    deleting_tag_id <- reactiveVal(NULL)
    concepts_edit_mode <- reactiveVal(FALSE)

    ## Statistics State ----
    selected_stats_profile <- reactiveVal(NULL)

    ## Export State ----
    export_zip_path <- reactiveVal(NULL)

    ## Fuzzy Search ----
    fuzzy <- fuzzy_search_server("fuzzy_search", input, session, trigger_rv = table_trigger, ns = ns)

    ## Filters ----
    active_filters <- reactiveVal(list(
      category = character(0),
      subcategory = character(0),
      status = character(0),
      tags = character(0)
    ))

    ## Selected Concept Set (for parent modules) ----
    selected_concept_set <- reactive({
      rows <- input$concept_sets_table_rows_selected
      if (is.null(rows) || length(rows) == 0) return(list(selected_id = NULL))

      data <- concept_sets_data()
      if (is.null(data)) return(list(selected_id = NULL))

      list(selected_id = data$id[rows])
    })

    # 2) DATA LOADING ====

    ## Load Concept Sets and Tags ----
    observe_event(TRUE, {
      # Show/hide buttons based on permissions
      if (can_edit()) {
        shinyjs::show("add_concept_set")
        shinyjs::show("import_concept_sets")
      }
      shinyjs::show("export_all_concept_sets")
      shinyjs::show("filter_concept_sets")

      # Load concept sets data
      current_language <- i18n$get_translation_language()
      data <- get_all_concept_sets(language = current_language)
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)

      # Load tags
      all_tags <- get_all_tags()
      tags_data(all_tags)
      tags_trigger(tags_trigger() + 1)

      # Check if database is empty and offer to load defaults
      if (is.null(data) || nrow(data) == 0) {
        # Find default concept sets
        concept_sets_dir <- system.file("extdata/concept_sets", package = "indicate")
        if (concept_sets_dir == "" || !dir.exists(concept_sets_dir)) {
          concept_sets_dir <- "inst/extdata/concept_sets"
        }

        if (dir.exists(concept_sets_dir)) {
          json_files <- list.files(concept_sets_dir, pattern = "\\.json$", full.names = TRUE)
          json_files <- json_files[!grepl("README", basename(json_files), ignore.case = TRUE)]

          if (length(json_files) > 0) {
            # Update message with count
            message_text <- gsub("\\{count\\}", as.character(length(json_files)), as.character(i18n$t("load_default_count")))
            shinyjs::html("load_default_message", message_text)

            # Show modal
            show_modal(ns("load_default_modal"))
          }
        }
      }
    }, ignoreInit = FALSE, once = TRUE)

    # Initialize OMOP concepts table (required for outputOptions)
    output$omop_concepts_table <- DT::renderDT({
      create_empty_datatable("")
    })
    outputOptions(output, "omop_concepts_table", suspendWhenHidden = FALSE)

    # Initialize add modal descendants table (required for outputOptions)
    output$add_modal_descendants_table <- DT::renderDT({
      create_empty_datatable("")
    })
    outputOptions(output, "add_modal_descendants_table", suspendWhenHidden = FALSE)

    # Download handler for export all
    output$download_all_concept_sets <- downloadHandler(
      filename = function() {
        sprintf("indicate_concept_sets_%s.zip", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"))
      },
      content = function(file) {
        zip_path <- export_zip_path()
        if (!is.null(zip_path) && file.exists(zip_path)) {
          file.copy(zip_path, file)
        }
      }
    )

    # Initialize add modal concept details (force render when hidden in modal)
    output$add_modal_concept_details <- renderUI({
      render_concept_details(
        concept = NULL,
        i18n = i18n,
        empty_message = as.character(i18n$t("no_concept_selected"))
      )
    })
    outputOptions(output, "add_modal_concept_details", suspendWhenHidden = FALSE)

    # No initialization needed for reviews_table_container (renderUI)

    # Initialize version history table (required for outputOptions)
    output$version_history_table <- DT::renderDT({
      create_empty_datatable("No version history")
    })
    outputOptions(output, "version_history_table", suspendWhenHidden = FALSE)

    # 3) TABLE RENDERING ====

    ## Concept Sets Table Container ----
    observe_event(table_trigger(), {
      output$concept_sets_table_container <- renderUI({
        data <- concept_sets_data()

        # Apply fuzzy search filter on name column
        query <- fuzzy$query()
        if (!is.null(query) && query != "" && !is.null(data) && nrow(data) > 0) {
          data <- fuzzy_search_df(data, query, "name", max_dist = 3)
        }

        if (is.null(data) || nrow(data) == 0) {
          shinyjs::hide("concept_sets_fuzzy_search_container")
          return(tags$div(
            class = "no-content-message",
            tags$p(i18n$t("no_concept_sets"))
          ))
        }

        shinyjs::show("concept_sets_fuzzy_search_container")
        DT::DTOutput(ns("concept_sets_table"))
      })

      ## Concept Sets Table ----
      output$concept_sets_table <- DT::renderDT({
        data <- concept_sets_data()

        # Apply fuzzy search filter on name column
        query <- fuzzy$query()
        if (!is.null(query) && query != "" && !is.null(data) && nrow(data) > 0) {
          data <- fuzzy_search_df(data, query, "name", max_dist = 3)
        }

        if (is.null(data) || nrow(data) == 0) return(NULL)

        # Apply active filters
        filters <- active_filters()

        # Filter by category
        if (length(filters$category) > 0) {
          data <- data[!is.na(data$category) & data$category %in% filters$category, ]
        }

        # Filter by subcategory
        if (length(filters$subcategory) > 0) {
          data <- data[!is.na(data$subcategory) & data$subcategory %in% filters$subcategory, ]
        }

        # Filter by status
        if (length(filters$status) > 0) {
          status_col <- ifelse(is.na(data$review_status) | data$review_status == "", "draft", data$review_status)
          data <- data[status_col %in% filters$status, ]
        }

        # Filter by tags (any tag match)
        if (length(filters$tags) > 0) {
          data <- data[sapply(seq_len(nrow(data)), function(i) {
            row_tags <- data$tags[i]
            if (is.na(row_tags) || row_tags == "") return(FALSE)
            row_tags_list <- trimws(strsplit(row_tags, ",")[[1]])
            any(row_tags_list %in% filters$tags)
          }), ]
        }

        if (nrow(data) == 0) return(NULL)

        # Format last update date (show date and time HH:MM, or empty if NA)
        format_date <- function(dt_str) {
          if (is.na(dt_str) || dt_str == "") return("")
          tryCatch({
            # Parse ISO format and return date + time (HH:MM)
            # Format: "YYYY-MM-DD HH:MM" (replace T with space)
            gsub("T", " ", substr(dt_str, 1, 16))
          }, error = function(e) "")
        }

        # Format tags as badges with colors
        all_tags <- get_all_tags()
        tag_colors <- setNames(all_tags$color, all_tags$name)

        format_tags <- function(tags_str) {
          if (is.na(tags_str) || tags_str == "") return("")
          # Split by comma, trim whitespace
          tags_list <- trimws(strsplit(tags_str, ",")[[1]])
          # Create badge for each tag with its color and appropriate text color
          badges <- sapply(tags_list, function(tag) {
            bg_color <- tag_colors[tag]
            if (is.na(bg_color)) bg_color <- "#6c757d"
            text_color <- get_text_color_for_bg(bg_color)
            sprintf('<span class="tag-badge" style="background-color: %s; color: %s;">%s</span>',
                    htmltools::htmlEscape(bg_color), text_color, htmltools::htmlEscape(tag))
          })
          paste(badges, collapse = " ")
        }

        # Format status with colored badge
        format_status <- function(status) {
          if (is.na(status) || status == "") status <- "draft"
          status_key <- paste0("status_", status)
          status_label <- as.character(i18n$t(status_key))
          sprintf('<span class="status-badge %s">%s</span>', status, htmltools::htmlEscape(status_label))
        }

        # Prepare display data - order: category, subcategory, name, description, tags, version, status, author, last_update, concepts
        display_data <- data.frame(
          id = data$id,
          category = ifelse(is.na(data$category), "", data$category),
          subcategory = ifelse(is.na(data$subcategory), "", data$subcategory),
          name = data$name,
          description = ifelse(
            is.na(data$description), "",
            ifelse(nchar(data$description) > 100, paste0(substr(data$description, 1, 100), "..."), data$description)
          ),
          tags = vapply(data$tags, format_tags, character(1), USE.NAMES = FALSE),
          version = ifelse(is.na(data$version) | data$version == "", "1.0.0", data$version),
          status = vapply(
            ifelse(is.na(data$review_status) | data$review_status == "", "draft", data$review_status),
            format_status,
            character(1),
            USE.NAMES = FALSE
          ),
          author = ifelse(
            is.na(data$created_by_first_name) & is.na(data$created_by_last_name),
            "",
            paste(
              ifelse(is.na(data$created_by_first_name), "", data$created_by_first_name),
              ifelse(is.na(data$created_by_last_name), "", data$created_by_last_name)
            )
          ),
          last_update = vapply(data$modified_date, format_date, character(1), USE.NAMES = FALSE),
          item_count = ifelse(is.na(data$item_count), 0L, data$item_count),
          stringsAsFactors = FALSE,
          row.names = NULL
        )

        # Convert to factors for dropdown filters (except tags - keep as text)
        display_data$category <- factor(display_data$category)
        display_data$subcategory <- factor(display_data$subcategory)

        # Add action buttons
        display_data$actions <- sapply(display_data$id, function(row_id) {
          create_datatable_actions(list(
            list(
              label = as.character(i18n$t("view")),
              icon = "eye",
              type = "primary",
              class = "btn-view",
              data_attr = list(id = row_id)
            ),
            list(
              label = as.character(i18n$t("edit")),
              icon = "edit",
              type = "warning",
              class = "btn-edit",
              data_attr = list(id = row_id)
            ),
            list(
              label = as.character(i18n$t("delete")),
              icon = "trash",
              type = "danger",
              class = "btn-delete",
              data_attr = list(id = row_id)
            )
          ))
        })

        dt <- create_standard_datatable(
          display_data,
          selection = "none",
          col_names = c(
            "ID",
            as.character(i18n$t("category")),
            as.character(i18n$t("subcategory")),
            as.character(i18n$t("name")),
            as.character(i18n$t("description")),
            as.character(i18n$t("tags")),
            as.character(i18n$t("version")),
            as.character(i18n$t("review_status")),
            as.character(i18n$t("created_by")),
            as.character(i18n$t("last_update")),
            as.character(i18n$t("concepts")),
            as.character(i18n$t("actions"))
          ),
          col_defs = list(
            list(targets = 0, visible = FALSE),  # ID
            list(targets = 1, width = "10%"),    # Category
            list(targets = 2, width = "10%"),    # Subcategory
            list(targets = 3, width = "15%"),    # Name
            list(targets = 4, width = "25%"),    # Description
            list(targets = 5, width = "10%", visible = FALSE),    # Tags (hidden)
            list(targets = 6, width = "6%", className = "dt-center"),   # Version
            list(targets = 7, width = "10%", className = "dt-center"),  # Status (with badge)
            list(targets = 8, width = "8%", visible = FALSE),    # Author (hidden)
            list(targets = 9, width = "8%", className = "dt-center", visible = FALSE),   # Last Update (hidden)
            list(targets = 10, width = "5%", className = "dt-center", visible = FALSE),  # Concepts count (hidden)
            list(targets = 11, width = "210px", className = "dt-center")  # Actions
          ),
          escape = FALSE
        )

        add_button_handlers(
          dt,
          handlers = list(
            list(selector = ".btn-view", input_id = ns("view_concept_set")),
            list(selector = ".btn-edit", input_id = ns("edit_concept_set")),
            list(selector = ".btn-delete", input_id = ns("delete_concept_set"))
          ),
          dblclick_input_id = ns("view_concept_set"),
          id_column_index = 0
        )
      })
    }, ignoreInit = FALSE)

    ## Reviews Table ----
    observe_event(reviews_trigger(), {
      output$reviews_table_container <- renderUI({
        reviews <- reviews_data()

        if (is.null(reviews) || nrow(reviews) == 0) {
          return(tags$div(
            class = "no-content-message",
            tags$p(i18n$t("no_reviews"))
          ))
        }

        # Format date
        reviews$review_date_formatted <- vapply(reviews$review_date, function(dt_str) {
          if (is.na(dt_str) || dt_str == "") return("")
          tryCatch({
            gsub("T", " ", substr(dt_str, 1, 16))
          }, error = function(e) "")
        }, character(1), USE.NAMES = FALSE)

        # Format status with badge
        reviews$status_formatted <- sapply(reviews$status, function(status) {
          if (is.na(status) || status == "") status <- "draft"
          status_key <- paste0("status_", status)
          status_label <- as.character(i18n$t(status_key))
          sprintf('<span class="status-badge %s">%s</span>', status, htmltools::htmlEscape(status_label))
        })

        # Add action buttons
        reviews$Actions <- sapply(reviews$review_id, function(id) {
          create_datatable_actions(list(
            list(label = as.character(i18n$t("view")), icon = "eye", type = "primary", class = "btn-view-review", data_attr = list(id = id)),
            list(label = as.character(i18n$t("edit")), icon = "edit", type = "warning", class = "btn-edit-review", data_attr = list(id = id)),
            list(label = as.character(i18n$t("delete")), icon = "trash", type = "danger", class = "btn-delete-review", data_attr = list(id = id))
          ))
        })

        # Select columns to display
        display_data <- data.frame(
          review_id = reviews$review_id,
          reviewer = reviews$reviewer_name,
          date = reviews$review_date_formatted,
          status = reviews$status_formatted,
          version = reviews$version,
          comments = ifelse(
            is.na(reviews$comments) | reviews$comments == "",
            "",
            ifelse(nchar(reviews$comments) > 100, paste0(substr(reviews$comments, 1, 100), "..."), reviews$comments)
          ),
          Actions = reviews$Actions,
          stringsAsFactors = FALSE
        )

        dt <- create_standard_datatable(
          display_data,
          selection = "none",
          col_names = c(
            "ID",
            as.character(i18n$t("reviewer")),
            as.character(i18n$t("review_date")),
            as.character(i18n$t("review_status")),
            as.character(i18n$t("version")),
            as.character(i18n$t("comments")),
            as.character(i18n$t("actions"))
          ),
          col_defs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 1, width = "15%"),
            list(targets = 2, width = "15%", className = "dt-center"),
            list(targets = 3, width = "15%", className = "dt-center"),
            list(targets = 4, width = "10%", className = "dt-center"),
            list(targets = 5, width = "30%"),
            list(targets = 6, width = "15%", className = "dt-center")
          ),
          escape = FALSE
        )

        dt <- add_button_handlers(
          dt,
          handlers = list(
            list(selector = ".btn-view-review", input_id = ns("view_review")),
            list(selector = ".btn-edit-review", input_id = ns("edit_review")),
            list(selector = ".btn-delete-review", input_id = ns("delete_review"))
          ),
          dblclick_input_id = ns("view_review"),
          id_column_index = 0
        )

        tags$div(
          style = "overflow-x: auto;",
          dt
        )
      })
    }, ignoreInit = FALSE)

    # 4) CRUD OPERATIONS ====

    ## Helper: Get unique categories from concept sets ----
    get_categories <- function() {
      data <- concept_sets_data()
      if (is.null(data) || nrow(data) == 0) return(character(0))
      sort(unique(data$category[!is.na(data$category) & data$category != ""]))
    }

    ## Helper: Get subcategories for a category ----
    get_subcategories <- function(category) {
      data <- concept_sets_data()
      if (is.null(data) || nrow(data) == 0 || is.null(category) || category == "") return(character(0))
      filtered <- data[!is.na(data$category) & data$category == category, ]
      sort(unique(filtered$subcategory[!is.na(filtered$subcategory) & filtered$subcategory != ""]))
    }

    ## Update subcategories when category changes ----
    observe_event(input$concept_set_category, {
      selected_category <- input$concept_set_category
      subcategories <- get_subcategories(selected_category)

      placeholder <- if (length(subcategories) == 0) {
        as.character(i18n$t("enter_new_subcategory"))
      } else {
        as.character(i18n$t("select_subcategory"))
      }

      updateSelectizeInput(
        session,
        "concept_set_subcategory",
        choices = subcategories,
        selected = character(0),
        options = list(placeholder = placeholder)
      )
    }, ignoreInit = TRUE)

    ## Confirm Add Category ----
    observe_event(input$confirm_add_category, {
      new_category <- trimws(input$concept_set_category_new)
      if (new_category == "") return()

      # Add to dropdown choices and select it
      categories <- get_categories()
      if (!(new_category %in% categories)) {
        categories <- sort(c(categories, new_category))
      }
      updateSelectizeInput(
        session,
        "concept_set_category",
        choices = categories,
        selected = new_category,
        options = list(placeholder = as.character(i18n$t("select_category")))
      )

      # Switch back to dropdown mode
      shinyjs::runjs(sprintf("
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
      ", ns("category_select_container"), ns("category_text_container"),
         ns("category_show_add"), ns("category_add_buttons")))

      updateTextInput(session, "concept_set_category_new", value = "")
    }, ignoreInit = TRUE)

    ## Confirm Add Subcategory ----
    observe_event(input$confirm_add_subcategory, {
      new_subcategory <- trimws(input$concept_set_subcategory_new)
      if (new_subcategory == "") return()

      # Add to dropdown choices and select it
      selected_category <- input$concept_set_category
      subcategories <- get_subcategories(selected_category)
      if (!(new_subcategory %in% subcategories)) {
        subcategories <- sort(c(subcategories, new_subcategory))
      }
      updateSelectizeInput(
        session,
        "concept_set_subcategory",
        choices = subcategories,
        selected = new_subcategory,
        options = list(placeholder = as.character(i18n$t("select_subcategory")))
      )

      # Switch back to dropdown mode
      shinyjs::runjs(sprintf("
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
      ", ns("subcategory_select_container"), ns("subcategory_text_container"),
         ns("subcategory_show_add"), ns("subcategory_add_buttons")))

      updateTextInput(session, "concept_set_subcategory_new", value = "")
    }, ignoreInit = TRUE)

    ## Add Concept Set (open modal) ----
    observe_event(input$add_concept_set, {
      editing_id(NULL)

      # Reset modal title via JS
      shinyjs::runjs(sprintf(
        "document.querySelector('#%s .modal-header h3').innerHTML = '<i class=\"fas fa-folder-open\" style=\"margin-right: 8px;\"></i>%s';",
        ns("concept_set_modal"),
        as.character(i18n$t("add_concept_set"))
      ))

      # Reset button text to "Add"
      shinyjs::runjs(sprintf(
        "document.querySelector('#%s').innerHTML = '<i class=\"fa fa-plus\" role=\"presentation\" aria-label=\"plus icon\"></i> %s';",
        ns("save_concept_set"),
        as.character(i18n$t("add"))
      ))

      # Reset form fields
      updateTextInput(session, "editing_concept_set_id", value = "")
      updateTextInput(session, "concept_set_name", value = "")
      updateTextInput(session, "concept_set_description", value = "")

      # Update category choices
      categories <- get_categories()
      updateSelectizeInput(
        session,
        "concept_set_category",
        choices = categories,
        selected = character(0),
        options = list(placeholder = as.character(i18n$t("select_category")))
      )
      updateTextInput(session, "concept_set_category_new", value = "")

      # Reset subcategory
      updateSelectizeInput(
        session,
        "concept_set_subcategory",
        choices = character(0),
        selected = character(0),
        options = list(placeholder = as.character(i18n$t("first_select_category")))
      )
      updateTextInput(session, "concept_set_subcategory_new", value = "")

      # Update tags choices
      all_tags <- tags_data()
      tag_choices <- if (!is.null(all_tags) && nrow(all_tags) > 0) all_tags$name else character(0)
      updateSelectizeInput(
        session,
        "concept_set_tags",
        choices = tag_choices,
        selected = character(0)
      )

      # Reset toggle buttons to select mode
      shinyjs::runjs(sprintf("
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
      ", ns("category_select_container"), ns("category_text_container"),
         ns("category_show_add"), ns("category_add_buttons"),
         ns("subcategory_select_container"), ns("subcategory_text_container"),
         ns("subcategory_show_add"), ns("subcategory_add_buttons")))

      # Update modal title via JS
      shinyjs::runjs(sprintf(
        "document.querySelector('#%s .modal-header h3').innerHTML = '<i class=\"fas fa-folder-open\" style=\"margin-right: 8px;\"></i>%s';",
        ns("concept_set_modal"),
        as.character(i18n$t("add_concept_set"))
      ))

      # Hide error messages
      shinyjs::hide("name_error")

      show_modal(ns("concept_set_modal"))
    }, ignoreInit = TRUE)

    ## Edit Concept Set (open modal) ----
    observe_event(input$edit_concept_set, {
      concept_set_id <- input$edit_concept_set
      if (is.null(concept_set_id)) return()

      editing_id(concept_set_id)

      # Load concept set data
      current_language <- i18n$get_translation_language()
      cs <- get_concept_set(concept_set_id, language = current_language)
      if (is.null(cs)) return()

      # Helper to convert NA/NULL to empty string
      na_to_empty <- function(x) if (is.null(x) || is.na(x)) "" else x

      # Populate form fields
      updateTextInput(session, "editing_concept_set_id", value = as.character(concept_set_id))
      updateTextInput(session, "concept_set_name", value = na_to_empty(cs$name))
      updateTextInput(session, "concept_set_description", value = na_to_empty(cs$description))

      # Update category choices and select current
      categories <- get_categories()
      current_category <- na_to_empty(cs$category)
      if (current_category != "" && !(current_category %in% categories)) {
        categories <- c(categories, current_category)
      }
      updateSelectizeInput(
        session,
        "concept_set_category",
        choices = sort(categories),
        selected = current_category,
        options = list(placeholder = as.character(i18n$t("select_category")))
      )
      updateTextInput(session, "concept_set_category_new", value = "")

      # Update subcategory choices and select current
      subcategories <- get_subcategories(current_category)
      current_subcategory <- na_to_empty(cs$subcategory)
      if (current_subcategory != "" && !(current_subcategory %in% subcategories)) {
        subcategories <- c(subcategories, current_subcategory)
      }
      updateSelectizeInput(
        session,
        "concept_set_subcategory",
        choices = sort(subcategories),
        selected = current_subcategory,
        options = list(placeholder = as.character(i18n$t("select_subcategory")))
      )
      updateTextInput(session, "concept_set_subcategory_new", value = "")

      # Update tags choices and select current
      all_tags <- tags_data()
      tag_choices <- if (!is.null(all_tags) && nrow(all_tags) > 0) all_tags$name else character(0)
      tags_value <- na_to_empty(cs$tags)
      current_tags <- if (tags_value != "") {
        trimws(strsplit(tags_value, ",")[[1]])
      } else {
        character(0)
      }
      updateSelectizeInput(
        session,
        "concept_set_tags",
        choices = unique(c(tag_choices, current_tags)),
        selected = current_tags
      )

      # Reset toggle buttons to select mode
      shinyjs::runjs(sprintf("
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
        document.getElementById('%s').style.display = 'block';
        document.getElementById('%s').style.display = 'none';
      ", ns("category_select_container"), ns("category_text_container"),
         ns("category_show_add"), ns("category_add_buttons"),
         ns("subcategory_select_container"), ns("subcategory_text_container"),
         ns("subcategory_show_add"), ns("subcategory_add_buttons")))

      # Update modal title via JS
      shinyjs::runjs(sprintf(
        "document.querySelector('#%s .modal-header h3').innerHTML = '<i class=\"fas fa-folder-open\" style=\"margin-right: 8px;\"></i>%s';",
        ns("concept_set_modal"),
        as.character(i18n$t("edit_concept_set"))
      ))

      # Update button text to "Save"
      shinyjs::runjs(sprintf(
        "document.querySelector('#%s').innerHTML = '<i class=\"fa fa-save\" role=\"presentation\" aria-label=\"save icon\"></i> %s';",
        ns("save_concept_set"),
        as.character(i18n$t("save"))
      ))

      # Hide error messages
      shinyjs::hide("name_error")

      show_modal(ns("concept_set_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Concept Set Modal ----
    observe_event(input$cancel_concept_set, {
      hide_modal(ns("concept_set_modal"))
      editing_id(NULL)
    }, ignoreInit = TRUE)

    ## Save Concept Set ----
    observe_event(input$save_concept_set, {
      # Validate required fields
      name <- trimws(input$concept_set_name)
      if (name == "") {
        shinyjs::show("name_error")
        shinyjs::html("name_error", as.character(i18n$t("name_required")))
        return()
      }
      shinyjs::hide("name_error")

      # Get other fields
      description_raw <- input$concept_set_description
      description <- if (is.null(description_raw) || length(description_raw) == 0 || trimws(description_raw) == "") {
        NULL
      } else {
        trimws(description_raw)
      }

      # Get category (from select or text input)
      category_select <- input$concept_set_category
      category_new <- trimws(input$concept_set_category_new)
      # Check which mode is active - handle empty vectors
      category <- if (length(category_new) > 0 && category_new != "") {
        category_new
      } else if (length(category_select) > 0 && category_select != "") {
        category_select
      } else {
        NULL
      }

      # Get subcategory (from select or text input)
      subcategory_select <- input$concept_set_subcategory
      subcategory_new <- trimws(input$concept_set_subcategory_new)
      subcategory <- if (length(subcategory_new) > 0 && subcategory_new != "") {
        subcategory_new
      } else if (length(subcategory_select) > 0 && subcategory_select != "") {
        subcategory_select
      } else {
        NULL
      }

      # Get tags (multiple selection)
      selected_tags <- input$concept_set_tags
      tags <- if (length(selected_tags) > 0) paste(selected_tags, collapse = ",") else NULL

      # Get current user information
      user_first_name <- NULL
      user_last_name <- NULL
      user_profession <- NULL
      user_affiliation <- NULL
      user_orcid <- NULL
      if (!is.null(current_user) && is.reactive(current_user)) {
        user <- current_user()
        if (!is.null(user)) {
          user_first_name <- user$first_name
          user_last_name <- user$last_name
          user_profession <- user$profession
          user_affiliation <- user$affiliation
          user_orcid <- user$orcid
        }
      }

      # Get current language
      current_language <- i18n$get_translation_language()

      # Add or update
      current_editing_id <- editing_id()
      if (is.null(current_editing_id)) {
        # Add new concept set
        add_concept_set(
          name = name,
          description = description,
          category = category,
          subcategory = subcategory,
          tags = tags,
          created_by_first_name = user_first_name,
          created_by_last_name = user_last_name,
          created_by_profession = user_profession,
          created_by_affiliation = user_affiliation,
          created_by_orcid = user_orcid,
          language = current_language
        )
        showNotification(as.character(i18n$t("concept_set_added")), type = "message")
      } else {
        # Update existing concept set
        update_concept_set(
          concept_set_id = current_editing_id,
          name = name,
          description = description,
          category = category,
          subcategory = subcategory,
          tags = tags,
          modified_by_first_name = user_first_name,
          modified_by_last_name = user_last_name,
          modified_by_profession = user_profession,
          modified_by_affiliation = user_affiliation,
          modified_by_orcid = user_orcid,
          language = current_language
        )
        showNotification(as.character(i18n$t("concept_set_updated")), type = "message")
      }

      # Hide modal and refresh data
      hide_modal(ns("concept_set_modal"))
      editing_id(NULL)

      # Reload data
      current_language <- i18n$get_translation_language()
      data <- get_all_concept_sets(language = current_language)
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)
    }, ignoreInit = TRUE)

    # 5) TAGS MANAGEMENT ====

    ## Open Manage Tags Modal ----
    observe_event(input$open_manage_tags, {
      # Refresh tags data
      all_tags <- get_all_tags()
      tags_data(all_tags)

      # Reset new tag input
      updateTextInput(session, "new_tag_name", value = "")
      shinyjs::hide("new_tag_error")

      # Show modal first
      show_modal(ns("manage_tags_modal"))

      # Trigger table render after delay to allow modal to become visible
      shinyjs::delay(500, {
        tags_trigger(tags_trigger() + 1)
      })

      # Force Shiny to detect the output is now visible and render it
      shinyjs::delay(600, {
        shinyjs::runjs(sprintf("
          $(window).trigger('resize');
          var $el = $('#%s');
          if ($el.length) {
            $el.trigger('shown');
            Shiny.bindAll($el.parent());
          }
        ", ns("tags_table")))
      })
    }, ignoreInit = TRUE)

    ## Close Manage Tags Modal ----
    observe_event(input$close_manage_tags, {
      hide_modal(ns("manage_tags_modal"))

      # Refresh tags in concept set modal
      all_tags <- tags_data()
      tag_choices <- if (!is.null(all_tags) && nrow(all_tags) > 0) all_tags$name else character(0)
      current_selection <- input$concept_set_tags
      updateSelectizeInput(
        session,
        "concept_set_tags",
        choices = unique(c(tag_choices, current_selection)),
        selected = current_selection
      )
    }, ignoreInit = TRUE)

    ## Tags Table ----
    observe_event(tags_trigger(), {
      output$tags_table <- DT::renderDT({
        all_tags <- tags_data()

        if (is.null(all_tags) || nrow(all_tags) == 0) {
          return(create_empty_datatable(as.character(i18n$t("no_tags"))))
        }

        # Create display data with color badge
        display_data <- data.frame(
          tag_id = all_tags$tag_id,
          stringsAsFactors = FALSE
        )

        # Name with color swatch
        display_data$name <- sapply(seq_len(nrow(all_tags)), function(i) {
          tag_color <- if (!is.null(all_tags$color[i]) && all_tags$color[i] != "") all_tags$color[i] else "#6c757d"
          sprintf(
            '<span class="tag-color-badge"><span class="tag-color-swatch" style="background-color: %s;"></span>%s</span>',
            tag_color, htmltools::htmlEscape(all_tags$name[i])
          )
        })

        # Get usage count for each tag
        display_data$usage <- sapply(all_tags$name, function(tag_name) {
          get_tag_usage_count(tag_name)
        })

        # Add action buttons
        display_data$actions <- sapply(seq_len(nrow(display_data)), function(i) {
          tag_id <- display_data$tag_id[i]
          usage <- display_data$usage[i]

          # Delete button is disabled if tag is in use
          delete_class <- if (usage > 0) "btn-delete disabled" else "btn-delete"
          delete_title <- if (usage > 0) as.character(i18n$t("cannot_delete_tag_in_use")) else ""

          create_datatable_actions(list(
            list(
              label = as.character(i18n$t("edit")),
              icon = "edit",
              type = "warning",
              class = "btn-edit-tag",
              data_attr = list(id = tag_id)
            ),
            list(
              label = as.character(i18n$t("delete")),
              icon = "trash",
              type = "danger",
              class = delete_class,
              data_attr = list(id = tag_id, usage = usage)
            )
          ))
        })

        dt <- create_standard_datatable(
          display_data,
          selection = "none",
          filter = "none",
          page_length = 10,
          dom = "tip",
          col_names = c(
            "ID",
            as.character(i18n$t("tag_name")),
            as.character(i18n$t("usage")),
            as.character(i18n$t("actions"))
          ),
          col_defs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 1, width = "50%"),
            list(targets = 2, width = "20%", className = "dt-center"),
            list(targets = 3, width = "30%", className = "dt-center")
          ),
          escape = FALSE
        )

        add_button_handlers(dt, handlers = list(
          list(selector = ".btn-edit-tag", input_id = ns("edit_tag")),
          list(selector = ".btn-delete:not(.disabled)", input_id = ns("delete_tag"))
        ))
      })
    }, ignoreInit = FALSE)

    ## Add New Tag ----
    observe_event(input$add_new_tag, {
      tag_name <- trimws(input$new_tag_name)
      tag_color <- input$new_tag_color

      if (tag_name == "") {
        shinyjs::show("new_tag_error")
        shinyjs::html("new_tag_error", as.character(i18n$t("tag_name_required")))
        return()
      }

      # Check if tag already exists
      all_tags <- tags_data()
      if (!is.null(all_tags) && tag_name %in% all_tags$name) {
        shinyjs::show("new_tag_error")
        shinyjs::html("new_tag_error", as.character(i18n$t("tag_already_exists")))
        return()
      }

      shinyjs::hide("new_tag_error")

      # Add tag with color
      if (is.null(tag_color) || tag_color == "") tag_color <- "#6c757d"
      add_tag(tag_name, tag_color)
      showNotification(as.character(i18n$t("tag_added")), type = "message")

      # Refresh and reset inputs
      updateTextInput(session, "new_tag_name", value = "")
      # Reset color picker
      shinyjs::runjs(sprintf("
        var picker = document.getElementById('%s').closest('.color-picker');
        if (picker) {
          picker.querySelectorAll('.color-swatch').forEach(function(el) {
            el.classList.remove('selected');
          });
          var defaultSwatch = picker.querySelector('.color-swatch[data-color=\"#6c757d\"]');
          if (defaultSwatch) {
            defaultSwatch.classList.add('selected');
          }
        }
        Shiny.setInputValue('%s', '#6c757d', {priority: 'event'});
      ", ns("new_tag_color"), ns("new_tag_color")))
      all_tags <- get_all_tags()
      tags_data(all_tags)
      tags_trigger(tags_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Edit Tag (open modal) ----
    observe_event(input$edit_tag, {
      tag_id <- input$edit_tag
      if (is.null(tag_id)) return()

      editing_tag_id(tag_id)

      # Get tag data
      all_tags <- tags_data()
      tag <- all_tags[all_tags$tag_id == tag_id, ]
      if (nrow(tag) == 0) return()

      updateTextInput(session, "editing_tag_id", value = as.character(tag_id))
      updateTextInput(session, "edit_tag_name", value = tag$name[1])

      # Set color picker value
      tag_color <- if (!is.null(tag$color[1]) && tag$color[1] != "") tag$color[1] else "#6c757d"
      shinyjs::runjs(sprintf("
        var picker = document.getElementById('%s').closest('.color-picker');
        if (picker) {
          picker.querySelectorAll('.color-swatch').forEach(function(el) {
            el.classList.remove('selected');
          });
          var matchingSwatch = picker.querySelector('.color-swatch[data-color=\"%s\"]');
          if (matchingSwatch) {
            matchingSwatch.classList.add('selected');
          }
        }
        Shiny.setInputValue('%s', '%s', {priority: 'event'});
      ", ns("edit_tag_color"), tag_color, ns("edit_tag_color"), tag_color))

      shinyjs::hide("edit_tag_error")

      show_modal(ns("edit_tag_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Edit Tag ----
    observe_event(input$cancel_edit_tag, {
      hide_modal(ns("edit_tag_modal"))
      editing_tag_id(NULL)
    }, ignoreInit = TRUE)

    ## Save Edit Tag ----
    observe_event(input$save_edit_tag, {
      tag_id <- editing_tag_id()
      if (is.null(tag_id)) return()

      tag_name <- trimws(input$edit_tag_name)
      tag_color <- input$edit_tag_color

      if (tag_name == "") {
        shinyjs::show("edit_tag_error")
        shinyjs::html("edit_tag_error", as.character(i18n$t("tag_name_required")))
        return()
      }

      # Check if tag name already exists (excluding current)
      all_tags <- tags_data()
      other_tags <- all_tags[all_tags$tag_id != tag_id, ]
      if (tag_name %in% other_tags$name) {
        shinyjs::show("edit_tag_error")
        shinyjs::html("edit_tag_error", as.character(i18n$t("tag_already_exists")))
        return()
      }

      shinyjs::hide("edit_tag_error")

      # Update tag with color
      if (is.null(tag_color) || tag_color == "") tag_color <- "#6c757d"
      update_tag(tag_id, tag_name, tag_color)
      showNotification(as.character(i18n$t("tag_updated")), type = "message")

      # Refresh
      hide_modal(ns("edit_tag_modal"))
      editing_tag_id(NULL)
      all_tags <- get_all_tags()
      tags_data(all_tags)
      tags_trigger(tags_trigger() + 1)

      # Refresh concept sets data (tag names may have changed)
      data <- get_all_concept_sets()
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Delete Tag (open confirmation modal) ----
    observe_event(input$delete_tag, {
      tag_id <- input$delete_tag
      if (is.null(tag_id)) return()

      deleting_tag_id(tag_id)

      # Get tag name
      all_tags <- tags_data()
      tag <- all_tags[all_tags$tag_id == tag_id, ]
      tag_name <- if (nrow(tag) > 0) tag$name[1] else tag_id

      updateTextInput(session, "deleting_tag_id", value = as.character(tag_id))
      shinyjs::html("delete_tag_message", paste0(
        as.character(i18n$t("confirm_delete_tag")), " <strong>", tag_name, "</strong>?"
      ))

      show_modal(ns("delete_tag_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Delete Tag ----
    observe_event(input$cancel_delete_tag, {
      hide_modal(ns("delete_tag_modal"))
      deleting_tag_id(NULL)
    }, ignoreInit = TRUE)

    ## Confirm Delete Tag ----
    observe_event(input$confirm_delete_tag, {
      tag_id <- deleting_tag_id()
      if (is.null(tag_id)) return()

      # Delete tag
      result <- delete_tag(tag_id)
      if (result) {
        showNotification(as.character(i18n$t("tag_deleted")), type = "message")
      } else {
        showNotification(as.character(i18n$t("cannot_delete_tag_in_use")), type = "error")
      }

      # Refresh
      hide_modal(ns("delete_tag_modal"))
      deleting_tag_id(NULL)
      all_tags <- get_all_tags()
      tags_data(all_tags)
      tags_trigger(tags_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Delete Concept Set (open confirmation modal) ----
    observe_event(input$delete_concept_set, {
      concept_set_id <- input$delete_concept_set
      if (is.null(concept_set_id)) return()

      deleting_id(concept_set_id)

      # Get concept set name for confirmation message
      cs <- get_concept_set(concept_set_id)
      cs_name <- if (!is.null(cs)) cs$name else concept_set_id

      # Update confirmation message
      updateTextInput(session, "deleting_concept_set_id", value = as.character(concept_set_id))
      shinyjs::html("delete_confirmation_message", paste0(
        as.character(i18n$t("confirm_delete_concept_set")), "<br><strong>", cs_name, "</strong>?"
      ))

      show_modal(ns("delete_concept_set_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Delete ----
    observe_event(input$cancel_delete_concept_set, {
      hide_modal(ns("delete_concept_set_modal"))
      deleting_id(NULL)
    }, ignoreInit = TRUE)

    ## Confirm Delete ----
    observe_event(input$confirm_delete_concept_set, {
      concept_set_id <- deleting_id()
      if (is.null(concept_set_id)) return()

      # Delete concept set
      delete_concept_set(concept_set_id)
      showNotification(as.character(i18n$t("concept_set_deleted")), type = "message")

      # Hide modal
      hide_modal(ns("delete_concept_set_modal"))
      deleting_id(NULL)

      # Reload data
      current_language <- i18n$get_translation_language()
      data <- get_all_concept_sets(language = current_language)
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)
    }, ignoreInit = TRUE)

    # 6) CONCEPT SET DETAILS VIEW ====

    ## State for details view ----
    viewing_concept_set_id <- reactiveVal(NULL)
    selected_concept_id <- reactiveVal(NULL)
    concepts_trigger <- reactiveVal(0)
    viewing_review_id <- reactiveVal(NULL)

    ## View Concept Set (open details page) ----
    observe_event(input$view_concept_set, {
      concept_set_id <- input$view_concept_set
      if (is.null(concept_set_id)) return()

      viewing_concept_set_id(concept_set_id)

      # Load concept set data
      current_language <- i18n$get_translation_language()
      cs <- get_concept_set(concept_set_id, language = current_language)
      if (is.null(cs)) return()

      # Update the title with status and version badges
      version <- if (is.null(cs$version) || is.na(cs$version)) "1.0.0" else cs$version
      status <- if (is.null(cs$review_status) || is.na(cs$review_status)) "draft" else cs$review_status

      # Get status translation key
      status_key <- paste0("status_", status)
      status_label <- as.character(i18n$t(status_key))

      # Update title (name only)
      shinyjs::html("concept_set_detail_title", htmltools::htmlEscape(cs$name))

      # Update badges (separate span next to title)
      badges_html <- sprintf(
        '<span class="version-badge" style="cursor: pointer;" onclick="Shiny.setInputValue(\'%s\', Date.now(), {priority: \'event\'});" title="%s">v%s</span><span class="status-badge %s" style="cursor: pointer;" onclick="Shiny.setInputValue(\'%s\', Date.now(), {priority: \'event\'});" title="%s">%s</span>',
        ns("open_version_modal"),
        as.character(i18n$t("new_version")),
        htmltools::htmlEscape(version),
        status,
        ns("open_status_modal"),
        as.character(i18n$t("change_status")),
        htmltools::htmlEscape(status_label)
      )
      shinyjs::html("concept_set_badges", badges_html)

      # Switch to details view
      shinyjs::hide("concept_sets_list_container")
      shinyjs::show("concept_set_details_container")

      # Reset edit mode and clear any pending changes
      concepts_edit_mode(FALSE)
      pending_additions(list())
      pending_deletions(character(0))
      shinyjs::hide("edit_mode_buttons")
      shinyjs::hide("concepts_edit_buttons")
      shinyjs::runjs(sprintf(
        "$('#%s').closest('.settings-backup-container').removeClass('edit-mode');",
        ns("concepts_section_left")
      ))

      # Show export and edit buttons if user can edit
      shinyjs::show("export_concept_set_btn")
      if (can_edit()) {
        shinyjs::show("edit_concepts_btn")
      }

      # Reset selected concept
      selected_concept_id(NULL)

      # Trigger concepts table render
      concepts_trigger(concepts_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Back to list ----
    observe_event(input$back_to_list, {
      viewing_concept_set_id(NULL)
      selected_concept_id(NULL)

      # Reset edit mode and discard any pending changes
      concepts_edit_mode(FALSE)
      pending_additions(list())
      pending_deletions(character(0))
      shinyjs::hide("edit_mode_buttons")
      shinyjs::hide("concepts_edit_buttons")

      # Switch back to list view
      shinyjs::hide("concept_set_details_container")
      shinyjs::show("concept_sets_list_container")
    }, ignoreInit = TRUE)

    ## Concepts Table Container (top-left quadrant) ----
    observe_event(concepts_trigger(), {
      output$concepts_table_container <- renderUI({
        cs_id <- viewing_concept_set_id()
        if (is.null(cs_id)) {
          shinyjs::hide("concepts_fuzzy_search_container")
          return(tags$div(
            class = "no-content-message",
            tags$p(i18n$t("no_concept_sets"))
          ))
        }

        # Get concepts for this concept set
        concepts <- get_concept_set_items(cs_id)

        # Get pending changes to check total count
        additions <- pending_additions()
        deletions <- pending_deletions()

        # Calculate effective concept count
        saved_count <- if (!is.null(concepts)) nrow(concepts) else 0
        deleted_count <- if (!is.null(concepts) && length(deletions) > 0) {
          sum(as.character(concepts$concept_id) %in% deletions)
        } else 0
        added_count <- length(additions)
        effective_count <- saved_count - deleted_count + added_count

        if (effective_count == 0) {
          shinyjs::hide("concepts_fuzzy_search_container")
          return(tags$div(
            class = "no-content-message",
            tags$p(i18n$t("no_concepts"))
          ))
        }

        # Show fuzzy search when we have concepts
        shinyjs::show("concepts_fuzzy_search_container")

        # Return datatable container
        DT::DTOutput(ns("concepts_table"))
      })

      # Render the datatable separately
      output$concepts_table <- DT::renderDT({
        cs_id <- viewing_concept_set_id()
        if (is.null(cs_id)) return(NULL)

        concepts <- get_concept_set_items(cs_id)

        # Get pending changes
        additions <- pending_additions()
        deletions <- pending_deletions()

        # Filter out pending deletions from saved concepts
        if (!is.null(concepts) && nrow(concepts) > 0 && length(deletions) > 0) {
          concepts <- concepts[!as.character(concepts$concept_id) %in% deletions, ]
        }

        # Add pending additions
        if (length(additions) > 0) {
          additions_df <- dplyr::bind_rows(lapply(additions, function(x) {
            data.frame(
              concept_id = x$concept_id,
              concept_name = x$concept_name,
              vocabulary_id = x$vocabulary_id,
              concept_code = x$concept_code,
              domain_id = if (!is.null(x$domain_id)) x$domain_id else NA_character_,
              concept_class_id = if (!is.null(x$concept_class_id)) x$concept_class_id else NA_character_,
              standard_concept = x$standard_concept,
              is_excluded = if (!is.null(x$is_excluded)) x$is_excluded else FALSE,
              include_descendants = if (!is.null(x$include_descendants)) x$include_descendants else TRUE,
              include_mapped = if (!is.null(x$include_mapped)) x$include_mapped else TRUE,
              stringsAsFactors = FALSE
            )
          }))

          if (is.null(concepts) || nrow(concepts) == 0) {
            concepts <- additions_df
          } else {
            concepts <- dplyr::bind_rows(concepts, additions_df)
          }
        }

        if (is.null(concepts) || nrow(concepts) == 0) return(NULL)

        # Check if in edit mode
        is_edit_mode <- concepts_edit_mode()

        # In view mode, resolve the concept set (apply exclude/descendants/mapped rules)
        # In edit mode, show the raw items with toggles
        if (!is_edit_mode) {
          # Resolve concept set - this will include descendants and mapped, exclude is_excluded
          resolved <- resolve_concept_set(concepts)

          if (is.null(resolved) || nrow(resolved) == 0) return(NULL)

          # Transform standard_concept to readable text
          standard_display <- dplyr::case_when(
            is.na(resolved$standard_concept) | resolved$standard_concept == "" ~ "Non-standard",
            resolved$standard_concept == "S" ~ "Standard",
            resolved$standard_concept == "C" ~ "Classification",
            TRUE ~ "Non-standard"
          )

          # Prepare display data for view mode
          display_data <- data.frame(
            concept_id = resolved$concept_id,
            vocabulary_id = factor(resolved$vocabulary_id),
            concept_name = resolved$concept_name,
            concept_code = resolved$concept_code,
            domain_id = factor(ifelse(is.na(resolved$domain_id), "", resolved$domain_id)),
            concept_class_id = factor(ifelse(is.na(resolved$concept_class_id), "", resolved$concept_class_id)),
            standard_concept = factor(standard_display, levels = c("Standard", "Classification", "Non-standard")),
            stringsAsFactors = FALSE
          )
        } else {
          # Edit mode: show raw items with toggles

          # Transform standard_concept to readable text
          standard_display <- dplyr::case_when(
            is.na(concepts$standard_concept) | concepts$standard_concept == "" ~ "Non-standard",
            concepts$standard_concept == "S" ~ "Standard",
            concepts$standard_concept == "C" ~ "Classification",
            TRUE ~ "Non-standard"
          )

          # Prepare display data - vocabulary_id before concept_name
          display_data <- data.frame(
            concept_id = concepts$concept_id,
            vocabulary_id = factor(concepts$vocabulary_id),
            concept_name = concepts$concept_name,
            concept_code = concepts$concept_code,
            domain_id = factor(ifelse(is.na(concepts$domain_id), "", concepts$domain_id)),
            concept_class_id = factor(ifelse(is.na(concepts$concept_class_id), "", concepts$concept_class_id)),
            standard_concept = factor(standard_display, levels = c("Standard", "Classification", "Non-standard")),
            stringsAsFactors = FALSE
          )
        }

        # In edit mode, add toggle columns for is_excluded, include_descendants, include_mapped
        if (can_edit() && is_edit_mode) {
          # Add toggle data from concepts
          display_data$is_excluded <- if ("is_excluded" %in% names(concepts)) concepts$is_excluded else FALSE
          display_data$include_descendants <- if ("include_descendants" %in% names(concepts)) concepts$include_descendants else TRUE
          display_data$include_mapped <- if ("include_mapped" %in% names(concepts)) concepts$include_mapped else TRUE

          # Prepare toggles
          display_data <- prepare_concept_set_toggles(display_data, ns, "toggle_concept_option")

          # Select columns for edit mode display (with toggles)
          display_data <- display_data[, c("concept_id", "vocabulary_id", "concept_name", "concept_code",
                                           "domain_id", "concept_class_id", "standard_concept",
                                           "exclude_toggle", "descendants_toggle", "mapped_toggle")]

          dt <- create_standard_datatable(
            display_data,
            selection = "multiple",
            col_names = c(
              as.character(i18n$t("omop_concept_id")),
              "Vocabulary",
              as.character(i18n$t("omop_concept_name")),
              "Code",
              as.character(i18n$t("domain_id")),
              as.character(i18n$t("concept_class_id")),
              as.character(i18n$t("standard")),
              as.character(i18n$t("exclude")),
              as.character(i18n$t("include_descendants")),
              as.character(i18n$t("include_mapped"))
            ),
            col_defs = list(
              list(targets = 0, width = "8%"),
              list(targets = 1, width = "9%"),
              list(targets = 2, width = "22%"),
              list(targets = 3, width = "9%"),
              list(targets = 4, width = "9%", visible = FALSE),
              list(targets = 5, width = "9%", visible = FALSE),
              list(targets = 6, width = "10%", className = "dt-center"),
              list(targets = 7, width = "7%", className = "dt-center"),
              list(targets = 8, width = "9%", className = "dt-center"),
              list(targets = 9, width = "7%", className = "dt-center")
            ),
            escape = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE),
            show_colvis = TRUE
          )

          # Add option to prevent row selection when clicking on toggles
          dt$x$options$select <- list(
            style = "multi",
            selector = "td:not(:has(.toggle-switch))"
          )

          # Apply standard concept column styling
          dt <- style_standard_concept_column(dt, "standard_concept")
        } else {
          dt <- create_standard_datatable(
            display_data,
            selection = "single",
            col_names = c(
              as.character(i18n$t("omop_concept_id")),
              "Vocabulary",
              as.character(i18n$t("omop_concept_name")),
              "Code",
              as.character(i18n$t("domain_id")),
              as.character(i18n$t("concept_class_id")),
              as.character(i18n$t("standard"))
            ),
            col_defs = list(
              list(targets = 0, width = "9%"),
              list(targets = 1, width = "11%"),
              list(targets = 2, width = "30%"),
              list(targets = 3, width = "12%"),
              list(targets = 4, width = "11%", visible = FALSE),
              list(targets = 5, width = "11%", visible = FALSE),
              list(targets = 6, width = "13%", className = "dt-center")
            ),
            escape = TRUE,
            show_colvis = TRUE
          )

          # Apply standard concept column styling
          dt <- style_standard_concept_column(dt, "standard_concept")
        }

        dt
      })
    }, ignoreInit = FALSE)

    ## Handle concept selection in concepts table ----
    observe_event(input$concepts_table_rows_selected, {
      rows <- input$concepts_table_rows_selected
      if (is.null(rows) || length(rows) == 0) {
        selected_concept_id(NULL)
        return()
      }

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      concepts <- get_concept_set_items(cs_id)
      if (is.null(concepts) || nrow(concepts) == 0) return()

      # In view mode, we display resolved concepts, so get them for selection
      is_edit_mode <- concepts_edit_mode()
      if (!is_edit_mode) {
        resolved <- resolve_concept_set(concepts)
        if (!is.null(resolved) && nrow(resolved) > 0) {
          selected_concept_id(resolved$concept_id[rows])
        }
      } else {
        selected_concept_id(concepts$concept_id[rows])
      }
    }, ignoreInit = TRUE)

    ## Handle toggle changes for concept options ----
    observe_event(input$toggle_concept_option, {
      toggle_data <- input$toggle_concept_option
      if (is.null(toggle_data)) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      concept_id <- toggle_data$concept_id
      field <- toggle_data$field
      value <- toggle_data$value

      if (is.null(concept_id) || is.null(field)) return()

      # Update the database immediately
      if (field == "is_excluded") {
        update_concept_set_item(cs_id, concept_id, is_excluded = value)
      } else if (field == "include_descendants") {
        update_concept_set_item(cs_id, concept_id, include_descendants = value)
      } else if (field == "include_mapped") {
        update_concept_set_item(cs_id, concept_id, include_mapped = value)
      }
    }, ignoreInit = TRUE)

    ## Selected Concept Details (bottom-left quadrant) ----
    output$selected_concept_details <- renderUI({
      concept_id <- selected_concept_id()

      if (is.null(concept_id)) {
        return(render_concept_details(
          concept = NULL,
          i18n = i18n,
          empty_message = as.character(i18n$t("no_concept_selected"))
        ))
      }

      # Get concept details from vocabulary database
      concept <- get_concept_by_id(concept_id)

      render_concept_details(
        concept = concept,
        i18n = i18n,
        empty_message = as.character(i18n$t("no_concept_selected"))
      )
    })

    ## Comments Display (top-right quadrant, comments tab) ----
    output$comments_display <- renderUI({
      cs_id <- viewing_concept_set_id()

      if (is.null(cs_id)) {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_comments"))
        ))
      }

      # Get concept set data
      current_language <- i18n$get_translation_language()
      cs <- get_concept_set(cs_id, language = current_language)

      if (is.null(cs) || is.na(cs$etl_comment) || cs$etl_comment == "") {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_comments"))
        ))
      }

      tags$div(
        class = "comments-content",
        tags$pre(
          class = "etl-comment-text",
          cs$etl_comment
        )
      )
    })

    ## Stats Display (statistics tab) ----
    output$stats_display <- renderUI({
      tags$div(
        class = "no-content-message",
        tags$p(i18n$t("no_stats"))
      )
    })

    ## Review Display (review tab) ----
    output$review_display <- renderUI({
      tags$div(
        class = "no-content-message",
        tags$p(i18n$t("coming_soon"))
      )
    })

    ## Main tab switching (Concepts, Comments, Statistics, Review) ----
    observe_event(input$tab_concepts, {
      # Show concepts panel, hide others
      shinyjs::show("panel_concepts")
      shinyjs::hide("panel_comments")
      shinyjs::hide("panel_stats")
      shinyjs::hide("panel_review")

      # Update active state on tab buttons
      shinyjs::runjs(sprintf("
        document.getElementById('%s').classList.add('active');
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.remove('active');
      ", ns("tab_concepts"), ns("tab_comments"), ns("tab_stats"), ns("tab_review")))
    }, ignoreInit = TRUE)

    observe_event(input$tab_comments, {
      # Show comments panel, hide others
      shinyjs::hide("panel_concepts")
      shinyjs::show("panel_comments")
      shinyjs::hide("panel_stats")
      shinyjs::hide("panel_review")

      # Update active state on tab buttons
      shinyjs::runjs(sprintf("
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.add('active');
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.remove('active');
      ", ns("tab_concepts"), ns("tab_comments"), ns("tab_stats"), ns("tab_review")))
    }, ignoreInit = TRUE)

    observe_event(input$tab_stats, {
      # Show stats panel, hide others
      shinyjs::hide("panel_concepts")
      shinyjs::hide("panel_comments")
      shinyjs::show("panel_stats")
      shinyjs::hide("panel_review")

      # Update active state on tab buttons
      shinyjs::runjs(sprintf("
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.add('active');
        document.getElementById('%s').classList.remove('active');
      ", ns("tab_concepts"), ns("tab_comments"), ns("tab_stats"), ns("tab_review")))
    }, ignoreInit = TRUE)

    observe_event(input$tab_review, {
      # Show review panel, hide others
      shinyjs::hide("panel_concepts")
      shinyjs::hide("panel_comments")
      shinyjs::hide("panel_stats")
      shinyjs::show("panel_review")

      # Update active state on tab buttons
      shinyjs::runjs(sprintf("
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.add('active');
      ", ns("tab_concepts"), ns("tab_comments"), ns("tab_stats"), ns("tab_review")))

      # Load reviews for this concept set
      cs_id <- viewing_concept_set_id()
      if (!is.null(cs_id)) {
        reviews <- get_concept_set_reviews(cs_id)
        reviews_data(reviews)
        reviews_trigger(reviews_trigger() + 1)

        # Update review status dropdown
        status_choices <- c("pending_review", "approved", "needs_revision")
        status_labels <- sapply(status_choices, function(s) {
          as.character(i18n$t(paste0("status_", s)))
        })
        names(status_choices) <- status_labels
        updateSelectInput(session, "review_status_input", choices = status_choices, selected = "pending_review")
      }
    }, ignoreInit = TRUE)

    ## Sub-tab switching for Related Concepts section ----
    observe_event(input$subtab_related, {
      # Show related content, hide others
      shinyjs::show("related_tab_content")
      shinyjs::hide("hierarchy_tab_content")
      shinyjs::hide("synonyms_tab_content")

      # Update active state on sub-tab buttons
      shinyjs::runjs(sprintf("
        document.getElementById('%s').classList.add('active');
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.remove('active');
      ", ns("subtab_related"), ns("subtab_hierarchy"), ns("subtab_synonyms")))
    }, ignoreInit = TRUE)

    observe_event(input$subtab_hierarchy, {
      # Show hierarchy content, hide others
      shinyjs::hide("related_tab_content")
      shinyjs::show("hierarchy_tab_content")
      shinyjs::hide("synonyms_tab_content")

      # Update active state on sub-tab buttons
      shinyjs::runjs(sprintf("
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.add('active');
        document.getElementById('%s').classList.remove('active');
      ", ns("subtab_related"), ns("subtab_hierarchy"), ns("subtab_synonyms")))
    }, ignoreInit = TRUE)

    observe_event(input$subtab_synonyms, {
      # Show synonyms content, hide others
      shinyjs::hide("related_tab_content")
      shinyjs::hide("hierarchy_tab_content")
      shinyjs::show("synonyms_tab_content")

      # Update active state on sub-tab buttons
      shinyjs::runjs(sprintf("
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.remove('active');
        document.getElementById('%s').classList.add('active');
      ", ns("subtab_related"), ns("subtab_hierarchy"), ns("subtab_synonyms")))
    }, ignoreInit = TRUE)

    ## Handle Related Section Fullscreen Toggle ----
    observe_event(input$related_expanded_toggle, {
      expanded <- input$related_expanded_toggle$expanded
      related_section_expanded(expanded)

      # Trigger hierarchy graph regeneration with appropriate height
      hierarchy_graph_trigger(hierarchy_graph_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Related Concepts Display (sub-tab in related concepts section) ----
    output$related_display <- renderUI({
      concept_id <- selected_concept_id()

      if (is.null(concept_id)) {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_concept_selected"))
        ))
      }

      # Get related concepts from vocabulary database
      related <- get_related_concepts(concept_id)

      if (is.null(related) || nrow(related) == 0) {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_related_concepts"))
        ))
      }

      # Return DataTable output
      DT::DTOutput(ns("related_concepts_table"))
    })

    # Related concepts DataTable
    output$related_concepts_table <- DT::renderDT({
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return(NULL)

      related <- get_related_concepts(concept_id)
      if (is.null(related) || nrow(related) == 0) return(NULL)

      # Reorder columns: relationship_id, concept_name, vocabulary_id, concept_id (hidden)
      display_data <- data.frame(
        relationship_id = related$relationship_id,
        concept_name = related$concept_name,
        vocabulary_id = related$vocabulary_id,
        concept_id = related$concept_id,
        stringsAsFactors = FALSE
      )

      DT::datatable(
        display_data,
        selection = "none",
        rownames = FALSE,
        colnames = c("Relationship", as.character(i18n$t("omop_concept_name")), "Vocabulary", "OMOP ID"),
        options = list(
          pageLength = 8,
          dom = "tip",
          language = get_datatable_language(),
          columnDefs = list(
            list(targets = 3, visible = FALSE),  # OMOP ID hidden
            list(targets = 0, width = "25%"),
            list(targets = 1, width = "45%"),
            list(targets = 2, width = "30%")
          )
        )
      )
    })

    ## Hierarchy Display (sub-tab in related concepts section) ----
    output$hierarchy_display <- renderUI({
      concept_id <- selected_concept_id()

      if (is.null(concept_id)) {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_concept_selected"))
        ))
      }

      # Get hierarchy graph data
      hierarchy_data <- get_concept_hierarchy_graph(concept_id)

      if (is.null(hierarchy_data$stats) ||
          (hierarchy_data$stats$total_ancestors == 0 && hierarchy_data$stats$total_descendants == 0)) {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_related_concepts"))
        ))
      }

      # Show stats and visNetwork graph
      tagList(
        # Stats widget
        tags$div(
          class = "hierarchy-stats-widget",
          style = "padding: 10px; margin-bottom: 10px; background: #f8f9fa; border-radius: 6px; display: flex; gap: 20px;",
          tags$div(
            class = "flex-center-gap-8",
            tags$span(style = "font-size: 18px; color: #6c757d;", HTML("&#8593;")),
            tags$span(style = "font-weight: bold; color: #333;", hierarchy_data$stats$total_ancestors),
            tags$span(style = "color: #666; font-size: 13px;", "ancestors")
          ),
          tags$div(
            class = "flex-center-gap-8",
            tags$span(style = "font-size: 18px; color: #28a745;", HTML("&#8595;")),
            tags$span(style = "font-weight: bold; color: #333;", hierarchy_data$stats$total_descendants),
            tags$span(style = "color: #666; font-size: 13px;", tolower(as.character(i18n$t("descendants"))))
          )
        ),
        # visNetwork graph container - height managed via CSS
        tags$div(
          class = "hierarchy-graph-container",
          visNetwork::visNetworkOutput(ns("hierarchy_graph"), height = "100%")
        )
      )
    })

    # Hierarchy visNetwork graph
    output$hierarchy_graph <- visNetwork::renderVisNetwork({
      # Depend on trigger for fullscreen toggle
      hierarchy_graph_trigger()

      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return(NULL)

      hierarchy_data <- get_concept_hierarchy_graph(concept_id)

      if (nrow(hierarchy_data$nodes) == 0) {
        return(NULL)
      }

      visNetwork::visNetwork(
        hierarchy_data$nodes,
        hierarchy_data$edges,
        height = "100%",
        width = "100%"
      ) %>%
        visNetwork::visHierarchicalLayout(
          direction = "UD",
          sortMethod = "directed",
          levelSeparation = 80,
          nodeSpacing = 120
        ) %>%
        visNetwork::visNodes(
          font = list(color = "white", face = "Arial")
        ) %>%
        visNetwork::visEdges(
          smooth = list(type = "cubicBezier", roundness = 0.5)
        ) %>%
        visNetwork::visInteraction(
          navigationButtons = TRUE,
          zoomView = TRUE,
          dragView = TRUE
        ) %>%
        visNetwork::visOptions(
          highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE)
        ) %>%
        visNetwork::visPhysics(enabled = FALSE) %>%
        visNetwork::visLayout(randomSeed = 123)
    })

    ## Synonyms Display (sub-tab in related concepts section) ----
    output$synonyms_display <- renderUI({
      concept_id <- selected_concept_id()

      if (is.null(concept_id)) {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_concept_selected"))
        ))
      }

      # Get synonyms from vocabulary database
      synonyms <- get_concept_synonyms(concept_id)

      if (is.null(synonyms) || nrow(synonyms) == 0) {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_synonyms_found"))
        ))
      }

      # Return DataTable output
      DT::DTOutput(ns("synonyms_table"))
    })

    # Synonyms DataTable
    output$synonyms_table <- DT::renderDT({
      concept_id <- selected_concept_id()
      if (is.null(concept_id)) return(NULL)

      synonyms <- get_concept_synonyms(concept_id)
      if (is.null(synonyms) || nrow(synonyms) == 0) return(NULL)

      # Select only synonym and language columns
      display_data <- data.frame(
        synonym = synonyms$synonym,
        language = synonyms$language,
        stringsAsFactors = FALSE
      )

      DT::datatable(
        display_data,
        selection = "none",
        rownames = FALSE,
        colnames = c(as.character(i18n$t("synonyms")), as.character(i18n$t("language"))),
        options = list(
          pageLength = 8,
          dom = "tip",
          language = get_datatable_language(),
          columnDefs = list(
            list(targets = 0, width = "70%"),
            list(targets = 1, width = "30%")
          )
        )
      )
    })

    # 7) CONCEPT SET ITEMS MANAGEMENT ====

    ## State for add concepts modal ----
    omop_concepts_cache <- reactiveVal(NULL)
    add_modal_selected_concept <- reactiveVal(NULL)
    omop_table_trigger <- reactiveVal(0)
    removing_concept_id <- reactiveVal(NULL)

    ## Staging for edit mode (pending changes until Save/Cancel) ----
    # Store concepts to be added (list keyed by concept_id)
    pending_additions <- reactiveVal(list())
    # Store concept IDs to be deleted (vector of concept_ids)
    pending_deletions <- reactiveVal(character(0))
    # Store original concepts data when entering edit mode (for cancel)
    original_concepts_data <- reactiveVal(NULL)

    ## Fuzzy search for OMOP concepts ----
    omop_fuzzy <- fuzzy_search_server(
      "omop_fuzzy_search",
      input,
      session,
      trigger_rv = omop_table_trigger,
      ns = ns
    )

    ## Limit 10K for OMOP concepts ----
    omop_limit_10k <- limit_10k_server(
      checkbox_id = "omop_limit_10k",
      modal_id = "omop_limit_10k_confirmation_modal",
      confirm_btn_id = "confirm_omop_limit_10k",
      input = input,
      session = session,
      on_change = function(limit) {
        omop_table_trigger(omop_table_trigger() + 1)
      },
      ns = ns
    )

    ## OMOP Filters ----
    omop_filters <- omop_filters_server(
      prefix = "omop_filters",
      input = input,
      session = session,
      vocabularies = function() load_vocabularies_from_duckdb(),
      settings_btn_id = "omop_filters_btn",
      limit_checkbox_id = "omop_limit_10k",
      on_apply = function(filters) {
        omop_table_trigger(omop_table_trigger() + 1)
      },
      on_clear = function() {
        omop_table_trigger(omop_table_trigger() + 1)
      },
      ns = ns
    )

    ## Show OMOP Filters Modal ----
    observe_event(input$omop_filters_btn, {
      omop_filters$show()
    }, ignoreInit = TRUE)

    ## Export Concept Set ----

    ### Open export modal
    observe_event(input$export_concept_set_btn, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      show_modal(ns("export_concept_set_modal"))
    }, ignoreInit = TRUE)

    ### Cancel export
    observe_event(input$cancel_export, {
      hide_modal(ns("export_concept_set_modal"))
    }, ignoreInit = TRUE)

    ### Handle export actions
    observe_event(input$export_action, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      action <- input$export_action

      # Get concept set data
      con <- get_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      cs <- DBI::dbGetQuery(
        con,
        "SELECT * FROM concept_sets WHERE id = ?",
        params = list(cs_id)
      )

      concepts_data <- DBI::dbGetQuery(
        con,
        "SELECT * FROM concept_set_items WHERE concept_set_id = ?",
        params = list(cs_id)
      )

      # Perform export based on action type (allow export even with no concepts)
      if (action == "json_clipboard") {
        json_output <- export_concept_set_to_json(cs_id, concepts_data)
        if (!is.null(json_output)) {
          # Copy to clipboard using JavaScript
          shinyjs::runjs(sprintf(
            "navigator.clipboard.writeText(`%s`).then(function() {
              Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
            }).catch(function() {
              Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
            });",
            gsub("`", "\\\\`", json_output),
            ns("json_copy_success"),
            ns("copy_failed_event")
          ))
        }

      } else if (action == "json_file") {
        json_output <- export_concept_set_to_json(cs_id, concepts_data)
        if (!is.null(json_output)) {
          # Create download file with INDICATE_ prefix and version
          version <- if (!is.null(cs$version) && !is.na(cs$version)) cs$version else "1.0.0"
          clean_name <- gsub("[^a-zA-Z0-9_-]", "_", cs$name)
          filename <- paste0("INDICATE_", clean_name, "_v", version, ".json")
          filepath <- file.path(tempdir(), filename)
          writeLines(json_output, filepath)

          # Trigger download via JavaScript
          shinyjs::runjs(sprintf(
            "var link = document.createElement('a');
             link.download = '%s';
             link.href = 'data:application/json;charset=utf-8,' + encodeURIComponent(`%s`);
             link.click();",
            filename,
            gsub("`", "\\\\`", json_output)
          ))

          showNotification(
            paste(as.character(i18n$t("export")), ":", filename),
            type = "message",
            duration = 3
          )
        }

      } else if (action == "concept_list") {
        concept_list <- export_concept_list(concepts_data)
        if (nchar(concept_list) > 0) {
          # Copy to clipboard using JavaScript
          shinyjs::runjs(sprintf(
            "navigator.clipboard.writeText(`%s`).then(function() {
              Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
            }).catch(function() {
              Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
            });",
            concept_list,
            ns("concept_list_copy_success"),
            ns("copy_failed_event")
          ))
        }

      } else if (action == "sql_query") {
        sql_output <- export_concept_set_to_sql(cs$name, concepts_data)
        if (!is.null(sql_output)) {
          # Copy to clipboard using JavaScript
          shinyjs::runjs(sprintf(
            "navigator.clipboard.writeText(`%s`).then(function() {
              Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
            }).catch(function() {
              Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
            });",
            gsub("`", "\\\\`", sql_output),
            ns("sql_copy_success"),
            ns("copy_failed_event")
          ))
        }
      }

      # Close modal
      hide_modal(ns("export_concept_set_modal"))
    }, ignoreInit = TRUE)

    ### Export success notifications
    observe_event(input$json_copy_success, {
      showNotification(
        as.character(i18n$t("json_copied")),
        type = "message",
        duration = 3
      )
    }, ignoreInit = TRUE)

    observe_event(input$concept_list_copy_success, {
      showNotification(
        as.character(i18n$t("concept_list_copied")),
        type = "message",
        duration = 3
      )
    }, ignoreInit = TRUE)

    observe_event(input$sql_copy_success, {
      showNotification(
        as.character(i18n$t("sql_copied")),
        type = "message",
        duration = 3
      )
    }, ignoreInit = TRUE)

    observe_event(input$copy_failed_event, {
      showNotification(
        as.character(i18n$t("copy_failed")),
        type = "error",
        duration = 5
      )
    }, ignoreInit = TRUE)

    ## Enter Edit Mode for Concepts ----
    observe_event(input$edit_concepts_btn, {
      if (!can_edit()) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Enter edit mode
      concepts_edit_mode(TRUE)

      # Update UI: hide export and edit buttons, show save/cancel buttons
      shinyjs::hide("export_concept_set_btn")
      shinyjs::hide("edit_concepts_btn")
      shinyjs::show("edit_mode_buttons")

      # Hide fullscreen button (not needed in edit mode - already fullscreen)
      shinyjs::hide("expand_concepts")

      # Hide description text in edit mode
      shinyjs::hide("concepts_desc_text")

      # Show concepts edit action buttons
      shinyjs::show("concepts_edit_buttons")

      # Add edit-mode class to container for CSS
      shinyjs::runjs(sprintf(
        "$('#%s').closest('.settings-backup-container').addClass('edit-mode');",
        ns("concepts_section_left")
      ))

      # Refresh concepts table to show delete buttons
      concepts_trigger(concepts_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Cancel Edit Mode for Concepts - Discard all staged changes ----
    observe_event(input$cancel_edit_concepts, {
      # Discard all pending changes
      pending_additions(list())
      pending_deletions(character(0))

      # Exit edit mode
      concepts_edit_mode(FALSE)

      # Update UI: show export and edit buttons, hide save/cancel buttons
      shinyjs::show("export_concept_set_btn")
      shinyjs::show("edit_concepts_btn")
      shinyjs::hide("edit_mode_buttons")

      # Show fullscreen button again
      shinyjs::show("expand_concepts")

      # Show description text again
      shinyjs::show("concepts_desc_text")

      # Hide concepts edit action buttons
      shinyjs::hide("concepts_edit_buttons")

      # Remove edit-mode class from container
      shinyjs::runjs(sprintf(
        "$('#%s').closest('.settings-backup-container').removeClass('edit-mode');",
        ns("concepts_section_left")
      ))

      # Refresh concepts table to show original data (without staged changes)
      concepts_trigger(concepts_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Save Edit Mode for Concepts - Commit all staged changes to database ----
    observe_event(input$save_edit_concepts, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Get pending changes
      additions <- pending_additions()
      deletions <- pending_deletions()

      # Commit deletions to database
      if (length(deletions) > 0) {
        for (concept_id in deletions) {
          delete_concept_set_item(cs_id, as.integer(concept_id))
        }
      }

      # Commit additions to database
      if (length(additions) > 0) {
        for (concept_data in additions) {
          add_concept_set_item(
            concept_set_id = cs_id,
            concept_id = concept_data$concept_id,
            concept_name = concept_data$concept_name,
            vocabulary_id = concept_data$vocabulary_id,
            concept_code = concept_data$concept_code,
            domain_id = concept_data$domain_id,
            concept_class_id = concept_data$concept_class_id,
            standard_concept = concept_data$standard_concept,
            is_excluded = concept_data$is_excluded,
            include_descendants = concept_data$include_descendants,
            include_mapped = concept_data$include_mapped
          )
        }
      }

      # Track what was saved
      comments_saved <- FALSE
      stats_saved <- FALSE

      # Save comments if changed
      comments_text <- input$comments_editor
      if (!is.null(comments_text)) {
        current_language <- i18n$get_translation_language()
        update_concept_set(cs_id, etl_comment = comments_text, language = current_language)
        comments_saved <- TRUE
      }

      # Save statistics if changed
      stats_text <- input$stats_editor
      if (!is.null(stats_text)) {
        # Validate JSON
        is_valid <- tryCatch({
          jsonlite::fromJSON(stats_text)
          TRUE
        }, error = function(e) {
          shinyjs::html("stats_json_error", paste("Invalid JSON:", e$message))
          shinyjs::show("stats_json_error")
          FALSE
        })

        if (is_valid) {
          update_concept_set_stats(cs_id, stats_text)
          shinyjs::hide("stats_json_error")
          stats_saved <- TRUE
        }
      }

      # Clear pending changes
      pending_additions(list())
      pending_deletions(character(0))

      # Exit edit mode
      concepts_edit_mode(FALSE)

      # Update UI: show export and edit buttons, hide save/cancel buttons
      shinyjs::show("export_concept_set_btn")
      shinyjs::show("edit_concepts_btn")
      shinyjs::hide("edit_mode_buttons")

      # Show fullscreen button again
      shinyjs::show("expand_concepts")

      # Show description text again
      shinyjs::show("concepts_desc_text")

      # Hide concepts edit action buttons
      shinyjs::hide("concepts_edit_buttons")

      # Remove edit-mode class from container
      shinyjs::runjs(sprintf(
        "$('#%s').closest('.settings-backup-container').removeClass('edit-mode');",
        ns("concepts_section_left")
      ))

      # Show notification if changes were made
      if (length(additions) > 0 || length(deletions) > 0 || comments_saved || stats_saved) {
        if (comments_saved) {
          showNotification(
            as.character(i18n$t("comments_saved")),
            type = "message",
            duration = 3
          )
        } else if (stats_saved) {
          showNotification(
            as.character(i18n$t("stats_saved")),
            type = "message",
            duration = 3
          )
        } else {
          showNotification(
            as.character(i18n$t("changes_saved")),
            type = "message",
            duration = 3
          )
        }
      }

      # Refresh concepts table
      concepts_trigger(concepts_trigger() + 1)

      # Refresh main table to update item count
      current_language <- i18n$get_translation_language()
      data <- get_all_concept_sets(language = current_language)
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Open Add Concepts Modal ----
    observe_event(input$add_concepts_btn, {
      if (!can_edit()) return()
      if (!concepts_edit_mode()) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Reset modal state
      add_modal_selected_concept(NULL)
      omop_table_trigger(omop_table_trigger() + 1)

      # Show modal
      show_modal(ns("add_concepts_modal"))
    }, ignoreInit = TRUE)

    ## Toggle Details/Descendants section based on Multiple Selection ----
    observe_event(input$add_modal_multiple_select, {
      if (isTRUE(input$add_modal_multiple_select)) {
        shinyjs::hide("add_modal_details_section")
      } else {
        shinyjs::show("add_modal_details_section")
      }
    }, ignoreInit = TRUE)

    ## OMOP Concepts Table in Modal ----
    observe_event(list(omop_table_trigger(), input$add_modal_multiple_select), {
      # Try to load vocabularies from DuckDB
      vocabs <- load_vocabularies_from_duckdb()

      if (is.null(vocabs)) {
        output$omop_concepts_table <- DT::renderDT({
          create_empty_datatable(as.character(i18n$t("vocabularies_not_loaded")))
        })
        return()
      }

      # Get fuzzy query
      fuzzy_query <- omop_fuzzy$query()
      fuzzy_active <- !is.null(fuzzy_query) && fuzzy_query != ""

      # Get filters
      filters <- omop_filters$filters()

      # Get limit setting
      use_limit <- isTRUE(omop_limit_10k())
      row_limit <- if (use_limit) 10000 else 1000000

      # Build query
      base_query <- vocabs$concept %>%
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
        base_query <- base_query %>%
          dplyr::filter(vocabulary_id %in% !!filters$vocabulary_id)
      }
      if (length(filters$domain_id) > 0) {
        base_query <- base_query %>%
          dplyr::filter(domain_id %in% !!filters$domain_id)
      }
      if (length(filters$concept_class_id) > 0) {
        base_query <- base_query %>%
          dplyr::filter(concept_class_id %in% !!filters$concept_class_id)
      }
      if (length(filters$standard_concept) > 0) {
        # Map filter values to DB values
        std_values <- filters$standard_concept
        std_values <- gsub("NS", "", std_values)  # Non-standard is empty/NA in DB
        base_query <- base_query %>%
          dplyr::filter(standard_concept %in% !!std_values | (is.na(standard_concept) & "" %in% !!std_values))
      }
      if (length(filters$validity) > 0) {
        if ("Valid" %in% filters$validity && !"Invalid" %in% filters$validity) {
          base_query <- base_query %>%
            dplyr::filter(is.na(invalid_reason) | invalid_reason == "")
        } else if ("Invalid" %in% filters$validity && !"Valid" %in% filters$validity) {
          base_query <- base_query %>%
            dplyr::filter(!is.na(invalid_reason) & invalid_reason != "")
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
          dplyr::collect() %>%
          dplyr::mutate(fuzzy_score = NA_real_)
      }

      # Cache concepts for selection
      omop_concepts_cache(concepts)

      if (nrow(concepts) == 0) {
        output$omop_concepts_table <- DT::renderDT({
          msg <- if (fuzzy_active) {
            as.character(i18n$t("no_matching_concepts"))
          } else {
            as.character(i18n$t("no_omop_concepts"))
          }
          create_empty_datatable(msg)
        })
        return()
      }

      # Prepare display data
      display_concepts <- concepts %>%
        dplyr::select(concept_id, vocabulary_id, concept_name, concept_code, domain_id, concept_class_id, standard_concept, invalid_reason)

      display_concepts$concept_id <- as.character(display_concepts$concept_id)
      display_concepts$vocabulary_id <- as.factor(display_concepts$vocabulary_id)
      display_concepts$domain_id <- as.factor(display_concepts$domain_id)
      display_concepts$concept_class_id <- as.factor(display_concepts$concept_class_id)

      display_concepts <- display_concepts %>%
        dplyr::mutate(
          standard_concept = factor(
            dplyr::case_when(
              standard_concept == "S" ~ "Standard",
              standard_concept == "C" ~ "Classification",
              TRUE ~ "Non-standard"
            ),
            levels = c("Standard", "Classification", "Non-standard")
          ),
          validity = factor(
            dplyr::case_when(
              is.na(invalid_reason) | invalid_reason == "" ~ "Valid",
              TRUE ~ "Invalid"
            ),
            levels = c("Valid", "Invalid")
          )
        ) %>%
        dplyr::select(-invalid_reason)

      # Selection mode
      is_multiple <- isTRUE(input$add_modal_multiple_select)
      selection_mode <- if (is_multiple) "multiple" else "single"

      output$omop_concepts_table <- DT::renderDT({
        dt <- create_standard_datatable(
          display_concepts,
          selection = selection_mode,
          page_length = 10,
          col_names = c(
            as.character(i18n$t("omop_concept_id")),
            "Vocabulary",
            as.character(i18n$t("omop_concept_name")),
            "Code",
            as.character(i18n$t("domain_id")),
            as.character(i18n$t("concept_class_id")),
            as.character(i18n$t("standard")),
            as.character(i18n$t("validity"))
          ),
          col_defs = list(
            list(targets = 0, width = "9%"),
            list(targets = 1, width = "10%"),
            list(targets = 2, width = "26%"),
            list(targets = 3, width = "10%"),
            list(targets = 4, width = "10%", visible = FALSE),
            list(targets = 5, width = "10%", visible = FALSE),
            list(targets = 6, width = "11%", className = "dt-center"),
            list(targets = 7, width = "9%", className = "dt-center")
          ),
          escape = TRUE
        )

        # Apply standard concept column styling
        dt <- style_standard_concept_column(dt, "standard_concept")
        dt <- style_validity_column(dt, "validity")

        dt
      }, server = TRUE)
    }, ignoreInit = FALSE)

    ## Handle OMOP concept selection in modal ----
    observe_event(input$omop_concepts_table_rows_selected, {
      rows <- input$omop_concepts_table_rows_selected
      if (is.null(rows) || length(rows) == 0) {
        add_modal_selected_concept(NULL)
        return()
      }

      concepts <- omop_concepts_cache()
      if (is.null(concepts)) return()

      # Take the first selected concept for details display
      add_modal_selected_concept(concepts$concept_id[rows[1]])
    }, ignoreInit = TRUE)

    ## Concept Details in Add Modal ----
    observe_event(add_modal_selected_concept(), {
      concept_id <- add_modal_selected_concept()

      if (is.null(concept_id)) {
        output$add_modal_concept_details <- renderUI({
          render_concept_details(
            concept = NULL,
            i18n = i18n,
            empty_message = as.character(i18n$t("no_concept_selected"))
          )
        })
        return()
      }

      concept <- get_concept_by_id(concept_id)

      # Check if concept is already added to the current concept set
      cs_id <- viewing_concept_set_id()
      is_already_added <- FALSE
      if (!is.null(cs_id) && !is.null(concept) && nrow(concept) > 0) {
        existing_concepts <- get_concept_set_items(cs_id)
        if (!is.null(existing_concepts)) {
          is_already_added <- concept$concept_id[1] %in% existing_concepts$concept_id
        }
        # Also check pending additions
        if (!is_already_added) {
          additions <- pending_additions()
          is_already_added <- as.character(concept$concept_id[1]) %in% names(additions)
        }
      }

      output$add_modal_concept_details <- renderUI({
        render_concept_details(
          concept = concept,
          i18n = i18n,
          show_already_added = TRUE,
          is_already_added = is_already_added
        )
      })
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    ## Descendants Container in Add Modal ----
    output$add_modal_descendants_container <- renderUI({
      concept_id <- add_modal_selected_concept()

      if (is.null(concept_id)) {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_concept_selected"))
        ))
      }

      # Get descendants from vocabulary database
      descendants <- get_concept_descendants(concept_id)

      if (is.null(descendants) || nrow(descendants) == 0) {
        return(tags$div(
          class = "no-content-message",
          tags$p(i18n$t("no_descendants"))
        ))
      }

      # Return DataTable output
      DT::DTOutput(ns("add_modal_descendants_table"))
    })

    ## Descendants Table in Add Modal ----
    output$add_modal_descendants_table <- DT::renderDT({
      concept_id <- add_modal_selected_concept()
      if (is.null(concept_id)) return(NULL)

      descendants <- get_concept_descendants(concept_id)
      if (is.null(descendants) || nrow(descendants) == 0) return(NULL)

      create_standard_datatable(
        descendants,
        selection = "none",
        col_names = c("Concept ID", "Concept Name", "Vocabulary", "Min Sep", "Max Sep"),
        col_defs = list(
          list(targets = 0, width = "15%"),
          list(targets = 1, width = "45%"),
          list(targets = 2, width = "20%"),
          list(targets = 3, width = "10%", className = "dt-center"),
          list(targets = 4, width = "10%", className = "dt-center")
        ),
        escape = TRUE
      )
    })

    ## Add OMOP Concepts to Concept Set (staging - not saved until Save is clicked) ----
    observe_event(input$add_omop_concepts, {
      if (!can_edit()) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      selected_rows <- input$omop_concepts_table_rows_selected
      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      all_concepts <- omop_concepts_cache()
      if (is.null(all_concepts)) return()

      # Get toggle values
      is_excluded <- isTRUE(input$add_modal_is_excluded)
      include_descendants <- isTRUE(input$add_modal_include_descendants)
      include_mapped <- isTRUE(input$add_modal_include_mapped)

      # Get existing concepts from database
      existing_concepts <- get_concept_set_items(cs_id)
      existing_ids <- if (!is.null(existing_concepts)) as.character(existing_concepts$concept_id) else character(0)

      # Get current pending additions and deletions
      current_additions <- pending_additions()
      current_deletions <- pending_deletions()

      # Count added concepts
      num_added <- 0
      num_already_present <- 0

      for (row_idx in selected_rows) {
        concept <- all_concepts[row_idx, ]
        concept_id_str <- as.character(concept$concept_id)

        # Check if already in database (and not pending deletion)
        in_db <- concept_id_str %in% existing_ids && !(concept_id_str %in% current_deletions)
        # Check if already in pending additions
        in_pending <- concept_id_str %in% names(current_additions)

        if (in_db || in_pending) {
          num_already_present <- num_already_present + 1
        } else {
          # If it was marked for deletion, remove from deletions instead
          if (concept_id_str %in% current_deletions) {
            current_deletions <- setdiff(current_deletions, concept_id_str)
          } else {
            # Add to pending additions
            current_additions[[concept_id_str]] <- list(
              concept_id = concept$concept_id,
              concept_name = concept$concept_name,
              vocabulary_id = concept$vocabulary_id,
              concept_code = concept$concept_code,
              domain_id = concept$domain_id,
              concept_class_id = concept$concept_class_id,
              standard_concept = concept$standard_concept,
              is_excluded = is_excluded,
              include_descendants = include_descendants,
              include_mapped = include_mapped
            )
          }
          num_added <- num_added + 1
        }
      }

      # Update reactive values
      pending_additions(current_additions)
      pending_deletions(current_deletions)

      # Show notification
      if (num_added > 0 && num_already_present > 0) {
        showNotification(
          sprintf("%d %s | %d %s",
                  num_added,
                  as.character(i18n$t("concepts_added")),
                  num_already_present,
                  as.character(i18n$t("already_present"))),
          type = "message",
          duration = 4
        )
      } else if (num_added > 0) {
        showNotification(
          sprintf("%d %s", num_added, as.character(i18n$t("concepts_added"))),
          type = "message",
          duration = 3
        )
      } else if (num_already_present > 0) {
        showNotification(
          as.character(i18n$t("all_concepts_already_present")),
          type = "warning",
          duration = 3
        )
      }

      # Refresh concepts table to show staged changes
      concepts_trigger(concepts_trigger() + 1)

      # Clear selection
      DT::dataTableProxy("omop_concepts_table", session = session) %>%
        DT::selectRows(NULL)
    }, ignoreInit = TRUE)

    ## Remove Concept - Show confirmation ----
    observe_event(input$remove_concept, {
      if (!can_edit()) return()

      concept_id <- input$remove_concept
      if (is.null(concept_id)) return()

      removing_concept_id(concept_id)
      show_modal(ns("remove_concept_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Remove Concept ----
    observe_event(input$cancel_remove_concept, {
      removing_concept_id(NULL)
      hide_modal(ns("remove_concept_modal"))
    }, ignoreInit = TRUE)

    ## Confirm Remove Concept (staging - not saved until Save is clicked) ----
    observe_event(input$confirm_remove_concept, {
      if (!can_edit()) return()

      cs_id <- viewing_concept_set_id()
      concept_id <- removing_concept_id()

      if (is.null(cs_id) || is.null(concept_id)) return()

      concept_id_str <- as.character(concept_id)

      # Get current pending state
      current_additions <- pending_additions()
      current_deletions <- pending_deletions()

      # Check if this concept is a pending addition (not yet saved)
      if (concept_id_str %in% names(current_additions)) {
        # Just remove from pending additions
        current_additions[[concept_id_str]] <- NULL
        pending_additions(current_additions)
      } else {
        # Mark for deletion (it's an existing concept in the database)
        if (!(concept_id_str %in% current_deletions)) {
          current_deletions <- c(current_deletions, concept_id_str)
          pending_deletions(current_deletions)
        }
      }

      # Hide modal
      hide_modal(ns("remove_concept_modal"))
      removing_concept_id(NULL)

      # Show notification
      showNotification(
        as.character(i18n$t("concept_removed")),
        type = "message",
        duration = 3
      )

      # Refresh concepts table to show staged changes
      concepts_trigger(concepts_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Select All Concepts ----
    observe_event(input$select_all_concepts, {
      if (!can_edit()) return()
      if (!concepts_edit_mode()) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      concepts <- get_concept_set_items(cs_id)
      if (is.null(concepts) || nrow(concepts) == 0) return()

      proxy <- DT::dataTableProxy("concepts_table", session = session)
      datatable_select_rows(proxy, select = TRUE, data = concepts)
    }, ignoreInit = TRUE)

    ## Unselect All Concepts ----
    observe_event(input$unselect_all_concepts, {
      if (!can_edit()) return()
      if (!concepts_edit_mode()) return()

      proxy <- DT::dataTableProxy("concepts_table", session = session)
      datatable_select_rows(proxy, select = FALSE)
    }, ignoreInit = TRUE)

    ## Delete Selected Concepts - Show confirmation ----
    observe_event(input$delete_selected_concepts, {
      if (!can_edit()) return()
      if (!concepts_edit_mode()) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Check if there are selected rows
      selected_rows <- input$concepts_table_rows_selected
      if (is.null(selected_rows) || length(selected_rows) == 0) {
        showNotification(
          as.character(i18n$t("no_concepts_selected")),
          type = "warning",
          duration = 3
        )
        return()
      }

      # Update message with count
      count <- length(selected_rows)
      message <- paste0(as.character(i18n$t("confirm_delete_selected_concepts")), " (", count, " ", tolower(as.character(i18n$t("concepts"))), ")")
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("delete_concepts_message_text"), message))

      show_modal(ns("delete_selected_concepts_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Delete Selected Concepts ----
    observe_event(input$cancel_delete_selected_concepts, {
      hide_modal(ns("delete_selected_concepts_modal"))
    }, ignoreInit = TRUE)

    ## Confirm Delete Selected Concepts (staging - not saved until Save is clicked) ----
    observe_event(input$confirm_delete_selected_concepts, {
      if (!can_edit()) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      selected_rows <- input$concepts_table_rows_selected
      if (is.null(selected_rows) || length(selected_rows) == 0) return()

      # Get concepts from database
      concepts <- get_concept_set_items(cs_id)
      if (is.null(concepts) || nrow(concepts) == 0) return()

      # Get selected concept IDs
      selected_ids <- as.character(concepts$concept_id[selected_rows])

      # Update pending deletions
      current_deletions <- pending_deletions()
      pending_deletions(unique(c(current_deletions, selected_ids)))

      # Also remove from pending additions if present
      current_additions <- pending_additions()
      current_additions <- current_additions[!sapply(current_additions, function(x) as.character(x$concept_id) %in% selected_ids)]
      pending_additions(current_additions)

      # Hide modal
      hide_modal(ns("delete_selected_concepts_modal"))

      # Show notification
      showNotification(
        paste0(length(selected_ids), " ", as.character(i18n$t("concepts_deleted"))),
        type = "message",
        duration = 3
      )

      # Clear selection and refresh concepts table
      proxy <- DT::dataTableProxy("concepts_table", session = session)
      datatable_select_rows(proxy, select = FALSE)
      concepts_trigger(concepts_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Submit Review ----
    observe_event(input$submit_review, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Get current concept set to get version
      current_language <- i18n$get_translation_language()
      cs <- get_concept_set(cs_id, language = current_language)
      if (is.null(cs)) return()

      version <- if (is.null(cs$version) || is.na(cs$version)) "1.0.0" else cs$version
      status <- input$review_status_input
      comments <- trimws(input$review_comments_input)

      # Validation
      if (is.null(status) || status == "") {
        showNotification("Please select a review status", type = "error", duration = 3)
        return()
      }

      # Get current user ID (for now use 1, later use current_user()$user_id)
      reviewer_user_id <- 1  # TODO: use current_user()$user_id

      # Add review
      review_id <- add_concept_set_review(cs_id, version, reviewer_user_id, status, comments)

      # Update concept set review_status if approved or needs_revision
      if (status %in% c("approved", "needs_revision")) {
        update_concept_set(cs_id, review_status = status)

        # Refresh concept sets data to update badges
        current_language <- i18n$get_translation_language()
        data <- get_all_concept_sets(language = current_language)
        concept_sets_data(data)
        table_trigger(table_trigger() + 1)

        # Update detail page badges
        status_key <- paste0("status_", status)
        status_label <- as.character(i18n$t(status_key))

        badges_html <- sprintf(
          '<span class="version-badge" style="cursor: pointer;" onclick="Shiny.setInputValue(\'%s\', Date.now(), {priority: \'event\'});" title="%s">v%s</span><span class="status-badge %s" style="cursor: pointer;" onclick="Shiny.setInputValue(\'%s\', Date.now(), {priority: \'event\'});" title="%s">%s</span>',
          ns("open_version_modal"),
          as.character(i18n$t("new_version")),
          htmltools::htmlEscape(version),
          status,
          ns("open_status_modal"),
          as.character(i18n$t("change_status")),
          htmltools::htmlEscape(status_label)
        )
        shinyjs::html("concept_set_badges", badges_html)
      }

      # Clear form
      updateTextAreaInput(session, "review_comments_input", value = "")

      # Refresh reviews table
      reviews <- get_concept_set_reviews(cs_id)
      reviews_data(reviews)
      reviews_trigger(reviews_trigger() + 1)

      # Show notification
      showNotification(
        as.character(i18n$t("review_submitted")),
        type = "message",
        duration = 3
      )
    }, ignoreInit = TRUE)

    ## Add Review Button ----
    observe_event(input$add_review_btn, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Reset modal inputs with default markdown
      default_markdown <- "# Review Comments\n\nEnter your review comments here using Markdown syntax.\n\n## Suggestions\n\n- Item 1\n- Item 2\n"
      shinyAce::updateAceEditor(session, "review_markdown_editor", value = default_markdown)
      updateSelectInput(session, "review_status_modal", selected = "")

      # Open the fullscreen Add Review modal
      show_modal(ns("add_review_modal"))
    }, ignoreInit = TRUE)

    ## Update Markdown Preview (Add Review) ----
    output$review_markdown_preview <- renderUI({
      markdown_text <- input$review_markdown_editor

      # If no text, show placeholder
      if (is.null(markdown_text) || nchar(trimws(markdown_text)) == 0) {
        return(tags$div(
          class = "markdown-preview-placeholder",
          "Preview will appear here..."
        ))
      }

      # Convert markdown to HTML
      html_content <- tryCatch({
        markdown::markdownToHTML(
          text = markdown_text,
          fragment.only = TRUE,
          options = c("use_xhtml", "smartypants", "base64_images", "mathjax", "highlight_code")
        )
      }, error = function(e) {
        paste0("<p style='color: red;'>Error rendering markdown: ", e$message, "</p>")
      })

      tags$div(
        class = "markdown-body markdown-preview-container",
        HTML(html_content)
      )
    })

    ## Update Markdown Preview (Edit Review) ----
    output$edit_review_markdown_preview <- renderUI({
      markdown_text <- input$edit_review_markdown_editor

      # If no text, show placeholder
      if (is.null(markdown_text) || nchar(trimws(markdown_text)) == 0) {
        return(tags$div(
          class = "markdown-preview-placeholder",
          "Preview will appear here..."
        ))
      }

      # Convert markdown to HTML
      html_content <- tryCatch({
        markdown::markdownToHTML(
          text = markdown_text,
          fragment.only = TRUE,
          options = c("use_xhtml", "smartypants", "base64_images", "mathjax", "highlight_code")
        )
      }, error = function(e) {
        paste0("<p style='color: red;'>Error rendering markdown: ", e$message, "</p>")
      })

      tags$div(
        class = "markdown-body markdown-preview-container",
        HTML(html_content)
      )
    })

    # Force render even when hidden
    outputOptions(output, "review_markdown_preview", suspendWhenHidden = FALSE)
    outputOptions(output, "edit_review_markdown_preview", suspendWhenHidden = FALSE)

    ## Submit Add Review ----
    observe_event(input$submit_add_review, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Get current concept set to get version
      current_language <- i18n$get_translation_language()
      cs <- get_concept_set(cs_id, language = current_language)
      if (is.null(cs)) return()

      version <- if (is.null(cs$version) || is.na(cs$version)) "1.0.0" else cs$version
      status <- input$review_status_modal
      comments <- trimws(input$review_markdown_editor)

      # Validation - both status and comments are required
      if (is.null(status) || status == "") {
        showNotification("Please select a review status", type = "error", duration = 3)
        return()
      }

      if (is.null(comments) || comments == "") {
        showNotification("Review comments are required", type = "error", duration = 3)
        return()
      }

      # Get current user ID
      user <- current_user()
      reviewer_user_id <- if (!is.null(user)) user$user_id else 1

      # Add review
      review_id <- add_concept_set_review(cs_id, version, reviewer_user_id, status, comments)

      # Refresh reviews table
      reviews <- get_concept_set_reviews(cs_id)
      reviews_data(reviews)
      reviews_trigger(reviews_trigger() + 1)

      # Close modal
      hide_modal(ns("add_review_modal"))

      # Show notification
      showNotification(
        as.character(i18n$t("review_submitted")),
        type = "message",
        duration = 3
      )
    }, ignoreInit = TRUE)

    ## Edit Review Button ----
    observe_event(input$edit_review, {
      review_id <- input$edit_review
      if (is.null(review_id)) return()

      # Get review data
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      reviews <- get_concept_set_reviews(cs_id)
      review <- reviews[reviews$review_id == review_id, ]

      if (nrow(review) == 0) return()

      # Populate form
      updateSelectInput(session, "edit_review_status_input", selected = review$status)
      comments_text <- if (is.na(review$comments)) "" else review$comments
      shinyAce::updateAceEditor(session, "edit_review_markdown_editor", value = comments_text)
      updateTextInput(session, "editing_review_id", value = as.character(review_id))

      # Show fullscreen modal
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'flex';", ns("edit_review_modal")))
    }, ignoreInit = TRUE)

    ## Confirm Edit Review ----
    observe_event(input$confirm_edit_review, {
      review_id <- as.integer(input$editing_review_id)
      if (is.null(review_id) || is.na(review_id)) return()

      status <- input$edit_review_status_input
      comments <- trimws(input$edit_review_markdown_editor)

      # Validation
      if (is.null(status) || status == "") {
        showNotification("Please select a review status", type = "error", duration = 3)
        return()
      }

      if (is.null(comments) || comments == "") {
        showNotification("Review comments are required", type = "error", duration = 3)
        return()
      }

      # Update review
      update_concept_set_review(review_id, status = status, comments = comments)

      # Refresh reviews table
      cs_id <- viewing_concept_set_id()
      if (!is.null(cs_id)) {
        reviews <- get_concept_set_reviews(cs_id)
        reviews_data(reviews)
        reviews_trigger(reviews_trigger() + 1)
      }

      # Close modal
      shinyjs::runjs(sprintf("document.getElementById('%s').style.display = 'none';", ns("edit_review_modal")))

      # Show notification
      showNotification("Review updated successfully", type = "message", duration = 3)
    }, ignoreInit = TRUE)

    ## Delete Review Button ----
    observe_event(input$delete_review, {
      review_id <- input$delete_review
      if (is.null(review_id)) return()

      # Store review_id
      updateTextInput(session, "deleting_review_id", value = as.character(review_id))

      # Show confirmation modal
      show_modal(ns("delete_review_modal"))
    }, ignoreInit = TRUE)

    ## Confirm Delete Review ----
    observe_event(input$confirm_delete_review_final, {
      review_id <- as.integer(input$deleting_review_id)
      if (is.null(review_id) || is.na(review_id)) return()

      # Delete review
      delete_concept_set_review(review_id)

      # Refresh reviews table
      cs_id <- viewing_concept_set_id()
      if (!is.null(cs_id)) {
        reviews <- get_concept_set_reviews(cs_id)
        reviews_data(reviews)
        reviews_trigger(reviews_trigger() + 1)
      }

      # Close modal
      hide_modal(ns("delete_review_modal"))

      # Show notification
      showNotification("Review deleted successfully", type = "message", duration = 3)
    }, ignoreInit = TRUE)

    ## Cancel Delete Review ----
    observe_event(input$cancel_delete_review, {
      hide_modal(ns("delete_review_modal"))
    }, ignoreInit = TRUE)

    ## View Review Button / Double Click ----
    observe_event(input$view_review, {
      review_id <- input$view_review
      if (is.null(review_id)) return()

      # Store the review_id to trigger renderUI
      viewing_review_id(review_id)

      # Get review data
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      reviews <- get_concept_set_reviews(cs_id)
      review <- reviews[reviews$review_id == review_id, ]

      if (nrow(review) == 0) return()

      # Build header info HTML with reviewer, date, version and status
      reviewer_name <- if (is.na(review$reviewer_name)) "Unknown" else review$reviewer_name
      review_date <- gsub("T", " ", substr(review$review_date, 1, 16))
      version <- if (is.na(review$version)) "N/A" else review$version

      status <- if (is.na(review$status)) "draft" else review$status
      status_key <- paste0("status_", status)
      status_label <- as.character(i18n$t(status_key))

      header_html <- sprintf(
        '<span style="margin-right: 10px;"><strong>Reviewer:</strong> %s</span><span style="margin-right: 10px;"><strong>Date:</strong> %s</span><span style="margin-right: 10px;"><strong>Version:</strong> %s</span><span class="status-badge %s">%s</span>',
        htmltools::htmlEscape(reviewer_name),
        htmltools::htmlEscape(review_date),
        htmltools::htmlEscape(version),
        status,
        htmltools::htmlEscape(status_label)
      )
      shinyjs::html("view_review_header_info", header_html)

      # Show fullscreen modal
      shinyjs::runjs(sprintf(
        "document.getElementById('%s').style.display = 'flex';",
        ns("view_review_modal")
      ))
    }, ignoreInit = TRUE)

    ## Render View Review Content ----
    output$view_review_content <- renderUI({
      review_id <- viewing_review_id()
      if (is.null(review_id)) return(NULL)

      # Get review data
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return(NULL)

      reviews <- get_concept_set_reviews(cs_id)
      review <- reviews[reviews$review_id == review_id, ]

      if (nrow(review) == 0) return(NULL)

      # Get markdown content
      markdown_text <- if (is.na(review$comments)) "" else review$comments

      # Convert markdown to HTML
      html_content <- tryCatch({
        markdown::markdownToHTML(
          text = markdown_text,
          fragment.only = TRUE,
          options = c(
            "use_xhtml",
            "smartypants",
            "base64_images",
            "mathjax",
            "highlight_code"
          )
        )
      }, error = function(e) {
        paste0(
          "<p style='color: red;'>Error rendering markdown: ",
          e$message,
          "</p>"
        )
      })

      # Display only the rendered markdown
      tags$div(
        class = "markdown-body",
        HTML(html_content)
      )
    })

    # Force render even when hidden
    outputOptions(output, "view_review_content", suspendWhenHidden = FALSE)

    ## Open Status Modal ----
    observe_event(input$open_status_modal, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      current_language <- i18n$get_translation_language()
      cs <- get_concept_set(cs_id, language = current_language)
      if (is.null(cs)) return()

      # Populate status dropdown with all status options
      status_choices <- c("draft", "pending_review", "approved", "needs_revision", "deprecated")
      status_labels <- sapply(status_choices, function(s) {
        as.character(i18n$t(paste0("status_", s)))
      })
      names(status_choices) <- status_labels

      current_status <- if (is.null(cs$review_status) || is.na(cs$review_status)) "draft" else cs$review_status

      updateSelectInput(session, "new_status_input", choices = status_choices, selected = current_status)

      show_modal(ns("change_status_modal"))
    }, ignoreInit = TRUE)

    ## Confirm Change Status ----
    observe_event(input$confirm_change_status, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      new_status <- input$new_status_input

      if (is.null(new_status) || new_status == "") return()

      # Update concept set status
      update_concept_set(cs_id, review_status = new_status)

      # Refresh concept sets data
      current_language <- i18n$get_translation_language()
      data <- get_all_concept_sets(language = current_language)
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)

      # Update detail page badges
      cs <- get_concept_set(cs_id, language = current_language)
      version <- if (is.null(cs$version) || is.na(cs$version)) "1.0.0" else cs$version
      status_key <- paste0("status_", new_status)
      status_label <- as.character(i18n$t(status_key))

      badges_html <- sprintf(
        '<span class="version-badge" style="cursor: pointer;" onclick="Shiny.setInputValue(\'%s\', Date.now(), {priority: \'event\'});" title="%s">v%s</span><span class="status-badge %s" style="cursor: pointer;" onclick="Shiny.setInputValue(\'%s\', Date.now(), {priority: \'event\'});" title="%s">%s</span>',
        ns("open_version_modal"),
        as.character(i18n$t("new_version")),
        htmltools::htmlEscape(version),
        new_status,
        ns("open_status_modal"),
        as.character(i18n$t("change_status")),
        htmltools::htmlEscape(status_label)
      )
      shinyjs::html("concept_set_badges", badges_html)

      hide_modal(ns("change_status_modal"))

      showNotification(
        as.character(i18n$t("status_changed")),
        type = "message",
        duration = 3
      )
    }, ignoreInit = TRUE)

    ## Cancel Change Status ----
    observe_event(input$cancel_change_status, {
      hide_modal(ns("change_status_modal"))
    }, ignoreInit = TRUE)

    ## Open Version Modal ----
    observe_event(input$open_version_modal, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      current_language <- i18n$get_translation_language()
      cs <- get_concept_set(cs_id, language = current_language)
      if (is.null(cs)) return()

      current_version <- if (is.null(cs$version) || is.na(cs$version)) "1.0.0" else cs$version

      # Suggest next patch version
      version_parts <- strsplit(current_version, "\\.")[[1]]
      if (length(version_parts) == 3) {
        patch <- as.integer(version_parts[3]) + 1
        suggested_version <- paste(version_parts[1], version_parts[2], patch, sep = ".")
      } else {
        suggested_version <- paste0(current_version, ".1")
      }

      updateTextInput(session, "new_version_number", value = suggested_version)
      updateTextAreaInput(session, "version_change_summary", value = "")

      # Load version history
      history <- get_version_history(cs_id)

      # Render version history table
      output$version_history_table <- DT::renderDT({
        if (is.null(history) || nrow(history) == 0) {
          return(create_empty_datatable("No version history"))
        }

        # Format display data (no ID column)
        display_data <- data.frame(
          version = history$version_to,
          summary = ifelse(is.na(history$change_summary), "", history$change_summary),
          changed_by = ifelse(is.na(history$changed_by_name), "", history$changed_by_name),
          date = vapply(history$change_date, function(dt_str) {
            if (is.na(dt_str) || dt_str == "") return("")
            tryCatch(gsub("T", " ", substr(dt_str, 1, 16)), error = function(e) "")
          }, character(1), USE.NAMES = FALSE),
          stringsAsFactors = FALSE
        )

        # Add action buttons (storing change_id in data attribute)
        display_data$actions <- sapply(history$change_id, function(id) {
          create_datatable_actions(list(
            list(
              label = as.character(i18n$t("edit")),
              icon = "edit",
              type = "warning",
              class = "btn-edit-version",
              data_attr = list(id = id)
            ),
            list(
              label = as.character(i18n$t("delete")),
              icon = "trash",
              type = "danger",
              class = "btn-delete-version",
              data_attr = list(id = id)
            )
          ))
        })

        dt <- DT::datatable(
          display_data,
          selection = "none",
          colnames = c("Version", "Summary", "Changed By", "Date", "Actions"),
          options = list(
            dom = "t",  # Only table, no search/pagination/column visibility
            pageLength = 5,
            ordering = FALSE,
            columnDefs = list(
              list(targets = 0, width = "80px"),
              list(targets = 1, width = "250px"),
              list(targets = 2, width = "120px"),
              list(targets = 3, width = "130px"),
              list(targets = 4, width = "180px", className = "dt-center")
            )
          ),
          escape = FALSE,
          rownames = FALSE
        )

        add_button_handlers(dt, handlers = list(
          list(selector = ".btn-edit-version", input_id = ns("edit_version_entry")),
          list(selector = ".btn-delete-version", input_id = ns("delete_version_entry"))
        ))
      })

      show_modal(ns("new_version_modal"))
    }, ignoreInit = TRUE)

    ## Confirm New Version ----
    observe_event(input$confirm_new_version, {
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      new_version <- trimws(input$new_version_number)
      change_summary <- trimws(input$version_change_summary)

      if (is.null(new_version) || new_version == "") {
        showNotification("Please enter a version number", type = "error", duration = 3)
        return()
      }

      # Get current version
      current_language <- i18n$get_translation_language()
      cs <- get_concept_set(cs_id, language = current_language)
      old_version <- if (is.null(cs$version) || is.na(cs$version)) "1.0.0" else cs$version

      # Get current user ID
      user_id <- NULL
      if (!is.null(current_user) && is.reactive(current_user)) {
        user <- current_user()
        if (!is.null(user) && !is.null(user$user_id)) {
          user_id <- user$user_id
        }
      }

      # Update concept set version
      update_concept_set(cs_id, version = new_version)

      # Add changelog entry
      add_changelog_entry(
        concept_set_id = cs_id,
        version_from = old_version,
        version_to = new_version,
        changed_by_user_id = user_id,
        change_type = "version_change",
        change_summary = if (change_summary == "") NULL else change_summary
      )

      # Refresh concept sets data
      current_language <- i18n$get_translation_language()
      data <- get_all_concept_sets(language = current_language)
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)

      # Update detail page badges
      cs <- get_concept_set(cs_id, language = current_language)
      status <- if (is.null(cs$review_status) || is.na(cs$review_status)) "draft" else cs$review_status
      status_key <- paste0("status_", status)
      status_label <- as.character(i18n$t(status_key))

      badges_html <- sprintf(
        '<span class="version-badge" style="cursor: pointer;" onclick="Shiny.setInputValue(\'%s\', Date.now(), {priority: \'event\'});" title="%s">v%s</span><span class="status-badge %s" style="cursor: pointer;" onclick="Shiny.setInputValue(\'%s\', Date.now(), {priority: \'event\'});" title="%s">%s</span>',
        ns("open_version_modal"),
        as.character(i18n$t("new_version")),
        htmltools::htmlEscape(new_version),
        status,
        ns("open_status_modal"),
        as.character(i18n$t("change_status")),
        htmltools::htmlEscape(status_label)
      )
      shinyjs::html("concept_set_badges", badges_html)

      hide_modal(ns("new_version_modal"))

      showNotification(
        as.character(i18n$t("version_created")),
        type = "message",
        duration = 3
      )
    }, ignoreInit = TRUE)

    ## Cancel New Version ----
    observe_event(input$cancel_new_version, {
      hide_modal(ns("new_version_modal"))
    }, ignoreInit = TRUE)

    ## Edit Version Entry ----
    observe_event(input$edit_version_entry, {
      change_id <- input$edit_version_entry
      if (is.null(change_id)) return()

      # Get the changelog entry
      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      history <- get_version_history(cs_id)
      entry <- history[history$change_id == change_id, ]
      if (nrow(entry) == 0) return()

      # Populate modal and show it
      current_summary <- if (is.na(entry$change_summary)) "" else entry$change_summary
      updateTextAreaInput(session, "edit_version_summary_input", value = current_summary)
      updateTextInput(session, "editing_change_id", value = as.character(change_id))

      show_modal(ns("edit_version_summary_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Edit Version Summary ----
    observe_event(input$cancel_edit_version_summary, {
      hide_modal(ns("edit_version_summary_modal"))
    }, ignoreInit = TRUE)

    ## Save Edit Version Summary ----
    observe_event(input$save_edit_version_summary, {
      change_id <- as.integer(input$editing_change_id)
      if (is.null(change_id) || is.na(change_id)) return()

      new_summary <- trimws(input$edit_version_summary_input)

      # Update the changelog entry
      update_changelog_entry(change_id, new_summary)

      showNotification(
        "Change summary updated successfully",
        type = "message",
        duration = 3
      )

      hide_modal(ns("edit_version_summary_modal"))

      # Refresh version history table
      cs_id <- viewing_concept_set_id()
      if (!is.null(cs_id)) {
        # Re-trigger the modal to refresh
        shinyjs::runjs(sprintf("
          Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
        ", ns("open_version_modal")))
      }
    }, ignoreInit = TRUE)

    ## Delete Version Entry ----
    observe_event(input$delete_version_entry, {
      change_id <- input$delete_version_entry
      if (is.null(change_id)) return()

      # Show delete confirmation modal
      updateTextInput(session, "deleting_change_id", value = as.character(change_id))
      show_modal(ns("delete_version_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Delete Version ----
    observe_event(input$cancel_delete_version, {
      hide_modal(ns("delete_version_modal"))
    }, ignoreInit = TRUE)

    ## Confirm Delete Version (Final) ----
    observe_event(input$confirm_delete_version_final, {
      change_id <- as.integer(input$deleting_change_id)
      if (is.null(change_id) || is.na(change_id)) return()

      # Delete the changelog entry
      delete_changelog_entry(change_id)

      showNotification(
        "Version entry deleted successfully",
        type = "message",
        duration = 3
      )

      hide_modal(ns("delete_version_modal"))

      # Refresh version history table
      cs_id <- viewing_concept_set_id()
      if (!is.null(cs_id)) {
        # Re-trigger the modal to refresh
        shinyjs::runjs(sprintf("
          Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
        ", ns("open_version_modal")))
      }
    }, ignoreInit = TRUE)

    # 5) EXPORT ALL ====

    ## Export All Concept Sets ----
    observe_event(input$export_all_concept_sets, {
      current_language <- i18n$get_translation_language()

      # Generate ZIP file
      zip_file <- export_all_concept_sets(language = current_language)

      if (!is.null(zip_file) && file.exists(zip_file)) {
        # Store path in reactive value
        export_zip_path(zip_file)

        # Trigger the download
        shinyjs::delay(100, {
          shinyjs::runjs(sprintf("$('#%s')[0].click();", session$ns("download_all_concept_sets")))
        })
      } else {
        showNotification(
          "Failed to create export file",
          type = "error",
          duration = 5
        )
      }
    }, ignoreInit = TRUE)

    # 5.1) IMPORT ====

    ## Open Import Modal ----
    observe_event(input$import_concept_sets, {
      # Reset file input
      shinyjs::reset("import_zip_file")
      # Reset import mode
      updateRadioButtons(session, "import_mode", selected = "add")
      # Show/hide mode descriptions
      shinyjs::show("import_mode_desc_add")
      shinyjs::hide("import_mode_desc_replace")
      # Hide status message
      shinyjs::hide("import_status_message")
      # Show modal
      show_modal(ns("import_concept_sets_modal"))
    }, ignoreInit = TRUE)

    ## Confirm Import ----
    observe_event(input$confirm_import, {
      # Validate file selection
      if (is.null(input$import_zip_file)) {
        shinyjs::html("import_status_message", as.character(i18n$t("select_zip_file")))
        shinyjs::runjs(sprintf("$('#%s').css({'background': '#fee', 'border': '1px solid #fcc', 'color': '#c33', 'display': 'block'});", ns("import_status_message")))
        return()
      }

      zip_path <- input$import_zip_file$datapath

      # Get import mode (default to "add" if not set)
      import_mode <- if (is.null(input$import_mode) || length(input$import_mode) == 0) "add" else input$import_mode

      # If mode is "replace", show confirmation
      if (import_mode == "replace") {
        # Show confirmation in modal
        shinyjs::html("import_status_message", as.character(i18n$t("confirm_replace_all")))
        shinyjs::runjs(sprintf("$('#%s').css({'background': '#fff3cd', 'border': '1px solid #ffc107', 'color': '#856404', 'display': 'block'});", ns("import_status_message")))

        # Add a confirmation button
        shinyjs::runjs(sprintf("
          $('#%s').append('<button id=\"%s\" class=\"btn btn-danger\" style=\"margin-top: 10px;\">%s</button>');
        ", ns("import_status_message"), ns("confirm_replace_btn"), as.character(i18n$t("confirm"))))

        return()
      }

      # Show processing message
      shinyjs::html("import_status_message", as.character(i18n$t("processing_import")))
      shinyjs::runjs(sprintf("$('#%s').css({'background': '#d1ecf1', 'border': '1px solid #bee5eb', 'color': '#0c5460', 'display': 'block'});", ns("import_status_message")))

      # Disable button during import
      shinyjs::disable("confirm_import")

      # Perform import
      current_language <- i18n$get_translation_language()
      result <- import_concept_sets_from_zip(zip_path, mode = import_mode, language = current_language)

      if (result$success) {
        # Success message
        message_text <- gsub("\\{count\\}", as.character(result$count), as.character(i18n$t("import_success")))
        shinyjs::html("import_status_message", message_text)
        shinyjs::runjs(sprintf("$('#%s').css({'background': '#d4edda', 'border': '1px solid #c3e6cb', 'color': '#155724', 'display': 'block'});", ns("import_status_message")))

        # Reload concept sets
        table_trigger(table_trigger() + 1)

        # Close modal after 2 seconds
        shinyjs::delay(2000, hide_modal(ns("import_concept_sets_modal")))
      } else {
        # Error message
        error_message <- if (result$message == "no_json_files_found") {
          as.character(i18n$t("no_json_files_found"))
        } else {
          paste(as.character(i18n$t("import_failed")), result$message, sep = ": ")
        }
        shinyjs::html("import_status_message", error_message)
        shinyjs::runjs(sprintf("$('#%s').css({'background': '#f8d7da', 'border': '1px solid #f5c6cb', 'color': '#721c24', 'display': 'block'});", ns("import_status_message")))
      }

      # Re-enable button
      shinyjs::enable("confirm_import")
    }, ignoreInit = TRUE)

    ## Cancel Import ----
    observe_event(input$cancel_import, {
      hide_modal(ns("import_concept_sets_modal"))
    }, ignoreInit = TRUE)

    ## Confirm Load Default Concept Sets ----
    observe_event(input$confirm_load_default, {
      # Find default concept sets
      concept_sets_dir <- system.file("extdata/concept_sets", package = "indicate")
      if (concept_sets_dir == "" || !dir.exists(concept_sets_dir)) {
        concept_sets_dir <- "inst/extdata/concept_sets"
      }

      if (dir.exists(concept_sets_dir)) {
        # Load Heart rate concept set (327.json) as test
        heart_rate_file <- file.path(concept_sets_dir, "327.json")

        if (file.exists(heart_rate_file)) {
          current_language <- i18n$get_translation_language()
          message(sprintf("[mod_data_dictionary] Loading Heart rate concept set: %s", heart_rate_file))

          result <- import_concept_set_from_json(heart_rate_file, language = current_language)

          if (!is.null(result)) {
            message("[mod_data_dictionary] Successfully loaded first concept set")

            # Reload data
            data <- get_all_concept_sets(language = current_language)
            concept_sets_data(data)
            table_trigger(table_trigger() + 1)

            # Show success notification with count
            message_text <- gsub("\\{count\\}", "1", as.character(i18n$t("load_default_success")))
            showNotification(
              message_text,
              type = "message",
              duration = 5
            )
          } else {
            message("[mod_data_dictionary] Failed to load first concept set")
            showNotification(
              as.character(i18n$t("load_default_failed")),
              type = "error",
              duration = 5
            )
          }
        }
      }

      # Hide modal
      hide_modal(ns("load_default_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Load Default ----
    observe_event(input$cancel_load_default, {
      hide_modal(ns("load_default_modal"))
    }, ignoreInit = TRUE)

    # 6) FILTERS ====

    ## Open Filters Modal ----
    observe_event(input$filter_concept_sets, {
      # Get unique values for filter options
      data <- concept_sets_data()
      if (is.null(data) || nrow(data) == 0) return()

      # Categories
      categories <- sort(unique(data$category[!is.na(data$category) & data$category != ""]))
      updateSelectizeInput(session, "filter_category", choices = categories, selected = active_filters()$category)

      # Subcategories
      subcategories <- sort(unique(data$subcategory[!is.na(data$subcategory) & data$subcategory != ""]))
      updateSelectizeInput(session, "filter_subcategory", choices = subcategories, selected = active_filters()$subcategory)

      # Statuses - use translation keys
      status_choices <- c("draft", "pending_review", "approved", "needs_revision", "deprecated")
      status_labels <- sapply(status_choices, function(s) {
        as.character(i18n$t(paste0("status_", s)))
      })
      names(status_choices) <- status_labels
      updateSelectizeInput(session, "filter_status", choices = status_choices, selected = active_filters()$status)

      # Tags - parse all tags from data
      all_tags_list <- character(0)
      if (!is.null(data$tags)) {
        tags_vec <- data$tags[!is.na(data$tags) & data$tags != ""]
        if (length(tags_vec) > 0) {
          all_tags_list <- unique(unlist(lapply(tags_vec, function(t) trimws(strsplit(t, ",")[[1]]))))
          all_tags_list <- sort(all_tags_list)
        }
      }
      updateSelectizeInput(session, "filter_tags", choices = all_tags_list, selected = active_filters()$tags)

      # Show modal
      show_modal(ns("filters_modal"))
    }, ignoreInit = TRUE)

    ## Apply Filters ----
    observe_event(input$apply_filters, {
      # Store filter values
      active_filters(list(
        category = if (is.null(input$filter_category)) character(0) else input$filter_category,
        subcategory = if (is.null(input$filter_subcategory)) character(0) else input$filter_subcategory,
        status = if (is.null(input$filter_status)) character(0) else input$filter_status,
        tags = if (is.null(input$filter_tags)) character(0) else input$filter_tags
      ))

      # Refresh table
      table_trigger(table_trigger() + 1)

      # Hide modal
      hide_modal(ns("filters_modal"))
    }, ignoreInit = TRUE)

    ## Reset Filters ----
    observe_event(input$reset_filters, {
      # Clear all filters
      active_filters(list(
        category = character(0),
        subcategory = character(0),
        status = character(0),
        tags = character(0)
      ))

      # Clear filter inputs
      updateSelectizeInput(session, "filter_category", selected = character(0))
      updateSelectizeInput(session, "filter_subcategory", selected = character(0))
      updateSelectizeInput(session, "filter_status", selected = character(0))
      updateSelectizeInput(session, "filter_tags", selected = character(0))

      # Refresh table
      table_trigger(table_trigger() + 1)

      # Hide modal
      hide_modal(ns("filters_modal"))
    }, ignoreInit = TRUE)

  # ===================================================================
  # COMMENTS PAGE LOGIC
  # ===================================================================

  ## Render Comments Display ----
  observe_event(c(viewing_concept_set_id(), table_trigger()), {
    cs_id <- viewing_concept_set_id()

    output$comments_display <- renderUI({
      if (is.null(cs_id)) return(tags$p(style = "color: #999; font-style: italic;", i18n$t("no_concept_set_selected")))

      current_language <- i18n$get_translation_language()
      cs <- get_concept_set(cs_id, language = current_language)
      if (is.null(cs)) return(NULL)

      comments_text <- if (!is.null(cs$etl_comment) && !is.na(cs$etl_comment) && nchar(cs$etl_comment) > 0) {
        cs$etl_comment
      } else {
        i18n$t("no_comments_yet")
      }

      if (comments_text == as.character(i18n$t("no_comments_yet"))) {
        return(tags$p(style = "color: #999; font-style: italic;", comments_text))
      }

      # Render markdown
      html_content <- tryCatch({
        markdown::markdownToHTML(
          text = comments_text,
          fragment.only = TRUE,
          options = c("use_xhtml", "smartypants", "base64_images", "mathjax", "highlight_code")
        )
      }, error = function(e) {
        paste0("<p style='color: red;'>Error rendering markdown: ", e$message, "</p>")
      })

      tags$div(class = "markdown-body", HTML(html_content))
    })
  }, ignoreInit = FALSE)

  ## Render Comments Preview ----
  output$comments_preview <- renderUI({
    markdown_text <- input$comments_editor
    if (is.null(markdown_text) || nchar(trimws(markdown_text)) == 0) {
      return(NULL)
    }

    html_content <- tryCatch({
      markdown::markdownToHTML(
        text = markdown_text,
        fragment.only = TRUE,
        options = c("use_xhtml", "smartypants", "base64_images", "mathjax", "highlight_code")
      )
    }, error = function(e) {
      paste0("<p style='color: red;'>Error rendering markdown: ", e$message, "</p>")
    })

    tags$div(class = "markdown-body", HTML(html_content))
  })

  outputOptions(output, "comments_preview", suspendWhenHidden = FALSE)

  ## Toggle Comments Edit Mode ----
  observe_event(concepts_edit_mode(), {
    is_edit <- concepts_edit_mode()

    if (is_edit) {
      # Load current comments into editor
      cs_id <- viewing_concept_set_id()
      if (!is.null(cs_id)) {
        current_language <- i18n$get_translation_language()
        cs <- get_concept_set(cs_id, language = current_language)
        if (!is.null(cs)) {
          comments_text <- if (!is.null(cs$etl_comment) && !is.na(cs$etl_comment)) cs$etl_comment else ""
          shinyAce::updateAceEditor(session, "comments_editor", value = comments_text)
        }
      }

      # Show edit mode
      shinyjs::hide("comments_view_section")
      shinyjs::show("comments_edit_section")
    } else {
      # Show view mode
      shinyjs::show("comments_view_section")
      shinyjs::hide("comments_edit_section")
    }
  }, ignoreInit = FALSE)


  # ===================================================================
  # STATISTICS PAGE LOGIC
  # ===================================================================

  ## Helper: Get Statistics Data ----
  get_stats_data <- reactive({
    cs_id <- viewing_concept_set_id()
    # Trigger dependency on table_trigger to force refresh
    table_trigger()

    if (is.null(cs_id)) return(NULL)

    con <- get_db_connection()
    on.exit(DBI::dbDisconnect(con))

    stats_data <- DBI::dbGetQuery(
      con,
      "SELECT stats FROM concept_set_stats WHERE concept_set_id = ?",
      params = list(cs_id)
    )

    if (nrow(stats_data) == 0 || is.na(stats_data$stats[1]) || nchar(trimws(stats_data$stats[1])) == 0) {
      return(NULL)
    }

    # Parse JSON with simplifyDataFrame = FALSE to keep list structure
    stats_json <- tryCatch({
      jsonlite::fromJSON(stats_data$stats[1], simplifyDataFrame = FALSE)
    }, error = function(e) {
      return(NULL)
    })

    stats_json
  })

  ## Render Profile Selector ----
  observe_event(get_stats_data(), {
    output$stats_profile_selector <- renderUI({
      stats_json <- get_stats_data()
      if (is.null(stats_json)) return(NULL)

      profiles <- stats_json$profiles
      if (is.null(profiles) || length(profiles) == 0) return(NULL)

      profile_names <- sapply(profiles, function(p) p$name_en)
      if (length(profile_names) <= 1) return(NULL)  # Don't show selector if only one profile

      # Get current selected profile or default
      current_profile <- selected_stats_profile()
      if (is.null(current_profile) || !(current_profile %in% profile_names)) {
        current_profile <- stats_json$default_profile
        if (is.null(current_profile) || !(current_profile %in% profile_names)) {
          current_profile <- profile_names[1]
        }
        selected_stats_profile(current_profile)
      }

      tags$span(
        style = "float: right; display: flex; align-items: center; gap: 8px;",
        tags$span(style = "font-size: 11px; color: #666;", "Profile:"),
        tags$select(
          id = ns("stats_profile_select"),
          style = "font-size: 11px; padding: 2px 6px; border: 1px solid #ccc; border-radius: 4px;",
          onchange = sprintf("Shiny.setInputValue('%s', this.value, {priority: 'event'})", ns("stats_profile_change")),
          lapply(profile_names, function(pn) {
            is_selected <- !is.na(pn) && !is.na(current_profile) && pn == current_profile
            tags$option(value = pn, selected = if (is_selected) "selected" else NULL, pn)
          })
        )
      )
    })
  }, ignoreInit = FALSE)

  ## Render Other Information Content ----
  observe_event(c(get_stats_data(), selected_stats_profile()), {
    output$stats_info_content <- renderUI({
      stats_json <- get_stats_data()
      if (is.null(stats_json)) {
        return(tags$p(style = "color: #999; font-style: italic;", i18n$t("no_stats_yet")))
      }

      profiles <- stats_json$profiles
      if (is.null(profiles) || length(profiles) == 0) {
        return(tags$p(style = "color: #999; font-style: italic;", "No profiles found."))
      }

      # Get current profile
      current_profile <- selected_stats_profile()
      profile_names <- sapply(profiles, function(p) p$name_en)

      if (is.null(current_profile) || !(current_profile %in% profile_names)) {
        current_profile <- stats_json$default_profile
        if (is.null(current_profile) || !(current_profile %in% profile_names)) {
          current_profile <- profile_names[1]
        }
        selected_stats_profile(current_profile)
      }

      # Find profile data
      profile_data <- NULL
      for (p in profiles) {
        if (!is.null(p$name_en) && p$name_en == current_profile) {
          profile_data <- p
          break
        }
      }

      if (is.null(profile_data)) {
        profile_data <- profiles[[1]]
      }

      render_stats_summary_panel(profile_data)
    })
  }, ignoreInit = FALSE)

  ## Render Distribution Content (boxplot + stats) ----
  observe_event(c(get_stats_data(), selected_stats_profile()), {
    output$stats_distribution_content <- renderUI({
      stats_json <- get_stats_data()
      if (is.null(stats_json)) {
        return(tags$p(style = "color: #999; font-style: italic;", i18n$t("no_stats_yet")))
      }

      profiles <- stats_json$profiles
      if (is.null(profiles) || length(profiles) == 0) {
        return(tags$p(style = "color: #999; font-style: italic;", "No profiles found."))
      }

      # Get current profile
      current_profile <- selected_stats_profile()
      profile_names <- sapply(profiles, function(p) p$name_en)

      if (is.null(current_profile) || !(current_profile %in% profile_names)) {
        current_profile <- stats_json$default_profile
        if (is.null(current_profile) || !(current_profile %in% profile_names)) {
          current_profile <- profile_names[1]
        }
        selected_stats_profile(current_profile)
      }

      # Find profile data
      profile_data <- NULL
      for (p in profiles) {
        if (!is.null(p$name_en) && p$name_en == current_profile) {
          profile_data <- p
          break
        }
      }

      if (is.null(profile_data)) {
        profile_data <- profiles[[1]]
      }

      # Render only boxplot section (without histogram)
      render_stats_boxplot_section(profile_data)
    })
  }, ignoreInit = FALSE)

  ## Render Histogram Content ----
  observe_event(c(get_stats_data(), selected_stats_profile()), {
    output$stats_histogram_content <- renderUI({
      stats_json <- get_stats_data()
      if (is.null(stats_json)) {
        return(tags$p(style = "color: #999; font-style: italic;", i18n$t("no_stats_yet")))
      }

      profiles <- stats_json$profiles
      if (is.null(profiles) || length(profiles) == 0) {
        return(tags$p(style = "color: #999; font-style: italic;", "No profiles found."))
      }

      # Get current profile
      current_profile <- selected_stats_profile()
      profile_names <- sapply(profiles, function(p) p$name_en)

      if (is.null(current_profile) || !(current_profile %in% profile_names)) {
        current_profile <- stats_json$default_profile
        if (is.null(current_profile) || !(current_profile %in% profile_names)) {
          current_profile <- profile_names[1]
        }
        selected_stats_profile(current_profile)
      }

      # Find profile data
      profile_data <- NULL
      for (p in profiles) {
        if (!is.null(p$name_en) && p$name_en == current_profile) {
          profile_data <- p
          break
        }
      }

      if (is.null(profile_data)) {
        profile_data <- profiles[[1]]
      }

      # Render only histogram section
      render_stats_histogram_section(profile_data)
    })
  }, ignoreInit = FALSE)

  ## Toggle Statistics Edit Mode ----
  observe_event(concepts_edit_mode(), {
    is_edit <- concepts_edit_mode()

    if (is_edit) {
      # Load current stats into editor
      cs_id <- viewing_concept_set_id()
      if (!is.null(cs_id)) {
        con <- get_db_connection()
        on.exit(DBI::dbDisconnect(con))

        stats_data <- DBI::dbGetQuery(
          con,
          "SELECT stats FROM concept_set_stats WHERE concept_set_id = ?",
          params = list(cs_id)
        )

        stats_text <- if (nrow(stats_data) > 0 && !is.na(stats_data$stats[1])) {
          # Pretty print the JSON
          tryCatch({
            parsed <- jsonlite::fromJSON(stats_data$stats[1])
            jsonlite::toJSON(parsed, auto_unbox = TRUE, pretty = TRUE)
          }, error = function(e) {
            stats_data$stats[1]
          })
        } else {
          "{}"
        }

        shinyAce::updateAceEditor(session, "stats_editor", value = stats_text)
      }

      # Show edit mode
      shinyjs::hide("stats_view_section")
      shinyjs::show("stats_edit_section")
      shinyjs::hide("stats_json_error")
    } else {
      # Show view mode
      shinyjs::show("stats_view_section")
      shinyjs::hide("stats_edit_section")
    }
  }, ignoreInit = FALSE)

  ## Handle Statistics Profile Change ----
  observe_event(input$stats_profile_change, {
    new_profile <- input$stats_profile_change
    if (!is.null(new_profile)) {
      selected_stats_profile(new_profile)
      # Observers will react to selected_stats_profile() change automatically
    }
  }, ignoreInit = TRUE)

    # Return selected concept set for use by parent
    selected_concept_set
  })
}
