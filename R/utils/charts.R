# ============================================================================
# MicroarrAI - Native interactive charts
# ============================================================================
# R builds a small spec (list + data frames); www/charts/*.js draws it as SVG
# or canvas in the browser. Replaces ggiraph (needed system fonts such as Arial
# on the server) and rgl/car (3D through a WebGL widget). Nothing here touches
# fonts or graphics devices, so it behaves the same in every container.
# ============================================================================

#' Placeholder for a native chart
chartOutput <- function(id, height = "400px") {
  tagList(
    singleton(tags$head(
      tags$link(rel = "stylesheet", href = "charts/charts.css"),
      tags$script(src = "charts/core.js"),
      tags$script(src = "charts/plots2d.js"),
      tags$script(src = "charts/scatter3d.js")
    )),
    tags$div(id = id, class = "mai-chart", style = paste0("height:", height, ";"))
  )
}

#' Render a chart spec (one of the chart_*() builders below)
renderChart <- function(expr, env = parent.frame(), quoted = FALSE) {
  func <- shiny::exprToFunction(expr, env, quoted)
  shiny::createRenderFunction(func, function(value, session, name, ...) value, chartOutput)
}

#' Group colours from the corporate palette, interpolated past 12 groups
chart_colors <- function(levels) as.list(stats::setNames(microarrai_pal()(length(levels)), levels))

chart_levels <- function(g) if (is.factor(g)) levels(droplevels(g)) else sort(unique(as.character(g)))

#' Text shown in place of a chart (empty state or a readable error)
chart_message <- function(text, kind = "info") list(type = "message", text = text, kind = kind)

#' Ordination / score plot: one point per sample, coloured by group
chart_scatter <- function(x, y, group, id, tip, xlab, ylab, title = NULL, subtitle = NULL,
                          shape = NULL, ellipse = TRUE, group_title = NULL, shape_title = NULL) {
  data <- data.frame(x = x, y = y, g = as.character(group), id = as.character(id), tip = tip)
  if (!is.null(shape)) data$shape <- as.character(shape)
  lv <- chart_levels(group)
  list(type = "scatter", data = data, groups = lv, colors = chart_colors(lv), xlab = xlab, ylab = ylab,
       title = title, subtitle = subtitle, ellipse = ellipse, groupTitle = group_title, shapeTitle = shape_title)
}

#' 3D ordination: same as chart_scatter() with a third axis
chart_scatter3d <- function(x, y, z, group, id, tip, labels, title = NULL, subtitle = NULL) {
  lv <- chart_levels(group)
  list(type = "scatter3d",
       data = data.frame(x = x, y = y, z = z, g = as.character(group), id = as.character(id), tip = tip),
       groups = lv, colors = chart_colors(lv), labels = labels, title = title, subtitle = subtitle)
}

#' Tooltip for one sample in an ordination
sample_tip <- function(id, group, ...) {
  coords <- list(...)
  paste0(id, "\nGroup: ", group,
         do.call(paste0, lapply(names(coords), function(k) paste0("\n", k, ": ", round(coords[[k]], 2)))))
}

#' Donut of counts per category
chart_donut <- function(labels, values, colors, center_label = NULL, title = NULL) {
  list(type = "donut", slices = data.frame(label = labels, value = values, color = rep_len(colors, length(labels))),
       center = list(label = center_label), title = title)
}

#' Small-multiple histograms; panels is a named list of numeric vectors
chart_histogram <- function(panels, colors, xlab, bins = 40, title = NULL) {
  colors <- rep_len(colors, length(panels))
  list(type = "histogram", xlab = xlab, bins = bins, title = title,
       panels = unname(Map(function(nm, v, col) list(name = nm, color = col, values = v[is.finite(v)]),
                           names(panels), panels, colors)))
}

#' Violin + box + samples of one variable per group
chart_groupdist <- function(values, group, ids, ylab, title = NULL, subtitle = NULL) {
  lv <- chart_levels(group)
  cols <- chart_colors(lv)
  list(type = "groupdist", ylab = ylab, title = title, subtitle = subtitle,
       groups = lapply(lv, function(g) {
         k <- as.character(group) == g
         list(name = g, color = cols[[g]], values = values[k], ids = as.character(ids[k]))
       }))
}

#' Radar of metrics on a 0-1 scale (NA shown as n/a)
chart_radar <- function(axes, values, color, title = NULL) {
  list(type = "radar", axes = axes, values = unname(values), color = color, title = title)
}

#' ROC curves from calculate_roc_curve() output (one curve per class)
chart_roc <- function(roc_data, title = NULL, subtitle = NULL) {
  lv <- unique(roc_data$class)
  cols <- if (length(lv) == 1) list(stats::setNames("#17a589", lv)) else chart_colors(lv)
  cols <- unlist(cols)
  list(type = "roc", title = title, subtitle = subtitle,
       curves = lapply(lv, function(cl) {
         d <- roc_data[roc_data$class == cl, ]
         list(name = cl, color = unname(cols[cl]), fpr = 1 - d$specificity, tpr = d$sensitivity,
              auc = d$auc[1], lo = d$auc_low[1], hi = d$auc_high[1])
       }))
}

