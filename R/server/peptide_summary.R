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
  
  # Isotype analysis: one row per isotype found in the column names, plus "Other"
  iso_of <- peptide_isotype(colnames(numeric_data))
  mat <- as.matrix(numeric_data)
  isotype_summary <- purrr::map_dfr(unique(iso_of), function(iso) {
    m <- mat[, iso_of == iso, drop = FALSE]
    tibble(
      Isotype = iso,
      n_samples = nrow(mat),
      n_peptides = ncol(m),
      # NOTE: counts positive (sample x peptide) observations, NOT peptide features
      n_positive_peptides = sum(m > expression_threshold, na.rm = TRUE),
      mean_expression = mean(m, na.rm = TRUE),
      median_expression = median(m, na.rm = TRUE)
    )
  }) %>%
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
create_isotype_donut_chart <- function(isotype_summary) {
  
  # Wedges are the share of positive calls (sample x peptide above threshold)
  d <- isotype_summary %>% dplyr::mutate(n_observations = n_peptides * n_samples)
  spec <- chart_donut(d$Isotype, d$n_positive_peptides, isotype_colors(d$Isotype), center_label = "positive calls")
  spec$slices$tip <- paste0(d$Isotype, "\nPositive calls: ", d$n_positive_peptides,
                            "\nPeptides: ", d$n_peptides, " x ", d$n_samples, " samples",
                            "\n% positive: ", round(100 * d$n_positive_peptides / d$n_observations, 1), " %",
                            "\nMean expression: ", round(d$mean_expression, 2))
  spec
}


#' Create Summary Value Boxes (KPI Cards)
#'
#' @param summary_stats List from calculate_peptide_summary().
#' @param na_stats Optional list from compute_na_stats() on the pre-imputation
#'   matrix. When provided, a "Peptides with NA" KPI is appended.
create_summary_value_boxes <- function(summary_stats, na_stats = NULL) {

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

  # Missing-value reporting lives in the Quality Control tab, which breaks it
  # down per array instead of giving a single global count. `na_stats` is kept
  # in the signature so existing callers do not break.
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
  num <- dplyr::select(peptide_data, where(is.numeric))
  iso <- peptide_isotype(names(num))
  panels <- lapply(split(names(num), factor(iso, levels = unique(iso))), function(cols) unlist(num[cols], use.names = FALSE))
  chart_histogram(panels, isotype_colors(names(panels)), xlab = "Expression value")
}
