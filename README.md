# MicroarrAI

**Advanced Peptide Microarray Analysis Platform**

[![R](https://img.shields.io/badge/R-4.0+-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/Shiny-1.7+-green.svg)](https://shiny.rstudio.com/)
[![License](https://img.shields.io/badge/license-MIT-orange.svg)](LICENSE)

MicroarrAI is a comprehensive Shiny-based platform for peptide microarray data analysis, featuring advanced machine learning algorithms, statistical analysis, and interactive visualizations.

---

## Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Installation](#-installation)
  - [Local Installation](#local-installation)
  - [Docker Deployment](#-docker-deployment-recommended)
- [Usage](#-usage)
- [Module Documentation](#-module-documentation)
- [Machine Learning Algorithms](#-machine-learning-algorithms)
- [Statistical Analysis](#-statistical-analysis)
- [Visualizations](#-visualizations)
- [Project Structure](#-project-structure)
- [Contributing](#-contributing)
- [Citation](#-citation)

---

## Features

### Data Analysis
- **Data Import & Validation**: Support for multiple file formats (CSV, Excel, TSV)
- **Quality Control**: Missing value detection, outlier identification, normalization
- **Statistical Tests**: t-tests, ANOVA, Mann-Whitney U, Kruskal-Wallis with FDR correction
- **Differential Expression**: Volcano plots with isotype-specific analysis (IgE, IgG4)

### Machine Learning
- **Unsupervised Learning**:
  - Principal Component Analysis (PCA) with variance analysis
  - Principal Coordinate Analysis (PCoA) with multiple distance metrics
  - Non-Metric Multidimensional Scaling (NMDS)
  
- **Supervised Learning**:
  - C5.0 Decision Trees with boosting
  - Random Forest with feature importance
  - Support Vector Machines (SVM) with Recursive Feature Elimination (RFE)
  - XGBoost with SHAP interpretability

- **Regression Models**:
  - Binary Logistic Regression (GLM)
  - Multinomial Logistic Regression
  - Performance metrics: Accuracy, AUC, Sensitivity, Specificity
  - ROC curve analysis (binary and multiclass)

### Visualizations
- **2D/3D Interactive Plots**: PCA, PCoA, NMDS with surface fitting
- **Decision Boundaries**: Visual representation of ML model classifications
- **Feature Importance**: Bar plots, SHAP waterfall, SHAP beeswarm
- **Heatmaps**: Clustered heatmaps with dendrograms
- **Volcano Plots**: Log2 fold change vs -log10(p-value)
- **ROC Curves**: Multi-class and binary classification performance

### Interactive Features
- Custom color palettes and themes
- Surface fitting (smooth, linear, quadratic, additive)
- Real-time parameter adjustment
- Export-ready publication-quality figures

---

## Architecture

MicroarrAI follows a **modular architecture** with separation of concerns:

```
MicroarrAI/
├── app.R                          # Main Shiny application
├── global.R                       # Global environment & module loading
├── R/
│   ├── ui/                        # UI modules (6 modules)
│   │   ├── ui_data_module.R       # Data upload & validation
│   │   ├── ui_stats_module.R      # Statistical analysis
│   │   ├── ui_unsupervised_module.R  # Unsupervised ML
│   │   ├── ui_supervised_module.R    # Supervised ML
│   │   ├── ui_visualization_module.R # Visualizations
│   │   └── ui_utils_module.R      # Utilities
│   └── server/                    # Server modules (6 modules)
│       ├── data_processing.R      # Data import & preprocessing
│       ├── statistical_analysis.R # Statistical tests & volcano plots
│       ├── ml_unsupervised.R     # PCA, PCoA, NMDS (7 functions)
│       ├── ml_supervised.R       # C5.0, RF, SVM, XGBoost (13 functions)
│       ├── regression_models.R   # GLM, multinomial, ROC (5 functions)
│       └── visualization_3d.R    # 3D plots with rgl (5 functions)
├── Def/                          # Helper functions
│   ├── Function2.R              # Utility functions
│   └── synthetic_data.R         # Data generation
├── www/                          # Web assets
│   └── assets/                  # Images, CSS, JS
└── docs/                         # Documentation
    ├── ml_modules.md            # ML module documentation (2,400 lines)
    ├── PHASE2_SUMMARY.md        # Phase 2 technical summary
    └── README.md                # Documentation index
```

### Module Overview

| Module | Functions | Lines | Description |
|--------|-----------|-------|-------------|
| **data_processing.R** | 6 | ~350 | Data import, validation, normalization |
| **statistical_analysis.R** | 6 | ~400 | Statistical tests, p-value correction |
| **ml_unsupervised.R** | 7 | ~320 | PCA, PCoA, NMDS, distance matrices |
| **ml_supervised.R** | 13 | ~770 | C5.0, RF, SVM, XGBoost, decision boundaries |
| **regression_models.R** | 5 | ~380 | GLM, multinomial, metrics, ROC |
| **visualization_3d.R** | 5 | ~280 | rgl 3D scatter plots |
| **Total** | **42** | **~2,500** | Pure, reusable functions |

---

## Installation

### 🐳 Docker Deployment (Recommended)

The easiest way to deploy MicroarrAI is using Docker. This method handles all dependencies automatically.

**Quick Start:**

```bash
# Clone repository
git clone https://github.com/yourusername/MicroarrAI.git
cd MicroarrAI

# Option 1: Using the deploy script (easiest)
./deploy.sh

# Option 2: Using docker-compose
docker-compose up -d

# Option 3: Using docker build directly
docker build -t microarrai:latest .
docker run -p 3838:3838 microarrai:latest
```

Access the application at `http://localhost:3838/MicroarrAI`

**📘 For detailed Docker deployment instructions, see [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)**

---

### Local Installation

For local development or if you prefer running without Docker:

**Prerequisites:**

```r
# R version 4.0 or higher
R.version.string
```

**Install Dependencies:**

```r
# Core packages
install.packages(c(
  "shiny", "shinydashboard", "shinyWidgets", "shinyBS",
  "DT", "plotly", "ggplot2", "tidyverse", "dplyr", "tidyr"
))

# Machine Learning
install.packages(c(
  "C50", "randomForest", "e1071", "caret", "xgboost",
  "shapviz", "vegan", "FactoMineR"
))

# Statistical Analysis
install.packages(c(
  "stats", "agricolae", "multcomp", "pROC"
))

# Visualization
install.packages(c(
  "rgl", "car", "ggrepel", "ggvenn", "pheatmap", "RColorBrewer"
))

# Regression (tidymodels)
install.packages(c(
  "parsnip", "yardstick", "tidymodels"
))
```

**Clone & Run:**

```bash
# Clone repository
git clone https://github.com/yourusername/MicroarrAI.git
cd MicroarrAI

# Run application
Rscript -e "shiny::runApp()"
```

---

## Usage

### Quick Start

1. **Launch the app**:
   ```r
   library(shiny)
   runApp()
   ```

2. **Upload data**: Navigate to "Data Upload" and import your peptide microarray file

3. **Explore**: Use tabs for statistical analysis, ML, and visualizations

### Example Workflow

```r
# Load modules
source("global.R")

# Import data
data <- import_peptide_data("my_data.csv")

# Statistical analysis
volcano_data <- generate_volcano_data(
  data, group_var = "Disease_Status",
  level_a = "Healthy", level_b = "Disease"
)

# Machine Learning
ml_data <- prepare_ml_data(data, group_var = "Disease_Status")
pca_result <- compute_pca(ml_data)

# Train models
c50_model <- train_c50_model(ml_data, trials = 50)
rf_model <- train_randomforest_model(ml_data)
xgb_result <- train_xgboost_model(ml_data)

# Feature importance
c50_vars <- extract_c50_importance(c50_model, top_n = 30)
rf_vars <- extract_rf_importance(rf_model, top_n = 30)

# Decision boundary visualization
plot <- create_decision_boundary_plot(ml_data, "c50", c50_vars)
```

---

## Module Documentation

### Unsupervised Learning (`ml_unsupervised.R`)

#### `compute_pca(data, center = TRUE, scale = TRUE)`
Performs Principal Component Analysis for dimensionality reduction.

**Parameters:**
- `data`: Data frame with numeric predictors and 'target' column
- `center`: Center variables to zero mean (default: TRUE)
- `scale`: Scale variables to unit variance (default: TRUE)

**Returns:** PCA model object from `stats::prcomp()`

**Example:**
```r
pca_result <- compute_pca(ml_data)
```

#### `perform_pcoa(distance_matrix, k = 2)`
Classical (Metric) Multidimensional Scaling on distance matrix.

**Parameters:**
- `distance_matrix`: Distance/dissimilarity matrix
- `k`: Number of dimensions (default: 2)

**Returns:** Matrix of coordinates with k columns

#### `perform_nmds(distance_matrix, k = 2, try_max = 20)`
Non-Metric Multidimensional Scaling for ordination.

**Parameters:**
- `distance_matrix`: Distance matrix
- `k`: Number of dimensions (default: 2)
- `try_max`: Maximum random starts (default: 20)

**Returns:** NMDS model object from `vegan::metaMDS()`

### Supervised Learning (`ml_supervised.R`)

#### `train_c50_model(data, trials = 50, rules = FALSE, seed = 120)`
Trains C5.0 decision tree with boosting.

**Key Features:**
- Information gain-based splits
- Automatic missing value handling
- Feature importance scores

#### `train_randomforest_model(data, ntree = 500, mtry = NULL)`
Random Forest ensemble classifier.

**Key Features:**
- Robust to overfitting
- Gini importance for feature ranking
- Handles high-dimensional data

#### `train_xgboost_model(data, max_depth = 3, eta = 0.1, nrounds = 100)`
XGBoost gradient boosting (auto-detects binary vs multiclass).

**Key Features:**
- Binary: "binary:logistic" objective
- Multiclass: "multi:softmax" objective
- SHAP value support for interpretability

#### `create_decision_boundary_plot(data, model_type, important_vars, ...)`
**NEW in Phase 2** - Creates 2D decision boundary visualization.

**Parameters:**
- `model_type`: "c50", "rf", or "svm"
- `important_vars`: Variable names (minimum 2)
- `grid_resolution`: Grid size (default: 100)

**Returns:** ggplot2 object with colored decision regions

### Regression Models (`regression_models.R`)

#### `fit_binary_glm(predictors, target)`
Binary logistic regression using GLM.

**Returns:** List with model, predictions, probabilities

#### `fit_multinomial_regression(predictors, target)`
Multinomial logistic regression for 3+ classes.

**Uses:** tidymodels framework (parsnip, yardstick)

#### `calculate_performance_metrics(predictions, actual, probabilities)`
Comprehensive performance evaluation.

**Metrics:**
- Accuracy
- AUC (binary and multiclass)
- Sensitivity (binary only)
- Specificity (binary only)

### 3D Visualization (`visualization_3d.R`)

#### `create_3d_pca(pca_result, data, color_by = "target")`
Interactive 3D PCA plot with rgl.

#### `toggle_surface_fit(current_surface)`
Cycles through surface types: "smooth" → "linear" → "quadratic" → "additive"

---

## Machine Learning Algorithms

### Algorithm Comparison

| Algorithm | Type | Best For | Interpretability | Speed |
|-----------|------|----------|-----------------|-------|
| **C5.0** | Tree | Categorical targets | High (tree rules) | Fast |
| **Random Forest** | Ensemble | High-dimensional data | Medium (importance) | Medium |
| **SVM** | Kernel | Small datasets | Low | Medium |
| **XGBoost** | Boosting | Complex patterns | High (SHAP) | Fast |

### Feature Selection Methods

1. **Embedded** (C5.0, Random Forest, XGBoost): Built into model training
2. **Wrapper** (SVM with RFE): Iterative feature elimination
3. **Consensus**: Venn diagram intersection of all methods

---

## Statistical Analysis

### Supported Tests

| Test | Use Case | Function |
|------|----------|----------|
| **t-test** | 2 groups, normal | `stats::t.test()` |
| **ANOVA** | 3+ groups, normal | `stats::aov()` |
| **Mann-Whitney U** | 2 groups, non-normal | `stats::wilcox.test()` |
| **Kruskal-Wallis** | 3+ groups, non-normal | `stats::kruskal.test()` |

### Multiple Testing Correction

- Benjamini-Hochberg (FDR)
- Bonferroni
- Holm

---

## Visualizations

### Available Plots

- **Scatter plots**: 2D/3D with color grouping
- **Heatmaps**: Hierarchical clustering with dendrograms
- **Volcano plots**: Differential expression with significance thresholds
- **ROC curves**: Model performance evaluation
- **Decision boundaries**: ML classification regions
- **SHAP plots**: Feature importance and interactions
- **Venn diagrams**: Feature consensus across models

---

## Project Structure

```
MicroarrAI/
├── app.R                    # Main Shiny app (~1,550 lines)
├── global.R                 # Module loader
├── R/
│   ├── ui/                  # 6 UI modules
│   └── server/              # 6 server modules (42 functions)
├── Def/
│   ├── Function2.R          # Helper utilities
│   └── synthetic_data.R     # Test data generator
├── www/
│   └── assets/              # Images, CSS, JS
└── docs/
    ├── ml_modules.md        # ML documentation (2,400 lines)
    ├── PHASE2_SUMMARY.md    # Technical summary (1,500 lines)
    └── README.md            # Documentation index
```

---

## Development

### Code Quality

- **Modular design**: 42 pure functions across 6 modules
- **Documentation**: 4,000+ lines of comprehensive docs
- **Type safety**: Input validation in all functions
- **Error handling**: Graceful degradation with informative messages
- **Testing**: Synthetic data generation for validation

### Recent Updates (Phase 2 - December 2024)

#### Refactoring Summary
- 26 sections refactored in app.R (~300 lines reduced)
- Created 36 modular functions
- Unified API across all ML algorithms
- Zero syntax errors
- 100% consistent coding style

#### New Features
- `create_decision_boundary_plot()`: Unified 2D decision boundary visualization
- Auto-detection of binary vs multiclass classification
- SHAP value integration for XGBoost interpretability
- Comprehensive ROC curve support (binary and multiclass)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Contact

**MicroarrAI Team**

- GitHub: [@OPSergio](https://github.com/OPSergio)
- Email: solmos97@gmail.com
- Documentation: [docs/README.md](docs/README.md)

---

## Acknowledgments

- **Shiny Team** for the amazing framework
- **tidyverse** for data manipulation tools
- **ML Libraries**: C50, randomForest, e1071, xgboost, shapviz
- **Visualization**: ggplot2, plotly, rgl, pheatmap

---

## Citation

If you use MicroarrAI in your research, please cite:

```bibtex
@software{microarrai2024,
  title = {MicroarrAI: Advanced Peptide Microarray Analysis Platform},
  author = {Olmos-Piñero, Sergio},
  year = {2025},
  url = {https://github.com/OPSergio/MicroarrAI}
}
```

---

