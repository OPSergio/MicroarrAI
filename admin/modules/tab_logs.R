# =============================================================================
# ADMIN — Logs: live tail of Shiny Server / R process logs
# =============================================================================
# The server checks the file size every second and sends ONLY the new bytes
# over the websocket; www/admin.js appends them (capped at 3000 lines). The
# whole log is never re-rendered, so it neither flickers nor jumps.
# Search and level filters run in the browser over the lines already sent.
# =============================================================================

logs_ui <- function(id) {
  ns <- NS(id)
  layout_columns(col_widths = c(3, 9),
    card(card_header("Ficheros", span(class = "card__sub", log_dir())),
         selectInput(ns("file"), NULL, choices = NULL, width = "100%", size = 14, selectize = FALSE),
         downloadButton(ns("download"), "Descargar", class = "btn-sm")),
    card(
      div(class = "log-toolbar",
          tags$input(class = "form-control log-search", placeholder = "Buscar… (p. ej. Error in)",
                     `data-view` = ns("view")),
          div(class = "btn-group log-level", `data-view` = ns("view"),
              tags$button(class = "btn btn-sm btn-outline-light active", `data-level` = "all", "Todo"),
              tags$button(class = "btn btn-sm btn-outline-light", `data-level` = "err", "Errores"),
              tags$button(class = "btn btn-sm btn-outline-light", `data-level` = "warn", "Avisos")),
          checkboxInput(ns("follow"), "Seguir en vivo", value = TRUE)),
      div(id = ns("view"), class = "logview"))
  )
}

logs_server <- function(id, authed, visible) moduleServer(id, function(input, output, session) {
  ns <- session$ns
  st <- new.env()  # tail state of this browser tab

  # Refresh the file list only when it changes, or the open dropdown would reset
  observe({
    req(authed())
    invalidateLater(5000)
    d <- list_logs()
    # (an empty selector means the panel was just re-rendered after a login)
    if (identical(d$name, st$names) && isTruthy(isolate(input$file))) return()
    st$names <- d$name
    label <- sprintf("%s  ·  %s", d$name, fmt_mb(d$size / 1024^2))
    keep <- isolate(input$file)
    updateSelectInput(session, "file", choices = setNames(d$name, label),
                      selected = if (isTRUE(keep %in% d$name)) keep else d$name[1])
  })

  # Only names from the listing are accepted: a crafted input can't read
  # anything outside the log directory
  current_path <- reactive({
    req(authed(), input$file %in% list_logs()$name)
    file.path(log_dir(), input$file)
  })

  push <- function(reset = FALSE) {
    r <- read_from(st$path, st$offset)
    st$offset <- r$offset
    text <- paste0(st$rest, r$text)
    if (!nzchar(text) && !reset && !r$reset) return()
    lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
    complete <- endsWith(text, "\n")
    st$rest <- if (complete || !length(lines)) "" else lines[length(lines)]
    if (!complete && length(lines)) lines <- lines[-length(lines)]
    if (st$skip_first && length(lines)) { lines <- lines[-1]; st$skip_first <- FALSE }
    session$sendCustomMessage("log_lines", list(view = ns("view"), reset = reset || r$reset,
                                                lines = as.list(sub("\r$", "", lines))))
  }

  # New file selected: show its last 256 KB
  observeEvent(current_path(), {
    st$path <- current_path()
    st$offset <- max(0, file.size(st$path) - 256 * 1024)
    st$skip_first <- st$offset > 0  # first line is probably cut in half
    st$rest <- ""
    push(reset = TRUE)
  })

  # Live: 1 s polling while "Seguir" is on (the browser also pauses it when
  # the tab is hidden, see admin.js)
  observe({
    req(authed(), isTRUE(input$follow), visible())
    invalidateLater(1000)
    if (!is.null(st$path)) push()
  })

  output$download <- downloadHandler(
    filename = function() input$file,
    content = function(file) file.copy(current_path(), file)
  )
})
