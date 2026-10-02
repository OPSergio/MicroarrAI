test_that("the right password logs in and a wrong one does not", {
  con <- local_db()
  set_admin_password(con, "ana", "correct horse battery")

  expect_equal(check_login(con, "ana", "correct horse battery", "10.0.0.1"), "ok")
  expect_equal(check_login(con, "ana", "Correct horse battery", "10.0.0.1"), "bad")
  expect_equal(check_login(con, "nobody", "correct horse battery", "10.0.0.1"), "bad")

  a <- DBI::dbGetQuery(con, "SELECT * FROM login_attempts ORDER BY rowid")
  expect_equal(a$ok, c(1, 0, 0))
  expect_false(is.na(DBI::dbGetQuery(con, "SELECT last_login FROM admin_users")$last_login))
})

test_that("passwords are stored as salted hashes, never in clear", {
  con <- local_db()
  set_admin_password(con, "ana", "same password 123")
  set_admin_password(con, "val", "same password 123")
  u <- DBI::dbGetQuery(con, "SELECT * FROM admin_users ORDER BY username")

  expect_false(any(grepl("same password", unlist(u))))
  expect_false(u$salt[1] == u$salt[2])
  expect_false(u$hash[1] == u$hash[2])  # same password, different hash
})

test_that("resetting a password replaces the old one", {
  con <- local_db()
  set_admin_password(con, "ana", "first password 1")
  set_admin_password(con, "ana", "second password 2")
  expect_equal(check_login(con, "ana", "first password 1", ""), "bad")
  expect_equal(check_login(con, "ana", "second password 2", ""), "ok")
})

test_that("five failures lock the account, even for the right password", {
  con <- local_db()
  set_admin_password(con, "ana", "correct horse battery")
  for (i in 1:5) check_login(con, "ana", "guess", "10.0.0.1")

  expect_equal(check_login(con, "ana", "correct horse battery", "10.0.0.2"), "locked")
})

test_that("an IP that keeps failing is locked out for every username", {
  con <- local_db()
  set_admin_password(con, "ana", "correct horse battery")
  for (u in c("a", "b", "c", "d", "e")) check_login(con, u, "guess", "203.0.113.9")

  expect_equal(check_login(con, "ana", "correct horse battery", "203.0.113.9"), "locked")
  expect_equal(check_login(con, "ana", "correct horse battery", "10.0.0.1"), "ok")
})

test_that("failures older than the lockout window don't count", {
  con <- local_db()
  set_admin_password(con, "ana", "correct horse battery")
  old <- utc(Sys.time() - (LOCKOUT_MINUTES + 1) * 60)
  for (i in 1:5) DBI::dbExecute(con, "INSERT INTO login_attempts VALUES (?, 'ana', '', 0)", params = list(old))

  expect_equal(check_login(con, "ana", "correct horse battery", ""), "ok")
})

test_that("disabled accounts cannot log in", {
  con <- local_db()
  set_admin_password(con, "ana", "correct horse battery")
  DBI::dbExecute(con, "UPDATE admin_users SET disabled = 1 WHERE username = 'ana'")
  expect_equal(check_login(con, "ana", "correct horse battery", ""), "bad")
})
