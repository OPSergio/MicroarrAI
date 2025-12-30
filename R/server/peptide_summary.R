# =============================================================================
# PEPTIDE_SUMMARY.R
# Peptide Database Summary and Visualization Functions
# =============================================================================

#' Calculate Global Peptide Summary Statistics
#' 
#' @param peptide_data Tibble with peptide expression data
#' @param expression_threshold Numeric. Expression threshold for positive peptides (default: 3)
calculate_peptide_summary <- function(peptide_data, expression_threshold = 3) {
  
  # Convert to numeric matrix (excluding id column)
  numeric_data <- peptide_data %>%
    dplyr::select(where(is.numeric))
  
  # Global statistics
  global_mean <- mean(as.matrix(numeric_data), na.rm = TRUE)
  global_sd <- sd(as.matrix(numeric_data), na.rm = TRUE)
  
  global_stats <- list(
    n_samples = nrow(peptide_data),
    n_peptides = ncol(numeric_data),
    mean_expression = global_mean,
    median_expression = median(as.matrix(numeric_data), na.rm = TRUE),
    sd_expression = global_sd,
    min_expression = min(as.matrix(numeric_data), na.rm = TRUE),
    max_expression = max(as.matrix(numeric_data), na.rm = TRUE),
    expression_threshold = expression_threshold
  )
  
  # Use literal threshold (no z-score calculation)
  global_stats$positive_threshold <- expression_threshold
  
  # Per-sample statistics using literal threshold
  per_sample_stats <- numeric_data %>%
    dplyr::mutate(
      sample_id = peptide_data$id,
      n_positive_peptides = rowSums(. > expression_threshold, na.rm = TRUE),
      mean_expression = rowMeans(., na.rm = TRUE),
      median_expression = apply(., 1, median, na.rm = TRUE),
      sd_expression = apply(., 1, sd, na.rm = TRUE)
    ) %>%
    dplyr::select(sample_id, n_positive_peptides, mean_expression, 
                  median_expression, sd_expression)
  
  # Isotype analysis (IgE, IgG4, Other)
  peptide_cols <- colnames(numeric_data)
  
  # Calculate positive peptides per isotype using literal threshold
  ige_cols <- grepl("^IgE_", peptide_cols, ignore.case = TRUE)
  igg4_cols <- grepl("^IgG4_", peptide_cols, ignore.case = TRUE)
  other_cols <- !grepl("^(IgE_|IgG4_)", peptide_cols, ignore.case = TRUE)
  
  isotype_summary <- tibble(
    Isotype = c("IgE", "IgG4", "Other"),
    n_peptides = c(
      sum(ige_cols),
      sum(igg4_cols),
      sum(other_cols)
    ),
    n_positive_peptides = c(
      sum(as.matrix(numeric_data[, ige_cols]) > expression_threshold, na.rm = TRUE),
      sum(as.matrix(numeric_data[, igg4_cols]) > expression_threshold, na.rm = TRUE),
      sum(as.matrix(numeric_data[, other_cols]) > expression_threshold, na.rm = TRUE)
    ),
    mean_expression = c(
      mean(as.matrix(numeric_data[, ige_cols]), na.rm = TRUE),
      mean(as.matrix(numeric_data[, igg4_cols]), na.rm = TRUE),
      mean(as.matrix(numeric_data[, other_cols]), na.rm = TRUE)
    ),
    median_expression = c(
      median(as.matrix(numeric_data[, ige_cols]), na.rm = TRUE),
      median(as.matrix(numeric_data[, igg4_cols]), na.rm = TRUE),
      median(as.matrix(numeric_data[, other_cols]), na.rm = TRUE)
    )
  ) %>%
    dplyr::filter(n_peptides > 0)
  
  # Expression distribution (quantiles)
  expression_distribution <- tibble(
    Quantile = c("0%", "25%", "50%", "75%", "100%"),
    Value = quantile(as.matrix(numeric_data), 
                     probs = c(0, 0.25, 0.50, 0.75, 1.00), 
                     na.rm = TRUE)
  )
  
  # Return all summaries
  return(list(
    global = global_stats,
    per_sample = per_sample_stats,
    isotype_summary = isotype_summary,
    expression_distribution = expression_distribution
  ))
}


