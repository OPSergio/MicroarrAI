# =============================================================================
# ADMIN — Auditoría: accounts, login attempts and panel actions
# =============================================================================

audit_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(col_widths = c(4, 8),
      card(card_header("Administradores",
                       span(class = "card__sub", "se gestionan con singularity-deploy.sh users")),
           DT::DTOutput(ns("users"))),
      card(card_header("Intentos de acceso"), DT::DTOutput(ns("attempts")))),
    card(card_header("Acciones en el panel"), DT::DTOutput(ns("audit")))
  )
}

audit_server <- function(id, con, authed) moduleServer(id, function(input, output, session) {
  tick <- reactive({ req(authed()); invalidateLater(30000); Sys.time() })
  when <- function(ts) ifelse(is.na(ts), "—", substr(sub("T", " ", ts), 1, 16))

  output$users <- DT::renderDT({
    tick()
    u <- DBI::dbGetQuery(con, "SELECT username, disabled, last_login FROM admin_users ORDER BY username")
    admin_table(data.frame(Usuario = u$username, Estado = ifelse(u$disabled == 1, "desactivado", "activo"),
                           `Último acceso` = when(u$last_login), check.names = FALSE))
  })

  output$attempts <- DT::renderDT({
    tick()
    a <- DBI::dbGetQuery(con, "SELECT * FROM login_attempts ORDER BY ts DESC LIMIT 200")
    admin_table(data.frame(Fecha = when(a$ts), Usuario = a$username, IP = a$ip,
                           Resultado = ifelse(a$ok == 1, "OK", "Fallido")))
  })

  output$audit <- DT::renderDT({
    tick()
    a <- DBI::dbGetQuery(con, "SELECT * FROM audit ORDER BY ts DESC LIMIT 200")
    admin_table(data.frame(Fecha = when(a$ts), Usuario = a$username, Acción = a$action, Detalle = a$detail))
  })
})
