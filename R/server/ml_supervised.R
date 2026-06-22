# =============================================================================
# ML_SUPERVISED.R
# Supervised Machine Learning Module
# =============================================================================
# Description:
#   Functions for supervised machine learning including:
#   - C5.0 Decision Trees (classification)
#   - Random Forest (feature importance, classification)
#   - SVM with RFE (Recursive Feature Elimination)
#   - XGBoost with SHAP values (binary and multiclass)
#   - Feature importance extraction
#   - Decision boundary visualization support
#   - Advanced training with RFE and Cross-Validation
#
# Dependencies:
#   - C50: C5.0 decision trees
#   - randomForest: Random Forest
#   - e1071: SVM
#   - caret: RFE, model training, cross-validation
#   - xgboost: Gradient boosting
#   - shapviz: SHAP value visualization
#   - dplyr, tidyr: Data manipulation
#   - pROC: ROC curves and AUC calculation
#
# Author: Sergio Olmos Piñero
# Last Modified: 2025
# =============================================================================

#' Train model with Cross-Validation and optional RFE
#'
#' @description
#' Comprehensive training function that supports:
#' - Cross-validation for performance estimation
#' - Recursive Feature Elimination (RFE) for feature selection
#' - Multiple model types (C5.0, RF, SVM, XGBoost)
#' - Hyperparameter tuning
#'
#' @param data A data.frame with 'target' column (factor) and numeric predictors
#' @param model_type Character: "c50", "rf", "svm", or "xgboost"
#' @param use_rfe Logical. Apply RFE for feature selection (default: FALSE)
#' @param use_cv Logical. Use cross-validation (default: TRUE)
#' @param cv_folds Number of CV folds (default: 5)
#' @param cv_repeats Number of CV repeats (default: 3)
#' @param tune_params Logical. Perform hyperparameter tuning (default: FALSE)
#' @param rfe_sizes Vector of feature subset sizes for RFE (default: c(5, 10, 15, 20, 25))
#'
#' @return A list with:
#'   - model: Trained model object
#'   - cv_results: Cross-validation results (if use_cv = TRUE)
#'   - rfe_results: RFE results (if use_rfe = TRUE)
#'   - selected_features: Selected feature names
#'   - metrics: Performance metrics (accuracy, AUC, etc.)
#'   - confusion_matrix: Confusion matrix from CV
#'
#' @examples
#' # Basic training with CV
#' result <- train_model_advanced(data, model_type = "rf", use_cv = TRUE)
#' 
#' # Training with RFE
#' caret "xgbTree" method that avoids the deprecated `ntreelimit`
#'
#' caret 6.0.94 predicts intermediate tree counts via its "submodel" mechanism
#' with `ntreelimit`, which xgboost >= 1.6 deprecated (flooding the console).
#' Disabling `$loop` removes that submodel optimisation: caret instead fits each
#' grid candidate at its own nrounds and predicts the full model (no ntreelimit).
#' caret's original — and correct — predict/prob are kept untouched, so model
#' performance is identical; only the deprecated code path is avoided.
xgbtree_method_fixed <- function() {
  m <- caret::getModelInfo("xgbTree", regex = FALSE)[[1]]
  m$loop <- NULL
  m
}

