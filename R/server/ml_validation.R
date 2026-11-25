# =============================================================================
# ML_VALIDATION.R
# Leak-free evaluation for the supervised ML tab.
#
# Everything that learns from the data (imputation, candidate selection, RFE,
# tuning, model fit) sees only training rows. Test rows are touched once, to
# score the finished model.
#
#   - "holdout": stratified 70/30 split; metrics on the 30 % test set.
#   - "nested" : outer stratified k-fold; the whole training recipe is repeated
#                inside each outer fold and the out-of-fold predictions are
#                pooled. For samples too small to spare a test set.
# =============================================================================

ML_TEST_PROP    <- 0.3   # share of samples held out as the independent test set
ML_DEFAULT_SEED <- 123
ML_CV_FOLDS     <- 5     # inner CV on the training partition (5 x 3)
ML_CV_REPEATS   <- 3
ML_OUTER_FOLDS  <- 5     # outer folds for nested CV


#' Stratified train/test split
#'
#' @param data Data frame with a factor `target` column
#' @param test_prop Share of samples held out (default 0.3)
#' @param seed RNG seed
#' @return List with `train` and `test` data frames
split_holdout <- function(data, test_prop = ML_TEST_PROP, seed = ML_DEFAULT_SEED) {
  set.seed(seed)
  idx <- caret::createDataPartition(data$target, p = 1 - test_prop, list = FALSE)[, 1]
  list(train = data[idx, , drop = FALSE], test = data[-idx, , drop = FALSE])
}


#' Impute training rows alone, then each test row against the training rows
#'
#' A test row never informs the training values or another test row: it is
#' imputed on its own, stacked under the already-complete training matrix.
impute_holdout <- function(train, test, method = "knn") {
  train <- impute_missing(train, method = method)
  if (anyNA(test[, vapply(test, is.numeric, logical(1))])) {
    test <- do.call(rbind, lapply(seq_len(nrow(test)), function(i)
      utils::tail(impute_missing(rbind(train, test[i, , drop = FALSE]), method = method), 1)))
  }
  list(train = train, test = test)
}


#' Per-peptide screen used to choose ML candidates
#'
#' Same criteria as the Peptide Analysis funnel: one lm() per peptide (F-test,
#' Benjamini-Hochberg) and the peptide's own discriminative AUC.
#'
#' @param data Data frame: `target` + numeric peptide columns
#' @return Data frame: peptide, p, p.adj, AUC
peptide_screen <- function(data) {
  peps <- setdiff(names(data), "target")
  nzv  <- caret::nearZeroVar(data[peps], names = TRUE)
  peps <- setdiff(peps, nzv)
  y <- data$target

  res <- do.call(rbind, lapply(peps, function(p) {
    x <- data[[p]]
    pval <- tryCatch(stats::anova(stats::lm(x ~ y))[["Pr(>F)"]][1], error = function(e) NA_real_)
    auc <- tryCatch(
      if (nlevels(y) == 2) as.numeric(pROC::auc(pROC::roc(y, x, direction = "auto", quiet = TRUE)))
      else as.numeric(pROC::multiclass.roc(y, x, quiet = TRUE)$auc),
      error = function(e) NA_real_)
    data.frame(peptide = p, p = pval, AUC = auc, stringsAsFactors = FALSE)
  }))
  res$p.adj <- stats::p.adjust(res$p, method = "BH")
  res
}


#' Choose candidate peptides on the data it is given (the training rows)
#'
#' @param data Data frame: `target` + numeric peptide columns
#' @param criteria List: `method` ("all", "top_n" or "auc_threshold"),
#'   `padj_max`, `auc_min` (funnel filters), `top_n`, `auc_threshold`
#' @return Character vector of peptide columns
select_candidates <- function(data, criteria = list(method = "all")) {
  peps <- setdiff(names(data), "target")
  if (is.null(criteria$method) || criteria$method == "all") return(peps)

  screen <- peptide_screen(data)
  ranked <- screen[!is.na(screen$p.adj) & screen$p < 0.05 &
                   screen$p.adj < criteria$padj_max &
                   !is.na(screen$AUC) & screen$AUC >= criteria$auc_min, ]
  ranked <- ranked[order(-(-log10(ranked$p.adj) + ranked$AUC)), ]

  chosen <- if (criteria$method == "top_n") utils::head(ranked$peptide, criteria$top_n)
            else ranked$peptide[ranked$AUC >= criteria$auc_threshold]
  # Nothing passes the filters on this partition: fall back to the strongest
  # peptides by AUC rather than training on an empty matrix.
  if (length(chosen) < 2) chosen <- utils::head(screen$peptide[order(-screen$AUC)], 10)
  chosen
}


