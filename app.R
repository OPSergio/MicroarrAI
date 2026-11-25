# ============================================================================
# MicroarrAI - Main Application Entry Point
# ============================================================================
# Description: Shiny application for peptide microarray analysis
# Author: Sergio Olmos Piñero, Val Fernández Lanza, et al.
# ============================================================================

# Load global configuration, libraries, and utility functions
source("R/global.R")


########################### UI ##############################################
ui <- fluidPage(
  # ===== Head: Metadata & External Resources =====
  tags$head(
    tags$title("MicroarrAI"),
    tags$link(rel = "icon", type = "image/svg+xml", href = "assets/favicon.svg"),
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(rel = "preconnect", href = "https://fonts.gstatic.com", crossorigin = NA),
    tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Cinzel:wght@400;500;600&family=Inter:wght@400;500;600;700&family=Space+Grotesk:wght@500;600;700&display=swap"
    )
  ),
  
  # ===== Shiny Extensions =====
  useShinyjs(),
  
  # ===== Bootstrap Theme =====
  theme = bs_theme(
    fg = "#191c32", 
    primary = "#191c32", 
    font_scale = NULL, 
    `enable-gradients` = TRUE, 
    `enable-shadows` = TRUE, 
    bg = "#ffffff"
  ),
  
  # ===== External Stylesheets & Scripts =====
  includeCSS("www/styles.css"),
  includeScript("www/custom.js"),
  
  # ===== Top Navbar (glass, METIS) =====
  ui_navbar(),

  # ===== Tab Navigation =====
  tabsetPanel(
    id = "main_tabs",
    ui_home(),
    ui_preprocess(),
    ui_peptide(),
    ui_ml(),
    ui_quality(),
    ui_protein_viz(),
    ui_documentation()
  
  )# Cierre del body
) # Cierre del UI


