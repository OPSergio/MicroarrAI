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
  
  # Disulfide bonds (FT DISULFID  66..160)
  ss_lines <- ft[grepl("^FT\\s+DISULFID", ft)]
  disulfides <- Filter(Negate(is.null), lapply(ss_lines, function(l) {
    nums <- as.integer(unlist(regmatches(l, gregexpr("[0-9]+", l))))
    if (length(nums) >= 2) c(nums[1], nums[2]) else NULL
  }))

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
  
  # Retornar con signal_length y disulfuros como atributos
  attr(result, "signal_length") <- signal_len
  attr(result, "disulfides") <- disulfides
  result
}

#' Generar péptidos sintéticos desde secuencia FASTA
#' 
#' @param seq_complete Secuencia completa de aminoácidos
#' @param peptide_length Longitud de cada péptido (default: 20)
#' @param offset Offset entre péptidos consecutivos (default: 3)
#' @return tibble con péptidos numerados y sus posiciones
#' @export
generate_peptides_from_fasta <- function(seq_complete, peptide_length = 20, offset = 3,
                                         closing = c("truncate", "flush", "none")) {
  closing <- match.arg(closing)
  seq_vec <- strsplit(seq_complete, "")[[1]]
  L <- length(seq_vec)

  # Regular walk at `offset`, never emitting a peptide shorter than
  # peptide_length. How the C-terminus is closed is a property of the array
  # design, so it is declared rather than assumed:
  #   truncate - one extra peptide one step further, shorter than the rest
  #   flush    - one extra peptide starting at L - peptide_length + 1
  #   none     - stop at the last full-length peptide
  # All three give the same peptide COUNT; they differ by 1-2 residues in
  # where the last peptide starts.
  last_start <- max(L - peptide_length + 1, 1)
  starts <- seq(1, last_start, by = offset)

  if (tail(starts, 1) + peptide_length - 1 < L) {
    starts <- switch(closing,
      truncate = c(starts, tail(starts, 1) + offset),
      flush    = c(starts, last_start),
      none     = starts
    )
  }
  
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
    Structure_info = Structure_info,
    disulfides = attr(uniprot_info, "disulfides")
  )
}

#' Isotype prefixes present in a set of feature columns
#'
#' Reads the analyte prefix off positional peptide columns
#' ("IgE_p15_ovoalb_1" -> "IgE"). Nothing is hardcoded, so IgG-only or IgG+IgM
#' datasets are handled the same way as IgE+IgG4.
#'
#' @param cols Character vector. Column names of the peptide matrix
#' @return Character vector of isotypes, sorted; empty if none found
#' @export
discover_isotypes <- function(cols) {
  positional <- cols[grepl("_p[ _.-]?\\d+_", cols)]
  found <- unique(stringr::str_match(positional, "^([A-Za-z][A-Za-z0-9]*)_")[, 2])
  sort(found[!is.na(found)])
}


#' Comparable form of a protein name
#'
#' The annotation file says "a-s1-cas" while the matrix says "a.s1.cas",
#' because make.names() rewrites the separators when the matrix is built.
#' Dropping case and separators from both sides makes them comparable without
#' treating the name as a regex, where a "." would silently match anything.
#'
#' @param x Character vector
#' @return Character vector, lowercase and alphanumeric only
#' @export
comparable_name <- function(x) tolower(gsub("[^A-Za-z0-9]+", "", x))


#' Contar péptidos totales en dataset
#'
#' @param peptide_data DataFrame con datos de péptidos
#' @param protein Nombre de la proteína tal y como la declara la anotación
#'   ("b-lac", "ovoalb")
#' @return Lista con count total y columnas
#' @export
count_peptides <- function(peptide_data, protein) {
  if (is.null(peptide_data) || nrow(peptide_data) == 0) {
    return(list(total = 0, cols = character(0)))
  }

  numeric_cols <- names(peptide_data)[sapply(peptide_data, is.numeric)]
  matching_cols <- numeric_cols[
    grepl(comparable_name(protein), comparable_name(numeric_cols), fixed = TRUE)]

  message("[COUNT_PEPTIDES] '", protein, "': ", length(matching_cols), " of ",
          length(numeric_cols), " numeric columns")
  if (length(matching_cols) == 0) {
    message("[COUNT_PEPTIDES] no match. Columns look like: ",
            paste(head(numeric_cols, 5), collapse = ", "))
  }

  list(
    total = length(matching_cols),
    cols = matching_cols
  )
}

# =============================================================================
# Peptide annotation file
# =============================================================================
# The array design is declared, not guessed: one row per spotted peptide with
# its protein, its UniProt accession and the positions it covers. This replaces
# regenerating peptides with an assumed length/offset, which only ever matched
# arrays that happened to be tiled 20/3.
# =============================================================================

# Accepted header spellings, mapped to the names used downstream.
ANNOTATION_COLUMNS <- c(
  proteina = "protein", protein = "protein", protein_id = "protein",
  accesion = "accession", accession = "accession",
  uniprot = "accession", uniprot_id = "accession",
  numero = "number", number = "number", peptide_number = "number",
  inicio = "start", start = "start", pos = "start", position = "start",
  fin = "end", end = "end",
  peptido = "sequence", peptide = "sequence", secuencia = "sequence",
  sequence = "sequence"
)

