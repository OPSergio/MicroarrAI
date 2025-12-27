# ============================================================================
# MicroarrAI - Machine Learning UI Module
# ============================================================================
# Description: UI for unsupervised and supervised machine learning analysis
# Dependencies: ui_helpers.R
# ============================================================================

#' Machine Learning Tab UI
#' 
#' Complete ML interface with heatmap, unsupervised, and supervised methods
#' 
#' @return tabPanel for Machine Learning
ui_ml <- function() {
  tabPanel(
    title = "Machine Learning",
    
    # Target group selector (filled by server)
    fluidRow(box(uiOutput("target_hgroup"))),
    
    # Annotated Heatmap
    fluidRow(
      column(12, 
        section_title("Heatmap with annotations", size = "2.5em"),
        card_container(
          box(
            width = 12, 
            plotOutput("Combined_hplot", height = "500px")
          )
        )
      )
    ),
    
    # PCA target selector
    fluidRow(box(uiOutput("target_PCA"))),
    
    # Nested tabs: Unsupervised vs Supervised
    fluidRow(
      tabsetPanel(
        # ========== UNSUPERVISED TAB ==========
        ui_ml_unsupervised(),
        
        # ========== SUPERVISED TAB ==========
        ui_ml_supervised()
      )
    )
  )
}


#' Unsupervised Machine Learning Sub-Tab
#' 
#' PCA, PCoA, NMDS with 2D/3D visualizations
#' 
#' @return tabPanel for Unsupervised ML
ui_ml_unsupervised <- function() {
  tabPanel(
    "Unsupervised Machine Learning",
    
    # ===== PCA Section =====
    fluidRow(
      column(12, 
        section_title("Principal Component Analysis (PCA)"),
        card_container(
          fluidRow(
            column(6, 
              info_card(
                "Description",
                p("Principal Component Analysis (PCA) is a dimensionality reduction technique that transforms a set of correlated variables into a new set of uncorrelated variables, called principal components. In PCA, the first components capture most of the variability in the data.", 
                  style = "color: #191c32;"),
                p("This analysis is useful for reducing the complexity of large data sets, allowing easier visualisation and identification of important patterns. The 2D and 3D representations of the components are shown below.", 
                  style = "color: #191c32;"),
                shinycssloaders::withSpinner(plotOutput("PCA_2d", height = "400px", width = "100%"))
              )
            ),
            column(6,
              tags$div(
                actionButton("toggle_surface_PCA", "Cambiar tipo de superficie"),
                actionButton("toggle_ellipsoid_PCA", "Alternar elipsoide"),
                br(),
                verbatimTextOutput("current_params_PCA")
              ),
              tags$div(
                shinycssloaders::withSpinner(rglwidgetOutput("d3_PCA", height = "600px", width = "600px"))
              )
            )
          )
        )
      )
    ),
    
    # ===== Distance Method Selector =====
    fluidRow(
      column(12,
        selectInput("distance_method", 
          label = dark_label("Choose the Distance Method:"),
          choices = c("euclidean", "manhattan", "canberra", "bray"),
          selected = "euclidean"
        )
      )
    ),
    
    # ===== PCoA Section =====
    fluidRow(
      column(12, 
        section_title("Principal Coordinates Analysis (PCoA)"),
        card_container(
          fluidRow(
            column(6, 
              info_card(
                "Description",
                p("Principal Coordinate Analysis (PCoA) is a dimensionality reduction technique based on a distance matrix. It is used to visualise the relationships between samples in a reduced space while maintaining the relative distances between them.", 
                  style = "color: #191c32;"),
                p("The 2D and 3D representations using selected distance methods are shown below.", 
                  style = "color: #191c32;"),
                shinycssloaders::withSpinner(plotOutput("PCoA_2d", height = "400px", width = "100%"))
              )
            ),
            column(6,
              tags$div(
                actionButton("toggle_surface_PCOA", "Cambiar tipo de superficie"),
                actionButton("toggle_ellipsoid_PCOA", "Alternar elipsoide"),
                br(),
                verbatimTextOutput("current_params_PCOA")
              ),
              tags$div(
                shinycssloaders::withSpinner(rglwidgetOutput("PCoA_3d", height = "600px", width = "600px"))
              )
            )
          )
        )
      )
    ),
    
    # ===== NMDS Section =====
    fluidRow(
      column(12, 
        section_title("Non-metric Multidimensional Scaling (NMDS)"),
        card_container(
          fluidRow(
            column(6, 
              info_card(
                "Description",
                p("Non-Metric Multidimensional Scaling (NMDS) is a non-linear dimensionality reduction technique based on the preservation of distance relationships between samples.", 
                  style = "color: #191c32;"),
                p("NMDS is commonly used to visualise complex relationships in data, such as those found in ecological or gene expression studies.", 
                  style = "color: #191c32;"),
                shinycssloaders::withSpinner(plotOutput("NMDS_2d", height = "400px", width = "100%"))
              )
            ),
            column(6,
              tags$div(
                actionButton("toggle_surface_NMDS", "Cambiar tipo de superficie"),
                actionButton("toggle_ellipsoid_NMDS", "Alternar elipsoide"),
                br(),
                verbatimTextOutput("current_params_NMDS")
              ),
              tags$div(
                shinycssloaders::withSpinner(rglwidgetOutput("NMDS_3d", height = "600px", width = "600px"))
              )
            )
          )
        )
      )
    )
  )
}


