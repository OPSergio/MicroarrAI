# ============================================================================
# MicroarrAI - UI Helper Functions
# ============================================================================
# Description: Reusable UI component builders to reduce code duplication
# Used by: All UI modules
# ============================================================================

#' Create a White Card Container
#' 
#' Standardized white card with rounded corners and shadow
#' This pattern is repeated ~20+ times in the app
#'
#' @param ... UI elements to include in the card
#' @param style Additional inline styles (optional)
#' @param class Additional CSS classes (optional)
#' @return A tags$div with standard card styling
#' @examples
#' card_container(
#'   h4("Title"),
#'   p("Content")
#' )
card_container <- function(..., style = NULL, class = NULL) {
  base_style <- "background-color: #ffffff; border-radius: 15px; padding: 25px; box-shadow: 2px 2px 12px rgba(0,0,0,0.1);"
  
  final_style <- if (!is.null(style)) {
    paste(base_style, style)
  } else {
    base_style
  }
  
  tags$div(
    style = final_style,
    class = class,
    ...
  )
}

#' Create a Card with Purple Shadow (Highlighted)
#' 
#' Used for important analysis sections
#'
#' @param ... UI elements to include in the card
#' @param style Additional inline styles (optional)
#' @return A tags$div with purple shadow styling
card_container_highlighted <- function(..., style = NULL) {
  base_style <- "background-color: #ffffff; border-radius: 15px; padding: 25px; box-shadow: 0px 0px 20px rgba(87, 19, 248, 0.3);"
  
  final_style <- if (!is.null(style)) {
    paste(base_style, style)
  } else {
    base_style
  }
  
  tags$div(
    style = final_style,
    ...
  )
}

#' Create Centered Section Title
#' 
#' Standardized h3 with consistent styling
#'
#' @param title The title text
#' @param color Text color (default: white)
#' @param size Font size in em (default: 2.5)
#' @param transform Text transform (default: none to preserve h3 CSS)
#' @return h3 element with inline styles
section_title <- function(title, color = "#FFFFFF", size = "2.5em", transform = "none") {
  h3(title, style = sprintf("color: %s; font-size: %s; text-align: left; text-transform: %s;", 
                            color, size, transform))
}

#' Create Dark Text Label
#' 
#' Used for labels inside white cards
#'
#' @param text Label text
#' @return tags$span with dark color
dark_label <- function(text) {
  tags$span(style = "color: #191c32;", text)
}

#' Create Loading Spinner Overlay
#'
#' Full-screen CSS spinner shown while a long task runs (toggled via shinyjs).
#'
#' @param id Element ID (default: "loader")
#' @param label Text shown under the spinner
#' @param gif_src Deprecated, ignored (kept for backward compatibility)
#' @return tags$div with fixed positioning
loading_overlay <- function(id = "loader", label = "Running statistical tests…", gif_src = NULL) {
  tags$div(
    id = id,
    style = "position: fixed; inset: 0; z-index: 9999; display: none;
             background-color: rgba(25, 28, 50, 0.55);",
    tags$style(HTML("@keyframes microarrai-spin { to { transform: rotate(360deg); } }")),
    tags$div(
      style = "position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; color: #fff;",
      tags$div(style = "width: 64px; height: 64px; margin: 0 auto 18px; border: 6px solid rgba(255,255,255,0.25);
                        border-top-color: #17a589; border-radius: 50%; animation: microarrai-spin 0.9s linear infinite;"),
      tags$div(label, style = "font-size: 16px; font-weight: 600; letter-spacing: .02em;")
    )
  )
}

#' Create Two-Column Control Panel
#' 
#' Common pattern: controls on left, output on right
#'
#' @param left_content UI for left column
#' @param right_content UI for right column
#' @param left_width Column width for left (default: 4)
#' @param right_width Column width for right (default: 8)
#' @return fluidRow with two columns
control_panel <- function(left_content, right_content, left_width = 4, right_width = 8) {
  fluidRow(
    column(left_width, left_content),
    column(right_width, right_content)
  )
}

#' Create Info Description Card
#' 
#' Used for methodology explanations
#'
#' @param title Section title (h4)
#' @param ... Paragraph content
#' @return tags$div with description
info_card <- function(title, ...) {
  tags$div(
    h4(title, style = "color: #191c32;"),
    ...
  )
}

#' Create Centered Content Wrapper
#' 
#' Centers content both horizontally and vertically
#'
#' @param ... Content to center
#' @param height Height of container (default: 100%)
#' @return tags$div with flexbox centering
centered_content <- function(..., height = "100%") {
  tags$div(
    style = sprintf("display: flex; justify-content: center; align-items: center; height: %s;", height),
    ...
  )
}

#' Create Spacer Row
#' 
#' Adds vertical spacing between sections
#'
#' @param height Height in pixels (default: 40)
#' @return fluidRow with specified height
spacer <- function(height = 40) {
  fluidRow(style = sprintf("margin-top: %dpx;", height))
}


#' PowerBI-style KPI Card
#'
#' Flat tile with a small uppercase label and a large value. Used in the Data
#' Overview grid.
#'
#' @param label Metric name (small uppercase).
#' @param value Metric value (large number/text).
#' @param accent Top-border accent colour.
#' @return A tags$div KPI tile.
kpi_card <- function(label, value, accent = "#17a589") {
  tags$div(
    style = paste0("background:#fff;border:1px solid #e6e8ec;border-top:3px solid ", accent,
                   ";border-radius:8px;padding:16px 18px;min-height:92px;margin-bottom:16px;"),
    tags$div(label, style = "font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:#8a8f98;font-weight:600;margin-bottom:8px;"),
    tags$div(value, style = "font-size:28px;font-weight:700;color:#191c32;line-height:1.1;")
  )
}