#' result <- train_model_advanced(data, model_type = "svm", use_rfe = TRUE, use_cv = TRUE)
#'
#' @export
train_model_advanced <- function(data,
                                  model_type = c("c50", "rf", "svm", "xgboost"),
                                  use_rfe = FALSE,
                                  use_cv = TRUE,
                                  cv_folds = 5,
                                  cv_repeats = 3,
                                  tune_params = FALSE,
                                  rfe_sizes = c(5, 10, 15, 20, 25)) {
  
  model_type <- match.arg(model_type)
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!"target" %in% colnames(data)) {
    stop("Data must contain 'target' column")
  }
  
  if (!is.factor(data$target)) {
    data$target <- as.factor(data$target)
  }
  
  # Initialize result list
  result <- list(
    model_type = model_type,
    use_rfe = use_rfe,
    use_cv = use_cv,
    rfe_used = FALSE,           # Track if RFE actually ran
    rfe_reason = NULL,          # Why RFE was used/skipped
    selected_features = NULL,
    metrics = list(),
    cv_results = NULL,
    rfe_results = NULL,
    model = NULL
  )
  
  # Convert factors to dummy variables for SVM (required for RFE and model training)
  if (model_type == "svm") {
    # First convert factors to dummies
    target <- data$target
    predictors <- data[, -which(names(data) == "target"), drop = FALSE]
    
    # Identify factor columns
    factor_cols <- sapply(predictors, is.factor)
    
    if (any(factor_cols)) {
      message("[SVM] Converting ", sum(factor_cols), " factor column(s) to dummy variables...")
      
      # Create dummy variables using model.matrix
      formula_str <- paste("~", paste(names(predictors), collapse = " + "), "- 1")
      dummy_matrix <- model.matrix(as.formula(formula_str), data = predictors)
      
      # Reconstruct data with dummies
      data <- as.data.frame(dummy_matrix)
      data$target <- target
      
      message("[SVM] Expanded from ", ncol(predictors), " to ", ncol(data) - 1, " features after dummy encoding")
    }
    
    # Then scale
    data <- scale_ml_data(data)
  }
  
  # Step 1: Feature Selection with RFE (Safe, Model-Specific Implementation)
  # CRITICAL: RFE requires cross-validation to evaluate feature subsets
  if (use_rfe && !use_cv) {
    message("[RFE] DISABLED: RFE requires cross-validation (CV=TRUE) to evaluate feature subsets")
    result$rfe_used <- FALSE
    result$rfe_reason <- "RFE requires CV to be enabled. Enable CV to use RFE for feature selection."
    result$selected_features <- setdiff(colnames(data), "target")
    use_rfe <- FALSE  # Override to skip RFE logic below
  }
  
  if (use_rfe) {
    message("[RFE] Checking if RFE can be used for ", model_type, "...")
    
    # Prepare data for RFE validation
    x <- data[, -which(names(data) == "target"), drop = FALSE]
    y <- data$target
    
    # Check if RFE is feasible for this model and data
    rfe_check <- can_use_rfe(model_type, x, rfe_sizes)
    
    if (!rfe_check$ok) {
      # RFE not possible - log reason and continue without it
      message("[RFE] DISABLED: ", rfe_check$reason)
      result$rfe_used <- FALSE
      result$rfe_reason <- rfe_check$reason
      result$selected_features <- colnames(x)  # Use all features
      
    } else {
      # RFE is safe to proceed
      message("[RFE] ENABLED: ", rfe_check$reason)
      if (!is.null(rfe_check$note)) {
        message("[RFE] Note: ", rfe_check$note)
      }
      
      # Adjust RFE sizes to available features
      rfe_sizes_adj <- adjust_rfe_sizes(rfe_sizes, ncol(x))
      message("[RFE] Using sizes: ", paste(rfe_sizes_adj, collapse = ", "))
      
      # Configure RFE with MODEL-SPECIFIC functions
      ctrl_rfe <- caret::rfeControl(
        functions = rfe_check$funcs,  # Model-specific (treebagFuncs, rfFuncs, etc.)
        method = "cv",
        number = cv_folds,
        verbose = FALSE,
        allowParallel = FALSE  # Avoid shinyapps.io crashes
      )
      
      # Run RFE with error handling
      rfe_result <- tryCatch(
        {
          message("[RFE] Running feature selection...")
          caret::rfe(
            x = x,
            y = y,
            sizes = rfe_sizes_adj,
            rfeControl = ctrl_rfe,
            method = switch(model_type,
              "c50" = "C5.0",
              "rf" = "rf",
              "svm" = "svmLinear",
              NULL
            )
          )
        },
        error = function(e) {
          message("[RFE] ERROR: ", e$message)
          message("[RFE] Falling back to using all features")
          NULL
        }
      )
      
      if (!is.null(rfe_result)) {
        result$rfe_results <- rfe_result
        result$selected_features <- caret::predictors(rfe_result)
        result$rfe_used <- TRUE
        result$rfe_reason <- paste0("RFE completed successfully. Selected ", 
                                    length(result$selected_features), 
                                    " features from ", ncol(x))
        
        message("[RFE] SUCCESS: Selected ", length(result$selected_features), " features")
        
        # Filter data to selected features
        data <- data[, c("target", result$selected_features), drop = FALSE]
        
      } else {
        # RFE failed - use all features
        result$rfe_used <- FALSE
        result$rfe_reason <- "RFE failed during execution. Using all features."
        result$selected_features <- colnames(x)
      }
    }
    
  } else {
    # RFE not requested
    result$rfe_used <- FALSE
    result$rfe_reason <- "RFE not requested by user"
    result$selected_features <- setdiff(colnames(data), "target")
  }
  
  # Step 2: Cross-Validation Setup
  # Detect binary vs multiclass for correct summary function
  num_classes <- length(levels(data$target))
  is_binary <- num_classes == 2
  
  if (use_cv) {
    ctrl_cv <- caret::trainControl(
      method = "repeatedcv",
      number = cv_folds,
      repeats = cv_repeats,
      classProbs = TRUE,
      summaryFunction = if (is_binary) caret::twoClassSummary else caret::multiClassSummary,
      savePredictions = "final",
      verboseIter = FALSE,  # FALSE to avoid Shiny console capture issues
      allowParallel = FALSE  # Disable parallel to avoid hanging
    )
  } else {
    ctrl_cv <- caret::trainControl(
      method = "none",
      classProbs = TRUE,
      savePredictions = "final"
    )
  }
  
  # Step 3: Hyperparameter Grid (if tuning requested)
  # IMPORTANT: When use_cv=FALSE, we MUST disable tuning to avoid "Only one model" error
  tune_grid <- NULL
  
  if (tune_params && use_cv) {
    # Only tune when CV is enabled
    tune_grid <- switch(model_type,
      "rf" = expand.grid(mtry = c(2, 5, 10, 15)),
      "svm" = expand.grid(C = c(0.1, 1, 10, 100)),
      "xgboost" = expand.grid(
        nrounds = c(50, 100, 150),
        max_depth = c(3, 6, 9),
        eta = c(0.01, 0.1, 0.3),
        gamma = 0,
        colsample_bytree = 1,
        min_child_weight = 1,
        subsample = 1
      ),
      NULL
    )
  } else if (!use_cv) {
    # When CV is disabled, force default parameters for each model
    tune_grid <- switch(model_type,
      "c50" = data.frame(trials = 1, model = "tree", winnow = FALSE),
      "rf" = data.frame(mtry = floor(sqrt(ncol(data) - 1))),
      "svm" = data.frame(C = 1),
      "xgboost" = data.frame(
        nrounds = 100,
        max_depth = 6,
        eta = 0.3,
        gamma = 0,
        colsample_bytree = 1,
        min_child_weight = 1,
        subsample = 1
      ),
      NULL
    )
  }
  
  # Step 4: Train Model with caret
  set.seed(123)
  
  # Set metric based on binary vs multiclass
  # Use Kappa for multiclass (more robust than Mean_F1 which requires MLmetrics)
  train_metric <- if (is_binary) "ROC" else "Kappa"
  
  if (use_cv) {
    message("[CV] Starting ", cv_folds, "-fold CV with ", cv_repeats, " repeats (", cv_folds * cv_repeats, " iterations)...")
    flush.console()
  } else {
    message("[Training] Starting single model training...")
    flush.console()
  }
  
  message("[DEBUG] About to call caret::train() with metric=", train_metric, "...")
  flush.console()
  
  # xgboost: use a patched method that calls iteration_range instead of the
  # deprecated ntreelimit, so caret's submodel predictions don't flood the log.
  caret_method <- switch(model_type,
    "c50" = "C5.0", "rf" = "rf", "svm" = "svmLinear",
    "xgboost" = xgbtree_method_fixed())

  # Wrap in tryCatch to surface errors in Shiny
  model_trained <- tryCatch(
    {
      caret::train(
        target ~ .,
        data = data,
        method = caret_method,
        trControl = ctrl_cv,
        tuneGrid = tune_grid,
        metric = train_metric
      )
    },
    error = function(e) {
      message("[ERROR] caret::train() failed: ", e$message)
      flush.console()
      stop("Model training failed: ", e$message)
    }
  )
  
  message("[DEBUG] caret::train() finished successfully")
  flush.console()
  
  result$model <- model_trained
  result$cv_results <- model_trained$results
  message("[Training] Model training completed")
  flush.console()
  
  # Extract variable importance (unified approach)
  message("[DEBUG] Extracting variable importance via caret::varImp()")
  flush.console()
  
  varimp <- tryCatch(
    caret::varImp(model_trained, scale = TRUE),
    error = function(e) {
      message("[WARNING] varImp not available: ", e$message)
      NULL
    }
  )
  
  result$varimp <- varimp
  
  # Step 5: Extract Performance Metrics
  if (use_cv) {
    tryCatch({
      message("[Metrics] Extracting performance metrics...")
      flush.console()
      
      # Get predictions from CV
      cv_preds <- model_trained$pred
      
      if (is.null(cv_preds) || nrow(cv_preds) == 0) {
        message("[WARNING] No CV predictions available")
        flush.console()
      } else {
        # Calculate confusion matrix
        cm <- caret::confusionMatrix(cv_preds$pred, cv_preds$obs)
        
        result$confusion_matrix <- cm
        result$metrics$accuracy <- cm$overall["Accuracy"]
        result$metrics$kappa <- cm$overall["Kappa"]
        
        # Handle byClass which can be matrix or vector depending on number of classes
        if (is.matrix(cm$byClass)) {
          result$metrics$sensitivity <- mean(cm$byClass[, "Sensitivity"], na.rm = TRUE)
          result$metrics$specificity <- mean(cm$byClass[, "Specificity"], na.rm = TRUE)
        } else {
          result$metrics$sensitivity <- cm$byClass["Sensitivity"]
          result$metrics$specificity <- cm$byClass["Specificity"]
        }
        
        message("[Metrics] Accuracy: ", round(result$metrics$accuracy, 3))
        flush.console()
        
        # Calculate AUC if probability predictions are available
        if (all(levels(data$target) %in% colnames(cv_preds))) {
          if (length(levels(data$target)) == 2) {
            # Binary classification
            roc_obj <- pROC::roc(
              response = cv_preds$obs,
              predictor = cv_preds[, levels(data$target)[1]],
              levels = levels(data$target),
              quiet = TRUE
            )
            result$metrics$auc <- as.numeric(pROC::auc(roc_obj))
            message("[Metrics] AUC: ", round(result$metrics$auc, 3))
            flush.console()
          } else {
            # Multiclass AUC (one-vs-rest average)
            auc_values <- c()
            for (class_name in levels(data$target)) {
              binary_obs <- ifelse(cv_preds$obs == class_name, 1, 0)
              binary_pred <- cv_preds[, class_name]
              
              if (length(unique(binary_obs)) > 1) {
                roc_obj <- pROC::roc(binary_obs, binary_pred, quiet = TRUE)
                auc_values <- c(auc_values, as.numeric(pROC::auc(roc_obj)))
              }
            }
            result$metrics$auc <- mean(auc_values, na.rm = TRUE)
            message("[Metrics] Mean AUC: ", round(result$metrics$auc, 3))
            flush.console()
          }
        } else {
          message("[WARNING] Probability predictions not available, skipping AUC calculation")
          flush.console()
          result$metrics$auc <- NA
        }
      }
      
      message("[Metrics] Extraction completed successfully")
      flush.console()
      
    }, error = function(e) {
      message("[ERROR] Failed to extract metrics: ", e$message)
      flush.console()
      # Set default values so the function doesn't fail completely
      result$metrics$accuracy <<- NA
      result$metrics$auc <<- NA
      result$metrics$sensitivity <<- NA
      result$metrics$specificity <<- NA
    })
  }
  
  message("[COMPLETE] train_model_advanced finished. Returning result object.")
  flush.console()
  
  return(result)
}

