# =============================================================================
# ADMIN — Resumen: is the app up, how close to the memory limit, did it crash
# =============================================================================

overview_ui <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("kpis")),
    layout_columns(col_widths = c(8, 4),
      card(card_header("Memoria de la app (24 h)",
                       span(class = "card__sub", "un punto cada 30 s; un hueco = proceso ocupado")),
           plotly::plotlyOutput(ns("mem"), height = "280px")),
      card(card_header("Estado"), uiOutput(ns("health")))),
    layout_columns(col_widths = c(6, 6),
      card(card_header("Caídas (7 días)",
                       span(class = "card__sub", "proceso R que murió con usuarios conectados")),
           DT::DTOutput(ns("crashes")), uiOutput(ns("crash_detail"))),
      card(card_header("Errores en los logs (24 h)"), DT::DTOutput(ns("errors")))),
    card(card_header("Actividad reciente"), DT::DTOutput(ns("events")))
  )
}

overview_server <- function(id, con, authed) moduleServer(id, function(input, output, session) {
  # Every output hangs off tick(), so nothing is computed or sent before login
  tick <- reactive({ req(authed()); invalidateLater(15000); Sys.time() })

  mem    <- reactive({ tick(); memory_status() })
  health <- reactive({ tick(); app_health() })
  procs  <- reactive({ tick(); process_summary(con, r_processes()) })

  output$kpis <- renderUI({
    m <- mem(); h <- health(); p <- procs(); today <- today_counts(con)
    n <- function(type) sum(today$n[today$type == type])
    live <- p[p$alive, , drop = FALSE]
    busy <- nrow(live) > 0 && any(as.numeric(difftime(Sys.time(), as.POSIXct(live$last_ts, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), units = "secs")) > 90)
    pct <- m$used_mb / m$limit_mb * 100
    div(class = "kpi-row",
      kpi("App", if (h$ok) status("good", "Responde") else status("critical", "No responde"),
          if (h$ok) sprintf("%d ms", h$ms) else "ocupada o caída"),
      kpi("Memoria", if (is.na(pct)) fmt_mb(m$used_mb) else sprintf("%.0f %%", pct),
          if (is.na(m$limit_mb)) "sin límite detectado" else sprintf("%s de %s", fmt_mb(m$used_mb), fmt_mb(m$limit_mb))),
      kpi("Sesiones activas", sum(live$sessions), if (busy) status("warning", "proceso ocupado") else "según el último muestreo"),
      kpi("Caídas · 7 días", sum(p$crashed), if (is.na(m$oom_kills)) "OOM: no disponible" else sprintf("OOM kills: %d", m$oom_kills)),
      kpi("Hoy", n("session_start"), sprintf("sesiones · %d subidas · %d acciones", n("upload"), n("action")))
    )
  })

  output$health <- renderUI({
    m <- mem(); h <- health(); img <- image_info()
    level <- function(p) if (is.na(p)) "neutral" else if (p > 90) "critical" else if (p > 75) "warning" else "good"
    pct <- m$used_mb / m$limit_mb * 100
    tags$ul(class = "comp-list",
      tags$li(if (h$ok) status("good", "Shiny") else status("critical", "Shiny"),
              span(class = "meta", if (h$ok) sprintf("responde en %d ms", h$ms) else "sin respuesta en 10 s")),
      tags$li(status(level(pct), "Memoria"),
              span(class = "meta", if (is.na(pct)) "límite no visible" else sprintf("%.0f %% · pico %s", pct, fmt_mb(m$peak_mb)))),
      tags$li(status(if (isTRUE(m$oom_kills > 0)) "critical" else if (is.na(m$oom_kills)) "neutral" else "good", "OOM kills"),
              span(class = "meta", if (is.na(m$oom_kills)) "no disponible" else m$oom_kills)),
      tags$li(status("neutral", "Imagen"), span(class = "meta", img$build_date))
    )
  })

  output$mem <- plotly::renderPlotly({
    tick()
    d <- DBI::dbGetQuery(con, "SELECT ts, proc, rss_mb FROM metrics WHERE ts > ? ORDER BY ts",
                         params = list(since_utc(24)))
    d$ts <- as.POSIXct(d$ts, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    d$proc <- paste("PID", sub("-.*", "", d$proc))
    lim <- mem()$limit_mb
    p <- plotly::plot_ly(d, x = ~ts, y = ~rss_mb, color = ~proc, type = "scatter", mode = "lines",
                         colors = c("#3987e5", "#d95926", "#199e70"),
                         hovertemplate = "%{y:.0f} MB<extra>%{fullData.name}</extra>")
    if (!is.na(lim)) {
      p <- plotly::layout(p, shapes = list(list(type = "line", xref = "paper", x0 = 0, x1 = 1, y0 = lim, y1 = lim,
                                                line = list(color = "#d03b3b", dash = "dot", width = 1))),
                          annotations = list(list(xref = "paper", x = 1, y = lim, text = "límite", showarrow = FALSE,
                                                  xanchor = "right", yanchor = "bottom", font = list(color = "#ff8a8a"))))
    }
    dark_plotly(plotly::layout(p, yaxis = list(title = "MB", rangemode = "tozero")))
  })

  # Only replaced when the set of crashes changes, so a row the admin clicked
  # stays selected across the 15 s refreshes
  crashes <- reactiveVal(NULL)
  observe({
    p <- procs()
    c <- p[p$crashed, , drop = FALSE]
    if (!identical(c$proc, crashes()$proc)) crashes(c)
  })

  output$crashes <- DT::renderDT({
    c <- req(crashes())
    admin_table(data.frame(
      `Último dato` = substr(sub("T", " ", c$last_ts), 1, 16),
      PID = sub("-.*", "", c$proc),
      Sesiones = c$sessions,
      `Memoria final` = fmt_mb(c$rss_mb),
      Pico = fmt_mb(c$peak_mb),
      check.names = FALSE), page = 5, selection = "single")
  })

  # Clicking a crash shows what that process was doing just before it died
  output$crash_detail <- renderUI({
    i <- req(input$crashes_rows_selected)
    ev <- last_events(con, crashes()$proc[i], n = 8)
    tagList(tags$h6(class = "mt-3", "Últimos eventos de ese proceso"),
            tags$pre(class = "trace", paste(sub("T", " ", ev$ts), ev$sid, ev$type, ev$detail, collapse = "\n")))
  })

  output$errors <- DT::renderDT({ tick(); admin_table(log_errors(), page = 5) })

  output$events <- DT::renderDT({
    tick()
    e <- last_events(con, n = 50)
    admin_table(data.frame(Hora = substr(sub("T", " ", e$ts), 12, 19), Sesión = e$sid,
                           Evento = e$type, Detalle = e$detail), page = 10)
  })
})
