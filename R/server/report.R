# =============================================================================
# ANALYSIS REPORT (PDF) AND RESULTS WORKBOOK (XLSX)
# =============================================================================
# Both are built from one plain list `r` assembled in R/server/report_server.R,
# so they always agree and can be tested without a Shiny session. Any section
# may be NULL (step not run yet); the report then says so instead of failing.
#
#   r$meta        date, session, versions
#   r$settings    named list of sections, each a named character vector
#   r$input       arrays, analytes, features, groups, clinical column summary
#   r$qc          metrics (+ verdict), graded, problems, thresholds
#   r$stats       target, results (per peptide), top, volcano
#   r$ml          label, validation, consensus, importance, split, partition
#   r$protein     consensus biomarkers placed on their proteins
#   r$epitopes    every annotated peptide of the proteins carrying biomarkers
#   r$snapshots   pictures of the protein views (3D + 2D) taken in the browser
#
# Typeset like a paper: Times, black and grey only, booktabs tables (three
# rules, no fills), numbered tables, figures and equations. Drawn with grid on
# the base pdf() device (no LaTeX, no browser, no system fonts); text is folded
# to Latin-1, which the standard PDF fonts can show.
# =============================================================================

RP <- list(w = 8.27, h = 11.69, margin = 0.95, top = 10.85, bottom = 0.95, font = "Times",
           ink = "#000000", muted = "#4d4d4d", light = "#b3b3b3")
RP$text_w <- RP$w - 2 * RP$margin

rp_or <- function(a, b) if (is.null(a)) b else a

rp_latin <- function(x) {
  x <- as.character(x)
  for (p in list(c("≥", ">="), c("≤", "<="), c("[–—−]", "-"), c("Δ", "delta "),
                 c("→", "->"), c("[‘’]", "'"), c("[“”]", "\""), c("…", "...")))
    x <- gsub(p[1], p[2], x)
  iconv(x, "UTF-8", "latin1", sub = "?")
}

rp_fmt <- function(v, digits = 3) {
  if (!is.numeric(v)) return(ifelse(is.na(v), "", as.character(v)))
  small <- !is.na(v) & v != 0 & abs(v) < 1e-3          # p-values: 9.7e-16, not 0.00000000000000097
  ifelse(is.na(v), "", ifelse(small, formatC(v, format = "e", digits = 1), formatC(signif(v, digits), format = "fg", digits = digits)))
}

rp_gp <- function(size, face = "plain", col = RP$ink) grid::gpar(fontsize = size, fontface = face, col = col, fontfamily = RP$font)
rp_in <- function(v) grid::unit(v, "in")

# ---------------------------------------------------------------- layout ----
rp_new <- function(r) { e <- new.env(); e$page <- 0; e$y <- RP$top; e$r <- r; e$sec <- 0; e$tab <- 0; e$fig <- 0; e$eq <- 0; e$section <- ""; e }

rp_page <- function(ctx, section = ctx$section) {
  grid::grid.newpage()
  ctx$page <- ctx$page + 1
  ctx$section <- section
  grid::grid.lines(rp_in(c(RP$margin, RP$w - RP$margin)), rp_in(RP$h - 0.62), gp = grid::gpar(col = RP$ink, lwd = 0.5))
  grid::grid.text("MicroarrAI - Analysis report", rp_in(RP$margin), rp_in(RP$h - 0.52), just = "left", gp = rp_gp(8.5, "italic", RP$muted))
  grid::grid.text(rp_latin(section), rp_in(RP$w - RP$margin), rp_in(RP$h - 0.52), just = "right", gp = rp_gp(8.5, "italic", RP$muted))
  grid::grid.text(ctx$page, rp_in(RP$w / 2), rp_in(0.55), gp = rp_gp(9))
  ctx$y <- RP$top
}

rp_need <- function(ctx, h) if (ctx$y - h < RP$bottom) rp_page(ctx)

