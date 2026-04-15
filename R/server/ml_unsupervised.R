# =============================================================================
# ML_UNSUPERVISED.R
# Unsupervised Machine Learning Module
# =============================================================================
# Description:
#   Functions for unsupervised machine learning analysis including:
#   - PCA (Principal Component Analysis)
#   - PCoA (Principal Coordinate Analysis)
#   - NMDS (Non-metric Multidimensional Scaling)
#   - Distance matrix calculation
#   - 2D and 3D visualization support
#
# Dependencies:
#   - vegan: Distance matrices, ordination methods
#   - stats: PCA computation
#   - dplyr, tidyr: Data manipulation
#
# Author: Sergio Olmos Piñero
# Last Modified: 2025
# =============================================================================

#' Compute PCA (Principal Component Analysis)
#' 
#' @description
#' Performs PCA on numeric columns of the input data. Missing values are 
#' replaced with 0. The function centers the data before applying PCA.
#'
#' @param data A data.frame with samples as rows. First column should be 
#'   sample IDs, followed by numeric peptide/gene expression columns.
#' @param center Logical. If TRUE (default), center the data before PCA.
#' @param scale. Logical. If TRUE, scale the data to unit variance.
#'
#' @return A data.frame with principal component coordinates (PC1, PC2, PC3, ...)
#'   with one row per sample.
#'
#' @details
#' The function:
#' 1. Selects only numeric columns from input data
#' 2. Replaces NA values with 0
#' 3. Applies prcomp() with centering
#' 4. Returns PC coordinates as a data.frame
#'
#' @examples
#' # Basic PCA
#' pca_result <- compute_pca(expression_data)
#' 
#' # PCA with scaling
#' pca_scaled <- compute_pca(expression_data, scale. = TRUE)
#'
#' @export
compute_pca <- function(data, center = TRUE, scale. = FALSE) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  # Select numeric columns only
  numeric_data <- data %>% 
    dplyr::select(where(is.numeric))
  
  if (ncol(numeric_data) == 0) {
    stop("No numeric columns found in input data")
  }
  
  # Replace NA values with 0
  numeric_data[is.na(numeric_data)] <- 0
  
  # Perform PCA
  pca <- prcomp(numeric_data, center = center, scale. = scale.)
  
  # Return PC coordinates as data.frame
  pca_coords <- as.data.frame(pca$x)
  
  return(pca_coords)
}


#' Calculate variance explained by principal components
#'
#' @description
#' Computes the percentage of variance explained by each principal component.
#'
#' @param pca_result Output from prcomp() or compute_pca()
#' @param n_components Number of components to calculate variance for (default: all)
#'
#' @return A numeric vector with variance percentages
#'
#' @details
#' Formula: Variance % = (eigenvalue / sum of eigenvalues) * 100
#'
#' @examples
#' pca <- compute_pca(data)
#' var_explained <- calculate_pca_variance(pca)
#'
#' @export
calculate_pca_variance <- function(pca_result, n_components = NULL) {
  
  # Extract standard deviations (eigenvalues)
  sdev <- pca_result$sdev
  
  # Calculate variance explained
  variance <- sdev^2
  variance_percent <- (variance / sum(variance)) * 100
  
  # Limit to n_components if specified
  if (!is.null(n_components)) {
    variance_percent <- variance_percent[1:min(n_components, length(variance_percent))]
  }
  
  return(variance_percent)
}


