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
#
# Dependencies:
#   - C50: C5.0 decision trees
#   - randomForest: Random Forest
#   - e1071: SVM
#   - caret: RFE, model training
#   - xgboost: Gradient boosting
#   - shapviz: SHAP value visualization
#   - dplyr, tidyr: Data manipulation
#
# Author: MicroarrAI Team
# Last Modified: 2024
# =============================================================================

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
#'
#' @examples
#' model <- train_c50_model(data)
#' top_vars <- extract_c50_importance(model, top_n = 15)
#'
#' @export
extract_c50_importance <- function(model, top_n = 30) {
  
  # Extract importance
  importance <- C50::C5imp(model)
  
  # Get top N variables
  top_vars <- as.data.frame(importance) %>%
    dplyr::arrange(desc(Overall)) %>%
    tibble::rownames_to_column(var = "Var") %>%
    dplyr::slice_head(n = top_n) %>%
    dplyr::pull(Var)
  
  return(top_vars)
}


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
#'
#' @examples
#' model <- train_randomforest_model(data)
#' top_vars <- extract_rf_importance(model, top_n = 15)
#'
#' @export
extract_rf_importance <- function(model, top_n = 30) {
  
  # Extract importance using caret::varImp
  importance <- caret::varImp(model)
  
  # Get top N variables
  top_vars <- as.data.frame(importance) %>%
    dplyr::arrange(desc(Overall)) %>%
    tibble::rownames_to_column(var = "Var") %>%
    dplyr::slice_head(n = top_n) %>%
    dplyr::pull(Var)
  
  return(top_vars)
}


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
#' - Frequency: Number of times feature is used in trees
#'
#' @examples
#' xgb_result <- train_xgboost_model(data)
#' top_vars <- extract_xgboost_importance(xgb_result, top_n = 15)
#'
#' @export
extract_xgboost_importance <- function(xgb_result, top_n = 30) {
  
  # Extract model and training matrix
  model <- xgb_result$model
  matrix_train <- xgb_result$matrix_train
  
  # Get importance
  importance <- xgboost::xgb.importance(
    feature_names = colnames(matrix_train), 
    model = model
  )
  
  # Get top N variables by Gain
  top_vars <- importance %>%
    dplyr::arrange(desc(Gain)) %>%
    dplyr::slice_head(n = top_n) %>%
    dplyr::pull(Feature)
  
  return(top_vars)
}


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
prepare_ml_data <- function(data, group_var, id_column = "id") {
  
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
  
  # Preprocess
  ml_data <- data %>%
    dplyr::mutate(across(where(is.character), as.factor)) %>%
    dplyr::rename(target = !!rlang::sym(group_var)) %>%
    dplyr::mutate(target = as.factor(target)) %>%
    tibble::column_to_rownames(var = id_column)
  
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
  
  # Create plot using aes() with .data pronoun for dynamic variable names
  plot <- ggplot2::ggplot(data_2d, ggplot2::aes(
    x = .data[[predictors[1]]], 
    y = .data[[predictors[2]]], 
    color = target
  )) +
    ggplot2::geom_point(size = 2) +
    ggplot2::geom_point(
      data = grid, 
      ggplot2::aes(x = .data[[predictors[1]]], y = .data[[predictors[2]]], color = target), 
      alpha = 0.1, 
      size = 1.5
    ) +
    ggplot2::labs(title = plot_title) +
    ggplot2::theme_minimal()
  
  return(plot)
}
