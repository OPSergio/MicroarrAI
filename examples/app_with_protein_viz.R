# Ejemplo de integración - Visualización de Proteínas

library(shiny)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggiraph)
library(tibble)
library(stringr)
library(readxl)

source("R/utils/protein_utils.R")
source("R/utils/snake_plot_utils.R")
source("R/ui/ui_protein_viz.R")
source("R/server/visualization_protein.R")

ui <- navbarPage(
  "MicroarrAI",
  tabPanel("🧬 Proteínas 2D/3D", ui_protein_viz())
)

server <- function(input, output, session) {
  
  # Datos de péptidos (columnas: id, p1_protein_ige, p1_protein_igg4, etc.)
  peptide_data <- reactive({
    readxl::read_excel("Data/Peptides_DEMO.xlsx")
  })
  
  # Datos clínicos (columnas: id, Risk2)
  clinical_data <- reactive({
    readxl::read_excel("Data/Clinics_DEMO.xlsx")
  })
  
  # Biomarcadores desde ML (formato: "p4 a-s2-cas ige", "p6 a-s2-cas igg4")
  biomarkers_selected <- reactive({
    c(
      "p4 a-s2-cas ige",
      "p6 a-s2-cas ige",
      "p10 a-s1-cas igg4"
    )
  })
  
  server_protein_viz(
    input, output, session,
    clinical_data = clinical_data,
    peptide_data = peptide_data,
    biomarkers = biomarkers_selected,
    target = "Risk2"
  )
}

shinyApp(ui, server)
