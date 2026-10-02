# Functional test of the live log tail: what actually goes down the websocket.
# MockShinySession's clock (session$elapse) drives invalidateLater(1000).

capture_session <- function() {
  sent <- new.env()
  sent$msgs <- list()
  s <- MockShinySession$new()
  s$sendCustomMessage <- function(type, message) {
    if (type == "log_lines") sent$msgs[[length(sent$msgs) + 1]] <- message
  }
  list(session = s, sent = sent)
}

test_that("opening a log sends its tail, then only the new lines every second", {
  dirs <- local_state()
  f <- file.path(dirs$logs, "MicroarrAI-shiny-1.log")
  write_log(f, "Listening on http://127.0.0.1:41022\nWarning: Error in foo: bar\n")
  cap <- capture_session()

  testServer(logs_server, args = list(authed = reactive(TRUE), visible = reactive(TRUE)),
             session = cap$session, {
    session$setInputs(follow = TRUE, file = "MicroarrAI-shiny-1.log")

    first <- cap$sent$msgs[[1]]
    expect_true(first$reset)
    expect_equal(unlist(first$lines), c("Listening on http://127.0.0.1:41022", "Warning: Error in foo: bar"))

    # A line written in two chunks is only sent once it is complete
    write_log(f, "[telemetry] upload ab", append = TRUE)
    session$elapse(1000)
    sent_lines <- unlist(lapply(cap$sent$msgs[-1], `[[`, "lines"))
    expect_false(any(grepl("telemetry", sent_lines)))

    write_log(f, "cd {}\n", append = TRUE)
    session$elapse(1000)
    last <- cap$sent$msgs[[length(cap$sent$msgs)]]
    expect_false(last$reset)
    expect_equal(unlist(last$lines), "[telemetry] upload abcd {}")
  })
})

test_that("nothing is polled while 'Seguir' is off or the browser tab is hidden", {
  dirs <- local_state()
  f <- file.path(dirs$logs, "a.log")
  write_log(f, "x\n")
  visible <- reactiveVal(TRUE)
  cap <- capture_session()

  testServer(logs_server, args = list(authed = reactive(TRUE), visible = visible),
             session = cap$session, {
    session$setInputs(follow = FALSE, file = "a.log")
    n <- length(cap$sent$msgs)
    write_log(f, "y\n", append = TRUE)
    session$elapse(3000)
    expect_length(cap$sent$msgs, n)

    visible(FALSE)
    session$setInputs(follow = TRUE)
    session$elapse(3000)
    expect_length(cap$sent$msgs, n)

    visible(TRUE)
    session$elapse(1000)
    expect_equal(unlist(cap$sent$msgs[[length(cap$sent$msgs)]]$lines), "y")
  })
})

test_that("a file name outside the log listing is refused", {
  dirs <- local_state()
  write_log(file.path(dirs$logs, "a.log"), "x\n")
  write_log(file.path(dirs$state, "secret.log"), "do not show\n")
  cap <- capture_session()

  testServer(logs_server, args = list(authed = reactive(TRUE), visible = reactive(TRUE)),
             session = cap$session, {
    session$setInputs(follow = TRUE, file = "../state/secret.log")
    session$elapse(2000)
    expect_length(cap$sent$msgs, 0)
  })
})

test_that("the log tab sends nothing before login", {
  dirs <- local_state()
  write_log(file.path(dirs$logs, "a.log"), "x\n")
  cap <- capture_session()

  testServer(logs_server, args = list(authed = reactive(FALSE), visible = reactive(TRUE)),
             session = cap$session, {
    session$setInputs(follow = TRUE, file = "a.log")
    session$elapse(2000)
    expect_length(cap$sent$msgs, 0)
  })
})
