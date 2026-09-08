# ============================================================================
# MicroarrAI - Array quality control
# ============================================================================
# Per-array metrics computed from spots the pipeline already reads, plus the
# grading that turns each number into green / amber / red.
#
# Thresholds are stated once here and reused by the UI, so the same rule
# drives the heatmap, the summary cards and the normalization warning.
# ============================================================================

#' Quality thresholds
#'
#' `good` and `warn` are the cut points; `higher_is_better` says which side is
#' healthy. The replicate cut points follow the reproducibility published for
#' overlapping-peptide allergen arrays (R = 0.92-0.96).
QC_THRESHOLDS <- tibble::tribble(
  ~metric,        ~label,                    ~good, ~warn, ~higher_is_better, ~meaning,
  "replicates",   "Replicate agreement (R)",  0.90,  0.80,  TRUE,
  "Correlation between the two spots of each peptide on the same array. Low means the array itself is not reproducible, so no downstream difference can be trusted.",
  "dose",         "Positive control slope",   0.80,  0.40,  TRUE,
  "Correlation between the concentration of the positive control dilution series and its signal. Low means the assay did not respond, regardless of what the peptides show.",
  "snr",          "Signal / noise",           3.00,  1.50,  TRUE,
  "Median spot signal divided by its local background. Around 1 the channel is measuring background, not binding.",
  "background",   "Background stability",     1.50,  2.00,  FALSE,
  "How far this array's blank-spot spread sits from the cohort median, as a ratio. High means its blanks are unusually noisy, which distorts any control-based normalization.",
  "missing",      "Missing spots (%)",        2.00,  5.00,  FALSE,
  "Share of spots with no usable value (flagged, absent or non-finite).",
  "saturation",   "Saturated spots (%)",      1.00,  5.00,  FALSE,
  "Share of spots at the scanner ceiling. Their true value is unknown, so strong binders get censored downwards."
)


#' Grade a value against its metric thresholds
#'
#' @param metric Character. Metric name present in QC_THRESHOLDS
#' @param value Numeric vector
#' @return Character vector: "green", "amber", "red" or NA when value is NA
grade_metric <- function(metric, value) {
  rule <- QC_THRESHOLDS[QC_THRESHOLDS$metric == metric, ]
  if (nrow(rule) == 0) return(rep(NA_character_, length(value)))

  if (rule$higher_is_better) {
    dplyr::case_when(
      is.na(value)        ~ NA_character_,
      value >= rule$good  ~ "green",
      value >= rule$warn  ~ "amber",
      TRUE                ~ "red"
    )
  } else {
    dplyr::case_when(
      is.na(value)        ~ NA_character_,
      value <= rule$good  ~ "green",
      value <= rule$warn  ~ "amber",
      TRUE                ~ "red"
    )
  }
}


#' Per-array quality metrics
#'
#' @param spots Tibble. Spot-level data with muestra/sample, ID, channel,
#'   Expression and the optional quality columns from read_microarray_file()
#' @param negative_controls Character vector. IDs treated as blank
#' @param positive_controls Tibble with `ID` and `dose`, the dilution series
#'   used to check the assay responded. NULL skips that metric.
#' @return One row per sample and channel with the raw metric values
#' Positional peptide IDs, with or without the isotype prefix
#'
#' Raw spot IDs look like "p_9_k-cas"; once processed they carry the channel
#' label ("IgE_p_9_k-cas"). Both must match.
PEPTIDE_ID_PATTERN <- "(^|_)p[ _.-]?\\d+_"


