# ============================================================================
# MicroarrAI - Quality Control tab server
# ============================================================================
# dplyr verbs are namespaced throughout: several modelling packages loaded in
# global.R mask select() and filter(), and an unqualified call resolves to the
# wrong one at runtime.
# ============================================================================

QC_COLOURS <- c(green = "#17a589", amber = "#e8a33d", red = "#d1495b")

QC_POINT <- "#17a589"   # every scatter uses the same mark
QC_LINE  <- "#d1495b"   # fitted / reference lines
QC_GUIDE <- "#c3ced1"   # inert guides (identity line, grid emphasis)

#' Shared look for every plot in the tab
qc_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold", size = 12, colour = "#191c32"),
      plot.subtitle = ggplot2::element_text(size = 10, colour = "#8a8f98"),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "#eef0f3"),
      legend.key.width = ggplot2::unit(8, "pt")
    )
}

#' Wire up the Quality Control tab
#'
#' @param input,output,session Shiny objects
#' @param qc_spots Reactive returning spot-level data (sample, ID, channel,
#'   Expression and the quality columns), or NULL when only a processed matrix
#'   was uploaded
#' @param norm_diagnostics Reactive returning normalization_diagnostics() output
#' @param positive_controls Reactive returning a tibble with ID and dose
#' @param na_stats Reactive returning compute_na_stats() on the pre-imputation
#'   matrix. Completeness lives here rather than in the Peptide tab.
setup_quality_server <- function(input, output, session,
                                 qc_spots, norm_diagnostics, positive_controls,
                                 na_stats = reactive(NULL)) {

  metrics <- reactive({
    spots <- qc_spots()
    req(spots)
    compute_array_quality(spots, positive_controls = positive_controls())
  })

  graded <- reactive(grade_array_quality(metrics()))
  verdicts <- reactive(summarise_array_quality(graded()))

  # Guards every downstream reactive: without a channel the filters compare
  # against a zero-length value and dplyr aborts.
  chosen_channel <- reactive({
    req(input$qc_channel, nzchar(input$qc_channel))
    input$qc_channel
  })

  output$qc_missing_notice <- renderUI({
    if (!is.null(qc_spots())) return(NULL)
    tags$div(class = "qc-banner bad",
             tags$b("No raw arrays loaded. "),
             "Quality control reads the individual spots, so it needs the raw files rather than an already-processed matrix.")
  })

  # Each array is graded once per channel, because an array can be clean in one
  # channel and near the noise floor in the other. The tiles count those pairs,
  # not arrays, and say so.
  output$qc_verdict_tiles <- renderUI({
    v <- verdicts()
    counts <- table(factor(v$verdict, levels = c("green", "amber", "red")))

    tile <- function(class, n, label, tip) {
      tags$div(class = paste("qc-tile", class), `data-tip` = tip,
               tags$b(n), tags$span(label))
    }

    tags$div(class = "qc-verdicts",
      tile("qc-green", counts[["green"]], "array-channel pairs passing every check",
           "Green on all six metrics."),
      tile("qc-amber", counts[["amber"]], "borderline on at least one",
           "Best grade is amber: the array is usable but at least one metric sits between the pass and fail cut points."),
      tile("qc-red", counts[["red"]], "failing at least one check",
           "At least one metric is red. Open Array forensics below to see which one, then decide whether to drop the array."),
      tile("qc-slate", sprintf("%d x %d", dplyr::n_distinct(v$sample), dplyr::n_distinct(v$channel)),
           "arrays x channels examined",
           "Every array is graded separately in each channel.")
    )
  })

  # A cohort-wide median can sit exactly between two channels that behave
  # nothing alike, so the split is shown rather than left to be discovered.
  output$qc_channel_breakdown <- renderUI({
    v <- verdicts()
    req(dplyr::n_distinct(v$channel) > 1)

    worst <- graded() %>%
      dplyr::filter(grade == "red") %>%
      dplyr::count(channel, label, sort = TRUE) %>%
      dplyr::group_by(channel) %>%
      dplyr::slice_head(n = 1) %>%
      dplyr::ungroup()

    # A factor with .drop = FALSE keeps the three columns even when no array
    # earns that verdict anywhere.
    rows <- v %>%
      dplyr::mutate(verdict = factor(verdict, levels = c("green", "amber", "red"))) %>%
      dplyr::count(channel, verdict, .drop = FALSE) %>%
      tidyr::pivot_wider(names_from = verdict, values_from = n, values_fill = 0) %>%
      dplyr::left_join(worst, by = "channel")

    tags$div(
      class = "qc-card",
      tags$h4("Per-channel split"),
      tags$table(
        class = "qc-split",
        tags$tr(lapply(c("Channel", "Pass", "Borderline", "Fail", "Most common failure"),
                       function(h) tags$th(h))),
        lapply(seq_len(nrow(rows)), function(i) {
          tags$tr(
            tags$td(tags$b(rows$channel[i])),
            tags$td(rows$green[i]),
            tags$td(rows$amber[i]),
            tags$td(rows$red[i]),
            tags$td(if (is.na(rows$label[i])) "—"
                    else sprintf("%s (%d arrays)", rows$label[i], rows$n[i]))
          )
        })
      )
    )
  })

  output$qc_raw_notice <- renderUI({
    req(qc_spots())
    tags$p(class = "qc-help",
           tags$b("These grades are measured on the raw spots, before any normalization. "),
           "Normalization puts arrays on a common scale; it cannot make duplicate spots agree, ",
           "raise signal above background, or resurrect a control series that did not respond. ",
           "A red wall here is a statement about the assay, not about the normalization you chose.")
  })

  output$qc_normalization_banner <- renderUI({
    d <- norm_diagnostics()
    if (is.null(d)) return(NULL)

    tags$div(class = paste("qc-banner", if (d$improved) "ok" else "bad"),
             tags$b(if (d$improved) "Normalization is working. " else "Normalization is not doing its job. "),
             d$message)
  })

  output$qc_channel_selector <- renderUI({
    channels <- sort(unique(metrics()$channel))
    selectInput("qc_channel", "Channel", choices = channels, selected = channels[1])
  })

  # ---- Completeness (absorbed from the Peptide tab overview) -------------

  output$qc_completeness <- renderUI({
    stats <- na_stats()
    if (is.null(stats)) return(NULL)

    grade <- if (stats$pct_na > 5) "red" else if (stats$pct_na > 2) "amber" else "green"

    tags$div(
      class = "qc-verdicts",
      tags$div(class = paste("qc-tile", paste0("qc-", grade)),
               `data-tip` = "Share of peptide x sample cells with no usable value. Above 5% imputation starts inventing a meaningful part of the matrix.",
               tags$b(sprintf("%.1f%%", stats$pct_na)), tags$span("cells missing before imputation")),
      tags$div(class = "qc-tile qc-slate",
               `data-tip` = "Peptides missing in at least one sample. A peptide missing almost everywhere is a candidate to drop rather than impute.",
               tags$b(stats$n_peptides_with_na), tags$span("peptides with at least one gap")),
      tags$div(class = "qc-tile qc-slate",
               `data-tip` = "Samples missing at least one peptide.",
               tags$b(stats$n_samples_with_na), tags$span("samples with at least one gap")),
      tags$div(class = "qc-tile qc-slate",
               `data-tip` = "Samples x peptides going into the analysis.",
               tags$b(paste0(stats$n_samples, " x ", stats$n_peptides)), tags$span("matrix shape"))
    )
  })

  # ---- Traffic-light grid ------------------------------------------------

  heatmap_data <- reactive({
    canal <- chosen_channel()

    orden <- verdicts() %>%
      dplyr::filter(channel == canal) %>%
      dplyr::arrange(match(verdict, c("red", "amber", "green")), dplyr::desc(red), dplyr::desc(amber))

    datos <- graded() %>%
      dplyr::filter(channel == canal) %>%
      dplyr::left_join(dplyr::select(verdicts(), sample, channel, verdict),
                       by = c("sample", "channel"))

    if (isTRUE(input$qc_only_problems)) {
      datos <- dplyr::filter(datos, verdict != "green")
      orden <- dplyr::filter(orden, verdict != "green")
    }

    datos %>%
      dplyr::mutate(
        sample = factor(sample, levels = orden$sample),
        label  = factor(label, levels = rev(QC_THRESHOLDS$label)),
        tooltip = sprintf("%s\n%s: %s\n%s", sample, label,
                          ifelse(is.na(value), "not measurable", format(round(value, 3))),
                          toupper(ifelse(is.na(grade), "n/a", grade)))
      )
  })

  # Arrays run along the x axis: there are many of them and only six metrics,
  # so the grid stays landscape and readable at any cohort size.
  output$qc_heatmap <- ggiraph::renderGirafe({
    datos <- heatmap_data()
    req(nrow(datos) > 0)

    n_arrays <- dplyr::n_distinct(datos$sample)

    p <- ggplot2::ggplot(datos, ggplot2::aes(x = sample, y = label)) +
      ggiraph::geom_tile_interactive(
        ggplot2::aes(fill = grade, tooltip = tooltip, data_id = sample),
        colour = "white", linewidth = 0.4
      ) +
      ggplot2::scale_fill_manual(values = QC_COLOURS, na.value = "#dfe4e6",
                                 na.translate = TRUE, name = NULL) +
      ggplot2::labs(x = NULL, y = NULL) +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(
        axis.text.x = if (n_arrays <= 45) {
          ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7)
        } else ggplot2::element_blank(),
        axis.text.y = ggplot2::element_text(face = "bold", size = 10),
        panel.grid = ggplot2::element_blank(),
        legend.position = "none"
      )

    ggiraph::girafe(ggobj = p, width_svg = 13,
                    height_svg = if (n_arrays <= 45) 4.4 else 3.2,
                    options = list(ggiraph::opts_hover(css = "stroke:#191c32;stroke-width:1.5px;")))
  })

  # ---- Cohort plots -------------------------------------------------------

  peptide_spots <- reactive({
    canal <- chosen_channel()
    req(qc_spots())

    qc_spots() %>%
      dplyr::filter(grepl(PEPTIDE_ID_PATTERN, ID), channel == canal,
                    is.finite(Expression))
  })

  output$qc_density <- renderPlot({
    datos <- peptide_spots()
    req(nrow(datos) > 0)

    ggplot2::ggplot(datos, ggplot2::aes(x = Expression, group = sample)) +
      ggplot2::geom_density(colour = QC_POINT, alpha = 0.18, linewidth = 0.35) +
      ggplot2::labs(subtitle = paste("Channel", chosen_channel()),
                    x = "Peptide signal", y = "Density") +
      qc_theme()
  })

  output$qc_qq <- renderPlot({
    datos <- peptide_spots()
    req(nrow(datos) > 0)
    muestra <- datos$Expression[sample.int(nrow(datos), min(20000, nrow(datos)))]

    ggplot2::ggplot(data.frame(v = muestra), ggplot2::aes(sample = v)) +
      ggplot2::stat_qq(colour = QC_POINT, alpha = 0.35, size = 0.9) +
      ggplot2::stat_qq_line(colour = QC_LINE, linewidth = 0.8) +
      ggplot2::labs(subtitle = paste("Channel", chosen_channel()),
                    x = "Theoretical quantiles", y = "Observed") +
      qc_theme()
  })

  # ---- Per-array forensics ------------------------------------------------

  output$qc_array_selector <- renderUI({
    canal <- chosen_channel()
    orden <- verdicts() %>%
      dplyr::filter(channel == canal) %>%
      dplyr::arrange(match(verdict, c("red", "amber", "green")))

    selectInput("qc_array", "Array", choices = orden$sample, width = "320px")
  })

  array_spots <- reactive({
    canal <- chosen_channel()
    req(input$qc_array)

    dplyr::filter(qc_spots(), sample == input$qc_array, channel == canal)
  })

  # Every forensics panel says which array and channel it is showing: the tab
  # grades each channel separately, so an unlabelled plot is ambiguous.
  panel_subtitle <- reactive(sprintf("%s  ·  channel %s", input$qc_array, chosen_channel()))

  output$qc_spatial <- renderPlot({
    datos <- array_spots() %>% dplyr::filter(is.finite(x), is.finite(y))
    req(nrow(datos) > 0)

    ggplot2::ggplot(datos, ggplot2::aes(x = x, y = y, colour = Expression)) +
      ggplot2::geom_point(size = 1.6) +
      ggplot2::scale_colour_gradientn(colours = c("#f7f7f7", "#7fcdbb", QC_POINT, "#0b4f44"),
                                      na.value = "#e8a33d", name = NULL) +
      ggplot2::scale_y_reverse() +
      ggplot2::coord_equal() +
      ggplot2::labs(title = "Where the signal sits", subtitle = panel_subtitle(),
                    x = NULL, y = NULL) +
      qc_theme() +
      ggplot2::theme(axis.text = ggplot2::element_blank(),
                     panel.grid = ggplot2::element_blank())
  })

  output$qc_replicates <- renderPlot({
    datos <- array_spots() %>%
      dplyr::filter(grepl(PEPTIDE_ID_PATTERN, ID)) %>%
      dplyr::group_by(ID) %>%
      dplyr::mutate(replicate = dplyr::row_number()) %>%
      dplyr::ungroup() %>%
      dplyr::filter(replicate <= 2) %>%
      dplyr::select(ID, replicate, Expression) %>%
      tidyr::pivot_wider(names_from = replicate, values_from = Expression,
                         names_prefix = "rep") %>%
      dplyr::filter(is.finite(rep1), is.finite(rep2))

    req(nrow(datos) > 0, "rep2" %in% names(datos))
    r <- suppressWarnings(stats::cor(datos$rep1, datos$rep2, use = "complete.obs"))

    ggplot2::ggplot(datos, ggplot2::aes(x = rep1, y = rep2)) +
      ggplot2::geom_abline(slope = 1, intercept = 0, colour = QC_GUIDE, linetype = "22") +
      ggplot2::geom_point(colour = QC_POINT, alpha = 0.55, size = 1.6) +
      ggplot2::labs(title = sprintf("Duplicate spots  (R = %.3f)", r),
                    subtitle = panel_subtitle(),
                    x = "First spot", y = "Second spot") +
      qc_theme()
  })

  output$qc_dose <- renderPlot({
    controles <- positive_controls()
    req(!is.null(controles), nrow(controles) > 0)

    datos <- array_spots() %>%
      dplyr::inner_join(controles, by = "ID") %>%
      dplyr::filter(is.finite(Expression), is.finite(dose))
    req(nrow(datos) > 1)

    ggplot2::ggplot(datos, ggplot2::aes(x = dose, y = Expression)) +
      ggplot2::geom_smooth(method = "lm", se = FALSE, colour = QC_LINE,
                           linewidth = 0.8, formula = y ~ x) +
      ggplot2::geom_point(colour = QC_POINT, alpha = 0.85, size = 2.2) +
      ggplot2::scale_x_log10() +
      ggplot2::labs(title = "Positive control response", subtitle = panel_subtitle(),
                    x = "Concentration (log)", y = "Signal") +
      qc_theme()
  })

  # ---- Reference table and export ----------------------------------------

  output$qc_thresholds <- renderTable({
    QC_THRESHOLDS %>%
      dplyr::transmute(
        Metric = label,
        `What it measures` = meaning,
        Pass = ifelse(higher_is_better, paste("≥", good), paste("≤", good)),
        Borderline = ifelse(higher_is_better,
                            paste(warn, "–", good), paste(good, "–", warn)),
        Fail = ifelse(higher_is_better, paste("<", warn), paste(">", warn))
      )
  }, width = "100%")

  output$qc_download <- downloadHandler(
    filename = function() paste0("array_quality_", Sys.Date(), ".csv"),
    content = function(file) {
      readr::write_csv(
        dplyr::left_join(metrics(), verdicts(), by = c("sample", "channel")), file
      )
    }
  )
}
