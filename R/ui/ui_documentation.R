# ============================================================================
# MicroarrAI - Documentation Tab UI
# ============================================================================
# Description: Interactive documentation viewer with sidebar navigation
# Dependencies: markdown, shiny
# ============================================================================

ui_documentation <- function() {
  tabPanel(
    "Documentation",
    
    # Custom CSS for documentation page
    tags$head(
      # KaTeX CSS for math rendering
      tags$link(
        rel = "stylesheet",
        href = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css",
        integrity = "sha384-n8MVd4RsNIU0tAv4ct0nTaAbDJwPJzDEaqSD1odI+WdtXRGWt2kTvGFasHpSy3SV",
        crossorigin = "anonymous"
      ),
      # KaTeX JS for math rendering
      tags$script(
        src = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js",
        integrity = "sha384-XjKyOOlGwcjNTAIQHIpgOno0Hl1YQqzUOEleOLALmuqehneUG+vnGctmUb0ZY0l8",
        crossorigin = "anonymous"
      ),
      # Auto-render extension for automatic math detection
      tags$script(
        src = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js",
        integrity = "sha384-+VBxd3r6XgURycqtZ117nYw44OOcIax56Z4dCRWbxyPt0Koah1uHoK0o4+/RRE05",
        crossorigin = "anonymous"
      ),
      
      tags$style(HTML("
        /* Documentation specific styles */
        .doc-content {
          margin-left: 0;
          transition: margin-left 0.3s ease;
          padding: 30px 40px;
          overflow-y: auto;
          background: #ffffff;
          min-height: calc(100vh - 150px);
        }
        
        .doc-content.sidebar-open {
          margin-left: 320px;
        }
        
        .doc-content h1 {
          color: #191c32;
          font-size: 32px;
          font-weight: 700;
          margin-bottom: 10px;
          border-bottom: 3px solid #667eea;
          padding-bottom: 10px;
        }
        
        .doc-content h2 {
          color: #191c32;
          font-size: 24px;
          font-weight: 600;
          margin-top: 30px;
          margin-bottom: 15px;
          padding-top: 10px;
        }
        
        .doc-content h3 {
          color: #2a2d4a;
          font-size: 20px;
          font-weight: 600;
          margin-top: 25px;
          margin-bottom: 12px;
        }
        
        .doc-content h4 {
          color: #2a2d4a;
          font-size: 18px;
          font-weight: 600;
          margin-top: 20px;
          margin-bottom: 10px;
        }
        
        .doc-content p {
          color: #333333;
          font-size: 15px;
          line-height: 1.7;
          margin-bottom: 15px;
        }
        
        .doc-content ul, .doc-content ol {
          color: #333333;
          font-size: 15px;
          line-height: 1.7;
          margin-bottom: 15px;
          padding-left: 30px;
        }
        
        .doc-content li {
          margin-bottom: 8px;
        }
        
        .doc-content code {
          background: #f5f5f5;
          padding: 2px 6px;
          border-radius: 3px;
          font-family: 'Courier New', monospace;
          font-size: 14px;
          color: #d63384;
        }
        
        .doc-content pre {
          background: #f8f9fa;
          border-left: 4px solid #667eea;
          padding: 15px;
          border-radius: 5px;
          overflow-x: auto;
          margin-bottom: 20px;
        }
        
        .doc-content pre code {
          background: transparent;
          padding: 0;
          color: #333333;
          font-size: 13px;
        }
        
        .doc-content blockquote {
          border-left: 4px solid #667eea;
          padding: 10px 20px;
          margin: 20px 0;
          background: #f0f4ff;
          color: #2d4a7d;
          font-style: italic;
        }
        
        .doc-content table {
          width: 100%;
          border-collapse: collapse;
          margin: 20px 0;
        }
        
        .doc-content table th {
          background: #667eea;
          color: #ffffff;
          padding: 12px;
          text-align: left;
          font-weight: 600;
        }
        
        .doc-content table td {
          padding: 10px 12px;
          border-bottom: 1px solid #e0e0e0;
        }
        
        .doc-content table tr:hover {
          background: #f5f5f5;
        }
        
        .doc-content hr {
          border: none;
          border-top: 2px solid #e0e0e0;
          margin: 30px 0;
        }
        
        /* Math rendering (KaTeX) */
        .katex {
          font-size: 1.1em;
        }
        
        .katex-display {
          margin: 20px 0;
          overflow-x: auto;
          overflow-y: hidden;
        }
        
        .doc-content .katex-display > .katex {
          text-align: center;
        }
        
        /* Highlighted boxes for important info */
        .doc-content .info-box {
          background: #e7f3ff;
          border-left: 4px solid #2196F3;
          padding: 15px;
          margin: 20px 0;
          border-radius: 5px;
        }
        
        .doc-content .warning-box {
          background: #fff3cd;
          border-left: 4px solid #ffc107;
          padding: 15px;
          margin: 20px 0;
          border-radius: 5px;
        }
        
        .doc-content .success-box {
          background: #d4edda;
          border-left: 4px solid #28a745;
          padding: 15px;
          margin: 20px 0;
          border-radius: 5px;
        }
        
        .doc-content .danger-box {
          background: #f8d7da;
          border-left: 4px solid #dc3545;
          padding: 15px;
          margin: 20px 0;
          border-radius: 5px;
        }
        
        /* Scrollbar Styling */
        .doc-content::-webkit-scrollbar {
          width: 8px;
        }
        
        .doc-content::-webkit-scrollbar-track {
          background: #f0f0f0;
        }
        
        .doc-content::-webkit-scrollbar-thumb {
          background: #c0c0c0;
          border-radius: 4px;
        }
        
        .doc-content::-webkit-scrollbar-thumb:hover {
          background: #a0a0a0;
        }
        
        /* Responsive adjustments */
        @media (max-width: 768px) {
          .doc-content {
            padding: 20px;
          }
          
          .doc-content.sidebar-open {
            margin-left: 0;
          }
        }
      "))
    ),
    
    # Floating Sidebar (same style as ML/Peptide tabs)
    tags$div(
      id = "doc-sidebar",
      class = "ml-sidebar",
      
      tags$h4(
        icon("book"),
        " Documentation"
      ),
      
      # Sidebar Toggle Button
      tags$div(
        id = "doc-sidebar-toggle",
        class = "ml-sidebar-toggle",
        icon("bars")
      ),
      
      # Main Sections
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "GETTING STARTED"),
        
        tags$div(
          class = "ml-sidebar-item active",
          `data-doc` = "index",
          onclick = "Shiny.setInputValue('doc_selected', 'index', {priority: 'event'})",
          icon("home"),
          "Overview"
        ),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-doc` = "preprocessing",
          onclick = "Shiny.setInputValue('doc_selected', 'preprocessing', {priority: 'event'})",
          icon("cogs"),
          "1. Preprocessing"
        ),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-doc` = "deg",
          onclick = "Shiny.setInputValue('doc_selected', 'deg', {priority: 'event'})",
          icon("chart-line"),
          "2. DEG Analysis"
        ),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-doc` = "ml",
          onclick = "Shiny.setInputValue('doc_selected', 'ml', {priority: 'event'})",
          icon("brain"),
          "3. Machine Learning"
        )
      ),
      
      # Quick Links
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "QUICK LINKS"),
        
        tags$div(
          class = "ml-sidebar-item",
          style = "cursor: pointer;",
          onclick = "window.scrollTo(0, 0);",
          icon("arrow-up"),
          "Back to Top"
        )
      )
    ),
    
    # Content Area
    tags$div(
      class = "doc-content ml-content",
      uiOutput("doc_content")
    ),
    
    # JavaScript for navigation and math rendering
    tags$script(HTML("
      $(document).ready(function() {
        // ===== DOC SIDEBAR =====
        var docSidebarOpen = false;
        
        // Doc Sidebar Toggle
        $(document).on('click', '#doc-sidebar-toggle', function() {
          docSidebarOpen = !docSidebarOpen;
          
          if (docSidebarOpen) {
            $('#doc-sidebar').addClass('open').css('left', '0');
            $('.doc-content').addClass('sidebar-open');
            $(this).addClass('sidebar-open');
            $(this).html('<i class=\"fa fa-times\"></i>');
          } else {
            $('#doc-sidebar').removeClass('open').css('left', '-320px');
            $('.doc-content').removeClass('sidebar-open');
            $(this).removeClass('sidebar-open');
            $(this).html('<i class=\"fa fa-bars\"></i>');
          }
        });
        
        // Handle navigation item clicks
        $(document).on('click', '.ml-sidebar-item[data-doc]', function() {
          $('.ml-sidebar-item').removeClass('active');
          $(this).addClass('active');
          
          // Scroll content to top
          $('.doc-content').scrollTop(0);
        });
        
        // Render math on initial load
        if (typeof renderMathInElement !== 'undefined') {
          setTimeout(function() {
            renderMathInElement(document.querySelector('.doc-content'), {
              delimiters: [
                {left: '$$', right: '$$', display: true},
                {left: '$', right: '$', display: false},
                {left: '\\\\(', right: '\\\\)', display: false},
                {left: '\\\\[', right: '\\\\]', display: true}
              ],
              throwOnError: false
            });
          }, 500);
        }
      });
      
      // Re-render math when content changes
      $(document).on('shiny:value', function(event) {
        if (event.name === 'doc_content') {
          if (typeof renderMathInElement !== 'undefined') {
            setTimeout(function() {
              renderMathInElement(document.querySelector('.doc-content'), {
                delimiters: [
                  {left: '$$', right: '$$', display: true},
                  {left: '$', right: '$', display: false},
                  {left: '\\\\(', right: '\\\\)', display: false},
                  {left: '\\\\[', right: '\\\\]', display: true}
                ],
                throwOnError: false
              });
            }, 500);
          }
        }
      });
    "))
  )
}
