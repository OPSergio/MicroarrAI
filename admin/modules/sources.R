# =============================================================================
# ADMIN DATA SOURCES — read-only helpers over logs, /proc, cgroups and the DB
# =============================================================================
# Every reader degrades to NA / empty instead of failing, so the panel still
# loads on a machine without /proc (local dev on Windows) or without cgroups.
# =============================================================================

log_dir <- function() Sys.getenv("MICROARRAI_LOG_DIR", "/var/log/shiny-server")

or_na <- function(x) if (length(x)) x[1] else NA_real_
first_line <- function(path) c(read_lines(path), "")[1]  # "" when missing
read_lines <- function(path) if (file.exists(path)) readLines(path, warn = FALSE) else character()
read_num <- function(path) or_na(suppressWarnings(as.numeric(read_lines(path)[1])))
fmt_mb <- function(mb) ifelse(is.na(mb), "—", ifelse(mb >= 1024, sprintf("%.1f GB", mb / 1024), sprintf("%.0f MB", mb)))
ago <- function(ts) {
  s <- as.numeric(difftime(Sys.time(), as.POSIXct(ts, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), units = "secs"))
  ifelse(s < 120, sprintf("hace %.0f s", s), ifelse(s < 7200, sprintf("hace %.0f min", s / 60), sprintf("hace %.1f h", s / 3600)))
}

# ---- logs -------------------------------------------------------------------

list_logs <- function() {
  f <- list.files(log_dir(), pattern = "\\.log$", full.names = TRUE)
  i <- file.info(f)
  d <- data.frame(name = basename(f), size = i$size, mtime = i$mtime)
  d[order(d$mtime, decreasing = TRUE), , drop = FALSE]
}

#' Bytes appended to `path` since byte `offset`
#' @return list(text, offset = new offset, reset = TRUE if the file shrank)
read_from <- function(path, offset) {
  size <- file.size(path)
  if (is.na(size)) return(list(text = "", offset = 0, reset = TRUE))
  reset <- offset > size
  if (reset) offset <- 0
  if (size == offset) return(list(text = "", offset = offset, reset = reset))
  con <- file(path, "rb")
  on.exit(close(con))
  seek(con, offset)
  text <- rawToChar(readBin(con, "raw", size - offset))
  Encoding(text) <- "UTF-8"
  list(text = text, offset = size, reset = reset)
}

#' R errors in recently written logs, grouped by message (numbers -> #)
log_errors <- function(hours = 24, max_bytes = 2 * 1024^2) {
  d <- list_logs()
  d <- d[d$mtime > Sys.time() - hours * 3600, , drop = FALSE]
  lines <- unlist(lapply(file.path(log_dir(), d$name), function(p) {
    strsplit(read_from(p, max(0, file.size(p) - max_bytes))$text, "\n", fixed = TRUE)[[1]]
  }))
  err <- sub("^Warning: ", "", grep("^(Warning: )?Error in ", lines, value = TRUE))
  if (!length(err)) return(data.frame(Error = character(), Veces = integer()))
  tab <- sort(table(gsub("[0-9]+", "#", err)), decreasing = TRUE)
  data.frame(Error = names(tab), Veces = as.integer(tab))
}

# ---- memory, CPU, disk ------------------------------------------------------

# cgroup v2 directory of this process (the instance's limits live there)
cgroup_dir <- function() {
  l <- grep("^0::", read_lines("/proc/self/cgroup"), value = TRUE)
  if (!length(l)) return(NA_character_)
  file.path("/sys/fs/cgroup", sub("^0::/?", "", l))
}

memory_status <- function() {
  cg <- cgroup_dir()
  cgf <- function(f) if (is.na(cg)) NA_real_ else read_num(file.path(cg, f))
  events <- if (is.na(cg)) character() else read_lines(file.path(cg, "memory.events"))
  meminfo <- read_lines("/proc/meminfo")
  kb <- function(k) or_na(as.numeric(gsub("\\D", "", grep(paste0("^", k, ":"), meminfo, value = TRUE)))) / 1024
  list(
    used_mb   = cgf("memory.current") / 1024^2,
    limit_mb  = cgf("memory.max") / 1024^2,        # NA when "max" (no limit)
    peak_mb   = cgf("memory.peak") / 1024^2,       # kernel >= 5.19 only
    oom_kills = or_na(as.numeric(sub("oom_kill ", "", grep("^oom_kill ", events, value = TRUE)))),
    host_total_mb = kb("MemTotal"),
    host_avail_mb = kb("MemAvailable")
  )
}

cpu_status <- function() {
  cg <- cgroup_dir()
  quota <- if (is.na(cg)) character() else strsplit(read_lines(file.path(cg, "cpu.max"))[1], " ")[[1]]
  load <- strsplit(first_line("/proc/loadavg"), " ")[[1]]
  list(
    limit_cores = if (length(quota) == 2 && quota[1] != "max") as.numeric(quota[1]) / as.numeric(quota[2]) else NA,
    host_cores  = parallel::detectCores(),
    load        = if (length(load) >= 3) paste(load[1:3], collapse = " / ") else "—"
  )
}

