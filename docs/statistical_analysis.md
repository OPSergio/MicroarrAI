# Statistical Analysis Module

## Overview

This module provides functions for differential expression analysis with **automatic test selection** based on data characteristics. All statistical logic is **encapsulated** and **testable**.

## Core Function

### `perform_differential_analysis()`

**Purpose:** Complete pipeline for comparing peptide expression between clinical groups.

**Input:**
- `peptide_data` (tibble): id + peptide columns (output from data processing)
- `clinical_data` (tibble): id + clinical variables (age, treatment, outcome, etc.)
- `target_variable` (string): Column name for grouping (e.g., "Treatment", "Response")

**Output:**
Tibble with structure depending on number of groups:

**2 groups:**
| peptide | method | p.value | p.adj | fold_change |
|---------|--------|---------|-------|-------------|
| p001 | T-test | 0.0012 | 0.0456 | 2.34 |
| p045 | Wilcoxon | 0.0234 | 0.0891 | -1.56 |

**3+ groups:**
| peptide | method | p.value | p.adj | test_value |
|---------|--------|---------|-------|------------|
| p001 | ANOVA | 0.0012 | 0.0456 | 15.67 |
| p045 | Kruskal-Wallis | 0.0234 | 0.0891 | 8.23 |

**Process Flow:**
```
1. Remove near-zero variance peptides
   ↓
2. Merge peptide + clinical data
   ↓
3. Prepare target variable (factor)
   ↓
4. Reshape to long format
   ↓
5. Count groups → Route to appropriate analysis
   ↓
6. For each peptide:
   - Test normality (Shapiro-Wilk)
   - Select parametric vs non-parametric test
   - Calculate statistics
   - Apply multiple testing correction
   ↓
7. Return clean results table
```

**Automatic Test Selection:**

```r
# Example data
peptide_data <- tibble(
  id = paste0("P", 1:50),
  p001 = rnorm(50, 100, 20),
  p002 = rnorm(50, 150, 30),
  # ... 178 more peptides
)

clinical_data <- tibble(
  id = paste0("P", 1:50),
  Treatment = sample(c("Control", "Drug"), 50, replace=TRUE),
  Age = sample(30:70, 50, replace=TRUE)
)

# Run analysis
results <- perform_differential_analysis(
  peptide_data, 
  clinical_data, 
  "Treatment"
)

# Results automatically use t-test/Wilcoxon (2 groups)
# If Treatment had 3 levels → ANOVA/Kruskal-Wallis
```

---

## Supporting Functions

### 1. `perform_twogroup_analysis()`

**Purpose:** Handle pairwise comparisons (t-test or Wilcoxon).

**Input:**
- `df_long` (tibble): Long format with columns: target, pep, Expression
- `target_levels` (factor): For fold change direction

**Output:**
Tibble with columns: peptide, method, p.value, p.adj, fold_change

**Statistical Details:**

#### Normality Testing
For each peptide:
```r
shapiro.test(Expression)$p.value
```
- **p > 0.05**: Assume normal → **t-test**
- **p ≤ 0.05**: Non-normal → **Wilcoxon rank-sum**

#### Fold Change Calculation
```r
log2(mean(Group2) / mean(Group1))
```
- **Positive**: Upregulated in Group 2
- **Negative**: Downregulated in Group 2
- **Magnitude**: |FC| > 1 means >2-fold change

#### Multiple Testing Correction
**Benjamini-Hochberg** (FDR control):
- Less conservative than Bonferroni
- Controls false discovery rate
- Appropriate when looking for biomarkers (exploratory)

**Example:**
```r
# Direct usage (called internally)
df_long <- tibble(
  target = factor(rep(c("Control", "Treatment"), each=100)),
  pep = rep(paste0("p", 1:20), 10),
  Expression = rnorm(200, 100, 20)
)

results <- perform_twogroup_analysis(df_long, levels(df_long$target))
```

---

### 2. `perform_multigroup_analysis()`

**Purpose:** Handle 3+ group comparisons (ANOVA or Kruskal-Wallis).

**Input:**
- `df_long` (tibble): Long format with columns: target, pep, Expression

