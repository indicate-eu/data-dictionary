# Import/Export Functions for Concept Sets

# GITHUB IMPORT FUNCTIONS ====

#' Apply concept set updates from GitHub
#'
#' @description Applies updates from a downloaded GitHub repository.
#'              New concept sets are imported, updated ones are deleted and re-imported.
#'
#' @param updates Result from check_concept_sets_updates()
#' @param extracted_dir Path to extracted concept_sets folder
#' @param language Language code (default: "en")
#' @param progress_callback Optional function(current, total) for progress reporting
#'
#' @return List with success_count and failed_count
#' @noRd
apply_concept_sets_updates <- function(updates, extracted_dir, language = "en", progress_callback = NULL) {
  items_to_process <- c(updates$new, updates$updated)
  total <- length(items_to_process)
  success_count <- 0
  failed_count <- 0

  for (i in seq_along(items_to_process)) {
    item <- items_to_process[[i]]
    json_file <- file.path(extracted_dir, paste0(item$id, ".json"))

    if (!file.exists(json_file)) {
      failed_count <- failed_count + 1
      next
    }

    # For updated items, delete existing first
    if (item$status == "updated") {
      tryCatch(
        delete_concept_set(item$id),
        error = function(e) NULL
      )
    }

    # Import from JSON
    result <- import_concept_set_from_json(json_file, language = language)
    if (!is.null(result)) {
      success_count <- success_count + 1
    } else {
      failed_count <- failed_count + 1
    }

    if (is.function(progress_callback)) {
      progress_callback(i, total)
    }
  }

  list(success_count = success_count, failed_count = failed_count)
}

#' Check for concept set updates
#'
#' @description Compares remote concept sets (from extracted ZIP) against local database.
#'              Classifies each as new, updated, or unchanged.
#'
#' @param extracted_dir Path to extracted concept_sets folder
#' @param language Language code (default: "en")
#'
#' @return List with new, updated, unchanged (each a list of items with id, name, status,
#'         local_version, remote_version, local_date, remote_date)
#' @noRd
check_concept_sets_updates <- function(extracted_dir, language = "en") {
  # Get local concept sets

  local_data <- get_all_concept_sets(language = language)
  local_lookup <- list()
  if (!is.null(local_data) && nrow(local_data) > 0) {
    for (i in seq_len(nrow(local_data))) {
      local_lookup[[as.character(local_data$id[i])]] <- list(
        id = local_data$id[i],
        name = local_data$name[i],
        version = if ("version" %in% names(local_data)) local_data$version[i] else NA,
        modified_date = if ("modified_date" %in% names(local_data)) local_data$modified_date[i] else NA
      )
    }
  }

  # Read remote JSON files
  json_files <- list.files(extracted_dir, pattern = "\\.json$", full.names = TRUE)
  json_files <- json_files[!grepl("README", basename(json_files), ignore.case = TRUE)]

  new_items <- list()
  updated_items <- list()
  unchanged_items <- list()

  for (json_file in json_files) {
    json_data <- tryCatch({
      json_text <- readLines(json_file, encoding = "UTF-8", warn = FALSE)
      jsonlite::fromJSON(paste(json_text, collapse = "\n"), simplifyVector = FALSE)
    }, error = function(e) NULL)

    if (is.null(json_data)) next

    remote_id <- as.character(json_data$id)
    remote_name <- if (!is.null(json_data$name)) json_data$name else paste("Concept Set", remote_id)
    remote_version <- if (!is.null(json_data$version)) json_data$version else "1.0.0"
    remote_date <- if (!is.null(json_data$modifiedDate)) json_data$modifiedDate else if (!is.null(json_data$createdDate)) json_data$createdDate else ""

    local <- local_lookup[[remote_id]]

    if (is.null(local)) {
      # New concept set
      new_items[[length(new_items) + 1]] <- list(
        id = as.integer(remote_id),
        name = remote_name,
        status = "new",
        local_version = NA,
        remote_version = remote_version,
        local_date = NA,
        remote_date = remote_date
      )
    } else {
      # Compare version and date
      local_version <- if (!is.null(local$version)) local$version else ""
      local_date <- if (!is.null(local$modified_date)) local$modified_date else ""

      if (!identical(as.character(local_version), as.character(remote_version)) ||
          !identical(as.character(local_date), as.character(remote_date))) {
        updated_items[[length(updated_items) + 1]] <- list(
          id = as.integer(remote_id),
          name = remote_name,
          status = "updated",
          local_version = local_version,
          remote_version = remote_version,
          local_date = local_date,
          remote_date = remote_date
        )
      } else {
        unchanged_items[[length(unchanged_items) + 1]] <- list(
          id = as.integer(remote_id),
          name = remote_name,
          status = "unchanged",
          local_version = local_version,
          remote_version = remote_version,
          local_date = local_date,
          remote_date = remote_date
        )
      }
    }
  }

  list(
    new = new_items,
    updated = updated_items,
    unchanged = unchanged_items
  )
}