#' Train C5.0 decision tree model
#'
#' @description
#' Trains a C5.0 classification model with boosting trials. C5.0 is an 
#' efficient algorithm for multi-class classification with built-in feature
#' importance calculation.
#'
#' @param data A data.frame with 'target' column (factor) and numeric predictors
#' @param trials Number of boosting trials (default: 50)
#' @param rules Logical. Use rule-based model instead of tree (default: FALSE)
#' @param seed Random seed for reproducibility (default: 120)
#'
#' @return A C5.0 model object
#'
#' @details
#' C5.0 algorithm:
#' - Builds decision trees using information gain
#' - Supports boosting to improve accuracy
#' - Handles missing values automatically
#' - Provides variable importance scores
#'
#' @examples
#' # Basic C5.0 model
#' model <- train_c50_model(ml_data)
#' 
#' # With more trials
#' model <- train_c50_model(ml_data, trials = 100)
#'
#' @export
train_c50_model <- function(data, trials = 50, rules = FALSE, seed = 120) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!"target" %in% colnames(data)) {
    stop("Data must contain 'target' column")
  }
  
  if (!is.factor(data$target)) {
    stop("'target' column must be a factor")
  }
  
  # Train C5.0 model
  model <- C50::C5.0(
    target ~ ., 
    data = data,
    trials = trials, 
    rules = rules,
    control = C50::C5.0Control(seed = seed),
    na.action = na.omit
  )
  
  return(model)
}