**Output:**
Tibble with columns: peptide, method, p.value, p.adj, test_value

**Statistical Details:**

#### Test Selection
Same normality testing as 2-group, but:
- **Normal**: `aov(Expression ~ target)` → F-statistic
- **Non-normal**: `kruskal.test(Expression ~ target)` → H-statistic

#### Test Statistics Interpretation
**ANOVA F-value:**
```
F = Between-group variance / Within-group variance
```
- Higher F → stronger group separation
- Requires normality + homoscedasticity assumptions

**Kruskal-Wallis H-value:**
```
H = chi-squared approximation of rank sums
```
- Distribution-free
- Robust to outliers
- Lower power than ANOVA when assumptions met

#### Multiple Testing Correction
**Bonferroni:**
```r
p.adj = p.value * n_tests
```
- Very conservative (controls family-wise error rate)
- Appropriate for confirmatory analysis
- Reduces false positives aggressively

**Example:**
```r
df_long <- tibble(
  target = factor(rep(c("Control", "Low", "High"), each=100)),
  pep = rep(paste0("p", 1:30), 10),
  Expression = rnorm(300, 100, 20)
)

results <- perform_multigroup_analysis(df_long)
```

---

### 3. `generate_volcano_data()`

**Purpose:** Prepare data for volcano plot visualization.

**Input:**
- `stats_results` (tibble): Output from 2-group analysis
- `pval_threshold` (numeric, default=0.05): Adjusted p-value cutoff
- `fc_threshold` (numeric, default=1): Log2 fold change cutoff

**Output:**
Tibble with columns: peptide, fold_change, neg_log_pval, significance

**Significance Classification:**
```
significance = 
  if p.adj < 0.05 AND fold_change > 1: "Up"
  if p.adj < 0.05 AND fold_change < -1: "Down"
  else: "NS" (not significant)
```

**Visualization Formula:**
```
x-axis: fold_change (log2 scale)
y-axis: -log10(p.adj) (emphasizes small p-values)

Horizontal line: -log10(pval_threshold)
Vertical lines: ±fc_threshold
```

**Example:**
```r
# After running 2-group analysis
volcano_data <- generate_volcano_data(
  stats_results, 
  pval_threshold = 0.01,  # Stricter significance
  fc_threshold = 1.5      # Require >2.8-fold change
)

# Volcano plot
ggplot(volcano_data, aes(x = fold_change, y = neg_log_pval, color = significance)) +
  geom_point() +
  geom_hline(yintercept = -log10(0.01), linetype = "dashed") +
  geom_vline(xintercept = c(-1.5, 1.5), linetype = "dashed") +
  scale_color_manual(values = c("Up" = "red", "Down" = "blue", "NS" = "gray"))
```

---

### 4. `filter_biomarkers()`

**Purpose:** Extract statistically significant peptides.

**Input:**
- `stats_results` (tibble): From perform_differential_analysis()
- `pval_raw_threshold` (numeric, default=0.05): Raw p-value cutoff
- `pval_adj_threshold` (numeric, default=0.05): Adjusted p-value cutoff

**Output:**
Filtered tibble with only significant peptides

**Filtering Logic:**
```
Step 1: p.value < 0.05 (nominal significance)
Step 2: p.adj < 0.05 (corrected significance)

Both conditions must be TRUE
```

**Use Cases:**
1. **Feature selection for ML**: Use significant peptides as predictors
2. **Heatmap visualization**: Show only differential peptides
3. **Biomarker discovery**: Prioritize candidates for validation

**Example:**
```r
# Strict filtering
strict_markers <- filter_biomarkers(
  stats_results,
  pval_raw_threshold = 0.01,
  pval_adj_threshold = 0.01
)

# Relaxed filtering
relaxed_markers <- filter_biomarkers(
  stats_results,
  pval_raw_threshold = 0.05,
  pval_adj_threshold = 0.1
)
```

---

### 5. `rank_peptides_by_criteria()`

**Purpose:** Score and rank peptides combining multiple metrics.

