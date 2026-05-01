# ============================================================================
# MicroarrAI - Statistical Analysis Functions
# ============================================================================
# Description: Pure functions for differential expression analysis
# Dependencies: tidyverse, broom, caret
# Documentation: docs/statistical_analysis.md
# ============================================================================

#' Perform Differential Expression Analysis
#' 
#' Compares expression between groups using appropriate statistical tests
#'
#' @param peptide_data Tibble with id + peptide columns
#' @param clinical_data Tibble with id + clinical variables
#' @param target_variable String. Column name in clinical_data for grouping
#' @return Tibble with columns: peptide, method, p.value, p.adj, [test_value or fold_change]
#' @details
#' **Automatic test selection based on groups:**
#' - **2 groups**: t-test (parametric) or Wilcoxon (non-parametric) + fold change
#' - **3+ groups**: ANOVA (parametric) or Kruskal-Wallis (non-parametric)
#' 
#' **Normality testing:**
#' - Shapiro-Wilk test for each peptide
#' - p > 0.05 → parametric test
#' - p <= 0.05 → non-parametric test
#' 
#' **Multiple testing correction:**
#' - 2 groups: Benjamini-Hochberg (FDR)
#' - 3+ groups: Bonferroni (stricter)
#' 
#' @examples
#' results <- perform_differential_analysis(peptide_df, clinical_df, "Treatment")
perform_differential_analysis <- function(peptide_data, 
                                         clinical_data, 
                                         target_variable) {
  
  # Remove near-zero variance peptides
  peps <- peptide_data
  nzv <- caret::nearZeroVar(peps, saveMetrics = TRUE)
  peps <- peps[, !nzv$nzv]
  
  # Merge peptide + clinical data
  meta <- peps %>% inner_join(clinical_data, by = "id")
  
  # Prepare target variable
  df <- meta %>%
    rename(target = !!rlang::sym(target_variable)) %>%
    mutate(target = as.factor(target)) %>%
    dplyr::select(id, target)
  
  # Reshape to long format for grouped analysis
  df_long <- df %>%
    inner_join(meta %>% dplyr::select(1:ncol(peps)), by = "id") %>%
    dplyr::select(-id) %>%
    pivot_longer(names_to = "pep", values_to = "Expression", cols = -target)
  
  num_groups <- nlevels(df$target)
  
  if (num_groups > 2) {
    # Multi-group comparison (ANOVA/Kruskal-Wallis)
    results <- perform_multigroup_analysis(df_long)
  } else {
    # Two-group comparison (t-test/Wilcoxon + fold change)
    results <- perform_twogroup_analysis(df_long, df$target)
  }
  
  return(results)
}


#' Perform Two-Group Comparison
#' 
#' t-test or Wilcoxon + fold change calculation
#'
#' @param df_long Tibble in long format: target, pep, Expression
#' @param target_levels Factor levels for fold change direction
#' @return Tibble with columns: peptide, method, p.value, p.adj, fold_change
#' @details
#' **Fold change calculation:**
#' log2(mean_group2 / mean_group1)
#' - Positive: higher in group 2
#' - Negative: lower in group 2
#' 
#' **Multiple testing:**
#' Benjamini-Hochberg (FDR control)
perform_twogroup_analysis <- function(df_long, target_levels) {
  tests <- df_long %>%
    group_by(pep) %>%
    nest() %>%
    mutate(
      # Remove zero-variance peptides
      data = purrr::map(data, ~ .x %>% filter(var(Expression, na.rm = TRUE) != 0)),
      
      # Test normality
      norm = purrr::map(data, ~ {
        if (nrow(.x) > 0 && length(unique(.x$Expression)) > 1) {
          shapiro.test(.x$Expression)$p.value
        } else {
          NA_real_
        }
      })
    ) %>%
    unnest(norm) %>%
    mutate(
      # Choose test based on normality
      test_results = ifelse(
        norm > 0.05,
        purrr::map(data, ~ broom::tidy(t.test(.x$Expression ~ .x$target))),
        purrr::map(data, ~ broom::tidy(wilcox.test(.x$Expression ~ .x$target)))
      ),
      
      # Calculate fold change
      fold_change = purrr::map_dbl(data, ~ {
        log2(
          mean(.x$Expression[.x$target == levels(target_levels)[2]]) /
          mean(.x$Expression[.x$target == levels(target_levels)[1]])
        )
      })
    ) %>%
    unnest(test_results) %>%
    mutate(
      method = ifelse(norm > 0.05, "T-test (Fold change)", "Wilcoxon")
    ) %>%
    filter(!is.na(p.value)) %>%
    ungroup() %>%
    rename(peptide = pep) %>%
    mutate(
      p.adj = p.adjust(p.value, method = "BH", n = length(p.value)),
      p.value = round(p.value, 4),
      p.adj = round(p.adj, 4),
      fold_change = round(fold_change, 2)
    ) %>%
    dplyr::select(peptide, method, p.value, p.adj, fold_change)
  
  return(tests)
}


