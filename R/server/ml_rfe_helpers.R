# ============================================================================
# MicroarrAI - RFE (Recursive Feature Elimination) Helpers
# ============================================================================
# Description: Safe, model-specific RFE configuration and validation
# Dependencies: caret
# ============================================================================

#' RFE Capabilities Table (Single Source of Truth)
#'
#' Defines which models support RFE, their specific caret functions,
#' requirements, and behavior. This prevents unsafe or inappropriate RFE usage.
#'
#' Fields:
#'   - supported: Can this model use caret::rfe()?
#'   - funcs: caret RFE functions (treebagFuncs, rfFuncs, svmFuncs, etc.)
#'   - requires_numeric: Must predictors be numeric? (most models yes)
#'   - requires_kernlab: Does this need kernlab package?
#'   - provides_importance: Can model produce feature importance?
#'   - rfe_role: How RFE is used ("screening" = feature selection before CV)
#'   - reason: Explanation if not supported
get_rfe_capabilities <- function() {
  list(
    c50 = list(
      supported = TRUE,
      funcs = caret::treebagFuncs,  # C5.0 uses treebag functions (tree-based)
      requires_numeric = TRUE,
      requires_kernlab = FALSE,
      provides_importance = TRUE,
      rfe_role = "screening",
      note = "RFE used for feature screening before final model CV"
    ),
    
    rf = list(
      supported = TRUE,
      funcs = caret::rfFuncs,  # Random Forest specific functions
      requires_numeric = TRUE,
      requires_kernlab = FALSE,
      provides_importance = TRUE,
      rfe_role = "screening",
      note = "RFE used for feature screening before final model CV"
    ),
    
    svm = list(
      supported = TRUE,
      funcs = caret::caretFuncs,  # SVM uses generic caret functions (safer)
      requires_numeric = TRUE,
      requires_kernlab = TRUE,  # svmLinear needs kernlab
      provides_importance = FALSE,  # SVM does not have inherent importance
      rfe_role = "screening_pool_only",
      note = "RFE produces selected features only (no importance ranking). Requires kernlab package."
    ),
    
    xgboost = list(
      supported = FALSE,
      funcs = NULL,
      requires_numeric = TRUE,
      requires_kernlab = FALSE,
      provides_importance = TRUE,
      rfe_role = "not_applicable",
      reason = "RFE not supported for XGBoost. Use embedded feature importance (Gain) or SHAP values instead.",
      note = "XGBoost has built-in importance via Gain/Cover/Frequency and SHAP - no need for RFE"
    )
  )
}

