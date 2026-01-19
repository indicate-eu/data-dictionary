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
#' @return A tags$div containing the fuzzy search label and input
fuzzy_search_ui <- function(id, ns = NULL, i18n = NULL, placeholder = NULL,
                            limit_checkbox = FALSE, limit_checkbox_id = NULL) {

  input_id <- if (!is.null(ns)) ns(id) else id

  label_text <- if (!is.null(i18n)) i18n$t("fuzzy_search") else "Fuzzy Search"

  placeholder_text <- if (!is.null(placeholder)) {
    placeholder
  } else if (!is.null(i18n)) {
    i18n$t("fuzzy_search_placeholder")
  } else {
    "Search..."
  }

  # Build checkbox if requested
  limit_checkbox_el <- NULL
  if (limit_checkbox && !is.null(limit_checkbox_id)) {
    checkbox_id <- if (!is.null(ns)) ns(limit_checkbox_id) else limit_checkbox_id
    limit_checkbox_el <- tags$label(
      class = "fuzzy-search-limit-checkbox",
      style = "display: none;",
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
