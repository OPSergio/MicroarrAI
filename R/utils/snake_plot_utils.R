# =============================================================================
# Utilidades para visualización de snake plots
# =============================================================================

#' Generar coordenadas para snake plot
#' 
#' Esta función es la misma que existe en ./Def/Function2.R
#' 
#' @param n Número de posiciones
#' @param altura Altura de las ondulaciones
#' @param anchura Anchura de las ondulaciones
#' @param pte Pendiente de las diagonales
#' @return data.frame con coordenadas x, y
#' @export
posiciones <- function(n, altura, anchura, pte) {
  x <- 0
  y <- 0
  res <- data.frame()
  estado <- "SN"
  
  for (i in seq_len(n)) {
    if (estado == "SN") {
      y <- y + 1
      res <- dplyr::bind_rows(res, data.frame(x, y))
      if (y == altura) estado <- "SA"
      next
    }
    if (estado == "SA") {
      x <- x + .5
      y <- y + .5
      res <- dplyr::bind_rows(res, data.frame(x, y))
      if (y == altura + pte) estado <- "DA"
      next
    }
    if (estado == "DA") {
      x <- x + .5
      y <- y - .5
      res <- dplyr::bind_rows(res, data.frame(x, y))
      if (y == altura) estado <- "DN"
      next
    }
    if (estado == "DN") {
      y <- y - 1
      res <- dplyr::bind_rows(res, data.frame(x, y))
      if (y == 0) estado <- "DB"
      next
    }
    if (estado == "DB") {
      x <- x + .5
      y <- y - .5
      res <- dplyr::bind_rows(res, data.frame(x, y))
      if (y == -pte) estado <- "SB"
      next
    }
    if (estado == "SB") {
      x <- x + .5
      y <- y + .5
      res <- dplyr::bind_rows(res, data.frame(x, y))
      if (y == 0) estado <- "SN"
      next
    }
  }
  
  res
}

#' Preparar datos para snake plot con expresión y biomarcadores
#' 
#' @param Structure_info Información de estructura de proteína
#' @param peptide_means Medias de expresión por péptido
#' @param signal_length Longitud del péptido señal
#' @param uniprot_info Información completa de UniProt
#' @param altura Altura para coordenadas (default: 17)
#' @param anchura Anchura para coordenadas (default: 2)
#' @param pte Pendiente para coordenadas (default: 1)
#' @return Lista con Protein_plot, PTM_plot, Biomarker_plot, Signal_plot
#' @export
prepare_snake_data <- function(Structure_info, peptide_means, signal_length, 
                                uniprot_info, altura = 17, anchura = 2, pte = 1) {
  
  message("\n[PREPARE_SNAKE] Starting...")
  message("[PREPARE_SNAKE] Structure_info rows: ", nrow(Structure_info))
  message("[PREPARE_SNAKE] peptide_means rows: ", nrow(peptide_means))
  
  # Debug biomarkers in peptide_means
  biomarkers_in_means <- peptide_means %>%
    dplyr::filter(is_biomarker == TRUE)
  message("[PREPARE_SNAKE] Biomarkers in peptide_means: ", nrow(biomarkers_in_means))
  if (nrow(biomarkers_in_means) > 0) {
    message("[PREPARE_SNAKE] Biomarker peptide numbers: ", paste(unique(biomarkers_in_means$Number), collapse = ", "))
  }
  
  # Datos de expresión solo para la proteína madura
  AA_expression <- Structure_info %>%
    dplyr::left_join(peptide_means, by = "Number", relationship = "many-to-many")
  
  message("[PREPARE_SNAKE] After join: ", nrow(AA_expression), " rows")
  biomarkers_after_join <- AA_expression %>%
    dplyr::filter(is_biomarker == TRUE)
  message("[PREPARE_SNAKE] Biomarkers after join: ", nrow(biomarkers_after_join))
  
  AA_expression_summary <- AA_expression %>%
    dplyr::group_by(Pos, AA_Pep, mod, is_signal, Risk2) %>%
    dplyr::summarise(
      expr_mean = mean(expr_mean, na.rm = TRUE),
      is_biomarker = any(is_biomarker),
      biomarker_id = paste(unique(biomarker_id[is_biomarker]), collapse = "; "),
      .groups = "drop"
    ) %>%
    dplyr::arrange(Pos)
  
  biomarkers_in_summary <- AA_expression_summary %>%
    dplyr::filter(is_biomarker == TRUE)
  message("[PREPARE_SNAKE] Biomarkers in summary: ", nrow(biomarkers_in_summary))
  if (nrow(biomarkers_in_summary) > 0) {
    message("[PREPARE_SNAKE] Biomarker positions: ", paste(unique(biomarkers_in_summary$Pos), collapse = ", "))
  }
  
  # Añadir filas para el péptido señal (sin datos de expresión)
  if (signal_length > 0) {
    # Obtener los grupos reales de los datos (NO hardcodear H/L)
    actual_groups <- unique(peptide_means$Risk2)
    
    signal_peptide_rows <- uniprot_info %>%
      dplyr::filter(is_signal) %>%
      tidyr::crossing(Risk2 = actual_groups) %>%  # ← Usar grupos dinámicos
      dplyr::mutate(
        AA_Pep = AA,
        expr_mean = NA_real_,
        is_biomarker = FALSE,
        biomarker_id = NA_character_
      ) %>%
      dplyr::select(Pos, AA_Pep, mod, is_signal, Risk2, expr_mean, is_biomarker, biomarker_id)
    
    AA_expression_summary <- dplyr::bind_rows(
      signal_peptide_rows,
      AA_expression_summary
    ) %>%
      dplyr::arrange(Pos)
    
    message(sprintf("🔵 Añadidas %d posiciones de péptido señal (sin datos de expresión)", signal_length))
  }
  
  # Generar coordenadas
  coords <- AA_expression_summary %>%
    dplyr::distinct(Pos) %>%
    dplyr::arrange(Pos)
  
  coords <- dplyr::bind_cols(coords, posiciones(nrow(coords), altura, anchura, pte))
  
  # Preparar datos para plot
  Protein_plot <- AA_expression_summary %>%
    dplyr::left_join(coords, by = "Pos") %>%
    dplyr::mutate(
      tooltip = ifelse(
        is_biomarker,
        paste0(
          "<div style='line-height: 1.6;'>",
          "<strong>Position: ", Pos, "</strong>",
          "<span class='biomarker-badge'>BIOMARKER</span>",
          "<br>AA: ", AA_Pep,
          "<br>Mean expr: ", round(expr_mean, 2),
          ifelse(!is.na(mod), paste0("<br>PTM: ", mod), ""),
          "</div>"
        ),
        paste0(
          "Position: ", Pos,
          "\nAA: ", AA_Pep,
          ifelse(is_signal, "\n🔵 Signal peptide (no data)", ""),
          ifelse(!is_signal & !is.na(expr_mean), paste0("\nMean expr: ", round(expr_mean, 2)), ""),
          ifelse(is.na(mod), "", paste0("\nPTM: ", mod))
        )
      ),
      data_id = as.character(Pos),
      point_shape = ifelse(is_signal, 22, 21)  # 22 = square, 21 = circle
    )
  
  PTM_plot <- Protein_plot %>%
    dplyr::filter(!is.na(mod)) %>%
    dplyr::mutate(x_ptm = x + 1.2, y_ptm = y)
  
  Biomarker_plot <- Protein_plot %>%
    dplyr::filter(is_biomarker == TRUE)
  
  Signal_plot <- Protein_plot %>%
    dplyr::filter(is_signal == TRUE)
  
  Protein_plot <- Protein_plot %>%
    dplyr::filter(!is.na(Risk2))
  
  list(
    AA_expression_summary = AA_expression_summary,
    Protein_plot = Protein_plot,
    PTM_plot = PTM_plot,
    Biomarker_plot = Biomarker_plot,
    Signal_plot = Signal_plot
  )
}

