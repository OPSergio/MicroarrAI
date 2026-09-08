# ============================================================================
# MicroarrAI / METIS - Top Navbar
# ============================================================================
# Description: Floating glass navbar (METIS) that replaces the old titlePanel.
#   Links drive the main tabset via Shiny.setInputValue('nav_target', ...),
#   handled in server with updateTabsetPanel(). Styling is vanilla CSS
#   (class prefix `metis-`) so it never collides with Bootstrap.
# ============================================================================

# A single nav link. `tab` must match the tabPanel title (its value).
metis_link <- function(label, tab) {
  tags$a(
    class = "metis-link",
    `data-tab` = tab,
    onclick = sprintf("metisNav('%s', this)", tab),
    label
  )
}

ui_navbar <- function() {
  tags$header(
    class = "metis-nav",
    tags$div(
      class = "metis-nav__pill",

      # Brand -> Home (wordmark only, no emblem)
      tags$a(
        class = "metis-brand",
        onclick = "metisNav('Home', null)",
        tags$span(class = "metis-wordmark", "MicroarrAI")
      ),

      # Section links (values match the tabPanel titles)
      tags$nav(
        class = "metis-links",
        metis_link("Preprocessing",     "Preprocess"),
        metis_link("Quality",           "Quality Control"),
        metis_link("Peptide finder",    "Peptide finder"),
        metis_link("Machine learning",  "Machine Learning"),
        metis_link("3D visualization",  "Protein Visualization"),
        metis_link("Docs",              "Documentation")
      ),

      # Light/dark switcher (themes the navbar + the landing iframe)
      tags$button(
        class = "metis-toggle",
        `aria-label` = "Toggle light/dark",
        onclick = "metisTheme(this)",
        HTML("&#9728;")  # ☀
      )
    ),

    # Reset the whole pipeline — fixed in the top-right corner, always clickable
    tags$button(
      id = "metis-reset-btn",
      `aria-label` = "Reset pipeline",
      title = "Reset pipeline (clears all data and results)",
      onclick = "if (confirm('Reset the whole pipeline? Loaded data and results will be cleared.')) Shiny.setInputValue('metis_reset', Math.random(), {priority:'event'});",
      HTML("&#8635;")  # ↻
    )
  )
}
