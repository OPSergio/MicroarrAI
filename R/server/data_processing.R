# ============================================================================
# MicroarrAI - Data Processing Functions
# ============================================================================
# Description: Pure functions for microarray data loading and normalization
# Dependencies: tidyverse, preprocessCore
# Documentation: docs/data_processing.md
# ============================================================================

#' Read and Process Single Microarray File
#' 
#' Reads a CSV file from GenePix scanner, filters by quality flags,
#' and calculates log2 expression ratios
#'
#' @param file_path Character. Full path to CSV file
#' @param skip_rows Integer. Number of rows to skip (default: 60)
#' @param flag_threshold Integer. Maximum flag value to keep (default: 4)
#' @return Tibble with columns: ID, Expression
#' @details 
#' - Selects columns 7, 14-20 from GenePix output
#' - Filters spots with Flags >= 4 (poor quality)
#' - Calculates Expression = log2(Ch1.Median / Ch1.B.Median)
#' @examples
#' df <- read_microarray_file("sample001.csv")
read_microarray_file <- function(file_path, skip_rows = 60, flag_threshold = 4) {
  df <- read.csv(file_path, skip = skip_rows, fileEncoding = 'latin1') %>%
    dplyr::select(c(7, 14:20)) %>%
    dplyr::filter(Flags < flag_threshold) %>%
    dplyr::mutate(
      Expression = log2(as.numeric(Ch1.Median) / as.numeric(Ch1.B.Median))
    ) %>%
    dplyr::select(ID, Expression)
  
  return(df)
}


#' Normalize Microarray Expression Data
#' 
#' Applies normalization method to expression values
#'
#' @param df Tibble with columns: ID, Expression
#' @param method Character. One of: "Z-score", "Quantile", "Median Scaling"
#' @return Tibble with additional column: MExpression (normalized expression)
#' @details
#' **Z-score normalization:**
#' - Uses PBS 1X as control
#' - MExpression = (Expression - median_PBS) / mad_PBS
#' - Robust to outliers (uses median + MAD instead of mean + SD)
#' 
#' **Quantile normalization:**
#' - Forces expression distribution to be identical across samples
#' - Uses preprocessCore::normalize.quantiles()
#' 
#' **Median Scaling:**
#' - MExpression = Expression / median(Expression)
#' - Simple centering around median
#' 
#' @examples
#' df_norm <- normalize_expression(df, method = "Z-score")
normalize_expression <- function(df, method = "Z-score") {
  if (method == "Z-score") {
    # Calculate PBS control statistics
    df_PBS <- df %>%
      dplyr::filter(ID == "PBS 1X") %>%
      dplyr::summarize(
        median_PBS = median(Expression),
        mad_PBS = mad(Expression)
      )
    
    # Apply Z-score normalization
    df <- df %>%
      dplyr::mutate(
        MExpression = (Expression - df_PBS$median_PBS) / df_PBS$mad_PBS
      )
    
  } else if (method == "Quantile") {
    # Quantile normalization
    df <- df %>%
      dplyr::mutate(
        MExpression = normalize.quantiles(as.matrix(df$Expression))
      )
    
  } else if (method == "Median Scaling") {
    # Median scaling
    median_expr <- median(df$Expression)
    df <- df %>%
      dplyr::mutate(MExpression = Expression / median_expr)
  } else {
    stop("Invalid normalization method. Use: 'Z-score', 'Quantile', or 'Median Scaling'")
  }
  
  return(df)
}


