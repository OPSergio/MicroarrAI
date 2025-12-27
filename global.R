# =============================================================================
# GLOBAL.R
# Global configuration and module loading
# =============================================================================
# Description:
#   Central configuration file for MicroarrAI Shiny application.
#   Loads all required packages, custom functions, and modules.
#
# Author: MicroarrAI Team
# Last Modified: 2024
# =============================================================================

# =============================================================================
# Package Loading
# =============================================================================

# Data manipulation
library(dplyr)
library(tidyr)
library(tibble)
library(readr)
library(purrr)
library(stringr)

# Shiny framework
library(shiny)
library(shinyWidgets)
library(shinydashboard)
library(shinycssloaders)
library(DT)

# Visualization - General
library(ggplot2)
library(plotly)
library(ggpubr)
library(cowplot)
library(ggrepel)
library(ggvenn)
library(formattable)  # Styled tables

# Visualization - 3D
library(rgl)
library(car)

# Statistical analysis
library(vegan)  # Distance matrices, ordination (PCoA, NMDS)

# Machine Learning - Supervised
library(C50)           # C5.0 decision trees
library(randomForest)  # Random Forest
library(e1071)         # SVM
library(caret)         # ML framework, RFE, train
library(xgboost)       # Gradient boosting
library(shapviz)       # SHAP values

# Machine Learning - Regression
library(tidymodels)    # Meta-package for modeling
library(parsnip)       # Model specifications (multinom_reg)
library(yardstick)     # Performance metrics (accuracy, roc_auc)
library(pROC)          # ROC curves

# =============================================================================
# Load Server Modules
# =============================================================================

# Data processing
source("R/server/data_processing.R", encoding = "UTF-8")

# Statistical analysis
source("R/server/statistical_analysis.R", encoding = "UTF-8")

# Peptide summary and visualizations
source("R/server/peptide_summary.R", encoding = "UTF-8")

# Machine Learning - Unsupervised
source("R/server/ml_unsupervised.R", encoding = "UTF-8")

# Machine Learning - Supervised
source("R/server/ml_supervised.R", encoding = "UTF-8")

# Regression models
source("R/server/regression_models.R", encoding = "UTF-8")

# 3D Visualization
source("R/server/visualization_3d.R", encoding = "UTF-8")

# =============================================================================
# Load UI Modules
# =============================================================================

source("R/ui/ui_home.R", encoding = "UTF-8")
source("R/ui/ui_preprocess.R", encoding = "UTF-8")
source("R/ui/ui_peptide.R", encoding = "UTF-8")
source("R/ui/ui_ml.R", encoding = "UTF-8")
source("R/ui/ui_visualization.R", encoding = "UTF-8")

# =============================================================================
# Load Helper Functions
# =============================================================================

# Custom theme function
source("Def/Function2.R", encoding = "UTF-8")

# Synthetic data generation
source("Def/synthetic_data.R", encoding = "UTF-8")

# =============================================================================
# Global Variables and Configuration
# =============================================================================

# Custom color palette (ggsci NPG)
custom_palette <- c(
  "#E64B35FF", "#4DBBD5FF", "#00A087FF", "#3C5488FF", 
  "#F39B7FFF", "#8491B4FF", "#91D1C2FF", "#DC0000FF"
)

# Maximum file upload size (100 MB)
options(shiny.maxRequestSize = 100 * 1024^2)

# Disable scientific notation for readability
options(scipen = 999)
