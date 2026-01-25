# Fuzzy search functions for text matching with typo tolerance
#
# This file provides reusable fuzzy search functionality for DataTables:
# - fuzzy_search_ui(): Creates the fuzzy search input UI element
# - fuzzy_search_server(): Sets up the server-side observer and returns a reactive
# - fuzzy_search_df(): Performs the actual fuzzy matching on data
# - normalize_text_for_search(): Text normalization helper

#' Create fuzzy search UI element
#'
#' Creates an absolutely positioned fuzzy search input that can be placed
#' inside a container with position: relative.
#'
#' @param id The input ID (will be namespaced if ns is provided)
#' @param ns Optional namespace function from the module
#' @param i18n Optional i18n object for translations
#' @param placeholder Custom placeholder text (optional)
#' @param limit_checkbox Whether to show a "Limit to 10K" checkbox (default: FALSE)
#' @param limit_checkbox_id ID for the limit checkbox (required if limit_checkbox = TRUE)
#' @param settings_btn Whether to show a settings button for advanced filters (default: FALSE)
#' @param settings_btn_id ID for the settings button (required if settings_btn = TRUE)
#' @param initially_visible Whether checkbox and settings button are visible initially (default: TRUE).
#'   Set to FALSE if visibility will be controlled by JavaScript later.
#' @return A tags$div containing the fuzzy search label and input
fuzzy_search_ui <- function(id, ns = NULL, i18n = NULL, placeholder = NULL,
                            limit_checkbox = FALSE, limit_checkbox_id = NULL,
                            settings_btn = FALSE, settings_btn_id = NULL,
                            initially_visible = TRUE) {

  input_id <- if (!is.null(ns)) ns(id) else id

  label_text <- if (!is.null(i18n)) i18n$t("fuzzy_search") else "Fuzzy Search"

  placeholder_text <- if (!is.null(placeholder)) {
    placeholder
  } else if (!is.null(i18n)) {
    i18n$t("fuzzy_search_placeholder")
  } else {
    "Search..."
  }

  # Style for initially hidden elements
  hidden_style <- if (!initially_visible) "display: none;" else NULL

  # Build settings button if requested
  settings_btn_el <- NULL
  if (settings_btn && !is.null(settings_btn_id)) {
    btn_id <- if (!is.null(ns)) ns(settings_btn_id) else settings_btn_id
    settings_btn_el <- tags$button(
      id = btn_id,
      type = "button",
      class = "fuzzy-search-settings-btn",
      style = hidden_style,
      title = "Advanced filters",
      # Direct onclick handler to ensure click is captured even inside modals with stopPropagation
      onclick = sprintf("Shiny.setInputValue('%s', Math.random(), {priority: 'event'});", btn_id),
      # Sliders/mixer icon (Font Awesome 6)
      tags$i(class = "fa-solid fa-sliders")
    )
  }

  # Build checkbox if requested
  limit_checkbox_el <- NULL
  if (limit_checkbox && !is.null(limit_checkbox_id)) {
    checkbox_id <- if (!is.null(ns)) ns(limit_checkbox_id) else limit_checkbox_id
    limit_checkbox_el <- tags$label(
      class = "fuzzy-search-limit-checkbox",
      style = hidden_style,
      tags$input(
        id = checkbox_id,
        type = "checkbox",
        checked = "checked"
      ),
      tags$span("Limit 10K")
    )
  }

  tags$div(
    class = "fuzzy-search-container",
    settings_btn_el,
    limit_checkbox_el,
    tags$span(class = "fuzzy-search-label", label_text),
    tags$input(
      id = input_id,
      type = "text",
      class = "fuzzy-search-input",
      placeholder = placeholder_text
    )
  )
}

#' Set up fuzzy search server logic
#'
#' Creates a reactive value to track the fuzzy search query and sets up
#' the observer for input changes. Returns a list with the reactive value
#' and a function to clear the search.
#'
#' @param id The input ID used in fuzzy_search_ui
#' @param input The Shiny input object
#' @param session The Shiny session object
#' @param trigger_rv Optional reactiveVal to increment when query changes
#' @param ns Optional namespace function (for clearing the input via JS)
#' @return A list with:
#'   - query: reactiveVal containing the current search query
#'   - clear: function to clear the search input
fuzzy_search_server <- function(id, input, session, trigger_rv = NULL, ns = NULL) {
  # Create reactive value for the query
query_rv <- reactiveVal("")

  # The JS sends input with suffix "_query"
  input_name <- paste0(id, "_query")

  # Set up observer for input changes
  observe_event(input[[input_name]], {
    query_rv(input[[input_name]])

    # Trigger table update if trigger_rv is provided
    if (!is.null(trigger_rv)) {
      trigger_rv(trigger_rv() + 1)
    }
  }, ignoreNULL = FALSE, ignoreInit = TRUE)

  # Create clear function
  input_id <- if (!is.null(ns)) ns(id) else id
  clear_fn <- function() {
    query_rv("")
    shinyjs::runjs(sprintf("$('#%s').val('');", input_id))
  }

  # Return list with query reactive and clear function
  list(
    query = query_rv,
    clear = clear_fn
  )
}

