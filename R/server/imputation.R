# =============================================================================
# IMPUTATION.R
# Missing-value diagnostics and imputation for the peptide/protein expression
# matrix.
#
# Rationale: NA values come from spots removed by quality flags. They are NOT
# "below detection" (so zero / minimum imputation is misleading) and leaving
# them as NA causes whole samples to be dropped during ML. We therefore impute
# them using methods that borrow information from similar peptides/samples.
#
# Methods (few, robust):
#   - "knn"    : k-nearest-neighbour imputation (Troyanskaya 2001), the
#                microarray standard. Uses Bioconductor 'impute' when available,
#                with a base-R fallback.
#   - "rf"     : Random-Forest (missForest-style) iterative imputation using
#                'randomForest'. Captures non-linear structure; slower.
#   - "median" : per-peptide median. Fast, robust fallback.
#
# All functions operate on the wide table (one row per sample, `id` + numeric
# peptide columns) and leave non-numeric columns untouched.
# =============================================================================


#' Missing-value Statistics for the Expression Matrix
#'
#' @param data Tibble/data.frame. One row per sample; numeric peptide columns.
#' @return List with NA diagnostics (computed on numeric columns only).
compute_na_stats <- function(data) {
  num_cols <- names(data)[vapply(data, is.numeric, logical(1))]
  if (length(num_cols) == 0) {
    return(list(n_peptides = 0, n_samples = nrow(data), n_na = 0, pct_na = 0,
                n_peptides_with_na = 0, n_samples_with_na = 0))
  }
  m <- as.matrix(data[, num_cols, drop = FALSE])
  total <- length(m)
  n_na <- sum(is.na(m))

  list(
    n_peptides         = ncol(m),
    n_samples          = nrow(m),
    n_na               = n_na,
    pct_na             = if (total > 0) 100 * n_na / total else 0,
    n_peptides_with_na = sum(colSums(is.na(m)) > 0),
    n_samples_with_na  = sum(rowSums(is.na(m)) > 0)
  )
}


#' Per-peptide Median Imputation
#'
#' @param mat Numeric matrix. Rows = samples, columns = peptides.
#' @return Matrix with NAs replaced by the column (peptide) median.
impute_median_matrix <- function(mat) {
  for (j in seq_len(ncol(mat))) {
    na <- is.na(mat[, j])
    if (any(na)) {
      med <- median(mat[, j], na.rm = TRUE)
      if (is.na(med)) med <- 0  # whole peptide missing -> neutral fallback
      mat[na, j] <- med
    }
  }
  mat
}


#' k-Nearest-Neighbour Imputation
#'
#' @param mat Numeric matrix. Rows = samples, columns = peptides.
#' @param k Integer. Number of neighbours (default 10).
#' @return Imputed matrix.
#' @details Uses impute::impute.knn (rows must be features), so the matrix is
#' transposed to peptides x samples before imputation and back afterwards. Each
#' missing peptide value is filled from the k most similar peptides. Falls back
#' to median imputation if the 'impute' package is unavailable.
impute_knn_matrix <- function(mat, k = 10) {
  if (requireNamespace("impute", quietly = TRUE)) {
    k <- max(1L, min(as.integer(k), nrow(t(mat)) - 1L))
    res <- tryCatch(
      impute::impute.knn(t(mat), k = k, rng.seed = 362436069),
      error = function(e) NULL
    )
    if (!is.null(res)) {
      return(t(res$data))
    }
    warning("impute.knn failed; falling back to median imputation.")
  } else {
    warning("Package 'impute' not available; falling back to median imputation.")
  }
  impute_median_matrix(mat)
}


