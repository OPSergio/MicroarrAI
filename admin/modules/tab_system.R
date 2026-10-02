# =============================================================================
# ADMIN — Sistema: limits vs usage, disk, R processes, image
# =============================================================================

system_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(col_widths = c(4, 4, 4),
      card(card_header("Memoria"), uiOutput(ns("memory"))),
      card(card_header("CPU"), uiOutput(ns("cpu"))),
      card(card_header("Disco"), uiOutput(ns("disk")))),
    layout_columns(col_widths = c(8, 4),
      card(card_header("Procesos R", span(class = "card__sub", "todos los usuarios comparten el proceso de la app")),
           DT::DTOutput(ns("procs"))),
      card(card_header("Imagen y configuración"), uiOutput(ns("config"))))
  )
}

meter <- function(label, used, total, unit_fmt = fmt_mb) {
  pct <- used / total * 100
  lvl <- if (is.na(pct)) "neutral" else if (pct > 90) "critical" else if (pct > 75) "warning" else "good"
  width <- if (is.na(pct)) 0 else min(100, pct)
  div(class = "meter",
      div(class = "meter__row", status(lvl, label),
          span(class = "v", if (is.na(pct)) unit_fmt(used) else sprintf("%s / %s · %.0f %%", unit_fmt(used), unit_fmt(total), pct))),
      div(class = "meter__bar", span(class = paste0("meter--", lvl), style = sprintf("width:%.0f%%", width))))
}

system_server <- function(id, authed) moduleServer(id, function(input, output, session) {
  tick <- reactive({ req(authed()); invalidateLater(10000); Sys.time() })

  output$memory <- renderUI({
    tick()
    m <- memory_status()
    tagList(
      meter("Instancia (límite)", m$used_mb, m$limit_mb),
      meter("Máquina", m$host_total_mb - m$host_avail_mb, m$host_total_mb),
      tags$dl(class = "kv",
        tags$dt("Pico de la instancia"), tags$dd(fmt_mb(m$peak_mb)),
        tags$dt("Procesos matados por OOM"), tags$dd(if (is.na(m$oom_kills)) "no disponible" else m$oom_kills)),
      if (is.na(m$limit_mb)) p(class = "note", "No se ve un límite de memoria: la instancia puede usar toda la RAM de la máquina."))
  })

  output$cpu <- renderUI({
    tick()
    c <- cpu_status()
    tags$dl(class = "kv",
      tags$dt("Límite"), tags$dd(if (is.na(c$limit_cores)) "sin límite" else sprintf("%g núcleos", c$limit_cores)),
      tags$dt("Núcleos de la máquina"), tags$dd(c$host_cores),
      tags$dt("Carga 1 / 5 / 15 min"), tags$dd(c$load))
  })

  output$disk <- renderUI({
    tick()
    row <- function(label, path) { d <- disk_status(path); meter(label, d$used_mb, d$used_mb + d$avail_mb) }
    tagList(row("/tmp (subidas)", "/tmp"), row("Logs", log_dir()), row("Estado (BD)", state_dir()),
            p(class = "note", "Cada medidor es la partición entera donde está esa carpeta."))
  })

  output$procs <- DT::renderDT({
    tick()
    p <- r_processes()
    admin_table(data.frame(PID = p$pid, App = p$app, RAM = fmt_mb(p$rss_mb),
                           Arrancó = format(p$start, "%d/%m %H:%M")))
  })

  output$config <- renderUI({
    tick()
    img <- image_info()
    tags$dl(class = "kv",
      tags$dt("Build de la imagen"), tags$dd(img$build_date),
      tags$dt("Versión"), tags$dd(img$version),
      tags$dt("Subida máxima"), tags$dd(paste(Sys.getenv("MICROARRAI_MAX_UPLOAD_MB", "1024"), "MB")),
      tags$dt("OMP_NUM_THREADS"), tags$dd(Sys.getenv("OMP_NUM_THREADS", "—")),
      tags$dt("R"), tags$dd(R.version$version.string),
      tags$dt("Base de datos"), tags$dd(file.path(state_dir(), "microarrai.sqlite")))
  })
})
