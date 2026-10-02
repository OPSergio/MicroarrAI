#!/usr/bin/env Rscript
# =============================================================================
# Manage admin accounts in the state database (run on the server, never in
# the browser). Passwords are read from stdin so they never appear in `ps`
# or the shell history.
#
#   Rscript manage_users.R list
#   Rscript manage_users.R add <user>       # also resets the password
#   Rscript manage_users.R disable <user>
#   Rscript manage_users.R enable <user>
#
# In the Singularity deployment use: ./singularity/singularity-deploy.sh users
# =============================================================================

here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "..", "R", "utils", "state_db.R"), encoding = "UTF-8")
source(file.path(here, "modules", "auth.R"), encoding = "UTF-8")

MIN_PASSWORD <- 8

args <- commandArgs(TRUE)
cmd <- c(args, "")[1]
username <- c(args[-1], "")[1]

con <- state_db_connect()
if (is.null(con)) stop("State directory not writable: ", state_dir(), call. = FALSE)

if (cmd == "list") {
  print(DBI::dbGetQuery(con, "SELECT username, disabled, created_at, last_login FROM admin_users ORDER BY username"))
} else if (cmd %in% c("add", "disable", "enable") && grepl("^[A-Za-z0-9._-]{3,32}$", username)) {
  if (cmd == "add") {
    password <- readLines(file("stdin"), n = 1, warn = FALSE)
    if (length(password) == 0 || nchar(password) < MIN_PASSWORD) {
      stop("Password must have at least ", MIN_PASSWORD, " characters.", call. = FALSE)
    }
    set_admin_password(con, username, password)
  } else {
    n <- DBI::dbExecute(con, "UPDATE admin_users SET disabled = ? WHERE username = ?",
                        params = list(as.integer(cmd == "disable"), username))
    if (n == 0) stop("No such user: ", username, call. = FALSE)
  }
  audit_log(con, "(servidor)", paste("user", cmd), username)
  message("OK: ", cmd, " ", username)
} else {
  stop("Usage: manage_users.R list | add <user> | disable <user> | enable <user>\n",
       "       (user: 3-32 chars, letters, digits, . _ -)", call. = FALSE)
}

DBI::dbDisconnect(con)
