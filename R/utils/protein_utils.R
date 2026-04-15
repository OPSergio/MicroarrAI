# =============================================================================
# Utilidades para procesamiento de información de proteínas
# =============================================================================

#' Obtener información de aminoácidos y modificaciones desde UniProt
#' 
#' @param uniprot_id ID de UniProt de la proteína
#' @return tibble con información de aminoácidos, posiciones, modificaciones y péptido señal
#' @export
uniprot_AA_Pos_mod <- function(uniprot_id) {
  url <- paste0("https://rest.uniprot.org/uniprotkb/", uniprot_id, ".txt")
  txt <- readLines(url, warn = FALSE)
  
  ft <- txt[grepl("^FT", txt)]
  signal_line <- ft[grepl("^FT\\s+SIGNAL", ft)]
  
  # Obtener longitud del péptido señal
  if (length(signal_line) > 0) {
    signal_pos <- as.integer(unlist(regmatches(signal_line, gregexpr("[0-9]+", signal_line))))
    signal_len <- signal_pos[2]
  } else {
    signal_len <- 0
  }
  
  # Obtener modificaciones post-traduccionales
  mod_idx <- grep("^FT\\s+MOD_RES", ft)
  
  mods_df <- if (length(mod_idx) > 0) {
    do.call(rbind, lapply(mod_idx, function(i) {
      pos <- as.integer(regmatches(ft[i], regexpr("[0-9]+", ft[i])))
      note <- sub(".*note=\"([^\"]+)\".*", "\\1", ft[i + 1])
      data.frame(pos_uniprot = pos, modification = note, stringsAsFactors = FALSE)
    }))
  } else NULL
  
  # Usar secuencia COMPLETA (con péptido señal) para alineación con AlphaFold
  seq_lines <- txt[grepl("^[[:space:]]+[A-Z]", txt)]
  seq_complete <- gsub("[[:space:]]|[0-9]", "", paste(seq_lines, collapse = ""))
  aa_vec <- strsplit(seq_complete, "")[[1]]
  
  # Crear resultado con TODAS las posiciones (incluyendo péptido señal)
  result <- tibble::tibble(
    AA = aa_vec, 
    Pos = seq_along(aa_vec),
    is_signal = Pos <= signal_len
  )
  
  if (!is.null(mods_df)) {
    result <- result %>% 
      dplyr::left_join(mods_df, by = c("Pos" = "pos_uniprot")) %>% 
      dplyr::rename(mod = modification)
  } else {
    result$mod <- NA
  }
  
  # Logging
  message(sprintf("ℹ️  Secuencia procesada: Péptido señal (1-%d), Proteína madura (%d-%d), Total: %d AA", 
                  signal_len, signal_len + 1, nrow(result), nrow(result)))
  
  # Retornar con signal_length como atributo
  attr(result, "signal_length") <- signal_len
  result
}

#' Generar péptidos sintéticos desde secuencia FASTA
#' 
#' @param seq_complete Secuencia completa de aminoácidos
#' @param peptide_length Longitud de cada péptido (default: 20)
#' @param offset Offset entre péptidos consecutivos (default: 3)
#' @return tibble con péptidos numerados y sus posiciones
#' @export
generate_peptides_from_fasta <- function(seq_complete, peptide_length = 20, offset = 3) {
  seq_vec <- strsplit(seq_complete, "")[[1]]
  L <- length(seq_vec)
  starts <- seq(1, L, by = offset)
  
  dplyr::bind_rows(lapply(seq_along(starts), function(i) {
    start <- starts[i]
    end <- min(start + peptide_length - 1, L)
    tibble::tibble(
      Number = i,
      AA_Pep = seq_vec[start:end],
      Pos = start:end
    )
  }))
}

#' Procesar información completa de proteína desde UniProt
#' 
#' @param uniprot_id ID de UniProt
#' @param peptide_length Longitud de péptidos a generar
#' @param offset Offset entre péptidos
#' @return Lista con uniprot_info, Structure_info y signal_length
#' @export
get_protein_info <- function(uniprot_id, peptide_length = 20, offset = 3) {
  # Obtener información de UniProt
  uniprot_info <- uniprot_AA_Pos_mod(uniprot_id)
  signal_length <- attr(uniprot_info, "signal_length")
  
  # Generar péptidos solo desde la proteína MADURA (sin péptido señal)
  # Pero mantener las posiciones absolutas para que coincidan con AlphaFold
  seq_mature <- paste(uniprot_info$AA[(signal_length + 1):nrow(uniprot_info)], collapse = "")
  
  Protein_info <- generate_peptides_from_fasta(
    seq_complete = seq_mature,
    peptide_length = peptide_length,
    offset = offset
  )
  
  # Ajustar las posiciones para que sean absolutas (sumando signal_length)
  Protein_info <- Protein_info %>%
    dplyr::mutate(Pos = Pos + signal_length)
  
  # Unir con uniprot_info para obtener AA, mod, is_signal
  Structure_info <- Protein_info %>%
    dplyr::inner_join(uniprot_info, by = "Pos") %>%
    dplyr::select(Number, Pos, AA_Pep = AA, mod, is_signal)
  
  list(
    uniprot_info = uniprot_info,
    signal_length = signal_length,
    Structure_info = Structure_info
  )
}

#' Contar péptidos totales en dataset
#' 
#' @param peptide_data DataFrame con datos de péptidos
#' @param regex Regex para identificar proteína (ej: "ovom", "ovoalb", "a_s2_cas")
#' @return Lista con count total y columnas
#' @export
count_peptides <- function(peptide_data, regex) {
  if (is.null(peptide_data) || nrow(peptide_data) == 0) {
    return(list(total = 0, cols = character(0)))
  }
  
  # Obtener SOLO columnas numéricas (péptidos) - excluir id, variables clínicas, etc.
  numeric_cols <- names(peptide_data)[sapply(peptide_data, is.numeric)]
  
  # Buscar TODAS las columnas numéricas que contengan el regex (case-insensitive)
  # Esto coincide con tu script: select(id, contains(Regex()))
  matching_cols <- grep(regex, numeric_cols, value = TRUE, ignore.case = TRUE)
  
  message("\n========== [COUNT_PEPTIDES] Debug ==========")
  message("[COUNT_PEPTIDES] Total columns in data: ", ncol(peptide_data))
  message("[COUNT_PEPTIDES] Numeric columns: ", length(numeric_cols))
  message("[COUNT_PEPTIDES] Regex pattern: '", regex, "'")
  message("[COUNT_PEPTIDES] Matching peptides: ", length(matching_cols))
  if (length(matching_cols) > 0) {
    message("[COUNT_PEPTIDES] First 5 matches: ", paste(head(matching_cols, 5), collapse = ", "))
    message("[COUNT_PEPTIDES] Last 5 matches: ", paste(tail(matching_cols, 5), collapse = ", "))
  } else {
    message("[COUNT_PEPTIDES] WARNING: No matches found!")
    message("[COUNT_PEPTIDES] Sample of numeric columns: ", paste(head(numeric_cols, 10), collapse = ", "))
  }
  message("========== [COUNT_PEPTIDES] Complete ==========")
  
  list(
    total = length(matching_cols),
    cols = matching_cols
  )
}
