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
      "Risk2"  # Default
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
    
    protein_trigger(protein_trigger() + 1)
  })
  
  # ============================================================================
  # REACTIVOS: Datos de proteína
  # ============================================================================
  
  protein_info_data <- reactive({
    req(input$protein_uniprot_id)
    protein_trigger()  # Depender del trigger
    
    isolate({
      uniprot_id <- input$protein_uniprot_id
      message("[PROTEIN_INFO] Fetching data for: ", uniprot_id)
      
      # Validate format
      if (nchar(uniprot_id) < 6) {
        showNotification("❌ Invalid UniProt ID", type = "error")
        return(NULL)
      }
      
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
      dplyr::mutate(Number = as.integer(stringr::str_match(peptide, "_p(\\d+)_")[,2])) %>%
      dplyr::filter(!is.na(Number))
    
    message("[EXPRESSION_DATA] Peptide numbers range: ", min(peptide_means$Number, na.rm=TRUE), " - ", max(peptide_means$Number, na.rm=TRUE))
    message("[EXPRESSION_DATA] Total rows after pivot: ", nrow(peptide_means))
    
    # Renombrar columna target a Risk2 para compatibilidad
    colnames(peptide_means)[colnames(peptide_means) == target] <- "Risk2"
    message("[EXPRESSION_DATA] Renamed '", target, "' to 'Risk2'")
    
    # Procesar biomarcadores si están disponibles
    message("\n========== [BIOMARKER_MATCH] Starting ==========")
    biomarkers_tbl <- tryCatch({
      if (!is.null(biomarkers) && !is.null(biomarkers())) {
        biomarkers_raw <- biomarkers()
        message("[BIOMARKER_MATCH] Received ", length(biomarkers_raw), " biomarkers from ML")
        if (length(biomarkers_raw) > 0) {
          message("[BIOMARKER_MATCH] Full list: ", paste(biomarkers_raw, collapse = ", "))
          
          # CRITICAL: Filtrar SOLO los que tienen formato de péptido (contienen "_p\d+_")
          peptide_biomarkers <- biomarkers_raw[grepl("_p\\d+_", biomarkers_raw)]
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
                Number = as.integer(stringr::str_match(raw, "_p(\\d+)_")[,2]),
                # Extraer protein_id: "IgE_p15_ovoalb_1" → "ovoalb"
                protein_id = stringr::str_match(raw, "_p\\d+_([^_]+)")[,2],
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
      dplyr::mutate(Number = as.integer(stringr::str_match(peptide, "_p(\\d+)_")[,2])) %>%
      dplyr::filter(!is.na(Number))
    
    colnames(peptide_means)[colnames(peptide_means) == target] <- "Risk2"
    
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
      dplyr::mutate(Number = as.integer(stringr::str_match(peptide, "_p(\\d+)_")[,2])) %>%
      dplyr::filter(!is.na(Number))
    
    colnames(peptide_means)[colnames(peptide_means) == target] <- "Risk2"
    
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
  # OUTPUTS: Snake plots separados por analito
  # ============================================================================
  
  # Snake plot IgE
  output$protein_snake_ige <- ggiraph::renderGirafe({
    # Si no se ha activado el trigger, mostrar placeholder
    if (protein_trigger() == 0) {
      empty_plot <- ggplot2::ggplot() +
        ggplot2::annotate(
          "text", x = 0.5, y = 0.6,
          label = "🔴 IgE Ready",
          size = 7, color = "#e74c3c", fontface = "bold"
        ) +
        ggplot2::annotate(
          "text", x = 0.5, y = 0.4,
          label = "Enter UniProt ID and Regex, then click 'Load and Visualize'",
          size = 4, color = "#666"
        ) +
        ggplot2::theme_void() +
        ggplot2::xlim(0, 1) +
        ggplot2::ylim(0, 1)
      
      return(ggiraph::girafe(ggobj = empty_plot, width_svg = 12, height_svg = 3.5))
    }
    
    req(protein_info_data())
    
    # Validar que hay datos IgE
    if (is.null(expression_data_ige())) {
      empty_plot <- ggplot2::ggplot() +
        ggplot2::annotate(
          "text", x = 0.5, y = 0.5,
          label = "No IgE peptides found.\nCheck your regex pattern.",
          size = 6, color = "#e74c3c"
        ) +
        ggplot2::theme_void() +
        ggplot2::xlim(0, 1) +
        ggplot2::ylim(0, 1)
      
      return(ggiraph::girafe(ggobj = empty_plot, width_svg = 12, height_svg = 3.5))
    }
    
    req(AA_data_ige())
    
    plot_data <- AA_data_ige()
    
    snake_gg <- create_snake_plot(
      Protein_plot = plot_data$Protein_plot,
      PTM_plot = plot_data$PTM_plot,
      Biomarker_plot = plot_data$Biomarker_plot,
      Signal_plot = plot_data$Signal_plot,
      color_palette = "green",  # Green scale for IgE
      facet_type = "vertical",  # Vertical facets (stacked)
      aspect_ratio = 0.55       # Optimal aspect ratio
    )
    
    ggiraph::girafe(
      ggobj = snake_gg,
      width_svg = 10,
      height_svg = 9,
      options = list(
        ggiraph::opts_hover(css = "stroke-width:3;opacity:1;"),
        ggiraph::opts_hover_inv(css = "opacity:0.5;"),
        ggiraph::opts_selection(type = "none"),
        ggiraph::opts_tooltip(
          use_fill = FALSE,
          css = "background-color:rgba(0,0,0,0.85);color:white;padding:8px;border-radius:6px;font-size:12px;"
        )
      )
    )
  })
  
  # Snake plot IgG4
  output$protein_snake_igg4 <- ggiraph::renderGirafe({
    # Si no se ha activado el trigger, mostrar placeholder
    if (protein_trigger() == 0) {
      empty_plot <- ggplot2::ggplot() +
        ggplot2::annotate(
          "text", x = 0.5, y = 0.6,
          label = "🔵 IgG4 Ready",
          size = 7, color = "#3498db", fontface = "bold"
        ) +
        ggplot2::annotate(
          "text", x = 0.5, y = 0.4,
          label = "Enter UniProt ID and Regex, then click 'Load and Visualize'",
          size = 4, color = "#666"
        ) +
        ggplot2::theme_void() +
        ggplot2::xlim(0, 1) +
        ggplot2::ylim(0, 1)
      
      return(ggiraph::girafe(ggobj = empty_plot, width_svg = 12, height_svg = 3.5))
    }
    
    req(protein_info_data())
    
    # Validar que hay datos IgG4
    if (is.null(expression_data_igg4())) {
      empty_plot <- ggplot2::ggplot() +
        ggplot2::annotate(
          "text", x = 0.5, y = 0.5,
          label = "No IgG4 peptides found.\nCheck your regex pattern.",
          size = 6, color = "#3498db"
        ) +
        ggplot2::theme_void() +
        ggplot2::xlim(0, 1) +
        ggplot2::ylim(0, 1)
      
      return(ggiraph::girafe(ggobj = empty_plot, width_svg = 12, height_svg = 3.5))
    }
    
    req(AA_data_igg4())
    
    plot_data <- AA_data_igg4()
    
    snake_gg <- create_snake_plot(
      Protein_plot = plot_data$Protein_plot,
      PTM_plot = plot_data$PTM_plot,
      Biomarker_plot = plot_data$Biomarker_plot,
      Signal_plot = plot_data$Signal_plot,
      color_palette = "red",    # Red scale for IgG4
      facet_type = "vertical",  # Vertical facets (stacked)
      aspect_ratio = 0.55       # Optimal aspect ratio
    )
    
    ggiraph::girafe(
      ggobj = snake_gg,
      width_svg = 10,
      height_svg = 9,
      options = list(
        ggiraph::opts_hover(css = "stroke-width:3;opacity:1;"),
        ggiraph::opts_hover_inv(css = "opacity:0.5;"),
        ggiraph::opts_selection(type = "none"),
        ggiraph::opts_tooltip(
          use_fill = FALSE,
          css = "background-color:rgba(0,0,0,0.85);color:white;padding:8px;border-radius:6px;font-size:12px;"
        )
      )
    )
  })

  
  # ============================================================================
  # OUTPUTS: NGL Viewers 3D separados por analito
  # ============================================================================
  
  # 3D Viewer para IgE
  output$protein_3d_ige <- renderUI({
    # Solo mostrar iframe si se ha cargado la proteína
    if (protein_trigger() == 0) {
      tags$div(
        style = "width: 100%; height: 600px; display: flex; align-items: center; justify-content: center; background: #ffe6e6; border: 2px dashed #e74c3c; border-radius: 10px;",
        tags$div(
          style = "text-align: center; color: #666;",
          tags$h4(style = "color: #e74c3c; margin-bottom: 10px;", "🔴 IgE 3D Structure"),
          tags$p("Click 'Load and Visualize' to load the protein structure")
        )
      )
    } else {
      tags$iframe(
        src = "ngl_viewer.html",
        width = "100%",
        height = "600px",
        style = "border:none; border-radius:10px;"
      )
    }
  })
  
  # 3D Viewer para IgG4
  output$protein_3d_igg4 <- renderUI({
    # Solo mostrar iframe si se ha cargado la proteína
    if (protein_trigger() == 0) {
      tags$div(
        style = "width: 100%; height: 600px; display: flex; align-items: center; justify-content: center; background: #e6f2ff; border: 2px dashed #3498db; border-radius: 10px;",
        tags$div(
          style = "text-align: center; color: #666;",
          tags$h4(style = "color: #3498db; margin-bottom: 10px;", "🔵 IgG4 3D Structure"),
          tags$p("Click 'Load and Visualize' to load the protein structure")
        )
      )
    } else {
      tags$iframe(
        src = "ngl_viewer.html",
        width = "100%",
        height = "600px",
        style = "border:none; border-radius:10px;"
      )
    }
  })
  
  # ============================================================================
  # OUTPUTS: Info de proteína
  # ============================================================================
  
  output$protein_info_display <- renderUI({
    req(protein_info_data())
    
    info <- protein_info_data()
    
    tagList(
      tags$strong("Protein Information:"),
      tags$ul(
        tags$li(paste("Signal peptide:", info$signal_length, "AA")),
        tags$li(paste("Total:", nrow(info$uniprot_info), "AA")),
        tags$li(paste("Peptides:", max(info$Structure_info$Number, na.rm = TRUE)))
      )
    )
  })
  
  # ============================================================================
  # OBSERVERS: Comunicación con NGL Viewer
  # ============================================================================
  
  # Preparar datos de biomarcadores para NGL (todos los péptidos)
  biomarker_data <- reactive({
    req(protein_info_data())
    
    # Validar que tengamos datos de expresión
    if (is.null(expression_data())) {
      return(list(
        biomarker_resi = integer(0),
        biomarker_resi_ngl = integer(0),
        signal_length = protein_info_data()$signal_length,
        num_biomarkers = 0
      ))
    }
    
    Structure_info <- protein_info_data()$Structure_info
    signal_length <- protein_info_data()$signal_length
    
    # Función auxiliar
    make_resi_list_for_numbers <- function(nums) {
      sort(unique(Structure_info$Pos[Structure_info$Number %in% nums]))
    }
    
    # Obtener números de biomarcadores
    biomarker_nums <- if (!is.null(expression_data()$biomarkers_tbl) && nrow(expression_data()$biomarkers_tbl) > 0) {
      expression_data()$biomarkers_tbl$Number
    } else {
      integer(0)
    }
    
    biomarker_resi <- if (length(biomarker_nums) > 0) {
      make_resi_list_for_numbers(biomarker_nums)
    } else {
      integer(0)
    }
    
    # Notify biomarkers found
    if (length(biomarker_nums) > 0) {
      showNotification(
        paste("🎯", length(biomarker_nums), "biomarkers identified for this protein"),
        type = "message",
        duration = 3
      )
    }
    
    list(
      biomarker_resi = biomarker_resi,
      biomarker_resi_ngl = if (length(biomarker_resi) > 0) biomarker_resi - signal_length else integer(0),
      signal_length = signal_length,
      num_biomarkers = length(biomarker_nums)
    )
  })
  
  # Inicializar NGL cuando esté listo
  observeEvent(input$molstar_ready, {
    message("\n========== [MOLSTAR_READY] EVENT TRIGGERED ==========")
    message("[MOLSTAR_READY] input$molstar_ready value: ", input$molstar_ready)
    message("[MOLSTAR_READY] protein_info_data available: ", !is.null(protein_info_data()))
    message("[MOLSTAR_READY] input$protein_uniprot_id: ", input$protein_uniprot_id)
    
    req(protein_info_data(), input$protein_uniprot_id)
    
    # Validar que tenemos datos de expresión
    if (is.null(AA_data())) {
      message("[MOLSTAR_READY] ⚠️ NGL Viewer ready but no expression data available yet")
      return()
    }
    
    message("[MOLSTAR_READY] ✅ All data available, initializing 3D viewer...")
    message("[MOLSTAR_READY] Loading structure for UniProt: ", input$protein_uniprot_id)
    
    # Cargar estructura
    session$sendCustomMessage(
      type = "send_to_molstar",
      message = list(
        type = "load_structure",
        uniprot_id = input$protein_uniprot_id
      )
    )
    
    bm_data <- biomarker_data()
    signal_length <- bm_data$signal_length
    biomarker_resi_ngl <- bm_data$biomarker_resi_ngl
    
    AA_expression_summary <- AA_data()$AA_expression_summary
    
    if (is.null(AA_expression_summary)) {
      message("⚠️ No expression summary available for 3D visualization")
      return()
    }
    
    # Preparar datos de expresión - usar grupos dinámicos, no hardcodeados
    expr_by_group <- AA_expression_summary %>%
      dplyr::filter(!is_signal, !is.na(expr_mean)) %>%
      dplyr::select(Pos, Risk2, expr_mean) %>%
      tidyr::pivot_wider(names_from = Risk2, values_from = expr_mean)
    
    # Obtener nombres de grupos dinámicamente
    group_names <- setdiff(colnames(expr_by_group), "Pos")
    message("\n[NGL_READY] Preparing expression data for tooltips...")
    message("[NGL_READY] Groups found: ", paste(group_names, collapse = ", "))
    message("[NGL_READY] Positions with expression: ", nrow(expr_by_group))
    
    expr_data <- list()
    for (i in 1:nrow(expr_by_group)) {
      pos <- as.character(expr_by_group$Pos[i])
      row_data <- as.list(expr_by_group[i, group_names, drop = FALSE])
      names(row_data) <- group_names
      expr_data[[pos]] <- row_data
    }
    
    message("[NGL_READY] Expression data prepared for ", length(expr_data), " positions")
    message("[NGL_READY] Example (first position):")
    if (length(expr_data) > 0) {
      first_pos <- names(expr_data)[1]
      message("  Position ", first_pos, ": ", paste(names(expr_data[[first_pos]]), "=", 
             round(unlist(expr_data[[first_pos]]), 2), collapse = ", "))
    }
    
    message("\n[NGL_READY] Sending highlight_biomarkers message...")
    message("[NGL_READY] Biomarker residues (NGL coords): ", paste(biomarker_resi_ngl, collapse = ", "))
    message("[NGL_READY] Signal length: ", signal_length)
    
    # Enviar biomarcadores
    session$sendCustomMessage(
      type = "send_to_molstar",
      message = list(
        type = "highlight_biomarkers",
        uniprot_id = input$protein_uniprot_id,
        residues = as.list(biomarker_resi_ngl),
        signal_length = signal_length,
        expression_data = expr_data
      )
    )
    
    message("[NGL_READY] ✓ highlight_biomarkers message sent")
    
    # Marcar péptido señal
    if (signal_length > 0) {
      session$sendCustomMessage(
        type = "send_to_molstar",
        message = list(
          type = "mark_signal",
          signal_residues = as.list(1:signal_length)
        )
      )
    }
  }, ignoreInit = TRUE)
  
  # Actualizar cuando cambie la proteína
  observeEvent(protein_trigger(), {
    req(protein_info_data(), input$protein_uniprot_id)
    
    # Validar que tenemos datos antes de continuar
    if (is.null(AA_data())) {
      message("⚠️ Protein loaded but no expression data available for 3D update")
      return()
    }
    
    bm_data <- biomarker_data()
    signal_length <- bm_data$signal_length
    biomarker_resi_ngl <- bm_data$biomarker_resi_ngl
    
    AA_expression_summary <- AA_data()$AA_expression_summary
    
    if (is.null(AA_expression_summary)) {
      message("⚠️ No expression summary available for 3D update")
      return()
    }
    
    # Preparar datos de expresión - usar grupos dinámicos
    expr_by_group <- AA_expression_summary %>%
      dplyr::filter(!is_signal, !is.na(expr_mean)) %>%
      dplyr::select(Pos, Risk2, expr_mean) %>%
      tidyr::pivot_wider(names_from = Risk2, values_from = expr_mean)
    
    # Obtener nombres de grupos dinámicamente
    group_names <- setdiff(colnames(expr_by_group), "Pos")
    
    expr_data <- list()
    for (i in 1:nrow(expr_by_group)) {
      pos <- as.character(expr_by_group$Pos[i])
      row_data <- as.list(expr_by_group[i, group_names, drop = FALSE])
      names(row_data) <- group_names
      expr_data[[pos]] <- row_data
    }
    
    # Cargar nueva estructura
    session$sendCustomMessage(
      type = "send_to_molstar",
      message = list(
        type = "load_structure",
        uniprot_id = input$protein_uniprot_id
      )
    )
    
    # Enviar biomarcadores
    session$sendCustomMessage(
      type = "send_to_molstar",
      message = list(
        type = "highlight_biomarkers",
        uniprot_id = input$protein_uniprot_id,
        residues = as.list(biomarker_resi_ngl),
        signal_length = signal_length,
        expression_data = expr_data
      )
    )
    
    # Marcar péptido señal
    if (signal_length > 0) {
      session$sendCustomMessage(
        type = "send_to_molstar",
        message = list(
          type = "mark_signal",
          signal_residues = as.list(1:signal_length)
        )
      )
    }
  }, ignoreInit = TRUE)
  
  # Conectar hover de ggiraph con NGL
  observeEvent(input$snake_hovered, {
    hovered_id <- input$snake_hovered
    
    if (!is.null(hovered_id) && hovered_id != "") {
      if (grepl("^\\d+$", hovered_id)) {
        pos <- as.integer(hovered_id)
        
        session$sendCustomMessage(
          type = "send_to_molstar",
          message = list(
            type = "hover_residue",
            pos = pos
          )
        )
      }
    } else {
      session$sendCustomMessage(
        type = "send_to_molstar",
        message = list(type = "hover_residue", pos = NULL)
      )
    }
  }, ignoreInit = TRUE, ignoreNULL = FALSE)
  
  # Switch de modo de color
  observeEvent(input$protein_color_mode, {
    message("\n[COLOR_MODE] Observer triggered: ", input$protein_color_mode)
    
    # Process IgE color mode
    if (!is.null(expression_data_ige()) && !is.null(AA_data_ige())) {
      message("[COLOR_MODE] Processing IgE...")
      
      if (input$protein_color_mode == "expression") {
        AA_summary_ige <- AA_data_ige()$AA_expression_summary
        first_group <- unique(AA_summary_ige$Risk2)[1]
        
        expr_by_pos <- AA_summary_ige %>%
          dplyr::filter(Risk2 == first_group, !is_signal, !is.na(expr_mean)) %>%
          dplyr::select(Pos, expr_mean) %>%
          dplyr::distinct()
        
        expr_list <- setNames(expr_by_pos$expr_mean, as.character(expr_by_pos$Pos))
        min_expr <- min(expr_by_pos$expr_mean, na.rm = TRUE)
        max_expr <- max(expr_by_pos$expr_mean, na.rm = TRUE)
        
        session$sendCustomMessage(
          type = "send_to_molstar",
          message = list(
            type = "color_by_expression",
            target = "ige",  # Target IgE viewer only
            data = as.list(expr_list),
            min = min_expr,
            max = max_expr,
            colorScale = "green"  # GREEN for IgE
          )
        )
        message("[COLOR_MODE] ✓ IgE expression mode sent (green scale)")
      } else if (input$protein_color_mode == "polarity") {
        session$sendCustomMessage(
          type = "send_to_molstar",
          message = list(type = "color_by_polarity")
        )
      } else {
        # Biomarkers mode
        bm_ige <- expression_data_ige()$biomarkers_tbl
        if (nrow(bm_ige) > 0) {
          Structure_info <- protein_info_data()$Structure_info
          biomarker_nums <- bm_ige$Number
          biomarker_resi_ngl <- sort(unique(Structure_info$Pos[Structure_info$Number %in% biomarker_nums]))
          
          session$sendCustomMessage(
            type = "send_to_molstar",
            message = list(
              type = "highlight_biomarkers",
              residues = as.list(biomarker_resi_ngl)
            )
          )
        }
      }
    }
    
    # Process IgG4 color mode
    if (!is.null(expression_data_igg4()) && !is.null(AA_data_igg4())) {
      message("[COLOR_MODE] Processing IgG4...")
      
      if (input$protein_color_mode == "expression") {
        AA_summary_igg4 <- AA_data_igg4()$AA_expression_summary
        first_group <- unique(AA_summary_igg4$Risk2)[1]
        
        expr_by_pos <- AA_summary_igg4 %>%
          dplyr::filter(Risk2 == first_group, !is_signal, !is.na(expr_mean)) %>%
          dplyr::select(Pos, expr_mean) %>%
          dplyr::distinct()
        
        expr_list <- setNames(expr_by_pos$expr_mean, as.character(expr_by_pos$Pos))
        min_expr <- min(expr_by_pos$expr_mean, na.rm = TRUE)
        max_expr <- max(expr_by_pos$expr_mean, na.rm = TRUE)
        
        session$sendCustomMessage(
          type = "send_to_molstar",
          message = list(
            type = "color_by_expression",
            target = "igg4",  # Target IgG4 viewer only
            data = as.list(expr_list),
            min = min_expr,
            max = max_expr,
            colorScale = "red"  # RED for IgG4
          )
        )
        message("[COLOR_MODE] ✓ IgG4 expression mode sent (red scale)")
      } else if (input$protein_color_mode == "polarity") {
        session$sendCustomMessage(
          type = "send_to_molstar",
          message = list(type = "color_by_polarity")
        )
      } else {
        # Biomarkers mode
        bm_igg4 <- expression_data_igg4()$biomarkers_tbl
        if (nrow(bm_igg4) > 0) {
          Structure_info <- protein_info_data()$Structure_info
          biomarker_nums <- bm_igg4$Number
          biomarker_resi_ngl <- sort(unique(Structure_info$Pos[Structure_info$Number %in% biomarker_nums]))
          
          session$sendCustomMessage(
            type = "send_to_molstar",
            message = list(
              type = "highlight_biomarkers",
              residues = as.list(biomarker_resi_ngl)
            )
          )
        }
      }
    }
  })
  
  # Toggle de superficie
  observeEvent(input$protein_show_surface, {
    message("\n[SURFACE_TOGGLE] Observer triggered: ", input$protein_show_surface)
    message("[SURFACE_TOGGLE] Sending message to NGL viewer...")
    
    session$sendCustomMessage(
      type = "send_to_molstar",
      message = list(
        type = "toggle_surface",
        show = input$protein_show_surface
      )
    )
    
    message("[SURFACE_TOGGLE] ✓ Message sent")
  })
}