#' Compute distance matrix with multiple methods
#'
#' @description
#' Calculates a distance matrix using vegan::vegdist() with support for 
#' various distance metrics. The function handles data preprocessing including
#' scaling and NA imputation.
#'
#' @param data A data.frame with samples as rows. Must include 'id' column
#'   for sample identifiers and a grouping variable.
#' @param group_var Character. Name of the grouping variable column.
#' @param distance_method Character. Distance metric to use. Options include:
#'   "bray", "euclidean", "manhattan", "jaccard", "kulczynski", etc.
#'   See ?vegan::vegdist for all options.
#' @param scale_data Logical. If TRUE (default), scale numeric columns.
#' @param impute_na Logical. If TRUE (default), replace NA with column median.
#'
#' @return A distance matrix object (class 'dist')
#'
#' @details
#' Processing steps:
#' 1. Convert character columns to factors
#' 2. Rename group_var to 'target' and convert to factor
#' 3. Set 'id' as row names
#' 4. Scale numeric columns (excluding 'target')
#' 5. Impute NA values with column medians
#' 6. Calculate distance matrix using vegan::vegdist()
#'
#' Common distance methods:
#' - "euclidean": Euclidean distance (default in many algorithms)
#' - "bray": Bray-Curtis dissimilarity (ecology, microbiome)
#' - "jaccard": Jaccard index (binary/presence-absence data)
#' - "manhattan": Manhattan/city-block distance
#'
#' @examples
#' # Bray-Curtis distance
#' dist_mat <- compute_distance_matrix(data, "Disease_Status", "bray")
#' 
#' # Euclidean without scaling
#' dist_mat <- compute_distance_matrix(data, "Group", "euclidean", scale_data = FALSE)
#'
#' @export
compute_distance_matrix <- function(data, 
                                     group_var, 
                                     distance_method = "bray",
                                     scale_data = TRUE,
                                     impute_na = TRUE) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!group_var %in% colnames(data)) {
    stop(paste("Group variable", group_var, "not found in data"))
  }
  
  if (!"id" %in% colnames(data)) {
    stop("Data must contain 'id' column for sample identifiers")
  }
  
  # Data preprocessing
  df <- data %>%
    dplyr::mutate(across(where(is.character), as.factor)) %>%
    dplyr::rename(target = !!rlang::sym(group_var)) %>%
    dplyr::mutate(target = as.factor(target)) %>%
    tibble::column_to_rownames(var = "id")
  
  # Scale numeric columns (excluding 'target')
  if (scale_data) {
    numeric_columns <- sapply(df, is.numeric)
    df[, numeric_columns & names(df) != "target"] <- scale(
      df[, numeric_columns & names(df) != "target"], 
      center = TRUE, 
      scale = TRUE
    )
  }
  
  # Select only numeric columns for distance calculation
  dist_input <- df %>%
    dplyr::select(where(is.numeric))
  
  # Impute NA values with median
  if (impute_na) {
    dist_input <- dist_input %>%
      dplyr::mutate(across(everything(), ~ifelse(is.na(.), median(., na.rm = TRUE), .)))
  }
  
  # Calculate distance matrix
  dist_matrix <- vegan::vegdist(dist_input, method = distance_method, na.rm = TRUE)
  
  return(dist_matrix)
}


#' Perform PCoA (Principal Coordinate Analysis)
#'
#' @description
#' Computes PCoA coordinates from a distance matrix using classical 
#' multidimensional scaling (cmdscale).
#'
#' @param distance_matrix A distance matrix object (class 'dist')
#' @param k Number of dimensions to return (default: 2 for 2D plots)
#' @param add Logical. Add a constant to the non-diagonal dissimilarities to 
#'   make the matrix Euclidean (default: TRUE).
#' @param eig Logical. Return eigenvalues (default: TRUE).
#'
#' @return A data.frame with PCoA coordinates (pcoa1, pcoa2, pcoa3, ...)
#'   Row names are preserved from the distance matrix.
#'
#' @details
#' PCoA (also known as Classical MDS) is a dimensionality reduction technique
#' that preserves the pairwise distances between samples.
#' 
#' The 'add' parameter helps handle negative eigenvalues that can occur with
#' non-Euclidean distance matrices (e.g., Bray-Curtis).
#'
#' @examples
#' # 2D PCoA
#' dist_mat <- compute_distance_matrix(data, "Group", "bray")
#' pcoa_2d <- perform_pcoa(dist_mat, k = 2)
#' 
#' # 3D PCoA for visualization
#' pcoa_3d <- perform_pcoa(dist_mat, k = 3)
#'
#' @export
perform_pcoa <- function(distance_matrix, k = 2, add = TRUE, eig = TRUE) {
  
  # Input validation
  if (!inherits(distance_matrix, "dist")) {
    stop("Input must be a distance matrix object (class 'dist')")
  }
  
  # Perform PCoA using cmdscale
  pcoa <- cmdscale(distance_matrix, eig = eig, k = k, add = add)
  
  # Extract coordinates
  if (eig) {
    pcoa_coords <- as.data.frame(pcoa$points)
  } else {
    pcoa_coords <- as.data.frame(pcoa)
  }
  
  # Name columns
  colnames(pcoa_coords) <- paste0("pcoa", 1:ncol(pcoa_coords))
  
  return(pcoa_coords)
}


