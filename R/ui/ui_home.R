# ============================================================================
# MicroarrAI - Home Tab UI
# ============================================================================
# Description: Landing page with scrolling sections and methodology overview
# Dependencies: ui_helpers.R
# ============================================================================

ui_home <- function() {
  tabPanel(
    "Home",
    fluidRow(
      column(
        12,
        tags$div(
          style = "color: #ffffff; border-radius: 15px; padding: 25px; box-shadow: 2px 2px 12px rgba(0,0,0,0.1); height: 100%;",
          
          # ===== Header =====
          fluidRow(
            h3("Peptide MicroarrAI", style = "text-transform: none")
          ),
          fluidRow(
            h6("Authors: Sergio Olmos Piñero, Val Fernández Lanza, Javier Martínez-Botas, Belén de la Hoz Caballer, Miguel Ángel Sicilia Urban")
          ),
          
          # ===== Animated Tiles + Content Sections =====
          fluidRow(
            # Layered tiles (scroll-animated)
            div(
              class = "tiles",
              div(class = "tile", id = "tile1"),
              div(class = "tile", id = "tile2"),
              div(class = "tile", id = "tile3"),
              div(class = "tile", id = "tile4")
            ),
            
            # Section 1: Preprocessing
            div(
              class = "section",
              tags$article(
                h2("Preprocessing"),
                p("The preprocessing step involves the normalization of the arrays, which can follow two main paths:"),
                h5("Raw Data:"),
                p("Inter-array normalization is performed, taking into account the local background for each spot on the array in order to subtract this local background noise. Additionally, the non-specific signal is removed using negative controls. Following this, normalization is carried out, with the user able to select the method from the currently implemented options: z-score, median scaling, or quantile normalization."),
                h5("Preprocessed Matrix:"),
                p("Alternatively, users may upload a matrix that has already undergone preprocessing. In this case, the platform offers the option to apply further normalization or scaling methods. If no additional normalization is desired, the user can proceed with the analysis directly."),
                p("In both cases, variables that exhibit zero variance are automatically removed during the preprocessing step to ensure that the analysis is not skewed by uninformative features.")
              )
            ),
            
            # Section 2: Peptide Selection
            div(
              class = "section",
              tags$article(
                h2("Peptide Selection"),
                p("In this module, statistical models are constructed to identify peptides that exhibit statistically significant differences across conditions. Both parametric and non-parametric tests are applied, depending on the distribution and characteristics of the data. These tests help to ensure that only meaningful differences are identified, accounting for potential variability in the dataset."),
                p("Additionally, depending on the nature of the target variable and the selected analysis, generalized linear models (GLM) or linear models (LM) are employed to further refine the selection of candidate peptides. GLMs are particularly useful when dealing with non-normally distributed outcomes or categorical variables, while LMs are appropriate for continuous outcomes. The choice of model ensures that the method is aligned with the statistical assumptions of the data and improves the robustness of the findings."),
                p("To ensure the reliability and clinical relevance of the selected peptides, several key metrics are used during the selection process:"),
                tags$ul(
                  tags$li(tags$strong("Area Under the Curve (AUC): "), "This metric is employed to evaluate the discriminatory ability of the peptides in distinguishing between different conditions or classes. AUC provides an indication of how well the peptides can be used as potential biomarkers."),
                  tags$li(tags$strong("Adjusted p-value: "), "To correct for multiple testing and reduce the risk of false positives, p-values are adjusted using methods such as the ", tags$em("Benjamini-Hochberg"), " procedure. This ensures that the identified peptides are statistically robust and not the result of random variation."),
                  tags$li(tags$strong("Fold-change: "), "This metric measures the magnitude of the difference in expression levels between groups, helping to identify peptides with biologically meaningful differences."),
                  tags$li(tags$strong("F-ANOVA: "), "In cases where multiple conditions are compared, F-tests from analysis of variance (ANOVA) are employed to detect whether the expression levels of the peptides differ significantly across groups.")
                )
              )
            ),
            
            # Section 3: Machine Learning
            div(
              class = "section",
              tags$article(
                h2("Machine Learning"),
                h5("Dimensionality Reduction for Visualization"),
                p("This module also includes a submodule focused on visualizing the data through dimensionality reduction techniques such as PCA (Principal Component Analysis), PCoA (Principal Coordinate Analysis), and NMDS (Non-metric Multidimensional Scaling). These methods help to illustrate the patterns and relationships within the data, offering a visual perspective on the associations identified by the models. While these techniques are primarily used for exploratory visualization, they complement the feature selection process by providing insight into the overall structure of the data."),
                h5("Variable Selection and Marker Identification"),
                p("In this module, the selection of important variables and candidate biomarkers is performed using machine learning models tailored to high-dimensional data. The models currently implemented include Random Forest, C5.0, and Support Vector Machine (SVM), each chosen for their ability to handle complex, multivariate data and provide robust insights into the most relevant features."),
                tags$ul(
                  tags$li(tags$strong("Random Forest: "), "This ensemble method is used due to its strength in identifying important variables from large datasets, particularly when the number of variables exceeds the number of samples. Random Forest ranks the variables based on their contribution to reducing impurity (e.g., Gini index) in the decision trees, providing a straightforward metric for identifying potential biomarkers. The method is robust against overfitting due to its random sampling and can handle noisy data effectively."),
                  tags$li(tags$strong("C5.0: "), "This decision tree-based model is employed for its ability to perform well with large datasets while maintaining computational efficiency. It allows for boosting, which improves model performance by combining multiple weak classifiers to create a strong classifier. The model provides feature importance based on its decision paths, helping to pinpoint peptides that may serve as reliable biomarkers."),
                  tags$li(tags$strong("Support Vector Machine (SVM): "), "is applied in cases where the relationship between variables and outcomes is non-linear. The model is particularly effective in high-dimensional spaces and is well-suited for classification tasks. To identify the most important variables, ", tags$strong("Recursive Feature Elimination (RFE)"), " is used in conjunction with SVM, iteratively eliminating the least significant features to isolate the most informative ones.")
                ),
                tags$strong("Planned Enhancements"),
                p("In the future, we plan to incorporate additional models, such as XGBoost and Elastic Net, to further refine variable selection and improve model performance. XGBoost will allow for enhanced boosting strategies, which can handle complex interactions between variables, while Elastic Net will provide a combined regularization approach (Lasso and Ridge) to select the most relevant features in datasets with correlated variables.")
              )
            ),
            
            # Section 4: Immunogenic Region Visualization
            div(
              class = "section",
              tags$article(
                h2("Immunogenic Region Visualization"),
                p("This module focuses on the visualization of immunogenic regions, leveraging both two-dimensional (2D) and three-dimensional (3D) representations to integrate structural and biochemical data. The goal of this module is to highlight regions of interest that may serve as immunogenic markers or targets for further investigation."),
                tags$strong("Two-Dimensional Visualization"),
                p("In the 2D visualization approach, structural information derived from the Protein Data Bank (PDB) is integrated with other biochemical modifications such as methylations, disulfide bridges, and other relevant post-translational modifications. This layer of information is crucial for identifying regions that may influence the immunogenicity of peptides, as these modifications can alter protein folding, stability, and interaction with immune receptors."),
                p("The use of 2D visualization helps to pinpoint potential immunogenic regions by overlaying data from biochemical annotations onto a simplified planar representation of the protein structure. This allows researchers to focus on areas where specific structural modifications may coincide with or enhance the immunogenic properties of a given peptide."),
                tags$strong("Three-Dimensional Visualization"),
                p("In parallel, 3D visualization is employed to map the candidate peptides, identified in previous modules, onto the three-dimensional structure of the protein. The spatial arrangement of these peptides provides valuable insights into their accessibility and potential interactions with immune receptors, particularly B-cell or T-cell receptors. By visualizing the peptides in the context of the complete protein structure, researchers can assess their potential as biomarkers or therapeutic targets."),
                h5("Ongoing Development"),
                p("Currently, this module is in development, with future iterations aiming to enhance the visual representation of peptide-protein interactions. Advanced algorithms will be incorporated to better predict potential immunogenic hotspots based on structural and functional data. Furthermore, the integration of real-time visualization tools and interactive interfaces will allow users to explore the protein structures and candidate markers dynamically, facilitating more comprehensive analyses.")
              )
            )
          ),
          
          # ===== Footer Image =====
          fluidRow(
            style = "background-color: #ffffff; z-index: 2; position: relative;",
            img(src = "assets/pie.png", height = "100%", width = "100%", align = "center")
          )
        )
      )
    )
  )
}
