#' User Management Functions
#'
#' @description Functions to manage users, authentication, and password hashing
#'
#' @noRd
#'
#' @importFrom bcrypt hashpw gensalt checkpw

#' Add new user
#'
#' @description Create a new user in the database
#'
#' @param login User login
#' @param password User password
#' @param first_name First name
#' @param last_name Last name
#' @param role User role
#' @param affiliation User affiliation
#' @param user_access_id User access profile ID
#'
#' @return User ID of newly created user, or NULL if login exists
#' @noRd
add_user <- function(login, password, first_name = "", last_name = "",
                     role = "", affiliation = "", user_access_id = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Check if login already exists
  existing <- DBI::dbGetQuery(
    con,
    "SELECT login FROM users WHERE login = ?",
    params = list(login)
  )

  if (nrow(existing) > 0) {
    return(NULL)
  }

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  password_hash <- hash_password(password)

  DBI::dbExecute(
    con,
    "INSERT INTO users (login, password_hash, salt, first_name, last_name,
                        role, affiliation, user_access_id, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(login, password_hash, "", first_name, last_name,
                  role, affiliation, user_access_id, timestamp, timestamp)
  )

  # Get the ID of the newly inserted user
  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")

  result$id[1]
}

#' Authenticate user
#'
#' @description Verify user credentials and return user information
#'
#' @param login User login
#' @param password User password
#'
#' @return User data frame if authenticated, NULL otherwise
#' @noRd
authenticate_user <- function(login, password) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Get user data with user access info
  result <- DBI::dbGetQuery(
    con,
    "SELECT u.user_id, u.login, u.password_hash, u.first_name, u.last_name,
            u.role, u.affiliation, u.user_access_id, ua.name as user_access_name
     FROM users u
     LEFT JOIN user_accesses ua ON u.user_access_id = ua.user_access_id
     WHERE u.login = ?",
    params = list(login)
  )

  if (nrow(result) == 0) {
    return(NULL)
  }

  user <- result[1, ]

  # Verify password using bcrypt
  if (verify_password(password, user$password_hash)) {
    return(user)
  }

  NULL
}

#' Delete user
#'
#' @description Delete a user from the database
#'
#' @param user_id User ID
#'
#' @return TRUE if successful
#' @noRd
delete_user <- function(user_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))
  
  DBI::dbExecute(
    con,
    "DELETE FROM users WHERE user_id = ?",
    params = list(user_id)
  )
  
  TRUE
}

#' Get all users
#'
#' @description Retrieve all users from the database
#'
#' @return Data frame with all users (excluding password fields)
#' @noRd
get_all_users <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT u.user_id, u.login, u.first_name, u.last_name, u.role, u.affiliation,
            u.user_access_id, ua.name as user_access_name, u.created_at, u.updated_at
     FROM users u
     LEFT JOIN user_accesses ua ON u.user_access_id = ua.user_access_id
     ORDER BY u.created_at DESC"
  )

  result
}

#' Hash password using bcrypt
#'
#' @description Create secure password hash using bcrypt (cost=12)
#' bcrypt is specifically designed for password hashing with:
#' - Built-in salt generation
#' - Adaptive cost factor (resistant to brute-force as hardware improves)
#' - Protection against timing attacks
#'
#' @param password Plain text password
#'
#' @return Hashed password string (contains salt and hash)
#' @noRd
hash_password <- function(password) {
  # bcrypt with cost=12 (recommended, ~300ms per hash on modern CPU)
  # The hash includes the salt, so no need to store it separately
  bcrypt::hashpw(password, bcrypt::gensalt(12))
}

