# =============================================================================
# TELEMETRY (main app -> state database, read by the admin panel)
# =============================================================================
# Records what users do (never what they upload) and samples this R process's
# memory every 30 s. Every R process serves all sessions, so when it dies the
# last samples and the last action logged are the best clue to why.
#
# Never breaks the app: without a writable state directory it only prints the
# "[telemetry]" lines to the log, and any database error is swallowed.
# =============================================================================

.telemetry <- new.env()
.telemetry$sessions <- 0L
.telemetry$proc <- paste0(Sys.getpid(), "-", as.integer(Sys.time()))

telemetry_con <- function() {
  if (is.null(.telemetry$con) && !isTRUE(.telemetry$off)) {
    .telemetry$con <- tryCatch(state_db_connect(), error = function(e) NULL)
    .telemetry$off <- is.null(.telemetry$con)
  }
  .telemetry$con
}

telemetry_write <- function(sql, params) {
  con <- telemetry_con()
  if (is.null(con)) return(invisible())
  tryCatch(DBI::dbExecute(con, sql, params = params),
           error = function(e) message("[telemetry] write failed: ", conditionMessage(e)))
  invisible()
}

#' Record one event. Extra named arguments become the JSON `detail`.
log_event <- function(sid, type, ...) {
  detail <- as.character(jsonlite::toJSON(list(...), auto_unbox = TRUE))
  # message() goes to stderr, which reaches the log file unbuffered
  message("[telemetry] ", type, " ", sid, " ", detail)
  telemetry_write("INSERT INTO events VALUES (?, ?, ?, ?, ?)",
                  list(now_utc(), sid, .telemetry$proc, type, detail))
}

# Resident memory of this process in MB (Linux only; NA elsewhere)
rss_mb <- function() {
  if (!file.exists("/proc/self/status")) return(NA_real_)
  line <- grep("^VmRSS:", readLines("/proc/self/status", warn = FALSE), value = TRUE)
  as.numeric(gsub("\\D", "", line)) / 1024
}

# One sampler per process. later() only fires while R is idle, so a gap in
# the samples means the process was busy computing, not that it died.
start_metrics_sampler <- function(every = 30) {
  if (isTRUE(.telemetry$sampling)) return(invisible())
  .telemetry$sampling <- TRUE
  tick <- function() {
    telemetry_write("INSERT INTO metrics VALUES (?, ?, ?, ?)",
                    list(now_utc(), .telemetry$proc, rss_mb(), .telemetry$sessions))
    later::later(tick, every)
  }
  tick()
}

#' Wire telemetry into one user session. Call once at the top of server().
telemetry_attach <- function(input, session) {
  sid <- substr(as.character(openssl::sha256(session$token)), 1, 8)
  started <- Sys.time()
  .telemetry$sessions <- .telemetry$sessions + 1L
  start_metrics_sampler()
  log_event(sid, "session_start", sessions = .telemetry$sessions)

  session$onSessionEnded(function() {
    .telemetry$sessions <- .telemetry$sessions - 1L
    log_event(sid, "session_end",
              minutes = round(as.numeric(difftime(Sys.time(), started, units = "mins")), 1))
  })

  # High priority: logged BEFORE the app's own observer starts the heavy work,
  # so the action that crashed the process is still on record.
  lapply(c("raw_files", "pep_fileinput", "db_fileinput", "protein_annotation"), function(id) {
    observeEvent(input[[id]], priority = 100, {
      f <- input[[id]]
      log_event(sid, "upload", input = id, n_files = nrow(f), mb = round(sum(f$size) / 1024^2, 1))
    })
  })
  lapply(c("process_button", "finish_preprocess", "run_analysis_1", "ml_run_pipeline",
           "load_example_db", "load_example_pep", "metis_reset"), function(id) {
    observeEvent(input[[id]], priority = 100, log_event(sid, "action", input = id))
  })
  observeEvent(input$nav_target, priority = 100, log_event(sid, "tab", tab = input$nav_target))
}
