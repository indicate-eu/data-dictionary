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
          create_page_layout(
            "full",
            create_panel(
              title = i18n$t("concept_sets"),
              content = tags$div(
                style = "position: relative;",
                fuzzy_search_ui("fuzzy_search", ns = ns, i18n = i18n),
                DT::DTOutput(ns("concept_sets_table"))
              ),
              tooltip = i18n$t("concept_sets_tooltip"),
              header_extra = shinyjs::hidden(
                actionButton(
                  ns("add_concept_set"),
                  i18n$t("add_concept_set"),
                  class = "btn-success-custom btn-sm",
                  icon = icon("plus")
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
                      # Edit button (visible by default in view mode)
                      shinyjs::hidden(
                        actionButton(
                          ns("edit_concepts_btn"),
                          label = NULL,
                          icon = icon("edit"),
                          class = "btn-save-icon has-tooltip",
                          `data-tooltip` = as.character(i18n$t("edit_page"))
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
                            class = "btn-secondary-custom btn-sm",
                            icon = icon("times")
                          ),
                          actionButton(
                            ns("save_edit_concepts"),
                            i18n$t("save"),
                            class = "btn-primary-custom btn-sm",
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
                          class = "settings-section settings-backup-section",
                          # Section header with title and action buttons
                          tags$div(
                            class = "settings-section-header",
                            tags$h4(
                              class = "settings-section-title",
                              style = "margin: 0;",
                              tags$i(class = "fas fa-list", style = "margin-right: 8px; color: #0f60af;"),
                              i18n$t("concepts")
                            ),
                            # Action buttons (hidden by default, shown in edit mode)
                            shinyjs::hidden(
                              tags$div(
                                id = ns("concepts_edit_buttons"),
                                class = "flex-gap-8",
                                actionButton(
                                  ns("delete_all_concepts"),
                                  i18n$t("delete_all"),
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
                            )
                          ),
                          tags$p(
                            class = "settings-section-desc",
                            i18n$t("concepts_in_set_tooltip")
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
                          class = "settings-section settings-backup-section",
                          tags$h4(
                            class = "settings-section-title settings-section-title-success",
                            tags$i(class = "fas fa-info-circle", style = "margin-right: 8px; color: #28a745;"),
                            i18n$t("selected_concept_details")
                          ),
                          tags$p(
                            class = "settings-section-desc",
                            i18n$t("selected_concept_details_tooltip")
                          ),
                          tags$div(
                            style = "flex: 1; overflow: auto;",
                            uiOutput(ns("selected_concept_details"))
                          )
                        ),

                        # Bottom-right: Related concepts with sub-tabs
                        tags$div(
                          id = ns("concepts_section_related"),
                          class = "settings-section settings-backup-section",
                          tags$div(
                            style = "display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px;",
                            tags$h4(
                              class = "settings-section-title",
                              style = "margin: 0;",
                              tags$i(class = "fas fa-link", style = "margin-right: 8px; color: #0f60af;"),
                              i18n$t("related_concepts")
                            ),
                            tags$div(
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
                              )
                            )
                          ),
                          tags$p(
                            class = "settings-section-desc",
                            i18n$t("related_concepts_tooltip")
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
                              style = "flex: 1; overflow: auto;",
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
                        tags$div(
                          class = "settings-section settings-backup-section",
                          style = "width: 100%; max-width: 100%;",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-comment", style = "margin-right: 8px; color: #0f60af;"),
                            i18n$t("comments")
                          ),
                          tags$p(
                            class = "settings-section-desc",
                            i18n$t("comments_stats_tooltip")
                          ),
                          uiOutput(ns("comments_display"))
                        )
                      )
                    ),

                    # Statistics Tab Panel
                    tags$div(
                      id = ns("panel_stats"),
                      class = "detail-tab-panel",
                      tags$div(
                        class = "settings-backup-container",
                        tags$div(
                          class = "settings-section settings-backup-section",
                          style = "width: 100%; max-width: 100%;",
                          tags$h4(
                            class = "settings-section-title",
                            tags$i(class = "fas fa-chart-bar", style = "margin-right: 8px; color: #0f60af;"),
                            i18n$t("statistics")
                          ),
                          tags$p(
                            class = "settings-section-desc",
                            i18n$t("statistics_desc")
                          ),
                          uiOutput(ns("stats_display"))
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
                            tags$i(class = "fas fa-clipboard-check", style = "margin-right: 8px; color: #0f60af;"),
                            i18n$t("review")
                          ),
                          tags$p(
                            class = "settings-section-desc",
                            i18n$t("review_desc")
                          ),
                          uiOutput(ns("review_display"))
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
            actionButton(ns("save_concept_set"), i18n$t("save"), class = "btn-primary-custom", icon = icon("save"))
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

        ### Modal - Add Concepts to Concept Set ----
        tags$div(
          id = ns("add_concepts_modal"),
          class = "modal-fullscreen",
          style = "display: none;",

          # Header
          tags$div(
            class = "modal-header",
            style = "padding: 15px 20px; border-bottom: 1px solid #ddd; background: #f8f9fa; display: flex; align-items: center; gap: 10px;",
            tags$button(
              class = "modal-fullscreen-close",
              style = "position: static; font-size: 24px; width: 32px; height: 32px; display: flex; align-items: center; justify-content: center;",
              onclick = sprintf("document.getElementById('%s').style.display = 'none';", ns("add_concepts_modal")),
              HTML("&times;")
            ),
            tags$h3(class = "modal-title", style = "margin: 0; font-size: 16px;", i18n$t("add_concepts_to_set"))
          ),

          # Content
          tags$div(
            class = "modal-body",
            style = "flex: 1; display: flex; flex-direction: column; padding: 20px; overflow: hidden;",

            # Search section (top)
            tags$div(
              style = "flex: 2; min-height: 0; display: flex; flex-direction: column; overflow: hidden;",
              tags$div(
                style = "position: relative; flex: 1; min-height: 0; overflow: auto;",
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

            # Bottom section: Concept Details (left) and Descendants (right)
            tags$div(
              style = "flex: 1; min-height: 200px; display: flex; gap: 15px;",

              # Concept Details (left)
              tags$div(
                style = "flex: 1; min-height: 0; display: flex; flex-direction: column; border: 1px solid #ddd; border-radius: 4px; padding: 15px; background: white;",
                tags$h5(i18n$t("selected_concept_details_modal"), style = "margin-top: 0; margin-bottom: 10px;"),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto;",
                  uiOutput(ns("add_modal_concept_details"))
                )
              ),

              # Descendants (right)
              tags$div(
                style = "flex: 1; min-height: 0; display: flex; flex-direction: column; border: 1px solid #ddd; border-radius: 4px; padding: 15px; background: white;",
                tags$h5(i18n$t("descendants"), style = "margin-top: 0; margin-bottom: 10px;"),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto;",
                  DT::DTOutput(ns("add_modal_descendants_table"))
                )
              )
            ),

            # Bottom buttons
            tags$div(
              style = "display: flex; justify-content: space-between; align-items: center; flex-shrink: 0; padding-top: 10px;",
              # Left side: Multiple selection checkbox
              tags$div(
                class = "checkbox",
                style = "display: flex; align-items: center; margin: 0;",
                tags$label(
                  style = "display: flex; align-items: center; margin: 0; cursor: pointer;",
                  tags$input(
                    id = ns("add_modal_multiple_select"),
                    type = "checkbox",
                    class = "shiny-input-checkbox"
                  ),
                  tags$span(
                    style = "margin-left: 5px;",
                    i18n$t("multiple_selection")
                  )
                )
              ),
              # Right side: Toggles and Add button
              tags$div(
                class = "flex-center-gap-8",
                # Exclude toggle
                tags$div(
                  class = "flex-center-gap-8",
                  tags$span(i18n$t("exclude"), style = "font-size: 13px; color: #666;"),
                  tags$label(
                    class = "toggle-switch toggle-small toggle-exclude",
                    tags$input(
                      type = "checkbox",
                      id = ns("add_modal_is_excluded")
                    ),
                    tags$span(class = "toggle-slider")
                  )
                ),
                # Descendants toggle
                tags$div(
                  class = "flex-center-gap-8",
                  style = "margin-left: 15px;",
                  tags$span(i18n$t("include_descendants"), style = "font-size: 13px; color: #666;"),
                  tags$label(
                    class = "toggle-switch toggle-small",
                    tags$input(
                      type = "checkbox",
                      id = ns("add_modal_include_descendants"),
                      checked = "checked"
                    ),
                    tags$span(class = "toggle-slider")
                  )
                ),
                # Mapped toggle
                tags$div(
                  class = "flex-center-gap-8",
                  style = "margin-left: 15px;",
                  tags$span(i18n$t("include_mapped"), style = "font-size: 13px; color: #666;"),
                  tags$label(
                    class = "toggle-switch toggle-small",
                    tags$input(
                      type = "checkbox",
                      id = ns("add_modal_include_mapped"),
                      checked = "checked"
                    ),
                    tags$span(class = "toggle-slider")
                  )
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

        ### Modal - Delete All Concepts Confirmation ----
        create_modal(
          id = "delete_all_concepts_modal",
          title = i18n$t("confirm_deletion"),
          body = tagList(
            tags$p(i18n$t("confirm_delete_all_concepts"))
          ),
          footer = tagList(
            actionButton(ns("cancel_delete_all_concepts"), i18n$t("cancel"), class = "btn-secondary-custom", icon = icon("times")),
            actionButton(ns("confirm_delete_all_concepts"), i18n$t("delete_all"), class = "btn-danger-custom", icon = icon("trash"))
          ),
          size = "small",
          icon = "fas fa-exclamation-triangle",
          ns = ns
        )
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

    ## Triggers ----
    table_trigger <- reactiveVal(0)
    tags_trigger <- reactiveVal(0)

    ## Edit State ----
    editing_id <- reactiveVal(NULL)
    deleting_id <- reactiveVal(NULL)
    editing_tag_id <- reactiveVal(NULL)
    deleting_tag_id <- reactiveVal(NULL)
    concepts_edit_mode <- reactiveVal(FALSE)

    ## Fuzzy Search ----
    fuzzy <- fuzzy_search_server("fuzzy_search", input, session, trigger_rv = table_trigger, ns = ns)

    # 2) DATA LOADING ====

    ## Load Concept Sets and Tags ----
    observe_event(TRUE, {
      # Show/hide buttons based on permissions
      if (can_edit()) {
        shinyjs::show("add_concept_set")
      }

      # Load concept sets data
      data <- get_all_concept_sets()
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)

      # Load tags
      all_tags <- get_all_tags()
      tags_data(all_tags)
      tags_trigger(tags_trigger() + 1)
    }, ignoreInit = FALSE, once = TRUE)

    # 3) TABLE RENDERING ====

    ## Concept Sets Table ----
    observe_event(table_trigger(), {
      output$concept_sets_table <- DT::renderDT({
        data <- concept_sets_data()

        if (is.null(data) || nrow(data) == 0) {
          return(create_empty_datatable(as.character(i18n$t("no_concept_sets"))))
        }

        # Apply fuzzy search filter on name column
        query <- fuzzy$query()
        if (!is.null(query) && query != "") {
          data <- fuzzy_search_df(data, query, "name", max_dist = 3)
          if (nrow(data) == 0) {
            return(create_empty_datatable(as.character(i18n$t("no_concept_sets"))))
          }
        }

        # Format last update date (show date and time HH:MM, or empty if NA)
        format_date <- function(dt_str) {
          if (is.na(dt_str) || dt_str == "") return("")
          tryCatch({
            # Parse ISO format and return date + time (HH:MM)
            # Format: "YYYY-MM-DD HH:MM" (replace T with space)
            gsub("T", " ", substr(dt_str, 1, 16))
          }, error = function(e) "")
        }

        # Format tags with space after comma
        format_tags <- function(tags_str) {
          if (is.na(tags_str) || tags_str == "") return("")
          # Split by comma, trim whitespace, rejoin with ", "
          tags_list <- trimws(strsplit(tags_str, ",")[[1]])
          paste(tags_list, collapse = ", ")
        }

        # Prepare display data - order: category, subcategory, name, description, tags, concepts, last_update
        display_data <- data.frame(
          id = data$id,
          category = ifelse(is.na(data$category), "", data$category),
          subcategory = ifelse(is.na(data$subcategory), "", data$subcategory),
          name = data$name,
          description = ifelse(
            is.na(data$description), "",
            ifelse(nchar(data$description) > 100, paste0(substr(data$description, 1, 100), "..."), data$description)
          ),
          tags = sapply(data$tags, format_tags),
          item_count = data$item_count,
          last_update = sapply(data$modified_date, format_date),
          stringsAsFactors = FALSE
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
              label = as.character(i18n$t("export")),
              icon = "download",
              type = "success",
              class = "btn-export",
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
            as.character(i18n$t("concepts")),
            as.character(i18n$t("last_update")),
            as.character(i18n$t("actions"))
          ),
          col_defs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 1, width = "9%"),
            list(targets = 2, width = "9%"),
            list(targets = 3, width = "14%"),
            list(targets = 4, width = "20%"),
            list(targets = 5, width = "9%"),
            list(targets = 6, width = "6%", className = "dt-center"),
            list(targets = 7, width = "10%", className = "dt-center"),
            list(targets = 8, width = "23%", className = "dt-center")
          ),
          escape = FALSE
        )

        add_button_handlers(
          dt,
          handlers = list(
            list(selector = ".btn-view", input_id = ns("view_concept_set")),
            list(selector = ".btn-edit", input_id = ns("edit_concept_set")),
            list(selector = ".btn-export", input_id = ns("export_concept_set")),
            list(selector = ".btn-delete", input_id = ns("delete_concept_set"))
          ),
          dblclick_input_id = ns("view_concept_set"),
          id_column_index = 0
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
      cs <- get_concept_set(concept_set_id)
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

      # Get current user login
      created_by <- NULL
      if (!is.null(current_user) && is.reactive(current_user)) {
        user <- current_user()
        if (!is.null(user) && !is.null(user$login)) {
          created_by <- user$login
        }
      }

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
          created_by = created_by
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
          modified_by = created_by
        )
        showNotification(as.character(i18n$t("concept_set_updated")), type = "message")
      }

      # Hide modal and refresh data
      hide_modal(ns("concept_set_modal"))
      editing_id(NULL)

      # Reload data
      data <- get_all_concept_sets()
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
        var container = document.getElementById('%s').closest('.color-picker-container');
        if (container) {
          container.querySelector('.color-picker-value').value = '#6c757d';
          container.querySelector('.color-picker-preview').style.backgroundColor = '#6c757d';
          container.querySelector('.color-picker-custom-input').value = '#6c757d';
          container.querySelectorAll('.color-preset').forEach(function(el) { el.classList.remove('selected'); });
          container.querySelector('.color-preset[data-color=\"#6c757d\"]').classList.add('selected');
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
        var container = document.getElementById('%s').closest('.color-picker-container');
        if (container) {
          container.querySelector('.color-picker-value').value = '%s';
          container.querySelector('.color-picker-preview').style.backgroundColor = '%s';
          container.querySelector('.color-picker-custom-input').value = '%s';
          container.querySelectorAll('.color-preset').forEach(function(el) { el.classList.remove('selected'); });
          var matchingPreset = container.querySelector('.color-preset[data-color=\"%s\"]');
          if (matchingPreset) matchingPreset.classList.add('selected');
        }
        Shiny.setInputValue('%s', '%s', {priority: 'event'});
      ", ns("edit_tag_color"), tag_color, tag_color, tag_color, tag_color, ns("edit_tag_color"), tag_color))

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
      data <- get_all_concept_sets()
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)
    }, ignoreInit = TRUE)

    # 6) CONCEPT SET DETAILS VIEW ====

    ## State for details view ----
    viewing_concept_set_id <- reactiveVal(NULL)
    selected_concept_id <- reactiveVal(NULL)
    concepts_trigger <- reactiveVal(0)

    ## View Concept Set (open details page) ----
    observe_event(input$view_concept_set, {
      concept_set_id <- input$view_concept_set
      if (is.null(concept_set_id)) return()

      viewing_concept_set_id(concept_set_id)

      # Load concept set data
      cs <- get_concept_set(concept_set_id)
      if (is.null(cs)) return()

      # Update the title
      shinyjs::html("concept_set_detail_title", htmltools::htmlEscape(cs$name))

      # Switch to details view
      shinyjs::hide("concept_sets_list_container")
      shinyjs::show("concept_set_details_container")

      # Reset edit mode
      concepts_edit_mode(FALSE)
      shinyjs::hide("edit_mode_buttons")
      shinyjs::hide("concepts_edit_buttons")
      shinyjs::runjs(sprintf(
        "$('#%s').closest('.settings-backup-container').removeClass('edit-mode');",
        ns("concepts_section_left")
      ))

      # Show edit button if user can edit
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

      # Reset edit mode
      concepts_edit_mode(FALSE)
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

        if (is.null(concepts) || nrow(concepts) == 0) {
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
        if (is.null(concepts) || nrow(concepts) == 0) return(NULL)

        # Prepare display data
        display_data <- data.frame(
          concept_id = concepts$concept_id,
          concept_name = concepts$concept_name,
          vocabulary_id = concepts$vocabulary_id,
          concept_code = concepts$concept_code,
          standard_concept = ifelse(
            is.na(concepts$standard_concept) | concepts$standard_concept == "",
            "",
            concepts$standard_concept
          ),
          stringsAsFactors = FALSE
        )

        # Check if in edit mode
        is_edit_mode <- concepts_edit_mode()

        # Add actions column only if user can edit AND in edit mode
        if (can_edit() && is_edit_mode) {
          display_data$actions <- sapply(display_data$concept_id, function(cid) {
            create_datatable_actions(list(
              list(
                label = NULL,
                icon = "trash",
                type = "danger",
                class = "btn-remove-concept",
                data_attr = list(id = cid)
              )
            ))
          })

          dt <- create_standard_datatable(
            display_data,
            selection = "single",
            col_names = c(
              as.character(i18n$t("omop_concept_id")),
              as.character(i18n$t("omop_concept_name")),
              "Vocabulary",
              "Code",
              as.character(i18n$t("standard")),
              ""
            ),
            col_defs = list(
              list(targets = 0, width = "10%"),
              list(targets = 1, width = "38%"),
              list(targets = 2, width = "14%"),
              list(targets = 3, width = "14%"),
              list(targets = 4, width = "12%", className = "dt-center"),
              list(targets = 5, width = "12%", className = "dt-center", orderable = FALSE)
            ),
            escape = FALSE
          )

          dt <- add_button_handlers(dt, handlers = list(
            list(selector = ".btn-remove-concept", input_id = ns("remove_concept"))
          ))
        } else {
          dt <- create_standard_datatable(
            display_data,
            selection = "single",
            col_names = c(
              as.character(i18n$t("omop_concept_id")),
              as.character(i18n$t("omop_concept_name")),
              "Vocabulary",
              "Code",
              as.character(i18n$t("standard"))
            ),
            col_defs = list(
              list(targets = 0, width = "12%"),
              list(targets = 1, width = "45%"),
              list(targets = 2, width = "15%"),
              list(targets = 3, width = "15%"),
              list(targets = 4, width = "13%", className = "dt-center")
            ),
            escape = TRUE
          )
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

      selected_concept_id(concepts$concept_id[rows])
    }, ignoreInit = TRUE)

    ## Selected Concept Details (bottom-left quadrant) ----
    output$selected_concept_details <- renderUI({
      concept_id <- selected_concept_id()

      if (is.null(concept_id)) {
        return(tags$div(
          class = "no-selection-message",
          tags$p(i18n$t("no_concept_selected"))
        ))
      }

      # Get concept details from vocabulary database
      concept <- get_concept_by_id(concept_id)

      if (is.null(concept) || nrow(concept) == 0) {
        return(tags$div(
          class = "no-selection-message",
          tags$p(i18n$t("no_concept_selected"))
        ))
      }

      # Build details display
      tags$div(
        class = "concept-details-card",
        tags$div(
          class = "detail-row",
          tags$span(class = "detail-label", "Concept ID:"),
          tags$span(class = "detail-value", concept$concept_id[1])
        ),
        tags$div(
          class = "detail-row",
          tags$span(class = "detail-label", "Concept Name:"),
          tags$span(class = "detail-value", concept$concept_name[1])
        ),
        tags$div(
          class = "detail-row",
          tags$span(class = "detail-label", "Domain:"),
          tags$span(class = "detail-value", ifelse(is.na(concept$domain_id[1]), "-", concept$domain_id[1]))
        ),
        tags$div(
          class = "detail-row",
          tags$span(class = "detail-label", "Vocabulary:"),
          tags$span(class = "detail-value", ifelse(is.na(concept$vocabulary_id[1]), "-", concept$vocabulary_id[1]))
        ),
        tags$div(
          class = "detail-row",
          tags$span(class = "detail-label", "Concept Class:"),
          tags$span(class = "detail-value", ifelse(is.na(concept$concept_class_id[1]), "-", concept$concept_class_id[1]))
        ),
        tags$div(
          class = "detail-row",
          tags$span(class = "detail-label", "Concept Code:"),
          tags$span(class = "detail-value", ifelse(is.na(concept$concept_code[1]), "-", concept$concept_code[1]))
        ),
        tags$div(
          class = "detail-row",
          tags$span(class = "detail-label", "Standard Concept:"),
          tags$span(class = "detail-value", ifelse(is.na(concept$standard_concept[1]) || concept$standard_concept[1] == "", "Non-Standard", concept$standard_concept[1]))
        )
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
      cs <- get_concept_set(cs_id)

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

      # Build HTML table manually for simple display
      tags$div(
        class = "simple-table-container",
        style = "overflow: auto; max-height: 100%;",
        tags$table(
          class = "table table-striped table-sm",
          style = "width: 100%; font-size: 13px;",
          tags$thead(
            tags$tr(
              tags$th(style = "width: 12%;", i18n$t("omop_concept_id")),
              tags$th(style = "width: 45%;", i18n$t("omop_concept_name")),
              tags$th(style = "width: 23%;", "Relationship"),
              tags$th(style = "width: 20%;", "Vocabulary")
            )
          ),
          tags$tbody(
            lapply(seq_len(nrow(related)), function(i) {
              tags$tr(
                tags$td(related$concept_id[i]),
                tags$td(related$concept_name[i]),
                tags$td(related$relationship_id[i]),
                tags$td(related$vocabulary_id[i])
              )
            })
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

      # Placeholder for hierarchy visualization
      tags$div(
        class = "no-content-message",
        tags$p(i18n$t("coming_soon"))
      )
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

      # Placeholder for synonyms
      tags$div(
        class = "no-content-message",
        tags$p(i18n$t("coming_soon"))
      )
    })

    # 7) CONCEPT SET ITEMS MANAGEMENT ====

    ## State for add concepts modal ----
    omop_concepts_cache <- reactiveVal(NULL)
    add_modal_selected_concept <- reactiveVal(NULL)
    omop_table_trigger <- reactiveVal(0)
    removing_concept_id <- reactiveVal(NULL)

    ## Fuzzy search for OMOP concepts ----
    omop_fuzzy <- fuzzy_search_server(
      "omop_fuzzy_search",
      input,
      session,
      trigger_rv = omop_table_trigger,
      ns = ns
    )

    ## Enter Edit Mode for Concepts ----
    observe_event(input$edit_concepts_btn, {
      if (!can_edit()) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Enter edit mode
      concepts_edit_mode(TRUE)

      # Update UI: hide edit button, show save/cancel buttons
      shinyjs::hide("edit_concepts_btn")
      shinyjs::show("edit_mode_buttons")

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

    ## Cancel Edit Mode for Concepts ----
    observe_event(input$cancel_edit_concepts, {
      # Exit edit mode
      concepts_edit_mode(FALSE)

      # Update UI: show edit button, hide save/cancel buttons
      shinyjs::show("edit_concepts_btn")
      shinyjs::hide("edit_mode_buttons")

      # Hide concepts edit action buttons
      shinyjs::hide("concepts_edit_buttons")

      # Remove edit-mode class from container
      shinyjs::runjs(sprintf(
        "$('#%s').closest('.settings-backup-container').removeClass('edit-mode');",
        ns("concepts_section_left")
      ))

      # Refresh concepts table to hide delete buttons
      concepts_trigger(concepts_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Save Edit Mode for Concepts ----
    observe_event(input$save_edit_concepts, {
      # Exit edit mode (changes are already saved individually)
      concepts_edit_mode(FALSE)

      # Update UI: show edit button, hide save/cancel buttons
      shinyjs::show("edit_concepts_btn")
      shinyjs::hide("edit_mode_buttons")

      # Hide concepts edit action buttons
      shinyjs::hide("concepts_edit_buttons")

      # Remove edit-mode class from container
      shinyjs::runjs(sprintf(
        "$('#%s').closest('.settings-backup-container').removeClass('edit-mode');",
        ns("concepts_section_left")
      ))

      # Refresh concepts table
      concepts_trigger(concepts_trigger() + 1)
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

      # Build query
      base_query <- vocabs$concept %>%
        dplyr::select(
          concept_id,
          concept_name,
          vocabulary_id,
          domain_id,
          concept_class_id,
          concept_code,
          standard_concept
        )

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
          utils::head(10000) %>%
          dplyr::collect()
      } else {
        concepts <- base_query %>%
          dplyr::arrange(concept_name) %>%
          utils::head(10000) %>%
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
        dplyr::select(concept_id, vocabulary_id, concept_name, concept_code, domain_id, concept_class_id, standard_concept)

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
          )
        )

      # Selection mode
      is_multiple <- isTRUE(input$add_modal_multiple_select)
      selection_mode <- if (is_multiple) "multiple" else "single"

      output$omop_concepts_table <- DT::renderDT({
        dt <- DT::datatable(
          display_concepts,
          rownames = FALSE,
          selection = selection_mode,
          filter = "top",
          options = list(
            pageLength = 10,
            lengthMenu = list(c(10, 25, 50, 100), c("10", "25", "50", "100")),
            dom = "ltip",
            language = get_datatable_language(),
            ordering = TRUE,
            autoWidth = FALSE,
            columnDefs = list(
              list(targets = 6, width = "100px", className = "dt-center")
            )
          ),
          colnames = c("Concept ID", "Vocabulary", "Concept Name", "Concept Code", "Domain", "Concept Class", "Standard")
        )

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
    output$add_modal_concept_details <- renderUI({
      concept_id <- add_modal_selected_concept()

      if (is.null(concept_id)) {
        return(tags$div(
          class = "no-selection-message",
          tags$p(i18n$t("no_concept_selected"))
        ))
      }

      concept <- get_concept_by_id(concept_id)

      if (is.null(concept) || nrow(concept) == 0) {
        return(tags$div(
          class = "no-selection-message",
          tags$p(i18n$t("no_concept_selected"))
        ))
      }

      tags$div(
        class = "concept-details-card",
        tags$div(class = "detail-row", tags$span(class = "detail-label", "Concept ID:"), tags$span(class = "detail-value", concept$concept_id[1])),
        tags$div(class = "detail-row", tags$span(class = "detail-label", "Concept Name:"), tags$span(class = "detail-value", concept$concept_name[1])),
        tags$div(class = "detail-row", tags$span(class = "detail-label", "Domain:"), tags$span(class = "detail-value", ifelse(is.na(concept$domain_id[1]), "-", concept$domain_id[1]))),
        tags$div(class = "detail-row", tags$span(class = "detail-label", "Vocabulary:"), tags$span(class = "detail-value", ifelse(is.na(concept$vocabulary_id[1]), "-", concept$vocabulary_id[1]))),
        tags$div(class = "detail-row", tags$span(class = "detail-label", "Concept Class:"), tags$span(class = "detail-value", ifelse(is.na(concept$concept_class_id[1]), "-", concept$concept_class_id[1]))),
        tags$div(class = "detail-row", tags$span(class = "detail-label", "Concept Code:"), tags$span(class = "detail-value", ifelse(is.na(concept$concept_code[1]), "-", concept$concept_code[1]))),
        tags$div(class = "detail-row", tags$span(class = "detail-label", "Standard:"), tags$span(class = "detail-value", ifelse(is.na(concept$standard_concept[1]) || concept$standard_concept[1] == "", "Non-Standard", concept$standard_concept[1])))
      )
    })

    ## Descendants Table in Add Modal ----
    output$add_modal_descendants_table <- DT::renderDT({
      concept_id <- add_modal_selected_concept()

      if (is.null(concept_id)) {
        return(create_empty_datatable(as.character(i18n$t("no_concept_selected"))))
      }

      # Get descendants from vocabulary database
      descendants <- get_concept_descendants(concept_id)

      if (is.null(descendants) || nrow(descendants) == 0) {
        return(create_empty_datatable(as.character(i18n$t("no_descendants"))))
      }

      dt <- create_standard_datatable(
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

      dt
    })

    ## Add OMOP Concepts to Concept Set ----
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

      # Count added concepts
      num_added <- 0
      num_already_present <- 0

      for (row_idx in selected_rows) {
        concept <- all_concepts[row_idx, ]

        result <- add_concept_set_item(
          concept_set_id = cs_id,
          concept_id = concept$concept_id,
          concept_name = concept$concept_name,
          vocabulary_id = concept$vocabulary_id,
          concept_code = concept$concept_code,
          standard_concept = concept$standard_concept,
          is_excluded = is_excluded,
          include_descendants = include_descendants,
          include_mapped = include_mapped
        )

        if (result) {
          num_added <- num_added + 1
        } else {
          num_already_present <- num_already_present + 1
        }
      }

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

      # Refresh concepts table
      concepts_trigger(concepts_trigger() + 1)

      # Refresh main table to update item count
      data <- get_all_concept_sets()
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)

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

    ## Confirm Remove Concept ----
    observe_event(input$confirm_remove_concept, {
      if (!can_edit()) return()

      cs_id <- viewing_concept_set_id()
      concept_id <- removing_concept_id()

      if (is.null(cs_id) || is.null(concept_id)) return()

      # Delete from database
      delete_concept_set_item(cs_id, concept_id)

      # Hide modal
      hide_modal(ns("remove_concept_modal"))
      removing_concept_id(NULL)

      # Show notification
      showNotification(
        as.character(i18n$t("concept_removed")),
        type = "message",
        duration = 3
      )

      # Refresh concepts table
      concepts_trigger(concepts_trigger() + 1)

      # Refresh main table to update item count
      data <- get_all_concept_sets()
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)
    }, ignoreInit = TRUE)

    ## Delete All Concepts - Show confirmation ----
    observe_event(input$delete_all_concepts, {
      if (!can_edit()) return()
      if (!concepts_edit_mode()) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Check if there are concepts to delete
      concepts <- get_concept_set_items(cs_id)
      if (is.null(concepts) || nrow(concepts) == 0) return()

      show_modal(ns("delete_all_concepts_modal"))
    }, ignoreInit = TRUE)

    ## Cancel Delete All Concepts ----
    observe_event(input$cancel_delete_all_concepts, {
      hide_modal(ns("delete_all_concepts_modal"))
    }, ignoreInit = TRUE)

    ## Confirm Delete All Concepts ----
    observe_event(input$confirm_delete_all_concepts, {
      if (!can_edit()) return()

      cs_id <- viewing_concept_set_id()
      if (is.null(cs_id)) return()

      # Get all concepts and delete them
      concepts <- get_concept_set_items(cs_id)
      if (!is.null(concepts) && nrow(concepts) > 0) {
        for (cid in concepts$concept_id) {
          delete_concept_set_item(cs_id, cid)
        }
      }

      # Hide modal
      hide_modal(ns("delete_all_concepts_modal"))

      # Show notification
      showNotification(
        as.character(i18n$t("all_concepts_deleted")),
        type = "message",
        duration = 3
      )

      # Refresh concepts table
      concepts_trigger(concepts_trigger() + 1)

      # Refresh main table to update item count
      data <- get_all_concept_sets()
      concept_sets_data(data)
      table_trigger(table_trigger() + 1)
    }, ignoreInit = TRUE)

    # Return selected concept set for use by parent
    reactive({
      rows <- input$concept_sets_table_rows_selected
      if (is.null(rows) || length(rows) == 0) return(list(selected_id = NULL))

      data <- concept_sets_data()
      if (is.null(data)) return(list(selected_id = NULL))

      list(selected_id = data$id[rows])
    })
  })
}