#' Update user
#'
#' @description Update an existing user
#'
#' @param user_id User ID
#' @param login User login
#' @param password User password (if NULL, password not changed)
#' @param first_name First name
#' @param last_name Last name
#' @param role User role
#' @param affiliation User affiliation
#' @param user_access_id User access profile ID
#'
#' @return TRUE if successful
#' @noRd
update_user <- function(user_id, login = NULL, password = NULL,
                        first_name = NULL, last_name = NULL, role = NULL,
                        affiliation = NULL, user_access_id = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Build update query dynamically based on provided parameters
  updates <- c()
  params <- list()

  if (!is.null(login)) {
    updates <- c(updates, "login = ?")
    params <- c(params, login)
  }

  if (!is.null(password)) {
    password_hash <- hash_password(password)
    updates <- c(updates, "password_hash = ?")
    params <- c(params, password_hash)
  }

  if (!is.null(first_name)) {
    updates <- c(updates, "first_name = ?")
    params <- c(params, first_name)
  }

  if (!is.null(last_name)) {
    updates <- c(updates, "last_name = ?")
    params <- c(params, last_name)
  }

  if (!is.null(role)) {
    updates <- c(updates, "role = ?")
    params <- c(params, role)
  }

  if (!is.null(affiliation)) {
    updates <- c(updates, "affiliation = ?")
    params <- c(params, affiliation)
  }

  if (!is.null(user_access_id)) {
    updates <- c(updates, "user_access_id = ?")
    params <- c(params, user_access_id)
  }

  updates <- c(updates, "updated_at = ?")
  params <- c(params, timestamp)

  # Add user_id to end of params
  params <- c(params, user_id)

  query <- paste0(
    "UPDATE users SET ",
    paste(updates, collapse = ", "),
    " WHERE user_id = ?"
  )

  DBI::dbExecute(con, query, params = params)

  TRUE
}

#' Verify password against stored bcrypt hash
#'
#' @description Check if provided password matches stored bcrypt hash
#'
#' @param password Plain text password
#' @param stored_hash Stored bcrypt hash (includes salt)
#'
#' @return Logical TRUE if password matches
#' @noRd
verify_password <- function(password, stored_hash) {
  tryCatch({
    bcrypt::checkpw(password, stored_hash)
  }, error = function(e) {
    FALSE
  })
}

# User Access Functions ====

#' Check if user has permission
#'
#' @description Check if a user has a specific permission based on their user access profile
#'
#' @param user_id User ID
#' @param category Permission category
#' @param permission Permission name
#'
#' @return TRUE if user has full_access for this permission, FALSE otherwise
#' @noRd
has_permission <- function(user_id, category, permission) {
  if (is.null(user_id)) return(FALSE)

  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT uap.access_level
     FROM users u
     JOIN user_access_permissions uap ON u.user_access_id = uap.user_access_id
     WHERE u.user_id = ? AND uap.category = ? AND uap.permission = ?",
    params = list(user_id, category, permission)
  )

  if (nrow(result) == 0) return(FALSE)

  result$access_level[1] == "full_access"
}

#' Check if current user has permission (reactive version)
#'
#' @description Helper function for Shiny modules to check permissions.
#'   Accepts a reactive current_user and returns TRUE if the user has
#'   full_access for the specified permission.
#'
#' @param current_user Reactive function returning user data (must have user_id field)
#' @param category Permission category
#' @param permission Permission name
#'
#' @return TRUE if user has full_access for this permission, FALSE otherwise
#' @noRd
user_has_permission_for <- function(current_user, category, permission) {
  user <- current_user()
  if (is.null(user)) return(FALSE)
  if (is.null(user$user_id)) return(FALSE)
  has_permission(user$user_id, category, permission)
}

#' Get all user accesses
#'
#' @description Retrieve all user access profiles from the database
#'
#' @return Data frame with all user accesses
#' @noRd
get_all_user_accesses <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT user_access_id, name, description, created_at, updated_at
     FROM user_accesses
     ORDER BY user_access_id"
  )

  result
}

