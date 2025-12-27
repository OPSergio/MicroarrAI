# ============================================================================
# MicroarrAI - ggplot2 Theme System
# ============================================================================
# Description: Custom ggplot2 theme with corporate styling
# Dependencies: colors.R (for MICROARRAI_COLORS)
# Used by: All plotting functions throughout the app
# ============================================================================

#' MicroarrAI Custom ggplot2 Theme
#'
#' Provides a consistent, clean theme for all plots in the application
#' Based on theme_minimal with custom typography and colors
#'
#' @param base_size Base font size in points (default: 12)
#' @param base_family Font family (default: Arial or from options)
#' @param grid Show grid lines (default: TRUE)
#' @param axis Show axis titles and text (default: TRUE)
#' @param ticks Show axis ticks (default: TRUE)
#' @return A ggplot2 theme object
#' @examples
#' ggplot(data) + geom_point() + theme_microarrai()
#' ggplot(data) + geom_bar() + theme_microarrai(grid = FALSE)
theme_microarrai <- function(base_size = 12,
                             base_family = getOption("microarrai_font", "Arial"),
                             grid = TRUE, 
                             axis = TRUE, 
                             ticks = TRUE) {
  
  th <- ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      # Plot elements
      plot.title      = ggplot2::element_text(
        face = "bold", 
        size = base_size + 4, 
        hjust = 0, 
        margin = ggplot2::margin(b = 8)
      ),
      plot.subtitle   = ggplot2::element_text(
        size = base_size + 1, 
        margin = ggplot2::margin(b = 6)
      ),
      plot.caption    = ggplot2::element_text(
        size = base_size - 1, 
        colour = "#6b7280"
      ),
      
      # Axis elements
      axis.title.x    = ggplot2::element_text(
        face = "bold", 
        margin = ggplot2::margin(t = 6)
      ),
      axis.title.y    = ggplot2::element_text(
        face = "bold", 
        margin = ggplot2::margin(r = 6)
      ),
      axis.text       = ggplot2::element_text(colour = "#111827"),
      
      # Legend elements
      legend.position = "right",
      legend.title    = ggplot2::element_text(face = "bold"),
      
      # Panel elements
      panel.grid.major = ggplot2::element_line(
        colour = "#e5e7eb", 
        linewidth = 0.5
      ),
      panel.grid.minor = ggplot2::element_line(
        colour = "#f3f4f6", 
        linewidth = 0.25
      ),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.background  = ggplot2::element_rect(fill = "white", colour = NA),
      
      # Facet elements
      strip.text       = ggplot2::element_text(face = "bold"),
      strip.background = ggplot2::element_rect(fill = "#eef2ff", colour = NA)
    )
  
  # Optional: remove grid
  if (!grid) {
    th <- th + ggplot2::theme(panel.grid = ggplot2::element_blank())
  }
  
  # Optional: remove axis labels
  if (!axis) {
    th <- th + ggplot2::theme(
      axis.title = ggplot2::element_blank(), 
      axis.text = ggplot2::element_blank()
    )
  }
  
  # Optional: remove ticks
  if (!ticks) {
    th <- th + ggplot2::theme(axis.ticks = ggplot2::element_blank())
  }
  
  th
}

#' Set Default Geom Aesthetics for MicroarrAI
#'
#' Applies consistent defaults to common geoms (line, point, bar, etc.)
#' Ensures all plots follow corporate style without explicit styling
#'
#' @return NULL (side effect: updates ggplot2 defaults)
#' @examples
#' set_geom_defaults_microarrai()
set_geom_defaults_microarrai <- function() {
  ggplot2::update_geom_defaults(
    "line", 
    list(linewidth = 0.8, colour = "#2C3E50")
  )
  ggplot2::update_geom_defaults(
    "point", 
    list(size = 2.5, alpha = 0.8)
  )
  ggplot2::update_geom_defaults(
    "bar", 
    list(fill = MICROARRAI_COLORS[1], alpha = 0.8)
  )
  ggplot2::update_geom_defaults(
    "col", 
    list(fill = MICROARRAI_COLORS[1], alpha = 0.8)
  )
  ggplot2::update_geom_defaults(
    "boxplot", 
    list(outlier.colour = MICROARRAI_COLORS[6], outlier.alpha = 0.7)
  )
}

#' Activate MicroarrAI Plot Style Globally
#'
#' One-time setup to apply theme and geom defaults across the entire app
#' Should be called once at app startup (in global.R or server initialization)
#'
#' @return NULL (side effects: sets ggplot2 theme and defaults)
#' @examples
#' activate_microarrai_plot_style()
activate_microarrai_plot_style <- function() {
  ggplot2::theme_set(theme_microarrai())
  set_geom_defaults_microarrai()
  options(microarrai_font = "Arial")  # Can be changed to "DejaVu Sans" if preferred
}