#' Check if RFE Can Be Used for Model
#'
#' Validates whether RFE is safe and feasible for the given model and data.
#' Returns a list with ok=TRUE/FALSE and a human-readable reason.
#'
#' @param model_type Character: "c50", "rf", "svm", or "xgboost"
#' @param x Data frame or matrix of predictors (no target column)
#' @param rfe_sizes Integer vector of feature subset sizes to try
#' @return List with:
#'   - ok: Logical, can RFE proceed?
#'   - reason: Character, explanation (success or failure)
#'   - funcs: RFE functions to use (NULL if not ok)
can_use_rfe <- function(model_type, x, rfe_sizes = c(5, 10, 15, 20, 25)) {
  
  # Get capabilities
  caps <- get_rfe_capabilities()
  
  if (!model_type %in% names(caps)) {
    return(list(
      ok = FALSE,
      reason = paste0("Unknown model type: ", model_type),
      funcs = NULL
    ))
  }
  
  model_caps <- caps[[model_type]]
  
  # Check 1: Model supports RFE?
  if (!model_caps$supported) {
    return(list(
      ok = FALSE,
      reason = model_caps$reason,
      funcs = NULL
    ))
  }
  
  # Check 2: Required packages available?
  if (model_caps$requires_kernlab) {
    if (!requireNamespace("kernlab", quietly = TRUE)) {
      return(list(
        ok = FALSE,
        reason = "RFE for SVM requires 'kernlab' package. Install with: install.packages('kernlab')",
        funcs = NULL
      ))
    }
  }
  
  # Check 3: Enough features for RFE sizes?
  n_features <- ncol(x)
  max_size <- max(rfe_sizes)
  
  if (max_size > n_features) {
    return(list(
      ok = FALSE,
      reason = sprintf("Not enough features for RFE. Max size=%d but only %d features available", 
                      max_size, n_features),
      funcs = NULL
    ))
  }
  
  # Check 4: Predictors compatible with model?
  # Note: Tree-based models (C5.0, RF) can handle factors
  # SVM requires numeric predictors
  if (model_caps$requires_numeric && model_type == "svm") {
    # SVM is strict - must be all numeric
    non_numeric <- !sapply(x, is.numeric)
    if (any(non_numeric)) {
      non_numeric_cols <- names(x)[non_numeric]
      return(list(
        ok = FALSE,
        reason = sprintf("SVM RFE requires numeric predictors. Found %d non-numeric: %s", 
                        sum(non_numeric), 
                        paste(head(non_numeric_cols, 3), collapse=", ")),
        funcs = NULL
      ))
    }
  } else if (model_caps$requires_numeric) {
    # Tree models: warn but allow factors (they handle them internally)
    non_numeric <- !sapply(x, function(col) is.numeric(col) || is.factor(col))
    if (any(non_numeric)) {
      # Only fail if there are truly incompatible types (not numeric or factor)
      return(list(
        ok = FALSE,
        reason = sprintf("Found %d incompatible predictor types (must be numeric or factor)", 
                        sum(non_numeric)),
        funcs = NULL
      ))
    }
  }
  
  # All checks passed
  return(list(
    ok = TRUE,
    reason = sprintf("RFE enabled for %s (%s)", model_type, model_caps$rfe_role),
    funcs = model_caps$funcs,
    note = model_caps$note
  ))
}

#' Adjust RFE Sizes to Data Constraints
#'
#' Ensures RFE sizes don't exceed available features and are sensible.
#' Creates aggressive feature selection sizes (10%, 20%, 30%, 40%, 50% of total)
#'
#' @param rfe_sizes Integer vector of requested sizes (will be overridden)
#' @param n_features Integer, number of available features
#' @param min_size Integer, minimum feature set size (default 5)
#' @return Integer vector of valid RFE sizes
adjust_rfe_sizes <- function(rfe_sizes, n_features, min_size = 5) {
  
  # Create aggressive sizes based on percentages of total features
  # This ensures real feature reduction, not just selecting almost everything
  percentages <- c(0.10, 0.20, 0.30, 0.40, 0.50)
  valid_sizes <- unique(pmax(min_size, floor(n_features * percentages)))
  
  # Add any user-requested sizes that fit within our range
  user_sizes <- rfe_sizes[rfe_sizes >= min_size & rfe_sizes <= max(valid_sizes)]
  if (length(user_sizes) > 0) {
    valid_sizes <- unique(c(valid_sizes, user_sizes))
  }
  
  # Ensure at least min_size if n_features allows
  if (n_features >= min_size && !any(valid_sizes == min_size)) {
    valid_sizes <- c(min_size, valid_sizes)
  }
  
  # Cap at reasonable maximum (50% of features or 100, whichever is smaller)
  max_allowed <- min(floor(n_features * 0.5), 100)
  valid_sizes <- valid_sizes[valid_sizes <= max_allowed]
  
  # If still no valid sizes, use minimal default
  if (length(valid_sizes) == 0) {
    valid_sizes <- min(min_size, n_features)
  }
  
  # Ensure uniqueness and sorting
  valid_sizes <- sort(unique(valid_sizes))
  
  message("[RFE] Adjusted sizes to: ", paste(valid_sizes, collapse=", "), 
          " (from ", n_features, " total features)")
  
  return(valid_sizes)
}