#' Create Interactive Donut Chart for Isotype Distribution
create_isotype_donut_chart <- function(isotype_summary, 
                                       colors = c("#191c32", "#667eea", "#00A087FF")) {
  
  # Calculate percentages and coordinates for donut chart
  isotype_summary <- isotype_summary %>%
    dplyr::mutate(
      positive_percentage = round(n_positive_peptides / sum(n_positive_peptides) * 100, 1),
      fraction = n_positive_peptides / sum(n_positive_peptides),
      ymax = cumsum(fraction),
      ymin = c(0, head(ymax, n = -1)),
      labelPosition = (ymax + ymin) / 2,
      label = paste0(positive_percentage, "%"),
      tooltip = paste0(
        "<b>", Isotype, "</b><br/>",
        "Positive Peptides: ", n_positive_peptides, "<br/>",
        "Total Peptides: ", n_peptides, "<br/>",
        "% Positive: ", round(n_positive_peptides / n_peptides * 100, 1), "%<br/>",
        "Mean Expr: ", round(mean_expression, 2)
      ),
      data_id = Isotype
    )
  
  # Create donut chart with ggiraph
  p <- ggplot(isotype_summary, aes(ymax = ymax, ymin = ymin, xmax = 4, xmin = 2.5,
                                    fill = Isotype, tooltip = tooltip, data_id = data_id)) +
    geom_rect_interactive(color = "white", linewidth = 1.5) +
    coord_polar(theta = "y") +
    xlim(c(0, 4)) +
    scale_fill_manual(values = colors[1:nrow(isotype_summary)]) +
    theme_void() +
    theme(
      legend.position = "bottom",
      legend.title = element_blank()
    )
  
  apply_girafe(p, width_svg = 4, height_svg = 4)
}


#' Create Summary Value Boxes (KPI Cards)
create_summary_value_boxes <- function(summary_stats) {
  
  global <- summary_stats$global
  per_sample <- summary_stats$per_sample
  
  # Create KPI tibble
  kpi_data <- tibble(
    Metric = c(
      "Total Samples",
      "Total Peptides",
      "Mean Expression",
      "Median Expression",
      "Avg Positive Peptides/Sample",
      "Expression Range"
    ),
    Value = c(
      as.character(global$n_samples),
      as.character(global$n_peptides),
      round(global$mean_expression, 2),
      round(global$median_expression, 2),
      round(mean(per_sample$n_positive_peptides, na.rm = TRUE), 1),
      paste0(round(global$min_expression, 1), " - ", round(global$max_expression, 1))
    ),
    Icon = c("fa-users", "fa-dna", "fa-chart-line", "fa-chart-area", "fa-plus-circle", "fa-arrows-alt-h")
  )
  
  return(kpi_data)
}


#' Create Styled Summary Table
create_styled_summary_table <- function(per_sample_stats, top_n = 10) {
  
  # Select top N samples by positive peptides
  top_samples <- per_sample_stats %>%
    dplyr::arrange(desc(n_positive_peptides)) %>%
    dplyr::slice_head(n = top_n) %>%
    dplyr::mutate(
      Sample = sample_id,
      `Positive Peptides` = as.integer(n_positive_peptides),
      `Mean Expression` = round(mean_expression, 2),
      `Median Expression` = round(median_expression, 2),
      `SD Expression` = round(sd_expression, 2)
    ) %>%
    dplyr::select(Sample, `Positive Peptides`, `Mean Expression`, `Median Expression`, `SD Expression`)
  
  return(top_samples)
}


#' Sample Heatmap Data (Limit to 300 Features)
sample_heatmap_features <- function(matrix_data, max_features = 300, seed = 123) {
  
  n_features <- ncol(matrix_data)
  
  if (n_features <= max_features) {
    return(matrix_data)
  }
  
  # Set seed for reproducibility
  set.seed(seed)
  
  # Random sample of column indices
  sampled_indices <- sort(sample(1:n_features, max_features, replace = FALSE))
  
  # Subset matrix
  sampled_matrix <- matrix_data[, sampled_indices, drop = FALSE]
  
  return(sampled_matrix)
}


#' Create Interactive Expression Distribution Plot
create_expression_distribution_plot <- function(peptide_data) {
  
  # Convert to long format and identify isotype
  expression_values <- peptide_data %>%
    dplyr::select(where(is.numeric)) %>%
    tidyr::pivot_longer(everything(), names_to = "peptide", values_to = "expression") %>%
    dplyr::filter(!is.na(expression)) %>%
    dplyr::mutate(
      Isotype = case_when(
        grepl("^IgE_", peptide, ignore.case = TRUE) ~ "IgE",
        grepl("^IgG4_", peptide, ignore.case = TRUE) ~ "IgG4",
        TRUE ~ "Other"
      ),
      tooltip = paste0(
        "<b>", Isotype, "</b><br/>",
        "Expression: ", round(expression, 2)
      ),
      data_id = paste0(Isotype, "_", row_number())
    )
  
  # Create histogram with ggiraph and facets
  p <- ggplot(expression_values, aes(x = expression, fill = Isotype)) +
    geom_histogram(alpha = 0.8, bins = 40) +
    facet_wrap(~Isotype, ncol = 1, scales = "free_y") +
    scale_fill_manual(values = c("IgE" = "#667eea", "IgG4" = "#00A087FF", "Other" = "#4DBBD5FF")) +
    labs(
      title = "Expression Distribution by Isotype",
      x = "Expression Value", 
      y = "Frequency"
    ) +
    theme_microarrai() +
    theme(
      legend.position = "none",
      strip.background = element_rect(fill = "#f4f6f9", color = "#191c32"),
      strip.text = element_text(face = "bold", size = 11)
    )
  
  apply_girafe(p, width_svg = 10, height_svg = 6)
}