#' Get user access by ID
#'
#' @description Retrieve a specific user access profile
#'
#' @param user_access_id User access ID
#'
#' @return Data frame with user access info
#' @noRd
get_user_access <- function(user_access_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT user_access_id, name, description, created_at, updated_at
     FROM user_accesses
     WHERE user_access_id = ?",
    params = list(user_access_id)
  )

  if (nrow(result) == 0) return(NULL)

  result[1, ]
}

#' Add new user access
#'
#' @description Create a new user access profile
#'
#' @param name Profile name
#' @param description Profile description
#'
#' @return User access ID of newly created profile, or NULL if name exists
#' @noRd
add_user_access <- function(name, description = "") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Check if name already exists
  existing <- DBI::dbGetQuery(
    con,
    "SELECT name FROM user_accesses WHERE name = ?",
    params = list(name)
  )

  if (nrow(existing) > 0) {
    return(NULL)
  }

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "INSERT INTO user_accesses (name, description, created_at, updated_at)
     VALUES (?, ?, ?, ?)",
    params = list(name, description, timestamp, timestamp)
  )

  # Get the ID of the newly inserted user access
  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")
  user_access_id <- result$id[1]

  # Initialize permissions with read_only for all
  all_permissions <- get_all_permission_definitions()

  for (i in seq_len(nrow(all_permissions))) {
    DBI::dbExecute(
      con,
      "INSERT INTO user_access_permissions (user_access_id, category, permission, access_level)
       VALUES (?, ?, ?, 'read_only')",
      params = list(user_access_id, all_permissions$category[i], all_permissions$permission[i])
    )
  }

  user_access_id
}

#' Update user access
#'
#' @description Update an existing user access profile
#'
#' @param user_access_id User access ID
#' @param name Profile name
#' @param description Profile description
#'
#' @return TRUE if successful
#' @noRd
update_user_access <- function(user_access_id, name = NULL, description = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  updates <- c()
  params <- list()

  if (!is.null(name)) {
    updates <- c(updates, "name = ?")
    params <- c(params, name)
  }

  if (!is.null(description)) {
    updates <- c(updates, "description = ?")
    params <- c(params, description)
  }

  updates <- c(updates, "updated_at = ?")
  params <- c(params, timestamp)

  params <- c(params, user_access_id)

  query <- paste0(
    "UPDATE user_accesses SET ",
    paste(updates, collapse = ", "),
    " WHERE user_access_id = ?"
  )

  DBI::dbExecute(con, query, params = params)

  TRUE
}

#' Delete user access
#'
#' @description Delete a user access profile
#'
#' @param user_access_id User access ID
#'
#' @return TRUE if successful, FALSE if users are still assigned to this profile
#' @noRd
delete_user_access <- function(user_access_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Check if any users are assigned to this profile
  users_count <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) as count FROM users WHERE user_access_id = ?",
    params = list(user_access_id)
  )

  if (users_count$count[1] > 0) {
    return(FALSE)
  }

  # Delete permissions first
  DBI::dbExecute(
    con,
    "DELETE FROM user_access_permissions WHERE user_access_id = ?",
    params = list(user_access_id)
  )

  # Delete user access
  DBI::dbExecute(
    con,
    "DELETE FROM user_accesses WHERE user_access_id = ?",
    params = list(user_access_id)
  )

  TRUE
}

#' Get permissions for a user access profile
#'
#' @description Retrieve all permissions for a user access profile
#'
#' @param user_access_id User access ID
#'
#' @return Data frame with permissions
#' @noRd
get_user_access_permissions <- function(user_access_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT permission_id, category, permission, access_level
     FROM user_access_permissions
     WHERE user_access_id = ?
     ORDER BY category, permission",
    params = list(user_access_id)
  )

  result
}

