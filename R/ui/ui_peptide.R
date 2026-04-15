# ============================================================================
# MicroarrAI - Peptide Finder Tab UI
# ============================================================================
# Description: Statistical analysis and peptide selection interface
# Dependencies: ui_helpers.R
# ============================================================================

ui_peptide <- function() {
  tabPanel(
    title = "Peptide finder",
    
    # Floating Sidebar (SAME STYLE AS ML)
    tags$div(
      id = "peptide-sidebar",
      class = "ml-sidebar",
      
      tags$h4(
        icon("microscope", style = "margin-right: 10px;"),
        "Peptide Analysis"
      ),
      
      # Navigation Sections
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "VISUALIZATION"),
        
        tags$div(
          class = "ml-sidebar-item active",
          `data-target` = "peptide_hplot",
          icon("fire", style = "margin-right: 10px;"),
          "Heatmap"
        )
      ),
      
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "OVERVIEW"),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "kpi_boxes",
          icon("chart-pie", style = "margin-right: 10px;"),
          "Data Overview"
        )
      ),
      
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "ANALYSIS"),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "run_analysis_1",
          icon("flask", style = "margin-right: 10px;"),
          "Statistical Tests"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "volcano_div",
          icon("mountain", style = "margin-right: 10px;"),
          "Volcano Plot"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "feature_level_table",
          icon("dna", style = "margin-right: 10px;"),
          "Feature Level"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "results_panel",
          icon("chart-bar", style = "margin-right: 10px;"),
          "Results"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "biomarker_selector",
          icon("bullseye", style = "margin-right: 10px;"),
          "Biomarkers"
        )
      )
    ),
    
    # Sidebar Toggle Button
    tags$div(
      id = "peptide-sidebar-toggle",
      class = "ml-sidebar-toggle",
      icon("bars")
    ),
    
    # Main Content
    tags$div(
      class = "ml-content",
      
      # ===== 1. HEATMAP =====
    tags$div(
      style = "text-align: center;",
      section_title("EXPRESSION HEATMAP", size = "2.5em")
    ),
    
    card_container(
      style = "padding: 25px; margin: 0 15px; background: transparent;
      box-shadow: none;",
      fluidRow(
        column(
          12,
          plotOutput("peptide_hplot", height = "600px")
        )
      )
    ),
    
    # ===== 2. DATA OVERVIEW =====
    tags$div(
      style = "text-align: center;",
      section_title("DATA OVERVIEW", size = "2.5em")
    ),
    
    # KPI Boxes 
    tags$div(
      style = "padding: 20px 15px 10px 15px; margin: 0;",
      fluidRow(
        column(12, uiOutput("kpi_boxes"))
      )
    ),
    
    # Visualizations y slider con background
    card_container(
      style = "padding: 25px; margin: 0 15px;",
      
      # Expression threshold control - pequeño arriba
      fluidRow(
        column(
          3,
          sliderInput(
            inputId = "zscore_threshold",
            label = dark_label("Expression threshold:"),
            min = 0, max = 10, value = 3, step = 0.5
          )
        )
      ),
      
      # Threshold info panel below slider
      fluidRow(
        column(
          12,
          uiOutput("threshold_info_panel")
        )
      ),
      
      tags$hr(style = "margin: 15px 0;"),
      
      # Visualizations Row
      fluidRow(
        column(
          4,
          tags$h4("Positive Peptides by Isotype", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
          girafeOutput("isotype_donut", height = "300px"),
          tags$br(),
          tags$h4("Isotype Summary Statistics", style = "color: #191c32; margin-bottom: 15px; margin-top: 20px; font-weight: bold;"),
          DT::dataTableOutput("isotype_table")
        ),
        column(
          8,
          tags$h4("Expression Distribution by Isotype", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
          girafeOutput("expression_dist_plot", height = "300px", width = "100%"),
          tags$br(),
          tags$h4("Top Samples by Positive Peptides", style = "color: #191c32; margin-bottom: 15px; margin-top: 20px; font-weight: bold;"),
          DT::dataTableOutput("top_samples_table", height = "300px", width = "100%")
        )
      )
    ),
    
    # ===== Loading Overlay =====
    loading_overlay(id = "loader", gif_src = "assets/Carga.gif"),
    
    # ===== 3. SELECTION OF CANDIDATE PEPTIDES =====
    tags$div(
      style = "margin-top: 60px;",
      section_title("SELECTION OF CANDIDATE PEPTIDES", size = "2.5em")
    ),
    
    card_container_highlighted(
      style = "margin: 0 15px; padding: 25px;",
      fluidRow(
        column(
          12,
          tags$div(
            style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 8px; padding: 20px; margin-bottom: 25px; color: white;",
            tags$h4("What are Differentially Expressed Genes (DEGs)?", style = "margin-top: 0; font-weight: bold; color: white;"),
            tags$p(
              "Differentially Expressed Genes (DEGs) are features showing significant changes in expression levels between experimental conditions. In biomarker discovery, identifying DEGs is crucial as they represent potential diagnostic or therapeutic targets.",
              style = "margin-bottom: 10px; line-height: 1.6;"
            ),
            tags$p(
              tags$strong("Selection Criteria:"), " For robust biomarker selection, combine biological criteria (down/over-expression patterns), statistical significance (p-values, adjusted p-values), and discriminatory power (Fold Change, AUC, Accuracy). This multifaceted approach ensures that selected candidates are both statistically significant and biologically relevant.",
              style = "margin-bottom: 0; line-height: 1.6;"
            )
          )
        )
      ),
      fluidRow(
        column(
          12,
          p("Linear Models (LM) are used as the primary method for differential expression analysis.",
            style = "color: #191c32; text-align: justify; margin-bottom: 20px;")
        )
      ),
      fluidRow(
        column(
          3,
          selectInput(
            inputId = "analysis_type",
            label = dark_label("Type of Analysis:"),
            choices = c("Comparison between groups (Classification)", "Regression model"),
            selected = "Comparison between groups (Classification)"
          )
        ),
        column(3, uiOutput("stats_var")),
        column(
          6,
          centered_content(
            height = "80%",
            actionButton(
              inputId = "run_analysis_1",
              label = "Run Analysis",
              class = "btn-primary",
              style = "width: 50%; margin-top: 25px;"
            )
          )
        )
      )
    ),
    
    
    # ===== VOLCANO PLOT | DIFFERENTIAL EXPRESSION =====
    tags$div(
      id = "volcano_div",
      style = "display: none; margin-top: 60px;",
      section_title("DIFFERENTIAL EXPRESSION ANALYSIS", size = "2.5em"),
      card_container_highlighted(
        style = "margin: 0 15px; padding: 25px;",
        fluidRow(
          column(
            12,
            tags$div(
              style = "background: #f8f9fa; border-left: 4px solid #667eea; padding: 15px; margin-bottom: 20px; border-radius: 4px;",
              tags$p(
                tags$strong("About Volcano Plots:"), " Volcano plots visualize the relationship between statistical significance (p-value) and biological significance (fold change). Points in the upper corners represent highly significant and biologically relevant changes.",
                style = "margin: 0; color: #191c32;"
              )
            )
          )
        ),
        fluidRow(
          column(
            3,
            h4("Filter Options", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
            
            checkboxGroupInput(
              "volcano_isotypes", 
              dark_label("Select Isotypes:"),
              choices = c("IgE", "IgG4"),
              selected = c("IgE", "IgG4")
            ),
            
            checkboxInput(
              "volcano_facet_isotype", 
              "Separate plots by isotype", 
              value = TRUE
            ),
            
            uiOutput("volcano_group_var_ui"),
            uiOutput("volcano_level_a_ui"),
            uiOutput("volcano_level_b_ui"),
            
            tags$div(
              style = "margin-top: 15px;",
              sliderInput(
                "volcano_lfc_thr", 
                dark_label("Fold Change Threshold (|log2FC|):"),
                min = 0, max = 3, value = 1, step = 0.1
              ),
              tags$small("Minimum absolute log2 fold change to consider a feature significant", style = "color: #666;")
            ),
            
            tags$div(
              style = "margin-top: 15px;",
              sliderInput(
                "volcano_padj_thr", 
                dark_label("FDR Threshold (Benjamini-Hochberg):"),
                min = 0, max = 0.2, value = 0.05, step = 0.005
              ),
              tags$small("False Discovery Rate threshold for multiple testing correction", style = "color: #666;")
            ),
            
            checkboxInput(
              "volcano_interactive", 
              "Interactive plot (plotly)", 
              value = TRUE
            ),
            
            tags$hr(),
            
            downloadButton(
              "download_volcano_tbl", 
              "Download Results (.csv)",
              class = "btn-primary",
              style = "width: 100%;"
            )
          ),
          column(
            9,
            uiOutput("volcano_plot_container"),
            br(),
            tags$h4("Significant Features", style = "color: #191c32; margin: 20px 0 15px 0; font-weight: bold;"),
            DT::DTOutput("volcano_hits_table")
          )
        )
      )
    ),
    
    # ===== 5. DIFFERENTIAL EXPRESSION | FEATURE ANALYSIS =====
    tags$div(
      id = "stats_div",
      style = "display: none; margin-top: 60px;",
      section_title("FEATURE LEVEL", size = "2.5em"),
      card_container_highlighted(
        style = "margin: 0 15px; padding: 25px;",
        fluidRow(
          column(
            6,
            tags$h4("Differential Expression Results", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
            withSpinner(DT::dataTableOutput("unified_stats_table"))
          ),
          column(
            6,
            tags$div(
              uiOutput("stats_var_plot"),
              withSpinner(girafeOutput("stats_plot", height = "350px"))
            ),
            tags$hr(style = "margin: 20px 0;"),
            tags$div(
              tags$h4("ROC Curve", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
              withSpinner(plotOutput("rocs_plot", height = "350px"))
            )
          )
        )
      )
    ),
    
    # ===== 6. ANALYSIS FILTERS =====
    tags$div(
      id = "results_filters_div",
      style = "display: none; margin-top: 60px;",
      section_title("ANALYSIS FILTERS", size = "2.5em"),
      card_container_highlighted(
        style = "margin: 0 15px; padding: 30px;",
        tags$div(
          style = "max-width: 1200px; margin: 0 auto;",
          tags$div(
            style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; padding: 20px; margin-bottom: 25px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);",
            tags$div(
              style = "display: flex; align-items: center; margin-bottom: 10px;",
              icon("filter", style = "font-size: 22px; color: white; margin-right: 12px;"),
              tags$h4("Filter Criteria for Results", style = "color: white; margin: 0; font-weight: 600;")
            ),
            tags$p(
              style = "color: rgba(255,255,255,0.9); margin: 0; font-size: 14px; line-height: 1.6;",
              "Adjust the thresholds below to refine the peptides included in the analysis results. Only peptides meeting both criteria will be displayed."
            )
          ),
          fluidRow(
            column(
              6,
              tags$div(
                style = "background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);",
                tags$div(
                  style = "display: flex; align-items: center; margin-bottom: 15px;",
                  icon("chart-line", style = "font-size: 18px; color: #667eea; margin-right: 10px;"),
                  tags$h5("Statistical Significance", style = "color: #191c32; margin: 0; font-weight: 600;")
                ),
                sliderInput(
                  inputId = "results_pval_threshold",
                  label = dark_label("Adjusted p-value threshold:"),
                  min = 0, max = 0.1, value = 0.05, step = 0.01,
                  width = "100%"
                ),
                tags$small(
                  "Only peptides with FDR-corrected p-value below this threshold are included.",
                  style = "color: #666; font-size: 12px;"
                )
              )
            ),
            column(
              6,
              tags$div(
                style = "background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);",
                tags$div(
                  style = "display: flex; align-items: center; margin-bottom: 15px;",
                  icon("bullseye", style = "font-size: 18px; color: #667eea; margin-right: 10px;"),
                  tags$h5("Predictive Performance", style = "color: #191c32; margin: 0; font-weight: 600;")
                ),
                sliderInput(
                  inputId = "results_auc_threshold",
                  label = dark_label("Minimum AUC threshold:"),
                  min = 0.5, max = 1, value = 0.65, step = 0.05,
                  width = "100%"
                ),
                tags$small(
                  "Only peptides with Area Under the Curve (AUC) above this value are included.",
                  style = "color: #666; font-size: 12px;"
                )
              )
            )
          )
        )
      )
    ),
    
    # ===== 7. RESULTS OF THE ANALYSIS =====
    tags$div(
      id = "results_summary_div",
      style = "display: none; margin-top: 40px;",
      section_title("RESULTS OF THE ANALYSIS", size = "2.5em"),
      
      # KPIs outside main container
      tags$div(
        style = "padding: 20px 15px; margin: 0; background: transparent;",
        fluidRow(
          column(12, 
            tags$div(
              style = "justify-content: center;",
              uiOutput("results_kpi_boxes")
            )
          )
        )
      ),
      
      # Main content container
      card_container(
        style = "padding: 25px; margin: 0 15px;",
        fluidRow(
          column(
            6,
            tags$h4("Selection Process Overview", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
            girafeOutput("results_donut", height = "350px")
          ),
          column(
            6,
            tags$div(
              style = "background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
              tags$h4("Analysis Summary", style = "color: #191c32; margin-top: 0; margin-bottom: 15px; font-weight: bold;"),
              uiOutput("results_summary_text")
            )
          )
        )
      )
    ),
    
    # ===== 8. BIOMARKER SELECTION FOR ML =====
    tags$div(
      id = "funnel_div",
      style = "display: none; margin-top: 60px;",
      section_title("BIOMARKER SELECTION FOR MACHINE LEARNING", size = "2.5em"),
      card_container_highlighted(
        style = "margin: 0 15px; padding: 25px;",
        fluidRow(
          column(
            12,
            tags$div(
              style = "background: #f8f9fa; border-left: 4px solid #667eea; padding: 20px; margin-bottom: 25px; border-radius: 4px;",
              tags$h4("Biomarker Selection Methods", style = "margin-top: 0; color: #191c32; font-weight: bold;"),
              tags$p(
                tags$strong("Top N:"), " Selects the N best peptides ranked by a combined score of p-value and AUC. This method ensures you get the most statistically significant and discriminatory biomarkers.",
                style = "margin-bottom: 10px; color: #191c32;"
              ),
              tags$p(
                tags$strong("AUC Threshold:"), " Selects all peptides with an Area Under the Curve (AUC) above the specified threshold. AUC measures the classifier's ability to distinguish between classes, where 0.5 = random and 1.0 = perfect classification.",
                style = "margin-bottom: 0; color: #191c32;"
              )
            )
          )
        ),
        fluidRow(
          column(
            6,
            tags$h4("Selection Method", style = "color: #191c32; margin-bottom: 20px; font-weight: bold;"),
            radioButtons(
              "ml_selection_method", 
              dark_label("Select peptides by:"),
              choices = c("Top N (best p-value & AUC)" = "top_n", "AUC Threshold" = "auc_threshold"),
              selected = "top_n"
            ),
            conditionalPanel(
              condition = "input.ml_selection_method == 'top_n'",
              numericInput("ml_top_n", dark_label("Number of peptides:"), value = 20, min = 1, max = 100, step = 1)
            ),
            conditionalPanel(
              condition = "input.ml_selection_method == 'auc_threshold'",
              sliderInput("ml_auc_threshold", dark_label("Minimum AUC:"), min = 0.5, max = 1, value = 0.7, step = 0.05)
            ),
            tags$hr(style = "margin: 30px 0 20px 0;"),
            actionButton("ml_select_peptides", "Apply Selection", class = "btn-info", style = "width: 100%; margin-bottom: 10px;"),
            actionButton("ml_send_to_tab", "Send to Machine Learning →", class = "btn-primary", style = "width: 100%;")
          ),
          column(
            6,
            tags$div(
              style = "background: white; border-radius: 8px; padding: 20px; min-height: 300px; display: flex; align-items: center; justify-content: center;",
              uiOutput("ml_selection_summary")
            )
          )
        )
      )
    )  # Close ml-content div
  )
)    # Close tabPanel
}      # Close function