#' Supervised Machine Learning Sub-Tab
#' 
#' C5.0, Random Forest, SVM, XGBoost models with visualizations
#' 
#' @return tabPanel for Supervised ML
ui_ml_supervised <- function() {
  tabPanel(
    "Supervised Machine Learning",
    
    # ===== C5.0 Model =====
    fluidRow(section_title("Model C5.0")),
    fluidRow(
      card_container(
        fluidRow(
          column(4, 
            info_card(
              "Description",
              p("The C5.0 algorithm is an improvement of the C4.5 algorithm. It is used for classification by generating a decision tree that divides the data into groups according to the feature offering the highest information gain. It is fast and efficient, handling large amounts of data and variables."),
              p("In this model, we have used 100 trials and selected the 30 most important variables based on feature importance metrics.", 
                style = "color: #191c32;")
            )
          ),
          column(4, 
            shinycssloaders::withSpinner(plotOutput("c5.plot", height = "300px", width = "300px"))
          ),
          column(4, 
            shinycssloaders::withSpinner(plotOutput("c5.decision", height = "300px", width = "300px"))
          )
        )
      )
    ),
    
    # ===== Random Forest =====
    fluidRow(section_title("Random Forest")),
    fluidRow(
      card_container(
        fluidRow(
          column(4,
            info_card(
              "Description",
              p("Random Forest is a supervised learning algorithm based on multiple decision trees. Each tree is trained on a subset of the data, and the final prediction is obtained by taking the average (regression) or the majority vote (classification) of all the trees."),
              p("This model is robust against overfitting and handles well data sets with many characteristics. In this case, we have selected the 30 most important variables to visualise.", 
                style = "color: #191c32;")
            )
          ),
          column(4, 
            shinycssloaders::withSpinner(plotOutput("rf.plot", height = "400px", width = "400px"))
          ),
          column(4, 
            shinycssloaders::withSpinner(plotOutput("rf.decision", height = "400px", width = "400px"))
          )
        )
      )
    ),
    
    # ===== SVM Model =====
    fluidRow(section_title("Supported Vector Machine (SVM)")),
    fluidRow(
      card_container(
        fluidRow(
          column(4, 
            shinycssloaders::withSpinner(plotlyOutput("svm3d.plot", height = "400px", width = "400px"))
          ),
          column(4, 
            shinycssloaders::withSpinner(plotOutput("svm.plot", height = "400px", width = "400px"))
          ),
          column(4, 
            info_card(
              "Description",
              p("SVM is a classification algorithm that seeks to find a hyperplane that optimally partitions the data. It maximises the margin between the closest data points of each class (support vectors). In this case, we use a linear kernel for classification."),
              p("We use Recursive Feature Elimination (RFE) to select the most important variables that aid classification. The two most relevant variables are plotted in the graph below.", 
                style = "color: #191c32;")
            )
          )
        )
      )
    ),
    
    # ===== XGBoost Model =====
    fluidRow(section_title("XGBoost Model")),
    fluidRow(
      card_container(
        # Main row with description + 2 plots
        fluidRow(
          column(4, 
            info_card(
              "Description",
              p("XGBoost (Extreme Gradient Boosting) is a tree-based supervised learning algorithm using boosting. It is extremely efficient for handling large volumes of data and detecting complex relationships between features. In this case, we have used 100 iterations to train the model."),
              p("XGBoost focuses on minimising error through iterative model fitting and is robust against overfitting. We have selected the 30 most important variables based on their Gain information obtained during training.", 
                style = "color: #191c32;")
            )
          ),
          column(4, 
            shinycssloaders::withSpinner(plotOutput("shap_importance_plot", height = "400px", width = "600px"))
          ),
          column(4, 
            shinycssloaders::withSpinner(plotOutput("shap_importance_bee_plot", height = "400px", width = "600px"))
          )
        ),
        
        # Waterfall plot (centered, full width)
        fluidRow(
          column(12, 
            card_container(
              centered_content(
                shinycssloaders::withSpinner(plotOutput("shap_waterfall_plot", height = "500px", width = "900px"))
              )
            )
          )
        ),
        
        # Force plot (centered, full width)
        fluidRow(
          column(12, 
            card_container(
              centered_content(
                shinycssloaders::withSpinner(plotOutput("shap_force_plot", height = "400px", width = "900px"))
              )
            )
          )
        )
      )
    ),
    
    # ===== Variable Selection (Venn Diagram) =====
    fluidRow(
      column(5, 
        tags$div(
          style = "padding: 20px; display: flex; justify-content: flex-start; align-items: center; height: 100%;",
          h3("VARIABLE SELECTION PROCESS", 
             style = "color: #FFFFFF; font-size: 2.5em; text-align: left;")
        )
      ),
      column(7, 
        card_container(
          fluidRow(
            shinycssloaders::withSpinner(plotOutput("venn.plot", height = "400px", width = "500px"))
          ),
          fluidRow(
            uiOutput("explanation")
          )
        )
      )
    )
  )
}
