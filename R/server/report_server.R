# =============================================================================
# REPORT SERVER: collects what the session computed into the list that
# build_pdf_report() / build_results_workbook() (R/server/report.R) draw.
# =============================================================================
# `src` is a list of the app's reactives and helpers. Every section is built
# on its own and turns into NULL when its step has not run, so a report can be
# downloaded at any point and simply says what is still missing.
# =============================================================================

# Peptide feature name "IgE_p_19_Arah2" -> isotype, number, protein
parse_feature <- function(x) {
  m <- stringr::str_match(x, "^([A-Za-z][A-Za-z0-9]*)_p[ _.-]?(\\d+)_(.+)$")
  data.frame(feature = x, isotype = m[, 2], number = as.integer(m[, 3]), protein = m[, 4], stringsAsFactors = FALSE)
}

setup_report_server <- function(input, output, session, src) {
  safe <- function(expr) tryCatch(expr, error = function(e) NULL)
  pkg_version <- function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(e) "not installed")

  settings <- reactive({
    db <- safe(src$active_database())
    labels <- safe(src$channel_labels())
    used <- safe(src$selected_channels())
    models <- c("C5.0", "Random Forest", "SVM", "XGBoost")[c(isTRUE(input$ml_use_c50), isTRUE(input$ml_use_rf),
                                                              isTRUE(input$ml_use_svm), isTRUE(input$ml_use_xgboost))]
    list(
      "Data input" = c("Input mode" = input$input_mode,
                       "Scan files" = length(safe(list_array_files(src$path1())) %||% character(0)),
                       "Channels analysed" = if (length(used)) paste0("channel ", used, " = ", labels[used], collapse = "; ") else NA,
                       "Spot value" = if (identical(input$spot_metric, "difference")) "signal - background" else "log2(signal / background)"),
      "Controls" = list("Negative controls" = input$negative_controls, "Positive controls" = input$positive_controls),
      "Normalization" = c("Within each array" = input$normalization_method,
                          "Between arrays" = if (isTRUE(input$enable_inter_norm)) input$inter_norm_method else "off",
                          "Missing-value imputation" = input$imputation_method),
      "Clinical table" = list("File" = if (!is.null(input$db_fileinput)) input$db_fileinput$name else "example data",
                              "Sample ID column" = input$sample_id_col,
                              "Columns analysed" = setdiff(names(db), "id")),
      "Peptide analysis" = c("Target variable" = input$stats, "Analysis" = input$analysis_type,
                             "FDR threshold" = input$results_pval_threshold, "AUC threshold" = input$results_auc_threshold,
                             "Volcano contrast" = if (!is.null(input$volcano_level_a)) paste(input$volcano_level_b, "vs", input$volcano_level_a) else NA,
                             "Candidate rule" = if (identical(input$ml_selection_method, "top_n")) paste("top", input$ml_top_n) else paste("AUC >=", input$ml_auc_threshold)),
      "Machine learning" = list("Target variable" = input$ml_target_var,
                                "Validation" = if (identical(input$ml_validation_mode, "nested")) "nested cross-validation (5 outer folds)" else "independent test set, 70/30 stratified hold-out",
                                "Random seed" = input$ml_seed, "Cross-validation in training" = "5-fold x 3 repeats",
                                "Recursive feature elimination" = isTRUE(input$ml_use_rfe),
                                "Hyperparameter tuning" = isTRUE(input$ml_use_tuning),
                                "Models" = models, "Consensus: top N per model" = input$consensus_top_n %||% 20)
    )
  })

  input_section <- reactive({
    pd <- safe(src$processed_data()); db <- safe(src$active_database())
    if (is.null(pd)) return(NULL)
    target <- input$stats %||% input$ml_target_var
    matched <- if (!is.null(db)) db[db$id %in% pd$id, , drop = FALSE] else NULL
    raw <- safe(src$raw_pepdata())
    list(arrays = nrow(pd), analytes = length(safe(src$available_analytes())), features = ncol(pd) - 1,
         matched = if (!is.null(matched)) nrow(matched),
         groups = if (!is.null(matched) && !is.null(target) && target %in% names(matched)) table(matched[[target]]),
         missing = if (!is.null(raw)) sprintf("%d values (%.2f %%)", sum(is.na(raw[, -1])), 100 * mean(is.na(raw[, -1]))),
         clinical = if (!is.null(db)) data.frame(
           Column = setdiff(names(db), "id"),
           Type = vapply(setdiff(names(db), "id"), function(c) if (is.numeric(db[[c]])) "numeric" else "categorical", ""),
           Values = vapply(setdiff(names(db), "id"), function(c) { v <- db[[c]]
             if (is.numeric(v)) sprintf("%s to %s", signif(min(v, na.rm = TRUE), 3), signif(max(v, na.rm = TRUE), 3))
             else paste(utils::head(names(sort(table(v), decreasing = TRUE)), 4), collapse = ", ") }, ""),
           Missing = vapply(setdiff(names(db), "id"), function(c) sum(is.na(db[[c]])), 0L),
           check.names = FALSE, row.names = NULL))
  })

  qc_section <- reactive({
    q <- src$qc_results
    v <- safe(q$verdicts()); if (is.null(v)) return(NULL)
    g <- safe(q$graded())
    bad <- v[v$verdict != "green", ]
    problems <- if (nrow(bad)) do.call(rbind, lapply(seq_len(nrow(bad)), function(i) {
      gi <- g[g$sample == bad$sample[i] & g$channel == bad$channel[i] & g$grade %in% c("red", "amber"), ]
      data.frame(Array = bad$sample[i], Channel = bad$channel[i], Verdict = ifelse(bad$verdict[i] == "red", "fail", "borderline"),
                 `Metrics out of range` = paste0(gi$label, " = ", signif(gi$value, 3), collapse = "; "), check.names = FALSE)
    }))
    list(verdicts = v, graded = g, problems = problems,
         metrics = safe(dplyr::left_join(q$metrics(), v, by = c("sample", "channel"))),
         normalization = safe(src$norm_diagnostics()$message),
         thresholds = data.frame(Metric = QC_THRESHOLDS$label,
                                 Pass = ifelse(QC_THRESHOLDS$higher_is_better, paste(">=", QC_THRESHOLDS$good), paste("<=", QC_THRESHOLDS$good)),
                                 Fail = ifelse(QC_THRESHOLDS$higher_is_better, paste("<", QC_THRESHOLDS$warn), paste(">", QC_THRESHOLDS$warn))))
  })

  stats_section <- reactive({
    t <- safe(src$tests()); if (is.null(t)) return(NULL)
    reg <- safe(src$reg_models())
    res <- if (!is.null(reg)) dplyr::left_join(t, dplyr::rename(reg, peptide = Peptide), by = "peptide") else t
    top <- res[order(res$p.adj, res$p.value), intersect(c("peptide", "coefficient", "p.value", "p.adj", "AUC", "Accuracy"), names(res))]
    names(top) <- sub("coefficient", "effect", names(top))
    vol <- safe(src$volcano_data())
    list(target = input$stats, results = res, top = top,
         volcano = if (!is.null(vol)) vol[, intersect(c("peptide", "isotype", "log2FC", "p", "padj", "status"), names(vol))],
         volcano_label = if (!is.null(input$volcano_level_a)) paste0("Mean difference (", input$volcano_level_b, " - ", input$volcano_level_a, ")"))
  })

  ml_section <- reactive({
    runs <- src$ml_runs()
    rows <- Filter(Negate(is.null), lapply(names(runs), function(nm) {
      r <- runs[[nm]]
      if (is.null(r) || isTRUE(r$skipped) || is.null(r$metrics)) return(NULL)
      m <- r$metrics
      data.frame(Model = nm, AUC = m$auc %||% NA, AUC_low = m$auc_low %||% NA, AUC_high = m$auc_high %||% NA,
                 Accuracy = m$accuracy %||% NA, Kappa = m$kappa %||% NA, Sensitivity = m$sensitivity %||% NA,
                 Specificity = m$specificity %||% NA, CV_AUC = r$cv_metrics$auc %||% NA)
    }))
    if (!length(rows)) return(NULL)
    first <- Filter(function(r) !is.null(r$validation_label), runs)[[1]]
    p <- safe(src$ml_prep())
    partition <- if (!is.null(p) && identical(p$mode, "holdout"))
      data.frame(id = c(rownames(p$train), rownames(p$test)), partition = rep(c("train", "test"), c(nrow(p$train), nrow(p$test))))
    importance <- Filter(Negate(is.null), lapply(runs, function(r) safe(format_varimp_df(r$varimp, top_n = 100))))
    list(validation = do.call(rbind, rows), label = first$validation_label, consensus = safe(src$ml_consensus()),
         importance = importance, partition = partition,
         split = if (!is.null(p)) list("Mode" = p$mode, "Training samples" = nrow(p$train),
                                       "Test samples" = if (!is.null(p$test)) nrow(p$test), "Candidates" = length(p$candidates)))
  })

  annotation_tbl <- reactive({
    path <- if (!is.null(input$protein_annotation)) input$protein_annotation$datapath else safe(src$example_annotation())
    if (!is.null(path)) safe(read_peptide_annotation(path))
  })

  protein_section <- reactive({
    bm <- safe(src$consensus_biomarkers()); if (!length(bm)) return(NULL)
    f <- parse_feature(bm)
    ann <- annotation_tbl()
    if (is.null(ann)) return(f[, c("feature", "isotype", "protein", "number")])
    ann$key <- paste(comparable_name(ann$protein), ann$number)
    f$key <- paste(comparable_name(f$protein), f$number)
    out <- dplyr::left_join(f, ann[, intersect(c("key", "accession", "start", "end", "peptide"), names(ann))], by = "key")
    out[, intersect(c("feature", "isotype", "protein", "accession", "number", "start", "end", "peptide"), names(out))]
  })

  # Every annotated peptide of the proteins that carry a consensus biomarker,
  # with its group difference: the data behind the linear epitope maps
  epitope_section <- reactive({
    bm <- safe(src$consensus_biomarkers()); res <- safe(src$tests()); ann <- annotation_tbl()
    if (!length(bm) || is.null(res) || is.null(ann) || !"coefficient" %in% names(res)) return(NULL)
    f <- parse_feature(res$peptide)
    f$effect <- res$coefficient; f$padj <- res$p.adj
    f <- f[!is.na(f$number), ]
    f$key <- paste(comparable_name(f$protein), f$number)
    ann$key <- paste(comparable_name(ann$protein), ann$number)
    d <- merge(f, ann[, intersect(c("key", "accession", "start", "end"), names(ann))], by = "key")
    if (!all(c("start", "end") %in% names(d))) return(NULL)
    d$biomarker <- d$feature %in% bm
    d <- d[d$protein %in% unique(d$protein[d$biomarker]), ]
    d[order(d$protein, d$isotype, d$start), intersect(c("protein", "accession", "isotype", "number", "start", "end", "effect", "padj", "biomarker"), names(d))]
  })

  # Pictures of the protein views sent by www/report_snapshots.js (PNG data URIs)
  snapshots <- reactive({
    dec <- function(uri) if (is.character(uri) && startsWith(uri, "data:image/png;base64,"))
      safe(png::readPNG(base64enc::base64decode(sub("^data:image/png;base64,", "", uri))))
    raw <- input$report_snapshots
    if (is.null(raw) || !nzchar(raw)) return(list())
    lapply(jsonlite::fromJSON(raw, simplifyVector = FALSE), function(s) list(protein = s$protein, accession = s$accession, pdb = s$pdb, isotype = s$isotype,
                                                    group = s$group, mode = s$mode, view3d = dec(s$view3d), map2d = dec(s$map2d)))
  })

  methods_text <- reactive({
    s <- settings()
    ml <- s[["Machine learning"]]
    paste0(
      "Scanner files were read with their quality flags; each spot was summarised as ", s[["Data input"]][["Spot value"]],
      ". Within each array and channel, values were normalised against the negative-control spots (",
      paste(input$negative_controls %||% "none", collapse = ", "), ") with the '", input$normalization_method %||% "?",
      "' method; between arrays: ", s$Normalization[["Between arrays"]], ". Missing values were imputed by ",
      input$imputation_method %||% "?", ". Every array was graded on six quality metrics. ",
      "Each peptide was compared between the groups of '", input$stats %||% "?",
      "' with a linear model and Benjamini-Hochberg FDR, and its discriminative AUC was estimated by logistic regression. ",
      "Supervised models (", paste(ml$Models, collapse = ", "), ") were trained with ", ml$Validation,
      " (seed ", input$ml_seed %||% "?", "); imputation, candidate selection, feature elimination and tuning used training samples only, ",
      "and performance is reported on held-out samples with DeLong 95% confidence intervals."
    )
  })

  payload <- reactive({
    list(meta = list(date = format(Sys.time(), "%Y-%m-%d %H:%M"), session = log_sid(),
                     app_version = Sys.getenv("MICROARRAI_VERSION", "dev"),
                     r_version = R.version.string,
                     packages = data.frame(Package = c("shiny", "caret", "pROC", "C50", "randomForest", "kernlab", "xgboost",
                                                       "mixOmics", "vegan", "dbscan", "ggplot2"),
                                           Version = vapply(c("shiny", "caret", "pROC", "C50", "randomForest", "kernlab", "xgboost",
                                                              "mixOmics", "vegan", "dbscan", "ggplot2"), pkg_version, ""))),
         settings = safe(settings()), input = safe(input_section()), qc = safe(qc_section()),
         stats = safe(stats_section()), ml = safe(ml_section()), protein = safe(protein_section()),
         epitopes = safe(epitope_section()), snapshots = safe(snapshots()),
         methods = safe(methods_text()))
  })

  describe <- function(r) list(qc = !is.null(r$qc), stats = !is.null(r$stats), ml = !is.null(r$ml), protein = !is.null(r$protein),
                               pictures = length(r$snapshots) > 0)

  output$report_pdf <- downloadHandler(
    filename = function() paste0("MicroarrAI_report_", format(Sys.time(), "%Y%m%d_%H%M"), ".pdf"),
    content = function(file) {
      r <- payload()
      ok <- run_step("REPORT", "building the PDF report", build_pdf_report(file, r), sections = names(Filter(isTRUE, describe(r))),
                     protein_pictures = length(Filter(function(s) !is.null(s$view3d), r$snapshots)),
                     hint = "The report is built from what has been computed; try again after the step named above finishes.")
      if (is.null(ok)) {   # still hand the user a file that says what went wrong
        grDevices::pdf(file); grid::grid.text("The report could not be built. See the application log."); grDevices::dev.off()
      }
    }
  )

  output$results_xlsx <- downloadHandler(
    filename = function() paste0("MicroarrAI_results_", format(Sys.time(), "%Y%m%d_%H%M"), ".xlsx"),
    content = function(file) {
      run_step("REPORT", "building the results workbook", build_results_workbook(file, payload()))
    }
  )

  # Report dialog: what is in it right now, and the two downloads
  observeEvent(input$open_report, {
    r <- describe(payload())
    item <- function(ok, txt) tags$li(class = if (ok) "ok" else "todo", txt)
    showModal(modalDialog(
      title = "Download the analysis", easyClose = TRUE, footer = modalButton("Close"),
      tags$p("The report and the workbook collect the parameters you entered, the input data and every result computed so far."),
      tags$ul(class = "report-status",
              item(TRUE, "Parameters and input data"), item(r$qc, "Quality control scorecard"),
              item(r$stats, "Differential analysis and top peptides"), item(r$ml, "Model validation and consensus biomarkers"),
              item(r$protein, "Biomarkers on their proteins and linear epitope maps"),
              item(r$pictures, "Pictures of the 3D and 2D protein views (open a protein in the 3D tab first)")),
      tags$div(class = "report-actions",
               downloadButton("report_pdf", "Report (PDF)", class = "btn-report"),
               downloadButton("results_xlsx", "All results (Excel)", class = "btn-report alt"))
    ))
  })
}
