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
#' @return List with four elements:
#'   \itemize{
#'     \item any_iso: Logical indicating if any isotype columns were found
#'     \item names: The (up to two) isotypes found, e.g. c("IgE", "IgG4")
#'     \item ige: Matrix of the first isotype's columns (NULL if none found)
#'     \item igg4: Matrix of the second isotype's columns (NULL if none found)
#'   }
#' @examples
#' mat <- matrix(rnorm(100), ncol = 10)
#' colnames(mat) <- c(paste0("IgE_p_", 1:5, "_bl"), paste0("IgG4_p_", 1:5, "_bl"))
#' result <- split_isotype_mats(mat)
#' result$ige   # 5-column matrix
#' result$igg4  # 5-column matrix
split_isotype_mats <- function(mat) {
  stopifnot(is.matrix(mat))
  # The first two isotypes found in the data (IgE/IgG4, IgA/IgG, ...); the
  # `ige`/`igg4` slot names are kept for the callers, `names` labels them
  isos <- utils::head(discover_isotypes(colnames(mat)), 2)
  pick <- function(iso) if (is.na(iso)) NULL else mat[, startsWith(colnames(mat), paste0(iso, "_")), drop = FALSE]
  list(any_iso = length(isos) > 0, names = isos, ige = pick(isos[1]), igg4 = pick(isos[2]))
}
