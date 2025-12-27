# ============================================================================
# MicroarrAI - Preprocess Tab UI
# ============================================================================
# Description: Data upload, normalization, and quality control interface
# Dependencies: ui_helpers.R
# ============================================================================

ui_preprocess <- function() {
  tabPanel(
    "Preprocess",
    fluidRow(
      style = "margin-top: 20px;",
      
      # ===== Left Sidebar: Upload Controls =====
      column(
        2,
        card_container(
          fileInput(
            "db_fileinput",
            buttonLabel = "Upload...",
            label = dark_label("Upload clinic database")
          ),
          fileInput(
            "pep_fileinput",
            buttonLabel = "Upload...",
            label = dark_label("Upload microarray database")
          ),
          h6(
            "If you want to perform the analysis with the raw data, select the directory where the .csv files are located.",
            style = "color: #191c32;"
          ),
          shinyDirButton('directory', 'Folder select', 'Please select a folder'),
          br(), br(),
          actionButton("scale_button", "Scale Data"),
          br(), br(),
          downloadButton("download_button", "Download as Excel")
        )
      ),
      
      # ===== Right Panel: Normalization & Preview =====
      column(
        10,
        
        # Normalization Method Selection
        card_container(
          style = "width: 80%;",
          selectInput(
            "normalization_method",
            "Choose Normalization Method",
            choices = c("Z-score", "Quantile", "Median Scaling"),
            selected = "Z-score"
          ),
          actionButton("process_button", "Start Normalization Process")
        ),
        
        spacer(20),
        
        # Example Data Buttons
        card_container(
          actionButton("load_example_db", "Load example clinical Data"),
          actionButton("load_example_pep", "Load sample peptide Data"),
          br(), br(),
          verbatimTextOutput("data_status_db"),
          verbatimTextOutput("data_status_pep")
        ),
        
        spacer(20),
        
        # Data Preview
        fluidRow(
          DT::DTOutput("data_table")
        ),
        
        spacer(20),
        
        # Density Plot
        fluidRow(
          plotOutput("density_plot")
        )
      )
    )
  )
}
