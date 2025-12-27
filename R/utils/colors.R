# ============================================================================
# MicroarrAI - Color Palette Definitions
# ============================================================================
# Description: Corporate color palette for consistent branding across all plots
# Used by: theme.R, scales.R, all plotting functions
# ============================================================================

#' MicroarrAI Corporate Color Palette
#' 
#' A carefully curated 12-color palette for data visualization
#' Ensures accessibility and visual consistency across the application
MICROARRAI_COLORS <- c(
  "#1F78B4",  # navy_blue
  "#18BC9C",  # green
  "#CCBE93",  # yellow
  "#A6CEE3",  # steel_blue
  "#2C3E50",  # blue
  "#E31A1C",  # red
  "#B2DF8A",  # light_green
  "#FB9A99",  # pink
  "#FDBF6F",  # light_orange
  "#FF7F00",  # orange
  "#CAB2D6",  # light_purple
  "#6A3D9A"   # purple
)

# Legacy alias for backward compatibility
custom_palette <- MICROARRAI_COLORS

#' MicroarrAI Palette Function
#' 
#' Returns a function that can generate n colors from the palette
#' If n > 12, uses colorRampPalette to interpolate
#'
#' @return Function that takes n (number of colors) and returns color vector
#' @examples
#' pal <- microarrai_pal()
#' pal(5)  # First 5 colors
#' pal(20) # Interpolated 20 colors
microarrai_pal <- function() {
  force(MICROARRAI_COLORS)
  function(n) {
    if (n <= length(MICROARRAI_COLORS)) {
      MICROARRAI_COLORS[seq_len(n)]
    } else {
      grDevices::colorRampPalette(MICROARRAI_COLORS)(n)
    }
  }
}
