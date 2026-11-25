# Array QC metrics (R/server/quality_control.R)

suppressPackageStartupMessages(library(dplyr))
source(file.path(repo, "R", "server", "quality_control.R"), encoding = "UTF-8")

# One array, one channel: 20 non-binding peptides (S/N ~ 1) and an anti-IgE
# series whose top dose reaches S/N = top
make_spots <- function(top) {
  peps <- tibble(ID = rep(sprintf("p_%d_x", 1:20), each = 2), snr = 1, Expression = 0)
  ctrl <- tibble(ID = rep(c("aIgE_0125", "aIgE_025", "aIgE_05"), each = 2),
                 snr = rep(c(top / 4, top / 2, top), each = 2), Expression = rep(1:3, each = 2))
  blank <- tibble(ID = "PBS_1X", snr = 1, Expression = rnorm(10, 0, 0.1))
  bind_rows(peps, ctrl, blank) %>% mutate(sample = "a1", channel = "IgE")
}
controls <- tibble(ID = c("aIgE_0125", "aIgE_025", "aIgE_05"), dose = c(0.0125, 0.025, 0.05))

test_that("S/N is read from the top-dose positive control, not from every spot", {
  q <- compute_array_quality(make_spots(top = 25), positive_controls = controls)
  expect_equal(q$snr, 25)
})

test_that("S/N grades follow the 3 SD detection and 10 SD quantification limits", {
  expect_equal(grade_metric("snr", c(25, 10, 5, 3, 2)), c("green", "green", "amber", "amber", "red"))
})

test_that("the best control series counts when a channel only lights one of them", {
  s <- bind_rows(make_spots(top = 25),
                 tibble(ID = "aIgG_05", snr = 1, Expression = 0, sample = "a1", channel = "IgE"))
  ctrl <- bind_rows(controls, tibble(ID = "aIgG_05", dose = 0.05))
  expect_equal(positive_control_snr(s, ctrl)$snr, 25)
})

test_that("S/N is not measurable without a scanner S/N column", {
  q <- compute_array_quality(select(make_spots(25), -snr), positive_controls = controls)
  expect_true(is.na(q$snr))
})