server <- function(input, output, session){

  # ===== Usage telemetry (read by the admin panel) =====
  telemetry_attach(input, session)

  # ===== Glass navbar -> tab switching =====
  observeEvent(input$nav_target, {
    updateTabsetPanel(session, "main_tabs", selected = input$nav_target)
  })

  ########################### INDEX ###########################################
  # RAW scans are uploaded by the user, never read from the server: a folder
  # browser would only expose the container's own filesystem, which holds no
  # user data. The pipeline still wants a directory of CSVs whose file names
  # are the sample IDs, so the upload is staged into a private per-session
  # directory (see R/utils/upload_staging.R) and that is what path1() returns.
  raw_upload_dir <- new_upload_dir()
  session$onSessionEnded(function() unlink(raw_upload_dir, recursive = TRUE))
  
  # Returns "" while nothing is uploaded, which every downstream req()/guard
  # already treats as "no data yet".
  # Either the user's upload or a built-in example (R/server/example_data.R)
  # (the staging dir never changes, so a counter is what signals new files)
  staged_dir <- reactiveVal("")
  staged_n <- reactiveVal(0)
  stage <- function(dir) { staged_dir(dir); staged_n(staged_n() + 1) }
  observeEvent(input$raw_files, {
    example_channels(NULL)
    f <- input$raw_files
    log_step("UPLOAD", "Scan files received", files = nrow(f), mb = round(sum(f$size) / 1024^2, 1),
             extensions = unique(tolower(tools::file_ext(f$name))))
    dir <- run_step("UPLOAD", "staging the scan files", stage_uploaded_files(f, raw_upload_dir),
                    hint = "Upload the files again; if it persists the server disk may be full.")
    if (!is.null(dir)) stage(dir)
  })
  path1 <- reactive({ staged_n(); staged_dir() })
  example_annotation <- reactiveVal(NULL)
  example_channels <- reactiveVal(NULL)
  
  # Reset the whole pipeline from scratch (fresh session clears every reactiveVal
  # and cached result) so the user never has to reload the browser manually.
  observeEvent(input$metis_reset, { session$reload() })

  raw_data <- reactiveVal(NULL
  )
  processed_data <- reactiveVal(NULL)
  database <- reactiveVal(NULL)
  database_edited <- reactiveVal(NULL)
  # Bumped to force the editable metadata table to re-render (load / replace /
  # revert / id-rename). Cell edits sync silently WITHOUT bumping this, so the
  # table never re-renders mid-edit (no cursor jumps, no reactive loop).
  metadata_render_trigger <- reactiveVal(0)
  pepdata <- reactiveVal(NULL)
  available_analytes <- reactiveVal(NULL)
  qc_spot_data <- reactiveVal(NULL)      # spot-level data feeding Quality Control
  norm_diagnostics <- reactiveVal(NULL)  # did normalization make arrays comparable?
  
  # Clinical columns the user chose to analyse (NULL = all of them)
  clinical_keep <- reactiveVal(NULL)

  # ===== ACTIVE DATABASE: edited version if any, restricted to the chosen columns =====
  active_database <- reactive({
    df <- if (!is.null(database_edited()) && nrow(database_edited()) > 0) database_edited() else database()
    if (is.null(df) || is.null(clinical_keep())) return(df)
    df[, intersect(names(df), c("id", clinical_keep())), drop = FALSE]
  })
  
  # ===== UI Output: Input Mode Info =====
  output$input_mode_info <- renderUI({
    if (input$input_mode == "raw") {
      tags$div(
        style = "background: #d4edda; padding: 15px; border-radius: 8px; border-left: 4px solid #28a745;",
        tags$h6(icon("check-circle"), " RAW Mode Selected", style = "color: #155724; margin-bottom: 10px;"),
        tags$p("You will process scanner files (.gpr, .csv, .txt) with full normalization control.", 
              style = "color: #155724; margin: 0;")
      )
    } else {
      tags$div(
        style = "background: #cce5ff; padding: 15px; border-radius: 8px; border-left: 4px solid #007bff;",
        tags$h6(icon("upload"), " Processed Matrix Mode", style = "color: #004085; margin-bottom: 10px;"),
        tags$p("You will upload pre-normalized data. Normalization steps will be skipped.", 
              style = "color: #004085; margin: 0;")
      )
    }
  })
  
  # ===== UI Output: Step 2 Instructions =====
  output$step2_instructions <- renderUI({
    if (input$input_mode == "raw") {
      tagList(
        tags$h5(icon("info-circle"), " Load your scanner files", style = "color: #191c32; margin-bottom: 10px;"),
        tags$p("One file per array, as the scanner exported it: GenePix / Mapix / InnoScan .gpr, or ScanArray and other .csv / .txt / .tsv exports.", style = "color: #191c32;"),
        tags$p(tags$b("What happens next:"), style = "color: #191c32;"),
        tags$ul(
          style = "color: #191c32;",
          tags$li("The file header, separator and channels are detected automatically"),
          tags$li("Analyte IDs will be extracted and cleaned"),
          tags$li("Control selectors will be populated")
        )
      )
    } else {
      tagList(
        tags$h5(icon("info-circle"), " Upload Processed Matrix", style = "color: #191c32; margin-bottom: 10px;"),
        tags$p("Upload your pre-normalized expression matrix (.csv or .xlsx).", style = "color: #191c32;"),
        tags$p(tags$b("Required format:"), style = "color: #191c32;"),
        tags$ul(
          style = "color: #191c32;",
          tags$li("First column: 'id' with sample identifiers"),
          tags$li("Other columns: numeric expression values"),
          tags$li("Optional: Use channel prefixes (e.g., IgE_p001)")
        )
      )
    }
  })
  
  # ===== UI Output: Folder Status =====
  output$folder_status <- renderUI({
    if (is.null(path1()) || length(path1()) == 0 || path1() == "") {
      tags$div(
        style = "margin-top: 15px;",
        tags$p(icon("folder"), " No files uploaded yet",
              style = "color: #6c757d; font-style: italic;")
      )
    } else {
      files <- list_array_files(path1())
      tags$div(
        style = "margin-top: 15px; background: #d4edda; padding: 15px; border-radius: 8px; border-left: 4px solid #28a745;",
        tags$h6(icon("check-circle"), " Files Uploaded Successfully!",
               style = "color: #155724; margin-bottom: 10px;"),
        tags$p(tags$b("Scan files read:"), length(files), style = "color: #155724; margin: 5px 0;"),
        tags$p(tags$b("Analytes detected:"), 
              if (!is.null(available_analytes())) length(available_analytes()) else "Processing...",
              style = "color: #155724; margin: 5px 0;")
      )
    }
  })
  
  # ===== UI Output: Normalization Method Description =====
output$normalization_method_description <- renderUI({
  if (input$normalization_method == "Z-score") {
    tagList(
      tags$p(tags$b("Z-score Normalization:"), style = "color: #191c32; margin-bottom: 5px;"),
      tags$ul(
        style = "color: #191c32; font-size: 13px;",
        tags$li("Uses median and MAD of negative controls"),
        tags$li("Robust to outliers"),
        tags$li("Formula: (value - median) / MAD"),
        tags$li("Recommended for most cases")
      )
    )
  } else {
    tagList(
      tags$p(tags$b("Median Scaling:"), style = "color: #191c32; margin-bottom: 5px;"),
      tags$ul(
        style = "color: #191c32; font-size: 13px;",
        tags$li("Divides by median expression"),
        tags$li("Simple centering method"),
        tags$li("Formula: value / median(all values)"),
        tags$li("Less robust than Z-score")
      )
    )
  }
  })
  
  # ===== Channels present in the loaded folder =====
  # The first file's columns name the channels; its values tell which ones
  # actually carry signal (a laser at gain 0 still exports its columns)
  first_array <- reactive({
    req(input$input_mode == "raw", path1())
    files <- list_array_files(path1())
    req(length(files) > 0)

    read_array_table(files[1])
  })
  detected_channels <- reactive(detect_array_channels(names(first_array()))$channel)
  silent_channels <- reactive(silent_array_channels(first_array()))

  channel_labels <- reactive({
    channels <- detected_channels()
    stats::setNames(
      vapply(channels, function(ch) {
        value <- input[[paste0("ch_label_", ch)]]
        if (is.null(value) || !nzchar(value)) paste0("Ch", ch) else value
      }, character(1)),
      channels
    )
  })

  # The checkbox group only exists for multi-channel files; a single-channel
  # scan is always analysed as-is.
  selected_channels <- reactive({
    channels <- detected_channels()
    if (length(channels) <= 1) return(channels)
    intersect(input$use_channels, channels)
  })

  output$channel_labels_ui <- renderUI({
    channels <- detected_channels()
    silent <- intersect(silent_channels(), channels)
    if (length(silent) == length(channels)) silent <- character(0)  # nothing to choose
    labels <- if (!is.null(example_channels())) example_channels() else default_channel_labels(channels)

    tagList(
      tags$p(sprintf("%d channel%s detected in these files.",
                     length(channels), if (length(channels) == 1) "" else "s"),
             style = "color: #6c757d; font-size: 13px; margin-bottom: 12px;"),
      # Which channels become features. Untick one to analyse a single channel
      # (e.g. only the IgE scan of a two-channel array).
      if (length(channels) > 1) checkboxGroupInput(
        "use_channels", dark_label("Channels to analyse:"),
        choices = stats::setNames(channels, paste0("Channel ", channels)),
        selected = setdiff(channels, silent), inline = TRUE
      ),
      if (length(silent) > 0) tags$p(
        sprintf("Channel %s has no signal in these files (scanned at gain 0?) and starts unticked.",
                paste(silent, collapse = ", ")),
        style = "color: #8a6d3b; font-size: 13px; margin: -6px 0 12px;"
      ),
      lapply(seq_along(channels), function(i) {
        textInput(
          paste0("ch_label_", channels[i]),
          dark_label(tagList(tags$span(class = "channel-dot", style = paste0("background:", channel_color(channels, i))),
                             paste0("Channel ", channels[i], ":"))),
          value = labels[i]
        )
      })
    )
  })

  # ===== Analyte ID extraction from RAW files =====
  observeEvent(path1(), {
    req(input$input_mode == "raw")
    req(path1())

    files <- list_array_files(path1())
    if (length(files) > 0) {
      # Show processing notification
      showNotification("Extracting analyte IDs from files...", type = "message", duration = 2)
      
      analytes <- run_step("UPLOAD", sprintf("reading spot names from %d files", length(files)),
        get_unique_analytes(files),
        hint = "Every file must be a scanner export with an ID (or Name) column; remove files that are not.",
        done = function(a) list(analytes = length(a), peptides = sum(grepl("(^|_)p[ _.-]?\\d+_", a)),
                                other_spots = utils::head(a[!grepl("(^|_)p[ _.-]?\\d+_", a)], 12)))
      if (is.null(analytes)) return()
      available_analytes(analytes)
      ch <- tryCatch(detected_channels(), error = function(e) character(0))
      log_step("UPLOAD", "Channels detected", channels = ch,
               silent = tryCatch(silent_array_channels(first_array()), error = function(e) NULL),
               default_labels = default_channel_labels(ch))
      
      # Group similar analytes for easier selection
      # Find base names (e.g., PBS_1X from PBS_1X_1, PBS_1X_2)
      analyte_groups <- lapply(analytes, function(x) {
        # Try to detect numbered variants
        base <- sub("_\\d+$", "", x)
        list(display = x, value = x, group = base)
      })
      
      # Update control selectors with grouped choices
      updateSelectizeInput(session, "negative_controls", 
                       choices = setNames(analytes, analytes),
                       selected = NULL,
                       server = TRUE)
      updateSelectizeInput(session, "positive_controls", 
                       choices = setNames(analytes, analytes),
                       selected = NULL,
                       server = TRUE)
      
      # Show success notification
      showNotification(
        paste("Found", length(analytes), "unique analytes. Control selectors updated."),
        type = "message",
        duration = 3
      )
    }
  })
  
  # ===== Apply Regex to Negative Controls =====
  observeEvent(input$apply_neg_regex, {
    req(input$neg_ctrl_regex)
    req(available_analytes())
    
    tryCatch({
      pattern <- input$neg_ctrl_regex
      matching <- grep(pattern, available_analytes(), value = TRUE)
      
      if (length(matching) > 0) {
        updateSelectizeInput(session, "negative_controls", selected = matching)
        showNotification(
          paste("Selected", length(matching), "controls matching pattern:", pattern),
          type = "message",
          duration = 5
        )
      } else {
        showNotification(
          paste("No analytes match the pattern:", pattern),
          type = "warning",
          duration = 3
        )
      }
    }, error = function(e) {
      showNotification(
        paste("Invalid regex pattern:", e$message),
        type = "error",
        duration = 5
      )
    })
  })
  
  # ===== Apply Regex to Positive Controls =====
  observeEvent(input$apply_pos_regex, {
    req(input$pos_ctrl_regex)
    req(available_analytes())
    
    tryCatch({
      pattern <- input$pos_ctrl_regex
      matching <- grep(pattern, available_analytes(), value = TRUE)
      
      if (length(matching) > 0) {
        updateSelectizeInput(session, "positive_controls", selected = matching)
        showNotification(
          paste("Selected", length(matching), "controls matching pattern:", pattern),
          type = "message",
          duration = 5
        )
      } else {
        showNotification(
          paste("No analytes match the pattern:", pattern),
          type = "warning",
          duration = 3
        )
      }
    }, error = function(e) {
      showNotification(
        paste("Invalid regex pattern:", e$message),
        type = "error",
        duration = 5
      )
    })
  })
  
  # ===== Helper: Expand control selection with _ALL groups =====
  expand_control_selection <- function(selected_controls, all_analytes) {
    if (is.null(selected_controls) || length(selected_controls) == 0) {
      return(character(0))
    }
    
    expanded <- c()
    for (ctrl in selected_controls) {
      if (grepl("_ALL$", ctrl)) {
        # This is a group selector, expand to all variants
        base_name <- sub("_ALL$", "", ctrl)
        variants <- grep(paste0("^", base_name, "_\\d+$"), all_analytes, value = TRUE)
        expanded <- c(expanded, variants)
      } else {
        expanded <- c(expanded, ctrl)
      }
    }
    
    return(unique(expanded))
  }
  
  # ===== Helper: Safe Join with Validation =====
  safe_join <- function(df1, df2, by = NULL, join_type = "inner") {
    # Validate inputs
    if (is.null(df1) || is.null(df2)) {
      stop("Cannot join: one or both data frames are NULL")
    }
    
    if (nrow(df1) == 0 || nrow(df2) == 0) {
      stop("Cannot join: one or both data frames are empty")
    }
    
    # Check for common columns
    if (is.null(by)) {
      common_cols <- intersect(names(df1), names(df2))
      if (length(common_cols) == 0) {
        stop("Cannot join: no common columns found between data frames")
      }
      by <- common_cols[1]
    }
    
    # Check that join column exists
    if (!by %in% names(df1) || !by %in% names(df2)) {
      stop(paste("Join column", by, "not found in both data frames"))
    }
    
    # Perform join
    if (join_type == "inner") {
      result <- dplyr::inner_join(df1, df2, by = by)
    } else if (join_type == "left") {
      result <- dplyr::left_join(df1, df2, by = by)
    } else {
      stop("Invalid join_type. Use 'inner' or 'left'")
    }
    
    return(result)
  }
  
  # ===== UI Output: Negative Controls Summary =====
  output$neg_controls_summary <- renderUI({
    if (is.null(input$negative_controls) || length(input$negative_controls) == 0) {
      return(NULL)
    }
    
    num_selected <- length(input$negative_controls)
    
    # Get unique base names to show groups
    base_names <- unique(sub("_\\d+$", "", input$negative_controls))
    
    tags$div(
      style = "background: #e8f5e9; padding: 8px 12px; border-radius: 4px; border-left: 3px solid #4caf50; margin-top: 5px;",
      tags$div(
        style = "display: flex; align-items: center; justify-content: space-between;",
        tags$span(
          icon("check-circle", style = "color: #4caf50; margin-right: 5px;"),
          tags$b(num_selected, " control(s) selected"),
          style = "color: #2e7d32; font-size: 13px;"
        ),
        if (num_selected > 10) {
          tags$small(
            paste("Groups:", length(base_names)),
            style = "color: #2e7d32;"
          )
        }
      ),
      if (num_selected <= 5) {
        tags$div(
          style = "color: #2e7d32; font-size: 12px; margin-top: 5px;",
          paste(input$negative_controls, collapse = ", ")
        )
      } else {
        tags$div(
          style = "color: #2e7d32; font-size: 12px; margin-top: 5px;",
          paste(head(input$negative_controls, 3), collapse = ", "),
          " ... ",
          paste(tail(input$negative_controls, 2), collapse = ", ")
        )
      }
    )
  })
  
  # ===== UI Output: Positive Controls Summary =====
  output$pos_controls_summary <- renderUI({
    if (is.null(input$positive_controls) || length(input$positive_controls) == 0) {
      return(NULL)
    }
    
    num_selected <- length(input$positive_controls)
    
    # Get unique base names to show groups
    base_names <- unique(sub("_\\d+$", "", input$positive_controls))
    
    tags$div(
      style = "background: #e3f2fd; padding: 8px 12px; border-radius: 4px; border-left: 3px solid #2196f3; margin-top: 5px;",
      tags$div(
        style = "display: flex; align-items: center; justify-content: space-between;",
        tags$span(
          icon("check-circle", style = "color: #2196f3; margin-right: 5px;"),
          tags$b(num_selected, " control(s) selected"),
          style = "color: #1565c0; font-size: 13px;"
        ),
        if (num_selected > 10) {
          tags$small(
            paste("Groups:", length(base_names)),
            style = "color: #1565c0;"
          )
        }
      ),
      if (num_selected <= 5) {
        tags$div(
          style = "color: #1565c0; font-size: 12px; margin-top: 5px;",
          paste(input$positive_controls, collapse = ", ")
        )
      } else {
        tags$div(
          style = "color: #1565c0; font-size: 12px; margin-top: 5px;",
          paste(head(input$positive_controls, 3), collapse = ", "),
          " ... ",
          paste(tail(input$positive_controls, 2), collapse = ", ")
        )
      }
    )
  })
  
##### Preprocesado de datos ####
  observeEvent(input$process_button, {
    # Every reason not to start is logged and shown: a silent req() here made
    # the button look broken when, e.g., no negative control was selected.
    files <- if (nzchar(path1())) list_array_files(path1()) else character(0)
    use_channels <- tryCatch(selected_channels(), error = function(e) character(0))
    problem <- if (!identical(input$input_mode, "raw")) "the input mode is not 'Raw scanner files' (Step 1)"
      else if (length(files) == 0) "no scan files have been uploaded (Step 2)"
      else if (length(input$negative_controls) == 0) "no negative control is selected (Step 3)"
      else if (length(use_channels) == 0) "no channel is ticked (Step 3)"
    neg_controls <- if (is.null(problem)) expand_control_selection(input$negative_controls, available_analytes())
    if (is.null(problem) && length(neg_controls) == 0) problem <- "the negative controls selected are not spots of these files"
    if (!is.null(problem)) {
      log_step("NORMALIZE", "Start refused", level = "WARN", why = problem)
      showNotification(paste("Cannot start the normalization:", problem), type = "error", duration = 8)
      return()
    }

    ch_labels <- channel_labels()
    pos_controls <- if (length(input$positive_controls) > 0) input$positive_controls else NULL
    regex_pattern <- if (nzchar(input$neg_ctrl_regex %||% "")) input$neg_ctrl_regex else NULL
    pos_regex_pattern <- if (nzchar(input$positive_controls_regex %||% "")) input$positive_controls_regex else NULL
    inter <- isTRUE(input$enable_inter_norm)

    result <- withProgress(message = "Processing files...", value = 0, run_step(
      "NORMALIZE", sprintf("normalising %d arrays", length(files)),
      negative_controls = neg_controls, positive_controls = pos_controls,
      channels = paste0(use_channels, "=", ch_labels[use_channels]),
      spot_value = input$spot_metric %||% "ratio", intra_sample = input$normalization_method,
      inter_sample = if (inter) input$inter_norm_method else "off", imputation = input$imputation_method,
      hint = "Check the control selection and that every file is an export of the same slide layout.",
      done = function(r) list(samples = nrow(r$data), features = ncol(r$data) - 1,
                              spots_for_qc = nrow(r$qc), normalization_improved = r$diag$improved),
      {
        out <- process_microarray_batch(
          files, input$normalization_method,
          negative_controls = neg_controls, negative_controls_pattern = regex_pattern,
          positive_controls = pos_controls, positive_controls_pattern = pos_regex_pattern,
          channel_labels = ch_labels, channels = use_channels,
          spot_metric = input$spot_metric %||% "ratio", return_qc = TRUE,
          progress_callback = function(i, total, name) incProgress(1 / total, detail = paste("Sample", name, "complete"))
        )
        data <- out$data
        validation <- validate_expression_matrix(data, min_samples = 1, min_features = 1)
        if (!validation$valid) stop(validation$message, call. = FALSE)
        if (inter) data <- apply_inter_sample_normalization(data, method = input$inter_norm_method)
        # Diagnostic against the RAW spot signal: did the whole normalization
        # leave the arrays on a common scale?
        list(data = data, qc = out$qc, diag = normalization_diagnostics(raw_peptide_matrix(out$qc), data))
      }))
    if (is.null(result)) return()

    qc_spot_data(result$qc)
    norm_diagnostics(result$diag)
    if (!result$diag$improved) {
      log_step("NORMALIZE", "Arrays are not on a common scale after normalization", level = "WARN",
               why = result$diag$message, hint = "Enable inter-sample normalization or review the negative controls")
      showNotification(HTML(paste0("<strong>Check the normalization.</strong><br>", result$diag$message)),
                       type = "warning", duration = 14)
    }
    processed_data(result$data)
    showNotification(HTML(paste0("<strong>Processing complete</strong><br>Samples: ", nrow(result$data),
                                 "<br>Features: ", ncol(result$data) - 1,
                                 "<br>Channels: ", paste(ch_labels[use_channels], collapse = ", "))),
                     type = "message", duration = 8)
  })
  
  # ===== Validate processed matrix upload =====
  observeEvent(
    list(input$pep_fileinput, input$matrix_orientation,
         input$matrix_normalized, input$matrix_norm_method), {
    req(input$input_mode == "processed")
    req(input$pep_fileinput)

    orientation <- input$matrix_orientation
    if (is.null(orientation)) orientation <- "samples_in_rows"

    validation <- validate_processed_matrix(input$pep_fileinput$datapath, orientation)

    output$matrix_validation_status <- renderText({
      validation$message
    })

    if (!validation$valid) return(NULL)

    data <- read_processed_matrix(input$pep_fileinput$datapath, orientation)

    if (identical(input$matrix_normalized, "no")) {
      method <- input$matrix_norm_method
      if (is.null(method)) method <- "quantile"
      data <- apply_inter_sample_normalization(data, method = method)
      showNotification(paste("Applied", method, "normalization to the uploaded matrix."),
                       type = "message", duration = 5)
    }

    processed_data(data)
  })
  
  # ===== Clinical Database Upload with Advanced Options =====
  observeEvent(input$db_fileinput, {
    req(input$db_fileinput)
    
    ext <- tools::file_ext(input$db_fileinput$datapath)
    
    # Use advanced options if enabled
    use_advanced <- !is.null(input$toggle_advanced_upload) && input$toggle_advanced_upload > 0
    
    if (!tolower(ext) %in% c("xlsx", "xls", "csv")) {
      log_step("CLINICAL", "Upload refused", level = "WARN", file = input$db_fileinput$name, why = "unsupported format")
      showNotification("Unsupported file format. Use .csv or .xlsx", type = "error")
      return()
    }
    df <- run_step("CLINICAL", paste("reading", input$db_fileinput$name),
      file_type = ext, advanced_options = use_advanced,
      hint = "Save the table as .csv (comma separated, UTF-8) or .xlsx with the column names in the first row.",
      if (tolower(ext) %in% c("xlsx", "xls")) {
        d <- readxl::read_excel(input$db_fileinput$datapath)
        # read.csv sanitizes names by default; read_excel does not. Column names
        # end up inside model formulas, where R evaluates them as code.
        names(d) <- make.names(names(d), unique = TRUE)
        as.data.frame(d)
      } else if (use_advanced) {
        read.csv(input$db_fileinput$datapath,
                 sep = if (!is.null(input$csv_separator)) input$csv_separator else ",",
                 header = if (!is.null(input$csv_header)) input$csv_header else TRUE,
                 fileEncoding = if (!is.null(input$csv_encoding)) input$csv_encoding else "UTF-8")
      } else {
        read.csv(input$db_fileinput$datapath)
      })

    if (!is.null(df) && nrow(df) > 0) {
      # Clean sample IDs: remove file extensions (.csv, .txt, etc.)
      id_col <- if("id" %in% colnames(df)) "id" else colnames(df)[1]
      df[[id_col]] <- gsub("\\.(csv|txt|xlsx|xls)$", "", df[[id_col]], ignore.case = TRUE)
      
      # Update column selectors
      updateSelectInput(session, "sample_id_col", choices = colnames(df),
                       selected = if("id" %in% colnames(df)) "id" else colnames(df)[1])
      updateSelectInput(session, "replace_column", choices = colnames(df),
                       selected = colnames(df)[1])

      # Store original database
      clinical_keep(NULL)
      database(df)
      database_edited(df)
      arrays <- if (nzchar(path1())) tools::file_path_sans_ext(basename(list_array_files(path1()))) else character(0)
      ids <- as.character(df[[id_col]])
      log_step("CLINICAL", "Clinical table loaded", file = input$db_fileinput$name, rows = nrow(df),
               columns = names(df), id_column = id_col,
               ids_matching_arrays = if (length(arrays)) sum(ids %in% arrays) else NULL,
               arrays_without_row = if (length(arrays)) setdiff(arrays, ids) else NULL,
               rows_without_array = if (length(arrays)) setdiff(ids, arrays) else NULL)
      if (length(arrays) && sum(ids %in% arrays) < length(arrays)) {
        log_step("CLINICAL", "Some arrays have no clinical row and will be dropped from every comparison", level = "WARN",
                 hint = "The id column must equal the scan file names without extension")
      }
      metadata_render_trigger(metadata_render_trigger() + 1)

      showNotification(
        paste("Metadata loaded:", nrow(df), "samples,", ncol(df), "columns"),
        type = "message",
        duration = 3
      )
    } else {
      if (!is.null(df)) log_step("CLINICAL", "Clinical table is empty", level = "WARN", file = input$db_fileinput$name)
      showNotification("Error: Database is empty or could not be read", type = "error")
    }
  })
  
  # ===== Clinical column picker =====
  # One chip per column with its type and missing values; unticked columns are
  # dropped from active_database(), so no selector or model ever sees them.
  output$clinical_columns_ui <- renderUI({
    df <- database_edited()
    req(df)
    cols <- setdiff(names(df), c("id", input$sample_id_col))
    req(length(cols) > 0)
    describe <- function(v) paste0(if (is.numeric(v)) "numeric" else paste(dplyr::n_distinct(v, na.rm = TRUE), "levels"),
                                   if (anyNA(v)) paste0(" · ", sum(is.na(v)), " missing") else "")
    keep <- if (is.null(isolate(clinical_keep()))) cols else intersect(isolate(clinical_keep()), cols)
    tags$div(class = "clinical-cols",
      tags$div(class = "clinical-cols-head",
        tags$b("Columns to analyse"),
        tags$span(class = "clinical-cols-count", textOutput("clinical_cols_count", inline = TRUE)),
        actionLink("clinical_cols_all", "All"), actionLink("clinical_cols_none", "None")),
      checkboxGroupInput("clinical_columns", NULL, inline = TRUE, selected = keep, choiceValues = cols,
                         choiceNames = lapply(cols, function(c) tags$span(tags$b(c), tags$small(describe(df[[c]]))))))
  })
  output$clinical_cols_count <- renderText({
    n_all <- length(setdiff(names(database_edited()), c("id", input$sample_id_col)))
    sprintf("%d of %d selected", if (is.null(clinical_keep())) n_all else length(clinical_keep()), n_all)
  })
  observeEvent(input$clinical_columns, clinical_keep(input$clinical_columns %||% character(0)),
               ignoreNULL = FALSE, ignoreInit = TRUE)
  observeEvent(input$clinical_cols_all, {
    cols <- setdiff(names(database_edited()), c("id", input$sample_id_col))
    updateCheckboxGroupInput(session, "clinical_columns", selected = cols)
  })
  observeEvent(input$clinical_cols_none, updateCheckboxGroupInput(session, "clinical_columns", selected = character(0)))

  # ===== Rename sample ID column to 'id' when user confirms selection =====
  # Operates on the EDITED metadata so manual edits / find-replace are preserved.
  observeEvent(input$sample_id_col, {
    req(database_edited())
    req(input$sample_id_col)

    df <- database_edited()
    sel <- input$sample_id_col

    if (!sel %in% colnames(df) || sel == "id") {
      return()  # nothing to rename
    }

    # Drop any pre-existing 'id' column so the rename never collides
    if ("id" %in% colnames(df)) df[["id"]] <- NULL
    df <- df %>% dplyr::rename(id = !!rlang::sym(sel))

    database_edited(df)
    metadata_render_trigger(metadata_render_trigger() + 1)

    showNotification(
      paste0("Sample ID column '", sel, "' renamed to 'id' for analysis"),
      type = "message",
      duration = 3
    )
  })

  # ===== Metadata Preview Table =====
  # Re-renders only on explicit triggers (load / replace / revert / rename), NOT
  # on every cell edit -> avoids cursor jumps and reactive loops.
  output$metadata_table <- rhandsontable::renderRHandsontable({
    metadata_render_trigger()
    df <- isolate(database_edited())
    req(df)
    rhandsontable::rhandsontable(df, height = 300, stretchH = "all") %>%
      rhandsontable::hot_context_menu(allowRowEdit = FALSE, allowColEdit = FALSE)
  })

  # ===== Auto-sync manual cell edits into database_edited =====
  # Keeps the edited data current so Find & Replace and downstream joins always
  # see the latest cell edits without needing an explicit "Apply" click.
  observeEvent(input$metadata_table, {
    edited_df <- rhandsontable::hot_to_r(input$metadata_table)
    if (!is.null(edited_df)) {
      database_edited(edited_df)
    }
  }, ignoreInit = TRUE)

  # ===== Find & Replace in Metadata =====
  observeEvent(input$apply_find_replace, {
    req(database_edited())
    req(input$replace_column)
    req(input$find_text)

    df <- database_edited()
    col <- input$replace_column
    find_text <- input$find_text
    replace_text <- if (is.null(input$replace_text)) "" else input$replace_text

    if (col %in% colnames(df)) {
      # Operate on a character copy so numeric/factor columns match as displayed
      col_chr <- as.character(df[[col]])
      matches <- sum(grepl(find_text, col_chr, fixed = TRUE))

      if (matches > 0) {
        # Replace all occurrences and force the table to refresh
        df[[col]] <- gsub(find_text, replace_text, col_chr, fixed = TRUE)
        database_edited(df)
        metadata_render_trigger(metadata_render_trigger() + 1)

        showNotification(
          paste("Replaced", matches, "occurrence(s) in column:", col),
          type = "message",
          duration = 5
        )
      } else {
        showNotification(
          paste0("No matches found for '", find_text, "' in column: ", col),
          type = "warning",
          duration = 3
        )
      }
    }
  })

  # ===== Apply Metadata Edits (explicit confirm; edits already auto-sync) =====
  observeEvent(input$apply_metadata_edits, {
    if (!is.null(input$metadata_table)) {
      edited_df <- rhandsontable::hot_to_r(input$metadata_table)
      database_edited(edited_df)
      showNotification("Metadata changes applied", type = "message")
    }
  })

  # ===== Revert Metadata Edits =====
  observeEvent(input$revert_metadata_edits, {
    database_edited(database())
    metadata_render_trigger(metadata_render_trigger() + 1)
    showNotification("Metadata reverted to original", type = "message")
  })
  
  
  ##### Descargar los datos en Excel ####
  output$download_button <- downloadHandler(
    filename = function() {
      paste("microarray_data_", Sys.Date(), ".xlsx", sep = "")
    },
    content = function(file) {
      # Create workbook with multiple sheets
      wb <- openxlsx::createWorkbook()
      
      # Sheet 1: Expression data
      if (!is.null(processed_data())) {
        openxlsx::addWorksheet(wb, "Expression_Data")
        openxlsx::writeData(wb, "Expression_Data", processed_data())
      }
      
      # Sheet 2: Clinical metadata (edited version if available)
      if (!is.null(database_edited())) {
        openxlsx::addWorksheet(wb, "Clinical_Metadata")
        openxlsx::writeData(wb, "Clinical_Metadata", database_edited())
      }
      
      # Sheet 3: Processing log
      log_data <- data.frame(
        Parameter = c("Processing Date", "Input Mode", "Normalization Method",
                     "Channel Labels", "Channels Analysed", "Spot Signal",
                     "Negative Controls", "Inter-sample Normalization"),
        Value = c(
          as.character(Sys.Date()),
          if (!is.null(input$input_mode)) input$input_mode else "N/A",
          if (!is.null(input$normalization_method)) input$normalization_method else "N/A",
          paste(tryCatch(channel_labels(), error = function(e) "N/A"), collapse = ", "),
          paste(tryCatch(selected_channels(), error = function(e) "N/A"), collapse = ", "),
          if (!is.null(input$spot_metric)) input$spot_metric else "ratio",
          if (!is.null(input$negative_controls)) paste(input$negative_controls, collapse = ", ") else "N/A",
          if (!is.null(input$enable_inter_norm) && input$enable_inter_norm) 
            input$inter_norm_method else "None"
        )
      )
      openxlsx::addWorksheet(wb, "Processing_Log")
      openxlsx::writeData(wb, "Processing_Log", log_data)
      
      openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
    }
  )
  
  
  output$data_table <- renderDT({
    req(processed_data())
    datatable(processed_data(), style="bootstrap4",
              options = list(
                scrollY = "250px",
                pageLength = 5,
                lengthMenu = c(5, 10, 15, 20)
              ))
  })
  
  output$density_plot <- renderPlot({
    req(processed_data())
    
    # Validate before plotting
    validation <- validate_expression_matrix(processed_data())
    if (!validation$valid) {
      return(NULL)
    }
    
    data_long <- tidyr::pivot_longer(
      processed_data(), 
      cols = -id, 
      names_to = "ID", 
      values_to = "MExpression"
    )
    
    # Filter non-finite values
    data_long <- data_long %>%
      dplyr::filter(is.finite(MExpression))
    
    # Check if any data remains
    if (nrow(data_long) == 0) {
      return(NULL)
    }
    
    unique_ids <- unique(data_long$ID)
    if (length(unique_ids) == 0) {
      return(NULL)
    }
    
    selected_ids <- sample(unique_ids, size = min(20, length(unique_ids)))
    
    data_filtered <- data_long %>%
      dplyr::filter(ID %in% selected_ids)
    
    # Final check
    req(nrow(data_filtered) > 0)
    
    ggplot(data_filtered, aes(x = MExpression, y = ID, fill = ID)) +
      ggridges::geom_density_ridges(scale = 1) +
      theme_microarrai() +
      scale_fill_viridis_d(option = "mako") + 
      theme(legend.position = "none") +
      labs(title = "Density Plot of Normalized Expression (20 Variables)", 
           x = "Normalized Expression", 
           y = "Variable (ID)")
  })
  
  #### Fin preprocesado ####
  
  # Built-in example: stage its arrays like an upload, load its clinical table
  # and hand its peptide annotation to the protein tab.
  observeEvent(input$load_example, {
    key <- input$example_dataset
    updateRadioButtons(session, "input_mode", selected = "raw")
    example_channels(EXAMPLE_CHANNELS[[key]])
    stage(stage_example_arrays(key, raw_upload_dir))

    df <- read.csv(file.path(example_dir(key), "clinical.csv"))
    clinical_keep(NULL)
    database(df)
    database_edited(df)
    metadata_render_trigger(metadata_render_trigger() + 1)
    updateSelectInput(session, "sample_id_col", choices = colnames(df), selected = "id")
    updateSelectInput(session, "replace_column", choices = colnames(df), selected = "Group")
    example_annotation(file.path(example_dir(key), "annotation.csv"))
    log_step("UPLOAD", "Example dataset loaded", dataset = key, arrays = nrow(df), channels = EXAMPLE_CHANNELS[[key]])

    showNotification(paste0("Example loaded: ", nrow(df), " arrays and their clinical data. ",
                            "Continue with Step 3."), type = "message", duration = 6)
  })

  ##### Mostrar estado de la base de datos clínica #####
  output$data_status_db <- renderText({
    if (is.null(database())) {
      "No hay datos clínicos cargados."
    } else {
      paste("Rows:", nrow(database()), "Columns:", ncol(database()))
    }
  })
  

  # ===== Finish Preprocess Button: Switch to Peptide Tab =====
  observeEvent(input$finish_preprocess, {
    # Check that data is ready (logged: a silent stop made the button look dead)
    if (is.null(processed_data()) || nrow(processed_data()) == 0) {
      log_step("PREPROCESS", "Finish refused", level = "WARN", why = "no processed matrix yet",
               hint = "Run Step 4 (Start Normalization Process) first")
      showNotification(
        "No expression data available. Please process your data first.",
        type = "error",
        duration = 5
      )
      return()
    }
    
    if (is.null(database_edited()) || nrow(database_edited()) == 0) {
      log_step("PREPROCESS", "Finish refused", level = "WARN", why = "no clinical table", hint = "Upload it in Step 5")
      showNotification(
        "No clinical metadata available. Please upload clinical data.",
        type = "warning",
        duration = 5
      )
      return()
    }
    
    # Success notification
    showNotification(
      HTML(paste0(
        "<strong>Preprocessing Complete!</strong><br>",
        "Samples: ", nrow(processed_data()), "<br>",
        "Features: ", ncol(processed_data()) - 1, "<br>",
        "<br>Switching to Peptide Analysis tab..."
      )),
      type = "message",
      duration = 5
    )
    
    db <- active_database()
    pd <- processed_data()
    log_step("PREPROCESS", "Preprocessing finished", samples = nrow(pd), features = ncol(pd) - 1,
             samples_with_clinical_row = sum(pd$id %in% db$id), clinical_columns_used = setdiff(names(db), "id"),
             missing_values = sum(is.na(pd[, -1])))
    # Switch to Peptide tab
    updateTabsetPanel(session, "main_tabs", selected = "Peptide finder")
  })
  
  ## Peptide tab - Updated to use processed_data from both RAW and processed modes
  # Raw analysis matrix BEFORE imputation (still contains NAs from flagged spots).
  # Kept separate so the Data Overview can report missingness honestly.
  raw_pepdata <- reactive({
    # Processed data from either mode (built-in examples arrive as RAW arrays)
    data <- processed_data()
    if (is.null(data)) return(NULL)

    # Clean column names for R compatibility
    colnames(data) <- make.names(colnames(data))
    data
  })

  # Missing-value diagnostics on the raw (pre-imputation) matrix
  na_stats <- reactive({
    req(raw_pepdata())
    compute_na_stats(raw_pepdata())
  })

  # Analysis matrix: missing values imputed so downstream stats/ML/viz never
  # drop samples. Method is user-selectable (default kNN). Imputation replaces
  # the old silent NA->0, which was a biased "equal to control" assumption.
  pepdata <- reactive({
    data <- raw_pepdata()
    if (is.null(data)) return(NULL)

    method <- if (!is.null(input$imputation_method)) input$imputation_method else "knn"
    impute_missing(data, method = method)
  })
  
  output$data_status_pep <- renderText({
    # Use processed_data for Step 6 preview, pepdata for Peptide tab
    data_to_show <- if (!is.null(processed_data())) {
      processed_data()
    } else if (!is.null(pepdata())) {
      pepdata()
    } else {
      NULL
    }
    
    if (is.null(data_to_show)) {
      "No expression data available."
    } else {
      paste("Rows:", nrow(data_to_show), "Columns:", ncol(data_to_show))
    }
  })
 
  
  
  output$peptide_hplot <- renderPlot({
    req(pepdata())
    
    # Convert to numeric matrix
    mat <- prepare_matrix(pepdata(), row_col = "id")
    
    # Check for non-finite values
    if (!any(is.finite(mat))) {
      plot.new()
      text(0.5, 0.5, "No valid data for heatmap\n(all values are NA/Inf)", 
           cex = 1.5, col = "white")
      return(NULL)
    }
    
    # Remove columns with all NA/Inf
    valid_cols <- apply(mat, 2, function(x) any(is.finite(x)))
    if (sum(valid_cols) == 0) {
      plot.new()
      text(0.5, 0.5, "No valid features for heatmap", cex = 1.5, col = "white")
      return(NULL)
    }
    
    mat <- mat[, valid_cols, drop = FALSE]
    
    # Limit to 300 features for performance
    mat_sampled <- sample_heatmap_features(mat, max_features = 300, seed = 123)
    
    iso <- split_isotype_mats(mat_sampled)
    
    # Define color palette with app background for 0 values
    ige_colors <- colorRampPalette(c("#191c32","lightgreen", "green"))(50)
    igg4_colors <- colorRampPalette(c("#191c32", "#fd6b6bff", "red"))(50)
    default_colors <- colorRampPalette(c("#191c32", "lightgreen", "green"))(50)
    
    if (iso$any_iso) {
      ht_list <- NULL
      if (!is.null(iso$ige) && ncol(iso$ige) > 0) {
        ht_ige <- ComplexHeatmap::Heatmap(
          iso$ige, name = iso$names[1],
          col = ige_colors,
          cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
          show_column_names = FALSE,
          show_row_names = FALSE,
          row_dend_gp = grid::gpar(col = "white"),
          column_dend_gp = grid::gpar(col = "white"),
          heatmap_legend_param = list(
            border = "white",
            title_gp = grid::gpar(fontsize = 10, fontface = "bold", col = "white"),
            labels_gp = grid::gpar(fontsize = 9, col = "white")
          )
        )
        ht_list <- ht_ige
      }
      if (!is.null(iso$igg4) && ncol(iso$igg4) > 0) {
        ht_igg4 <- ComplexHeatmap::Heatmap(
          iso$igg4, name = iso$names[2],
          col = igg4_colors,  
          cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
          show_column_names = FALSE,
          show_row_names = FALSE,
          row_dend_gp = grid::gpar(col = "white"),
          column_dend_gp = grid::gpar(col = "white"),
          heatmap_legend_param = list(
            border = "white",
            title_gp = grid::gpar(fontsize = 10, fontface = "bold", col = "white"),
            labels_gp = grid::gpar(fontsize = 9, col = "white")
          )
        )
        ht_list <- if (is.null(ht_list)) ht_igg4 else (ht_list + ht_igg4)
      }
      ComplexHeatmap::draw(
        ht_list, 
        heatmap_legend_side = "right",
        background = "transparent"
      )
    } else {
      ht <- ComplexHeatmap::Heatmap(
        mat_sampled, name = "Expression",
        col = default_colors,
        cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
        show_column_names = FALSE,
        show_row_names = FALSE,
        row_dend_gp = grid::gpar(col = "white"),
        column_dend_gp = grid::gpar(col = "white"),
        heatmap_legend_param = list(
          border = "white",
          title_gp = grid::gpar(fontsize = 10, fontface = "bold", col = "white"),
          labels_gp = grid::gpar(fontsize = 9, col = "white")
        )
      )
      ComplexHeatmap::draw(
        ht, 
        heatmap_legend_side = "right",
        background = "transparent"
      )
    }
  }, bg = "transparent")
  outputOptions(output, "peptide_hplot", suspendWhenHidden = FALSE)
  
  
  # ========== GLOBAL SUMMARY PANEL ==========
  
  # Calculate summary statistics
  peptide_summary <- reactive({
    req(pepdata())
    req(input$zscore_threshold)
    calculate_peptide_summary(pepdata(), expression_threshold = input$zscore_threshold)
  })
  
  # Isotype donut chart
  output$isotype_donut <- renderChart({
    req(peptide_summary())
    create_isotype_donut_chart(peptide_summary()$isotype_summary)
  })
  
  # Expression distribution plot
  output$expression_dist_plot <- renderChart({
    req(pepdata())
    create_expression_distribution_plot(pepdata())
  })
  
  # KPI value boxes
  output$kpi_boxes <- renderUI({
    req(peptide_summary())
    kpi_data <- create_summary_value_boxes(peptide_summary(), na_stats())

    # PowerBI-style flat tiles, 4 per row. Completeness moved to Quality Control.
    tagList(
      fluidRow(
        lapply(seq_len(nrow(kpi_data)), function(i) {
          column(3, kpi_card(kpi_data$Metric[i], kpi_data$Value[i], "#17a589"))
        })
      ),
      tags$p(
        style = "color:#6b7280;font-size:12.5px;margin-top:10px;",
        icon("circle-info", style = "margin-right:6px;"),
        "Missing values, replicate agreement and per-array quality live in the Quality Control tab."
      )
    )
  })
  
  # ========== Threshold Info Panel ==========
  output$threshold_info_panel <- renderUI({
    req(input$zscore_threshold)
    div(
      style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 8px; padding: 15px; margin-top: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);",
      tags$p(
        style = "margin: 0; color: white; font-size: 16px;",
        tags$i(class = "fa fa-info-circle", style = "margin-right: 10px;"),
        tags$strong("Expression Threshold: "), 
        input$zscore_threshold,
        " | Peptides with expression > ",
        input$zscore_threshold,
        " are considered positive"
      )
    )
  })
  
  # Styled summary table (top samples)
  output$top_samples_table <- DT::renderDataTable({
    req(peptide_summary())
    table_data <- create_styled_summary_table(peptide_summary()$per_sample, top_n = 10)
    
    DT::datatable(
      table_data,
      options = list(
        dom = 't',
        ordering = TRUE,
        pageLength = 10,
        scrollX = TRUE,
        scrollY = "250px",
        scrollCollapse = TRUE,
        columnDefs = list(
          list(className = 'dt-center', targets = '_all')
        )
      ),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        'Positive Peptides',
        background = DT::styleColorBar(range(table_data$`Positive Peptides`), '#667eea'),
        backgroundSize = '100% 90%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  # Isotype summary table
  output$isotype_table <- DT::renderDataTable({
    req(peptide_summary())
    isotype_data <- peptide_summary()$isotype_summary %>%
      mutate(
        mean_expression = round(mean_expression, 2),
        median_expression = round(median_expression, 2),
        percentage = round(n_peptides / sum(n_peptides) * 100, 1)
      ) %>%
      dplyr::select(Isotype, `N Peptides` = n_peptides, `Percentage (%)` = percentage,
                    `Mean Expr` = mean_expression, `Median Expr` = median_expression)
    
    DT::datatable(
      isotype_data,
      options = list(
        dom = 't',
        ordering = FALSE,
        pageLength = 10
      ),
      rownames = FALSE
    )
  })
  
  
  # Single source of truth for "which clinical variable are we analysing".
  # Every other tab inherits this unless it explicitly overrides it; before, five
  # independent selectors could silently point at different variables, which is
  # why the Feature Level and volcano tables disagreed.
  global_target_var <- reactive({ input$stats })

  output$stats_var <- renderUI({
    req(database())
    selectInput("stats", 
                label = tags$span(style = "color: #191c32;", "Target variable (used by every tab)"),
                choices = colnames(meta_data() %>% 
                                     dplyr::select((ncol(pepdata()) +1):ncol(meta_data())) %>% 
                                     as.data.frame())) 
  })

  
  ####### Peptide #####
  shinyjs::hide("stats_div")
  shinyjs::hide("feature_level_div")
  shinyjs::hide("loader")
  shinyjs::hide("results_summary_div")
  
  observeEvent(input$run_analysis_1, {
    # Mostrar el loader cuando se hace clic en el botón de análisis
    shinyjs::show("loader")
    
    # Condicional para ejecutar sólo si se selecciona la opción correcta
    if (input$analysis_type == "Comparison between groups (Classification)") {
      req(tests())  
      req(reg_models())
      
      # Después de 3 segundos, ocultar el loader y mostrar los divs
      Sys.sleep(3)
      shinyjs::hide("loader")
      shinyjs::show("stats_div")
      shinyjs::show("feature_level_div")
      shinyjs::show("volcano_div")
      shinyjs::show("results_filters_div")
      shinyjs::show("results_summary_div")
      shinyjs::show("funnel_div")
      
      
    } else {
      showNotification("The selected analysis option is not yet implemented.", type = "error")
      shinyjs::hide("loader")  # Asegurarse de ocultar el loader si hay error
    }
  })
  

  tests <- eventReactive(input$run_analysis_1, {
    req(input$analysis_type == "Comparison between groups (Classification)")
    req(pepdata(), active_database(), input$stats)
    groups <- table(active_database()[[input$stats]][active_database()$id %in% pepdata()$id])
    if (length(groups) < 2) {
      log_step("STATS", "Analysis refused", level = "WARN", target = input$stats, groups = names(groups),
               why = "the target has fewer than two groups among the samples with arrays",
               hint = "Choose a variable with at least two groups, or check that the clinical ids match the arrays")
      showNotification(paste0("'", input$stats, "' has fewer than two groups among the analysed samples."), type = "error", duration = 10)
      req(FALSE)
    }

    res <- run_step("STATS", paste("differential analysis by", input$stats),
      target = input$stats, groups = paste0(names(groups), "=", as.integer(groups)),
      peptides = ncol(pepdata()) - 1, model = "lm per peptide + BH FDR",
      contrast_test = if (isTRUE(input$add_contrast_test)) input$contrast_method,
      hint = "Each group needs at least two samples; a numeric target should be grouped first.",
      done = function(r) list(tested = nrow(r), fdr_below_0.05 = sum(r$p.adj < 0.05, na.rm = TRUE)),
      {
        lm_results <- perform_lm_differential_analysis(
          peptide_data = pepdata(), clinical_data = active_database(),
          target_variable = input$stats, test_method = "lm"
        )
        # Optional second test, joined as extra p-value columns
        if (isTRUE(input$add_contrast_test)) {
          contrast_results <- perform_lm_differential_analysis(
            peptide_data = pepdata(), clinical_data = active_database(),
            target_variable = input$stats, test_method = input$contrast_method
          )
          lm_results <- lm_results %>%
            left_join(contrast_results %>% select(peptide, contrast_p = p, contrast_p.adj = p.adj), by = "peptide")
        }
        lm_results
      })
    req(res)
    res
  })
  
  tests_filtered <- reactive({
    req(tests())
    req(input$results_pval_threshold)
    
    filtered <- filter_biomarkers(
      stats_results = tests(),
      pval_raw_threshold = 0.05,
      pval_adj_threshold = input$results_pval_threshold
    )
    
    # Ensure consistent column names: rename p.value -> p
    if ("p.value" %in% names(filtered) && !"p" %in% names(filtered)) {
      filtered <- filtered %>% rename(p = p.value)
    }
    
    # Note: log2FC and status are contrast-specific (calculated in volcano plot)
    # They don't belong to the peptide itself, only to a 2-group comparison
    
    return(filtered)
  })
  
  
  output$stats_table <- DT::renderDataTable({
    req(tests_filtered())
    
    # Format table with rounded p-values
    table_data <- tests_filtered() %>%
      as.data.frame()
    
    # Round numeric columns safely
    if ("p" %in% names(table_data)) {
      table_data$p <- round(as.numeric(table_data$p), 4)
    }
    if ("p.adj" %in% names(table_data)) {
      table_data$p.adj <- round(as.numeric(table_data$p.adj), 4)
    }
    if ("log2FC" %in% names(table_data)) {
      table_data$log2FC <- round(as.numeric(table_data$log2FC), 4)
    }
    
    # If contrast columns exist, round them too
    if ("contrast_p" %in% names(table_data)) {
      table_data$contrast_p <- round(as.numeric(table_data$contrast_p), 4)
      table_data$contrast_p.adj <- round(as.numeric(table_data$contrast_p.adj), 4)
    }
    
    DT::datatable(
      table_data,
      options = list(
        scrollY = "250px",
        pageLength = 5,
        lengthMenu = c(5, 10, 15, 20)
      ),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        'p.adj',
        background = DT::styleColorBar(c(0, max(table_data$p.adj, na.rm = TRUE)), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  # ========== Unified Stats Table (DEG + Regression) ==========
  output$unified_stats_table <- DT::renderDataTable({
    req(tests_filtered(), reg_models())
    
    # Merge stats and regression tables (without log2FC - that's contrast-specific)
    stats_data <- tests_filtered() %>%
      as.data.frame() %>%
      dplyr::select(peptide, p, p.adj)
    
    reg_data <- reg_models() %>%
      as.data.frame() %>%
      dplyr::select(Peptide, Method, Accuracy, AUC, F1, Recall) %>%
      dplyr::rename(peptide = Peptide)
    
    unified_data <- stats_data %>%
      dplyr::left_join(reg_data, by = "peptide") %>%
      dplyr::select(Peptide = peptide, Method, `P-value` = p, `P-adj` = p.adj, 
             Accuracy, AUC, F1, Recall) %>%
      mutate(
        `P-value` = round(as.numeric(`P-value`), 4),
        `P-adj` = round(as.numeric(`P-adj`), 4),
        Accuracy = round(as.numeric(Accuracy), 2),
        AUC = round(as.numeric(AUC), 2),
        F1 = round(as.numeric(F1), 2),
        Recall = round(as.numeric(Recall), 2)
      )
    
    DT::datatable(
      unified_data,
      options = list(
        scrollY = "600px",
        scrollX = TRUE,
        pageLength = 15,
        lengthMenu = c(10, 25, 50),
        columnDefs = list(
          list(className = 'dt-center', targets = '_all')
        )
      ),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        'P-adj',
        background = DT::styleColorBar(c(0, max(unified_data$`P-adj`, na.rm = TRUE)), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      ) %>%
      DT::formatStyle(
        'AUC',
        background = DT::styleColorBar(c(0, 1), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      ) %>%
      DT::formatStyle(
        'F1',
        background = DT::styleColorBar(c(0, 1), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      ) %>%
      DT::formatStyle(
        'Accuracy',
        background = DT::styleColorBar(c(0, 1), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      ) %>%
      DT::formatStyle(
        'Recall',
        background = DT::styleColorBar(c(0, 1), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  ### Boxplots + p-value
  output$stats_var_plot <- renderUI({
    req(tests_filtered())
    df <- tests_filtered()
    req(database())
    selectInput("stats_plot_var", "Grouping var",
                choices = df$peptide) 
  })
  
  
  output$stats_plot <- renderChart({
    req(tests_filtered(), input$stats_plot_var, input$stats)
    meta <- tryCatch(safe_join(pepdata(), active_database(), by = "id", join_type = "inner"), error = function(e) NULL)
    if (is.null(meta) || nrow(meta) == 0) return(chart_message("No sample IDs match between the expression matrix and the clinical table."))
    req(all(c(input$stats, input$stats_plot_var) %in% names(meta)))
    d <- dplyr::filter(meta, is.finite(.data[[input$stats_plot_var]]), !is.na(.data[[input$stats]]))
    chart_groupdist(d[[input$stats_plot_var]], d[[input$stats]], d$id, ylab = "Expression",
                    title = input$stats_plot_var, subtitle = paste("Grouped by", input$stats))
  })
  #################### Logistic regression ####################################
  
  reg_models <- eventReactive(input$run_analysis_1,{
    req(input$analysis_type == "Comparison between groups (Classification)")
    req(pepdata())  
    req(active_database())
    req(tests_filtered())
    
    testt <- tests_filtered() %>% as.data.frame()
    peps <- pepdata()
    tmp1 <- active_database()
    
    # Safe join with validation
    tryCatch({
      meta <- safe_join(peps, tmp1, by = "id", join_type = "inner")
    }, error = function(e) {
      showNotification(
        "Cannot run regression: sample IDs don't match between expression and clinical data",
        type = "error"
      )
      return(NULL)
    })
    
    if (is.null(meta) || nrow(meta) == 0) {
      showNotification("No matching samples found", type = "error")
      return(NULL)
    }
    
    df <- tmp1 %>% rename(target = !!rlang::sym(input$stats)) %>% dplyr::select(id,target)
    df2 <- meta %>% dplyr::select(1:ncol(peps))
    df3 <- df %>% inner_join(df2, by = "id") %>% dplyr::select(-id) %>% 
      mutate(target = as.factor(target)) %>% 
      pivot_longer(names_to = "pep", values_to = "Expression", cols = -target)
    
    # Filter non-finite values
    df3 <- df3 %>% dplyr::filter(is.finite(Expression))
    
    if (nrow(df3) == 0) {
      showNotification("No valid expression data after filtering", type = "error")
      return(NULL)
    }
    
    nlevels_target <- nlevels(as.factor(df3$target))
    perfor <- run_step("STATS", sprintf("per-peptide %s and AUC for %d candidates",
                                         if (nlevels_target > 2) "multinomial regression" else "logistic regression", nrow(testt)),
      hint = "A peptide whose values are constant within a group cannot be modelled; lower the FDR filter or check the data.",
      done = function(r) list(peptides = nrow(r), mean_auc = mean(r$AUC, na.rm = TRUE)), {
    perfor <- data.frame()
    for (i in testt$peptide) {
      M <- df3 %>% filter(pep == i) %>% filter(!is.na(Expression))
      
      # Use modular regression functions
      if (nlevels_target > 2) {
        # Multinomial regression
        result <- fit_multinomial_regression(
          expression_data = M$Expression,
          target = M$target
        )
        Method <- "Multinomial logistic"
      } else {
        # Binary GLM
        result <- fit_binary_glm(
          expression_data = M$Expression,
          target = M$target
        )
        Method <- "GLM"
      }
      
      # Calculate performance metrics
      metrics <- calculate_performance_metrics(
        predictions = result$predictions,
        actual = M$target,
        probabilities = if (nlevels_target > 2) result$probabilities else result$probabilities[, 2]
      )
      
      perfor <- bind_rows(perfor, data.frame(
        i = i,
        Method = Method,
        Accuracy = round(metrics$accuracy, 2),
        AUC = round(metrics$auc, 2),
        F1 = round(metrics$f1, 2),
        Recall = round(metrics$recall, 2)
      ))
    }
    perfor
    })
    req(perfor)
    perfor %>% rename(Peptide = i)
  })
  
  
  output$reg_table <- DT::renderDataTable({
    req(tests_filtered())
    table <- reg_models() %>% 
      as.data.frame() %>%
      mutate(
        Accuracy = round(Accuracy, 4),
        AUC = round(AUC, 4),
        F1 = round(F1, 4),
        Recall = round(Recall, 4)
      )
    rownames(table) <- NULL
    
    DT::datatable(
      table,
      options = list(
        scrollY = "250px",
        pageLength = 5,
        lengthMenu = c(5, 10, 15, 20)
      ),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        'AUC',
        background = DT::styleColorBar(c(0, 1), '#4facfe'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  # -------- Helpers volcano --------
  volcano_colors <- c(
    Up   = MICROARRAI_COLORS[2],  # verde corporativo
    Down = MICROARRAI_COLORS[6],  # rojo corporativo
    NS   = "#9CA3AF"              # gris
  )
  
  # Variable de agrupación (solo factores/char de la base clínica)
  output$volcano_group_var_ui <- renderUI({
    req(active_database())
    db <- active_database()
    facs <- names(db)[vapply(db, function(x) is.factor(x) || is.character(x), logical(1))]
    facs <- setdiff(facs, "id")
    # Inherit the global target. isolate() so that changing the target updates the
    # selection (below) instead of re-rendering the input and wiping the A/B levels.
    sel <- isolate(global_target_var())
    if (is.null(sel) || !sel %in% facs) sel <- facs[1]
    tagList(
      selectInput("volcano_group_var", dark_label("Contrast Variable:"),
                  choices = facs, selected = sel),
      checkboxInput("volcano_override_var",
                    "Contrast a different variable than the target", value = FALSE)
    )
  })

  # Keep the volcano on the global target unless the user deliberately opted out.
  observeEvent(list(global_target_var(), input$volcano_override_var), {
    req(global_target_var())
    if (isTRUE(input$volcano_override_var)) return()
    updateSelectInput(session, "volcano_group_var", selected = global_target_var())
  }, ignoreInit = TRUE)

  observe({
    shinyjs::toggleState("volcano_group_var",
                         condition = isTRUE(input$volcano_override_var))
  })
  
  # Niveles A y B (contraste binario)
  output$volcano_level_a_ui <- renderUI({
    req(active_database(), input$volcano_group_var)
    lv <- levels(as.factor(active_database()[[input$volcano_group_var]]))
    selectInput("volcano_level_a", dark_label("Group A (numerator):"), choices = lv)
  })
  output$volcano_level_b_ui <- renderUI({
    req(active_database(), input$volcano_group_var)
    lv <- levels(as.factor(active_database()[[input$volcano_group_var]]))
    sel <- if (length(lv) >= 2) lv[min(2, length(lv))] else lv[1]
    selectInput("volcano_level_b", dark_label("Group B (denominator):"), choices = lv, selected = sel)
  })
  
  # Tabla base para volcano (1 o 2 isotipos)
  # Isotypes (channel prefixes) present in the analysis matrix. Positional names
  # from raw arrays (IgE_p_9_k.cas) are read by discover_isotypes(); otherwise
  # any prefix shared by several columns counts, as long as there are 2+ of them
  # (a lone shared prefix such as "Peptide_1" is a naming scheme, not an isotype).
  peptide_isotypes <- reactive({
    req(pepdata())
    cols <- setdiff(names(pepdata()), "id")
    isos <- discover_isotypes(cols)
    if (length(isos) > 0) return(isos)
    pre <- table(sub("_.*", "", cols[grepl("_", cols)]))
    if (sum(pre >= 2) >= 2) names(pre)[pre >= 2] else character(0)
  })

  output$volcano_isotypes_ui <- renderUI({
    isos <- peptide_isotypes()
    if (length(isos) == 0) return(NULL)
    checkboxGroupInput("volcano_isotypes", dark_label("Select Isotypes:"),
                       choices = isos, selected = isos)
  })

  volcano_tbl <- reactive({
    req(pepdata(), active_database(),
        input$volcano_group_var, input$volcano_level_a, input$volcano_level_b)
    validate(need(input$volcano_level_a != input$volcano_level_b,
                  "Choose levels"))
    
    # merge pep + clínica. NO se filtra a los dos niveles del contraste: el lm()
    # se ajusta sobre TODOS los grupos y de ahí se lee el coeficiente A -> B, que
    # es lo que permite pedir A-B, B-C o A-C del mismo modelo. Con dos grupos el
    # resultado es idéntico al t-test pooled que había antes.
    dat <- dplyr::inner_join(pepdata(), active_database(), by = "id") %>%
      dplyr::filter(!is.na(.data[[input$volcano_group_var]])) %>%
      dplyr::mutate(.grp = stats::relevel(
        factor(.data[[input$volcano_group_var]]), ref = input$volcano_level_a))
    
    # columnas peptídicas numéricas
    pep_cols <- setdiff(names(pepdata()), "id")
    is_num   <- vapply(pepdata()[pep_cols], is.numeric, logical(1))
    pep_cols <- pep_cols[is_num]
    
    # isotipos detectados en los datos (prefijo de canal: IgE_, IgG4_, IgA_...)
    isos    <- peptide_isotypes()
    has_iso <- length(isos) > 0

    # columnas elegidas
    if (has_iso) {
      # respetar el filtro del UI; si el usuario desmarca todo, usamos todos los isotipos
      shown   <- intersect(input$volcano_isotypes, isos)
      if (length(shown) == 0) shown <- isos
      chosen  <- grep(paste0("^(", paste(shown, collapse = "|"), ")_"), pep_cols, value = TRUE)
      long <- dat %>%
        dplyr::select(id, .grp, dplyr::all_of(chosen)) %>%
        tidyr::pivot_longer(cols = dplyr::all_of(chosen),
                            names_to = "peptide", values_to = "expr") %>%
        dplyr::mutate(
          expr    = suppressWarnings(as.numeric(expr)),
          isotype = sub("^([^_]+).*", "\\1", peptide)  # IgE / IgG4
        )
    } else {
      # fallback solicitado: mezclar todas las features
      chosen <- pep_cols
      long <- dat %>%
        dplyr::select(id, .grp, dplyr::all_of(chosen)) %>%
        tidyr::pivot_longer(cols = dplyr::all_of(chosen),
                            names_to = "peptide", values_to = "expr") %>%
        dplyr::mutate(
          expr    = suppressWarnings(as.numeric(expr)),
          isotype = factor("Mixed")
        )
    }
    
    # resumen por feature: un lm() por feature, del que se lee el contraste
    # seleccionado. El estimate sigue siendo mean(B) - mean(A) (los datos ya están
    # en escala log/z, así que el fold change es una diferencia, no un cociente),
    # pero el p usa la varianza residual agrupada de todos los grupos.
    lvl_a <- input$volcano_level_a
    lvl_b <- input$volcano_level_b
    res <- long %>%
      dplyr::group_by(peptide, isotype) %>%
      dplyr::group_modify(~ lm_contrast(.x$expr, .x$.grp, lvl_a, lvl_b)) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(
        padj = p.adjust(p, method = "BH"),
        neglog10_p = -log10(p),
        neglog10_padj = -log10(padj),
        group_var = input$volcano_group_var,
        group_A   = input$volcano_level_a,
        group_B   = input$volcano_level_b
      ) %>%
      dplyr::arrange(padj, dplyr::desc(abs(log2FC)))

    res
  })

  # Add status using the current thresholds. Kept separate from volcano_tbl()
  # so moving a threshold recolours instantly without re-running the t-tests.
  volcano_data <- reactive({
    volcano_tbl() %>%
      dplyr::mutate(status = dplyr::case_when(
        padj <= input$volcano_padj_thr & log2FC >=  input$volcano_lfc_thr ~ "Up",
        padj <= input$volcano_padj_thr & log2FC <= -input$volcano_lfc_thr ~ "Down",
        TRUE ~ "NS"
      ))
  })
  
  
  # Volcano plot is now a native D3 module (www/volcano_d3.js). Status, the Y
  # metric and threshold lines are recomputed client-side, so colours/labels
  # refresh instantly when sliders or the axis change.
  volcano_view <- function() list(
    padjThr  = input$volcano_padj_thr,
    lfcThr   = input$volcano_lfc_thr,
    yaxis    = if (is.null(input$volcano_yaxis)) "padj" else input$volcano_yaxis,
    facet    = isTRUE(input$volcano_facet_isotype),
    isotypes = as.list(if (is.null(input$volcano_isotypes)) peptide_isotypes() else input$volcano_isotypes)
  )

  observeEvent(volcano_tbl(), {
    tb <- volcano_tbl()
    rows <- lapply(seq_len(nrow(tb)), function(i) list(
      peptide = tb$peptide[i], isotype = as.character(tb$isotype[i]),
      log2FC = tb$log2FC[i], p = tb$p[i], padj = tb$padj[i],
      neglog10_p = tb$neglog10_p[i], neglog10_padj = tb$neglog10_padj[i],
      nA = tb$nA[i], nB = tb$nB[i]
    ))
    session$sendCustomMessage("volcanoData", list(rows = rows, view = volcano_view()))
  })

  # Threshold / axis / facet / isotype changes only update the view (instant)
  observeEvent(input$volcano_padj_thr,      session$sendCustomMessage("volcanoView", volcano_view()), ignoreInit = TRUE)
  observeEvent(input$volcano_lfc_thr,       session$sendCustomMessage("volcanoView", volcano_view()), ignoreInit = TRUE)
  observeEvent(input$volcano_yaxis,         session$sendCustomMessage("volcanoView", volcano_view()), ignoreInit = TRUE)
  observeEvent(input$volcano_facet_isotype, session$sendCustomMessage("volcanoView", volcano_view()), ignoreInit = TRUE)
  observeEvent(input$volcano_isotypes,      session$sendCustomMessage("volcanoView", volcano_view()), ignoreInit = TRUE)


  # Tabla de “hits”
  output$volcano_hits_table <- DT::renderDT({
    tb <- volcano_data() %>%
      dplyr::mutate(
        meanA = round(meanA, 4),
        meanB = round(meanB, 4),
        log2FC = round(log2FC, 4),
        p = round(p, 4),
        padj = round(padj, 4),
        neglog10_padj = round(neglog10_padj, 4)
      )
    # Significance is a yes/no call, so p and padj are shaded green when they
    # clear the threshold and left plain when they do not. A bar length would
    # only invite reading a magnitude into them.
    thr <- if (is.null(input$volcano_padj_thr)) 0.05 else input$volcano_padj_thr

    DT::datatable(
      tb,
      options = list(pageLength = 10, scrollY = "350px"),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        c('p', 'padj'),
        backgroundColor = DT::styleInterval(thr, c('#e3f4ef', '')),
        color           = DT::styleInterval(thr, c('#0b4f44', '')),
        fontWeight      = DT::styleInterval(thr, c('bold', 'normal'))
      )
  })
  
  # Descarga de resultados
  output$download_volcano_tbl <- downloadHandler(
    filename = function() {
      iso <- paste(input$volcano_isotypes, collapse = "+")
      paste0("volcano_", iso, "_", input$volcano_level_a, "_vs_", input$volcano_level_b, ".csv")
    },
    content = function(file) {
      readr::write_csv(volcano_data(), file)
    }
  )
  
  
  
  ####################### ROC PLOTS ###########################################
  
  # ROC of the selected peptide on its own (in-sample, the same AUC as the
  # results table). Two groups: one curve; more: one-vs-rest per group.
  output$rocs_plot <- renderChart({
    req(tests_filtered(), input$stats_plot_var, input$stats)
    meta <- dplyr::inner_join(pepdata(), active_database(), by = "id")
    req(all(c(input$stats, input$stats_plot_var) %in% names(meta)))
    d <- data.frame(target = meta[[input$stats]], value = meta[[input$stats_plot_var]]) %>%
      dplyr::filter(is.finite(value), !is.na(target)) %>%
      dplyr::mutate(target = droplevels(factor(target)))
    k <- nlevels(d$target)
    if (nrow(d) < 5 || k < 2) return(chart_message("A ROC curve needs at least 5 samples spread over two or more groups."))
    tryCatch({
      fit <- if (k > 2) fit_multinomial_regression(d$value, d$target) else fit_binary_glm(d$value, d$target)
      chart_roc(calculate_roc_curve(d$target, if (k > 2) fit$probabilities else fit$probabilities[, 2]),
                title = input$stats_plot_var,
                subtitle = if (k > 2) "One-vs-rest: one curve per group" else paste("Positive class:", levels(d$target)[2]))
    }, error = function(e) chart_message(paste("The ROC curve could not be computed:", conditionMessage(e)), "error"))
  })
  
  
  # Reactive to filter results by AUC threshold
  results_filtered <- reactive({
    req(tests_filtered())
    req(reg_models())
    req(input$results_auc_threshold)
    
    results_data <- tests_filtered() %>%
      left_join(reg_models() %>% rename(peptide = Peptide), by = "peptide")
    
    # Filter by AUC threshold
    results_data %>% filter(AUC >= input$results_auc_threshold)
  })
  
  # ====== RESULTS KPI BOXES ======
  output$results_kpi_boxes <- renderUI({
    req(results_filtered())
    
    results_data <- results_filtered()
    
    total_selected <- nrow(results_data)
    mean_auc <- mean(results_data$AUC, na.rm = TRUE)
    mean_f1 <- mean(results_data$F1, na.rm = TRUE)
    mean_accuracy <- mean(results_data$Accuracy, na.rm = TRUE)
    
    # Breakdown per isotype found in the data (count only, no up/down without a contrast)
    iso_kpis <- lapply(peptide_isotypes(), function(iso) {
      d <- results_data[startsWith(results_data$peptide, paste0(iso, "_")), ]
      list(label = paste(iso, "Peptides"), value = nrow(d), icon = "dna",
           subtitle = paste0("Mean AUC: ", if (nrow(d) > 0) round(mean(d$AUC, na.rm = TRUE), 2) else 0))
    })

    kpi_data <- c(
      list(list(label = "Selected Peptides", value = total_selected, icon = "check-circle")),
      iso_kpis,
      list(list(label = "Mean AUC", value = round(mean_auc, 2), icon = "bullseye"),
           list(label = "Mean F1", value = round(mean_f1, 2), icon = "trophy"),
           list(label = "Mean Accuracy", value = round(mean_accuracy, 2), icon = "chart-bar"))
    )
    kpi_width <- max(2, 12 %/% length(kpi_data))

    fluidRow(
      lapply(1:length(kpi_data), function(i) {
        kpi <- kpi_data[[i]]
        column(
          width = kpi_width,
          div(
            style = paste0(
              "background: white;",
              "border-radius: 12px;",
              "padding: 20px 15px;",
              "margin-bottom: 15px;",
              "min-height: 142px;",
              "box-shadow: 0 4px 15px rgba(0,0,0,0.1);",
              "transition: transform 0.3s ease, box-shadow 0.3s ease;",
              "position: relative;",
              "overflow: hidden;"
            ),
            # Icon background decoration
            div(
              style = "position: absolute; right: -10px; top: -10px; opacity: 0.03; font-size: 60px; color: #191c32;",
              tags$i(class = paste0("fa fa-", kpi$icon))
            ),
            # Content
            div(
              style = "position: relative; z-index: 2;",
              tags$div(
                style = "align-items: center; margin-bottom: 10px;",
                icon(kpi$icon, style = "font-size: 18px; color: #191c32; margin-right: 8px;"),
                tags$span(kpi$label, style = "font-size: 14px; color: #191c32; font-weight: 600;")
              ),
              tags$div(
                style = "font-size: 32px; font-weight: bold; color: #191c32; margin: 5px 0;",
                kpi$value
              ),
              if (!is.null(kpi$subtitle)) {
                tags$div(
                  style = "font-size: 12px; color: #666; margin-top: 5px;",
                  kpi$subtitle
                )
              } else {
                NULL
              }
            )
          )
        )
      })
    )
  })
  
  # ====== RESULTS DONUT CHART ======
  output$results_donut <- renderChart({
    req(results_filtered())
    isos <- peptide_isotypes()
    req(length(isos) > 0)
    n <- vapply(isos, function(iso) sum(startsWith(results_filtered()$peptide, paste0(iso, "_"))), integer(1))
    chart_donut(isos, n, isotype_colors(isos), center_label = "selected peptides")
  })
  
  # ====== RESULTS SUMMARY TEXT ======
  output$results_summary_text <- renderUI({
    req(results_filtered())
    req(input$results_pval_threshold)
    req(input$results_auc_threshold)
    
    results_data <- results_filtered()
    
    num_peptides <- nrow(results_data)
    
    if (num_peptides == 0) {
      tags$div(
        style = "color: #191c32; padding: 20px;",
        HTML("<h5>No candidate variables identified</h5>
             <p>Try adjusting the p-value or AUC thresholds in the filters section.</p>")
      )
    } else {
      # Top 5 peptides by AUC
      top_peptides <- results_data %>%
        arrange(desc(AUC)) %>%
        head(5)
      
      tags$div(
        style = "color: #191c32;",
        tags$h5("Top 5 Peptides by AUC:", style = "font-weight: bold; margin-bottom: 15px;"),
        tags$ul(
          style = "list-style-type: none; padding: 0;",
          lapply(1:nrow(top_peptides), function(i) {
            tags$li(
              style = "padding: 8px; margin-bottom: 8px; background: rgba(79, 172, 254, 0.1); border-radius: 6px;",
              HTML(sprintf(
                "<strong>%d.</strong> %s<br>
                <small style='color: #666;'>AUC: %.3f | p-adj: %s</small>",
                i,
                top_peptides$peptide[i],
                top_peptides$AUC[i],
                format(top_peptides$p.adj[i], scientific = TRUE, digits = 2)
              ))
            )
          })
        ),
        tags$hr(style = "margin: 20px 0; border-color: rgba(25, 28, 50, 0.1);"),
        tags$div(
          style = "margin-bottom: 15px;",
          tags$h5("Applied Filters:", style = "color: #191c32; font-weight: bold; margin-bottom: 10px;"),
          tags$ul(
            style = "color: #666; line-height: 1.8;",
            tags$li(paste0("Adjusted p-value < ", input$results_pval_threshold)),
            tags$li(paste0("Minimum AUC ≥ ", input$results_auc_threshold)),
            tags$li("Logistic/multinomial regression models applied")
          )
        )
      )
    }
  })
  
  # ====== FUNNEL: estado global de selección ===================================
  selected_biomarkers <- reactiveVal(character(0))   # candidates sent from the Peptide tab (ML input)
  consensus_biomarkers <- reactiveVal(character(0))  # consensus sent from ML (protein maps, report)
  
  # Ranking combinando p.adj (↑ significancia) y AUC (↑ rendimiento)
  ml_ranked_peptides <- reactive({
    req(results_filtered())
    
    base <- results_filtered() %>% dplyr::select(peptide, p.adj, AUC, dplyr::any_of("Accuracy"))
    
    base %>%
      dplyr::mutate(
        score = (-log10(p.adj)) + AUC
      ) %>%
      dplyr::arrange(dplyr::desc(score))
  })
  
  # Apply selection when button is clicked
  # ML biomarker selection
  selected_peptides_ml <- reactiveVal(NULL)
  
  observeEvent(input$ml_select_peptides, {
    req(ml_ranked_peptides())
    
    ranked <- ml_ranked_peptides()
    
    if (input$ml_selection_method == "top_n") {
      # Select top N peptides
      n <- min(input$ml_top_n, nrow(ranked))
      selected <- ranked$peptide[1:n]
    } else {
      # Select by AUC threshold
      selected <- ranked %>%
        filter(AUC >= input$ml_auc_threshold) %>%
        pull(peptide)
    }
    
    selected_peptides_ml(selected)
    
    showNotification(
      paste(length(selected), "peptides selected"),
      type = "message"
    )
  })
  
  # Summary of selected peptides
  output$ml_selection_summary <- renderUI({
    selected <- selected_peptides_ml()
    
    if (is.null(selected) || length(selected) == 0) {
      return(
        tags$div(
          style = "text-align: center; color: #666;",
          icon("info-circle", style = "font-size: 48px; margin-bottom: 15px; color: #667eea;"),
          tags$p("Click 'Apply Selection' to choose biomarkers", style = "font-size: 16px; margin: 0;")
        )
      )
    }
    
    ranked <- ml_ranked_peptides()
    selected_data <- ranked %>% filter(peptide %in% selected)
    
    tags$div(
      style = "text-align: center;",
      tags$div(
        style = "font-size: 48px; font-weight: bold; color: #667eea; margin-bottom: 10px;",
        length(selected)
      ),
      tags$div(
        style = "font-size: 18px; color: #191c32; font-weight: 600; margin-bottom: 20px;",
        "Peptides Selected"
      ),
      tags$hr(style = "margin: 20px 0;"),
      tags$div(
        style = "font-size: 14px; color: #191c32;",
        tags$p(
          tags$strong("Mean AUC:"), " ", 
          round(mean(selected_data$AUC, na.rm = TRUE), 3),
          style = "margin: 5px 0;"
        ),
        tags$p(
          tags$strong("Mean Accuracy:"), " ", 
          round(mean(selected_data$Accuracy, na.rm = TRUE), 3),
          style = "margin: 5px 0;"
        ),
        tags$p(
          tags$strong("Mean p-adj:"), " ", 
          format(mean(selected_data$p.adj, na.rm = TRUE), scientific = TRUE, digits = 3),
          style = "margin: 5px 0;"
        )
      )
    )
  })
  
  # Send selected peptides to ML tab
  observeEvent(input$ml_send_to_tab, {
    sel <- selected_peptides_ml()
    if (is.null(sel) || length(sel) == 0) {
      showNotification("Click 'Apply Selection' first to choose peptides.", type = "warning")
      return(NULL)
    }
    selected_biomarkers(sel)
    log_step("SELECT", "Candidates sent to Machine Learning", n = length(sel), rule = input$ml_selection_method,
             top_n = if (identical(input$ml_selection_method, "top_n")) input$ml_top_n,
             auc_threshold = if (!identical(input$ml_selection_method, "top_n")) input$ml_auc_threshold, peptides = sel)
    showNotification(
      paste(length(sel), "biomarkers sent to Machine Learning tab."), 
      type = "message",
      duration = 5
    )
    
    # Switch to ML tab automatically
    updateTabsetPanel(session, "main_tabs", selected = "Machine Learning")
  })
  # ============================================================================
  
  # ====== Conjunto de péptidos activos para ML (aplica el filtro del funnel) ===
  active_pepdata <- reactive({
    req(pepdata())
    p <- pepdata()
    sel <- selected_biomarkers()
    
    if (!is.null(sel) && length(sel) > 0) {
      keep <- intersect(colnames(p), c("id", sel))
      if (length(keep) < 2) {
        showNotification("Ninguno de los péptidos seleccionados está en la matriz. Uso todos.", type = "warning")
        return(p)
      }
      p[, keep, drop = FALSE]
    } else {
      p
    }
  })
  
  # ====== Conjunto COMPLETO de péptidos para Protein Visualization (SIN filtrar) ===
  full_pepdata <- reactive({
    req(pepdata())
    pepdata()  # Devuelve TODA la matriz sin filtrar
  })
  
  meta_data_ML <- reactive({
    req(active_pepdata(), active_database())
    dplyr::inner_join(active_pepdata(), active_database(), by = "id")
  })
  
  ############################### Combined #####################################
  
  meta_data <- reactive({
    req(pepdata())
    req(active_database())
    tmp1 <- pepdata()
    tmp2 <- active_database()
    
    # DEBUG
    cat("\n=== META_DATA JOIN DEBUG ===")
    cat("\npepdata columns:", paste(head(colnames(tmp1), 10), collapse = ", "))
    cat("\ndatabase columns:", paste(colnames(tmp2), collapse = ", "))
    cat("\n'id' in pepdata:", "id" %in% colnames(tmp1))
    cat("\n'id' in database:", "id" %in% colnames(tmp2))
    cat("\n")
    
    dplyr::inner_join(tmp1, tmp2, by = "id")
  })
  
  
  output$target_hgroup <- renderUI({
    req(database())
    selectInput("h_target", "Target Variable",
                multiple = TRUE,
                choices = colnames(meta_data_ML() %>% 
                                     dplyr::select((ncol(active_pepdata()) +1):ncol(meta_data_ML())) %>% 
                                     as.data.frame()),
                selected = 1) ## PODRIA MEJORARSE CON SOLO CARACTERES
  })
  
  ################ HEATMAP CON ANOTACION ######################################
  
  rowa <- reactive({
    target_var <- active_target_var()
    req(target_var)
    df <- meta_data_ML()
    df %>% dplyr::select(all_of(target_var))
  })
  
  output$comb_table <- renderTable({
    req(rowa())
    df <- as.data.frame(rowa())
    gt::gt(prop.table(df))
  })
  
  output$Combined_hplot <- renderPlot({
    req(input$ml_use_heatmap)  # Only render if selected
    req(active_pepdata(), meta_data_ML(), rowa())
    
    df <- meta_data_ML()
    
    mat <- df %>%
      dplyr::select(1:ncol(active_pepdata())) %>%
      tibble::column_to_rownames("id") %>%
      as.matrix()
    mat[] <- lapply(as.data.frame(mat), function(x) suppressWarnings(as.numeric(x))) %>% as.data.frame() %>% as.matrix()
    
    ann <- as.data.frame(lapply(rowa(), function(x) as.factor(as.character(x))))
    rownames(ann) <- rownames(mat)
    ann <- ann[rownames(mat), , drop = FALSE]
    ra  <- ComplexHeatmap::rowAnnotation(df = ann)
    
    iso <- split_isotype_mats(mat)
    
    # Define color palette matching Peptide heatmap (dark background for 0 values)
    ige_colors <- colorRampPalette(c("#191c32","lightgreen", "green"))(50)
    igg4_colors <- colorRampPalette(c("#191c32", "#fd6b6bff", "red"))(50)
    default_colors <- colorRampPalette(c("#191c32", "lightgreen", "green"))(50)
    
    if (iso$any_iso) {
      ht_list <- NULL
      if (!is.null(iso$ige) && ncol(iso$ige) > 0) {
        ht_ige <- ComplexHeatmap::Heatmap(
          iso$ige, name = iso$names[1],
          col = ige_colors,
          cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
          show_column_names = FALSE,
          show_row_names = FALSE,
          row_dend_gp = grid::gpar(col = "#191c32"),
          column_dend_gp = grid::gpar(col = "#191c32"),
          heatmap_legend_param = list(
            border = "#191c32",
            title_gp = grid::gpar(fontsize = 10, fontface = "bold", col = "#191c32"),
            labels_gp = grid::gpar(fontsize = 9, col = "#191c32")
          )
        )
        ht_list <- ht_ige
      }
      if (!is.null(iso$igg4) && ncol(iso$igg4) > 0) {
        ht_igg4 <- ComplexHeatmap::Heatmap(
          iso$igg4, name = iso$names[2],
          col = igg4_colors,
          cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
          show_column_names = FALSE,
          show_row_names = FALSE,
          row_dend_gp = grid::gpar(col = "#191c32"),
          column_dend_gp = grid::gpar(col = "#191c32"),
          heatmap_legend_param = list(
            border = "#191c32",
            title_gp = grid::gpar(fontsize = 10, fontface = "bold", col = "#191c32"),
            labels_gp = grid::gpar(fontsize = 9, col = "#191c32")
          )
        )
        ht_list <- if (is.null(ht_list)) ht_igg4 else (ht_list + ht_igg4)
      }
      ComplexHeatmap::draw(
        ra + ht_list, 
        heatmap_legend_side = "right", 
        annotation_legend_side = "right",
        background = "transparent"
      )
    } else {
      ht <- ComplexHeatmap::Heatmap(
        mat, name = "Expression",
        col = default_colors,
        cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
        show_column_names = FALSE,
        show_row_names = FALSE,
        heatmap_legend_param = list(
          border = "#191c32",
          title_gp = grid::gpar(fontsize = 10, fontface = "bold"),
          labels_gp = grid::gpar(fontsize = 9)
        )
      )
      ComplexHeatmap::draw(
        ra + ht, 
        heatmap_legend_side = "right", 
        annotation_legend_side = "right",
        background = "transparent"
      )
    }
  }, bg = "transparent")
  outputOptions(output, "Combined_hplot", suspendWhenHidden = FALSE)
  
  
  
  
  
  
  
  ######################### PCA  + 3D #########################################
  
  ## INPUT 
  
  output$target_PCA <- renderUI({
    req(database())
    req(active_pepdata())
    selectInput("PCA_target", 
                label = tags$span(style = "color: #ffffff;", "Target Variable for Machine Learning analysis"),
                choices = colnames(meta_data_ML() %>% 
                                     dplyr::select((ncol(active_pepdata()) +1):ncol(meta_data_ML())) %>% 
                                     as.data.frame())) 
  })
  
  
  ########################## PLOT PCA ############################################
  # Groups for the unsupervised plots; waits until the target exists in the data
  ml_groups <- reactive({
    req(active_target_var() %in% names(meta_data_ML()))
    extract_target_groups(meta_data_ML(), active_target_var())
  })

  # One PCA (scaled, constant peptides dropped) behind the 2D and 3D views
  pca_fit <- reactive({
    X <- meta_data_ML() %>% dplyr::select(1:ncol(active_pepdata())) %>% dplyr::select(-id) %>% dplyr::select(where(is.numeric))
    X[is.na(X)] <- 0
    stats::prcomp(X[, vapply(X, function(v) stats::var(v) > 0, logical(1)), drop = FALSE], center = TRUE, scale. = TRUE)
  })
  pca_var <- reactive(round(100 * pca_fit()$sdev^2 / sum(pca_fit()$sdev^2), 1))

  output$PCA_2d <- renderChart({
    req(input$ml_use_pca)
    s <- as.data.frame(pca_fit()$x); v <- pca_var(); g <- ml_groups(); id <- meta_data_ML()$id
    chart_scatter(s$PC1, s$PC2, g, id, sample_tip(id, g, PC1 = s$PC1, PC2 = s$PC2),
                  xlab = sprintf("PC1 (%s %% variance)", v[1]), ylab = sprintf("PC2 (%s %% variance)", v[2]))
  })
  
  PCA_mod <- reactive({
    df1 <- meta_data_ML()
    PCA_DB <- df1 %>% dplyr::select(1: ncol(active_pepdata())) %>% select_if(is.numeric)
    PCA_DB[is.na(PCA_DB)] <- 0
    
    # Use modular PCA function
    compute_pca(PCA_DB, center = TRUE, scale. = FALSE)
  })
  

  output$d3_PCA <- renderChart({
    req(input$ml_use_pca)
    s <- as.data.frame(pca_fit()$x); req(ncol(s) >= 3)
    v <- pca_var(); g <- ml_groups(); id <- meta_data_ML()$id
    chart_scatter3d(s$PC1, s$PC2, s$PC3, g, id, sample_tip(id, g, PC1 = s$PC1, PC2 = s$PC2, PC3 = s$PC3),
                    labels = sprintf("PC%d (%s%%)", 1:3, v[1:3]))
  })
  
  ########################## PCoA dist.matrix ############################################
  pcoa_dist_matrix <- reactive({
    req(input$pcoa_distance_method)
    
    # Use modular distance matrix function
    compute_distance_matrix(
      data = meta_data_ML(),
      group_var = active_target_var(),
      distance_method = input$pcoa_distance_method,
      scale_data = TRUE,
      impute_na = TRUE
    )
  })
  
  ########################## NMDS dist.matrix ############################################
  nmds_dist_matrix <- reactive({
    req(input$nmds_distance_method)
    
    # Use modular distance matrix function
    compute_distance_matrix(
      data = meta_data_ML(),
      group_var = active_target_var(),
      distance_method = input$nmds_distance_method,
      scale_data = TRUE,
      impute_na = TRUE
    )
  })
  
  ########################## PLOT PCoA ############################################
  
  output$PCoA_2d <- renderChart({
    req(input$ml_use_pcoa)
    s <- perform_pcoa(pcoa_dist_matrix(), k = 2); g <- ml_groups(); id <- meta_data_ML()$id
    chart_scatter(s$pcoa1, s$pcoa2, g, id, sample_tip(id, g, PCoA1 = s$pcoa1, PCoA2 = s$pcoa2),
                  xlab = "PCoA axis 1", ylab = "PCoA axis 2")
  })

  output$PCoA_3d <- renderChart({
    req(input$ml_use_pcoa)
    s <- perform_pcoa(pcoa_dist_matrix(), k = 3); g <- ml_groups(); id <- meta_data_ML()$id
    chart_scatter3d(s$pcoa1, s$pcoa2, s$pcoa3, g, id,
                    sample_tip(id, g, PCoA1 = s$pcoa1, PCoA2 = s$pcoa2, PCoA3 = s$pcoa3), labels = paste("PCoA axis", 1:3))
  })
  
  
  ########################## PLOT NMDS ############################################
  output$NMDS_2d <- renderChart({
    req(input$ml_use_nmds)
    s <- perform_nmds(nmds_dist_matrix(), k = 2); g <- ml_groups(); id <- meta_data_ML()$id
    chart_scatter(s$NMDS1, s$NMDS2, g, id, sample_tip(id, g, NMDS1 = s$NMDS1, NMDS2 = s$NMDS2),
                  xlab = "NMDS 1", ylab = "NMDS 2")
  })

  output$NMDS_3d <- renderChart({
    req(input$ml_use_nmds)
    s <- perform_nmds(nmds_dist_matrix(), k = 3); g <- ml_groups(); id <- meta_data_ML()$id
    chart_scatter3d(s$NMDS1, s$NMDS2, s$NMDS3, g, id,
                    sample_tip(id, g, NMDS1 = s$NMDS1, NMDS2 = s$NMDS2, NMDS3 = s$NMDS3), labels = paste("NMDS", 1:3))
  })
  
  ########################## DBSCAN CLUSTERING ############################################
  
  # One DBSCAN run on the first two PCs, shared by the plot and the metrics
  dbscan_fit <- reactive({
    req(input$ml_use_dbscan)
    eps <- if (!is.null(input$dbscan_eps)) input$dbscan_eps else 2.0
    minpts <- if (!is.null(input$dbscan_minpts)) input$dbscan_minpts else 5
    coords <- PCA_mod()[, 1:2]
    list(coords = coords, eps = eps, minpts = minpts, result = dbscan::dbscan(coords, eps = eps, minPts = minpts))
  })

  output$dbscan_plot <- renderChart({
    fit <- dbscan_fit()
    pca_coords <- fit$coords
    groups <- ml_groups()
    sample_ids <- meta_data_ML()$id
    eps_value <- fit$eps
    minpts_value <- fit$minpts
    db_result <- fit$result
    
    # Create plot data
    plot_data <- data.frame(
      PC1 = pca_coords[, 1],
      PC2 = pca_coords[, 2],
      Cluster = factor(db_result$cluster),
      True_Group = groups,
      Sample_ID = sample_ids
    )
    
    # Cluster 0 = noise/outliers
    plot_data$Cluster_Label <- ifelse(plot_data$Cluster == "0", "Noise", 
                                       paste("Cluster", plot_data$Cluster))
    
    chart_scatter(plot_data$PC1, plot_data$PC2, groups, sample_ids,
                  paste0(sample_ids, "\nTrue group: ", groups, "\nDBSCAN: ", plot_data$Cluster_Label),
                  xlab = "PC1", ylab = "PC2", ellipse = FALSE, shape = plot_data$Cluster_Label,
                  group_title = "True group", shape_title = "DBSCAN cluster",
                  subtitle = paste0("eps = ", round(eps_value, 2), " · minPts = ", minpts_value,
                                    " · clusters: ", max(db_result$cluster), " · noise points: ", sum(db_result$cluster == 0)))
  })
  
  output$dbscan_metrics <- renderUI({
    # Same run as the plot (it used fixed eps = 0.5, minPts = 3 and disagreed)
    pca_coords <- dbscan_fit()$coords
    db_result <- dbscan_fit()$result
    
    n_clusters <- max(db_result$cluster)
    n_noise <- sum(db_result$cluster == 0)
    n_samples <- nrow(pca_coords)
    
    # Silhouette needs at least 2 non-noise clusters, else silhouette() returns NA
    sil_score <- NA
    non_noise_idx <- db_result$cluster != 0
    if (length(unique(db_result$cluster[non_noise_idx])) >= 2) {
      sil <- cluster::silhouette(db_result$cluster[non_noise_idx],
                                 dist(pca_coords[non_noise_idx, ]))
      if (is.matrix(sil)) sil_score <- round(mean(sil[, 3]), 3)
    }
    
    tagList(
      tags$div(
        style = "background: #f5f5f5; padding: 15px; border-radius: 8px;",
        tags$h6("Clustering Summary", style = "color: #191c32; font-weight: 600; margin-bottom: 15px;"),
        tags$table(
          style = "width: 100%; border-collapse: collapse;",
          tags$tr(
            tags$td(strong("Number of Clusters:"), style = "padding: 8px 0;"),
            tags$td(n_clusters, style = "padding: 8px 0; text-align: right; color: #667eea; font-weight: 600;")
          ),
          tags$tr(
            tags$td(strong("Noise Points:"), style = "padding: 8px 0;"),
            tags$td(paste0(n_noise, " (", round(n_noise/n_samples*100, 1), "%)"), 
                   style = "padding: 8px 0; text-align: right;")
          ),
          tags$tr(
            tags$td(strong("Clustered Points:"), style = "padding: 8px 0;"),
            tags$td(paste0(n_samples - n_noise, " (", round((n_samples-n_noise)/n_samples*100, 1), "%)"), 
                   style = "padding: 8px 0; text-align: right;")
          ),
          tags$tr(
            tags$td(strong("Silhouette Score:"), style = "padding: 8px 0;"),
            tags$td(ifelse(is.na(sil_score), "N/A", sil_score), 
                   style = "padding: 8px 0; text-align: right;")
          )
        )
      ),
      tags$br(),
      tags$div(
        style = "background: #e3f2fd; padding: 12px; border-radius: 4px; border-left: 4px solid #2196F3;",
        tags$small(
          style = "color: #0d47a1;",
          icon("info-circle", style = "margin-right: 5px;"),
          strong("Note: "),
          "DBSCAN clusters are found based on density. Points marked as 'Noise' don't belong to any dense region."
        )
      )
    )
  })
  
  ########################## PLS-DA ANALYSIS ############################################
  
  output$plsda_score_plot <- renderChart({
    req(input$ml_use_plsda)
    
    # Prepare data
    X <- meta_data_ML() %>% 
      dplyr::select(1:ncol(active_pepdata())) %>% 
      dplyr::select(-id) %>%
      select_if(is.numeric)
    
    Y <- ml_groups()
    sample_ids <- meta_data_ML()$id
    
    # Remove NA and ensure proper format
    X[is.na(X)] <- 0
    X <- as.matrix(X)
    Y <- as.factor(Y)
    
    # Perform PLS-DA
    plsda_result <- mixOmics::plsda(X, Y, ncomp = 2)
    
    scores <- as.data.frame(plsda_result$variates$X)
    var_exp <- round(100 * plsda_result$prop_expl_var$X, 1)
    chart_scatter(scores$comp1, scores$comp2, Y, sample_ids,
                  sample_tip(sample_ids, Y, Comp1 = scores$comp1, Comp2 = scores$comp2),
                  xlab = sprintf("Component 1 (%s %%)", var_exp[1]), ylab = sprintf("Component 2 (%s %%)", var_exp[2]))
  })
  
  output$plsda_metrics <- renderUI({
    req(input$ml_use_plsda)
    
    # Prepare data
    X <- meta_data_ML() %>% 
      dplyr::select(1:ncol(active_pepdata())) %>% 
      dplyr::select(-id) %>%
      select_if(is.numeric)
    
    Y <- ml_groups()
    
    # Remove NA
    X[is.na(X)] <- 0
    X <- as.matrix(X)
    Y <- as.factor(Y)
    small <- names(which(table(Y) < 2))
    if (length(small)) {
      return(tags$div(class = "mai-chart-msg error", tags$span("!"), tags$p(
        "Cross-validated PLS-DA needs at least 2 samples per group; these groups have one: ",
        paste(small, collapse = ", "), ". If the target is a numeric variable, choose a categorical one.")))
    }
    
    # Perform PLS-DA with cross-validation
    plsda_result <- mixOmics::plsda(X, Y, ncomp = 2)
    
    # Perform cross-validation
    set.seed(123)
    plsda_perf <- mixOmics::perf(plsda_result, validation = "Mfold", 
                                 folds = 5, nrepeat = 10)
    
    # Get error rates - usar max.dist o BER según disponibilidad
    error_rate_matrix <- plsda_perf$error.rate$overall
    if("max.dist" %in% colnames(error_rate_matrix)) {
      error_rate <- error_rate_matrix["comp2", "max.dist"]
    } else if("BER" %in% colnames(error_rate_matrix)) {
      error_rate <- error_rate_matrix["comp2", "BER"]
    } else {
      error_rate <- error_rate_matrix["comp2", 1]
    }
    
    tagList(
      tags$div(
        style = "background: #f5f5f5; padding: 15px; border-radius: 8px;",
        tags$h6("Model Performance (5-Fold CV)", style = "color: #191c32; font-weight: 600; margin-bottom: 15px;"),
        tags$table(
          style = "width: 100%; border-collapse: collapse;",
          tags$tr(
            tags$td(strong("Classification Error:"), style = "padding: 8px 0;"),
            tags$td(paste0(round(error_rate * 100, 1), "%"), 
                   style = "padding: 8px 0; text-align: right; color: #667eea; font-weight: 600;")
          ),
          tags$tr(
            tags$td(strong("Accuracy:"), style = "padding: 8px 0;"),
            tags$td(paste0(round((1 - error_rate) * 100, 1), "%"), 
                   style = "padding: 8px 0; text-align: right; color: #4caf50; font-weight: 600;")
          ),
          tags$tr(
            tags$td(strong("Number of Components:"), style = "padding: 8px 0;"),
            tags$td("2", style = "padding: 8px 0; text-align: right;")
          ),
          tags$tr(
            tags$td(strong("Number of Variables:"), style = "padding: 8px 0;"),
            tags$td(ncol(X), style = "padding: 8px 0; text-align: right;")
          )
        )
      )
    )
  })
  
  output$plsda_vip_plot <- renderPlot({
    req(input$ml_use_plsda)
    
    # Prepare data
    X <- meta_data_ML() %>% 
      dplyr::select(1:ncol(active_pepdata())) %>% 
      dplyr::select(-id) %>%
      select_if(is.numeric)
    
    Y <- ml_groups()
    
    # Remove NA
    X[is.na(X)] <- 0
    X <- as.matrix(X)
    Y <- as.factor(Y)
    
    # Perform PLS-DA
    plsda_result <- mixOmics::plsda(X, Y, ncomp = 2)
    
    # Calculate VIP scores
    vip_scores <- mixOmics::vip(plsda_result)
    
    # Get top 15 variables
    vip_df <- data.frame(
      Variable = rownames(vip_scores),
      VIP = vip_scores[, 1]
    ) %>%
      arrange(desc(VIP)) %>%
      slice_head(n = 15)
    
    # Plot
    ggplot(vip_df, aes(x = reorder(Variable, VIP), y = VIP)) +
      geom_bar(stat = "identity", fill = "#667eea", alpha = 0.8) +
      geom_hline(yintercept = 1, linetype = "dashed", color = "red", linewidth = 1) +
      coord_flip() +
      labs(
        title = "Top 15 Variables by VIP Score",
        subtitle = "Variables with VIP > 1 are considered important",
        x = "Variable",
        y = "VIP Score"
      ) +
      theme_microarrai() +
      theme(axis.text.y = element_text(size = 9))
  })
  
  ####### Supervised machine learning ####
  
  # Model input: peptides BEFORE imputation plus the target. Imputation,
  # candidate selection and fitting happen in ml_prep() on training rows only
  # (R/server/ml_validation.R), so no test sample leaks into the model.
  ml_input <- reactive({
    req(raw_pepdata(), active_database(), active_target_var())
    target <- active_target_var()
    d <- dplyr::inner_join(raw_pepdata(), active_database()[, c("id", target)], by = "id") %>%
      dplyr::rename(target = !!rlang::sym(target)) %>%
      dplyr::filter(!is.na(target)) %>%
      as.data.frame() %>%
      tibble::column_to_rownames("id")
    d$target <- droplevels(factor(d$target))
    levels(d$target) <- make.names(levels(d$target), unique = TRUE)  # caret needs syntactic class names
    d[, c("target", setdiff(names(d), "target"))]
  })

  # Candidate rule chosen in the Peptide Analysis funnel, re-applied on the
  # training rows. Without a funnel selection every peptide is a candidate.
  ml_criteria <- reactive({
    if (length(selected_biomarkers()) == 0) return(list(method = "all"))
    list(method = input$ml_selection_method, padj_max = input$results_pval_threshold,
         auc_min = input$results_auc_threshold, top_n = input$ml_top_n,
         auc_threshold = input$ml_auc_threshold)
  })

  ml_impute_method <- reactive(if (is.null(input$imputation_method)) "knn" else input$imputation_method)
  ml_seed <- reactive(if (is.null(input$ml_seed) || is.na(input$ml_seed)) ML_DEFAULT_SEED else as.integer(input$ml_seed))
  ml_mode <- reactive(if (is.null(input$ml_validation_mode)) "holdout" else input$ml_validation_mode)

  # Split plus training-only imputation and selection, shared by every model so
  # all of them are scored on the same test samples.
  ml_prep <- eventReactive(input$ml_run_pipeline, {
    # First thing the pipeline does, so the request heads the ML log lines
    log_step("ML", "Pipeline requested", target = input$ml_target_var,
             supervised = c("C5.0", "RF", "SVM", "XGBoost")[c(isTRUE(input$ml_use_c50), isTRUE(input$ml_use_rf), isTRUE(input$ml_use_svm), isTRUE(input$ml_use_xgboost))],
             unsupervised = c("heatmap", "PCA", "PCoA", "NMDS", "DBSCAN", "PLS-DA")[c(isTRUE(input$ml_use_heatmap), isTRUE(input$ml_use_pca), isTRUE(input$ml_use_pcoa), isTRUE(input$ml_use_nmds), isTRUE(input$ml_use_dbscan), isTRUE(input$ml_use_plsda))],
             validation = ml_mode(), seed = ml_seed(), candidates_from_peptide_tab = length(selected_biomarkers()))
    d <- ml_input()
    # A numeric clinical variable (e.g. a 3-10 score) makes one class per value,
    # many with a single sample: every fold then lacks a class and all models fail.
    counts <- table(d$target)
    small <- names(counts)[counts < ML_CV_FOLDS]
    if (length(small)) log_step("ML", "Training refused", level = "WARN", target = active_target_var(),
                                groups = paste0(names(counts), "=", as.integer(counts)),
                                why = sprintf("%d groups have fewer than %d samples", length(small), ML_CV_FOLDS),
                                hint = "Choose a categorical target, or group a numeric one (e.g. low / high)")
    validate(need(length(small) == 0, sprintf(paste(
      "Classification needs at least %d samples in every group of '%s', and %d of its %d groups have fewer (%s).",
      "If it is a numeric variable, choose a categorical one or group its values first."),
      ML_CV_FOLDS, active_target_var(), length(small), length(counts), paste(utils::head(small, 6), collapse = ", "))))
    if (ml_mode() == "nested") {
      full <- impute_missing(d, method = ml_impute_method())
      return(list(mode = "nested", data = d,
                  train = full[, c("target", select_candidates(full, ml_criteria())), drop = FALSE]))
    }
    s <- split_holdout(d, seed = ml_seed())
    p <- c(list(mode = "holdout", data = d),
           prepare_partition(s$train, s$test, ml_impute_method(), ml_criteria()))
    log_step("ML", "Hold-out split ready", seed = ml_seed(), train = nrow(p$train), test = nrow(p$test),
             test_groups = paste0(names(table(p$test$target)), "=", as.integer(table(p$test$target))),
             candidates = length(p$candidates), candidate_rule = ml_criteria()$method, imputation = ml_impute_method())
    p
  })

  # Training rows behind the model-specific plots (C5.0 tree, SHAP, SVM 3D)
  ml_train_data <- reactive(ml_prep()$train)

  ml_fit <- function(model_type, label) {
    p <- ml_prep()
    opts <- list(use_rfe = isTRUE(input$ml_use_rfe), use_cv = !isFALSE(input$ml_use_cv),
                 tune_params = isTRUE(input$ml_use_tuning))
    log_step("ML", paste("START training", label), validation = p$mode, rfe = opts$use_rfe, cv = opts$use_cv,
             tuning = opts$tune_params, predictors = ncol(p$train) - 1, training_samples = nrow(p$train))
    t0 <- Sys.time()
    res <- tryCatch(withProgress(message = paste0("Training ", label, "..."), value = 0.3, {
      if (p$mode == "nested") {
        do.call(run_nested_cv, c(list(p$data, model_type, ml_impute_method(), ml_criteria(), ml_seed()), opts))
      } else {
        do.call(fit_holdout, c(list(p, model_type), opts))
      }
    }), error = function(e) {
      # Logged here, re-raised so the model's panel can still say why
      if (!inherits(e, c("shiny.silent.error", "validation")))
        log_step("ML", paste("FAILED training", label), level = "ERROR", why = conditionMessage(e),
                 hint = "Check the class sizes in the log above; try without RFE or with nested CV for small cohorts")
      stop(e)
    })
    if (isTRUE(res$skipped)) {
      log_step("ML", paste(label, "skipped"), level = "WARN", why = res$skip_reason)
    } else {
      m <- res$metrics
      log_step("ML", sprintf("DONE training %s in %.1f s", label, as.numeric(difftime(Sys.time(), t0, units = "secs"))),
               test_auc = m$auc, auc_95ci = c(m$auc_low, m$auc_high), accuracy = m$accuracy, kappa = m$kappa,
               rfe_used = res$rfe_used, features = length(res$selected_features))
    }
    res
  }

  # Runs an ML training reactive and keeps the error instead of collapsing a
  # failure to a bare NULL, so panels can say WHY training failed instead of
  # going quietly blank.
  capture_ml_result <- function(reactive_call) {
    tryCatch(list(result = reactive_call(), error = NULL),
             error = function(e) {
               # An empty message is req()/validate() not satisfied yet (e.g.
               # the pipeline hasn't been run), not a real training failure.
               msg <- conditionMessage(e)
               list(result = NULL, error = if (nzchar(msg)) msg else NULL)
             })
  }

  # Same assessment used by train_model_advanced(), reused here so the
  # disclaimer shows up BEFORE the user clicks "Run" (and doesn't require a
  # successful training run to be seen).
  ml_size_check <- reactive({
    # Only evaluate once an actual training attempt has been made (the user
    # clicked "Run ML Pipeline"), not as soon as a target variable is picked —
    # a disclaimer nobody asked for yet is just noise.
    # Assess what the models actually see: training rows and the candidates
    # chosen on them, not every peptide in the matrix.
    req(input$ml_run_pipeline)
    tr <- ml_prep()$train
    ml_sample_size_check(
      n = nrow(tr), class_counts = table(tr$target), n_features = ncol(tr) - 1,
      cv_folds = ML_CV_FOLDS
    )
  })

  output$ml_sample_size_banner <- renderUI({
    check <- tryCatch(ml_size_check(), error = function(e) NULL)
    ml_disclaimer_banner(check)
  })

  # Which validation scheme suits this sample size, shown next to the selector
  output$ml_validation_hint <- renderUI({
    d <- tryCatch(ml_input(), error = function(e) NULL)
    if (is.null(d)) return(NULL)
    n_feat <- if (length(selected_biomarkers()) > 0) length(selected_biomarkers()) else ncol(d) - 1
    rec <- recommend_validation(table(d$target), n_feat)
    tags$small(icon("lightbulb", style = "margin-right: 4px;"), rec$reason,
               style = "color: #0066cc; font-size: 11px; display: block; margin-top: 6px;")
  })

  # ===== TRAINING REACTIVES =====
  c50_advanced_result     <- eventReactive(input$ml_run_pipeline, { req(input$ml_use_c50);     ml_fit("c50", "C5.0") })
  rf_advanced_result      <- eventReactive(input$ml_run_pipeline, { req(input$ml_use_rf);      ml_fit("rf", "Random Forest") })
  svm_advanced_result     <- eventReactive(input$ml_run_pipeline, { req(input$ml_use_svm);     ml_fit("svm", "SVM") })
  xgboost_advanced_result <- eventReactive(input$ml_run_pipeline, { req(input$ml_use_xgboost); ml_fit("xgboost", "XGBoost") })

  # Independent-test metrics for every trained model, CV shown as reference
  output$ml_validation_summary <- renderUI({
    p <- tryCatch(ml_prep(), error = function(e) NULL)
    req(p)
    runs <- list("C5.0" = c50_advanced_result, "Random Forest" = rf_advanced_result,
                 "SVM" = svm_advanced_result, "XGBoost" = xgboost_advanced_result)
    used <- c(isTRUE(input$ml_use_c50), isTRUE(input$ml_use_rf),
              isTRUE(input$ml_use_svm), isTRUE(input$ml_use_xgboost))
    fmt <- function(x) if (is.null(x) || is.na(x)) "\u2014" else sprintf("%.2f", x)

    rows <- lapply(names(runs)[used], function(nm) {
      r <- capture_ml_result(runs[[nm]])$result
      if (is.null(r) || isTRUE(r$skipped) || is.null(r$validation)) return(NULL)
      m <- r$metrics
      ci <- if (is.na(m$auc_low)) "" else sprintf(" [%.2f\u2013%.2f]", m$auc_low, m$auc_high)
      tags$tr(tags$td(tags$strong(nm)), tags$td(paste0(fmt(m$auc), ci)), tags$td(fmt(m$accuracy)),
              tags$td(fmt(m$kappa)), tags$td(fmt(m$sensitivity)), tags$td(fmt(m$specificity)),
              tags$td(fmt(r$cv_metrics$auc), style = "color: #999;"))
    })

    header <- if (p$mode == "nested") {
      sprintf("Nested cross-validation: %d outer folds, every one of the %d samples predicted by a model that never saw it.",
              ML_OUTER_FOLDS, nrow(p$data))
    } else {
      sprintf("Independent test set: %d samples (%d%%, stratified, seed %d), never used for imputation, peptide selection, RFE or tuning. Training: %d samples, %d candidate peptides.",
              nrow(p$test), round(100 * ML_TEST_PROP), ml_seed(), nrow(p$train), length(p$candidates))
    }

    card_container(
      style = "margin: 0 15px; padding: 25px;",
      tags$p(icon("shield-alt", style = "color: #17a589; margin-right: 8px;"), header,
             style = "color: #191c32; font-size: 14px;"),
      tags$table(
        class = "table table-sm", style = "color: #191c32; text-align: center;",
        tags$thead(tags$tr(lapply(c("Model", "AUC [95% CI]", "Accuracy", "Kappa", "Sensitivity",
                                    "Specificity", "CV AUC (reference)"), tags$th))),
        tags$tbody(rows)
      ),
      tags$small(if (p$mode == "nested") "Metrics pooled over the outer folds. CV AUC is the inner cross-validation of the final model, shown for reference only."
                 else "Metrics on the test set. CV AUC is the cross-validation inside the training set, shown for reference only.",
                 style = "color: #666;")
    )
  })

  # ===== DYNAMIC PANEL OUTPUTS =====
  
  # C5.0 Panel
  output$c50_panel_content <- renderUI({
    req(input$ml_use_c50)

    outcome <- capture_ml_result(c50_advanced_result)
    result <- outcome$result
    use_cv <- if(!is.null(input$ml_use_cv)) input$ml_use_cv else FALSE
    size_check <- tryCatch(ml_size_check(), error = function(e) NULL)
    
    card_container(
      style = "margin: 0 15px; padding: 25px;",
      
      # Model header
      tags$div(
        style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; padding: 20px; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);",
        tags$h4(
          style = "color: white; margin: 0 0 10px 0; font-weight: 600;",
          icon("tree", style = "margin-right: 10px;"),
          "C5.0 Decision Tree"
        ),
        tags$p(
          style = "color: rgba(255,255,255,0.95); margin: 0; font-size: 14px; line-height: 1.6;",
          "Builds interpretable decision trees using information gain ratio. Supports boosting with multiple trials to improve accuracy. Automatically handles missing values and provides variable importance scores."
        )
      ),

      tags$hr(style = "margin: 20px 0; border-color: #ddd;"),

      ml_disclaimer_banner(size_check),

      # Two-column layout
      fluidRow(
        # Left column: Histogram
        column(7,
          tags$h5("Feature Importance", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
          shinycssloaders::withSpinner(plotOutput("c5.plot", height = "450px"))
        ),
        # Right column: Slider + Params + Metrics
        column(5,
          # Slider with disclaimer
          tags$div(
            style = "background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
            tags$h6("Display Options", style = "color: #191c32; margin-bottom: 10px; font-weight: 600;"),
            sliderInput("c50_top_n", "Number of features:", 
                       min = 5, max = 30, value = 15, step = 1),
            tags$p(
              style = "font-size: 11px; color: #666; line-height: 1.4; margin: 10px 0 0 0;",
              icon("info-circle", style = "color: #667eea; margin-right: 5px;"),
              "Ranked by usage frequency and accuracy contribution."
            )
          ),
          # Model parameters
          tags$div(
            style = "background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #e0e0e0; margin-bottom: 15px;",
            tags$div(
              style = "font-size: 13px; color: #191c32; font-weight: 500;",
              icon("cog", style = "color: #667eea; margin-right: 8px;"),
              if(!is.null(result)) {
                n_features <- if(!is.null(result$varimp)) nrow(result$varimp$importance) else 0
                cv_info <- if (!is.null(result$validation_label)) result$validation_label else "No CV"
                paste0("C5.0 + ", cv_info, " | ", n_features, " features")
              } else if (!is.null(outcome$error)) {
                paste0("Training failed: ", outcome$error)
              } else {
                "C5.0 Model"
              }
            )
          ),
          # Performance metrics - Radar plot
          if(!is.null(result)) {
            tags$div(
              style = "background: #fff; padding: 15px; border-radius: 8px; margin-bottom: 0;",
              chartOutput("c50_radar", height = "300px")
            )
          }
        )
      )
    )
  })
  
  # Random Forest Panel
  output$rf_panel_content <- renderUI({
    req(input$ml_use_rf)

    outcome <- capture_ml_result(rf_advanced_result)
    result <- outcome$result
    use_cv <- if(!is.null(input$ml_use_cv)) input$ml_use_cv else FALSE
    size_check <- tryCatch(ml_size_check(), error = function(e) NULL)
    
    card_container(
      style = "margin: 0 15px; padding: 25px;",
      
      # Model header
      tags$div(
        style = "background: linear-gradient(135deg, #34a853 0%, #0f9d58 100%); border-radius: 12px; padding: 20px; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(52, 168, 83, 0.3);",
        tags$h4(
          style = "color: white; margin: 0 0 10px 0; font-weight: 600;",
          icon("tree", style = "margin-right: 10px;"),
          "Random Forest"
        ),
        tags$p(
          style = "color: rgba(255,255,255,0.95); margin: 0; font-size: 14px; line-height: 1.6;",
          "Ensemble learning method that builds multiple decision trees on bootstrap samples and aggregates their predictions. Highly robust against overfitting and effective for high-dimensional data. Importance calculated using Mean Decrease in Gini impurity."
        )
      ),

      tags$hr(style = "margin: 20px 0; border-color: #ddd;"),

      ml_disclaimer_banner(size_check),

      # Two-column layout
      fluidRow(
        # Left column: Histogram
        column(7,
          tags$h5("Feature Importance (Gini)", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
          shinycssloaders::withSpinner(plotOutput("rf.plot", height = "450px"))
        ),
        # Right column: Slider + Params + Metrics
        column(5,
          # Slider with disclaimer
          tags$div(
            style = "background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
            tags$h6("Display Options", style = "color: #191c32; margin-bottom: 10px; font-weight: 600;"),
            sliderInput("rf_top_n", "Number of features:", 
                       min = 5, max = 30, value = 15, step = 1),
            tags$p(
              style = "font-size: 11px; color: #666; line-height: 1.4; margin: 10px 0 0 0;",
              icon("info-circle", style = "color: #34a853; margin-right: 5px;"),
              "Ranked by Mean Decrease in Gini impurity."
            )
          ),
          # Model parameters
          tags$div(
            style = "background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #e0e0e0; margin-bottom: 15px;",
            tags$div(
              style = "font-size: 13px; color: #191c32; font-weight: 500;",
              icon("cog", style = "color: #34a853; margin-right: 8px;"),
              if(!is.null(result)) {
                n_features <- if(!is.null(result$varimp)) nrow(result$varimp$importance) else 0
                cv_info <- if (!is.null(result$validation_label)) result$validation_label else "No CV"
                paste0("RF + ", cv_info, " | ", n_features, " features")
              } else if (!is.null(outcome$error)) {
                paste0("Training failed: ", outcome$error)
              } else {
                "Random Forest Model"
              }
            )
          ),
          # Performance metrics - Radar plot
          if(!is.null(result)) {
            tags$div(
              style = "background: #fff; padding: 15px; border-radius: 8px; margin-bottom: 0;",
              chartOutput("rf_radar", height = "300px")
            )
          }
        )
      )
    )
  })
  
  # SVM Panel
  output$svm_panel_content <- renderUI({
    req(input$ml_use_svm)

    outcome <- capture_ml_result(svm_advanced_result)
    result <- outcome$result
    use_cv <- if(!is.null(input$ml_use_cv)) input$ml_use_cv else FALSE
    use_rfe <- if(!is.null(input$ml_use_rfe)) input$ml_use_rfe else FALSE
    size_check <- tryCatch(ml_size_check(), error = function(e) NULL)
    
    card_container(
      style = "margin: 0 15px; padding: 25px;",
      
      # Model header
      tags$div(
        style = "background: linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%); border-radius: 12px; padding: 20px; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(255, 107, 107, 0.3);",
        tags$h4(
          style = "color: white; margin: 0 0 10px 0; font-weight: 600;",
          icon("vector-square", style = "margin-right: 10px;"),
          "Support Vector Machine (SVM)"
        ),
        tags$p(
          style = "color: rgba(255,255,255,0.95); margin: 0; font-size: 14px; line-height: 1.6;",
          "Finds the optimal hyperplane that maximizes the margin between classes. Linear kernel used with cost parameter C=10. Features selected using Recursive Feature Elimination (RFE) with cross-validation."
        )
      ),

      tags$hr(style = "margin: 20px 0; border-color: #ddd;"),

      ml_disclaimer_banner(size_check),

      if (!is.null(result) && isTRUE(result$skipped)) {
        ml_disclaimer_banner(list(severity = "low", message = result$skip_reason))
      },

      # Two-column layout
      fluidRow(
        # Left column: Feature list
        column(7,
          tags$h5("Selected Features (RFE)", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
          uiOutput("svm_features_list")
        ),
        # Right column: Params + Metrics
        column(5,
          # Model parameters
          tags$div(
            style = "background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #e0e0e0; margin-bottom: 15px;",
            tags$div(
              style = "font-size: 13px; color: #191c32; font-weight: 500;",
              icon("cog", style = "color: #ff6b6b; margin-right: 8px;"),
              if (!is.null(result) && isTRUE(result$skipped)) {
                "SVM not run (see note above)"
              } else if(!is.null(result)) {
                n_features <- if(!is.null(result$selected_features)) length(result$selected_features) else 0
                cv_info <- if (!is.null(result$validation_label)) result$validation_label else "No CV"
                rfe_info <- if(use_rfe) " + RFE" else ""
                paste0("SVM + ", cv_info, rfe_info, " | ", n_features, " features")
              } else if (!is.null(outcome$error)) {
                paste0("Training failed: ", outcome$error)
              } else {
                "SVM Model"
              }
            )
          ),
          # Performance metrics - Radar plot
          if(!is.null(result) && !isTRUE(result$skipped)) {
            tags$div(
              style = "background: #fff; padding: 15px; border-radius: 8px; margin-bottom: 0;",
              chartOutput("svm_radar", height = "300px")
            )
          }
        )
      )
    )
  })
  
  # XGBoost Panel
  output$xgboost_panel_content <- renderUI({
    req(input$ml_use_xgboost)

    outcome <- capture_ml_result(xgboost_advanced_result)
    result <- outcome$result
    use_cv <- if(!is.null(input$ml_use_cv)) input$ml_use_cv else FALSE
    size_check <- tryCatch(ml_size_check(), error = function(e) NULL)
    
    card_container(
      style = "margin: 0 15px; padding: 25px;",
      
      # Model header
      tags$div(
        style = "background: linear-gradient(135deg, #f39c12 0%, #e67e22 100%); border-radius: 12px; padding: 20px; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(243, 156, 18, 0.3);",
        tags$h4(
          style = "color: white; margin: 0 0 10px 0; font-weight: 600;",
          icon("bolt", style = "margin-right: 10px;"),
          "XGBoost (Extreme Gradient Boosting)"
        ),
        tags$p(
          style = "color: rgba(255,255,255,0.95); margin: 0; font-size: 14px; line-height: 1.6;",
          "Scalable gradient boosting algorithm that builds sequential trees to correct errors from previous iterations. Highly efficient for large datasets with complex feature interactions. SHAP (SHapley Additive exPlanations) values provide model interpretability."
        )
      ),

      tags$hr(style = "margin: 20px 0; border-color: #ddd;"),

      ml_disclaimer_banner(size_check),

      # Two-column layout
      fluidRow(
        # Left column: Importance plot (SHAP or VarImp)
        column(7,
          uiOutput("xgb_plot_title"),
          shinycssloaders::withSpinner(plotOutput("xgb_importance_plot", height = "450px"))
        ),
        # Right column: Toggle + Slider + Params + Metrics
        column(5,
          # Toggle SHAP/VarImp
          tags$div(
            style = "background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
            tags$h6("Importance Type", style = "color: #191c32; margin-bottom: 10px; font-weight: 600;"),
            radioButtons("xgb_importance_type", NULL,
                        choices = c("SHAP Values" = "shap", "Variable Importance" = "varimp"),
                        selected = "varimp", inline = TRUE),
            tags$p(
              style = "font-size: 11px; color: #666; line-height: 1.4; margin: 10px 0 0 0;",
              icon("info-circle", style = "color: #f39c12; margin-right: 5px;"),
              textOutput("xgb_importance_help", inline = TRUE)
            )
          ),
          # Slider (only for VarImp)
          conditionalPanel(
            condition = "input.xgb_importance_type == 'varimp'",
            tags$div(
              style = "background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
              sliderInput("xgb_top_n", "Number of features:", 
                         min = 5, max = 30, value = 15, step = 1)
            )
          ),
          # Model parameters
          tags$div(
            style = "background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #e0e0e0; margin-bottom: 15px;",
            tags$div(
              style = "font-size: 13px; color: #191c32; font-weight: 500;",
              icon("cog", style = "color: #f39c12; margin-right: 8px;"),
              if(!is.null(result)) {
                n_features <- if(!is.null(result$varimp)) nrow(result$varimp$importance) else 0
                cv_info <- if (!is.null(result$validation_label)) result$validation_label else "No CV"
                paste0("XGBoost + ", cv_info, " | ", n_features, " features")
              } else if (!is.null(outcome$error)) {
                paste0("Training failed: ", outcome$error)
              } else {
                "XGBoost Model"
              }
            )
          ),
          # Performance metrics - Radar plot
          if(!is.null(result)) {
            tags$div(
              style = "background: #fff; padding: 15px; border-radius: 8px; margin-bottom: 0;",
              chartOutput("xgb_radar", height = "300px")
            )
          }
        )
      )
    )
  })
  
  ## Modelo C5.0 ##
  
  # C5.0 Variable Importance Features (unified caret approach)
  variables_c5 <- reactive({
    req(input$ml_use_c50)
    
    # Get result from advanced training
    result <- tryCatch({
      c50_advanced_result()
    }, error = function(e) {
      # An empty message is the pipeline simply not having run yet
      # (req() inside the eventReactive), not a training failure.
      if (nzchar(e$message)) message("[variables_c5] Training failed: ", e$message)
      NULL
    })
    
    if (is.null(result)) {
      return(character(0))
    }
    
    # PRIORITY 1: If RFE was used, show selected features from RFE
    if (!is.null(result$rfe_used) && result$rfe_used && !is.null(result$selected_features)) {
      message("[variables_c5] Using RFE-selected features (", length(result$selected_features), " features)")
      return(head(result$selected_features, 30))  # Top 30 from RFE
    }
    
    # PRIORITY 2: Try variable importance (if available)
    if (!is.null(result$varimp)) {
      importance_df <- format_varimp_df(result$varimp, top_n = 30)
      if (!is.null(importance_df) && nrow(importance_df) > 0) {
        message("[variables_c5] Using varImp-ranked features")
        return(importance_df$Feature)
      }
    }
    
    # Fallback: empty vector
    message("[variables_c5] No variable importance or RFE features available")
    return(character(0))
  })
  
  # C5.0 Feature Importance Plot (uses c50_advanced_result reactive)
  output$c5.plot <- renderPlot({
    req(input$ml_use_c50)

    top_n <- if(!is.null(input$c50_top_n)) input$c50_top_n else 15
    outcome <- capture_ml_result(c50_advanced_result)
    result <- outcome$result

    if (is.null(result) || is.null(result$varimp)) {
      reason <- if (!is.null(outcome$error)) {
        paste0("Training failed:\n", outcome$error)
      } else {
        "Variable importance not available"
      }
      return(ml_unavailable_plot(reason))
    }

    importance_df <- format_varimp_df(result$varimp, top_n = top_n)

    if (is.null(importance_df) || nrow(importance_df) == 0) {
      return(ml_unavailable_plot("No features available"))
    }
    
    # Simple ggplot
    ggplot(importance_df, aes(x = reorder(Feature, Importance), y = Importance)) +
      geom_col(fill = "#667eea", alpha = 0.8) +
      coord_flip() +
      labs(title = paste("Top", top_n, "Most Important Features"),
           x = NULL, y = "Relative Importance") +
      theme_minimal() +
      theme(axis.text = element_text(size = 10))
  })
  
  output$c5.tree <- renderPlot({
    req(input$ml_use_c50)  # Only render if selected
    # Use modular C5.0 function
    model <- train_c50_model(ml_train_data(), trials = 50, seed = 1234)
    plot(model)
  })
  
  # C5.0 Radar Plot for Performance Metrics
  output$c50_radar <- renderChart({
    req(input$ml_use_c50)
    result <- tryCatch(c50_advanced_result(), error = function(e) NULL)
    
    if(is.null(result)) {
      return(NULL)
    }
    
    create_performance_radar(result, model_color = "#667eea")
  })
  
  
  ## Random Forest ##
  
  # Random Forest Variable Importance Features (unified caret approach)
  variables_rf <- reactive({
    req(input$ml_use_rf)
    
    # Get result from advanced training (uses caret::varImp)
    result <- tryCatch({
      rf_advanced_result()
    }, error = function(e) {
      # An empty message is the pipeline simply not having run yet
      # (req() inside the eventReactive), not a training failure.
      if (nzchar(e$message)) message("[variables_rf] Training failed: ", e$message)
      NULL
    })
    
    if (is.null(result)) {
      return(character(0))
    }
    
    # PRIORITY 1: If RFE was used, show selected features from RFE
    if (!is.null(result$rfe_used) && result$rfe_used && !is.null(result$selected_features)) {
      message("[variables_rf] Using RFE-selected features (", length(result$selected_features), " features)")
      return(head(result$selected_features, 30))  # Top 30 from RFE
    }
    
    # PRIORITY 2: Try variable importance (if available)
    if (!is.null(result$varimp)) {
      importance_df <- format_varimp_df(result$varimp, top_n = 30)
      if (!is.null(importance_df) && nrow(importance_df) > 0) {
        message("[variables_rf] Using varImp-ranked features")
        return(importance_df$Feature)
      }
    }
    
    # Fallback: empty vector
    message("[variables_rf] No variable importance or RFE features available")
    return(character(0))
  })
  
  # RF Feature Importance Plot (uses rf_advanced_result reactive)
  output$rf.plot <- renderPlot({
    req(input$ml_use_rf)

    top_n <- if(!is.null(input$rf_top_n)) input$rf_top_n else 15
    outcome <- capture_ml_result(rf_advanced_result)
    result <- outcome$result

    if (is.null(result) || is.null(result$varimp)) {
      reason <- if (!is.null(outcome$error)) {
        paste0("Training failed:\n", outcome$error)
      } else {
        "Variable importance not available"
      }
      return(ml_unavailable_plot(reason))
    }

    importance_df <- format_varimp_df(result$varimp, top_n = top_n)

    if (is.null(importance_df) || nrow(importance_df) == 0) {
      return(ml_unavailable_plot("No features available"))
    }
    
    # Simple ggplot
    ggplot(importance_df, aes(x = reorder(Feature, Importance), y = Importance)) +
      geom_col(fill = "#34a853", alpha = 0.8) +
      coord_flip() +
      labs(title = paste("Top", top_n, "Most Important Features"),
           x = NULL, y = "Relative Importance (Gini)") +
      theme_minimal() +
      theme(axis.text = element_text(size = 10))
  })
  
  # RF Radar Plot for Performance Metrics
  output$rf_radar <- renderChart({
    req(input$ml_use_rf)
    result <- tryCatch(rf_advanced_result(), error = function(e) NULL)
    
    if(is.null(result)) {
      return(NULL)
    }
    
    create_performance_radar(result, model_color = "#34a853")
  })
  
  ## SVM ##
  
  # SVM Variable Importance Features (unified caret approach)
  variables_importantes_reactive <- reactive({
    req(input$ml_use_svm)
    
    # Get result from advanced training
    result <- tryCatch({
      svm_advanced_result()
    }, error = function(e) {
      # An empty message is the pipeline simply not having run yet
      # (req() inside the eventReactive), not a training failure.
      if (nzchar(e$message)) message("[variables_svm] Training failed: ", e$message)
      NULL
    })
    
    if (is.null(result)) {
      return(character(0))
    }
    
    # PRIORITY 1: If RFE was used, show selected features from RFE
    if (!is.null(result$rfe_used) && result$rfe_used && !is.null(result$selected_features)) {
      message("[variables_svm] Using RFE-selected features (", length(result$selected_features), " features)")
      return(head(result$selected_features, 30))  # Top 30 from RFE
    }
    
    # PRIORITY 2: Try variable importance (if available)
    if (!is.null(result$varimp)) {
      importance_df <- format_varimp_df(result$varimp, top_n = 30)
      if (!is.null(importance_df) && nrow(importance_df) > 0) {
        message("[variables_svm] Using varImp-ranked features")
        return(importance_df$Feature)
      }
    }
    
    # Fallback: empty vector
    message("[variables_svm] No variable importance or RFE features available")
    return(character(0))
  })
  
  # SVM Features List UI
  output$svm_features_list <- renderUI({
    req(input$ml_use_svm)

    features <- variables_importantes_reactive()

    if(length(features) == 0) {
      outcome <- capture_ml_result(svm_advanced_result)
      msg <- if (!is.null(outcome$result) && isTRUE(outcome$result$skipped)) {
        outcome$result$skip_reason
      } else if (!is.null(outcome$error)) {
        paste0("Training failed: ", outcome$error)
      } else {
        "No features available"
      }
      return(tags$p(msg, style = "color: #666; font-style: italic; white-space: pre-wrap;"))
    }
    
    tags$div(
      style = "background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #e0e0e0; max-height: 400px; overflow-y: auto;",
      lapply(seq_along(features), function(i) {
        tags$div(
          style = "padding: 8px; margin-bottom: 5px; background: #f8f9fa; border-radius: 4px; border-left: 3px solid #ff6b6b;",
          tags$strong(paste0(i, ". "), style = "color: #ff6b6b; margin-right: 8px; font-size: 12px;"),
          tags$span(features[i], style = "color: #191c32; font-size: 12px;")
        )
      })
    )
  })
  
  # SVM Radar Plot for Performance Metrics
  output$svm_radar <- renderChart({
    req(input$ml_use_svm)
    result <- tryCatch(svm_advanced_result(), error = function(e) NULL)

    if(is.null(result) || isTRUE(result$skipped)) {
      return(NULL)
    }

    create_performance_radar(result, model_color = "#ff6b6b")
  })
  
  # SVM decision boundary plot removed - replaced with feature list
  
  ## XGBoost ##
  # XGBoost plot title
  output$xgb_plot_title <- renderUI({
    req(input$ml_use_xgboost)
    plot_type <- if(!is.null(input$xgb_importance_type)) input$xgb_importance_type else "varimp"
    title <- if(plot_type == "shap") "SHAP Feature Importance" else "Variable Importance (Gain)"
    tags$h5(title, style = "color: #191c32; margin-bottom: 15px; font-weight: 600;")
  })
  
  # XGBoost help text
  output$xgb_importance_help <- renderText({
    plot_type <- if(!is.null(input$xgb_importance_type)) input$xgb_importance_type else "varimp"
    if(plot_type == "shap") {
      "SHAP values show game-theoretic feature contributions to predictions."
    } else {
      "Gain measures total improvement in loss when splitting on each feature."
    }
  })
  
  # XGBoost unified importance plot
  output$xgb_importance_plot <- renderPlot({
    withProgress(message = 'Creando gráfico 3D', value = 0, {
      # Use modular scaling function
      df.scaled <- scale_ml_data(ml_train_data())
      
      # Obtener las variables importantes de la expresión reactiva
      variables_importantes <- variables_importantes_reactive()
      
      # Seleccionar las tres mejores variables para el gráfico 3D
      predictoras_3d <- variables_importantes[1:3]
      
      
      # Entrenar el modelo SVM con las tres mejores variables
      modelo_svm_3d <- svm(formula = as.formula(paste("target ~", paste(quote_terms(predictoras_3d), collapse = " + "))),
                           data = df.scaled, kernel = "linear", cost = 10)
      
      # Crear una cuadrícula de valores para las tres variables predictoras
      x_min <- min(df.scaled[,predictoras_3d[1]])
      x_max <- max(df.scaled[,predictoras_3d[1]])
      y_min <- min(df.scaled[,predictoras_3d[2]])
      y_max <- max(df.scaled[,predictoras_3d[2]])
      z_min <- min(df.scaled[,predictoras_3d[3]])
      z_max <- max(df.scaled[,predictoras_3d[3]])
      
      # Crear la cuadrícula
      grid_3d <- expand.grid(
        x1 = seq(x_min, x_max, length.out = 30),
        x2 = seq(y_min, y_max, length.out = 30),
        x3 = seq(z_min, z_max, length.out = 30)
      )
      names(grid_3d) <- predictoras_3d
      
      # Hacer predicciones en la cuadrícula
      grid_3d$target <- predict(modelo_svm_3d, grid_3d)
      
      # Convertir target a factor
      grid_3d$target <- as.factor(grid_3d$target)
      
      incProgress(0.5, detail = "Generating 3D graphics...")
      
      # Crear la visualización 3D
      fig <- plot_ly() %>%
        # Graficar los puntos originales
        add_markers(data = df.scaled, 
                    x = ~df.scaled[,predictoras_3d[1]], 
                    y = ~df.scaled[,predictoras_3d[2]], 
                    z = ~df.scaled[,predictoras_3d[3]], 
                    color = ~df.scaled$target,
                    colors = custom_palette,
                    marker = list(size = 5),
                    opacity = 0.8) %>%
        # Graficar la frontera de decisión
        add_markers(data = grid_3d, 
                    x = ~grid_3d[,predictoras_3d[1]], 
                    y = ~grid_3d[,predictoras_3d[2]], 
                    z = ~grid_3d[,predictoras_3d[3]], 
                    color = ~grid_3d$target, 
                    colors = custom_palette,
                    marker = list(size = 3),
                    opacity = 0.15) %>%
        layout(scene = list(xaxis = list(title = predictoras_3d[1]),
                            yaxis = list(title = predictoras_3d[2]),
                            zaxis = list(title = predictoras_3d[3]),
                            aspectmode = 'cube'))
      
      incProgress(1, detail = "Completed 3D graphic")
      
      fig
    })
  })
  
  ## XGBoost - Variable Importance Features (unified caret approach)
  variables_xgb <- reactive({
    req(input$ml_use_xgboost)
    
    # Get result from advanced training (uses caret::varImp)
    result <- tryCatch({
      xgboost_advanced_result()
    }, error = function(e) {
      # An empty message is the pipeline simply not having run yet
      # (req() inside the eventReactive), not a training failure.
      if (nzchar(e$message)) message("[variables_xgb] Training failed: ", e$message)
      NULL
    })
    
    # Return features from varimp (NOT selected_features which is for RFE)
    if (!is.null(result) && !is.null(result$varimp)) {
      # Use unified format function
      importance_df <- format_varimp_df(result$varimp, top_n = 30)
      if (!is.null(importance_df) && nrow(importance_df) > 0) {
        return(importance_df$Feature)
      }
    }
    
    # Fallback: empty vector
    message("[variables_xgb] No variable importance available")
    return(character(0))
  })
  

  ## XGBoost SHAP ##
  xgb.shap <- reactive({
    req(input$ml_use_xgboost)  # Only compute if selected
    # Use modular XGBoost and SHAP functions
    xgb_result <- train_xgboost_model(ml_train_data(), max_depth = 3, eta = 0.1, nrounds = 100)
    calculate_shap_values(xgb_result)
  })
  
  # XGBoost unified importance plot (SHAP or VarImp)
  output$xgb_importance_plot <- renderPlot({
    req(input$ml_use_xgboost)
    
    plot_type <- if(!is.null(input$xgb_importance_type)) input$xgb_importance_type else "varimp"
    
    if(plot_type == "shap") {
      # SHAP values plot
      shap_values <- xgb.shap()
      sv_importance(shap_values, show_numbers = TRUE) +
        theme_minimal() +
        theme(axis.text = element_text(size = 10))
    } else {
      # Variable Importance (caret::varImp)
      top_n <- if(!is.null(input$xgb_top_n)) input$xgb_top_n else 15

      outcome <- capture_ml_result(xgboost_advanced_result)
      result <- outcome$result

      if (is.null(result) || is.null(result$varimp)) {
        reason <- if (!is.null(outcome$error)) {
          paste0("Training failed:\n", outcome$error)
        } else {
          "Variable importance not available"
        }
        return(ml_unavailable_plot(reason))
      }

      importance_df <- format_varimp_df(result$varimp, top_n = top_n)

      if (is.null(importance_df) || nrow(importance_df) == 0) {
        return(ml_unavailable_plot("No features available"))
      }
      
      # Simple ggplot
      ggplot(importance_df, aes(x = reorder(Feature, Importance), y = Importance)) +
        geom_col(fill = "#f39c12", alpha = 0.8) +
        coord_flip() +
        labs(title = paste("Top", top_n, "Most Important Features (XGBoost)"),
             x = NULL, y = "Relative Importance (Gain)") +
        theme_minimal() +
        theme(axis.text = element_text(size = 10))
    }
  })
  
  # XGBoost Radar Plot for Performance Metrics
  output$xgb_radar <- renderChart({
    req(input$ml_use_xgboost)
    result <- tryCatch(xgboost_advanced_result(), error = function(e) NULL)
    
    if(is.null(result)) {
      return(NULL)
    }
    
    create_performance_radar(result, model_color = "#f39c12")
  })
  
  # Legacy SHAP plot removed - now integrated in xgb_importance_plot
  
  #### End supervised Machine ####
  
  
  # Feature overlap is now an interactive D3 Venn (www/venn_d3.js). Build the
  # per-model top-N feature lists and push them to the client.
  venn_model_vars <- reactive({
    top_n <- if (!is.null(input$consensus_top_n)) input$consensus_top_n else 20
    safe <- function(expr) tryCatch(expr, error = function(e) NULL)
    mv <- list()
    if (isTRUE(input$ml_use_c50))     mv[["C5.0"]]          <- head(safe(variables_c5()), top_n)
    if (isTRUE(input$ml_use_rf))      mv[["Random Forest"]] <- head(safe(variables_rf()), top_n)
    if (isTRUE(input$ml_use_svm))     mv[["SVM"]]           <- head(safe(variables_importantes_reactive()), top_n)
    if (isTRUE(input$ml_use_xgboost)) mv[["XGBoost"]]       <- head(safe(variables_xgb()), top_n)
    mv[vapply(mv, function(v) length(v) > 0, logical(1))]   # drop empty / untrained
  })

  observeEvent(venn_model_vars(), {
    mv <- venn_model_vars()
    req(length(mv) >= 2)
    sets <- lapply(names(mv), function(nm) list(name = nm, features = as.list(as.character(mv[[nm]]))))
    # On-brand, distinct set colours (teal, blue, orange, purple)
    venn_cols <- c("#18BC9C", "#1F78B4", "#FF7F00", "#6A3D9A")
    session$sendCustomMessage("vennData", list(
      sets = sets, colors = as.list(venn_cols[seq_along(sets)])
    ))
  })
  
  output$consensus_vars <- renderText({
    # Build list dynamically based on selected models
    model_vars <- list()
    
    if (!is.null(input$ml_use_c50) && input$ml_use_c50) {
      model_vars[["C5.0"]] <- variables_c5()
    }
    
    if (!is.null(input$ml_use_rf) && input$ml_use_rf) {
      model_vars[["Random Forest"]] <- variables_rf()
    }
    
    if (!is.null(input$ml_use_svm) && input$ml_use_svm) {
      model_vars[["SVM"]] <- variables_importantes_reactive()
    }
    
    if (!is.null(input$ml_use_xgboost) && input$ml_use_xgboost) {
      model_vars[["XGBoost"]] <- variables_xgb()
    }
    
    req(length(model_vars) >= 2)
    
    consensus <- Reduce(intersect, unname(model_vars))
    if (length(consensus) > 0) {
      paste(consensus, collapse = ", ")
    } else {
      "There are no variables in common between the models."
    }
  })
  
  # Consensus biomarkers list UI
  output$consensus_biomarkers_list <- renderUI({
    # Get top N from slider
    top_n <- if(!is.null(input$consensus_top_n)) input$consensus_top_n else 20
    
    # Build list dynamically based on selected models, limited to top_n
    model_vars <- list()
    
    if (!is.null(input$ml_use_c50) && input$ml_use_c50) {
      all_vars <- variables_c5()
      model_vars[["C5.0"]] <- head(all_vars, top_n)
    }
    
    if (!is.null(input$ml_use_rf) && input$ml_use_rf) {
      all_vars <- variables_rf()
      model_vars[["Random Forest"]] <- head(all_vars, top_n)
    }
    
    if (!is.null(input$ml_use_svm) && input$ml_use_svm) {
      all_vars <- variables_importantes_reactive()
      model_vars[["SVM"]] <- head(all_vars, top_n)
    }
    
    if (!is.null(input$ml_use_xgboost) && input$ml_use_xgboost) {
      all_vars <- variables_xgb()
      model_vars[["XGBoost"]] <- head(all_vars, top_n)
    }
    
    req(length(model_vars) >= 2)
    
    # Find features in 2+ models (coerce to character; some models may return none)
    all_features <- unique(as.character(unlist(model_vars, use.names = FALSE)))
    all_features <- all_features[!is.na(all_features) & nzchar(all_features)]
    req(length(all_features) > 0)
    feature_counts <- sapply(all_features, function(feat) {
      sum(sapply(model_vars, function(vars) feat %in% as.character(vars)))
    })

    # Get consensus features (in 2+ models), most frequent first
    consensus_features <- names(which(feature_counts >= 2))
    consensus_features <- consensus_features[order(-feature_counts[consensus_features])]
    
    if (length(consensus_features) > 0) {
      tags$div(
        style = "background: #f8f9fa; padding: 15px; border-radius: 8px; max-height: 400px; overflow-y: auto;",
        lapply(seq_along(consensus_features), function(i) {
          feat <- consensus_features[i]
          count <- feature_counts[feat]
          tags$div(
            style = "padding: 10px; margin-bottom: 8px; background: white; border-radius: 4px; border-left: 4px solid #3498db;",
            tags$div(
              style = "display: flex; justify-content: space-between; align-items: center;",
              tags$div(
                tags$strong(paste0(i, ". "), style = "color: #3498db; margin-right: 8px;"),
                tags$span(feat, style = "color: #191c32; font-weight: 500;")
              ),
              tags$span(
                paste0(count, "/", length(model_vars), " models"),
                style = "background: #3498db; color: white; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600;"
              )
            )
          )
        }),
        tags$div(
          style = "margin-top: 15px; padding: 12px; background: #e8f5e9; border-radius: 4px; border-left: 3px solid #4caf50;",
          tags$small(
            style = "color: #2e7d32; font-weight: 500;",
            icon("check-circle", style = "margin-right: 5px;"),
            "Total: ", length(consensus_features), " consensus biomarkers identified"
          )
        )
      )
    } else {
      tags$div(
        style = "background: #fff3cd; padding: 20px; border-radius: 8px; border-left: 4px solid #ffc107; text-align: center;",
        tags$p(
          style = "color: #856404; margin: 0; font-size: 14px;",
          icon("exclamation-triangle", style = "margin-right: 8px;"),
          strong("No consensus features found."),
          tags$br(),
          tags$span("Features selected by different models do not overlap. Consider adjusting feature selection thresholds.", style = "font-size: 12px;")
        )
      )
    }
  })
  
  # Send biomarkers from ML to protein visualization
  observeEvent(input$ml_send_biomarkers_to_viz, {
    message("\n========== [ML_EXPORT] Sending Biomarkers to Protein Viz ==========")
    
    # Get top N from slider
    top_n <- if(!is.null(input$consensus_top_n)) input$consensus_top_n else 20
    message("[ML_EXPORT] Top N threshold: ", top_n)
    
    # Build list dynamically based on selected models, limited to top_n
    model_vars <- list()
    
    tryCatch({
      if (!is.null(input$ml_use_c50) && input$ml_use_c50) {
        all_vars <- variables_c5()
        model_vars[["C5.0"]] <- head(all_vars, top_n)
        message("[ML_EXPORT] C5.0: ", length(all_vars), " total, using top ", length(model_vars[["C5.0"]]))
      }
      
      if (!is.null(input$ml_use_rf) && input$ml_use_rf) {
        all_vars <- variables_rf()
        model_vars[["Random Forest"]] <- head(all_vars, top_n)
        message("[ML_EXPORT] RF: ", length(all_vars), " total, using top ", length(model_vars[["Random Forest"]]))
      }
      
      if (!is.null(input$ml_use_svm) && input$ml_use_svm) {
        all_vars <- variables_importantes_reactive()
        model_vars[["SVM"]] <- head(all_vars, top_n)
        message("[ML_EXPORT] SVM: ", length(all_vars), " total, using top ", length(model_vars[["SVM"]]))
      }
      
      if (!is.null(input$ml_use_xgboost) && input$ml_use_xgboost) {
        all_vars <- variables_xgb()
        model_vars[["XGBoost"]] <- head(all_vars, top_n)
        message("[ML_EXPORT] XGBoost: ", length(all_vars), " total, using top ", length(model_vars[["XGBoost"]]))
      }
    }, error = function(e) {
      message("Error collecting features: ", e$message)
    })
    
    # Need at least 2 models for consensus
    if (length(model_vars) < 2) {
      message("[ML_EXPORT] ERROR: Need at least 2 models, only ", length(model_vars), " selected")
      showNotification(
        "Need at least 2 models to calculate consensus biomarkers.",
        type = "warning",
        duration = 5
      )
      return()
    }
    
    message("[ML_EXPORT] Models selected: ", paste(names(model_vars), collapse = ", "))
    
    # Find features in multiple models (consensus = in 2+ models)
    all_features <- unique(unlist(model_vars))
    message("[ML_EXPORT] Total unique features across models: ", length(all_features))
    
    feature_counts <- sapply(all_features, function(feat) {
      sum(sapply(model_vars, function(vars) feat %in% vars))
    })
    
    # Get consensus features (in 2+ models)
    consensus_features <- names(feature_counts[feature_counts >= 2])
    consensus_features <- consensus_features[order(-feature_counts[consensus_features])]
    
    message("[ML_EXPORT] Consensus features (2+ models): ", length(consensus_features))
    if (length(consensus_features) > 0) {
      message("[ML_EXPORT] Examples: ", paste(head(consensus_features, 5), collapse = ", "))
    }
    
    if (length(consensus_features) == 0) {
      message("[ML_EXPORT] ERROR: No consensus features found")
      showNotification(
        "No consensus biomarkers found. Features from different models do not overlap.",
        type = "warning",
        duration = 5
      )
      return()
    }
    
    # Update selected_biomarkers with consensus features only
    # Kept apart from selected_biomarkers(): that one is the ML input, and
    # overwriting it made the next training run use the consensus alone.
    consensus_biomarkers(consensus_features)
    log_step("ML", "Consensus biomarkers sent to the protein view", n = length(consensus_features),
             peptides = consensus_features, models = names(model_vars))
    message("[ML_EXPORT] Full list: ", paste(consensus_features, collapse = ", "))
    message("========== [ML_EXPORT] Complete ==========")
    
    showNotification(
      paste(length(consensus_features), "consensus biomarkers sent to Protein Visualization tab."),
      type = "message",
      duration = 5
    )
  })
  
  # ============================================================================
  # MACHINE LEARNING - NEW PIPELINE SYSTEM
  # ============================================================================
  
  # Hide all ML result sections initially
  shinyjs::hide("ml_heatmap_section")
  shinyjs::hide("ml_ordination_section")
  shinyjs::hide("ml_pca_results")
  shinyjs::hide("ml_pcoa_results")
  shinyjs::hide("ml_nmds_results")
  shinyjs::hide("ml_dbscan_results")
  shinyjs::hide("ml_plsda_results")
  shinyjs::hide("ml_c50_results")
  shinyjs::hide("ml_rf_results")
  shinyjs::hide("ml_svm_results")
  shinyjs::hide("ml_xgboost_results")
  shinyjs::hide("ml_validation_results")
  shinyjs::hide("ml_venn_results")
  shinyjs::hide("ml_send_biomarkers_section")
  
  # Unified target variable (new system uses ml_target_var, old uses PCA_target/h_target)
  # First chosen target that still exists in the clinical table. A selector can
  # keep a column from a previous upload (e.g. "P_clara"), which used to crash
  # every plot that looked it up.
  active_target_var <- reactive({
    cand <- c(input$ml_target_var, input$PCA_target, input$h_target[1], global_target_var())
    db <- tryCatch(active_database(), error = function(e) NULL)
    hit <- if (is.null(db)) cand else cand[cand %in% names(db)]
    if (length(hit)) hit[1] else NULL
  })
  
  # ML Target Variable Selector
  output$ml_target_selector <- renderUI({
    req(database())
    req(active_pepdata())
    
    choices <- colnames(meta_data_ML() %>%
                         dplyr::select((ncol(active_pepdata()) + 1):ncol(meta_data_ML())) %>%
                         as.data.frame())

    # Preserve the user's current choice across re-renders (e.g. after running ML
    # meta_data_ML changes and this UI rebuilds). isolate() avoids re-rendering on
    # every target change while keeping the selection sticky.
    cur <- isolate(input$ml_target_var)
    selectInput(
      "ml_target_var",
      label = NULL,
      choices = choices,
      selected = if (!is.null(cur) && cur %in% choices) cur else choices[1],
      width = "100%"
    )
  })
  
  # Run ML Pipeline
  observeEvent(input$ml_run_pipeline, {
    req(input$ml_target_var)

    # Debounce: block re-runs for 10s so rapid clicks don't queue the pipeline
    shinyjs::disable("ml_run_pipeline")
    shinyjs::delay(10000, shinyjs::enable("ml_run_pipeline"))

    # Validate at least one method selected
    any_unsupervised <- input$ml_use_heatmap || input$ml_use_pca ||
                        input$ml_use_pcoa || input$ml_use_nmds || 
                        input$ml_use_dbscan || input$ml_use_plsda
    
    any_supervised <- input$ml_use_c50 || input$ml_use_rf || 
                      input$ml_use_svm || input$ml_use_xgboost
    
    if (!any_unsupervised && !any_supervised) {
      log_step("ML", "Run refused", level = "WARN", why = "no method ticked")
      showNotification(
        "Please select at least one ML method to run.",
        type = "warning",
        duration = 5
      )
      return()
    }
    
    # Check biomarker selection
    sel_biomarkers <- selected_biomarkers()
    if (is.null(sel_biomarkers) || length(sel_biomarkers) == 0) {
      showNotification(
        "No biomarkers selected. Using all peptides from the database.",
        type = "warning",
        duration = 5
      )
    } else {
      showNotification(
        paste("Using", length(sel_biomarkers), "selected biomarkers from Peptide tab"),
        type = "message",
        duration = 4
      )
    }
    
    shinyjs::show("ml_loader")

    # Run with progress bar
    withProgress(message = 'Running ML Pipeline...', value = 0, {

      # Step 1: Show/hide heatmap
      incProgress(0.1, detail = "Configuring heatmap...")
      if (input$ml_use_heatmap) {
        shinyjs::show("ml_heatmap_section")
      } else {
        shinyjs::hide("ml_heatmap_section")
      }
      
      # Step 2: Configure unsupervised methods
      incProgress(0.2, detail = "Configuring unsupervised methods...")
      
      # Show ordination section if any ordination method is selected
      if (input$ml_use_pca || input$ml_use_pcoa || input$ml_use_nmds) {
        shinyjs::show("ml_ordination_section")
      } else {
        shinyjs::hide("ml_ordination_section")
      }
      
      if (input$ml_use_pca) {
        shinyjs::show("ml_pca_results")
      } else {
        shinyjs::hide("ml_pca_results")
      }
      
      if (input$ml_use_pcoa) {
        shinyjs::show("ml_pcoa_results")
      } else {
        shinyjs::hide("ml_pcoa_results")
      }
      
      if (input$ml_use_nmds) {
        shinyjs::show("ml_nmds_results")
      } else {
        shinyjs::hide("ml_nmds_results")
      }
      
      if (input$ml_use_dbscan) {
        shinyjs::show("ml_dbscan_results")
      } else {
        shinyjs::hide("ml_dbscan_results")
      }
      
      if (input$ml_use_plsda) {
        shinyjs::show("ml_plsda_results")
      } else {
        shinyjs::hide("ml_plsda_results")
      }
      
      # Step 3: Configure supervised methods
      incProgress(0.4, detail = "Configuring supervised methods...")
      
      shinyjs::toggle("ml_validation_results",
                      condition = any(c(input$ml_use_c50, input$ml_use_rf, input$ml_use_svm, input$ml_use_xgboost)))

      if (input$ml_use_c50) {
        shinyjs::show("ml_c50_results")
      } else {
        shinyjs::hide("ml_c50_results")
      }
      
      if (input$ml_use_rf) {
        shinyjs::show("ml_rf_results")
      } else {
        shinyjs::hide("ml_rf_results")
      }
      
      if (input$ml_use_svm) {
        shinyjs::show("ml_svm_results")
      } else {
        shinyjs::hide("ml_svm_results")
      }
      
      if (input$ml_use_xgboost) {
        shinyjs::show("ml_xgboost_results")
      } else {
        shinyjs::hide("ml_xgboost_results")
      }
      
      # Show Venn diagram if more than one supervised method
      if (sum(c(input$ml_use_c50, input$ml_use_rf, input$ml_use_svm, input$ml_use_xgboost)) > 1) {
        shinyjs::show("ml_venn_results")
        shinyjs::show("ml_send_biomarkers_section")  # Show export button with consensus
      } else {
        shinyjs::hide("ml_venn_results")
        shinyjs::hide("ml_send_biomarkers_section")
      }
      
      # Step 4: Switch to appropriate tab
      incProgress(0.6, detail = "Navigating to results...")
      
      if (any_unsupervised) {
        updateTabsetPanel(session, "ml_subtabs", selected = "Unsupervised Learning")
      } else if (any_supervised) {
        updateTabsetPanel(session, "ml_subtabs", selected = "Supervised Learning")
      }
      
      # Step 5: Complete
      incProgress(1, detail = "Pipeline configured successfully!")
    })

    # Force training in a deferred callback so the spinner actually renders first
    # (show + heavy work in the same synchronous observer would never paint).
    shinyjs::delay(250, {
      if (isTRUE(input$ml_use_c50))     try(c50_advanced_result(), silent = TRUE)
      if (isTRUE(input$ml_use_rf))      try(rf_advanced_result(), silent = TRUE)
      if (isTRUE(input$ml_use_svm))     try(svm_advanced_result(), silent = TRUE)
      if (isTRUE(input$ml_use_xgboost)) try(xgboost_advanced_result(), silent = TRUE)
      shinyjs::hide("ml_loader")
      showNotification("ML pipeline ready! Results are shown below.", type = "message", duration = 4)
    })
  })
  
  # ============================================================================
  # ============================== LEGACY CODE =================================
  # ============================================================================
  # Below this line: Original ML outputs that compute the actual results
  # These use active_target_var() and active_pepdata() (filtered by selected_biomarkers)
  
  # ============================================================================
  # MACHINE LEARNING - LEGACY CODE (TO BE ENCAPSULATED)
  # ============================================================================
  
  output$explanation <- renderUI({
    tagList(
      p("The variable selection process includes two approaches: "),
      tags$ul(
        tags$li(
          strong("Recursive Feature Elimination (RFE): "),
          "RFE is an iterative process that selects the most relevant variables while eliminating the less important ones according to the underlying model. It is commonly used in models such as SVM."
        ),
        tags$li(
          strong("Embedded selection methods: "),
          "In models such as Random Forest and C5.0, the variable selection process is embedded within the model training itself. These methods automatically select important variables during model building."
        )
      ),
      p("The Venn diagram below represents the variables selected by each model, showing the intersections or consensus between them."),
      p(strong("Consensus variables: "), textOutput("consensus_vars"))
    )
  })
  
  #### 2D Represent Logic ####

  
  #### Protein 2D/3D Visualization ####
  
  server_protein_viz(
    input = input,
    output = output,
    session = session,
    clinical_data = reactive({ active_database() }),
    peptide_data = reactive({ full_pepdata() }),  # ← MATRIZ COMPLETA, no filtrada
    biomarkers = reactive({ if (length(consensus_biomarkers())) consensus_biomarkers() else selected_biomarkers() }),
    # Pass the reactive itself. With target = active_target_var() the promise was
    # forced once inside the module and frozen at that first value (usually NULL,
    # which fell through to the hardcoded "group"), so the protein tab never
    # followed the selected target.
    target = active_target_var,
    example_annotation = example_annotation
  )
  
  #### End Protein Visualization ####

  #### Quality Control ####

  # The positive-control dilution series is what tells us the assay responded.
  # Concentrations are read off the analyte name (e.g. "aIgE_0125", "aIgG_025");
  # only their order matters, the metric is a rank correlation.
  qc_positive_controls <- reactive({
    spots <- qc_spot_data()
    if (is.null(spots)) return(NULL)

    series <- unique(spots$ID[grepl("^a\\.?Ig", spots$ID, ignore.case = TRUE)])
    if (length(series) < 3) return(NULL)

    digits <- sub("^[^0-9]*", "", series)
    tibble::tibble(ID = series, dose = as.numeric(paste0("0.", digits))) %>%
      dplyr::filter(is.finite(dose))
  })

  qc_results <- setup_quality_server(
    input, output, session,
    qc_spots = reactive({ qc_spot_data() }),
    norm_diagnostics = reactive({ norm_diagnostics() }),
    positive_controls = qc_positive_controls,
    na_stats = reactive({ if (is.null(raw_pepdata())) NULL else na_stats() })
  )

  #### End Quality Control ####

  #### Report and results downloads ####

  # Every trained model's result (NULL when not run or failed)
  ml_runs <- reactive({
    runs <- list("C5.0" = c50_advanced_result, "Random Forest" = rf_advanced_result,
                 "SVM" = svm_advanced_result, "XGBoost" = xgboost_advanced_result)
    used <- c(isTRUE(input$ml_use_c50), isTRUE(input$ml_use_rf), isTRUE(input$ml_use_svm), isTRUE(input$ml_use_xgboost))
    lapply(runs[used], function(f) capture_ml_result(f)$result)
  })

  # Consensus table: peptides in the top N of at least two models
  ml_consensus <- reactive({
    top_n <- if (is.null(input$consensus_top_n)) 20 else input$consensus_top_n
    get <- function(use, f) if (isTRUE(use)) utils::head(tryCatch(as.character(f()), error = function(e) character(0)), top_n)
    vars <- Filter(length, list("C5.0" = get(input$ml_use_c50, variables_c5), "Random Forest" = get(input$ml_use_rf, variables_rf),
                                "SVM" = get(input$ml_use_svm, variables_importantes_reactive), "XGBoost" = get(input$ml_use_xgboost, variables_xgb)))
    req(length(vars) >= 2)
    feats <- unique(unlist(vars))
    hit <- matrix(vapply(vars, function(v) feats %in% v, logical(length(feats))), nrow = length(feats))
    rank <- matrix(vapply(vars, function(v) match(feats, v), integer(length(feats))), nrow = length(feats))
    out <- data.frame(peptide = feats, models = rowSums(hit),
                      which_models = apply(hit, 1, function(h) paste(names(vars)[h], collapse = ", ")),
                      mean_rank = round(rowMeans(rank, na.rm = TRUE), 1))
    out <- out[out$models >= 2, ]
    out[order(-out$models, out$mean_rank), ]
  })

  setup_report_server(input, output, session, src = list(
    active_database = active_database, processed_data = processed_data, raw_pepdata = raw_pepdata,
    available_analytes = available_analytes, path1 = path1, channel_labels = channel_labels,
    selected_channels = selected_channels, qc_results = qc_results, norm_diagnostics = norm_diagnostics,
    tests = tests, reg_models = reg_models, volcano_data = volcano_data, ml_runs = ml_runs, ml_prep = ml_prep,
    ml_consensus = ml_consensus, consensus_biomarkers = consensus_biomarkers, example_annotation = example_annotation))
  
  ########################### DOCUMENTATION ###################################
  # The user guide is now fully static HTML in R/ui/ui_documentation.R — no
  # server rendering required.
  #### End Documentation ####
  
}


shiny::shinyApp(ui, server)
