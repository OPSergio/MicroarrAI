# =============================================================================
# MicroarrAI — Admin panel (separate Shiny app, served at /MicroarrAI/admin)
# =============================================================================
# Runs in its own R process, so it stays responsive while the main app is busy
# (e.g. training a model) and can show what happened when the main app dies.
#
# Nothing of the panel exists before login: the UI is rendered server-side and
# every module output depends on authed(), so a client that injects an output
# element without logging in receives nothing.
# =============================================================================

library(shiny)
library(bslib)

source("../R/utils/state_db.R", encoding = "UTF-8")
for (f in list.files("modules", pattern = "\\.R$", full.names = TRUE)) source(f, encoding = "UTF-8")

theme <- bs_theme(
  version = 5, bg = "#0d0f22", fg = "#eef1f8", primary = "#18BC9C",
  base_font = "Inter, system-ui, -apple-system, 'Segoe UI', sans-serif",
  "card-bg" = "#151931", "border-color" = "rgba(255,255,255,0.10)"
)

ui <- page_fluid(
  theme = theme,
  tags$head(
    tags$title("MicroarrAI Admin"),
    tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Cinzel:wght@500&family=Inter:wght@400;500;600;700&family=JetBrains+Mono&display=swap"),
    tags$link(rel = "stylesheet", href = "admin.css")
  ),
  uiOutput("root"),
  tags$script(src = "admin.js")  # after Shiny's scripts: it registers message handlers
)

login_ui <- function(no_users) {
  div(class = "login",
    div(class = "card login__card",
      div(class = "login__brand", span(class = "wordmark", "MICROARRAI"), span(class = "chip", "ADMIN")),
      uiOutput("login_msg"),
      textInput("user", "Usuario", width = "100%"),
      passwordInput("pass", "Contraseña", width = "100%"),
      actionButton("login", "Entrar", class = "btn-primary w-100"),
      if (no_users) p(class = "note mt-3", "No hay administradores todavía. Crea uno en el servidor con ",
                      tags$code("./singularity/singularity-deploy.sh users"), "."),
      p(class = "note mt-3", "La sesión se cierra tras 30 min sin actividad. Todos los accesos quedan registrados.")))
}

panel_ui <- function(user) {
  tagList(
    div(class = "topbar",
        span(class = "wordmark", "MICROARRAI"), span(class = "chip", "ADMIN"),
        div(class = "topbar__right", span(class = "pill", user),
            actionButton("logout", "Salir", class = "btn-sm btn-outline-light"))),
    navset_underline(
      nav_panel("Resumen", overview_ui("overview")),
      nav_panel("Logs", logs_ui("logs")),
      nav_panel("Sistema", system_ui("system")),
      nav_panel("Auditoría", audit_ui("audit"))
    )
  )
}

no_db_ui <- function() {
  div(class = "login", div(class = "card login__card",
    h4("Base de datos no disponible"),
    p("El panel necesita la carpeta de estado con permiso de escritura: ", tags$code(state_dir()), "."),
    p(class = "note", "En Singularity la monta singularity-deploy.sh (./state). En local, define MICROARRAI_STATE_DIR.")))
}

server <- function(input, output, session) {
  con <- tryCatch(state_db_connect(), error = function(e) NULL)
  session$onSessionEnded(function() if (!is.null(con)) DBI::dbDisconnect(con))

  user <- reactiveVal(NULL)
  authed <- reactive(!is.null(user()))
  login_msg <- reactiveVal(NULL)

  output$root <- renderUI({
    if (is.null(con)) return(no_db_ui())
    if (!authed()) {
      no_users <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM admin_users WHERE disabled = 0")$n == 0
      return(login_ui(no_users))
    }
    panel_ui(user())
  })

  output$login_msg <- renderUI({
    req(login_msg())
    div(class = "alert alert-danger py-2", login_msg())
  })

  observeEvent(input$login, {
    req(!is.null(con), !authed())
    u <- trimws(input$user)
    result <- check_login(con, u, input$pass, client_ip(session))
    if (result == "ok") {
      login_msg(NULL)
      user(u)
      audit_log(con, u, "login")
    } else {
      login_msg(if (result == "locked")
        sprintf("Demasiados intentos fallidos. Espera %d minutos.", LOCKOUT_MINUTES)
      else "Usuario o contraseña incorrectos.")
    }
  })

  logout <- function(detail = "") {
    req(authed())
    audit_log(con, user(), "logout", detail)
    user(NULL)
  }
  observeEvent(input$logout, logout())
  observeEvent(input$idle_logout, logout("30 min sin actividad"))

  visible <- reactive(!isFALSE(input$page_visible))
  overview_server("overview", con, authed)
  logs_server("logs", authed, visible)
  system_server("system", authed)
  audit_server("audit", con, authed)
}

shinyApp(ui, server)
