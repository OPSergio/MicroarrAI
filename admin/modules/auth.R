# =============================================================================
# ADMIN AUTH — accounts in the state database, never in the image or env
# =============================================================================
# Password hash: openssl::bcrypt_pbkdf (OpenSSH's KDF) with a random 16-byte
# salt per user. `rounds` is stored per row so it can be raised later without
# invalidating existing accounts.
# =============================================================================

AUTH_ROUNDS <- 64L
LOCKOUT_FAILS <- 5L
LOCKOUT_MINUTES <- 15

hash_password <- function(password, salt, rounds = AUTH_ROUNDS) {
  key <- openssl::bcrypt_pbkdf(password, openssl::base64_decode(salt), rounds, 32L)
  openssl::base64_encode(key)
}

new_salt <- function() openssl::base64_encode(openssl::rand_bytes(16))

#' Create or replace an admin account (used by manage_users.R)
set_admin_password <- function(con, username, password) {
  salt <- new_salt()
  DBI::dbExecute(con,
    "INSERT INTO admin_users (username, salt, hash, rounds, disabled, created_at)
     VALUES (?, ?, ?, ?, 0, ?)
     ON CONFLICT(username) DO UPDATE SET salt = excluded.salt, hash = excluded.hash,
       rounds = excluded.rounds, disabled = 0",
    params = list(username, salt, hash_password(password, salt), AUTH_ROUNDS, now_utc()))
}

locked_out <- function(con, username, ip) {
  since <- format(Sys.time() - LOCKOUT_MINUTES * 60, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  n <- DBI::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM login_attempts
     WHERE ok = 0 AND ts > ? AND (username = ? OR (ip <> '' AND ip = ?))",
    params = list(since, username, ip))$n
  n >= LOCKOUT_FAILS
}

#' Check credentials and record the attempt
#'
#' @return "ok", "locked" or "bad"
check_login <- function(con, username, password, ip) {
  if (locked_out(con, username, ip)) {
    DBI::dbExecute(con, "INSERT INTO login_attempts VALUES (?, ?, ?, 0)",
                   params = list(now_utc(), username, ip))
    return("locked")
  }
  user <- DBI::dbGetQuery(con, "SELECT * FROM admin_users WHERE username = ? AND disabled = 0",
                          params = list(username))
  # Hash even for unknown users so response time doesn't reveal which exist
  salt <- if (nrow(user)) user$salt else new_salt()
  rounds <- if (nrow(user)) user$rounds else AUTH_ROUNDS
  ok <- identical(hash_password(password, salt, rounds), if (nrow(user)) user$hash else "")

  DBI::dbExecute(con, "INSERT INTO login_attempts VALUES (?, ?, ?, ?)",
                 params = list(now_utc(), username, ip, as.integer(ok)))
  if (ok) DBI::dbExecute(con, "UPDATE admin_users SET last_login = ? WHERE username = ?",
                         params = list(now_utc(), username))
  if (ok) "ok" else "bad"
}

audit_log <- function(con, username, action, detail = "") {
  DBI::dbExecute(con, "INSERT INTO audit VALUES (?, ?, ?, ?)",
                 params = list(now_utc(), username, action, detail))
}

# Best effort: Shiny Server may not forward proxy headers
client_ip <- function(session) {
  req <- session$request
  ip <- c(req$HTTP_X_FORWARDED_FOR, req$REMOTE_ADDR, "")[1]  # c() drops NULLs
  trimws(sub(",.*", "", ip))
}
