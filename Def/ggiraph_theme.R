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

# Opciones reutilizables de girafe
get_girafe_options <- function(width_svg = 7, height_svg = 5) {
  list(
    opts_hover(css = hover_css),
    opts_tooltip(css = tooltip_css),
    opts_hover_inv(css = hover_inv_css),
    opts_sizing(rescale = TRUE, width = 1),
    opts_toolbar(saveaspng = TRUE)
  )
}

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

# Helper para crear tooltips informativos
create_tooltip <- function(...) {
  args <- list(...)
  tooltip_lines <- sapply(names(args), function(name) {
    paste0("<b>", name, ":</b> ", args[[name]])
  })
  paste(tooltip_lines, collapse = "<br/>")
}

# Ejemplo de uso:
# ggplot(data, aes(x = x, y = y, 
#                  tooltip = create_tooltip(
#                    Sample = id,
#                    Value = round(value, 2),
#                    Group = group
#                  ),
#                  data_id = id)) +
#   geom_point_interactive() +
#   theme_microarrai()
#
# interactive_plot <- apply_girafe(last_plot())