**Input:**
- `stats_results` (tibble): Statistical analysis results
- `weights` (named list): Relative importance of metrics

**Output:**
Tibble with additional columns: score, rank

**Scoring Formula:**

**For 2-group comparisons:**
```r
score = w1 * (1 - p.value) +      # Statistical significance
        w2 * (1 - p.adj) +         # Corrected significance
        w3 * abs(fold_change)      # Effect size
```

**For 3+ group comparisons:**
```r
score = w1 * (1 - p.value) + 
        w2 * (1 - p.adj) + 
        w3 * (test_value / max(test_value))  # Normalized statistic
```

**Default Weights:**
Equal importance (1/3 each)

**Custom Weighting Examples:**
```r
# Emphasize statistical significance
rank_peptides_by_criteria(
  stats_results,
  weights = list(p_value = 0.2, p_adj = 0.5, effect_size = 0.3)
)

# Emphasize effect size (biological relevance)
rank_peptides_by_criteria(
  stats_results,
  weights = list(p_value = 0.2, p_adj = 0.2, effect_size = 0.6)
)

# Balanced approach
rank_peptides_by_criteria(
  stats_results,
  weights = list(p_value = 1/3, p_adj = 1/3, effect_size = 1/3)
)
```

**Use Cases:**
- **Top-N selection**: `filter(rank <= 10)`
- **Prioritization**: Order biomarkers for validation
- **Visualization**: Color code by score/rank

---

## Usage in Server

### Before (Monolithic):
```r
tests <- eventReactive(input$run_analysis_1, {
  # 120+ lines of nested statistical logic
  # Mixed data prep + statistics + formatting
})
```

### After (Modular):
```r
tests <- eventReactive(input$run_analysis_1, {
  req(pepdata(), database())
  
  perform_differential_analysis(
    peptide_data = pepdata(),
    clinical_data = database(),
    target_variable = input$stats
  )
})

# Filtering also simplified
tests_filtered <- reactive({
  req(tests())
  filter_biomarkers(tests(), pval_adj_threshold = input$pval_threshold)
})

# Volcano plot data
volcano_data <- reactive({
  req(tests())
  generate_volcano_data(tests(), pval_threshold = 0.05, fc_threshold = 1)
})
```

**Benefits:**
- ✅ Server code reduced from 120 to 10 lines
- ✅ Statistical logic testable in isolation
- ✅ Easy to add new test types
- ✅ Consistent results across UI interactions

---

## Testing Strategy

```r
# Unit tests
test_that("Two-group analysis returns fold change", {
  df_long <- tibble(
    target = factor(rep(c("A", "B"), each=50)),
    pep = rep(paste0("p", 1:10), 10),
    Expression = c(rnorm(50, 100, 10), rnorm(50, 150, 10))
  )
  
  results <- perform_twogroup_analysis(df_long, levels(df_long$target))
  
  expect_true("fold_change" %in% colnames(results))
  expect_equal(nrow(results), 10)
  expect_true(all(results$fold_change > 0))  # Group B higher
})

test_that("Multi-group analysis returns test_value", {
  df_long <- tibble(
    target = factor(rep(c("A", "B", "C"), each=50)),
    pep = rep(paste0("p", 1:10), 15),
    Expression = rnorm(150, 100, 20)
  )
  
  results <- perform_multigroup_analysis(df_long)
  
  expect_true("test_value" %in% colnames(results))
  expect_false("fold_change" %in% colnames(results))
})
```

---

## Dependencies

- **tidyverse**: Data manipulation
- **broom**: Tidy statistical outputs (tidy())
- **caret**: Near-zero variance detection
- **stats**: Base R statistical tests (t.test, aov, wilcox.test, kruskal.test, shapiro.test)

---

## Design Principles

1. **Automatic Test Selection**: No manual decision-making required
2. **Robust Statistics**: Normality testing before parametric tests
3. **Multiple Testing Correction**: Built-in FDR/Bonferroni
4. **Clean Outputs**: Consistent tibble structure
5. **Composability**: Functions chain naturally

---

## File Location

`R/server/statistical_analysis.R`

Sourced in `R/global.R` before server definition.
