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
#'
#' @return User ID of newly created user, or NULL if login exists
#' @noRd
add_user <- function(login, password, first_name = "", last_name = "",
                     role = "", affiliation = "") {
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
                        role, affiliation, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(login, password_hash, "", first_name, last_name,
                  role, affiliation, timestamp, timestamp)
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
  
  # Get user data
  result <- DBI::dbGetQuery(
    con,
    "SELECT user_id, login, password_hash, first_name, last_name,
            role, affiliation
     FROM users
     WHERE login = ?",
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
    "SELECT user_id, login, first_name, last_name, role, affiliation,
            created_at, updated_at
     FROM users
     ORDER BY created_at DESC"
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
#'
#' @return TRUE if successful
#' @noRd
update_user <- function(user_id, login = NULL, password = NULL,
                        first_name = NULL, last_name = NULL, role = NULL,
                        affiliation = NULL) {
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