#' Perform Multi-Group Comparison
#' 
#' ANOVA or Kruskal-Wallis for 3+ groups
#'
#' @param df_long Tibble in long format: target, pep, Expression
#' @return Tibble with columns: peptide, method, p.value, p.adj, test_value
#' @details
#' **Test statistics:**
#' - ANOVA: F-value (ratio of between/within variance)
#' - Kruskal-Wallis: H-value (chi-squared approximation)
#' 
#' **Multiple testing:**
#' Bonferroni correction (conservative for many tests)
perform_multigroup_analysis <- function(df_long) {
  tests <- df_long %>%
    group_by(pep) %>%
    nest() %>%
    mutate(
      # Remove zero-variance peptides
      data = purrr::map(data, ~ .x %>% filter(var(Expression, na.rm = TRUE) != 0)),
      
      # Test normality
      norm = purrr::map(data, ~ {
        if (nrow(.x) > 0 && length(unique(.x$Expression)) > 1) {
          shapiro.test(.x$Expression)$p.value
        } else {
          NA_real_
        }
      })
    ) %>%
    unnest(norm) %>%
    mutate(
      # Choose test based on normality
      test_results = ifelse(
        norm > 0.05,
        purrr::map(data, ~ broom::tidy(aov(Expression ~ target, data = .x))),
        purrr::map(data, ~ broom::tidy(kruskal.test(Expression ~ target, data = .x)))
      )
    ) %>%
    unnest(test_results) %>%
    mutate(
      method = ifelse(norm > 0.05, "ANOVA (F-value)", "Kruskal-Wallis (H-value)"),
      test_value = statistic
    ) %>%
    filter(!is.na(p.value)) %>%
    ungroup() %>%
    rename(peptide = pep) %>%
    mutate(
      p.adj = p.adjust(p.value, method = "bonferroni", n = length(p.value)),
      p.value = round(p.value, 2),
      p.adj = round(p.adj, 2),
      test_value = round(test_value, 2)
    ) %>%
    dplyr::select(peptide, method, p.value, p.adj, test_value)
  
  return(tests)
}


#' Generate Volcano Plot Data
#' 
#' Prepare data structure for volcano visualization
#'
#' @param stats_results Tibble from perform_differential_analysis() (2-group)
#' @param pval_threshold Numeric. Adjusted p-value cutoff (default: 0.05)
#' @param fc_threshold Numeric. Absolute log2 fold change cutoff (default: 1)
#' @return Tibble with columns: peptide, fold_change, neg_log_pval, significance
#' @details
#' **Significance categories:**
#' - "Up": p.adj < threshold AND fold_change > fc_threshold
#' - "Down": p.adj < threshold AND fold_change < -fc_threshold
#' - "NS": Not significant
#' 
#' **neg_log_pval:**
#' -log10(p.adj) for y-axis scaling
#' 
#' @examples
#' volcano_data <- generate_volcano_data(stats_results, pval_threshold = 0.05, fc_threshold = 1)
generate_volcano_data <- function(stats_results, 
                                  pval_threshold = 0.05, 
                                  fc_threshold = 1) {
  
  # Ensure fold_change column exists (only in 2-group analysis)
  if (!"fold_change" %in% colnames(stats_results)) {
    stop("Volcano plot requires 2-group comparison with fold_change column")
  }
  
  volcano_tbl <- stats_results %>%
    mutate(
      neg_log_pval = -log10(p.adj),
      significance = case_when(
        p.adj < pval_threshold & fold_change > fc_threshold ~ "Up",
        p.adj < pval_threshold & fold_change < -fc_threshold ~ "Down",
        TRUE ~ "NS"
      )
    ) %>%
    dplyr::select(peptide, fold_change, neg_log_pval, significance, p.adj)
  
  return(volcano_tbl)
}