#' Extract feature importance from C5.0 model
#'
#' @description
#' Extracts variable importance scores from a trained C5.0 model and returns
#' the top N most important features.
#'
#' @param model A C5.0 model object
#' @param top_n Number of top variables to return (default: 30)
#'
#' @return A character vector of variable names, ordered by importance
#'
#' @details
#' C5.0 importance is based on:
#' - Usage: How often a variable is used in splits
#' - Overall: Weighted importance across all trees
#' Train Random Forest model
#'
#' @description
#' Trains a Random Forest classification model. RF is an ensemble method that
#' builds multiple decision trees and aggregates their predictions.
#'
#' @param data A data.frame with 'target' column (factor) and numeric predictors
#' @param ntree Number of trees to grow (default: 500)
#' @param mtry Number of variables randomly sampled at each split (default: sqrt(p))
#'
#' @return A randomForest model object
#'
#' @details
#' Random Forest advantages:
#' - Robust to overfitting
#' - Handles high-dimensional data well
#' - Provides variable importance (Gini importance)
#' - Can handle missing values (with rfImpute)
#'
#' @examples
#' # Basic RF model
#' model <- train_randomforest_model(ml_data)
#' 
#' # More trees
#' model <- train_randomforest_model(ml_data, ntree = 1000)
#'
#' @export
train_randomforest_model <- function(data, ntree = 500, mtry = NULL) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!"target" %in% colnames(data)) {
    stop("Data must contain 'target' column")
  }
  
  if (!is.factor(data$target)) {
    stop("'target' column must be a factor")
  }
  
  # Remove rows with NAs
  data_clean <- na.omit(data)
  
  if (nrow(data_clean) == 0) {
    stop("No valid rows after removing NAs")
  }
  
  # Calculate appropriate mtry if not specified
  if (is.null(mtry)) {
    num_predictors <- ncol(data_clean) - 1
    mtry <- floor(sqrt(num_predictors))
  }
  
  # Train Random Forest
  model <- randomForest::randomForest(
    target ~ ., 
    data = data_clean,
    ntree = ntree,
    mtry = mtry,
    na.action = na.omit
  )
  
  return(model)
}


#' Extract feature importance from Random Forest model
#'
#' @description
#' Extracts variable importance scores from a trained Random Forest model.
#'
#' @param model A randomForest model object
#' @param top_n Number of top variables to return (default: 30)
#'
#' @return A character vector of variable names, ordered by importance
#'
#' @details
#' RF importance is based on Mean Decrease in Gini impurity:
#' Higher values = more important for classification
#' Perform Recursive Feature Elimination (RFE) for SVM
#'
#' @description
#' Uses RFE to identify the most important variables for SVM classification.
#' RFE recursively removes the least important features and rebuilds the model.
#'
#' @param data A data.frame with 'target' column (factor) and numeric predictors.
#'   Data should be scaled before using this function.
#' @param sizes Vector of feature subset sizes to test (default: 1:10)
#' @param cv_folds Number of cross-validation folds (default: 2)
#'
#' @return A character vector of selected important variables
#'
#' @details
#' RFE process:
#' 1. Train model on all features
#' 2. Rank features by importance
#' 3. Remove least important feature
#' 4. Repeat until reaching target size
#' 5. Select best performing subset via CV
#'
#' @examples
#' # Scale data first
#' data_scaled <- scale_ml_data(data)
#' 
#' # Run RFE
#' important_vars <- perform_rfe_svm(data_scaled, sizes = c(5, 10, 15))
#'
#' @export
perform_rfe_svm <- function(data, sizes = c(1:10), cv_folds = 2) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!"target" %in% colnames(data)) {
    stop("Data must contain 'target' column")
  }
  
  # Configure RFE control
  control <- caret::rfeControl(
    functions = caret::caretFuncs, 
    method = "cv", 
    number = cv_folds
  )
  
  # Separate features and target
  features <- data[, -which(names(data) == "target")]
  target <- data$target
  
  # Run RFE
  rfe_results <- caret::rfe(
    x = features, 
    y = target, 
    sizes = sizes,
    rfeControl = control
  )
  
  # Extract selected variables
  important_vars <- caret::predictors(rfe_results)
  
  return(important_vars)
}


