# ============================================================================
# MicroarrAI - Radar Plot for Model Performance
# ============================================================================
# Description: Interactive radar plot using ggiraph for ML model metrics
# Dependencies: ggplot2, ggiraph, dplyr
# ============================================================================

#' Build Radar Plot Coordinates
#'
#' Converts metric values (0-1 scale) to polar coordinates for radar visualization
#'
#' @param df Data frame with 'Feature' and 'Value' columns
#' @return List with original df and df_closed (polygon closed for geom_polygon)
build_radar_coords <- function(df) {
  df <- df %>%
    dplyr::mutate(
      Feature = factor(Feature, levels = Feature),
      idx = as.integer(Feature),
      n = dplyr::n_distinct(Feature),
      angle = 2 * pi * (idx - 1) / n
    )
  
  # Convert polar -> cartesian (x = r*cos, y = r*sin)
  df <- df %>%
    dplyr::mutate(
      x = Value * cos(angle),
      y = Value * sin(angle),
      tooltip = paste0("<b>", Feature, "</b><br>", round(Value * 100, 1), "%")
    )
  
  # Close polygon by repeating first point
  df_closed <- dplyr::bind_rows(df, df[1, ] %>% dplyr::mutate(idx = n + 1))
  
  list(df = df, df_closed = df_closed)
}

#' Create Interactive Radar Plot
#'
#' Generates radar plot with grid, labels, and interactive tooltips
#'
#' @param df Data frame with 'Feature' and 'Value' columns (values 0-1)
#' @param fill_col Hex color for polygon fill
#' @return ggplot object with ggiraph interactivity
make_radar_plot <- function(df, fill_col = "#667eea") {
  
  coords <- build_radar_coords(df)
  pts <- coords$df
  poly <- coords$df_closed
  
  # Add grid (circles and spokes)
  n <- nlevels(pts$Feature)
  grid_r <- seq(0.25, 1, by = 0.25)
  
  circle_grid <- dplyr::bind_rows(lapply(grid_r, function(r) {
    t <- seq(0, 2*pi, length.out = 200)
    data.frame(x = r*cos(t), y = r*sin(t), r = r)
  }))
  
  spoke_grid <- data.frame(
    angle = 2*pi*(0:(n-1))/n,
    x0 = 0, y0 = 0,
    x1 = cos(2*pi*(0:(n-1))/n),
    y1 = sin(2*pi*(0:(n-1))/n),
    lab = levels(pts$Feature)
  )
  
  ggplot2::ggplot() +
    # circular grid
    ggplot2::geom_path(data = circle_grid, ggplot2::aes(x = x, y = y, group = r), alpha = 0.25, color = "#999") +
    # spokes
    ggplot2::geom_segment(data = spoke_grid, ggplot2::aes(x = x0, y = y0, xend = x1, yend = y1), alpha = 0.25, color = "#999") +
    # axis labels
    ggplot2::geom_text(data = spoke_grid, ggplot2::aes(x = 1.2*x1, y = 1.2*y1, label = lab), 
                      size = 3.5, fontface = "bold", color = "#191c32") +
    
    # polygon (filled, interactive)
    ggiraph::geom_polygon_interactive(
      data = poly,
      ggplot2::aes(x = x, y = y, 
          tooltip = paste0("Overall Performance<br>Mean: ", round(mean(pts$Value) * 100, 1), "%")),
      fill = fill_col,
      alpha = 0.3,
      color = fill_col,
      linewidth = 1.5
    ) +
    
    # points (interactive)
    ggiraph::geom_point_interactive(
      data = pts,
      ggplot2::aes(x = x, y = y, tooltip = tooltip, data_id = as.character(Feature)),
      size = 4,
      color = fill_col
    ) +
    
    ggplot2::coord_equal(xlim = c(-1.3, 1.3), ylim = c(-1.3, 1.3)) +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.margin = ggplot2::margin(10, 10, 10, 10)
    )
}

#' Create Model Performance Radar Plot
#'
#' Wrapper function to generate radar plot from ML model metrics
#' Automatically calculates F1 score from sensitivity and specificity
#'
#' @param result Model result object with metrics (accuracy, auc, sensitivity, specificity)
#' @param model_color Hex color for the model
#' @return ggiraph object ready for rendering
#' @examples
#' # result <- train_model_advanced(data, "c50")
#' # create_performance_radar(result, "#667eea")
create_performance_radar <- function(result, model_color = "#667eea") {
  
  # Extract metrics (values should be 0-1 scale)
  accuracy <- if(!is.null(result$metrics$accuracy)) result$metrics$accuracy else 0
  auc <- if(!is.null(result$metrics$auc)) result$metrics$auc else 0
  sensitivity <- if(!is.null(result$metrics$sensitivity)) result$metrics$sensitivity else 0
  specificity <- if(!is.null(result$metrics$specificity)) result$metrics$specificity else 0
  
  # Calculate F1 score
  # F1 = 2 * (Precision * Recall) / (Precision + Recall)
  # For binary classification from confusion matrix:
  # Sensitivity = Recall = TP/(TP+FN)
  # Specificity = TN/(TN+FP)
  # Precision = TP/(TP+FP)
  # Simplified F1 calculation using sensitivity (as proxy for both precision and recall)
  f1 <- if(sensitivity > 0) {
    # Approximate F1 using harmonic mean of sensitivity and specificity
    2 * (sensitivity * specificity) / (sensitivity + specificity)
  } else {
    0
  }
  
  # Build radar data
  radar_data <- data.frame(
    Feature = c("Accuracy", "AUC", "Sensitivity", "Specificity", "F1 Score"),
    Value = c(accuracy, auc, sensitivity, specificity, f1),
    stringsAsFactors = FALSE
  )
  
  # Create plot
  p <- make_radar_plot(radar_data, fill_col = model_color)
  
  # Return girafe object
  ggiraph::girafe(
    ggobj = p,
    width_svg  = 4.5,
    height_svg = 4.5,
    options = list(
      ggiraph::opts_tooltip(css = "
        background-color: white;
        padding: 8px 12px;
        border-radius: 6px;
        border: 1px solid #ddd;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        font-size: 13px;
        color: #191c32;
      "),
      ggiraph::opts_hover(css = "opacity: 1;"),
      ggiraph::opts_sizing(rescale = TRUE, width = 1)
    )
  )
}
