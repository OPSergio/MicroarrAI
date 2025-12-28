# =============================================================================
# REGRESSION_MODELS.R
# Regression Models Module
# =============================================================================
# Description:
#   Functions for peptide-level regression analysis:
#   - Binary logistic regression (GLM with binomial family)
#   - Multinomial logistic regression (3+ classes)
#   - Performance metrics (Accuracy, AUC, Sensitivity, Specificity)
#   - ROC curve calculation
#   - Model predictions
#
# Dependencies:
#   - tidymodels: Multinomial regression (parsnip, workflows)
#   - caret: GLM training, confusionMatrix
#   - pROC: ROC curves and AUC calculation
#   - dplyr, tidyr: Data manipulation
#
# Author: MicroarrAI Team
# Last Modified: 2024
# =============================================================================

#' Fit binary logistic regression (GLM)
#'
#' @description
#' Fits a logistic regression model for binary classification using caret::train()
#' with GLM method and binomial family.
#'
#' @param expression_data Numeric vector. Expression values for a single peptide
#' @param target Factor with 2 levels. Target variable (e.g., Disease vs Healthy)
#' @param method Character. Training method (default: "glm")
#' @param family Character. GLM family (default: "binomial")
#'
#' @return A list with:
#'   - model: Trained caret model object
#'   - predictions: Predicted class labels
#'   - probabilities: Predicted probabilities for each class
#'
#' @details
#' Binary logistic regression models the log-odds of the outcome:
#' log(P(Y=1) / P(Y=0)) = β₀ + β₁X
#' 
#' The function uses caret::train() which provides:
#' - Automatic handling of factor levels
#' - Built-in cross-validation options
#' - Consistent API with other caret models
#'
#' @examples
#' # Fit GLM for single peptide
#' result <- fit_binary_glm(
#'   expression_data = data$IgE_Pep123,
#'   target = data$Disease_Status
#' )
#' 
#' # Access predictions
#' predictions <- result$predictions
#' probabilities <- result$probabilities
#'
#' @export
fit_binary_glm <- function(expression_data, target, 
                           method = "glm", family = "binomial") {
  
  # Input validation
  if (!is.numeric(expression_data)) {
    stop("expression_data must be numeric")
  }
  
  if (!is.factor(target)) {
    stop("target must be a factor")
  }
  
  if (nlevels(target) != 2) {
    stop("target must have exactly 2 levels for binary classification")
  }
  
  if (length(expression_data) != length(target)) {
    stop("expression_data and target must have the same length")
  }
  
  # Create data frame
  model_data <- data.frame(
    Expression = expression_data,
    target = target
  )
  
  # Fit GLM using caret
  model <- caret::train(
    target ~ Expression, 
    data = model_data,
    method = method,
    family = family
  )
  
  # Make predictions
  predictions <- predict(model, model_data)
  probabilities <- predict(model, model_data, type = "prob")
  
  # Return results
  result <- list(
    model = model,
    predictions = predictions,
    probabilities = probabilities
  )
  
  return(result)
}


