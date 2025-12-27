# =============================================================================
# VISUALIZATION_3D.R
# 3D Visualization Module
# =============================================================================
# Description:
#   Functions for creating interactive 3D scatter plots using rgl package.
#   Supports PCA, PCoA, and NMDS visualizations with:
#   - Group-based coloring
#   - Confidence ellipsoids
#   - Fitted surfaces (smooth, linear, quadratic, additive)
#   - Interactive rglwidget output for Shiny
#
# Dependencies:
#   - rgl: 3D graphics
#   - car: scatter3d function
#   - dplyr: Data manipulation
#
# Author: MicroarrAI Team
# Last Modified: 2024
# =============================================================================

#' Create 3D scatter plot with rgl
#'
#' @description
#' Creates an interactive 3D scatter plot using car::scatter3d() and rgl.
#' Supports grouped data with customizable ellipsoids and fitted surfaces.
#'
#' @param x Numeric vector. X-axis coordinates
#' @param y Numeric vector. Y-axis coordinates
#' @param z Numeric vector. Z-axis coordinates
#' @param groups Factor. Grouping variable for color coding
#' @param xlab Character. X-axis label (default: "Dim 1")
#' @param ylab Character. Y-axis label (default: "Dim 2")
#' @param zlab Character. Z-axis label (default: "Dim 3")
#' @param surface Logical. Draw fitted surface (default: TRUE)
#' @param ellipsoid Logical. Draw confidence ellipsoids (default: FALSE)
#' @param fit Character. Surface fit type: "smooth", "linear", "quadratic", 
#'   "additive" (default: "smooth")
#' @param surface_col Character vector. Colors for surface (default: custom_palette)
#' @param axis_col Character vector. Axis colors (default: rep("black", 3))
#' @param grid Logical. Show grid (default: TRUE)
#'
#' @return An rglwidget object for rendering in Shiny
#'
#' @details
#' Surface fit types:
#' - "smooth": Smooth surface using local regression (loess)
#' - "linear": Linear regression plane
#' - "quadratic": Quadratic surface
#' - "additive": Additive model (GAM-like)
#'
#' The function:
#' 1. Opens a new rgl device (useNULL = TRUE for Shiny)
#' 2. Creates scatter3d plot with specified parameters
#' 3. Returns rglwidget for Shiny renderRglwidget()
#'
#' Note: When ellipsoid = TRUE, surface is automatically disabled to avoid
#' visual clutter.
#'
#' @examples
#' # Basic 3D PCA plot
#' plot_3d <- create_3d_scatter(
#'   x = pca$PC1, y = pca$PC2, z = pca$PC3,
#'   groups = metadata$group,
#'   xlab = "PC1", ylab = "PC2", zlab = "PC3"
#' )
#' 
#' # With ellipsoids
#' plot_3d <- create_3d_scatter(
#'   x = coords$x, y = coords$y, z = coords$z,
#'   groups = groups, 
#'   ellipsoid = TRUE, 
#'   surface = FALSE
#' )
#'
#' @export
create_3d_scatter <- function(x, y, z, groups,
                               xlab = "Dim 1", 
                               ylab = "Dim 2", 
                               zlab = "Dim 3",
                               surface = TRUE,
                               ellipsoid = FALSE,
                               fit = "smooth",
                               surface_col = NULL,
                               axis_col = c("black", "black", "black"),
                               grid = TRUE) {
  
  # Input validation
  if (length(x) != length(y) || length(x) != length(z)) {
    stop("x, y, and z must have the same length")
  }
  
  if (length(x) != length(groups)) {
    stop("groups must have the same length as x, y, z")
  }
  
  if (!is.factor(groups)) {
    groups <- as.factor(groups)
  }
  
  # Default surface colors
  if (is.null(surface_col)) {
    surface_col <- c("#E64B35FF", "#4DBBD5FF", "#00A087FF", "#3C5488FF", 
                     "#F39B7FFF", "#8491B4FF", "#91D1C2FF", "#DC0000FF")
  }
  
  # When ellipsoid is TRUE, disable surface to avoid clutter
  if (ellipsoid) {
    surface <- FALSE
  }
  
  # Open rgl device (useNULL = TRUE for Shiny compatibility)
  rgl::open3d(useNULL = TRUE)
  
  # Create 3D scatter plot
  car::scatter3d(
    x = x, 
    y = y, 
    z = z,
    groups = groups,
    grid = grid, 
    surface = surface,
    ellipsoid = ellipsoid,
    surface.col = surface_col,
    axis.col = axis_col,
    xlab = xlab, 
    ylab = ylab, 
    zlab = zlab,
    fit = fit
  )
  
  # Return rglwidget for Shiny
  return(rgl::rglwidget())
}


