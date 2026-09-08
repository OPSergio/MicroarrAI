#!/usr/bin/env Rscript
# =============================================================================
# MicroarrAI - canonical R dependency list
# =============================================================================
# Single source of truth for docker/Dockerfile and singularity/MicroarrAI.def,
# so the two images cannot drift apart again.
#
#   Rscript dependencies.R install   install everything that is missing
#   Rscript dependencies.R check     exit 1 if anything is still missing
#
# Every package listed here is either attached by R/global.R or reached with
# `::` somewhere in the app. Nothing else belongs in this list.
# =============================================================================

# -----------------------------------------------------------------------------
# CRAN
# -----------------------------------------------------------------------------
CRAN_PACKAGES <- c(
  # Data manipulation and I/O
  "dplyr", "tidyr", "tibble", "readr", "purrr", "stringr",
  "readxl", "broom", "rlang", "jsonlite", "openxlsx",

  # Shiny ecosystem
  "shiny", "shinyWidgets", "shinydashboard", "shinycssloaders", "DT",
  "shinyjs", "shinythemes", "bslib", "rhandsontable", "markdown",

  # Visualization
  "ggplot2", "plotly", "ggpubr", "cowplot", "ggrepel", "ggvenn", "ggiraph",
  "ggridges", "rgl", "car",

  # Statistics
  "vegan", "dbscan", "cluster",

  # Machine learning
  # nnet backs parsnip::multinom_reg(engine = "nnet") in regression_models.R
  "C50", "randomForest", "e1071", "kernlab", "caret", "xgboost", "shapviz",
  "nnet", "parsnip", "yardstick", "pROC", "MLmetrics"
)

# -----------------------------------------------------------------------------
# Bioconductor
# -----------------------------------------------------------------------------
# ComplexHeatmap drives every heatmap in app.R; impute backs the default KNN
# imputation in R/server/imputation.R (which otherwise degrades to medians).
BIOC_PACKAGES <- c("mixOmics", "ComplexHeatmap", "impute")


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

missing_packages <- function(pkgs) {
  pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
}

# The rocker base image pins CRAN to a dated Posit Package Manager snapshot,
# which gives reproducible versions and prebuilt Linux binaries. Keep it, and
# only fall back to cloud.r-project.org when no usable repository is set.
ensure_cran_repo <- function() {
  repos <- getOption("repos")
  cran <- if (!is.null(repos) && "CRAN" %in% names(repos)) repos[["CRAN"]] else ""
  if (!nzchar(cran) || cran == "@CRAN@") {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
    message("No CRAN repository configured; falling back to cloud.r-project.org")
  } else {
    message("Using CRAN repository: ", cran)
  }
}

install_missing <- function() {
  ensure_cran_repo()

  missing_cran <- missing_packages(CRAN_PACKAGES)
  if (length(missing_cran) > 0) {
    message("Installing ", length(missing_cran), " CRAN packages: ",
            paste(missing_cran, collapse = ", "))
    install.packages(missing_cran)
  } else {
    message("All CRAN packages already present.")
  }

  missing_bioc <- missing_packages(BIOC_PACKAGES)
  if (length(missing_bioc) > 0) {
    if (!requireNamespace("BiocManager", quietly = TRUE)) {
      install.packages("BiocManager")
    }
    message("Installing ", length(missing_bioc), " Bioconductor packages: ",
            paste(missing_bioc, collapse = ", "))
    BiocManager::install(missing_bioc, ask = FALSE, update = FALSE)
  } else {
    message("All Bioconductor packages already present.")
  }
}

# install.packages() only warns when a package fails to build, so the image
# would otherwise be declared healthy with holes in it. Fail the build loudly.
check_all <- function() {
  all_packages <- c(CRAN_PACKAGES, BIOC_PACKAGES)
  missing <- missing_packages(all_packages)
  if (length(missing) > 0) {
    message("MISSING PACKAGES (", length(missing), "): ",
            paste(missing, collapse = ", "))
    quit(status = 1)
  }
  message("All ", length(all_packages), " required packages are installed.")
}


# -----------------------------------------------------------------------------
# Entry point
# -----------------------------------------------------------------------------
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  action <- if (length(args) > 0) args[1] else "check"

  if (action == "install") {
    install_missing()
    check_all()
  } else if (action == "check") {
    check_all()
  } else {
    message("Usage: Rscript dependencies.R [install|check]")
    quit(status = 2)
  }
}
