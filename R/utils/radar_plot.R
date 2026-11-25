# ============================================================================
# MicroarrAI - Model performance radar
# ============================================================================
# Drawn by www/charts/plots2d.js (chart type "radar"). Metrics missing for a
# model (e.g. sensitivity in a multiclass run) are shown as n/a, not as zero.
# Kappa is clamped at 0 for display: below 0 is worse than chance.
# ============================================================================

#' Radar spec of a trained model's metrics
#'
#' @param result Model result with `metrics` (accuracy, auc, sensitivity,
#'   specificity, kappa)
#' @param model_color Hex colour of the model
create_performance_radar <- function(result, model_color = "#667eea") {
  m <- result$metrics
  pick <- function(k) { v <- m[[k]]; if (is.null(v) || !is.finite(v)) NA_real_ else v }
  chart_radar(c("Accuracy", "AUC", "Sensitivity", "Specificity", "Kappa"),
              c(pick("accuracy"), pick("auc"), pick("sensitivity"), pick("specificity"), max(0, pick("kappa"))),
              color = model_color)
}
