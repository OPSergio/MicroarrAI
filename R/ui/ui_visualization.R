# ============================================================================
# MicroarrAI - Visualization UI Module
# ============================================================================
# Description: UI for 2D protein representation and 3D AlphaFold2 visualization
# Dependencies: ui_helpers.R
# ============================================================================

#' 2D Protein Representation Tab UI
#' 
#' Upload FASTA sequence and biochemical info for protein visualization
#' 
#' @return tabPanel for 2D Representation
ui_2d_visualization <- function() {
  tabPanel(
    "2D Representation",
    fluidRow(
      # Left panel: Controls
      column(2,
        card_container(
          style = "margin-top: 20px; height: 100%;",
          fileInput("fasta_file", "Upload Aminoacid Sequence"),
          fileInput("bio_file", "Upload Biochemical Info"),
          numericInput("amino_count", "Number of amino acids.", value = 186, min = 1),
          numericInput("chain_length", "Chain length", value = 20, min = 1),
          numericInput("spacing", "Letter spacing", value = 15, min = 1),
          numericInput("offset", "Position offset", value = 1),
          actionButton("plot_btn", "Generate Chart")
        )
      ),
      
      # Right panel: Visualization
      column(10, 
        card_container(
          style = "margin-top: 20px; height: 100%;",
          plotOutput("protein_plot", height = "600px")
        )
      )
    )
  )
}


#' 3D AlphaFold2 Visualization Tab UI
#' 
#' Interactive molecular structure viewer powered by Molstar
#' 
#' @return tabPanel for 3D Visualization
ui_3d_visualization <- function() {
  tabPanel(
    title = "3D Visualization by Alphafold2",
    fluidRow(
      Molstar(
        pdbId = "",
        useInterface = TRUE,
        showControls = TRUE,
        showAxes = TRUE
      )
    )
  )
}