#' Normalize text for fuzzy matching
#'
#' Removes accents, replaces underscores with spaces, lowercases text,
#' and normalizes whitespace.
#'
#' @param text Character vector to normalize
#' @return Normalized character vector
normalize_text_for_search <- function(text) {
  text %>%
    tolower() %>%
    stringi::stri_trans_general("Latin-ASCII") %>%
    gsub("_", " ", .) %>%
    gsub("\\s+", " ", .) %>%
    trimws()
}

#' Perform fuzzy search on a data frame
#'
#' Searches for query matches in a specified column using fuzzy matching
#' with Levenshtein distance. Returns rows that match within the specified
#' distance threshold, sorted by relevance (best matches first).
#'
#' Scoring:
#' - 0: Exact substring match (after normalization)
#' - 0.5: All query tokens found in text
#' - N: Sum of minimum Levenshtein distances for each query token
#'
#' @param data Data frame to search
#' @param query Search query string
#' @param column_name Name of the column to search in
#' @param max_dist Maximum total Levenshtein distance to accept (default: 3)
#' @return Data frame with matching rows, sorted by relevance score
fuzzy_search_df <- function(data, query, column_name, max_dist = 3) {
  if (is.null(query) || query == "") {
    return(data)
  }

  if (nrow(data) == 0) {
    return(data)
  }

  if (!column_name %in% colnames(data)) {
    return(data)
  }

  # Normalize query

query_norm <- normalize_text_for_search(query)
  query_tokens <- strsplit(query_norm, "\\s+")[[1]]

  # Normalize target column
  targets <- normalize_text_for_search(as.character(data[[column_name]]))

  # Calculate scores for each row
  scores <- vapply(seq_len(nrow(data)), function(i) {
    target <- targets[i]

    if (is.na(target) || target == "") {
      return(Inf)
    }

    # Exact substring match
    if (grepl(query_norm, target, fixed = TRUE)) {
      return(0)
    }

    # All tokens found
    all_found <- all(vapply(query_tokens, function(t) {
      grepl(t, target, fixed = TRUE)
    }, logical(1)))

    if (all_found) {
      return(0.5)
    }

    # Levenshtein distance on tokens
    target_words <- strsplit(target, "\\s+")[[1]]
    if (length(target_words) == 0) {
      return(Inf)
    }

    total_dist <- sum(vapply(query_tokens, function(q) {
      distances <- stringdist::stringdist(q, target_words, method = "lv")
      min(distances)
    }, numeric(1)))

    total_dist
  }, numeric(1))

  # Filter and sort by score
  mask <- scores <= max_dist
  result <- data[mask, , drop = FALSE]
  result_scores <- scores[mask]

  if (nrow(result) > 0) {
    result <- result[order(result_scores), , drop = FALSE]
  }

  result
}

