# Small UI pieces shared by the admin tabs

kpi <- function(label, value, sub = NULL) {
  div(class = "kpi card",
      div(class = "kpi__label", label),
      div(class = "kpi__value", value),
      if (!is.null(sub)) div(class = "kpi__sub", sub))
}

# Status always carries an icon + word, never colour alone
status <- function(level = c("good", "warning", "critical", "neutral"), text) {
  level <- match.arg(level)
  icon <- c(good = "✓", warning = "!", critical = "×", neutral = "–")[[level]]
  span(class = paste0("status status--", level), span(class = "status__icon", icon), text)
}

# Compact dark DataTable used by every tab
admin_table <- function(df, page = 10, selection = "none") {
  DT::datatable(df, rownames = FALSE, style = "bootstrap5", selection = selection,
                options = list(dom = if (nrow(df) > page) "tp" else "t", pageLength = page,
                               language = list(emptyTable = "Sin datos todavía")))
}

dark_plotly <- function(p) {
  plotly::config(plotly::layout(p,
    paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
    font = list(color = "#b4bad3", family = "Inter, system-ui, sans-serif", size = 11),
    xaxis = list(gridcolor = "#262b4a", zerolinecolor = "#3a4064", title = ""),
    yaxis = list(gridcolor = "#262b4a", zerolinecolor = "#3a4064"),
    legend = list(orientation = "h", y = -0.2),
    margin = list(l = 50, r = 10, t = 10, b = 30)), displayModeBar = FALSE)
}
