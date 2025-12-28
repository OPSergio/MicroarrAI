# ============================================================================
# MicroarrAI - Global Configuration
# ============================================================================
# Description: Central configuration file for the Shiny application
# Loads all required libraries and sources modular components
# ============================================================================

# ===== Library Loading =====
library(shiny)
library(tidyverse)
library(GGally)
library(shinydashboard)
library(readxl)
library(skimr)
library(shinythemes)
library(ComplexHeatmap)
library(ggsci)
library(tidyquant)
library(car)
library(factoextra)
library(FactoMineR)
library(tidyr)
library(rgl)
library(pheatmap)
library(shiny.molstar)
library(tidymodels)
library(htmltools)
library(shinyFiles)
library(bslib)
library(randomForest)
library(C50)
library(caret)
library(e1071)
library(plotly)
library(shinycssloaders)
library(ggvenn)
library(vegan)
library(cowplot)
library(shinyjs)
library(preprocessCore)
library(ggridges)
library(DT)
library(shapviz)

# ===== Source External Functions =====
source("Def/Function2.R")

# ===== Source Utility Modules =====
# These are pure functions with no reactive dependencies
# Safe to load before UI/server definition

# Color palette definitions
source("R/utils/colors.R")

# ggplot2 theme system
source("R/utils/theme.R")

# ggplot2 scale helpers
source("R/utils/scales.R")

# Plotting utilities (e.g., split_isotype_mats)
source("R/utils/plot_utils.R")

# UI helper functions (card_container, etc.)
source("R/utils/ui_helpers.R")

# ===== Source Server Functions =====
# Data processing and normalization
source("R/server/data_processing.R")

# Statistical analysis (differential expression)
source("R/server/statistical_analysis.R")

# Regression models (GLM, multinomial)
source("R/server/regression_models.R")

# Machine learning - supervised models
source("R/server/ml_supervised.R")

# Machine learning - unsupervised models
source("R/server/ml_unsupervised.R")

# 3D visualization helpers
source("R/server/visualization_3d.R")

# Peptide summary statistics
source("R/server/peptide_summary.R")

# ===== Source UI Modules =====
source("R/ui/ui_home.R")
source("R/ui/ui_preprocess.R")
source("R/ui/ui_peptide.R")
source("R/ui/ui_ml.R")
source("R/ui/ui_visualization.R")

# ===== Global Configuration =====
# Activate MicroarrAI plotting style globally
# This sets default theme and geom aesthetics for all ggplot2 plots
# NOTE: This is called here (global scope) so it applies before any plots are rendered
# DO NOT call again in server() — it's already active
activate_microarrai_plot_style()