rp_text <- function(ctx, txt, size = 10, face = "plain", col = RP$ink, gap = 0.08, indent = 0, align = "left") {
  chars <- floor((RP$text_w - indent) * 72 / (size * 0.47))
  lines <- unlist(lapply(rp_latin(txt), strwrap, width = chars))
  lh <- size / 72 * 1.32
  for (l in lines) {
    rp_need(ctx, lh)
    x <- if (align == "center") RP$w / 2 else RP$margin + indent
    grid::grid.text(l, rp_in(x), rp_in(ctx$y - lh * 0.8), just = align, gp = rp_gp(size, face, col))
    ctx$y <- ctx$y - lh
  }
  ctx$y <- ctx$y - gap
}

rp_section <- function(ctx, title, new_page = TRUE) {
  ctx$sec <- ctx$sec + 1; ctx$sub <- 0
  label <- paste0(ctx$sec, "  ", title)
  if (new_page) rp_page(ctx, label) else { rp_need(ctx, 2); ctx$section <- label }   # never a heading alone at the foot
  rp_text(ctx, label, size = 14, face = "bold", gap = 0.12)
}
rp_sub <- function(ctx, title) {
  ctx$sub <- ctx$sub + 1
  rp_need(ctx, 0.8); ctx$y <- ctx$y - 0.06
  rp_text(ctx, paste0(ctx$sec, ".", ctx$sub, "  ", title), size = 11, face = "bold", gap = 0.05)
}
rp_note <- function(ctx, txt) rp_text(ctx, txt, size = 9, face = "italic", col = RP$muted, gap = 0.1)

# Display equation, centred and numbered on the right
rp_eq <- function(ctx, expr, h = 0.5) {
  ctx$eq <- ctx$eq + 1
  rp_need(ctx, h)
  yc <- ctx$y - h / 2
  grid::grid.text(expr, rp_in(RP$w / 2), rp_in(yc), gp = rp_gp(11))
  grid::grid.text(sprintf("(%d)", ctx$eq), rp_in(RP$w - RP$margin), rp_in(yc), just = "right", gp = rp_gp(10))
  ctx$y <- ctx$y - h - 0.04
}

# Booktabs table: caption above, top / mid / bottom rules, no fills.
# Numbers right-aligned, text left-aligned; split over pages with the header repeated.
rp_table <- function(ctx, df, caption = NULL, max_chars = 40, size = 8.5) {
  if (is.null(df) || nrow(df) == 0) return(rp_note(ctx, "No rows."))
  num <- vapply(df, is.numeric, logical(1))
  cells <- as.data.frame(lapply(df, function(v) { v <- rp_latin(rp_fmt(v)); ifelse(nchar(v) > max_chars, paste0(substr(v, 1, max_chars - 3), "..."), v) }),
                         check.names = FALSE, stringsAsFactors = FALSE)
  head <- rp_latin(gsub("_", " ", names(df)))
  width_of <- function(s, face) vapply(s, function(x) grid::convertWidth(grid::grobWidth(grid::textGrob(x, gp = rp_gp(size, face))), "in", valueOnly = TRUE), 0)
  pad <- 0.14
  cw <- vapply(seq_along(cells), function(j) max(width_of(head[j], "bold"), width_of(cells[[j]], "plain")) + pad, 0)
  if (sum(cw) > RP$text_w) {                         # too wide: shrink the type, then cut long cells
    if (size > 7) return(rp_table(ctx, df, caption, max_chars, size - 0.75))
    if (max_chars > 14) return(rp_table(ctx, df, caption, max_chars - 6, size))
  }
  tw <- min(sum(cw), RP$text_w); x0 <- RP$margin + (RP$text_w - tw) / 2
  xs <- x0 + c(0, cumsum(cw))
  rh <- size / 72 * 1.55
  draw_head <- function() {
    grid::grid.lines(rp_in(c(x0, x0 + tw)), rp_in(ctx$y), gp = grid::gpar(lwd = 1.2, col = RP$ink))
    for (j in seq_along(head)) {
      grid::grid.text(head[j], rp_in(if (num[j]) xs[j + 1] - pad / 2 else xs[j] + pad / 2), rp_in(ctx$y - rh * 0.68),
                      just = if (num[j]) "right" else "left", gp = rp_gp(size, "bold"))
    }
    ctx$y <- ctx$y - rh * 1.05
    grid::grid.lines(rp_in(c(x0, x0 + tw)), rp_in(ctx$y), gp = grid::gpar(lwd = 0.6, col = RP$ink))
    ctx$y <- ctx$y - 0.03
  }
  caption_lines <- function(cont) {
    if (is.null(caption)) return(invisible())
    if (!cont) ctx$tab <- ctx$tab + 1
    rp_text(ctx, paste0("Table ", ctx$tab, ". ", caption, if (cont) " (continued)" else ""), size = 9, gap = 0.12)
  }
  rp_need(ctx, rh * 4 + 0.3)
  caption_lines(FALSE); draw_head()
  for (i in seq_len(nrow(cells))) {
    if (ctx$y - rh < RP$bottom + 0.05) {
      grid::grid.lines(rp_in(c(x0, x0 + tw)), rp_in(ctx$y), gp = grid::gpar(lwd = 1.2, col = RP$ink))
      rp_page(ctx); caption_lines(TRUE); draw_head()
    }
    for (j in seq_along(cells)) {
      grid::grid.text(cells[i, j], rp_in(if (num[j]) xs[j + 1] - pad / 2 else xs[j] + pad / 2), rp_in(ctx$y - rh * 0.7),
                      just = if (num[j]) "right" else "left", gp = rp_gp(size))
    }
    ctx$y <- ctx$y - rh
  }
  ctx$y <- ctx$y - 0.03
  grid::grid.lines(rp_in(c(x0, x0 + tw)), rp_in(ctx$y), gp = grid::gpar(lwd = 1.2, col = RP$ink))
  ctx$y <- ctx$y - 0.22
}

