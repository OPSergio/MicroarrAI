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

# ----------------------------------------------------------------------------
# Isotypes and scanner channels (lab convention)
# ----------------------------------------------------------------------------
# Channel 1 is scanned red and holds IgG4; channel 2 is scanned green and holds
# IgE. GenePix-style files name channels by wavelength (635 nm red, 532 nm
# green) instead, so those are mapped by colour, not by order.
ISOTYPE_COLORS <- c(IgE = "#17a589", IgG4 = "#d1495b")

#' Colour per isotype: IgE green, IgG4 red, any other from the palette
isotype_colors <- function(isos) {
  other <- rep_len(c("#1F78B4", "#6A3D9A", "#FF7F00", "#2C3E50"), length(isos))
  unname(ifelse(isos %in% names(ISOTYPE_COLORS), ISOTYPE_COLORS[isos], other))
}

#' Default label of each detected channel
#'
#' Wavelength-named channels (GenePix / ScanArray .gpr: 532, 543, 633, 635…)
#' follow their laser colour, however many there are; a pair of numbered
#' channels (ScanArray CSV "Ch1", "Ch2") follows the order red, green.
default_channel_labels <- function(channels) {
  nm <- suppressWarnings(as.numeric(channels))
  wl <- !is.na(nm) & nm > 400
  out <- paste0("Ch", channels)
  out[wl] <- ifelse(nm[wl] >= 600, "IgG4", "IgE")
  if (!any(wl) && length(channels) == 2) out <- c("IgG4", "IgE")
  out
}

#' Scanner colour of channel i, for the dot next to its label
channel_color <- function(channels, i) {
  label <- default_channel_labels(channels)[i]
  if (label %in% names(ISOTYPE_COLORS)) ISOTYPE_COLORS[[label]] else "#9ca3af"
}