compute_array_quality <- function(spots,
                                  negative_controls = "PBS_1X",
                                  positive_controls = NULL) {

  peptides <- dplyr::filter(spots, grepl(PEPTIDE_ID_PATTERN, ID))

  if (nrow(peptides) == 0) {
    stop("No positional peptide IDs found (expected names like 'p_9_b-lac').")
  }

  # Duplicate spots of the same analyte are technical replicates: their
  # agreement is the most direct reproducibility measure available.
  replicates <- peptides %>%
    dplyr::group_by(sample, channel, ID) %>%
    dplyr::mutate(replicate = dplyr::row_number()) %>%
    dplyr::ungroup() %>%
    dplyr::filter(replicate <= 2) %>%
    dplyr::select(sample, channel, ID, replicate, Expression) %>%
    tidyr::pivot_wider(names_from = replicate, values_from = Expression,
                       names_prefix = "rep") %>%
    dplyr::group_by(sample, channel) %>%
    dplyr::summarise(
      replicates = suppressWarnings(stats::cor(rep1, rep2, use = "complete.obs")),
      .groups = "drop"
    )

  general <- spots %>%
    dplyr::group_by(sample, channel) %>%
    dplyr::summarise(
      snr        = if ("snr" %in% names(spots)) stats::median(snr, na.rm = TRUE) else NA_real_,
      saturation = if ("saturation" %in% names(spots)) 100 * mean(saturation > 0, na.rm = TRUE) else NA_real_,
      missing    = 100 * mean(!is.finite(Expression)),
      blank_mad  = stats::mad(Expression[ID %in% negative_controls], na.rm = TRUE),
      blank_level = stats::median(Expression[ID %in% negative_controls], na.rm = TRUE),
      .groups = "drop"
    )

  # Background stability: how far this array's blank spread sits from the
  # cohort, as a ratio. A blank three times noisier than its peers distorts
  # every control-based normalization.
  general <- general %>%
    dplyr::group_by(channel) %>%
    dplyr::mutate(background = blank_mad / stats::median(blank_mad, na.rm = TRUE)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(background = pmax(background, 1 / background))

  metrics <- dplyr::left_join(general, replicates, by = c("sample", "channel"))

  if (!is.null(positive_controls) && nrow(positive_controls) > 0) {
    dose <- spots %>%
      dplyr::inner_join(positive_controls, by = "ID") %>%
      dplyr::group_by(sample, channel) %>%
      dplyr::summarise(
        dose = suppressWarnings(stats::cor(dose, Expression, method = "spearman",
                                           use = "complete.obs")),
        .groups = "drop"
      )
    metrics <- dplyr::left_join(metrics, dose, by = c("sample", "channel"))
  } else {
    metrics$dose <- NA_real_
  }

  metrics
}


#' Long, graded view of the metrics, ready to plot
#'
#' @param metrics Tibble from compute_array_quality()
#' @return One row per sample, channel and metric with `value` and `grade`
grade_array_quality <- function(metrics) {
  metrics %>%
    dplyr::select(sample, channel, dplyr::all_of(QC_THRESHOLDS$metric)) %>%
    tidyr::pivot_longer(dplyr::all_of(QC_THRESHOLDS$metric),
                        names_to = "metric", values_to = "value") %>%
    dplyr::group_by(metric) %>%
    dplyr::mutate(grade = grade_metric(dplyr::first(metric), value)) %>%
    dplyr::ungroup() %>%
    dplyr::left_join(dplyr::select(QC_THRESHOLDS, metric, label), by = "metric")
}


#' One verdict per array: the worst grade it earned
#'
#' @param graded Tibble from grade_array_quality()
#' @return One row per sample and channel with `verdict` and counts
summarise_array_quality <- function(graded) {
  graded %>%
    dplyr::group_by(sample, channel) %>%
    dplyr::summarise(
      red   = sum(grade == "red", na.rm = TRUE),
      amber = sum(grade == "amber", na.rm = TRUE),
      green = sum(grade == "green", na.rm = TRUE),
      verdict = dplyr::case_when(red > 0 ~ "red", amber > 0 ~ "amber", TRUE ~ "green"),
      .groups = "drop"
    )
}


#' Wide matrix of raw peptide signal, for before/after comparisons
#'
#' @param spots Tibble. Spot-level data with sample, ID, channel, Expression
#' @return Tibble with `id` plus one column per peptide, averaged over channels
#'   and replicates. NULL when there are no spots.
raw_peptide_matrix <- function(spots) {
  if (is.null(spots) || nrow(spots) == 0) return(NULL)

  spots %>%
    dplyr::filter(grepl(PEPTIDE_ID_PATTERN, ID), is.finite(Expression)) %>%
    dplyr::group_by(sample, channel, ID) %>%
    dplyr::summarise(value = mean(Expression), .groups = "drop") %>%
    dplyr::mutate(feature = paste0(channel, "_", ID)) %>%
    dplyr::select(id = sample, feature, value) %>%
    tidyr::pivot_wider(names_from = feature, values_from = value)
}


#' Does the chosen normalization actually make arrays comparable?
#'
#' @param before,after Tibbles. `id` + numeric features, same shape
#' @return List with the dispersion before and after, whether it improved, and
#'   a message ready to show the user
normalization_diagnostics <- function(before, after) {
  if (is.null(before) || is.null(after)) return(NULL)

  spread <- function(df) {
    values <- as.matrix(df[, vapply(df, is.numeric, logical(1)), drop = FALSE])
    stats::sd(apply(values, 1, stats::median, na.rm = TRUE), na.rm = TRUE)
  }

  sd_before <- spread(before)
  sd_after  <- spread(after)
  improved  <- is.finite(sd_after) && is.finite(sd_before) && sd_after <= sd_before

  list(
    sd_before = sd_before,
    sd_after  = sd_after,
    improved  = improved,
    message = if (improved) {
      sprintf("Between-array spread went from %.3f to %.3f.", sd_before, sd_after)
    } else {
      sprintf(paste("Between-array spread went UP, from %.3f to %.3f.",
                    "Scaling each array by its own control spread does not put arrays",
                    "on a common scale; add an inter-sample normalization step."),
              sd_before, sd_after)
    }
  )
}