#' Download concept sets from GitHub repository
#'
#' @description Downloads a GitHub repository as ZIP and extracts the concept_sets folder.
#'
#' @param repo_url GitHub repository URL (e.g. "https://github.com/owner/repo")
#' @param branch Branch name (default: "main")
#'
#' @return Path to extracted concept_sets folder, or NULL on failure
#' @noRd
download_github_concept_sets <- function(repo_url, branch = "main") {
  parsed <- parse_github_url(repo_url)
  if (is.null(parsed)) return(NULL)

  zip_url <- sprintf("https://github.com/%s/%s/archive/refs/heads/%s.zip",
                      parsed$owner, parsed$repo, branch)

  temp_zip <- tempfile(fileext = ".zip")
  temp_dir <- tempfile()
  dir.create(temp_dir)

  tryCatch({
    old_timeout <- getOption("timeout")
    options(timeout = 300)
    on.exit(options(timeout = old_timeout), add = TRUE)

    utils::download.file(zip_url, temp_zip, mode = "wb", quiet = TRUE)
    utils::unzip(temp_zip, exdir = temp_dir)

    # GitHub ZIP extracts to {repo}-{branch}/ folder
    extracted_dirs <- list.dirs(temp_dir, recursive = FALSE)
    if (length(extracted_dirs) == 0) return(NULL)

    # Find concept_sets folder
    concept_sets_dir <- file.path(extracted_dirs[1], "concept_sets")
    if (!dir.exists(concept_sets_dir)) return(NULL)

    concept_sets_dir
  }, error = function(e) {
    NULL
  }, finally = {
    if (file.exists(temp_zip)) unlink(temp_zip)
  })
}

#' Get latest GitHub commit SHA for a path
#'
#' @description Queries the GitHub API to get the latest commit SHA that modified a specific path.
#'
#' @param repo_url GitHub repository URL
#' @param path Path within the repository (default: "concept_sets")
#' @param branch Branch name (default: "main")
#'
#' @return Commit SHA string, or NULL on failure
#' @noRd
get_github_latest_commit <- function(repo_url, path = "concept_sets", branch = "main") {
  parsed <- parse_github_url(repo_url)
  if (is.null(parsed)) return(NULL)

  api_url <- sprintf(
    "https://api.github.com/repos/%s/%s/commits?path=%s&sha=%s&per_page=1",
    parsed$owner, parsed$repo, utils::URLencode(path, reserved = TRUE), branch
  )

  tryCatch({
    temp_file <- tempfile(fileext = ".json")
    on.exit(unlink(temp_file), add = TRUE)

    old_timeout <- getOption("timeout")
    options(timeout = 30)
    on.exit(options(timeout = old_timeout), add = TRUE)

    utils::download.file(api_url, temp_file, quiet = TRUE)

    json_text <- readLines(temp_file, encoding = "UTF-8", warn = FALSE)
    commits <- jsonlite::fromJSON(paste(json_text, collapse = "\n"), simplifyVector = FALSE)

    if (length(commits) == 0) return(NULL)

    commits[[1]]$sha
  }, error = function(e) {
    NULL
  })
}

#' Import concept sets from GitHub repository
#'
#' @description Downloads concept sets from a GitHub repository and imports them into the database.
#'              On success, saves the repository URL and commit SHA to config.
#'
#' @param repo_url GitHub repository URL
#' @param branch Branch name (default: "main")
#' @param language Language code (default: "en")
#' @param progress_callback Optional function(current, total) for progress reporting
#'
#' @return List with success_count, failed_count, total, or NULL on download failure
#' @noRd
import_concept_sets_from_github <- function(repo_url, branch = "main", language = "en", progress_callback = NULL) {
  # Download and extract
  concept_sets_dir <- download_github_concept_sets(repo_url, branch)
  if (is.null(concept_sets_dir)) return(NULL)

  # Find JSON files
  json_files <- list.files(concept_sets_dir, pattern = "\\.json$", full.names = TRUE)
  json_files <- json_files[!grepl("README", basename(json_files), ignore.case = TRUE)]

  if (length(json_files) == 0) return(NULL)

  total <- length(json_files)
  success_count <- 0
  failed_count <- 0

  for (i in seq_along(json_files)) {
    result <- import_concept_set_from_json(json_files[i], language = language)
    if (!is.null(result)) {
      success_count <- success_count + 1
    } else {
      failed_count <- failed_count + 1
    }

    if (is.function(progress_callback)) {
      progress_callback(i, total)
    }
  }

  # Save config on success
  if (success_count > 0) {
    set_config_value("concept_sets_repo_url", repo_url)

    # Also store the latest commit SHA
    sha <- get_github_latest_commit(repo_url, branch = branch)
    if (!is.null(sha)) {
      set_config_value("concept_sets_last_commit_sha", sha)
    }
  }

  list(success_count = success_count, failed_count = failed_count, total = total)
}