#' Process Multiple Microarray Files
#' 
#' Batch processes all CSV files in a directory with progress tracking
#'
#' @param file_paths Character vector. Paths to CSV files
#' @param normalization_method Character. Normalization method to apply
#' @param progress_callback Function. Optional callback for progress updates
#' @return Tibble in wide format: id (sample name) + peptide columns
#' @details
#' Processing pipeline:
#' 1. Read each file with read_microarray_file()
#' 2. Apply normalization with normalize_expression()
#' 3. Combine all samples
#' 4. Average technical replicates (same Sample + ID)
#' 5. Pivot to wide format (samples as rows, peptides as columns)
#' 6. Round to 2 decimals
#' 7. Select only peptide columns (starts_with "p")
#' 
#' @examples
#' files <- list.files("data/", pattern = "\\.csv$", full.names = TRUE)
#' data <- process_microarray_batch(files, "Z-score")
process_microarray_batch <- function(file_paths, 
                                     normalization_method = "Z-score",
                                     progress_callback = NULL) {
  
  # Process each file
  data_list <- lapply(seq_along(file_paths), function(i) {
    file <- file_paths[i]
    
    # Read and normalize
    df <- read_microarray_file(file)
    df <- normalize_expression(df, method = normalization_method)
    
    # Add sample identifier
    df <- df %>%
      dplyr::select(ID, MExpression) %>%
      dplyr::mutate(Sample = basename(file))
    
    # Update progress
    if (!is.null(progress_callback)) {
      progress_callback(i, length(file_paths), basename(file))
    }
    
    return(df)
  })
  
  # Combine all samples
  data <- dplyr::bind_rows(data_list)
  
  # Average technical replicates
  data <- data %>%
    dplyr::group_by(Sample, ID) %>%
    dplyr::summarise(MExpression = mean(MExpression), .groups = "drop")
  
  # Convert to wide format
  wider_data <- data %>%
    dplyr::mutate(MExpression = round(MExpression, 2)) %>%
    tidyr::pivot_wider(names_from = ID, values_from = MExpression) %>%
    dplyr::rename(id = Sample) %>%
    dplyr::select(id, starts_with("p"))
  
  return(wider_data)
}


#' Generate Synthetic Microarray Data
#' 
#' Creates example dataset for testing/demonstration
#'
#' @param num_patients Integer. Number of samples (default: 130)
#' @param num_peptides Integer. Number of peptide features (default: 180)
#' @param num_markers Integer. Number of differential peptides (default: 15)
#' @param database Tibble. Clinical database with 'Target' column for stratification
#' @return Tibble with id column + peptide columns (Peptide_1, Peptide_2, ...)
#' @details
#' - Generates random expression values (0-500)
#' - If database provided with 'Target' column, creates differential markers:
#'   - Treatment 1: low expression (mean=150, sd=35)
#'   - Treatment 2: medium expression (mean=200, sd=50)
#'   - Treatment 3: high expression (mean=300, sd=45)
#' 
#' @examples
#' synthetic_pep <- generate_synthetic_peptide_data(130, 180, 15, clinical_db)
generate_synthetic_peptide_data <- function(num_patients = 130, 
                                           num_peptides = 180,
                                           num_markers = 15,
                                           database = NULL) {
  
  # Initialize base data frame
  example_pep <- data.frame(
    id = paste0("Patient_", 1:num_patients)
  )
  
  # Add random peptide columns
  for (i in 1:num_peptides) {
    example_pep[[paste0("Peptide_", i)]] <- runif(num_patients, 0, 500)
  }
  
  # Add differential markers if database provided
  if (!is.null(database) && "Target" %in% colnames(database)) {
    marker_indices <- sample(2:(num_peptides + 1), num_markers)
    
    for (idx in marker_indices) {
      for (treatment in c("Tratamiento 1", "Tratamiento 2", "Tratamiento 3")) {
        mask <- database$Target == treatment
        
        if (sum(mask) > 0) {
          if (treatment == "Tratamiento 1") {
            example_pep[mask, idx] <- rnorm(sum(mask), mean = 150, sd = 35)
          } else if (treatment == "Tratamiento 2") {
            example_pep[mask, idx] <- rnorm(sum(mask), mean = 200, sd = 50)
          } else if (treatment == "Tratamiento 3") {
            example_pep[mask, idx] <- rnorm(sum(mask), mean = 300, sd = 45)
          }
        }
      }
    }
  }
  
  return(example_pep)
}


#' Prepare Matrix from Tibble
#' 
#' Converts tibble to numeric matrix for analysis
#'
#' @param data Tibble with id column + numeric feature columns
#' @param row_col Character. Name of column to use as row names (default: "id")
#' @return Numeric matrix with row names from row_col
#' @details
#' - Sets id column as row names
#' - Converts all columns to numeric
#' - Handles factor/character columns gracefully
#' - Returns clean numeric matrix ready for ML/stats
#' 
#' @examples
#' mat <- prepare_matrix(peptide_data, row_col = "id")
prepare_matrix <- function(data, row_col = "id") {
  mat <- data %>%
    tibble::column_to_rownames(row_col) %>%
    as.matrix()
  
  # Force numeric conversion
  mat[] <- lapply(as.data.frame(mat), function(x) {
    suppressWarnings(as.numeric(x))
  }) %>%
    as.data.frame() %>%
    as.matrix()
  
  return(mat)
}
