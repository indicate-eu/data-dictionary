#' DataTable Functions
#'
#' @description Helper functions for DataTables including state management,
#' business logic helpers, and internationalization support
#' @noRd

#' Get DataTable Language Options
#'
#' @description Returns a list of language options for DataTables based on the current language.
#' This provides translations for pagination, info, and other DataTable UI elements.
#'
#' @param language Character: Language code ("en" or "fr"). Defaults to INDICATE_LANGUAGE env var or "en".
#'
#' @return List of language options compatible with DataTables options$language
#'
#' @examples
#' \dontrun{
#'   # Use in a datatable
#'   DT::datatable(
#'     data,
#'     options = list(
#'       language = get_datatable_language()
#'     )
#'   )
#' }
#'
#' @noRd
get_datatable_language <- function(language = NULL) {
  if (is.null(language)) {
    language <- Sys.getenv("INDICATE_LANGUAGE", "en")
  }

  if (language == "fr") {
    list(
      processing = "Traitement en cours...",
      search = "Rechercher :",
      lengthMenu = "Afficher _MENU_ \u00e9l\u00e9ments",
      info = "Affichage de _START_ \u00e0 _END_ sur _TOTAL_ \u00e9l\u00e9ments",
      infoEmpty = "Affichage de 0 \u00e0 0 sur 0 \u00e9l\u00e9ments",
      infoFiltered = "(filtr\u00e9 de _MAX_ \u00e9l\u00e9ments au total)",
      infoPostFix = "",
      loadingRecords = "Chargement en cours...",
      zeroRecords = "Aucun \u00e9l\u00e9ment \u00e0 afficher",
      emptyTable = "Aucune donn\u00e9e disponible dans le tableau",
      paginate = list(
        first = "Premier",
        previous = "Pr\u00e9c\u00e9dent",
        `next` = "Suivant",
        last = "Dernier"
      ),
      aria = list(
        sortAscending = ": activer pour trier la colonne par ordre croissant",
        sortDescending = ": activer pour trier la colonne par ordre d\u00e9croissant"
      )
    )
  } else {
    list(
      processing = "Processing...",
      search = "Search:",
      lengthMenu = "Show _MENU_ entries",
      info = "Showing _START_ to _END_ of _TOTAL_ entries",
      infoEmpty = "Showing 0 to 0 of 0 entries",
      infoFiltered = "(filtered from _MAX_ total entries)",
      infoPostFix = "",
      loadingRecords = "Loading...",
      zeroRecords = "No matching records found",
      emptyTable = "No data available in table",
      paginate = list(
        first = "First",
        previous = "Previous",
        `next` = "Next",
        last = "Last"
      ),
      aria = list(
        sortAscending = ": activate to sort column ascending",
        sortDescending = ": activate to sort column descending"
      )
    )
  }
}


#' Create Empty DataTable
#'
#' @description Creates a standardized empty DataTable with a message,
#' commonly used when no data is available or no selection has been made.
#'
#' @param message Character: Message to display in the table
#' @param column_name Character: Column name for the message (default "Message")
#'
#' @return DT datatable object with single message row
#'
#' @examples
#' \dontrun{
#'   # No data available
#'   if (nrow(data) == 0) {
#'     return(create_empty_datatable("No data available"))
#'   }
#'
#'   # No selection made
#'   if (is.null(selected_id)) {
#'     return(create_empty_datatable("Select a concept to view details"))
#'   }
#'
#'   # Custom column name
#'   create_empty_datatable("No mappings created yet.", column_name = "Status")
#' }
#'
#' @noRd
create_empty_datatable <- function(message, column_name = "Message") {
  # Create data frame with single column
  df <- data.frame(x = message, stringsAsFactors = FALSE)
  colnames(df) <- column_name
  
  # Return datatable with minimal UI (no pagination, no search)
  DT::datatable(
    df,
    options = list(dom = 't'),
    rownames = FALSE,
    selection = 'none'
  )
}

#' Save DataTable State
#'
#' @description Saves the current page number and column search filters of a DataTable
#'
#' @param input Shiny input object
#' @param table_id Character: ID of the datatable (without namespace)
#' @param saved_page reactiveVal to store page number
#' @param saved_search reactiveVal to store search column filters
#'
#' @return Invisible NULL
#'
#' @examples
#' \dontrun{
#' saved_page <- reactiveVal(1)
#' saved_search <- reactiveVal(NULL)
#' save_datatable_state(input, "my_table", saved_page, saved_search)
#' }
save_datatable_state <- function(input, table_id, saved_page, saved_search) {
  state_name <- paste0(table_id, "_state")
  search_name <- paste0(table_id, "_search_columns")

  # Save current page number
  if (!is.null(input[[state_name]])) {
    current_page <- input[[state_name]]$start / input[[state_name]]$length + 1
    saved_page(current_page)
  }

  # Save column search filters
  if (!is.null(input[[search_name]])) {
    saved_search(input[[search_name]])
  }

  invisible(NULL)
}