# Two-column booktabs table for settings
rp_kv_table <- function(ctx, kv, caption) {
  if (length(kv) == 0) return(rp_note(ctx, "Not set."))
  val <- vapply(kv, function(v) if (length(v) == 0 || all(is.na(v))) "-" else paste(v, collapse = ", "), "")
  rp_table(ctx, data.frame(Setting = names(kv), Value = val, check.names = FALSE), caption, max_chars = 70)
}

# Figure: a ggplot or a list of rasters side by side; caption below
rp_figure <- function(ctx, content, h, caption, width = RP$text_w) {
  if (is.null(content)) return(invisible())
  rp_need(ctx, h + 0.45)
  x0 <- RP$margin + (RP$text_w - width) / 2
  if (inherits(content, "ggplot")) {
    print(content, vp = grid::viewport(x = rp_in(x0), y = rp_in(ctx$y), width = rp_in(width), height = rp_in(h), just = c("left", "top")))
  } else {                                           # list of image arrays, panels (a), (b), ...
    n <- length(content); pw <- (width - 0.15 * (n - 1)) / n
    for (k in seq_len(n)) {
      img <- content[[k]]; if (is.null(img)) next
      ar <- dim(img)[2] / dim(img)[1]
      iw <- min(pw, (h - 0.2) * ar); ih <- iw / ar
      xk <- x0 + (k - 1) * (pw + 0.15)
      grid::grid.raster(img, rp_in(xk + (pw - iw) / 2), rp_in(ctx$y - 0.2), width = rp_in(iw), height = rp_in(ih), just = c("left", "top"))
      grid::grid.rect(rp_in(xk + (pw - iw) / 2), rp_in(ctx$y - 0.2), rp_in(iw), rp_in(ih), just = c("left", "top"), gp = grid::gpar(fill = NA, col = RP$light, lwd = 0.5))
      grid::grid.text(paste0("(", letters[k], ")"), rp_in(xk), rp_in(ctx$y - 0.08), just = "left", gp = rp_gp(9, "bold"))
    }
  }
  ctx$y <- ctx$y - h - 0.08
  ctx$fig <- ctx$fig + 1
  rp_text(ctx, paste0("Figure ", ctx$fig, ". ", caption), size = 9, gap = 0.2)
}