#' Perform NMDS (Non-metric Multidimensional Scaling)
#'
#' @description
#' Computes NMDS coordinates from a distance matrix using vegan::metaMDS().
#' NMDS is a robust ordination method that handles non-linear relationships.
#'
#' @param distance_matrix A distance matrix object (class 'dist')
#' @param k Number of dimensions (default: 2 for 2D plots)
#' @param trymax Maximum number of random starts (default: 20)
#' @param autotransform Logical. Use simple model-based transformations 
#'   (default: TRUE).
#'
#' @return A data.frame with NMDS coordinates (NMDS1, NMDS2, NMDS3, ...)
#'   Row names are preserved from the distance matrix.
#'
#' @details
#' NMDS is an iterative ordination method that:
#' 1. Ranks the dissimilarities
#' 2. Finds a configuration that best preserves these ranks
#' 3. Minimizes stress (goodness of fit)
#' 
#' Stress values interpretation:
#' - < 0.05: Excellent
#' - 0.05-0.10: Good
#' - 0.10-0.20: Acceptable
#' - > 0.20: Poor (consider more dimensions)
#'
#' @examples
#' # 2D NMDS
#' dist_mat <- compute_distance_matrix(data, "Group", "bray")
#' nmds_2d <- perform_nmds(dist_mat, k = 2)
#' 
#' # 3D NMDS
#' nmds_3d <- perform_nmds(dist_mat, k = 3)
#'
#' @export
perform_nmds <- function(distance_matrix, k = 2, trymax = 20, autotransform = TRUE) {
  
  # Input validation
  if (!inherits(distance_matrix, "dist")) {
    stop("Input must be a distance matrix object (class 'dist')")
  }
  
  # Perform NMDS
  nmds <- vegan::metaMDS(distance_matrix, k = k, trymax = trymax, autotransform = autotransform)
  
  # Extract coordinates
  nmds_coords <- vegan::scores(nmds) %>%
    as.data.frame()
  
  return(nmds_coords)
}


#' Extract target groups from processed data
#'
#' @description
#' Helper function to extract target grouping variable from data after 
#' preprocessing for ordination analysis.
#'
#' @param data A data.frame with samples and metadata
#' @param group_var Character. Name of the grouping variable
#'
#' @return A factor vector with group labels, names matching row IDs
#'
#' @details
#' This function:
#' 1. Converts character columns to factors
#' 2. Renames group_var to 'target'
#' 3. Sets 'id' as row names
#' 4. Returns the target column as a factor
#'
#' @examples
#' groups <- extract_target_groups(data, "Disease_Status")
#'
#' @export
extract_target_groups <- function(data, group_var) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data.frame")
  }
  
  if (!group_var %in% colnames(data)) {
    stop(paste("Group variable", group_var, "not found in data"))
  }
  
  if (!"id" %in% colnames(data)) {
    stop("Data must contain 'id' column for sample identifiers")
  }
  
  # Process data
  df <- data %>%
    dplyr::mutate(across(where(is.character), as.factor)) %>%
    dplyr::rename(target = !!rlang::sym(group_var)) %>%
    dplyr::mutate(target = as.factor(target)) %>%
    tibble::column_to_rownames(var = "id")
  
  return(df$target)
}
