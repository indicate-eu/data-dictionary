#' Build FHIR Resource URL
#'
#' @description Build FHIR resource URL for concept lookup
#'
#' @param vocabulary_id Single vocabulary identifier (SNOMED, LOINC, etc.)
#' @param concept_code The concept code to look up
#' @param config Configuration list containing FHIR settings
#'
#' @return FHIR lookup URL, "no_link" for vocabularies without FHIR support, or NULL
#' @noRd
#'
#' @importFrom htmltools tags
build_fhir_url <- function(vocabulary_id, concept_code, config) {
  # Ensure single value input
  if (length(vocabulary_id) != 1 || length(concept_code) != 1) {
    warning("build_fhir_url expects single values, got multiple")
    return(NULL)
  }

  # Check if vocabulary should show "No link available"
  if (vocabulary_id %in% config$fhir_no_link_vocabularies) {
    return("no_link")
  }

  # Check if vocabulary is supported
  if (vocabulary_id %in% names(config$fhir_systems) &&
      vocabulary_id %in% names(config$fhir_base_url)) {

    system <- config$fhir_systems[[vocabulary_id]]
    base_url <- config$fhir_base_url[[vocabulary_id]]

    # Build FHIR lookup URL
    return(paste0(
      base_url,
      "/CodeSystem/$lookup?system=",
      system,
      "&code=",
      concept_code
    ))
  }

  return(NULL)
}

#' Build FHIR URL for Unit Concepts
#'
#' @description Build FHIR URL for unit concepts (assumes UCUM system)
#'
#' @param unit_concept_name The unit concept name
#' @param config Configuration list containing FHIR settings
#'
#' @return FHIR lookup URL for unit or NULL if invalid
#' @noRd
build_unit_fhir_url <- function(unit_concept_name, config) {
  # Validate input
  if (length(unit_concept_name) != 1) {
    warning("build_unit_fhir_url expects single value, got multiple")
    return(NULL)
  }

  # Check if unit concept is valid
  if (!is.na(unit_concept_name) &&
      !is.null(unit_concept_name) &&
      unit_concept_name != "" &&
      unit_concept_name != "/") {

    # Use UCUM system for units
    system <- config$fhir_systems[["UCUM"]]
    base_url <- config$fhir_base_url[["UCUM"]]

    return(paste0(
      base_url,
      "/CodeSystem/$lookup?system=",
      system,
      "&code=",
      URLencode(unit_concept_name)
    ))
  }

  return(NULL)
}

#' Build ATHENA OHDSI URL
#'
#' @description Build ATHENA OHDSI URL for concept lookup
#'
#' @param concept_id OMOP concept ID
#' @param config Configuration list containing ATHENA base URL
#'
#' @return ATHENA lookup URL or NULL if concept_id is invalid
#' @noRd
build_athena_url <- function(concept_id, config) {
  # Validate input
  if (is.null(concept_id) || is.na(concept_id)) {
    return(NULL)
  }

  # Build ATHENA URL
  return(paste0(config$athena_base_url, "/", concept_id))
}

#' Create Clickable HTML Link
#'
#' @description Create clickable HTML link
#'
#' @param url The URL to link to
#' @param text The display text for the link
#'
#' @return HTML link element or plain text if no URL
#' @noRd
#'
#' @importFrom htmltools tags
create_link <- function(url, text) {
  if (!is.null(url) && !is.na(url)) {
    tags$a(href = url, target = "_blank", text)
  } else {
    text
  }
}

#' Create Keyboard Navigation JavaScript Options
#'
#' @description Create keyboard navigation options for DataTables
#'
#' @param keyboard_nav JavaScript code for keyboard navigation
#' @param auto_select_first_row Whether to auto-select first row
#' @param auto_focus Whether to auto-focus the table
#'
#' @return JavaScript callback function
#' @noRd
#'
#' @importFrom htmlwidgets JS
create_keyboard_nav <- function(keyboard_nav, auto_select_first_row = TRUE, auto_focus = TRUE) {
  JS(sprintf("function(settings, json) {
    json = json || {};
    json.autoSelectFirstRow = %s;
    json.autoFocus = %s;
    return (%s)(settings, json);
  }",
             tolower(auto_select_first_row),
             tolower(auto_focus),
             keyboard_nav))
}

#' Get Path to Application Resources
#'
#' @description Get the path to application resources (www, data directories)
#'
#' @param ... Path components to append after the app directory
#'
#' @return Full path to the requested resource
#' @noRd
app_sys <- function(...) {
  system.file(..., package = "indicate")
}

#' Get Clinical Drug Concepts from Ingredient
#'
#' @description Query OHDSI vocabularies to retrieve Clinical Drug concepts
#' that are descendants of a given RxNorm Ingredient concept
#'
#' @param ingredient_concept_id Integer. The RxNorm Ingredient concept_id
#' @param vocabularies Reactive containing preloaded OHDSI vocabulary tables
#'
#' @return Data frame with Clinical Drug concepts
#' @noRd
#'
#' @importFrom dplyr filter select arrange distinct inner_join
get_clinical_drugs_from_ingredient <- function(
    ingredient_concept_id,
    vocabularies
) {
  # Validate input
  if (is.null(ingredient_concept_id) || is.na(ingredient_concept_id)) {
    return(data.frame(
      concept_id = integer(),
      concept_name = character(),
      vocabulary_id = character(),
      concept_code = character(),
      concept_class_id = character()
    ))
  }

  # Get vocabulary tables
  concept <- vocabularies$concept
  concept_ancestor <- vocabularies$concept_ancestor

  # Get Clinical Drug descendants using concept_ancestor
  clinical_drugs <- concept_ancestor %>%
    filter(ancestor_concept_id == ingredient_concept_id) %>%
    inner_join(
      concept %>%
        filter(
          concept_class_id == "Clinical Drug",
          vocabulary_id %in% c("RxNorm", "RxNorm Extension"),
          domain_id == "Drug",
          is.na(invalid_reason) | invalid_reason == ""
        ),
      by = c("descendant_concept_id" = "concept_id")
    ) %>%
    select(
      concept_id = descendant_concept_id,
      concept_name,
      vocabulary_id,
      concept_code,
      concept_class_id,
      standard_concept
    ) %>%
    distinct() %>%
    arrange(concept_name)

  return(as.data.frame(clinical_drugs))
}

#' Get Default Statistical Summary JSON Template
#'
#' @description Returns the default JSON structure for statistical summary
#'
#' @return Character string containing default JSON template
#' @noRd
get_default_statistical_summary_template <- function() {
  '{
  "data_types": ["numeric"],
  "statistical_data": {
    "min": null,
    "max": null,
    "median": null,
    "mean": null,
    "p5": null,
    "p25": null,
    "p75": null,
    "p95": null,
    "outliers_count": null
  },
  "temporal_info": {
    "frequency_range": {
      "min": null,
      "max": null
    },
    "measurement_period": []
  },
  "possible_values": []
}'
}
