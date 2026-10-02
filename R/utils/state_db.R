# =============================================================================
# STATE DATABASE (shared by the main app and the admin panel)
# =============================================================================
# One SQLite file outside the app directory, so it is never served over HTTP
# and survives image rebuilds: the deploy script bind-mounts ./state on the
# host to /var/lib/microarrai. Override with MICROARRAI_STATE_DIR (local dev).
#
# Tables
#   events          one row per user action (session, upload, ML run, ...)
#   metrics         memory samples of each R process (crash forensics)
#   admin_users     admin accounts, password = bcrypt_pbkdf(salt) hash
#   login_attempts  every admin login try (lockout + audit)
#   audit           actions taken in the admin panel
#
# `proc` is "<pid>-<start epoch>": PIDs restart at 1 in every container, so
# the start time keeps processes from different runs apart.
# =============================================================================

state_dir <- function() Sys.getenv("MICROARRAI_STATE_DIR", "/var/lib/microarrai")

STATE_SCHEMA <- c(
  "CREATE TABLE IF NOT EXISTS events (ts TEXT, sid TEXT, proc TEXT, type TEXT, detail TEXT)",
  "CREATE INDEX IF NOT EXISTS events_ts ON events (ts)",
  "CREATE TABLE IF NOT EXISTS metrics (ts TEXT, proc TEXT, rss_mb REAL, sessions INTEGER)",
  "CREATE INDEX IF NOT EXISTS metrics_ts ON metrics (ts)",
  "CREATE TABLE IF NOT EXISTS admin_users (username TEXT PRIMARY KEY, salt TEXT, hash TEXT,
     rounds INTEGER, disabled INTEGER DEFAULT 0, created_at TEXT, last_login TEXT)",
  "CREATE TABLE IF NOT EXISTS login_attempts (ts TEXT, username TEXT, ip TEXT, ok INTEGER)",
  "CREATE TABLE IF NOT EXISTS audit (ts TEXT, username TEXT, action TEXT, detail TEXT)"
)

#' Open the state database, creating it on first use
#'
#' @return A DBI connection, or NULL when the state directory is missing or
#'   not writable (callers then simply skip persistence).
state_db_connect <- function() {
  dir <- state_dir()
  if (!dir.exists(dir) || file.access(dir, 2) != 0) return(NULL)
  con <- DBI::dbConnect(RSQLite::SQLite(), file.path(dir, "microarrai.sqlite"))
  # WAL: the admin panel reads while the app writes; busy_timeout waits for a
  # competing writer instead of failing at once.
  DBI::dbExecute(con, "PRAGMA journal_mode = WAL")
  DBI::dbExecute(con, "PRAGMA busy_timeout = 5000")
  for (sql in STATE_SCHEMA) DBI::dbExecute(con, sql)
  con
}

now_utc <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