#' Fit multinomial logistic regression
#'
#' @description
#' Fits a multinomial logistic regression model for multi-class classification
#' (3 or more classes) using tidymodels framework.
#'
#' @param expression_data Numeric vector. Expression values for a single peptide
#' @param target Factor with 3+ levels. Target variable
#' @param engine Character. Computational engine (default: "nnet" for multinom)
#' @param penalty Numeric. Regularization penalty (default: 0 = no penalty)
#'
#' @return A list with:
#'   - model: Fitted parsnip model object
#'   - predictions: Predicted class labels
#'   - probabilities: Predicted probabilities for each class (data.frame)
#'
#' @details
#' Multinomial logistic regression extends binary logistic regression to K classes
#' by fitting K-1 binary models (one class as reference).
#' 
#' For each non-reference class k:
#' log(P(Y=k) / P(Y=ref)) = β₀ₖ + β₁ₖX
#'
#' Uses tidymodels::multinom_reg() with nnet engine (neural network backend).
#'
#' @examples
#' # Fit multinomial for 3-class problem
#' result <- fit_multinomial_regression(
#'   expression_data = data$IgG_Pep456,
#'   target = factor(c("Healthy", "Mild", "Severe"))
#' )
#' 
#' # Access predictions
#' predictions <- result$predictions
#' probabilities <- result$probabilities
#'
#' @export
fit_multinomial_regression <- function(expression_data, target, 
                                       engine = "nnet", penalty = 0) {
  
  # Input validation
  if (!is.numeric(expression_data)) {
    stop("expression_data must be numeric")
  }
  
  if (!is.factor(target)) {
    stop("target must be a factor")
  }
  
  if (nlevels(target) < 3) {
    stop("target must have 3 or more levels for multinomial regression")
  }
  
  if (length(expression_data) != length(target)) {
    stop("expression_data and target must have the same length")
  }
  
  # Create data frame
  model_data <- data.frame(
    Expression = expression_data,
    target = target
  )
  
  # Define multinomial model
  multinom_model <- parsnip::multinom_reg(penalty = penalty) %>%
    parsnip::set_engine(engine) %>%
    parsnip::set_mode("classification")
  
  # Fit model
  fitted_model <- multinom_model %>%
    parsnip::fit(target ~ Expression, data = model_data)
  
  # Make predictions
  predictions <- predict(fitted_model, model_data)$.pred_class
  probabilities <- predict(fitted_model, model_data, type = "prob")
  
  # Return results
  result <- list(
    model = fitted_model,
    predictions = predictions,
    probabilities = probabilities
  )
  
  return(result)
}


