# =============================================================================
# NORMALIZATION.R
# Self-contained, dependency-free normalization methods for peptide/protein
# microarrays.
#
# Two stages, each with robust, well-implemented methods only:
#
#   1. Intra-sample (within array)  -> normalize_zscore_controls()
#        Robust z-score against negative-control spots (median / MAD).
#        Expresses every spot in units of robust SDs above the array's own
#        background level. This is the method historically used in this lab.
#
#   2. Inter-sample (between arrays) -> apply_inter_sample_normalization()
#        Makes whole samples comparable to each other. Two robust options:
#          - "robust"   : per-sample median centering + MAD scaling (row-wise)
#          - "quantile" : Bolstad et al. (2003) quantile normalization,
#                         implemented in base R (no preprocessCore), NA-tolerant
#
# No third-party normalization back-ends are used: everything below is base R.
# =============================================================================


# -----------------------------------------------------------------------------
# Intra-sample: robust z-score against negative controls
# -----------------------------------------------------------------------------

#' Robust Z-score Normalization Against Negative Controls
#'
#' Normalizes a single expression vector (one channel of one array) so that the
#' negative-control spots define the zero point and the unit of spread.
#'
#' @param expression Numeric vector. Raw (log-ratio) expression values.
#' @param ids Character vector. Analyte IDs, parallel to `expression`.
#' @param negative_controls Character vector. IDs of the negative-control spots.
#' @return Numeric vector. `(expression - median_ctrl) / mad_ctrl`.
#' @details
#' - Uses the median and MAD of the control spots (robust to outliers).
#' - Falls back to SD when the control MAD is zero (e.g. very few controls).
#' - Inf/-Inf inputs are turned into NA so they propagate as missing values.
normalize_zscore_controls <- function(expression, ids, negative_controls) {
  if (is.null(negative_controls) || length(negative_controls) == 0) {
    stop("Z-score normalization requires negative_controls.")
  }

  # Inf/-Inf (e.g. log of zero background) become NA and propagate downstream
  expression[is.infinite(expression)] <- NA

  control_mask <- ids %in% negative_controls
  if (sum(control_mask) == 0) {
    stop("No negative controls found in data. Check control IDs.")
  }

  control_vals <- expression[control_mask]
  median_ctrl <- median(control_vals, na.rm = TRUE)
  mad_ctrl <- mad(control_vals, na.rm = TRUE)  # scaled by 1.4826 (normal-consistent)

  # Fallback to SD if MAD collapses to zero (too few / identical controls)
  if (is.na(mad_ctrl) || mad_ctrl == 0) {
    warning("MAD of controls is zero. Using standard deviation instead.")
    mad_ctrl <- sd(control_vals, na.rm = TRUE)
  }

  if (is.na(mad_ctrl) || mad_ctrl == 0) {
    stop("Cannot normalize: negative controls have zero variance. ",
         "Check your control selection.")
  }

  (expression - median_ctrl) / mad_ctrl
}


# -----------------------------------------------------------------------------
# Inter-sample helpers
# -----------------------------------------------------------------------------

#' Quantile Normalization (Bolstad et al. 2003), base R, NA-tolerant
#'
#' Forces every column of `mat` to share a common distribution. The reference
#' distribution is the average of the per-column quantiles evaluated on a common
#' probability grid; each column is then remapped onto it by rank.
#'
#' @param mat Numeric matrix. Columns are the units to be equalized.
#' @return Numeric matrix of the same shape, column distributions harmonized.
#' @details
#' Pure base-R implementation (no preprocessCore). Handles missing values by
#' ranking only the observed entries of each column and interpolating them onto
#' the reference distribution; NA positions are left as NA.
quantile_normalize <- function(mat) {
  mat <- as.matrix(mat)
  m <- nrow(mat)
  n <- ncol(mat)
  if (m < 2L || n < 2L) {
    return(mat)  # nothing meaningful to harmonize
  }

  # Reference distribution = mean of the order statistics across columns.
  # For NA-tolerance each column's observed order statistics are interpolated
  # onto a common length-m grid before averaging (limma::normalizeQuantiles
  # strategy). With no NAs this reduces to the canonical Bolstad reference.
  sorted <- vapply(seq_len(n), function(j) {
    x <- sort(mat[, j], na.last = NA)  # ascending, NAs dropped
    k <- length(x)
    if (k == 0L) return(rep(NA_real_, m))
    if (k == m)  return(x)
    approx(seq_len(k), x, xout = seq(1, k, length.out = m))$y
  }, numeric(m))
  ref <- rowMeans(sorted, na.rm = TRUE)

  # Remap each column onto the reference by rank (ties -> averaged ranks).
  out <- mat
  for (j in seq_len(n)) {
    x <- mat[, j]
    ok <- !is.na(x)
    k <- sum(ok)
    if (k == 0L) next
    r <- rank(x[ok], ties.method = "average")
    # Map rank r in [1, k] onto the reference grid position in [1, m]
    pos <- if (k == 1L) (m + 1) / 2 else 1 + (r - 1) * (m - 1) / (k - 1)
    out[ok, j] <- approx(seq_len(m), ref, xout = pos, rule = 2)$y
  }
  out
}


#' Robust Per-sample Normalization (median centering + MAD scaling)
#'
#' Centers and scales each sample (row) by its own median and MAD so that
#' between-array shifts and spread differences are removed while between-peptide
#' structure within a sample is preserved.
#'
#' @param mat Numeric matrix. Rows are samples, columns are peptides.
#' @return Numeric matrix of the same shape.
robust_per_sample_normalize <- function(mat) {
  mat <- as.matrix(mat)
  normalized <- t(apply(mat, 1, function(s) {
    med <- median(s, na.rm = TRUE)
    spread <- mad(s, na.rm = TRUE)
    if (is.na(spread) || spread == 0) spread <- sd(s, na.rm = TRUE)
    if (is.na(spread) || spread == 0) return(s - med)  # constant sample
    (s - med) / spread
  }))
  dimnames(normalized) <- dimnames(mat)
  normalized
}


# -----------------------------------------------------------------------------
# Inter-sample: public entry point operating on the wide expression table
# -----------------------------------------------------------------------------

#' Apply Inter-sample Normalization to the Wide Expression Table
#'
#' Operates across samples to remove technical between-array variation. Acts only
#' on numeric peptide columns; the `id` column (and any other non-numeric column)
#' is passed through untouched.
#'
#' @param data Tibble/data.frame. One row per sample; `id` + numeric peptide cols.
#' @param method Character. "robust" (per-sample median/MAD) or "quantile".
#' @return The same table with numeric columns normalized across samples.
#' @details
#' Both methods treat each ROW as a sample. For quantile normalization the
#' samples-as-rows matrix is transposed so samples become columns (the unit that
#' quantile normalization equalizes), then transposed back.
apply_inter_sample_normalization <- function(data, method = c("robust", "quantile")) {
  method <- match.arg(method)

  num_cols <- names(data)[vapply(data, is.numeric, logical(1))]
  if (length(num_cols) == 0) {
    return(data)
  }

  mat <- as.matrix(data[, num_cols, drop = FALSE])  # rows = samples, cols = peptides

  norm_mat <- switch(
    method,
    robust   = robust_per_sample_normalize(mat),
    # quantile equalizes columns -> transpose so samples are columns
    quantile = t(quantile_normalize(t(mat)))
  )

  data[, num_cols] <- as.data.frame(norm_mat)
  data
}
