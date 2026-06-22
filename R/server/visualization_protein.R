# =============================================================================
# Server for 2D/3D Protein Visualization
# =============================================================================

#' Server logic for protein visualization
#' 
#' @param input Shiny input
#' @param output Shiny output
#' @param session Shiny session
#' @param clinical_data Reactive with clinical data (must contain target column)
#' @param peptide_data Reactive with peptide data
#' @param biomarkers Reactive with biomarkers vector (format: "p4 a-s2-cas", etc.)
#' @param target Name of target column in clinical data
#' @export
server_protein_viz <- function(input, output, session, 
                                clinical_data = NULL, 
                                peptide_data = NULL,
                                biomarkers = NULL,
                                target = NULL) {
  
  # Target puede ser reactive o string
  target_var <- reactive({
    if (is.reactive(target)) {
      target()
    } else if (!is.null(target)) {
      target
    } else {
      "group"  # Default
    }
  })
  
  # ============================================================================
  # REACTIVOS: Proteína seleccionada
  # ============================================================================
  
  # Trigger para cargar proteína
  protein_trigger <- reactiveVal(0)
  
  observeEvent(input$protein_load, {
    req(input$protein_uniprot_id, input$protein_regex)
    
    # Validar que tenemos datos necesarios
    if (is.null(peptide_data) || is.null(peptide_data())) {
      showNotification(
        "⚠️ Please load peptide data first (Preprocess tab)",
        type = "warning",
        duration = 5
      )
      return()
    }
    
    if (is.null(clinical_data) || is.null(clinical_data())) {
      showNotification(
        "⚠️ Please load clinical data first (Preprocess tab)",
        type = "warning",
        duration = 5
      )
      return()
    }
    
    # Verificar que hay péptidos que coincidan con el regex
    counts <- count_peptides(peptide_data(), input$protein_regex)
    if (counts$total == 0) {
      showNotification(
        paste("⚠️ No peptides found matching regex:", input$protein_regex),
        type = "warning",
        duration = 5
      )
      return()
    }
    
    showNotification(
      paste("🔍 Loading protein", input$protein_uniprot_id, "..."),
      type = "message",
      duration = 2
    )

    shinyjs::show("protein_loader")
    protein_trigger(protein_trigger() + 1)
  })

  # Hide the overlay once the 2D/3D controller reports the structure is rendered
  observeEvent(input$pv_structure_loaded, shinyjs::hide("protein_loader"))
  # Safety: also hide it if protein loading failed (invalid UniProt -> NULL)
  observeEvent(protein_info_data(), {
    if (is.null(protein_info_data())) shinyjs::hide("protein_loader")
  }, ignoreNULL = FALSE)
  
  # ============================================================================
  # REACTIVOS: Datos de proteína
  # ============================================================================
  
  protein_info_data <- reactive({
    req(protein_trigger() > 0)        # only after the user clicks "Load"
    req(input$protein_uniprot_id)

    isolate({
      uniprot_id <- input$protein_uniprot_id
      message("[PROTEIN_INFO] Fetching data for: ", uniprot_id)
      
      # Need a plausible accession before fetching (silent: no scary disclaimer)
      req(nchar(uniprot_id) >= 6)

      tryCatch({
        protein_info <- get_protein_info(uniprot_id, peptide_length = 20, offset = 3)
        
        showNotification(
          paste("✅ Proteína cargada:", nrow(protein_info$uniprot_info), "AA,",
                max(protein_info$Structure_info$Number, na.rm = TRUE), "péptidos"),
          type = "message", 
          duration = 3
        )
        
        protein_info
      }, error = function(e) {
        showNotification(
          paste("❌ Error al cargar proteína:", e$message), 
          type = "error", 
          duration = 7
        )
        NULL
      })
    })
  })
  
  # ============================================================================
  # OUTPUTS: Contador de péptidos
  # ============================================================================
  
  output$protein_peptide_count <- renderUI({
    # Solo requiere datos de peptides y regex, NO necesita protein_info_data()
    req(input$protein_regex)
    
    # Validar que hay datos de péptidos disponibles
    if (is.null(peptide_data) || is.null(peptide_data())) {
      return(
        tags$div(
          style = "background: #fff3cd; padding: 10px; border-radius: 5px; color: #856404;",
          tags$strong("⚠️ No peptide data loaded"),
          tags$p(
            style = "margin: 5px 0 0 0; font-size: 12px;",
            "Please load peptide data in Preprocess tab first"
          )
        )
      )
    }
    
    counts <- count_peptides(peptide_data(), input$protein_regex)
    
    tags$div(
      style = "background: #e3f2fd; padding: 15px; border-radius: 5px; border-left: 4px solid #2196F3;",
      tags$strong(style = "color: #1976D2; font-size: 16px;", "Peptides identified:"),
      tags$span(style = "margin-left: 10px; font-size: 18px; font-weight: bold; color: #0D47A1;", 
                paste(counts$total, "péptidos encontrados"))
    )
  })
  
  # ============================================================================
  # REACTIVOS: Procesar datos de expresión
  # ============================================================================
  
  # MANTENER expression_data() para compatibilidad (procesa TODO - IgE + IgG4)
  expression_data <- reactive({
    req(protein_info_data(), input$protein_regex)
    
    regex <- input$protein_regex
    
    # Si no hay datos externos, retornar NULL
    if (is.null(peptide_data) || is.null(clinical_data)) {
      return(NULL)
    }
    
    peptides <- peptide_data()
    clinics <- clinical_data()
    target <- target_var()
    
    # Contar péptidos
    counts <- count_peptides(peptides, regex)
    
    if (counts$total == 0) {
      return(NULL)
    }
    
    # Procesar peptide means
    message("\n[EXPRESSION_DATA] Processing peptide means...")
    peptide_means <- peptides %>%
      dplyr::select(id, dplyr::all_of(counts$cols)) %>%
      dplyr::inner_join(clinics %>% dplyr::select(id, dplyr::all_of(target)), by = "id") %>%
      dplyr::group_by(!!rlang::sym(target)) %>%
      dplyr::summarise(
        dplyr::across(dplyr::all_of(counts$cols), ~mean(.x, na.rm = TRUE)),
        .groups = "drop"
      )
    
    message("[EXPRESSION_DATA] Groups found: ", paste(unique(peptide_means[[target]]), collapse = ", "))
    
    peptide_means <- peptide_means %>%
      tidyr::pivot_longer(
        cols = -dplyr::all_of(target),
        names_to = "peptide",
        values_to = "expr_mean"
      ) %>%
      dplyr::mutate(Number = as.integer(stringr::str_match(peptide, "_p[ _.-]?(\\d+)_")[,2])) %>%
      dplyr::filter(!is.na(Number))
    
    message("[EXPRESSION_DATA] Peptide numbers range: ", min(peptide_means$Number, na.rm=TRUE), " - ", max(peptide_means$Number, na.rm=TRUE))
    message("[EXPRESSION_DATA] Total rows after pivot: ", nrow(peptide_means))
    
    # Renombrar columna target a group para compatibilidad
    colnames(peptide_means)[colnames(peptide_means) == target] <- "group"
    message("[EXPRESSION_DATA] Renamed '", target, "' to 'group'")
    
    # Procesar biomarcadores si están disponibles
    message("\n========== [BIOMARKER_MATCH] Starting ==========")
    biomarkers_tbl <- tryCatch({
      if (!is.null(biomarkers) && !is.null(biomarkers())) {
        biomarkers_raw <- biomarkers()
        message("[BIOMARKER_MATCH] Received ", length(biomarkers_raw), " biomarkers from ML")
        if (length(biomarkers_raw) > 0) {
          message("[BIOMARKER_MATCH] Full list: ", paste(biomarkers_raw, collapse = ", "))
          
          # CRITICAL: Filtrar SOLO los que tienen formato de péptido (contienen "_p\d+_")
          peptide_biomarkers <- biomarkers_raw[grepl("_p[ _.-]?\\d+_", biomarkers_raw)]
          non_peptide <- setdiff(biomarkers_raw, peptide_biomarkers)
          
          if (length(non_peptide) > 0) {
            message("[BIOMARKER_MATCH] ⚠️ Skipping non-peptide features: ", paste(non_peptide, collapse = ", "))
          }
          message("[BIOMARKER_MATCH] Peptide biomarkers to process: ", length(peptide_biomarkers))
          
          if (length(peptide_biomarkers) == 0) {
            message("[BIOMARKER_MATCH] No peptide biomarkers found")
            tibble::tibble(Number = integer(), antibody_type = character(), 
                          is_biomarker = logical(), biomarker_id = character())
          } else {
            result <- tibble::tibble(raw = peptide_biomarkers) %>%
              dplyr::mutate(
                # Extraer número DESPUÉS de _p: "IgE_p15_ovoalb_1" → 15
                Number = as.integer(stringr::str_match(raw, "_p[ _.-]?(\\d+)_")[,2]),
                # Extraer protein_id: "IgE_p15_ovoalb_1" → "ovoalb"
                protein_id = stringr::str_match(raw, "_p[ _.-]?\\d+_([^_]+)")[,2],
                # Extraer antibody type: "IgE_p15_..." → "IgE"
                antibody_type = stringr::str_extract(raw, "^(IgE|IgG4)")
              )
            
            message("[BIOMARKER_MATCH] Parsed biomarkers:")
            for (i in 1:nrow(result)) {
              message(sprintf("  [%d] '%s' → Number=%d, protein_id=%s, antibody=%s", 
                            i, result$raw[i], result$Number[i], 
                            result$protein_id[i], result$antibody_type[i]))
            }
            
            message("[BIOMARKER_MATCH] Unique protein IDs: ", paste(unique(result$protein_id), collapse = ", "))
            message("[BIOMARKER_MATCH] Unique antibody types: ", paste(unique(result$antibody_type), collapse = ", "))
            message("[BIOMARKER_MATCH] Current regex filter: '", regex, "'")
            
            # Filtrar por regex
            filtered_result <- result %>%
              dplyr::filter(grepl(regex, protein_id, ignore.case = TRUE))
            
            message("[BIOMARKER_MATCH] After regex filter: ", nrow(filtered_result), " biomarkers matched")
            
            if (nrow(filtered_result) > 0) {
              # MANTENER antibody_type para separación IgE/IgG4
              result <- filtered_result %>%
                dplyr::select(Number, antibody_type, raw) %>%
                dplyr::mutate(
                  is_biomarker = TRUE, 
                  biomarker_id = paste0("BM_p", Number, "_", antibody_type)
                )
              
              message("[BIOMARKER_MATCH] Final biomarkers: ", nrow(result))
              message("[BIOMARKER_MATCH] Matched peptide numbers: ", paste(result$Number, collapse = ", "))
              message("[BIOMARKER_MATCH] IgE biomarkers: ", sum(result$antibody_type == "IgE"))
              message("[BIOMARKER_MATCH] IgG4 biomarkers: ", sum(result$antibody_type == "IgG4"))
              result
            } else {
              message("[BIOMARKER_MATCH] ⚠️ WARNING: No biomarkers matched the regex!")
              tibble::tibble(Number = integer(), antibody_type = character(), 
                            is_biomarker = logical(), biomarker_id = character())
            }
          }
        } else {
          tibble::tibble(Number = integer(), antibody_type = character(), 
                        is_biomarker = logical(), biomarker_id = character())
        }
      } else {
        tibble::tibble(Number = integer(), antibody_type = character(), 
                      is_biomarker = logical(), biomarker_id = character())
      }
    }, error = function(e) {
      message("[BIOMARKER_MATCH] ❌ ERROR: ", e$message)
      message("[BIOMARKER_MATCH] Stack trace:")
      print(traceback())
      tibble::tibble(Number = integer(), antibody_type = character(), 
                    is_biomarker = logical(), biomarker_id = character())
    })
    
    message("========== [BIOMARKER_MATCH] Complete ==========")
    
    message("\n[EXPRESSION_DATA] Joining biomarkers with peptide_means...")
    message("[EXPRESSION_DATA] Biomarkers_tbl rows: ", nrow(biomarkers_tbl))
    message("[EXPRESSION_DATA] Biomarkers_tbl columns: ", paste(colnames(biomarkers_tbl), collapse = ", "))
    
    peptide_means <- peptide_means %>%
      dplyr::left_join(biomarkers_tbl, by = "Number") %>%
      dplyr::mutate(
        is_biomarker = ifelse(is.na(is_biomarker), FALSE, TRUE),
        biomarker_id = ifelse(is.na(biomarker_id), NA_character_, biomarker_id),
        antibody_type = ifelse(is.na(antibody_type), NA_character_, antibody_type)
      )
    
    # Notificar procesamiento exitoso
    showNotification(
      paste("📊 Expression data processed -", counts$total, "peptides,", nrow(biomarkers_tbl), "biomarkers"),
      type = "message",
      duration = 3
    )
    
    list(
      peptide_means = peptide_means,
      biomarkers_tbl = biomarkers_tbl
    )
  })
  

  
  # ============================================================================
  # REACTIVOS: Datos SEPARADOS por analito (IgE e IgG4)
  # ============================================================================
  
  # Expression data para IgE SOLAMENTE
  expression_data_ige <- reactive({
    req(protein_info_data(), input$protein_regex)
    
    regex <- input$protein_regex
    
    if (is.null(peptide_data) || is.null(clinical_data)) {
      return(NULL)
    }
    
    peptides <- peptide_data()
    clinics <- clinical_data()
    target <- target_var()
    
    # Filtrar SOLO columnas IgE
    message("\n[EXPRESSION_IgE] Filtering IgE peptides...")
    ige_cols <- names(peptides)[grepl("^IgE_", names(peptides)) & grepl(regex, names(peptides), ignore.case = TRUE)]
    
    if (length(ige_cols) == 0) {
      message("[EXPRESSION_IgE] No IgE peptides found for regex: ", regex)
      return(NULL)
    }
    
    message("[EXPRESSION_IgE] Found ", length(ige_cols), " IgE peptides")
    
    # Calcular medias por grupo
    peptide_means <- peptides %>%
      dplyr::select(id, dplyr::all_of(ige_cols)) %>%
      dplyr::inner_join(clinics %>% dplyr::select(id, dplyr::all_of(target)), by = "id") %>%
      dplyr::group_by(!!rlang::sym(target)) %>%
      dplyr::summarise(
        dplyr::across(dplyr::all_of(ige_cols), ~mean(.x, na.rm = TRUE)),
        .groups = "drop"
      ) %>%
      tidyr::pivot_longer(
        cols = -dplyr::all_of(target),
        names_to = "peptide",
        values_to = "expr_mean"
      ) %>%
      dplyr::mutate(Number = as.integer(stringr::str_match(peptide, "_p[ _.-]?(\\d+)_")[,2])) %>%
      dplyr::filter(!is.na(Number))

    if (nrow(peptide_means) == 0) {
      message("[EXPRESSION_IgE] No positional peptides (e.g. _p11_ / _p_11_) matched; nothing to map.")
      return(NULL)
    }

    colnames(peptide_means)[colnames(peptide_means) == target] <- "group"

    # Filtrar biomarcadores IgE
    biomarkers_tbl <- if (!is.null(biomarkers) && !is.null(biomarkers())) {
      expression_data()$biomarkers_tbl %>%
        dplyr::filter(antibody_type == "IgE")
    } else {
      tibble::tibble(Number = integer(), antibody_type = character(), 
                    is_biomarker = logical(), biomarker_id = character())
    }
    
    message("[EXPRESSION_IgE] IgE biomarkers: ", nrow(biomarkers_tbl))
    
    peptide_means <- peptide_means %>%
      dplyr::left_join(biomarkers_tbl, by = "Number") %>%
      dplyr::mutate(
        is_biomarker = ifelse(is.na(is_biomarker), FALSE, TRUE),
        biomarker_id = ifelse(is.na(biomarker_id), NA_character_, biomarker_id),
        antibody_type = "IgE"
      )
    
    list(
      peptide_means = peptide_means,
      biomarkers_tbl = biomarkers_tbl
    )
  })
  
  # Expression data para IgG4 SOLAMENTE
  expression_data_igg4 <- reactive({
    req(protein_info_data(), input$protein_regex)
    
    regex <- input$protein_regex
    
    if (is.null(peptide_data) || is.null(clinical_data)) {
      return(NULL)
    }
    
    peptides <- peptide_data()
    clinics <- clinical_data()
    target <- target_var()
    
    # Filtrar SOLO columnas IgG4
    message("\n[EXPRESSION_IgG4] Filtering IgG4 peptides...")
    igg4_cols <- names(peptides)[grepl("^IgG4_", names(peptides)) & grepl(regex, names(peptides), ignore.case = TRUE)]
    
    if (length(igg4_cols) == 0) {
      message("[EXPRESSION_IgG4] No IgG4 peptides found for regex: ", regex)
      return(NULL)
    }
    
    message("[EXPRESSION_IgG4] Found ", length(igg4_cols), " IgG4 peptides")
    
    # Calcular medias por grupo
    peptide_means <- peptides %>%
      dplyr::select(id, dplyr::all_of(igg4_cols)) %>%
      dplyr::inner_join(clinics %>% dplyr::select(id, dplyr::all_of(target)), by = "id") %>%
      dplyr::group_by(!!rlang::sym(target)) %>%
      dplyr::summarise(
        dplyr::across(dplyr::all_of(igg4_cols), ~mean(.x, na.rm = TRUE)),
        .groups = "drop"
      ) %>%
      tidyr::pivot_longer(
        cols = -dplyr::all_of(target),
        names_to = "peptide",
        values_to = "expr_mean"
      ) %>%
      dplyr::mutate(Number = as.integer(stringr::str_match(peptide, "_p[ _.-]?(\\d+)_")[,2])) %>%
      dplyr::filter(!is.na(Number))

    if (nrow(peptide_means) == 0) {
      message("[EXPRESSION_IgG4] No positional peptides (e.g. _p11_ / _p_11_) matched; nothing to map.")
      return(NULL)
    }

    colnames(peptide_means)[colnames(peptide_means) == target] <- "group"

    # Filtrar biomarcadores IgG4
    biomarkers_tbl <- if (!is.null(biomarkers) && !is.null(biomarkers())) {
      expression_data()$biomarkers_tbl %>%
        dplyr::filter(antibody_type == "IgG4")
    } else {
      tibble::tibble(Number = integer(), antibody_type = character(), 
                    is_biomarker = logical(), biomarker_id = character())
    }
    
    message("[EXPRESSION_IgG4] IgG4 biomarkers: ", nrow(biomarkers_tbl))
    
    peptide_means <- peptide_means %>%
      dplyr::left_join(biomarkers_tbl, by = "Number") %>%
      dplyr::mutate(
        is_biomarker = ifelse(is.na(is_biomarker), FALSE, TRUE),
        biomarker_id = ifelse(is.na(biomarker_id), NA_character_, biomarker_id),
        antibody_type = "IgG4"
      )
    
    list(
      peptide_means = peptide_means,
      biomarkers_tbl = biomarkers_tbl
    )
  })
  
  # ============================================================================
  # REACTIVOS: AA_data separados por analito
  # ============================================================================
  
  AA_data_ige <- reactive({
    req(protein_info_data(), expression_data_ige())
    
    message("\n[AA_DATA_IgE] Preparing IgE snake plot data...")
    Structure_info <- protein_info_data()$Structure_info
    peptide_means <- expression_data_ige()$peptide_means
    signal_length <- protein_info_data()$signal_length
    uniprot_info <- protein_info_data()$uniprot_info
    
    message("[AA_DATA_IgE] Structure_info rows: ", nrow(Structure_info))
    message("[AA_DATA_IgE] peptide_means rows: ", nrow(peptide_means))
    message("[AA_DATA_IgE] IgE biomarkers: ", sum(peptide_means$is_biomarker, na.rm = TRUE))
    
    result <- prepare_snake_data(
      Structure_info, peptide_means, signal_length, uniprot_info, 17, 2, 1
    )
    
    message("[AA_DATA_IgE] ✓ IgE snake data prepared:")
    message("  - Protein_plot rows: ", nrow(result$Protein_plot))
    message("  - Biomarker_plot rows: ", nrow(result$Biomarker_plot))
    
    result
  })
  
  AA_data_igg4 <- reactive({
    req(protein_info_data(), expression_data_igg4())
    
    message("\n[AA_DATA_IgG4] Preparing IgG4 snake plot data...")
    Structure_info <- protein_info_data()$Structure_info
    peptide_means <- expression_data_igg4()$peptide_means
    signal_length <- protein_info_data()$signal_length
    uniprot_info <- protein_info_data()$uniprot_info
    
    message("[AA_DATA_IgG4] Structure_info rows: ", nrow(Structure_info))
    message("[AA_DATA_IgG4] peptide_means rows: ", nrow(peptide_means))
    message("[AA_DATA_IgG4] IgG4 biomarkers: ", sum(peptide_means$is_biomarker, na.rm = TRUE))
    
    result <- prepare_snake_data(
      Structure_info, peptide_means, signal_length, uniprot_info, 17, 2, 1
    )
    
    message("[AA_DATA_IgG4] ✓ IgG4 snake data prepared:")
    message("  - Protein_plot rows: ", nrow(result$Protein_plot))
    message("  - Biomarker_plot rows: ", nrow(result$Biomarker_plot))
    
    result
  })
  
  # ============================================================================
  # REACTIVOS: Datos completos LEGACY (mantener para compatibilidad)
  # ============================================================================
  
  AA_data <- reactive({
    req(protein_info_data(), expression_data())
    
    message("\n[AA_DATA] Preparing snake plot data...")
    Structure_info <- protein_info_data()$Structure_info
    peptide_means <- expression_data()$peptide_means
    signal_length <- protein_info_data()$signal_length
    uniprot_info <- protein_info_data()$uniprot_info
    
    message("[AA_DATA] Structure_info rows: ", nrow(Structure_info))
    message("[AA_DATA] peptide_means rows: ", nrow(peptide_means))
    message("[AA_DATA] Signal length: ", signal_length)
    
    # Debug biomarkers
    biomarkers_in_means <- unique(peptide_means$biomarker_id[!is.na(peptide_means$biomarker_id)])
    message("[AA_DATA] Unique biomarker IDs in peptide_means: ", paste(biomarkers_in_means, collapse = ", "))
    
    result <- prepare_snake_data(
      Structure_info, peptide_means, signal_length, uniprot_info, 17, 2, 1
    )
    
    message("[AA_DATA] ✓ Snake data prepared:")
    message("  - Protein_plot rows: ", nrow(result$Protein_plot))
    message("  - Biomarker_plot rows: ", nrow(result$Biomarker_plot))
    message("  - PTM_plot rows: ", nrow(result$PTM_plot))
    message("  - Signal_plot rows: ", nrow(result$Signal_plot))
    
    if (nrow(result$Biomarker_plot) > 0) {
      message("  - Biomarker positions: ", paste(unique(result$Biomarker_plot$Pos), collapse = ", "))
    } else {
      message("  - ⚠️ NO BIOMARKERS IN PLOT DATA!")
    }
    
    result
  })

  # ============================================================================
  # OUTPUT: feed the D3 (2D) + 3Dmol (3D) controller with real pipeline data
  # ============================================================================

  `%||%` <- function(a, b) if (is.null(a)) b else a
  na_false <- function(x) ifelse(is.na(x), FALSE, x)
  rows_list <- function(df) lapply(seq_len(nrow(df)), function(i) as.list(df[i, ]))

  output$protein_info_display <- renderUI({
    req(protein_info_data())
    info <- protein_info_data()
    tagList(
      tags$strong("Protein Information:"),
      tags$ul(
        tags$li(paste("Signal peptide:", info$signal_length, "AA")),
        tags$li(paste("Total:", nrow(info$uniprot_info), "AA")),
        tags$li(paste("Peptides:", max(info$Structure_info$Number, na.rm = TRUE))),
        tags$li(paste("Disulfides:", length(info$disulfides %||% list())))
      )
    )
  })

  # Clinical group levels (group selector + Δ-groups mode)
  protein_groups <- reactive({
    req(clinical_data(), target_var())
    levels(factor(clinical_data()[[target_var()]]))
  })
  output$protein_group_ui <- renderUI({
    g <- protein_groups()
    radioButtons("protein_group", "Group", choices = g, selected = g[1])
  })

  # Per-(isotype, group, position) dataset, reusing the snake summaries
  protein_dataset <- reactive({
    req(AA_data_ige(), AA_data_igg4())
    to_rows <- function(d, iso) {
      s <- d$AA_expression_summary
      data.frame(
        pos = s$Pos, aa = s$AA_Pep, isotype = iso, group = s$group,
        expr = replace(s$expr_mean, is.nan(s$expr_mean), NA_real_),
        is_biomarker = na_false(s$is_biomarker), padj = NA_real_,
        is_signal = na_false(s$is_signal), mod = s$mod, peptide = NA_integer_,
        stringsAsFactors = FALSE
      )
    }
    rbind(to_rows(AA_data_ige(), "IgE"), to_rows(AA_data_igg4(), "IgG4"))
  })

  view <- function() list(
    isotype = isolate(input$protein_isotype) %||% "IgE",
    group   = isolate(input$protein_group) %||% protein_groups()[1],
    mode    = isolate(input$protein_color_mode) %||% "expr",
    fdr     = isolate(input$protein_fdr) %||% 0.05,
    surface = isTRUE(isolate(input$protein_show_surface)),
    biomarkers = isTRUE(isolate(input$protein_biomarkers) %||% TRUE)
  )

  send_all <- function() {
    info <- isolate(protein_info_data())
    session$sendCustomMessage("loadProtein", list(
      uniprot = isolate(input$protein_uniprot_id), chain = "A",
      signalLength = info$signal_length, disulfides = info$disulfides %||% list(),
      isotypes = list("IgE", "IgG4"), groups = as.list(protein_groups()),
      data = rows_list(protein_dataset()), view = view()
    ))
  }
  push_view <- function() session$sendCustomMessage("setView", view())

  observeEvent(protein_dataset(), send_all())
  observeEvent(input$protein_isotype, push_view(), ignoreInit = TRUE)
  observeEvent(input$protein_group, push_view(), ignoreInit = TRUE)
  observeEvent(input$protein_color_mode, push_view(), ignoreInit = TRUE)
  observeEvent(input$protein_fdr, push_view(), ignoreInit = TRUE)
  observeEvent(input$protein_show_surface, push_view(), ignoreInit = TRUE)
  observeEvent(input$protein_biomarkers, push_view(), ignoreInit = TRUE)

  output$protein_export <- downloadHandler(
    filename = function() paste0("biomarkers_", isolate(input$protein_isotype) %||% "IgE", ".fasta"),
    content = function(file) {
      df <- protein_dataset(); v <- view()
      bm <- df[df$isotype == v$isotype & df$group == v$group & df$is_biomarker & !df$is_signal, ]
      bm <- bm[order(bm$pos), ]
      if (nrow(bm) == 0) { writeLines("; no biomarkers selected", file); return() }
      brk <- c(0, cumsum(diff(bm$pos) != 1))               # contiguous stretches
      lines <- unlist(lapply(split(bm, brk), function(r) c(
        sprintf(">%s_%d-%d isotype=%s", isolate(input$protein_uniprot_id), min(r$pos), max(r$pos), v$isotype),
        paste(r$aa, collapse = ""))))
      writeLines(lines, file)
    }
  )
}