#' Train SVM model with linear kernel
#'
#' @description
#' Trains a Support Vector Machine with linear kernel for classification.
#'
#' @param data A data.frame with 'target' column (factor) and numeric predictors.
#'   Data should be scaled before using this function.
#' @param cost Cost parameter for SVM (default: 10)
#' @param kernel Kernel type (default: "linear")
#'
#' @return An SVM model object (e1071)
#'
#' @details
#' Linear SVM finds a hyperplane that maximally separates classes.
#' The cost parameter controls the trade-off between:
#' - Maximizing margin (low cost)
#' - Minimizing misclassification (high cost)
#'
#' @examples
#' # Scale data first
#' data_scaled <- scale_ml_data(data)
#' 
#' # Train SVM
#' model <- train_svm_model(data_scaled, cost = 10)
#'
#' @export
train_svm_model <- function(data, cost = 10, kernel = "linear") {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!"target" %in% colnames(data)) {
    stop("Data must contain 'target' column")
  }
  
  # Train SVM
  model <- e1071::svm(
    formula = target ~ ., 
    data = data, 
    kernel = kernel, 
    cost = cost
  )
  
  return(model)
}


#' Scale numeric predictors for ML
#'
#' @description
#' Scales numeric columns (excluding 'target') to zero mean and unit variance.
#' Essential preprocessing for SVM and other distance-based algorithms.
#'
#' @param data A data.frame with 'target' column and numeric predictors
#'
#' @return A data.frame with scaled numeric columns
#'
#' @details
#' Scaling formula: z = (x - mean(x)) / sd(x)
#' Only numeric columns are scaled; 'target' column is preserved.
#'
#' @examples
#' data_scaled <- scale_ml_data(ml_data)
#'
#' @export
scale_ml_data <- function(data) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!"target" %in% colnames(data)) {
    stop("Data must contain 'target' column")
  }
  
  # Scale numeric columns (excluding 'target')
  data_scaled <- data
  numeric_columns <- sapply(data_scaled, is.numeric)
  data_scaled[, numeric_columns & names(data_scaled) != "target"] <- scale(
    data_scaled[, numeric_columns & names(data_scaled) != "target"]
  )
  
  return(data_scaled)
}


#' Train XGBoost model (binary or multiclass)
#'
#' @description
#' Trains an XGBoost gradient boosting model. Automatically detects binary vs
#' multiclass classification and sets appropriate objective function.
#'
#' @param data A data.frame with 'target' column (factor) and numeric predictors.
#'   All columns must be numeric or will be converted.
#' @param max_depth Maximum tree depth (default: 3)
#' @param eta Learning rate (default: 0.1)
#' @param nrounds Number of boosting rounds (default: 100)
#' @param verbose Print training progress (default: 0 = silent)
#'
#' @return A list with:
#'   - model: xgboost model object
#'   - matrix_train: Feature matrix used for training
#'   - target_train: Encoded target values
#'   - num_classes: Number of classes (2 = binary, >2 = multiclass)
#'
#' @details
#' Binary classification:
#' - Objective: "binary:logistic"
#' - Target encoded as 0/1
#' 
#' Multiclass classification:
#' - Objective: "multi:softmax"
#' - Target encoded as 0, 1, 2, ..., (K-1)
#' - Requires num_class parameter
#'
#' @examples
#' # Binary classification
#' xgb_result <- train_xgboost_model(binary_data)
#' 
#' # Multiclass with more rounds
#' xgb_result <- train_xgboost_model(multiclass_data, nrounds = 200)
#'
#' @export
train_xgboost_model <- function(data, max_depth = 3, eta = 0.1, nrounds = 100, verbose = 0) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!"target" %in% colnames(data)) {
    stop("Data must contain 'target' column")
  }
  
  # Convert all columns to numeric (factors become integers)
  data_xgb <- as.data.frame(lapply(data, function(x) {
    if (is.factor(x)) as.numeric(x) else x
  }))
  
  # Determine number of classes
  num_classes <- length(unique(data_xgb$target))
  
  # Prepare data based on classification type
  if (num_classes == 2) {
    # Binary classification
    data_xgb$target <- ifelse(data_xgb$target == min(data_xgb$target), 0, 1)
    objective_type <- "binary:logistic"
    
    matrix_train <- as.matrix(data_xgb[, -which(names(data_xgb) == "target")])
    target_train <- data_xgb$target
    
    model <- xgboost::xgboost(
      data = matrix_train, 
      label = target_train, 
      max_depth = max_depth, 
      eta = eta, 
      nrounds = nrounds, 
      objective = objective_type, 
      verbose = verbose
    )
    
  } else {
    # Multiclass classification
    data_xgb$target <- as.integer(as.factor(data_xgb$target)) - 1
    objective_type <- "multi:softmax"
    
    matrix_train <- as.matrix(data_xgb[, -which(names(data_xgb) == "target")])
    target_train <- data_xgb$target
    
    model <- xgboost::xgboost(
      data = matrix_train, 
      label = target_train, 
      max_depth = max_depth, 
      eta = eta, 
      nrounds = nrounds, 
      objective = objective_type, 
      num_class = num_classes,
      verbose = verbose
    )
  }
  
  # Return model and training data
  result <- list(
    model = model,
    matrix_train = matrix_train,
    target_train = target_train,
    num_classes = num_classes
  )
  
  return(result)
}


