# ============================================================================
# MicroarrAI - Data Processing Functions
# ============================================================================
# Description: Pure functions for microarray data loading and normalization
# Dependencies: tidyverse (normalization maths live in R/server/normalization.R)
# Documentation: docs/data_processing.md
# ============================================================================

#' Array file extensions the reader accepts
ARRAY_FILE_PATTERN <- "\\.(csv|txt|gpr)$"


#' Locate Header Row and Field Separator
#'
#' @param file_path Character. Full path to the array file
#' @return List with `skip` (rows to skip) and `sep` (field separator)
#' @details
#' ATF files (GenePix .gpr / .txt exports) declare their own header length on
#' line 2, so there is nothing to guess. Otherwise the header is the first row
#' containing an exact "ID" field, tried as comma- then tab-separated.
detect_array_header <- function(file_path) {
  lines <- readLines(file_path, n = 200, warn = FALSE, encoding = "latin1")

  if (length(lines) >= 2 && startsWith(lines[1], "ATF")) {
    declared <- suppressWarnings(as.integer(strsplit(lines[2], "\t")[[1]][1]))
    if (!is.na(declared)) {
      return(list(skip = declared + 2, sep = "\t"))
    }
  }

  for (sep in c(",", "\t")) {
    has_id <- vapply(lines, function(line) {
      "ID" %in% trimws(gsub('"', '', strsplit(line, sep, fixed = TRUE)[[1]]))
    }, logical(1))
    header_row <- which(has_id)[1]
    if (!is.na(header_row)) {
      return(list(skip = header_row - 1, sep = sep))
    }
  }

  stop("Could not locate the header row: no exact 'ID' column in the first 200 lines.")
}


