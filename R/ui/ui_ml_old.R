# ============================================================================
# MicroarrAI - Machine Learning UI Module (REFACTORED)
# ============================================================================
# Description: Professional ML analysis configurator with launcher menu
# Author: Sergio Olmos Piñero
# ============================================================================

#' Machine Learning Tab UI - Complete Refactor
#' 
#' Professional launcher-style interface with configuration menu
#' 
#' @return tabPanel for Machine Learning
ui_ml <- function() {
  tabPanel(
    title = "Machine Learning",
    
    tabsetPanel(
      id = "ml_subtabs",
      
      # ===== CONFIGURATION TAB =====
      tabPanel(
        title = "Configuration",
        
        tags$div(
          style = "margin-top: 20px;",
          
          # Main Title
          section_title("MACHINE LEARNING PIPELINE CONFIGURATOR", size = "2.5em"),
      
          # Configuration Container
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
                  tags$small("Visual clustering with dendrograms and annotations", style = "color: #666;")
                ),
                value = TRUE
              ),
              
              # PCA
              checkboxInput("ml_use_pca", 
                tags$span(
                  tags$strong("PCA (Principal Component Analysis)"),
                  tags$br(),
                  tags$small("Linear dimensionality reduction, variance-based", style = "color: #666;")
                ),
                value = TRUE
              ),
              
              # PCoA
              checkboxInput("ml_use_pcoa", 
                tags$span(
                  tags$strong("PCoA (Principal Coordinates Analysis)"),
                  tags$br(),
                  tags$small("Distance-based ordination for complex relationships", style = "color: #666;")
                ),
                value = TRUE
              ),
              
              # NMDS
              checkboxInput("ml_use_nmds", 
                tags$span(
                  tags$strong("NMDS (Non-metric Multidimensional Scaling)"),
                  tags$br(),
                  tags$small("Non-linear ordination preserving rank distances", style = "color: #666;")
                ),
                value = TRUE
              ),
              
              # DBSCAN
              checkboxInput("ml_use_dbscan", 
                tags$span(
                  tags$strong("DBSCAN (Density-Based Clustering)"),
                  tags$br(),
                  tags$small("Detects clusters of arbitrary shape and outliers", style = "color: #666;")
                ),
                value = FALSE
              ),
              
              # PLS-DA
              checkboxInput("ml_use_plsda", 
                tags$span(
                  tags$strong("PLS-DA (Partial Least Squares-Discriminant Analysis)"),
                  tags$br(),
                  tags$small("Supervised dimensionality reduction for classification", style = "color: #666;")
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
              
              # Tip Box
              tags$div(
                style = "background: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; margin-bottom: 20px; border-radius: 4px;",
                tags$div(
                  style = "display: flex; align-items: center;",
                  icon("lightbulb", style = "color: #ffc107; margin-right: 8px; font-size: 16px;"),
                  tags$strong("Selection Strategy", style = "color: #856404; font-size: 13px;")
                ),
                tags$p(
                  "The more models you select, the more restrictive the biomarker search becomes. Only features consistently important across all selected models will be identified as top biomarkers.",
                  style = "color: #856404; font-size: 12px; margin: 8px 0 0 0; line-height: 1.5;"
                )
              ),
              
              # C5.0
              checkboxInput("ml_use_c50", 
                tags$span(
                  tags$strong("C5.0 Decision Tree"),
                  tags$br(),
                  tags$small("Fast, interpretable tree-based classifier", style = "color: #666;")
                ),
                value = TRUE
              ),
              
              # Random Forest
              checkboxInput("ml_use_rf", 
                tags$span(
                  tags$strong("Random Forest"),
                  tags$br(),
                  tags$small("Ensemble of trees, robust to overfitting", style = "color: #666;")
                ),
                value = TRUE
              ),
              
              # SVM
              checkboxInput("ml_use_svm", 
                tags$span(
                  tags$strong("SVM (Support Vector Machine)"),
                  tags$br(),
                  tags$small("Maximum-margin classifier with RFE", style = "color: #666;")
                ),
                value = TRUE
              ),
              
              # XGBoost
              checkboxInput("ml_use_xgboost", 
                tags$span(
                  tags$strong("XGBoost (Extreme Gradient Boosting)"),
                  tags$br(),
                  tags$small("State-of-the-art gradient boosting with SHAP values", style = "color: #666;")
                ),
                value = TRUE
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
    )
  ),
  
  # ===== UNSUPERVISED RESULTS TAB =====
  tabPanel(
    title = "Unsupervised Learning",
    
    tags$div(
      id = "ml_unsupervised_section",
      style = "margin-top: 20px;",
      
      # Heatmap Section
      tags$div(
        id = "ml_heatmap_section",
        style = "display: none;",
        section_title("HIERARCHICAL CLUSTERING HEATMAP", size = "2.5em"),
        card_container(
          style = "margin: 0 15px; padding: 25px;",
          shinycssloaders::withSpinner(
            plotOutput("Combined_hplot", height = "600px")
          )
        ),
        tags$hr(style = "margin: 40px 0;")
      ),
      
      # Distance method selector
      tags$div(
        id = "ml_ordination_section",
        style = "display: none;",
        fluidRow(
          column(12,
            card_container(
              style = "margin: 0 15px; padding: 20px;",
              selectInput("distance_method", 
                label = dark_label("Distance Method for Ordination:"),
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
        tags$br()
      ),
      
      # PCA Section
      tags$div(
        id = "ml_pca_results",
        style = "display: none;",
        fluidRow(
          column(12,
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
          )
        )
      ),
      
      # PCoA Section
      tags$div(
        id = "ml_pcoa_results",
        style = "display: none;",
        fluidRow(
          column(12,
            section_title("Principal Coordinates Analysis (PCoA)", size = "2em"),
            card_container(
              style = "margin: 0 15px; padding: 25px;",
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
          )
        )
      ),
      
      # NMDS Section
      tags$div(
        id = "ml_nmds_results",
        style = "display: none;",
        fluidRow(
          column(12,
            section_title("Non-metric Multidimensional Scaling (NMDS)", size = "2em"),
            card_container(
              style = "margin: 0 15px; padding: 25px;",
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
          )
        )
      ),
      
      # DBSCAN Section
      tags$div(
        id = "ml_dbscan_results",
        style = "display: none;",
        fluidRow(
          column(12,
            section_title("DBSCAN Clustering", size = "2em"),
            card_container(
              style = "margin: 0 15px; padding: 25px;",
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
          )
        )
      ),
      
      # PLS-DA Section
      tags$div(
        id = "ml_plsda_results",
        style = "display: none;",
        fluidRow(
          column(12,
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
          )
        )
      )
    )
  ),
  
  # ===== SUPERVISED RESULTS TAB =====
  tabPanel(
    title = "Supervised Learning",
    
    tags$div(
      id = "ml_supervised_section",
      style = "margin-top: 20px;",
      
      # C5.0 Section
      tags$div(
        id = "ml_c50_results",
        style = "display: none;",
        fluidRow(
          column(12,
            section_title("C5.0 Decision Tree", size = "2em"),
            card_container(
              style = "margin: 0 15px; padding: 25px;",
              fluidRow(
                column(4,
                  tags$div(
                    tags$h5("Model Description", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                    tags$p("C5.0 creates interpretable decision trees using information gain. Trained with 100 trials on the 30 most important features.", 
                           style = "color: #666; font-size: 13px; line-height: 1.6;")
                  )
                ),
                column(4,
                  shinycssloaders::withSpinner(girafeOutput("c5.plot", height = "350px"))
                ),
                column(4,
                  shinycssloaders::withSpinner(girafeOutput("c5.decision", height = "350px"))
                )
              )
            )
          )
        )
      ),
      
      # Random Forest Section
      tags$div(
        id = "ml_rf_results",
        style = "display: none;",
        fluidRow(
          column(12,
            section_title("Random Forest Classifier", size = "2em"),
            card_container(
              style = "margin: 0 15px; padding: 25px;",
              fluidRow(
                column(4,
                  tags$div(
                    tags$h5("Model Description", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                    tags$p("Ensemble of decision trees trained on bootstrap samples. Robust against overfitting and handles high-dimensional data well.", 
                           style = "color: #666; font-size: 13px; line-height: 1.6;")
                  )
                ),
                column(4,
                  shinycssloaders::withSpinner(girafeOutput("rf.plot", height = "400px"))
                ),
                column(4,
                  shinycssloaders::withSpinner(girafeOutput("rf.decision", height = "400px"))
                )
              )
            )
          )
        )
      ),
      
      # SVM Section
      tags$div(
        id = "ml_svm_results",
        style = "display: none;",
        fluidRow(
          column(12,
            section_title("Support Vector Machine (SVM)", size = "2em"),
            card_container(
              style = "margin: 0 15px; padding: 25px;",
              fluidRow(
                column(4,
                  shinycssloaders::withSpinner(plotlyOutput("svm3d.plot", height = "400px"))
                ),
                column(4,
                  shinycssloaders::withSpinner(girafeOutput("svm.plot", height = "400px"))
                ),
                column(4,
                  tags$div(
                    tags$h5("Model Description", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                    tags$p("SVM finds the optimal hyperplane that maximizes the margin between classes. Features selected using Recursive Feature Elimination (RFE).", 
                           style = "color: #666; font-size: 13px; line-height: 1.6;")
                  )
                )
              )
            )
          )
        )
      ),
      
      # XGBoost Section
      tags$div(
        id = "ml_xgboost_results",
        style = "display: none;",
        fluidRow(
          column(12,
            section_title("XGBoost Classifier", size = "2em"),
            card_container(
              style = "margin: 0 15px; padding: 25px;",
              fluidRow(
                column(4,
                  tags$div(
                    tags$h5("Model Description", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                    tags$p("Extreme Gradient Boosting with 100 iterations. Highly efficient for large datasets with complex feature interactions. SHAP values provide interpretability.", 
                           style = "color: #666; font-size: 13px; line-height: 1.6;")
                  )
                ),
                column(4,
                  shinycssloaders::withSpinner(plotOutput("shap_importance_plot", height = "400px"))
                ),
                column(4,
                  shinycssloaders::withSpinner(plotOutput("shap_importance_bee_plot", height = "400px"))
                )
              ),
              tags$hr(style = "margin: 30px 0;"),
              fluidRow(
                column(12,
                  tags$h5("SHAP Waterfall Explanation", style = "color: #191c32; margin-bottom: 15px; font-weight: 600; text-align: center;"),
                  shinycssloaders::withSpinner(plotOutput("shap_waterfall_plot", height = "500px"))
                )
              ),
              tags$hr(style = "margin: 30px 0;"),
              fluidRow(
                column(12,
                  tags$h5("SHAP Force Plot", style = "color: #191c32; margin-bottom: 15px; font-weight: 600; text-align: center;"),
                  shinycssloaders::withSpinner(plotOutput("shap_force_plot", height = "400px"))
                )
              )
            )
          )
        )
      ),
      
      # Variable Selection (Venn Diagram)
      tags$div(
        id = "ml_venn_results",
        style = "display: none;",
        fluidRow(
          column(12,
            section_title("BIOMARKER SELECTION CONSENSUS", size = "2em"),
            card_container(
              style = "margin: 0 15px; padding: 25px;",
              fluidRow(
                column(6,
                  tags$div(
                    style = "padding: 20px;",
                    tags$h4("Variable Selection Process", style = "color: #191c32; margin-bottom: 15px; font-weight: 600;"),
                    tags$p("The Venn diagram shows the overlap of important features identified by each model. Features selected by multiple models are considered more robust biomarkers.", 
                           style = "color: #666; font-size: 14px; line-height: 1.6;")
                  )
                ),
                column(6,
                  shinycssloaders::withSpinner(plotOutput("venn.plot", height = "450px"))
                )
              ),
              tags$hr(style = "margin: 30px 0;"),
              fluidRow(
                column(12,
                  uiOutput("explanation")
                )
              )
            )
          )
        )
      )
    )
  )  # Close tabPanel Supervised Learning
)    # Close tabsetPanel
)    # Close tabPanel Machine Learning
}    # Close ui_ml function
