# =============================================================================
# Synthetic example datasets for MicroarrAI (tutorial + journal test data)
# =============================================================================
# Three two-group cohorts written as ScanArray-style CSV exports: two channels,
# duplicate peptide spots, PBS blanks and a positive-control dilution series.
# Signal levels follow aggregate statistics of real arrays (blank log2 F/B
# sd ~0.1, local background ~1240 (Ch1) / ~330 (Ch2)). No patient value is used.
#
# Sequences come from UniProt at generation time. Run from the repo root:
#   Rscript www/examples/make_examples.R
# =============================================================================

suppressPackageStartupMessages({ library(dplyr); library(tibble) })
set.seed(2026)

out_root <- "www/examples"

# Epitopes: protein tag, centre residue, kind ("diff" favours group 1 in the
# first channel; "shared" is equally frequent in both groups)
datasets <- list(
  food_allergy = list(
    prefix = "FA", groups = c(Allergic = 62, Tolerant = 58),
    channels = c("IgE", "IgG4"), pep_len = 20, offset = 3, pos_ctrl = "aIgE",
    proteins = tribble(
      ~tag,     ~accession, ~name,
      "Arah2",  "Q6PSU2",   "Ara h 2 (peanut 2S albumin)",
      "Bosd5",  "P02754",   "Bos d 5 (beta-lactoglobulin)",
      "Bosd9",  "P02662",   "Bos d 9 (alpha-s1-casein)",
      "Gald1",  "P01005",   "Gal d 1 (ovomucoid)",
      "Prup3",  "P81402",   "Pru p 3 (peach lipid-transfer protein)"
    ),
    epitopes = tribble(
      ~tag,    ~centre, ~kind,
      "Arah2",  35, "diff",  "Arah2",  65, "diff",  "Arah2", 140, "shared",
      "Bosd5",  70, "diff",  "Bosd5", 135, "shared",
      "Bosd9",  85, "diff",  "Bosd9", 185, "diff",
      "Gald1",  60, "shared","Gald1", 140, "diff",
      "Prup3",  18, "diff",  "Prup3",  75, "shared"
    ),
    channel2_favours = "group2",   # IgG4 is higher in tolerant patients
    clinical = function(n, grp) tibble(
      Age = round(runif(n, 2, 16)),
      Sex = sample(c("Female", "Male"), n, TRUE),
      Total_IgE_kUL = round(exp(rnorm(n, ifelse(grp == "Allergic", 6, 4.8), 0.8))),
      Atopic_dermatitis = ifelse(runif(n) < ifelse(grp == "Allergic", 0.55, 0.3), "Yes", "No")
    )
  ),

  airborne_allergy = list(
    prefix = "AA", groups = c(Symptomatic = 56, Asymptomatic = 54),
    channels = c("IgE", "IgG4"), pep_len = 15, offset = 5, pos_ctrl = "aIgE",
    proteins = tribble(
      ~tag,     ~accession, ~name,
      "Betv1",  "P15494",   "Bet v 1 (birch pollen PR-10)",
      "Derp1",  "P08176",   "Der p 1 (house dust mite cysteine protease)",
      "Derp2",  "P49278",   "Der p 2 (house dust mite NPC2 family)",
      "Feld1",  "P30438",   "Fel d 1 chain 1 (cat uteroglobin)",
      "Olee1",  "P19963",   "Ole e 1 (olive pollen)"
    ),
    epitopes = tribble(
      ~tag,    ~centre, ~kind,
      "Betv1",  45, "diff",  "Betv1", 145, "diff",
      "Derp1", 125, "diff",  "Derp1", 215, "shared", "Derp1", 290, "diff",
      "Derp2",  70, "diff",
      "Feld1",  35, "shared","Feld1",  70, "diff",
      "Olee1",  50, "shared","Olee1", 100, "diff"
    ),
    channel2_favours = "group2",
    clinical = function(n, grp) tibble(
      Age = round(runif(n, 18, 65)),
      Sex = sample(c("Female", "Male"), n, TRUE),
      Asthma = ifelse(runif(n) < ifelse(grp == "Symptomatic", 0.6, 0.1), "Yes", "No"),
      Eosinophils_uL = round(exp(rnorm(n, ifelse(grp == "Symptomatic", 5.9, 5.3), 0.4)))
    )
  ),

  viral_serology = list(
    prefix = "VS", groups = c(Multiple_sclerosis = 65, Control = 65),
    channels = c("IgG", "IgA"), pep_len = 15, offset = 4, pos_ctrl = "aIgG",
    proteins = tribble(
      ~tag,        ~accession, ~name,                                      ~from, ~to,
      "EBNA1",     "P03211",   "EBV nuclear antigen 1 (C-terminal region)", 330,  641,
      "VCAp18",    "P14348",   "EBV VCA p18 (BFRF3)",                        1,    176,
      "SpikeRBD",  "P0DTC2",   "SARS-CoV-2 spike receptor-binding domain", 319,  541,
      "Nucleo",    "P0DTC9",   "SARS-CoV-2 nucleoprotein",                    1,    419
    ),
    epitopes = tribble(
      ~tag,       ~centre, ~kind,
      "EBNA1",     395, "diff",  "EBNA1", 465, "shared", "EBNA1", 600, "diff",
      "VCAp18",    160, "shared",
      "SpikeRBD",  460, "shared", "SpikeRBD", 500, "shared",
      "Nucleo",    165, "shared", "Nucleo", 385, "shared"
    ),
    channel2_favours = "none",     # IgA: no group difference
    clinical = function(n, grp) tibble(
      Age = round(runif(n, 20, 60)),
      Sex = ifelse(runif(n) < ifelse(grp == "Multiple_sclerosis", 0.7, 0.5), "Female", "Male"),
      COVID19_vaccinated = ifelse(runif(n) < 0.9, "Yes", "No")
    )
  )
)