#' Perform fuzzy search on a DuckDB table using Jaro-Winkler similarity
#'
#' Executes a fuzzy search directly in DuckDB using the jaro_winkler_similarity
#' function, which is highly optimized for large datasets (4M+ rows in ~200ms).
#'
#' @param con DuckDB connection object
#' @param table_name Name of the table to search in
#' @param column_name Name of the column to search (e.g., "concept_name")
#' @param query Search query string
#' @param min_score Minimum Jaro-Winkler similarity score (0-1, default: 0.75)
#' @param limit Maximum number of results to return (default: 100)
#' @param select_cols Character vector of columns to select (default: all with *)
#' @param additional_where Additional WHERE clause conditions (optional)
#' @return Data frame with matching rows, sorted by similarity score (descending)
fuzzy_search_duckdb <- function(
  con,
  table_name,
  column_name,
  query,
  min_score = 0.75,
  limit = 100,
  select_cols = "*",
  additional_where = NULL
) {
  if (is.null(query) || query == "") {
    return(NULL)
  }

  # Escape single quotes in query
  query_escaped <- gsub("'", "''", query)

  # Build SELECT clause
  select_clause <- if (length(select_cols) == 1 && select_cols == "*") {
    "*"
  } else {
    paste(select_cols, collapse = ", ")
  }

  # Build WHERE clause
  where_parts <- sprintf(
    "jaro_winkler_similarity(lower(%s), lower('%s')) > %s",
    column_name, query_escaped, min_score
  )

  if (!is.null(additional_where) && additional_where != "") {
    where_parts <- paste(where_parts, "AND", additional_where)
  }

  # Build full query
  sql <- sprintf(
    "SELECT %s,
            jaro_winkler_similarity(lower(%s), lower('%s')) as fuzzy_score
     FROM %s
     WHERE %s
     ORDER BY fuzzy_score DESC
     LIMIT %d",
    select_clause, column_name, query_escaped, table_name,
    where_parts, limit
  )

  DBI::dbGetQuery(con, sql)
}

#' Perform fuzzy search on a dplyr tbl (DuckDB lazy table)
#'
#' Similar to fuzzy_search_duckdb but works with dplyr tbl objects.
#' Useful when you already have a dplyr pipeline set up.
#'
#' @param tbl A dplyr tbl object connected to DuckDB
#' @param column_name Name of the column to search (unquoted or as string)
#' @param query Search query string
#' @param min_score Minimum Jaro-Winkler similarity score (0-1, default: 0.75)
#' @param limit Maximum number of results to return (default: 100)
#' @return Data frame with matching rows, sorted by similarity score (descending)
fuzzy_search_tbl <- function(tbl, column_name, query, min_score = 0.75, limit = 100) {
  if (is.null(query) || query == "") {
    return(NULL)
  }

  # Escape single quotes
  query_escaped <- gsub("'", "''", tolower(query))

  # Use dplyr with raw SQL for the similarity function
  tbl %>%
    dplyr::mutate(
      fuzzy_score = dplyr::sql(sprintf(
        "jaro_winkler_similarity(lower(%s), '%s')",
        column_name, query_escaped
      ))
    ) %>%
    dplyr::filter(fuzzy_score > min_score) %>%
    dplyr::arrange(dplyr::desc(fuzzy_score)) %>%
    utils::head(limit) %>%
    dplyr::collect()
}

#' Create Limit 10K Confirmation Modal UI
#'
#' Creates a modal dialog to confirm disabling the 10K row limit.
#' Used in conjunction with limit_10k_server() for the server logic.
#'
#' @param modal_id The modal ID (will be namespaced if ns is provided)
#' @param checkbox_id The checkbox ID to control (will be namespaced if ns is provided)
#' @param confirm_btn_id The confirm button ID (will be namespaced if ns is provided)
#' @param ns Optional namespace function from the module
#' @param i18n Optional i18n object for translations
#' @return A tags$div containing the modal overlay and content
limit_10k_modal_ui <- function(modal_id, checkbox_id, confirm_btn_id, ns = NULL, i18n = NULL) {
  # Apply namespace if provided
  modal_id_ns <- if (!is.null(ns)) ns(modal_id) else modal_id
  checkbox_id_ns <- if (!is.null(ns)) ns(checkbox_id) else checkbox_id
  confirm_btn_id_ns <- if (!is.null(ns)) ns(confirm_btn_id) else confirm_btn_id

  # Translation helpers
  confirm_action <- if (!is.null(i18n)) i18n$t("confirm_action") else "Confirm Action"
  warning_text <- if (!is.null(i18n)) i18n$t("limit_10k_warning") else "You are about to load all concepts without the 10,000 row limit."
  details_text <- if (!is.null(i18n)) i18n$t("limit_10k_warning_details") else "This operation may take several seconds. The application will not be responsive during this time."
  cancel_text <- if (!is.null(i18n)) i18n$t("cancel") else "Cancel"
  continue_text <- if (!is.null(i18n)) i18n$t("continue") else "Continue"

  tags$div(
    id = modal_id_ns,
    class = "modal-overlay",
    style = "display: none;",
    onclick = sprintf(
      "if (event.target === this) { $('#%s').hide(); $('#%s').prop('checked', true); Shiny.setInputValue('%s', true, {priority: 'event'}); }",
      modal_id_ns, checkbox_id_ns, checkbox_id_ns
    ),
    tags$div(
      class = "modal-content",
      style = "max-width: 450px;",
      tags$div(
        class = "modal-header",
        tags$h3(confirm_action),
        tags$button(
          class = "modal-close",
          onclick = sprintf(
            "$('#%s').hide(); $('#%s').prop('checked', true); Shiny.setInputValue('%s', true, {priority: 'event'});",
            modal_id_ns, checkbox_id_ns, checkbox_id_ns
          ),
          HTML("&times;")
        )
      ),
      tags$div(
        class = "modal-body",
        tags$p(
          style = "margin-bottom: 15px;",
          tags$i(class = "fas fa-exclamation-triangle", style = "color: #ffc107; margin-right: 8px;"),
          warning_text
        ),
        tags$p(
          style = "color: #666; font-size: 13px;",
          details_text
        )
      ),
      tags$div(
        class = "modal-footer",
        style = "display: flex; justify-content: flex-end; gap: 10px;",
        tags$button(
          class = "btn btn-secondary",
          onclick = sprintf(
            "$('#%s').hide(); $('#%s').prop('checked', true); Shiny.setInputValue('%s', true, {priority: 'event'});",
            modal_id_ns, checkbox_id_ns, checkbox_id_ns
          ),
          cancel_text
        ),
        actionButton(
          confirm_btn_id_ns,
          continue_text,
          class = "btn btn-primary-custom"
        )
      )
    )
  )
}

