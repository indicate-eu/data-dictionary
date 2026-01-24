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
                class = "btn-success-custom",
                icon = icon("plus")
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
            # Format: "YYYY-MM-DD HH:MM"
            substr(dt_str, 1, 16)
          }, error = function(e) "")
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
          tags = ifelse(is.na(data$tags), "", data$tags),
          item_count = data$item_count,
          last_update = sapply(data$modified_date, format_date),
          stringsAsFactors = FALSE
        )

        # Convert to factors for dropdown filters
        display_data$category <- factor(display_data$category)
        display_data$subcategory <- factor(display_data$subcategory)
        display_data$tags <- factor(display_data$tags)

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