#' Apply Yes/No Boolean Styling to DataTable Column
#'
#' @description Applies standardized styling to Yes/No boolean columns in DataTables.
#' Creates green highlighting for "Yes" values and gray for "No" values with
#' appropriate text colors and font weights.
#'
#' @param dt DT datatable object to modify
#' @param column Character: Column name to style
#' @param yes_color Character: Background color for "Yes" (default "#d4edda" - light green)
#' @param no_color Character: Background color for "No" (default "#f8f9fa" - light gray)
#'
#' @return Modified datatable object with formatting applied
#'
#' @examples
#' \dontrun{
#'   # Style a single column
#'   dt <- datatable(data) %>%
#'     style_yes_no_column("is_required")
#'
#'   # Style multiple columns
#'   dt <- datatable(data) %>%
#'     style_yes_no_column("is_required") %>%
#'     style_yes_no_column("is_active")
#'
#'   # Custom colors
#'   dt <- datatable(data) %>%
#'     style_yes_no_column("status", yes_color = "#c3e6cb", no_color = "#f5c6cb")
#' }
#'
#' @noRd
style_yes_no_column <- function(dt, column,
                                yes_color = "#d4edda",
                                no_color = "#f8f9fa") {
  dt %>%
    DT::formatStyle(
      column,
      target = "cell",
      backgroundColor = DT::styleEqual(
        c("Yes", "No"),
        c(yes_color, no_color)
      ),
      fontWeight = DT::styleEqual(
        c("Yes", "No"),
        c("bold", "normal")
      ),
      color = DT::styleEqual(
        c("Yes", "No"),
        c("#155724", "#666")
      )
    )
}

#' Apply Yes/No Styling with Custom Colors
#'
#' @description Variant of style_yes_no_column for projects like coverage status
#' where "No" should be highlighted with a warning color (red) instead of neutral gray.
#'
#' @param dt DT datatable object to modify
#' @param column Character: Column name to style
#' @param yes_bg Character: Background color for "Yes" (default "#d4edda" - light green)
#' @param no_bg Character: Background color for "No" (default "#f8d7da" - light red)
#' @param yes_text Character: Text color for "Yes" (default "#155724" - dark green)
#' @param no_text Character: Text color for "No" (default "#721c24" - dark red)
#'
#' @return Modified datatable object with formatting applied
#'
#' @examples
#' \dontrun{
#'   # Style coverage column with red for incomplete
#'   dt <- datatable(data) %>%
#'     style_yes_no_custom("covered",
#'                         yes_bg = "#d4edda", no_bg = "#f8d7da",
#'                         yes_text = "#155724", no_text = "#721c24")
#' }
#'
#' @noRd
style_yes_no_custom <- function(dt, column,
                                yes_bg = "#d4edda", no_bg = "#f8d7da",
                                yes_text = "#155724", no_text = "#721c24") {
  dt %>%
    DT::formatStyle(
      column,
      backgroundColor = DT::styleEqual(
        c("Yes", "No"),
        c(yes_bg, no_bg)
      ),
      color = DT::styleEqual(
        c("Yes", "No"),
        c(yes_text, no_text)
      ),
      fontWeight = "bold"
    )
}

#' Apply Standard Concept Column Styling
#'
#' @description Apply consistent styling to standard_concept columns in DataTables.
#' Colors: Standard (green), Classification (gray), Non-standard (red).
#'
#' @param dt DT datatable object to modify
#' @param column Character: Column name to style (default "standard_concept_display")
#'
#' @return DT datatable with styling applied
#' @noRd
style_standard_concept_column <- function(dt, column = "standard_concept_display") {
  dt %>%
    DT::formatStyle(
      column,
      backgroundColor = DT::styleEqual(
        c("Standard", "Classification", "Non-standard"),
        c("#d4edda", "#e2e3e5", "#f8d7da")
      ),
      fontWeight = DT::styleEqual(
        c("Standard", "Classification", "Non-standard"),
        c("bold", "bold", "bold")
      ),
      color = DT::styleEqual(
        c("Standard", "Classification", "Non-standard"),
        c("#155724", "#383d41", "#721c24")
      )
    )
}

