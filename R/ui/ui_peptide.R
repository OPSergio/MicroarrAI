# ============================================================================
# MicroarrAI - Peptide Finder Tab UI
# ============================================================================
# Description: Statistical analysis and peptide selection interface
# Dependencies: ui_helpers.R
# ============================================================================

ui_peptide <- function() {
  tabPanel(
    title = "Peptide finder",
    
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
    
    # KPI Boxes - flotando sin background container
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
          6,
          tags$h4("Positive Peptides by Isotype", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
          plotly::plotlyOutput("isotype_donut", height = "300px"),
          tags$br(),
          tags$h4("Isotype Summary Statistics", style = "color: #191c32; margin-bottom: 15px; margin-top: 20px; font-weight: bold;"),
          DT::dataTableOutput("isotype_table")
        ),
        column(
          6,
          tags$h4("Expression Distribution by Isotype", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
          plotly::plotlyOutput("expression_dist_plot", height = "300px"),
          tags$br(),
          tags$h4("Top Samples by Positive Peptides", style = "color: #191c32; margin-bottom: 15px; margin-top: 20px; font-weight: bold;"),
          DT::dataTableOutput("top_samples_table", height = "300px")
        )
      )
    ),
    
    # ===== Loading Overlay =====
    loading_overlay(id = "loader", gif_src = "assets/Carga.gif"),
    
    # ===== 3. SELECTION OF CANDIDATE PEPTIDES =====
    section_title("SELECTION OF CANDIDATE PEPTIDES", size = "2.5em"),
    
    card_container_highlighted(
      style = "margin: 0 15px; padding: 25px;",
      fluidRow(
        column(
          12,
          p("Linear Models (LM) are used as the primary method for differential expression analysis. You can optionally add contrast tests (ANOVA/t-test or Kruskal-Wallis/Wilcoxon) for comparison.",
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
          3,
          checkboxInput(
            inputId = "add_contrast_test",
            label = "Add contrast test",
            value = FALSE
          ),
          conditionalPanel(
            condition = "input.add_contrast_test == true",
            radioButtons(
              inputId = "contrast_method",
              label = dark_label("Contrast Test:"),
              choices = c("ANOVA/t-test" = "anova",
                         "Kruskal-Wallis/Wilcoxon" = "kruskal"),
              selected = "anova"
            )
          )
        ),
        column(
          3,
          centered_content(
            height = "80%",
            actionButton(
              inputId = "run_analysis_1",
              label = "Run Analysis",
              class = "btn-primary",
              style = "width: 100%; margin-top: 25px;"
            )
          )
        )
      )
    ),
    
    # ===== 4. DEG (DIFFERENTIAL EXPRESSION) =====
    tags$div(
      id = "stats_div",
      style = "display: none;",
      section_title("DIFFERENTIAL EXPRESSION GENES (DEG)", size = "2.5em"),
      card_container_highlighted(
        style = "margin: 0 15px; padding: 25px;",
        fluidRow(
          column(
            4,
            sliderInput(
              inputId = "pval_threshold",
              label = dark_label("Adjusted p-value threshold:"),
              min = 0, max = 0.1, value = 0.05, step = 0.01
            ),
            withSpinner(DT::dataTableOutput("stats_table"))
          ),
          column(
            8,
            uiOutput("stats_var_plot"),
            withSpinner(plotly::plotlyOutput("stats_plot"))
          )
        )
      )
    ),
    
    # ===== 5. FEATURE LEVEL (ROC & REGRESSION) =====
    tags$div(
      id = "feature_level_div",
      style = "display: none;",
      section_title("FEATURE LEVEL ANALYSIS", size = "2.5em"),
      card_container_highlighted(
        style = "margin: 0 15px; padding: 25px;",
        fluidRow(
          column(6, withSpinner(DT::dataTableOutput("reg_table")), align = "center"),
          column(6, withSpinner(plotOutput("rocs_plot")))
        )
      )
    ),
    
    # ===== VOLCANO PLOT =====
    tags$div(
      id = "volcano_div",
      section_title("VOLCANO PLOT", size = "2.5em"),
      style = "display: none;",
      card_container_highlighted(
        style = "margin: 0 15px; padding: 25px;",
        fluidRow(
          column(
            3,
            h4("Volcano (DE)", style = "color: #191c32; margin-bottom: 15px;"),
            checkboxGroupInput(
              "volcano_isotypes", "Isotypes",
              choices = c("IgE", "IgG4"),
              selected = c("IgE", "IgG4")
            ),
            checkboxInput("volcano_facet_isotype", "Facet por isotipo", value = TRUE),
            uiOutput("volcano_group_var_ui"),
            uiOutput("volcano_level_a_ui"),
            uiOutput("volcano_level_b_ui"),
            sliderInput("volcano_lfc_thr", "Umbral |log2FC|", min = 0, max = 3, value = 1, step = 0.1),
            sliderInput("volcano_padj_thr", "Umbral FDR (BH)", min = 0, max = 0.2, value = 0.05, step = 0.005),
            checkboxInput("volcano_interactive", "Gráfico interactivo (plotly)", value = TRUE),
            downloadButton("download_volcano_tbl", "Descargar resultados (.csv)")
          ),
          column(
            9,
            uiOutput("volcano_plot_container"),
            br(),
            DT::DTOutput("volcano_hits_table")
          )
        )
      )
    ),
    
    # ===== 6. RESULTS OF THE ANALYSIS =====
    tags$div(
      id = "results_summary_div",
      style = "display: none;",
      section_title("RESULTS OF THE ANALYSIS", size = "2.5em"),
      card_container(
        style = "padding: 25px; margin: 0 15px; background: transparent;",
        fluidRow(
          column(12, uiOutput("results_kpi_boxes"))
        ),
        tags$hr(style = "margin: 20px 0; border-color: rgba(255,255,255,0.1);"),
        fluidRow(
          column(
            6,
            tags$h4("Selection Process Overview", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
            plotly::plotlyOutput("results_donut", height = "350px")
          ),
          column(
            6,
            tags$h4("Analysis Summary", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
            uiOutput("results_summary_text")
          )
        )
      )
    ),
    
    # ===== 7. BIOMARKER SELECTION FOR ML =====
    tags$div(
      id = "funnel_div",
      style = "display: none;",
      section_title("BIOMARKER SELECTION FOR MACHINE LEARNING", size = "2.5em"),
      card_container_highlighted(
        style = "margin: 0 15px; padding: 25px;",
        fluidRow(
          column(
            4,
            tags$h4("Selection Method", style = "color: #191c32; margin-bottom: 20px; font-weight: bold;"),
            radioButtons(
              "ml_selection_method", 
              "Select peptides by:",
              choices = c("Top N (best p-value & AUC)" = "top_n", "AUC Threshold" = "auc_threshold"),
              selected = "top_n"
            ),
            conditionalPanel(
              condition = "input.ml_selection_method == 'top_n'",
              numericInput("ml_top_n", "Number of peptides:", value = 20, min = 1, max = 100, step = 1)
            ),
            conditionalPanel(
              condition = "input.ml_selection_method == 'auc_threshold'",
              sliderInput("ml_auc_threshold", "Minimum AUC:", min = 0.5, max = 1, value = 0.7, step = 0.05)
            ),
            tags$hr(style = "margin: 20px 0;"),
            actionButton("ml_select_peptides", "Apply Selection", class = "btn-info", style = "width: 100%; margin-bottom: 10px;"),
            actionButton("ml_send_to_tab", "Send to Machine Learning →", class = "btn-primary", style = "width: 100%;")
          ),
          column(
            8,
            tags$h4("Selected Biomarkers", style = "color: #191c32; margin-bottom: 15px; font-weight: bold;"),
            selectizeInput(
              "ml_selected_peptides",
              label = NULL,
              choices = NULL, 
              multiple = TRUE,
              options = list(placeholder = "No peptides selected yet")
            ),
            DT::DTOutput("ml_selection_table")
          )
        )
      )
    )
  )
}