#' Extract feature importance from XGBoost model
#'
#' @description
#' Extracts variable importance from XGBoost model using Gain metric.
#'
#' @param xgb_result Output from train_xgboost_model()
#' @param top_n Number of top variables to return (default: 30)
#'
#' @return A character vector of variable names, ordered by Gain importance
#'
#' @details
#' XGBoost importance metrics:
#' - Gain: Improvement in accuracy brought by a feature
#' - Cover: Number of observations related to this feature

#' Calculate SHAP values for XGBoost model
#'
#' @description
#' Computes SHAP (SHapley Additive exPlanations) values for model 
#' interpretability. SHAP values show the contribution of each feature
#' to individual predictions.
#'
#' @param xgb_result Output from train_xgboost_model()
#'
#' @return A shapviz object with SHAP values
#'
#' @details
#' SHAP values provide:
#' - Feature importance: Global view of feature impact
#' - Prediction explanation: Why a specific prediction was made
#' - Feature interactions: How features work together
#'
#' Use with shapviz functions:
#' - sv_importance(): Importance plot
#' - sv_waterfall(): Single prediction breakdown
#' - sv_force(): Force plot for prediction
#' - sv_dependence(): Feature effect plot
#'
#' @examples
#' xgb_result <- train_xgboost_model(data)
#' shap_values <- calculate_shap_values(xgb_result)
#' 
#' # Importance plot
#' shapviz::sv_importance(shap_values)
#'
#' @export
calculate_shap_values <- function(xgb_result) {
  
  # Extract model and training matrix
  model <- xgb_result$model
  matrix_train <- xgb_result$matrix_train
  
  # Calculate SHAP values
  shap_values <- shapviz::shapviz(model, X_pred = matrix_train)
  
  return(shap_values)
}


#' Prepare data for supervised ML
#'
#' @description
#' Preprocesses data for machine learning by converting character columns
#' to factors, renaming target variable, and setting row names.
#'
#' @param data A data.frame with sample metadata and expression values
#' @param group_var Character. Name of the column to use as target variable
#' @param id_column Character. Name of the ID column (default: "id")
#'
#' @return A data.frame ready for ML:
#'   - 'target' column as factor
#'   - Character columns converted to factors
#'   - Row names set to sample IDs
#'
#' @details
#' This is a preprocessing step that ensures data is in the correct format
#' for supervised ML functions.
#'
#' @examples
#' ml_data <- prepare_ml_data(metadata, group_var = "Disease_Status")
#' model <- train_randomforest_model(ml_data)
#'
#' @export
prepare_ml_data <- function(data, group_var, id_column = "id", impute_method = "knn") {

  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }

  if (!group_var %in% colnames(data)) {
    stop(paste("Group variable", group_var, "not found in data"))
  }

  if (!id_column %in% colnames(data)) {
    stop(paste("ID column", id_column, "not found in data"))
  }

  # Preprocess: drop rows without a label (can't train on unknown target)
  ml_data <- data %>%
    dplyr::mutate(across(where(is.character), as.factor)) %>%
    dplyr::rename(target = !!rlang::sym(group_var)) %>%
    dplyr::filter(!is.na(target)) %>%
    dplyr::mutate(target = droplevels(as.factor(target))) %>%
    tibble::column_to_rownames(var = id_column)

  # Drop all-NA predictors, then impute the rest with the same knn/rf method used
  # for peptides (clinical metadata may still carry NAs).
  ml_data <- ml_data[, vapply(ml_data, function(x) any(!is.na(x)), logical(1)), drop = FALSE]
  ml_data <- impute_missing_mixed(ml_data, method = impute_method)

  return(ml_data)
}


