# =============================================================================
# UI for 2D/3D Protein Visualization
# Native D3 (2D snake) + 3Dmol (3D AlphaFold) explorer, hover-linked.
# =============================================================================

#' UI for protein visualization tab
#' @return Shiny UI
#' @export
ui_protein_viz <- function() {
  tabPanel(
    "Protein Visualization",

    loading_overlay(id = "protein_loader", label = "Loading visualization…"),

    tags$head(
      tags$script(src = "https://d3js.org/d3.v7.min.js"),
      tags$script(src = "https://3Dmol.org/build/3Dmol-min.js"),
      tags$script(src = "protein_playground.js"),
      tags$style(HTML("
        /* match the rest of the app's UI font */
        #protein-content, #protein-sidebar, .pv-card, #pv-info, #pv-legend, .pv-tip,
        #pv-2d text, #pv-legend text {
          font-family: 'Space Grotesk', 'Inter', system-ui, sans-serif;
        }
        /* Long proteins: the strip scrolls instead of pushing the page down */
        #pv-strip { display:flex; flex-wrap:wrap; gap:2px; max-height:132px; overflow-y:auto; padding-right:4px; }
        .pv-aa { flex:0 0 auto; width:19px; height:22px; display:flex; align-items:center; justify-content:center;
                 font:600 11px ui-monospace, monospace; background:#f0f2f5; border:1px solid #e2e5ea;
                 border-radius:3px; color:#3a4050; cursor:pointer; }
        .pv-aa.bm { border-bottom:2px solid #ff6b35; }
        .pv-aa.hl { outline:2px solid #ffd60a; outline-offset:1px; background:#fff7d6; }
        .pv-bottom { display:flex; gap:14px; align-items:stretch; }
        .pv-left { flex:0 0 320px; display:flex; }
        .pv-left .pv-card { display:flex; flex-direction:column; width:100%; }
        .pv-right { flex:1; min-width:0; }
        .pv-card { background:#fff; border:1px solid #e6e8ec; border-radius:12px; padding:12px 14px; margin-bottom:14px; }
        .pv-card h4 { margin:0 0 10px; font-size:13px; color:#8a8f98; text-transform:uppercase; letter-spacing:.04em; }
        #pv-2d { flex:1; min-height:340px; display:flex; flex-direction:column; }
        #pv-2d svg { display:block; }
        /* The canvas scrolls; the drawing keeps a readable size */
        .pv-canvas { flex:1; max-height:560px; overflow:auto; border:1px solid #eef0f3;
                     border-radius:8px; background:#fcfcfd; }
        .pv-tools { display:flex; align-items:center; gap:6px; margin-bottom:8px; }
        .pv-tools-info { flex:1; font-size:12px; color:#8a8f98; }
        .pv-btn { border:1px solid #d8dbe0; background:#fff; border-radius:6px;
                  padding:3px 10px; font-size:12px; color:#3a4050; cursor:pointer; }
        .pv-btn:hover { background:#f0f2f5; border-color:#17a589; color:#0e7d6e; }
        .pv-btn:focus-visible { outline:2px solid #17a589; outline-offset:1px; }
        .pv-hint { font-size:11.5px; color:#8a8f98; line-height:1.5; margin:-8px 0 12px; }
        .pv-structure-note { background:#fff4e5; border-left:4px solid #ff6b35; padding:10px 14px;
                             border-radius:6px; font-size:13px; color:#191c32; margin-bottom:14px; }
        #pv-3d { width:100%; height:600px; position:relative; border-radius:8px; }
        #pv-legend { margin-top:10px; font-size:12px; color:#3a4050; }
        #pv-info { margin-top:8px; font-size:13px; color:#191c32; min-height:20px; }
        .pv-tip { position:absolute; pointer-events:none; background:rgba(25,28,50,.94); color:#fff;
                  padding:8px 10px; border-radius:6px; font-size:12px; line-height:1.55; opacity:0; z-index:10000; max-width:230px; }
        #protein-content { transition: margin-left 0.3s ease; margin-left: 0; }
      "))
    ),

    # ---- Floating sidebar (same pattern as ML tab) ----
    tags$div(
      id = "protein-sidebar", class = "ml-sidebar",
      tags$h4(icon("dna", style = "margin-right:10px;"), "Protein Viz"),
      tags$div(id = "protein-sidebar-toggle", class = "ml-sidebar-toggle", icon("bars")),

      tags$div(class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "CONFIGURATION"),
        tags$div(style = "padding:10px;",
          fileInput("protein_annotation", HTML("<strong>Peptide annotation:</strong>"),
                    buttonLabel = "Browse...", accept = c(".csv", ".tsv", ".txt", ".xlsx", ".xls")),
          tags$p(class = "pv-hint",
                 "One row per spotted peptide: protein, accession, number, start and either end or the peptide sequence."),
          uiOutput("protein_selector"),
          uiOutput("protein_peptide_count"),
          actionButton("protein_load", "Load and Visualize", icon = icon("play-circle"),
            style = "width:100%;margin-top:15px;background:linear-gradient(135deg,#17a589 0%,#0e7d6e 100%);color:#fff;border:none;padding:10px;font-weight:bold;")
        )
      ),

      tags$div(class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "VIEW"),
        tags$div(style = "padding:10px;",
          uiOutput("protein_isotype_ui"),
          uiOutput("protein_group_ui"),
          uiOutput("protein_ref_group_ui"),
          uiOutput("protein_color_mode_ui"),
          sliderInput("protein_fdr", "Biomarker FDR ≤", min = 0.001, max = 0.10, value = 0.05, step = 0.001),
          checkboxInput("protein_show_surface", "Molecular surface", FALSE),
          checkboxInput("protein_biomarkers", "Highlight biomarkers", TRUE),
          downloadButton("protein_export", "Export biomarkers (FASTA)", style = "width:100%;margin-top:6px;")
        )
      ),

      tags$div(class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "INFO"),
        tags$div(style = "padding:10px;", uiOutput("protein_info_display"))
      )
    ),

    # ---- Main content ----
    tags$div(id = "protein-content",
      tags$div(style = "background:white;padding:24px;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.1);margin-top:20px;",
        h4("Protein recognition map", style = "color:#191c32;font-weight:bold;margin:0 0 16px;"),
        uiOutput("protein_structure_note"),
        tags$div(class = "pv-card", tags$h4("Sequence"), tags$div(id = "pv-strip")),
        tags$div(class = "pv-bottom",
          tags$div(class = "pv-left",
            tags$div(class = "pv-card",
              tags$h4("2D recognition map"),
              tags$div(id = "pv-2d"),
              tags$div(id = "pv-legend"),
              tags$div(id = "pv-info", "Hover a residue")
            )
          ),
          tags$div(class = "pv-right",
            tags$div(class = "pv-card", style = "height:100%;",
              uiOutput("protein_structure_title"), tags$div(id = "pv-3d"))
          )
        )
      )
    )
  )
}
