# ============================================================================
# GGIRAPH CUSTOMIZATION TEMPLATE
# Sistema de plots interactivos con ggiraph
# ============================================================================

# CSS Styles para tooltips y hover effects
tooltip_css <- "
  border-radius: 12px;
  color: #333;
  background-color: white;
  padding: 10px;
  font-size: 14px;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  transition: all 0.3s ease-out;
"

hover_css <- "
  filter: brightness(1.15);
  cursor: pointer;
  transition: all 0.3s ease-out;
"

hover_inv_css <- "
  opacity: 0.3;
  transition: all 0.1s ease-out;
"

# Wrapper function para aplicar opciones consistentes
apply_girafe <- function(ggplot_obj, width_svg = 9, height_svg = 6.5) {
  girafe_obj <- girafe(
    ggobj = ggplot_obj,
    width_svg = width_svg,
    height_svg = height_svg
  )

  # Apply all options
  girafe_obj <- girafe_options(
    x = girafe_obj,
    opts_hover(css = hover_css),
    opts_tooltip(css = tooltip_css),
    opts_hover_inv(css = hover_inv_css),
    opts_sizing(rescale = TRUE, width = 1),
    opts_toolbar(saveaspng = TRUE)
  )

  return(girafe_obj)
}