#' Calculate classification performance metrics
#'
#' @description
#' Computes Accuracy, Sensitivity, Specificity, and AUC for a classification model.
#'
#' @param predictions Factor. Predicted class labels
#' @param actual Factor. Actual class labels
#' @param probabilities Numeric vector or data.frame. Predicted probabilities.
#'   For binary: vector of probabilities for positive class
#'   For multiclass: data.frame with columns for each class
#'
#' @return A list with:
#'   - accuracy: Overall accuracy (0-1)
#'   - sensitivity: True positive rate (binary only, 0-1)
#'   - specificity: True negative rate (binary only, 0-1)
#'   - auc: Area under ROC curve (0-1). For multiclass, uses macro-average.
#'   - confusion_matrix: Confusion matrix object (from caret)
#'
#' @details
#' Metrics:
#' - Accuracy = (TP + TN) / (TP + TN + FP + FN)
#' - Sensitivity (Recall) = TP / (TP + FN)
#' - Specificity = TN / (TN + FP)
#' - AUC: Area Under ROC Curve (discrimination ability)
#'
#' For binary classification:
#' - Uses pROC::roc() for AUC calculation
#' - Returns Sensitivity and Specificity from confusion matrix
#'
#' For multiclass:
#' - Calculates macro-average AUC (one-vs-rest strategy)
#' - Sensitivity/Specificity are class-averaged
#'
#' @examples
#' # Binary classification
#' glm_result <- fit_binary_glm(data$Expression, data$target)
#' metrics <- calculate_performance_metrics(
#'   predictions = glm_result$predictions,
#'   actual = data$target,
#'   probabilities = glm_result$probabilities[, 2]
#' )
#' 
#' # Multiclass classification
#' multinom_result <- fit_multinomial_regression(data$Expression, data$target)
#' metrics <- calculate_performance_metrics(
#'   predictions = multinom_result$predictions,
#'   actual = data$target,
#'   probabilities = multinom_result$probabilities
#' )
#'
#' @export
calculate_performance_metrics <- function(predictions, actual, probabilities) {
  
  # Input validation
  if (length(predictions) != length(actual)) {
    stop("predictions and actual must have the same length")
  }
  
  if (!is.factor(predictions)) {
    predictions <- as.factor(predictions)
  }
  
  if (!is.factor(actual)) {
    actual <- as.factor(actual)
  }
  
  # Ensure same levels
  levels(predictions) <- levels(actual)
  
  # Calculate confusion matrix
  cm <- caret::confusionMatrix(predictions, actual)
  
  # Extract accuracy
  accuracy <- cm$overall["Accuracy"]
  
  # Initialize sensitivity and specificity
  sensitivity <- NA
  specificity <- NA
  auc <- NA
  
  # Binary classification
  if (nlevels(actual) == 2) {
    # Get sensitivity and specificity from confusion matrix
    if ("Sensitivity" %in% names(cm$byClass)) {
      sensitivity <- cm$byClass["Sensitivity"]
      specificity <- cm$byClass["Specificity"]
    }
    
    # Calculate AUC using pROC
    if (is.numeric(probabilities)) {
      # probabilities should be for the positive class (second level)
      roc_obj <- pROC::roc(
        response = actual, 
        predictor = probabilities,
        levels = levels(actual),
        direction = "<"
      )
      auc <- as.numeric(pROC::auc(roc_obj))
    }
    
  } else {
    # Multiclass classification
    # Average sensitivity and specificity across classes
    if ("Sensitivity" %in% colnames(cm$byClass)) {
      sensitivity <- mean(cm$byClass[, "Sensitivity"], na.rm = TRUE)
      specificity <- mean(cm$byClass[, "Specificity"], na.rm = TRUE)
    }
    
    # Calculate macro-average AUC (one-vs-rest)
    # Convert matrix to data.frame if needed
    if (is.matrix(probabilities)) {
      probabilities <- as.data.frame(probabilities)
      # Set column names to class levels if missing
      if (is.null(colnames(probabilities))) {
        colnames(probabilities) <- levels(actual)
      }
    }
    
    if (is.data.frame(probabilities) || is.matrix(probabilities)) {
      probabilities <- as.data.frame(probabilities)
      auc_values <- numeric(nlevels(actual))
      
      for (i in 1:nlevels(actual)) {
        class_name <- levels(actual)[i]
        
        # Create binary response (class vs rest)
        binary_response <- ifelse(actual == class_name, 1, 0)
        
        # Get probability for this class (by column index if name not found)
        if (class_name %in% colnames(probabilities)) {
          class_prob <- probabilities[[class_name]]
        } else if (i <= ncol(probabilities)) {
          class_prob <- probabilities[[i]]
        } else {
          next
        }
        
        # Calculate ROC
        roc_obj <- pROC::roc(
          response = binary_response,
          predictor = class_prob,
          levels = c(0, 1),
          direction = "<"
        )
        
        auc_values[i] <- as.numeric(pROC::auc(roc_obj))
      }
      
      # Macro-average AUC
      auc <- mean(auc_values, na.rm = TRUE)
    }
  }
  
  # Extract F1 and Recall
  f1 <- NA
  recall <- sensitivity  # Recall is the same as Sensitivity
  
  if (nlevels(actual) == 2) {
    # Binary: F1 from byClass
    if ("F1" %in% names(cm$byClass)) {
      f1 <- cm$byClass["F1"]
    }
  } else {
    # Multiclass: macro-average F1
    if ("F1" %in% colnames(cm$byClass)) {
      f1 <- mean(cm$byClass[, "F1"], na.rm = TRUE)
    }
  }
  
  # Return metrics
  metrics <- list(
    accuracy = as.numeric(accuracy),
    sensitivity = as.numeric(sensitivity),
    specificity = as.numeric(specificity),
    f1 = as.numeric(f1),
    recall = as.numeric(recall),
    auc = auc,
    confusion_matrix = cm
  )
  
    return(metrics)
  }



