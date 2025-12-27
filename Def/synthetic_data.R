# ============================================
# Generador de datos sintéticos MicroarrAI (v4) — con epítopo forzado
# - En prot2, peps 31–36:
#   * Tratados: IgG4 HIGH (↑) e IgE HIGH (↓)
#   * Placebo: NS en ambos
# ============================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(tidyr)
  library(openxlsx)
})

generate_microarrai_datasets_v4 <- function(
    # Población
  n_treated = 30,
  n_placebo = 30,
  # Diseño del array
  n_proteins = 3,
  peps_per_protein = 70,
  n_epitopes = 6,
  epitope_size_range = c(3, 4),
  n_decoy_per_isotype = 80,
  # Efectos (magnitudes |log2FC| por tramo)
  effects = list(
    IgE  = list(slight_mu = 0.30, slight_sd = 0.12, high_mu = 0.80, high_sd = 0.25),
    IgG4 = list(slight_mu = 0.32, slight_sd = 0.15, high_mu = 0.90, high_sd = 0.22)
  ),
  # Proporciones de tramos por grupo/isotipo (Placebo sin "high" por defecto)
  props_placebo = list(
    IgE  = c(NS = 0.92, slight = 0.08, high = 0.00),
    IgG4 = c(NS = 0.93, slight = 0.07, high = 0.00)
  ),
  props_treated = list(
    IgE  = c(NS = 0.70, slight = 0.22, high = 0.08),
    IgG4 = c(NS = 0.72, slight = 0.20, high = 0.08)
  ),
  # Proporción de "up" (resto "down")
  up_ratio = list(
    treated = list(IgE = 0.20, IgG4 = 0.90),
    placebo = list(IgE = 0.45, IgG4 = 0.55)
  ),
  # Baseline (log2) y cero-inflación
  baseline_log2 = list(
    IgE  = list(mu = 8.2, sd = 0.55, zero_prob = 0.10, near0_min = 0.03, near0_max = 0.10),
    IgG4 = list(mu = 1.2, sd = 0.45, zero_prob = 0.65, near0_min = 0.01, near0_max = 0.05)
  ),
  # Ruido/jitter
  ns_sd_log2 = 0.03,           # NS ~ N(0, ns_sd)
  per_sample_jitter_sd = 0.05, # jitter por muestra en END
  # Epítopos (probabilidad de "high" en tratados; placebo sin "high")
  epitope_high_prob_treated = 0.65,
  epitope_placebo_slight_prob = 0.85, # resto NS
  # >>> NUEVO: epítopo forzado y sus reglas
  forced_epitope = list(
    protein = "prot2", start = 31, size = 6, epitope_id = "E_forzado",
    treated = list(IgG4 = list(cat = "high", dir = +1),
                   IgE  = list(cat = "high", dir = -1)),
    placebo = list(IgG4 = list(cat = "NS",   dir = +1),
                   IgE  = list(cat = "NS",   dir = -1))
  ),
  # Semilla
  seed = 123
) {
  set.seed(seed)
  stopifnot(length(epitope_size_range) == 2)
  
  # ---------- 1) Matriz clínica ----------
  make_ids <- function(prefix, n) sprintf("%s%03d", prefix, seq_len(n))
  ids_t <- make_ids("T", n_treated)
  ids_p <- make_ids("P", n_placebo)
  
  clinical <- tibble(
    id = c(
      paste0(rep(ids_t, each = 2), "_", rep(c("baseline","end_followup"), times = n_treated)),
      paste0(rep(ids_p, each = 2), "_", rep(c("baseline","end_followup"), times = n_placebo))
    ),
    Group = factor(c(
      rep(c("Inmunoterapia_baseline","Inmunoterapia_end_followup"), times = n_treated),
      rep(c("Placebo_baseline","Placebo_end_followup"), times = n_placebo)
    ),
    levels = c("Inmunoterapia_baseline","Inmunoterapia_end_followup",
               "Placebo_baseline","Placebo_end_followup")),
    Sex  = sample(c("Male","Female"), size = (n_treated + n_placebo)*2, replace = TRUE),
    Age  = sample(5:17, size = (n_treated + n_placebo)*2, replace = TRUE)
  )
  
  # ---------- 2) Catálogo de features ----------
  proteins <- paste0("prot", seq_len(n_proteins))
  pep_ids  <- paste0("pep", seq_len(peps_per_protein))
  make_feat <- function(isotype) unlist(lapply(proteins, function(pr) paste0(isotype, "_", pr, "_", pep_ids)))
  feats_IgE  <- make_feat("IgE")
  feats_IgG4 <- make_feat("IgG4")
  all_feats  <- c(feats_IgE, feats_IgG4)
  
  # ---------- 3) Epítopos co-localizados ----------
  pick_epitopes <- function() {
    ep_list <- list(); tries <- 0
    while (length(ep_list) < n_epitopes && tries < 2000) {
      pr <- sample(proteins, 1)
      sz <- sample(seq(epitope_size_range[1], epitope_size_range[2]), 1)
      st <- sample(1:(peps_per_protein - sz + 1), 1)
      key <- paste(pr, st, sz, sep = "_")
      if (!key %in% names(ep_list)) ep_list[[key]] <- list(protein = pr, start = st, size = sz)
      tries <- tries + 1
    }
    ep_df <- bind_rows(lapply(ep_list, as.data.frame))
    ep_df$epitope_id <- paste0("E", seq_len(nrow(ep_df)))
    ep_df
  }
  ep_meta <- pick_epitopes()
  
  # --- Inserta epítopo fijo en prot2: pep 31-36 ---
  add_forced_epitope <- function(ep_df, forced) {
    if (!forced$protein %in% paste0("prot", seq_len(n_proteins))) return(ep_df)
    if (forced$start < 1 || forced$start + forced$size - 1 > peps_per_protein) return(ep_df)
    exists_same <- any(ep_df$protein == forced$protein &
                         ep_df$start   == forced$start &
                         ep_df$size    == forced$size)
    if (!exists_same) {
      ep_df <- bind_rows(
        ep_df,
        tibble(protein = forced$protein, start = forced$start, size = forced$size, epitope_id = forced$epitope_id)
      )
    } else {
      # si ya existe, mantenemos su epitope_id original
      idx <- which(ep_df$protein == forced$protein &
                     ep_df$start   == forced$start &
                     ep_df$size    == forced$size)
      ep_df$epitope_id[idx] <- ifelse(is.na(ep_df$epitope_id[idx]), forced$epitope_id, ep_df$epitope_id[idx])
    }
    ep_df
  }
  ep_meta <- add_forced_epitope(ep_meta, forced_epitope)
  
  make_weights <- function(sz) {
    x <- seq_len(sz); mid <- (sz + 1) / 2
    w <- dnorm(x, mean = mid, sd = sz/4)
    w / max(w) # pico central
  }
  
  expand_ep <- function(isotype) {
    map_dfr(seq_len(nrow(ep_meta)), function(i) {
      pr <- ep_meta$protein[i]; st <- ep_meta$start[i]; sz <- ep_meta$size[i]
      idx <- st:(st + sz - 1)
      tibble(
        epitope_id = ep_meta$epitope_id[i],
        isotype    = isotype,
        protein    = pr,
        pep_index  = idx,
        feature    = paste0(isotype, "_", pr, "_pep", idx),
        weight     = make_weights(sz)[seq_along(idx)]
      )
    })
  }
  ep_IgE  <- expand_ep("IgE")
  ep_IgG4 <- expand_ep("IgG4")
  
  # ---------- 4) Decoys fuera de epítopos ----------
  pool_IgE  <- setdiff(feats_IgE,  unique(ep_IgE$feature))
  pool_IgG4 <- setdiff(feats_IgG4, unique(ep_IgG4$feature))
  dec_IgE   <- sample(pool_IgE,  size = n_decoy_per_isotype, replace = FALSE)
  dec_IgG4  <- sample(pool_IgG4, size = n_decoy_per_isotype, replace = FALSE)
  
  # ---------- 5) Tabla de features con metadatos ----------
  feat_tbl <- bind_rows(
    tibble(feature = feats_IgE,  isotype = "IgE"),
    tibble(feature = feats_IgG4, isotype = "IgG4")
  ) %>%
    separate(feature, into = c("isotype","protein","pep"), sep = "_", remove = FALSE) %>%
    mutate(pep_index = as.integer(sub("^pep","", pep)),
           in_epitope = FALSE,
           epitope_id = NA_character_,
           weight = 1)
  
  # anotar épitopos
  annotate_ep <- function(ft, ep_map) {
    idx <- match(ft$feature, ep_map$feature)
    m   <- !is.na(idx)
    ft$in_epitope[m] <- TRUE
    ft$epitope_id[m] <- ep_map$epitope_id[idx[m]]
    ft$weight[m]     <- ep_map$weight[idx[m]]
    ft
  }
  feat_tbl <- feat_tbl %>% annotate_ep(ep_IgE) %>% annotate_ep(ep_IgG4)
  
  # ---------- 6) Baseline en log2 + cero-inflación ----------
  n_samples  <- nrow(clinical)
  n_features <- nrow(feat_tbl)
  
  # efectos por péptido (pequeños) para baseline
  pep_effect_log2 <- feat_tbl %>%
    mutate(pep_eff = ifelse(isotype == "IgE",
                            rnorm(n(), 0, 0.06),
                            rnorm(n(), 0, 0.04))) %>%
    pull(pep_eff)
  
  X_log2 <- matrix(NA_real_, nrow = n_samples, ncol = n_features,
                   dimnames = list(clinical$id, feat_tbl$feature))
  
  fill_baseline_log2 <- function(isotype, nfeat) {
    pars <- baseline_log2[[isotype]]
    v <- rnorm(nfeat, mean = pars$mu, sd = pars$sd)
    z <- rbinom(nfeat, 1, prob = pars$zero_prob) == 1
    if (any(z)) {
      v[z] <- log2(runif(sum(z), min = pars$near0_min, max = pars$near0_max))
    }
    v
  }
  
  for (i in seq_len(n_samples)) {
    this_iso <- feat_tbl$isotype
    base_vec <- ifelse(this_iso == "IgE",
                       fill_baseline_log2("IgE",  sum(this_iso == "IgE")),
                       fill_baseline_log2("IgG4", sum(this_iso == "IgG4")))
    base_full <- numeric(n_features)
    base_full[this_iso == "IgE"]  <- base_vec[seq_len(sum(this_iso == "IgE"))]
    base_full[this_iso == "IgG4"] <- base_vec[(sum(this_iso == "IgE")+1):length(base_vec)]
    X_log2[i, ] <- base_full + pep_effect_log2
  }
  
  # ---------- 7) Asignación de tramos y direcciones por grupo/isotipo ----------
  draw_categories <- function(n, props) {
    stopifnot(abs(sum(props) - 1) < 1e-8)
    sample(c("NS","slight","high"), size = n, replace = TRUE, prob = props)
  }
  draw_directions <- function(n, up_prob) {
    ifelse(runif(n) < up_prob, 1, -1) # +1 up, -1 down
  }
  
  assign_per_group <- function(isotype, props, up_prob, allow_high) {
    feats <- feat_tbl$feature[feat_tbl$isotype == isotype]
    cats  <- draw_categories(length(feats),
                             c(NS = props["NS"],
                               slight = props["slight"],
                               high = if (allow_high) props["high"] else 0))
    dirs  <- draw_directions(length(feats), up_prob)
    tibble(feature = feats, isotype = isotype, cat = cats, dir = dirs)
  }
  
  treated_IgE  <- assign_per_group("IgE",  props_treated$IgE,  up_ratio$treated$IgE,  allow_high = TRUE)
  treated_IgG4 <- assign_per_group("IgG4", props_treated$IgG4, up_ratio$treated$IgG4, allow_high = TRUE)
  plac_IgE     <- assign_per_group("IgE",  props_placebo$IgE,  up_ratio$placebo$IgE,  allow_high = FALSE)
  plac_IgG4    <- assign_per_group("IgG4", props_placebo$IgG4, up_ratio$placebo$IgG4, allow_high = FALSE)
  
  # --------- Reglas especiales en epítopos (incluye el forzado) ----------
  # features del epítopo forzado
  forced_features <- list(
    IgE  = paste0("IgE_",  forced_epitope$protein, "_pep", forced_epitope$start:(forced_epitope$start + forced_epitope$size - 1)),
    IgG4 = paste0("IgG4_", forced_epitope$protein, "_pep", forced_epitope$start:(forced_epitope$start + forced_epitope$size - 1))
  )
  
  force_epitopes <- function(df, is_treated, isotype_label) {
    # 1) Reglas generales (epítopos aleatorios)
    ep_feats <- (if (isotype_label == "IgE") ep_IgE else ep_IgG4) %>% pull(feature)
    is_ep <- df$feature %in% ep_feats
    if (any(is_ep)) {
      if (is_treated) {
        draw_high <- runif(sum(is_ep)) < epitope_high_prob_treated
        df$cat[is_ep] <- ifelse(draw_high, "high", "slight")
      } else {
        draw_slight <- runif(sum(is_ep)) < epitope_placebo_slight_prob
        df$cat[is_ep] <- ifelse(draw_slight, "slight", "NS")
      }
    }
    # Direcciones base por grupo
    if (is_treated && isotype_label == "IgE")   df$dir[is_ep] <- draw_directions(sum(is_ep), up_ratio$treated$IgE)
    if (is_treated && isotype_label == "IgG4")  df$dir[is_ep] <- draw_directions(sum(is_ep), up_ratio$treated$IgG4)
    if (!is_treated && isotype_label == "IgE")  df$dir[is_ep] <- draw_directions(sum(is_ep), up_ratio$placebo$IgE)
    if (!is_treated && isotype_label == "IgG4") df$dir[is_ep] <- draw_directions(sum(is_ep), up_ratio$placebo$IgG4)
    
    # 2) OVERRIDE para el epítopo forzado prot2 pep31–36
    forced_vec <- forced_features[[isotype_label]]
    m_forced <- df$feature %in% forced_vec
    if (any(m_forced)) {
      rules <- if (is_treated) forced_epitope$treated[[isotype_label]] else forced_epitope$placebo[[isotype_label]]
      df$cat[m_forced] <- rules$cat
      df$dir[m_forced] <- rules$dir
    }
    df
  }
  
  treated_IgE  <- force_epitopes(treated_IgE,  is_treated = TRUE,  isotype_label = "IgE")
  treated_IgG4 <- force_epitopes(treated_IgG4, is_treated = TRUE,  isotype_label = "IgG4")
  plac_IgE     <- force_epitopes(plac_IgE,     is_treated = FALSE, isotype_label = "IgE")
  plac_IgG4    <- force_epitopes(plac_IgG4,    is_treated = FALSE, isotype_label = "IgG4")
  
  plan_treated <- bind_rows(treated_IgE, treated_IgG4)
  plan_placebo <- bind_rows(plac_IgE, plac_IgG4)
  
  # ---------- 8) Construir delta por feature (log2) ----------
  draw_mag <- function(isotype, cat) {
    eff <- effects[[isotype]]
    if (cat == "NS")  return(rnorm(1, mean = 0, sd = ns_sd_log2))
    if (cat == "slight") return(abs(rnorm(1, eff$slight_mu, eff$slight_sd)))
    if (cat == "high")   return(abs(rnorm(1, eff$high_mu,   eff$high_sd)))
    0
  }
  
  build_delta_vec <- function(plan_df) {
    out <- numeric(n_features); names(out) <- feat_tbl$feature
    by_feat <- plan_df
    for (j in seq_len(nrow(by_feat))) {
      f   <- by_feat$feature[j]
      iso <- by_feat$isotype[j]
      cat <- by_feat$cat[j]
      dir <- by_feat$dir[j]
      w   <- feat_tbl$weight[match(f, feat_tbl$feature)]
      mag <- draw_mag(iso, cat)
      out[f] <- dir * mag * w
    }
    out
  }
  
  delta_treated  <- build_delta_vec(plan_treated)
  delta_placebo  <- build_delta_vec(plan_placebo)
  
  # ---------- 9) Aplicar deltas a END ----------
  is_trt_end  <- clinical$Group == "Inmunoterapia_end_followup"
  is_plcb_end <- clinical$Group == "Placebo_end_followup"
  
  if (any(is_trt_end)) {
    X_log2[is_trt_end, ]  <- sweep(X_log2[is_trt_end, , drop = FALSE], 2, delta_treated, `+`) +
      matrix(rnorm(sum(is_trt_end) * n_features, 0, per_sample_jitter_sd),
             nrow = sum(is_trt_end), ncol = n_features)
  }
  if (any(is_plcb_end)) {
    X_log2[is_plcb_end, ] <- sweep(X_log2[is_plcb_end, , drop = FALSE], 2, delta_placebo, `+`) +
      matrix(rnorm(sum(is_plcb_end) * n_features, 0, per_sample_jitter_sd),
             nrow = sum(is_plcb_end), ncol = n_features)
  }
  
  # ---------- 10) Salidas (lineal) ----------
  X <- 2^X_log2
  dimnames(X) <- list(clinical$id, feat_tbl$feature)
  
  peptide_df <- as_tibble(X, .name_repair = "minimal") %>%
    bind_cols(tibble(id = clinical$id), .) %>%
    relocate(id)
  
  epitope_map <- bind_rows(
    ep_IgE  %>% select(isotype, protein, epitope_id, pep_index, feature),
    ep_IgG4 %>% select(isotype, protein, epitope_id, pep_index, feature)
  ) %>% arrange(isotype, protein, epitope_id, pep_index)
  
  decoys <- tibble(feature = c(dec_IgE, dec_IgG4),
                   isotype = ifelse(grepl("^IgE_", c(dec_IgE, dec_IgG4)), "IgE", "IgG4"))
  
  list(
    clinical    = clinical,
    peptides    = peptide_df,
    epitope_map = epitope_map,
    decoys      = decoys
  )
}

