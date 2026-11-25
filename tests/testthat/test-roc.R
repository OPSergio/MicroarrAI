# ROC curves (R/server/regression_models.R): points must form a valid path

suppressPackageStartupMessages(library(dplyr))
source(file.path(repo, "R", "server", "regression_models.R"), encoding = "UTF-8")

monotone <- function(d) all(diff(1 - d$specificity) >= 0) && all(diff(d$sensitivity) >= 0)

test_that("a binary ROC curve runs up and to the right, ties included", {
  set.seed(1)
  y <- factor(rep(c("A", "B"), each = 40))
  score <- round(c(rnorm(40), rnorm(40, 1)), 1)          # rounding creates ties
  d <- calculate_roc_curve(y, score)
  expect_true(monotone(d))
  expect_equal(d$auc[1], as.numeric(pROC::auc(pROC::roc(y, score, levels = c("A", "B"), direction = "<", quiet = TRUE))))
  expect_true(d$auc_low[1] < d$auc[1] && d$auc[1] < d$auc_high[1])
})

test_that("one-vs-rest curves are monotone and use each class's own probability", {
  set.seed(2)
  y <- factor(rep(c("a", "b", "c"), each = 30))
  # columns deliberately in a different order from the levels
  p <- data.frame(c = runif(90), a = ifelse(y == "a", 0.9, 0.1), b = runif(90))
  d <- calculate_roc_curve(y, p)
  expect_setequal(unique(d$class), c("a", "b", "c"))
  for (cl in unique(d$class)) expect_true(monotone(d[d$class == cl, ]))
  expect_equal(d$auc[d$class == "a"][1], 1)              # perfectly separated by its own column
})