#' Filter Biomarkers by Statistical Criteria
#' 
#' Select peptides passing significance thresholds
#'
#' @param stats_results Tibble from perform_differential_analysis()
#' @param pval_raw_threshold Numeric. Raw p-value cutoff (default: 0.05)
#' @param pval_adj_threshold Numeric. Adjusted p-value cutoff (default: 0.05)
#' @return Tibble with significant peptides only
#' @details
#' **Filtering logic:**
#' 1. p.value < pval_raw_threshold (initial filter)
#' 2. p.adj < pval_adj_threshold (multiple testing correction)
#' 
#' **Use cases:**
#' - Biomarker selection
#' - Feature reduction for ML
#' - Visualization (e.g., heatmap of significant peptides)
#' 
#' @examples
#' biomarkers <- filter_biomarkers(stats_results, pval_raw_threshold = 0.05, pval_adj_threshold = 0.01)
filter_biomarkers <- function(stats_results, 
                              pval_raw_threshold = 0.05, 
                              pval_adj_threshold = 0.05) {
  
  filtered <- stats_results %>%
    filter(p.value < pval_raw_threshold) %>%
    filter(p.adj < pval_adj_threshold)
  
  return(filtered)
}


#' Rank Peptides by Multiple Criteria
#' 
#' Score and rank peptides combining statistical + effect size metrics
#'
#' @param stats_results Tibble from perform_differential_analysis()
#' @param weights Named list with weights: p_value, p_adj, effect_size (default: equal)
#' @return Tibble with additional columns: score, rank
#' @details
#' **Scoring formula (2-group):**
#' ```
#' score = w1 * (1 - p.value) + 
#'         w2 * (1 - p.adj) + 
#'         w3 * abs(fold_change)
#' ```
#' 
#' **Scoring formula (3+ groups):**
#' ```
#' score = w1 * (1 - p.value) + 
#'         w2 * (1 - p.adj) + 
#'         w3 * test_value
#' ```
#' 
#' Higher score = more promising biomarker
#' 
#' @examples
#' ranked <- rank_peptides_by_criteria(
#'   stats_results, 
#'   weights = list(p_value = 0.3, p_adj = 0.4, effect_size = 0.3)
#' )
rank_peptides_by_criteria <- function(stats_results, 
                                      weights = list(p_value = 1/3, p_adj = 1/3, effect_size = 1/3)) {
  
  # Determine if fold_change or test_value
  has_fc <- "fold_change" %in% colnames(stats_results)
  
  ranked <- stats_results %>%
    mutate(
      score = weights$p_value * (1 - p.value) + 
              weights$p_adj * (1 - p.adj) + 
              if (has_fc) {
                weights$effect_size * abs(fold_change)
              } else {
                weights$effect_size * test_value / max(test_value, na.rm = TRUE)
              },
      rank = rank(-score, ties.method = "first")
    ) %>%
    arrange(rank)
  
  return(ranked)
}


