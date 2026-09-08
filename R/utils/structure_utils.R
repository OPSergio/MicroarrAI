# =============================================================================
# Structure lookup: AlphaFold model or experimental PDB
# =============================================================================
# AlphaFold no longer serves every entry under AF-{acc}-F1-model_v*.pdb, so the
# URL has to be resolved through its API. When the model is unreliable (low
# pLDDT or partial coverage) we fall back to the best experimental structure
# mapped to the same accession, and only then give up and stay in 2D.
# =============================================================================

# Results are memoised per session: resolve_structure() runs on every protein
# load, and re-querying EBI each time invites rate-limiting, which used to
# surface as "no structure for this protein".
.structure_cache <- new.env(parent = emptyenv())

#' Fetch JSON, telling "not there" apart from "could not ask"
#'
#' @param url Character. Endpoint to read.
#' @return List with `status` ("ok", "absent" or "error") and `data`.
#' @details A bare tryCatch(..., error = NULL) made a timeout, a DNS failure and
#'   an HTTP 429 look exactly like a protein with no published structure, so a
#'   transient network problem was reported to the user as a permanent absence.
fetch_json <- function(url, cache_key = url) {
  if (!is.null(.structure_cache[[cache_key]])) return(.structure_cache[[cache_key]])

  old <- options(timeout = 20); on.exit(options(old), add = TRUE)

  res <- tryCatch(
    list(status = "ok", data = jsonlite::fromJSON(url)),
    error = function(e) {
      msg <- conditionMessage(e)
      # EBI answers 404 when it simply has nothing for the accession
      if (grepl("404", msg, fixed = TRUE)) list(status = "absent", data = NULL)
      else list(status = "error", data = NULL, message = msg)
    }
  )

  # Never cache a failure: the next attempt should be free to succeed
  if (res$status != "error") assign(cache_key, res, envir = .structure_cache)
  res
}


#' Query the AlphaFold model for an accession
#'
#' @param accession Character. UniProt accession
#' @return List with url, plddt, unreliable_fraction, coverage_range; NULL if absent
alphafold_entry <- function(accession) {
  res <- fetch_json(paste0("https://alphafold.ebi.ac.uk/api/prediction/", accession),
                    cache_key = paste0("af:", accession))
  if (res$status == "error") return(list(unreachable = TRUE))

  entry <- res$data
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
  res <- fetch_json(paste0("https://www.ebi.ac.uk/pdbe/api/mappings/best_structures/", accession),
                    cache_key = paste0("pdbe:", accession))
  if (res$status == "error") return(list(unreachable = TRUE))

  entry <- res$data
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

#' Describe AlphaFold confidence without jargon
#'
#' @param plddt Numeric. Global pLDDT (0-100).
#' @param unreliable Numeric. Fraction of residues below pLDDT 70.
#' @return A short, plain-language sentence.
#' @details pLDDT is AlphaFold's own per-residue confidence. It says nothing
#'   about whether the model is the right protein, so it is reported here, never
#'   used to override the accession the user supplied.
confidence_note <- function(plddt, unreliable) {
  if (!is.finite(plddt)) return("confidence unknown")
  low <- if (is.finite(unreliable)) round(100 * unreliable) else NA

  band <- if (plddt >= 90) "very high confidence"
          else if (plddt >= 70) "confident"
          else if (plddt >= 50) "low confidence"
          else "very low confidence - the protein is probably disordered"

  if (is.na(low) || low < 10) band
  else sprintf("%s (%d%% of residues modelled with low confidence)", band, low)
}


#' Pick the structure to display for a protein
#'
#' @param accession Character. UniProt accession, as supplied by the user's
#'   annotation. This is authoritative: the structure shown is always the one
#'   for this accession.
#' @param length_aa Integer. Full sequence length, used to report model coverage.
#' @return List with `source` ("alphafold", "pdb" or "none"), the payload the
#'   viewer needs, a human-readable `detail`, and `alternative` describing an
#'   experimental structure the user can switch to when one exists.
#' @details The AlphaFold model is shown whenever one exists. Confidence and
#'   coverage are reported as information, never used to silently swap in a
#'   different structure: judging whether a low-confidence model is useful is
#'   the user's call, not this function's. The experimental structure is only
#'   selected automatically when AlphaFold publishes no model at all.
resolve_structure <- function(accession, length_aa) {

  empty <- list(source = "none", url = NULL, pdb_id = NULL, chain = "A",
                reason = NULL, detail = NULL, alternative = NULL)

  if (is.null(accession) || !nzchar(accession)) return(empty)

  model        <- alphafold_entry(accession)
  experimental <- pdbe_entry(accession)

  # A lookup that could not be performed is not the same as a protein without a
  # structure; say so instead of sending the user to 2D for a network blip.
  unreachable <- function(x) isTRUE(x$unreachable)
  if (unreachable(model) && unreachable(experimental)) {
    empty$reason <- "the structure lookup could not reach AlphaFold or the PDB"
    empty$detail <- "This is usually a network or rate-limit problem. Reload the protein to try again."
    return(empty)
  }
  if (unreachable(model)) model <- NULL
  if (unreachable(experimental)) experimental <- NULL

  alt <- if (!is.null(experimental)) {
    sprintf("%s (%s%s) also covers %.0f%% of this sequence",
            toupper(experimental$pdb_id), experimental$method,
            if (is.na(experimental$resolution)) "" else sprintf(" %.2f A", experimental$resolution),
            100 * experimental$coverage)
  } else NULL

  # An entry can exist without a usable model file; treat that as no model.
  if (!is.null(model) && (length(model$url) == 0 || !nzchar(model$url))) model <- NULL

  if (!is.null(model)) {
    coverage <- (model$to - model$from + 1) / length_aa
    return(list(
      source = "alphafold", url = model$url, pdb_id = NULL, chain = "A",
      reason = NULL,
      detail = sprintf("AlphaFold model for %s - covers %.0f%% of the sequence - %s",
                       accession, 100 * coverage,
                       confidence_note(model$plddt, model$unreliable)),
      alternative = alt
    ))
  }

  # Only now, with no model for this accession at all, fall back to experiment.
  if (!is.null(experimental)) {
    return(list(
      source = "pdb", url = NULL, pdb_id = experimental$pdb_id,
      chain = experimental$chain,
      reason = "AlphaFold publishes no model for this protein",
      detail = sprintf("%s - %s%s - covers %.0f%% - %d chain(s) - %d structures available",
                       toupper(experimental$pdb_id), experimental$method,
                       if (is.na(experimental$resolution)) "" else sprintf(" %.2f A", experimental$resolution),
                       100 * experimental$coverage, experimental$chains, experimental$total),
      alternative = NULL
    ))
  }

  empty$reason <- "no structure is available for this accession"
  empty$detail <- "Neither AlphaFold nor the PDB has a structure mapped to it."
  empty
}
