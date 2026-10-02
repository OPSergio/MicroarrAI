test_that("the state database is created with every table, in WAL mode", {
  dirs <- local_state()
  con <- state_db_connect()
  on.exit(DBI::dbDisconnect(con))

  expect_true(file.exists(file.path(dirs$state, "microarrai.sqlite")))
  expect_setequal(DBI::dbListTables(con),
                  c("events", "metrics", "admin_users", "login_attempts", "audit"))
  expect_equal(DBI::dbGetQuery(con, "PRAGMA journal_mode")[[1]], "wal")
})

test_that("opening it twice keeps the data (schema creation is idempotent)", {
  con <- local_db()
  DBI::dbExecute(con, "INSERT INTO audit VALUES ('t', 'u', 'a', 'd')")
  con2 <- state_db_connect()
  on.exit(DBI::dbDisconnect(con2))
  expect_equal(DBI::dbGetQuery(con2, "SELECT COUNT(*) AS n FROM audit")$n, 1)
})

test_that("without a state directory it returns NULL instead of failing", {
  withr::local_envvar(MICROARRAI_STATE_DIR = file.path(tempdir(), "does-not-exist"))
  expect_null(state_db_connect())
})
