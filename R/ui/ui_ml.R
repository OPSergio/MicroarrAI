# ============================================================================
# MicroarrAI - Machine Learning UI Module (DASHBOARD VERSION)
# ============================================================================
# Description: ML dashboard with floating sidebar navigation
# Author: Sergio Olmos Piñero
# ============================================================================

#' Machine Learning Tab UI - Dashboard with Floating Sidebar
#' 
#' Professional dashboard interface with configurable sidebar
#' 
#' @return tabPanel for Machine Learning
ui_ml <- function() {
  tabPanel(
    title = "Machine Learning",
    
    # Floating Sidebar
    tags$div(
      id = "ml-sidebar",
      class = "ml-sidebar",
      
      tags$h4(
        icon("brain", style = "margin-right: 10px;"),
        "ML Dashboard"
      ),
      
      # Sidebar Toggle Button
      tags$div(
        id = "ml-sidebar-toggle",
        class = "ml-sidebar-toggle",
        icon("bars")
      ),
      
      # Configuration Section
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "CONFIGURATION"),
        
        tags$div(
          class = "ml-sidebar-item active",
          `data-target` = "ml_config_panel",
          icon("cog", style = "margin-right: 10px;"),
          "Pipeline Setup"
        )
      ),
      
      # Unsupervised Methods
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "UNSUPERVISED"),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_heatmap_section",
          icon("th", style = "margin-right: 10px;"),
          "Heatmap"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_pca_results",
          icon("chart-scatter", style = "margin-right: 10px;"),
          "PCA"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_pcoa_results",
          icon("chart-scatter", style = "margin-right: 10px;"),
          "PCoA"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_nmds_results",
          icon("chart-scatter", style = "margin-right: 10px;"),
          "NMDS"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_dbscan_results",
          icon("project-diagram", style = "margin-right: 10px;"),
          "DBSCAN"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_plsda_results",
          icon("project-diagram", style = "margin-right: 10px;"),
          "PLS-DA"
        )
      ),
      
      # Supervised Methods
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "SUPERVISED"),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_c50_results",
          icon("tree", style = "margin-right: 10px;"),
          "C5.0"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_rf_results",
          icon("tree", style = "margin-right: 10px;"),
          "Random Forest"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_svm_results",
          icon("vector-square", style = "margin-right: 10px;"),
          "SVM"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_xgboost_results",
          icon("rocket", style = "margin-right: 10px;"),
          "XGBoost"
        )
      ),
      
      # Results Section
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "RESULTS"),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "ml_venn_results",
          icon("circle-notch", style = "margin-right: 10px;"),
          "Biomarker Consensus"
        )
      )
    ),
    
    # Main Content Area
    tags$div(
      id = "ml-content",
      class = "ml-content",
      
      # ===== CONFIGURATION PANEL =====
      tags$div(
        id = "ml_config_panel",
        style = "margin-top: 20px;",
        
        section_title("MACHINE LEARNING PIPELINE CONFIGURATOR", size = "2.5em"),
        
        card_container_highlighted(
          style = "margin: 0 15px; padding: 30px;",
          
          # Info Banner
          tags$div(
            style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; padding: 20px; margin-bottom: 30px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);",
            tags$h4("Configure Your Analysis Pipeline", style = "color: white; margin: 0 0 10px 0; font-weight: 600;"),
            tags$p(
              style = "color: rgba(255,255,255,0.95); margin: 0; font-size: 14px; line-height: 1.6;",
              "Select methods to apply to your biomarker data. Only peptides selected in the Peptide tab will be used for analysis."
            )
          ),
          
          # Target Variable Selection
          fluidRow(
            column(3,
              tags$div(
                style = "background: white; border-radius: 8px; padding: 20px; margin-bottom: 25px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);",
                tags$div(
                  style = "display: flex; align-items: center; margin-bottom: 15px;",
                  icon("bullseye", style = "font-size: 20px; color: #667eea; margin-right: 10px;"),
                  tags$h5("Target Variable", style = "color: #191c32; margin: 0; font-weight: 600;")
                ),
                uiOutput("ml_target_selector"),
                tags$small(
                  "Clinical variable for predictions or grouping.",
                  style = "color: #666; font-size: 12px;"
                )
              )
            ),
            column(9,
              tags$div(
                style = "background: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; border-radius: 4px;",
                tags$div(
                  style = "display: flex; align-items: center;",
                  icon("info-circle", style = "color: #2196F3; margin-right: 8px; font-size: 16px;"),
                  tags$strong("Biomarker Filtering", style = "color: #0d47a1; font-size: 14px;")
                ),
                tags$p(
                  "This analysis will use ONLY the peptides you selected in the Peptide tab. If no selection has been made, all peptides will be used.",
                  style = "color: #0d47a1; font-size: 13px; margin: 8px 0 0 0; line-height: 1.5;"
                )
              )
            )
          ),
          
          # Method Selection Grid
          fluidRow(
            # Unsupervised Methods
            column(6,
              tags$div(
                style = "background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); height: 100%;",
                tags$div(
                  style = "display: flex; align-items: center; margin-bottom: 15px; padding-bottom: 15px; border-bottom: 2px solid #667eea;",
                  icon("project-diagram", style = "font-size: 20px; color: #667eea; margin-right: 10px;"),
                  tags$h5("Unsupervised Learning", style = "color: #191c32; margin: 0; font-weight: 600;")
                ),
                tags$p(
                  "Explore data structure and identify natural groupings without labels.",
                  style = "color: #666; font-size: 13px; margin-bottom: 20px;"
                ),
                
                # Heatmap
                checkboxInput("ml_use_heatmap", 
                  tags$span(
                    tags$strong("Hierarchical Clustering Heatmap"),
                    tags$br(),
                    tags$small("Visual clustering with dendrograms", style = "color: #666;")
                  ),
                  value = TRUE
                ),
                
                # PCA
                checkboxInput("ml_use_pca", 
                  tags$span(
                    tags$strong("PCA (Principal Component Analysis)"),
                    tags$br(),
                    tags$small("Linear dimensionality reduction", style = "color: #666;")
                  ),
                  value = TRUE
                ),
                
                # PCoA
                checkboxInput("ml_use_pcoa", 
                  tags$span(
                    tags$strong("PCoA (Principal Coordinates Analysis)"),
                    tags$br(),
                    tags$small("Distance-based ordination", style = "color: #666;")
                  ),
                  value = TRUE
                ),
                
                # NMDS
                checkboxInput("ml_use_nmds", 
                  tags$span(
                    tags$strong("NMDS (Non-metric MDS)"),
                    tags$br(),
                    tags$small("Non-linear ordination", style = "color: #666;")
                  ),
                  value = TRUE
                ),
                
                # DBSCAN
                checkboxInput("ml_use_dbscan", 
                  tags$span(
                    tags$strong("DBSCAN Clustering"),
                    tags$br(),
                    tags$small("Density-based clustering", style = "color: #666;")
                  ),
                  value = FALSE
                ),
                
                # PLS-DA
                checkboxInput("ml_use_plsda", 
                  tags$span(
                    tags$strong("PLS-DA"),
                    tags$br(),
                    tags$small("Supervised dimensionality reduction", style = "color: #666;")
                  ),
                  value = FALSE
                )
              )
            ),
            
            # Supervised Methods
            column(6,
              tags$div(
                style = "background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); height: 100%;",
                tags$div(
                  style = "display: flex; align-items: center; margin-bottom: 15px; padding-bottom: 15px; border-bottom: 2px solid #667eea;",
                  icon("brain", style = "font-size: 20px; color: #667eea; margin-right: 10px;"),
                  tags$h5("Supervised Learning", style = "color: #191c32; margin: 0; font-weight: 600;")
                ),
                tags$p(
                  "Train predictive models using labeled data to classify samples.",
                  style = "color: #666; font-size: 13px; margin-bottom: 20px;"
                ),
                
                # Model Selection
                checkboxInput("ml_use_c50", 
                  tags$span(
                    tags$strong("C5.0 Decision Tree"),
                    tags$br(),
                    tags$small("Fast, interpretable classifier", style = "color: #666;")
                  ),
                  value = TRUE
                ),
                
                checkboxInput("ml_use_rf", 
                  tags$span(
                    tags$strong("Random Forest"),
                    tags$br(),
                    tags$small("Ensemble of trees", style = "color: #666;")
                  ),
                  value = TRUE
                ),
                
                checkboxInput("ml_use_svm", 
                  tags$span(
                    tags$strong("SVM (Support Vector Machine)"),
                    tags$br(),
                    tags$small("Maximum-margin classifier", style = "color: #666;")
                  ),
                  value = TRUE
                ),
                
                checkboxInput("ml_use_xgboost", 
                  tags$span(
                    tags$strong("XGBoost"),
                    tags$br(),
                    tags$small("Gradient boosting with SHAP", style = "color: #666;")
                  ),
                  value = TRUE
                ),
                
                tags$hr(style = "margin: 20px 0;"),
                
                # Advanced Options Section
                tags$div(
                  style = "background: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; margin-bottom: 15px; border-radius: 4px;",
                  tags$div(
                    style = "display: flex; align-items: center; margin-bottom: 10px;",
                    icon("sliders-h", style = "color: #ffc107; margin-right: 8px; font-size: 16px;"),
                    tags$strong("Advanced Options", style = "color: #856404; font-size: 13px;")
                  ),
                  
                  # RFE Option
                  checkboxInput("ml_use_rfe", 
                    tags$span(
                      tags$strong("Recursive Feature Elimination (RFE)", style = "font-size: 13px;"),
                      tags$br(),
                      tags$small("Iteratively remove less important features", style = "color: #666; font-size: 11px;")
                    ),
                    value = FALSE
                  ),
                  
                  # CV Option
                  checkboxInput("ml_use_cv", 
                    tags$span(
                      tags$strong("Cross-Validation (CV)", style = "font-size: 13px;"),
                      tags$br(),
                      tags$small("Evaluate model performance with k-fold CV", style = "color: #666; font-size: 11px;")
                    ),
                    value = TRUE
                  ),
                  
                  # Hyperparameter Tuning
                  checkboxInput("ml_use_tuning", 
                    tags$span(
                      tags$strong("Hyperparameter Tuning", style = "font-size: 13px;"),
                      tags$br(),
                      tags$small("Optimize model parameters (slower)", style = "color: #666; font-size: 11px;")
                    ),
                    value = FALSE
                  )
                )
              )
            )
          ),
          
          # Launch Button
          fluidRow(
            column(12,
              tags$div(
                style = "margin-top: 30px; text-align: center;",
                actionButton(
                  "ml_run_pipeline",
                  tags$span(
                    icon("play-circle", style = "margin-right: 8px;"),
                    "Run ML Pipeline"
                  ),
                  class = "btn-primary",
                  style = "font-size: 18px; padding: 15px 40px; font-weight: 600; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);"
                ),
                tags$p(
                  "Click to start the analysis with your selected configuration",
                  style = "color: #666; font-size: 13px; margin-top: 10px;"
                )
              )
            )
          )
        )
      ),
      
      # ===== UNSUPERVISED RESULTS =====
      
      # Heatmap Section
      tags$div(
        id = "ml_heatmap_section",
        style = "display: none; margin-top: 20px;",
        section_title("HIERARCHICAL CLUSTERING HEATMAP", size = "2.5em"),
        card_container(
          style = "margin: 0 15px; padding: 25px;",
          
          # Explanation
          fluidRow(
            column(12,
              tags$div(
                style = "background: #f0f0f0; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #667eea;",
                tags$h5("About Hierarchical Clustering", style = "color: #191c32; margin-top: 0; font-weight: 600;"),
                tags$p(
                  "Hierarchical clustering groups similar samples and features based on their expression patterns. The dendrogram (tree structure) shows relationships between samples, with shorter branches indicating higher similarity. This visualization helps identify sample clusters and outliers.",
                  style = "color: #666; margin-bottom: 0; line-height: 1.6;"
                )
              )
            )
          ),
          
          shinycssloaders::withSpinner(
            plotOutput("Combined_hplot", height = "600px")
          )
        )
      ),
      
      # PCA Section
      tags$div(
        id = "ml_pca_results",
        style = "display: none; margin-top: 20px;",
        section_title("Principal Component Analysis (PCA)", size = "2em"),
        card_container(
          style = "margin: 0 15px; padding: 25px;",
          fluidRow(
            column(6,
              tags$div(
                tags$h5("2D Projection", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                tags$p("PCA reduces dimensionality by projecting data onto principal components that capture maximum variance.", 
                       style = "color: #666; font-size: 13px; margin-bottom: 15px;"),
                shinycssloaders::withSpinner(girafeOutput("PCA_2d", height = "450px"))
              )
            ),
            column(6,
              tags$div(
                tags$h5("3D Interactive Visualization", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                actionButton("toggle_surface_PCA", "Toggle Surface Type", style = "margin-bottom: 10px;"),
                actionButton("toggle_ellipsoid_PCA", "Toggle Ellipsoid", style = "margin-bottom: 10px;"),
                br(),
                verbatimTextOutput("current_params_PCA"),
                shinycssloaders::withSpinner(rglwidgetOutput("d3_PCA", height = "500px"))
              )
            )
          )
        )
      ),
      
      # PCoA Section
      tags$div(
        id = "ml_pcoa_results",
        style = "display: none; margin-top: 20px;",
        section_title("Principal Coordinates Analysis (PCoA)", size = "2em"),
        card_container(
          style = "margin: 0 15px; padding: 25px;",
          
          # Distance method selector for PCoA
          fluidRow(
            column(12,
              tags$div(
                style = "background: #f0f0f0; padding: 15px; border-radius: 8px; margin-bottom: 20px;",
                selectInput("pcoa_distance_method", 
                  label = dark_label("Distance Method:"),
                  choices = c("Euclidean" = "euclidean", 
                             "Manhattan" = "manhattan", 
                             "Canberra" = "canberra", 
                             "Bray-Curtis" = "bray"),
                  selected = "euclidean",
                  width = "300px"
                )
              )
            )
          ),
          
          fluidRow(
            column(6,
              tags$div(
                tags$h5("2D Ordination", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                tags$p("PCoA visualizes sample relationships based on a distance matrix, preserving inter-sample distances.", 
                       style = "color: #666; font-size: 13px; margin-bottom: 15px;"),
                shinycssloaders::withSpinner(girafeOutput("PCoA_2d", height = "450px"))
              )
            ),
            column(6,
              tags$div(
                tags$h5("3D Interactive Visualization", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                actionButton("toggle_surface_PCOA", "Toggle Surface Type", style = "margin-bottom: 10px;"),
                actionButton("toggle_ellipsoid_PCOA", "Toggle Ellipsoid", style = "margin-bottom: 10px;"),
                br(),
                verbatimTextOutput("current_params_PCOA"),
                shinycssloaders::withSpinner(rglwidgetOutput("PCoA_3d", height = "500px"))
              )
            )
          )
        )
      ),
      
      # NMDS Section
      tags$div(
        id = "ml_nmds_results",
        style = "display: none; margin-top: 20px;",
        section_title("Non-metric Multidimensional Scaling (NMDS)", size = "2em"),
        card_container(
          style = "margin: 0 15px; padding: 25px;",
          
          # Distance method selector for NMDS
          fluidRow(
            column(12,
              tags$div(
                style = "background: #f0f0f0; padding: 15px; border-radius: 8px; margin-bottom: 20px;",
                selectInput("nmds_distance_method", 
                  label = dark_label("Distance Method:"),
                  choices = c("Euclidean" = "euclidean", 
                             "Manhattan" = "manhattan", 
                             "Canberra" = "canberra", 
                             "Bray-Curtis" = "bray"),
                  selected = "euclidean",
                  width = "300px"
                )
              )
            )
          ),
          
          fluidRow(
            column(6,
              tags$div(
                tags$h5("2D Ordination", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                tags$p("NMDS preserves rank-order distances between samples using a non-linear approach. Lower stress values indicate better fit.", 
                       style = "color: #666; font-size: 13px; margin-bottom: 15px;"),
                shinycssloaders::withSpinner(girafeOutput("NMDS_2d", height = "450px"))
              )
            ),
            column(6,
              tags$div(
                tags$h5("3D Interactive Visualization", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                actionButton("toggle_surface_NMDS", "Toggle Surface Type", style = "margin-bottom: 10px;"),
                actionButton("toggle_ellipsoid_NMDS", "Toggle Ellipsoid", style = "margin-bottom: 10px;"),
                br(),
                verbatimTextOutput("current_params_NMDS"),
                shinycssloaders::withSpinner(rglwidgetOutput("NMDS_3d", height = "500px"))
              )
            )
          )
        )
      ),
      
      # DBSCAN Section
      tags$div(
        id = "ml_dbscan_results",
        style = "display: none; margin-top: 20px;",
        section_title("DBSCAN Clustering", size = "2em"),
        card_container(
          style = "margin: 0 15px; padding: 25px;",
          
          # DBSCAN Parameters
          fluidRow(
            column(12,
              tags$div(
                style = "background: #f0f0f0; padding: 15px; border-radius: 8px; margin-bottom: 20px;",
                tags$h5("Clustering Parameters", style = "color: #191c32; margin-bottom: 10px;"),
                fluidRow(
                  column(6,
                    sliderInput("dbscan_eps", 
                      label = dark_label("Epsilon (eps) - Maximum distance:"),
                      min = 0.1, max = 5, value = 2.0, step = 0.1
                    ),
                    tags$small("Maximum distance between two samples to be considered neighbors", 
                               style = "color: #666;")
                  ),
                  column(6,
                    sliderInput("dbscan_minpts", 
                      label = dark_label("Minimum Points (minPts):"),
                      min = 2, max = 20, value = 5, step = 1
                    ),
                    tags$small("Minimum number of samples in a neighborhood to form a cluster", 
                               style = "color: #666;")
                  )
                )
              )
            )
          ),
          
          fluidRow(
            column(6,
              tags$div(
                tags$h5("Cluster Visualization", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                tags$p("DBSCAN identifies dense regions as clusters and marks sparse points as outliers (noise).", 
                       style = "color: #666; font-size: 13px; margin-bottom: 15px;"),
                shinycssloaders::withSpinner(girafeOutput("dbscan_plot", height = "450px"))
              )
            ),
            column(6,
              tags$div(
                tags$h5("Performance Metrics", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                uiOutput("dbscan_metrics")
              )
            )
          )
        )
      ),
      
      # PLS-DA Section
      tags$div(
        id = "ml_plsda_results",
        style = "display: none; margin-top: 20px;",
        section_title("PLS-DA Analysis", size = "2em"),
        card_container(
          style = "margin: 0 15px; padding: 25px;",
          fluidRow(
            column(6,
              tags$div(
                tags$h5("Score Plot", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                tags$p("PLS-DA maximizes separation between groups by finding latent variables that best discriminate classes.", 
                       style = "color: #666; font-size: 13px; margin-bottom: 15px;"),
                shinycssloaders::withSpinner(girafeOutput("plsda_score_plot", height = "450px"))
              )
            ),
            column(6,
              tags$div(
                tags$h5("Model Performance", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                uiOutput("plsda_metrics"),
                tags$hr(),
                tags$h5("Variable Importance (VIP)", style = "color: #191c32; margin-top: 20px; margin-bottom: 15px; font-weight: 600;"),
                shinycssloaders::withSpinner(plotOutput("plsda_vip_plot", height = "300px"))
              )
            )
          )
        )
      ),
      
      # ===== SUPERVISED RESULTS =====
      
      # C5.0 Section
      tags$div(
        id = "ml_c50_results",
        style = "margin-top: 20px;",
        section_title("C5.0 Decision Tree", size = "2em"),
        uiOutput("c50_panel_content")
      ),
      
      # Random Forest Section
      tags$div(
        id = "ml_rf_results",
        style = "margin-top: 20px;",
        section_title("Random Forest Classifier", size = "2em"),
        uiOutput("rf_panel_content")
      ),
      
      # SVM Section
      tags$div(
        id = "ml_svm_results",
        style = "margin-top: 20px;",
        section_title("Support Vector Machine (SVM)", size = "2em"),
        uiOutput("svm_panel_content")
      ),
      
      # XGBoost Section
      tags$div(
        id = "ml_xgboost_results",
        style = "margin-top: 20px;",
        section_title("XGBoost Classifier", size = "2em"),
        uiOutput("xgboost_panel_content")
      ),
      
      # Biomarker Consensus Section
      tags$div(
        id = "ml_venn_results",
        style = "display: none; margin-top: 20px;",
        section_title("BIOMARKER SELECTION CONSENSUS", size = "2em"),
        card_container(
          style = "margin: 0 15px; padding: 25px;",
          
          # Explanation header
          tags$div(
            style = "background: linear-gradient(135deg, #3498db 0%, #2980b9 100%); border-radius: 12px; padding: 20px; margin-bottom: 25px; box-shadow: 0 4px 15px rgba(52, 152, 219, 0.3);",
            tags$h4(
              style = "color: white; margin: 0 0 10px 0; font-weight: 600;",
              icon("project-diagram", style = "margin-right: 10px;"),
              "Multi-Model Consensus Approach"
            ),
            tags$p(
              style = "color: rgba(255,255,255,0.95); margin: 0; font-size: 14px; line-height: 1.6;",
              "Features are ranked by importance within each model independently. The Venn diagram visualizes overlap between models. ",
              strong("Biomarkers identified by multiple models"), 
              " are considered more robust and reliable, as they demonstrate consistent importance across different algorithmic approaches."
            )
          ),
          
          # Venn diagram and feature list
          fluidRow(
            column(7,
              tags$h5("Feature Overlap Visualization", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
              shinycssloaders::withSpinner(plotOutput("venn.plot", height = "450px"))
            ),
            column(5,
              tags$div(
                style = "background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
                tags$h6("Display Options", style = "color: #191c32; margin-bottom: 10px; font-weight: 600;"),
                sliderInput("consensus_top_n", "Top N features per model:",
                           min = 5, max = 50, value = 20, step = 5)
              ),
              tags$h5("Consensus Biomarkers", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
              tags$p(
                style = "font-size: 13px; color: #666; margin-bottom: 15px;",
                "Features identified by 2 or more models:"
              ),
              uiOutput("consensus_biomarkers_list")
            )
          )
        )
      )
    ) # Close ml-content
  ) # Close tabPanel
} # Close ui_ml function
