# ============================================================================
# METIS — Dev launcher (hot reload)
# ============================================================================
# Run this instead of app.R during development:
#   - watches the app folder and auto-reloads the browser on any change to
#     .R / .css / .js / .html / images (incl. www/ and www/landing/)
#   - so editing styles.css, custom.js, the landing, or UI/server R files
#     refreshes automatically — no manual restart.
#
# Usage:  Rscript run_dev.R       (or open this file in RStudio and Source it)
# ============================================================================

options(shiny.autoreload = TRUE)        # watch files + push browser reload
options(shiny.autoreload.interval = 500) # poll every 0.5s
# Widen the watch list to be safe (default already covers r/html/js/css/png...)
options(shiny.autoreload.pattern = "\\.(r|R|html?|js|css|svg|png|jpe?g|gif)$")

# Verbose-ish dev logging
options(shiny.fullstacktrace = TRUE)

message("METIS dev server — hot reload ON. Edit & save; the browser refreshes.")
shiny::runApp(".", launch.browser = TRUE, port = 3838)
