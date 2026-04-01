# =============================================================================
# MicroarrAI - Dockerfile
# =============================================================================
# Multi-stage build for optimized Shiny application deployment
# Base: rocker/shiny-verse (includes R, Shiny Server, and tidyverse)
# =============================================================================

FROM rocker/shiny-verse:4.4.0

# =============================================================================
# SYSTEM DEPENDENCIES
# =============================================================================
# Install system libraries required for R packages
RUN apt-get update && apt-get install -y \
    # Core development tools
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    # Graphics and visualization
    libcairo2-dev \
    libxt-dev \
    libx11-dev \
    libglu1-mesa-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    # Font rendering
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    # Excel file support
    libzip-dev \
    # Database support
    libpq-dev \
    libsqlite3-dev \
    # Additional utilities
    zlib1g-dev \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# R PACKAGE INSTALLATION
# =============================================================================
# Install R packages in logical groups for better build caching

# Core tidyverse extensions (not in base image)
RUN R -e "install.packages(c('openxlsx'), repos='https://cloud.r-project.org/')"

# Shiny ecosystem
RUN R -e "install.packages(c( \
    'shinyWidgets', \
    'shinydashboard', \
    'shinycssloaders', \
    'DT', \
    'shinyjs', \
    'shinythemes', \
    'bslib', \
    'shinyFiles', \
    'rhandsontable', \
    'markdown' \
    ), repos='https://cloud.r-project.org/')"

# Visualization packages
RUN R -e "install.packages(c( \
    'plotly', \
    'ggpubr', \
    'cowplot', \
    'ggrepel', \
    'ggvenn', \
    'ggiraph', \
    'rgl', \
    'car' \
    ), repos='https://cloud.r-project.org/')"

# Statistical packages
RUN R -e "install.packages(c( \
    'vegan', \
    'dbscan', \
    'cluster' \
    ), repos='https://cloud.r-project.org/')"

# Machine Learning - Part 1 (CRAN packages)
RUN R -e "install.packages(c( \
    'C50', \
    'randomForest', \
    'e1071', \
    'kernlab', \
    'caret', \
    'xgboost', \
    'shapviz' \
    ), repos='https://cloud.r-project.org/')"

# Machine Learning - Part 2 (tidymodels ecosystem)
RUN R -e "install.packages(c( \
    'tidymodels', \
    'parsnip', \
    'yardstick', \
    'pROC', \
    'MLmetrics' \
    ), repos='https://cloud.r-project.org/')"

# Bioconductor packages (mixOmics)
RUN R -e "if (!requireNamespace('BiocManager', quietly = TRUE)) install.packages('BiocManager'); \
    BiocManager::install('mixOmics')"

# GitHub packages (shiny.molstar)
RUN R -e "if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes'); \
    remotes::install_github('Bristol-Vaccine-Centre/shiny.molstar')"

# =============================================================================
# APPLICATION DEPLOYMENT
# =============================================================================

# Remove default Shiny Server app
RUN rm -rf /srv/shiny-server/*

# Create application directory
RUN mkdir -p /srv/shiny-server/MicroarrAI

# Set working directory
WORKDIR /srv/shiny-server/MicroarrAI

# Copy application files
# Order matters for build cache efficiency - copy least changing files first
COPY www ./www
COPY Def ./Def
COPY docs ./docs
COPY R ./R
COPY app.R .
COPY global.R .

# Set proper permissions for Shiny Server
RUN chown -R shiny:shiny /srv/shiny-server/MicroarrAI

# =============================================================================
# SHINY SERVER CONFIGURATION
# =============================================================================

# Copy custom Shiny Server configuration (optional - see shiny-server.conf)
# COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

# Expose port 3838 (default Shiny Server port)
EXPOSE 3838

# =============================================================================
# RUNTIME
# =============================================================================

# Run Shiny Server
CMD ["/usr/bin/shiny-server"]

# =============================================================================
# BUILD INSTRUCTIONS
# =============================================================================
# Build the image:
#   docker build -t microarrai:latest .
#
# Run the container:
#   docker run --rm -p 3838:3838 microarrai:latest
#
# Access the app:
#   http://localhost:3838/MicroarrAI
#
# Run with persistent data volume:
#   docker run --rm -p 3838:3838 -v $(pwd)/data:/srv/shiny-server/MicroarrAI/data microarrai:latest
# =============================================================================