#' Read a peptide annotation file
#'
#' @param path Path to a .csv/.tsv/.txt/.xlsx file
#' @return Tibble with protein, accession, number, start, end and sequence
#' @export
read_peptide_annotation <- function(path) {
  ext <- tolower(tools::file_ext(path))

  raw <- if (ext %in% c("xlsx", "xls")) {
    readxl::read_excel(path)
  } else {
    readr::read_delim(path, show_col_types = FALSE, progress = FALSE)
  }

  names(raw) <- tolower(trimws(names(raw)))
  known <- names(raw) %in% names(ANNOTATION_COLUMNS)
  annotation <- raw[, known, drop = FALSE]
  names(annotation) <- ANNOTATION_COLUMNS[names(annotation)]

  missing <- setdiff(c("protein", "accession", "number", "start"), names(annotation))
  if (length(missing) > 0) {
    stop("Annotation file is missing: ", paste(missing, collapse = ", "),
         ". Found: ", paste(names(raw), collapse = ", "))
  }

  annotation <- annotation %>%
    dplyr::mutate(
      protein   = trimws(as.character(protein)),
      accession = trimws(as.character(accession)),
      number    = as.integer(number),
      start     = as.integer(start)
    )

  # `end` is redundant when the sequence is there, so either one is enough.
  if (!"end" %in% names(annotation)) {
    if (!"sequence" %in% names(annotation)) {
      stop("Annotation file needs either an 'end' column or a peptide sequence.")
    }
    annotation$end <- annotation$start + nchar(annotation$sequence) - 1L
  }
  annotation$end <- as.integer(annotation$end)

  bad <- with(annotation, is.na(number) | is.na(start) | is.na(end) | end < start)
  if (any(bad)) {
    stop(sum(bad), " annotation rows have unusable positions (row ",
         paste(utils::head(which(bad), 5), collapse = ", "), ").")
  }

  dplyr::arrange(annotation, protein, number)
}


#' Protein information built from the annotation file
#'
#' Same shape as get_protein_info(), but the peptide positions are read rather
#' than regenerated. The sequence and its modifications still come from UniProt.
#'
#' @param annotation Tibble from read_peptide_annotation()
#' @param protein Protein to load, as named in the annotation
#' @return List with uniprot_info, signal_length, Structure_info and disulfides
#' @export
protein_info_from_annotation <- function(annotation, protein) {
  rows <- dplyr::filter(annotation, protein == !!protein)
  if (nrow(rows) == 0) stop("No peptides annotated for '", protein, "'.")

  accession <- unique(rows$accession)
  if (length(accession) != 1) {
    stop("'", protein, "' maps to several accessions: ",
         paste(accession, collapse = ", "))
  }

  uniprot_info <- uniprot_AA_Pos_mod(accession)
  signal_length <- attr(uniprot_info, "signal_length")
  sequence <- paste(uniprot_info$AA, collapse = "")

  # Files number positions either from the mature protein or from the start of
  # the UniProt entry. With the peptide sequence at hand we can check which one
  # lands on the right residues instead of assuming.
  agreement <- function(shift) {
    if (!"sequence" %in% names(rows)) return(NA_real_)
    mean(substring(sequence, rows$start + shift, rows$end + shift) == rows$sequence)
  }
  shift <- if (isTRUE(agreement(signal_length) > agreement(0))) signal_length else 0L
  matched <- agreement(shift)

  Structure_info <- rows %>%
    dplyr::mutate(Pos = Map(seq, start + shift, end + shift)) %>%
    dplyr::select(Number = number, Pos) %>%
    tidyr::unnest(Pos) %>%
    dplyr::inner_join(uniprot_info, by = "Pos") %>%
    dplyr::select(Number, Pos, AA_Pep = AA, mod, is_signal)

  outside <- sum(rows$end + shift > nrow(uniprot_info))
  if (outside > 0) {
    warning(outside, " peptides of '", protein, "' fall past the end of ",
            accession, " (", nrow(uniprot_info), " aa) and were trimmed.")
  }
  if (!is.na(matched) && matched < 0.9) {
    warning(sprintf("Only %.0f%% of '%s' peptides match %s at the annotated positions.",
                    100 * matched, protein, accession))
  }

  message(sprintf("[ANNOTATION] %s (%s): %d peptides, %d-%d aa, shift %d, %s",
                  protein, accession, dplyr::n_distinct(Structure_info$Number),
                  min(Structure_info$Pos), max(Structure_info$Pos), shift,
                  if (is.na(matched)) "no sequence to verify"
                  else sprintf("%.0f%% verified against the sequence", 100 * matched)))

  list(
    uniprot_info  = uniprot_info,
    signal_length = signal_length,
    Structure_info = Structure_info,
    disulfides    = attr(uniprot_info, "disulfides")
  )
}