#' Crear gráfico snake interactivo con ggiraph
#' 
#' @param Protein_plot Datos principales de proteína
#' @param PTM_plot Datos de modificaciones post-traduccionales
#' @param Biomarker_plot Datos de biomarcadores
#' @param Signal_plot Datos de péptido señal
#' @param color_palette "green" para IgE, "red" para IgG4
#' @param facet_type "horizontal" para grupos lado a lado, "vertical" para apilados
#' @param aspect_ratio Relación altura/anchura del plot
#' @return Objeto ggplot
#' @export
create_snake_plot <- function(Protein_plot, PTM_plot, Biomarker_plot, Signal_plot, 
                              color_palette = "green", facet_type = "horizontal", aspect_ratio = 0.75) {
  ggplot2::ggplot(Protein_plot, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_path(linewidth = 1.2, color = "grey40") +
    # Signal peptide with blue squares
    ggiraph::geom_point_interactive(
      data = Signal_plot,
      ggplot2::aes(tooltip = tooltip, data_id = data_id),
      shape = 22, size = 10, fill = "#7d898d", color = "#8990a5", 
      stroke = 2, alpha = 0.6
    ) +
    # Shading for biomarkers
    ggiraph::geom_point_interactive(
      data = Biomarker_plot,
      ggplot2::aes(tooltip = tooltip, data_id = data_id),
      shape = 21, size = 10, fill = "#ff6b35", color = "#ff6b35", 
      stroke = 2, alpha = 0.3
    ) +
    # Normal points
    ggiraph::geom_point_interactive(
      ggplot2::aes(fill = expr_mean, tooltip = tooltip, data_id = data_id, shape = point_shape),
      size = 8, color = "black", stroke = 0.4
    ) +
    ggplot2::scale_shape_identity() +
    ggiraph::geom_text_interactive(
      ggplot2::aes(label = AA_Pep, tooltip = tooltip, data_id = data_id),
      size = 3.2, color = "black", fontface = "bold", vjust = 0.5, hjust = 0.5
    ) +
    ggiraph::geom_segment_interactive(
      data = PTM_plot,
      ggplot2::aes(x = x, y = y, xend = x_ptm, yend = y_ptm, tooltip = tooltip, data_id = data_id),
      linewidth = 0.8, color = "black"
    ) +
    ggiraph::geom_point_interactive(
      data = PTM_plot,
      ggplot2::aes(x = x_ptm, y = y_ptm, tooltip = tooltip, data_id = data_id),
      shape = 21, size = 4, fill = "white", color = "black", stroke = 1.2
    ) +
    ggplot2::scale_fill_gradient2(
      low = ifelse(color_palette == "green", "white", "white"),
      mid = "white",
      high = ifelse(color_palette == "green", "#00a86b", "#d62828"),
      midpoint = 0, na.value = "grey85",
      name = "Mean\nrecognition"
    ) +
    ggplot2::coord_equal() +
    # Dynamic facet based on user selection
    {if (facet_type == "vertical") ggplot2::facet_grid(Risk2 ~ .) else ggplot2::facet_grid(~ Risk2)} +
    ggplot2::theme_void() +
    ggplot2::theme(
      legend.position = "right",
      strip.background = ggplot2::element_rect(fill = "#f0f0f0", color = "#cccccc", size = 0.5),
      strip.text = ggplot2::element_text(size = 11, face = "bold", color = "#191c32"),
      panel.spacing = ggplot2::unit(1.5, "lines"),
      aspect.ratio = aspect_ratio
    )
}
