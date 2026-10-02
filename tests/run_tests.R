#!/usr/bin/env Rscript
# Run the test suite from the repository root (no Singularity needed):
#   Rscript tests/run_tests.R
# Needs testthat and withr besides the app's own packages.
testthat::test_dir("tests/testthat", reporter = "progress", stop_on_failure = TRUE)