#' Detect Signal/Background Column Pairs
#'
#' @param cols Character vector. Column names of the array file
#' @return Tibble with one row per channel: `channel`, `fg`, `bg`
#' @details
#' Handles both naming conventions seen in the wild: `Ch1.Median` +
#' `Ch1.B.Median` (ScanArray) and `F635 Median` + `B635 Median` (GenePix,
#' named by wavelength). The channel token is kept as the internal id so a
#' single-channel array works without special-casing.
detect_array_channels <- function(cols) {
  # ScanArray exports carry latin1 characters in some headers ("Ch2 Rgn R²"),
  # which break regex matching unless compared byte-wise.
  flat <- gsub("[ .]", "", cols, useBytes = TRUE)

  tokens <- c(
    sub("^Ch([0-9]+)Median$", "\\1", grep("^Ch[0-9]+Median$", flat, value = TRUE)),
    sub("^F([0-9]+)Median$", "\\1", grep("^F[0-9]+Median$", flat, value = TRUE))
  )
  tokens <- sort(unique(tokens))

  found <- lapply(tokens, function(n) {
    fg <- cols[flat %in% c(paste0("Ch", n, "Median"), paste0("F", n, "Median"))]
    bg <- cols[flat %in% c(paste0("Ch", n, "BMedian"), paste0("B", n, "Median"))]
    if (length(fg) == 0 || length(bg) == 0) return(NULL)
    tibble::tibble(channel = n, fg = fg[1], bg = bg[1])
  })

  channels <- dplyr::bind_rows(found)

  if (nrow(channels) == 0) {
    stop("No signal/background column pair found. Expected 'Ch1.Median' + 'Ch1.B.Median' ",
         "or 'F635 Median' + 'B635 Median'. Found: ",
         paste(utils::head(cols, 12), collapse = ", "))
  }

  channels
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
#' @param file_path Character. Full path to the array file (.csv, .txt, .gpr)
#' @param flag_threshold Integer. Maximum flag value to keep (default: 4)
#' @param spot_metric Character. "ratio" for log2(signal/background) or
#'   "difference" for background-corrected foreground
#' @return Tibble in long format: ID (cleaned), channel, Expression
#' @details
#' Works with any number of channels. The returned `channel` column holds the
#' token detected in the file ("1", "2", "635"), which the batch step maps to
#' a user-facing label.
#' @examples
#' df <- read_microarray_file("sample001.csv")
read_microarray_file <- function(file_path,
                                 flag_threshold = 4,
                                 spot_metric = c("ratio", "difference"),
                                 with_quality = FALSE) {

  spot_metric <- match.arg(spot_metric)
  header <- detect_array_header(file_path)

  df <- utils::read.delim(file_path, sep = header$sep, skip = header$skip,
                          check.names = FALSE, stringsAsFactors = FALSE,
                          fileEncoding = "latin1")

  channels <- detect_array_channels(names(df))

  if ("Flags" %in% names(df)) {
    df <- df[as.numeric(df$Flags) < flag_threshold, , drop = FALSE]
  }

  ids <- clean_analyte_ids(df[["ID"]])
  optional <- function(name) if (name %in% names(df)) suppressWarnings(as.numeric(df[[name]])) else NA_real_

  per_channel <- lapply(seq_len(nrow(channels)), function(i) {
    fg <- as.numeric(df[[channels$fg[i]]])
    bg <- as.numeric(df[[channels$bg[i]]])

    spot <- tibble::tibble(
      ID = ids,
      channel = channels$channel[i],
      Expression = if (spot_metric == "ratio") log2(fg / bg) else fg - bg
    )

    if (!with_quality) return(spot)

    # Quality columns the scanner already computes; richer than the flag alone
    # and what the QC tab needs to spot dust, gradients and saturation.
    snr_col <- grep(paste0("^(Ch)?", channels$channel[i], ".*(SignalNoiseRatio|SNR)"),
                    names(df), value = TRUE)
    sat_col <- grep(paste0("^(Ch)?", channels$channel[i], ".*Sat"),
                    names(df), value = TRUE)

    dplyr::mutate(spot,
      signal    = fg,
      background = bg,
      x         = optional("X"),
      y         = optional("Y"),
      flag      = optional("Flags"),
      footprint = optional("Footprint"),
      snr       = if (length(snr_col)) suppressWarnings(as.numeric(df[[snr_col[1]]])) else NA_real_,
      saturation = if (length(sat_col)) suppressWarnings(as.numeric(df[[sat_col[1]]])) else NA_real_
    )
  })

  dplyr::bind_rows(per_channel)
}


#' Map Detected Channels to User-Facing Labels
#'
#' @param channels Character vector. Channel tokens found in the file
#' @param labels List or named vector. User labels, named either by token
#'   ("1", "635") or with the legacy `ch1`/`ch2` form
#' @return Named character vector: token -> label
resolve_channel_labels <- function(channels, labels = NULL) {
  resolved <- stats::setNames(paste0("Ch", channels), channels)

  if (is.null(labels) || length(labels) == 0) {
    return(resolved)
  }

  labels <- unlist(labels)
  labels <- labels[nzchar(labels)]
  names(labels) <- sub("^ch", "", names(labels), ignore.case = TRUE)

  shared <- intersect(names(labels), channels)
  resolved[shared] <- labels[shared]
  resolved
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
#' @param channel_labels List/named vector. Labels per detected channel; NULL uses Ch<token>
#' @param channels Character vector. Channel tokens to keep ("1", "2", "635");
#'   NULL keeps every channel found in the files
#' @param spot_metric Character. "ratio" (log2 signal/background) or "difference"
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
                                     channel_labels = NULL,
                                     channels = NULL,
                                     spot_metric = "ratio",
                                     return_qc = FALSE,
                                     progress_callback = NULL) {

  qc_spots <- vector("list", length(file_paths))

  # Process each file
  data_list <- lapply(seq_along(file_paths), function(i) {
    file <- file_paths[i]

    spots <- read_microarray_file(file, spot_metric = spot_metric,
                                  with_quality = return_qc)

    # Single-channel analysis: drop the other channel(s) before anything is
    # normalized or reported, so QC and features agree on what was analysed.
    if (!is.null(channels)) {
      spots <- dplyr::filter(spots, channel %in% channels)
      if (nrow(spots) == 0) {
        stop("None of the selected channels (", paste(channels, collapse = ", "),
             ") were found in ", basename(file))
      }
    }

    if (return_qc) {
      qc_spots[[i]] <<- dplyr::mutate(
        spots, sample = tools::file_path_sans_ext(basename(file))
      )
    }

    df <- spots %>%
      dplyr::group_by(channel) %>%
      dplyr::mutate(
        MExpression = normalize_channel(
          Expression, ID, normalization_method, negative_controls
        )
      ) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(Sample = tools::file_path_sans_ext(basename(file))) %>%
      dplyr::select(Sample, ID, channel, MExpression)

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
    dplyr::group_by(Sample, ID, channel) %>%
    dplyr::summarise(MExpression = mean(MExpression, na.rm = TRUE), .groups = "drop")

  labels <- resolve_channel_labels(sort(unique(data$channel)), channel_labels)

  wider_data <- data %>%
    dplyr::mutate(feature = paste0(labels[channel], "_", ID)) %>%
    dplyr::select(Sample, feature, MExpression) %>%
    tidyr::pivot_wider(names_from = feature, values_from = MExpression) %>%
    dplyr::rename(id = Sample) %>%
    dplyr::mutate(dplyr::across(where(is.numeric), ~round(.x, 2)))
  
  # Report NA count (imputed later in pepdata())
  na_count_total <- sum(is.na(wider_data))
  if (na_count_total > 0) {
    message(sprintf("Note: %d NA values from filtered flags will be imputed downstream", na_count_total))
  }

  if (!return_qc) {
    return(wider_data)
  }

  list(data = wider_data, qc = dplyr::bind_rows(qc_spots))
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


#' Read an Already-Processed Expression Matrix
#'
#' @param file_path Character. Path to .csv/.txt/.tsv/.xlsx
#' @param orientation Character. "samples_in_rows" (default) or "features_in_rows"
#' @return Tibble with `id` plus one numeric column per feature
#' @details
#' Public matrices ship in both orientations — the Dryad coronavirus chip puts
#' features in rows and samples in columns, the opposite of what the app
#' expects — so the caller declares which one it is rather than the reader
#' guessing. Field separator is taken from the header line.
read_processed_matrix <- function(file_path, orientation = "samples_in_rows") {

  ext <- tools::file_ext(file_path)

  df <- if (ext %in% c("xlsx", "xls")) {
    readxl::read_excel(file_path)
  } else {
    header <- readLines(file_path, n = 1, warn = FALSE)
    tabs <- lengths(regmatches(header, gregexpr("\t", header)))
    commas <- lengths(regmatches(header, gregexpr(",", header)))
    utils::read.delim(file_path, sep = if (tabs > commas) "\t" else ",",
                      check.names = FALSE, stringsAsFactors = FALSE)
  }

  if (identical(orientation, "features_in_rows")) {
    df <- transpose_expression_matrix(df)
  }

  df <- tibble::as_tibble(df)
  names(df)[1] <- "id"
  df
}


#' Flip a features-in-rows matrix into samples-in-rows
#'
#' @param df Data frame. First column holds feature names, remaining columns are samples
#' @return Tibble with sample ids in the first column
transpose_expression_matrix <- function(df) {
  features <- make.unique(as.character(df[[1]]))
  values <- t(as.matrix(df[, -1, drop = FALSE]))

  out <- tibble::as_tibble(values, .name_repair = "minimal")
  names(out) <- features

  dplyr::bind_cols(tibble::tibble(id = colnames(df)[-1]), out)
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
validate_processed_matrix <- function(file_path, orientation = "samples_in_rows") {
  tryCatch({
    ext <- tools::file_ext(file_path)

    if (!ext %in% c("csv", "txt", "tsv", "xlsx", "xls")) {
      return(list(valid = FALSE,
                  message = "Invalid file format. Use .csv, .txt, .tsv or .xlsx"))
    }

    df <- read_processed_matrix(file_path, orientation)

    numeric_cols <- vapply(df[, -1, drop = FALSE], is.numeric, logical(1))

    if (sum(numeric_cols) == 0) {
      return(list(valid = FALSE, message = paste0(
        "No numeric feature columns found. If the file has features in rows and ",
        "samples in columns, switch the orientation."
      )))
    }

    values <- as.matrix(df[, names(numeric_cols)[numeric_cols], drop = FALSE])
    saturated <- sum(values == 65535, na.rm = TRUE)

    message <- paste0("Valid matrix: ", nrow(df), " samples, ",
                      sum(numeric_cols), " features",
                      if (sum(!numeric_cols) > 0)
                        paste0(" (", sum(!numeric_cols), " non-numeric columns ignored)") else "")

    if (saturated > 0) {
      message <- paste0(message, "\nWarning: ", saturated,
                        " values sit exactly at 65535, the 16-bit scanner ceiling. ",
                        "Those readings are censored, not real intensities.")
    }

    list(valid = TRUE, message = message)

  }, error = function(e) {
    list(valid = FALSE, message = paste("Error reading file:", e$message))
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
