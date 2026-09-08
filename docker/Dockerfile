# =============================================================================
# MicroarrAI - Dockerfile
# =============================================================================
# Base: rocker/shiny-verse (includes R, Shiny Server, and tidyverse)
#
# The R package set lives in ../dependencies.R, which singularity/MicroarrAI.def
# uses as well, so the two images install exactly the same thing.
# =============================================================================

FROM rocker/shiny-verse:4.4.0

# =============================================================================
# SYSTEM DEPENDENCIES
# =============================================================================
# System libraries required to build the R packages listed in dependencies.R
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
    # Mathematics and Graph libs (required for mixOmics/igraph)
    libglpk-dev \
    libgmp3-dev \
    # Excel file support
    libzip-dev \
    # Database support
    libpq-dev \
    libsqlite3-dev \
    # Additional utilities
    # curl is required by the docker-compose healthcheck
    zlib1g-dev \
    git \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# R PACKAGE INSTALLATION
# =============================================================================
# Copied on its own so the (long) install layer is only rebuilt when the
# dependency list actually changes, not on every application edit.
#
# No repos= override here on purpose: the rocker base image pins CRAN to a dated
# Posit Package Manager snapshot, which gives reproducible versions and prebuilt
# Linux binaries. Overriding it with cloud.r-project.org would force every
# package to be compiled from source and un-pin the whole image.
COPY dependencies.R /tmp/dependencies.R
RUN Rscript /tmp/dependencies.R install && rm /tmp/dependencies.R

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
COPY dependencies.R .

# Set proper permissions for Shiny Server
RUN chown -R shiny:shiny /srv/shiny-server/MicroarrAI

# =============================================================================
# SHINY SERVER CONFIGURATION
# =============================================================================
# Enabled so the app gets the longer init timeout it needs: loading mixOmics,
# caret and the rest of R/global.R takes well over the 60s default on a cold
# start, which otherwise surfaces to the user as "an error has occurred".
COPY docker/shiny-server.conf /etc/shiny-server/shiny-server.conf

# Expose port 3838 (default Shiny Server port)
EXPOSE 3838

# =============================================================================
# RUNTIME
# =============================================================================

# Fail fast if the image is missing a package the app needs
RUN Rscript /srv/shiny-server/MicroarrAI/dependencies.R check

# Run Shiny Server
CMD ["/usr/bin/shiny-server"]

# =============================================================================
# BUILD INSTRUCTIONS
# =============================================================================
# Build the image (from the repository root, the build context is ..):
#   docker compose -f docker/docker-compose.yml build
#
# Run the container:
#   docker compose -f docker/docker-compose.yml up -d
#
# Access the app:
#   http://localhost:3838/MicroarrAI
#
# Users upload their own scan files through the browser; no host data directory
# is mounted and nothing user-supplied is stored in the image.
# =============================================================================