#' Restore DataTable State
#'
#' @description Restores previously saved page number and column search filters to a DataTable
#'
#' @param table_id Character: ID of the datatable (without namespace)
#' @param saved_page reactiveVal with stored page number
#' @param saved_search reactiveVal with stored search column filters
#' @param session Shiny session object
#' @param delay_ms Numeric: Delay in milliseconds before restoring (default 100ms)
#'
#' @return Invisible NULL
#'
#' @examples
#' \dontrun{
#' restore_datatable_state("my_table", saved_page, saved_search, session)
#' }
restore_datatable_state <- function(table_id, saved_page, saved_search, session, delay_ms = 100) {
  shinyjs::delay(delay_ms, {
    proxy <- DT::dataTableProxy(table_id, session = session)

    # Restore column filters
    search_columns <- saved_search()
    if (!is.null(search_columns)) {
      DT::updateSearch(proxy, keywords = list(
        global = NULL,
        columns = search_columns
      ))
    }

    # Restore page position
    page_num <- saved_page()
    if (!is.null(page_num) && page_num > 0) {
      DT::selectPage(proxy, page_num)
    }
  })

  invisible(NULL)
}

#' Save and Restore DataTable State (Combined)
#'
#' @description Convenience function that saves state, executes an action, then restores state
#'
#' @param input Shiny input object
#' @param table_id Character: ID of the datatable (without namespace)
#' @param saved_page reactiveVal to store page number
#' @param saved_search reactiveVal to store search column filters
#' @param session Shiny session object
#' @param action Function to execute between save and restore
#' @param delay_ms Numeric: Delay in milliseconds before restoring (default 100ms)
#'
#' @return Result of the action function
#'
#' @examples
#' \dontrun{
#' with_datatable_state(input, "my_table", saved_page, saved_search, session, {
#'   # Modify data
#'   data <- local_data()
#'   data$my_table <- updated_data
#'   local_data(data)
#' })
#' }
with_datatable_state <- function(input, table_id, saved_page, saved_search, session, action, delay_ms = 100) {
  # Save state before action
  save_datatable_state(input, table_id, saved_page, saved_search)

  # Execute action
  result <- action

  # Restore state after action
  restore_datatable_state(table_id, saved_page, saved_search, session, delay_ms)

  invisible(result)
}

#' Prepare Concept Set Data for DataTable Display
#'
#' @description Prepares concept set data with HTML toggle switches for
#' is_excluded, include_descendants, and include_mapped columns. Used by both
#' Dictionary Explorer and Concept Mapping modules for consistent display.
#'
#' @param mappings Data frame with concept mappings containing columns:
#'   omop_concept_id, concept_name, vocabulary_id, domain_id, concept_code,
#'   standard_concept, is_excluded, include_descendants, include_mapped
#' @param ns Shiny namespace function
#' @param editable Logical: Whether to show editable toggles (TRUE) or read-only display (FALSE)
#' @param toggle_input_id Character: Input ID for toggle change events (used when editable=TRUE)
#' @param delete_enabled Logical: Whether to show delete icons (default TRUE when editable)
#'
#' @return Data frame with HTML columns for toggles and standard_concept badge
#'
#' @noRd
prepare_concept_set_display <- function(
    mappings,
    ns,
    editable = TRUE,
    toggle_input_id = "toggle_concept_option",
    delete_enabled = TRUE
) {
  if (nrow(mappings) == 0) {
    return(mappings)
  }

  # Ensure required columns exist with defaults

  if (!"is_excluded" %in% colnames(mappings)) {
    mappings$is_excluded <- FALSE
  }
  if (!"include_descendants" %in% colnames(mappings)) {
    mappings$include_descendants <- FALSE
  }
  if (!"include_mapped" %in% colnames(mappings)) {
    mappings$include_mapped <- FALSE
  }

  # Build standard_concept_display as factor for filtering
  mappings <- mappings %>%
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

  if (editable) {
    # Build HTML toggle switches
    mappings <- mappings %>%
      dplyr::mutate(
        is_excluded_toggle = sprintf(
          '<label class="toggle-switch toggle-small toggle-exclude"><input type="checkbox" data-omop-id="%s" data-field="is_excluded" %s onchange="Shiny.setInputValue(\'%s\', {omop_id: %s, field: \'is_excluded\', value: this.checked}, {priority: \'event\'})"><span class="toggle-slider"></span></label>',
          omop_concept_id, ifelse(is_excluded, "checked", ""), ns(toggle_input_id), omop_concept_id
        ),
        include_descendants_toggle = sprintf(
          '<label class="toggle-switch toggle-small"><input type="checkbox" data-omop-id="%s" data-field="include_descendants" %s onchange="Shiny.setInputValue(\'%s\', {omop_id: %s, field: \'include_descendants\', value: this.checked}, {priority: \'event\'})"><span class="toggle-slider"></span></label>',
          omop_concept_id, ifelse(include_descendants, "checked", ""), ns(toggle_input_id), omop_concept_id
        ),
        include_mapped_toggle = sprintf(
          '<label class="toggle-switch toggle-small"><input type="checkbox" data-omop-id="%s" data-field="include_mapped" %s onchange="Shiny.setInputValue(\'%s\', {omop_id: %s, field: \'include_mapped\', value: this.checked}, {priority: \'event\'})"><span class="toggle-slider"></span></label>',
          omop_concept_id, ifelse(include_mapped, "checked", ""), ns(toggle_input_id), omop_concept_id
        )
      )

    if (delete_enabled) {
      # Ensure is_custom and custom_concept_id columns exist
      if (!"is_custom" %in% colnames(mappings)) {
        mappings$is_custom <- FALSE
      }
      if (!"custom_concept_id" %in% colnames(mappings)) {
        mappings$custom_concept_id <- NA_integer_
      }

      mappings <- mappings %>%
        dplyr::mutate(
          action = dplyr::if_else(
            is_custom == TRUE & !is.na(custom_concept_id),
            sprintf(
              '<i class="fa fa-trash delete-icon" data-omop-id="" data-custom-id="%s" style="cursor: pointer; color: #dc3545;"></i>',
              custom_concept_id
            ),
            sprintf(
              '<i class="fa fa-trash delete-icon" data-omop-id="%s" data-custom-id="" style="cursor: pointer; color: #dc3545;"></i>',
              omop_concept_id
            )
          )
        )
    }
  }

  mappings
}