#' Random-Forest (missForest-style) Imputation
#'
#' @param mat Numeric matrix. Rows = samples, columns = peptides.
#' @param seed Integer. RNG seed for reproducibility.
#' @param max_iter Integer. Maximum refinement iterations (default 5).
#' @param ntree Integer. Trees per forest (default 100).
#' @return Imputed matrix.
#' @details Iteratively predicts each column's missing entries from all other
#' columns using random forests, refreshing until the change between iterations
#' is negligible. Falls back to kNN if 'randomForest' is unavailable.
impute_rf_matrix <- function(mat, seed = 123, max_iter = 5, ntree = 100) {
  if (!requireNamespace("randomForest", quietly = TRUE)) {
    warning("Package 'randomForest' not available; falling back to kNN imputation.")
    return(impute_knn_matrix(mat))
  }
  set.seed(seed)
  na_mask <- is.na(mat)
  filled <- impute_median_matrix(mat)  # initialize

  cols_with_na <- which(colSums(na_mask) > 0)
  if (length(cols_with_na) == 0) return(filled)
  # impute least-missing columns first (missForest ordering)
  ord <- cols_with_na[order(colSums(na_mask)[cols_with_na])]

  prev <- filled
  for (iter in seq_len(max_iter)) {
    for (j in ord) {
      mis <- na_mask[, j]
      obs <- !mis
      if (!any(mis)) next
      x_train <- filled[obs, -j, drop = FALSE]
      y_train <- filled[obs, j]
      x_pred  <- filled[mis, -j, drop = FALSE]
      if (nrow(x_train) < 5 || ncol(x_train) < 1) next  # too little to model
      rf <- randomForest::randomForest(x = x_train, y = y_train, ntree = ntree)
      filled[mis, j] <- predict(rf, x_pred)
    }
    denom <- sum(filled^2, na.rm = TRUE)
    diff <- if (denom > 0) sum((filled - prev)^2, na.rm = TRUE) / denom else 0
    if (is.finite(diff) && diff < 1e-4) break
    prev <- filled
  }
  filled
}


#' Impute Missing Values in the Wide Expression Table
#'
#' @param data Tibble/data.frame. One row per sample; `id` + numeric columns.
#' @param method Character. "knn", "rf", "median" or "zero".
#' @param k Integer. Neighbours for kNN (default 10).
#' @param seed Integer. RNG seed for RF.
#' @return The table with missing numeric values imputed.
#' @details "zero" is retained only as an explicit, documented baseline (the old
#' behaviour); it is biased and not recommended. Non-numeric columns (e.g. `id`)
#' pass through unchanged. If there are no NAs the data is returned as-is.
impute_missing <- function(data, method = c("knn", "rf", "median", "zero"),
                           k = 10, seed = 123) {
  method <- match.arg(method)

  num_cols <- names(data)[vapply(data, is.numeric, logical(1))]
  if (length(num_cols) == 0) return(data)

  mat <- as.matrix(data[, num_cols, drop = FALSE])  # samples x peptides
  if (!any(is.na(mat))) return(data)

  imputed <- switch(
    method,
    zero   = { mat[is.na(mat)] <- 0; mat },
    median = impute_median_matrix(mat),
    knn    = impute_knn_matrix(mat, k = k),
    rf     = impute_rf_matrix(mat, seed = seed)
  )

  data[, num_cols] <- as.data.frame(imputed)
  data
}


#' Impute Missing Values in a Mixed-type Table
#'
#' Reuses impute_missing() (knn/rf/median) for numeric columns and fills
#' categorical columns with their most frequent value (mode). Used to impute
#' clinical metadata, which mixes numeric variables and factors.
#'
#' @param data Tibble/data.frame with numeric and/or categorical columns.
#' @param method Character. Numeric-column method: "knn", "rf", "median", "zero".
#' @return The table with all missing values imputed.
impute_missing_mixed <- function(data, method = c("knn", "rf", "median", "zero")) {
  data <- impute_missing(data, method = match.arg(method))  # numeric columns
  for (j in names(data)) {
    x <- data[[j]]
    if (!is.numeric(x) && anyNA(x)) data[[j]][is.na(x)] <- names(which.max(table(x)))
  }
  data
}