#' Set up Limit 10K confirmation server logic
#'
#' Creates observers to handle the limit 10K checkbox with confirmation modal.
#' Returns a reactiveVal that tracks whether the limit is disabled.
#'
#' @param checkbox_id The checkbox input ID (without namespace)
#' @param modal_id The modal element ID (without namespace)
#' @param confirm_btn_id The confirm button input ID (without namespace)
#' @param input The Shiny input object
#' @param session The Shiny session object
#' @param on_change Optional callback function called when limit state changes.
#'   Receives the new limit_10k value (TRUE = limited, FALSE = unlimited).
#' @param ns Optional namespace function
#' @return A reactiveVal containing TRUE if limit is active, FALSE if disabled
limit_10k_server <- function(checkbox_id, modal_id, confirm_btn_id, input, session,
                              on_change = NULL, ns = NULL) {
  # Apply namespace for JS selectors
  modal_id_ns <- if (!is.null(ns)) ns(modal_id) else modal_id
  checkbox_id_ns <- if (!is.null(ns)) ns(checkbox_id) else checkbox_id

  # Track if limit is active (TRUE by default)
  limit_active <- reactiveVal(TRUE)

  # Observer for checkbox - show confirmation when unchecking
 observe_event(input[[checkbox_id]], {
    # If checking (enabling limit), just update
    if (isTRUE(input[[checkbox_id]])) {
      limit_active(TRUE)
      if (!is.null(on_change)) on_change(TRUE)
      return()
    }
    # If unchecking, show confirmation modal
    if (isFALSE(input[[checkbox_id]])) {
      shinyjs::runjs(sprintf("$('#%s').show();", modal_id_ns))
      shinyjs::runjs(sprintf("$('#%s').prop('checked', true);", checkbox_id_ns))
    }
  }, ignoreInit = TRUE)

  # Observer for confirm button
  observe_event(input[[confirm_btn_id]], {
    shinyjs::runjs(sprintf("$('#%s').hide();", modal_id_ns))
    shinyjs::runjs(sprintf("$('#%s').prop('checked', false);", checkbox_id_ns))
    limit_active(FALSE)
    if (!is.null(on_change)) on_change(FALSE)
  }, ignoreInit = TRUE)

  limit_active
}

