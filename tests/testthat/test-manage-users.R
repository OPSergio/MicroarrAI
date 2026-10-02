# The account CLI exactly as the server runs it: a separate Rscript process
# with the password on stdin.

run_cli <- function(..., password = NULL) {
  rscript <- file.path(R.home("bin"), "Rscript")
  out <- suppressWarnings(system2(rscript, c(shQuote(file.path(repo, "admin", "manage_users.R")), ...),
                                  input = password, stdout = TRUE, stderr = TRUE))
  list(status = c(attr(out, "status"), 0L)[1], output = paste(out, collapse = "\n"))
}

test_that("add creates an account that can log in; disable blocks it", {
  local_state()
  expect_equal(run_cli("add", "ana", password = "correct horse battery")$status, 0)

  con <- state_db_connect()
  on.exit(DBI::dbDisconnect(con))
  expect_equal(check_login(con, "ana", "correct horse battery", ""), "ok")

  expect_equal(run_cli("disable", "ana")$status, 0)
  expect_equal(check_login(con, "ana", "correct horse battery", ""), "bad")
  expect_equal(run_cli("enable", "ana")$status, 0)
  expect_equal(check_login(con, "ana", "correct horse battery", ""), "ok")

  expect_equal(DBI::dbGetQuery(con, "SELECT action FROM audit ORDER BY rowid")$action,
               c("user add", "user disable", "user enable"))
})

test_that("short passwords, bad usernames and unknown users are rejected", {
  local_state()
  expect_match(run_cli("add", "ana", password = "short")$output, "at least 8")
  expect_equal(run_cli("add", "val", password = "Abcd1234")$status, 0)  # exactly 8 is fine
  expect_match(run_cli("add", "a b; rm", password = "correct horse battery")$output, "Usage")
  expect_match(run_cli("disable", "ghost")$output, "No such user")
})

test_that("list shows accounts without hashes", {
  local_state()
  run_cli("add", "ana", password = "correct horse battery")
  out <- run_cli("list")$output
  expect_match(out, "ana")
  expect_no_match(out, "hash|salt")
})