#' Create 3D PCA visualization
#'
#' @description
#' Convenience wrapper for creating 3D PCA plots with proper axis labels
#' including variance explained.
#'
#' @param pca_coords Data.frame with PC1, PC2, PC3 columns
#' @param groups Factor. Grouping variable
#' @param variance Numeric vector. Variance explained by each PC (optional)
#' @param surface Logical. Draw fitted surface (default: TRUE)
#' @param ellipsoid Logical. Draw confidence ellipsoids (default: FALSE)
#' @param fit Character. Surface fit type (default: "smooth")
#' @param surface_col Character vector. Surface colors
#'
#' @return An rglwidget object
#'
#' @details
#' If variance is provided, axis labels will include % variance explained:
#' e.g., "PC1 (45.2% Variance)"
#'
#' @examples
#' pca_result <- compute_pca(data)
#' variance <- calculate_pca_variance(pca_result)
#' 
#' plot_3d <- create_3d_pca(
#'   pca_coords = pca_result$x,
#'   groups = metadata$group,
#'   variance = variance
#' )
#'
#' @export
create_3d_pca <- function(pca_coords, groups, variance = NULL,
                          surface = TRUE, ellipsoid = FALSE, 
                          fit = "smooth", surface_col = NULL) {
  
  # Check for required columns
  required_cols <- c("PC1", "PC2", "PC3")
  if (!all(required_cols %in% colnames(pca_coords))) {
    stop("pca_coords must contain PC1, PC2, PC3 columns")
  }
  
  # Create axis labels
  if (!is.null(variance) && length(variance) >= 3) {
    xlab <- sprintf("PC1 (%.1f%% Variance)", variance[1])
    ylab <- sprintf("PC2 (%.1f%% Variance)", variance[2])
    zlab <- sprintf("PC3 (%.1f%% Variance)", variance[3])
  } else {
    xlab <- "PC1"
    ylab <- "PC2"
    zlab <- "PC3"
  }
  
  # Create plot
  plot_3d <- create_3d_scatter(
    x = pca_coords$PC1,
    y = pca_coords$PC2,
    z = pca_coords$PC3,
    groups = groups,
    xlab = xlab,
    ylab = ylab,
    zlab = zlab,
    surface = surface,
    ellipsoid = ellipsoid,
    fit = fit,
    surface_col = surface_col
  )
  
  return(plot_3d)
}