fetch_sequence <- function(acc) {
  jsonlite::fromJSON(paste0("https://rest.uniprot.org/uniprotkb/", acc,
                            ".json?fields=sequence"))$sequence$value
}

# Overlapping peptides covering [from, to] of each protein
tile_peptides <- function(proteins, pep_len, offset) {
  bind_rows(lapply(seq_len(nrow(proteins)), function(i) {
    p <- proteins[i, ]
    seq <- fetch_sequence(p$accession)
    from <- if ("from" %in% names(p)) p$from else 1
    to <- if ("to" %in% names(p)) p$to else nchar(seq)
    starts <- seq(from, to - pep_len + 1, by = offset)
    tibble(protein = p$tag, accession = p$accession, name = p$name,
           number = seq_along(starts), start = starts, end = starts + pep_len - 1,
           peptide = substring(seq, starts, starts + pep_len - 1), length = pep_len)
  }))
}

# log2(F/B) each patient's antibodies add to a peptide: one bump per epitope,
# scaled by how much of the 10-residue epitope the peptide covers
peptide_signal <- function(peps, epitopes, reactive, amplitude) {
  out <- numeric(nrow(peps))
  for (k in which(reactive)) {
    e <- epitopes[k, ]
    on <- peps$protein == e$tag
    cover <- pmax(0, pmin(peps$end, e$centre + 5) - pmax(peps$start, e$centre - 4)) / 10
    out[on] <- out[on] + amplitude[k] * cover[on]^1.3
  }
  out
}

# Which epitopes a patient recognises, and how strongly, in one channel
draw_response <- function(epitopes, in_group1, channel, favours) {
  diff <- epitopes$kind == "diff"
  p <- if (channel == 1) {
    ifelse(diff, ifelse(in_group1, 0.75, 0.2), 0.5)
  } else if (favours == "group2") {
    ifelse(diff, ifelse(in_group1, 0.3, 0.7), 0.4)
  } else 0.35
  amp_mean <- if (channel == 1) ifelse(diff & in_group1, 2.8, 1.6) else 1.9
  list(reactive = runif(nrow(epitopes)) < p,
       amplitude = pmax(0.3, rnorm(nrow(epitopes), amp_mean, 0.7)))
}

write_array <- function(path, layout, f1, b1, f2, b2, flags) {
  sat <- function(f) ifelse(f >= 65535, 100, 0)
  data <- tibble(Index = seq_len(nrow(layout)), Name = layout$ID, ID = layout$ID,
                 X = layout$X, Y = layout$Y, Flags = flags,
                 `Ch1 Median` = round(pmin(f1, 65535)), `Ch1 B Median` = round(b1),
                 `Ch1 F % Sat.` = sat(f1),
                 `Ch2 Median` = round(pmin(f2, 65535)), `Ch2 B Median` = round(b2),
                 `Ch2 F % Sat.` = sat(f2))
  header <- c("BEGIN HEADER,", "MicroarrAI synthetic example - not patient data,",
              "ScanArrayCSVFileFormat,2", "END HEADER,", "", "BEGIN DATA,")
  con <- file(path, "w")
  writeLines(header, con)
  write.table(data, con, sep = ",", row.names = FALSE, quote = FALSE)
  writeLines("END DATA,", con)
  close(con)
}

