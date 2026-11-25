# Leak-free ML evaluation (R/server/ml_validation.R): the test partition must
# never influence imputation, candidate selection or the fit.

suppressPackageStartupMessages({ library(dplyr); library(caret) })
for (f in c("imputation.R", "ml_rfe_helpers.R", "ml_supervised.R", "ml_validation.R")) {
  source(file.path(repo, "R", "server", f), encoding = "UTF-8")
}

# 2 groups, 40 peptides, the first 5 informative, a few NAs
make_ml_data <- function(n = 100, seed = 1) {
  set.seed(seed)
  target <- factor(rep(c("Case", "Control"), length.out = n))
  x <- matrix(rnorm(n * 40), n, 40, dimnames = list(paste0("s", 1:n), paste0("IgE_p", 1:40)))
  x[target == "Case", 1:5] <- x[target == "Case", 1:5] + 1.5
  x[sample(length(x), 30)] <- NA
  data.frame(target = target, x, check.names = FALSE)
}

test_that("the hold-out split is stratified and reproducible with the seed", {
  d <- make_ml_data()
  a <- split_holdout(d, seed = 42)
  b <- split_holdout(d, seed = 42)
  expect_identical(rownames(a$test), rownames(b$test))
  expect_equal(nrow(a$train) + nrow(a$test), nrow(d))
  expect_length(intersect(rownames(a$train), rownames(a$test)), 0)
  expect_equal(as.numeric(prop.table(table(a$test$target))), c(0.5, 0.5), tolerance = 0.05)
  expect_false(identical(rownames(split_holdout(d, seed = 7)$test), rownames(a$test)))
})

test_that("test rows never change the imputed training rows", {
  d <- make_ml_data()
  s <- split_holdout(d)
  ref <- impute_holdout(s$train, s$test, method = "knn")
  s$test[, -1] <- s$test[, -1] * 100 + 50
  pert <- impute_holdout(s$train, s$test, method = "knn")
  expect_equal(ref$train, pert$train)
  expect_false(anyNA(pert$test[, -1]))
})

test_that("candidate selection does not depend on the test rows", {
  d <- make_ml_data()
  s <- split_holdout(d)
  crit <- list(method = "top_n", padj_max = 0.05, auc_min = 0.5, top_n = 5, auc_threshold = 0.7)
  ref <- prepare_partition(s$train, s$test, "median", crit)$candidates

  s$test[, -1] <- -s$test[, -1]               # flip every test value
  s$test$target <- rev(s$test$target)         # and scramble its labels
  expect_identical(prepare_partition(s$train, s$test, "median", crit)$candidates, ref)
  expect_true(all(ref %in% paste0("IgE_p", 1:5)))
})

test_that("'all' keeps every peptide and the funnel thresholds are honoured", {
  d <- impute_missing(make_ml_data(), method = "median")
  expect_setequal(select_candidates(d, list(method = "all")), setdiff(names(d), "target"))
  strict <- select_candidates(d, list(method = "auc_threshold", padj_max = 0.05,
                                      auc_min = 0.5, auc_threshold = 0.75))
  expect_true(all(strict %in% paste0("IgE_p", 1:5)))
})

test_that("metrics come from the test rows only, with a DeLong CI", {
  d <- make_ml_data()
  s <- split_holdout(d)
  prep <- prepare_partition(s$train, s$test, "median", list(method = "all"))
  res <- fit_holdout(prep, "rf", use_rfe = FALSE, use_cv = FALSE)
  expect_equal(res$metrics$n, nrow(s$test))
  expect_equal(sum(res$confusion_matrix$table), nrow(s$test))
  expect_true(res$metrics$auc_low <= res$metrics$auc && res$metrics$auc <= res$metrics$auc_high)
  expect_equal(res$validation$mode, "holdout")
})

test_that("evaluate_predictions matches hand-computed values", {
  obs  <- factor(c("A", "A", "B", "B"), levels = c("A", "B"))
  pred <- factor(c("A", "B", "B", "B"), levels = c("A", "B"))
  prob <- data.frame(A = c(.9, .4, .2, .1), B = c(.1, .6, .8, .9))
  m <- evaluate_predictions(obs, pred, prob)
  expect_equal(m$accuracy, 0.75)
  expect_equal(m$sensitivity, 0.5)   # positive class = first level
  expect_equal(m$specificity, 1)
  expect_equal(m$auc, 1)
})

test_that("nested CV pools one prediction per sample", {
  d <- make_ml_data(n = 60)
  res <- run_nested_cv(d, "rf", impute_method = "median", k = 3,
                       use_rfe = FALSE, use_cv = FALSE)
  expect_equal(res$metrics$n, nrow(d))
  expect_equal(res$validation$mode, "nested")
})

test_that("small samples are steered to nested CV", {
  expect_equal(recommend_validation(table(c(rep("a", 60), rep("b", 60))), 20)$mode, "holdout")
  expect_equal(recommend_validation(table(c(rep("a", 12), rep("b", 12))), 20)$mode, "nested")
})

test_that("the recommended split sizes match the split actually made", {
  d <- data.frame(target = factor(rep(c("A", "T"), c(62, 58))), x = rnorm(120))
  s <- split_holdout(d)
  expect_match(recommend_validation(table(d$target), 20)$reason,
               sprintf("Training set of %d samples, test set of %d", nrow(s$train), nrow(s$test)))
})

test_that("the SVM test rows are scaled with the training statistics", {
  d <- make_ml_data()
  s <- split_holdout(d)
  prep <- prepare_partition(s$train, s$test, "median",
                            list(method = "top_n", padj_max = 0.05, auc_min = 0.5, top_n = 8, auc_threshold = 0.7))
  res <- fit_holdout(prep, "svm", use_rfe = TRUE, use_cv = TRUE)
  expect_gt(res$metrics$auc, 0.75)   # unscaled test rows collapse to one class (AUC 0.5)
})

test_that("RFE runs when there are fewer candidates than the largest subset size", {
  x <- data.frame(matrix(rnorm(300), 30, 10))
  expect_true(can_use_rfe("rf", x, c(5, 10, 15, 20, 25))$ok)
  expect_false(can_use_rfe("rf", x[, 1:4], c(5, 10, 15, 20, 25))$ok)
})
