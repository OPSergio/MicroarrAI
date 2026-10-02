# Loaded by testthat before every test file. Sources the code under test and
# gives each test its own throw-away state + log directories, so the suite runs
# anywhere with R (no Singularity, no /var/lib, no running Shiny Server).

library(shiny)

repo <- normalizePath(file.path(testthat::test_path(), "..", ".."))
source(file.path(repo, "R", "utils", "state_db.R"), encoding = "UTF-8")
source(file.path(repo, "R", "utils", "telemetry.R"), encoding = "UTF-8")
for (f in list.files(file.path(repo, "admin", "modules"), pattern = "\\.R$", full.names = TRUE)) {
  source(f, encoding = "UTF-8")
}

# Telemetry caches one connection per process; start every test clean
reset_telemetry <- function() {
  if (!is.null(.telemetry$con)) DBI::dbDisconnect(.telemetry$con)
  .telemetry$con <- NULL
  .telemetry$off <- NULL
  .telemetry$sampling <- NULL
  .telemetry$sessions <- 0L
}

#' Point the app at fresh temp directories for the rest of the calling test
local_state <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  dirs <- list(state = file.path(root, "state"), logs = file.path(root, "logs"))
  lapply(dirs, dir.create)
  withr::local_envvar(MICROARRAI_STATE_DIR = dirs$state, MICROARRAI_LOG_DIR = dirs$logs,
                      .local_envir = env)
  reset_telemetry()
  # Deferred calls run last-in-first-out: close SQLite before the dir is deleted
  withr::defer(reset_telemetry(), envir = env)
  dirs
}

#' A state DB connection closed automatically at the end of the calling test
local_db <- function(env = parent.frame()) {
  local_state(env)
  con <- state_db_connect()
  withr::defer(DBI::dbDisconnect(con), envir = env)
  con
}

# Binary writes: no CRLF translation on Windows, like a Linux log file
write_log <- function(path, text, append = FALSE) {
  con <- file(path, if (append) "ab" else "wb")
  on.exit(close(con))
  writeBin(charToRaw(text), con)
}

utc <- function(t) format(t, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

# MockShinySession warns every time session$request is read (client_ip does);
# silence only that message so real warnings still show
quiet_mock <- function(expr) {
  withCallingHandlers(expr, warning = function(w) {
    if (grepl("realistic request", conditionMessage(w))) invokeRestart("muffleWarning")
  })
}