rp_theme <- function() {
  ggplot2::theme_classic(base_size = 9, base_family = RP$font) +
    ggplot2::theme(legend.position = "bottom", strip.background = ggplot2::element_blank(),
                   strip.text = ggplot2::element_text(face = "bold"), axis.line = ggplot2::element_line(linewidth = 0.3),
                   axis.ticks = ggplot2::element_line(linewidth = 0.3))
}

# -------------------------------------------------------------- sections ----
rp_title <- function(ctx) {
  r <- ctx$r
  rp_page(ctx, "")
  ctx$y <- ctx$y - 0.3
  rp_text(ctx, "MicroarrAI analysis report", size = 20, face = "bold", align = "center", gap = 0.06)
  rp_text(ctx, "Peptide microarray study: quality control, differential analysis, validated classifiers and epitope mapping",
          size = 10.5, face = "italic", align = "center", gap = 0.06)
  rp_text(ctx, sprintf("Generated %s  |  session %s  |  MicroarrAI %s  |  %s", r$meta$date, r$meta$session, r$meta$app_version, r$meta$r_version),
          size = 9, col = RP$muted, align = "center", gap = 0.35)
  best <- if (!is.null(r$ml$validation) && nrow(r$ml$validation)) r$ml$validation[which.max(r$ml$validation$AUC), ] else NULL
  rows <- c(
    "Arrays analysed" = rp_or(r$input$arrays, "-"),
    "Peptide features (isotype x peptide)" = rp_or(r$input$features, "-"),
    "Groups compared" = if (!is.null(r$input$groups)) paste0(names(r$input$groups), " (n = ", r$input$groups, ")", collapse = ", ") else "-",
    "Arrays passing quality control" = if (!is.null(r$qc$verdicts)) sprintf("%d of %d array-channel pairs", sum(r$qc$verdicts$verdict == "green"), nrow(r$qc$verdicts)) else "not run",
    "Peptides with FDR < 0.05" = if (!is.null(r$stats$results)) sum(r$stats$results$p.adj < 0.05, na.rm = TRUE) else "not run",
    "Best classifier on held-out samples" = if (!is.null(best)) sprintf("%s, AUC %.2f (95%% CI %.2f-%.2f)", best$Model, best$AUC, best$AUC_low, best$AUC_high) else "not run",
    "Consensus biomarkers" = if (!is.null(r$ml$consensus)) nrow(r$ml$consensus) else "not run")
  rp_table(ctx, data.frame(Measure = names(rows), Result = unname(rows), check.names = FALSE), "Summary of the analysis.", max_chars = 80)
}

rp_methods <- function(ctx) {
  rp_section(ctx, "Methods", new_page = FALSE)
  rp_text(ctx, rp_or(ctx$r$methods, "Run the analysis to generate a methods summary."))
  rp_text(ctx, "Within each array and channel, spot values x were standardised against the negative-control spots:")
  rp_eq(ctx, quote(z[ij] == frac(x[ij] - tilde(x)[neg * "," * j], MAD[neg * "," * j])))
  rp_text(ctx, "Arrays were graded on the signal-to-noise of the top-dose positive control, with the classical limits of detection (3) and quantification (10):")
  rp_eq(ctx, quote(S/N == frac(F - B, sigma[B]) ~~~~ "detection:" ~ S/N >= 3 ~~~~ "quantification:" ~ S/N >= 10))
  rp_text(ctx, "Each peptide p was compared between groups g with a linear model, and p-values were adjusted by Benjamini-Hochberg over the m peptides tested:")
  rp_eq(ctx, quote(y[ip] == beta[0 * p] + beta[1 * p] * g[i] + epsilon[ip]))
  rp_eq(ctx, quote(q[(k)] == min(group("", frac(m ~ p[(l)], l), ""), l >= k)), h = 0.55)
  rp_text(ctx, "Classifiers were scored once on samples never used for imputation, selection or tuning; the AUC is reported with its DeLong 95% confidence interval:")
  rp_eq(ctx, quote(widehat(AUC) %+-% 1.96 * sqrt(widehat(Var)[DeLong](widehat(AUC)))))
}

