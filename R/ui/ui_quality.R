# ============================================================================
# MicroarrAI - Quality Control tab
# ============================================================================
# Reads the arrays the way a lab does: first "did the assay work at all", then
# "which arrays do I not trust", then "why". The traffic-light grid answers the
# first two at a glance; the per-array panels answer the third.
# ============================================================================

ui_quality <- function() {
  tabPanel(
    "Quality Control",

    tags$head(tags$style(HTML("
      #qc-page { margin-top: 20px; }
      .qc-card { background:#fff; border:1px solid #e6e8ec; border-radius:12px;
                 padding:18px 20px; margin-bottom:16px; }
      .qc-card > h4 { margin:0 0 14px; font-size:13px; color:#8a8f98;
                      text-transform:uppercase; letter-spacing:.05em; }
      .qc-verdicts { display:flex; gap:14px; flex-wrap:wrap; margin-bottom:16px; }
      .qc-tile { flex:1 1 150px; border-radius:12px; padding:16px 18px; color:#fff; }
      .qc-tile b { display:block; font-size:2rem; line-height:1.1; font-variant-numeric:tabular-nums; }
      .qc-tile span { font-size:.82rem; opacity:.92; }
      .qc-green { background:linear-gradient(135deg,#17a589,#0e7d6e); }
      .qc-amber { background:linear-gradient(135deg,#e8a33d,#c9791b); }
      .qc-red   { background:linear-gradient(135deg,#d1495b,#a32e40); }
      .qc-slate { background:linear-gradient(135deg,#4a5568,#2d3748); }
      .qc-banner { border-radius:10px; padding:14px 18px; margin-bottom:16px;
                   font-size:14px; line-height:1.55; }
      .qc-banner.ok   { background:#e8f6f2; border-left:4px solid #17a589; color:#0b4f44; }
      .qc-banner.bad  { background:#fdecef; border-left:4px solid #d1495b; color:#7d1f2c; }
      .qc-legend { display:flex; gap:16px; font-size:12px; color:#5c6873; margin-top:10px; }
      .qc-dot { display:inline-block; width:10px; height:10px; border-radius:2px; margin-right:5px; }
      .qc-help { font-size:12.5px; color:#6b7280; margin:-6px 0 12px; }

      /* Hover explanation on any element carrying data-tip */
      [data-tip] { position:relative; cursor:help; }
      [data-tip]::after {
        content: attr(data-tip);
        position:absolute; left:0; top:calc(100% + 8px); z-index:50;
        width:max-content; max-width:320px;
        background:#191c32; color:#fff; font-size:12px; font-weight:400;
        line-height:1.5; text-transform:none; letter-spacing:0;
        padding:9px 11px; border-radius:8px;
        box-shadow:0 6px 18px rgba(0,0,0,.22);
        opacity:0; visibility:hidden; transition:opacity .15s ease;
      }
      [data-tip]:hover::after { opacity:1; visibility:visible; }
      .qc-metric-help { border-bottom:1px dotted #9aa3ad; }
      .qc-split { width:100%; border-collapse:collapse; font-size:13px; }
      .qc-split th { text-align:left; font-weight:600; color:#8a8f98; font-size:11.5px;
                     text-transform:uppercase; letter-spacing:.04em;
                     padding:0 12px 8px 0; border-bottom:1px solid #e6e8ec; }
      .qc-split td { padding:9px 12px 9px 0; border-bottom:1px solid #f2f4f6;
                     color:#191c32; font-variant-numeric:tabular-nums; }
    "))),

    tags$div(
      id = "qc-page",

      tags$h3("Quality control", style = "color:#191c32;font-weight:bold;margin:0 0 4px;"),
      tags$p(class = "qc-help",
             "Every metric here comes from spots the pipeline already reads: duplicate spots, blank spots and the positive control series."),

      uiOutput("qc_missing_notice"),

      # ---- Headline verdicts --------------------------------------------
      uiOutput("qc_verdict_tiles"),
      uiOutput("qc_raw_notice"),
      uiOutput("qc_channel_breakdown"),

      # ---- Normalization diagnostic -------------------------------------
      uiOutput("qc_normalization_banner"),

      # ---- Completeness (was duplicated in the Peptide finder overview) --
      tags$div(
        class = "qc-card",
        tags$h4("Data completeness"),
        tags$p(class = "qc-help",
               "Counted before imputation, so it reflects what the arrays actually delivered."),
        uiOutput("qc_completeness")
      ),

      # ---- Traffic-light grid -------------------------------------------
      tags$div(
        class = "qc-card",
        tags$h4("Per-array scorecard"),
        tags$p(class = "qc-help",
               "One column per array, worst first. Hover any cell for the value and the grade it earned."),
        fluidRow(
          column(3, uiOutput("qc_channel_selector")),
          column(3, checkboxInput("qc_only_problems", "Only arrays with a problem", FALSE))
        ),
        ggiraph::girafeOutput("qc_heatmap", height = "340px"),
        tags$div(
          class = "qc-legend",
          tags$span(tags$span(class = "qc-dot", style = "background:#17a589;"), "Pass"),
          tags$span(tags$span(class = "qc-dot", style = "background:#e8a33d;"), "Borderline"),
          tags$span(tags$span(class = "qc-dot", style = "background:#d1495b;"), "Fail"),
          tags$span(tags$span(class = "qc-dot", style = "background:#dfe4e6;"), "Not measurable")
        )
      ),

      # ---- Cohort-level distribution ------------------------------------
      fluidRow(
        column(6, tags$div(class = "qc-card",
          tags$h4("Signal distribution per array"),
          tags$p(class = "qc-help", "Arrays that sit apart from the pack are the ones normalization has to reconcile."),
          plotOutput("qc_density", height = "300px"))),
        column(6, tags$div(class = "qc-card",
          tags$h4("Normal Q-Q"),
          tags$p(class = "qc-help", "Departures at the right tail are real binding; departures at the left tail mean the background model is off."),
          plotOutput("qc_qq", height = "300px")))
      ),

      # ---- Per-array forensics ------------------------------------------
      tags$div(
        class = "qc-card",
        tags$h4("Array forensics"),
        tags$p(class = "qc-help",
               "Pick an array to see where its signal sits physically, whether its duplicate spots agree, and whether the positive control responded."),
        uiOutput("qc_array_selector"),
        fluidRow(
          column(4, plotOutput("qc_spatial", height = "330px")),
          column(4, plotOutput("qc_replicates", height = "330px")),
          column(4, plotOutput("qc_dose", height = "330px"))
        )
      ),

      # ---- The numbers ---------------------------------------------------
      tags$div(
        class = "qc-card",
        tags$h4("Metric definitions and thresholds"),
        tableOutput("qc_thresholds"),
        downloadButton("qc_download", "Download the scorecard (CSV)",
                       style = "margin-top:10px;")
      )
    )
  )
}
