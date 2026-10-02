events <- function() DBI::dbGetQuery(.telemetry$con, "SELECT * FROM events ORDER BY rowid")

test_that("log_event stores type, session, process and a JSON detail", {
  local_state()
  log_event("abc12345", "upload", n_files = 3L, note = "it's \"quoted\"; DROP TABLE events")

  e <- events()
  expect_equal(nrow(e), 1)
  expect_equal(e$type, "upload")
  expect_equal(e$sid, "abc12345")
  expect_match(e$proc, paste0("^", Sys.getpid(), "-[0-9]+$"))
  detail <- jsonlite::fromJSON(e$detail)
  expect_equal(detail$n_files, 3)
  expect_equal(detail$note, "it's \"quoted\"; DROP TABLE events")  # parameterised: stored verbatim
})

test_that("telemetry is a silent no-op when there is no state directory", {
  withr::local_envvar(MICROARRAI_STATE_DIR = file.path(tempdir(), "no-state-here"))
  reset_telemetry()
  on.exit(reset_telemetry())
  expect_no_error(log_event("abc", "action", input = "x"))
  expect_no_error(start_metrics_sampler())
  expect_true(.telemetry$off)
})

test_that("a user session records start, uploads, heavy actions, tabs and end", {
  local_state()
  server <- function(input, output, session) telemetry_attach(input, session)

  testServer(server, {
    session$setInputs(raw_files = data.frame(name = c("a.csv", "b.csv"), size = c(1, 2) * 1024^2,
                                             datapath = c("x", "y")))
    session$setInputs(ml_run_pipeline = 1)
    session$setInputs(nav_target = "Machine Learning")
    expect_equal(.telemetry$sessions, 1L)
    session$close()
  })

  e <- events()
  expect_equal(e$type, c("session_start", "upload", "action", "tab", "session_end"))
  expect_length(unique(e$sid), 1)
  upload <- jsonlite::fromJSON(e$detail[2])
  expect_equal(upload[c("input", "n_files", "mb")], list(input = "raw_files", n_files = 2L, mb = 3))
  expect_equal(jsonlite::fromJSON(e$detail[3])$input, "ml_run_pipeline")
  expect_equal(.telemetry$sessions, 0L)

  # The memory sampler wrote its first sample when the session started
  m <- DBI::dbGetQuery(.telemetry$con, "SELECT * FROM metrics")
  expect_equal(nrow(m), 1)
  expect_equal(m$sessions, 1)
})

test_that("the session id is a short hash, not the Shiny session token", {
  local_state()
  testServer(function(input, output, session) telemetry_attach(input, session), {
    sid <- events()$sid[1]
    expect_match(sid, "^[0-9a-f]{8}$")
    expect_false(grepl(sid, session$token, fixed = TRUE))
  })
})
