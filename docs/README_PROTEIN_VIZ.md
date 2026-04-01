# Visualización de Proteínas 2D/3D - MicroarrAI

## Archivos Implementados

### Utilidades
- `R/utils/protein_utils.R` - Procesamiento de proteínas desde UniProt
- `R/utils/snake_plot_utils.R` - Generación de snake plots

### UI/Server
- `R/ui/ui_protein_viz.R` - Interfaz de usuario
- `R/server/visualization_protein.R` - Lógica del servidor

### Ejemplo
- `examples/app_with_protein_viz.R` - Integración completa

## Integración Rápida

```r
# 1. Cargar módulos
source("R/utils/protein_utils.R")
source("R/utils/snake_plot_utils.R")
source("R/ui/ui_protein_viz.R")
source("R/server/visualization_protein.R")

# 2. UI
ui <- navbarPage(
  "MicroarrAI",
  tabPanel("🧬 Proteínas", ui_protein_viz())
)

# 3. Server
server <- function(input, output, session) {
  server_protein_viz(
    input, output, session,
    clinical_data = your_clinical_data,  # Reactivo con id + Risk2
    peptide_data = your_peptide_data,    # Reactivo con id + péptidos
    biomarkers = your_biomarkers,        # Vector: c("p4 a-s2-cas ige", ...)
    target = "Risk2"
  )
}
```

## Inputs

**Usuario:**
- UniProt ID (ej: P02663)
- Regex de proteína (ej: a_s2_cas)

**Datos:**
- clinical_data: DataFrame con `id` + variable target
- peptide_data: DataFrame con `id` + columnas de péptidos (`p1_protein_ige`, `p1_protein_igg4`, etc.)
- biomarkers: Vector con formato `"p4 a-s2-cas ige"`, `"p6 a-s2-cas igg4"`
- target: Nombre de columna (ej: "Risk2")

## Salidas

### IgE (verde - arriba)
- Snake plot 2D con paleta verde
- Estructura 3D con biomarcadores IgE

### IgG4 (rojo - abajo)
- Snake plot 2D con paleta roja
- Estructura 3D con biomarcadores IgG4

## Formato de Péptidos

Las columnas deben incluir el sufijo `_ige` o `_igg4`:
- `p1_a_s2_cas_ige`
- `p1_a_s2_cas_igg4`
- `p2_a_s2_cas_ige`
- etc.

## Formato de Biomarcadores

Biomarcadores deben incluir el tipo al final:
- `"p4 a-s2-cas ige"`
- `"p6 a-s2-cas igg4"`
- `"p10 a-s1-cas ige"`