# ============================
# EJEMPLO DE USO + GUARDADO
# ============================
# NOTA: Este código está comentado para evitar generar archivos al cargar el módulo.
# Para generar datos sintéticos, ejecuta manualmente este bloque en la consola.

# synth <- generate_microarrai_datasets_v4(
#   n_treated = 130, n_placebo = 60,
#   n_proteins = 3, peps_per_protein = 70,
#   n_epitopes = 6, n_decoy_per_isotype = 80,
#   # Config ejemplo (puedes ajustar a tu gusto)
#   effects = list(
#     IgE  = list(slight_mu = 0.28, slight_sd = 0.10, high_mu = 0.75, high_sd = 0.20),
#     IgG4 = list(slight_mu = 0.30, slight_sd = 0.12, high_mu = 0.85, high_sd = 0.22)
#   ),
#   props_placebo = list(
#     IgE  = c(NS = 0.62, slight = 0.38, high = 0.00),
#     IgG4 = c(NS = 0.53, slight = 0.47, high = 0.00)
#   ),
#   props_treated = list(
#     IgE  = c(NS = 0.50, slight = 0.34, high = 0.16),
#     IgG4 = c(NS = 0.52, slight = 0.20, high = 0.28)
#   ),
#   # (opcional) puedes omitir forced_epitope aquí porque ya viene configurado como "high" en ambos
#   seed = 123
# )
# 
# clinical_df <- synth$clinical
# peptide_df  <- synth$peptides
# 
# # Guardar en XLSX
# write.xlsx(clinical_df, "pdata_v1.xlsx", overwrite = TRUE)
# write.xlsx(peptide_df,  "expression_matrix_v1.xlsx", overwrite = TRUE)