#' Create 3D PCoA visualization
#'
#' @description
#' Convenience wrapper for creating 3D PCoA plots with proper axis labels.
#'
#' @param pcoa_coords Data.frame with pcoa1, pcoa2, pcoa3 columns (or PCoA1, PCoA2, PCoA3)
#' @param groups Factor. Grouping variable
#' @param surface Logical. Draw fitted surface (default: TRUE)
#' @param ellipsoid Logical. Draw confidence ellipsoids (default: FALSE)
#' @param fit Character. Surface fit type (default: "smooth")
#' @param surface_col Character vector. Surface colors
#'
#' @return An rglwidget object
#'
#' @examples
#' dist_mat <- compute_distance_matrix(data, "Group", "bray")
#' pcoa_coords <- perform_pcoa(dist_mat, k = 3)
#' 
#' plot_3d <- create_3d_pcoa(
#'   pcoa_coords = pcoa_coords,
#'   groups = groups,
#'   ellipsoid = TRUE
#' )
#'
#' @export
create_3d_pcoa <- function(pcoa_coords, groups,
                           surface = TRUE, ellipsoid = FALSE, 
                           fit = "smooth", surface_col = NULL) {
  
  # Check for required columns (case-insensitive)
  col_names <- colnames(pcoa_coords)
  
  # Try lowercase first
  if (all(c("pcoa1", "pcoa2", "pcoa3") %in% tolower(col_names))) {
    idx <- match(c("pcoa1", "pcoa2", "pcoa3"), tolower(col_names))
    x_col <- col_names[idx[1]]
    y_col <- col_names[idx[2]]
    z_col <- col_names[idx[3]]
  } else if (all(c("PCoA1", "PCoA2", "PCoA3") %in% col_names)) {
    x_col <- "PCoA1"
    y_col <- "PCoA2"
    z_col <- "PCoA3"
  } else {
    stop("pcoa_coords must contain pcoa1, pcoa2, pcoa3 or PCoA1, PCoA2, PCoA3 columns")
  }
  
  # Create plot
  plot_3d <- create_3d_scatter(
    x = pcoa_coords[[x_col]],
    y = pcoa_coords[[y_col]],
    z = pcoa_coords[[z_col]],
    groups = groups,
    xlab = "PCoA 1",
    ylab = "PCoA 2",
    zlab = "PCoA 3",
    surface = surface,
    ellipsoid = ellipsoid,
    fit = fit,
    surface_col = surface_col
  )
  
  return(plot_3d)
}


#' Create 3D NMDS visualization
#'
#' @description
#' Convenience wrapper for creating 3D NMDS plots with proper axis labels.
#'
#' @param nmds_coords Data.frame with NMDS1, NMDS2, NMDS3 columns
#' @param groups Factor. Grouping variable
#' @param surface Logical. Draw fitted surface (default: TRUE)
#' @param ellipsoid Logical. Draw confidence ellipsoids (default: FALSE)
#' @param fit Character. Surface fit type (default: "smooth")
#' @param surface_col Character vector. Surface colors
#'
#' @return An rglwidget object
#'
#' @examples
#' dist_mat <- compute_distance_matrix(data, "Group", "bray")
#' nmds_coords <- perform_nmds(dist_mat, k = 3)
#' 
#' plot_3d <- create_3d_nmds(
#'   nmds_coords = nmds_coords,
#'   groups = groups,
#'   fit = "linear"
#' )
#'
#' @export
create_3d_nmds <- function(nmds_coords, groups,
                           surface = TRUE, ellipsoid = FALSE, 
                           fit = "smooth", surface_col = NULL) {
  
  # Check for required columns
  required_cols <- c("NMDS1", "NMDS2", "NMDS3")
  if (!all(required_cols %in% colnames(nmds_coords))) {
    stop("nmds_coords must contain NMDS1, NMDS2, NMDS3 columns")
  }
  
  # Create plot
  plot_3d <- create_3d_scatter(
    x = nmds_coords$NMDS1,
    y = nmds_coords$NMDS2,
    z = nmds_coords$NMDS3,
    groups = groups,
    xlab = "NMDS 1",
    ylab = "NMDS 2",
    zlab = "NMDS 3",
    surface = surface,
    ellipsoid = ellipsoid,
    fit = fit,
    surface_col = surface_col
  )
  
  return(plot_3d)
}


#' Toggle surface fit type
#'
#' @description
#' Cycles through surface fit types: smooth -> linear -> quadratic -> additive -> smooth
#'
#' @param current_fit Character. Current fit type
#'
#' @return Character. Next fit type in cycle
#'
#' @details
#' This is a helper function for reactive surface type toggling in Shiny apps.
#'
#' @examples
#' # In observeEvent for toggle button
#' new_fit <- toggle_surface_fit(surface_type())
#' surface_type(new_fit)
#'
#' @export
toggle_surface_fit <- function(current_fit) {
  
  fit_cycle <- c("smooth", "linear", "quadratic", "additive")
  
  # Find current position
  current_idx <- match(current_fit, fit_cycle)
  
  # If not found, default to smooth
  if (is.na(current_idx)) {
    return("smooth")
  }
  
  # Get next in cycle
  next_idx <- (current_idx %% length(fit_cycle)) + 1
  
  return(fit_cycle[next_idx])
}