#' Create OMOP Advanced Filters Modal UI
#'
#' Creates a modal dialog for filtering OMOP concepts by vocabulary, domain,
#' concept class, standard concept status, and validity.
#'
#' @param prefix ID prefix for all inputs (will be namespaced if ns is provided)
#' @param ns Optional namespace function from the module
#' @param i18n Optional i18n object for translations
#' @return A tags$div containing the modal overlay and content
omop_filters_modal_ui <- function(prefix, ns = NULL, i18n = NULL) {
  # Apply namespace helper
  ns_id <- function(id) {
    full_id <- paste0(prefix, "_", id)
    if (!is.null(ns)) ns(full_id) else full_id
  }

  modal_id <- ns_id("modal")

  # Translation helpers
  title <- if (!is.null(i18n)) i18n$t("advanced_filters") else "Advanced Filters"
  select_placeholder <- if (!is.null(i18n)) i18n$t("select_or_type") else "Select or type..."
  reset_text <- if (!is.null(i18n)) i18n$t("reset_filters") else "Reset Filters"
  apply_text <- if (!is.null(i18n)) i18n$t("apply") else "Apply"

  tags$div(
    id = modal_id,
    class = "modal-overlay",
    style = "display: none;",
    onclick = sprintf("if (event.target === this) $('#%s').hide();", modal_id),
    tags$div(
      class = "modal-content",
      style = "max-width: 380px;",
      tags$div(
        class = "modal-header",
        tags$h3(title),
        tags$button(
          class = "modal-close",
          onclick = sprintf("$('#%s').hide();", modal_id),
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
            ns_id("vocabulary_id"),
            label = NULL,
            choices = NULL,
            multiple = TRUE,
            options = list(placeholder = select_placeholder)
          )
        ),
        tags$div(
          class = "mb-15",
          tags$label(class = "form-label", "Domain ID"),
          selectizeInput(
            ns_id("domain_id"),
            label = NULL,
            choices = NULL,
            multiple = TRUE,
            options = list(placeholder = select_placeholder)
          )
        ),
        tags$div(
          class = "mb-15",
          tags$label(class = "form-label", "Concept Class ID"),
          selectizeInput(
            ns_id("concept_class_id"),
            label = NULL,
            choices = NULL,
            multiple = TRUE,
            options = list(placeholder = select_placeholder)
          )
        ),
        tags$div(
          class = "mb-15",
          tags$label(class = "form-label", "Standard Concept"),
          selectizeInput(
            ns_id("standard_concept"),
            label = NULL,
            choices = NULL,
            multiple = TRUE,
            options = list(placeholder = select_placeholder)
          )
        ),
        tags$div(
          class = "mb-15",
          tags$label(class = "form-label", "Validity"),
          selectizeInput(
            ns_id("validity"),
            label = NULL,
            choices = NULL,
            multiple = TRUE,
            options = list(placeholder = select_placeholder)
          )
        )
      ),
      tags$div(
        class = "modal-footer",
        actionButton(
          ns_id("clear"),
          reset_text,
          class = "btn-secondary-custom",
          icon = icon("eraser")
        ),
        actionButton(
          ns_id("apply"),
          apply_text,
          class = "btn-primary-custom",
          icon = icon("check")
        )
      )
    )
  )
}

