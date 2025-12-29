# =============================================================================
# GLOBAL.R
# Global configuration and module loading
# =============================================================================
# Description:
#   Central configuration file for MicroarrAI Shiny application.
#   Loads all required packages, custom functions, and modules.
#
# Author: Sergio Olmos Piñero
# Last Modified: 2025
# =============================================================================

# =============================================================================
# PACKAGE LOADING
# =============================================================================

# -----------------------------------------------------------------------------
# Core Data Manipulation (tidyverse)
# -----------------------------------------------------------------------------
library(dplyr)      # Data manipulation (filter, select, mutate, etc.)
library(tidyr)      # Data tidying (pivot, separate, etc.)
library(tibble)     # Modern data frames
library(readr)      # Fast reading of delimited files
library(purrr)      # Functional programming tools
library(stringr)    # String manipulation
library(openxlsx)   # Excel file reading and writing

# -----------------------------------------------------------------------------
# Shiny Web Framework
# -----------------------------------------------------------------------------
library(shiny)            # Core Shiny framework
library(shinyWidgets)     # Enhanced UI widgets
library(shinydashboard)   # Dashboard layout components
library(shinycssloaders)  # Loading animations
library(DT)               # Interactive DataTables
library(shinyjs)         # JavaScript integration
library(shinythemes)     # Predefined themes for Shiny apps
library(bslib)            # Modern UI components
library(shinyFiles)       # File system browser widgets
# -----------------------------------------------------------------------------
# Data Visualization - 2D
# -----------------------------------------------------------------------------
library(ggplot2)      # Grammar of graphics plotting
library(plotly)       # Interactive plots
library(ggpubr)       # Publication-ready plots
library(cowplot)      # Plot composition and themes
library(ggrepel)      # Non-overlapping text labels
library(ggvenn)       # Venn diagrams
library(formattable)  # Styled and formatted tables
library(ggiraph)      # Interactive ggplot2 graphics

# -----------------------------------------------------------------------------
# Data Visualization - 3D
# -----------------------------------------------------------------------------
library(rgl)          # 3D visualization and graphics
library(car)          # 3D ellipsoids and scatter plots
library(shiny.molstar)       # Molecular structure visualization (Molstar)

# -----------------------------------------------------------------------------
# Statistical Analysis & Clustering
# -----------------------------------------------------------------------------
library(vegan)        # Ecological statistics (PCoA, NMDS, distance matrices)
library(dbscan)       # Density-based spatial clustering (DBSCAN)
library(cluster)      # Clustering algorithms and silhouette analysis

# -----------------------------------------------------------------------------
# Machine Learning - Supervised Classification
# -----------------------------------------------------------------------------
library(C50)           # C5.0 decision trees
library(randomForest)  # Random Forest ensemble
library(e1071)         # Support Vector Machines (SVM)
library(kernlab)       # Kernel-based machine learning (SVM support)
library(caret)         # ML framework (train, RFE, cross-validation)
library(xgboost)       # Extreme Gradient Boosting
library(shapviz)       # SHAP values for model interpretability
library(mixOmics)      # Multivariate methods (PLS-DA, sparse PLS)

# -----------------------------------------------------------------------------
# Machine Learning - Regression & Model Evaluation
# -----------------------------------------------------------------------------
library(tidymodels)    # Meta-package for tidy modeling
library(parsnip)       # Unified model interface (multinom_reg, etc.)
library(yardstick)     # Model performance metrics (accuracy, roc_auc, etc.)
library(pROC)          # ROC curve analysis and AUC calculation
library(MLmetrics)     # Additional ML metrics for multiclass classification

# =============================================================================
# SERVER MODULES
# =============================================================================

# Data processing and file handling
source("R/server/data_processing.R", encoding = "UTF-8")

# Statistical analysis and hypothesis testing
source("R/server/statistical_analysis.R", encoding = "UTF-8")

# Peptide data summary and visualizations
source("R/server/peptide_summary.R", encoding = "UTF-8")

# Machine Learning - Unsupervised methods (PCA, PCoA, NMDS, DBSCAN, PLS-DA)
source("R/server/ml_unsupervised.R", encoding = "UTF-8")

# Machine Learning - RFE helpers (model-specific feature selection)
source("R/server/ml_rfe_helpers.R", encoding = "UTF-8")

# Machine Learning - Supervised methods (C5.0, RF, SVM, XGBoost)
source("R/server/ml_supervised.R", encoding = "UTF-8")

# Regression models and predictive analytics
source("R/server/regression_models.R", encoding = "UTF-8")

# 3D visualization and interactive plots
source("R/server/visualization_3d.R", encoding = "UTF-8")

# =============================================================================
# UI MODULES
# =============================================================================

source("R/ui/ui_home.R", encoding = "UTF-8")           # Home page and intro
source("R/ui/ui_preprocess.R", encoding = "UTF-8")    # Data preprocessing tab
source("R/ui/ui_peptide.R", encoding = "UTF-8")       # Peptide analysis tab
source("R/ui/ui_ml.R", encoding = "UTF-8")            # Machine Learning tab
source("R/ui/ui_visualization.R", encoding = "UTF-8") # Visualization tab

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Custom ggplot2 themes and styling functions
source("Def/Function2.R", encoding = "UTF-8")

# Ggiraph theme and interactive plot utilities
source("Def/ggiraph_theme.R", encoding = "UTF-8")

# Synthetic data generation for testing and demos
source("Def/synthetic_data.R", encoding = "UTF-8")

# Color palette definitions
source("R/utils/colors.R", encoding = "UTF-8")

# Custom ggplot2 themes
source("R/utils/theme.R", encoding = "UTF-8")

# Custom ggplot2 scales
source("R/utils/scales.R", encoding = "UTF-8")

# Plot utility functions
source("R/utils/plot_utils.R", encoding = "UTF-8")

# Radar plot utilities for model performance visualization
source("R/utils/radar_plot.R", encoding = "UTF-8")

# UI helper functions (card containers, section titles, etc.)
source("R/utils/ui_helpers.R", encoding = "UTF-8")

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

# Custom color palette (based on ggsci NPG)
# Used across all visualizations for consistency
custom_palette <- c(
  "#E64B35FF", "#4DBBD5FF", "#00A087FF", "#3C5488FF", 
  "#F39B7FFF", "#8491B4FF", "#91D1C2FF", "#DC0000FF"
)

# Maximum file upload size (100 MB)
# Allows users to upload larger datasets
options(shiny.maxRequestSize = 100 * 1024^2)

# Disable scientific notation for better readability
# Display full numbers instead of 1.23e+05 format
options(scipen = 999)