#' Parse GitHub URL
#'
#' @description Extracts owner and repo from a GitHub URL.
#'
#' @param url GitHub URL (e.g. "https://github.com/owner/repo")
#'
#' @return List with owner and repo, or NULL if invalid
#' @noRd
parse_github_url <- function(url) {
  if (is.null(url) || !is.character(url) || nchar(trimws(url)) == 0) return(NULL)

  url <- trimws(url)
  # Remove trailing slash and any path beyond owner/repo
  url <- sub("/$", "", url)

  # Match github.com/owner/repo pattern

  match <- regmatches(url, regexec("github\\.com/([^/]+)/([^/]+)", url))[[1]]

  if (length(match) < 3) return(NULL)

  owner <- match[2]
  repo <- sub("\\.git$", "", match[3])

  if (nchar(owner) == 0 || nchar(repo) == 0) return(NULL)

  list(owner = owner, repo = repo)
}

# ZIP IMPORT FUNCTIONS ====

#' Import concept sets from ZIP file
#'
#' @description Imports concept sets from a ZIP file containing JSON files
#'              Supports two structures: JSON at root or in concept_sets/ folder
#'
#' @param zip_file Path to ZIP file
#' @param mode Import mode: "add" (add to existing) or "replace" (replace all)
#' @param language Language code for default language (default: "en")
#'
#' @return List with success status, count of imported concept sets, and any errors
#' @noRd
import_concept_sets_from_zip <- function(zip_file, mode = "add", language = "en") {
  tryCatch({
    # Create temporary directory for extraction
    temp_dir <- tempfile()
    dir.create(temp_dir)
    on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

    # Extract ZIP
    utils::unzip(zip_file, exdir = temp_dir)

    # Find JSON files - check both root and concept_sets/ folder
    json_files <- list.files(temp_dir, pattern = "\\.json$", full.names = TRUE, recursive = FALSE)

    # If no JSON at root, check for concept_sets/ folder
    if (length(json_files) == 0) {
      concept_sets_dir <- file.path(temp_dir, "concept_sets")
      if (dir.exists(concept_sets_dir)) {
        json_files <- list.files(concept_sets_dir, pattern = "\\.json$", full.names = TRUE, recursive = FALSE)
      }
    }

    # Filter out README files
    json_files <- json_files[!grepl("README", basename(json_files), ignore.case = TRUE)]

    if (length(json_files) == 0) {
      return(list(
        success = FALSE,
        count = 0,
        message = "no_json_files_found"
      ))
    }

    # Import each JSON file with appropriate mode handling
    imported_count <- 0
    updated_count <- 0
    skipped_count <- 0
    errors <- character()

    con <- get_db_connection()
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    for (json_file in json_files) {
      # Read JSON to get the concept set ID (with UTF-8 encoding)
      json_data <- tryCatch({
        json_text <- readLines(json_file, encoding = "UTF-8", warn = FALSE)
        jsonlite::fromJSON(paste(json_text, collapse = "\n"))
      }, error = function(e) {
        errors <- c(errors, basename(json_file))
        return(NULL)
      })

      if (is.null(json_data)) next

      concept_set_id <- json_data$id

      # Check if concept set already exists
      existing <- DBI::dbGetQuery(
        con,
        "SELECT id FROM concept_sets WHERE id = ?",
        params = list(concept_set_id)
      )

      is_update <- FALSE

      if (mode == "add") {
        # Add mode: skip if exists
        if (nrow(existing) > 0) {
          skipped_count <- skipped_count + 1
          next
        }
      } else if (mode == "replace") {
        # Replace mode: delete existing before importing
        if (nrow(existing) > 0) {
          DBI::dbExecute(
            con,
            "DELETE FROM concept_sets WHERE id = ?",
            params = list(concept_set_id)
          )
          is_update <- TRUE
        }
      }

      # Import the concept set
      result <- import_concept_set_from_json(json_file, language = language)

      if (!is.null(result)) {
        if (is_update) {
          updated_count <- updated_count + 1
        } else {
          imported_count <- imported_count + 1
        }
      } else {
        errors <- c(errors, basename(json_file))
      }
    }

    # Build message based on mode and results
    if (mode == "add") {
      total_processed <- imported_count + skipped_count
      message_text <- sprintf(
        "Imported %d new concept sets, %d skipped (already exist)",
        imported_count, skipped_count
      )
    } else {
      total_processed <- imported_count + updated_count
      message_text <- sprintf(
        "Imported %d new concept sets, %d updated",
        imported_count, updated_count
      )
    }

    if (length(errors) > 0) {
      message_text <- sprintf("%s, %d failed", message_text, length(errors))
    }

    return(list(
      success = TRUE,
      count = total_processed,
      imported = imported_count,
      updated = updated_count,
      skipped = skipped_count,
      errors = errors,
      message = message_text
    ))

  }, error = function(e) {
    return(list(
      success = FALSE,
      count = 0,
      message = paste("Error:", e$message)
    ))
  })
}