#' Set up OMOP Advanced Filters server logic
#'
#' Creates observers and reactive values to handle the OMOP filters modal.
#' Returns a list with the active filters reactiveVal and helper functions.
#'
#' @param prefix ID prefix used in omop_filters_modal_ui (without namespace)
#' @param input The Shiny input object
#' @param session The Shiny session object
#' @param vocabularies Reactive expression returning vocabulary data (with $concept table)
#' @param settings_btn_id Optional ID of the settings button to toggle active class
#' @param limit_checkbox_id Optional ID of the limit checkbox to reset on clear
#' @param on_apply Optional callback when filters are applied
#' @param on_clear Optional callback when filters are cleared
#' @param ns Optional namespace function
#' @return A list with:
#'   - filters: reactiveVal containing list of active filters
#'   - show: function to show the modal
#'   - has_active_filters: reactive returning TRUE if any filter is set
omop_filters_server <- function(prefix, input, session, vocabularies,
                                 settings_btn_id = NULL, limit_checkbox_id = NULL,
                                 on_apply = NULL, on_clear = NULL, ns = NULL) {
  # ID helpers (input IDs without namespace for accessing input$...)
  input_id <- function(id) paste0(prefix, "_", id)
  # Full namespaced IDs for JS selectors
  full_id <- function(id) {
    base_id <- paste0(prefix, "_", id)
    if (!is.null(ns)) ns(base_id) else base_id
  }

  modal_id <- full_id("modal")
  settings_btn_id_ns <- if (!is.null(settings_btn_id) && !is.null(ns)) ns(settings_btn_id) else settings_btn_id
  limit_checkbox_id_ns <- if (!is.null(limit_checkbox_id) && !is.null(ns)) ns(limit_checkbox_id) else limit_checkbox_id

  # Track whether filters have been loaded
  filters_loaded <- reactiveVal(FALSE)

  # Track active filters
  active_filters <- reactiveVal(list(
    vocabulary_id = NULL,
    domain_id = NULL,
    concept_class_id = NULL,
    standard_concept = NULL,
    validity = NULL
  ))

  # Function to show modal and load filter values
  show_modal <- function() {
    # Load filter values if not already loaded
    if (!filters_loaded()) {
      vocabs <- vocabularies()
      if (!is.null(vocabs) && !is.null(vocabs$concept)) {
        concept_tbl <- vocabs$concept

        # Get distinct values for each filter field
        vocab_ids <- concept_tbl %>%
          dplyr::distinct(vocabulary_id) %>%
          dplyr::arrange(vocabulary_id) %>%
          dplyr::collect() %>%
          dplyr::pull(vocabulary_id)

        domain_ids <- concept_tbl %>%
          dplyr::distinct(domain_id) %>%
          dplyr::arrange(domain_id) %>%
          dplyr::collect() %>%
          dplyr::pull(domain_id)

        concept_class_ids <- concept_tbl %>%
          dplyr::distinct(concept_class_id) %>%
          dplyr::arrange(concept_class_id) %>%
          dplyr::collect() %>%
          dplyr::pull(concept_class_id)

        standard_choices <- c(
          "Standard" = "S",
          "Classification" = "C",
          "Non-standard" = "NS"
        )

        validity_choices <- c("Valid", "Invalid")

        # Update selectize inputs
        updateSelectizeInput(session, input_id("vocabulary_id"), choices = vocab_ids, server = TRUE)
        updateSelectizeInput(session, input_id("domain_id"), choices = domain_ids, server = TRUE)
        updateSelectizeInput(session, input_id("concept_class_id"), choices = concept_class_ids, server = TRUE)
        updateSelectizeInput(session, input_id("standard_concept"), choices = standard_choices, server = FALSE)
        updateSelectizeInput(session, input_id("validity"), choices = validity_choices, server = FALSE)

        filters_loaded(TRUE)
      }
    }

    shinyjs::runjs(sprintf("$('#%s').show();", modal_id))
  }

  # Apply filters observer
  observe_event(input[[input_id("apply")]], {
    active_filters(list(
      vocabulary_id = input[[input_id("vocabulary_id")]],
      domain_id = input[[input_id("domain_id")]],
      concept_class_id = input[[input_id("concept_class_id")]],
      standard_concept = input[[input_id("standard_concept")]],
      validity = input[[input_id("validity")]]
    ))

    # Update settings button appearance
    if (!is.null(settings_btn_id_ns)) {
      filters <- active_filters()
      has_active <- any(sapply(filters, function(f) length(f) > 0))
      if (has_active) {
        shinyjs::runjs(sprintf("$('#%s').addClass('active');", settings_btn_id_ns))
      } else {
        shinyjs::runjs(sprintf("$('#%s').removeClass('active');", settings_btn_id_ns))
      }
    }

    shinyjs::runjs(sprintf("$('#%s').hide();", modal_id))

    if (!is.null(on_apply)) on_apply(active_filters())
  }, ignoreInit = TRUE)

  # Clear filters observer
  observe_event(input[[input_id("clear")]], {
    # Reset all selectize inputs
    updateSelectizeInput(session, input_id("vocabulary_id"), selected = character(0))
    updateSelectizeInput(session, input_id("domain_id"), selected = character(0))
    updateSelectizeInput(session, input_id("concept_class_id"), selected = character(0))
    updateSelectizeInput(session, input_id("standard_concept"), selected = character(0))
    updateSelectizeInput(session, input_id("validity"), selected = character(0))

    # Clear active filters
    active_filters(list(
      vocabulary_id = NULL,
      domain_id = NULL,
      concept_class_id = NULL,
      standard_concept = NULL,
      validity = NULL
    ))

    # Remove active class from settings button
    if (!is.null(settings_btn_id_ns)) {
      shinyjs::runjs(sprintf("$('#%s').removeClass('active');", settings_btn_id_ns))
    }

    # Reset limit checkbox if provided
    if (!is.null(limit_checkbox_id_ns)) {
      shinyjs::runjs(sprintf("$('#%s').prop('checked', true); Shiny.setInputValue('%s', true, {priority: 'event'});",
                             limit_checkbox_id_ns, limit_checkbox_id_ns))
    }

    shinyjs::runjs(sprintf("$('#%s').hide();", modal_id))

    if (!is.null(on_clear)) on_clear()
  }, ignoreInit = TRUE)

  # Return list with filters and helpers
  list(
    filters = active_filters,
    show = show_modal,
    has_active_filters = reactive({
      filters <- active_filters()
      any(sapply(filters, function(f) length(f) > 0))
    })
  )
}