#' Calculate ROC curve data
#'
#' @description
#' Computes ROC curve coordinates for visualization. Supports both binary
#' and multiclass classification.
#'
#' @param actual Factor. Actual class labels
#' @param probabilities Numeric vector or data.frame. Predicted probabilities.
#'   For binary: vector of probabilities for positive class
#'   For multiclass: data.frame with columns for each class
#'
#' @return A data.frame with:
#'   - specificity: 1 - False Positive Rate (for x-axis in ROC plot)
#'   - sensitivity: True Positive Rate (for y-axis in ROC plot)
#'   - class: Class name (for multiclass, identifies which one-vs-rest curve)
#'   - auc: AUC value for this class/overall
#'
#' @details
#' ROC (Receiver Operating Characteristic) curve shows the trade-off between
#' sensitivity (True Positive Rate) and 1-specificity (False Positive Rate)
#' at various classification thresholds.
#'
#' For binary classification:
#' - Single ROC curve
#' - X-axis: 1 - Specificity (FPR)
#' - Y-axis: Sensitivity (TPR)
#'
#' For multiclass:
#' - Multiple ROC curves (one-vs-rest for each class)
#' - Each curve treats one class as positive, rest as negative
#'
#' @examples
#' # Binary ROC
#' glm_result <- fit_binary_glm(data$Expression, data$target)
#' roc_data <- calculate_roc_curve(
#'   actual = data$target,
#'   probabilities = glm_result$probabilities[, 2]
#' )
#' 
#' # Plot
#' ggplot(roc_data, aes(x = 1 - specificity, y = sensitivity)) +
#'   geom_line() +
#'   geom_abline(slope = 1, intercept = 0, linetype = "dashed")
#'
#' @export
calculate_roc_curve <- function(actual, probabilities) {
  
  # Input validation
  if (!is.factor(actual)) {
    actual <- as.factor(actual)
  }
  
  # Binary classification
  if (nlevels(actual) == 2) {
    
    if (!is.numeric(probabilities)) {
      stop("For binary classification, probabilities must be numeric vector")
    }
    
    # Calculate ROC
    roc_obj <- pROC::roc(
      response = actual,
      predictor = probabilities,
      levels = levels(actual),
      direction = "<"
    )
    
    # Extract coordinates
    roc_data <- data.frame(
      specificity = roc_obj$specificities,
      sensitivity = roc_obj$sensitivities,
      class = levels(actual)[2],  # Positive class
      auc = as.numeric(pROC::auc(roc_obj))
    )
    
    return(roc_data)
    
  } else {
    # Multiclass classification
    
    if (!is.data.frame(probabilities)) {
      probabilities <- as.data.frame(probabilities)
    }
    
    # Initialize list for ROC data
    roc_list <- list()
    
    # Calculate ROC for each class (one-vs-rest)
    for (i in 1:nlevels(actual)) {
      class_name <- levels(actual)[i]
      
      # Create binary response
      binary_response <- ifelse(actual == class_name, 1, 0)
      
      # Get probability for this class - use column index directly
      class_prob <- probabilities[[i]]
      
      # Calculate ROC
      roc_obj <- tryCatch({
        pROC::roc(
          response = binary_response,
          predictor = class_prob,
          levels = c(0, 1),
          direction = "<",
          quiet = TRUE
        )
      }, error = function(e) {
        warning(paste("Error calculating ROC for class", class_name, ":", e$message))
        return(NULL)
      })
      
      if (is.null(roc_obj)) {
        next
      }
      
      # Store coordinates
      roc_list[[i]] <- data.frame(
        specificity = roc_obj$specificities,
        sensitivity = roc_obj$sensitivities,
        class = class_name,
        auc = as.numeric(pROC::auc(roc_obj))
      )
    }
    
    # Combine all ROC curves
    roc_data <- dplyr::bind_rows(roc_list)
    
    return(roc_data)
  }
}