rp_settings <- function(ctx) {
  rp_section(ctx, "Parameters")
  rp_note(ctx, "Every setting the results depend on. With the same input files and these values, the analysis can be repeated exactly.")
  for (sec in names(ctx$r$settings)) rp_kv_table(ctx, ctx$r$settings[[sec]], paste0(sec, "."))
}

rp_input <- function(ctx) {
  i <- ctx$r$input
  rp_section(ctx, "Input data", new_page = FALSE)
  if (is.null(i)) return(rp_note(ctx, "No data loaded."))
  rows <- list("Arrays (scan files)" = i$arrays, "Spot names found" = i$analytes,
               "Peptide features (isotype x peptide)" = i$features, "Samples with a clinical row" = i$matched,
               "Groups of the target" = if (!is.null(i$groups)) paste0(names(i$groups), " = ", i$groups),
               "Missing values before imputation" = i$missing)
  rp_kv_table(ctx, Filter(Negate(is.null), rows), "Arrays and samples.")
  rp_table(ctx, i$clinical, "Clinical columns used in the analysis.")
}

rp_qc <- function(ctx) {
  q <- ctx$r$qc
  rp_section(ctx, "Quality control")
  if (is.null(q$verdicts)) return(rp_note(ctx, "Quality control needs raw scanner files; it was not run."))
  v <- q$verdicts
  rp_text(ctx, sprintf("Of %d array-channel pairs, %d passed every metric, %d were borderline and %d failed at least one. %s",
                       nrow(v), sum(v$verdict == "green"), sum(v$verdict == "amber"), sum(v$verdict == "red"), rp_or(q$normalization, "")))
  if (!is.null(q$graded)) {
    g <- q$graded
    g$grade <- factor(ifelse(is.na(g$grade), "not measurable", c(green = "pass", amber = "borderline", red = "fail")[g$grade]),
                      levels = c("pass", "borderline", "fail", "not measurable"))
    g$sample <- factor(g$sample, levels = unique(v$sample[order(-match(v$verdict, c("green", "amber", "red")))]))
    many <- length(unique(g$sample)) > 50                # thin columns: white borders would hide the tiles
    p <- ggplot2::ggplot(g, ggplot2::aes(sample, label, fill = grade)) + ggplot2::geom_tile(colour = if (many) NA else "white", linewidth = 0.2) +
      ggplot2::facet_wrap(~ paste("Channel", channel), ncol = 1) +
      ggplot2::scale_fill_manual(values = c(pass = "#d4d4d4", borderline = "#7f7f7f", fail = "#000000", "not measurable" = "#ffffff"), drop = FALSE) +
      ggplot2::labs(x = "Arrays (worst on the right)", y = NULL, fill = NULL) + rp_theme() +
      ggplot2::theme(axis.text.x = ggplot2::element_blank(), axis.ticks.x = ggplot2::element_blank(), axis.line = ggplot2::element_blank())
    rp_figure(ctx, p, h = 1.1 + 1.25 * length(unique(g$channel)), "Quality scorecard: one column per array, one row per metric.")
  }
  rp_table(ctx, q$problems, "Arrays that did not pass, with the metrics out of range.", max_chars = 70)
  rp_table(ctx, q$thresholds, "Quality thresholds.")
}

