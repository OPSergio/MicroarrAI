# Machine Learning Modules Documentation

**MicroarrAI - Unsupervised and Supervised ML Functions**

---

## Table of Contents

1. [Overview](#overview)
2. [Unsupervised Learning](#unsupervised-learning)
   - [PCA](#pca-principal-component-analysis)
   - [PCoA](#pcoa-principal-coordinate-analysis)
   - [NMDS](#nmds-non-metric-multidimensional-scaling)
3. [Supervised Learning](#supervised-learning)
   - [C5.0 Decision Trees](#c50-decision-trees)
   - [Random Forest](#random-forest)
   - [SVM with RFE](#svm-with-rfe)
   - [XGBoost](#xgboost)
4. [Regression Models](#regression-models)
   - [Binary Logistic Regression](#binary-logistic-regression)
   - [Multinomial Regression](#multinomial-regression)
5. [3D Visualization](#3d-visualization)
6. [Usage Examples](#usage-examples)
7. [Performance Metrics](#performance-metrics)

---

## Overview

The Machine Learning modules provide comprehensive analysis capabilities for microarray peptide data, divided into four main categories:

### Module Structure

```
R/server/
├── ml_unsupervised.R     # PCA, PCoA, NMDS, distance matrices
├── ml_supervised.R       # C5.0, RF, SVM, XGBoost, feature selection
├── regression_models.R   # GLM, multinomial regression, ROC curves
└── visualization_3d.R    # 3D scatter plots with rgl
```

### Key Features

- **Unsupervised Learning**: Dimensionality reduction and ordination methods
- **Supervised Learning**: Multi-algorithm feature selection and classification
- **Regression Analysis**: Peptide-level binary and multiclass regression
- **Performance Metrics**: Accuracy, AUC, Sensitivity, Specificity, ROC curves
- **3D Visualization**: Interactive plots with ellipsoids and fitted surfaces

---

## Unsupervised Learning

### PCA (Principal Component Analysis)

**File**: `R/server/ml_unsupervised.R`

#### Function: `compute_pca()`

Performs PCA on numeric expression data.

**Parameters:**
- `data`: Data.frame with samples as rows, expression columns
- `center`: Logical, center data (default: TRUE)
- `scale.`: Logical, scale to unit variance (default: FALSE)

**Returns:**
- Data.frame with PC coordinates (PC1, PC2, PC3, ...)

**Mathematical Basis:**

PCA finds orthogonal axes (principal components) that maximize variance:

$$
\text{Cov}(X) = V \Lambda V^T
$$

Where:
- $V$ = eigenvectors (principal component directions)
- $\Lambda$ = eigenvalues (variance explained)

**Variance Explained:**

$$
\text{Variance}_i = \frac{\lambda_i}{\sum_{j=1}^{p} \lambda_j} \times 100\%
$$

**Usage:**

```r
# Basic PCA
pca_result <- compute_pca(expression_data)

# PCA with scaling (recommended for different units)
pca_scaled <- compute_pca(expression_data, scale. = TRUE)

# Calculate variance explained
variance <- calculate_pca_variance(pca_result)
# Output: [1] 45.2 23.1 12.8 8.5 ... (% variance per PC)
```

**When to Use:**
- Linear relationships expected
- Variables on similar scales
- Euclidean distance appropriate
- Want interpretable axes (PCs are linear combinations)

---

### PCoA (Principal Coordinate Analysis)

**File**: `R/server/ml_unsupervised.R`

#### Function: `compute_distance_matrix()` + `perform_pcoa()`

PCoA preserves pairwise distances in a lower-dimensional space.

**Step 1: Calculate Distance Matrix**

```r
dist_matrix <- compute_distance_matrix(
  data = metadata_with_expression,
  group_var = "Disease_Status",
  distance_method = "bray",  # or "euclidean", "jaccard", etc.
  scale_data = TRUE,
  impute_na = TRUE
)
```

**Parameters:**
- `data`: Data.frame with 'id' column and numeric features
- `group_var`: Column name for grouping (converted to 'target')
- `distance_method`: 
  - `"euclidean"`: Straight-line distance (default in many contexts)
  - `"bray"`: Bray-Curtis dissimilarity (ecology, abundance data)
  - `"jaccard"`: Jaccard index (binary, presence/absence)
  - `"manhattan"`: City-block distance (robust to outliers)
- `scale_data`: Scale numeric columns (recommended)
- `impute_na`: Replace NA with median (default: TRUE)

**Distance Formulas:**

**Euclidean:**
$$
d_{ij} = \sqrt{\sum_{k=1}^{p} (x_{ik} - x_{jk})^2}
$$

**Bray-Curtis:**
$$
d_{ij} = \frac{\sum_{k=1}^{p} |x_{ik} - x_{jk}|}{\sum_{k=1}^{p} (x_{ik} + x_{jk})}
$$

**Step 2: Perform PCoA**

```r
# 2D PCoA
pcoa_2d <- perform_pcoa(dist_matrix, k = 2)

# 3D PCoA for visualization
pcoa_3d <- perform_pcoa(dist_matrix, k = 3)
```

**Parameters:**
- `distance_matrix`: Output from `compute_distance_matrix()`
- `k`: Number of dimensions (2 or 3)
- `add`: Add constant for non-Euclidean matrices (default: TRUE)

**When to Use:**
- Non-Euclidean distances (Bray-Curtis, Jaccard)
- Preserving dissimilarity structure
- Ecological or microbiome data
- Abundance/compositional data

---

### NMDS (Non-metric Multidimensional Scaling)

**File**: `R/server/ml_unsupervised.R`

#### Function: `perform_nmds()`

NMDS uses rank-order of distances, not absolute values.

**Parameters:**
- `distance_matrix`: Distance matrix object
- `k`: Number of dimensions (default: 2)
- `trymax`: Maximum random starts (default: 20)
- `autotransform`: Use transformations (default: TRUE)

**Returns:**
- Data.frame with NMDS coordinates (NMDS1, NMDS2, ...)

**Mathematical Basis:**

NMDS minimizes **stress** (goodness of fit):

$$
\text{Stress} = \sqrt{\frac{\sum (d_{ij} - \hat{d}_{ij})^2}{\sum d_{ij}^2}}
$$

Where:
- $d_{ij}$ = observed dissimilarity
- $\hat{d}_{ij}$ = distance in ordination space

**Stress Interpretation:**
- **< 0.05**: Excellent representation
- **0.05 - 0.10**: Good
- **0.10 - 0.20**: Acceptable
- **> 0.20**: Poor (consider more dimensions or different method)

**Usage:**

```r
# Calculate distance matrix
dist_mat <- compute_distance_matrix(data, "Group", "bray")

# 2D NMDS
nmds_2d <- perform_nmds(dist_mat, k = 2)

# 3D NMDS
nmds_3d <- perform_nmds(dist_mat, k = 3, trymax = 50)
```

**When to Use:**
- Non-linear relationships
- Rank-order preservation more important than absolute distances
- Ecological/microbiome data
- When PCoA stress is high

---

## Supervised Learning

### C5.0 Decision Trees

**File**: `R/server/ml_supervised.R`

#### Function: `train_c50_model()`

C5.0 builds decision trees using information gain.

**Parameters:**
- `data`: Data.frame with 'target' column (factor) and predictors
- `trials`: Number of boosting trials (default: 50)
- `rules`: Use rule-based model (default: FALSE = tree)
- `seed`: Random seed (default: 120)

**Returns:**
- C5.0 model object

**Algorithm:**

C5.0 uses **entropy** and **information gain**:

$$
\text{Entropy}(S) = -\sum_{i=1}^{c} p_i \log_2(p_i)
$$

$$
\text{Info Gain} = \text{Entropy}(parent) - \sum \frac{|S_i|}{|S|} \text{Entropy}(S_i)
$$

**Feature Importance:**

```r
model <- train_c50_model(ml_data, trials = 100)

# Extract top 15 important variables
top_vars <- extract_c50_importance(model, top_n = 15)
# Output: ["IgE_Pep123", "IgG_Pep456", ...]
```

**Advantages:**
- Fast training and prediction
- Handles missing values automatically
- Built-in feature importance
- Boosting improves accuracy

**When to Use:**
- Multiclass classification
- Need interpretable model
- Large number of features
- Mixed numeric/categorical data

---

### Random Forest

**File**: `R/server/ml_supervised.R`

#### Function: `train_randomforest_model()`

Ensemble of decision trees with random feature subsets.

**Parameters:**
- `data`: Data.frame with 'target' and predictors
- `ntree`: Number of trees (default: 500)
- `mtry`: Features per split (default: $\sqrt{p}$ for classification)

**Algorithm:**

1. Bootstrap sample from training data
2. At each node, sample $m$ features randomly
3. Choose best split among these $m$ features
4. Grow tree to max depth (no pruning)
5. Repeat for $B$ trees
6. **Final prediction**: Majority vote (classification)

**Feature Importance (Gini):**

$$
\text{Importance}(X_j) = \sum_{t \in T} \Delta \text{Gini}(t, X_j)
$$

**Usage:**

```r
model <- train_randomforest_model(ml_data, ntree = 1000)

# Get top important features
top_vars <- extract_rf_importance(model, top_n = 30)
```

**Advantages:**
- Robust to overfitting
- Handles high-dimensional data
- Non-linear relationships
- Out-of-bag error estimate

**When to Use:**
- Need robust baseline model
- High-dimensional microarray data
- Non-linear decision boundaries
- Want feature importance ranking

---

### SVM with RFE

**File**: `R/server/ml_supervised.R`

#### Functions: `perform_rfe_svm()` + `train_svm_model()`

Support Vector Machine with Recursive Feature Elimination.

**Step 1: Scale Data**

```r
# SVM requires scaling!
data_scaled <- scale_ml_data(ml_data)
```

**Step 2: Perform RFE**

```r
important_vars <- perform_rfe_svm(
  data = data_scaled,
  sizes = c(5, 10, 15, 20),
  cv_folds = 5
)
# Output: ["Pep_001", "Pep_045", "Pep_089", ...]
```

**RFE Algorithm:**

1. Train SVM on all features
2. Rank features by importance (weight magnitude)
3. Remove least important feature
4. Repeat until target size
5. Select size with best CV performance

**Step 3: Train SVM**

```r
# Select important features
ml_data_selected <- data_scaled %>%
  select(target, all_of(important_vars))

# Train SVM
model <- train_svm_model(
  data = ml_data_selected,
  cost = 10,
  kernel = "linear"
)
```

**Linear SVM Decision Function:**

$$
f(x) = \text{sign}(w^T x + b)
$$

Where $w$ and $b$ are learned to maximize margin:

$$
\max \frac{2}{||w||} \quad \text{subject to} \quad y_i(w^T x_i + b) \geq 1
$$

**When to Use:**
- Linear separability expected
- High-dimensional data (p >> n)
- Want sparse feature selection
- Need theoretically principled classifier

---

### XGBoost

**File**: `R/server/ml_supervised.R`

#### Function: `train_xgboost_model()`

Gradient boosting with tree learners.

**Parameters:**
- `data`: Data.frame with 'target' and predictors
- `max_depth`: Maximum tree depth (default: 3)
- `eta`: Learning rate (default: 0.1)
- `nrounds`: Boosting rounds (default: 100)

**Returns:**
- List with model, training matrix, target, num_classes

**Algorithm:**

XGBoost minimizes loss + regularization:

$$
\mathcal{L} = \sum_{i=1}^{n} l(y_i, \hat{y}_i) + \sum_{k=1}^{K} \Omega(f_k)
$$

Where:
- $l$ = loss function (logistic, softmax)
- $\Omega(f) = \gamma T + \frac{1}{2}\lambda ||w||^2$ (regularization)

**Binary vs Multiclass:**

```r
# Automatically detects classification type
xgb_result <- train_xgboost_model(data)

# Binary: objective = "binary:logistic", target = {0, 1}
# Multiclass: objective = "multi:softmax", target = {0, 1, ..., K-1}
```

**Feature Importance:**

```r
top_vars <- extract_xgboost_importance(xgb_result, top_n = 20)
```

**SHAP Values (Model Interpretability):**

```r
shap_values <- calculate_shap_values(xgb_result)

# Importance plot
shapviz::sv_importance(shap_values, show_numbers = TRUE)

# Bee swarm plot (feature effects)
shapviz::sv_importance(shap_values, kind = "bee")

# Waterfall plot (single prediction breakdown)
shapviz::sv_waterfall(shap_values, row_id = 2)

# Force plot
shapviz::sv_force(shap_values, row_id = 2)
```

**SHAP (SHapley Additive exPlanations):**

$$
\phi_j = \sum_{S \subseteq F \backslash \{j\}} \frac{|S|!(|F|-|S|-1)!}{|F|!} [f_{S \cup \{j\}}(x_{S \cup \{j\}}) - f_S(x_S)]
$$

Interprets each feature's contribution to individual predictions.

**When to Use:**
- State-of-the-art accuracy needed
- Large datasets (1000s of samples)
- Need model interpretability (SHAP)
- Willing to tune hyperparameters

---

## Regression Models

**File**: `R/server/regression_models.R`

### Binary Logistic Regression

#### Function: `fit_binary_glm()`

Logistic regression for binary outcomes (2 classes).

**Parameters:**
- `expression_data`: Numeric vector (single peptide expression)
- `target`: Factor with 2 levels (e.g., Disease vs Healthy)

**Returns:**
- List with model, predictions, probabilities

**Logistic Function:**

$$
P(Y=1|X) = \frac{1}{1 + e^{-(\beta_0 + \beta_1 X)}}
$$

**Log-Odds (Logit):**

$$
\log\left(\frac{P(Y=1)}{1-P(Y=1)}\right) = \beta_0 + \beta_1 X
$$

**Usage:**

```r
# Fit GLM for peptide "IgE_Pep123"
glm_result <- fit_binary_glm(
  expression_data = data$IgE_Pep123,
  target = data$Disease_Status
)

# Access results
predictions <- glm_result$predictions
probabilities <- glm_result$probabilities
```

**When to Use:**
- Binary classification
- Need probability estimates
- Interpretable coefficients (odds ratios)
- Small to medium datasets

---

### Multinomial Regression

#### Function: `fit_multinomial_regression()`

Logistic regression for 3+ classes.

**Parameters:**
- `expression_data`: Numeric vector
- `target`: Factor with 3+ levels
- `engine`: "nnet" (neural network backend)

**Returns:**
- List with model, predictions, probabilities (data.frame)

**Multinomial Logit:**

For class $k$ vs reference class:

$$
\log\left(\frac{P(Y=k)}{P(Y=\text{ref})}\right) = \beta_{0k} + \beta_{1k} X
$$

**Probabilities:**

$$
P(Y=k|X) = \frac{e^{\beta_{0k} + \beta_{1k} X}}{1 + \sum_{j=1}^{K-1} e^{\beta_{0j} + \beta_{1j} X}}
$$

**Usage:**

```r
# 3-class example: Healthy, Mild, Severe
multinom_result <- fit_multinomial_regression(
  expression_data = data$IgG_Pep456,
  target = factor(data$Disease_Severity)
)

# Probabilities for each class
prob_df <- multinom_result$probabilities
#   Healthy  Mild  Severe
# 1   0.65  0.25    0.10
# 2   0.10  0.30    0.60
```

**When to Use:**
- 3+ classes
- Need class probabilities
- One predictor (peptide-level analysis)

---

## Performance Metrics

**File**: `R/server/regression_models.R`

### Function: `calculate_performance_metrics()`

Computes classification metrics.

**Parameters:**
- `predictions`: Predicted class labels
- `actual`: True class labels
- `probabilities`: Predicted probabilities (vector for binary, data.frame for multiclass)

**Returns:**
- List with accuracy, sensitivity, specificity, AUC, confusion_matrix

**Metrics:**

**Accuracy:**
$$
\text{Accuracy} = \frac{TP + TN}{TP + TN + FP + FN}
$$

**Sensitivity (Recall, True Positive Rate):**
$$
\text{Sensitivity} = \frac{TP}{TP + FN}
$$

**Specificity (True Negative Rate):**
$$
\text{Specificity} = \frac{TN}{TN + FP}
$$

**AUC (Area Under ROC Curve):**
- Binary: Single AUC value
- Multiclass: Macro-average AUC (one-vs-rest)

**Usage:**

```r
# Binary classification
metrics <- calculate_performance_metrics(
  predictions = glm_result$predictions,
  actual = data$target,
  probabilities = glm_result$probabilities[, 2]
)

# Output:
# $accuracy: 0.85
# $sensitivity: 0.82
# $specificity: 0.88
# $auc: 0.91

# Multiclass classification
metrics <- calculate_performance_metrics(
  predictions = multinom_result$predictions,
  actual = data$target,
  probabilities = multinom_result$probabilities
)

# Output:
# $accuracy: 0.78
# $sensitivity: 0.75 (class-averaged)
# $specificity: 0.87 (class-averaged)
# $auc: 0.86 (macro-average)
```

---

### ROC Curves

#### Function: `calculate_roc_curve()`

Generates ROC curve data for plotting.

**Parameters:**
- `actual`: True class labels
- `probabilities`: Predicted probabilities

**Returns:**
- Data.frame with specificity, sensitivity, class, auc

**ROC Curve:**

Plots TPR (Sensitivity) vs FPR (1 - Specificity) at various thresholds.

**Usage:**

```r
# Binary ROC
roc_data <- calculate_roc_curve(
  actual = data$target,
  probabilities = glm_result$probabilities[, 2]
)

# Plot
ggplot(roc_data, aes(x = 1 - specificity, y = sensitivity)) +
  geom_line(size = 1) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray") +
  labs(
    x = "False Positive Rate (1 - Specificity)",
    y = "True Positive Rate (Sensitivity)",
    title = paste0("ROC Curve (AUC = ", round(roc_data$auc[1], 3), ")")
  ) +
  theme_minimal()

# Multiclass ROC (one curve per class)
roc_data <- calculate_roc_curve(
  actual = data$target,
  probabilities = multinom_result$probabilities
)

ggplot(roc_data, aes(x = 1 - specificity, y = sensitivity, color = class)) +
  geom_line(size = 1) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(title = "Multiclass ROC Curves (One-vs-Rest)") +
  theme_minimal()
```

---

## 3D Visualization

**File**: `R/server/visualization_3d.R`

### Function: `create_3d_scatter()`

Creates interactive 3D scatter plots with rgl.

**Parameters:**
- `x, y, z`: Numeric vectors (coordinates)
- `groups`: Factor (grouping variable)
- `xlab, ylab, zlab`: Axis labels
- `surface`: Logical, draw fitted surface (default: TRUE)
- `ellipsoid`: Logical, draw confidence ellipsoids (default: FALSE)
- `fit`: Surface type ("smooth", "linear", "quadratic", "additive")
- `surface_col`: Color palette

**Returns:**
- rglwidget object (for Shiny renderRglwidget)

**Surface Fit Types:**

1. **"smooth"**: Local regression (loess) - best for non-linear patterns
2. **"linear"**: Linear regression plane - simplest model
3. **"quadratic"**: Quadratic surface - moderate complexity
4. **"additive"**: Additive model (GAM) - flexible, avoids overfitting

**Usage:**

```r
# PCA 3D plot
pca_result <- compute_pca(data)
groups <- extract_target_groups(data, "Disease_Status")

plot_3d <- create_3d_pca(
  pca_coords = pca_result,
  groups = groups,
  variance = calculate_pca_variance(pca_result),
  ellipsoid = TRUE,
  surface = FALSE  # Disabled when ellipsoid = TRUE
)

# In Shiny server:
output$pca_3d <- renderRglwidget({
  plot_3d
})
```

**Convenience Wrappers:**

```r
# PCA
create_3d_pca(pca_coords, groups, variance, ...)

# PCoA
create_3d_pcoa(pcoa_coords, groups, ...)

# NMDS
create_3d_nmds(nmds_coords, groups, ...)
```

**Toggle Surface Fit (Reactive):**

```r
# In Shiny server
surface_type <- reactiveVal("smooth")

observeEvent(input$toggle_surface_btn, {
  new_fit <- toggle_surface_fit(surface_type())
  surface_type(new_fit)
})

# Cycle: smooth -> linear -> quadratic -> additive -> smooth
```

---

## Usage Examples

### Complete Unsupervised ML Workflow

```r
# 1. Load data
data <- meta_data_ML()  # Contains 'id', 'group', and expression columns

# 2. PCA Analysis
pca_result <- compute_pca(data, scale. = TRUE)
variance <- calculate_pca_variance(pca_result)
groups <- extract_target_groups(data, "Disease_Status")

# 3. PCoA Analysis
dist_mat <- compute_distance_matrix(
  data = data,
  group_var = "Disease_Status",
  distance_method = "bray"
)
pcoa_3d <- perform_pcoa(dist_mat, k = 3)

# 4. NMDS Analysis
nmds_3d <- perform_nmds(dist_mat, k = 3, trymax = 50)

# 5. 3D Visualization
pca_plot <- create_3d_pca(pca_result, groups, variance, ellipsoid = TRUE)
pcoa_plot <- create_3d_pcoa(pcoa_3d, groups, fit = "linear")
nmds_plot <- create_3d_nmds(nmds_3d, groups, fit = "smooth")
```

---

### Complete Supervised ML Workflow

```r
# 1. Prepare data
ml_data <- prepare_ml_data(
  data = metadata_with_expression,
  group_var = "Disease_Status",
  id_column = "id"
)

# 2. Train models
c50_model <- train_c50_model(ml_data, trials = 100)
rf_model <- train_randomforest_model(ml_data, ntree = 1000)

# Scale for SVM
ml_scaled <- scale_ml_data(ml_data)
svm_vars <- perform_rfe_svm(ml_scaled, sizes = c(10, 20, 30))
svm_data <- ml_scaled %>% select(target, all_of(svm_vars))
svm_model <- train_svm_model(svm_data, cost = 10)

# XGBoost with SHAP
xgb_result <- train_xgboost_model(ml_data, nrounds = 200, eta = 0.05)
shap_values <- calculate_shap_values(xgb_result)

# 3. Extract feature importance
c50_vars <- extract_c50_importance(c50_model, top_n = 30)
rf_vars <- extract_rf_importance(rf_model, top_n = 30)
xgb_vars <- extract_xgboost_importance(xgb_result, top_n = 30)

# 4. Consensus features
consensus <- Reduce(intersect, list(c50_vars, rf_vars, svm_vars, xgb_vars))
# Peptides selected by ALL 4 algorithms

# 5. Visualize SHAP
shapviz::sv_importance(shap_values, show_numbers = TRUE) +
  ggtitle("XGBoost Feature Importance (SHAP)")
```

---

### Peptide-Level Regression Workflow

```r
# 1. Get significant peptides from differential analysis
volcano_data <- generate_volcano_data(
  data = expression_matrix,
  clinical_data = metadata,
  group_var = "Disease_Status",
  level_a = "Healthy",
  level_b = "Disease"
)

significant_peptides <- volcano_data %>%
  filter(p_value < 0.05, abs(log2FC) > 1) %>%
  pull(peptide)

# 2. Fit regression models for each peptide
regression_results <- list()

for (peptide in significant_peptides) {
  
  # Extract expression
  expr <- expression_matrix[[peptide]]
  target <- metadata$Disease_Status
  
  # Binary or multinomial?
  if (nlevels(target) == 2) {
    result <- fit_binary_glm(expr, target)
  } else {
    result <- fit_multinomial_regression(expr, target)
  }
  
  # Calculate performance
  metrics <- calculate_performance_metrics(
    predictions = result$predictions,
    actual = target,
    probabilities = if (nlevels(target) == 2) result$probabilities[, 2] else result$probabilities
  )
  
  # Store
  regression_results[[peptide]] <- list(
    model = result$model,
    metrics = metrics
  )
}

# 3. Rank peptides by AUC
peptide_auc <- sapply(regression_results, function(x) x$metrics$auc)
top_peptides <- names(sort(peptide_auc, decreasing = TRUE)[1:10])

# 4. Plot ROC for top peptide
best_peptide <- top_peptides[1]
best_result <- regression_results[[best_peptide]]

roc_data <- calculate_roc_curve(
  actual = metadata$Disease_Status,
  probabilities = predict(best_result$model, type = "prob")[, 2]
)

ggplot(roc_data, aes(x = 1 - specificity, y = sensitivity)) +
  geom_line(size = 1.5, color = "#E64B35FF") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(
    title = paste0(best_peptide, " ROC Curve"),
    subtitle = paste0("AUC = ", round(roc_data$auc[1], 3)),
    x = "False Positive Rate",
    y = "True Positive Rate"
  ) +
  theme_minimal()
```

---

## Summary

### Module Comparison

| Module | Best For | Output | Scalability |
|--------|----------|--------|-------------|
| **PCA** | Linear relationships, Euclidean | PC coordinates, variance % | High (fast) |
| **PCoA** | Non-Euclidean distances | Coordinate matrix | Medium |
| **NMDS** | Rank-order preservation | Ordination coordinates | Low (iterative) |
| **C5.0** | Interpretable trees, boosting | Decision tree, importance | High |
| **Random Forest** | Robust baseline, feature selection | Ensemble, Gini importance | Medium |
| **SVM** | Linear separability, sparse features | Hyperplane, support vectors | Medium |
| **XGBoost** | State-of-the-art accuracy, SHAP | Gradient boosted trees, SHAP | High |
| **GLM** | Binary outcomes, probabilities | Coefficients, odds ratios | Very High |
| **Multinomial** | 3+ classes, probabilities | Class probabilities | High |

### Best Practices

1. **Unsupervised Learning**:
   - Use PCA for initial exploration
   - Use PCoA/NMDS for ecological/compositional data
   - Scale data before distance calculation
   - Check NMDS stress values

2. **Supervised Learning**:
   - Train multiple algorithms, compare performance
   - Use consensus features (intersection across models)
   - Scale data for SVM
   - Tune XGBoost hyperparameters for best results
   - Use SHAP for model interpretability

3. **Regression Models**:
   - Check for class imbalance
   - Use AUC as primary metric (robust to imbalance)
   - Validate on independent test set
   - Plot ROC curves for visualization

4. **3D Visualization**:
   - Use ellipsoids to show group separation
   - Toggle surface fits to explore patterns
   - Variance labels for PCA axes
   - Interactive rglwidget for exploration

---

**For more details, see:**
- [Data Processing Documentation](data_processing.md)
- [Statistical Analysis Documentation](statistical_analysis.md)
- [Master README](README.md)