make_dataset <- function(key, d) {
  message("== ", key)
  dir <- file.path(out_root, key)
  unlink(dir, recursive = TRUE)
  dir.create(file.path(dir, "arrays"), recursive = TRUE)

  peps <- tile_peptides(d$proteins, d$pep_len, d$offset)
  readr::write_csv(peps, file.path(dir, "annotation.csv"))

  # Spot layout shared by every array (same print run): duplicate peptides,
  # 60 PBS blanks, 4 empty spots and a 4-step positive-control series
  pep_ids <- paste0("p ", peps$number, " (", peps$protein, ")")
  doses <- c("00625", "0125", "025", "05")
  ids <- c(rep(pep_ids, 2), rep("PBS 1X", 60), rep("empty", 4),
           rep(paste0(d$pos_ctrl, "_", doses), 2))
  ids <- sample(ids)
  ncol_grid <- 24
  layout <- tibble(ID = ids, X = 300 + 180 * ((seq_along(ids) - 1) %% ncol_grid),
                   Y = 300 + 180 * ((seq_along(ids) - 1) %/% ncol_grid))
  pep_row <- match(sub("^p (\\d+) \\((.*)\\)$", "\\2:\\1", layout$ID),
                   paste0(peps$protein, ":", peps$number))
  dose_level <- match(sub(".*_", "", layout$ID), doses)
  dose_level[!startsWith(layout$ID, d$pos_ctrl)] <- NA

  groups <- rep(names(d$groups), d$groups)
  n <- length(groups)
  ids_samples <- sprintf("%s-%03d", d$prefix, seq_len(n))
  # Three arrays carry a typical failure so the QC tab has something to show:
  # a failed assay, a badly flagged print and a background gradient
  bad <- sample(n, 3)

  for (i in seq_len(n)) {
    g1 <- groups[i] == names(d$groups)[1]
    strength <- exp(rnorm(1, 0, 0.25))
    signal <- lapply(1:2, function(ch) {
      r <- draw_response(d$epitopes, g1, ch, d$channel2_favours)
      peptide_signal(peps, d$epitopes, r$reactive, r$amplitude * strength)
    })

    # Each peptide also has its own non-specific binding in each patient, shared
    # by its duplicate spots (as on real slides); blanks only carry spot noise
    spot_log2 <- function(ch) {
      sticky <- rnorm(nrow(peps), 0, 0.22)
      s <- ifelse(is.na(pep_row), 0, signal[[ch]][pep_row] + sticky[pep_row])
      s[!is.na(dose_level)] <- c(1.2, 2.2, 3.2, 4.2)[dose_level[!is.na(dose_level)]]
      s + rnorm(nrow(layout), 0.02, ifelse(is.na(pep_row), 0.1, 0.07))
    }
    l1 <- spot_log2(1); l2 <- spot_log2(2)
    b1 <- 330 * exp(rnorm(1, 0, 0.2)) * exp(rnorm(nrow(layout), 0, 0.12))
    b2 <- 1240 * exp(rnorm(1, 0, 0.2)) * exp(rnorm(nrow(layout), 0, 0.12))
    flags <- sample(c(1, 3), nrow(layout), TRUE, prob = c(0.9, 0.1))

    if (i == bad[1]) {                      # failed assay: no specific signal
      l1 <- rnorm(nrow(layout), 0.02, 0.25); l2 <- rnorm(nrow(layout), 0.02, 0.25)
    } else if (i == bad[2]) {               # print defects: many unusable spots
      flags[sample(nrow(layout), round(0.12 * nrow(layout)))] <- 4
    } else if (i == bad[3]) {               # background gradient across the slide
      gradient <- 1 + 2.5 * (layout$X - min(layout$X)) / diff(range(layout$X))
      b1 <- b1 * gradient; b2 <- b2 * gradient
      l1 <- l1 + rnorm(nrow(layout), 0, 0.35); l2 <- l2 + rnorm(nrow(layout), 0, 0.35)
    }

    # Lab convention: scanner channel 1 (red) holds the secondary isotype
    # (IgG4 / IgA), channel 2 (green) the primary one (IgE / IgG)
    write_array(file.path(dir, "arrays", paste0(ids_samples[i], ".csv")),
                layout, b2 * 2^l2, b2, b1 * 2^l1, b1, flags)
  }

  clinical <- bind_cols(tibble(id = ids_samples, Group = groups),
                        d$clinical(n, groups))
  readr::write_csv(clinical, file.path(dir, "clinical.csv"))
  message("   ", n, " arrays, ", nrow(peps), " peptides, problem arrays: ",
          paste(ids_samples[bad], collapse = ", "))
}

for (key in names(datasets)) make_dataset(key, datasets[[key]])
