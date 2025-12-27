# =============================================================================
# TEST_IMPORTS.R
# Script to verify all modular functions are correctly loaded
# =============================================================================
# Description:
#   Tests that all 42 modular functions are accessible after sourcing global.R
#
# Usage:
#   source("test_imports.R")
# =============================================================================

# Load global configuration
source("global.R", encoding = "UTF-8")

cat("Testing modular function imports...\n\n")

# =============================================================================
# Test data_processing.R (6 functions)
# =============================================================================
cat("Testing data_processing.R functions:\n")
test_functions <- c(
  "import_peptide_data",
  "validate_data_structure", 
  "normalize_data",
  "detect_missing_values",
  "filter_low_variance",
  "merge_clinical_data"
)

for (func in test_functions) {
  if (exists(func)) {
    cat("  [OK]", func, "\n")
  } else {
    cat("  [ERROR]", func, "not found!\n")
  }
}

# =============================================================================
# Test statistical_analysis.R (6 functions)
# =============================================================================
cat("\nTesting statistical_analysis.R functions:\n")
test_functions <- c(
  "perform_statistical_test",
  "correct_pvalues",
  "generate_volcano_data",
  "calculate_fold_change",
  "identify_significant_features",
  "perform_anova"
)

for (func in test_functions) {
  if (exists(func)) {
    cat("  [OK]", func, "\n")
  } else {
    cat("  [ERROR]", func, "not found!\n")
  }
}

# =============================================================================
# Test ml_unsupervised.R (7 functions)
# =============================================================================
cat("\nTesting ml_unsupervised.R functions:\n")
test_functions <- c(
  "compute_pca",
  "calculate_pca_variance",
  "compute_distance_matrix",
  "perform_pcoa",
  "perform_nmds",
  "extract_target_groups",
  "prepare_ml_data"
)

for (func in test_functions) {
  if (exists(func)) {
    cat("  [OK]", func, "\n")
  } else {
    cat("  [ERROR]", func, "not found!\n")
  }
}

# =============================================================================
# Test ml_supervised.R (13 functions)
# =============================================================================
cat("\nTesting ml_supervised.R functions:\n")
test_functions <- c(
  "train_c50_model",
  "extract_c50_importance",
  "train_randomforest_model",
  "extract_rf_importance",
  "perform_rfe_svm",
  "train_svm_model",
  "scale_ml_data",
  "train_xgboost_model",
  "extract_xgboost_importance",
  "calculate_shap_values",
  "prepare_ml_data",
  "create_decision_boundary_plot"
)

for (func in test_functions) {
  if (exists(func)) {
    cat("  [OK]", func, "\n")
  } else {
    cat("  [ERROR]", func, "not found!\n")
  }
}

# =============================================================================
# Test regression_models.R (5 functions)
# =============================================================================
cat("\nTesting regression_models.R functions:\n")
test_functions <- c(
  "fit_binary_glm",
  "fit_multinomial_regression",
  "calculate_performance_metrics",
  "calculate_roc_curve",
  "prepare_regression_data"
)

for (func in test_functions) {
  if (exists(func)) {
    cat("  [OK]", func, "\n")
  } else {
    cat("  [ERROR]", func, "not found!\n")
  }
}

# =============================================================================
# Test visualization_3d.R (5 functions)
# =============================================================================
cat("\nTesting visualization_3d.R functions:\n")
test_functions <- c(
  "create_3d_scatter",
  "create_3d_pca",
  "create_3d_pcoa",
  "create_3d_nmds",
  "toggle_surface_fit"
)

for (func in test_functions) {
  if (exists(func)) {
    cat("  [OK]", func, "\n")
  } else {
    cat("  [ERROR]", func, "not found!\n")
  }
}

# =============================================================================
# Summary
# =============================================================================
cat("\n=============================================================================\n")
cat("Import test completed!\n")
cat("Total expected functions: 42\n")
cat("=============================================================================\n")