#' Perform Differential Expression Analysis with Linear Models
#' 
#' @description
#' Uses linear models (lm()) for differential expression analysis.
#' More robust than t-tests for complex designs and provides coefficients,
#' R-squared, and model diagnostics.
#'
#' @param peptide_data Tibble with id + peptide columns
#' @param clinical_data Tibble with id + clinical variables  
#' @param target_variable String. Column name in clinical_data for grouping
#' @param test_method Character. "lm" (default), "anova", or "kruskal" for fallback
#'
#' @return Tibble with columns: peptide, method, p.value, p.adj, coefficient, 
#'         r.squared, statistic, fold_change (for 2 groups)
#'
#' @details
#' **Linear Model approach:**
#' - Fits: Expression ~ Group for each peptide
#' - Extracts: p-value, coefficient, R², F-statistic
#' - More informative than simple t-tests
#' - Handles 2+ groups uniformly
#' 
#' **For 2 groups:**
#' - Also calculates log2 fold change
#' - Coefficient represents difference between groups
#' 
#' **For 3+ groups:**
#' - Overall F-test p-value
#' - Can perform post-hoc pairwise comparisons
#' 
#' **Multiple testing correction:**
#' - Benjamini-Hochberg (FDR)
#'
#' @examples
#' results <- perform_lm_differential_analysis(peptide_df, clinical_df, "Treatment")
#'
#' @export
perform_lm_differential_analysis <- function(peptide_data, 
                                             clinical_data, 
                                             target_variable,
                                             test_method = "lm") {
  
  # Validate target_variable
  if (is.null(target_variable) || length(target_variable) == 0 || target_variable == "") {
    stop("target_variable cannot be NULL or empty")
  }
  
  # Validate that target_variable exists in clinical_data
  if (!target_variable %in% names(clinical_data)) {
    stop(paste0("Column '", target_variable, "' not found in clinical data"))
  }
  
  # Remove near-zero variance peptides
  peps <- peptide_data
  nzv <- caret::nearZeroVar(peps, saveMetrics = TRUE)
  peps <- peps[, !nzv$nzv]
  
  # Merge peptide + clinical data
  meta <- peps %>% inner_join(clinical_data, by = "id")
  
  # Prepare target variable
  df <- meta %>%
    rename(target = !!rlang::sym(target_variable)) %>%
    mutate(target = as.factor(target)) %>%
    dplyr::select(id, target)
  
  # Reshape to long format
  df_long <- df %>%
    inner_join(meta %>% dplyr::select(1:ncol(peps)), by = "id") %>%
    dplyr::select(-id) %>%
    pivot_longer(names_to = "pep", values_to = "Expression", cols = -target)
  
  num_groups <- nlevels(df$target)
  
  # Choose analysis method based on test_method and number of groups
  if (test_method == "anova" || test_method == "kruskal") {
    # Use the original perform_differential_analysis logic for these methods
    # Prepare data structure
    df2 <- meta %>% dplyr::select(1:ncol(peps))
    df3 <- df %>% inner_join(df2, by = "id") %>% dplyr::select(-id) %>% 
      pivot_longer(names_to = "pep", values_to = "Expression", cols = -target)
    
    # Perform tests
    if (num_groups == 2) {
      method_name <- ifelse(test_method == "anova", "t-test", "Wilcoxon")
      df_result <- df3 %>%
        group_by(pep) %>%
        nest() %>%
        mutate(
          result = purrr::map(data, ~{
            if (test_method == "anova") {
              t.test(Expression ~ target, data = .x)
            } else {
              wilcox.test(Expression ~ target, data = .x)
            }
          }),
          p.value = purrr::map_dbl(result, "p.value")
        ) %>%
        ungroup() %>%
        mutate(
          p.adj = p.adjust(p.value, method = "BH"),
          method = method_name
        ) %>%
        dplyr::select(peptide = pep, method, p.value, p.adj)
      
    } else {
      # Multi-group ANOVA or Kruskal
      method_name <- ifelse(test_method == "anova", "ANOVA", "Kruskal-Wallis")
      df_result <- df3 %>%
        group_by(pep) %>%
        nest() %>%
        mutate(
          result = purrr::map(data, ~{
            if (test_method == "anova") {
              aov(Expression ~ target, data = .x)
            } else {
              kruskal.test(Expression ~ target, data = .x)
            }
          }),
          p.value = purrr::map_dbl(result, ~{
            summary_res <- summary(.x)
            if (test_method == "anova") {
              summary_res[[1]]$`Pr(>F)`[1]
            } else {
              .x$p.value
            }
          })
        ) %>%
        ungroup() %>%
        mutate(
          p.adj = p.adjust(p.value, method = "BH"),
          method = method_name
        ) %>%
        dplyr::select(peptide = pep, method, p.value, p.adj)
    }
    
    return(df_result)
  }
  
  # Linear model analysis (default)
  if (num_groups == 2) {
    # Two-group LM with fold change
    results <- perform_lm_twogroup(df_long, df$target)
  } else {
    # Multi-group LM (ANOVA-like)
    results <- perform_lm_multigroup(df_long)
  }
  
  return(results)
}


