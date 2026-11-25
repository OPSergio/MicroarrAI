# PDF report and results workbook (R/server/report.R), step log (R/utils/logging.R)

suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
source(file.path(repo, "R", "utils", "logging.R"), encoding = "UTF-8")
source(file.path(repo, "R", "server", "report.R"), encoding = "UTF-8")

full_payload <- function() {
  set.seed(1)
  graded <- expand.grid(sample = sprintf("A%02d", 1:12), channel = c("1", "2"),
                        label = c("Replicate agreement (R)", "Positive control S/N"), stringsAsFactors = FALSE)
  graded$grade <- sample(c("green", "green", "amber", "red", NA), nrow(graded), TRUE)
  graded$value <- runif(nrow(graded))
  verdicts <- graded %>% group_by(sample, channel) %>%
    summarise(verdict = if (any(grade %in% "red")) "red" else if (any(grade %in% "amber")) "amber" else "green", .groups = "drop")
  res <- data.frame(peptide = paste0("IgE_p_", 1:60, "_Arah2"), p.value = runif(60) / 10, coefficient = rnorm(60))
  res$p.adj <- p.adjust(res$p.value, "BH"); res$AUC <- runif(60, .5, .9)
  list(
    meta = list(date = "2026-11-24 10:00", session = "abcd1234", app_version = "dev", r_version = "R test",
                packages = data.frame(Package = "shiny", Version = "1.9.1")),
    settings = list("Controls" = list("Negative controls" = "PBS_1X", "Positive controls" = c("aIgE_05", "aIgE_025")),
                    "Normalization" = c("Within each array" = "Z-score", "Between arrays" = "robust ≥ 0")),
    input = list(arrays = 12, analytes = 70, features = 120, matched = 12, groups = table(rep(c("A", "B"), 6)), missing = "0 values",
                 clinical = data.frame(Column = c("Group", "Age"), Type = c("categorical", "numeric"), Values = c("A, B", "3 to 16"), Missing = c(0L, 1L))),
    qc = list(verdicts = verdicts, graded = graded, metrics = verdicts, normalization = "Normalization is working.",
              problems = data.frame(Array = "A01", Channel = "1", Verdict = "fail", `Metrics out of range` = "S/N = 1.2", check.names = FALSE),
              thresholds = data.frame(Metric = "S/N", Pass = ">= 10", Fail = "< 3")),
    stats = list(target = "Group", results = res, top = res,
                 volcano = data.frame(peptide = res$peptide, isotype = "IgE", log2FC = res$coefficient, padj = res$p.adj,
                                      status = ifelse(res$p.adj < .05, "Up", "NS"))),
    ml = list(label = "Hold-out test (n = 4)",
              validation = data.frame(Model = c("C5.0", "RF"), AUC = c(.9, .8), AUC_low = c(.7, .6), AUC_high = c(1, .95),
                                      Accuracy = .8, Kappa = .6, Sensitivity = .8, Specificity = .8, CV_AUC = .85),
              consensus = data.frame(peptide = "IgE_p_3_Arah2", models = 2L, which_models = "C5.0, RF", mean_rank = 1.5),
              importance = list(RF = data.frame(Feature = "IgE_p_3_Arah2", Importance = 100)),
              partition = data.frame(id = c("A01", "A02"), partition = c("train", "test")),
              split = list(Mode = "holdout", "Training samples" = 8)),
    protein = data.frame(feature = "IgE_p_3_Arah2", protein = "Arah2", start = 7, end = 26),
    epitopes = data.frame(protein = "Arah2", accession = "Q6PSU2", isotype = rep(c("IgE", "IgG4"), each = 20), number = 1:20,
                          start = seq(1, 58, 3), end = seq(1, 58, 3) + 19, effect = rnorm(40), padj = runif(40), biomarker = 1:40 %in% c(3, 4)),
    snapshots = list(list(protein = "Arah2", accession = "Q6PSU2", pdb = "", isotype = "IgE", group = "Allergic", mode = "expr",
                          view3d = array(runif(60 * 80 * 3), c(60, 80, 3)), map2d = array(runif(40 * 90 * 3), c(40, 90, 3)))),
    methods = "Synthetic test payload."
  )
}

test_that("a full report is a multi-page PDF", {
  f <- withr::local_tempfile(fileext = ".pdf")
  build_pdf_report(f, full_payload())
  expect_true(file.size(f) > 5000)
  expect_identical(readBin(f, "raw", 4), charToRaw("%PDF"))
})

test_that("a report before any analysis still builds and says what is missing", {
  f <- withr::local_tempfile(fileext = ".pdf")
  build_pdf_report(f, list(meta = full_payload()$meta))
  expect_true(file.size(f) > 1000)
})

test_that("the workbook has one sheet per computed table", {
  f <- withr::local_tempfile(fileext = ".xlsx")
  build_results_workbook(f, full_payload())
  sheets <- openxlsx::getSheetNames(f)
  expect_true(all(c("Settings", "QC_scorecard", "Differential", "ML_validation", "ML_consensus", "Epitope_map", "Importance_RF") %in% sheets))
  expect_equal(nrow(openxlsx::read.xlsx(f, "Differential")), 60)
})

test_that("run_step logs START and DONE, and turns a failure into NULL with the reason", {
  out <- capture_messages(res <- run_step("TEST", "adding", 1 + 1, x = 3))
  expect_equal(res, 2)
  expect_match(out[1], "INFO .*TEST .*\\| START adding \\| x=3")
  expect_match(out[2], "DONE adding in")

  out <- capture_messages(res <- run_step("TEST", "failing", stop("bad input"), hint = "fix it"))
  expect_null(res)
  expect_match(out[2], "ERROR .*FAILED failing .*why=bad input.*hint=fix it")
})

test_that("repeated warnings are logged once and counted", {
  out <- capture_messages(run_step("TEST", "warning", { for (i in 1:5) warning("same"); 1 }))
  expect_equal(sum(grepl("warning: same", out)), 1)
  expect_true(any(grepl("repeated 5 times", out)))
})