rp_stats <- function(ctx) {
  s <- ctx$r$stats
  rp_section(ctx, "Differential analysis")
  if (is.null(s$results)) return(rp_note(ctx, "The peptide analysis was not run."))
  rp_text(ctx, sprintf("Target variable: %s. %d peptide features tested; %d with FDR < 0.05.",
                       s$target, nrow(s$results), sum(s$results$p.adj < 0.05, na.rm = TRUE)))
  if (!is.null(s$volcano) && nrow(s$volcano)) {
    vd <- s$volcano
    vd$status <- factor(vd$status, levels = c("Up", "Down", "NS"))
    p <- ggplot2::ggplot(vd, ggplot2::aes(log2FC, -log10(padj), shape = status, colour = status)) +
      ggplot2::geom_point(size = 1.2) +
      ggplot2::scale_shape_manual(values = c(Up = 16, Down = 1, NS = 20), drop = FALSE) +
      ggplot2::scale_colour_manual(values = c(Up = "#000000", Down = "#000000", NS = "#b3b3b3"), drop = FALSE) +
      ggplot2::geom_hline(yintercept = -log10(0.05), linetype = "dashed", linewidth = 0.3) +
      ggplot2::labs(x = rp_latin(rp_or(s$volcano_label, "Mean difference (B - A)")), y = expression(-log[10]~FDR), shape = NULL, colour = NULL) + rp_theme()
    if ("isotype" %in% names(vd)) p <- p + ggplot2::facet_wrap(~isotype)
    rp_figure(ctx, p, h = 3.1, "Volcano plot per isotype. Filled: higher in the second group; open: higher in the first; grey: not significant. Dashed line: FDR = 0.05.")
  }
  rp_table(ctx, utils::head(s$top, 30), "Top peptides by adjusted p-value. Effect: difference of group means; AUC: discriminative ability of the peptide alone.")
}

rp_ml <- function(ctx) {
  m <- ctx$r$ml
  rp_section(ctx, "Machine learning")
  if (is.null(m$validation)) return(rp_note(ctx, "No supervised model was trained."))
  rp_text(ctx, paste0(rp_or(m$label, ""), "."))
  val <- m$validation
  rp_table(ctx, val, "Performance on samples not used for training. AUC with DeLong 95% confidence interval; CV AUC from cross-validation inside the training set, for reference only.")
  if (nrow(val) && any(!is.na(val$AUC))) {
    p <- ggplot2::ggplot(val, ggplot2::aes(stats::reorder(Model, AUC), AUC)) +
      ggplot2::geom_point(size = 2) +
      ggplot2::geom_errorbar(ggplot2::aes(ymin = AUC_low, ymax = AUC_high), width = 0.15, linewidth = 0.4, na.rm = TRUE) +
      ggplot2::geom_hline(yintercept = 0.5, linetype = "dashed", linewidth = 0.3) +
      ggplot2::coord_flip(ylim = c(0.4, 1)) + ggplot2::labs(x = NULL, y = "Test AUC") + rp_theme()
    rp_figure(ctx, p, h = 0.7 + 0.35 * nrow(val), "Test AUC per model with 95% confidence intervals. Dashed line: chance.", width = 5)
  }
  rp_table(ctx, m$consensus, "Consensus biomarkers: peptides among the top-ranked features of at least two models.")
  if (!is.null(m$split)) rp_kv_table(ctx, m$split, "Data split.")
}