#' Create 2D decision boundary plot for classification models
#'
#' @description
#' Creates a decision boundary visualization for classification models using
#' the two most important features. Supports C5.0, Random Forest, and SVM.
#'
#' @param data A data.frame with 'target' column (factor) and numeric predictors
#' @param model_type Character: "c50", "rf", or "svm"
#' @param important_vars Character vector of important variable names (minimum 2 required)
#' @param grid_resolution Resolution of decision boundary grid (default: 100)
#' @param ... Additional parameters passed to model training functions
#'   - For C5.0: trials (default: 100)
#'   - For RF: ntree (default: 500)
#'   - For SVM: cost (default: 10), requires scaled data
#'
#' @return A ggplot2 object showing data points and decision boundary
#'
#' @details
#' Process:
#' 1. Select top 2 important variables
#' 2. Train 2D model with only those variables
#' 3. Create prediction grid (grid_resolution x grid_resolution)
#' 4. Predict class for each grid point
#' 5. Overlay original data points on colored grid
#'
#' The decision boundary is visualized as a colored background where each
#' color represents a predicted class region.
#'
#' @examples
#' # C5.0 decision boundary
#' c5_vars <- extract_c50_importance(model, top_n = 30)
#' plot <- create_decision_boundary_plot(data, "c50", c5_vars, trials = 100)
#' 
#' # Random Forest decision boundary
#' rf_vars <- extract_rf_importance(model, top_n = 30)
#' plot <- create_decision_boundary_plot(data, "rf", rf_vars)
#' 
#' # SVM decision boundary (data must be scaled)
#' data_scaled <- scale_ml_data(data)
#' svm_vars <- perform_rfe_svm(data_scaled)
#' plot <- create_decision_boundary_plot(data_scaled, "svm", svm_vars, cost = 10)
#'
#' @export
create_decision_boundary_plot <- function(data, model_type, important_vars, 
                                          grid_resolution = 100, ...) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!"target" %in% colnames(data)) {
    stop("Data must contain 'target' column")
  }
  
  if (length(important_vars) < 2) {
    stop("At least 2 important variables are required for 2D plot")
  }
  
  model_type <- tolower(model_type)
  if (!model_type %in% c("c50", "rf", "svm")) {
    stop("model_type must be 'c50', 'rf', or 'svm'")
  }
  
  # Select only numeric columns and target
  data <- data %>%
    dplyr::select(target, where(is.numeric))
  
  # Select top 2 important variables
  predictors <- important_vars[1:2]
  
  # Filter data to only include target and top 2 predictors
  data_2d <- data %>% dplyr::select(target, all_of(predictors))
  
  # Verify selected variables are numeric
  if (!all(sapply(data_2d[, predictors], is.numeric))) {
    stop("Selected variables must be numeric")
  }
  
  # Train 2D model based on type
  formula_2d <- as.formula(paste("target ~", paste(predictors, collapse = " + ")))
  
  if (model_type == "c50") {
    # Extract trials parameter or use default
    trials <- list(...)$trials
    if (is.null(trials)) trials <- 100
    
    model_2d <- C50::C5.0(
      formula = formula_2d, 
      data = data_2d,
      trials = trials, 
      rules = FALSE,
      control = C50::C5.0Control(seed = 1234),
      na.action = na.omit
    )
    plot_title <- "Decision frontier of model C5.0"
    
  } else if (model_type == "rf") {
    # Extract ntree parameter or use default
    ntree <- list(...)$ntree
    if (is.null(ntree)) ntree <- 500
    
    model_2d <- randomForest::randomForest(
      formula = formula_2d, 
      data = data_2d, 
      ntree = ntree,
      na.action = na.omit
    )
    plot_title <- "Decision frontier of model Random Forest"
    
  } else if (model_type == "svm") {
    # Extract cost parameter or use default
    cost <- list(...)$cost
    if (is.null(cost)) cost <- 10
    
    model_2d <- e1071::svm(
      formula = formula_2d, 
      data = data_2d, 
      kernel = "linear", 
      cost = cost
    )
    plot_title <- "Decision frontier of model SVM"
  }
  
  # Get min/max for grid
  x_min <- min(data_2d[[predictors[1]]], na.rm = TRUE)
  x_max <- max(data_2d[[predictors[1]]], na.rm = TRUE)
  y_min <- min(data_2d[[predictors[2]]], na.rm = TRUE)
  y_max <- max(data_2d[[predictors[2]]], na.rm = TRUE)
  
  # Create prediction grid
  grid <- expand.grid(
    x1 = seq(x_min, x_max, length.out = grid_resolution),
    x2 = seq(y_min, y_max, length.out = grid_resolution)
  )
  
  # Rename grid columns to match predictors
  names(grid) <- predictors
  
  # Predict on grid
  grid$target <- predict(model_2d, grid)
  grid$target <- as.factor(grid$target)
  
  # Add tooltips to actual data points
  data_2d$tooltip <- paste0(
    "<b>Prediction: ", data_2d$target, "</b><br/>",
    predictors[1], ": ", round(data_2d[[predictors[1]]], 2), "<br/>",
    predictors[2], ": ", round(data_2d[[predictors[2]]], 2)
  )
  data_2d$data_id <- seq_len(nrow(data_2d))
  
  # Create plot using aes() with .data pronoun for dynamic variable names
  plot <- ggplot2::ggplot(data_2d, ggplot2::aes(
    x = .data[[predictors[1]]], 
    y = .data[[predictors[2]]], 
    color = target
  )) +
    # Background grid (decision boundary)
    ggplot2::geom_point(
      data = grid, 
      ggplot2::aes(x = .data[[predictors[1]]], y = .data[[predictors[2]]], color = target), 
      alpha = 0.08, 
      size = 1.2,
      show.legend = FALSE
    ) +
    # Actual data points (interactive)
    ggiraph::geom_point_interactive(
      ggplot2::aes(tooltip = tooltip, data_id = data_id),
      size = 4,
      alpha = 0.9
    ) +
    ggplot2::labs(title = plot_title) +
    ggplot2::theme_minimal()
  
  return(plot)
}


#' Create performance summary UI cards
#'
#' @description
#' Generates HTML cards summarizing model performance metrics, similar to
#' DBSCAN and PLS-DA summary cards.
#'
#' @param result Output from train_model_advanced()
#' @param model_name Character. Display name of the model (e.g., "Random Forest")
#'
#' @return A Shiny tagList with performance metric cards
#'
#' @details
#' Creates visually appealing summary cards showing:
#' - Accuracy with confidence interval
#' - AUC score
#' - Sensitivity and Specificity
#' - Number of features used
#' - CV configuration (if used)
#' - RFE status (if used)
#'
#' @examples
#' result <- train_model_advanced(data, "rf", use_cv = TRUE)
#' ui_cards <- create_performance_summary_cards(result, "Random Forest")
#'
#' @export

