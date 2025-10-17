#' Get Application Configuration
#'
#' @description Returns the configuration settings for the INDICATE application
#'
#' @return A list containing configuration parameters
#' @noRd
get_config <- function() {
  list(
    # FHIR configuration - Base URLs for terminology services
    fhir_base_url = list(
      SNOMED = "https://tx.fhir.org/r4",
      LOINC = "https://tx.fhir.org/r4",
      ICD10 = "https://tx.fhir.org/r4",
      UCUM = "https://tx.fhir.org/r4",
      RxNorm = "https://tx.fhir.org/r4"
    ),

    # FHIR system identifiers for each vocabulary
    fhir_systems = list(
      SNOMED = "http://snomed.info/sct",
      LOINC = "http://loinc.org",
      ICD10 = "http://hl7.org/fhir/sid/icd-10",
      UCUM = "http://unitsofmeasure.org",
      RxNorm = "http://www.nlm.nih.gov/research/umls/rxnorm"
    ),

    # External links
    athena_base_url = "https://athena.ohdsi.org/search-terms/terms"
  )
}