#' Perform Two-Group Linear Model Analysis
#' 
#' @param df_long Tibble in long format: target, pep, Expression
#' @param target_levels Factor levels
#' @return Tibble with LM results
#' @keywords internal
perform_lm_twogroup <- function(df_long, target_levels) {
  
  results <- df_long %>%
    group_by(pep) %>%
    nest() %>%
    mutate(
      # Fit linear model
      model = purrr::map(data, ~{
        if (nrow(.x) > 2 && length(unique(.x$Expression)) > 1) {
          tryCatch(
            lm(Expression ~ target, data = .x),
            error = function(e) NULL
          )
        } else {
          NULL
        }
      }),
      
      # Extract model summary
      summary = purrr::map(model, ~{
        if (!is.null(.x)) broom::tidy(.x) else NULL
      }),
      
      # Extract glance metrics
      glance = purrr::map(model, ~{
        if (!is.null(.x)) broom::glance(.x) else NULL
      }),
      
      # Calculate fold change
      fold_change = purrr::map_dbl(data, ~{
        if (nrow(.x) > 0) {
          means <- .x %>% group_by(target) %>% 
            summarise(m = mean(Expression, na.rm = TRUE), .groups = "drop")
          if (nrow(means) == 2) {
            log2(means$m[2] / means$m[1])
          } else {
            NA_real_
          }
        } else {
          NA_real_
        }
      })
    ) %>%
    unnest(summary) %>%
    filter(term != "(Intercept)") %>%  # Keep only group coefficient
    dplyr::select(peptide = pep, coefficient = estimate, std.error, 
                  statistic, p.value, fold_change) %>%
    left_join(
      df_long %>% group_by(pep) %>% 
        nest() %>% 
        mutate(
          glance = purrr::map(data, ~{
            model <- tryCatch(lm(Expression ~ target, data = .x), error = function(e) NULL)
            if (!is.null(model)) broom::glance(model) else NULL
          })
        ) %>%
        unnest(glance) %>%
        dplyr::select(pep, r.squared, adj.r.squared),
      by = c("peptide" = "pep")
    ) %>%
    mutate(
      method = "Linear Model (2 groups)",
      p.adj = p.adjust(p.value, method = "BH")
    ) %>%
    dplyr::select(peptide, method, p.value, p.adj, coefficient, fold_change, 
                  r.squared, statistic, std.error)
  
  return(results)
}


#' Perform Multi-Group Linear Model Analysis
#' 
#' @param df_long Tibble in long format: target, pep, Expression
#' @return Tibble with LM results
#' @keywords internal
perform_lm_multigroup <- function(df_long) {
  
  results <- df_long %>%
    group_by(pep) %>%
    nest() %>%
    mutate(
      # Fit linear model
      model = purrr::map(data, ~{
        if (nrow(.x) > 3 && length(unique(.x$Expression)) > 1) {
          tryCatch(
            lm(Expression ~ target, data = .x),
            error = function(e) NULL
          )
        } else {
          NULL
        }
      }),
      
      # Extract ANOVA F-test
      anova_result = purrr::map(model, ~{
        if (!is.null(.x)) {
          aov_summary <- anova(.x)
          tibble::tibble(
            f.statistic = aov_summary$`F value`[1],
            p.value = aov_summary$`Pr(>F)`[1]
          )
        } else {
          tibble::tibble(f.statistic = NA_real_, p.value = NA_real_)
        }
      }),
      
      # Extract R-squared
      r.squared = purrr::map_dbl(model, ~{
        if (!is.null(.x)) summary(.x)$r.squared else NA_real_
      })
    ) %>%
    tidyr::unnest(cols = anova_result)
  
  if (!"p.value" %in% colnames(results)) {
    return(tibble::tibble(
      peptide = character(),
      method = character(),
      p.value = numeric(),
      p.adj = numeric(),
      statistic = numeric(),
      r.squared = numeric()
    ))
  }
  
  results <- results %>%
    dplyr::filter(!is.na(p.value))
  
  if (nrow(results) == 0) {
    return(tibble::tibble(
      peptide = character(),
      method = character(),
      p.value = numeric(),
      p.adj = numeric(),
      statistic = numeric(),
      r.squared = numeric()
    ))
  }
  
  results <- results %>%
    mutate(
      method = "Linear Model (ANOVA)",
      p.adj = p.adjust(p.value, method = "BH")
    ) %>%
    dplyr::select(peptide = pep, method, p.value, p.adj, 
                  statistic = f.statistic, r.squared) %>%
    arrange(p.adj)
  
  return(results)
}

