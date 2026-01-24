# MODULE STRUCTURE OVERVIEW ====
#
# This module manages concept mapping - aligning user-provided concepts
# (custom concepts from CSV files) with standardized INDICATE dictionary concepts.
#
# UI STRUCTURE:
#   ## UI - Main Layout
#      ### Breadcrumb Navigation
#      ### Dynamic Content Area (switches between views)
#   ## UI - Modals
#      ### Modal - Alignment Editor (2-page form: name/description → file upload/mapping)
#      ### Modal - Concept Details Viewer
#      ### Modal - ETL Comments Display
#      ### Modal - Delete Confirmation Dialog
#
# SERVER STRUCTURE:
#   ## 1) Server - Reactive Values & State
#      ### View & Selection State - Track current view, selected alignment, tab
#      ### Edit Mode State - Manage edit/view mode (if applicable)
#      ### Data Management - Local data (alignments, uploaded data, vocabularies)
#      ### Cascade Triggers - Reactive triggers for cascade pattern
#
#   ## 2) Server - Navigation & Events
#      ### Trigger Updates - Cascade observers that propagate state changes
#      ### Breadcrumb Rendering - Dynamic breadcrumb navigation
#      ### Content Area Rendering - Switch between alignments list and detail views
#      ### Tab Switching - Handle Summary/All Mappings/Evaluate Mappings tabs
#      ### Navigation Handlers - All back button handlers (back_to_alignments, etc.)
#
#   ## 3) Server - Alignments List View
#      ### Alignments Table Rendering - Display alignments table
#      ### Add Alignment Modal - Create new alignment
#          #### Modal UI Handling - Show/hide modal, page navigation
#          #### File Upload & Processing - CSV/Excel upload, parsing
#          #### CSV Options & Column Mapping - Configure import options
#          #### File Preview - Display uploaded file preview
#          #### Save Alignment - Persist new alignment to database
#      ### Edit Alignment - Modify existing alignment
#      ### Delete Alignment - Remove alignment with confirmation
#      ### Open Alignment - Navigate to alignment detail view
#
#   ## 4) Server - Alignment Detail View
#      ### General Concepts Header Rendering - Display alignment header
#      ### Helper Functions - View Renderers - render_mapping_view(), etc.
#
#      ### a) Summary Tab
#          #### Source Concepts Table - Initial Render - Display source concepts (responds to alignment changes)
#          #### Source Concepts Table - Update Data Using Proxy - Preserve state during updates
#          #### General Concepts Table Rendering - Display general concepts
#          #### Concept Mappings Table Rendering - Display mappings for selected concept
#          #### Comments Display - Show ETL comments and guidance
#          #### Modal - Concept Details - Detailed concept information
#          #### Modal - ETL Comments - Fullscreen comments view
#          #### Add/Remove Mapping Actions - Create/delete mappings
#
#      ### b) All Mappings Tab
#          #### All Mappings Table - Initial Render - Display all mappings (responds to alignment changes)
#          #### All Mappings Table - Update Data Using Proxy - Preserve state during updates
#          #### Mapped View Tables - Source concepts and mapped concepts views
#          #### Delete Mapping Actions - Remove mappings
#
#      ### c) Import Mappings Tab
#          #### File Browser Modal Function - Show modal for file selection
#          #### File Path Display - Show selected file path
#          #### Browse Button Handler - Open file browser modal
#          #### Toggle Sort - Switch sort order
#          #### Filter Input - Filter files and folders
#          #### Current Path Display - Show current path in modal
#          #### Sort Icon Display - Show sort direction icon
#          #### Go Home Button - Navigate to home directory
#          #### File Browser Rendering - Display files and folders
#          #### Navigation Handler - Handle folder navigation
#          #### Select File Handler - Handle file selection
#          #### Cancel Browse - Close modal without selection
#          #### Import History Table - Display import history
#          #### Import CSV Handler - Process selected CSV file
#          #### Delete Import - Remove imported mappings
#
#      ### d) Evaluate Mappings Tab
#          #### Evaluate Mappings State - Track evaluation state
#          #### Evaluate Mappings Table - Initial Render - Display evaluation table (responds to alignment changes)
#          #### Evaluate Mappings Table - Update Data Using Proxy - Preserve state during updates
#          #### Projects Compatibility Table - Show project compatibility
#          #### Handle Evaluation Actions - Process votes
#          #### Handle Comment Editing - Double-click to edit comments
#          #### Save Comment - Persist comment changes
#
#      ### Export Alignment - Export functionality

# UI SECTION ====

#' Concept Mapping Module - UI
#'
#' @description UI function for the concept mapping module
#'
#' @param id Module ID
#'
#' @return Shiny UI elements
#' @noRd
#'
#' @importFrom shiny NS fluidRow column actionButton uiOutput textInput numericInput
#' @importFrom htmltools tags tagList
#' @importFrom DT DTOutput
mod_concept_mapping_ui <- function(id, i18n) {
  ns <- NS(id)

  tagList(
    shinyjs::useShinyjs(),

    # Main content for concept mapping
    div(class = "main-panel",
        div(class = "main-content",
            # Breadcrumb navigation
            uiOutput(ns("breadcrumb")),

            # Dynamic content area
            uiOutput(ns("content_area"))
        )
    ),

    # Modal for adding/editing alignment (2 pages)
    tags$div(
      id = ns("alignment_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("alignment_modal")),
      tags$div(
        id = ns("alignment_modal_dialog"),
        class = "modal-content",
        style = "max-width: 600px; max-height: 90vh; display: flex; flex-direction: column;",
        tags$div(
          class = "modal-header",
          tags$h3(id = ns("alignment_modal_title"), i18n$t("add_alignment")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("alignment_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "flex: 1; overflow: hidden; padding: 20px; display: flex; flex-direction: column;",
          # Page 1: Name and Description
          tags$div(
            id = ns("modal_page_1"),
            tags$div(
              class = "mb-20",
              tags$label(i18n$t("alignment_name"), class = "form-label"),
              textInput(
                ns("alignment_name"),
                label = NULL,
                placeholder = as.character(i18n$t("enter_alignment_name")),
                width = "100%"
              ),
              tags$div(
                id = ns("alignment_name_error"),
                style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                i18n$t("please_enter_alignment_name")
              ),
              tags$div(
                id = ns("alignment_name_duplicate_error"),
                style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                i18n$t("name_already_exists")
              )
            ),
            tags$div(
              class = "mb-20",
              tags$label(i18n$t("description"), class = "form-label"),
              textAreaInput(
                ns("alignment_description"),
                label = NULL,
                placeholder = as.character(i18n$t("enter_description")),
                width = "100%",
                rows = 4
              )
            )
          ),
          # Page 2: File Upload and Preview (hidden initially)
          tags$div(
            id = ns("modal_page_2"),
            style = "display: none; height: 100%;",
            tags$div(
              style = "display: flex; gap: 20px; height: 100%;",
              # Left: Upload and column mapping
              tags$div(
                style = "flex: 1; min-width: 50%; display: flex; flex-direction: column; overflow-y: auto; gap: 10px;",
                tags$div(
                  style = "background-color: #f8f9fa; border-radius: 4px; overflow: hidden;",
                  tags$div(
                    style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px;",
                    i18n$t("upload_csv_file")
                  ),
                  tags$div(
                    class = "p-15",
                    fileInput(
                      ns("alignment_file"),
                      label = NULL,
                      accept = c(".csv", ".xlsx", ".xls")
                    ),
                    tags$div(
                      id = ns("alignment_file_error"),
                      style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                      i18n$t("please_upload_file")
                    )
                  )
                ),
                uiOutput(ns("csv_options")),
                uiOutput(ns("column_mapping_wrapper"))
              ),
              # Right: File preview
              tags$div(
                style = "width: 50%; display: flex; flex-direction: column; overflow: auto;",
                DT::DTOutput(ns("file_preview_table"))
              )
            )
          ),
          # Page 3: Column Data Types (hidden initially)
          tags$div(
            id = ns("modal_page_3"),
            style = "display: none; height: 100%;",
            tags$div(
              style = "display: flex; gap: 20px; height: 100%;",
              # Left: Data type selection
              tags$div(
                style = "flex: 1; min-width: 50%; display: flex; flex-direction: column; overflow-y: auto; gap: 10px;",
                tags$div(
                  style = "background-color: #f8f9fa; border-radius: 4px; overflow: hidden;",
                  tags$div(
                    style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px;",
                    i18n$t("column_data_types")
                  ),
                  tags$div(
                    class = "p-15",
                    uiOutput(ns("column_data_types_controls"))
                  )
                )
              ),
              # Right: File preview (same as page 2)
              tags$div(
                style = "width: 50%; display: flex; flex-direction: column; overflow: auto;",
                DT::DTOutput(ns("file_preview_table_page3"))
              )
            )
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "padding: 15px 20px; border-top: 1px solid #dee2e6; display: flex; align-items: center;",
          tags$div(
            id = ns("modal_page_indicator"),
            style = "color: #666; font-size: 14px;",
            "Page 1 of 3"
          ),
          tags$div(
            class = "flex-1"
          ),
          tags$div(
            class = "flex-gap-10",
            actionButton(
              ns("alignment_modal_cancel"),
              i18n$t("cancel"),
              class = "btn btn-secondary btn-secondary-custom",
              icon = icon("times")
            ),
            actionButton(
              ns("alignment_modal_back"),
              i18n$t("back"),
              class = "btn btn-secondary btn-secondary-custom",
              style = "display: none;",
              icon = icon("arrow-left")
            ),
            actionButton(
              ns("alignment_modal_next"),
              i18n$t("next"),
              class = "btn-primary-custom",
              icon = icon("arrow-right")
            ),
            actionButton(
              ns("alignment_modal_save"),
              i18n$t("save"),
              class = "btn-success-custom",
              style = "display: none;",
              icon = icon("save")
            )
          )
        )
      )
    ),

    # Modal for Import Column Mapping
    tags$div(
      id = ns("import_column_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("import_column_modal")),
      tags$div(
        id = ns("import_column_modal_dialog"),
        class = "modal-content",
        style = "max-width: 90vw; max-height: 80vh; display: flex; flex-direction: column; height: 80vh;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("import_column_mapping")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("import_column_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "flex: 1; overflow: hidden; padding: 20px; display: flex; flex-direction: column;",
          tags$div(
            style = "display: flex; gap: 20px; height: 100%;",
            # Left: Column mapping dropdowns
            tags$div(
              style = "flex: 0 0 350px; display: flex; flex-direction: column; overflow-y: auto;",
              tags$div(
                style = "background-color: #f8f9fa; border-radius: 4px; overflow: hidden;",
                tags$div(
                  style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px;",
                  i18n$t("import_column_mapping")
                ),
                tags$div(
                  class = "p-15",
                  tags$p(
                    style = "margin-bottom: 15px; color: #666; font-size: 13px;",
                    i18n$t("import_column_mapping_desc")
                  ),
                  # Source Code Column (required)
                  tags$div(
                    class = "mb-15",
                    tags$label(
                      style = "display: block; margin-bottom: 5px; font-weight: 500;",
                      i18n$t("source_code_column"),
                      tags$span(style = "color: #dc3545;", " *")
                    ),
                    selectInput(
                      ns("import_map_source_code"),
                      label = NULL,
                      choices = c(""),
                      selected = "",
                      width = "100%"
                    ),
                    tags$div(
                      id = ns("import_error_source_code"),
                      style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                      i18n$t("field_required")
                    )
                  ),
                  # Source Vocabulary Column (required)
                  tags$div(
                    class = "mb-15",
                    tags$label(
                      style = "display: block; margin-bottom: 5px; font-weight: 500;",
                      i18n$t("source_vocabulary_column"),
                      tags$span(style = "color: #dc3545;", " *")
                    ),
                    selectInput(
                      ns("import_map_source_vocab"),
                      label = NULL,
                      choices = c(""),
                      selected = "",
                      width = "100%"
                    ),
                    tags$div(
                      id = ns("import_error_source_vocab"),
                      style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                      i18n$t("field_required")
                    )
                  ),
                  # Target Concept ID Column (required)
                  tags$div(
                    class = "mb-15",
                    tags$label(
                      style = "display: block; margin-bottom: 5px; font-weight: 500;",
                      i18n$t("target_concept_column"),
                      tags$span(style = "color: #dc3545;", " *")
                    ),
                    selectInput(
                      ns("import_map_target_concept"),
                      label = NULL,
                      choices = c(""),
                      selected = "",
                      width = "100%"
                    ),
                    tags$div(
                      id = ns("import_error_target_concept"),
                      style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                      i18n$t("field_required")
                    ),
                    tags$div(
                      id = ns("import_error_numeric"),
                      style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
                      i18n$t("invalid_numeric_values")
                    )
                  )
                )
              )
            ),
            # Right: Preview table
            tags$div(
              style = "flex: 1; display: flex; flex-direction: column; overflow: auto;",
              tags$div(
                style = "background-color: #f8f9fa; border-radius: 4px; overflow: hidden; height: 100%; display: flex; flex-direction: column;",
                tags$div(
                  style = "background-color: #0f60af; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px;",
                  i18n$t("import_preview")
                ),
                tags$div(
                  style = "padding: 15px; flex: 1; overflow: auto;",
                  tags$p(
                    id = ns("import_rows_count"),
                    style = "color: #666; font-size: 13px; margin-bottom: 10px;"
                  ),
                  DT::DTOutput(ns("import_preview_table"))
                )
              )
            )
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "padding: 15px 20px; border-top: 1px solid #dee2e6; display: flex; justify-content: flex-end; gap: 10px;",
          actionButton(
            ns("import_cancel_mapping"),
            i18n$t("cancel"),
            class = "btn btn-secondary btn-secondary-custom",
            icon = icon("times")
          ),
          actionButton(
            ns("import_confirm_mapping"),
            i18n$t("import_mappings"),
            class = "btn-primary-custom",
            icon = icon("file-import")
          )
        )
      )
    ),

    # Modal for concept details
    tags$div(
      id = ns("concept_detail_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("concept_detail_modal")),
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h3("Concept Details"),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("concept_detail_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          uiOutput(ns("concept_detail_modal_body"))
        )
      )
    ),

    # Modal for ETL guidance and comments
    tags$div(
      id = ns("etl_comments_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("etl_comments_modal")),
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("etl_guidance_comments")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("etl_comments_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          uiOutput(ns("etl_comments_modal_body"))
        )
      )
    ),

    # Modal for delete confirmation
    tags$div(
      id = ns("delete_confirmation_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("delete_confirmation_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 500px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("confirm_deletion")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("delete_confirmation_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          tags$p(
            class = "mb-20",
            i18n$t("delete_alignment_confirm")
          ),
          tags$div(
            id = ns("delete_alignment_name_display"),
            style = "font-weight: bold; margin-bottom: 20px; padding: 10px; background-color: #f8f9fa; border-radius: 4px;"
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "display: flex; justify-content: flex-end; gap: 10px;",
          tags$button(
            class = "btn btn-secondary",
            onclick = sprintf("$('#%s').hide();", ns("delete_confirmation_modal")),
            tags$i(class = "fas fa-times"),
            paste0(" ", i18n$t("cancel"))
          ),
          actionButton(
            ns("confirm_delete_alignment"),
            i18n$t("delete"),
            class = "btn btn-danger",
            icon = icon("trash")
          )
        )
      )
    ),

    ### Modal - Delete Mappings Confirmation ----
    tags$div(
      id = ns("delete_mappings_confirmation_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("delete_mappings_confirmation_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 500px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("confirm_deletion")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("delete_mappings_confirmation_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          tags$p(
            id = ns("delete_mappings_message"),
            class = "mb-20"
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "display: flex; justify-content: flex-end; gap: 10px;",
          tags$button(
            class = "btn btn-secondary",
            onclick = sprintf("$('#%s').hide();", ns("delete_mappings_confirmation_modal")),
            tags$i(class = "fas fa-times"),
            paste0(" ", i18n$t("cancel"))
          ),
          actionButton(
            ns("confirm_delete_mappings"),
            i18n$t("delete"),
            class = "btn btn-danger",
            icon = icon("trash")
          )
        )
      )
    ),

    ### Modal - Comments Fullscreen ----
    tags$div(
      id = ns("target_comments_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        tags$div(
          style = "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
          # Left: Back button (hidden by default) and title
          tags$div(
            class = "flex-center-gap-10",
            actionButton(
              ns("back_from_target_global_comment"),
              label = HTML("&#8592;"),
              class = "btn-back-comment",
              style = "display: none;"
            ),
            tags$h3(
              id = ns("target_comments_modal_title"),
              class = "text-primary", style = "margin: 0;",
              i18n$t("etl_guidance_comments")
            )
          ),
          # Center: Global Comment button
          actionButton(
            ns("view_target_global_comment"),
            label = tagList(
              tags$i(class = "fas fa-globe", style = "margin-right: 6px;"),
              i18n$t("view_global_comment")
            ),
            class = "btn-global-comment"
          ),
          # Right: Close button
          actionButton(
            ns("close_target_comments_fullscreen"),
            label = HTML("&times;"),
            class = "modal-fullscreen-close"
          )
        ),
        # Concept comment content
        tags$div(
          id = ns("target_concept_comment_container"),
          style = "flex: 1; overflow: hidden; padding: 0;",
          uiOutput(ns("target_comments_fullscreen_content"))
        ),
        # Global comment content (hidden by default)
        tags$div(
          id = ns("target_global_comment_container"),
          style = "flex: 1; overflow: hidden; padding: 20px; display: none;",
          uiOutput(ns("target_global_comment_display"))
        )
      )
    ),

    ### Modal - Eval Comments Fullscreen ----
    tags$div(
      id = ns("eval_comments_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        tags$div(
          style = "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
          # Left: Back button (hidden by default) and title
          tags$div(
            class = "flex-center-gap-10",
            actionButton(
              ns("back_from_eval_global_comment"),
              label = HTML("&#8592;"),
              class = "btn-back-comment",
              style = "display: none;"
            ),
            tags$h3(
              id = ns("eval_comments_modal_title"),
              class = "text-primary", style = "margin: 0;",
              i18n$t("etl_guidance_comments")
            )
          ),
          # Center: Global Comment button
          actionButton(
            ns("view_eval_global_comment"),
            label = tagList(
              tags$i(class = "fas fa-globe", style = "margin-right: 6px;"),
              i18n$t("view_global_comment")
            ),
            class = "btn-global-comment"
          ),
          # Right: Close button
          actionButton(
            ns("close_eval_comments_fullscreen"),
            label = HTML("&times;"),
            class = "modal-fullscreen-close"
          )
        ),
        # Concept comment content
        tags$div(
          id = ns("eval_concept_comment_container"),
          style = "flex: 1; overflow: hidden; padding: 0;",
          uiOutput(ns("eval_comments_fullscreen_content"))
        ),
        # Global comment content (hidden by default)
        tags$div(
          id = ns("eval_global_comment_container"),
          style = "flex: 1; overflow: hidden; padding: 20px; display: none;",
          uiOutput(ns("eval_global_comment_display"))
        )
      )
    ),

    ### Modal - Mapping Comments ----
    tags$div(
      id = ns("mapping_comments_modal"),
      class = "modal-overlay",
      style = "display: none; z-index: 1050;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("mapping_comments_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 700px; max-height: 80vh; display: flex; flex-direction: column;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("mapping_comments")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("mapping_comments_modal")),
            "×"
          )
        ),
        tags$div(
          class = "modal-body",
          style = "flex: 1; overflow: auto; display: flex; flex-direction: column;",
          # Comments list container
          tags$div(
            id = ns("mapping_comments_list"),
            style = "flex: 1; overflow: auto; margin-bottom: 15px; min-height: 200px;"
          ),
          # Add comment form
          tags$div(
            style = "border-top: 1px solid #ddd; padding-top: 15px;",
            tags$div(
              style = "margin-bottom: 10px;",
              tags$label(
                `for` = ns("new_mapping_comment"),
                style = "font-weight: 600; margin-bottom: 5px; display: block;",
                i18n$t("add_comment")
              ),
              tags$textarea(
                id = ns("new_mapping_comment"),
                style = "width: 100%; min-height: 80px; padding: 10px; border: 1px solid #ddd; border-radius: 4px; resize: vertical;",
                placeholder = i18n$t("add_comment_placeholder")
              )
            ),
            tags$div(
              style = "display: flex; justify-content: flex-end;",
              actionButton(
                ns("submit_mapping_comment"),
                i18n$t("add_comment"),
                class = "btn-primary-custom",
                icon = icon("paper-plane")
              )
            )
          )
        )
      )
    ),

    ### Modal - Delete Comment Confirmation ----
    tags$div(
      id = ns("delete_comment_modal"),
      class = "modal-overlay",
      style = "display: none; z-index: 1060;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("delete_comment_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 400px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("confirm_deletion")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("delete_comment_modal")),
            HTML("&times;")
          )
        ),
        tags$div(
          class = "modal-body",
          tags$p(
            class = "mb-20",
            i18n$t("delete_comment_confirm")
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "display: flex; justify-content: flex-end; gap: 10px;",
          tags$button(
            class = "btn btn-secondary",
            onclick = sprintf("$('#%s').hide();", ns("delete_comment_modal")),
            i18n$t("cancel")
          ),
          actionButton(
            ns("confirm_delete_comment"),
            i18n$t("delete"),
            class = "btn btn-danger",
            icon = icon("trash")
          )
        )
      )
    ),

    ### Modal - Delete Import Confirmation ----
    tags$div(
      id = ns("delete_import_modal"),
      class = "modal-overlay",
      style = "display: none; z-index: 1060;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("delete_import_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 500px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("confirm_deletion")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("delete_import_modal")),
            HTML("&times;")
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          tags$p(
            id = ns("delete_import_message"),
            style = "margin-bottom: 15px;",
            i18n$t("delete_import_confirmation_message")
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "display: flex; justify-content: flex-end; gap: 10px;",
          tags$button(
            class = "btn btn-secondary",
            onclick = sprintf("$('#%s').hide();", ns("delete_import_modal")),
            i18n$t("cancel")
          ),
          actionButton(
            ns("confirm_delete_import"),
            i18n$t("delete"),
            class = "btn btn-danger",
            icon = icon("trash")
          )
        )
      )
    ),

    ### Modal - Export Alignment ----
    tags$div(
      id = ns("export_modal"),
      class = "modal-overlay",
      style = "display: none; z-index: 1050;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("export_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 750px; max-height: 95vh; overflow: visible;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("export_alignment")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("export_modal")),
            HTML("&times;")
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px; max-height: calc(95vh - 140px); overflow-y: auto;",

          # Statistics summary
          tags$div(
            class = "mb-20",
            tags$h4(style = "margin-bottom: 15px; color: #333;", i18n$t("mapping_statistics")),
            tags$div(
              id = ns("export_stats_container"),
              style = "display: flex; gap: 10px; flex-wrap: nowrap;",
              tags$div(
                style = "background: #f8f9fa; padding: 10px 15px; border-radius: 4px; text-align: center; flex: 1;",
                tags$div(id = ns("stat_total"), style = "font-size: 20px; font-weight: 600; color: #0f60af;", "0"),
                tags$div(style = "font-size: 11px; color: #666;", i18n$t("total_mappings"))
              ),
              tags$div(
                style = "background: #d4edda; padding: 10px 15px; border-radius: 4px; text-align: center; flex: 1;",
                tags$div(id = ns("stat_approved"), style = "font-size: 20px; font-weight: 600; color: #28a745;", "0"),
                tags$div(style = "font-size: 11px; color: #155724;", i18n$t("approved"))
              ),
              tags$div(
                style = "background: #f8d7da; padding: 10px 15px; border-radius: 4px; text-align: center; flex: 1;",
                tags$div(id = ns("stat_rejected"), style = "font-size: 20px; font-weight: 600; color: #dc3545;", "0"),
                tags$div(style = "font-size: 11px; color: #721c24;", i18n$t("rejected"))
              ),
              tags$div(
                style = "background: #fff3cd; padding: 10px 15px; border-radius: 4px; text-align: center; flex: 1;",
                tags$div(id = ns("stat_uncertain"), style = "font-size: 20px; font-weight: 600; color: #856404;", "0"),
                tags$div(style = "font-size: 11px; color: #856404;", i18n$t("uncertain"))
              ),
              tags$div(
                style = "background: #e2e3e5; padding: 10px 15px; border-radius: 4px; text-align: center; flex: 1;",
                tags$div(id = ns("stat_not_evaluated"), style = "font-size: 20px; font-weight: 600; color: #6c757d;", "0"),
                tags$div(style = "font-size: 11px; color: #495057;", i18n$t("not_evaluated"))
              )
            )
          ),

          tags$hr(style = "margin: 20px 0;"),

          # Export format selection
          tags$div(
            class = "mb-20",
            tags$h4(style = "margin-bottom: 10px; color: #333;", i18n$t("export_format")),
            tags$div(
              style = "display: flex; flex-direction: column; gap: 12px; padding-left: 5px;",
              tags$div(
                class = "flex-center-gap-10",
                tags$input(
                  type = "radio",
                  id = ns("export_format_stcm"),
                  name = ns("export_format"),
                  value = "source_to_concept_map",
                  checked = "checked",
                  style = "margin: 0; cursor: pointer;"
                ),
                tags$label(
                  `for` = ns("export_format_stcm"),
                  style = "margin: 0; cursor: pointer; font-weight: 500;",
                  "SOURCE_TO_CONCEPT_MAP"
                ),
                tags$span(
                  style = "color: #999; font-size: 12px;",
                  i18n$t("stcm_format_desc")
                )
              ),
              tags$div(
                class = "flex-center-gap-10",
                tags$input(
                  type = "radio",
                  id = ns("export_format_usagi"),
                  name = ns("export_format"),
                  value = "usagi",
                  style = "margin: 0; cursor: pointer;"
                ),
                tags$label(
                  `for` = ns("export_format_usagi"),
                  style = "margin: 0; cursor: pointer; font-weight: 500;",
                  "Usagi Format"
                ),
                tags$span(
                  style = "color: #999; font-size: 12px;",
                  i18n$t("usagi_format_desc")
                )
              ),
              tags$div(
                class = "flex-center-gap-10",
                tags$input(
                  type = "radio",
                  id = ns("export_format_indicate"),
                  name = ns("export_format"),
                  value = "indicate",
                  style = "margin: 0; cursor: pointer;"
                ),
                tags$label(
                  `for` = ns("export_format_indicate"),
                  style = "margin: 0; cursor: pointer; font-weight: 500;",
                  "INDICATE Data Dictionary"
                ),
                tags$span(
                  style = "color: #999; font-size: 12px;",
                  i18n$t("indicate_format_desc")
                )
              )
            )
          ),

          # Mapping inclusion criteria (hidden for INDICATE format)
          tags$div(
            id = ns("mapping_filter_section"),
            tags$hr(style = "margin: 20px 0;"),
            tags$h4(style = "margin-bottom: 15px; color: #333;", i18n$t("include_mappings_by_status")),
            tags$div(
              style = "display: flex; flex-direction: column; gap: 8px;",

              # Approved checkbox with sub-options
              tags$div(
                tags$div(
                  class = "flex-center-gap-10",
                  checkboxInput(
                    ns("export_include_approved"),
                    label = NULL,
                    value = TRUE,
                    width = "auto"
                  ),
                  tags$label(
                    `for` = ns("export_include_approved"),
                    style = "margin: 0; cursor: pointer; display: flex; align-items: center; gap: 8px;",
                    tags$span(
                      style = "background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 12px;",
                      i18n$t("approved")
                    ),
                    tags$span(
                      id = ns("export_count_approved"),
                      style = "color: #999; font-weight: 600;",
                      "[0]"
                    )
                  )
                ),
                # Sub-options for approved (shown when approved is checked)
                tags$div(
                  id = ns("approved_sub_options"),
                  style = "margin-left: 30px; margin-top: 8px; padding: 10px; background: #f8f9fa; border-radius: 4px; display: flex; flex-direction: column; gap: 8px;",
                  tags$div(
                    class = "flex-center-gap-8",
                    tags$input(
                      type = "radio",
                      id = ns("approved_filter_all"),
                      name = ns("approved_filter"),
                      value = "all",
                      checked = "checked",
                      style = "margin: 0; cursor: pointer;"
                    ),
                    tags$label(
                      `for` = ns("approved_filter_all"),
                      style = "margin: 0; cursor: pointer; color: #555; font-size: 13px;",
                      i18n$t("include_all_approved")
                    )
                  ),
                  tags$div(
                    class = "flex-center-gap-8",
                    tags$input(
                      type = "radio",
                      id = ns("approved_filter_majority"),
                      name = ns("approved_filter"),
                      value = "majority",
                      style = "margin: 0; cursor: pointer;"
                    ),
                    tags$label(
                      `for` = ns("approved_filter_majority"),
                      style = "margin: 0; cursor: pointer; color: #555; font-size: 13px;",
                      i18n$t("only_majority_approval")
                    )
                  ),
                  tags$div(
                    class = "flex-center-gap-8",
                    tags$input(
                      type = "radio",
                      id = ns("approved_filter_no_rejection"),
                      name = ns("approved_filter"),
                      value = "no_rejection",
                      style = "margin: 0; cursor: pointer;"
                    ),
                    tags$label(
                      `for` = ns("approved_filter_no_rejection"),
                      style = "margin: 0; cursor: pointer; color: #555; font-size: 13px;",
                      i18n$t("exclude_if_any_rejection")
                    )
                  )
                )
              ),

              # Rejected checkbox
              tags$div(
                class = "flex-center-gap-10",
                checkboxInput(
                  ns("export_include_rejected"),
                  label = NULL,
                  value = FALSE,
                  width = "auto"
                ),
                tags$label(
                  `for` = ns("export_include_rejected"),
                  style = "margin: 0; cursor: pointer; display: flex; align-items: center; gap: 8px;",
                  tags$span(
                    style = "background: #dc3545; color: white; padding: 2px 8px; border-radius: 4px; font-size: 12px;",
                    i18n$t("rejected")
                  ),
                  tags$span(style = "color: #666; font-size: 13px;", i18n$t("at_least_one_rejection")),
                  tags$span(
                    id = ns("export_count_rejected"),
                    style = "color: #999; font-weight: 600;",
                    "[0]"
                  )
                )
              ),

              # Uncertain checkbox
              tags$div(
                class = "flex-center-gap-10",
                checkboxInput(
                  ns("export_include_uncertain"),
                  label = NULL,
                  value = FALSE,
                  width = "auto"
                ),
                tags$label(
                  `for` = ns("export_include_uncertain"),
                  style = "margin: 0; cursor: pointer; display: flex; align-items: center; gap: 8px;",
                  tags$span(
                    style = "background: #ffc107; color: #333; padding: 2px 8px; border-radius: 4px; font-size: 12px;",
                    i18n$t("uncertain")
                  ),
                  tags$span(style = "color: #666; font-size: 13px;", i18n$t("uncertain_no_approval")),
                  tags$span(
                    id = ns("export_count_uncertain"),
                    style = "color: #999; font-weight: 600;",
                    "[0]"
                  )
                )
              ),

              # Not Evaluated checkbox
              tags$div(
                class = "flex-center-gap-10",
                checkboxInput(
                  ns("export_include_not_evaluated"),
                  label = NULL,
                  value = FALSE,
                  width = "auto"
                ),
                tags$label(
                  `for` = ns("export_include_not_evaluated"),
                  style = "margin: 0; cursor: pointer; display: flex; align-items: center; gap: 8px;",
                  tags$span(
                    style = "background: #6c757d; color: white; padding: 2px 8px; border-radius: 4px; font-size: 12px;",
                    i18n$t("not_evaluated")
                  ),
                  tags$span(style = "color: #666; font-size: 13px;", i18n$t("no_evaluation")),
                  tags$span(
                    id = ns("export_count_not_evaluated"),
                    style = "color: #999; font-weight: 600;",
                    "[0]"
                  )
                )
              )
            ),

            # Total to export
            tags$div(
              style = "margin-top: 20px; padding: 15px; background: #f8f9fa; border-radius: 4px; text-align: center;",
              tags$span(style = "font-size: 14px; color: #666;", i18n$t("total_mappings_to_export")),
              tags$span(
                id = ns("export_total_count"),
                style = "font-size: 18px; font-weight: 600; color: #0f60af; margin-left: 10px;",
                "0"
              )
            )
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "display: flex; justify-content: flex-end; gap: 10px; padding: 15px 20px; border-top: 1px solid #eee;",
          tags$button(
            class = "btn btn-secondary",
            onclick = sprintf("$('#%s').hide();", ns("export_modal")),
            i18n$t("cancel")
          ),
          actionButton(
            ns("confirm_export"),
            i18n$t("export"),
            class = "btn btn-primary-custom",
            icon = icon("download")
          )
        )
      )
    ),

    ### Modal - Import INDICATE Format ----
    tags$div(
      id = ns("import_indicate_modal"),
      class = "modal-overlay",
      style = "display: none; z-index: 1050;",
      onclick = sprintf(
        "if (event.target === this) $('#%s').hide();",
        ns("import_indicate_modal")
      ),
      tags$div(
        class = "modal-content",
        style = "max-width: 500px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("import_indicate_format")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("import_indicate_modal")),
            HTML("&times;")
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",

          # Description
          tags$p(
            style = "color: #666; margin-bottom: 20px;",
            i18n$t("import_format_indicate_desc")
          ),

          # File input
          fileInput(
            ns("import_indicate_zip_file"),
            label = i18n$t("select_zip_file"),
            accept = ".zip",
            width = "100%"
          ),

          # Alignment name input (populated from metadata after file selection)
          tags$div(
            id = ns("import_indicate_name_container"),
            style = "display: none; margin-top: 15px;",
            textInput(
              ns("import_indicate_name"),
              label = i18n$t("alignment_name"),
              value = "",
              width = "100%"
            ),
            tags$div(
              id = ns("import_indicate_name_error"),
              class = "input-error-message",
              style = "display: none;",
              i18n$t("alignment_name_exists")
            )
          ),

          # Validation status
          tags$div(
            id = ns("import_indicate_validation_status"),
            style = "margin-top: 10px; display: none;"
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "display: flex; justify-content: flex-end; gap: 10px; padding: 15px 20px; border-top: 1px solid #eee;",
          tags$button(
            class = "btn btn-secondary",
            onclick = sprintf("$('#%s').hide();", ns("import_indicate_modal")),
            i18n$t("cancel")
          ),
          actionButton(
            ns("confirm_import_indicate"),
            i18n$t("import_mappings"),
            class = "btn btn-primary-custom",
            icon = icon("file-import")
          )
        )
      )
    ),

    ### Modal - Source JSON Fullscreen (Edit Mappings) ----
    tags$div(
      id = ns("source_json_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        tags$div(
          style = paste0(
            "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; ",
            "display: flex; justify-content: space-between; align-items: center; ",
            "box-shadow: 0 2px 4px rgba(0,0,0,0.1);"
          ),
          tags$h3(
            class = "text-primary", style = "margin: 0;",
            "Source Concept - JSON Structure"
          ),
          actionButton(
            ns("close_source_json_fullscreen"),
            label = HTML("&times;"),
            class = "modal-close",
            style = paste0(
              "font-size: 28px; font-weight: 300; color: #666; border: none; ",
              "background: none; cursor: pointer; padding: 0; width: 30px; ",
              "height: 30px; line-height: 1;"
            )
          )
        ),
        tags$div(
          style = "flex: 1; overflow: hidden; display: flex; gap: 0;",
          # Left column: Raw JSON
          tags$div(
            style = paste0(
              "flex: 1; overflow: auto; padding: 20px; background: #fff; ",
              "border-right: 1px solid #ddd;"
            ),
            tags$h4(
              style = "margin: 0 0 15px 0; color: #0f60af; font-size: 14px;",
              "Raw JSON"
            ),
            uiOutput(ns("source_json_fullscreen_content"))
          ),
          # Right column: Tutorial
          tags$div(
            style = "flex: 1; overflow: auto; padding: 20px; background: #f8f9fa;",
            uiOutput(ns("source_json_tutorial"))
          )
        )
      )
    ),

    ### Modal - Eval Source JSON Fullscreen (Evaluate Mappings) ----
    tags$div(
      id = ns("eval_source_json_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        tags$div(
          style = paste0(
            "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; ",
            "display: flex; justify-content: space-between; align-items: center; ",
            "box-shadow: 0 2px 4px rgba(0,0,0,0.1);"
          ),
          tags$h3(
            class = "text-primary", style = "margin: 0;",
            "Source Concept - JSON Structure"
          ),
          actionButton(
            ns("close_eval_source_json_fullscreen"),
            label = HTML("&times;"),
            class = "modal-close",
            style = paste0(
              "font-size: 28px; font-weight: 300; color: #666; border: none; ",
              "background: none; cursor: pointer; padding: 0; width: 30px; ",
              "height: 30px; line-height: 1;"
            )
          )
        ),
        tags$div(
          style = "flex: 1; overflow: hidden; display: flex; gap: 0;",
          # Left column: Raw JSON
          tags$div(
            style = paste0(
              "flex: 1; overflow: auto; padding: 20px; background: #fff; ",
              "border-right: 1px solid #ddd;"
            ),
            tags$h4(
              style = "margin: 0 0 15px 0; color: #0f60af; font-size: 14px;",
              "Raw JSON"
            ),
            uiOutput(ns("eval_source_json_fullscreen_content"))
          ),
          # Right column: Tutorial
          tags$div(
            style = "flex: 1; overflow: auto; padding: 20px; background: #f8f9fa;",
            uiOutput(ns("eval_source_json_tutorial"))
          )
        )
      )
    ),

    ### Modal - Category Breakdown Fullscreen ----
    tags$div(
      id = ns("category_breakdown_fullscreen_modal"),
      class = "modal-overlay modal-fullscreen",
      style = "display: none;",
      tags$div(
        class = "modal-fullscreen-content",
        style = "height: 100vh; display: flex; flex-direction: column;",
        tags$div(
          style = "padding: 15px 20px; background: white; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
          tags$h3(
            class = "text-primary", style = "margin: 0;",
            i18n$t("category_breakdown")
          ),
          actionButton(
            ns("close_category_breakdown_fullscreen"),
            label = HTML("&times;"),
            class = "modal-fullscreen-close"
          )
        ),
        tags$div(
          style = "flex: 1; overflow: auto; padding: 20px;",
          uiOutput(ns("category_breakdown_fullscreen_content"))
        )
      )
    ),

    ### Modal - Limit 10K Confirmation ----
    limit_10k_modal_ui(
      modal_id = "limit_10k_confirmation_modal",
      checkbox_id = "concept_mappings_limit_10k",
      confirm_btn_id = "confirm_disable_limit_10k",
      ns = ns,
      i18n = i18n
    ),

    ### Modal - OMOP Advanced Filters ----
    tags$div(
      id = ns("omop_filters_modal"),
      class = "modal-overlay",
      style = "display: none;",
      onclick = sprintf("if (event.target === this) $('#%s').hide();", ns("omop_filters_modal")),
      tags$div(
        class = "modal-content",
        style = "max-width: 380px;",
        tags$div(
          class = "modal-header",
          tags$h3(i18n$t("advanced_filters")),
          tags$button(
            class = "modal-close",
            onclick = sprintf("$('#%s').hide();", ns("omop_filters_modal")),
            HTML("&times;")
          )
        ),
        tags$div(
          class = "modal-body",
          style = "padding: 20px;",
          # Filter fields
          tags$div(
            class = "mb-15",
            tags$label(class = "form-label", "Vocabulary ID"),
            selectizeInput(
              ns("omop_filter_vocabulary_id"),
              label = NULL,
              choices = NULL,
              multiple = TRUE,
              options = list(placeholder = i18n$t("select_or_type"))
            )
          ),
          tags$div(
            class = "mb-15",
            tags$label(class = "form-label", "Domain ID"),
            selectizeInput(
              ns("omop_filter_domain_id"),
              label = NULL,
              choices = NULL,
              multiple = TRUE,
              options = list(placeholder = i18n$t("select_or_type"))
            )
          ),
          tags$div(
            class = "mb-15",
            tags$label(class = "form-label", "Concept Class ID"),
            selectizeInput(
              ns("omop_filter_concept_class_id"),
              label = NULL,
              choices = NULL,
              multiple = TRUE,
              options = list(placeholder = i18n$t("select_or_type"))
            )
          ),
          tags$div(
            class = "mb-15",
            tags$label(class = "form-label", "Standard Concept"),
            selectizeInput(
              ns("omop_filter_standard_concept"),
              label = NULL,
              choices = NULL,
              multiple = TRUE,
              options = list(placeholder = i18n$t("select_or_type"))
            )
          ),
          tags$div(
            class = "mb-15",
            tags$label(class = "form-label", "Validity"),
            selectizeInput(
              ns("omop_filter_validity"),
              label = NULL,
              choices = NULL,
              multiple = TRUE,
              options = list(placeholder = i18n$t("select_or_type"))
            )
          )
        ),
        tags$div(
          class = "modal-footer",
          style = "display: flex; justify-content: space-between; gap: 10px;",
          actionButton(
            ns("clear_omop_filters"),
            i18n$t("clear_all"),
            class = "btn btn-secondary",
            icon = icon("times")
          ),
          tags$div(
            style = "display: flex; gap: 10px;",
            tags$button(
              class = "btn btn-secondary",
              onclick = sprintf("$('#%s').hide();", ns("omop_filters_modal")),
              i18n$t("cancel")
            ),
            actionButton(
              ns("apply_omop_filters"),
              i18n$t("apply_filters"),
              class = "btn btn-primary-custom",
              icon = icon("check")
            )
          )
        )
      )
    )

  )
}

# SERVER SECTION ====

#' Concept Mapping Module - Server
#'
#' @description Server function for the concept mapping module
#'
#' @param id Module ID
#' @param data Reactive list containing application data
#' @param config Reactive list containing configuration
#' @param vocabularies Reactive containing OHDSI vocabularies
#' @param current_user Reactive containing current user information
#' @param log_level Character vector specifying logging level
#'
#' @return Server logic
#' @noRd
#'
#' @importFrom shiny moduleServer reactive observe observeEvent req
#' @importFrom DT renderDT datatable formatStyle
mod_concept_mapping_server <- function(id, data, config, vocabularies, current_user = reactive(NULL), i18n = NULL, log_level = character()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Helper function to check if current user has a specific permission
    user_has_permission <- function(category, permission) {
      user_has_permission_for(current_user, category, permission)
    }

    ## 1) Server - Reactive Values & State ----
    ### View & Selection State ----
    # Track current view and navigation state
    current_view <- reactiveVal("alignments")  # "alignments" or "mapping"
    selected_alignment_id <- reactiveVal(NULL)  # Track selected alignment for mapping
    mapping_view <- reactiveVal("general")  # "general" or "mapped" - for nested navigation
    selected_general_concept_id <- reactiveVal(NULL)  # Track selected general concept
    modal_page <- reactiveVal(1)  # Track modal page (1 or 2)
    modal_mode <- reactiveVal("add")  # "add" or "edit"
    alignment_to_delete <- reactiveVal(NULL)  # Track alignment ID to delete
    concept_mappings_view <- reactiveVal("table")  # "table" or "comments" - for right panel when general concept is selected
    file_preview_data <- reactiveVal(NULL)  # Store file preview data
    show_all_omop_concepts <- reactiveVal(FALSE)  # Track whether to show all OMOP concepts instead of filtered by general concept

    ### Edit Mode State ----
    # No edit mode currently implemented for this module

    ### Data Management ----
    # Load existing alignments from database
    initial_alignments <- get_all_alignments()

    # Store alignments data
    alignments_data <- reactiveVal(initial_alignments)

    # Store uploaded file data for current alignment
    uploaded_alignment_data <- reactiveVal(NULL)

    ### Cascade Triggers ----
    # Trigger to force refresh of completed mappings table
    mappings_refresh_trigger <- reactiveVal(0)

    # Track active mapping tab
    mapping_tab <- reactiveVal("summary")  # "summary", "edit_mappings", or "evaluate_mappings"

    # Evaluate mappings state
    # Note: Table state (page, search, length) is now managed by stateSave option in DataTables
    selected_eval_mapping_id <- reactiveVal(NULL)  # Track selected evaluation mapping for row selection
    eval_selected_row_data <- reactiveVal(NULL)  # Full row data for selected evaluation mapping
    eval_source_json <- reactiveVal(NULL)  # Source concept JSON data for evaluate mappings
    eval_source_row <- reactiveVal(NULL)  # Source concept row data for evaluate mappings
    eval_target_concept_id <- reactiveVal(NULL)  # Target general concept ID for evaluate mappings
    eval_target_json <- reactiveVal(NULL)  # Target concept JSON data for evaluate mappings
    eval_target_mapping <- reactiveVal(NULL)  # Target mapping data for evaluate mappings
    eval_source_tab <- reactiveVal("summary")  # Selected tab for source concept details
    eval_target_detail_tab <- reactiveVal("summary")  # Main tab: "summary", "comments" or "statistical_summary"
    eval_target_stats_sub_tab <- reactiveVal("summary")  # Sub-tab: "summary" or "distribution"
    eval_target_selected_profile <- reactiveVal(NULL)  # Selected profile name for evaluate target

    # Cascade triggers for selected_alignment_id() changes
    selected_alignment_id_trigger <- reactiveVal(0)  # Primary trigger when alignment selection changes
    all_mappings_table_trigger <- reactiveVal(0)  # Trigger for Summary tab table
    source_concepts_table_mapped_trigger <- reactiveVal(0)  # Trigger for Mapped view table
    source_concepts_table_general_trigger <- reactiveVal(0)  # Trigger for General view Edit Mappings table (alignment changes only)
    evaluate_mappings_table_trigger <- reactiveVal(0)  # Trigger for Evaluate Mappings tab table
    import_history_trigger <- reactiveVal(0)  # Trigger for Import Mappings history table

    # Import file state
    import_selected_file <- reactiveVal(NULL)
    import_selected_filename <- reactiveVal(NULL)  # Original filename from upload
    import_validation_result <- reactiveVal(NULL)  # Stores validation result for selected file

    # Import column mapping state
    import_csv_data <- reactiveVal(NULL)  # Stores the CSV data after file selection
    import_csv_columns <- reactiveVal(NULL)  # Column names from CSV
    import_source_code_col <- reactiveVal(NULL)  # Selected column for source_code
    import_source_vocab_col <- reactiveVal(NULL)  # Selected column for source_vocabulary_id (optional)
    import_target_concept_col <- reactiveVal(NULL)  # Selected column for target_concept_id

    # Mapping comments state
    comments_mapping_id <- reactiveVal(NULL)  # Track mapping ID for comments modal
    comments_trigger <- reactiveVal(0)  # Trigger to refresh comments display
    comment_to_delete <- reactiveVal(NULL)  # Track comment ID to delete
    import_to_delete <- reactiveVal(NULL)  # Track import ID to delete

    # Export modal state
    export_alignment_id <- reactiveVal(NULL)  # Track alignment ID for export modal

    # All mappings table state
    all_mappings_display_data <- reactiveVal(NULL)  # Store display data for selection handling
    mappings_to_delete <- reactiveVal(NULL)  # Track mapping IDs to delete (for confirmation modal)
    export_stats <- reactiveVal(NULL)  # Store export statistics

    # Separate trigger for source concepts table updates (used by mapping operations)
    source_concepts_table_trigger <- reactiveVal(0)  # Trigger for Edit Mappings table (mapping changes)
    source_concepts_data <- reactiveVal(NULL)  # Store source concepts data for proxy updates
    source_concepts_colnames <- reactiveVal(NULL)  # Store column names
    source_concepts_column_defs <- reactiveVal(NULL)  # Store column definitions
    # Fuzzy search for source concepts table
    source_concepts_fuzzy <- fuzzy_search_server(
      "source_concepts_fuzzy_search",
      input,
      session,
      trigger_rv = source_concepts_table_general_trigger,
      ns = ns
    )

    # Cascade triggers for selected_general_concept_id() changes
    selected_general_concept_id_trigger <- reactiveVal(0)  # Primary trigger when general concept selection changes
    mapped_concepts_table_trigger <- reactiveVal(0)  # Trigger for Mapped view table
    concept_mappings_table_trigger <- reactiveVal(0)  # Trigger for Edit Mappings concept mappings table

    # Fuzzy search for concept mappings table (must be after trigger definition)
    concept_mappings_fuzzy <- fuzzy_search_server(
      "concept_mappings_fuzzy_search",
      input,
      session,
      trigger_rv = concept_mappings_table_trigger,
      ns = ns
    )

    # Observer for limit 10K checkbox - show confirmation modal when unchecking
    observe_event(input$concept_mappings_limit_10k, {
      # If unchecking (going from TRUE to FALSE), show confirmation modal
      if (isFALSE(input$concept_mappings_limit_10k) && show_all_omop_concepts()) {
        # Show confirmation modal
        shinyjs::runjs(sprintf("$('#%s').show();", ns("limit_10k_confirmation_modal")))
        # Re-check the checkbox (will be unchecked by confirm button)
        shinyjs::runjs(sprintf("$('#%s').prop('checked', true);", ns("concept_mappings_limit_10k")))
      }
    }, ignoreInit = TRUE)

    # Confirm disable limit 10K
    observe_event(input$confirm_disable_limit_10k, {
      # Hide modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("limit_10k_confirmation_modal")))
      # Actually uncheck the checkbox and trigger update
      shinyjs::runjs(sprintf("$('#%s').prop('checked', false);", ns("concept_mappings_limit_10k")))
      shinyjs::runjs(sprintf("Shiny.setInputValue('%s', false, {priority: 'event'});", ns("concept_mappings_limit_10k_confirmed")))
    }, ignoreInit = TRUE)

    # Handle confirmed limit 10K disable
    observe_event(input$concept_mappings_limit_10k_confirmed, {
      if (show_all_omop_concepts()) {
        concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
      }
    }, ignoreInit = TRUE)

    ### OMOP Advanced Filters State ----
    # Track whether filters have been loaded
    omop_filters_loaded <- reactiveVal(FALSE)
    # Track active filters
    omop_active_filters <- reactiveVal(list(
      vocabulary_id = NULL,
      domain_id = NULL,
      concept_class_id = NULL,
      standard_concept = NULL,
      validity = NULL
    ))

    # Show/hide settings button and limit checkbox when entering/leaving show_all_omop_concepts mode
    observe_event(show_all_omop_concepts(), {
      if (show_all_omop_concepts()) {
        shinyjs::runjs(sprintf("$('#%s').css('display', 'flex');", ns("omop_filters_btn")))
        shinyjs::runjs(sprintf("$('#%s').closest('.fuzzy-search-limit-checkbox').css('display', 'flex');", ns("concept_mappings_limit_10k")))
      } else {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("omop_filters_btn")))
        shinyjs::runjs(sprintf("$('#%s').closest('.fuzzy-search-limit-checkbox').hide();", ns("concept_mappings_limit_10k")))
      }
    }, ignoreInit = FALSE)

    # Open filters modal when settings button is clicked
    observe_event(input$omop_filters_btn, {
      # Load filter values if not already loaded
      if (!omop_filters_loaded()) {
        vocabs <- vocabularies()
        if (!is.null(vocabs) && !is.null(vocabs$concept)) {
          # Get distinct values for each filter field
          concept_tbl <- vocabs$concept

          # Vocabulary IDs
          vocab_ids <- concept_tbl %>%
            dplyr::distinct(vocabulary_id) %>%
            dplyr::arrange(vocabulary_id) %>%
            dplyr::collect() %>%
            dplyr::pull(vocabulary_id)

          # Domain IDs
          domain_ids <- concept_tbl %>%
            dplyr::distinct(domain_id) %>%
            dplyr::arrange(domain_id) %>%
            dplyr::collect() %>%
            dplyr::pull(domain_id)

          # Concept Class IDs
          concept_class_ids <- concept_tbl %>%
            dplyr::distinct(concept_class_id) %>%
            dplyr::arrange(concept_class_id) %>%
            dplyr::collect() %>%
            dplyr::pull(concept_class_id)

          # Standard Concept choices with readable names
          # S = Standard, C = Classification, NS = Non-standard (NULL/empty in DB)
          standard_choices <- c(
            "Standard" = "S",
            "Classification" = "C",
            "Non-standard" = "NS"
          )

          # Validity (invalid_reason: NULL = Valid, non-NULL = Invalid)
          validity_choices <- c("Valid", "Invalid")

          # Update selectize inputs
          updateSelectizeInput(session, "omop_filter_vocabulary_id", choices = vocab_ids, server = TRUE)
          updateSelectizeInput(session, "omop_filter_domain_id", choices = domain_ids, server = TRUE)
          updateSelectizeInput(session, "omop_filter_concept_class_id", choices = concept_class_ids, server = TRUE)
          updateSelectizeInput(session, "omop_filter_standard_concept", choices = standard_choices, server = FALSE)
          updateSelectizeInput(session, "omop_filter_validity", choices = validity_choices, server = FALSE)

          omop_filters_loaded(TRUE)
        }
      }

      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("omop_filters_modal")))
    }, ignoreInit = TRUE)

    # Apply filters
    observe_event(input$apply_omop_filters, {
      # Store active filters
      omop_active_filters(list(
        vocabulary_id = input$omop_filter_vocabulary_id,
        domain_id = input$omop_filter_domain_id,
        concept_class_id = input$omop_filter_concept_class_id,
        standard_concept = input$omop_filter_standard_concept,
        validity = input$omop_filter_validity
      ))

      # Update settings button appearance (active if any filter is set)
      filters <- omop_active_filters()
      has_active_filters <- any(sapply(filters, function(f) length(f) > 0))
      if (has_active_filters) {
        shinyjs::runjs(sprintf("$('#%s').addClass('active');", ns("omop_filters_btn")))
      } else {
        shinyjs::runjs(sprintf("$('#%s').removeClass('active');", ns("omop_filters_btn")))
      }

      # Hide modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("omop_filters_modal")))

      # Trigger table refresh
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
    }, ignoreInit = TRUE)

    # Clear all filters
    observe_event(input$clear_omop_filters, {
      # Reset all selectize inputs
      updateSelectizeInput(session, "omop_filter_vocabulary_id", selected = character(0))
      updateSelectizeInput(session, "omop_filter_domain_id", selected = character(0))
      updateSelectizeInput(session, "omop_filter_concept_class_id", selected = character(0))
      updateSelectizeInput(session, "omop_filter_standard_concept", selected = character(0))
      updateSelectizeInput(session, "omop_filter_validity", selected = character(0))

      # Clear active filters
      omop_active_filters(list(
        vocabulary_id = NULL,
        domain_id = NULL,
        concept_class_id = NULL,
        standard_concept = NULL,
        validity = NULL
      ))

      # Remove active class from settings button
      shinyjs::runjs(sprintf("$('#%s').removeClass('active');", ns("omop_filters_btn")))

      # Re-enable limit 10K checkbox and trigger change event to update Shiny input
      shinyjs::runjs(sprintf("
        var checkbox = $('#%s');
        checkbox.prop('checked', true);
        Shiny.setInputValue('%s', true, {priority: 'event'});
      ", ns("concept_mappings_limit_10k"), ns("concept_mappings_limit_10k")))

      # Hide modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("omop_filters_modal")))

      # Trigger table refresh after a small delay to ensure checkbox state is updated
      shinyjs::runjs(sprintf("setTimeout(function() { Shiny.setInputValue('%s', Math.random(), {priority: 'event'}); }, 50);", ns("clear_filters_refresh")))
    }, ignoreInit = TRUE)

    # Handle clear filters refresh - this ensures limit 10K is properly applied
    observe_event(input$clear_filters_refresh, {
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
    }, ignoreInit = TRUE)

    general_concepts_table_trigger <- reactiveVal(0)  # Trigger for General Concepts table in Edit Mappings
    general_concepts_fuzzy_query <- reactiveVal("")  # Fuzzy search query for General Concepts table
    edit_mappings_initialized <- reactiveVal(FALSE)  # Track if Edit Mappings tables have been initialized

    # Cascade triggers for summary_trigger() changes
    summary_content_trigger <- reactiveVal(0)  # Trigger for summary content rendering
    projects_compatibility_table_trigger <- reactiveVal(0)  # Trigger for projects compatibility table

    ## 2) Server - Navigation & Events ----
    ### Trigger Updates ----
    # Summary tab reactive trigger
    summary_trigger <- reactiveVal(0)

    observe_event(c(selected_alignment_id(), data(), mappings_refresh_trigger()), {
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()
      summary_trigger(summary_trigger() + 1)
    }, ignoreInit = TRUE)

    ### Cascade Observer for summary_trigger() ----
    # Cascade observer: Fires all summary-specific triggers
    observe_event(summary_trigger(), {
      summary_content_trigger(summary_content_trigger() + 1)
      projects_compatibility_table_trigger(projects_compatibility_table_trigger() + 1)
    }, ignoreInit = TRUE)

    ### Cascade Observers for selected_alignment_id() ----
    # Primary observer: Fires main trigger when alignment selection changes
    observe_event(selected_alignment_id(), {
      # Reset tab to summary when changing alignments
      mapping_tab("summary")
      # Reset edit mappings initialized flag so tables re-render on next tab switch
      edit_mappings_initialized(FALSE)
      selected_alignment_id_trigger(selected_alignment_id_trigger() + 1)
    }, ignoreInit = TRUE)

    # Cascade observer: Fires all table-specific triggers
    observe_event(selected_alignment_id_trigger(), {
      all_mappings_table_trigger(all_mappings_table_trigger() + 1)
      source_concepts_table_mapped_trigger(source_concepts_table_mapped_trigger() + 1)
      source_concepts_table_general_trigger(source_concepts_table_general_trigger() + 1)
      general_concepts_table_trigger(general_concepts_table_trigger() + 1)
      evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)
      # Reset fuzzy search when changing alignment
      source_concepts_fuzzy$clear()
      general_concepts_fuzzy_query("")
      shinyjs::runjs(sprintf("$('#%s').val('');", ns("general_concepts_fuzzy_search")))
    }, ignoreInit = TRUE)

    # Observer for General Concepts fuzzy search query
    observe_event(input$general_concepts_fuzzy_search_query, {
      general_concepts_fuzzy_query(input$general_concepts_fuzzy_search_query)
      general_concepts_table_trigger(general_concepts_table_trigger() + 1)
    }, ignoreNULL = FALSE, ignoreInit = TRUE)

    ### Cascade Observers for selected_general_concept_id() ----
    # Primary observer: Fires main trigger when general concept selection changes
    observe_event(selected_general_concept_id(), {
      selected_general_concept_id_trigger(selected_general_concept_id_trigger() + 1)
    }, ignoreInit = TRUE)

    # Cascade observer: Fires all table-specific triggers
    observe_event(selected_general_concept_id_trigger(), {
      mapped_concepts_table_trigger(mapped_concepts_table_trigger() + 1)
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
      # Reset fuzzy search when changing general concept
      concept_mappings_fuzzy$clear()
    }, ignoreInit = TRUE)

    ### Helper Functions ----
    # Display import status message in the validation banner
    show_import_status <- function(message, type = "success", warning_message = NULL) {
      if (type == "success") {
        bg_color <- "#d4edda"
        text_color <- "#155724"
        icon <- "fa-check-circle"
      } else if (type == "warning") {
        bg_color <- "#fff3cd"
        text_color <- "#856404"
        icon <- "fa-exclamation-triangle"
      } else {
        bg_color <- "#f8d7da"
        text_color <- "#721c24"
        icon <- "fa-exclamation-circle"
      }

      # Build HTML content
      html_content <- sprintf(
        '<div style="display: inline-block; background-color: %s; color: %s; padding: 10px; border-radius: 4px;">
          <i class="fas %s"></i> %s
        </div>',
        bg_color, text_color, icon, message
      )

      # Add warning message if provided (on new line)
      if (!is.null(warning_message) && nchar(warning_message) > 0) {
        html_content <- paste0(
          html_content,
          sprintf(
            '<br><div style="display: inline-block; background-color: #fff3cd; color: #856404; padding: 10px; border-radius: 4px; margin-top: 8px;">
              <i class="fas fa-exclamation-triangle"></i> %s
            </div>',
            warning_message
          )
        )
      }

      shinyjs::html("import_validation_status", html_content)
      shinyjs::show("import_validation_status")
    }

    ### Breadcrumb Rendering ----
    output$breadcrumb <- renderUI({
      if (current_view() == "alignments") {
        NULL
      } else if (current_view() == "mapping") {
        if (is.null(selected_alignment_id())) return()
        alignment_name <- alignments_data() %>%
          dplyr::filter(alignment_id == selected_alignment_id()) %>%
          dplyr::pull(name)

        current_tab <- mapping_tab()

        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 12px; display: flex; align-items: center; justify-content: space-between;",
          # Left side: breadcrumb path
          tags$div(
            class = "flex-center-gap-10",
            tags$a(
              class = "breadcrumb-link",
              onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_alignments")),
              "Concept Mappings"
            ),
            tags$span(style = "color: #6c757d; font-size: 16px;", ">"),
            if (mapping_view() == "general") {
              tags$span(
                class = "section-title",
                style = "color: #333;",
                alignment_name
              )
            } else {
              tagList(
                tags$a(
                  class = "breadcrumb-link",
                  onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_general")),
                  alignment_name
                ),
                tags$span(style = "color: #6c757d; font-size: 16px; margin: 0 10px;", ">"),
                tags$span(
                  class = "section-title",
                  i18n$t("mapped_concepts")
                )
              )
            }
          ),
          # Right side: tabs navigation
          tags$div(
            style = "display: flex; gap: 5px;",
            tags$button(
              class = paste("tab-btn", if (current_tab == "summary") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'summary', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("summary")
            ),
            tags$button(
              class = paste("tab-btn", if (current_tab == "all_mappings") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'all_mappings', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("all_mappings")
            ),
            tags$button(
              class = paste("tab-btn", if (current_tab == "import_mappings") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'import_mappings', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("import_mappings")
            ),
            tags$button(
              class = paste("tab-btn", if (current_tab == "edit_mappings") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'edit_mappings', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("edit_mappings")
            ),
            tags$button(
              class = paste("tab-btn", if (current_tab == "evaluate_mappings") "tab-btn-active" else ""),
              onclick = sprintf("Shiny.setInputValue('%s', 'evaluate_mappings', {priority: 'event'})", ns("mapping_tab_click")),
              i18n$t("evaluate_mappings")
            )
          )
        )
      }
    })

    # Handle tab clicks from breadcrumb
    observe_event(input$mapping_tab_click, {
      mapping_tab(input$mapping_tab_click)
    })

    ### Content Area Rendering ----
    output$content_area <- renderUI({
      if (current_view() == "alignments") {
        render_alignments_view()
      } else if (current_view() == "mapping") {
        if (mapping_view() == "general") {
          render_mapping_view()
        } else {
          render_mapped_concepts_view()
        }
      }
    })

    ### Tab Switching ----
    # Show/hide panels based on selected tab
    observe_event(mapping_tab(), {
      tab <- mapping_tab()

      # Hide all panels first
      shinyjs::hide("panel_summary")
      shinyjs::hide("panel_all_mappings")
      shinyjs::hide("panel_edit_mappings")
      shinyjs::hide("panel_import_mappings")
      shinyjs::hide("panel_evaluate_mappings")

      # Reset evaluate mappings selection state when leaving the tab
      shinyjs::hide("eval_details_container")
      eval_selected_row_data(NULL)
      eval_source_json(NULL)
      eval_source_row(NULL)
      eval_target_concept_id(NULL)
      eval_target_json(NULL)
      eval_target_mapping(NULL)

      # Show the selected panel
      if (tab == "summary") {
        shinyjs::show("panel_summary")
      } else if (tab == "all_mappings") {
        shinyjs::show("panel_all_mappings")
        shinyjs::runjs(sprintf("$('#%s').css('display', 'flex');", ns("panel_all_mappings")))
      } else if (tab == "edit_mappings") {
        shinyjs::show("panel_edit_mappings")
        # Only trigger table rendering if not already initialized for this alignment
        if (!edit_mappings_initialized()) {
          source_concepts_table_general_trigger(source_concepts_table_general_trigger() + 1)
          general_concepts_table_trigger(general_concepts_table_trigger() + 1)
          edit_mappings_initialized(TRUE)
        }
      } else if (tab == "import_mappings") {
        shinyjs::show("panel_import_mappings")
        # Trigger import history table rendering
        import_history_trigger(import_history_trigger() + 1)
      } else if (tab == "evaluate_mappings") {
        shinyjs::show("panel_evaluate_mappings")
        shinyjs::runjs(sprintf("$('#%s').css('display', 'flex');", ns("panel_evaluate_mappings")))
      }
    }, ignoreNULL = FALSE)

    ### Navigation Handlers ----
    observe_event(input$back_to_alignments, {
      current_view("alignments")
      selected_alignment_id(NULL)
      mapping_view("general")
      selected_general_concept_id(NULL)
    })

    observe_event(input$back_to_general, {
      mapping_view("general")
      selected_general_concept_id(NULL)
    })

    observe_event(input$back_to_general_list, {
      selected_general_concept_id(NULL)
      show_all_omop_concepts(FALSE)
      concept_mappings_view("table")

      shinyjs::show("general_concepts_table_container")
      shinyjs::hide("concept_mappings_table_container")
      shinyjs::hide("target_concept_details_panel")

      # Hide the limit checkbox when leaving "Show All OMOP Concepts" mode
      shinyjs::runjs(sprintf(
        "$('#%s').closest('.fuzzy-search-limit-checkbox').hide();",
        ns("concept_mappings_limit_10k")
      ))

      # Clear target concept selection state
      selected_target_concept_id(NULL)
      selected_target_json(NULL)
      selected_target_mapping(NULL)
    })

    observe_event(input$show_all_omop_click, {
      show_all_omop_concepts(TRUE)
      selected_general_concept_id(NULL)

      shinyjs::hide("general_concepts_table_container")
      shinyjs::show("concept_mappings_table_container")

      # Show the limit checkbox when in "Show All OMOP Concepts" mode
      shinyjs::runjs(sprintf(
        "$('#%s').closest('.fuzzy-search-limit-checkbox').show();",
        ns("concept_mappings_limit_10k")
      ))

      # Trigger table refresh to show all concepts
      concept_mappings_table_trigger(concept_mappings_table_trigger() + 1)
    })

    observe_event(input$view_mapped_concepts, {
      general_concept_id <- input$view_mapped_concepts
      selected_general_concept_id(general_concept_id)

      shinyjs::hide("general_concepts_table_container")
      shinyjs::show("concept_mappings_table_container")

      shinyjs::hide("add_mapping_from_general")
    })

    observe_event(input$open_alignment, {
      selected_alignment_id(input$open_alignment)
      current_view("mapping")
      mapping_view("general")
    })

    ## 3) Server - Alignments List View ----
    ### Alignments Table Rendering ----
    output$alignments_table <- DT::renderDT({
      alignments <- alignments_data()

      if (nrow(alignments) == 0) {
        return(create_empty_datatable(i18n$t("no_alignments_yet")))
      }

      # Get database connection for statistics
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      # Calculate statistics for each alignment
      stats_list <- lapply(alignments$alignment_id, function(aid) {
        # Get CSV path for this alignment
        csv_path <- file.path(db_dir, paste0("alignment_", aid, ".csv"))
        total_source_concepts <- 0
        if (file.exists(csv_path)) {
          df <- read.csv(csv_path, stringsAsFactors = FALSE)
          total_source_concepts <- nrow(df)
        }

        if (!file.exists(db_path)) {
          return(list(
            mapped_concepts = "0 / 0",
            general_concepts_mapped = "0",
            evaluated_mappings = "0 / 0"
          ))
        }

        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        # Count unique source concepts that have mappings
        mappings_result <- DBI::dbGetQuery(
          con,
          "SELECT COUNT(DISTINCT row_id) as mapped_count FROM concept_mappings WHERE alignment_id = ?",
          params = list(aid)
        )
        mapped_source_concepts <- mappings_result$mapped_count[1]

        # Count distinct general concepts mapped
        all_mappings <- DBI::dbGetQuery(
          con,
          "SELECT DISTINCT target_general_concept_id, target_omop_concept_id FROM concept_mappings WHERE alignment_id = ?",
          params = list(aid)
        )

        direct_general_ids <- all_mappings$target_general_concept_id[!is.na(all_mappings$target_general_concept_id)]
        imported_omop_ids <- all_mappings$target_omop_concept_id[
          is.na(all_mappings$target_general_concept_id) & !is.na(all_mappings$target_omop_concept_id)
        ]

        # Lookup general concepts from dictionary for imported OMOP concept IDs
        dictionary_mappings <- data()$concept_mappings
        if (!is.null(dictionary_mappings) && length(imported_omop_ids) > 0) {
          lookup_general_ids <- dictionary_mappings$general_concept_id[
            dictionary_mappings$omop_concept_id %in% imported_omop_ids
          ]
          lookup_general_ids <- unique(lookup_general_ids[!is.na(lookup_general_ids)])
        } else {
          lookup_general_ids <- integer(0)
        }

        mapped_general_concept_ids <- unique(c(direct_general_ids, lookup_general_ids))
        total_general_concepts <- length(mapped_general_concept_ids)

        # Count evaluated mappings (mappings with at least one evaluation)
        evaluated_result <- DBI::dbGetQuery(
          con,
          "SELECT COUNT(DISTINCT cm.mapping_id) as evaluated_count
           FROM concept_mappings cm
           INNER JOIN mapping_evaluations me ON cm.mapping_id = me.mapping_id
           WHERE cm.alignment_id = ?",
          params = list(aid)
        )
        evaluated_count <- evaluated_result$evaluated_count[1]

        # Total mappings for this alignment
        total_mappings_result <- DBI::dbGetQuery(
          con,
          "SELECT COUNT(*) as total FROM concept_mappings WHERE alignment_id = ?",
          params = list(aid)
        )
        total_mappings <- total_mappings_result$total[1]

        list(
          mapped_concepts = as.character(mapped_source_concepts),
          general_concepts_mapped = as.character(total_general_concepts),
          evaluated_mappings = as.character(evaluated_count)
        )
      })

      # Convert to data frame columns
      alignments_display <- alignments %>%
        dplyr::mutate(
          created_formatted = format(as.POSIXct(created_date), "%Y-%m-%d %H:%M"),
          mapped_concepts = sapply(stats_list, function(x) x$mapped_concepts),
          general_concepts_mapped = sapply(stats_list, function(x) x$general_concepts_mapped),
          evaluated_mappings = sapply(stats_list, function(x) x$evaluated_mappings)
        ) %>%
        dplyr::select(alignment_id, name, description, mapped_concepts, general_concepts_mapped, evaluated_mappings, created_formatted)

      # Check permissions for action buttons
      can_edit <- user_has_permission("alignments", "edit_alignment")
      can_export <- user_has_permission("alignments", "export_mappings")
      can_delete <- user_has_permission("alignments", "delete_alignment")

      # Add action buttons (generate for each row based on permissions)
      alignments_display$Actions <- sapply(alignments_display$alignment_id, function(id) {
        actions <- list(
          list(
            label = "Open",
            icon = "folder-open",
            type = "primary",
            onclick = sprintf("Shiny.setInputValue('%s', %d, {priority: 'event'})", ns("open_alignment"), id)
          )
        )

        if (can_edit) {
          actions <- c(actions, list(list(
            label = "Edit",
            icon = "edit",
            type = "warning",
            onclick = sprintf("Shiny.setInputValue('%s', %d, {priority: 'event'})", ns("edit_alignment"), id)
          )))
        }

        if (can_export) {
          actions <- c(actions, list(list(
            label = "Export",
            icon = "download",
            type = "success",
            onclick = sprintf("Shiny.setInputValue('%s', %d, {priority: 'event'})", ns("export_alignment"), id)
          )))
        }

        if (can_delete) {
          actions <- c(actions, list(list(
            label = "Delete",
            icon = "trash",
            type = "danger",
            onclick = sprintf("Shiny.setInputValue('%s', %d, {priority: 'event'})", ns("delete_alignment"), id)
          )))
        }

        create_datatable_actions(actions)
      })

      dt <- datatable(
        alignments_display,
        escape = FALSE,
        rownames = FALSE,
        selection = 'none',
        options = list(
          pageLength = 25,
          dom = 'tp',
          language = get_datatable_language(),
          columnDefs = list(
            list(targets = 0, visible = FALSE),
            list(targets = 3, width = "90px", className = "dt-center"),
            list(targets = 4, width = "90px", className = "dt-center"),
            list(targets = 5, width = "90px", className = "dt-center"),
            list(targets = 6, width = "120px", className = "dt-center"),
            list(targets = 7, orderable = FALSE, width = "340px", searchable = FALSE, className = "dt-center")
          )
        ),
        colnames = c(
          "ID",
          as.character(i18n$t("project_name")),
          as.character(i18n$t("description")),
          as.character(i18n$t("mapped_concepts")),
          as.character(i18n$t("general_concepts_mapped")),
          as.character(i18n$t("evaluated_mappings")),
          as.character(i18n$t("created")),
          as.character(i18n$t("actions"))
        )
      )

      dt <- add_doubleclick_handler(dt, ns("open_alignment"))
      dt
    }, server = TRUE)

    ### Add Alignment Modal ----
    #### Modal UI Handling ----
    observe_event(input$add_alignment, {
      # Check permissions
      if (!user_has_permission("alignments", "add_alignment")) return()

      modal_mode("add")
      modal_page(1)

      updateTextInput(session, "alignment_name", value = "")
      updateTextInput(session, "alignment_description", value = "")

      shinyjs::hide("alignment_name_error")
      shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))

      shinyjs::runjs(sprintf("$('#%s').text('Add Alignment');", ns("alignment_modal_title")))

      shinyjs::show("alignment_modal")
    })

    observe_event(input$alignment_name, {
      if (!is.null(input$alignment_name) && input$alignment_name != "") {
        shinyjs::hide("alignment_name_error")
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))
      }
    }, ignoreInit = TRUE)

    ### Import INDICATE Format Modal ----
    import_indicate_validation <- reactiveVal(NULL)

    observe_event(input$open_import_indicate_modal, {
      # Check permissions
      if (!user_has_permission("alignments", "import_alignment")) return()

      # Reset state
      import_indicate_validation(NULL)
      shinyjs::hide("import_indicate_validation_status")
      shinyjs::hide("import_indicate_name_container")
      shinyjs::hide("import_indicate_name_error")
      updateTextInput(session, "import_indicate_name", value = "")
      shinyjs::show("import_indicate_modal")
    })

    observe_event(input$import_indicate_zip_file, {
      file_info <- input$import_indicate_zip_file
      if (is.null(file_info)) return()

      # Validate ZIP file
      validation <- validate_indicate_zip(file_info$datapath, i18n)
      import_indicate_validation(validation)

      # Show validation status
      if (validation$valid) {
        # Extract alignment name from metadata and populate the name field
        temp_dir <- tempfile(pattern = "indicate_validate_")
        dir.create(temp_dir)
        on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
        zip::unzip(file_info$datapath, exdir = temp_dir)
        metadata <- jsonlite::read_json(file.path(temp_dir, "metadata.json"))
        alignment_name <- metadata$alignment$name %||% paste0("Imported_", format(Sys.time(), "%Y%m%d_%H%M%S"))

        updateTextInput(session, "import_indicate_name", value = alignment_name)
        shinyjs::show("import_indicate_name_container")

        # Check if name already exists
        db_path <- file.path(get_app_dir(), "indicate.db")
        if (file.exists(db_path)) {
          con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
          on.exit(DBI::dbDisconnect(con), add = TRUE)
          existing <- DBI::dbGetQuery(
            con,
            "SELECT COUNT(*) as cnt FROM concept_alignments WHERE name = ?",
            params = list(alignment_name)
          )
          if (existing$cnt[1] > 0) {
            shinyjs::show("import_indicate_name_error")
          } else {
            shinyjs::hide("import_indicate_name_error")
          }
        }

        shinyjs::html(
          "import_indicate_validation_status",
          sprintf(
            '<div style="background-color: #d4edda; color: #155724; padding: 10px; border-radius: 4px;">
              <i class="fas fa-check-circle"></i> %s<br>
              <small>%d mappings, %d evaluations</small>
            </div>',
            i18n$t("import_validation_success"),
            validation$mappings_count %||% 0,
            validation$evaluations_count %||% 0
          )
        )
      } else {
        shinyjs::hide("import_indicate_name_container")
        shinyjs::html(
          "import_indicate_validation_status",
          sprintf(
            '<div style="background-color: #f8d7da; color: #721c24; padding: 10px; border-radius: 4px;">
              <i class="fas fa-exclamation-circle"></i> %s %s
            </div>',
            i18n$t("import_validation_error"),
            validation$message
          )
        )
      }
      shinyjs::show("import_indicate_validation_status")
    }, ignoreInit = TRUE)

    # Check name uniqueness when user types
    observe_event(input$import_indicate_name, {
      name <- input$import_indicate_name
      if (is.null(name) || name == "") return()

      db_path <- file.path(get_app_dir(), "indicate.db")
      if (file.exists(db_path)) {
        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)
        existing <- DBI::dbGetQuery(
          con,
          "SELECT COUNT(*) as cnt FROM concept_alignments WHERE name = ?",
          params = list(name)
        )
        if (existing$cnt[1] > 0) {
          shinyjs::show("import_indicate_name_error")
        } else {
          shinyjs::hide("import_indicate_name_error")
        }
      }
    }, ignoreInit = TRUE)

    observe_event(input$confirm_import_indicate, {
      file_info <- input$import_indicate_zip_file
      validation <- import_indicate_validation()

      if (is.null(file_info) || is.null(validation) || !validation$valid) {
        show_import_status(i18n$t("import_validation_error"), "error")
        return()
      }

      if (is.null(current_user())) {
        show_import_status(i18n$t("must_be_logged_in_import"), "error")
        return()
      }

      # Get alignment name from input field
      alignment_name <- trimws(input$import_indicate_name)
      if (is.null(alignment_name) || alignment_name == "") {
        shinyjs::show("import_indicate_name_error")
        return()
      }

      # Check if name already exists before proceeding
      db_path <- file.path(get_app_dir(), "indicate.db")
      if (file.exists(db_path)) {
        con_check <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        existing <- DBI::dbGetQuery(
          con_check,
          "SELECT COUNT(*) as cnt FROM concept_alignments WHERE name = ?",
          params = list(alignment_name)
        )
        DBI::dbDisconnect(con_check)
        if (existing$cnt[1] > 0) {
          shinyjs::show("import_indicate_name_error")
          return()
        }
      }

      # Extract ZIP and create new alignment
      tryCatch({
        temp_dir <- tempfile(pattern = "indicate_import_new_")
        dir.create(temp_dir)
        on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

        zip::unzip(file_info$datapath, exdir = temp_dir)

        # Read metadata
        metadata <- jsonlite::read_json(file.path(temp_dir, "metadata.json"))

        # Get alignment description and column_types from metadata
        alignment_description <- metadata$alignment$description %||% ""
        column_types_json <- metadata$alignment$column_types %||% NULL

        # Read source_concepts.csv if exists
        source_concepts_path <- file.path(temp_dir, "source_concepts.csv")
        if (!file.exists(source_concepts_path)) {
          showNotification("source_concepts.csv not found in ZIP", type = "error")
          return()
        }
        source_concepts <- read.csv(source_concepts_path, stringsAsFactors = FALSE)

        # Apply column types if available
        if (!is.null(column_types_json)) {
          source_concepts <- apply_column_types(source_concepts, column_types_json)
        }

        # Generate file_id and save source concepts
        file_id <- paste0("import_", format(Sys.time(), "%Y%m%d%H%M%S"), "_", sample(1000:9999, 1))
        mapping_dir <- get_app_dir("concept_mapping")
        if (!dir.exists(mapping_dir)) dir.create(mapping_dir, recursive = TRUE)
        csv_filename <- paste0(file_id, ".csv")
        csv_file_path <- file.path(mapping_dir, csv_filename)
        write.csv(source_concepts, csv_file_path, row.names = FALSE)

        # Create new alignment in database
        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

        # Insert alignment with column_types
        DBI::dbExecute(
          con,
          "INSERT INTO concept_alignments (name, description, file_id, created_date, column_types)
           VALUES (?, ?, ?, ?, ?)",
          params = list(alignment_name, alignment_description, file_id, timestamp, column_types_json)
        )
        new_alignment_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]

        # Read mappings, evaluations, comments
        mappings_path <- file.path(temp_dir, "mappings.csv")
        mappings <- if (file.exists(mappings_path)) read.csv(mappings_path, stringsAsFactors = FALSE) else data.frame()

        evaluations_path <- file.path(temp_dir, "evaluations.csv")
        evaluations <- if (file.exists(evaluations_path)) read.csv(evaluations_path, stringsAsFactors = FALSE) else data.frame()

        comments_path <- file.path(temp_dir, "comments.csv")
        comments <- if (file.exists(comments_path)) read.csv(comments_path, stringsAsFactors = FALSE) else data.frame()

        # Start transaction
        DBI::dbBegin(con)

        imported_mappings <- 0
        imported_evaluations <- 0
        imported_comments <- 0
        skipped_mappings <- 0
        unresolved_users <- list()  # Track users not found
        mapping_id_map <- list()  # Maps old mapping_id to new database mapping_id

        # Helper function to resolve user by first_name + last_name
        # Returns list(user_id, found, imported_user_name)
        # Always stores imported_user_name as backup (even when user_id is found)
        resolve_user <- function(row, con) {
          if ("user_first_name" %in% colnames(row) && "user_last_name" %in% colnames(row) &&
              !is.na(row$user_first_name) && !is.na(row$user_last_name) &&
              row$user_first_name != "" && row$user_last_name != "") {
            original_name <- paste(row$user_first_name, row$user_last_name)
            found <- DBI::dbGetQuery(
              con,
              "SELECT user_id FROM users WHERE first_name = ? AND last_name = ?",
              params = list(row$user_first_name, row$user_last_name)
            )
            if (nrow(found) > 0) {
              # Store both user_id AND imported_user_name as backup
              return(list(user_id = found$user_id[1], found = TRUE, imported_user_name = original_name))
            } else {
              return(list(user_id = NA_integer_, found = FALSE, imported_user_name = original_name))
            }
          }
          return(list(user_id = NA_integer_, found = FALSE, imported_user_name = NA_character_))
        }

        # Build lookup index for source_concepts by vocabulary_id + concept_code
        source_lookup <- list()
        has_vocab_code <- "vocabulary_id" %in% colnames(source_concepts) && "concept_code" %in% colnames(source_concepts)
        if (has_vocab_code) {
          for (i in seq_len(nrow(source_concepts))) {
            vocab_id <- as.character(source_concepts$vocabulary_id[i])
            code <- as.character(source_concepts$concept_code[i])
            if (!is.na(vocab_id) && !is.na(code) && vocab_id != "" && code != "") {
              key <- paste0(vocab_id, "|||", code)
              source_lookup[[key]] <- i
            }
          }
        }

        # Import mappings with vocabulary_id + concept_code matching
        if (nrow(mappings) > 0) {
          for (i in seq_len(nrow(mappings))) {
            row <- mappings[i, ]
            old_mapping_id <- row$mapping_id

            # Find row_id by matching vocabulary_id + concept_code
            new_source_index <- NA_integer_

            if (has_vocab_code && "vocabulary_id" %in% colnames(mappings) && "concept_code" %in% colnames(mappings)) {
              vocab_id <- as.character(row$vocabulary_id)
              code <- as.character(row$concept_code)
              if (!is.na(vocab_id) && !is.na(code) && vocab_id != "" && code != "") {
                key <- paste0(vocab_id, "|||", code)
                if (!is.null(source_lookup[[key]])) {
                  new_source_index <- source_lookup[[key]]
                }
              }
            }

            # Skip mapping if source concept not found in new alignment
            if (is.na(new_source_index)) {
              skipped_mappings <- skipped_mappings + 1
              next
            }

            # Get target_general_concept_id if available
            target_general_id <- if ("target_general_concept_id" %in% colnames(row) && !is.na(row$target_general_concept_id)) {
              row$target_general_concept_id
            } else {
              NA_integer_
            }

            # Get target_custom_concept_id if available (keep original ID, it references local custom_concepts.csv)
            target_custom_id <- if ("target_custom_concept_id" %in% colnames(row) && !is.na(row$target_custom_concept_id)) {
              as.integer(row$target_custom_concept_id)
            } else {
              NA_integer_
            }

            # Resolve mapping user from exported first_name/last_name
            resolved <- resolve_user(row, con)
            if (!resolved$found && !is.na(resolved$imported_user_name)) {
              unresolved_users[[resolved$imported_user_name]] <- TRUE
            }

            DBI::dbExecute(
              con,
              "INSERT INTO concept_mappings (alignment_id, csv_file_path, row_id,
                                             target_general_concept_id, target_omop_concept_id, target_custom_concept_id,
                                             mapping_datetime, mapped_by_user_id, imported_user_name)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
              params = list(
                new_alignment_id, csv_filename, new_source_index,
                target_general_id, row$target_omop_concept_id, target_custom_id,
                timestamp, resolved$user_id, resolved$imported_user_name
              )
            )

            new_mapping_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]
            mapping_id_map[[as.character(old_mapping_id)]] <- new_mapping_id
            imported_mappings <- imported_mappings + 1
          }
        }

        # Import evaluations
        if (nrow(evaluations) > 0) {
          for (i in seq_len(nrow(evaluations))) {
            row <- evaluations[i, ]
            old_mapping_id <- as.character(row$mapping_id)
            new_mapping_id <- mapping_id_map[[old_mapping_id]]

            if (!is.null(new_mapping_id)) {
              resolved <- resolve_user(row, con)
              if (!resolved$found && !is.na(resolved$imported_user_name)) {
                unresolved_users[[resolved$imported_user_name]] <- TRUE
              }

              DBI::dbExecute(
                con,
                "INSERT INTO mapping_evaluations (alignment_id, mapping_id, evaluator_user_id, imported_user_name, is_approved, evaluated_at)
                 VALUES (?, ?, ?, ?, ?, ?)",
                params = list(new_alignment_id, new_mapping_id, resolved$user_id, resolved$imported_user_name, row$is_approved, timestamp)
              )
              imported_evaluations <- imported_evaluations + 1
            }
          }
        }

        # Import comments
        if (nrow(comments) > 0) {
          for (i in seq_len(nrow(comments))) {
            row <- comments[i, ]
            old_mapping_id <- as.character(row$mapping_id)
            new_mapping_id <- mapping_id_map[[old_mapping_id]]

            if (!is.null(new_mapping_id)) {
              resolved <- resolve_user(row, con)
              if (!resolved$found && !is.na(resolved$imported_user_name)) {
                unresolved_users[[resolved$imported_user_name]] <- TRUE
              }
              comment_val <- if ("comment" %in% colnames(row)) row$comment else ""

              DBI::dbExecute(
                con,
                "INSERT INTO mapping_comments (mapping_id, user_id, imported_user_name, comment, created_at)
                 VALUES (?, ?, ?, ?, ?)",
                params = list(new_mapping_id, resolved$user_id, resolved$imported_user_name, comment_val, timestamp)
              )
              imported_comments <- imported_comments + 1
            }
          }
        }

        DBI::dbCommit(con)

        # Hide modal
        shinyjs::hide("import_indicate_modal")

        # Build notification message with HTML formatting
        msg_parts <- list()

        # Success message with bold alignment name
        success_msg <- i18n$t("import_alignment_created")
        success_msg <- gsub("\\{name\\}", paste0("<strong>", alignment_name, "</strong>"), success_msg)
        success_msg <- gsub("\\{mappings\\}", paste0("<strong>", imported_mappings, "</strong>"), success_msg)
        msg_parts[[length(msg_parts) + 1]] <- success_msg

        # Add skipped mappings info if any
        if (skipped_mappings > 0) {
          skipped_msg <- gsub("\\{count\\}", paste0("<strong>", skipped_mappings, "</strong>"), i18n$t("mappings_skipped_no_match"))
          msg_parts[[length(msg_parts) + 1]] <- paste0("(", skipped_msg, ")")
        }

        # Add warning about unresolved users if any
        has_warning <- length(unresolved_users) > 0
        if (has_warning) {
          unresolved_names <- names(unresolved_users)
          warning_msg <- gsub("\\{count\\}", paste0("<strong>", length(unresolved_names), "</strong>"), i18n$t("users_not_found_warning"))
          warning_msg <- paste0(warning_msg, ": ", paste(unresolved_names, collapse = ", "))
          msg_parts[[length(msg_parts) + 1]] <- warning_msg
        }

        notification_type <- if (has_warning) "warning" else "message"
        notification_ui <- tags$div(
          lapply(msg_parts, function(part) tags$div(HTML(part)))
        )
        showNotification(notification_ui, type = notification_type, duration = 10)

        # Refresh alignments data to update the table
        alignments_data(get_all_alignments())

      }, error = function(e) {
        showNotification(paste(i18n$t("import_failed"), e$message), type = "error")
      })
    })

    ### Edit Alignment ----
    observe_event(input$edit_alignment, {
      # Check permissions
      if (!user_has_permission("alignments", "edit_alignment")) return()

      alignment_id <- input$edit_alignment
      alignment <- alignments_data() %>% filter(alignment_id == !!alignment_id)

      if (nrow(alignment) > 0) {
        modal_mode("edit")
        modal_page(1)
        selected_alignment_id(alignment_id)

        updateTextInput(session, "alignment_name", value = alignment$name)
        updateTextInput(session, "alignment_description", value = alignment$description)

        shinyjs::runjs(sprintf("$('#%s').text('Edit Alignment');", ns("alignment_modal_title")))

        shinyjs::hide("alignment_modal_next")
        shinyjs::show("alignment_modal_save")

        shinyjs::show("alignment_modal")
      }
    })

    #### File Upload & Processing ----
    output$csv_options <- renderUI({
      if (is.null(input$alignment_file)) return()
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext != "csv") {
        return(NULL)
      }

      tags$div(
        style = "background-color: #f8f9fa; border-radius: 4px; overflow: hidden;",
        tags$div(
          style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px;",
          "CSV Options"
        ),
        tags$div(
          class = "p-15",
          tags$div(
            style = "display: flex; flex-wrap: wrap; gap: 15px;",
            tags$div(
              class = "flex-input-field",
              tags$label("Delimiter", class = "form-label"),
              selectInput(
                ns("csv_delimiter"),
                label = NULL,
                choices = c(
                  "Auto-detect" = "auto",
                  "Comma (,)" = ",",
                  "Semicolon (;)" = ";",
                  "Tab" = "\t",
                  "Pipe (|)" = "|"
                ),
                selected = "auto"
              )
            ),
            tags$div(
              class = "flex-input-field",
              tags$label("Encoding", class = "form-label"),
              selectInput(
                ns("csv_encoding"),
                label = NULL,
                choices = c(
                  "UTF-8" = "UTF-8",
                  "Latin1 (ISO-8859-1)" = "Latin1",
                  "Windows-1252" = "Windows-1252"
                ),
                selected = "UTF-8"
              )
            )
          )
        )
      )
    })

    #### CSV Options & Column Mapping ----
    output$column_mapping_wrapper <- renderUI({
      if (is.null(input$alignment_file)) return()

      tags$div(
        style = "background-color: #f8f9fa; border-radius: 4px;",
        uiOutput(ns("column_mapping_title")),
        tags$div(
          class = "p-15",
          uiOutput(ns("column_mapping_controls"))
        )
      )
    })

    output$column_mapping_title <- renderUI({
      if (is.null(input$alignment_file)) return()
      tags$div(
        style = "background-color: #fd7e14; color: white; padding: 10px 15px; font-weight: 600; font-size: 14px; border-radius: 4px 4px 0 0;",
        "Column Mapping"
      )
    })

    output$column_mapping_controls <- renderUI({
      if (is.null(input$alignment_file)) return()

      file_path <- input$alignment_file$datapath
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext == "csv") {
        delimiter <- if (!is.null(input$csv_delimiter) && input$csv_delimiter != "auto") {
          input$csv_delimiter
        } else {
          NULL
        }
        encoding <- if (!is.null(input$csv_encoding)) input$csv_encoding else "UTF-8"

        df <- vroom::vroom(
          file_path,
          delim = delimiter,
          locale = vroom::locale(encoding = encoding),
          show_col_types = FALSE,
          n_max = 1
        )
        df <- as.data.frame(df)
      } else if (file_ext %in% c("xlsx", "xls")) {
        df <- readxl::read_excel(file_path, n_max = 1)
      } else {
        return(tags$p("Unsupported file format", style = "color: red;"))
      }

      col_names <- colnames(df)
      choices <- c("", col_names)

      tagList(
        # Row 1: Vocabulary ID Column
        tags$div(
          style = "margin-bottom: 10px;",
          tags$label("Vocabulary ID Column", class = "form-label"),
          selectInput(
            ns("col_vocabulary_id"),
            label = NULL,
            choices = choices,
            selected = ""
          ),
          tags$div(
            id = ns("col_vocabulary_id_error"),
            style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
            "Please select Vocabulary ID column"
          )
        ),
        # Row 2: Concept Code + Concept Name
        tags$div(
          style = "display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 10px;",
          tags$div(
            class = "flex-input-field",
            tags$label("Concept Code Column", class = "form-label"),
            selectInput(
              ns("col_concept_code"),
              label = NULL,
              choices = choices,
              selected = ""
            ),
            tags$div(
              id = ns("col_concept_code_error"),
              style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
              "Please select Concept Code column"
            )
          ),
          tags$div(
            class = "flex-input-field",
            tags$label("Concept Name Column", class = "form-label"),
            selectInput(
              ns("col_concept_name"),
              label = NULL,
              choices = choices,
              selected = ""
            ),
            tags$div(
              id = ns("col_concept_name_error"),
              style = "color: #dc3545; font-size: 13px; margin-top: 5px; display: none;",
              "Please select Concept Name column"
            )
          )
        ),
        # Row 3: Category Column + JSON Column
        tags$div(
          style = "display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 10px;",
          tags$div(
            class = "flex-input-field",
            tags$label(
              "Category Column",
              tags$span(style = "color: #999; font-weight: normal; font-size: 12px;", " (optional)"),
              class = "form-label"
            ),
            selectInput(
              ns("col_category"),
              label = NULL,
              choices = choices,
              selected = ""
            )
          ),
          tags$div(
            class = "flex-input-field",
            tags$label(
              "JSON Column",
              tags$span(style = "color: #999; font-weight: normal; font-size: 12px;", " (optional)"),
              class = "form-label"
            ),
            selectInput(
              ns("col_json"),
              label = NULL,
              choices = choices,
              selected = ""
            )
          )
        ),
        # Row 4: Frequency Column + Target Concept ID Column
        tags$div(
          style = "display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 10px;",
          tags$div(
            class = "flex-input-field",
            tags$label(
              "Frequency Column",
              tags$span(style = "color: #999; font-weight: normal; font-size: 12px;", " (optional)"),
              class = "form-label"
            ),
            selectInput(
              ns("col_frequency"),
              label = NULL,
              choices = choices,
              selected = ""
            )
          ),
          tags$div(
            class = "flex-input-field",
            tags$label(
              i18n$t("target_concept_id_column"),
              tags$span(style = "color: #999; font-weight: normal; font-size: 12px;", paste0(" (", i18n$t("optional"), ")")),
              tags$span(
                class = "help-tooltip",
                style = "margin-left: 5px; cursor: help; position: relative; display: inline-block;",
                tags$i(class = "fas fa-question-circle", style = "color: #999; font-size: 12px;"),
                tags$span(
                  class = "tooltip-text",
                  style = "visibility: hidden; background-color: #333; color: #fff; text-align: center; border-radius: 6px; padding: 8px 12px; position: absolute; z-index: 1000; bottom: 125%; left: 50%; transform: translateX(-50%); width: 250px; font-size: 12px; font-weight: normal; opacity: 0; transition: opacity 0.2s;",
                  i18n$t("target_concept_id_column_desc")
                )
              ),
              class = "form-label"
            ),
            selectInput(
              ns("col_target_concept_id"),
              label = NULL,
              choices = choices,
              selected = ""
            )
          )
        ),
        # Row 5: Additional Columns
        tags$div(
          style = "margin-bottom: 10px;",
          tags$label(
            "Additional Columns",
            tags$span(style = "color: #999; font-weight: normal; font-size: 12px;", " (optional)"),
            class = "form-label"
          ),
          selectizeInput(
            ns("col_additional"),
            label = NULL,
            choices = col_names,
            selected = NULL,
            multiple = TRUE
          )
        )
      )
    })

    #### File Preview ----
    observe_event(input$alignment_file, {
      if (is.null(input$alignment_file)) {
        file_preview_data(NULL)
        return()
      }

      file_path <- input$alignment_file$datapath
      file_ext <- tools::file_ext(input$alignment_file$name)

      if (file_ext == "csv") {
        delimiter <- if (!is.null(input$csv_delimiter) && input$csv_delimiter != "auto") {
          input$csv_delimiter
        } else {
          NULL
        }

        encoding <- if (!is.null(input$csv_encoding)) {
          input$csv_encoding
        } else {
          "UTF-8"
        }

        df <- vroom::vroom(
          file_path,
          delim = delimiter,
          locale = vroom::locale(encoding = encoding),
          show_col_types = FALSE
        )
      } else if (file_ext %in% c("xlsx", "xls")) {
        df <- readxl::read_excel(file_path)
      } else {
        file_preview_data(NULL)
        return()
      }

      df <- as.data.frame(df) %>% dplyr::distinct()
      file_preview_data(df)
    })

    output$file_preview_table <- DT::renderDT({
      df <- file_preview_data()

      if (is.null(df)) {
        return(datatable(
          data.frame(),
          options = list(
            pageLength = 8,
            dom = 'tp',
            ordering = TRUE,
            language = get_datatable_language()
          ),
          rownames = FALSE,
          selection = 'none',
          filter = 'none',
          class = 'display'
        ))
      }

      datatable(
        df,
        options = list(
          pageLength = 8,
          dom = 'tp',
          ordering = TRUE,
          language = get_datatable_language()
        ),
        rownames = FALSE,
        selection = 'none',
        filter = 'none',
        class = 'display'
      )
    }, server = TRUE)

    #### Page 3: Column Data Types ----
    output$column_data_types_controls <- renderUI({
      df <- file_preview_data()
      if (is.null(df)) return(tags$p(style = "color: #999;", i18n$t("no_file_uploaded")))

      # Get only the columns selected in page 2 dropdowns
      selected_cols <- c(
        input$col_vocabulary_id,
        input$col_frequency,
        input$col_concept_code,
        input$col_concept_name,
        input$col_category,
        input$col_json,
        input$col_target_concept_id
      )

      # Track which column is the category column (for default type)
      category_col <- input$col_category
      # Add additional columns (multiple selection)
      if (!is.null(input$col_additional)) {
        selected_cols <- c(selected_cols, input$col_additional)
      }
      # Remove empty selections and duplicates
      selected_cols <- unique(selected_cols[selected_cols != "" & !is.na(selected_cols)])

      # Filter to only selected columns that exist in df
      col_names <- selected_cols[selected_cols %in% colnames(df)]

      if (length(col_names) == 0) {
        return(tags$p(style = "color: #999;", i18n$t("no_columns_selected")))
      }

      # Data type choices
      type_choices <- c(
        "character" = "character",
        "numeric" = "numeric",
        "integer" = "integer",
        "factor" = "factor",
        "date" = "date",
        "datetime" = "datetime",
        "logical" = "logical"
      )

      # Infer default types from data
      infer_type <- function(col_data) {
        if (all(is.na(col_data))) return("character")
        sample_data <- col_data[!is.na(col_data)]
        if (length(sample_data) == 0) return("character")

        # Convert to character for type inference
        sample_data <- as.character(sample_data)

        # Check if logical
        if (all(tolower(sample_data) %in% c("true", "false", "t", "f", "yes", "no", "1", "0"))) return("logical")

        # Check if numeric
        numeric_result <- tryCatch({
          nums <- suppressWarnings(as.numeric(sample_data))
          if (!any(is.na(nums))) {
            if (all(nums == floor(nums))) return("integer")
            return("numeric")
          }
          NULL
        }, error = function(e) NULL)
        if (!is.null(numeric_result)) return(numeric_result)

        # Check if date (YYYY-MM-DD format)
        date_result <- tryCatch({
          dates <- suppressWarnings(as.Date(sample_data, format = "%Y-%m-%d"))
          if (!any(is.na(dates))) return("date")
          NULL
        }, error = function(e) NULL)
        if (!is.null(date_result)) return(date_result)

        # Check if datetime (try common formats)
        datetime_result <- tryCatch({
          # Try ISO format first
          dts <- suppressWarnings(as.POSIXct(sample_data, format = "%Y-%m-%d %H:%M:%S"))
          if (!any(is.na(dts))) return("datetime")
          NULL
        }, error = function(e) NULL)
        if (!is.null(datetime_result)) return(datetime_result)

        # Default to character
        return("character")
      }

      # Create a dropdown for each column
      column_controls <- lapply(col_names, function(col_name) {
        # Default category column to factor, otherwise infer from data
        if (!is.null(category_col) && category_col != "" && col_name == category_col) {
          selected_type <- "factor"
        } else {
          selected_type <- infer_type(df[[col_name]])
        }
        input_id <- paste0("col_type_", gsub("[^a-zA-Z0-9]", "_", col_name))

        tags$div(
          style = "display: flex; align-items: center; margin-bottom: 8px; gap: 10px;",
          tags$span(
            style = "min-width: 150px; font-weight: 500; font-size: 13px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;",
            title = col_name,
            col_name
          ),
          tags$div(
            class = "flex-1",
            selectInput(
              ns(input_id),
              label = NULL,
              choices = type_choices,
              selected = selected_type,
              width = "100%"
            )
          )
        )
      })

      tags$div(
        style = "max-height: 400px; overflow-y: auto;",
        column_controls
      )
    })

    # File preview for page 3 (same data as page 2)
    output$file_preview_table_page3 <- DT::renderDT({
      df <- file_preview_data()

      if (is.null(df)) {
        return(datatable(
          data.frame(),
          options = list(
            pageLength = 8,
            dom = 'tp',
            ordering = TRUE,
            language = get_datatable_language()
          ),
          rownames = FALSE,
          selection = 'none',
          filter = 'none',
          class = 'display'
        ))
      }

      datatable(
        df,
        options = list(
          pageLength = 8,
          dom = 'tp',
          ordering = TRUE,
          language = get_datatable_language()
        ),
        rownames = FALSE,
        selection = 'none',
        filter = 'none',
        class = 'display'
      )
    }, server = TRUE)

    #### Modal Navigation & Save Handling ----
    observe_event(input$alignment_modal_next, {
      if (modal_page() == 1) {
        # Validate alignment name before proceeding to page 2
        alignment_name <- trimws(input$alignment_name)

        # Check if name is empty
        if (alignment_name == "") {
          shinyjs::show("alignment_name_error")
          shinyjs::hide("alignment_name_duplicate_error")
          shinyjs::runjs(sprintf("$('#%s input').css('border-color', '#dc3545');", ns("alignment_name")))
          return()
        }

        shinyjs::hide("alignment_name_error")

        # Check for duplicate name (only in add mode, or if name changed in edit mode)
        alignments <- alignments_data()
        if (!is.null(alignments) && nrow(alignments) > 0) {
          existing_names <- tolower(alignments$name)

          # In edit mode, exclude the current alignment from duplicate check
          if (modal_mode() == "edit" && !is.null(selected_alignment_id())) {
            current_alignment <- alignments %>% dplyr::filter(alignment_id == selected_alignment_id())
            if (nrow(current_alignment) > 0) {
              existing_names <- existing_names[existing_names != tolower(current_alignment$name[1])]
            }
          }

          if (tolower(alignment_name) %in% existing_names) {
            shinyjs::show("alignment_name_duplicate_error")
            shinyjs::runjs(sprintf("$('#%s input').css('border-color', '#dc3545');", ns("alignment_name")))
            return()
          }
        }

        shinyjs::hide("alignment_name_duplicate_error")
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))

        modal_page(2)

        shinyjs::hide(id = "modal_page_1")
        shinyjs::show(id = "modal_page_2")

        shinyjs::runjs(sprintf("$('#%s').css({'max-width': '90vw', 'height': '80vh', 'max-height': '80vh'});", ns("alignment_modal_dialog")))

        shinyjs::runjs(sprintf("$('#%s').text('Page 2 of 3');", ns("modal_page_indicator")))
        shinyjs::show("alignment_modal_back")
        shinyjs::show("alignment_modal_next")
        shinyjs::hide("alignment_modal_save")

      } else if (modal_page() == 2) {
        # Validate file upload and column mappings before proceeding to page 3
        if (is.null(input$alignment_file)) {
          shinyjs::show("alignment_file_error")
          return()
        }

        is_valid <- validate_required_inputs(
          input,
          fields = list(
            col_vocabulary_id = "col_vocabulary_id_error",
            col_concept_code = "col_concept_code_error",
            col_concept_name = "col_concept_name_error"
          )
        )

        if (!is_valid) return()

        modal_page(3)

        shinyjs::hide(id = "modal_page_2")
        shinyjs::show(id = "modal_page_3")

        shinyjs::runjs(sprintf("$('#%s').text('Page 3 of 3');", ns("modal_page_indicator")))
        shinyjs::show("alignment_modal_back")
        shinyjs::hide("alignment_modal_next")
        shinyjs::show("alignment_modal_save")
      }
    })

    observe_event(input$alignment_modal_back, {
      if (modal_page() == 2) {
        modal_page(1)

        shinyjs::show(id = "modal_page_1")
        shinyjs::hide(id = "modal_page_2")

        shinyjs::runjs(sprintf("$('#%s').css({'max-width': '600px', 'height': 'auto', 'max-height': '90vh'});", ns("alignment_modal_dialog")))

        shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 3');", ns("modal_page_indicator")))
        shinyjs::hide("alignment_modal_back")
        shinyjs::show("alignment_modal_next")
        shinyjs::hide("alignment_modal_save")

      } else if (modal_page() == 3) {
        modal_page(2)

        shinyjs::show(id = "modal_page_2")
        shinyjs::hide(id = "modal_page_3")

        shinyjs::runjs(sprintf("$('#%s').text('Page 2 of 3');", ns("modal_page_indicator")))
        shinyjs::show("alignment_modal_back")
        shinyjs::show("alignment_modal_next")
        shinyjs::hide("alignment_modal_save")
      }
    })

    observe_event(input$alignment_modal_cancel, {
      shinyjs::hide("alignment_modal")

      updateTextInput(session, "alignment_name", value = "")
      updateTextAreaInput(session, "alignment_description", value = "")

      file_preview_data(NULL)

      shinyjs::reset("alignment_file")

      updateSelectInput(session, "csv_delimiter", selected = "auto")
      updateSelectInput(session, "csv_encoding", selected = "UTF-8")
      updateSelectInput(session, "col_vocabulary_id", selected = "")
      updateSelectInput(session, "col_frequency", selected = "")
      updateSelectInput(session, "col_concept_code", selected = "")
      updateSelectInput(session, "col_concept_name", selected = "")
      updateSelectInput(session, "col_category", selected = "")
      updateSelectInput(session, "col_json", selected = "")
      updateSelectInput(session, "col_additional", selected = character(0))
      updateSelectInput(session, "col_target_concept_id", selected = "")

      shinyjs::runjs(sprintf("$('#%s').html('');", ns("csv_options")))
      shinyjs::runjs(sprintf("$('#%s').html('');", ns("column_mapping_wrapper")))

      shinyjs::hide("alignment_name_error")
      shinyjs::hide("alignment_file_error")
      shinyjs::hide("col_vocabulary_id_error")
      shinyjs::hide("col_concept_code_error")
      shinyjs::hide("col_concept_name_error")

      modal_page(1)

      shinyjs::show(id = "modal_page_1")
      shinyjs::hide(id = "modal_page_2")
      shinyjs::hide(id = "modal_page_3")
      shinyjs::runjs(sprintf("$('#%s').css({'max-width': '600px', 'height': 'auto', 'max-height': '90vh'});", ns("alignment_modal_dialog")))

      shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 3');", ns("modal_page_indicator")))
      shinyjs::hide("alignment_modal_back")
      shinyjs::show("alignment_modal_next")
      shinyjs::hide("alignment_modal_save")
    })

    observe_event(input$alignment_file, {
      if (!is.null(input$alignment_file)) {
        shinyjs::hide("alignment_file_error")
      }
    })

    observe_event(input$col_vocabulary_id, {
      if (!is.null(input$col_vocabulary_id) && input$col_vocabulary_id != "") {
        shinyjs::hide("col_vocabulary_id_error")
      }
    })

    observe_event(input$col_concept_code, {
      if (!is.null(input$col_concept_code) && input$col_concept_code != "") {
        shinyjs::hide("col_concept_code_error")
      }
    })

    observe_event(input$col_concept_name, {
      if (!is.null(input$col_concept_name) && input$col_concept_name != "") {
        shinyjs::hide("col_concept_name_error")
      }
    })

    #### Save Alignment ----
    observe_event(input$alignment_modal_save, {
      # Validate alignment name (required for both add and edit modes)
      alignment_name_value <- trimws(input$alignment_name)

      if (alignment_name_value == "") {
        shinyjs::show("alignment_name_error")
        shinyjs::hide("alignment_name_duplicate_error")
        shinyjs::runjs(sprintf("$('#%s input').css('border-color', '#dc3545');", ns("alignment_name")))
        return()
      }

      shinyjs::hide("alignment_name_error")

      # Check for duplicate name
      alignments <- alignments_data()
      if (!is.null(alignments) && nrow(alignments) > 0) {
        existing_names <- tolower(alignments$name)

        # In edit mode, exclude the current alignment from duplicate check
        if (modal_mode() == "edit" && !is.null(selected_alignment_id())) {
          current_alignment <- alignments %>% dplyr::filter(alignment_id == selected_alignment_id())
          if (nrow(current_alignment) > 0) {
            existing_names <- existing_names[existing_names != tolower(current_alignment$name[1])]
          }
        }

        if (tolower(alignment_name_value) %in% existing_names) {
          shinyjs::show("alignment_name_duplicate_error")
          shinyjs::runjs(sprintf("$('#%s input').css('border-color', '#dc3545');", ns("alignment_name")))
          return()
        }
      }

      shinyjs::hide("alignment_name_duplicate_error")
      shinyjs::runjs(sprintf("$('#%s input').css('border-color', '');", ns("alignment_name")))

      # Validate file upload and column mappings (only for add mode)
      if (modal_mode() == "add") {
        # Check file upload separately (not a text input)
        if (is.null(input$alignment_file)) {
          shinyjs::show("alignment_file_error")
          return()
        }

        # Validate required column mappings
        is_valid <- validate_required_inputs(
          input,
          fields = list(
            col_vocabulary_id = "col_vocabulary_id_error",
            col_concept_code = "col_concept_code_error",
            col_concept_name = "col_concept_name_error"
          )
        )

        if (!is_valid) return()
      }

      if (modal_mode() == "add") {
        file_path <- input$alignment_file$datapath
        file_ext <- tools::file_ext(input$alignment_file$name)

        if (file_ext == "csv") {
          delimiter <- if (!is.null(input$csv_delimiter) && input$csv_delimiter != "auto") {
            input$csv_delimiter
          } else {
            NULL
          }
          encoding <- if (!is.null(input$csv_encoding)) input$csv_encoding else "UTF-8"

          df <- vroom::vroom(
            file_path,
            delim = delimiter,
            locale = vroom::locale(encoding = encoding),
            show_col_types = FALSE
          )
          df <- as.data.frame(df)
        } else if (file_ext %in% c("xlsx", "xls")) {
          df <- readxl::read_excel(file_path)
        } else {
          return()
        }

        col_mapping <- list(
          vocabulary_id = input$col_vocabulary_id,
          concept_code = input$col_concept_code,
          concept_name = input$col_concept_name,
          category = input$col_category,
          json = input$col_json,
          target_concept_id = input$col_target_concept_id,
          frequency = input$col_frequency
        )

        additional_cols <- input$col_additional
        if (is.null(additional_cols)) {
          additional_cols <- character(0)
        }

        new_cols <- list()

        for (new_name in names(col_mapping)) {
          old_name <- col_mapping[[new_name]]
          if (!is.null(old_name) && old_name != "" && old_name %in% colnames(df)) {
            new_cols[[new_name]] <- df[[old_name]]
          }
        }

        for (col in additional_cols) {
          if (col %in% colnames(df) && !col %in% names(col_mapping)) {
            final_name <- col
            suffix <- 2
            while (final_name %in% names(new_cols)) {
              final_name <- paste0(col, "_", suffix)
              suffix <- suffix + 1
            }
            new_cols[[final_name]] <- df[[col]]
          }
        }

        new_df <- as.data.frame(new_cols, stringsAsFactors = FALSE)

        new_df <- new_df %>% dplyr::distinct()

        new_df <- cbind(row_id = seq_len(nrow(new_df)), new_df, stringsAsFactors = FALSE)

        file_id <- paste0("alignment_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))

        mapping_dir <- get_app_dir("concept_mapping")

        if (!dir.exists(mapping_dir)) {
          dir.create(mapping_dir, recursive = TRUE, showWarnings = FALSE)
        }

        csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
        write.csv(new_df, csv_path, row.names = FALSE)

        # Collect column types from page 3
        column_types_list <- list()
        col_names <- colnames(new_df)
        for (col_name in col_names) {
          input_id <- paste0("col_type_", gsub("[^a-zA-Z0-9]", "_", col_name))
          col_type <- input[[input_id]]
          if (!is.null(col_type) && col_type != "") {
            column_types_list[[col_name]] <- col_type
          }
        }

        # Convert to JSON string
        column_types_json <- if (length(column_types_list) > 0) {
          jsonlite::toJSON(column_types_list, auto_unbox = TRUE)
        } else {
          NULL
        }

        new_id <- add_alignment(
          name = input$alignment_name,
          description = ifelse(is.null(input$alignment_description), "", input$alignment_description),
          file_id = file_id,
          original_filename = input$alignment_file$name,
          column_types = column_types_json
        )

        # Import mappings if target_concept_id column was selected and has data
        if ("target_concept_id" %in% colnames(new_df)) {
          import_target_concept_mappings(
            alignment_id = new_id,
            source_data = new_df,
            csv_filename = paste0(file_id, ".csv"),
            user_id = current_user()$user_id,
            original_filename = input$alignment_file$name
          )
        }

        alignments_data(get_all_alignments())
      } else if (modal_mode() == "edit") {
        update_alignment(
          alignment_id = selected_alignment_id(),
          name = input$alignment_name,
          description = ifelse(is.null(input$alignment_description), "", input$alignment_description)
        )

        alignments_data(get_all_alignments())
      }

      shinyjs::hide("alignment_modal")
      modal_page(1)

      shinyjs::show(id = "modal_page_1")
      shinyjs::hide(id = "modal_page_2")
      shinyjs::hide(id = "modal_page_3")
      shinyjs::runjs(sprintf("$('#%s').css({'max-width': '600px', 'height': 'auto', 'max-height': '90vh'});", ns("alignment_modal_dialog")))

      shinyjs::runjs(sprintf("$('#%s').text('Page 1 of 3');", ns("modal_page_indicator")))
      shinyjs::hide("alignment_modal_back")
      shinyjs::show("alignment_modal_next")
      shinyjs::hide("alignment_modal_save")

      # Reset form inputs for next add
      updateTextInput(session, "alignment_name", value = "")
      updateTextAreaInput(session, "alignment_description", value = "")
      file_preview_data(NULL)
      shinyjs::reset("alignment_file")
      updateSelectInput(session, "csv_delimiter", selected = "auto")
      updateSelectInput(session, "csv_encoding", selected = "UTF-8")
      updateSelectInput(session, "col_vocabulary_id", selected = "")
      updateSelectInput(session, "col_frequency", selected = "")
      updateSelectInput(session, "col_concept_code", selected = "")
      updateSelectInput(session, "col_concept_name", selected = "")
      updateSelectInput(session, "col_category", selected = "")
      updateSelectInput(session, "col_json", selected = "")
      updateSelectInput(session, "col_additional", selected = character(0))
      updateSelectInput(session, "col_target_concept_id", selected = "")
      shinyjs::runjs(sprintf("$('#%s').html('');", ns("csv_options")))
      shinyjs::runjs(sprintf("$('#%s').html('');", ns("column_mapping_wrapper")))
    })

    ### Delete Alignment ----
    observe_event(input$delete_alignment, {
      # Check permissions
      if (!user_has_permission("alignments", "delete_alignment")) return()

      alignment_id <- input$delete_alignment
      alignment_to_delete(alignment_id)

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == !!alignment_id)

      if (nrow(alignment) == 1) {
        alignment_name <- alignment$name[1]
        shinyjs::html("delete_alignment_name_display", alignment_name)
      }

      shinyjs::show("delete_confirmation_modal")
    })

    observe_event(input$confirm_delete_alignment, {
      # Check permissions
      if (!user_has_permission("alignments", "delete_alignment")) return()
      if (is.null(alignment_to_delete())) return()

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == alignment_to_delete())

      if (nrow(alignment) == 1) {
        file_id <- alignment$file_id[1]

        mapping_dir <- get_app_dir("concept_mapping")

        csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
        if (file.exists(csv_path)) {
          file.remove(csv_path)
        }
      }

      delete_alignment(alignment_to_delete())
      alignments_data(get_all_alignments())

      shinyjs::hide("delete_confirmation_modal")
      alignment_to_delete(NULL)
    })
    
    
    ### Export Alignment - Open Modal ----
    observe_event(input$export_alignment, {
      # Check permissions
      if (!user_has_permission("alignments", "export_mappings")) return()

      alignment_id <- input$export_alignment
      if (is.null(alignment_id)) return()

      # Store alignment_id for export
      export_alignment_id(alignment_id)

      # Get database connection to calculate statistics
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        showNotification(i18n$t("database_not_found"), type = "error")
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings for this alignment with evaluation summary
      mappings_query <- "
        SELECT
          cm.mapping_id,
          cm.target_omop_concept_id,
          COALESCE(SUM(CASE WHEN me.is_approved = 1 THEN 1 ELSE 0 END), 0) as approval_count,
          COALESCE(SUM(CASE WHEN me.is_approved = 0 THEN 1 ELSE 0 END), 0) as rejection_count,
          COALESCE(SUM(CASE WHEN me.is_approved = -1 THEN 1 ELSE 0 END), 0) as uncertain_count,
          COUNT(me.evaluation_id) as total_evaluations
        FROM concept_mappings cm
        LEFT JOIN mapping_evaluations me ON cm.mapping_id = me.mapping_id
        WHERE cm.alignment_id = ?
        GROUP BY cm.mapping_id
      "

      mappings_data <- DBI::dbGetQuery(con, mappings_query, params = list(alignment_id))

      if (nrow(mappings_data) == 0) {
        showNotification(i18n$t("no_mappings_found"), type = "warning")
        return()
      }

      # Calculate statistics based on evaluation criteria
      # Approved: at least one approval
      count_approved <- sum(mappings_data$approval_count > 0)
      # Rejected: at least one rejection (and no approval)
      count_rejected <- sum(mappings_data$rejection_count > 0 & mappings_data$approval_count == 0)
      # Uncertain: at least one uncertain (and no approval, no rejection)
      count_uncertain <- sum(mappings_data$uncertain_count > 0 & mappings_data$approval_count == 0 & mappings_data$rejection_count == 0)
      # Not evaluated: no evaluations at all
      count_not_evaluated <- sum(mappings_data$total_evaluations == 0)

      total_mappings <- nrow(mappings_data)

      # Store statistics
      stats <- list(
        total = total_mappings,
        approved = count_approved,
        rejected = count_rejected,
        uncertain = count_uncertain,
        not_evaluated = count_not_evaluated,
        mappings_data = mappings_data
      )
      export_stats(stats)

      # Update statistics display
      shinyjs::html("stat_total", as.character(total_mappings))
      shinyjs::html("stat_approved", as.character(count_approved))
      shinyjs::html("stat_rejected", as.character(count_rejected))
      shinyjs::html("stat_uncertain", as.character(count_uncertain))
      shinyjs::html("stat_not_evaluated", as.character(count_not_evaluated))

      # Update checkbox counts
      shinyjs::html("export_count_approved", sprintf("[%d]", count_approved))
      shinyjs::html("export_count_rejected", sprintf("[%d]", count_rejected))
      shinyjs::html("export_count_uncertain", sprintf("[%d]", count_uncertain))
      shinyjs::html("export_count_not_evaluated", sprintf("[%d]", count_not_evaluated))

      # Reset checkboxes to defaults
      updateCheckboxInput(session, "export_include_approved", value = TRUE)
      updateCheckboxInput(session, "export_include_rejected", value = FALSE)
      updateCheckboxInput(session, "export_include_uncertain", value = FALSE)
      updateCheckboxInput(session, "export_include_not_evaluated", value = FALSE)

      # Reset radio buttons via JavaScript
      shinyjs::runjs(sprintf("
        document.getElementById('%s').checked = true;
        document.getElementById('%s').checked = false;
        document.getElementById('%s').checked = true;
        document.getElementById('%s').checked = false;
        document.getElementById('%s').checked = false;
        $('#%s').show();
        Shiny.setInputValue('%s', 'source_to_concept_map', {priority: 'event'});
        Shiny.setInputValue('%s', 'all', {priority: 'event'});
      ",
        ns("export_format_stcm"),
        ns("export_format_usagi"),
        ns("approved_filter_all"),
        ns("approved_filter_majority"),
        ns("approved_filter_no_rejection"),
        ns("approved_sub_options"),
        ns("export_format_value"),
        ns("approved_filter_value")
      ))

      # Show modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("export_modal")))
    }, ignoreInit = TRUE)

    ### Export - Toggle Approved Sub-options ----
    observe_event(input$export_include_approved, {
      if (isTRUE(input$export_include_approved)) {
        shinyjs::show("approved_sub_options")
      } else {
        shinyjs::hide("approved_sub_options")
      }
      # Trigger count update
      shinyjs::runjs(sprintf(
        "var filter = $('input[name=\"%s\"]:checked').val() || 'all';
         Shiny.setInputValue('%s', filter, {priority: 'event'});",
        ns("approved_filter"),
        ns("approved_filter_value")
      ))
    }, ignoreInit = TRUE)

    ### Export - Listen to Approved Filter Radio Changes ----
    # Add JavaScript event listener for radio button changes and calculate initial total
    observe_event(export_stats(), {
      stats <- export_stats()
      if (is.null(stats)) return()

      # Calculate initial total (approved checkbox is TRUE by default, filter is "all")
      initial_total <- stats$approved
      shinyjs::html("export_total_count", as.character(initial_total))

      # When modal opens, set up listeners for radio buttons
      shinyjs::runjs(sprintf("
        $('input[name=\"%s\"]').off('change.export').on('change.export', function() {
          Shiny.setInputValue('%s', $(this).val(), {priority: 'event'});
        });
        $('input[name=\"%s\"]').off('change.export').on('change.export', function() {
          Shiny.setInputValue('%s', $(this).val(), {priority: 'event'});
        });
      ",
        ns("approved_filter"),
        ns("approved_filter_value"),
        ns("export_format"),
        ns("export_format_value")
      ))
    }, ignoreInit = TRUE)

    ### Export - Show/Hide Filter Section Based on Format ----
    observe_event(input$export_format_value, {
      if (is.null(input$export_format_value)) return()

      if (input$export_format_value == "indicate") {
        shinyjs::hide("mapping_filter_section")
      } else {
        shinyjs::show("mapping_filter_section")
      }
    }, ignoreInit = TRUE)

    ### Export - Update Total Count ----
    # Listen to checkbox changes and trigger recalculation
    observe_event(c(
      input$export_include_approved,
      input$export_include_rejected,
      input$export_include_uncertain,
      input$export_include_not_evaluated
    ), {
      # Trigger JS to send current approved_filter value
      shinyjs::runjs(sprintf(
        "var filter = $('input[name=\"%s\"]:checked').val() || 'all';
         Shiny.setInputValue('%s', filter, {priority: 'event'});",
        ns("approved_filter"),
        ns("approved_filter_value")
      ))
    }, ignoreInit = TRUE)

    # Also listen to radio button changes via JS
    observe_event(input$approved_filter_value, {
      stats <- export_stats()
      if (is.null(stats)) return()

      mappings_data <- stats$mappings_data
      approved_filter <- input$approved_filter_value

      # Filter approved mappings based on sub-option
      approved_mappings <- if (isTRUE(input$export_include_approved)) {
        base_approved <- mappings_data %>% dplyr::filter(approval_count > 0)

        if (approved_filter == "majority") {
          base_approved %>% dplyr::filter(approval_count > rejection_count)
        } else if (approved_filter == "no_rejection") {
          base_approved %>% dplyr::filter(rejection_count == 0)
        } else {
          base_approved
        }
      } else {
        mappings_data %>% dplyr::filter(FALSE)
      }

      # Filter other categories
      rejected_mappings <- if (isTRUE(input$export_include_rejected)) {
        mappings_data %>% dplyr::filter(rejection_count > 0 & approval_count == 0)
      } else {
        mappings_data %>% dplyr::filter(FALSE)
      }

      uncertain_mappings <- if (isTRUE(input$export_include_uncertain)) {
        mappings_data %>% dplyr::filter(uncertain_count > 0 & approval_count == 0 & rejection_count == 0)
      } else {
        mappings_data %>% dplyr::filter(FALSE)
      }

      not_evaluated_mappings <- if (isTRUE(input$export_include_not_evaluated)) {
        mappings_data %>% dplyr::filter(total_evaluations == 0)
      } else {
        mappings_data %>% dplyr::filter(FALSE)
      }

      # Combine all selected mappings
      selected_mapping_ids <- unique(c(
        approved_mappings$mapping_id,
        rejected_mappings$mapping_id,
        uncertain_mappings$mapping_id,
        not_evaluated_mappings$mapping_id
      ))

      total_to_export <- length(selected_mapping_ids)
      shinyjs::html("export_total_count", as.character(total_to_export))
    }, ignoreInit = TRUE)

    ### Export - Confirm Export ----
    observe_event(input$confirm_export, {
      alignment_id <- export_alignment_id()
      if (is.null(alignment_id)) return()

      stats <- export_stats()
      if (is.null(stats)) return()

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == !!alignment_id)

      if (nrow(alignment) == 0) return()

      file_id <- alignment$file_id[1]
      alignment_name <- alignment$name[1]

      # Get mappings to export based on criteria
      mappings_data <- stats$mappings_data
      approved_filter <- input$approved_filter_value

      # Filter approved mappings based on sub-option
      approved_mappings <- if (isTRUE(input$export_include_approved)) {
        base_approved <- mappings_data %>% dplyr::filter(approval_count > 0)

        if (!is.null(approved_filter) && approved_filter == "majority") {
          base_approved %>% dplyr::filter(approval_count > rejection_count)
        } else if (!is.null(approved_filter) && approved_filter == "no_rejection") {
          base_approved %>% dplyr::filter(rejection_count == 0)
        } else {
          base_approved
        }
      } else {
        mappings_data %>% dplyr::filter(FALSE)
      }

      # Filter other categories
      rejected_mappings <- if (isTRUE(input$export_include_rejected)) {
        mappings_data %>% dplyr::filter(rejection_count > 0 & approval_count == 0)
      } else {
        mappings_data %>% dplyr::filter(FALSE)
      }

      uncertain_mappings <- if (isTRUE(input$export_include_uncertain)) {
        mappings_data %>% dplyr::filter(uncertain_count > 0 & approval_count == 0 & rejection_count == 0)
      } else {
        mappings_data %>% dplyr::filter(FALSE)
      }

      not_evaluated_mappings <- if (isTRUE(input$export_include_not_evaluated)) {
        mappings_data %>% dplyr::filter(total_evaluations == 0)
      } else {
        mappings_data %>% dplyr::filter(FALSE)
      }

      # Combine all selected mappings (use bind_rows to keep full data)
      selected_mappings <- dplyr::bind_rows(
        approved_mappings,
        rejected_mappings,
        uncertain_mappings,
        not_evaluated_mappings
      ) %>% dplyr::distinct(mapping_id, .keep_all = TRUE)

      # Get full mapping data from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")
      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      mapping_ids <- selected_mappings$mapping_id

      # Get mapping details
      mappings_full <- DBI::dbGetQuery(
        con,
        sprintf(
          "SELECT * FROM concept_mappings WHERE mapping_id IN (%s)",
          paste(mapping_ids, collapse = ",")
        )
      )

      # Read source CSV for concept names
      mapping_dir <- get_app_dir("concept_mapping")
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
      source_df <- NULL
      if (file.exists(csv_path)) {
        source_df <- read.csv(csv_path, stringsAsFactors = FALSE)
      }

      # Get vocabulary data
      vocab_data <- vocabularies()

      # Get format value (default to source_to_concept_map if not yet set)
      export_format <- if (!is.null(input$export_format_value)) input$export_format_value else "source_to_concept_map"

      # Generate safe filename
      safe_name <- gsub("[^a-zA-Z0-9_-]", "_", alignment_name)
      timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")

      if (export_format == "indicate") {
        # Export in INDICATE Data Dictionary format (ZIP)
        alignment_desc <- alignment$description[1]
        if (is.na(alignment_desc)) alignment_desc <- ""

        tryCatch({
          zip_path <- export_indicate_format(
            alignment_id = alignment_id,
            alignment_name = alignment_name,
            alignment_description = alignment_desc,
            current_user = current_user(),
            db_path = db_path,
            mapping_dir = mapping_dir
          )

          filename <- paste0(safe_name, "_indicate_alignment_", timestamp, ".zip")

          # Read ZIP file and encode
          zip_content <- readBin(zip_path, "raw", file.info(zip_path)$size)
          zip_encoded <- base64enc::base64encode(zip_content)
          unlink(zip_path)

          download_js <- sprintf(
            "var link = document.createElement('a');
             link.href = 'data:application/zip;base64,%s';
             link.download = '%s';
             link.click();",
            zip_encoded,
            filename
          )

          shinyjs::runjs(download_js)

          # Hide modal
          shinyjs::runjs(sprintf("$('#%s').hide();", ns("export_modal")))

          showNotification(
            i18n$t("export_successful_indicate"),
            type = "message"
          )
        }, error = function(e) {
          showNotification(
            paste(i18n$t("export_error"), e$message),
            type = "error"
          )
        })

        return()
      }

      # For CSV formats, filter mappings
      if (nrow(selected_mappings) == 0) {
        showNotification(i18n$t("no_mappings_to_export"), type = "warning")
        return()
      }

      if (export_format == "usagi") {
        # Export in Usagi format
        export_data <- export_usagi_format(
          mappings_full, selected_mappings, source_df, vocab_data, alignment_name, current_user(), i18n
        )
        filename_suffix <- "usagi"
      } else {
        # Export in SOURCE_TO_CONCEPT_MAP format
        export_data <- export_source_to_concept_map_format(
          mappings_full, source_df, vocab_data
        )
        filename_suffix <- "source_to_concept_map"
      }

      filename <- paste0(safe_name, "_", filename_suffix, "_", timestamp, ".csv")

      temp_csv <- tempfile(fileext = ".csv")
      write.csv(export_data, temp_csv, row.names = FALSE, quote = TRUE, na = "")
      csv_content <- paste(readLines(temp_csv, warn = FALSE), collapse = "\n")
      unlink(temp_csv)

      csv_encoded <- base64enc::base64encode(charToRaw(csv_content))
      download_js <- sprintf(
        "var link = document.createElement('a');
         link.href = 'data:text/csv;base64,%s';
         link.download = '%s';
         link.click();",
        csv_encoded,
        filename
      )

      shinyjs::runjs(download_js)

      # Hide modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("export_modal")))
    }, ignoreInit = TRUE)

    ## 4) Server - Alignment Detail View ----
    ### Helper Functions - View Renderers ----
    
    
    # Function to enrich data with target concept information (OMOP and custom)
    enrich_target_concepts <- function(enriched_data, vocabularies_data, data_obj) {
      # Enrich OMOP concepts
      vocab_data <- vocabularies_data
      if (!is.null(vocab_data)) {
        omop_rows <- enriched_data %>% dplyr::filter(!is.na(target_omop_concept_id))
        if (nrow(omop_rows) > 0) {
          concept_ids <- omop_rows$target_omop_concept_id
          omop_concepts <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% concept_ids) %>%
            dplyr::select(
              concept_id,
              concept_name_target = concept_name,
              vocabulary_id_target = vocabulary_id,
              concept_code_target = concept_code
            ) %>%
            dplyr::collect()
          
          enriched_data <- enriched_data %>%
            dplyr::left_join(
              omop_concepts,
              by = c("target_omop_concept_id" = "concept_id")
            )
        } else {
          enriched_data <- enriched_data %>%
            dplyr::mutate(
              concept_name_target = NA_character_,
              vocabulary_id_target = NA_character_,
              concept_code_target = NA_character_
            )
        }
      } else {
        enriched_data <- enriched_data %>%
          dplyr::mutate(
            concept_name_target = NA_character_,
            vocabulary_id_target = NA_character_,
            concept_code_target = NA_character_
          )
      }
      
      # Enrich custom concepts
      custom_concepts_path <- get_csv_path("custom_concepts.csv")
      if (file.exists(custom_concepts_path)) {
        custom_rows <- enriched_data %>% dplyr::filter(!is.na(target_custom_concept_id))
        if (nrow(custom_rows) > 0) {
          custom_concepts_all <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
          custom_concept_ids <- custom_rows$target_custom_concept_id
          
          custom_concepts_info <- custom_concepts_all %>%
            dplyr::filter(custom_concept_id %in% custom_concept_ids) %>%
            dplyr::select(
              custom_concept_id,
              concept_name_custom = concept_name,
              vocabulary_id_custom = vocabulary_id,
              concept_code_custom = concept_code
            )
          
          # For custom concepts, fill in the target columns
          enriched_data <- enriched_data %>%
            dplyr::left_join(
              custom_concepts_info,
              by = c("target_custom_concept_id" = "custom_concept_id")
            ) %>%
            dplyr::mutate(
              concept_name_target = ifelse(is.na(concept_name_target), concept_name_custom, concept_name_target),
              vocabulary_id_target = ifelse(is.na(vocabulary_id_target), vocabulary_id_custom, vocabulary_id_target),
              concept_code_target = ifelse(is.na(concept_code_target), concept_code_custom, concept_code_target)
            ) %>%
            dplyr::select(-concept_name_custom, -vocabulary_id_custom, -concept_code_custom)
        }
      }
      
      return(enriched_data)
    }
    
    render_alignments_view <- function() {
      # Check permissions for buttons
      can_add <- user_has_permission("alignments", "add_alignment")
      can_import <- user_has_permission("alignments", "import_alignment")

      # Build buttons list based on permissions
      buttons <- tagList()
      if (can_add) {
        buttons <- tagList(
          buttons,
          actionButton(
            ns("add_alignment"),
            i18n$t("add_alignment"),
            class = "btn-success-custom",
            icon = icon("plus")
          )
        )
      }
      if (can_import) {
        buttons <- tagList(
          buttons,
          actionButton(
            ns("open_import_indicate_modal"),
            i18n$t("import_indicate_format"),
            class = "btn-primary-custom",
            icon = icon("file-import")
          )
        )
      }

      tags$div(
        class = "flex-column-full",
        tags$div(
          class = "breadcrumb-nav",
          style = "padding: 10px 0 15px 12px; display: flex; align-items: center; gap: 15px; justify-content: space-between;",
          tags$div(
            class = "section-title",
            "Concept Mappings"
          ),
          tags$div(
            class = "flex-gap-10",
            buttons
          )
        ),
        tags$div(
          class = "card-container",
          style = "padding: 20px; flex: 1; min-height: 0; overflow: auto; margin: 0 10px 10px 10px;",
          DT::DTOutput(ns("alignments_table"))
        )
      )
    }

    render_mapping_view <- function() {
      tags$div(
        class = "panel-container-full",
        style = "display: flex; flex-direction: column; height: 100%;",

        # Summary panel
        tags$div(
          id = ns("panel_summary"),
          class = "flex-column-full",
          uiOutput(ns("summary_content"))
        ),

        # All Mappings panel
        tags$div(
          id = ns("panel_all_mappings"),
          style = "height: 100%; min-height: 0; display: none; flex-direction: column; padding: 10px;",
          tags$div(
            class = "card-container card-container-flex",
            style = "flex: 1; min-height: 0; display: flex; flex-direction: column;",
            # Header with delete button
            tags$div(
              style = "display: flex; justify-content: flex-end; align-items: center; padding: 10px 10px 0 10px; flex-shrink: 0;",
              actionButton(
                ns("delete_selected_mappings"),
                label = tagList(
                  tags$i(class = "fas fa-trash mr-6"),
                  i18n$t("delete_selected")
                ),
                class = "btn-danger-custom",
                style = "display: none;"
              )
            ),
            tags$div(
              class = "flex-scroll-container",
              DT::DTOutput(ns("all_mappings_table_main"), height = "100%")
            )
          )
        ),

        # Edit Mappings panel
        tags$div(
          id = ns("panel_edit_mappings"),
          style = "display: none; height: 100%; min-height: 0; margin: 0 10px;",
          tags$div(
            style = "height: 100%; display: flex; gap: 15px; min-height: 0;",
            # Left column: Source Concepts (top) + Concept Details (bottom)
            tags$div(
              style = "flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 15px;",
              # Top-left: Source Concepts table
              tags$div(
                class = "card-container card-container-flex",
                style = "flex: 1; min-height: 0;",
                tags$div(
                  class = "section-header",
                  tags$div(
                    class = "flex-1",
                    tags$h4(
                      style = "margin: 0;",
                      i18n$t("source_concepts"),
                      tags$span(
                        class = "info-icon",
                        `data-tooltip` = "Concepts from your uploaded CSV file to be mapped to INDICATE concepts",
                        "ⓘ"
                      )
                    )
                  ),
                  actionButton(
                    ns("add_mapping_from_general"),
                    "Add Mapping",
                    class = "btn-success-custom",
                    icon = icon("plus"),
                    style = "height: 32px; padding: 5px 15px; font-size: 14px; margin-right: 8px; display: none;"
                  )
                ),
                tags$div(
                  class = "flex-scroll-container",
                  style = "position: relative;",
                  fuzzy_search_ui("source_concepts_fuzzy_search", ns = ns, i18n = i18n),
                  DT::DTOutput(ns("source_concepts_table"))
                )
              ),
              # Bottom-left: Concept Details with tabs for JSON visualization
              tags$div(
                id = ns("concept_details_panel"),
                class = "card-container card-container-flex",
                style = "flex: 1; min-height: 0; display: none;",
                tags$div(
                  class = "section-header",
                  style = "margin-bottom: 0;",
                  tags$h4(style = "margin: 0;", i18n$t("source_concept_details")),
                  actionButton(
                    ns("view_source_json"),
                    label = NULL,
                    icon = icon("code"),
                    class = "btn-icon-only has-tooltip",
                    style = paste0(
                      "background: transparent; border: none; color: #333; ",
                      "padding: 4px 7px; cursor: pointer; font-size: 12px; ",
                      "margin-left: auto;"
                    ),
                    `data-tooltip` = i18n$t("view_raw_json")
                  )
                ),
                tags$div(
                  style = "flex: 1; min-height: 0; overflow: auto; padding: 0 10px 10px 10px;",
                  # Tabs for different JSON views
                  tags$div(
                    style = "display: flex; gap: 5px; margin-bottom: 10px;",
                    tags$button(
                      id = ns("detail_tab_summary"),
                      class = "tab-btn tab-btn-active",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'summary', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("summary")
                    ),
                    tags$button(
                      id = ns("detail_tab_distribution"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'distribution', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("distribution")
                    ),
                    tags$button(
                      id = ns("detail_tab_temporal"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'temporal', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("temporal")
                    ),
                    tags$button(
                      id = ns("detail_tab_units"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'units', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("hospital_units")
                    ),
                    tags$button(
                      id = ns("detail_tab_other"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'other', {priority: 'event'});
                      ", ns("concept_details_panel"), ns("detail_tab_selected")),
                      i18n$t("other")
                    )
                  ),
                  # Content area for selected tab
                  uiOutput(ns("concept_details_content"))
                )
              )
            ),
            # Right column: General Concepts (top) + Target Concept Details (bottom)
            tags$div(
              style = "flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 10px;",
              # Top-right: General Concepts table
              tags$div(
                id = ns("general_concepts_panel"),
                class = "card-container card-container-flex",
                style = "flex: 1; min-height: 0;",
                uiOutput(ns("general_concepts_header")),
                tags$div(
                  class = "flex-scroll-container",
                  tags$div(
                    id = ns("general_concepts_table_container"),
                    style = "height: 100%; position: relative;",
                    fuzzy_search_ui(
                      id = "general_concepts_fuzzy_search",
                      ns = ns,
                      i18n = i18n
                    ),
                    DT::DTOutput(ns("general_concepts_table"))
                  ),
                  tags$div(
                    id = ns("concept_mappings_table_container"),
                    style = "height: 100%; display: none; position: relative;",
                    fuzzy_search_ui(
                      "concept_mappings_fuzzy_search",
                      ns = ns,
                      i18n = i18n,
                      settings_btn = TRUE,
                      settings_btn_id = "omop_filters_btn",
                      limit_checkbox = TRUE,
                      limit_checkbox_id = "concept_mappings_limit_10k",
                      initially_visible = FALSE
                    ),
                    DT::DTOutput(ns("concept_mappings_table"))
                  )
                )
              ),
              # Bottom-right: Target Concept Details with tabs in header (no gray background)
              tags$div(
                id = ns("target_concept_details_panel"),
                class = "card-container card-container-flex",
                style = "flex: 1; min-height: 0; display: none;",
                tags$div(
                  class = "section-header",
                  style = "position: relative;",
                  tags$h4(
                    style = "margin: 0;",
                    "Target Concept Details",
                    tags$span(
                      class = "info-icon",
                      `data-tooltip` = "Details of the selected target concept from the dictionary",
                      "ⓘ"
                    )
                  ),
                  # Main tabs: Summary + Statistical Summary (top-right)
                  tags$div(
                    class = "section-tabs",
                    tags$button(
                      id = ns("target_detail_tab_summary"),
                      class = "tab-btn tab-btn-active",
                      onclick = sprintf("
                        document.querySelectorAll('#%s > .section-header > .section-tabs .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'summary', {priority: 'event'});
                      ", ns("target_concept_details_panel"), ns("target_detail_tab_selected")),
                      i18n$t("summary")
                    ),
                    tags$button(
                      id = ns("target_detail_tab_statistical_summary"),
                      class = "tab-btn",
                      onclick = sprintf("
                        document.querySelectorAll('#%s > .section-header > .section-tabs .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                        this.classList.add('tab-btn-active');
                        Shiny.setInputValue('%s', 'statistical_summary', {priority: 'event'});
                      ", ns("target_concept_details_panel"), ns("target_detail_tab_selected")),
                      i18n$t("statistical_summary")
                    )
                  )
                ),
                tags$div(
                  class = "flex-scroll-container",
                  uiOutput(ns("target_concept_details_content"))
                )
              )
            )
          )
        ),

        # Import Mappings panel
        tags$div(
          id = ns("panel_import_mappings"),
          class = "import-mappings-panel",
          style = "margin: 0 10px 10px 10px; height: calc(100% - 10px); min-height: 0; display: none; flex-direction: column;",

          # Import widget
          tags$div(
            class = "card-container",
            style = "height: 50%; overflow: auto; padding: 20px;",
            # Header with title
            tags$h4(style = "margin-bottom: 15px; color: #0f60af;", i18n$t("import_mappings")),

            # Format selector and file input row
            tags$div(
              style = "display: flex; align-items: flex-start; gap: 20px; flex-wrap: wrap;",

              # Format dropdown
              tags$div(
                style = "flex: 0 0 280px;",
                tags$label(
                  style = "display: block; margin-bottom: 5px; font-weight: 500;",
                  i18n$t("import_format")
                ),
                selectInput(
                  ns("import_format"),
                  label = NULL,
                  choices = stats::setNames(
                    c("csv", "stcm", "usagi", "indicate"),
                    c(i18n$t("import_format_csv"), i18n$t("import_format_stcm"),
                      i18n$t("import_format_usagi"), i18n$t("import_format_indicate"))
                  ),
                  selected = "csv",
                  width = "100%"
                )
              ),

              # File input container (changes based on format)
              tags$div(
                id = ns("import_file_container"),
                style = "flex: 0 0 300px;",
                # CSV file input (default)
                tags$div(
                  id = ns("import_csv_input_wrapper"),
                  fileInput(
                    ns("import_file_input"),
                    label = i18n$t("select_csv_file"),
                    accept = c(".csv"),
                    width = "100%"
                  )
                ),
                # ZIP file input (for INDICATE format)
                tags$div(
                  id = ns("import_zip_input_wrapper"),
                  style = "display: none;",
                  fileInput(
                    ns("import_zip_file_input"),
                    label = i18n$t("select_zip_file"),
                    accept = c(".zip"),
                    width = "100%"
                  )
                )
              ),

              # Import button
              tags$div(
                style = "position: relative; top: 24px;",
                actionButton(
                  ns("do_import_mappings"),
                  i18n$t("import_mappings"),
                  class = "btn-primary-custom",
                  icon = icon("file-import")
                )
              )
            ),

            # Validation status message
            tags$div(
              id = ns("import_validation_status"),
              style = "display: none;"
            )
          ),

          # Import History widget
          tags$div(
            class = "card-container",
            style = "margin-top: 10px; height: calc(50% - 10px); overflow: auto; padding: 20px;",
            tags$h4(style = "margin-bottom: 15px; color: #0f60af;", i18n$t("import_history")),
            DT::DTOutput(ns("import_history_table"))
          )
        ),

        # Evaluate Mappings panel
        tags$div(
          id = ns("panel_evaluate_mappings"),
          style = "margin: 0 10px 10px 10px; height: calc(100% - 10px); min-height: 0; display: none; flex-direction: column; gap: 10px;",
          # Top: Mappings table
          tags$div(
            class = "card-container",
            class = "flex-scroll-container",
            DT::DTOutput(ns("evaluate_mappings_table"))
          ),
          # Bottom: Source and Target Concept Details side by side
          tags$div(
            id = ns("eval_details_container"),
            style = "display: none; flex-direction: row; gap: 10px; flex: 1; min-height: 0;",
            # Left: Source Concept Details
            tags$div(
              id = ns("eval_source_concept_details_panel"),
              class = "card-container card-container-flex",
              style = "flex: 1; min-width: 0;",
              tags$div(
                class = "section-header",
                style = "margin-bottom: 0;",
                tags$h4(style = "margin: 0;", i18n$t("source_concept_details")),
                actionButton(
                  ns("view_eval_source_json"),
                  label = NULL,
                  icon = icon("code"),
                  class = "btn-icon-only has-tooltip",
                  style = paste0(
                    "background: transparent; border: none; color: #333; ",
                    "padding: 4px 7px; cursor: pointer; font-size: 12px; ",
                    "margin-left: auto;"
                  ),
                  `data-tooltip` = i18n$t("view_raw_json")
                )
              ),
              tags$div(
                style = "flex: 1; min-height: 0; overflow: auto; padding: 0 10px 10px 10px;",
                # Tabs for different views
                tags$div(
                  style = "display: flex; gap: 5px; margin-bottom: 10px;",
                  tags$button(
                    id = ns("eval_source_tab_summary"),
                    class = "tab-btn tab-btn-active",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'summary', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("summary")
                  ),
                  tags$button(
                    id = ns("eval_source_tab_distribution"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'distribution', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("distribution")
                  ),
                  tags$button(
                    id = ns("eval_source_tab_temporal"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'temporal', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("temporal")
                  ),
                  tags$button(
                    id = ns("eval_source_tab_units"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'units', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("hospital_units")
                  ),
                  tags$button(
                    id = ns("eval_source_tab_other"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'other', {priority: 'event'});
                    ", ns("eval_source_concept_details_panel"), ns("eval_source_tab_selected")),
                    i18n$t("other")
                  )
                ),
                # Content area for selected tab
                uiOutput(ns("eval_source_concept_details_content"))
              )
            ),
            # Right: Target Concept Details (matching Edit Mappings structure)
            tags$div(
              id = ns("eval_target_concept_details_panel"),
              class = "card-container card-container-flex",
              style = "flex: 1; min-width: 0;",
              tags$div(
                class = "section-header",
                style = "position: relative;",
                tags$h4(
                  style = "margin: 0;",
                  "Target Concept Details",
                  tags$span(
                    class = "info-icon",
                    `data-tooltip` = "Details of the selected target concept from the dictionary",
                    "ⓘ"
                  )
                ),
                # Main tabs: Summary + Comments + Statistical Summary (top-right)
                tags$div(
                  class = "section-tabs",
                  tags$button(
                    id = ns("eval_target_detail_tab_summary"),
                    class = "tab-btn tab-btn-active",
                    onclick = sprintf("
                      document.querySelectorAll('#%s > .section-header > .section-tabs .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'summary', {priority: 'event'});
                    ", ns("eval_target_concept_details_panel"), ns("eval_target_detail_tab_selected")),
                    i18n$t("summary")
                  ),
                  tags$button(
                    id = ns("eval_target_detail_tab_comments"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s > .section-header > .section-tabs .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'comments', {priority: 'event'});
                    ", ns("eval_target_concept_details_panel"), ns("eval_target_detail_tab_selected")),
                    i18n$t("comments")
                  ),
                  tags$button(
                    id = ns("eval_target_detail_tab_statistical_summary"),
                    class = "tab-btn",
                    onclick = sprintf("
                      document.querySelectorAll('#%s > .section-header > .section-tabs .tab-btn').forEach(b => b.classList.remove('tab-btn-active'));
                      this.classList.add('tab-btn-active');
                      Shiny.setInputValue('%s', 'statistical_summary', {priority: 'event'});
                    ", ns("eval_target_concept_details_panel"), ns("eval_target_detail_tab_selected")),
                    i18n$t("statistical_summary")
                  )
                )
              ),
              tags$div(
                class = "flex-scroll-container",
                uiOutput(ns("eval_target_concept_details_content"))
              )
            )
          )
        )
      )
    }

    render_mapped_concepts_view <- function() {
      tags$div(
        class = "panel-container-full",
        style = "display: flex; flex-direction: column; height: 100%;",
        tags$div(
          style = "height: 70%; display: flex; gap: 15px; min-height: 0;",
          tags$div(
            class = "card-container card-container-flex",
            tags$div(
              class = "section-header",

              tags$h4(
                i18n$t("source_concepts"),
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = "Concepts from your uploaded CSV file to be mapped to INDICATE concepts",
                  "ⓘ"
                )
              )
            ),
            tags$div(
              class = "flex-scroll-container",
              DT::DTOutput(ns("source_concepts_table_mapped"))
            )
          ),
          tags$div(
            class = "card-container card-container-flex",
            tags$div(
              class = "section-header",
              style = "height: 40px; display: flex; justify-content: space-between; align-items: center;",
              tags$h4(
                style = "margin: 0;",
                i18n$t("mapped_concepts"),
                tags$span(
                  class = "info-icon",
                  `data-tooltip` = i18n$t("mapped_concepts_tooltip"),
                  "ⓘ"
                )
              ),
              actionButton(
                ns("add_mapping_specific"),
                "Add Mapping",
                class = "btn-success-custom",
                icon = icon("plus"),
                style = "height: 32px; padding: 5px 15px; font-size: 14px; display: none;"
              )
            ),
            tags$div(
              class = "flex-scroll-container",
              DT::DTOutput(ns("mapped_concepts_table"))
            )
          )
        ),
        tags$div(
          class = "card-container",
          style = "height: 30%; display: flex; flex-direction: column; margin-top: 15px;",
          tags$div(
            class = "section-header",

            tags$h4(
              "Completed Mappings",
              tags$span(
                class = "info-icon",
                `data-tooltip` = "Mappings between your source concepts and INDICATE concepts that you have created",
                "ⓘ"
              )
            )
          ),
          tags$div(
            class = "flex-scroll-container",
            DT::DTOutput(ns("realized_mappings_table_mapped"))
          )
        )
      )
    }
    
    

    ### General Concepts Header Rendering ----
    output$general_concepts_header <- renderUI({
      # Only show in mapping view with general view
      if (current_view() != "mapping" || mapping_view() != "general") return(NULL)

      # Case 1: Show all OMOP concepts (not filtered by general concept)
      if (show_all_omop_concepts()) {
        return(tags$div(
          class = "section-header",
          tags$div(
            class = "flex-1",
            tags$a(
              class = "breadcrumb-link",
              style = "cursor: pointer;",
              onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_general_list")),
              i18n$t("general_concepts")
            ),
            tags$span(style = "color: #6c757d; margin: 0 8px;", ">"),
            tags$span(i18n$t("all_omop_concepts"))
          )
        ))
      }

      # Case 2: No general concept selected - show title with "See all OMOP concepts" button
      if (is.null(selected_general_concept_id())) {
        return(tags$div(
          class = "section-header",
          tags$div(
            class = "flex-1",
            tags$h4(
              style = "display: inline;",
              i18n$t("general_concepts"),
              tags$span(
                class = "info-icon",
                `data-tooltip` = i18n$t("general_concepts_tooltip"),
                "ⓘ"
              )
            )
          ),
          tags$button(
            type = "button",
            class = "btn btn-sm btn-success-custom",
            style = "display: flex; align-items: center; gap: 4px; height: 28px;",
            onclick = sprintf("Shiny.setInputValue('%s', Math.random(), {priority: 'event'})", ns("show_all_omop_click")),
            i18n$t("see_all_omop_concepts")
          )
        ))
      }

      # Case 3: General concept selected - show breadcrumb with Comments button
      if (is.null(data())) return()

      # Get the general concept name
      general_concepts <- data()$general_concepts
      selected_concept <- general_concepts[general_concepts$general_concept_id == selected_general_concept_id(), ]

      if (nrow(selected_concept) > 0) {
        concept_name <- selected_concept$general_concept_name[1]
      } else {
        concept_name <- "Unknown"
      }

      tags$div(
        class = "section-header",
        tags$div(
          class = "flex-1",
          tags$a(
            class = "breadcrumb-link",
            style = "cursor: pointer;",
            onclick = sprintf("Shiny.setInputValue('%s', true, {priority: 'event'})", ns("back_to_general_list")),
            i18n$t("general_concepts")
          ),
          tags$span(style = "color: #6c757d; margin: 0 8px;", ">"),
          tags$span(concept_name)
        ),
        tags$div(
          style = "display: flex; gap: 8px;",
          tags$button(
            type = "button",
            class = "btn btn-sm btn-primary-custom",
            style = "display: flex; align-items: center; gap: 4px; margin-right: 8px;",
            onclick = sprintf("Shiny.setInputValue('%s', Math.random(), {priority: 'event'})", ns("open_comments_modal_click")),
            tags$i(class = "fa fa-comment"),
            i18n$t("comments")
          )
        )
      )
    })

    ### a) Summary Tab ----
    #### Summary Content Rendering ----
    observe_event(summary_content_trigger(), {
      if (is.null(selected_alignment_id())) {
        output$summary_content <- renderUI({
          tags$div("No alignment selected")
        })
        return()
      }

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) {
        output$summary_content <- renderUI({
          tags$div("No alignment selected")
        })
        return()
      }

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      mapping_dir <- get_app_dir("concept_mapping")
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Get database path
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        output$summary_content <- renderUI({
          tags$div("Database not found")
        })
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get total source concepts from CSV (if exists)
      total_source_concepts <- 0
      if (file.exists(csv_path)) {
        df <- read.csv(csv_path, stringsAsFactors = FALSE)
        total_source_concepts <- nrow(df)
      }

      # Count unique source concepts that have mappings (includes both manual and imported)
      mappings_query <- "
        SELECT COUNT(DISTINCT row_id) as unique_source_concepts
        FROM concept_mappings
        WHERE alignment_id = ?
      "
      mappings_result <- DBI::dbGetQuery(con, mappings_query, params = list(selected_alignment_id()))
      mapped_source_concepts <- mappings_result$unique_source_concepts[1]

      pct_mapped_source <- if (total_source_concepts > 0) {
        round((mapped_source_concepts / total_source_concepts) * 100, 1)
      } else {
        0
      }

      # Get all general concepts mapped from database
      # First get all mappings with their target IDs
      all_mappings_query <- "
        SELECT DISTINCT target_general_concept_id, target_omop_concept_id
        FROM concept_mappings
        WHERE alignment_id = ?
      "
      all_mappings <- DBI::dbGetQuery(con, all_mappings_query, params = list(selected_alignment_id()))

      # For mappings with target_general_concept_id, use it directly
      direct_general_ids <- all_mappings$target_general_concept_id[!is.na(all_mappings$target_general_concept_id)]

      # For imported mappings (target_general_concept_id is NULL but target_omop_concept_id is set),
      # look up the general concept from the dictionary data
      imported_omop_ids <- all_mappings$target_omop_concept_id[
        is.na(all_mappings$target_general_concept_id) & !is.na(all_mappings$target_omop_concept_id)
      ]

      # Look up general concepts from dictionary for imported OMOP concept IDs
      dictionary_mappings <- data()$concept_mappings
      if (!is.null(dictionary_mappings) && length(imported_omop_ids) > 0) {
        lookup_general_ids <- dictionary_mappings$general_concept_id[
          dictionary_mappings$omop_concept_id %in% imported_omop_ids
        ]
        lookup_general_ids <- unique(lookup_general_ids[!is.na(lookup_general_ids)])
      } else {
        lookup_general_ids <- integer(0)
      }

      # Combine both sources
      mapped_general_concept_ids <- unique(c(direct_general_ids, lookup_general_ids))
      total_general_concepts <- length(mapped_general_concept_ids)

      # Calculate percentage of dictionary coverage
      total_dictionary_concepts <- nrow(data()$general_concepts)
      pct_general_concepts <- if (total_dictionary_concepts > 0) {
        round((total_general_concepts / total_dictionary_concepts) * 100, 1)
      } else {
        0
      }

      # Count evaluated concepts (concepts with at least one evaluation)
      evaluated_query <- "
        SELECT COUNT(DISTINCT cm.mapping_id) as evaluated_count
        FROM concept_mappings cm
        INNER JOIN mapping_evaluations me ON cm.mapping_id = me.mapping_id
        WHERE cm.alignment_id = ?
      "
      evaluated_result <- DBI::dbGetQuery(con, evaluated_query, params = list(selected_alignment_id()))
      evaluated_count <- evaluated_result$evaluated_count[1]

      pct_evaluated <- if (mapped_source_concepts > 0) {
        round((evaluated_count / mapped_source_concepts) * 100, 1)
      } else {
        0
      }

      # Calculate category breakdown if category column exists in CSV
      category_data <- NULL
      has_category <- FALSE
      if (file.exists(csv_path)) {
        if ("category" %in% colnames(df)) {
          has_category <- TRUE

          # Ensure row_id exists for joining
          if (!"row_id" %in% colnames(df)) {
            df$row_id <- seq_len(nrow(df))
          }

          # Get mapped row_ids from database
          mapped_row_ids_query <- "SELECT DISTINCT row_id FROM concept_mappings WHERE alignment_id = ?"
          mapped_row_ids <- DBI::dbGetQuery(con, mapped_row_ids_query, params = list(selected_alignment_id()))$row_id

          # Count concepts per category (all source concepts)
          category_counts <- as.data.frame(table(df$category, useNA = "ifany"), stringsAsFactors = FALSE)
          colnames(category_counts) <- c("category", "total")
          rownames(category_counts) <- NULL

          # Replace NA with "Uncategorized"
          category_counts$category <- ifelse(
            is.na(category_counts$category) | category_counts$category == "",
            "Uncategorized",
            as.character(category_counts$category)
          )

          # Count mapped concepts per category
          df$is_mapped <- df$row_id %in% mapped_row_ids
          df$category_clean <- ifelse(
            is.na(df$category) | df$category == "",
            "Uncategorized",
            as.character(df$category)
          )

          mapped_by_category <- df %>%
            dplyr::filter(is_mapped) %>%
            dplyr::group_by(category_clean) %>%
            dplyr::summarise(mapped = dplyr::n(), .groups = "drop") %>%
            dplyr::rename(category = category_clean)

          # Join total and mapped counts
          category_data <- category_counts %>%
            dplyr::left_join(mapped_by_category, by = "category") %>%
            dplyr::mutate(mapped = ifelse(is.na(mapped), 0L, as.integer(mapped)))
          rownames(category_data) <- NULL

          # Sort by total count descending
          category_data <- category_data[order(-category_data$total), ]
          rownames(category_data) <- NULL
        }
      }

      # Render UI
      output$summary_content <- renderUI({
        tags$div(
          style = "height: 100%; min-height: 0; display: flex; flex-direction: column;",

          # Top section: Summary stats cards (percentage-based width)
          tags$div(
            style = "display: flex; flex-direction: row; padding: 10px; gap: 10px; flex-shrink: 0;",

            # Card 1: Mapped concepts in alignment (33%)
            tags$div(
              style = paste0(
                "flex: 1; min-width: 0; background: white; ",
                "border-radius: 8px; padding: 15px; ",
                "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                "border-left: 4px solid #28a745;"
              ),
              tags$div(
                style = "font-size: 13px; color: #666; margin-bottom: 6px;",
                i18n$t("mapped_concepts")
              ),
              tags$div(
                style = paste0(
                  "font-size: 24px; font-weight: 700; color: #28a745; ",
                  "margin-bottom: 4px;"
                ),
                paste0(mapped_source_concepts, " / ", total_source_concepts)
              ),
              tags$div(
                style = "font-size: 16px; color: #999;",
                paste0(pct_mapped_source, "%")
              )
            ),

            # Card 2: General concepts mapped (33%)
            tags$div(
              style = paste0(
                "flex: 1; min-width: 0; background: white; ",
                "border-radius: 8px; padding: 15px; ",
                "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                "border-left: 4px solid #17a2b8;"
              ),
              tags$div(
                style = "font-size: 13px; color: #666; margin-bottom: 6px;",
                i18n$t("general_concepts_mapped")
              ),
              tags$div(
                style = paste0(
                  "font-size: 24px; font-weight: 700; color: #17a2b8; ",
                  "margin-bottom: 4px;"
                ),
                paste0(total_general_concepts, " / ", total_dictionary_concepts)
              ),
              tags$div(
                style = "font-size: 16px; color: #999;",
                paste0(pct_general_concepts, "%")
              )
            ),

            # Card 3: Evaluated mappings (33%)
            tags$div(
              style = paste0(
                "flex: 1; min-width: 0; background: white; ",
                "border-radius: 8px; padding: 15px; ",
                "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                "border-left: 4px solid #ffc107;"
              ),
              tags$div(
                style = "font-size: 13px; color: #666; margin-bottom: 6px;",
                i18n$t("evaluated_mappings")
              ),
              tags$div(
                style = paste0(
                  "font-size: 24px; font-weight: 700; color: #ffc107; ",
                  "margin-bottom: 4px;"
                ),
                paste0(evaluated_count, " / ", mapped_source_concepts)
              ),
              tags$div(
                style = "font-size: 16px; color: #999;",
                paste0(pct_evaluated, "%")
              )
            )
          ),

          # Bottom section: Category Breakdown and Projects side by side (50% each)
          tags$div(
            style = "flex: 1; min-height: 0; display: flex; flex-direction: row; padding: 0 10px 10px 10px; gap: 10px;",

            # Left: Category Breakdown (50%)
            if (has_category && !is.null(category_data) && nrow(category_data) > 0) {
              tags$div(
                style = paste0(
                  "flex: 1; min-width: 0; display: flex; flex-direction: column; ",
                  "background: white; border-radius: 8px; padding: 15px; ",
                  "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                  "border-left: 4px solid #0f60af;"
                ),
                # Header with title, tab buttons, and fullscreen button
                tags$div(
                  style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;",
                  tags$div(
                    style = "font-size: 14px; color: #666;",
                    i18n$t("category_breakdown")
                  ),
                  tags$div(
                    class = "flex-center-gap-8",
                    # Tab buttons for distribution/completion
                    tags$div(
                      style = "display: flex; gap: 4px;",
                      tags$button(
                        id = ns("category_tab_distribution"),
                        class = "btn btn-sm category-tab-btn active",
                        style = paste0(
                          "padding: 4px 10px; font-size: 12px; border-radius: 4px; ",
                          "border: 1px solid #0f60af; background: #0f60af; color: white; cursor: pointer;"
                        ),
                        onclick = sprintf(
                          "document.getElementById('%s').style.display='block'; document.getElementById('%s').style.display='none'; this.style.background='#0f60af'; this.style.color='white'; document.getElementById('%s').style.background='white'; document.getElementById('%s').style.color='#28a745';",
                          ns("category_distribution_content"), ns("category_completion_content"),
                          ns("category_tab_completion"), ns("category_tab_completion")
                        ),
                        i18n$t("distribution")
                      ),
                      tags$button(
                        id = ns("category_tab_completion"),
                        class = "btn btn-sm category-tab-btn",
                        style = paste0(
                          "padding: 4px 10px; font-size: 12px; border-radius: 4px; ",
                          "border: 1px solid #28a745; background: white; color: #28a745; cursor: pointer;"
                        ),
                        onclick = sprintf(
                          "document.getElementById('%s').style.display='none'; document.getElementById('%s').style.display='block'; this.style.background='#28a745'; this.style.color='white'; document.getElementById('%s').style.background='white'; document.getElementById('%s').style.color='#0f60af';",
                          ns("category_distribution_content"), ns("category_completion_content"),
                          ns("category_tab_distribution"), ns("category_tab_distribution")
                        ),
                        i18n$t("completion")
                      )
                    ),
                    # Fullscreen button
                    actionButton(
                      ns("open_category_breakdown_fullscreen"),
                      label = NULL,
                      icon = icon("expand-alt"),
                      class = "btn-icon-only has-tooltip",
                      style = paste0(
                        "background: transparent; border: none; color: #333; ",
                        "padding: 4px 8px; cursor: pointer; font-size: 14px;"
                      ),
                      `data-tooltip` = i18n$t("view_fullscreen")
                    )
                  )
                ),
                # Distribution view (blue bars - concept count per category, with completion overlay)
                tags$div(
                  id = ns("category_distribution_content"),
                  style = "flex: 1; min-height: 0; overflow-y: auto;",
                  lapply(seq_len(nrow(category_data)), function(i) {
                    cat_name <- category_data$category[i]
                    cat_total <- category_data$total[i]
                    cat_mapped <- category_data$mapped[i]
                    pct_total <- round(cat_total / total_source_concepts * 100, 1)
                    pct_mapped_of_total <- if (cat_total > 0) round(cat_mapped / cat_total * 100, 1) else 0
                    tags$div(
                      style = "margin-bottom: 8px;",
                      tags$div(
                        style = "display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 2px;",
                        tags$span(
                          style = "max-width: 60%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;",
                          cat_name
                        ),
                        tags$span(
                          class = "text-secondary",
                          sprintf("%d (%s%%)", cat_total, pct_total)
                        )
                      ),
                      # Blue bar for distribution with hatched completion overlay
                      tags$div(
                        style = "background: #e9ecef; border-radius: 4px; height: 8px; overflow: hidden; position: relative;",
                        # Base blue bar (full distribution width)
                        tags$div(
                          style = sprintf(
                            "background: #0f60af; width: %s%%; height: 100%%; position: relative;",
                            pct_total
                          ),
                          # Hatched overlay for completed portion (relative to category bar width)
                          tags$div(
                            style = sprintf(
                              paste0(
                                "position: absolute; left: 0; top: 0; height: 100%%; width: %s%%; ",
                                "background: repeating-linear-gradient(",
                                "45deg, ",
                                "rgba(255,255,255,0.3), ",
                                "rgba(255,255,255,0.3) 2px, ",
                                "transparent 2px, ",
                                "transparent 4px",
                                ");"
                              ),
                              pct_mapped_of_total
                            )
                          )
                        )
                      )
                    )
                  })
                ),
                # Completion view (green bars - mapping completion per category, sorted by completion %)
                {
                  # Sort by completion percentage descending
                  category_data_by_completion <- category_data %>%
                    dplyr::mutate(pct_mapped = ifelse(total > 0, mapped / total * 100, 0)) %>%
                    dplyr::arrange(dplyr::desc(pct_mapped))

                  tags$div(
                    id = ns("category_completion_content"),
                    style = "flex: 1; min-height: 0; overflow-y: auto; display: none;",
                    lapply(seq_len(nrow(category_data_by_completion)), function(i) {
                      cat_name <- category_data_by_completion$category[i]
                      cat_total <- category_data_by_completion$total[i]
                      cat_mapped <- category_data_by_completion$mapped[i]
                      pct_mapped <- round(category_data_by_completion$pct_mapped[i], 1)
                      tags$div(
                        style = "margin-bottom: 8px;",
                        tags$div(
                          style = "display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 2px;",
                          tags$span(
                            style = "max-width: 60%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;",
                            cat_name
                          ),
                          tags$span(
                            class = "text-secondary",
                            sprintf("%d / %d (%s%%)", cat_mapped, cat_total, pct_mapped)
                          )
                        ),
                        # Green bar for completion (full bar = 100% mapped)
                        tags$div(
                          style = "background: #e9ecef; border-radius: 4px; height: 8px; overflow: hidden;",
                          tags$div(
                            style = sprintf(
                              "background: #28a745; width: %s%%; height: 100%%;",
                              pct_mapped
                            )
                          )
                        )
                      )
                    })
                  )
                }
              )
            },

            # Right: Projects Compatibility (50%)
            tags$div(
              style = paste0(
                "flex: 1; min-width: 0; display: flex; flex-direction: column; ",
                "background: white; border-radius: 8px; padding: 15px; ",
                "box-shadow: 0 2px 8px rgba(0,0,0,0.1); ",
                "border-left: 4px solid #0f60af;"
              ),
              tags$div(
                style = "font-size: 14px; color: #666; margin-bottom: 10px;",
                i18n$t("projects_compatibility")
              ),
              tags$div(
                class = "flex-scroll-container",
                DT::DTOutput(ns("projects_compatibility_table"))
              )
            )
          )
        )
      })
    })

    #### Projects Compatibility Table ----
    observe_event(projects_compatibility_table_trigger(), {
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()

      output$projects_compatibility_table <- DT::renderDT({
        # Get projects and concept assignments
        projects <- data()$projects
        general_concept_projects <- data()$general_concept_projects

        if (is.null(projects) || nrow(projects) == 0) {
          return(create_empty_datatable("No projects defined"))
        }

        # Get mapped general concepts from database
        db_path <- file.path(get_app_dir(), "indicate.db")
        mapped_general_concept_ids <- integer(0)

        if (file.exists(db_path)) {
          con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
          on.exit(DBI::dbDisconnect(con), add = TRUE)

          # Query mapped general concept IDs for this alignment
          query <- "SELECT DISTINCT target_general_concept_id FROM concept_mappings WHERE alignment_id = ? AND target_general_concept_id IS NOT NULL"
          result <- DBI::dbGetQuery(con, query, params = list(selected_alignment_id()))

          if (nrow(result) > 0) {
            mapped_general_concept_ids <- as.integer(result$target_general_concept_id)
          }
        }

        # Build project compatibility table
        uc_compat <- projects %>%
          dplyr::rowwise() %>%
          dplyr::mutate(
            total_concepts = {
              if (is.null(general_concept_projects)) {
                0L
              } else {
                current_uc_id <- project_id
                # Get unique general concept IDs for this project
                length(unique(general_concept_projects %>%
                  dplyr::filter(project_id == current_uc_id) %>%
                  dplyr::pull(general_concept_id)))
              }
            },
            mapped_concepts = {
              if (is.null(general_concept_projects)) {
                0L
              } else {
                current_uc_id <- project_id
                # Get unique required general concept IDs for this project
                required_gc_ids <- unique(general_concept_projects %>%
                  dplyr::filter(project_id == current_uc_id) %>%
                  dplyr::pull(general_concept_id))
                required_gc_ids <- as.integer(required_gc_ids)
                sum(required_gc_ids %in% mapped_general_concept_ids)
              }
            },
            coverage_pct = ifelse(total_concepts > 0, round(mapped_concepts / total_concepts * 100), 0)
          ) %>%
          dplyr::ungroup() %>%
          dplyr::select(name, short_description, total_concepts, mapped_concepts, coverage_pct)

        # Create datatable
        dt <- datatable(
          uc_compat,
          rownames = FALSE,
          selection = 'none',
          filter = 'top',
          options = list(
            pageLength = 10,
            lengthMenu = c(5, 10, 15, 20, 50),
            dom = 'ltp',
            ordering = TRUE,
            autoWidth = FALSE,
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 2, width = "100px", className = "dt-center"),
              list(targets = 3, width = "100px", className = "dt-center"),
              list(targets = 4, width = "100px", className = "dt-center")
            )
          ),
          colnames = c(
            as.character(i18n$t("name")),
            as.character(i18n$t("description")),
            as.character(i18n$t("total_concepts")),
            as.character(i18n$t("mapped_concepts")),
            as.character(i18n$t("coverage"))
          )
        ) %>%
          DT::formatStyle(
            "coverage_pct",
            backgroundColor = DT::styleInterval(
              c(50, 100),
              c("#f8d7da", "#fff3cd", "#d4edda")
            ),
            color = DT::styleInterval(
              c(50, 100),
              c("#721c24", "#856404", "#155724")
            ),
            fontWeight = "bold"
          ) %>%
          DT::formatString("coverage_pct", suffix = "%")

        dt
      }, server = TRUE)
    })

    ### b) All Mappings Tab ----
    #### All Mappings Table Rendering ----
    # Render table when trigger fires
    observe_event(all_mappings_table_trigger(), {
      # Check visibility and prerequisites first
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()

      # Get mappings from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        output$all_mappings_table_main <- DT::renderDT({
          create_empty_datatable("Database not found")
        }, server = TRUE)
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings for this alignment from database with user info
      mappings_db <- DBI::dbGetQuery(
        con,
        "SELECT
          cm.mapping_id,
          cm.csv_file_path,
          cm.row_id,
          cm.target_general_concept_id,
          cm.target_omop_concept_id,
          cm.target_custom_concept_id,
          cm.imported_mapping_id,
          cm.mapping_datetime,
          cm.mapped_by_user_id,
          cm.imported_user_name,
          u.first_name as mapped_by_first_name,
          u.last_name as mapped_by_last_name
        FROM concept_mappings cm
        LEFT JOIN users u ON cm.mapped_by_user_id = u.user_id
        WHERE cm.alignment_id = ?",
        params = list(selected_alignment_id())
      )

      if (nrow(mappings_db) == 0) {
        output$all_mappings_table_main <- DT::renderDT({
          create_empty_datatable("No mappings created yet.")
        }, server = TRUE)
        return()
      }

      # Try to read source CSV for concept names (optional)
      csv_filename <- mappings_db$csv_file_path[1]
      csv_path <- file.path(get_app_dir("concept_mapping"), csv_filename)
      source_df <- NULL
      if (!is.na(csv_filename) && file.exists(csv_path)) {
        source_df <- read.csv(csv_path, stringsAsFactors = FALSE)
      }

      # Enrich with source concept information by matching row_id (DB) with row_id (CSV)
      if (!is.null(source_df) && "row_id" %in% colnames(source_df)) {
        # Join on row_id column from CSV with row_id from DB
        source_cols <- c("row_id")
        if ("concept_name" %in% colnames(source_df)) source_cols <- c(source_cols, "concept_name")
        if ("concept_code" %in% colnames(source_df)) source_cols <- c(source_cols, "concept_code")
        if ("vocabulary_id" %in% colnames(source_df)) source_cols <- c(source_cols, "vocabulary_id")
        if ("category" %in% colnames(source_df)) source_cols <- c(source_cols, "category")

        source_join_df <- source_df[, source_cols, drop = FALSE]
        colnames(source_join_df) <- c("row_id",
          if ("concept_name" %in% colnames(source_df)) "concept_name_source" else NULL,
          if ("concept_code" %in% colnames(source_df)) "concept_code_source" else NULL,
          if ("vocabulary_id" %in% colnames(source_df)) "vocabulary_id_source" else NULL,
          if ("category" %in% colnames(source_df)) "source_category" else NULL
        )

        mapped_rows <- mappings_db %>%
          dplyr::left_join(source_join_df, by = "row_id")

        # Fill in defaults for missing columns
        if (!"concept_name_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_name_source = paste0("Source concept #", row_id))
        } else {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_name_source = dplyr::if_else(
              is.na(concept_name_source),
              paste0("Source concept #", row_id),
              concept_name_source
            ))
        }
        if (!"concept_code_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_code_source = NA_character_)
        }
        if (!"vocabulary_id_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(vocabulary_id_source = NA_character_)
        }
        if (!"source_category" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(source_category = NA_character_)
        }
      } else {
        # Fallback for CSV without row_id column
        mapped_rows <- mappings_db %>%
          dplyr::mutate(
            concept_name_source = paste0("Source concept #", row_id),
            concept_code_source = NA_character_,
            vocabulary_id_source = NA_character_,
            source_category = NA_character_
          )
      }

      if (nrow(mapped_rows) == 0) {
        output$all_mappings_table_main <- DT::renderDT({
          create_empty_datatable("No mappings created yet.")
        }, server = TRUE)
        return()
      }

      # Enrich with general concept information
      general_concepts <- data()$general_concepts

      # Join with general concepts to get names
      enriched_rows <- mapped_rows %>%
        dplyr::left_join(
          general_concepts %>%
            dplyr::select(general_concept_id, general_concept_name, category, subcategory),
          by = c("target_general_concept_id" = "general_concept_id")
        )

      # Enrich with target concept info (OMOP or custom)
      if ("target_custom_concept_id" %in% colnames(enriched_rows)) {
        enriched_rows <- enrich_target_concepts(enriched_rows, vocabularies(), data())
      } else {
        # Fallback: old CSV format
        vocab_data <- vocabularies()
        if (!is.null(vocab_data) && nrow(enriched_rows) > 0) {
          concept_ids <- enriched_rows$target_omop_concept_id
          omop_concepts <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% concept_ids) %>%
            dplyr::select(
              concept_id,
              concept_name_target = concept_name,
              vocabulary_id_target = vocabulary_id,
              concept_code_target = concept_code
            ) %>%
            dplyr::collect()

          enriched_rows <- enriched_rows %>%
            dplyr::left_join(
              omop_concepts,
              by = c("target_omop_concept_id" = "concept_id")
            )
        } else {
          enriched_rows <- enriched_rows %>%
            dplyr::mutate(
              concept_name_target = NA_character_,
              vocabulary_id_target = NA_character_,
              concept_code_target = NA_character_
            )
        }
      }

      # We already have mapping_id from the initial database query, rename it to db_mapping_id
      enriched_rows <- enriched_rows %>%
        dplyr::rename(db_mapping_id = mapping_id)

      # Get vote statistics from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (file.exists(db_path)) {
        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        # Get vote counts for each mapping
        vote_query <- "
          SELECT
            cm.mapping_id,
            COUNT(CASE WHEN me.is_approved = 1 THEN 1 END) as upvotes,
            COUNT(CASE WHEN me.is_approved = 0 THEN 1 END) as downvotes,
            COUNT(CASE WHEN me.is_approved = -1 THEN 1 END) as uncertain_votes
          FROM concept_mappings cm
          LEFT JOIN mapping_evaluations me ON cm.mapping_id = me.mapping_id
          WHERE cm.alignment_id = ?
          GROUP BY cm.mapping_id
        "
        vote_stats <- DBI::dbGetQuery(con, vote_query, params = list(selected_alignment_id()))

        # Join vote stats with enriched_rows using the db mapping_id
        enriched_rows <- enriched_rows %>%
          dplyr::left_join(vote_stats, by = c("db_mapping_id" = "mapping_id"))
      } else {
        # No database, set vote columns to 0
        enriched_rows <- enriched_rows %>%
          dplyr::mutate(
            upvotes = 0L,
            downvotes = 0L,
            uncertain_votes = 0L
          )
      }

      # Build display dataframe with mapping_id for selection
      display_df <- enriched_rows %>%
        dplyr::mutate(
          mapping_id = db_mapping_id,
          Category = factor(dplyr::if_else(is.na(source_category) | source_category == "", "/", source_category)),
          Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
          Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
          Origin = dplyr::if_else(
            is.na(imported_mapping_id),
            sprintf('<span style="background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("manual")),
            sprintf('<span style="background: #0f60af; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("imported"))
          ),
          Mapped_By = factor(dplyr::case_when(
            !is.na(mapped_by_first_name) | !is.na(mapped_by_last_name) ~
              trimws(paste0(
                dplyr::if_else(is.na(mapped_by_first_name), "", mapped_by_first_name),
                " ",
                dplyr::if_else(is.na(mapped_by_last_name), "", mapped_by_last_name)
              )),
            !is.na(imported_user_name) ~ imported_user_name,
            TRUE ~ "/"
          )),
          Added = dplyr::if_else(
            is.na(mapping_datetime) | mapping_datetime == "",
            "/",
            mapping_datetime
          ),
          Upvotes = ifelse(is.na(upvotes), 0L, as.integer(upvotes)),
          Downvotes = ifelse(is.na(downvotes), 0L, as.integer(downvotes)),
          Uncertain = ifelse(is.na(uncertain_votes), 0L, as.integer(uncertain_votes))
        ) %>%
        dplyr::select(mapping_id, Category, Source, Target, Origin, Mapped_By, Added, Upvotes, Downvotes, Uncertain)

      # Store display_df for selection handling
      all_mappings_display_data(display_df)

      # Render table with prepared data (All Mappings)
      output$all_mappings_table_main <- DT::renderDT({
        datatable(
          display_df,
          escape = FALSE,
          filter = 'top',
          extensions = "Buttons",
          options = list(
            pageLength = 15,
            lengthMenu = c(10, 15, 20, 50, 100, 200),
            dom = 'Bltp',
            buttons = list("colvis"),
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 0, visible = FALSE),
              list(targets = 1, width = "10%"),
              list(targets = 4, width = "80px", className = "dt-center"),
              list(targets = 5, width = "12%"),
              list(targets = 6, width = "10%"),
              list(targets = 7, width = "60px", className = "dt-center"),
              list(targets = 8, width = "60px", className = "dt-center"),
              list(targets = 9, width = "60px", className = "dt-center")
            )
          ),
          rownames = FALSE,
          selection = 'multiple',
          colnames = c(
            "mapping_id",
            as.character(i18n$t("category")),
            as.character(i18n$t("source_concept")),
            as.character(i18n$t("target_concept")),
            as.character(i18n$t("origin")),
            as.character(i18n$t("mapped_by")),
            as.character(i18n$t("added")),
            as.character(i18n$t("upvotes")),
            as.character(i18n$t("downvotes")),
            as.character(i18n$t("uncertain"))
          )
        )
      }, server = TRUE)
    })

    #### Update All Mappings Table Data Using Proxy ----
    # Update data without re-rendering when mappings change
    observe_event(mappings_refresh_trigger(), {
      if (mappings_refresh_trigger() == 0) return()
      if (is.null(selected_alignment_id())) return()
      if (is.null(data())) return()

      # Get mappings from database (same logic as initial render)
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings for this alignment from database with user info
      mappings_db <- DBI::dbGetQuery(
        con,
        "SELECT
          cm.mapping_id,
          cm.csv_file_path,
          cm.row_id,
          cm.target_general_concept_id,
          cm.target_omop_concept_id,
          cm.target_custom_concept_id,
          cm.imported_mapping_id,
          cm.mapping_datetime,
          cm.mapped_by_user_id,
          cm.imported_user_name,
          u.first_name as mapped_by_first_name,
          u.last_name as mapped_by_last_name
        FROM concept_mappings cm
        LEFT JOIN users u ON cm.mapped_by_user_id = u.user_id
        WHERE cm.alignment_id = ?",
        params = list(selected_alignment_id())
      )

      if (nrow(mappings_db) == 0) {
        # Force full re-render when table becomes empty
        all_mappings_table_trigger(all_mappings_table_trigger() + 1)
        return()
      }

      # Try to read source CSV for concept names (optional)
      csv_filename <- mappings_db$csv_file_path[1]
      csv_path <- file.path(get_app_dir("concept_mapping"), csv_filename)
      source_df <- NULL
      if (!is.na(csv_filename) && file.exists(csv_path)) {
        source_df <- read.csv(csv_path, stringsAsFactors = FALSE)
      }

      # Enrich with source concept information by matching row_id (DB) with row_id (CSV)
      if (!is.null(source_df) && "row_id" %in% colnames(source_df)) {
        # Join on row_id column from CSV with row_id from DB
        source_cols <- c("row_id")
        if ("concept_name" %in% colnames(source_df)) source_cols <- c(source_cols, "concept_name")
        if ("concept_code" %in% colnames(source_df)) source_cols <- c(source_cols, "concept_code")
        if ("vocabulary_id" %in% colnames(source_df)) source_cols <- c(source_cols, "vocabulary_id")
        if ("category" %in% colnames(source_df)) source_cols <- c(source_cols, "category")

        source_join_df <- source_df[, source_cols, drop = FALSE]
        colnames(source_join_df) <- c("row_id",
          if ("concept_name" %in% colnames(source_df)) "concept_name_source" else NULL,
          if ("concept_code" %in% colnames(source_df)) "concept_code_source" else NULL,
          if ("vocabulary_id" %in% colnames(source_df)) "vocabulary_id_source" else NULL,
          if ("category" %in% colnames(source_df)) "source_category" else NULL
        )

        mapped_rows <- mappings_db %>%
          dplyr::left_join(source_join_df, by = "row_id")

        # Fill in defaults for missing columns
        if (!"concept_name_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_name_source = paste0("Source concept #", row_id))
        } else {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_name_source = dplyr::if_else(
              is.na(concept_name_source),
              paste0("Source concept #", row_id),
              concept_name_source
            ))
        }
        if (!"concept_code_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(concept_code_source = NA_character_)
        }
        if (!"vocabulary_id_source" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(vocabulary_id_source = NA_character_)
        }
        if (!"source_category" %in% colnames(mapped_rows)) {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(source_category = NA_character_)
        }
      } else {
        # Fallback for CSV without row_id column
        mapped_rows <- mappings_db %>%
          dplyr::mutate(
            concept_name_source = paste0("Source concept #", row_id),
            concept_code_source = NA_character_,
            vocabulary_id_source = NA_character_,
            source_category = NA_character_
          )
      }

      # Enrich with general concept information
      general_concepts <- data()$general_concepts

      # Join with general concepts to get names
      enriched_rows <- mapped_rows %>%
        dplyr::left_join(
          general_concepts %>%
            dplyr::select(general_concept_id, general_concept_name, category, subcategory),
          by = c("target_general_concept_id" = "general_concept_id")
        )

      # Enrich with target concept info (OMOP or custom)
      if ("target_custom_concept_id" %in% colnames(enriched_rows)) {
        enriched_rows <- enrich_target_concepts(enriched_rows, vocabularies(), data())
      } else {
        # Fallback: old CSV format
        vocab_data <- vocabularies()
        if (!is.null(vocab_data) && nrow(enriched_rows) > 0) {
          concept_ids <- enriched_rows$target_omop_concept_id
          omop_concepts <- vocab_data$concept %>%
            dplyr::filter(concept_id %in% concept_ids) %>%
            dplyr::select(
              concept_id,
              concept_name_target = concept_name,
              vocabulary_id_target = vocabulary_id,
              concept_code_target = concept_code
            ) %>%
            dplyr::collect()

          enriched_rows <- enriched_rows %>%
            dplyr::left_join(
              omop_concepts,
              by = c("target_omop_concept_id" = "concept_id")
            )
        } else {
          enriched_rows <- enriched_rows %>%
            dplyr::mutate(
              concept_name_target = NA_character_,
              vocabulary_id_target = NA_character_,
              concept_code_target = NA_character_
            )
        }
      }

      # Rename mapping_id to db_mapping_id
      enriched_rows <- enriched_rows %>%
        dplyr::rename(db_mapping_id = mapping_id)

      # Get vote counts for each mapping
      vote_query <- "
        SELECT
          cm.mapping_id,
          COUNT(CASE WHEN me.is_approved = 1 THEN 1 END) as upvotes,
          COUNT(CASE WHEN me.is_approved = 0 THEN 1 END) as downvotes,
          COUNT(CASE WHEN me.is_approved = -1 THEN 1 END) as uncertain_votes
        FROM concept_mappings cm
        LEFT JOIN mapping_evaluations me ON cm.mapping_id = me.mapping_id
        WHERE cm.alignment_id = ?
        GROUP BY cm.mapping_id
      "
      vote_stats <- DBI::dbGetQuery(con, vote_query, params = list(selected_alignment_id()))

      # Join vote stats with enriched_rows using the db mapping_id
      enriched_rows <- enriched_rows %>%
        dplyr::left_join(vote_stats, by = c("db_mapping_id" = "mapping_id"))

      # Build display dataframe with mapping_id for selection
      display_df <- enriched_rows %>%
        dplyr::mutate(
          mapping_id = db_mapping_id,
          Category = factor(dplyr::if_else(is.na(source_category) | source_category == "", "/", source_category)),
          Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
          Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
          Origin = dplyr::if_else(
            is.na(imported_mapping_id),
            sprintf('<span style="background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("manual")),
            sprintf('<span style="background: #0f60af; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("imported"))
          ),
          Mapped_By = factor(dplyr::case_when(
            !is.na(mapped_by_first_name) | !is.na(mapped_by_last_name) ~
              trimws(paste0(
                dplyr::if_else(is.na(mapped_by_first_name), "", mapped_by_first_name),
                " ",
                dplyr::if_else(is.na(mapped_by_last_name), "", mapped_by_last_name)
              )),
            !is.na(imported_user_name) ~ imported_user_name,
            TRUE ~ "/"
          )),
          Added = dplyr::if_else(
            is.na(mapping_datetime) | mapping_datetime == "",
            "/",
            mapping_datetime
          ),
          Upvotes = ifelse(is.na(upvotes), 0L, as.integer(upvotes)),
          Downvotes = ifelse(is.na(downvotes), 0L, as.integer(downvotes)),
          Uncertain = ifelse(is.na(uncertain_votes), 0L, as.integer(uncertain_votes))
        ) %>%
        dplyr::select(mapping_id, Category, Source, Target, Origin, Mapped_By, Added, Upvotes, Downvotes, Uncertain)

      # Update stored display data for selection handling
      all_mappings_display_data(display_df)

      # Use proxy to update data (preserves filters and pagination)
      proxy <- DT::dataTableProxy("all_mappings_table_main", session = session)
      DT::replaceData(proxy, display_df, resetPaging = FALSE, rownames = FALSE)
    }, ignoreInit = TRUE)

    #### Delete Mapping Actions ----

    # Show/hide delete selected button based on selection
    observe_event(input$all_mappings_table_main_rows_selected, {
      selected_rows <- input$all_mappings_table_main_rows_selected
      if (length(selected_rows) > 0) {
        shinyjs::show("delete_selected_mappings")
      } else {
        shinyjs::hide("delete_selected_mappings")
      }
    }, ignoreNULL = FALSE, ignoreInit = FALSE)

    # Handle delete selected button click - show confirmation modal
    observe_event(input$delete_selected_mappings, {
      selected_rows <- input$all_mappings_table_main_rows_selected
      if (length(selected_rows) == 0) return()

      display_data <- all_mappings_display_data()
      if (is.null(display_data)) return()

      # Get mapping_ids from selected rows
      selected_mapping_ids <- display_data$mapping_id[selected_rows]
      mappings_to_delete(selected_mapping_ids)

      # Update modal message
      count <- length(selected_mapping_ids)
      message <- sprintf(i18n$t("delete_mappings_confirm"), count)
      shinyjs::runjs(sprintf("$('#%s').text('%s');", ns("delete_mappings_message"), message))

      # Show confirmation modal
      shinyjs::show("delete_mappings_confirmation_modal")
    }, ignoreInit = TRUE)

    # Handle confirmation of deletion
    observe_event(input$confirm_delete_mappings, {
      mapping_ids <- mappings_to_delete()
      if (is.null(mapping_ids) || length(mapping_ids) == 0) return()

      # Hide modal first
      shinyjs::hide("delete_mappings_confirmation_modal")

      # Get mapping details from database
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Process each mapping to delete
      for (mapping_id in mapping_ids) {
        # Get mapping details
        mapping_to_delete <- DBI::dbGetQuery(
          con,
          "SELECT csv_file_path, row_id FROM concept_mappings WHERE mapping_id = ?",
          params = list(mapping_id)
        )

        if (nrow(mapping_to_delete) == 0) next

        # Delete from database
        delete_concept_mapping(mapping_id)

        # Update CSV file to remove the mapping
        csv_filename <- mapping_to_delete$csv_file_path[1]
        csv_path <- file.path(get_app_dir("concept_mapping"), csv_filename)
        row_id <- mapping_to_delete$row_id[1]

        if (!is.na(csv_filename) && !is.na(row_id) && file.exists(csv_path)) {
          df <- read.csv(csv_path, stringsAsFactors = FALSE)

          # Find the row with this row_id
          row_to_clear <- which(df$row_id == row_id)

          if (length(row_to_clear) > 0) {
            # Clear mapping columns
            if ("target_general_concept_id" %in% colnames(df)) df$target_general_concept_id[row_to_clear] <- NA_integer_
            if ("target_omop_concept_id" %in% colnames(df)) df$target_omop_concept_id[row_to_clear] <- NA_integer_
            if ("target_custom_concept_id" %in% colnames(df)) df$target_custom_concept_id[row_to_clear] <- NA_integer_
            if ("mapped_by_user_id" %in% colnames(df)) df$mapped_by_user_id[row_to_clear] <- NA_integer_
            if ("mapping_datetime" %in% colnames(df)) df$mapping_datetime[row_to_clear] <- NA_character_

            write.csv(df, csv_path, row.names = FALSE)
          }
        }
      }

      # Clear state
      mappings_to_delete(NULL)

      # Trigger refresh
      source_concepts_table_trigger(source_concepts_table_trigger() + 1)
      source_concepts_table_general_trigger(source_concepts_table_general_trigger() + 1)
      evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    }, ignoreInit = TRUE)

    #### Mapped View Tables ----
    observe_event(source_concepts_table_mapped_trigger(), {
      # Check visibility first
      if (is.null(selected_alignment_id())) return()
      if (mapping_view() != "mapped") return()

      # Prepare all data outside renderDT
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]

      mapping_dir <- get_app_dir("concept_mapping")

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      if (!file.exists(csv_path)) {
        output$source_concepts_table_mapped <- DT::renderDT({
          datatable(
            data.frame(Error = "CSV file not found"),
            options = list(dom = 't'),
            rownames = FALSE,
            selection = 'none'
          )
        }, server = TRUE)
        return()
      }

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Apply column types from alignment settings
      column_types_json <- alignment$column_types[1]
      df <- apply_column_types(df, column_types_json)

      standard_cols <- c("vocabulary_id", "concept_code", "concept_name", "statistical_summary")
      available_standard <- standard_cols[standard_cols %in% colnames(df)]
      excluded_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id", "row_id")
      other_cols <- setdiff(colnames(df), c(standard_cols, excluded_cols))
      df_final <- df[, c(available_standard, other_cols), drop = FALSE]

      # Rename columns for display
      nice_names <- colnames(df_final)
      nice_names[nice_names == "vocabulary_id"] <- as.character(i18n$t("vocabulary"))
      nice_names[nice_names == "concept_code"] <- as.character(i18n$t("concept_code"))
      nice_names[nice_names == "concept_name"] <- as.character(i18n$t("concept_name"))
      nice_names[nice_names == "statistical_summary"] <- as.character(i18n$t("summary"))
      nice_names[nice_names == "frequency"] <- as.character(i18n$t("frequency"))

      # Render table with prepared data only
      output$source_concepts_table_mapped <- DT::renderDT({
        datatable(
          df_final,
          colnames = nice_names,
          options = list(
            pageLength = 8,
            lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c('5', '8', '10', '15', '20', '50', '100')),
            dom = 'ltp',
            language = get_datatable_language()
          ),
          rownames = FALSE,
          selection = 'single'
        )
      }, server = TRUE)
    })

    observe_event(mapped_concepts_table_trigger(), {
      # Check visibility first
      if (is.null(selected_general_concept_id())) return()
      if (is.null(data())) return()
      if (is.null(vocabularies())) return()
      if (mapping_view() != "mapped") return()

      # Prepare all data outside renderDT
      concept_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == selected_general_concept_id())

      if (nrow(concept_mappings) == 0) {
        output$mapped_concepts_table <- DT::renderDT({
          create_empty_datatable("No mapped concepts found for this general concept.")
        }, server = TRUE)
        return()
      }

      vocabs <- vocabularies()
      mapped_with_details <- concept_mappings %>%
        dplyr::left_join(
          vocabs$concept %>% dplyr::select(concept_id, concept_name, concept_code, vocabulary_id, standard_concept) %>% dplyr::collect(),
          by = c("omop_concept_id" = "concept_id")
        ) %>%
        dplyr::select(omop_concept_id, concept_name, concept_code, vocabulary_id, standard_concept)

      # Render table with prepared data only
      output$mapped_concepts_table <- DT::renderDT({
        datatable(
          mapped_with_details,
          options = list(
            pageLength = 10,
            lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c('5', '8', '10', '15', '20', '50', '100')),
            dom = 'ltp',
            language = get_datatable_language()
          ),
          rownames = FALSE,
          selection = 'single',
          colnames = c(
            as.character(i18n$t("omop_concept_id")),
            as.character(i18n$t("concept_name")),
            as.character(i18n$t("concept_code")),
            as.character(i18n$t("vocabulary")),
            as.character(i18n$t("standard"))
          )
        )
      }, server = TRUE)
    })

    observe_event(mappings_refresh_trigger(), {
      # Check visibility first
      if (is.null(selected_alignment_id())) return()
      if (mapping_view() != "mapped") return()

      # Prepare data outside renderDT
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) {
        return(create_empty_datatable("No alignment selected"))
      }

      file_id <- alignment$file_id[1]

      # Get app folder and construct path
      mapping_dir <- get_app_dir("concept_mapping")

      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      # Check if file exists
      if (!file.exists(csv_path)) {
        return(create_empty_datatable("CSV file not found"))
      }

      # Read CSV
      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Apply column types from alignment settings
      column_types_json <- alignment$column_types[1]
      df <- apply_column_types(df, column_types_json)

      # Filter only rows with mappings
      if (!"target_omop_concept_id" %in% colnames(df)) {
        # No mappings yet
        return(create_empty_datatable("No mappings created yet. Select a source concept and a mapped concept, then click 'Add Mapping'."))
      }

      # Rename source columns to avoid conflicts
      df <- df %>%
        dplyr::rename(
          concept_name_source = concept_name,
          vocabulary_id_source = vocabulary_id,
          concept_code_source = concept_code
        )

      mapped_rows <- df %>%
        dplyr::filter(!is.na(target_general_concept_id))

      if (nrow(mapped_rows) == 0) {
        return(create_empty_datatable("No mappings created yet. Select a source concept and a mapped concept, then click 'Add Mapping'."))
      }

      # Enrich with target concept info (OMOP or custom)
      if ("target_custom_concept_id" %in% colnames(mapped_rows)) {
        # Enrich OMOP concepts
        vocab_data <- vocabularies()
        if (!is.null(vocab_data)) {
          omop_rows <- mapped_rows %>% dplyr::filter(!is.na(target_omop_concept_id))
          if (nrow(omop_rows) > 0) {
            concept_ids <- omop_rows$target_omop_concept_id
            omop_concepts <- vocab_data$concept %>%
              dplyr::filter(concept_id %in% concept_ids) %>%
              dplyr::select(
                concept_id,
                concept_name_target = concept_name,
                vocabulary_id_target = vocabulary_id,
                concept_code_target = concept_code
              ) %>%
              dplyr::collect()

            mapped_rows <- mapped_rows %>%
              dplyr::left_join(
                omop_concepts,
                by = c("target_omop_concept_id" = "concept_id")
              )
          } else {
            mapped_rows <- mapped_rows %>%
              dplyr::mutate(
                concept_name_target = NA_character_,
                vocabulary_id_target = NA_character_,
                concept_code_target = NA_character_
              )
          }
        } else {
          mapped_rows <- mapped_rows %>%
            dplyr::mutate(
              concept_name_target = NA_character_,
              vocabulary_id_target = NA_character_,
              concept_code_target = NA_character_
            )
        }

        # Enrich custom concepts
        custom_concepts_path <- get_csv_path("custom_concepts.csv")
        if (file.exists(custom_concepts_path)) {
          custom_rows <- mapped_rows %>% dplyr::filter(!is.na(target_custom_concept_id))
          if (nrow(custom_rows) > 0) {
            custom_concepts_all <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
            custom_concept_ids <- custom_rows$target_custom_concept_id

            custom_concepts_info <- custom_concepts_all %>%
              dplyr::filter(custom_concept_id %in% custom_concept_ids) %>%
              dplyr::select(
                custom_concept_id,
                concept_name_custom = concept_name,
                vocabulary_id_custom = vocabulary_id,
                concept_code_custom = concept_code
              )

            mapped_rows <- mapped_rows %>%
              dplyr::left_join(
                custom_concepts_info,
                by = c("target_custom_concept_id" = "custom_concept_id")
              ) %>%
              dplyr::mutate(
                concept_name_target = ifelse(is.na(concept_name_target), concept_name_custom, concept_name_target),
                vocabulary_id_target = ifelse(is.na(vocabulary_id_target), vocabulary_id_custom, vocabulary_id_target),
                concept_code_target = ifelse(is.na(concept_code_target), concept_code_custom, concept_code_target)
              ) %>%
              dplyr::select(-concept_name_custom, -vocabulary_id_custom, -concept_code_custom)
          }
        }

        display_df <- mapped_rows %>%
          dplyr::mutate(
            Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
            Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
            Actions = sprintf(
              '<button class="btn btn-sm btn-danger" style="padding: 2px 8px; font-size: 11px; line-height: 1.2;" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
              ns("remove_mapping_mapped"), dplyr::row_number()
            )
          ) %>%
          dplyr::select(Source, Target, Actions)
      } else {
        # Fallback: old CSV format
        if (is.null(vocabularies())) return()
        vocabs <- vocabularies()

        display_df <- mapped_rows %>%
          dplyr::left_join(
            vocabs$concept %>%
              dplyr::select(concept_id, concept_name, vocabulary_id, concept_code) %>%
              dplyr::collect(),
            by = c("target_omop_concept_id" = "concept_id")
          ) %>%
          dplyr::mutate(
            Source = paste0(concept_name_source, " (", vocabulary_id_source, ": ", concept_code_source, ")"),
            Target = paste0(concept_name, " (", vocabulary_id, ": ", concept_code, ")"),
            Actions = sprintf(
              '<button class="btn btn-sm btn-danger" style="padding: 2px 8px; font-size: 11px; line-height: 1.2;" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">Remove</button>',
              ns("remove_mapping_mapped"), dplyr::row_number()
            )
          ) %>%
          dplyr::select(Source, Target, Actions)
      }

      # Render table with prepared data
      output$realized_mappings_table_mapped <- DT::renderDT({
        datatable(
          display_df,
          escape = FALSE,
          options = list(
            pageLength = 6,
            dom = 'tp',
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 2, className = "dt-center")
            )
          ),
          rownames = FALSE,
          selection = 'none',
          colnames = c(
            as.character(i18n$t("source_concept")),
            as.character(i18n$t("target_concept")),
            as.character(i18n$t("actions"))
          )
        )
      }, server = TRUE)
    })

    ### c) Edit Mappings Tab ----
    #### Source Concepts Table Rendering ----
    # Render table when trigger fires (alignment changes)
    observe_event(source_concepts_table_general_trigger(), {
      # Check visibility first
      if (is.null(selected_alignment_id())) return()
      if (mapping_view() != "general") return()
      if (mapping_tab() != "edit_mappings") return()

      # Prepare all data outside renderDT
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      
      if (nrow(alignment) != 1) return()
      
      file_id <- alignment$file_id[1]
      
      mapping_dir <- get_app_dir("concept_mapping")
      
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
      
      if (!file.exists(csv_path)) {
        output$source_concepts_table <- DT::renderDT({
          datatable(
            data.frame(Error = "CSV file not found"),
            options = list(dom = "t"),
            rownames = FALSE,
            selection = "none"
          )
        }, server = FALSE)
        return()
      }

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Apply column types from alignment settings
      column_types_json <- alignment$column_types[1]
      df <- apply_column_types(df, column_types_json)

      # Default vocabulary_id to factor if not already set by column_types
      if ("vocabulary_id" %in% colnames(df) && !is.factor(df$vocabulary_id)) {
        df <- df %>%
          dplyr::mutate(vocabulary_id = as.factor(vocabulary_id))
      }

      # Check database for mappings (includes imported mappings)
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")
      db_mapped_row_ids <- integer(0)

      if (file.exists(db_path)) {
        con_db <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        db_mappings <- DBI::dbGetQuery(
          con_db,
          "SELECT DISTINCT row_id FROM concept_mappings WHERE alignment_id = ?",
          params = list(selected_alignment_id())
        )
        db_mapped_row_ids <- db_mappings$row_id
        DBI::dbDisconnect(con_db)
      }

      has_target_cols <- "target_general_concept_id" %in% colnames(df)
      has_omop_cols <- "target_omop_concept_id" %in% colnames(df)

      # Consider mapped if: CSV has target columns set OR concept exists in database mappings
      # Build mapped status based on available columns (avoid referencing non-existent columns)
      csv_mapped <- rep(FALSE, nrow(df))
      if (has_target_cols) {
        csv_mapped <- csv_mapped | !is.na(df$target_general_concept_id)
      }
      if (has_omop_cols) {
        csv_mapped <- csv_mapped | !is.na(df$target_omop_concept_id)
      }
      db_mapped <- df$row_id %in% db_mapped_row_ids

      df <- df %>%
        dplyr::mutate(
          Mapped = factor(
            ifelse(csv_mapped | db_mapped, "Yes", "No"),
            levels = c("Yes", "No")
          )
        )

      standard_cols <- c("vocabulary_id", "category", "concept_code", "concept_name", "statistical_summary")
      available_standard <- standard_cols[standard_cols %in% colnames(df)]
      target_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id")
      other_cols <- setdiff(colnames(df), c(standard_cols, target_cols, "Mapped", "row_id"))
      # Keep row_id in data for selection handling, but don't display it in the table
      df_with_rowid <- df[, c("row_id", available_standard, other_cols, "Mapped"), drop = FALSE]
      df_display <- df_with_rowid[, setdiff(colnames(df_with_rowid), "row_id"), drop = FALSE]

      nice_names <- colnames(df_display)
      nice_names[nice_names == "vocabulary_id"] <- as.character(i18n$t("vocabulary"))
      nice_names[nice_names == "concept_code"] <- as.character(i18n$t("concept_code"))
      nice_names[nice_names == "concept_name"] <- as.character(i18n$t("concept_name"))
      nice_names[nice_names == "statistical_summary"] <- as.character(i18n$t("summary"))
      nice_names[nice_names == "frequency"] <- as.character(i18n$t("frequency"))
      nice_names[nice_names == "category"] <- as.character(i18n$t("category"))
      nice_names[nice_names == "subcategory"] <- as.character(i18n$t("subcategory"))
      nice_names[nice_names == "Mapped"] <- as.character(i18n$t("mapped"))

      mapped_col_index <- which(colnames(df_display) == "Mapped") - 1

      # Build columnDefs list
      column_defs <- list(
        list(targets = mapped_col_index, width = "80px", className = "dt-center")
      )

      # Hide JSON column by default if it exists
      if ("json" %in% colnames(df_display)) {
        json_col_index <- which(colnames(df_display) == "json") - 1
        column_defs <- c(column_defs, list(
          list(targets = json_col_index, visible = FALSE)
        ))
      }

      # Apply fuzzy search filter if query is provided
      fuzzy_query <- source_concepts_fuzzy$query()
      if (!is.null(fuzzy_query) && fuzzy_query != "") {
        df_with_rowid <- fuzzy_search_df(df_with_rowid, fuzzy_query, "concept_name", max_dist = 3)
        df_display <- df_with_rowid[, setdiff(colnames(df_with_rowid), "row_id"), drop = FALSE]
      }

      # Store data with row_id in reactive for selection handling
      source_concepts_data(df_with_rowid)
      source_concepts_colnames(nice_names)
      source_concepts_column_defs(column_defs)

      # Render table with prepared data only
      output$source_concepts_table <- DT::renderDT({
        dt <- datatable(
          df_display,
          filter = "top",
          extensions = "Buttons",
          options = list(
            pageLength = 8,
            lengthMenu = list(c(5, 8, 10, 15, 20, 50, 100), c("5", "8", "10", "15", "20", "50", "100")),
            dom = "Bltip",
            language = get_datatable_language(),
            buttons = list(
              list(
                extend = "colvis",
                text = as.character(i18n$t("show_hide_columns"))
              )
            ),
            columnDefs = column_defs
          ),
          colnames = nice_names,
          rownames = FALSE,
          selection = "single"
        )

        dt <- dt %>%
          style_yes_no_column("Mapped")

        dt
      }, server = TRUE)
    })

    #### Update Source Concepts Table Data Using Proxy ----
    # Update only the Mapped column data using proxy (preserves filters)
    observe_event(source_concepts_table_trigger(), {
      if (source_concepts_table_trigger() == 0) return()
      if (is.null(selected_alignment_id())) return()
      if (is.null(source_concepts_data())) return()

      # Get current data and recalculate Mapped status
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]
      mapping_dir <- get_app_dir("concept_mapping")
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      if (!file.exists(csv_path)) return()

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Apply column types from alignment settings
      column_types_json <- alignment$column_types[1]
      df <- apply_column_types(df, column_types_json)

      # Check database for mappings
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")
      db_mapped_row_ids <- integer(0)

      if (file.exists(db_path)) {
        con_db <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        db_mappings <- DBI::dbGetQuery(
          con_db,
          "SELECT DISTINCT row_id FROM concept_mappings WHERE alignment_id = ?",
          params = list(selected_alignment_id())
        )
        db_mapped_row_ids <- db_mappings$row_id
        DBI::dbDisconnect(con_db)
      }

      has_target_cols <- "target_general_concept_id" %in% colnames(df)
      has_omop_cols <- "target_omop_concept_id" %in% colnames(df)

      csv_mapped <- rep(FALSE, nrow(df))
      if (has_target_cols) {
        csv_mapped <- csv_mapped | !is.na(df$target_general_concept_id)
      }
      if (has_omop_cols) {
        csv_mapped <- csv_mapped | !is.na(df$target_omop_concept_id)
      }
      db_mapped <- df$row_id %in% db_mapped_row_ids

      df <- df %>%
        dplyr::mutate(
          Mapped = factor(
            ifelse(csv_mapped | db_mapped, "Yes", "No"),
            levels = c("Yes", "No")
          )
        )

      standard_cols <- c("vocabulary_id", "category", "concept_code", "concept_name", "statistical_summary")
      available_standard <- standard_cols[standard_cols %in% colnames(df)]
      target_cols <- c("target_general_concept_id", "target_omop_concept_id", "target_custom_concept_id", "mapping_datetime", "mapped_by_user_id", "row_id")
      other_cols <- setdiff(colnames(df), c(standard_cols, target_cols, "Mapped"))

      # Keep row_id for selection handling
      df_with_rowid <- df[, c("row_id", available_standard, other_cols, "Mapped"), drop = FALSE]
      df_display <- df_with_rowid[, setdiff(colnames(df_with_rowid), "row_id"), drop = FALSE]

      # Apply fuzzy search filter if query is provided
      fuzzy_query <- source_concepts_fuzzy$query()
      if (!is.null(fuzzy_query) && fuzzy_query != "") {
        df_with_rowid <- fuzzy_search_df(df_with_rowid, fuzzy_query, "concept_name", max_dist = 3)
        df_display <- df_with_rowid[, setdiff(colnames(df_with_rowid), "row_id"), drop = FALSE]
      }

      # Update stored data with row_id for selection handling
      source_concepts_data(df_with_rowid)

      # Use proxy to update data (preserves filters and pagination)
      proxy <- DT::dataTableProxy("source_concepts_table", session = session)
      DT::replaceData(proxy, df_display, resetPaging = FALSE, rownames = FALSE)
    }, ignoreInit = TRUE)
    
    #### General Concepts Table Rendering ----
    observe_event(c(data(), general_concepts_table_trigger()), {
      # Check visibility first
      if (is.null(data())) return()
      if (mapping_view() != "general") return()
      if (mapping_tab() != "edit_mappings") return()

      # Prepare data outside renderDT
      general_concepts <- data()$general_concepts

      general_concepts_display <- data.frame(
        general_concept_id = general_concepts$general_concept_id,
        category = as.factor(general_concepts$category),
        subcategory = as.factor(general_concepts$subcategory),
        general_concept_name = general_concepts$general_concept_name,
        stringsAsFactors = FALSE
      )

      # Apply fuzzy search filter
      fuzzy_query <- general_concepts_fuzzy_query()
      if (!is.null(fuzzy_query) && fuzzy_query != "" && nrow(general_concepts_display) > 0) {
        general_concepts_display <- fuzzy_search_df(
          general_concepts_display,
          fuzzy_query,
          "general_concept_name",
          max_dist = 3
        )
      }

      # Render table with prepared data
      output$general_concepts_table <- DT::renderDT({
        dt <- datatable(
          general_concepts_display,
          filter = "top",
          options = list(
            pageLength = 15,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100), c("5", "10", "15", "20", "50", "100")),
            dom = "ltip",
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 0, visible = FALSE),
              list(targets = 1, width = "200px")
            )
          ),
          rownames = FALSE,
          selection = "single",
          colnames = c("ID", as.character(i18n$t("category")), as.character(i18n$t("subcategory")), as.character(i18n$t("general_concept")))
        )

        dt <- add_doubleclick_handler(dt, ns("view_mapped_concepts"))

        dt
      }, server = TRUE)
    }, ignoreNULL = FALSE)
    
    #### Concept Mappings Table Rendering ----
    observe_event(concept_mappings_table_trigger(), {
      # Check visibility first - require either a selected general concept or show_all_omop mode
      if (is.null(selected_general_concept_id()) && !show_all_omop_concepts()) return()
      if (is.null(data())) return()
      if (mapping_tab() != "edit_mappings") return()

      # Prepare data outside renderDT
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) {
        output$concept_mappings_table <- DT::renderDT({
          create_empty_datatable("OHDSI vocabularies not loaded. Please configure the ATHENA folder in Settings.")
        }, server = TRUE)
        return()
      }

      # Handle "Show All OMOP Concepts" mode differently
      if (show_all_omop_concepts()) {
        # Check if fuzzy search is active
        fuzzy_query <- concept_mappings_fuzzy$query()

        # Check if limit checkbox is checked (default TRUE if input doesn't exist yet)
        limit_10k <- isTRUE(input$concept_mappings_limit_10k) || is.null(input$concept_mappings_limit_10k)

        # Get active filters
        filters <- omop_active_filters()

        # Build base query with all necessary columns
        base_query <- vocab_data$concept %>%
          dplyr::select(
            omop_concept_id = concept_id,
            concept_name,
            vocabulary_id,
            domain_id,
            concept_code,
            standard_concept,
            invalid_reason
          )

        # Apply filters to base query
        if (length(filters$vocabulary_id) > 0) {
          base_query <- base_query %>% dplyr::filter(vocabulary_id %in% !!filters$vocabulary_id)
        }
        if (length(filters$domain_id) > 0) {
          base_query <- base_query %>% dplyr::filter(domain_id %in% !!filters$domain_id)
        }
        if (length(filters$concept_class_id) > 0) {
          # Need to re-add concept_class_id for filtering
          base_query <- vocab_data$concept %>%
            dplyr::select(
              omop_concept_id = concept_id,
              concept_name,
              vocabulary_id,
              domain_id,
              concept_class_id,
              concept_code,
              standard_concept,
              invalid_reason
            )
          if (length(filters$vocabulary_id) > 0) {
            base_query <- base_query %>% dplyr::filter(vocabulary_id %in% !!filters$vocabulary_id)
          }
          if (length(filters$domain_id) > 0) {
            base_query <- base_query %>% dplyr::filter(domain_id %in% !!filters$domain_id)
          }
          base_query <- base_query %>%
            dplyr::filter(concept_class_id %in% !!filters$concept_class_id) %>%
            dplyr::select(-concept_class_id)
        }
        if (length(filters$standard_concept) > 0) {
          # Handle "NS" (Non-standard) which means NULL or empty standard_concept in DB
          if ("NS" %in% filters$standard_concept) {
            other_vals <- filters$standard_concept[filters$standard_concept != "NS"]
            if (length(other_vals) > 0) {
              # Filter for NULL/empty OR specific values (S, C)
              base_query <- base_query %>%
                dplyr::filter(is.na(standard_concept) | standard_concept == "" | standard_concept %in% !!other_vals)
            } else {
              # Only non-standard selected
              base_query <- base_query %>%
                dplyr::filter(is.na(standard_concept) | standard_concept == "")
            }
          } else {
            # Only S or C selected
            base_query <- base_query %>% dplyr::filter(standard_concept %in% !!filters$standard_concept)
          }
        }
        if (length(filters$validity) > 0) {
          if ("Valid" %in% filters$validity && !"Invalid" %in% filters$validity) {
            base_query <- base_query %>% dplyr::filter(is.na(invalid_reason))
          } else if ("Invalid" %in% filters$validity && !"Valid" %in% filters$validity) {
            base_query <- base_query %>% dplyr::filter(!is.na(invalid_reason))
          }
        }

        if (!is.null(fuzzy_query) && fuzzy_query != "") {
          # Use DuckDB Jaro-Winkler for fuzzy search directly in SQL (fast on 4M+ rows)
          query_escaped <- gsub("'", "''", tolower(fuzzy_query))

          all_concepts <- base_query %>%
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

          if (nrow(all_concepts) == 0) {
            output$concept_mappings_table <- DT::renderDT({
              create_empty_datatable("No matching concepts found.")
            }, server = TRUE)
            return()
          }
        } else {
          # No fuzzy search - load concepts from DuckDB
          # Apply limit if checkbox is checked
          if (limit_10k) {
            all_concepts <- base_query %>%
              utils::head(10000) %>%
              dplyr::collect() %>%
              dplyr::mutate(fuzzy_score = NA_real_)
          } else {
            all_concepts <- base_query %>%
              dplyr::collect() %>%
              dplyr::mutate(fuzzy_score = NA_real_)
          }
        }

        # Add validity column based on invalid_reason
        all_concepts <- all_concepts %>%
          dplyr::mutate(
            validity = ifelse(is.na(invalid_reason), "Valid", "Invalid")
          ) %>%
          dplyr::select(-invalid_reason)

        # Get dictionary mappings to show which concepts are already mapped
        concept_mappings <- data()$concept_mappings
        general_concepts <- data()$general_concepts

        # Create lookup for general concept names by omop_concept_id
        if (nrow(concept_mappings) > 0) {
          mapping_lookup <- concept_mappings %>%
            dplyr::left_join(
              general_concepts %>% dplyr::select(general_concept_id, general_concept_name),
              by = "general_concept_id"
            ) %>%
            dplyr::select(omop_concept_id, general_concept_name) %>%
            dplyr::distinct()

          # Join all concepts with mapping lookup
          mappings <- all_concepts %>%
            dplyr::left_join(mapping_lookup, by = "omop_concept_id")
        } else {
          mappings <- all_concepts %>%
            dplyr::mutate(general_concept_name = NA_character_)
        }

        # Sort by fuzzy_score (best matches first), then standard_concept
        mappings <- mappings %>%
          dplyr::mutate(
            vocabulary_id = factor(vocabulary_id),
            sort_order = dplyr::case_when(
              standard_concept == "S" ~ 1,
              standard_concept == "C" ~ 2,
              TRUE ~ 3
            )
          ) %>%
          dplyr::arrange(dplyr::desc(fuzzy_score), sort_order, concept_name) %>%
          dplyr::select(-sort_order)

        # Ensure validity column exists in mappings (should be present from base_query)
        if (!"validity" %in% colnames(mappings)) {
          mappings <- mappings %>%
            dplyr::mutate(validity = "Valid")
        }

        # Store the sorted data for row selection lookups
        concept_mappings_table_data(mappings)

        # Ensure fuzzy_score exists in mappings
        if (!"fuzzy_score" %in% colnames(mappings)) {
          mappings <- mappings %>%
            dplyr::mutate(fuzzy_score = NA_real_)
        }

        # Prepare display data (preserves all columns including fuzzy_score and validity)
        mappings_display <- prepare_concept_set_display(
          mappings = mappings,
          ns = ns,
          editable = FALSE
        )

        # Ensure validity exists
        if (!"validity" %in% colnames(mappings_display)) {
          mappings_display <- mappings_display %>%
            dplyr::mutate(validity = "Valid")
        } else {
          mappings_display <- mappings_display %>%
            dplyr::mutate(validity = dplyr::coalesce(validity, "Valid"))
        }

        # Ensure fuzzy_score exists
        if (!"fuzzy_score" %in% colnames(mappings_display)) {
          mappings_display <- mappings_display %>%
            dplyr::mutate(fuzzy_score = NA_real_)
        }

        # Ensure standard_concept_display exists (may be missing if mappings was empty)
        if (!"standard_concept_display" %in% colnames(mappings_display)) {
          mappings_display <- mappings_display %>%
            dplyr::mutate(
              standard_concept_display = factor(
                dplyr::case_when(
                  standard_concept == "S" ~ "Standard",
                  standard_concept == "C" ~ "Classification",
                  TRUE ~ "Non-standard"
                ),
                levels = c("Standard", "Classification", "Non-standard")
              )
            )
        }

        # Select columns including general_concept_name, validity, and fuzzy_score
        mappings_display <- mappings_display %>%
          dplyr::select(general_concept_name, vocabulary_id, omop_concept_id, concept_code, concept_name, domain_id, standard_concept_display, validity, fuzzy_score)

        # Determine if fuzzy search is active (to show/hide Score column)
        fuzzy_active <- !is.null(fuzzy_query) && fuzzy_query != ""

        # Render table with general_concept_name, validity, and fuzzy_score columns (server-side for large datasets)
        output$concept_mappings_table <- DT::renderDT({
          dt <- datatable(
            mappings_display,
            options = list(
              pageLength = 15,
              lengthMenu = list(c(5, 10, 15, 20, 50, 100), c("5", "10", "15", "20", "50", "100")),
              dom = "Bltip",
              language = get_datatable_language(),
              buttons = list(
                list(
                  extend = "colvis",
                  text = "Columns",
                  className = "btn-colvis"
                )
              ),
              columnDefs = list(
                list(targets = 0, visible = FALSE),  # Hide General Concept by default
                list(targets = 5, visible = FALSE),  # Hide Domain
                list(targets = 6, width = "90px", className = "dt-center"),  # Standard column
                list(targets = 7, visible = FALSE, width = "70px", className = "dt-center"),  # Hide Validity by default
                list(targets = 8, width = "60px", className = "dt-center", visible = fuzzy_active)  # Score column - visible only when fuzzy search active
              )
            ),
            rownames = FALSE,
            selection = "single",
            filter = "top",
            colnames = c(as.character(i18n$t("general_concept")), "Vocabulary", "OMOP Concept ID", "Code", "Concept Name", "Domain", "Standard", as.character(i18n$t("validity")), "Fuzzy Score")
          )

          dt <- dt %>%
            style_standard_concept_column() %>%
            DT::formatStyle(
              "validity",
              color = DT::styleEqual(c("Valid", "Invalid"), c("#28a745", "#dc3545")),
              fontWeight = "bold"
            )

          # Format Score column only when fuzzy search is active
          if (fuzzy_active) {
            dt <- dt %>% DT::formatRound(columns = "fuzzy_score", digits = 2)
          }

          dt
        }, server = TRUE)
        return()
      }

      # Normal mode: show concepts for selected general concept
      concept_mappings <- data()$concept_mappings %>%
        dplyr::filter(general_concept_id == selected_general_concept_id())

      # Use resolve_concept_set to expand descendants/mapped concepts (like in data dictionary)
      if (nrow(concept_mappings) > 0) {
        resolved_concepts <- resolve_concept_set(concept_mappings, vocab_data)

        if (nrow(resolved_concepts) > 0) {
          mappings <- resolved_concepts %>%
            dplyr::mutate(
              is_custom = FALSE,
              custom_concept_id = NA_integer_
            )
        } else {
          mappings <- data.frame(
            omop_concept_id = integer(),
            concept_name = character(),
            vocabulary_id = character(),
            domain_id = character(),
            concept_code = character(),
            standard_concept = character(),
            is_custom = logical(),
            custom_concept_id = integer(),
            stringsAsFactors = FALSE
          )
        }
      } else {
        mappings <- data.frame(
          omop_concept_id = integer(),
          concept_name = character(),
          vocabulary_id = character(),
          domain_id = character(),
          concept_code = character(),
          standard_concept = character(),
          is_custom = logical(),
          custom_concept_id = integer(),
          stringsAsFactors = FALSE
        )
      }

      # Add custom concepts (they don't go through resolve_concept_set)
      custom_concepts_path <- get_csv_path("custom_concepts.csv")
      if (file.exists(custom_concepts_path)) {
        custom_concepts <- readr::read_csv(custom_concepts_path, show_col_types = FALSE) %>%
          dplyr::filter(general_concept_id == selected_general_concept_id()) %>%
          dplyr::select(
            custom_concept_id,
            concept_name,
            vocabulary_id,
            concept_code
          ) %>%
          dplyr::mutate(
            omop_concept_id = NA_integer_,
            domain_id = NA_character_,
            standard_concept = NA_character_,
            is_custom = TRUE
          )

        if (nrow(custom_concepts) > 0) {
          mappings <- dplyr::bind_rows(mappings, custom_concepts)
        }
      }

      if (nrow(mappings) == 0) {
        output$concept_mappings_table <- DT::renderDT({
          create_empty_datatable("No mapped concepts found for this general concept.")
        }, server = TRUE)
        return()
      }

      # Sort by standard_concept then concept_name
      mappings <- mappings %>%
        dplyr::mutate(
          vocabulary_id = factor(vocabulary_id),
          sort_order = dplyr::case_when(
            standard_concept == "S" ~ 1,
            standard_concept == "C" ~ 2,
            TRUE ~ 3
          )
        ) %>%
        dplyr::arrange(sort_order, concept_name) %>%
        dplyr::select(-sort_order)

      # Apply fuzzy search filter if query is provided
      fuzzy_query <- concept_mappings_fuzzy$query()
      if (!is.null(fuzzy_query) && fuzzy_query != "") {
        mappings <- fuzzy_search_df(mappings, fuzzy_query, "concept_name", max_dist = 3)
      }

      # Store the sorted data for row selection lookups
      concept_mappings_table_data(mappings)

      # Prepare display data using shared function (view mode, no toggles)
      mappings_display <- prepare_concept_set_display(
        mappings = mappings,
        ns = ns,
        editable = FALSE
      )

      # Select columns for view mode display (without toggle columns since they're resolved)
      mappings_display <- mappings_display %>%
        dplyr::select(vocabulary_id, omop_concept_id, concept_code, concept_name, domain_id, standard_concept_display)

      # Render table with prepared data
      # Columns: vocabulary_id, omop_concept_id, concept_code, concept_name, domain_id, standard_concept_display
      output$concept_mappings_table <- DT::renderDT({
        dt <- datatable(
          mappings_display,
          options = list(
            pageLength = 15,
            lengthMenu = list(c(5, 10, 15, 20, 50, 100), c("5", "10", "15", "20", "50", "100")),
            dom = "Bltip",
            language = get_datatable_language(),
            buttons = list(
              list(
                extend = "colvis",
                text = "Columns",
                className = "btn-colvis"
              )
            ),
            columnDefs = list(
              list(targets = 4, visible = FALSE),  # Hide Domain
              list(targets = 5, width = "90px", className = "dt-center")  # Standard column
            )
          ),
          rownames = FALSE,
          selection = "single",
          filter = "top",
          colnames = c("Vocabulary", "OMOP Concept ID", "Code", "Concept Name", "Domain", "Standard")
        )

        dt %>% style_standard_concept_column()
      }, server = TRUE)
    })

    #### Concept Details Panel ----
    # Reactive to store selected source concept JSON data
    selected_source_json <- reactiveVal(NULL)
    selected_source_row <- reactiveVal(NULL)  # Store full row data for rows_count, patients_count
    detail_tab <- reactiveVal("summary")
    source_distribution_type <- reactiveVal("auto")  # "auto", "numeric", or "categorical"

    # Show/hide concept details panel based on row selection
    observe_event(input$source_concepts_table_rows_selected, {
      if (mapping_tab() != "edit_mappings") return()

      row_selected <- input$source_concepts_table_rows_selected

      if (is.null(row_selected) || length(row_selected) == 0) {
        shinyjs::hide("concept_details_panel")
        selected_source_json(NULL)
        return()
      }

      # Get the row_id from the displayed data (handles fuzzy filtering)
      displayed_data <- source_concepts_data()
      if (is.null(displayed_data) || row_selected > nrow(displayed_data)) return()

      # Get row_id from the selected row in displayed data
      selected_row_id <- displayed_data$row_id[row_selected]
      if (is.null(selected_row_id) || is.na(selected_row_id)) return()

      # Get the selected row data from CSV using row_id
      if (is.null(selected_alignment_id())) return()

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]
      mapping_dir <- get_app_dir("concept_mapping")
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      if (!file.exists(csv_path)) return()

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      # Find the row by row_id instead of index
      row_data <- df[df$row_id == selected_row_id, ]
      if (nrow(row_data) == 0) return()

      # Store the full row data
      selected_source_row(row_data)

      # Check if json column exists
      if ("json" %in% colnames(df)) {
        json_str <- row_data$json[1]
        if (!is.null(json_str) && !is.na(json_str) && json_str != "") {
          json_data <- tryCatch(
            jsonlite::fromJSON(json_str),
            error = function(e) NULL
          )
          selected_source_json(json_data)
          shinyjs::show("concept_details_panel")
        } else {
          selected_source_json(NULL)
          shinyjs::hide("concept_details_panel")
        }
      } else {
        selected_source_json(NULL)
        shinyjs::hide("concept_details_panel")
      }
    }, ignoreNULL = FALSE)

    # Handle tab selection
    observe_event(input$detail_tab_selected, {
      detail_tab(input$detail_tab_selected)
    })

    # Handle distribution type selection
    observe_event(input$source_distribution_type_change, {
      source_distribution_type(input$source_distribution_type_change)
    })

    # Render concept details content based on selected tab
    output$concept_details_content <- renderUI({
      json_data <- selected_source_json()
      row_data <- selected_source_row()
      tab <- detail_tab()
      dist_type <- source_distribution_type()

      if (is.null(json_data)) {
        return(tags$div(
          class = "text-muted-italic",
          "No JSON data available for this concept."
        ))
      }

      if (tab == "summary") {
        render_json_summary(json_data, row_data)
      } else if (tab == "distribution") {
        render_json_distribution(json_data, dist_type)
      } else if (tab == "temporal") {
        render_json_temporal(json_data)
      } else if (tab == "units") {
        render_json_units(json_data)
      } else if (tab == "other") {
        render_source_other_columns(row_data, json_data)
      } else {
        tags$div("Unknown tab")
      }
    })

    # Helper function to render summary tab
    render_json_summary <- function(json_data, row_data = NULL) {
      left_items <- list()
      right_items <- list()

      # Left column: Source concept info (vocabulary, code, name) + rows, patients, unit

      # Vocabulary
      if (!is.null(row_data) && !is.null(row_data$vocabulary_id) && !is.na(row_data$vocabulary_id)) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            class = "mb-6",
            tags$span(class = "label-text", "Vocabulary:"),
            tags$span(class = "detail-value", row_data$vocabulary_id)
          )
        ))
      }

      # Concept Code
      if (!is.null(row_data) && !is.null(row_data$concept_code) && !is.na(row_data$concept_code)) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            class = "mb-6",
            tags$span(class = "label-text", "Concept Code:"),
            tags$span(class = "detail-value", row_data$concept_code)
          )
        ))
      }

      # Concept Name
      if (!is.null(row_data) && !is.null(row_data$concept_name) && !is.na(row_data$concept_name)) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            class = "mb-6",
            tags$span(class = "label-text", "Name:"),
            tags$span(class = "detail-value", row_data$concept_name)
          )
        ))
      }

      # Rows count
      if (!is.null(row_data) && !is.null(row_data$rows_count) && !is.na(row_data$rows_count)) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            class = "mb-6",
            tags$span(class = "label-text", "Rows:"),
            tags$span(class = "detail-value", format(row_data$rows_count, big.mark = " "))
          )
        ))
      }

      # Patients count
      if (!is.null(row_data) && !is.null(row_data$patients_count) && !is.na(row_data$patients_count)) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            class = "mb-6",
            tags$span(class = "label-text", "Patients:"),
            tags$span(class = "detail-value", format(row_data$patients_count, big.mark = " "))
          )
        ))
      }

      # Unit info (can be a string or an object with $name)
      unit_value <- NULL
      if (!is.null(json_data$unit)) {
        if (is.character(json_data$unit)) {
          unit_value <- json_data$unit
        } else if (is.list(json_data$unit) && !is.null(json_data$unit$name)) {
          unit_value <- json_data$unit$name
        }
      }
      if (!is.null(unit_value) && !is.na(unit_value) && nchar(unit_value) > 0) {
        left_items <- c(left_items, list(
          tags$div(
            class = "detail-item",
            class = "mb-6",
            tags$span(class = "label-text", "Unit:"),
            tags$span(class = "detail-value", unit_value)
          )
        ))
      }

      # Right column: Missing, Interval, numeric stats (mean, median, sd, range)

      # Missing rate
      if (!is.null(json_data$missing_rate)) {
        right_items <- c(right_items, list(
          tags$div(
            class = "detail-item",
            class = "mb-6",
            tags$span(class = "label-text", "Missing:"),
            tags$span(class = "detail-value", paste0(json_data$missing_rate, "%"))
          )
        ))
      }

      # Measurement frequency
      if (!is.null(json_data$measurement_frequency)) {
        mf <- json_data$measurement_frequency
        if (!is.null(mf$typical_interval) && !is.na(mf$typical_interval)) {
          right_items <- c(right_items, list(
            tags$div(
              class = "detail-item",
              class = "mb-6",
              tags$span(class = "label-text", "Interval:"),
              tags$span(class = "detail-value", gsub("_", " ", mf$typical_interval))
            )
          ))
        }
        if (!is.null(mf$average_per_patient_per_day) && !is.na(mf$average_per_patient_per_day)) {
          right_items <- c(right_items, list(
            tags$div(
              class = "detail-item",
              class = "mb-6",
              tags$span(class = "label-text", "Per day:"),
              tags$span(class = "detail-value", round(mf$average_per_patient_per_day, 1))
            )
          ))
        }
      }

      # Numeric data summary (mean, median, sd, range)
      if (!is.null(json_data$numeric_data)) {
        nd <- json_data$numeric_data
        if (!is.null(nd$mean) && !is.na(nd$mean)) {
          right_items <- c(right_items, list(
            tags$div(
              class = "detail-item",
              class = "mb-6",
              tags$span(class = "label-text", "Mean:"),
              tags$span(class = "detail-value", round(nd$mean, 2))
            ),
            tags$div(
              class = "detail-item",
              class = "mb-6",
              tags$span(class = "label-text", "Median:"),
              tags$span(class = "detail-value", round(nd$median, 2))
            ),
            tags$div(
              class = "detail-item",
              class = "mb-6",
              tags$span(class = "label-text", "SD:"),
              tags$span(class = "detail-value", round(nd$sd, 2))
            ),
            tags$div(
              class = "detail-item",
              class = "mb-6",
              tags$span(class = "label-text", "Range:"),
              tags$span(class = "detail-value", paste(nd$min, "-", nd$max))
            )
          ))
        }
      }

      if (length(left_items) == 0 && length(right_items) == 0) {
        return(tags$div(
          class = "text-muted-italic",
          "No summary data available."
        ))
      }

      tags$div(
        style = "display: flex; gap: 30px;",
        tags$div(
          class = "flex-1",
          left_items
        ),
        tags$div(
          class = "flex-1",
          right_items
        )
      )
    }

    # Helper function to render distribution tab (boxplot visualization)
    render_json_distribution <- function(json_data, selected_type = "auto") {
      # Check which distribution types are available
      has_numeric <- !is.null(json_data$numeric_data) &&
        !is.null(json_data$numeric_data$p25) && !is.na(json_data$numeric_data$p25) &&
        !is.null(json_data$numeric_data$p75) && !is.na(json_data$numeric_data$p75)

      has_categorical <- !is.null(json_data$categorical_data) && length(json_data$categorical_data) > 0

      # Validate categorical data structure
      if (has_categorical) {
        cat_df <- as.data.frame(json_data$categorical_data)
        value_col <- if ("value" %in% colnames(cat_df)) "value" else if ("category" %in% colnames(cat_df)) "category" else NULL
        has_categorical <- nrow(cat_df) > 0 && !is.null(value_col) && "percentage" %in% colnames(cat_df)
      }

      # Determine which type to show
      show_type <- selected_type
      if (show_type == "auto") {
        # Default to numeric if available, otherwise categorical
        show_type <- if (has_numeric) "numeric" else if (has_categorical) "categorical" else "none"
      }

      # Build header with dropdown if both types exist
      header <- NULL
      if (has_numeric && has_categorical) {
        header <- tags$div(
          class = "inline-select-container",
          class = "mb-15",
          tags$span(class = "inline-select-label", paste0(i18n$t("distribution_type"), " :")),
          tags$select(
            id = ns("source_distribution_type_select"),
            class = "inline-select",
            onchange = sprintf("Shiny.setInputValue('%s', this.value, {priority: 'event'})", ns("source_distribution_type_change")),
            tags$option(value = "numeric", selected = if (show_type == "numeric") "selected" else NULL, i18n$t("numeric_distribution")),
            tags$option(value = "categorical", selected = if (show_type == "categorical") "selected" else NULL, i18n$t("categorical_distribution"))
          )
        )
      }

      # Render numeric distribution
      if (show_type == "numeric" && has_numeric) {
        nd <- json_data$numeric_data
        min_val <- if (!is.null(nd$min) && !is.na(nd$min)) nd$min else nd$p5
        max_val <- if (!is.null(nd$max) && !is.na(nd$max)) nd$max else nd$p95
        median_val <- if (!is.null(nd$median) && !is.na(nd$median)) nd$median else (nd$p25 + nd$p75) / 2
        lower_val <- if (!is.null(nd$p5) && !is.na(nd$p5)) nd$p5 else min_val
        upper_val <- if (!is.null(nd$p95) && !is.na(nd$p95)) nd$p95 else max_val

        # Create horizontal boxplot with ggplot2
        p <- ggplot2::ggplot() +
          ggplot2::geom_boxplot(
            ggplot2::aes(x = "", ymin = lower_val, lower = nd$p25, middle = median_val,
                         upper = nd$p75, ymax = upper_val),
            stat = "identity",
            fill = "#0f60af",
              color = "#333",
              width = 0.5,
              fatten = 0  # Hide default median line
            ) +
            # Add white median line
            ggplot2::geom_segment(
              ggplot2::aes(x = 0.75, xend = 1.25, y = median_val, yend = median_val),
              color = "white",
              linewidth = 1
            ) +
            ggplot2::coord_flip() +
            ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.02))) +
            ggplot2::labs(x = NULL, y = NULL) +
            ggplot2::theme_minimal(base_size = 11) +
            ggplot2::theme(
              panel.grid.major.y = ggplot2::element_blank(),
              panel.grid.minor = ggplot2::element_blank(),
              axis.text.y = ggplot2::element_blank(),
              axis.text.x = ggplot2::element_text(size = 9),
              plot.margin = ggplot2::margin(5, 10, 5, 10)
            )

          # Check if histogram data exists - render as line plot
          histogram_plot <- NULL
          if (!is.null(json_data$histogram) && length(json_data$histogram) > 0) {
            hist_df <- as.data.frame(json_data$histogram)
            # Support both formats: new "x" format and legacy "bin_start/bin_end" format
            if (nrow(hist_df) > 0 && "count" %in% colnames(hist_df)) {
              if ("x" %in% colnames(hist_df)) {
                hist_df$bin_mid <- hist_df$x
              } else if ("bin_start" %in% colnames(hist_df) && "bin_end" %in% colnames(hist_df)) {
                hist_df$bin_mid <- (hist_df$bin_start + hist_df$bin_end) / 2
              } else {
                hist_df <- NULL
              }
            } else {
              hist_df <- NULL
            }

            # Validate that bin_mid column exists and has valid numeric values
            if (!is.null(hist_df) && nrow(hist_df) > 0 &&
                "bin_mid" %in% colnames(hist_df) &&
                !all(is.na(hist_df$bin_mid)) &&
                is.numeric(hist_df$bin_mid)) {
              # Calculate percentages
              total_count <- sum(hist_df$count, na.rm = TRUE)
              hist_df$percentage <- if (total_count > 0) hist_df$count / total_count * 100 else 0

              p_hist <- ggplot2::ggplot(hist_df, ggplot2::aes(x = bin_mid, y = percentage)) +
                ggplot2::geom_area(fill = "#0f60af", alpha = 0.3) +
                ggplot2::geom_line(color = "#0f60af", linewidth = 1.2) +
                ggplot2::geom_point(color = "#0f60af", size = 2) +
                ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.02))) +
                ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.05)), labels = function(x) paste0(x, "%")) +
                ggplot2::labs(x = NULL, y = NULL) +
                ggplot2::theme_minimal(base_size = 10) +
                ggplot2::theme(
                  panel.grid.minor = ggplot2::element_blank(),
                  panel.grid.major.x = ggplot2::element_blank(),
                  axis.text = ggplot2::element_text(size = 8),
                  plot.margin = ggplot2::margin(5, 10, 5, 10)
                )

              histogram_plot <- renderPlot({ p_hist }, height = 120, width = "auto")
            }
          }

          numeric_content <- tags$div(
            tags$div(
              style = "display: flex; gap: 20px;",
              # Left: statistics
              tags$div(
                class = "flex-1",
                tags$div(
                  style = "display: grid; grid-template-columns: 70px 1fr; gap: 4px; font-size: 12px;",
                  tags$span(class = "label-text", "Min:"), tags$span(round(min_val, 2)),
                  tags$span(class = "label-text", "P5:"), tags$span(if (!is.null(nd$p5)) round(nd$p5, 2) else "-"),
                  tags$span(class = "label-text", "P25:"), tags$span(round(nd$p25, 2)),
                  tags$span(style = "font-weight: 600; color: #0f60af;", "Median:"), tags$span(style = "font-weight: 600;", round(median_val, 2)),
                  tags$span(class = "label-text", "P75:"), tags$span(round(nd$p75, 2)),
                  tags$span(class = "label-text", "P95:"), tags$span(if (!is.null(nd$p95)) round(nd$p95, 2) else "-"),
                  tags$span(class = "label-text", "Max:"), tags$span(round(max_val, 2))
                )
              ),
              # Right: boxplot
              tags$div(
                style = "flex: 1.5;",
                renderPlot({ p }, height = 80, width = "auto")
              )
            ),
            # Histogram below
            if (!is.null(histogram_plot)) {
              tags$div(
                style = "margin-top: 10px;",
                histogram_plot
              )
            }
          )

          return(tags$div(header, numeric_content))
      }

      # Categorical distribution
      if (show_type == "categorical" && has_categorical) {
        cat_df <- as.data.frame(json_data$categorical_data)

        # Support both "value" and "category" column names
        value_col <- if ("value" %in% colnames(cat_df)) "value" else if ("category" %in% colnames(cat_df)) "category" else NULL

        if (nrow(cat_df) > 0 && !is.null(value_col) && "percentage" %in% colnames(cat_df)) {
          # Truncate long category names for display
          cat_df$display_value <- sapply(cat_df[[value_col]], function(v) {
            v <- gsub("\r\n|\r|\n", " ", as.character(v))
            if (nchar(v) > 50) paste0(substr(v, 1, 47), "...") else v
          })

          rows <- lapply(seq_len(nrow(cat_df)), function(i) {
            tags$div(
              style = "display: flex; align-items: center; margin-bottom: 5px;",
              tags$span(
                style = "width: 200px; font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;",
                title = gsub("\r\n|\r|\n", " ", as.character(cat_df[[value_col]][i])),
                cat_df$display_value[i]
              ),
              tags$div(
                style = "flex: 1; margin: 0 8px;",
                tags$div(style = sprintf("width: %s%%; background: #0f60af; height: 18px; border-radius: 3px;", cat_df$percentage[i]))
              ),
              tags$span(style = "font-size: 12px; color: #666; min-width: 45px; text-align: right;", paste0(cat_df$percentage[i], "%"))
            )
          })
          return(tags$div(header, do.call(shiny::tagList, rows)))
        }
      }

      tags$div(
        class = "text-muted-italic",
        "No distribution data available."
      )
    }

    # Helper function to render temporal tab
    render_json_temporal <- function(json_data) {
      items <- list()

      # Temporal coverage (start/end dates)
      # Check both temporal_coverage (old format) and temporal_distribution (new format)
      tc <- NULL
      if (!is.null(json_data$temporal_coverage)) {
        tc <- json_data$temporal_coverage
      } else if (!is.null(json_data$temporal_distribution) &&
                 !is.null(json_data$temporal_distribution$start_date)) {
        tc <- json_data$temporal_distribution
      }

      if (!is.null(tc) && !is.null(tc$start_date)) {
        items <- c(items, list(
          tags$div(
            style = "display: flex; gap: 20px; margin-bottom: 15px;",
            tags$div(
              class = "detail-item",
              tags$span(class = "detail-label", "Start:"),
              tags$span(class = "detail-value", tc$start_date)
            ),
            tags$div(
              class = "detail-item",
              tags$span(class = "detail-label", "End:"),
              tags$span(class = "detail-value", tc$end_date)
            )
          )
        ))
      }

      # Temporal distribution by year (or other interval) - ggplot bar chart
      if (!is.null(json_data$temporal_distribution) &&
          length(json_data$temporal_distribution) > 0) {
        # Handle nested structure with by_year array
        td <- json_data$temporal_distribution
        if (!is.null(td$by_year) && length(td$by_year) > 0) {
          year_df <- as.data.frame(td$by_year)
        } else if (is.list(td) && length(td) > 0 && !is.null(td[[1]]$year)) {
          # Fallback: direct array format
          year_df <- as.data.frame(td)
        } else {
          year_df <- data.frame()
        }

        # Determine x-axis column (year, month, quarter, etc.)
        x_col <- NULL
        x_label <- NULL
        if ("year" %in% colnames(year_df)) {
          x_col <- "year"
          x_label <- "Year"
        } else if ("month" %in% colnames(year_df)) {
          x_col <- "month"
          x_label <- "Month"
        } else if ("quarter" %in% colnames(year_df)) {
          x_col <- "quarter"
          x_label <- "Quarter"
        }

        if (!is.null(x_col) && nrow(year_df) > 0 &&
            "percentage" %in% colnames(year_df)) {
          year_df$x_val <- as.factor(year_df[[x_col]])

          p <- ggplot2::ggplot(year_df, ggplot2::aes(x = x_val, y = percentage)) +
            ggplot2::geom_col(fill = "#0f60af", width = 0.7) +
            ggplot2::labs(x = x_label, y = "%") +
            ggplot2::theme_minimal(base_size = 11) +
            ggplot2::theme(
              panel.grid.major.x = ggplot2::element_blank(),
              panel.grid.minor = ggplot2::element_blank(),
              axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 9),
              axis.text.y = ggplot2::element_text(size = 9),
              axis.title.y = ggplot2::element_text(size = 10),
              plot.margin = ggplot2::margin(5, 10, 5, 5)
            )

          items <- c(items, list(
            renderPlot({ p }, height = 150, width = "auto")
          ))
        }
      }

      if (length(items) == 0) {
        return(tags$div(
          class = "text-muted-italic",
          "No temporal data available."
        ))
      }

      tags$div(items)
    }

    # Helper function to render units tab
    render_json_units <- function(json_data) {
      # Distribution by hospital unit - horizontal bar chart
      if (!is.null(json_data$hospital_units) && length(json_data$hospital_units) > 0) {
        unit_df <- as.data.frame(json_data$hospital_units)
        if (nrow(unit_df) > 0 && "unit" %in% colnames(unit_df) && "percentage" %in% colnames(unit_df)) {
          # Order by percentage descending
          unit_df <- unit_df[order(-unit_df$percentage), ]
          # Truncate names if too long
          unit_df$unit_label <- ifelse(nchar(unit_df$unit) > 20,
            paste0(substr(unit_df$unit, 1, 18), "..."),
            unit_df$unit)
          unit_df$unit_label <- factor(unit_df$unit_label, levels = rev(unit_df$unit_label))

          # Calculate height based on number of units
          plot_height <- max(100, min(250, nrow(unit_df) * 25))

          p <- ggplot2::ggplot(unit_df, ggplot2::aes(x = unit_label, y = percentage)) +
            ggplot2::geom_col(fill = "#0f60af", width = 0.7) +
            ggplot2::coord_flip() +
            ggplot2::labs(x = NULL, y = "%") +
            ggplot2::theme_minimal(base_size = 11) +
            ggplot2::theme(
              panel.grid.major.y = ggplot2::element_blank(),
              panel.grid.minor = ggplot2::element_blank(),
              axis.text.x = ggplot2::element_text(size = 9),
              axis.text.y = ggplot2::element_text(size = 9),
              axis.title.x = ggplot2::element_text(size = 10),
              plot.margin = ggplot2::margin(5, 10, 5, 5)
            )

          return(tags$div(
            renderPlot({ p }, height = plot_height, width = "auto")
          ))
        }
      }

      tags$div(
        class = "text-muted-italic",
        "No unit distribution data available."
      )
    }

    # Helper function to render additional columns from source concept
    render_source_other_columns <- function(row_data, json_data = NULL) {
      # Standard columns that are not displayed in the "Other" tab
      standard_cols <- c(
        "row_id", "vocabulary_id", "concept_code", "concept_name", "json"
      )

      # Standard JSON fields that are displayed in other tabs
      standard_json_fields <- c(
        "data_types", "numeric_data", "histogram", "categorical_data",
        "measurement_frequency", "missing_rate", "temporal_distribution",
        "hospital_units", "unit"
      )

      if (is.null(row_data)) {
        return(tags$div(
          class = "text-muted-italic",
          i18n$t("no_data_available")
        ))
      }

      items <- list()

      # Get additional columns from row_data
      all_cols <- colnames(row_data)
      additional_cols <- setdiff(all_cols, standard_cols)

      # Build display items for each additional column
      for (col in additional_cols) {
        value <- row_data[[col]]
        if (is.null(value) || is.na(value) || value == "") {
          display_value <- "/"
        } else {
          display_value <- as.character(value)
        }

        items <- c(items, list(tags$div(
          class = "detail-item",
          style = "margin-bottom: 8px; display: flex; gap: 8px;",
          tags$span(
            style = "font-weight: 600; color: #666; min-width: 120px;",
            paste0(col, ":")
          ),
          tags$span(
            class = "detail-value",
            style = "word-break: break-word;",
            display_value
          )
        )))
      }

      # Get additional fields from JSON
      if (!is.null(json_data) && is.list(json_data)) {
        json_fields <- names(json_data)
        additional_json_fields <- setdiff(json_fields, standard_json_fields)

        for (field in additional_json_fields) {
          value <- json_data[[field]]
          if (is.null(value) || (is.atomic(value) && is.na(value))) {
            display_value <- "/"
          } else if (is.list(value) || is.vector(value) && length(value) > 1) {
            display_value <- tryCatch({
              jsonlite::toJSON(value, auto_unbox = TRUE)
            }, error = function(e) as.character(value))
          } else {
            display_value <- as.character(value)
          }

          items <- c(items, list(tags$div(
            class = "detail-item",
            style = "margin-bottom: 8px; display: flex; gap: 8px;",
            tags$span(
              style = "font-weight: 600; color: #666; min-width: 120px;",
              paste0(field, " (JSON):")
            ),
            tags$span(
              class = "detail-value",
              style = "word-break: break-word;",
              display_value
            )
          )))
        }
      }

      if (length(items) == 0) {
        return(tags$div(
          class = "text-muted-italic",
          i18n$t("no_additional_columns")
        ))
      }

      tags$div(
        style = "padding: 5px 0;",
        items
      )
    }

    # Helper function to render JSON tutorial
    render_json_tutorial <- function(language = "en") {
      if (language == "fr") {
        tutorial_md <- '
## Guide de structure JSON

Ce JSON décrit les statistiques d\'un concept source importé.

### Structure principale

```json
{
  "data_types": "numeric",
  "numeric_data": { ... },
  "histogram": [ ... ],
  "measurement_frequency": { ... },
  "missing_rate": 5.2,
  "temporal_distribution": { ... },
  "hospital_units": [ ... ]
}
```

### Type de données (`data_types`)

Indique le(s) type(s) de données. Peut être une valeur unique ou un tableau.

```json
{
  "data_types": "numeric"
}
```

Ou plusieurs types :

```json
{
  "data_types": ["numeric", "categorical"]
}
```

Valeurs possibles : `"numeric"`, `"categorical"`

### Données numériques (`numeric_data`)

Statistiques descriptives pour les variables numériques.

```json
{
  "numeric_data": {
    "mean": 120.5,
    "sd": 15.3,
    "min": 60,
    "max": 250,
    "p5": 95,
    "p25": 110,
    "median": 118,
    "p75": 130,
    "p95": 150
  }
}
```

| Champ | Description |
|-------|-------------|
| `mean` | Moyenne |
| `sd` | Écart-type |
| `min`, `max` | Valeurs extrêmes |
| `p5`, `p25`, `median`, `p75`, `p95` | Percentiles |

### Histogramme (`histogram`)

Distribution des valeurs (pour données numériques). Chaque élément contient `x` (valeur) et `count` (nombre d\'occurrences).

```json
{
  "histogram": [
    {"x": 60, "count": 150},
    {"x": 80, "count": 2500},
    {"x": 100, "count": 5000},
    {"x": 120, "count": 4200},
    {"x": 140, "count": 1800},
    {"x": 160, "count": 600},
    {"x": 180, "count": 200}
  ]
}
```

### Données catégorielles (`categorical_data`)

Distribution des catégories (pour variables catégorielles).

```json
{
  "data_types": "categorical",
  "categorical_data": [
    {"category": "Normal", "count": 45000, "percentage": 52.3},
    {"category": "Low", "count": 18500, "percentage": 21.5},
    {"category": "High", "count": 15200, "percentage": 17.7},
    {"category": "Critical", "count": 7300, "percentage": 8.5}
  ]
}
```

### Fréquence de mesure (`measurement_frequency`)

Intervalle typique entre les mesures.

```json
{
  "measurement_frequency": {
    "typical_interval": "4 hours",
    "min_interval": "1 hour",
    "max_interval": "24 hours"
  }
}
```

### Taux de données manquantes (`missing_rate`)

Pourcentage de valeurs manquantes.

```json
{
  "missing_rate": 5.2
}
```

### Distribution temporelle (`temporal_distribution`)

Couverture et répartition des données par année.

```json
{
  "temporal_distribution": {
    "start_date": "2018-01-15",
    "end_date": "2024-06-30",
    "by_year": [
      {"year": 2018, "percentage": 8.5},
      {"year": 2019, "percentage": 12.3},
      {"year": 2020, "percentage": 15.1},
      {"year": 2021, "percentage": 18.7},
      {"year": 2022, "percentage": 20.4},
      {"year": 2023, "percentage": 16.8},
      {"year": 2024, "percentage": 8.2}
    ]
  }
}
```

### Distribution par service (`hospital_units`)

Répartition des données par service hospitalier.

```json
{
  "hospital_units": [
    {"unit": "MICU", "percentage": 22.5},
    {"unit": "SICU", "percentage": 18.3},
    {"unit": "CCU", "percentage": 15.7},
    {"unit": "NICU", "percentage": 12.1},
    {"unit": "PICU", "percentage": 8.9},
    {"unit": "Neuro ICU", "percentage": 7.2},
    {"unit": "Burn ICU", "percentage": 5.4},
    {"unit": "Cardiac ICU", "percentage": 4.8},
    {"unit": "Trauma ICU", "percentage": 3.2},
    {"unit": "Step-down", "percentage": 1.9}
  ]
}
```

### Exemple complet (numérique)

```json
{
  "data_types": "numeric",
  "numeric_data": {
    "mean": 120.5,
    "sd": 15.3,
    "min": 60,
    "max": 250,
    "p5": 95,
    "p25": 110,
    "median": 118,
    "p75": 130,
    "p95": 150
  },
  "histogram": [
    {"x": 60, "count": 150},
    {"x": 80, "count": 2500},
    {"x": 100, "count": 5000},
    {"x": 120, "count": 4200},
    {"x": 140, "count": 1800}
  ],
  "measurement_frequency": {
    "typical_interval": "4 hours"
  },
  "missing_data": {
    "missing_rate": 5.2
  },
  "temporal_distribution": {
    "start_date": "2018-01-15",
    "end_date": "2024-06-30",
    "by_year": [
      {"year": 2020, "percentage": 25.1},
      {"year": 2021, "percentage": 28.7},
      {"year": 2022, "percentage": 30.4},
      {"year": 2023, "percentage": 15.8}
    ]
  },
  "hospital_units": [
    {"unit": "MICU", "percentage": 22.5},
    {"unit": "SICU", "percentage": 18.3},
    {"unit": "CCU", "percentage": 15.7},
    {"unit": "NICU", "percentage": 12.1},
    {"unit": "PICU", "percentage": 8.9},
    {"unit": "Neuro ICU", "percentage": 7.2},
    {"unit": "Burn ICU", "percentage": 5.4},
    {"unit": "Cardiac ICU", "percentage": 4.8},
    {"unit": "Trauma ICU", "percentage": 3.2},
    {"unit": "Step-down", "percentage": 1.9}
  ]
}
```
'
      } else {
        tutorial_md <- '
## JSON Structure Guide

This JSON describes statistics for an imported source concept.

### Main Structure

```json
{
  "data_types": "numeric",
  "numeric_data": { ... },
  "histogram": [ ... ],
  "measurement_frequency": { ... },
  "missing_rate": 5.2,
  "temporal_distribution": { ... },
  "hospital_units": [ ... ]
}
```

### Data Type (`data_types`)

Indicates the data type(s). Can be a single value or an array.

```json
{
  "data_types": "numeric"
}
```

Or multiple types:

```json
{
  "data_types": ["numeric", "categorical"]
}
```

Possible values: `"numeric"`, `"categorical"`

### Numeric Data (`numeric_data`)

Descriptive statistics for numeric variables.

```json
{
  "numeric_data": {
    "mean": 120.5,
    "sd": 15.3,
    "min": 60,
    "max": 250,
    "p5": 95,
    "p25": 110,
    "median": 118,
    "p75": 130,
    "p95": 150
  }
}
```

| Field | Description |
|-------|-------------|
| `mean` | Mean value |
| `sd` | Standard deviation |
| `min`, `max` | Extreme values |
| `p5`, `p25`, `median`, `p75`, `p95` | Percentiles |

### Histogram (`histogram`)

Value distribution (for numeric data). Each element contains `x` (value) and `count` (number of occurrences).

```json
{
  "histogram": [
    {"x": 60, "count": 150},
    {"x": 80, "count": 2500},
    {"x": 100, "count": 5000},
    {"x": 120, "count": 4200},
    {"x": 140, "count": 1800},
    {"x": 160, "count": 600},
    {"x": 180, "count": 200}
  ]
}
```

### Categorical Data (`categorical_data`)

Category distribution (for categorical variables).

```json
{
  "data_types": "categorical",
  "categorical_data": [
    {"category": "Normal", "count": 45000, "percentage": 52.3},
    {"category": "Low", "count": 18500, "percentage": 21.5},
    {"category": "High", "count": 15200, "percentage": 17.7},
    {"category": "Critical", "count": 7300, "percentage": 8.5}
  ]
}
```

### Measurement Frequency (`measurement_frequency`)

Typical interval between measurements.

```json
{
  "measurement_frequency": {
    "typical_interval": "4 hours",
    "min_interval": "1 hour",
    "max_interval": "24 hours"
  }
}
```

### Missing Rate (`missing_rate`)

Percentage of missing values.

```json
{
  "missing_rate": 5.2
}
```

### Temporal Distribution (`temporal_distribution`)

Data coverage and distribution by year.

```json
{
  "temporal_distribution": {
    "start_date": "2018-01-15",
    "end_date": "2024-06-30",
    "by_year": [
      {"year": 2018, "percentage": 8.5},
      {"year": 2019, "percentage": 12.3},
      {"year": 2020, "percentage": 15.1},
      {"year": 2021, "percentage": 18.7},
      {"year": 2022, "percentage": 20.4},
      {"year": 2023, "percentage": 16.8},
      {"year": 2024, "percentage": 8.2}
    ]
  }
}
```

### Hospital Units Distribution (`hospital_units`)

Data distribution by hospital unit/ward.

```json
{
  "hospital_units": [
    {"unit": "MICU", "percentage": 22.5},
    {"unit": "SICU", "percentage": 18.3},
    {"unit": "CCU", "percentage": 15.7},
    {"unit": "NICU", "percentage": 12.1},
    {"unit": "PICU", "percentage": 8.9},
    {"unit": "Neuro ICU", "percentage": 7.2},
    {"unit": "Burn ICU", "percentage": 5.4},
    {"unit": "Cardiac ICU", "percentage": 4.8},
    {"unit": "Trauma ICU", "percentage": 3.2},
    {"unit": "Step-down", "percentage": 1.9}
  ]
}
```

### Complete Example (numeric)

```json
{
  "data_types": "numeric",
  "numeric_data": {
    "mean": 120.5,
    "sd": 15.3,
    "min": 60,
    "max": 250,
    "p5": 95,
    "p25": 110,
    "median": 118,
    "p75": 130,
    "p95": 150
  },
  "histogram": [
    {"x": 60, "count": 150},
    {"x": 80, "count": 2500},
    {"x": 100, "count": 5000},
    {"x": 120, "count": 4200},
    {"x": 140, "count": 1800}
  ],
  "measurement_frequency": {
    "typical_interval": "4 hours"
  },
  "missing_rate": 5.2,
  "temporal_distribution": {
    "start_date": "2018-01-15",
    "end_date": "2024-06-30",
    "by_year": [
      {"year": 2020, "percentage": 25.1},
      {"year": 2021, "percentage": 28.7},
      {"year": 2022, "percentage": 30.4},
      {"year": 2023, "percentage": 15.8}
    ]
  },
  "hospital_units": [
    {"unit": "MICU", "percentage": 22.5},
    {"unit": "SICU", "percentage": 18.3},
    {"unit": "CCU", "percentage": 15.7},
    {"unit": "NICU", "percentage": 12.1},
    {"unit": "PICU", "percentage": 8.9},
    {"unit": "Neuro ICU", "percentage": 7.2},
    {"unit": "Burn ICU", "percentage": 5.4},
    {"unit": "Cardiac ICU", "percentage": 4.8},
    {"unit": "Trauma ICU", "percentage": 3.2},
    {"unit": "Step-down", "percentage": 1.9}
  ]
}
```
'
      }

      # Render markdown to HTML
      tags$div(
        class = "markdown-content",
        style = "font-size: 13px; line-height: 1.6;",
        HTML(markdown::markdownToHTML(
          text = tutorial_md,
          fragment.only = TRUE,
          options = c("fragment_only", "base64_images", "smartypants")
        ))
      )
    }

    #### Target Concept Details Panel ----
    # Reactive to store the concept mappings table data (sorted as displayed)
    concept_mappings_table_data <- reactiveVal(NULL)

    # Reactive to store selected target concept data
    selected_target_concept_id <- reactiveVal(NULL)
    selected_target_json <- reactiveVal(NULL)
    selected_target_mapping <- reactiveVal(NULL)
    target_detail_tab <- reactiveVal("summary")  # "summary", "comments" or "statistical_summary"
    target_stats_sub_tab <- reactiveVal("summary")  # "summary" or "distribution"
    target_selected_profile <- reactiveVal(NULL)  # Selected profile name

    # Show/hide target concept details panel based on concept mapping selection (specific/detailed concept)
    observe_event(input$concept_mappings_table_rows_selected, {
      if (mapping_tab() != "edit_mappings") return()

      row_selected <- input$concept_mappings_table_rows_selected

      if (is.null(row_selected) || length(row_selected) == 0) {
        shinyjs::hide("target_concept_details_panel")
        selected_target_concept_id(NULL)
        selected_target_json(NULL)
        selected_target_mapping(NULL)
        return()
      }

      # Get selected concept mapping from stored table data (sorted as displayed)
      if (is.null(data())) return()

      # Allow selection in both normal mode (selected_general_concept_id set) and "all OMOP" mode
      if (is.null(selected_general_concept_id()) && !show_all_omop_concepts()) return()

      # Use the stored table data which matches the displayed order
      mappings_data <- concept_mappings_table_data()

      if (is.null(mappings_data) || nrow(mappings_data) == 0) return()
      if (row_selected > nrow(mappings_data)) return()

      selected_row <- mappings_data[row_selected, ]
      selected_target_mapping(selected_row)

      # Get the general concept info for this mapping
      gc_data <- data()$general_concepts
      if (is.null(gc_data) || nrow(gc_data) == 0) return()

      # In "all OMOP" mode, get general_concept_id from the selected row if available
      general_concept_id_to_use <- if (show_all_omop_concepts()) {
        # The row may have general_concept_name from the join - find the ID
        if (!is.null(selected_row$general_concept_name) && !is.na(selected_row$general_concept_name)) {
          gc_match <- gc_data %>%
            dplyr::filter(general_concept_name == selected_row$general_concept_name)
          if (nrow(gc_match) > 0) gc_match$general_concept_id[1] else NULL
        } else {
          NULL
        }
      } else {
        selected_general_concept_id()
      }

      # Create default JSON for visualization
      target_json <- list(
        data_types = NULL,
        numeric_data = NULL,
        histogram = NULL,
        categorical_data = NULL,
        measurement_frequency = NULL,
        missing_rate = NULL
      )

      if (!is.null(general_concept_id_to_use)) {
        selected_gc <- gc_data %>%
          dplyr::filter(general_concept_id == general_concept_id_to_use)

        if (nrow(selected_gc) > 0) {
          selected_target_concept_id(selected_gc$general_concept_id[1])

          # If the general concept has a statistical_summary JSON, parse it
          if ("statistical_summary" %in% names(selected_gc) && !is.null(selected_gc$statistical_summary[1]) && !is.na(selected_gc$statistical_summary[1]) && selected_gc$statistical_summary[1] != "") {
            target_json <- tryCatch(
              jsonlite::fromJSON(selected_gc$statistical_summary[1]),
              error = function(e) target_json
            )
          }
        }
      } else {
        # No general concept associated - still show panel with basic OMOP concept info
        selected_target_concept_id(NULL)
      }

      selected_target_json(target_json)
      shinyjs::show("target_concept_details_panel")
    }, ignoreNULL = FALSE)

    # Handle target tab selection
    observe_event(input$target_detail_tab_selected, {
      target_detail_tab(input$target_detail_tab_selected)
    })

    # Handle sub-tab selection for statistical summary
    observe_event(input$target_stats_sub_tab_click, {
      new_tab <- input$target_stats_sub_tab_click
      if (!is.null(new_tab) && new_tab %in% c("summary", "distribution")) {
        target_stats_sub_tab(new_tab)
      }
    }, ignoreInit = TRUE)

    # Handle profile selection for statistical summary
    observe_event(input$target_profile_change, {
      new_profile <- input$target_profile_change
      if (!is.null(new_profile)) {
        target_selected_profile(new_profile)
      }
    }, ignoreInit = TRUE)

    # Render target concept details content based on selected tab
    output$target_concept_details_content <- renderUI({
      json_data <- selected_target_json()
      concept_id <- selected_target_concept_id()
      mapping_data <- selected_target_mapping()
      tab <- target_detail_tab()
      sub_tab <- target_stats_sub_tab()
      current_profile <- target_selected_profile()

      # Show message only if no concept selected AND no mapping selected
      if (is.null(concept_id) && is.null(mapping_data)) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          i18n$t("select_concept_to_view")
        ))
      }

      if (tab == "summary") {
        # Display concept summary details (works with or without general concept)
        render_target_concept_summary(concept_id)
      } else if (tab == "comments") {
        # Display comments for the selected general concept
        render_target_comments(concept_id)
      } else if (tab == "statistical_summary") {
        # Statistical Summary tab with sub-tabs and profile dropdown
        ns <- session$ns

        # Get profile names from JSON
        profile_names <- get_profile_names(json_data)

        # Set default profile if not set
        if (is.null(current_profile) || !current_profile %in% profile_names) {
          current_profile <- get_default_profile_name(json_data)
          target_selected_profile(current_profile)
        }

        # Get profile data for selected profile
        profile_data <- get_profile_data(json_data, current_profile)

        if (is.null(profile_data) || (is.null(profile_data$numeric_data) && is.null(profile_data$categorical_data))) {
          return(tags$div(
            style = "color: #999; font-style: italic; padding: 15px;",
            "No statistical data available for this concept."
          ))
        }

        tags$div(
          class = "flex-column-full",
          # Header with sub-tabs (left) and profile dropdown (right)
          tags$div(
            style = "display: flex; justify-content: space-between; align-items: center; padding: 8px 10px; border-bottom: 1px solid #eee;",
            # Sub-tabs (Summary / Distribution) - top-left
            tags$div(
              class = "section-tabs",
              style = "position: static; transform: none; display: flex; gap: 5px;",
              tags$button(
                class = if (sub_tab == "summary") "tab-btn tab-btn-active" else "tab-btn",
                onclick = sprintf("Shiny.setInputValue('%s', 'summary', {priority: 'event'})", ns("target_stats_sub_tab_click")),
                "Summary"
              ),
              tags$button(
                class = if (sub_tab == "distribution") "tab-btn tab-btn-active" else "tab-btn",
                onclick = sprintf("Shiny.setInputValue('%s', 'distribution', {priority: 'event'})", ns("target_stats_sub_tab_click")),
                "Distribution"
              )
            ),
            # Profile dropdown (right) - only show if multiple profiles
            if (length(profile_names) > 1) {
              tags$div(
                class = "flex-center-gap-8",
                tags$span(style = "font-size: 11px; color: #666;", paste0(i18n$t("profile"), " :")),
                tags$select(
                  id = ns("target_profile_select"),
                  style = "font-size: 11px; padding: 2px 6px; border: 1px solid #ccc; border-radius: 4px;",
                  onchange = sprintf("Shiny.setInputValue('%s', this.value, {priority: 'event'})", ns("target_profile_change")),
                  lapply(profile_names, function(pn) {
                    is_selected <- !is.na(pn) && !is.na(current_profile) && pn == current_profile
                    tags$option(value = pn, selected = if (is_selected) "selected" else NULL, pn)
                  })
                )
              )
            }
          ),
          # Content area
          tags$div(
            style = "flex: 1; overflow-y: auto; padding: 10px;",
            if (sub_tab == "summary") {
              render_target_summary(profile_data, concept_id)
            } else {
              render_target_distribution(profile_data)
            }
          )
        )
      } else {
        tags$div("Unknown tab")
      }
    })

    # Helper function to render comments with fullscreen button
    # Factorized for use in both Edit Mappings and Evaluate Mappings tabs
    render_comments_panel <- function(concept_id, expand_button_id) {
      if (is.null(data())) return(tags$div(style = "color: #999;", "No data available."))

      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
        tags$div(
          class = "comments-container",
          style = "background: #ffffff; border: 1px solid #ccc; border-radius: 6px; height: 100%; overflow-y: auto; box-sizing: border-box; position: relative;",
          tags$div(
            style = "position: sticky; top: -1px; left: -1px; z-index: 100; height: 0;",
            actionButton(
              session$ns(expand_button_id),
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
            shiny::markdown(concept_info$comments[1])
          )
        )
      } else {
        tags$div(
          style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic; height: 100%; overflow-y: auto; box-sizing: border-box;",
          "No comments available for this concept."
        )
      }
    }

    # Wrapper for Edit Mappings tab
    render_target_comments <- function(concept_id) {
      render_comments_panel(concept_id, "expand_target_comments")
    }

    # Render target concept summary for Edit Mappings tab
    # Displays concept details like Selected Concept Details in Dictionary Explorer
    render_target_concept_summary <- function(concept_id) {
      # Get selected mapping data
      mapping_data <- selected_target_mapping()
      if (is.null(mapping_data)) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          "No mapping selected."
        ))
      }

      # Get OMOP concept ID from mapping
      omop_concept_id <- mapping_data$omop_concept_id
      if (is.null(omop_concept_id) || is.na(omop_concept_id)) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          "No OMOP concept available for this mapping."
        ))
      }

      # Use factorized function
      render_concept_summary_panel(concept_id, omop_concept_id, mapping_data)
    }

    # Factorized function for rendering concept summary panel
    # Used by both Edit Mappings and Evaluate Mappings tabs
    render_concept_summary_panel <- function(concept_id, omop_concept_id, mapping_data) {
      # Get general concept info (if concept_id is available)
      if (!is.null(concept_id) && !is.na(concept_id)) {
        general_concept_info <- data()$general_concepts %>%
          dplyr::filter(general_concept_id == concept_id)
      } else {
        general_concept_info <- data.frame()
      }

      # Get concept details from OHDSI vocabularies
      vocab_data <- vocabularies()
      if (is.null(vocab_data)) {
        return(tags$div(
          style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic;",
          "Vocabulary data not available."
        ))
      }

      concept_details <- vocab_data$concept %>%
        dplyr::filter(concept_id == !!omop_concept_id) %>%
        dplyr::collect()

      if (nrow(concept_details) == 0) {
        return(tags$div(
          style = "padding: 15px; background: #f8f9fa; border-radius: 6px; color: #999; font-style: italic;",
          "Concept details not found in vocabularies."
        ))
      }

      info <- concept_details[1, ]

      # Get concept mapping for unit info
      concept_mapping <- data()$concept_mappings %>%
        dplyr::filter(omop_concept_id == !!omop_concept_id)

      # Build URLs
      athena_url <- paste0(config$athena_base_url, "/", omop_concept_id)
      fhir_url <- build_fhir_url(info$vocabulary_id, info$concept_code, config)

      # Determine validity and standard
      is_valid <- is.na(info$invalid_reason) || info$invalid_reason == ""
      validity_color <- if (is_valid) "#28a745" else "#dc3545"
      validity_text <- if (is_valid) "Valid" else paste0("Invalid (", info$invalid_reason, ")")

      is_standard <- !is.na(info$standard_concept) && info$standard_concept == "S"
      standard_color <- if (is_standard) "#28a745" else "#dc3545"
      standard_text <- if (is_standard) "Standard" else "Non-standard"

      # Get unit concept info if available
      unit_concept_name <- NULL
      unit_concept_code <- NULL
      unit_concept_id <- NULL
      athena_unit_url <- NULL

      # Check for unit in mapping_data or concept_mapping
      unit_id <- NULL
      if (!is.null(mapping_data) && "omop_unit_concept_id" %in% names(mapping_data)) {
        unit_id <- mapping_data$omop_unit_concept_id
      } else if (nrow(concept_mapping) > 0) {
        unit_id <- concept_mapping$omop_unit_concept_id[1]
      }

      if (!is.null(unit_id) && !is.na(unit_id) && unit_id != "" && unit_id != "/") {
        unit_concept_id <- unit_id
        athena_unit_url <- paste0(config$athena_base_url, "/", unit_concept_id)

        unit_concept_info <- vocab_data$concept %>%
          dplyr::filter(concept_id == as.integer(unit_concept_id)) %>%
          dplyr::collect()
        if (nrow(unit_concept_info) > 0) {
          unit_concept_name <- unit_concept_info$concept_name[1]
          unit_concept_code <- unit_concept_info$concept_code[1]
        }
      }

      # Build Unit FHIR URL
      unit_fhir_url <- NULL
      if (!is.null(unit_concept_code)) {
        unit_fhir_url <- build_fhir_url("UCUM", unit_concept_code, config)
      }

      # Display concept details in grid layout
      tags$div(
        class = "concept-details-container",
        style = "display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(8, auto); grid-auto-flow: column; gap: 4px 15px; padding: 15px;",
        # Column 1 (8 items): Vocabulary ID, Concept Name, Category, Subcategory, Domain ID, Concept Class ID, Validity, Standard
        create_detail_item(i18n$t("vocabulary_id"), info$vocabulary_id, include_colon = FALSE),
        create_detail_item(i18n$t("concept_name"), info$concept_name, include_colon = FALSE),
        create_detail_item(i18n$t("category"),
                          ifelse(nrow(general_concept_info) > 0, general_concept_info$category[1], NA),
                          include_colon = FALSE),
        create_detail_item(i18n$t("subcategory"),
                          ifelse(nrow(general_concept_info) > 0, general_concept_info$subcategory[1], NA),
                          include_colon = FALSE),
        create_detail_item(i18n$t("domain_id"), if (!is.na(info$domain_id)) info$domain_id else "/", include_colon = FALSE),
        create_detail_item(i18n$t("concept_class"), if (!is.na(info$concept_class_id)) info$concept_class_id else "/", include_colon = FALSE),
        create_detail_item(i18n$t("validity"), validity_text, color = validity_color, include_colon = FALSE),
        create_detail_item(i18n$t("standard"), standard_text, color = standard_color, include_colon = FALSE),
        # Column 2 (8 items): Concept Code, OMOP Concept ID, FHIR Resource, Unit Concept Name, Unit Concept Code, Unit Concept ID, Unit FHIR Resource, Unit Conversions
        create_detail_item(i18n$t("concept_code"), info$concept_code, include_colon = FALSE),
        create_detail_item(i18n$t("omop_concept_id"), omop_concept_id, url = athena_url, include_colon = FALSE),
        if (!is.null(fhir_url) && fhir_url != "no_link") {
          tags$div(
            class = "detail-item",
            tags$strong(i18n$t("fhir_resource")),
            tags$a(
              href = fhir_url,
              target = "_blank",
              style = "color: #0f60af; text-decoration: underline;",
              i18n$t("view")
            )
          )
        } else {
          tags$div(
            class = "detail-item",
            tags$strong(i18n$t("fhir_resource")),
            tags$span(class = "text-muted-italic", "No link available")
          )
        },
        create_detail_item(i18n$t("unit_concept_name"),
                          if (!is.null(unit_concept_name)) unit_concept_name else "/",
                          include_colon = FALSE),
        create_detail_item(i18n$t("unit_concept_code"),
                          if (!is.null(unit_concept_code)) unit_concept_code else "/",
                          include_colon = FALSE),
        if (!is.null(athena_unit_url)) {
          create_detail_item(i18n$t("omop_unit_concept_id"), unit_concept_id, url = athena_unit_url, include_colon = FALSE)
        } else {
          create_detail_item(i18n$t("omop_unit_concept_id"), "/", include_colon = FALSE)
        },
        if (!is.null(unit_fhir_url) && unit_fhir_url != "no_link") {
          tags$div(
            class = "detail-item",
            tags$strong(i18n$t("unit_fhir_resource")),
            tags$a(
              href = unit_fhir_url,
              target = "_blank",
              style = "color: #0f60af; text-decoration: underline;",
              i18n$t("view")
            )
          )
        } else {
          tags$div(
            class = "detail-item",
            tags$strong(i18n$t("unit_fhir_resource")),
            tags$span(class = "text-muted-italic", "No link available")
          )
        },
        create_detail_item(i18n$t("unit_conversions"), "/", include_colon = FALSE)
      )
    }

    # Handle open comments modal from General Concepts header
    observe_event(input$open_comments_modal_click, {
      shinyjs::show("target_comments_fullscreen_modal")
    })

    # Handle expand comments button for target
    observe_event(input$expand_target_comments, {
      shinyjs::show("target_comments_fullscreen_modal")
    })

    # Handle close fullscreen comments modal
    observe_event(input$close_target_comments_fullscreen, {
      shinyjs::hide("target_comments_fullscreen_modal")
    })

    # Render fullscreen comments content
    output$target_comments_fullscreen_content <- renderUI({
      # Prioritize selected_general_concept_id (from header button) over selected_target_concept_id
      concept_id <- selected_general_concept_id()
      if (is.null(concept_id)) concept_id <- selected_target_concept_id()
      if (is.null(concept_id)) return(NULL)
      if (is.null(data())) return(NULL)

      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
        tags$div(
          style = "height: 100%; overflow-y: auto; padding: 20px;",
          tags$div(
            class = "markdown-content",
            shiny::markdown(concept_info$comments[1])
          )
        )
      } else {
        tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No comments available for this concept."
        )
      }
    })

    # Handle expand eval comments button
    observe_event(input$expand_eval_comments, {
      shinyjs::show("eval_comments_fullscreen_modal")
    })

    # Handle close eval fullscreen comments modal
    observe_event(input$close_eval_comments_fullscreen, {
      shinyjs::hide("eval_comments_fullscreen_modal")
    })

    # Render eval fullscreen comments content
    output$eval_comments_fullscreen_content <- renderUI({
      concept_id <- eval_target_concept_id()
      if (is.null(concept_id)) return(NULL)
      if (is.null(data())) return(NULL)

      concept_info <- data()$general_concepts %>%
        dplyr::filter(general_concept_id == concept_id)

      if (nrow(concept_info) > 0 && !is.na(concept_info$comments[1]) && nchar(concept_info$comments[1]) > 0) {
        tags$div(
          style = "height: 100%; overflow-y: auto; padding: 20px;",
          tags$div(
            class = "markdown-content",
            shiny::markdown(concept_info$comments[1])
          )
        )
      } else {
        tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No comments available for this concept."
        )
      }
    })

    # Handle view target global comment button click
    observe_event(input$view_target_global_comment, {
      # Switch to global comment view
      shinyjs::hide("target_concept_comment_container")
      shinyjs::show("target_global_comment_container")
      shinyjs::show("back_from_target_global_comment")
      shinyjs::hide("view_target_global_comment")
      shinyjs::runjs(sprintf(
        "$('#%s').text('%s')",
        ns("target_comments_modal_title"),
        i18n$t("global_comment")
      ))

      # Load and render global comment from file
      output$target_global_comment_display <- renderUI({
        content <- get_global_comment()

        if (is.null(content) || nchar(content) == 0) {
          return(
            tags$div(
              style = "height: 100%; padding: 10px; overflow-y: auto; background: #f8f9fa;",
              tags$div(
                style = "background: white; padding: 20px; border-radius: 8px; color: #999; font-style: italic; text-align: center; height: 100%;",
                i18n$t("no_global_comment")
              )
            )
          )
        }

        # Render markdown content with same styling as concept comment fullscreen view
        tags$div(
          style = "height: 100%; padding: 10px; overflow-y: auto; background: #f8f9fa;",
          tags$div(
            class = "markdown-content",
            style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.1); height: 100%; overflow-y: auto;",
            shiny::markdown(content)
          )
        )
      })
    }, ignoreInit = TRUE)

    # Handle back from target global comment button click
    observe_event(input$back_from_target_global_comment, {
      # Switch back to concept comment view
      shinyjs::hide("target_global_comment_container")
      shinyjs::show("target_concept_comment_container")
      shinyjs::hide("back_from_target_global_comment")
      shinyjs::show("view_target_global_comment")
      shinyjs::runjs(sprintf(
        "$('#%s').text('%s')",
        ns("target_comments_modal_title"),
        i18n$t("etl_guidance_comments")
      ))
    }, ignoreInit = TRUE)

    # Handle view eval global comment button click
    observe_event(input$view_eval_global_comment, {
      # Switch to global comment view
      shinyjs::hide("eval_concept_comment_container")
      shinyjs::show("eval_global_comment_container")
      shinyjs::show("back_from_eval_global_comment")
      shinyjs::hide("view_eval_global_comment")
      shinyjs::runjs(sprintf(
        "$('#%s').text('%s')",
        ns("eval_comments_modal_title"),
        i18n$t("global_comment")
      ))

      # Load and render global comment from file
      output$eval_global_comment_display <- renderUI({
        content <- get_global_comment()

        if (is.null(content) || nchar(content) == 0) {
          return(
            tags$div(
              style = "height: 100%; padding: 10px; overflow-y: auto; background: #f8f9fa;",
              tags$div(
                style = "background: white; padding: 20px; border-radius: 8px; color: #999; font-style: italic; text-align: center; height: 100%;",
                i18n$t("no_global_comment")
              )
            )
          )
        }

        # Render markdown content with same styling as concept comment fullscreen view
        tags$div(
          style = "height: 100%; padding: 10px; overflow-y: auto; background: #f8f9fa;",
          tags$div(
            class = "markdown-content",
            style = "background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.1); height: 100%; overflow-y: auto;",
            shiny::markdown(content)
          )
        )
      })
    }, ignoreInit = TRUE)

    # Handle back from eval global comment button click
    observe_event(input$back_from_eval_global_comment, {
      # Switch back to concept comment view
      shinyjs::hide("eval_global_comment_container")
      shinyjs::show("eval_concept_comment_container")
      shinyjs::hide("back_from_eval_global_comment")
      shinyjs::show("view_eval_global_comment")
      shinyjs::runjs(sprintf(
        "$('#%s').text('%s')",
        ns("eval_comments_modal_title"),
        i18n$t("etl_guidance_comments")
      ))
    }, ignoreInit = TRUE)

    # Handle view source JSON button (Edit Mappings)
    observe_event(input$view_source_json, {
      shinyjs::show("source_json_fullscreen_modal")
    })

    # Handle close source JSON fullscreen modal
    observe_event(input$close_source_json_fullscreen, {
      shinyjs::hide("source_json_fullscreen_modal")
    })

    # Render source JSON fullscreen content (Edit Mappings)
    output$source_json_fullscreen_content <- renderUI({
      json_data <- selected_source_json()
      if (is.null(json_data)) {
        return(tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No JSON data available."
        ))
      }

      # Pretty print the JSON
      json_text <- tryCatch({
        jsonlite::toJSON(json_data, pretty = TRUE, auto_unbox = TRUE)
      }, error = function(e) {
        as.character(json_data)
      })

      tags$pre(
        style = paste0(
          "margin: 0; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; ",
          "font-size: 11px; line-height: 1.5; white-space: pre-wrap; ",
          "word-wrap: break-word; color: #333;"
        ),
        as.character(json_text)
      )
    })

    # Render source JSON tutorial (Edit Mappings)
    output$source_json_tutorial <- renderUI({
      render_json_tutorial(Sys.getenv("INDICATE_LANGUAGE", "en"))
    })

    # Handle view eval source JSON button (Evaluate Mappings)
    observe_event(input$view_eval_source_json, {
      shinyjs::show("eval_source_json_fullscreen_modal")
    })

    # Handle close eval source JSON fullscreen modal
    observe_event(input$close_eval_source_json_fullscreen, {
      shinyjs::hide("eval_source_json_fullscreen_modal")
    })

    # Render eval source JSON fullscreen content (Evaluate Mappings)
    output$eval_source_json_fullscreen_content <- renderUI({
      json_data <- eval_source_json()
      if (is.null(json_data)) {
        return(tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No JSON data available."
        ))
      }

      # Pretty print the JSON
      json_text <- tryCatch({
        jsonlite::toJSON(json_data, pretty = TRUE, auto_unbox = TRUE)
      }, error = function(e) {
        as.character(json_data)
      })

      tags$pre(
        style = paste0(
          "margin: 0; font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; ",
          "font-size: 11px; line-height: 1.5; white-space: pre-wrap; ",
          "word-wrap: break-word; color: #333;"
        ),
        as.character(json_text)
      )
    })

    # Render eval source JSON tutorial (Evaluate Mappings)
    output$eval_source_json_tutorial <- renderUI({
      render_json_tutorial(Sys.getenv("INDICATE_LANGUAGE", "en"))
    })

    # Handle open category breakdown fullscreen button
    observe_event(input$open_category_breakdown_fullscreen, {
      shinyjs::show("category_breakdown_fullscreen_modal")
    })

    # Handle close category breakdown fullscreen modal
    observe_event(input$close_category_breakdown_fullscreen, {
      shinyjs::hide("category_breakdown_fullscreen_modal")
    })

    # Render category breakdown fullscreen content
    output$category_breakdown_fullscreen_content <- renderUI({
      if (is.null(selected_alignment_id())) return(NULL)

      # Get alignment info
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return(NULL)

      file_id <- alignment$file_id[1]
      mapping_dir <- get_app_dir("concept_mapping")
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))

      if (!file.exists(csv_path)) {
        return(tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "CSV file not found."
        ))
      }

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      if (!"category" %in% colnames(df)) {
        return(tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No category column in the source data."
        ))
      }

      total_source_concepts <- nrow(df)

      # Get mapped row_ids from database
      db_path <- file.path(get_app_dir(), "indicate.db")
      mapped_row_ids <- integer(0)

      if (file.exists(db_path)) {
        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        mapped_row_ids_query <- "SELECT DISTINCT row_id FROM concept_mappings WHERE alignment_id = ?"
        mapped_row_ids <- DBI::dbGetQuery(con, mapped_row_ids_query, params = list(selected_alignment_id()))$row_id
      }

      # Count mapped concepts per category
      df$is_mapped <- df$row_id %in% mapped_row_ids
      df$category_clean <- ifelse(
        is.na(df$category) | df$category == "",
        "Uncategorized",
        as.character(df$category)
      )

      # Aggregate by category
      category_data <- df %>%
        dplyr::group_by(category_clean) %>%
        dplyr::summarise(
          total = dplyr::n(),
          mapped = sum(is_mapped),
          .groups = "drop"
        ) %>%
        dplyr::rename(category = category_clean) %>%
        dplyr::arrange(dplyr::desc(total))

      if (nrow(category_data) == 0) {
        return(tags$div(
          style = "padding: 20px; color: #999; font-style: italic;",
          "No category data available."
        ))
      }

      # Render with tab buttons for distribution/completion
      tags$div(
        class = "flex-column-full",
        # Controls row: Tab buttons, search, and sort
        tags$div(
          style = "display: flex; align-items: center; gap: 15px; margin-bottom: 15px; flex-wrap: wrap;",
          # Tab buttons
          tags$div(
            style = "display: flex; gap: 8px;",
            tags$button(
              id = ns("fullscreen_tab_distribution"),
              class = "btn btn-sm",
              style = paste0(
                "padding: 6px 16px; font-size: 13px; border-radius: 4px; ",
                "border: 1px solid #0f60af; background: #0f60af; color: white; cursor: pointer;"
              ),
              onclick = sprintf(
                "document.getElementById('%s').style.display='block'; document.getElementById('%s').style.display='none'; this.style.background='#0f60af'; this.style.color='white'; document.getElementById('%s').style.background='white'; document.getElementById('%s').style.color='#28a745';",
                ns("fullscreen_distribution_content"), ns("fullscreen_completion_content"),
                ns("fullscreen_tab_completion"), ns("fullscreen_tab_completion")
              ),
              i18n$t("distribution")
            ),
            tags$button(
              id = ns("fullscreen_tab_completion"),
              class = "btn btn-sm",
              style = paste0(
                "padding: 6px 16px; font-size: 13px; border-radius: 4px; ",
                "border: 1px solid #28a745; background: white; color: #28a745; cursor: pointer;"
              ),
              onclick = sprintf(
                "document.getElementById('%s').style.display='none'; document.getElementById('%s').style.display='block'; this.style.background='#28a745'; this.style.color='white'; document.getElementById('%s').style.background='white'; document.getElementById('%s').style.color='#0f60af';",
                ns("fullscreen_distribution_content"), ns("fullscreen_completion_content"),
                ns("fullscreen_tab_distribution"), ns("fullscreen_tab_distribution")
              ),
              i18n$t("completion")
            )
          ),
          # Spacer
          tags$div(class = "flex-1"),
          # Search input
          tags$div(
            class = "flex-center-gap-8",
            tags$input(
              id = ns("fullscreen_category_search"),
              type = "text",
              placeholder = i18n$t("search_categories"),
              style = "padding: 6px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px; width: 200px;",
              oninput = sprintf("window.filterCategoryBreakdown('%s', '%s', this.value);",
                ns("fullscreen_distribution_content"), ns("fullscreen_completion_content"))
            )
          ),
          # Sort dropdown
          tags$div(
            class = "flex-center-gap-8",
            tags$label(
              style = "font-size: 13px; color: #666; margin: 0;",
              i18n$t("sort_by")
            ),
            tags$select(
              id = ns("fullscreen_category_sort"),
              style = "padding: 6px 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px; cursor: pointer;",
              onchange = sprintf("window.sortCategoryBreakdown('%s', '%s', this.value);",
                ns("fullscreen_distribution_content"), ns("fullscreen_completion_content")),
              tags$option(value = "rate_desc", i18n$t("sort_rate_desc")),
              tags$option(value = "rate_asc", i18n$t("sort_rate_asc")),
              tags$option(value = "alpha_asc", i18n$t("sort_alpha_asc")),
              tags$option(value = "alpha_desc", i18n$t("sort_alpha_desc"))
            )
          )
        ),
        # Distribution view (blue bars with hatched completion overlay)
        tags$div(
          id = ns("fullscreen_distribution_content"),
          style = "flex: 1; overflow-y: auto;",
          lapply(seq_len(nrow(category_data)), function(i) {
            cat_name <- category_data$category[i]
            cat_total <- category_data$total[i]
            cat_mapped <- category_data$mapped[i]
            pct_total <- round(cat_total / total_source_concepts * 100, 1)
            pct_mapped_of_total <- if (cat_total > 0) round(cat_mapped / cat_total * 100, 1) else 0
            tags$div(
              class = "category-bar-item",
              `data-category` = tolower(cat_name),
              `data-rate` = pct_total,
              style = "margin-bottom: 12px;",
              tags$div(
                style = "display: flex; justify-content: space-between; font-size: 14px; margin-bottom: 4px;",
                tags$span(
                  class = "category-name",
                  style = "max-width: 70%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;",
                  cat_name
                ),
                tags$span(
                  class = "text-secondary",
                  sprintf("%d (%s%%)", cat_total, pct_total)
                )
              ),
              # Blue bar for distribution with hatched completion overlay
              tags$div(
                style = "background: #e9ecef; border-radius: 4px; height: 16px; overflow: hidden; position: relative;",
                # Base blue bar (full distribution width)
                tags$div(
                  style = sprintf(
                    "background: #0f60af; width: %s%%; height: 100%%; position: relative;",
                    pct_total
                  ),
                  # Hatched overlay for completed portion
                  tags$div(
                    style = sprintf(
                      paste0(
                        "position: absolute; left: 0; top: 0; height: 100%%; width: %s%%; ",
                        "background: repeating-linear-gradient(",
                        "45deg, ",
                        "rgba(255,255,255,0.3), ",
                        "rgba(255,255,255,0.3) 2px, ",
                        "transparent 2px, ",
                        "transparent 4px",
                        ");"
                      ),
                      pct_mapped_of_total
                    )
                  )
                )
              )
            )
          })
        ),
        # Completion view (green bars, sorted by completion %)
        {
          # Sort by completion percentage descending for fullscreen
          category_data_by_completion <- category_data %>%
            dplyr::mutate(pct_mapped = ifelse(total > 0, mapped / total * 100, 0)) %>%
            dplyr::arrange(dplyr::desc(pct_mapped))

          tags$div(
            id = ns("fullscreen_completion_content"),
            style = "flex: 1; overflow-y: auto; display: none;",
            lapply(seq_len(nrow(category_data_by_completion)), function(i) {
              cat_name <- category_data_by_completion$category[i]
              cat_total <- category_data_by_completion$total[i]
              cat_mapped <- category_data_by_completion$mapped[i]
              pct_mapped <- round(category_data_by_completion$pct_mapped[i], 1)
              tags$div(
                class = "category-bar-item",
                `data-category` = tolower(cat_name),
                `data-rate` = pct_mapped,
                style = "margin-bottom: 12px;",
                tags$div(
                  style = "display: flex; justify-content: space-between; font-size: 14px; margin-bottom: 4px;",
                  tags$span(
                    class = "category-name",
                    style = "max-width: 70%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;",
                    cat_name
                  ),
                  tags$span(
                    class = "text-secondary",
                    sprintf("%d / %d (%s%%)", cat_mapped, cat_total, pct_mapped)
                  )
                ),
                # Green bar for completion (full bar = 100% mapped)
                tags$div(
                  style = "background: #e9ecef; border-radius: 4px; height: 16px; overflow: hidden;",
                  tags$div(
                    style = sprintf(
                      "background: #28a745; width: %s%%; height: 100%%;",
                      pct_mapped
                    )
                  )
                )
              )
            })
          )
        },
        # JavaScript for filter and sort
        tags$script(HTML(sprintf("
          window.filterCategoryBreakdown = function(distId, compId, searchText) {
            var searchLower = searchText.toLowerCase();
            ['#' + distId, '#' + compId].forEach(function(containerId) {
              $(containerId + ' .category-bar-item').each(function() {
                var category = $(this).data('category') || '';
                if (category.indexOf(searchLower) !== -1 || searchText === '') {
                  $(this).show();
                } else {
                  $(this).hide();
                }
              });
            });
          };

          window.sortCategoryBreakdown = function(distId, compId, sortType) {
            ['#' + distId, '#' + compId].forEach(function(containerId) {
              var $container = $(containerId);
              var $items = $container.find('.category-bar-item').detach();

              $items.sort(function(a, b) {
                var aCategory = $(a).data('category') || '';
                var bCategory = $(b).data('category') || '';
                var aRate = parseFloat($(a).data('rate')) || 0;
                var bRate = parseFloat($(b).data('rate')) || 0;

                switch(sortType) {
                  case 'rate_desc':
                    return bRate - aRate;
                  case 'rate_asc':
                    return aRate - bRate;
                  case 'alpha_asc':
                    return aCategory.localeCompare(bCategory);
                  case 'alpha_desc':
                    return bCategory.localeCompare(aCategory);
                  default:
                    return 0;
                }
              });

              $container.append($items);
            });
          };
        ")))
      )
    })

    # Target summary render - uses shared render_stats_summary_panel from fct_statistics_display.R
    # profile_data: Profile data from target (already extracted via get_profile_data)
    # source_json: Raw source JSON (will extract profile data internally)
    render_summary_panel <- function(profile_data, concept_id, mapping_data, source_row, source_json) {
      vocab_data <- vocabularies()
      target_unit_name <- NULL
      source_unit_name <- NULL

      # Extract source profile data
      source_profile <- if (!is.null(source_json)) get_profile_data(source_json) else NULL

      # Get target unit name from vocabulary
      if (!is.null(mapping_data) && "omop_unit_concept_id" %in% names(mapping_data)) {
        unit_concept_id <- mapping_data$omop_unit_concept_id
        if (!is.null(unit_concept_id) && !is.na(unit_concept_id) && unit_concept_id != "" && unit_concept_id != "/") {
          if (!is.null(vocab_data) && !is.null(vocab_data$concept)) {
            unit_info <- vocab_data$concept %>%
              dplyr::filter(concept_id == as.integer(unit_concept_id)) %>%
              head(1) %>%
              dplyr::collect()
            if (nrow(unit_info) > 0 && !is.null(unit_info$concept_name)) {
              target_unit_name <- unit_info$concept_name
            }
          }
        }
      }

      # Get source unit name for comparison
      if (!is.null(source_row) && "unit" %in% names(source_row)) {
        source_unit <- source_row$unit
        if (!is.null(source_unit) && !is.na(source_unit) && source_unit != "" && source_unit != "/") {
          source_unit_name <- source_unit
        }
      }

      # Use the shared render function from fct_statistics_display.R
      # Don't show missing_rate and measurement_frequency for Target Concept Details
      # as these are source-specific stats (not relevant for EHDEN target data)
      render_stats_summary_panel(
        profile_data = profile_data,
        source_data = source_profile,
        row_data = NULL,  # Concept Mapping doesn't have row/patient counts
        target_unit_name = target_unit_name,
        source_unit_name = source_unit_name,
        show_source_specific_stats = FALSE
      )
    }

    # Wrapper for Edit Mappings tab
    render_target_summary <- function(profile_data, concept_id) {
      render_summary_panel(profile_data, concept_id, selected_target_mapping(), selected_source_row(), selected_source_json())
    }

    # Factorized helper function for parsing histogram data (supports both x and bin_start/bin_end formats)
    parse_histogram_data <- function(histogram_list) {
      if (is.null(histogram_list) || length(histogram_list) == 0) return(NULL)
      hist_df <- as.data.frame(histogram_list)
      if (nrow(hist_df) == 0 || !"count" %in% colnames(hist_df)) return(NULL)

      if ("x" %in% colnames(hist_df)) {
        hist_df$bin_mid <- hist_df$x
      } else if ("bin_start" %in% colnames(hist_df) && "bin_end" %in% colnames(hist_df)) {
        hist_df$bin_mid <- (hist_df$bin_start + hist_df$bin_end) / 2
      } else {
        return(NULL)
      }

      total_count <- sum(hist_df$count, na.rm = TRUE)
      hist_df$percentage <- if (total_count > 0) hist_df$count / total_count * 100 else 0
      hist_df
    }

    # Wrapper for Edit Mappings tab (uses selected_source_json)
    # Uses shared render_stats_distribution_panel from fct_statistics_display.R
    render_target_distribution <- function(profile_data) {
      source_profile <- if (!is.null(selected_source_json())) get_profile_data(selected_source_json()) else NULL
      render_stats_distribution_panel(profile_data, source_profile)
    }

    # Wrapper for Evaluate Mappings tab (uses eval_source_json)
    # Uses shared render_stats_distribution_panel from fct_statistics_display.R
    render_eval_target_distribution <- function(profile_data) {
      source_profile <- if (!is.null(eval_source_json())) get_profile_data(eval_source_json()) else NULL
      render_stats_distribution_panel(profile_data, source_profile)
    }

    #### Modal - Concept Details ----
    #### Modal - ETL Comments ----
    #### Add/Remove Mapping Actions ----
    observe_event(c(mapping_view(), selected_general_concept_id(), show_all_omop_concepts(), input$source_concepts_table_rows_selected, input$concept_mappings_table_rows_selected), {
      # Check permission first
      if (!user_has_permission("alignments", "add_mapping")) {
        shinyjs::hide("add_mapping_from_general")
        return()
      }

      if (mapping_view() != "general") {
        shinyjs::hide("add_mapping_from_general")
        return()
      }

      # Allow button in both normal mode and "all OMOP" mode
      if (is.null(selected_general_concept_id()) && !show_all_omop_concepts()) {
        shinyjs::hide("add_mapping_from_general")
        return()
      }

      source_selected <- !is.null(input$source_concepts_table_rows_selected)
      mapping_selected <- !is.null(input$concept_mappings_table_rows_selected)

      if (source_selected && mapping_selected) {
        shinyjs::show("add_mapping_from_general")
      } else {
        shinyjs::hide("add_mapping_from_general")
      }
    })
    
    observe_event(input$add_mapping_from_general, {
      # Check permissions
      if (!user_has_permission("alignments", "add_mapping")) return()

      source_row <- input$source_concepts_table_rows_selected
      mapping_row <- input$concept_mappings_table_rows_selected

      # Determine which mode we're in
      if (!is.null(selected_general_concept_id())) {
        # Normal mode: specific general concept selected
        if (is.null(source_row) || is.null(mapping_row)) return()
      } else if (show_all_omop_concepts()) {
        # "All OMOP" mode: concept selected from full vocabulary list
        if (is.null(source_row) || is.null(mapping_row)) return()
      } else {
        # Fallback: general concept table selection
        general_row <- input$general_concepts_table_rows_selected
        if (is.null(source_row) || is.null(general_row)) return()
      }

      if (is.null(selected_alignment_id())) return()

      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())

      if (nrow(alignment) != 1) return()

      file_id <- alignment$file_id[1]

      mapping_dir <- get_app_dir("concept_mapping")
      csv_filename <- paste0(file_id, ".csv")
      csv_path <- file.path(mapping_dir, csv_filename)

      if (!file.exists(csv_path)) return()

      df <- read.csv(csv_path, stringsAsFactors = FALSE)

      if (is.null(data())) return()

      if (!is.null(selected_general_concept_id())) {
        # Normal mode: specific general concept selected
        target_general_concept_id <- selected_general_concept_id()

        # Use stored table data which matches displayed order
        mappings_data <- concept_mappings_table_data()

        if (is.null(mappings_data) || nrow(mappings_data) == 0) return()
        if (mapping_row > nrow(mappings_data)) return()

        selected_mapping <- mappings_data[mapping_row, ]

        # Determine if it's a custom concept or OMOP concept
        if (isTRUE(selected_mapping$is_custom)) {
          target_omop_concept_id <- NA_integer_
          # For custom concepts, we need to get the custom_concept_id
          # The custom_concept_id is not in the displayed data, so look it up
          custom_concepts_path <- get_csv_path("custom_concepts.csv")
          if (file.exists(custom_concepts_path)) {
            custom_concepts_all <- readr::read_csv(custom_concepts_path, show_col_types = FALSE)
            custom_match <- custom_concepts_all %>%
              dplyr::filter(
                general_concept_id == target_general_concept_id,
                concept_name == selected_mapping$concept_name
              )
            if (nrow(custom_match) > 0) {
              target_custom_concept_id <- custom_match$custom_concept_id[1]
            } else {
              target_custom_concept_id <- NA_integer_
            }
          } else {
            target_custom_concept_id <- NA_integer_
          }
        } else {
          target_omop_concept_id <- selected_mapping$omop_concept_id
          target_custom_concept_id <- NA_integer_
        }
      } else if (show_all_omop_concepts()) {
        # "All OMOP" mode: get the selected OMOP concept from the table
        mappings_data <- concept_mappings_table_data()

        if (is.null(mappings_data) || nrow(mappings_data) == 0) return()
        if (mapping_row > nrow(mappings_data)) return()

        selected_mapping <- mappings_data[mapping_row, ]
        target_omop_concept_id <- selected_mapping$omop_concept_id
        target_custom_concept_id <- NA_integer_

        # Try to find the general_concept_id if the concept is mapped in dictionary
        gc_data <- data()$general_concepts
        if (!is.null(selected_mapping$general_concept_name) && !is.na(selected_mapping$general_concept_name)) {
          gc_match <- gc_data %>%
            dplyr::filter(general_concept_name == selected_mapping$general_concept_name)
          if (nrow(gc_match) > 0) {
            target_general_concept_id <- gc_match$general_concept_id[1]
          } else {
            target_general_concept_id <- NA_integer_
          }
        } else {
          target_general_concept_id <- NA_integer_
        }
      } else {
        # Fallback: general concept table selection (no specific mapping)
        general_row <- input$general_concepts_table_rows_selected
        general_concepts <- data()$general_concepts
        target_general_concept_id <- general_concepts$general_concept_id[general_row]

        if (is.na(target_general_concept_id)) return()

        concept_mappings_dict <- data()$concept_mappings %>%
          dplyr::filter(general_concept_id == target_general_concept_id)

        target_omop_concept_id <- NA_integer_
        target_custom_concept_id <- NA_integer_
        if (nrow(concept_mappings_dict) > 0) {
          target_omop_concept_id <- concept_mappings_dict$omop_concept_id[1]
        }
      }
      
      # Get the actual row_id from displayed data (handles fuzzy filtering)
      displayed_data <- source_concepts_data()
      if (is.null(displayed_data) || source_row > nrow(displayed_data)) return()
      csv_row_id <- displayed_data$row_id[source_row]

      con <- get_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Check if this exact mapping already exists (same source + same target)
      # Use row_id to match both manual and imported mappings
      existing_exact <- DBI::dbGetQuery(
        con,
        "SELECT mapping_id FROM concept_mappings
         WHERE alignment_id = ?
           AND row_id = ?
           AND target_general_concept_id = ?
           AND (target_omop_concept_id = ? OR (target_omop_concept_id IS NULL AND ? IS NULL))
           AND (target_custom_concept_id = ? OR (target_custom_concept_id IS NULL AND ? IS NULL))",
        params = list(
          selected_alignment_id(),
          csv_row_id,
          target_general_concept_id,
          target_omop_concept_id, target_omop_concept_id,
          target_custom_concept_id, target_custom_concept_id
        )
      )

      if (nrow(existing_exact) > 0) {
        showNotification(
          i18n$t("mapping_already_exists"),
          type = "warning",
          duration = 3
        )
        return()
      }

      mapping_datetime <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      user_id <- if (!is.null(current_user())) current_user()$user_id else NA_integer_

      # Always insert new mapping (multiple mappings per source concept are allowed)
      DBI::dbExecute(
        con,
        "INSERT INTO concept_mappings (
          alignment_id,
          csv_file_path,
          row_id,
          target_general_concept_id,
          target_omop_concept_id,
          target_custom_concept_id,
          mapped_by_user_id,
          mapping_datetime
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        params = list(
          selected_alignment_id(),
          csv_filename,
          csv_row_id,
          target_general_concept_id,
          target_omop_concept_id,
          target_custom_concept_id,
          user_id,
          mapping_datetime
        )
      )

      # Show success notification
      showNotification(
        i18n$t("mapping_added_successfully"),
        type = "message",
        duration = 2
      )

      # Refresh tables
      source_concepts_table_trigger(source_concepts_table_trigger() + 1)
      all_mappings_table_trigger(all_mappings_table_trigger() + 1)
      evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)

      # Reselect the source row after data refresh
      shinyjs::delay(200, {
        proxy <- DT::dataTableProxy("source_concepts_table", session = session)
        DT::selectRows(proxy, source_row)
      })
    })
    
    observe_event(input$remove_mapping, {
      # Check permissions
      if (!user_has_permission("alignments", "delete_mappings")) return()

      row_num <- input$remove_mapping

      if (is.null(selected_alignment_id())) return()
      alignments <- alignments_data()
      alignment <- alignments %>%
        dplyr::filter(alignment_id == selected_alignment_id())
      if (nrow(alignment) != 1) return()
      
      file_id <- alignment$file_id[1]
      
      mapping_dir <- get_app_dir("concept_mapping")
      
      csv_path <- file.path(mapping_dir, paste0(file_id, ".csv"))
      
      if (!file.exists(csv_path)) {
        return()
      }
      
      df <- read.csv(csv_path, stringsAsFactors = FALSE)
      
      if (!"target_general_concept_id" %in% colnames(df)) {
        return()
      }
      
      mapped_rows_indices <- which(!is.na(df$target_general_concept_id))
      
      if (row_num > length(mapped_rows_indices)) {
        return()
      }
      
      actual_row <- mapped_rows_indices[row_num]
      
      df$target_general_concept_id[actual_row] <- NA_integer_
      df$target_omop_concept_id[actual_row] <- NA_integer_
      
      write.csv(df, csv_path, row.names = FALSE)

      source_concepts_table_trigger(source_concepts_table_trigger() + 1)
      all_mappings_table_trigger(all_mappings_table_trigger() + 1)
      evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    })
    
    ### d) Evaluate Mappings Tab ----
    #### Evaluate Mappings Table Rendering ----
    # Render table when trigger fires
    observe_event(evaluate_mappings_table_trigger(), {
      # Check prerequisites first
      if (is.null(selected_alignment_id())) return()
      if (is.null(current_user())) return()

      # Prepare data outside renderDT
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings with evaluation status for current user, mapped by user info, and comment count
      query <- "
        SELECT
          cm.mapping_id,
          cm.row_id,
          cm.target_general_concept_id,
          cm.target_omop_concept_id,
          cm.target_custom_concept_id,
          cm.csv_file_path,
          cm.imported_mapping_id,
          cm.mapping_datetime,
          cm.mapped_by_user_id,
          cm.imported_user_name,
          u.first_name as mapped_by_first_name,
          u.last_name as mapped_by_last_name,
          me.is_approved,
          me.comment,
          COALESCE((SELECT COUNT(*) FROM mapping_comments mc WHERE mc.mapping_id = cm.mapping_id), 0) as comments_count
        FROM concept_mappings cm
        LEFT JOIN mapping_evaluations me
          ON cm.mapping_id = me.mapping_id
          AND me.evaluator_user_id = ?
        LEFT JOIN users u
          ON cm.mapped_by_user_id = u.user_id
        WHERE cm.alignment_id = ?
      "

      mappings_db <- DBI::dbGetQuery(
        con,
        query,
        params = list(current_user()$user_id, selected_alignment_id())
      )

      if (nrow(mappings_db) == 0) {
        output$evaluate_mappings_table <- DT::renderDT({
          create_empty_datatable("No mappings created yet.")
        }, server = TRUE)
        return()
      }

      # Read CSV to get source concept names (if file exists)
      csv_filename <- mappings_db$csv_file_path[1]
      csv_path <- file.path(get_app_dir("concept_mapping"), csv_filename)

      df <- NULL
      if (!is.na(csv_filename) && file.exists(csv_path)) {
        df <- read.csv(csv_path, stringsAsFactors = FALSE)
      }

      # Enrich with source concept information by matching row_id (DB) with row_id (CSV)
      if (!is.null(df) && "row_id" %in% colnames(df)) {
        # Join on row_id column from CSV with row_id from DB
        source_cols <- c("row_id")
        if ("concept_name" %in% colnames(df)) source_cols <- c(source_cols, "concept_name")
        if ("concept_code" %in% colnames(df)) source_cols <- c(source_cols, "concept_code")
        if ("vocabulary_id" %in% colnames(df)) source_cols <- c(source_cols, "vocabulary_id")
        if ("category" %in% colnames(df)) source_cols <- c(source_cols, "category")

        source_df <- df[, source_cols, drop = FALSE]
        colnames(source_df) <- c("row_id",
          if ("concept_name" %in% colnames(df)) "source_concept_name" else NULL,
          if ("concept_code" %in% colnames(df)) "source_concept_code" else NULL,
          if ("vocabulary_id" %in% colnames(df)) "source_vocabulary_id" else NULL,
          if ("category" %in% colnames(df)) "source_category" else NULL
        )

        enriched_data <- mappings_db %>%
          dplyr::left_join(source_df, by = "row_id")

        # Fill in defaults for missing columns
        if (!"source_concept_name" %in% colnames(enriched_data)) {
          enriched_data <- enriched_data %>%
            dplyr::mutate(source_concept_name = paste0("Source concept #", row_id))
        } else {
          enriched_data <- enriched_data %>%
            dplyr::mutate(source_concept_name = dplyr::if_else(
              is.na(source_concept_name),
              paste0("Source concept #", row_id),
              source_concept_name
            ))
        }
        if (!"source_concept_code" %in% colnames(enriched_data)) {
          enriched_data <- enriched_data %>%
            dplyr::mutate(source_concept_code = NA_character_)
        }
        if (!"source_vocabulary_id" %in% colnames(enriched_data)) {
          enriched_data <- enriched_data %>%
            dplyr::mutate(source_vocabulary_id = NA_character_)
        }
        if (!"source_category" %in% colnames(enriched_data)) {
          enriched_data <- enriched_data %>%
            dplyr::mutate(source_category = NA_character_)
        }
      } else {
        # Fallback for CSV without row_id column
        enriched_data <- mappings_db %>%
          dplyr::mutate(
            source_concept_name = paste0("Source concept #", row_id),
            source_concept_code = NA_character_,
            source_vocabulary_id = NA_character_,
            source_category = NA_character_
          )
      }

      # Enrich with target general concept information
      general_concepts <- data()$general_concepts

      enriched_data <- enriched_data %>%
        dplyr::left_join(
          general_concepts %>%
            dplyr::select(general_concept_id, target_general_concept_name = general_concept_name),
          by = c("target_general_concept_id" = "general_concept_id")
        )

      # Enrich with target concept info (OMOP or custom)
      enriched_data <- enrich_target_concepts(enriched_data, vocabularies(), data())

      # Add status column
      enriched_data <- enriched_data %>%
        dplyr::mutate(
          status = dplyr::case_when(
            is.na(is_approved) ~ as.character(i18n$t("not_evaluated")),
            is_approved == 1 ~ as.character(i18n$t("approved")),
            is_approved == 0 ~ as.character(i18n$t("rejected")),
            is_approved == -1 ~ as.character(i18n$t("uncertain")),
            TRUE ~ as.character(i18n$t("not_evaluated"))
          )
        )

        # Add row index for actions
        enriched_data <- enriched_data %>%
          dplyr::mutate(row_index = dplyr::row_number())

        # Store current user info for comparison
        current_user_id <- current_user()$user_id
        current_user_fullname <- trimws(paste(
          current_user()$first_name %||% "",
          current_user()$last_name %||% ""
        ))

        # Create action buttons HTML (or message if user created the mapping)
        enriched_data <- enriched_data %>%
          dplyr::rowwise() %>%
          dplyr::mutate(
            comments_badge = if (comments_count > 0) {
              sprintf('<span style="position: absolute; top: -6px; right: -6px; background: #dc3545; color: white; border-radius: 50%%; font-size: 10px; min-width: 16px; height: 16px; display: flex; align-items: center; justify-content: center; padding: 0 4px;">%d</span>', comments_count)
            } else {
              ""
            },
            is_own_mapping = (!is.na(mapped_by_user_id) && mapped_by_user_id == current_user_id) ||
              (!is.na(imported_user_name) && current_user_fullname != "" && imported_user_name == current_user_fullname),
            Actions = if (is_own_mapping) {
              # User can't evaluate own mappings, but can still view/add comments
              sprintf(
                '<div style="display: flex; gap: 5px; justify-content: center; align-items: center;">
                  <button class="btn-eval-action btn-comments" data-action="comments" data-mapping-id="%d" title="%s" style="position: relative;">
                    <i class="fas fa-comment"></i>%s
                  </button>
                </div>',
                mapping_id,
                i18n$t("mapping_comments"),
                comments_badge
              )
            } else {
              sprintf(
                '<div style="display: flex; gap: 5px; justify-content: center;">
                  <button class="btn-eval-action" data-action="approve" data-row="%d" data-mapping-id="%d" title="Approve">
                    <i class="fas fa-check"></i>
                  </button>
                  <button class="btn-eval-action" data-action="reject" data-row="%d" data-mapping-id="%d" title="Reject">
                    <i class="fas fa-times"></i>
                  </button>
                  <button class="btn-eval-action" data-action="uncertain" data-row="%d" data-mapping-id="%d" title="Uncertain">
                    <i class="fas fa-question"></i>
                  </button>
                  <button class="btn-eval-action" data-action="clear" data-row="%d" data-mapping-id="%d" title="Clear Evaluation">
                    <i class="fas fa-redo"></i>
                  </button>
                  <button class="btn-eval-action btn-comments" data-action="comments" data-mapping-id="%d" title="%s" style="position: relative;">
                    <i class="fas fa-comment"></i>%s
                  </button>
                </div>',
                row_index, mapping_id,
                row_index, mapping_id,
                row_index, mapping_id,
                row_index, mapping_id,
                mapping_id, i18n$t("mapping_comments"), comments_badge
              )
            }
          ) %>%
          dplyr::ungroup()

        # Build display columns like in All Completed Mappings
        display_data <- enriched_data %>%
          dplyr::mutate(
            Source = paste0(source_concept_name, " (", source_vocabulary_id, ": ", source_concept_code, ")"),
            Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
            Category = factor(dplyr::if_else(is.na(source_category) | source_category == "", "/", source_category)),
            status = factor(status, levels = c(
              as.character(i18n$t("not_evaluated")),
              as.character(i18n$t("approved")),
              as.character(i18n$t("rejected")),
              as.character(i18n$t("uncertain"))
            )),
            Origin = dplyr::if_else(
              is.na(imported_mapping_id),
              sprintf('<span style="background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("manual")),
              sprintf('<span style="background: #0f60af; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("imported"))
            ),
            Mapped_By = factor(dplyr::case_when(
              !is.na(mapped_by_first_name) | !is.na(mapped_by_last_name) ~
                trimws(paste0(
                  dplyr::if_else(is.na(mapped_by_first_name), "", mapped_by_first_name),
                  " ",
                  dplyr::if_else(is.na(mapped_by_last_name), "", mapped_by_last_name)
                )),
              !is.na(imported_user_name) ~ imported_user_name,
              TRUE ~ "/"
            )),
            Added = dplyr::if_else(
              is.na(mapping_datetime) | mapping_datetime == "",
              "/",
              mapping_datetime
            )
          ) %>%
          dplyr::select(
            Category,
            Source,
            Target,
            Origin,
            Mapped_By,
            Added,
            status,
            Actions
          )

      # Render table with prepared data
      # Using selection = "none" to handle row selection manually via JavaScript
      # This prevents action button clicks from affecting row selection
      output$evaluate_mappings_table <- DT::renderDT({
        dt <- DT::datatable(
          display_data,
          rownames = FALSE,
          selection = "none",
          escape = FALSE,
          filter = "top",
          extensions = "Buttons",
          options = list(
            pageLength = 8,
            lengthMenu = c(5, 8, 10, 15, 20, 50, 100),
            dom = "Bltip",
            buttons = list("colvis"),
            ordering = TRUE,
            autoWidth = FALSE,
            stateSave = TRUE,
            language = get_datatable_language(),
            columnDefs = list(
              list(targets = 0, width = "10%"),
              list(targets = 1, width = "22%"),
              list(targets = 2, width = "22%"),
              list(targets = 3, width = "8%", className = "dt-center"),
              list(targets = 4, width = "12%"),
              list(targets = 5, width = "10%"),
              list(targets = 6, width = "8%"),
              list(targets = 7, width = "18%", orderable = FALSE, searchable = FALSE, className = "dt-center no-select")
            )
          ),
          colnames = c(
            as.character(i18n$t("category")),
            as.character(i18n$t("source_concept")),
            as.character(i18n$t("target_concept")),
            as.character(i18n$t("origin")),
            as.character(i18n$t("mapped_by")),
            as.character(i18n$t("added")),
            as.character(i18n$t("status")),
            as.character(i18n$t("actions"))
          )
        ) %>%
          DT::formatStyle(
            "status",
            backgroundColor = DT::styleEqual(
              c(i18n$t("approved"), i18n$t("rejected"), i18n$t("uncertain"), i18n$t("not_evaluated")),
              c("#d4edda", "#f8d7da", "#fff3cd", "#e7e7e7")
            ),
            color = DT::styleEqual(
              c(i18n$t("approved"), i18n$t("rejected"), i18n$t("uncertain"), i18n$t("not_evaluated")),
              c("#155724", "#721c24", "#856404", "#666666")
            ),
            fontWeight = "bold"
          )

        dt
      }, server = TRUE)
    })

    #### Update Table Data Using Proxy ----
    # Update data without re-rendering when mappings change
    observe_event(mappings_refresh_trigger(), {
      if (mappings_refresh_trigger() == 0) return()
      if (is.null(selected_alignment_id())) return()
      if (is.null(current_user())) return()

      # Prepare updated data (same logic as initial render)
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings with evaluation status for current user, mapped by user info, and comment count
      query <- "
        SELECT
          cm.mapping_id,
          cm.row_id,
          cm.target_general_concept_id,
          cm.target_omop_concept_id,
          cm.target_custom_concept_id,
          cm.csv_file_path,
          cm.imported_mapping_id,
          cm.mapping_datetime,
          cm.mapped_by_user_id,
          cm.imported_user_name,
          u.first_name as mapped_by_first_name,
          u.last_name as mapped_by_last_name,
          me.is_approved,
          me.comment,
          COALESCE((SELECT COUNT(*) FROM mapping_comments mc WHERE mc.mapping_id = cm.mapping_id), 0) as comments_count
        FROM concept_mappings cm
        LEFT JOIN mapping_evaluations me
          ON cm.mapping_id = me.mapping_id
          AND me.evaluator_user_id = ?
        LEFT JOIN users u
          ON cm.mapped_by_user_id = u.user_id
        WHERE cm.alignment_id = ?
      "

      mappings_db <- DBI::dbGetQuery(
        con,
        query,
        params = list(current_user()$user_id, selected_alignment_id())
      )

      if (nrow(mappings_db) == 0) return()

      # Read CSV to get source concept names (if file exists)
      csv_filename <- mappings_db$csv_file_path[1]
      csv_path <- file.path(get_app_dir("concept_mapping"), csv_filename)
      df <- NULL
      if (!is.na(csv_filename) && file.exists(csv_path)) {
        df <- read.csv(csv_path, stringsAsFactors = FALSE)
      }

      # Enrich with source concept information
      enriched_data <- mappings_db %>%
        dplyr::rowwise() %>%
        dplyr::mutate(
          source_concept_name = {
            if (!is.null(df) && row_id <= nrow(df) && "concept_name" %in% colnames(df)) {
              df$concept_name[row_id]
            } else {
              paste0("Source concept #", row_id)
            }
          },
          source_concept_code = {
            if (!is.null(df) && row_id <= nrow(df) && "concept_code" %in% colnames(df)) {
              df$concept_code[row_id]
            } else {
              NA_character_
            }
          },
          source_vocabulary_id = {
            if (!is.null(df) && row_id <= nrow(df) && "vocabulary_id" %in% colnames(df)) {
              df$vocabulary_id[row_id]
            } else {
              NA_character_
            }
          },
          source_category = {
            if (!is.null(df) && row_id <= nrow(df) && "category" %in% colnames(df)) {
              df$category[row_id]
            } else {
              NA_character_
            }
          }
        ) %>%
        dplyr::ungroup()

      # Enrich with target general concept information
      general_concepts <- data()$general_concepts
      enriched_data <- enriched_data %>%
        dplyr::left_join(
          general_concepts %>%
            dplyr::select(general_concept_id, target_general_concept_name = general_concept_name),
          by = c("target_general_concept_id" = "general_concept_id")
        )

      # Enrich with target concept info (OMOP or custom)
      enriched_data <- enrich_target_concepts(enriched_data, vocabularies(), data())

      # Add status column
      enriched_data <- enriched_data %>%
        dplyr::mutate(
          status = dplyr::case_when(
            is.na(is_approved) ~ as.character(i18n$t("not_evaluated")),
            is_approved == 1 ~ as.character(i18n$t("approved")),
            is_approved == 0 ~ as.character(i18n$t("rejected")),
            is_approved == -1 ~ as.character(i18n$t("uncertain")),
            TRUE ~ as.character(i18n$t("not_evaluated"))
          )
        )

      # Add row index for actions
      enriched_data <- enriched_data %>%
        dplyr::mutate(row_index = dplyr::row_number())

      # Store current user info for comparison
      current_user_id <- current_user()$user_id
      current_user_fullname <- trimws(paste(
        current_user()$first_name %||% "",
        current_user()$last_name %||% ""
      ))

      # Create action buttons HTML (matching initial render logic)
      enriched_data <- enriched_data %>%
        dplyr::rowwise() %>%
        dplyr::mutate(
          comments_badge = if (comments_count > 0) {
            sprintf('<span style="position: absolute; top: -6px; right: -6px; background: #dc3545; color: white; border-radius: 50%%; font-size: 10px; min-width: 16px; height: 16px; display: flex; align-items: center; justify-content: center; padding: 0 4px;">%d</span>', comments_count)
          } else {
            ""
          },
          is_own_mapping = (!is.na(mapped_by_user_id) && mapped_by_user_id == current_user_id) ||
            (!is.na(imported_user_name) && current_user_fullname != "" && imported_user_name == current_user_fullname),
          Actions = if (is_own_mapping) {
            # User can't evaluate own mappings, but can still view/add comments
            sprintf(
              '<div style="display: flex; gap: 5px; justify-content: center; align-items: center;">
                <button class="btn-eval-action btn-comments" data-action="comments" data-mapping-id="%d" title="%s" style="position: relative;">
                  <i class="fas fa-comment"></i>%s
                </button>
              </div>',
              mapping_id,
              i18n$t("mapping_comments"),
              comments_badge
            )
          } else {
            sprintf(
              '<div style="display: flex; gap: 5px; justify-content: center;">
                <button class="btn-eval-action" data-action="approve" data-row="%d" data-mapping-id="%d" title="%s">
                  <i class="fas fa-check"></i>
                </button>
                <button class="btn-eval-action" data-action="reject" data-row="%d" data-mapping-id="%d" title="%s">
                  <i class="fas fa-times"></i>
                </button>
                <button class="btn-eval-action" data-action="uncertain" data-row="%d" data-mapping-id="%d" title="%s">
                  <i class="fas fa-question"></i>
                </button>
                <button class="btn-eval-action" data-action="clear" data-row="%d" data-mapping-id="%d" title="%s">
                  <i class="fas fa-redo"></i>
                </button>
                <button class="btn-eval-action btn-comments" data-action="comments" data-mapping-id="%d" title="%s" style="position: relative;">
                  <i class="fas fa-comment"></i>%s
                </button>
              </div>',
              row_index, mapping_id, i18n$t("approved"),
              row_index, mapping_id, i18n$t("rejected"),
              row_index, mapping_id, i18n$t("uncertain"),
              row_index, mapping_id, i18n$t("clear_evaluation"),
              mapping_id, i18n$t("mapping_comments"), comments_badge
            )
          }
        ) %>%
        dplyr::ungroup()

      # Build display columns
      display_data <- enriched_data %>%
        dplyr::mutate(
          Source = paste0(source_concept_name, " (", source_vocabulary_id, ": ", source_concept_code, ")"),
          Target = paste0(concept_name_target, " (", vocabulary_id_target, ": ", concept_code_target, ")"),
          Category = factor(dplyr::if_else(is.na(source_category) | source_category == "", "/", source_category)),
          status = factor(status, levels = c(
            as.character(i18n$t("not_evaluated")),
            as.character(i18n$t("approved")),
            as.character(i18n$t("rejected")),
            as.character(i18n$t("uncertain"))
          )),
          Origin = dplyr::if_else(
            is.na(imported_mapping_id),
            sprintf('<span style="background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("manual")),
            sprintf('<span style="background: #0f60af; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px;">%s</span>', i18n$t("imported"))
          ),
          Mapped_By = factor(dplyr::case_when(
            !is.na(mapped_by_first_name) | !is.na(mapped_by_last_name) ~
              trimws(paste0(
                dplyr::if_else(is.na(mapped_by_first_name), "", mapped_by_first_name),
                " ",
                dplyr::if_else(is.na(mapped_by_last_name), "", mapped_by_last_name)
              )),
            !is.na(imported_user_name) ~ imported_user_name,
            TRUE ~ "/"
          )),
          Added = dplyr::if_else(
            is.na(mapping_datetime) | mapping_datetime == "",
            "/",
            mapping_datetime
          )
        ) %>%
        dplyr::select(
          Category,
          Source,
          Target,
          Origin,
          Mapped_By,
          Added,
          status,
          Actions
        )

      # Update table data using proxy (preserves state)
      # Add small delay to ensure table is ready
      shinyjs::delay(100, {
        proxy <- DT::dataTableProxy("evaluate_mappings_table", session = session)
        DT::replaceData(proxy, display_data, resetPaging = FALSE, rownames = FALSE)
      })
    }, ignoreInit = TRUE)

    #### Handle Evaluation Actions ----
    observe_event(input$eval_action, {
      if (is.null(input$eval_action)) return()
      if (is.null(current_user())) return()

      action_data <- input$eval_action
      action <- action_data$action

      # Handle comments action separately (no permission check needed for viewing)
      if (action == "comments") {
        mapping_id <- as.integer(action_data$mapping_id)
        if (!is.na(mapping_id)) {
          comments_mapping_id(mapping_id)
          comments_trigger(comments_trigger() + 1)
          shinyjs::show("mapping_comments_modal")
        }
        return()
      }

      # Check permissions for evaluation actions
      if (!user_has_permission("alignments", "evaluate_mappings")) return()

      row_index <- as.integer(action_data$row)

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings for this alignment
      query <- "
        SELECT mapping_id
        FROM concept_mappings
        WHERE alignment_id = ?
      "
      mappings_db <- DBI::dbGetQuery(con, query, params = list(selected_alignment_id()))

      if (row_index < 1 || row_index > nrow(mappings_db)) return()

      mapping_id <- mappings_db$mapping_id[row_index]
      user_id <- current_user()$user_id
      timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

      # Determine is_approved value based on action
      is_approved <- switch(
        action,
        "approve" = 1L,
        "reject" = 0L,
        "uncertain" = -1L,
        "clear" = NA_integer_
      )

      if (action == "clear") {
        # Delete evaluation
        DBI::dbExecute(
          con,
          "DELETE FROM mapping_evaluations
           WHERE mapping_id = ? AND evaluator_user_id = ?",
          params = list(mapping_id, user_id)
        )
      } else {
        # Check if evaluation exists
        existing <- DBI::dbGetQuery(
          con,
          "SELECT evaluation_id FROM mapping_evaluations
           WHERE mapping_id = ? AND evaluator_user_id = ?",
          params = list(mapping_id, user_id)
        )

        if (nrow(existing) > 0) {
          # Update existing evaluation
          DBI::dbExecute(
            con,
            "UPDATE mapping_evaluations
             SET is_approved = ?, evaluated_at = ?
             WHERE mapping_id = ? AND evaluator_user_id = ?",
            params = list(is_approved, timestamp, mapping_id, user_id)
          )
        } else {
          # Insert new evaluation
          DBI::dbExecute(
            con,
            "INSERT INTO mapping_evaluations
             (alignment_id, mapping_id, evaluator_user_id, is_approved, evaluated_at)
             VALUES (?, ?, ?, ?, ?)",
            params = list(selected_alignment_id(), mapping_id, user_id, is_approved, timestamp)
          )
        }
      }

      # Trigger refresh to update the table
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    }, ignoreInit = TRUE)

    #### Render Mapping Comments ----
    observe_event(comments_trigger(), {
      mapping_id <- comments_mapping_id()
      if (is.null(mapping_id)) return()

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        shinyjs::html("mapping_comments_list", paste0(
          '<div style="color: #999; font-style: italic; padding: 20px; text-align: center;">',
          i18n$t("no_comments_yet"),
          '</div>'
        ))
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get comments for this mapping with user info and evaluation status
      comments_data <- DBI::dbGetQuery(
        con,
        "SELECT mc.comment_id, mc.comment, mc.evaluation_status, mc.created_at, mc.user_id,
                mc.imported_user_name, u.first_name, u.last_name
         FROM mapping_comments mc
         LEFT JOIN users u ON mc.user_id = u.user_id
         WHERE mc.mapping_id = ?
         ORDER BY mc.created_at DESC",
        params = list(mapping_id)
      )

      if (nrow(comments_data) == 0) {
        shinyjs::html("mapping_comments_list", paste0(
          '<div style="color: #999; font-style: italic; padding: 20px; text-align: center;">',
          i18n$t("no_comments_yet"),
          '</div>'
        ))
        return()
      }

      current_user_id <- current_user()$user_id

      # Build comments HTML
      comments_html <- sapply(seq_len(nrow(comments_data)), function(i) {
        row <- comments_data[i, ]

        # Format user name: use imported_user_name if user_id is NULL
        if (is.na(row$user_id) && !is.na(row$imported_user_name) && row$imported_user_name != "") {
          user_name <- paste0(row$imported_user_name, " (", i18n$t("imported"), ")")
        } else {
          user_name <- paste(row$first_name, row$last_name)
        }

        # Format date
        date_str <- row$created_at

        # Format evaluation status
        status_html <- ""
        if (!is.na(row$evaluation_status)) {
          status_text <- switch(
            as.character(row$evaluation_status),
            "1" = i18n$t("approved"),
            "0" = i18n$t("rejected"),
            "-1" = i18n$t("uncertain"),
            ""
          )
          status_color <- switch(
            as.character(row$evaluation_status),
            "1" = "#28a745",
            "0" = "#dc3545",
            "-1" = "#ffc107",
            "#999"
          )
          if (status_text != "") {
            status_html <- sprintf(
              '<span style="background: %s; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px; margin-left: 10px;">%s</span>',
              status_color, status_text
            )
          }
        } else {
          # Show "Not Evaluated" status when no evaluation exists
          status_html <- sprintf(
            '<span style="background: #6c757d; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px; margin-left: 10px;">%s</span>',
            i18n$t("not_evaluated")
          )
        }

        # Delete button (only for own comments)
        delete_btn <- ""
        if (!is.na(row$user_id) && row$user_id == current_user_id) {
          delete_btn <- sprintf(
            '<button class="btn-delete-comment" data-comment-id="%d" title="%s" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'});">
              <i class="fas fa-trash"></i>
            </button>',
            row$comment_id,
            i18n$t("delete"),
            ns("delete_mapping_comment"),
            row$comment_id
          )
        }

        # Convert newlines to <br> for HTML display
        comment_html <- gsub("\n", "<br>", htmltools::htmlEscape(row$comment))

        sprintf(
          '<div style="position: relative; padding: 15px; padding-right: 40px; border-bottom: 1px solid #eee; background: %s;">
            %s
            <div style="display: flex; align-items: center; margin-bottom: 8px; padding-right: 20px;">
              <span style="font-weight: 600; color: #0f60af;">%s</span>
              %s
              <span style="color: #999; font-size: 12px; margin-left: auto;">%s</span>
            </div>
            <div style="color: #333; line-height: 1.5; white-space: pre-wrap;">%s</div>
          </div>',
          if (i %% 2 == 0) "#f8f9fa" else "#fff",
          delete_btn,
          htmltools::htmlEscape(user_name),
          status_html,
          htmltools::htmlEscape(date_str),
          comment_html
        )
      })

      shinyjs::html("mapping_comments_list", paste(comments_html, collapse = ""))
    }, ignoreInit = TRUE)

    #### Submit Mapping Comment ----
    observe_event(input$submit_mapping_comment, {
      mapping_id <- comments_mapping_id()
      if (is.null(mapping_id)) return()
      if (is.null(current_user())) return()

      # Get comment text from textarea using JavaScript
      shinyjs::runjs(sprintf(
        "Shiny.setInputValue('%s', document.getElementById('%s').value, {priority: 'event'});",
        ns("new_comment_text"),
        ns("new_mapping_comment")
      ))
    }, ignoreInit = TRUE)

    observe_event(input$new_comment_text, {
      # Check permissions
      if (!user_has_permission("alignments", "evaluate_mappings")) return()

      comment_text <- input$new_comment_text
      if (is.null(comment_text) || trimws(comment_text) == "") return()

      mapping_id <- comments_mapping_id()
      if (is.null(mapping_id)) return()
      if (is.null(current_user())) return()

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      user_id <- current_user()$user_id
      timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

      # Get current evaluation status for this user (if any)
      evaluation <- DBI::dbGetQuery(
        con,
        "SELECT is_approved FROM mapping_evaluations
         WHERE mapping_id = ? AND evaluator_user_id = ?",
        params = list(mapping_id, user_id)
      )

      evaluation_status <- if (nrow(evaluation) > 0) evaluation$is_approved[1] else NA_integer_

      # Insert comment
      DBI::dbExecute(
        con,
        "INSERT INTO mapping_comments (mapping_id, user_id, comment, evaluation_status, created_at)
         VALUES (?, ?, ?, ?, ?)",
        params = list(mapping_id, user_id, trimws(comment_text), evaluation_status, timestamp)
      )

      # Clear textarea
      shinyjs::runjs(sprintf("document.getElementById('%s').value = '';", ns("new_mapping_comment")))

      showNotification(i18n$t("comment_added"), type = "message")

      # Refresh comments display
      comments_trigger(comments_trigger() + 1)

      # Refresh evaluate mappings table to update comment count (using proxy to preserve page/filters)
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    }, ignoreInit = TRUE)

    #### Delete Mapping Comment - Show Confirmation Modal ----
    observe_event(input$delete_mapping_comment, {
      comment_id <- input$delete_mapping_comment
      if (is.null(comment_id)) return()

      # Store comment_id for confirmation
      comment_to_delete(comment_id)

      # Show confirmation modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("delete_comment_modal")))
    }, ignoreInit = TRUE)

    #### Delete Mapping Comment - Confirm Deletion ----
    observe_event(input$confirm_delete_comment, {
      # Check permissions
      if (!user_has_permission("alignments", "evaluate_mappings")) return()

      comment_id <- comment_to_delete()
      if (is.null(comment_id)) return()
      if (is.null(current_user())) return()

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Verify the comment belongs to current user before deleting
      user_id <- current_user()$user_id
      comment_check <- DBI::dbGetQuery(
        con,
        "SELECT user_id FROM mapping_comments WHERE comment_id = ?",
        params = list(comment_id)
      )

      if (nrow(comment_check) == 0 || comment_check$user_id[1] != user_id) {
        showNotification("Cannot delete this comment.", type = "error")
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_comment_modal")))
        comment_to_delete(NULL)
        return()
      }

      # Delete comment
      DBI::dbExecute(
        con,
        "DELETE FROM mapping_comments WHERE comment_id = ?",
        params = list(comment_id)
      )

      showNotification(i18n$t("comment_deleted"), type = "message")

      # Hide modal
      shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_comment_modal")))
      comment_to_delete(NULL)

      # Refresh comments display
      comments_trigger(comments_trigger() + 1)

      # Refresh evaluate mappings table to update comment count (using proxy to preserve page/filters)
      mappings_refresh_trigger(mappings_refresh_trigger() + 1)
    }, ignoreInit = TRUE)

    #### Handle Evaluate Mappings Row Selection ----
    # Using manual row selection input from JavaScript (selection = "none" in datatable)
    observe_event(input$evaluate_mappings_table_row_selected, {
      if (mapping_tab() != "evaluate_mappings") return()

      row_selected <- input$evaluate_mappings_table_row_selected

      if (is.null(row_selected) || length(row_selected) == 0) {
        shinyjs::hide("eval_details_container")
        eval_selected_row_data(NULL)
        eval_source_json(NULL)
        eval_source_row(NULL)
        eval_target_concept_id(NULL)
        eval_target_json(NULL)
        eval_target_mapping(NULL)
        return()
      }

      # Get database connection to fetch mapping data
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) return()

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get all mappings for this alignment
      query <- "
        SELECT
          cm.mapping_id,
          cm.row_id,
          cm.target_general_concept_id,
          cm.target_omop_concept_id,
          cm.csv_file_path
        FROM concept_mappings cm
        WHERE cm.alignment_id = ?
      "
      mappings_db <- DBI::dbGetQuery(con, query, params = list(selected_alignment_id()))

      if (row_selected < 1 || row_selected > nrow(mappings_db)) return()

      selected_mapping <- mappings_db[row_selected, ]
      eval_selected_row_data(selected_mapping)

      # Load source concept JSON data
      csv_filename <- selected_mapping$csv_file_path
      csv_path <- file.path(get_app_dir("concept_mapping"), csv_filename)
      row_id <- selected_mapping$row_id

      if (!is.na(csv_filename) && file.exists(csv_path)) {
        df <- read.csv(csv_path, stringsAsFactors = FALSE)

        if (row_id <= nrow(df)) {
          row_data <- df[row_id, ]
          eval_source_row(row_data)

          # Check if json column exists
          if ("json" %in% colnames(df)) {
            json_str <- df$json[row_id]
            if (!is.null(json_str) && !is.na(json_str) && json_str != "") {
              json_data <- tryCatch(
                jsonlite::fromJSON(json_str),
                error = function(e) NULL
              )
              eval_source_json(json_data)
            } else {
              eval_source_json(NULL)
            }
          } else {
            eval_source_json(NULL)
          }
        }
      }

      # Load target concept data
      target_gc_id <- selected_mapping$target_general_concept_id
      if (!is.null(target_gc_id) && !is.na(target_gc_id)) {
        eval_target_concept_id(target_gc_id)

        # Get general concept info
        gc_data <- data()$general_concepts
        if (!is.null(gc_data)) {
          selected_gc <- gc_data %>%
            dplyr::filter(general_concept_id == target_gc_id)

          if (nrow(selected_gc) > 0) {
            # Create JSON-like data from general concept info
            target_json <- list(
              data_types = NULL,
              numeric_data = NULL,
              histogram = NULL,
              categorical_data = NULL,
              measurement_frequency = NULL,
              missing_rate = NULL
            )

            # If the general concept has a statistical_summary JSON, parse it
            if ("statistical_summary" %in% names(selected_gc) &&
                !is.null(selected_gc$statistical_summary[1]) &&
                !is.na(selected_gc$statistical_summary[1]) &&
                selected_gc$statistical_summary[1] != "") {
              target_json <- tryCatch(
                jsonlite::fromJSON(selected_gc$statistical_summary[1]),
                error = function(e) target_json
              )
            }
            eval_target_json(target_json)
          }
        }

        # Get target mapping data (concept mappings for this general concept)
        target_omop_id <- selected_mapping$target_omop_concept_id
        if (!is.null(target_omop_id) && !is.na(target_omop_id)) {
          mappings_data <- data()$concept_mappings %>%
            dplyr::filter(
              general_concept_id == target_gc_id,
              omop_concept_id == target_omop_id
            )

          if (nrow(mappings_data) > 0) {
            eval_target_mapping(mappings_data[1, ])
          }
        }
      }

      # Show the details container
      shinyjs::show("eval_details_container")
      shinyjs::runjs(sprintf("$('#%s').css('display', 'flex');", ns("eval_details_container")))
    }, ignoreNULL = FALSE)

    #### Handle Evaluate Source Tab Selection ----
    observe_event(input$eval_source_tab_selected, {
      eval_source_tab(input$eval_source_tab_selected)
    })

    #### Handle Evaluate Target Tab Selection ----
    observe_event(input$eval_target_detail_tab_selected, {
      eval_target_detail_tab(input$eval_target_detail_tab_selected)
    })

    #### Handle Evaluate Target Stats Sub-Tab Selection ----
    observe_event(input$eval_target_stats_sub_tab_selected, {
      eval_target_stats_sub_tab(input$eval_target_stats_sub_tab_selected)
    })

    #### Handle Evaluate Target Profile Selection ----
    observe_event(input$eval_target_profile_selected, {
      eval_target_selected_profile(input$eval_target_profile_selected)
    })

    #### Render Evaluate Source Concept Details ----
    output$eval_source_concept_details_content <- renderUI({
      json_data <- eval_source_json()
      row_data <- eval_source_row()
      tab <- eval_source_tab()

      if (is.null(eval_selected_row_data())) {
        return(tags$div(
          class = "text-muted-italic",
          "Select a mapping to see source details."
        ))
      }

      if (is.null(json_data)) {
        return(tags$div(
          class = "text-muted-italic",
          "No JSON data available for this source concept."
        ))
      }

      if (tab == "summary") {
        render_json_summary(json_data, row_data)
      } else if (tab == "distribution") {
        render_json_distribution(json_data)
      } else if (tab == "temporal") {
        render_json_temporal(json_data)
      } else if (tab == "units") {
        render_json_units(json_data)
      } else if (tab == "other") {
        render_source_other_columns(row_data, json_data)
      } else {
        tags$div("Unknown tab")
      }
    })

    #### Render Evaluate Target Concept Details ----
    output$eval_target_concept_details_content <- renderUI({
      json_data <- eval_target_json()
      concept_id <- eval_target_concept_id()
      main_tab <- eval_target_detail_tab()
      sub_tab <- eval_target_stats_sub_tab()
      selected_profile <- eval_target_selected_profile()

      ns <- session$ns

      if (is.null(eval_selected_row_data())) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          "Select a mapping to see target details."
        ))
      }

      if (is.null(concept_id)) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          "No target concept available."
        ))
      }

      if (main_tab == "summary") {
        # Display concept summary details (like Selected Concept Details in Dictionary Explorer)
        render_eval_target_concept_summary(concept_id)
      } else if (main_tab == "comments") {
        # Display comments for the selected general concept
        render_eval_target_comments(concept_id)
      } else if (main_tab == "statistical_summary") {
        # Statistical Summary tab with sub-tabs and profile dropdown
        profile_names <- get_profile_names(json_data)
        has_profiles <- length(profile_names) > 0

        # Auto-select first profile if none selected
        if (has_profiles && (is.null(selected_profile) || !selected_profile %in% profile_names)) {
          selected_profile <- profile_names[1]
          eval_target_selected_profile(selected_profile)
        }

        # Extract profile data based on selection
        profile_data <- get_profile_data(json_data, selected_profile)

        if (is.null(profile_data) || (is.null(profile_data$numeric_data) && is.null(profile_data$categorical_data))) {
          return(tags$div(
            style = "color: #999; font-style: italic; padding: 15px;",
            "No statistical data available for this concept."
          ))
        }

        # Render sub-tabs header with profile dropdown
        tags$div(
          style = "padding: 10px;",
          # Sub-tabs and profile dropdown row
          tags$div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
            # Sub-tabs (left)
            tags$div(
              style = "display: flex; gap: 5px;",
              tags$button(
                id = ns("eval_target_stats_sub_tab_summary"),
                class = if (sub_tab == "summary") "tab-btn tab-btn-active" else "tab-btn",
                onclick = sprintf("
                  document.getElementById('%s').classList.remove('tab-btn-active');
                  document.getElementById('%s').classList.remove('tab-btn-active');
                  this.classList.add('tab-btn-active');
                  Shiny.setInputValue('%s', 'summary', {priority: 'event'});
                ", ns("eval_target_stats_sub_tab_summary"), ns("eval_target_stats_sub_tab_distribution"), ns("eval_target_stats_sub_tab_selected")),
                "Summary"
              ),
              tags$button(
                id = ns("eval_target_stats_sub_tab_distribution"),
                class = if (sub_tab == "distribution") "tab-btn tab-btn-active" else "tab-btn",
                onclick = sprintf("
                  document.getElementById('%s').classList.remove('tab-btn-active');
                  document.getElementById('%s').classList.remove('tab-btn-active');
                  this.classList.add('tab-btn-active');
                  Shiny.setInputValue('%s', 'distribution', {priority: 'event'});
                ", ns("eval_target_stats_sub_tab_summary"), ns("eval_target_stats_sub_tab_distribution"), ns("eval_target_stats_sub_tab_selected")),
                "Distribution"
              )
            ),
            # Profile dropdown (right) - only show if multiple profiles
            if (has_profiles && length(profile_names) > 1) {
              tags$div(
                class = "flex-center-gap-8",
                tags$span(style = "font-size: 11px; color: #666;", paste0(i18n$t("profile"), " :")),
                tags$select(
                  id = ns("eval_target_profile_select"),
                  style = "font-size: 11px; padding: 2px 6px; border: 1px solid #ccc; border-radius: 4px;",
                  onchange = sprintf("Shiny.setInputValue('%s', this.value, {priority: 'event'})", ns("eval_target_profile_selected")),
                  lapply(profile_names, function(p) {
                    if (p == selected_profile) {
                      tags$option(value = p, selected = "selected", p)
                    } else {
                      tags$option(value = p, p)
                    }
                  })
                )
              )
            }
          ),
          # Content based on sub-tab
          if (sub_tab == "summary") {
            render_eval_target_summary(profile_data, concept_id)
          } else if (sub_tab == "distribution") {
            render_eval_target_distribution(profile_data)
          } else {
            tags$div("Unknown sub-tab")
          }
        )
      } else {
        tags$div("Unknown tab")
      }
    })

    #### Render Evaluate Target Comments ----
    # Uses factorized render_comments_panel function
    render_eval_target_comments <- function(concept_id) {
      render_comments_panel(concept_id, "expand_eval_comments")
    }

    #### Render Evaluate Target Concept Summary ----
    # Display concept details like Selected Concept Details in Dictionary Explorer
    # Uses factorized render_concept_summary_panel function
    render_eval_target_concept_summary <- function(concept_id) {
      # Get selected row data
      row_data <- eval_selected_row_data()
      if (is.null(row_data)) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          "No mapping selected."
        ))
      }

      # Get target OMOP concept ID from row data
      omop_concept_id <- row_data$target_omop_concept_id
      if (is.null(omop_concept_id) || is.na(omop_concept_id)) {
        return(tags$div(
          style = "color: #999; font-style: italic; padding: 15px;",
          "No OMOP concept available for this mapping."
        ))
      }

      # Use factorized function
      render_concept_summary_panel(concept_id, omop_concept_id, NULL)
    }

    #### Render Evaluate Target Statistical Summary ----
    # Wrapper for Evaluate Mappings tab (profile_data already extracted)
    render_eval_target_summary <- function(profile_data, concept_id) {
      render_summary_panel(profile_data, concept_id, eval_target_mapping(), eval_source_row(), eval_source_json())
    }

    ### c) Import Mappings Tab ----

    #### Validated Import Function (STCM, Usagi) ----
    do_validated_import <- function(file_path, alignment_id, user, i18n) {
      format <- input$import_format
      validation <- import_validation_result()

      if (is.null(validation) || !validation$valid) {
        show_import_status(i18n$t("import_validation_error"), "error")
        return()
      }

      # Read the file
      import_data <- tryCatch({
        read.csv(file_path, stringsAsFactors = FALSE)
      }, error = function(e) {
        show_import_status(paste(i18n$t("error_reading_csv"), e$message), "error")
        return(NULL)
      })

      if (is.null(import_data)) return()

      # Map columns based on format
      col_mapping <- validation$column_mapping

      # Rename columns to standard names
      colnames(import_data)[colnames(import_data) == col_mapping$source_code] <- "source_code"
      if (!is.null(col_mapping$source_vocabulary_id)) {
        colnames(import_data)[colnames(import_data) == col_mapping$source_vocabulary_id] <- "source_vocabulary_id"
      } else {
        import_data$source_vocabulary_id <- ""
      }
      colnames(import_data)[colnames(import_data) == col_mapping$target_concept_id] <- "target_concept_id"

      # Convert target_concept_id to integer
      target_values <- import_data$target_concept_id
      numeric_values <- suppressWarnings(as.numeric(target_values))
      invalid_count <- sum(is.na(numeric_values) & !is.na(target_values))

      if (invalid_count > 0) {
        showNotification(
          paste(i18n$t("import_validation_error"), "target_concept_id", i18n$t("contains_non_numeric_values")),
          type = "error"
        )
        return()
      }

      import_data$target_concept_id <- as.integer(numeric_values)

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        showNotification(i18n$t("database_not_found"), type = "error")
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get the alignment's CSV file path
      alignment_info <- DBI::dbGetQuery(
        con,
        "SELECT file_id FROM concept_alignments WHERE alignment_id = ?",
        params = list(alignment_id)
      )

      if (nrow(alignment_info) == 0) {
        showNotification(i18n$t("alignment_not_found"), type = "error")
        return()
      }

      file_id <- alignment_info$file_id[1]
      csv_filename <- paste0(file_id, ".csv")
      csv_file_path <- file.path(get_app_dir("concept_mapping"), csv_filename)

      # Check if alignment source file exists
      has_source_file <- file.exists(csv_file_path)
      source_data <- NULL
      if (has_source_file) {
        source_data <- read.csv(csv_file_path, stringsAsFactors = FALSE)
      }

      # Start transaction
      DBI::dbBegin(con)

      tryCatch({
        import_mode <- format
        timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        user_id <- user$user_id
        imported_count <- 0

        # Create import record
        original_filename <- basename(file_path)
        DBI::dbExecute(
          con,
          "INSERT INTO imported_mappings (alignment_id, original_filename, import_mode, concepts_count, imported_by_user_id, imported_at)
           VALUES (?, ?, ?, 0, ?, ?)",
          params = list(alignment_id, original_filename, import_mode, user_id, timestamp)
        )

        import_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]

        # Process each row
        skipped_count <- 0
        for (i in seq_len(nrow(import_data))) {
          row <- import_data[i, ]
          source_code <- as.character(row$source_code)
          target_concept_id <- as.integer(row$target_concept_id)

          # Skip rows with invalid target_concept_id
          if (is.na(target_concept_id) || target_concept_id == 0) {
            skipped_count <- skipped_count + 1
            next
          }

          # Find source row_id by matching vocabulary_id + concept_code
          source_row_id <- NA_integer_
          source_vocab_id <- as.character(row$source_vocabulary_id)

          # If we have source data, try to find matching row by vocabulary_id + concept_code
          if (!is.null(source_data) && "row_id" %in% colnames(source_data)) {
            # Match on vocabulary_id + concept_code
            if ("vocabulary_id" %in% colnames(source_data) && "concept_code" %in% colnames(source_data)) {
              matching_rows <- source_data[
                source_data$vocabulary_id == source_vocab_id &
                source_data$concept_code == source_code, ]
              if (nrow(matching_rows) > 0) {
                source_row_id <- matching_rows$row_id[1]
              }
            }

            # Fallback: match on concept_code only if no vocabulary match
            if (is.na(source_row_id)) {
              matching_rows <- source_data[
                source_data$concept_code == source_code |
                (if ("source_code" %in% colnames(source_data)) source_data$source_code == source_code else rep(FALSE, nrow(source_data))), ]
              if (nrow(matching_rows) > 0) {
                source_row_id <- matching_rows$row_id[1]
              }
            }
          }

          # Skip if no matching source concept found
          if (is.na(source_row_id)) {
            skipped_count <- skipped_count + 1
            next
          }

          # Check if this exact mapping already exists
          existing_exact <- DBI::dbGetQuery(
            con,
            "SELECT mapping_id FROM concept_mappings
             WHERE alignment_id = ? AND csv_file_path = ? AND row_id = ?
               AND target_omop_concept_id = ?",
            params = list(alignment_id, csv_filename, source_row_id, target_concept_id)
          )

          if (nrow(existing_exact) > 0) {
            skipped_count <- skipped_count + 1
            next
          }

          # Insert new mapping
          DBI::dbExecute(
            con,
            "INSERT INTO concept_mappings (alignment_id, csv_file_path, row_id,
                                           target_omop_concept_id, imported_mapping_id, mapping_datetime)
             VALUES (?, ?, ?, ?, ?, ?)",
            params = list(alignment_id, csv_filename, source_row_id, target_concept_id, import_id, timestamp)
          )

          imported_count <- imported_count + 1
        }

        # Update import record with actual count
        DBI::dbExecute(
          con,
          "UPDATE imported_mappings SET concepts_count = ? WHERE import_id = ?",
          params = list(imported_count, import_id)
        )

        DBI::dbCommit(con)

        # Build success message
        msg <- gsub("\\{count\\}", imported_count, i18n$t("successfully_imported_mappings"))
        if (skipped_count > 0) {
          msg <- paste0(msg, " (", gsub("\\{count\\}", skipped_count, i18n$t("duplicates_skipped")), ")")
        }

        # Show in validation banner
        show_import_status(msg, "success")

        # Refresh history and mappings tables
        import_history_trigger(import_history_trigger() + 1)
        source_concepts_table_trigger(source_concepts_table_trigger() + 1)
        summary_trigger(summary_trigger() + 1)
        mappings_refresh_trigger(mappings_refresh_trigger() + 1)
        all_mappings_table_trigger(all_mappings_table_trigger() + 1)
        evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)

        # Reset file input
        import_selected_file(NULL)
        import_csv_data(NULL)
        import_csv_columns(NULL)
        import_validation_result(NULL)

      }, error = function(e) {
        DBI::dbRollback(con)
        show_import_status(paste(i18n$t("import_failed"), e$message), "error")
      })
    }

    #### INDICATE Import Function ----
    do_indicate_import <- function(zip_path, alignment_id, user, i18n, original_filename = NULL) {
      if (!file.exists(zip_path)) {
        show_import_status(i18n$t("import_validation_error"), "error")
        return()
      }

      # Extract ZIP
      temp_dir <- tempfile(pattern = "indicate_import_")
      dir.create(temp_dir)
      on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

      tryCatch({
        zip::unzip(zip_path, exdir = temp_dir)

        # Read metadata
        metadata <- jsonlite::read_json(file.path(temp_dir, "metadata.json"))

        # Read mappings
        mappings_path <- file.path(temp_dir, "mappings.csv")
        mappings <- if (file.exists(mappings_path)) {
          read.csv(mappings_path, stringsAsFactors = FALSE)
        } else {
          data.frame()
        }

        # Read evaluations
        evaluations_path <- file.path(temp_dir, "evaluations.csv")
        evaluations <- if (file.exists(evaluations_path)) {
          read.csv(evaluations_path, stringsAsFactors = FALSE)
        } else {
          data.frame()
        }

        # Read comments
        comments_path <- file.path(temp_dir, "comments.csv")
        comments <- if (file.exists(comments_path)) {
          read.csv(comments_path, stringsAsFactors = FALSE)
        } else {
          data.frame()
        }

        # Get database connection
        db_dir <- get_app_dir()
        db_path <- file.path(db_dir, "indicate.db")

        if (!file.exists(db_path)) {
          showNotification(i18n$t("database_not_found"), type = "error")
          return()
        }

        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        # Get alignment info
        alignment_info <- DBI::dbGetQuery(
          con,
          "SELECT file_id FROM concept_alignments WHERE alignment_id = ?",
          params = list(alignment_id)
        )

        if (nrow(alignment_info) == 0) {
          showNotification(i18n$t("alignment_not_found"), type = "error")
          return()
        }

        file_id <- alignment_info$file_id[1]
        csv_filename <- paste0(file_id, ".csv")
        csv_file_path <- file.path(get_app_dir("concept_mapping"), csv_filename)

        # Load existing source CSV to check for duplicates
        existing_source <- NULL
        if (file.exists(csv_file_path)) {
          existing_source <- read.csv(csv_file_path, stringsAsFactors = FALSE)
        }

        # Get existing mappings for this alignment
        existing_mappings <- DBI::dbGetQuery(
          con,
          "SELECT row_id, target_omop_concept_id FROM concept_mappings WHERE alignment_id = ?",
          params = list(alignment_id)
        )

        # Build set of existing (vocabulary_id, concept_code, target_omop_concept_id) combinations
        existing_combos <- list()
        if (!is.null(existing_source) && nrow(existing_mappings) > 0) {
          for (j in seq_len(nrow(existing_mappings))) {
            idx <- existing_mappings$row_id[j]
            target_id <- existing_mappings$target_omop_concept_id[j]
            if (!is.na(idx) && idx >= 1 && idx <= nrow(existing_source)) {
              src_row <- existing_source[idx, ]
              vocab_id <- if ("vocabulary_id" %in% colnames(src_row)) as.character(src_row$vocabulary_id) else ""
              concept_code <- if ("concept_code" %in% colnames(src_row)) as.character(src_row$concept_code) else ""
              combo_key <- paste(vocab_id, concept_code, target_id, sep = "|||")
              existing_combos[[combo_key]] <- TRUE
            }
          }
        }

        # Start transaction
        DBI::dbBegin(con)

        timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        user_id <- user$user_id
        imported_mappings <- 0
        imported_evaluations <- 0
        imported_comments <- 0
        skipped_duplicates <- 0
        skipped_no_match <- 0
        unresolved_users <- list()  # Track users not found

        # Build lookup index for existing_source by vocabulary_id + concept_code
        source_lookup <- list()
        has_vocab_code <- !is.null(existing_source) &&
                          "vocabulary_id" %in% colnames(existing_source) &&
                          "concept_code" %in% colnames(existing_source)

        if (has_vocab_code) {
          for (j in seq_len(nrow(existing_source))) {
            v_id <- as.character(existing_source$vocabulary_id[j])
            c_code <- as.character(existing_source$concept_code[j])
            if (!is.na(v_id) && !is.na(c_code) && v_id != "" && c_code != "") {
              lookup_key <- paste0(v_id, "|||", c_code)
              source_lookup[[lookup_key]] <- j
            }
          }
        }

        # Check if we can match by row_id directly (fallback)
        max_source_rows <- if (!is.null(existing_source)) nrow(existing_source) else 0
        can_match_by_row_id <- max_source_rows > 0

        # Create import record with original filename
        import_filename <- if (!is.null(original_filename) && original_filename != "") {
          original_filename
        } else {
          basename(zip_path)
        }
        DBI::dbExecute(
          con,
          "INSERT INTO imported_mappings (alignment_id, original_filename, import_mode, concepts_count, imported_by_user_id, imported_at)
           VALUES (?, ?, ?, 0, ?, ?)",
          params = list(alignment_id, import_filename, "indicate", user_id, timestamp)
        )
        import_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]

        # Map old mapping_id to new database mapping_id for evaluations/comments
        mapping_id_map <- list()

        # Helper function to resolve user by first_name + last_name
        resolve_user_fn <- function(row, con) {
          if ("user_first_name" %in% colnames(row) && "user_last_name" %in% colnames(row) &&
              !is.na(row$user_first_name) && !is.na(row$user_last_name) &&
              row$user_first_name != "" && row$user_last_name != "") {
            original_name <- paste(row$user_first_name, row$user_last_name)
            found <- DBI::dbGetQuery(
              con,
              "SELECT user_id FROM users WHERE first_name = ? AND last_name = ?",
              params = list(row$user_first_name, row$user_last_name)
            )
            if (nrow(found) > 0) {
              return(list(user_id = found$user_id[1], found = TRUE, imported_user_name = original_name))
            } else {
              return(list(user_id = NA_integer_, found = FALSE, imported_user_name = original_name))
            }
          }
          return(list(user_id = NA_integer_, found = FALSE, imported_user_name = NA_character_))
        }

        # Import mappings
        if (nrow(mappings) > 0) {
          for (i in seq_len(nrow(mappings))) {
            row <- mappings[i, ]
            old_mapping_id <- row$mapping_id

            # Get vocabulary_id and concept_code from imported mapping
            vocab_id <- if ("vocabulary_id" %in% colnames(row) && !is.na(row$vocabulary_id)) as.character(row$vocabulary_id) else ""
            concept_code <- if ("concept_code" %in% colnames(row) && !is.na(row$concept_code)) as.character(row$concept_code) else ""
            target_id <- row$target_omop_concept_id

            # Find row_id by matching vocabulary_id + concept_code
            new_source_index <- NA_integer_
            if (has_vocab_code && vocab_id != "" && concept_code != "") {
              lookup_key <- paste0(vocab_id, "|||", concept_code)
              if (!is.null(source_lookup[[lookup_key]])) {
                new_source_index <- source_lookup[[lookup_key]]
              }
            }

            # Fallback: try to match by row_id if the existing source doesn't have vocab_id + concept_code
            if (is.na(new_source_index) && can_match_by_row_id && "row_id" %in% colnames(row)) {
              imported_row_id <- suppressWarnings(as.integer(row$row_id))
              if (!is.na(imported_row_id) && imported_row_id >= 1 && imported_row_id <= max_source_rows) {
                new_source_index <- imported_row_id
              }
            }

            # Skip mapping if source concept not found in current alignment
            if (is.na(new_source_index)) {
              skipped_no_match <- skipped_no_match + 1
              next
            }

            # Check for duplicate using vocabulary_id, concept_code, target_omop_concept_id
            # If vocab_id or concept_code are empty, use row_id instead for duplicate detection
            combo_key <- if (vocab_id != "" && concept_code != "") {
              paste(vocab_id, concept_code, target_id, sep = "|||")
            } else {
              paste("row", new_source_index, target_id, sep = "|||")
            }

            if (!is.null(existing_combos[[combo_key]])) {
              skipped_duplicates <- skipped_duplicates + 1
              next
            }

            # Resolve mapping user from exported first_name/last_name
            resolved <- resolve_user_fn(row, con)
            if (!resolved$found && !is.na(resolved$imported_user_name)) {
              unresolved_users[[resolved$imported_user_name]] <- TRUE
            }

            # Insert mapping with the correct row_id for current alignment
            DBI::dbExecute(
              con,
              "INSERT INTO concept_mappings (alignment_id, csv_file_path, row_id,
                                             target_omop_concept_id, imported_mapping_id, mapping_datetime,
                                             mapped_by_user_id, imported_user_name)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
              params = list(
                alignment_id, csv_filename, new_source_index,
                row$target_omop_concept_id, import_id, timestamp,
                resolved$user_id, resolved$imported_user_name
              )
            )

            new_mapping_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]
            mapping_id_map[[as.character(old_mapping_id)]] <- new_mapping_id
            imported_mappings <- imported_mappings + 1

            # Add to existing combos to prevent duplicates within same import
            existing_combos[[combo_key]] <- TRUE
          }
        }

        # Import evaluations with mapped IDs
        if (nrow(evaluations) > 0) {
          for (i in seq_len(nrow(evaluations))) {
            row <- evaluations[i, ]
            old_mapping_id <- as.character(row$mapping_id)
            new_mapping_id <- mapping_id_map[[old_mapping_id]]

            if (!is.null(new_mapping_id)) {
              resolved <- resolve_user_fn(row, con)
              if (!resolved$found && !is.na(resolved$imported_user_name)) {
                unresolved_users[[resolved$imported_user_name]] <- TRUE
              }

              DBI::dbExecute(
                con,
                "INSERT INTO mapping_evaluations (alignment_id, mapping_id, evaluator_user_id, imported_user_name, is_approved, evaluated_at)
                 VALUES (?, ?, ?, ?, ?, ?)",
                params = list(alignment_id, new_mapping_id, resolved$user_id, resolved$imported_user_name, row$is_approved, timestamp)
              )
              imported_evaluations <- imported_evaluations + 1
            }
          }
        }

        # Import comments with mapped IDs
        if (nrow(comments) > 0) {
          for (i in seq_len(nrow(comments))) {
            row <- comments[i, ]
            old_mapping_id <- as.character(row$mapping_id)
            new_mapping_id <- mapping_id_map[[old_mapping_id]]

            if (!is.null(new_mapping_id)) {
              resolved <- resolve_user_fn(row, con)
              if (!resolved$found && !is.na(resolved$imported_user_name)) {
                unresolved_users[[resolved$imported_user_name]] <- TRUE
              }

              # Use original comment if available
              comment_val <- if ("comment" %in% colnames(row)) row$comment else ""

              DBI::dbExecute(
                con,
                "INSERT INTO mapping_comments (mapping_id, user_id, imported_user_name, comment, created_at)
                 VALUES (?, ?, ?, ?, ?)",
                params = list(new_mapping_id, resolved$user_id, resolved$imported_user_name, comment_val, timestamp)
              )
              imported_comments <- imported_comments + 1
            }
          }
        }

        # Update import record
        DBI::dbExecute(
          con,
          "UPDATE imported_mappings SET concepts_count = ? WHERE import_id = ?",
          params = list(imported_mappings, import_id)
        )

        DBI::dbCommit(con)

        # Build success message
        msg <- gsub("\\{mappings\\}", imported_mappings, i18n$t("import_indicate_success"))
        msg <- gsub("\\{evaluations\\}", imported_evaluations, msg)

        # Add info about skipped mappings
        skipped_info <- c()
        if (skipped_no_match > 0) {
          skipped_info <- c(skipped_info, gsub("\\{count\\}", skipped_no_match, i18n$t("mappings_skipped_no_match")))
        }
        if (skipped_duplicates > 0) {
          skipped_info <- c(skipped_info, gsub("\\{count\\}", skipped_duplicates, i18n$t("duplicates_skipped")))
        }
        if (length(skipped_info) > 0) {
          msg <- paste0(msg, " (", paste(skipped_info, collapse = ", "), ")")
        }

        # Build warning message if some users were not found
        warning_msg <- NULL
        if (length(unresolved_users) > 0) {
          unresolved_names <- names(unresolved_users)
          warning_msg <- gsub("\\{count\\}", length(unresolved_names), i18n$t("users_not_found_warning"))
          warning_msg <- paste0(warning_msg, ": ", paste(unresolved_names, collapse = ", "))
        }

        # Show in validation banner
        show_import_status(msg, "success", warning_msg)

        # Refresh tables
        import_history_trigger(import_history_trigger() + 1)
        source_concepts_table_trigger(source_concepts_table_trigger() + 1)
        summary_trigger(summary_trigger() + 1)
        mappings_refresh_trigger(mappings_refresh_trigger() + 1)
        all_mappings_table_trigger(all_mappings_table_trigger() + 1)
        evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)

        # Reset file input
        import_selected_file(NULL)
        import_validation_result(NULL)

      }, error = function(e) {
        show_import_status(paste(i18n$t("import_failed"), e$message), "error")
      })
    }

    #### Column Mapping Modal Function ----
    show_import_column_mapping_modal <- function() {
      columns <- import_csv_columns()
      if (is.null(columns)) return()

      # Create choices for selectInput with empty first option
      column_choices <- c("", columns)
      names(column_choices) <- c(i18n$t("select_column"), columns)

      # Update selectInputs with column choices
      updateSelectInput(session, "import_map_source_code", choices = column_choices, selected = "")
      updateSelectInput(session, "import_map_source_vocab", choices = column_choices, selected = "")
      updateSelectInput(session, "import_map_target_concept", choices = column_choices, selected = "")

      # Hide error messages
      shinyjs::hide("import_error_source_code")
      shinyjs::hide("import_error_source_vocab")
      shinyjs::hide("import_error_target_concept")
      shinyjs::hide("import_error_numeric")

      # Update rows count
      csv_data <- import_csv_data()
      rows_text <- paste0(i18n$t("rows_to_import"), ": ", if (!is.null(csv_data)) nrow(csv_data) else 0)
      shinyjs::html("import_rows_count", rows_text)

      # Show the custom modal
      shinyjs::show("import_column_modal")
    }

    #### Import History Table ----
    observe_event(import_history_trigger(), {
      alignment_id <- selected_alignment_id()
      if (is.null(alignment_id)) return()

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        output$import_history_table <- DT::renderDT({
          DT::datatable(
            data.frame(Message = "No import history available"),
            options = list(dom = "t"),
            rownames = FALSE
          )
        })
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get import history for this alignment
      import_history <- DBI::dbGetQuery(
        con,
        "SELECT im.import_id, im.original_filename, im.import_mode, im.concepts_count,
                im.imported_at, u.first_name || ' ' || u.last_name AS imported_by
         FROM imported_mappings im
         LEFT JOIN users u ON im.imported_by_user_id = u.user_id
         WHERE im.alignment_id = ?
         ORDER BY im.imported_at DESC",
        params = list(alignment_id)
      )

      if (nrow(import_history) == 0) {
        output$import_history_table <- DT::renderDT({
          DT::datatable(
            data.frame(Message = as.character(i18n$t("no_imports_yet"))),
            options = list(dom = "t"),
            rownames = FALSE
          )
        })
        return()
      }

      # Add delete button column
      import_history <- import_history %>%
        dplyr::mutate(
          Actions = sprintf(
            '<button class="btn-danger-custom btn-sm" onclick="Shiny.setInputValue(\'%s\', %d, {priority: \'event\'})">
              <i class="fas fa-trash"></i> Delete
            </button>',
            ns("delete_import"), import_id
          )
        ) %>%
        dplyr::select(
          `File` = original_filename,
          `Concepts` = concepts_count,
          `Imported At` = imported_at,
          `Imported By` = imported_by,
          Actions
        )

      output$import_history_table <- DT::renderDT({
        DT::datatable(
          import_history,
          escape = FALSE,
          rownames = FALSE,
          options = list(
            dom = "t",
            pageLength = 10,
            ordering = FALSE,
            language = get_datatable_language()
          )
        )
      })
    }, ignoreInit = FALSE)

    #### Import Format Change Handler ----
    observe_event(input$import_format, {
      format <- input$import_format
      if (is.null(format)) return()

      # Update file input visibility based on format
      if (format == "indicate") {
        shinyjs::hide("import_csv_input_wrapper")
        shinyjs::show("import_zip_input_wrapper")
      } else {
        shinyjs::show("import_csv_input_wrapper")
        shinyjs::hide("import_zip_input_wrapper")
      }

      # Reset validation status
      shinyjs::hide("import_validation_status")
      import_validation_result(NULL)
    }, ignoreInit = TRUE)

    #### Import File Input Handler ----
    observe_event(input$import_file_input, {
      file_info <- input$import_file_input
      if (is.null(file_info)) return()

      format <- input$import_format
      if (is.null(format)) format <- "csv"

      # Read the CSV file
      csv_data <- tryCatch({
        read.csv(file_info$datapath, stringsAsFactors = FALSE)
      }, error = function(e) {
        showNotification(paste(i18n$t("error_reading_csv"), e$message), type = "error")
        return(NULL)
      })

      if (is.null(csv_data)) return()

      import_selected_file(file_info$datapath)
      import_csv_data(csv_data)
      import_csv_columns(colnames(csv_data))
      # Reset column selections
      import_source_code_col(NULL)
      import_source_vocab_col(NULL)
      import_target_concept_col(NULL)

      # Validate based on format
      validation <- validate_import_file(csv_data, format, i18n)
      import_validation_result(validation)

      # Show validation result
      if (validation$valid) {
        shinyjs::html(
          "import_validation_status",
          sprintf(
            '<div style="display: inline-block; background-color: #d4edda; color: #155724; padding: 10px; border-radius: 4px;">
              <i class="fas fa-check-circle"></i> %s
            </div>',
            i18n$t("import_validation_success")
          )
        )
      } else {
        shinyjs::html(
          "import_validation_status",
          sprintf(
            '<div style="display: inline-block; background-color: #f8d7da; color: #721c24; padding: 10px; border-radius: 4px;">
              <i class="fas fa-exclamation-circle"></i> %s %s
            </div>',
            i18n$t("import_validation_error"),
            validation$message
          )
        )
      }
      shinyjs::show("import_validation_status")
    }, ignoreInit = TRUE)

    #### Import ZIP File Input Handler (INDICATE format) ----
    observe_event(input$import_zip_file_input, {
      file_info <- input$import_zip_file_input
      if (is.null(file_info)) return()

      # Validate ZIP file structure
      validation <- validate_indicate_zip(file_info$datapath, i18n)
      import_validation_result(validation)
      import_selected_file(file_info$datapath)
      import_selected_filename(file_info$name)  # Store original filename

      # Show validation result
      if (validation$valid) {
        shinyjs::html(
          "import_validation_status",
          sprintf(
            '<div style="display: inline-block; background-color: #d4edda; color: #155724; padding: 10px; border-radius: 4px;">
              <i class="fas fa-check-circle"></i> %s (%d mappings, %d evaluations)
            </div>',
            i18n$t("import_validation_success"),
            validation$mappings_count %||% 0,
            validation$evaluations_count %||% 0
          )
        )
      } else {
        shinyjs::html(
          "import_validation_status",
          sprintf(
            '<div style="display: inline-block; background-color: #f8d7da; color: #721c24; padding: 10px; border-radius: 4px;">
              <i class="fas fa-exclamation-circle"></i> %s %s
            </div>',
            i18n$t("import_validation_error"),
            validation$message
          )
        )
      }
      shinyjs::show("import_validation_status")
    }, ignoreInit = TRUE)

    #### Import CSV Handler - Open Column Mapping Modal ----
    observe_event(input$do_import_mappings, {
      format <- input$import_format
      if (is.null(format)) format <- "csv"

      alignment_id <- selected_alignment_id()
      if (is.null(alignment_id)) {
        showNotification(i18n$t("no_alignment_selected_error"), type = "error")
        return()
      }

      if (is.null(current_user())) {
        show_import_status(i18n$t("must_be_logged_in_import"), "error")
        return()
      }

      # Handle based on format
      if (format == "indicate") {
        # INDICATE format import
        validation <- import_validation_result()
        if (is.null(validation) || !validation$valid) {
          show_import_status(i18n$t("import_validation_error"), "error")
          return()
        }
        # Perform INDICATE import
        do_indicate_import(
          import_selected_file(),
          alignment_id,
          current_user(),
          i18n,
          import_selected_filename()
        )
      } else if (format == "csv") {
        # Manual column mapping required
        if (is.null(import_csv_data())) {
          show_import_status(i18n$t("please_select_csv_file"), "warning")
          return()
        }
        show_import_column_mapping_modal()
      } else {
        # STCM or Usagi format - auto-validated
        validation <- import_validation_result()
        if (is.null(validation) || !validation$valid) {
          show_import_status(i18n$t("import_validation_error"), "error")
          return()
        }
        # Perform import with pre-mapped columns
        do_validated_import(
          import_selected_file(),
          alignment_id,
          current_user(),
          i18n
        )
      }
    }, ignoreInit = TRUE)

    #### Preview Table for Column Mapping Modal ----
    observe_event(list(
      input$import_map_source_code,
      input$import_map_source_vocab,
      input$import_map_target_concept
    ), {
      csv_data <- import_csv_data()
      if (is.null(csv_data)) return()

      source_col <- input$import_map_source_code
      vocab_col <- input$import_map_source_vocab
      target_col <- input$import_map_target_concept

      # Build preview data frame
      preview_data <- data.frame(row_num = seq_len(min(10, nrow(csv_data))))

      if (!is.null(source_col) && source_col != "" && source_col %in% colnames(csv_data)) {
        preview_data$source_code <- csv_data[[source_col]][1:nrow(preview_data)]
      } else {
        preview_data$source_code <- rep("-", nrow(preview_data))
      }

      if (!is.null(vocab_col) && vocab_col != "" && vocab_col %in% colnames(csv_data)) {
        preview_data$source_vocabulary <- csv_data[[vocab_col]][1:nrow(preview_data)]
      } else {
        preview_data$source_vocabulary <- rep("-", nrow(preview_data))
      }

      if (!is.null(target_col) && target_col != "" && target_col %in% colnames(csv_data)) {
        preview_data$target_concept_id <- csv_data[[target_col]][1:nrow(preview_data)]
      } else {
        preview_data$target_concept_id <- rep("-", nrow(preview_data))
      }

      # Remove row_num column
      preview_data$row_num <- NULL

      output$import_preview_table <- DT::renderDT({
        DT::datatable(
          preview_data,
          rownames = FALSE,
          options = list(
            dom = "t",
            pageLength = 10,
            ordering = FALSE,
            scrollX = TRUE
          )
        )
      })
    }, ignoreInit = TRUE)

    #### Cancel Column Mapping Modal ----
    observe_event(input$import_cancel_mapping, {
      shinyjs::hide("import_column_modal")
    }, ignoreInit = TRUE)

    #### Confirm Import with Column Mapping ----
    observe_event(input$import_confirm_mapping, {
      # Check permissions
      if (!user_has_permission("alignments", "import_mappings")) return()

      # Hide all error messages first
      shinyjs::hide("import_error_source_code")
      shinyjs::hide("import_error_source_vocab")
      shinyjs::hide("import_error_target_concept")
      shinyjs::hide("import_error_numeric")

      # Validate required columns are selected
      source_col <- input$import_map_source_code
      vocab_col <- input$import_map_source_vocab
      target_col <- input$import_map_target_concept

      has_error <- FALSE

      if (is.null(source_col) || source_col == "") {
        shinyjs::show("import_error_source_code")
        has_error <- TRUE
      }

      if (is.null(vocab_col) || vocab_col == "") {
        shinyjs::show("import_error_source_vocab")
        has_error <- TRUE
      }

      if (is.null(target_col) || target_col == "") {
        shinyjs::show("import_error_target_concept")
        has_error <- TRUE
      }

      if (has_error) return()

      selected_file <- import_selected_file()
      alignment_id <- selected_alignment_id()

      # Read full CSV file
      import_data <- tryCatch({
        read.csv(selected_file, stringsAsFactors = FALSE)
      }, error = function(e) {
        showNotification(paste(i18n$t("error_reading_csv"), e$message), type = "error")
        return(NULL)
      })

      if (is.null(import_data)) return()

      # Rename columns to standard names
      colnames(import_data)[colnames(import_data) == source_col] <- "source_code"
      colnames(import_data)[colnames(import_data) == vocab_col] <- "source_vocabulary_id"
      colnames(import_data)[colnames(import_data) == target_col] <- "target_concept_id"

      # Validate that target_concept_id contains numeric values
      target_values <- import_data$target_concept_id
      numeric_values <- suppressWarnings(as.numeric(target_values))
      invalid_count <- sum(is.na(numeric_values) & !is.na(target_values))

      if (invalid_count > 0) {
        shinyjs::show("import_error_numeric")
        return()
      }

      # Convert to integer
      import_data$target_concept_id <- as.integer(numeric_values)

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        showNotification(i18n$t("database_not_found"), type = "error")
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get the alignment's CSV file path
      alignment_info <- DBI::dbGetQuery(
        con,
        "SELECT file_id FROM concept_alignments WHERE alignment_id = ?",
        params = list(alignment_id)
      )

      if (nrow(alignment_info) == 0) {
        showNotification(i18n$t("alignment_not_found"), type = "error")
        return()
      }

      file_id <- alignment_info$file_id[1]
      csv_filename <- paste0(file_id, ".csv")
      csv_file_path <- file.path(get_app_dir("concept_mapping"), csv_filename)

      # Check if alignment source file exists - if not, we'll work without it
      has_source_file <- file.exists(csv_file_path)
      source_data <- NULL
      if (has_source_file) {
        source_data <- read.csv(csv_file_path, stringsAsFactors = FALSE)
      }

      # Start transaction
      DBI::dbBegin(con)

      tryCatch({
        # Always use merge mode (only import new mappings that don't already exist)
        import_mode <- "merge"
        timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        user_id <- current_user()$user_id
        imported_count <- 0

        # Create import record
        original_filename <- basename(selected_file)
        DBI::dbExecute(
          con,
          "INSERT INTO imported_mappings (alignment_id, original_filename, import_mode, concepts_count, imported_by_user_id, imported_at)
           VALUES (?, ?, ?, 0, ?, ?)",
          params = list(alignment_id, original_filename, import_mode, user_id, timestamp)
        )

        import_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]

        # Process each row in the import file
        skipped_count <- 0
        for (i in seq_len(nrow(import_data))) {
          row <- import_data[i, ]
          source_code <- as.character(row$source_code)
          target_concept_id <- as.integer(row$target_concept_id)

          # Find row_id by matching vocabulary_id + concept_code
          row_id <- NA_integer_
          source_vocab_id <- as.character(row$source_vocabulary_id)

          # If we have source data, try to find matching index by vocabulary_id + concept_code
          if (!is.null(source_data)) {
            # Match on vocabulary_id + concept_code
            if ("vocabulary_id" %in% colnames(source_data) && "concept_code" %in% colnames(source_data)) {
              matching_indices <- which(
                source_data$vocabulary_id == source_vocab_id &
                source_data$concept_code == source_code
              )
              if (length(matching_indices) > 0) {
                row_id <- matching_indices[1]
              }
            }

            # Fallback: match on concept_code only if no vocabulary match
            if (is.na(row_id)) {
              matching_indices <- which(
                source_data$concept_code == source_code |
                (if ("source_code" %in% colnames(source_data)) source_data$source_code == source_code else FALSE)
              )
              if (length(matching_indices) > 0) {
                row_id <- matching_indices[1]
              }
            }

            # Fallback: match on concept_name/source_code_description
            if (is.na(row_id) && "source_code_description" %in% colnames(row)) {
              source_desc <- as.character(row$source_code_description)
              matching_indices <- which(
                source_data$concept_name == source_desc |
                (if ("source_code_description" %in% colnames(source_data)) source_data$source_code_description == source_desc else FALSE)
              )
              if (length(matching_indices) > 0) {
                row_id <- matching_indices[1]
              }
            }
          }

          # Skip if no matching source concept found
          if (is.na(row_id)) {
            skipped_count <- skipped_count + 1
            next
          }

          # Check if this exact mapping already exists (same source + same target)
          existing_exact <- DBI::dbGetQuery(
            con,
            "SELECT mapping_id FROM concept_mappings
             WHERE alignment_id = ? AND csv_file_path = ? AND row_id = ?
               AND target_omop_concept_id = ?",
            params = list(alignment_id, csv_filename, row_id, target_concept_id)
          )

          if (nrow(existing_exact) > 0) {
            # Skip if exact mapping already exists (same source + same target)
            skipped_count <- skipped_count + 1
            next
          }

          # Insert new mapping (allows multiple mappings per source)
          DBI::dbExecute(
            con,
            "INSERT INTO concept_mappings (alignment_id, csv_file_path, row_id,
                                           target_omop_concept_id, imported_mapping_id, mapping_datetime)
             VALUES (?, ?, ?, ?, ?, ?)",
            params = list(alignment_id, csv_filename, row_id, target_concept_id, import_id, timestamp)
          )

          imported_count <- imported_count + 1
        }

        # Update import record with actual count
        DBI::dbExecute(
          con,
          "UPDATE imported_mappings SET concepts_count = ? WHERE import_id = ?",
          params = list(imported_count, import_id)
        )

        DBI::dbCommit(con)

        # Build success message
        msg <- gsub("\\{count\\}", imported_count, i18n$t("successfully_imported_mappings"))
        if (skipped_count > 0) {
          skipped_msg <- gsub("\\{count\\}", skipped_count, i18n$t("duplicates_skipped"))
          msg <- paste0(msg, " (", skipped_msg, ")")
        }

        # Show in validation banner
        show_import_status(msg, "success")

        # Close modal
        shinyjs::hide("import_column_modal")

        # Reset selected file and CSV data after successful import
        import_selected_file(NULL)
        import_csv_data(NULL)
        import_csv_columns(NULL)

        # Trigger refresh
        import_history_trigger(import_history_trigger() + 1)
        mappings_refresh_trigger(mappings_refresh_trigger() + 1)
        all_mappings_table_trigger(all_mappings_table_trigger() + 1)
        evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)

      }, error = function(e) {
        DBI::dbRollback(con)
        show_import_status(paste(i18n$t("import_failed"), e$message), "error")
      })
    }, ignoreInit = TRUE)

    #### Delete Import - Show Confirmation Modal ----
    observe_event(input$delete_import, {
      import_id <- input$delete_import
      if (is.null(import_id)) return()

      # Store import_id for confirmation
      import_to_delete(import_id)

      # Get import info for confirmation message
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (file.exists(db_path)) {
        con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        import_info <- DBI::dbGetQuery(
          con,
          "SELECT original_filename, concepts_count FROM imported_mappings
           WHERE import_id = ?",
          params = list(import_id)
        )

        if (nrow(import_info) > 0) {
          message <- sprintf(
            "%s '%s' (%d %s)",
            i18n$t("delete_import_confirmation_message"),
            import_info$original_filename[1],
            import_info$concepts_count[1],
            i18n$t("mappings")
          )
          shinyjs::html("delete_import_message", message)
        }
      }

      # Show confirmation modal
      shinyjs::runjs(sprintf("$('#%s').show();", ns("delete_import_modal")))
    }, ignoreInit = TRUE)

    #### Delete Import - Confirm Deletion ----
    observe_event(input$confirm_delete_import, {
      import_id <- import_to_delete()
      if (is.null(import_id)) return()

      # Get database connection
      db_dir <- get_app_dir()
      db_path <- file.path(db_dir, "indicate.db")

      if (!file.exists(db_path)) {
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_import_modal")))
        import_to_delete(NULL)
        return()
      }

      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      DBI::dbBegin(con)

      tryCatch({
        # Delete mappings associated with this import
        DBI::dbExecute(
          con,
          "DELETE FROM concept_mappings WHERE imported_mapping_id = ?",
          params = list(import_id)
        )

        # Delete the import record
        DBI::dbExecute(
          con,
          "DELETE FROM imported_mappings WHERE import_id = ?",
          params = list(import_id)
        )

        DBI::dbCommit(con)

        showNotification(i18n$t("import_deleted_successfully"), type = "message")

        # Hide modal and clear state
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_import_modal")))
        import_to_delete(NULL)

        # Trigger refresh
        import_history_trigger(import_history_trigger() + 1)
        mappings_refresh_trigger(mappings_refresh_trigger() + 1)
        all_mappings_table_trigger(all_mappings_table_trigger() + 1)
        evaluate_mappings_table_trigger(evaluate_mappings_table_trigger() + 1)

      }, error = function(e) {
        DBI::dbRollback(con)
        showNotification(paste(i18n$t("delete_failed"), e$message), type = "error")
        shinyjs::runjs(sprintf("$('#%s').hide();", ns("delete_import_modal")))
        import_to_delete(NULL)
      })
    }, ignoreInit = TRUE)
  })
}
