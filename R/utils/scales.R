# ============================================================================
# MicroarrAI - ggplot2 Scale Helpers
# ============================================================================
# Description: Custom color/fill scales using corporate palette
# Dependencies: colors.R (for MICROARRAI_COLORS and microarrai_pal)
# Used by: All ggplot2 plots requiring color/fill aesthetics
# ============================================================================

#' MicroarrAI Color Scale
#'
#' Apply the corporate color palette to ggplot2 color aesthetic
#' Supports both discrete (categorical) and continuous variables
#'
#' @param discrete Logical. If TRUE, uses discrete colors. If FALSE, uses gradient
#' @param ... Additional arguments passed to scale_color_manual or scale_color_gradientn
#' @return A ggplot2 scale object
#' @examples
#' ggplot(data, aes(x, y, color = group)) + geom_point() + scale_color_microarrai()
#' ggplot(data, aes(x, y, color = value)) + geom_point() + scale_color_microarrai(discrete = FALSE)
scale_color_microarrai <- function(discrete = TRUE, ...) {
  if (discrete) {
    ggplot2::scale_color_manual(values = MICROARRAI_COLORS, ...)
  } else {
    ggplot2::scale_color_gradientn(colours = microarrai_pal()(256), ...)
  }
}

#' MicroarrAI Fill Scale
#'
#' Apply the corporate color palette to ggplot2 fill aesthetic
#' Supports both discrete (categorical) and continuous variables
#'
#' @param discrete Logical. If TRUE, uses discrete colors. If FALSE, uses gradient
#' @param ... Additional arguments passed to scale_fill_manual or scale_fill_gradientn
#' @return A ggplot2 scale object
#' @examples
#' ggplot(data, aes(x, fill = group)) + geom_bar() + scale_fill_microarrai()
#' ggplot(data, aes(x, y, fill = value)) + geom_tile() + scale_fill_microarrai(discrete = FALSE)
scale_fill_microarrai <- function(discrete = TRUE, ...) {
  if (discrete) {
    ggplot2::scale_fill_manual(values = MICROARRAI_COLORS, ...)
  } else {
    ggplot2::scale_fill_gradientn(colours = microarrai_pal()(256), ...)
  }
}
