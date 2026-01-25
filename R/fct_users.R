#' User Management Functions
#'
#' @description Functions to manage users, authentication, and password hashing
#' @noRd
#'
#' @importFrom bcrypt hashpw gensalt checkpw

# USER CRUD ====

#' Add New User
#'
#' @description Create a new user in the database
#' @param login User login
#' @param password User password
#' @param first_name First name
#' @param last_name Last name
#' @param profession User profession
#' @param affiliation User affiliation
#' @param orcid User ORCID identifier
#' @param user_access_id User access profile ID
#' @return User ID of newly created user, or NULL if login exists
#' @noRd
add_user <- function(login, password, first_name = "", last_name = "",
                     profession = "", affiliation = "", orcid = "", user_access_id = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  existing <- DBI::dbGetQuery(
    con,
    "SELECT login FROM users WHERE login = ?",
    params = list(login)
  )

  if (nrow(existing) > 0) return(NULL)

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  password_hash <- hash_password(password)

  DBI::dbExecute(
    con,
    "INSERT INTO users (login, password_hash, first_name, last_name,
                        profession, affiliation, orcid, user_access_id, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(login, password_hash, first_name, last_name,
                  profession, affiliation, orcid, user_access_id, timestamp, timestamp)
  )

  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")
  result$id[1]
}

#' Authenticate User
#'
#' @description Verify user credentials and return user information
#' @param login User login
#' @param password User password
#' @return User data frame if authenticated, NULL otherwise
#' @noRd
authenticate_user <- function(login, password) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(
    con,
    "SELECT u.user_id, u.login, u.password_hash, u.first_name, u.last_name,
            u.profession, u.affiliation, u.orcid, u.user_access_id, ua.name as user_access_name
     FROM users u
     LEFT JOIN user_accesses ua ON u.user_access_id = ua.user_access_id
     WHERE u.login = ?",
    params = list(login)
  )

  if (nrow(result) == 0) return(NULL)

  user <- result[1, ]

  if (verify_password(password, user$password_hash)) {
    return(user)
  }

  NULL
}

#' Delete User
#'
#' @description Delete a user from the database
#' @param user_id User ID
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

#' Get All Users
#'
#' @description Retrieve all users from the database
#' @return Data frame with all users (excluding password fields)
#' @noRd
get_all_users <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT u.user_id, u.login, u.first_name, u.last_name, u.profession, u.affiliation, u.orcid,
            u.user_access_id, ua.name as user_access_name, u.created_at, u.updated_at
     FROM users u
     LEFT JOIN user_accesses ua ON u.user_access_id = ua.user_access_id
     ORDER BY u.created_at DESC"
  )
}

#' Update User
#'
#' @description Update an existing user
#' @param user_id User ID
#' @param login User login
#' @param password User password (if NULL, password not changed)
#' @param first_name First name
#' @param last_name Last name
#' @param profession User profession
#' @param affiliation User affiliation
#' @param orcid User ORCID identifier
#' @param user_access_id User access profile ID
#' @return TRUE if successful
#' @noRd
update_user <- function(user_id, login = NULL, password = NULL,
                        first_name = NULL, last_name = NULL, profession = NULL,
                        affiliation = NULL, orcid = NULL, user_access_id = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

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

  if (!is.null(profession)) {
    updates <- c(updates, "profession = ?")
    params <- c(params, profession)
  }

  if (!is.null(affiliation)) {
    updates <- c(updates, "affiliation = ?")
    params <- c(params, affiliation)
  }

  if (!is.null(orcid)) {
    updates <- c(updates, "orcid = ?")
    params <- c(params, orcid)
  }

  if (!is.null(user_access_id)) {
    updates <- c(updates, "user_access_id = ?")
    params <- c(params, user_access_id)
  }

  updates <- c(updates, "updated_at = ?")
  params <- c(params, timestamp)

  params <- c(params, user_id)

  query <- paste0(
    "UPDATE users SET ",
    paste(updates, collapse = ", "),
    " WHERE user_id = ?"
  )

  DBI::dbExecute(con, query, params = params)

  TRUE
}

# PASSWORD FUNCTIONS ====

#' Hash Password
#'
#' @description Create secure password hash using bcrypt
#' @param password Plain text password
#' @return Hashed password string
#' @noRd
hash_password <- function(password) {
  bcrypt::hashpw(password, bcrypt::gensalt(12))
}

#' Verify Password
#'
#' @description Check if provided password matches stored bcrypt hash
#' @param password Plain text password
#' @param stored_hash Stored bcrypt hash
#' @return Logical TRUE if password matches
#' @noRd
verify_password <- function(password, stored_hash) {
  tryCatch({
    bcrypt::checkpw(password, stored_hash)
  }, error = function(e) {
    FALSE
  })
}

# USER ACCESS FUNCTIONS ====

#' Add New User Access
#'
#' @description Create a new user access profile
#' @param name Profile name
#' @param description Profile description
#' @return User access ID of newly created profile, or NULL if name exists
#' @noRd
add_user_access <- function(name, description = "") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  existing <- DBI::dbGetQuery(
    con,
    "SELECT name FROM user_accesses WHERE name = ?",
    params = list(name)
  )

  if (nrow(existing) > 0) return(NULL)

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(
    con,
    "INSERT INTO user_accesses (name, description, created_at, updated_at)
     VALUES (?, ?, ?, ?)",
    params = list(name, description, timestamp, timestamp)
  )

  result <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")
  result$id[1]
}

#' Delete User Access
#'
#' @description Delete a user access profile
#' @param user_access_id User access ID
#' @return TRUE if successful, FALSE if users are still assigned
#' @noRd
delete_user_access <- function(user_access_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  users_count <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) as count FROM users WHERE user_access_id = ?",
    params = list(user_access_id)
  )

  if (users_count$count[1] > 0) return(FALSE)

  DBI::dbExecute(
    con,
    "DELETE FROM user_accesses WHERE user_access_id = ?",
    params = list(user_access_id)
  )

  TRUE
}

#' Get All User Accesses
#'
#' @description Retrieve all user access profiles
#' @return Data frame with all user accesses
#' @noRd
get_all_user_accesses <- function() {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(
    con,
    "SELECT user_access_id, name, description, created_at, updated_at
     FROM user_accesses
     ORDER BY user_access_id"
  )
}

#' Update User Access
#'
#' @description Update an existing user access profile
#' @param user_access_id User access ID
#' @param name Profile name
#' @param description Profile description
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
