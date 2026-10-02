# Functional tests: the real admin app server driven through shiny::testServer

html <- function(x) as.character(x$html)

admin_app <- function() {
  withr::local_dir(file.path(repo, "admin"))  # app.R sources paths relative to itself
  shiny::shinyAppDir(".")
}

test_that("nothing of the panel is served before login", {
  dirs <- local_state()
  con <- state_db_connect()
  set_admin_password(con, "ana", "correct horse battery")
  DBI::dbDisconnect(con)

  quiet_mock(testServer(admin_app(), {
    expect_match(html(output$root), "Contraseña")
    expect_no_match(html(output$root), "Resumen")
    # A client that injects the outputs without logging in gets nothing
    expect_error(output[["overview-kpis"]])
    expect_error(output[["audit-attempts"]])
    session$close()  # closes the panel's DB connection
  }))
})

test_that("login, wrong password, logout and audit trail", {
  local_state()
  con <- state_db_connect()
  set_admin_password(con, "ana", "correct horse battery")
  DBI::dbDisconnect(con)

  quiet_mock(testServer(admin_app(), {
    session$setInputs(user = "ana", pass = "nope", login = 1)
    expect_match(html(output$login_msg), "incorrectos")
    expect_match(html(output$root), "Contraseña")

    session$setInputs(pass = "correct horse battery", login = 2)
    expect_match(html(output$root), "Resumen")
    expect_match(html(output[["overview-kpis"]]), "Caídas")
    expect_match(html(output[["system-config"]]), "Base de datos")

    session$setInputs(logout = 1)
    expect_match(html(output$root), "Contraseña")
    session$close()  # closes the panel's DB connection
  }))

  con <- state_db_connect()
  on.exit(DBI::dbDisconnect(con))
  expect_equal(DBI::dbGetQuery(con, "SELECT action FROM audit ORDER BY rowid")$action, c("login", "logout"))
  expect_equal(DBI::dbGetQuery(con, "SELECT ok FROM login_attempts ORDER BY rowid")$ok, c(0, 1))
})

test_that("the login screen locks after five failures", {
  local_state()
  con <- state_db_connect()
  set_admin_password(con, "ana", "correct horse battery")
  DBI::dbDisconnect(con)

  quiet_mock(testServer(admin_app(), {
    for (i in 1:5) session$setInputs(user = "ana", pass = "guess", login = i)
    session$setInputs(pass = "correct horse battery", login = 6)
    expect_match(html(output$login_msg), "Demasiados intentos")
    expect_match(html(output$root), "Contraseña")
    session$close()  # closes the panel's DB connection
  }))
})

test_that("idle logout closes the session", {
  local_state()
  con <- state_db_connect()
  set_admin_password(con, "ana", "correct horse battery")
  DBI::dbDisconnect(con)

  quiet_mock(testServer(admin_app(), {
    session$setInputs(user = "ana", pass = "correct horse battery", login = 1)
    session$setInputs(idle_logout = 1)
    expect_match(html(output$root), "Contraseña")
    session$close()  # closes the panel's DB connection
  }))
})

test_that("the panel explains itself when the state directory is missing", {
  withr::local_envvar(MICROARRAI_STATE_DIR = file.path(tempdir(), "missing-state"))
  quiet_mock(testServer(admin_app(), {
    expect_match(html(output$root), "Base de datos no disponible")
    session$close()  # closes the panel's DB connection
  }))
})

test_that("the overview shows a crash and what the process was doing", {
  con <- local_db()
  set_admin_password(con, "ana", "correct horse battery")
  t <- utc(Sys.time() - 120)
  DBI::dbExecute(con, "INSERT INTO metrics VALUES (?, '4242-1000', 5900, 2)", params = list(t))
  DBI::dbExecute(con, "INSERT INTO events VALUES (?, 'abcd1234', '4242-1000', 'action', '{\"input\":\"ml_run_pipeline\"}')",
                 params = list(t))

  quiet_mock(testServer(admin_app(), {
    session$setInputs(user = "ana", pass = "correct horse battery", login = 1)
    expect_match(html(output[["overview-kpis"]]), "Caídas · 7 días")
    session$setInputs(`overview-crashes_rows_selected` = 1)
    expect_match(html(output[["overview-crash_detail"]]), "ml_run_pipeline")
    session$close()  # closes the panel's DB connection
  }))
})