#' Update a specific permission for a user access profile
#'
#' @description Update the access level for a specific permission
#'
#' @param user_access_id User access ID
#' @param category Permission category
#' @param permission Permission name
#' @param access_level Access level ('read_only' or 'full_access')
#'
#' @return TRUE if successful
#' @noRd
update_user_access_permission <- function(user_access_id, category, permission, access_level) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(
    con,
    "UPDATE user_access_permissions
     SET access_level = ?
     WHERE user_access_id = ? AND category = ? AND permission = ?",
    params = list(access_level, user_access_id, category, permission)
  )

  # Update user_accesses updated_at timestamp
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  DBI::dbExecute(
    con,
    "UPDATE user_accesses SET updated_at = ? WHERE user_access_id = ?",
    params = list(timestamp, user_access_id)
  )

  TRUE
}

#' Get all permission definitions
#'
#' @description Get the list of all available permissions with their categories
#'
#' @return Data frame with category, permission, and description columns
#' @noRd
get_all_permission_definitions <- function() {
  data.frame(
    category = c(
      "dictionary", "dictionary", "dictionary",
      "dictionary", "dictionary", "dictionary",
      "dictionary", "dictionary", "dictionary",
      "projects", "projects", "projects", "projects",
      "alignments", "alignments", "alignments", "alignments", "alignments",
      "alignments", "alignments", "alignments", "alignments", "alignments",
      "users", "users", "users", "users",
      "user_accesses", "user_accesses", "user_accesses", "user_accesses",
      "general_settings", "general_settings", "general_settings",
      "dictionary_settings", "dictionary_settings", "dictionary_settings",
      "dictionary_settings", "dictionary_settings", "dictionary_settings",
      "dev_tools", "dev_tools"
    ),
    permission = c(
      "add_general_concept", "edit_general_concept", "delete_general_concept",
      "add_associated_concept", "edit_associated_concept", "delete_associated_concept",
      "update_comment", "update_statistical_summary", "delete_history",
      "access_projects", "add_project", "edit_project", "delete_project",
      "access_concepts_mapping", "add_alignment", "edit_alignment", "delete_alignment", "import_alignment",
      "add_mapping", "import_mappings", "delete_mapping", "export_mappings", "evaluate_mappings",
      "access_users_page", "add_user", "edit_user", "delete_user",
      "add_user_access", "edit_user_access", "delete_user_access", "edit_permissions",
      "access_general_settings", "access_terminologies", "access_backup_restore",
      "access_dictionary_settings", "import_data_dictionary", "export_data_dictionary",
      "add_unit_conversion", "edit_unit_conversion", "delete_unit_conversion",
      "view_dev_tools", "execute_code"
    ),
    description = c(
      "Add general concepts", "Edit general concepts", "Delete general concepts",
      "Add associated concepts", "Edit associated concepts", "Delete associated concepts",
      "Update global comments", "Update statistical summary", "Delete history entries",
      "Access Projects page", "Add projects", "Edit projects", "Delete projects",
      "Access Concepts Mapping page", "Add alignments", "Edit alignments", "Delete alignments", "Import alignments",
      "Add mappings", "Import mappings", "Delete mappings", "Export mappings", "Evaluate mappings",
      "Access Users page", "Add users", "Edit users", "Delete users",
      "Add user access profiles", "Edit user access profiles", "Delete user access profiles", "Edit permissions",
      "Access General Settings", "Access Terminologies tab", "Access Backup & Restore tab",
      "Access Dictionary Settings", "Import data dictionary", "Export data dictionary",
      "Add unit conversions", "Edit unit conversions", "Delete unit conversions",
      "View Dev Tools page", "Execute R code in console"
    ),
    stringsAsFactors = FALSE
  )
}

#' Get permission categories
#'
#' @description Get the list of permission categories with display names
#'
#' @return Data frame with category and display_name columns
#' @noRd
get_permission_categories <- function() {
  data.frame(
    category = c(
      "dictionary", "projects", "alignments", "users",
      "user_accesses", "general_settings", "dictionary_settings", "dev_tools"
    ),
    display_name = c(
      "Dictionary", "Projects", "Alignments", "Users",
      "User Accesses", "General Settings", "Dictionary Settings", "Dev Tools"
    ),
    stringsAsFactors = FALSE
  )
}
