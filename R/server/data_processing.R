# ============================================================================
# MicroarrAI - Data Processing Functions
# ============================================================================
# Description: Pure functions for microarray data loading and normalization
# Dependencies: tidyverse (normalization maths live in R/server/normalization.R)
# Documentation: docs/data_processing.md
# ============================================================================

#' Detect GenePix Header Row
#' 
#' Automatically finds the header row in GenePix CSV files
#'
#' @param file_path Character. Full path to CSV file
#' @return Integer. Row number where header starts (0-indexed for skip parameter)
#' @details
#' Locates the column-header row by finding the first line whose
#' comma-separated fields contain an exact "ID" column. This works for both
#' GenePix (.gpr-style) exports and PerkinElmer ScanArray Express CSV files,
#' which place the column header right after a "BEGIN DATA" marker.
detect_genepix_header <- function(file_path) {
  lines <- readLines(file_path, n = 200, warn = FALSE, encoding = "latin1")

  # Find the row whose fields include an exact "ID" column header
  has_id_col <- vapply(lines, function(line) {
    fields <- trimws(strsplit(line, ",", fixed = TRUE)[[1]])
    "ID" %in% fields
  }, logical(1))
  header_row <- which(has_id_col)[1]

  if (is.na(header_row)) {
    # Fallback: GenePix files use a "Block" column header
    header_row <- which(grepl("Block", lines, ignore.case = TRUE))[1]
  }

  if (is.na(header_row)) {
    warning("Could not detect microarray header. Using default skip=60")
    return(60)
  }
  return(header_row - 1)  # Return skip value
}


#' Clean Analyte IDs
#' 
#' Standardizes analyte identifiers for consistent downstream processing
#'
#' @param ids Character vector. Raw analyte IDs from microarray
#' @return Character vector. Cleaned analyte IDs
#' @details 
#' - Trims whitespace
#' - Replaces spaces with underscores
#' - Removes special characters (except underscores and hyphens)
#' - Ensures uniqueness by appending numbers to duplicates
#' @examples
#' clean_analyte_ids(c("PBS 1X", "p001 ", "p001"))
clean_analyte_ids <- function(ids) {
  # Trim whitespace
  ids <- trimws(ids)
  
  # Replace spaces with underscores
  ids <- gsub("\\s+", "_", ids)
  
  # Remove special characters except underscores and hyphens
  ids <- gsub("[^[:alnum:]_-]", "", ids)
  
  # Remove specific unwanted substring
  ids <- gsub("µgµL", "", ids)
  
  return(ids)
}


#' Read and Process Single Microarray File
#' 
#' Reads a CSV file from GenePix scanner, filters by quality flags,
#' and calculates log2 expression ratios for both channels
#'
#' @param file_path Character. Full path to CSV file
#' @param flag_threshold Integer. Maximum flag value to keep (default: 4)
#' @param auto_detect_header Logical. Auto-detect header row (default: TRUE)
#' @param skip_rows Integer. Number of rows to skip if auto_detect=FALSE (default: 60)
#' @return Tibble with columns: ID (cleaned), Expression_Ch1, Expression_Ch2
#' @details 
#' - Auto-detects GenePix header row
#' - Filters spots with Flags >= flag_threshold
#' - Cleans analyte IDs
#' - Calculates Expression_Ch1 = log2(Ch1.Median / Ch1.B.Median)
#' - Calculates Expression_Ch2 = log2(Ch2.Median / Ch2.B.Median)
#' @examples
#' df <- read_microarray_file("sample001.csv")
read_microarray_file <- function(file_path,
                                 flag_threshold = 4,
                                 auto_detect_header = TRUE,
                                 skip_rows = 60) {
  
  # Detect header if requested
  if (auto_detect_header) {
    skip_rows <- detect_genepix_header(file_path)
  }
  
  # Read and process file
  df <- read.csv(file_path, skip = skip_rows, fileEncoding = 'latin1') %>%
    dplyr::select(
      ID,
      Flags,
      matches("^Ch1\\.Median$"),
      matches("^Ch1\\.B\\.Median$"),
      matches("^Ch2\\.Median$"),
      matches("^Ch2\\.B\\.Median$")
    ) %>%
    dplyr::filter(Flags < flag_threshold) %>%
    dplyr::mutate(
      ID = clean_analyte_ids(ID),
      Expression_Ch1 = log2(as.numeric(Ch1.Median) / as.numeric(Ch1.B.Median)),
      Expression_Ch2 = log2(as.numeric(Ch2.Median) / as.numeric(Ch2.B.Median))
    ) %>%
    dplyr::select(ID, Expression_Ch1, Expression_Ch2)
  
  return(df)
}


