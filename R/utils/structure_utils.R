# =============================================================================
# Structure lookup: AlphaFold model or experimental PDB
# =============================================================================
# AlphaFold no longer serves every entry under AF-{acc}-F1-model_v*.pdb, so the
# URL has to be resolved through its API. When the model is unreliable (low
# pLDDT or partial coverage) we fall back to the best experimental structure
# mapped to the same accession, and only then give up and stay in 2D.
# =============================================================================

#' Query the AlphaFold model for an accession
#'
#' @param accession Character. UniProt accession
#' @return List with url, plddt, unreliable_fraction, coverage_range; NULL if absent
alphafold_entry <- function(accession) {
  url <- paste0("https://alphafold.ebi.ac.uk/api/prediction/", accession)
  entry <- tryCatch(jsonlite::fromJSON(url), error = function(e) NULL)

  if (length(entry) == 0) return(NULL)

  list(
    url        = entry$pdbUrl[1],
    plddt      = entry$globalMetricValue[1],
    unreliable = entry$fractionPlddtVeryLow[1] + entry$fractionPlddtLow[1],
    from       = entry$uniprotStart[1],
    to         = entry$uniprotEnd[1]
  )
}

#' Best experimental structure mapped to an accession
#'
#' @param accession Character. UniProt accession
#' @return List with pdb_id, chain, chains, method, resolution, coverage, offset; NULL if none
pdbe_entry <- function(accession) {
  url <- paste0("https://www.ebi.ac.uk/pdbe/api/mappings/best_structures/", accession)
  entry <- tryCatch(jsonlite::fromJSON(url), error = function(e) NULL)

  if (length(entry) == 0) return(NULL)

  candidates <- entry[[1]]
  best <- candidates[which.max(candidates$coverage), ]

  list(
    pdb_id     = best$pdb_id,
    chain      = best$chain_id,
    chains     = sum(candidates$pdb_id == best$pdb_id),
    method     = best$experimental_method,
    resolution = best$resolution,
    coverage   = best$coverage,
    offset     = best$start - best$unp_start,
    total      = nrow(candidates)
  )
}

#' Pick the structure to display for a protein
#'
#' @param accession Character. UniProt accession
#' @param length_aa Integer. Full sequence length, used to judge model coverage
#' @param min_coverage Numeric. Minimum fraction of sequence covered (default 0.90)
#' @param max_unreliable Numeric. Maximum fraction of residues below pLDDT 70 (default 0.30)
#' @return List with `source` ("alphafold", "pdb" or "none"), the payload the
#'   viewer needs, and a human-readable `reason` when AlphaFold was rejected
resolve_structure <- function(accession, length_aa,
                              min_coverage = 0.90, max_unreliable = 0.30) {

  empty <- list(source = "none", url = NULL, pdb_id = NULL, chain = "A",
                reason = NULL, detail = NULL)

  if (is.null(accession) || !nzchar(accession)) return(empty)

  model <- alphafold_entry(accession)

  if (!is.null(model)) {
    coverage <- (model$to - model$from + 1) / length_aa

    if (coverage >= min_coverage && model$unreliable <= max_unreliable) {
      return(list(
        source = "alphafold", url = model$url, pdb_id = NULL, chain = "A",
        reason = NULL,
        detail = sprintf("AlphaFold · pLDDT %.0f · covers %.0f%%",
                         model$plddt, 100 * coverage)
      ))
    }

    empty$reason <- if (coverage < min_coverage) {
      sprintf("the AlphaFold model covers only %.0f%% of the sequence", 100 * coverage)
    } else {
      sprintf("%.0f%% of residues fall below pLDDT 70 in AlphaFold", 100 * model$unreliable)
    }
  } else {
    empty$reason <- "AlphaFold publishes no model for this protein"
  }

  experimental <- pdbe_entry(accession)

  if (!is.null(experimental) && experimental$coverage >= 0.50) {
    return(list(
      source = "pdb", url = NULL, pdb_id = experimental$pdb_id,
      chain = experimental$chain, reason = empty$reason,
      detail = sprintf("%s · %s%s · covers %.0f%% · %d chain(s) · %d structures available",
                       toupper(experimental$pdb_id), experimental$method,
                       if (is.na(experimental$resolution)) "" else sprintf(" %.2f A", experimental$resolution),
                       100 * experimental$coverage, experimental$chains, experimental$total)
    ))
  }

  empty$detail <- "No experimental structure covers enough of the sequence either."
  empty
}