disk_status <- function(path) {
  out <- tryCatch(system2("df", c("-Pk", path), stdout = TRUE, stderr = FALSE), error = function(e) character())
  f <- if (length(out) >= 2) strsplit(out[2], "\\s+")[[1]] else character()
  if (length(f) < 4) return(list(used_mb = NA, avail_mb = NA))
  list(used_mb = as.numeric(f[3]) / 1024, avail_mb = as.numeric(f[4]) / 1024)
}

# ---- R processes started by Shiny Server ---------------------------------------

r_processes <- function() {
  btime <- as.numeric(sub("btime ", "", grep("^btime ", read_lines("/proc/stat"), value = TRUE)))
  rows <- lapply(list.files("/proc", pattern = "^[0-9]+$"), function(pid) {
    cmd <- tryCatch(readBin(file.path("/proc", pid, "cmdline"), "raw", 4096), error = function(e) raw())
    cmd[cmd == as.raw(0)] <- as.raw(32)
    if (!grepl("SockJSAdapter", rawToChar(cmd))) return(NULL)  # Shiny Server's R worker
    stat <- strsplit(sub(".*\\) ", "", first_line(file.path("/proc", pid, "stat"))), " ")[[1]]
    rss <- grep("^VmRSS:", read_lines(file.path("/proc", pid, "status")), value = TRUE)
    data.frame(
      pid    = as.integer(pid),
      app    = basename(Sys.readlink(file.path("/proc", pid, "cwd"))),
      rss_mb = or_na(as.numeric(gsub("\\D", "", rss))) / 1024,
      start  = as.POSIXct(btime + as.numeric(stat[20]) / 100, origin = "1970-01-01")  # CLK_TCK = 100
    )
  })
  do.call(rbind, c(rows, list(data.frame(pid = integer(), app = character(), rss_mb = numeric(),
                                         start = as.POSIXct(character())))))
}

# Telemetry stamps a process as "<pid>-<epoch>" a few seconds after it starts
# (while packages load), so match the PID plus a generous start-time window.
proc_alive <- function(proc, procs) {
  pid <- as.integer(sub("-.*", "", proc))
  epoch <- as.numeric(sub(".*-", "", proc))
  vapply(seq_along(proc), function(i) {
    any(procs$pid == pid[i] & abs(as.numeric(procs$start) - epoch[i]) < 300)
  }, logical(1))
}

# ---- telemetry (state database) ---------------------------------------------

since_utc <- function(hours) format(Sys.time() - hours * 3600, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

#' Last memory sample of every app process in the window, with its peak
process_summary <- function(con, procs, hours = 24 * 7) {
  d <- DBI::dbGetQuery(con,
    "SELECT m.proc, m.ts AS last_ts, m.sessions, m.rss_mb, p.peak_mb
     FROM metrics m JOIN (SELECT proc, MAX(ts) AS ts, MAX(rss_mb) AS peak_mb
                          FROM metrics WHERE ts > ? GROUP BY proc) p
       ON m.proc = p.proc AND m.ts = p.ts",
    params = list(since_utc(hours)))
  d$alive <- proc_alive(d$proc, procs)
  # Died with users connected = crash. Idle exits (0 sessions) are normal.
  d$crashed <- !d$alive & d$sessions > 0
  d
}

last_events <- function(con, proc = NULL, n = 20) {
  if (is.null(proc)) {
    DBI::dbGetQuery(con, "SELECT * FROM events ORDER BY ts DESC LIMIT ?", params = list(n))
  } else {
    DBI::dbGetQuery(con, "SELECT * FROM events WHERE proc = ? ORDER BY ts DESC LIMIT ?",
                    params = list(proc, n))
  }
}

today_counts <- function(con) {
  DBI::dbGetQuery(con,
    "SELECT type, COUNT(*) AS n FROM events WHERE ts >= ? GROUP BY type",
    params = list(format(Sys.time(), "%Y-%m-%dT00:00:00Z", tz = "UTC")))
}

# ---- health & image -----------------------------------------------------------

app_health <- function(url = Sys.getenv("MICROARRAI_HEALTH_URL", "http://127.0.0.1:3838/MicroarrAI/")) {
  t0 <- Sys.time()
  r <- tryCatch(curl::curl_fetch_memory(url, handle = curl::new_handle(timeout = 10)),
                error = function(e) NULL)
  list(ok = !is.null(r) && r$status_code == 200,
       ms = round(as.numeric(difftime(Sys.time(), t0, units = "secs")) * 1000))
}

image_info <- function() {
  f <- "/.singularity.d/labels.json"
  l <- if (file.exists(f)) jsonlite::fromJSON(f) else list()
  list(build_date = c(l[["org.label-schema.build-date"]], "—")[1],
       version = c(l[["Version"]], "—")[1])
}
