test_that("read_from returns only what was appended since the last read", {
  f <- withr::local_tempfile()
  write_log(f, "one\n")
  r1 <- read_from(f, 0)
  expect_equal(r1$text, "one\n")

  write_log(f, "two\nthr", append = TRUE)
  r2 <- read_from(f, r1$offset)
  expect_equal(r2$text, "two\nthr")
  expect_false(r2$reset)

  expect_equal(read_from(f, r2$offset)$text, "")  # nothing new
})

test_that("read_from starts over when the file shrinks (rotated or truncated)", {
  f <- withr::local_tempfile()
  write_log(f, "a long first version\n")
  r1 <- read_from(f, 0)
  write_log(f, "new\n")
  r2 <- read_from(f, r1$offset)
  expect_true(r2$reset)
  expect_equal(r2$text, "new\n")
})

test_that("log_errors groups R errors by message and ignores other lines", {
  dirs <- local_state()
  write_log(file.path(dirs$logs, "MicroarrAI-shiny-1.log"), paste0(
    "Listening on http://127.0.0.1:41022\n",
    "Warning: Error in detect_array_header: no 'ID' column in the first 200 lines.\n",
    "  115: detect_array_header\n",
    "Error in foo(): bar\n",
    "Warning: Error in detect_array_header: no 'ID' column in the first 300 lines.\n",
    "Warning in normalizePath(\"~\") :\n"))

  e <- log_errors()
  expect_equal(nrow(e), 2)
  expect_equal(e$Veces, c(2L, 1L))
  expect_match(e$Error[1], "detect_array_header: no 'ID' column in the first # lines")
})

test_that("list_logs lists only .log files, newest first", {
  dirs <- local_state()
  write_log(file.path(dirs$logs, "old.log"), "x\n")
  Sys.setFileTime(file.path(dirs$logs, "old.log"), Sys.time() - 3600)
  write_log(file.path(dirs$logs, "new.log"), "x\n")
  write_log(file.path(dirs$logs, "notes.txt"), "x\n")

  expect_equal(list_logs()$name, c("new.log", "old.log"))
})

test_that("a process that died with users connected is a crash; an idle exit is not", {
  con <- local_db()
  now <- Sys.time()
  sample <- function(proc, sessions, rss, ago_s = 60) {
    DBI::dbExecute(con, "INSERT INTO metrics VALUES (?, ?, ?, ?)",
                   params = list(utc(now - ago_s), proc, rss, sessions))
  }
  sample("111-1000", 2, 5800)                          # died with 2 users -> crash
  sample("111-1000", 1, 6100, ago_s = 30)              # ... its last sample wins
  sample("222-1000", 0, 300)                           # idle shutdown -> normal
  sample(paste0("333-", as.integer(now)), 1, 500)      # still running
  sample("333-1000", 1, 400)                           # same PID, older run -> dead

  running <- data.frame(pid = 333L, app = "MicroarrAI", rss_mb = 500, start = now)
  s <- process_summary(con, running)
  crashed <- s$proc[s$crashed]

  expect_setequal(crashed, c("111-1000", "333-1000"))
  expect_equal(s$rss_mb[s$proc == "111-1000"], 6100)
  expect_equal(s$peak_mb[s$proc == "111-1000"], 6100)
  expect_true(s$alive[s$proc == paste0("333-", as.integer(now))])
})

test_that("system readers degrade to NA instead of failing without /proc", {
  expect_no_error(m <- memory_status())
  expect_named(m, c("used_mb", "limit_mb", "peak_mb", "oom_kills", "host_total_mb", "host_avail_mb"))
  expect_no_error(cpu_status())
  expect_s3_class(r_processes(), "data.frame")
})