#' Get Column Configuration for Concept Set DataTable
#'
#' @description Returns column names, escape settings, and column definitions
#' for concept set DataTables based on edit mode.
#'
#' @param editable Logical: Whether table is in edit mode
#' @param delete_enabled Logical: Whether delete column is shown
#'
#' @return List with escape_cols, col_names, and col_defs
#'
#' @noRd
get_concept_set_column_config <- function(editable = TRUE, delete_enabled = TRUE) {
  if (editable) {
    if (delete_enabled) {
      # Edit mode with delete: omop_concept_id, concept_name, vocabulary_id, domain_id, concept_code, standard_concept_display, is_excluded_toggle, include_descendants_toggle, include_mapped_toggle, action
      list(
        escape_cols = c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
        col_names = c("OMOP Concept ID", "Concept Name", "Vocabulary", "Domain", "Code", "Standard", "Exclude", "Descendants", "Mapped", "Action"),
        col_defs = list(
          list(targets = 0, visible = FALSE),
          list(targets = 1, width = "25%"),
          list(targets = 3, visible = FALSE),
          list(targets = 5, width = "90px", className = 'dt-center'),
          list(targets = 6, width = "70px", className = 'dt-center'),
          list(targets = 7, width = "110px", className = 'dt-center'),
          list(targets = 8, width = "100px", className = 'dt-center'),
          list(targets = 9, width = "50px", className = 'dt-center')
        )
      )
    } else {
      # Edit mode without delete
      list(
        escape_cols = c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE),
        col_names = c("OMOP Concept ID", "Concept Name", "Vocabulary", "Domain", "Code", "Standard", "Exclude", "Descendants", "Mapped"),
        col_defs = list(
          list(targets = 0, visible = FALSE),
          list(targets = 1, width = "25%"),
          list(targets = 3, visible = FALSE),
          list(targets = 5, width = "90px", className = 'dt-center'),
          list(targets = 6, width = "70px", className = 'dt-center'),
          list(targets = 7, width = "110px", className = 'dt-center'),
          list(targets = 8, width = "100px", className = 'dt-center')
        )
      )
    }
  } else {
    # View mode: omop_concept_id, concept_name, vocabulary_id, domain_id, concept_code, standard_concept_display
    list(
      escape_cols = c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE),
      col_names = c("OMOP Concept ID", "Concept Name", "Vocabulary", "Domain", "Code", "Standard"),
      col_defs = list(
        list(targets = 0, visible = FALSE),
        list(targets = 3, visible = FALSE),
        list(targets = 5, width = "120px", className = 'dt-center')
      )
    )
  }
}