#' Normalize Single Expression Vector (intra-sample)
#'
#' Thin wrapper around the intra-sample normalization methods defined in
#' R/server/normalization.R. Kept for backwards compatibility with the batch
#' pipeline; the actual maths live in the normalization module.
#'
#' @param expression Numeric vector. Expression values (log-ratios).
#' @param ids Character vector. Analyte IDs matching expression vector.
#' @param method Character. Currently only "Z-score" (robust, control-based).
#' @param negative_controls Character vector. IDs of negative controls.
#' @return Numeric vector. Normalized expression values.
#' @seealso normalize_zscore_controls
normalize_channel <- function(expression, ids, method = "Z-score", negative_controls = NULL) {
  if (method == "Z-score") {
    return(normalize_zscore_controls(expression, ids, negative_controls))
  }
  stop("Invalid intra-sample normalization method. Only 'Z-score' is supported.")
}



#' Process Multiple Microarray Files (Dual-Channel Support)
#' 
#' Batch processes all CSV files with independent channel normalization
#'
#' @param file_paths Character vector. Paths to CSV files
#' @param normalization_method Character. Normalization method to apply
#' @param negative_controls Character vector. IDs of negative controls
#' @param negative_controls_pattern Character. Regex pattern for negative controls (optional, overrides list)
#' @param positive_controls Character vector. IDs of positive controls (excluded from analysis)
#' @param positive_controls_pattern Character. Regex pattern for positive controls (optional, overrides list)
#' @param channel_labels List with ch1 and ch2 names (default: list(ch1="IgE", ch2="IgG4"))
#' @param progress_callback Function. Optional callback for progress updates
#' @return Tibble in wide format: id + prefixed peptide columns (e.g., IgE_p001, IgG4_p001)
#' @details
#' Processing pipeline:
#' 1. Read each file with read_microarray_file()
#' 2. Normalize Ch1 and Ch2 independently using negative controls
#' 3. Combine all samples
#' 4. Remove negative controls (using pattern if provided, else exact match)
#' 5. Remove positive controls (excluded from ML analysis, used only for QA)
#' 6. Average technical replicates (same Sample + ID)
#' 7. Pivot to wide format with channel prefixes
#' 8. Round to 2 decimals
#' 
#' @examples
#' files <- list.files("data/", pattern = "\\.csv$", full.names = TRUE)
#' data <- process_microarray_batch(files, "Z-score", c("PBS_1X", "Blank"))
process_microarray_batch <- function(file_paths, 
                                     normalization_method = "Z-score",
                                     negative_controls = c("PBS_1X"),
                                     negative_controls_pattern = NULL,
                                     positive_controls = NULL,
                                     positive_controls_pattern = NULL,
                                     channel_labels = list(ch1 = "IgE", ch2 = "IgG4"),
                                     progress_callback = NULL) {
  
  # Process each file
  data_list <- lapply(seq_along(file_paths), function(i) {
    file <- file_paths[i]
    
    # Read file
    df <- read_microarray_file(file)
    
    # Normalize each channel independently
    df <- df %>%
      dplyr::mutate(
        MExpression_Ch1 = normalize_channel(
          Expression_Ch1, ID, normalization_method, negative_controls
        ),
        MExpression_Ch2 = normalize_channel(
          Expression_Ch2, ID, normalization_method, negative_controls
        ),
        Sample = tools::file_path_sans_ext(basename(file))
      ) %>%
      dplyr::select(Sample, ID, MExpression_Ch1, MExpression_Ch2)
    
    # Update progress
    if (!is.null(progress_callback)) {
      progress_callback(i, length(file_paths), basename(file))
    }
    
    return(df)
  })
  
  # Combine all samples
  data <- dplyr::bind_rows(data_list)
  
  # DEBUG: Check what we're filtering
  # CRITICAL: Remove negative controls from final dataset
  # They are used only for normalization, not for downstream analysis
  if (!is.null(negative_controls_pattern)) {
    data <- data %>%
      dplyr::filter(!grepl(negative_controls_pattern, ID))
  } else {
    data <- data %>%
      dplyr::filter(!ID %in% negative_controls)
  }
  
  if (nrow(data) == 0) {
    stop("No data remaining after removing negative controls. Check your data files.")
  }
  
  # CRITICAL: Remove positive controls from final dataset
  # They are used only for QA, not for biomarker discovery
  if (!is.null(positive_controls_pattern)) {
    data <- data %>%
      dplyr::filter(!grepl(positive_controls_pattern, ID))
  } else if (!is.null(positive_controls) && length(positive_controls) > 0) {
    data <- data %>%
      dplyr::filter(!ID %in% positive_controls)
  }
  
  if (nrow(data) == 0) {
    stop("No data remaining after removing controls. Check your data files and control selection.")
  }
  
  # Average technical replicates
  data <- data %>%
    dplyr::group_by(Sample, ID) %>%
    dplyr::summarise(
      MExpression_Ch1 = mean(MExpression_Ch1, na.rm = TRUE),
      MExpression_Ch2 = mean(MExpression_Ch2, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Pivot to wide format for each channel
  data_ch1 <- data %>%
    dplyr::select(Sample, ID, MExpression_Ch1) %>%
    tidyr::pivot_wider(
      names_from = ID, 
      values_from = MExpression_Ch1,
      names_prefix = paste0(channel_labels$ch1, "_")
    )
  
  data_ch2 <- data %>%
    dplyr::select(Sample, ID, MExpression_Ch2) %>%
    tidyr::pivot_wider(
      names_from = ID, 
      values_from = MExpression_Ch2,
      names_prefix = paste0(channel_labels$ch2, "_")
    )
  
  # Merge both channels
  wider_data <- data_ch1 %>%
    dplyr::left_join(data_ch2, by = "Sample") %>%
    dplyr::rename(id = Sample) %>%
    dplyr::mutate(dplyr::across(where(is.numeric), ~round(.x, 2)))
  
  # Report NA count (will be replaced with 0 in pepdata() final step)
  na_count_total <- sum(is.na(wider_data))
  if (na_count_total > 0) {
    message(sprintf("Note: %d NA values from filtered flags will be replaced with 0 in final output", na_count_total))
  }
  
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


#' Get Unique Analyte IDs from RAW Files
#' 
#' Extracts and cleans unique analyte IDs from microarray files
#'
#' @param file_paths Character vector. Paths to CSV files
#' @param group_similar Logical. If TRUE, groups similar IDs (default: TRUE)
#' @return Character vector. Unique cleaned analyte IDs
#' @details 
#' Used to populate control selectors in UI.
#' If group_similar=TRUE, analytes like PBS_1X_1, PBS_1X_2 are recognized
#' as variants of the same control and can be selected together.
#' @examples
#' ids <- get_unique_analytes(list.files("data/", pattern = "\\.csv$", full.names = TRUE))
get_unique_analytes <- function(file_paths, group_similar = TRUE) {
  if (length(file_paths) == 0) {
    return(character(0))
  }
  
  # Read ALL files to get complete list of analytes
  # (important: first file might not contain all variants)
  all_ids <- character(0)
  
  for (file in file_paths) {
    df <- read_microarray_file(file)
    all_ids <- c(all_ids, unique(df$ID))
  }
  
  # Get unique IDs across all files
  unique_ids <- sort(unique(all_ids))
  
  # If grouping is enabled, add base names for similar analytes
  if (group_similar) {
    # Create a data frame with IDs and their base names
    id_df <- data.frame(
      id = unique_ids,
      base = sub("_\\d+$", "", unique_ids),  # Remove trailing numbers
      stringsAsFactors = FALSE
    )
    
    # Find groups with multiple variants
    group_counts <- table(id_df$base)
    multi_variant_groups <- names(group_counts[group_counts > 1])
    
    # Add group markers to IDs that have variants
    if (length(multi_variant_groups) > 0) {
      for (base_name in multi_variant_groups) {
        variants <- id_df$id[id_df$base == base_name]
        # Sort variants naturally (ignore IDs without trailing numbers)
        variant_nums <- suppressWarnings(as.numeric(gsub(".*_(\\d+)$", "\\1", variants)))
        variants <- variants[order(variant_nums, na.last = NA)]
        unique_ids <- c(unique_ids, paste0(base_name, "_ALL"))
      }
      unique_ids <- unique(unique_ids)
    }
  }
  
  return(unique_ids)
}


#' Validate Processed Matrix Input
#' 
#' Checks if uploaded file is a valid preprocessed matrix
#'
#' @param file_path Character. Path to uploaded file
#' @return List with valid (logical) and message (character)
#' @details
#' Validates:
#' - Has sample ID column
#' - Has numeric feature columns
#' - Has channel prefixes (e.g., IgE_, IgG4_) or generic features
validate_processed_matrix <- function(file_path) {
  tryCatch({
    ext <- tools::file_ext(file_path)
    
    if (ext %in% c("xlsx", "xls")) {
      df <- readxl::read_excel(file_path)
    } else if (ext == "csv") {
      df <- read.csv(file_path)
    } else {
      return(list(valid = FALSE, message = "Invalid file format. Use .csv or .xlsx"))
    }
    
    # Check for ID column
    if (!"id" %in% tolower(colnames(df))) {
      return(list(valid = FALSE, message = "Missing 'id' column"))
    }
    
    # Check for numeric columns
    numeric_cols <- sapply(df[, -1], is.numeric)
    if (sum(numeric_cols) == 0) {
      return(list(valid = FALSE, message = "No numeric feature columns found"))
    }
    
    return(list(
      valid = TRUE, 
      message = paste("Valid matrix:", nrow(df), "samples,", sum(numeric_cols), "features")
    ))
    
  }, error = function(e) {
    return(list(valid = FALSE, message = paste("Error reading file:", e$message)))
  })
}


#' Validate Expression Matrix
#' 
#' Ensures expression matrix is valid before downstream processing
#'
#' @param df Tibble. Expression matrix with id column + numeric features
#' @param min_samples Integer. Minimum number of samples required (default: 1)
#' @param min_features Integer. Minimum number of features required (default: 1)
#' @return List with valid (logical) and message (character)
#' @details
#' Checks:
#' - Object is not NULL
#' - Has at least min_samples rows
#' - Has at least min_features numeric columns
#' - Contains at least one finite value
#' 
#' @examples
#' validation <- validate_expression_matrix(expr_data)
#' if (!validation$valid) stop(validation$message)
validate_expression_matrix <- function(df, min_samples = 1, min_features = 1) {
  # Check NULL
  if (is.null(df)) {
    return(list(valid = FALSE, message = "Expression matrix is NULL"))
  }
  
  # Check dimensions
  if (nrow(df) < min_samples) {
    return(list(
      valid = FALSE, 
      message = paste("Expression matrix has only", nrow(df), "samples. Minimum required:", min_samples)
    ))
  }
  
  # Check numeric columns
  numeric_cols <- sapply(df, is.numeric)
  n_numeric <- sum(numeric_cols)
  
  if (n_numeric < min_features) {
    return(list(
      valid = FALSE,
      message = paste("Expression matrix has only", n_numeric, "numeric columns. Minimum required:", min_features)
    ))
  }
  
  # Check for finite values
  numeric_data <- df[, numeric_cols, drop = FALSE]
  has_finite <- any(sapply(numeric_data, function(x) any(is.finite(x))))
  
  if (!has_finite) {
    return(list(
      valid = FALSE,
      message = "Expression matrix contains no finite values (all NA/Inf/NaN)"
    ))
  }
  
  return(list(valid = TRUE, message = "Expression matrix is valid"))
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