#' Impute and select on the training rows, apply to the test rows
#'
#' @return List: `train`, `test` (target + candidates only) and `candidates`
prepare_partition <- function(train, test, impute_method = "knn", criteria = list(method = "all")) {
  imp <- impute_holdout(train, test, method = impute_method)
  candidates <- select_candidates(imp$train, criteria)
  keep <- c("target", candidates)
  list(train = imp$train[, keep, drop = FALSE], test = imp$test[, keep, drop = FALSE],
       candidates = candidates)
}


#' Classification metrics from observed classes, predictions and probabilities
#'
#' @param obs,pred Factors with the same levels
#' @param prob Data frame of class probabilities, one column per level
#' @return List: accuracy, kappa, sensitivity, specificity, auc, auc_low,
#'   auc_high (DeLong 95 % CI, binary only), n and the confusion matrix
evaluate_predictions <- function(obs, pred, prob) {
  lv <- levels(obs)
  cm <- caret::confusionMatrix(factor(pred, levels = lv), obs)
  bc <- cm$byClass
  binary <- length(lv) == 2

  auc <- if (binary) {
    roc <- pROC::roc(obs, prob[[lv[2]]], levels = lv, direction = "<", quiet = TRUE)
    as.numeric(pROC::ci.auc(roc, method = "delong"))
  } else {
    c(NA, as.numeric(pROC::multiclass.roc(obs, prob[lv], quiet = TRUE)$auc), NA)
  }

  list(
    accuracy    = unname(cm$overall["Accuracy"]),
    kappa       = unname(cm$overall["Kappa"]),
    sensitivity = if (binary) unname(bc["Sensitivity"]) else mean(bc[, "Sensitivity"], na.rm = TRUE),
    specificity = if (binary) unname(bc["Specificity"]) else mean(bc[, "Specificity"], na.rm = TRUE),
    auc = auc[2], auc_low = auc[1], auc_high = auc[3],
    n = length(obs), confusion_matrix = cm
  )
}


#' Predict new rows with a train_model_advanced() result
#'
#' The SVM is fitted on data scaled with the training mean/sd, so new rows go
#' through the same transform, with the training statistics, not their own.
#'
#' @return List: `pred` (factor) and `prob` (data frame, one column per class)
predict_rows <- function(result, train, newdata) {
  if (identical(result$model_type, "svm")) {
    num <- setdiff(names(newdata)[vapply(newdata, is.numeric, logical(1))], "target")
    mu  <- colMeans(train[num])
    sdv <- vapply(train[num], stats::sd, numeric(1))
    newdata[num] <- sweep(sweep(newdata[num], 2, mu), 2, sdv, "/")
  }
  list(pred = stats::predict(result$model, newdata = newdata),
       prob = stats::predict(result$model, newdata = newdata, type = "prob"))
}


#' Train on the training partition, score once on the test partition
#'
#' @param prep Output of prepare_partition()
#' @param model_type "c50", "rf", "svm" or "xgboost"
#' @param ... Passed to train_model_advanced() (use_rfe, use_cv, tune_params)
#' @return train_model_advanced() result where `metrics` are the TEST metrics,
#'   `cv_metrics` the cross-validation ones (reference only)
fit_holdout <- function(prep, model_type, ...) {
  result <- train_model_advanced(prep$train, model_type = model_type,
                                 cv_folds = ML_CV_FOLDS, cv_repeats = ML_CV_REPEATS, ...)
  if (isTRUE(result$skipped)) return(result)

  p <- predict_rows(result, prep$train, prep$test)
  test_metrics <- evaluate_predictions(prep$test$target, p$pred, p$prob)
  result$cv_metrics <- result$metrics
  result$metrics <- test_metrics[setdiff(names(test_metrics), "confusion_matrix")]
  result$confusion_matrix <- test_metrics$confusion_matrix
  result$validation <- list(mode = "holdout", n_train = nrow(prep$train),
                            n_test = nrow(prep$test), candidates = prep$candidates)
  result$validation_label <- sprintf("Hold-out test (n = %d) | %d-fold CV x %d on training",
                                     nrow(prep$test), ML_CV_FOLDS, ML_CV_REPEATS)
  result
}