#' Format Variable Importance DataFrame (Unified Approach)
#'
#' Normalizes variable importance from any caret varImp object to consistent format
#' with Feature and Importance columns only (no model-specific columns)
#'
#' @param varimp_obj varImp object from caret::varImp()
#' @param top_n Number of top features to return
#' @return Data frame with Feature and Importance columns, or NULL if unavailable
#' @export
format_varimp_df <- function(varimp_obj, top_n = 30) {
  if (is.null(varimp_obj)) return(NULL)

  df <- as.data.frame(varimp_obj$importance)
  if (ncol(df) == 0 || nrow(df) == 0) return(NULL)

  # caret returns "Overall" for most models, but per-class columns for 2-class
  # SVM/others — fall back to the row mean of the numeric importance columns.
  num <- df[, vapply(df, is.numeric, logical(1)), drop = FALSE]
  imp <- if ("Overall" %in% names(df)) df$Overall else rowMeans(num, na.rm = TRUE)

  out <- data.frame(Feature = rownames(df), Importance = imp, stringsAsFactors = FALSE)
  out <- out[order(-out$Importance), , drop = FALSE]
  utils::head(out, top_n)
}

#' Plot Variable Importance Histogram (Unified Approach)
#'
#' Creates a horizontal bar plot of feature importance from standardized format
#'
#' @param varimp_df Data frame with Feature and Importance columns
#' @return ggplot2 object
#' @export
plot_varimp_histogram <- function(varimp_df) {
  if (is.null(varimp_df) || nrow(varimp_df) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text", x = 0, y = 0, label = "No variable importance available") +
        ggplot2::theme_void()
    )
  }
  
  ggplot2::ggplot(
    varimp_df,
    ggplot2::aes(
      x = reorder(Feature, Importance),
      y = Importance
    )
  ) +
    ggplot2::geom_col(fill = "#17a589", alpha = 0.85) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Feature Importance",
      x = NULL,
      y = "Relative importance"
    ) +
    ggplot2::theme_minimal()
}

create_performance_summary_cards <- function(result, model_name) {
  
  # Extract metrics
  accuracy <- ifelse(!is.null(result$metrics$accuracy), 
                    round(result$metrics$accuracy * 100, 1), 
                    NA)
  auc <- ifelse(!is.null(result$metrics$auc), 
               round(result$metrics$auc, 3), 
               NA)
  sensitivity <- ifelse(!is.null(result$metrics$sensitivity), 
                       round(result$metrics$sensitivity * 100, 1), 
                       NA)
  specificity <- ifelse(!is.null(result$metrics$specificity), 
                       round(result$metrics$specificity * 100, 1), 
                       NA)
  
  n_features <- length(result$selected_features)
  
  # Build method description
  method_parts <- c(model_name)
  if (result$use_rfe) method_parts <- c(method_parts, "RFE")
  if (result$use_cv) method_parts <- c(method_parts, paste0(result$model$control$number, "-Fold CV"))
  method_desc <- paste(method_parts, collapse = " + ")
  
  # Create card UI - COMPACT VERSION
  shiny::tagList(
    tags$div(
      style = "background: #f5f5f5; padding: 12px; border-radius: 6px; margin-bottom: 12px;",
      
      # Metrics in single row
      fluidRow(
        column(3,
          tags$div(
            style = "background: white; border-radius: 4px; padding: 10px; text-align: center; box-shadow: 0 1px 3px rgba(0,0,0,0.1);",
            tags$div(
              style = "font-size: 1.5em; font-weight: 700; color: #4caf50;",
              ifelse(!is.na(accuracy), paste0(accuracy, "%"), "N/A")
            ),
            tags$div(
              style = "color: #666; font-size: 0.75em; margin-top: 3px;",
              strong("Accuracy")
            )
          )
        ),
        column(3,
          tags$div(
            style = "background: white; border-radius: 4px; padding: 10px; text-align: center; box-shadow: 0 1px 3px rgba(0,0,0,0.1);",
            tags$div(
              style = "font-size: 1.5em; font-weight: 700; color: #17a589;",
              ifelse(!is.na(auc), auc, "N/A")
            ),
            tags$div(
              style = "color: #666; font-size: 0.75em; margin-top: 3px;",
              strong("AUC")
            )
          )
        ),
        column(3,
          tags$div(
            style = "background: white; border-radius: 4px; padding: 10px; text-align: center; box-shadow: 0 1px 3px rgba(0,0,0,0.1);",
            tags$div(
              style = "font-size: 1.5em; font-weight: 700; color: #ff9800;",
              ifelse(!is.na(sensitivity), paste0(sensitivity, "%"), "N/A")
            ),
            tags$div(
              style = "color: #666; font-size: 0.75em; margin-top: 3px;",
              strong("Sens")
            )
          )
        ),
        column(3,
          tags$div(
            style = "background: white; border-radius: 4px; padding: 10px; text-align: center; box-shadow: 0 1px 3px rgba(0,0,0,0.1);",
            tags$div(
              style = "font-size: 1.5em; font-weight: 700; color: #2196F3;",
              ifelse(!is.na(specificity), paste0(specificity, "%"), "N/A")
            ),
            tags$div(
              style = "color: #666; font-size: 0.75em; margin-top: 3px;",
              strong("Spec")
            )
          )
        )
      ),
      
      # Compact info line
      tags$div(
        style = "margin-top: 10px; padding: 8px; background: white; border-radius: 4px; font-size: 12px; color: #666;",
        tags$span(
          icon("cogs", style = "color: #17a589; margin-right: 5px;"),
          strong(method_desc), " | ",
          n_features, " features"
        )
      )
    )
  )
}

