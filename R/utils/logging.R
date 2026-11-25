# =============================================================================
# STEP LOG: one line per thing the app is asked to do, did, or failed to do
# =============================================================================
#   2026-11-24 10:12:03 INFO  [a1b2c3d4] NORMALIZE | START normalising 120 arrays | neg=PBS_1X, inter=robust
#   2026-11-24 10:12:09 INFO  [a1b2c3d4] NORMALIZE | DONE in 6.1 s | samples=120, features=514
#   2026-11-24 10:15:40 ERROR [a1b2c3d4] ML        | FAILED training | why=..., hint=...
#
# Lines go to stderr (the Shiny Server log the admin panel tails), tagged with
# the session id that the "[telemetry]" lines use, so one user's run can be
# followed from upload to report. Patient data never appear: only counts,
# names of settings and of the user's columns.
# =============================================================================

#' Session id of the current user (the one telemetry logs), "--------" outside a session
log_sid <- function(session = shiny::getDefaultReactiveDomain()) {
  sid <- if (!is.null(session)) session$userData$sid
  if (is.null(sid)) "--------" else sid
}

# Compact value for a detail: long vectors are counted, numbers rounded
log_value <- function(v) {
  if (is.null(v) || length(v) == 0) return("none")
  if (is.numeric(v)) v <- signif(v, 4)
  v <- as.character(v)
  sep <- if (any(grepl(" ", v))) "; " else "/"   # phrases need a clearer separator than names
  if (length(v) > 6) paste0(paste(utils::head(v, 5), collapse = sep), sep, "… (", length(v), ")") else paste(v, collapse = sep)
}

#' Write one step line. Named extra arguments become "key=value" details.
log_step <- function(step, msg, ..., level = "INFO") {
  d <- list(...)
  d <- d[!vapply(d, is.null, logical(1))]
  details <- if (length(d)) paste0(" | ", paste(names(d), vapply(d, log_value, ""), sep = "=", collapse = ", ")) else ""
  message(sprintf("%s %-5s [%s] %-9s | %s%s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                  level, log_sid(), toupper(step), msg, details))
}

#' Run one step of the pipeline with its own START / DONE / FAILED lines
#'
#' Warnings raised inside are logged with the step name. An error is logged
#' with what was asked, why it failed and what the user can do, shown to the
#' user as a notification, and turned into NULL so the session carries on.
#' req() / validate() stops are not failures and pass through untouched.
#'
#' @param step Short pipeline stage (UPLOAD, NORMALIZE, QC, STATS, ML, ...)
#' @param request What the user asked for, in words
#' @param expr The work
#' @param ... Settings to record with the START line
#' @param hint What to try when it fails
#' @param done Function of the result returning a named list of details for the DONE line
run_step <- function(step, request, expr, ..., hint = NULL, done = NULL, notify = TRUE) {
  log_step(step, paste("START", request), ...)
  t0 <- Sys.time()
  failed <- FALSE
  seen <- list()
  res <- withCallingHandlers(
    tryCatch(expr, error = function(e) {
      if (inherits(e, c("shiny.silent.error", "validation"))) stop(e)
      failed <<- TRUE
      why <- conditionMessage(e)
      call <- conditionCall(e)
      log_step(step, paste("FAILED", request), level = "ERROR", why = why,
               where = if (!is.null(call)) deparse(call, nlines = 1)[1], hint = hint)
      if (notify && !is.null(shiny::getDefaultReactiveDomain())) {
        shiny::showNotification(paste0(request, " failed: ", why, if (!is.null(hint)) paste0(" — ", hint)),
                                type = "error", duration = 15)
      }
      NULL
    }),
    warning = function(w) {
      # First occurrence is logged; repeats (e.g. one per peptide) are counted
      msg <- conditionMessage(w)
      if (is.null(seen[[msg]])) log_step(step, paste("warning:", msg), level = "WARN")
      seen[[msg]] <<- if (is.null(seen[[msg]])) 1 else seen[[msg]] + 1
      invokeRestart("muffleWarning")
    }
  )
  for (msg in names(seen)) if (seen[[msg]] > 1) log_step(step, sprintf("warning repeated %d times: %s", seen[[msg]], msg), level = "WARN")
  if (!failed) {
    extra <- if (is.function(done)) tryCatch(done(res), error = function(e) list()) else list()
    do.call(log_step, c(list(step, sprintf("DONE %s in %.1f s", request, as.numeric(difftime(Sys.time(), t0, units = "secs")))), extra))
  }
  res
}
