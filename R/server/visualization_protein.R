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
  
  # ============================================================================
  # Anotación de péptidos: el array se declara en un fichero, no se adivina
  # ============================================================================

  annotation <- reactive({
    req(input$protein_annotation)

    tryCatch(read_peptide_annotation(input$protein_annotation$datapath),
             error = function(e) {
               showNotification(paste("❌ Annotation file:", e$message),
                                type = "error", duration = 10)
               NULL
             })
  })

  output$protein_selector <- renderUI({
    ann <- annotation()
    if (is.null(ann)) return(NULL)

    selectInput("protein_name", HTML("<strong>Protein:</strong>"),
                choices = sort(unique(ann$protein)))
  })

  # Everything downstream keys off these two: the tag that names the protein in
  # the peptide columns, and the accession that fetches sequence and structure.
  protein_tag <- reactive({
    req(input$protein_name)
    input$protein_name
  })

  protein_accession <- reactive({
    ann <- annotation()
    req(ann, input$protein_name)
    unique(ann$accession[ann$protein == input$protein_name])[1]
  })

  # Trigger para cargar proteína
  protein_trigger <- reactiveVal(0)

  observeEvent(input$protein_load, {
    req(annotation(), input$protein_name)

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
    
    counts <- count_peptides(peptide_data(), protein_tag())
    if (counts$total == 0) {
      showNotification(
        paste("⚠️ No peptide columns named after", protein_tag()),
        type = "warning",
        duration = 5
      )
      return()
    }

    showNotification(
      paste("🔍 Loading protein", protein_tag(), "..."),
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
    req(annotation(), input$protein_name)

    isolate({
      message("[PROTEIN_INFO] Building ", input$protein_name, " from the annotation file")

      tryCatch({
        protein_info <- protein_info_from_annotation(annotation(), input$protein_name)

        showNotification(
          paste("✅ Proteína cargada:", nrow(protein_info$uniprot_info), "AA,",
                dplyr::n_distinct(protein_info$Structure_info$Number), "péptidos"),
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
    req(protein_tag())

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
    
    counts <- count_peptides(peptide_data(), protein_tag())
    annotated <- sum(annotation()$protein == protein_tag())

    # Columns cover every isotype, so the honest denominator is annotated
    # peptides x isotypes present.
    isotypes <- max(1, length(discover_isotypes(names(peptide_data()))))

    tags$div(
      style = "background: #e3f2fd; padding: 15px; border-radius: 5px; border-left: 4px solid #2196F3;",
      tags$strong(style = "color: #1976D2; font-size: 15px;", "Peptides matched:"),
      tags$span(style = "margin-left: 10px; font-size: 18px; font-weight: bold; color: #0D47A1;",
                counts$total),
      tags$div(style = "font-size: 12px; color: #1976D2; margin-top: 4px;",
               sprintf("%d annotated x %d isotype(s)", annotated, isotypes))
    )
  })
  
  # ============================================================================
  # REACTIVOS: Procesar datos de expresión
  # ============================================================================
  
  # MANTENER expression_data() para compatibilidad (procesa TODO - IgE + IgG4)
  expression_data <- reactive({
    req(protein_info_data(), protein_tag())

    protein <- protein_tag()

    # Si no hay datos externos, retornar NULL
    if (is.null(peptide_data) || is.null(clinical_data)) {
      return(NULL)
    }
    
    peptides <- peptide_data()
    clinics <- clinical_data()
    target <- target_var()
    
    # Contar péptidos
    counts <- count_peptides(peptides, protein)
    
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
            message("[BIOMARKER_MATCH] Protein filter: ", protein)

            filtered_result <- result %>%
              dplyr::filter(grepl(comparable_name(protein), comparable_name(protein_id), fixed = TRUE))
            
            message("[BIOMARKER_MATCH] After protein filter: ", nrow(filtered_result), " biomarkers matched")
            
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
              message("[BIOMARKER_MATCH] ⚠️ WARNING: No biomarkers matched the protein!")
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
  # REACTIVOS: un analito cualquiera, descubierto del dato
  # ============================================================================

  # Isotype prefixes present in the peptide columns. Nothing is hardcoded: a
  # dataset with IgG only, or IgG + IgM, works the same as IgE + IgG4.
  protein_isotypes <- reactive({
    req(peptide_data())
    found <- discover_isotypes(names(peptide_data()))
    if (length(found) == 0) "Signal" else found
  })

  expression_for_isotype <- function(iso) {
    req(protein_info_data(), protein_tag())
    if (is.null(peptide_data) || is.null(clinical_data)) return(NULL)

    protein <- protein_tag()
    peptides <- peptide_data()
    clinics <- clinical_data()
    target <- target_var()

    iso_cols <- names(peptides)[
      grepl(paste0("^", iso, "_"), names(peptides)) &
      grepl(comparable_name(protein), comparable_name(names(peptides)), fixed = TRUE)
    ]
    if (length(iso_cols) == 0) return(NULL)

    peptide_means <- peptides %>%
      dplyr::select(id, dplyr::all_of(iso_cols)) %>%
      dplyr::inner_join(clinics %>% dplyr::select(id, dplyr::all_of(target)), by = "id") %>%
      dplyr::group_by(!!rlang::sym(target)) %>%
      dplyr::summarise(dplyr::across(dplyr::all_of(iso_cols), ~mean(.x, na.rm = TRUE)),
                       .groups = "drop") %>%
      tidyr::pivot_longer(cols = -dplyr::all_of(target),
                          names_to = "peptide", values_to = "expr_mean") %>%
      dplyr::mutate(Number = as.integer(stringr::str_match(peptide, "_p[ _.-]?(\\d+)_")[, 2])) %>%
      dplyr::filter(!is.na(Number))

    if (nrow(peptide_means) == 0) return(NULL)

    colnames(peptide_means)[colnames(peptide_means) == target] <- "group"

    biomarkers_tbl <- if (!is.null(biomarkers) && !is.null(biomarkers())) {
      expression_data()$biomarkers_tbl %>% dplyr::filter(antibody_type == iso)
    } else {
      tibble::tibble(Number = integer(), antibody_type = character(),
                     is_biomarker = logical(), biomarker_id = character())
    }

    peptide_means <- peptide_means %>%
      dplyr::left_join(biomarkers_tbl, by = "Number") %>%
      dplyr::mutate(
        is_biomarker = !is.na(is_biomarker),
        biomarker_id = ifelse(is.na(biomarker_id), NA_character_, biomarker_id),
        antibody_type = iso
      )

    list(peptide_means = peptide_means, biomarkers_tbl = biomarkers_tbl)
  }

  aa_data_for_isotype <- function(iso) {
    info <- protein_info_data()
    expression <- expression_for_isotype(iso)
    if (is.null(expression)) return(NULL)

    prepare_snake_data(
      info$Structure_info, expression$peptide_means,
      info$signal_length, info$uniprot_info, 17, 2, 1
    )
  }

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
    req(protein_info_data())
    to_rows <- function(d, iso) {
      if (is.null(d)) return(NULL)
      s <- d$AA_expression_summary
      data.frame(
        pos = s$Pos, aa = s$AA_Pep, isotype = iso, group = s$group,
        expr = replace(s$expr_mean, is.nan(s$expr_mean), NA_real_),
        is_biomarker = na_false(s$is_biomarker), padj = NA_real_,
        is_signal = na_false(s$is_signal), mod = s$mod, peptide = NA_integer_,
        stringsAsFactors = FALSE
      )
    }
    rows <- lapply(protein_isotypes(), function(iso) to_rows(aa_data_for_isotype(iso), iso))
    rows <- Filter(Negate(is.null), rows)
    req(length(rows) > 0)
    do.call(rbind, rows)
  })

  # Which structure to draw, decided server-side once per protein
  protein_structure <- reactive({
    req(protein_accession(), protein_info_data())
    resolve_structure(protein_accession(), nrow(protein_info_data()$uniprot_info))
  })

  output$protein_structure_note <- renderUI({
    s <- protein_structure()
    if (s$source == "alphafold") return(NULL)

    tags$div(
      class = "pv-structure-note",
      tags$b(if (s$source == "pdb") "Experimental structure: " else "2D only: "),
      paste0(s$reason, ". "), s$detail
    )
  })

  output$protein_isotype_ui <- renderUI({
    isotypes <- protein_isotypes()
    radioButtons("protein_isotype", "Isotype", choices = isotypes,
                 selected = isotypes[1], inline = TRUE)
  })

  output$protein_color_mode_ui <- renderUI({
    isotypes <- protein_isotypes()
    modes <- c("Expression" = "expr", "Δ groups" = "dgroup")
    if (length(isotypes) >= 2) {
      modes[paste(isotypes[1], "−", isotypes[2])] <- "diso"
    }
    radioButtons("protein_color_mode", "Colour by", choices = modes, selected = "expr")
  })

  view <- function() list(
    isotype = isolate(input$protein_isotype) %||% protein_isotypes()[1],
    group   = isolate(input$protein_group) %||% protein_groups()[1],
    mode    = isolate(input$protein_color_mode) %||% "expr",
    fdr     = isolate(input$protein_fdr) %||% 0.05,
    surface = isTRUE(isolate(input$protein_show_surface)),
    biomarkers = isTRUE(isolate(input$protein_biomarkers) %||% TRUE)
  )

  send_all <- function() {
    info <- isolate(protein_info_data())
    structure <- isolate(protein_structure())
    session$sendCustomMessage("loadProtein", list(
      uniprot = isolate(protein_accession()),
      structureUrl = structure$url, pdb = structure$pdb_id, chain = structure$chain,
      signalLength = info$signal_length, disulfides = info$disulfides %||% list(),
      isotypes = as.list(protein_isotypes()), groups = as.list(protein_groups()),
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
    filename = function() paste0("biomarkers_", isolate(input$protein_isotype) %||% protein_isotypes()[1], ".fasta"),
    content = function(file) {
      df <- protein_dataset(); v <- view()
      bm <- df[df$isotype == v$isotype & df$group == v$group & df$is_biomarker & !df$is_signal, ]
      bm <- bm[order(bm$pos), ]
      if (nrow(bm) == 0) { writeLines("; no biomarkers selected", file); return() }
      brk <- c(0, cumsum(diff(bm$pos) != 1))               # contiguous stretches
      lines <- unlist(lapply(split(bm, brk), function(r) c(
        sprintf(">%s_%d-%d isotype=%s", isolate(protein_tag()), min(r$pos), max(r$pos), v$isotype),
        paste(r$aa, collapse = ""))))
      writeLines(lines, file)
    }
  )
}