#' Nested cross-validation
#'
#' Imputation, candidate selection, RFE, tuning and fit are repeated inside each
#' outer fold; the outer-fold predictions are pooled for the metrics. The model
#' returned for importance/consensus is refitted on all samples with the same
#' recipe (its performance is the nested estimate, not its own CV).
#'
#' @param data Data frame: `target` + numeric peptide columns (may contain NA)
#' @return Same shape as fit_holdout()
run_nested_cv <- function(data, model_type, impute_method = "knn",
                          criteria = list(method = "all"), seed = ML_DEFAULT_SEED,
                          k = ML_OUTER_FOLDS, ...) {
  set.seed(seed)
  folds <- caret::createFolds(data$target, k = k)

  oof <- lapply(folds, function(idx) {
    prep <- prepare_partition(data[-idx, , drop = FALSE], data[idx, , drop = FALSE],
                              impute_method, criteria)
    fit <- train_model_advanced(prep$train, model_type = model_type,
                                cv_folds = ML_CV_FOLDS, cv_repeats = ML_CV_REPEATS, ...)
    if (isTRUE(fit$skipped)) return(NULL)
    c(list(obs = prep$test$target), predict_rows(fit, prep$train, prep$test))
  })
  oof <- Filter(Negate(is.null), oof)

  # Final model on every sample, for importance and consensus
  full <- impute_missing(data, method = impute_method)
  candidates <- select_candidates(full, criteria)
  result <- train_model_advanced(full[, c("target", candidates), drop = FALSE],
                                 model_type = model_type,
                                 cv_folds = ML_CV_FOLDS, cv_repeats = ML_CV_REPEATS, ...)
  if (isTRUE(result$skipped) || length(oof) == 0) return(result)

  pooled <- evaluate_predictions(
    factor(unlist(lapply(oof, function(o) as.character(o$obs))), levels = levels(data$target)),
    factor(unlist(lapply(oof, function(o) as.character(o$pred))), levels = levels(data$target)),
    do.call(rbind, lapply(oof, `[[`, "prob")))

  result$cv_metrics <- result$metrics
  result$metrics <- pooled[setdiff(names(pooled), "confusion_matrix")]
  result$confusion_matrix <- pooled$confusion_matrix
  result$validation <- list(mode = "nested", n_train = nrow(data), n_test = nrow(data),
                            outer_folds = length(folds), candidates = candidates)
  result$validation_label <- sprintf("Nested CV (%d outer folds) | %d-fold CV x %d inside",
                                     length(folds), ML_CV_FOLDS, ML_CV_REPEATS)
  result
}


#' Which validation scheme to recommend for this sample size
#'
#' Hold-out is recommended when ml_sample_size_check() on the training
#' partition is not "critical" for 5-fold CV and the test set keeps at least
#' 5 samples of every class; otherwise nested CV.
#'
#' @param class_counts Named table of samples per class
#' @param n_features Number of candidate predictors
#' @return List: `mode` ("holdout" or "nested") and `reason`
recommend_validation <- function(class_counts, n_features) {
  class_counts <- class_counts[class_counts > 0]
  # Same rounding as caret::createDataPartition() (ceiling per class), so the
  # sizes quoted here match the split that split_holdout() will make.
  train_counts <- ceiling(class_counts * (1 - ML_TEST_PROP))
  min_test <- min(class_counts - train_counts)
  check <- ml_sample_size_check(sum(train_counts), train_counts, n_features, cv_folds = ML_CV_FOLDS)

  if (check$severity == "critical" || min_test < 5) {
    list(mode = "nested", reason = sprintf(
      "Recommended: nested CV. A 30%% test set would keep only %d samples of the smallest class, too few for a stable estimate.",
      min_test))
  } else {
    list(mode = "holdout", reason = sprintf(
      "Recommended: hold-out. Training set of %d samples, test set of %d (at least %d per class).",
      sum(train_counts), sum(class_counts - train_counts), min_test))
  }
}
