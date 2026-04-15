# Data Processing Module

## Overview

This module provides pure functions for microarray data loading, normalization, and preparation. All functions are **stateless** and **testable** - they take inputs and return outputs without side effects.

## Functions

### 1. `read_microarray_file()`

**Purpose:** Read and preprocess a single GenePix CSV file.

**Input:**
- `file_path` (string): Full path to CSV file
- `skip_rows` (int, default=60): Rows to skip (GenePix header)
- `flag_threshold` (int, default=4): Maximum quality flag

**Output:**
Tibble with 2 columns:
- `ID`: Peptide/spot identifier
- `Expression`: log2(Channel1 / Background)

**Process:**
1. Read CSV skipping header rows
2. Select columns 7, 14-20 (GenePix specific)
3. Filter spots with Flags >= 4 (low quality)
4. Calculate log2 ratio: `log2(Ch1.Median / Ch1.B.Median)`

**Example:**
```r
df <- read_microarray_file("data/sample_001.csv")
# Output: tibble with ~1000 rows (peptides) x 2 columns
```

---

### 2. `normalize_expression()`

**Purpose:** Apply normalization to expression values.

**Input:**
- `df` (tibble): Output from `read_microarray_file()` with columns ID, Expression
- `method` (string): One of "Z-score", "Quantile", "Median Scaling"

**Output:**
Tibble with 3 columns:
- `ID`: Peptide identifier
- `Expression`: Original log2 values
- `MExpression`: Normalized expression

**Process by Method:**

#### Z-score (Default, Recommended)
Uses PBS 1X as internal control:
```
MExpression = (Expression - median_PBS) / mad_PBS
```
- **Robust**: Uses median + MAD instead of mean + SD
- **Assumption**: PBS spots represent background/noise
- **Result**: Values centered at 0, scaled by variability

#### Quantile
Forces identical distribution across all samples:
```
Uses preprocessCore::normalize.quantiles()
```
- **Use case**: When comparing many samples
- **Assumption**: Global expression distributions should be similar
- **Result**: Removes systematic differences

#### Median Scaling
Simple ratio to median:
```
MExpression = Expression / median(Expression)
```
- **Use case**: Quick normalization
- **Assumption**: Median represents typical expression
- **Result**: Values centered at 1

**Example:**
```r
df_norm <- normalize_expression(df, method = "Z-score")
```

---

### 3. `process_microarray_batch()`

**Purpose:** Process multiple files in batch with progress tracking.

**Input:**
- `file_paths` (character vector): Paths to all CSV files
- `normalization_method` (string): Normalization to apply
- `progress_callback` (function, optional): Callback for UI progress bar

**Output:**
Tibble in **wide format**:
- 1 row per sample
- Columns: `id` (sample name) + peptide columns (p001, p002, ...)

**Process Pipeline:**
```
For each file:
  1. read_microarray_file()     → Raw expression
  2. normalize_expression()      → Normalized expression
  3. Add Sample column          → Track file origin

Then:
  4. Combine all samples        → Long format
  5. Average replicates         → group_by(Sample, ID)
  6. Pivot to wide              → Samples as rows
  7. Round to 2 decimals        → Reduce precision noise
  8. Select peptide columns     → Remove non-peptide IDs
```

**Example:**
```r
files <- list.files("raw_data/", pattern = "\\.csv$", full.names = TRUE)

# With progress tracking (Shiny)
data <- process_microarray_batch(
  files, 
  "Z-score",
  progress_callback = function(i, total, name) {
    incProgress(1/total, detail = paste("Sample", name, "complete"))
  }
)

# Output: 
# 130 rows (samples) x 181 columns (id + 180 peptides)
```

---

### 4. `generate_synthetic_peptide_data()`

**Purpose:** Create realistic synthetic data for testing/demo.

**Input:**
- `num_patients` (int, default=130): Number of samples
- `num_peptides` (int, default=180): Number of features
- `num_markers` (int, default=15): Number of differential peptides
- `database` (tibble, optional): Clinical data with `Target` column

**Output:**
Tibble with structure matching real data:
- `id` column: Patient_1, Patient_2, ...
- Peptide columns: Peptide_1, Peptide_2, ...

**Process:**
```
1. Create base data frame with random values (0-500)

2. IF database with 'Target' column provided:
   - Select N random peptides as "biomarkers"
   - Stratify by treatment group:
     * Treatment 1: rnorm(mean=150, sd=35)  → LOW
     * Treatment 2: rnorm(mean=200, sd=50)  → MED
     * Treatment 3: rnorm(mean=300, sd=45)  → HIGH
   
   This creates realistic separation for testing ML models
```

**Example:**
```r
# Generate correlated with clinical outcomes
clinical_db <- data.frame(
  id = paste0("Patient_", 1:130),
  Target = sample(c("Tratamiento 1", "Tratamiento 2", "Tratamiento 3"), 130, replace=TRUE)
)

synthetic <- generate_synthetic_peptide_data(
  num_patients = 130,
  num_peptides = 180,
  num_markers = 15,
  database = clinical_db
)
```

---

### 5. `prepare_matrix()`

**Purpose:** Convert tibble to numeric matrix for ML/stats.

**Input:**
- `data` (tibble): Data with id column + numeric features
- `row_col` (string, default="id"): Column to use as row names

**Output:**
Numeric matrix with:
- Row names from `row_col`
- All values coerced to numeric
- NA for non-convertible values

**Process:**
```
1. Set id column as row names
2. Convert to matrix
3. Force numeric conversion (handles factors/characters)
4. Suppress conversion warnings
```

**Example:**
```r
# From tibble to matrix
mat <- prepare_matrix(peptide_data, row_col = "id")

# Now ready for:
# - PCA: prcomp(mat)
# - Heatmap: Heatmap(mat)
# - ML models: recipes use matrices
```

---

## Usage in Server

### Before (Monolithic):
```r
observeEvent(input$process_button, {
  # 80 lines of inline processing logic...
})
```

### After (Modular):
```r
observeEvent(input$process_button, {
  req(path1())
  
  files <- list.files(path = path1(), pattern = "\\.csv$", full.names = TRUE)
  
  withProgress(message = 'Processing files...', value = 0, {
    processed_data(
      process_microarray_batch(
        files, 
        input$normalization_method,
        progress_callback = function(i, total, name) {
          incProgress(1/total, detail = paste("Sample", name, "complete"))
        }
      )
    )
  })
})
```

**Benefits:**
- ✅ Server code reduced from 80 to 12 lines
- ✅ Business logic testable in isolation
- ✅ Functions reusable across multiple contexts
- ✅ Clear separation: UI orchestration vs data processing

---

## Testing Strategy

```r
# Unit tests (testthat)
test_that("normalize_expression handles Z-score correctly", {
  df <- data.frame(
    ID = c("PBS 1X", "PBS 1X", "p001", "p002"),
    Expression = c(5, 6, 10, 12)
  )
  
  result <- normalize_expression(df, "Z-score")
  
  expect_true("MExpression" %in% colnames(result))
  expect_equal(nrow(result), 4)
})
```

---

## Dependencies

- **tidyverse**: Data manipulation (dplyr, tidyr)
- **preprocessCore**: Quantile normalization
- **Base R**: read.csv, basename, lapply

---

## Design Principles

1. **Pure Functions**: No side effects, deterministic output
2. **Single Responsibility**: Each function does ONE thing
3. **Clear Contracts**: Documented inputs/outputs
4. **Error Handling**: Validate inputs, informative errors
5. **Composability**: Functions chain together naturally

---

## File Location

`R/server/data_processing.R`

Sourced in `R/global.R` before server definition.
