# ============================================================================
# MicroarrAI - Plotting Utility Functions
# ============================================================================
# Description: Reusable plotting helpers for data preparation and visualization
# Dependencies: None (pure functions)
# Used by: Heatmap rendering, isotype-specific visualizations
# ============================================================================

#' Split Matrix by Isotype Prefix
#'
#' Separates a matrix into IgE and IgG4 submatrices based on column name prefixes
#' Commonly used for dual-heatmap visualization or separate analysis of isotypes
#'
#' @param mat Numeric matrix with column names potentially prefixed with "IgE_" or "IgG4_"
#' @return List with three elements:
#'   \itemize{
#'     \item any_iso: Logical indicating if any isotype columns were found
#'     \item ige: Matrix of IgE columns (NULL if none found)
#'     \item igg4: Matrix of IgG4 columns (NULL if none found)
#'   }
#' @examples
#' mat <- matrix(rnorm(100), ncol = 10)
#' colnames(mat) <- c(paste0("IgE_", 1:5), paste0("IgG4_", 1:5))
#' result <- split_isotype_mats(mat)
#' result$ige   # 5-column matrix
#' result$igg4  # 5-column matrix
split_isotype_mats <- function(mat) {
  stopifnot(is.matrix(mat))
  
  cn <- colnames(mat)
  idx_ige  <- grepl("^IgE_",  cn)
  idx_igg4 <- grepl("^IgG4_", cn)
  
  list(
    any_iso = any(idx_ige) || any(idx_igg4),
    ige  = if (any(idx_ige))  mat[, idx_ige,  drop = FALSE] else NULL,
    igg4 = if (any(idx_igg4)) mat[, idx_igg4, drop = FALSE] else NULL
  )
}
