# ============================================================================
# MicroarrAI / METIS - Top Navbar
# ============================================================================
# Description: Floating glass navbar (METIS) that replaces the old titlePanel.
#   Links drive the main tabset via Shiny.setInputValue('nav_target', ...),
#   handled in server with updateTabsetPanel(). Styling is vanilla CSS
#   (class prefix `metis-`) so it never collides with Bootstrap.
# ============================================================================

# Laurel-in-circle emblem (lines inherit currentColor; leaves stay gold)
metis_mark_svg <- HTML(
  '<svg viewBox="0 0 100 100" fill="none" class="metis-mark" aria-hidden="true">
     <circle cx="50" cy="50" r="40" stroke="currentColor" stroke-width="2.2"/>
     <path d="M40 72 C 40 56 46 42 58 30" stroke="#c2a878" stroke-width="1.8" stroke-linecap="round"/>
     <g fill="#c2a878">
       <ellipse cx="41" cy="66" rx="6.6" ry="2.6" transform="rotate(-62 41 66)"/>
       <ellipse cx="44" cy="58" rx="7.0" ry="2.7" transform="rotate(-58 44 58)"/>
       <ellipse cx="48" cy="49" rx="7.2" ry="2.8" transform="rotate(-52 48 49)"/>
       <ellipse cx="52" cy="40" rx="7.0" ry="2.7" transform="rotate(-46 52 40)"/>
       <ellipse cx="57" cy="31" rx="6.4" ry="2.5" transform="rotate(-40 57 31)"/>
     </g>
   </svg>'
)

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

      # Brand -> Home
      tags$a(
        class = "metis-brand",
        onclick = "metisNav('Home', null)",
        metis_mark_svg,
        tags$span(class = "metis-wordmark", "METIS")
      ),

      # Section links (values match the tabPanel titles)
      tags$nav(
        class = "metis-links",
        metis_link("Preprocessing",     "Preprocess"),
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
    )
  )
}