rp_protein <- function(ctx) {
  r <- ctx$r
  rp_section(ctx, "Biomarkers on their proteins")
  if (is.null(r$protein) || nrow(r$protein) == 0) return(rp_note(ctx, "No consensus biomarker was sent to the protein view, or no peptide annotation was loaded."))
  rp_table(ctx, r$protein, "Consensus biomarkers with their position on the protein (UniProt numbering).", max_chars = 30)
  ep <- r$epitopes
  if (!is.null(ep) && nrow(ep)) for (pr in unique(ep$protein)) {
    d <- ep[ep$protein == pr, ]
    p <- ggplot2::ggplot(d) +
      ggplot2::geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.3) +
      ggplot2::geom_segment(ggplot2::aes(x = start, xend = end, y = effect, yend = effect, linewidth = biomarker, colour = biomarker)) +
      ggplot2::scale_linewidth_manual(values = c(`FALSE` = 0.5, `TRUE` = 1.6), guide = "none") +
      ggplot2::scale_colour_manual(values = c(`FALSE` = "#a6a6a6", `TRUE` = "#000000"), labels = c(`FALSE` = "other peptides", `TRUE` = "consensus biomarker")) +
      ggplot2::facet_wrap(~isotype, ncol = 1) +
      ggplot2::labs(x = "Residue", y = "Effect (difference of group means)", colour = NULL) + rp_theme()
    rp_figure(ctx, p, h = 0.9 + 1.1 * length(unique(d$isotype)),
              sprintf("Linear epitope map of %s%s: each segment is a spotted peptide at its residues, at the height of its group difference. Black: consensus biomarkers.",
                      pr, if (!is.null(d$accession) && !all(is.na(d$accession))) paste0(" (UniProt ", d$accession[1], ")") else ""))
  }
  for (s in r$snapshots) {
    if (is.null(s$view3d) && is.null(s$map2d)) next
    rp_figure(ctx, list(s$view3d, s$map2d), h = 3.1,
              sprintf("%s (UniProt %s%s) as shown in the app: (a) 3D structure and (b) sequence map, coloured by %s for %s%s. Consensus biomarkers are outlined.",
                      s$protein, s$accession, if (nzchar(rp_or(s$pdb, ""))) paste0(", PDB ", s$pdb) else ", AlphaFold model",
                      switch(rp_or(s$mode, "expr"), expr = "mean signal", dgroup = "the difference between groups", diso = "the difference between isotypes", s$mode),
                      s$isotype, if (nzchar(rp_or(s$group, ""))) paste0(", group ", s$group) else ""))
  }
}

rp_session <- function(ctx) {
  rp_section(ctx, "Software", new_page = FALSE)
  rp_table(ctx, ctx$r$meta$packages, "R packages used.")
  rp_note(ctx, "Report produced by MicroarrAI. Uploaded files stay in the session and are deleted when it ends.")
}

#' Write the PDF report
build_pdf_report <- function(file, r) {
  grDevices::pdf(file, width = RP$w, height = RP$h, family = RP$font, title = "MicroarrAI analysis report", onefile = TRUE)
  on.exit(grDevices::dev.off(), add = TRUE)
  ctx <- rp_new(r)
  rp_title(ctx); rp_methods(ctx)
  for (f in list(rp_settings, rp_input, rp_qc, rp_stats, rp_ml, rp_protein, rp_session)) f(ctx)
  invisible(file)
}

#' Write every table of the report into one workbook (one sheet each)
build_results_workbook <- function(file, r) {
  kv_df <- function(sec) data.frame(Section = rep(names(sec), lengths(sec)),
                                    Setting = unlist(lapply(sec, names), use.names = FALSE),
                                    Value = unlist(lapply(sec, function(s) vapply(s, function(v) paste(v, collapse = ", "), "")), use.names = FALSE))
  sheets <- list(
    Settings = if (length(r$settings)) kv_df(r$settings),
    Clinical_columns = r$input$clinical,
    QC_scorecard = r$qc$metrics,
    QC_problems = r$qc$problems,
    Differential = r$stats$results,
    Volcano = r$stats$volcano,
    ML_validation = r$ml$validation,
    ML_consensus = r$ml$consensus,
    ML_partition = r$ml$partition,
    Protein_biomarkers = r$protein,
    Epitope_map = r$epitopes,
    Software = r$meta$packages
  )
  for (nm in names(r$ml$importance)) sheets[[paste0("Importance_", gsub("[^A-Za-z0-9]", "", nm))]] <- r$ml$importance[[nm]]
  sheets <- Filter(function(x) !is.null(x) && nrow(x) > 0, sheets)
  if (!length(sheets)) sheets <- list(Info = data.frame(Message = "Nothing has been computed yet."))
  wb <- openxlsx::createWorkbook()
  head_style <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#E8F6F2")
  for (nm in names(sheets)) {
    openxlsx::addWorksheet(wb, substr(nm, 1, 31))
    openxlsx::writeData(wb, substr(nm, 1, 31), as.data.frame(sheets[[nm]]), headerStyle = head_style)
    openxlsx::freezePane(wb, substr(nm, 1, 31), firstRow = TRUE)
  }
  openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
  invisible(file)
}
