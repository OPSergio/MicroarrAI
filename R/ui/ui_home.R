# ============================================================================
# MicroarrAI / METIS - Home Tab UI
# ============================================================================
# Description: Home is the METIS landing (protein 3D + scroll storytelling),
#   embedded as an isolated iframe so its Tailwind styles never collide with
#   the app's Bootstrap. The source lives in www/landing/.
# ============================================================================

ui_home <- function() {
  tabPanel(
    "Home",
    div(
      class = "metis-home",
      tags$iframe(
        src = "landing/index.html",
        class = "metis-home__frame",
        title = "METIS",
        frameborder = "0",
        scrolling = "yes",
        onload = "metisSyncTheme(this)"   # match current app theme on load
      )
    )
  )
}
