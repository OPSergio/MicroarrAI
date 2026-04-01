# =============================================================================
# UI for 2D/3D Protein Visualization
# =============================================================================

#' UI for protein visualization tab
#' 
#' @return Shiny UI
#' @export
ui_protein_viz <- function() {
  tabPanel(
    "Protein Visualization",
    # JavaScript for communication between ggiraph and NGL
    tags$head(
      tags$script(HTML("
        console.log('[PROTEIN_VIZ] JavaScript initialized');
        
        // ========== 1. Listen for molstar-ready from iframe ==========
        window.addEventListener('message', function(event) {
          console.log('[PROTEIN_VIZ] Message received:', event.data);
          
          if (event.data && event.data.type === 'molstar-ready') {
            console.log('[PROTEIN_VIZ] ✅ Molstar ready detected!');
            if (window.Shiny) {
              console.log('[PROTEIN_VIZ] Sending to Shiny: molstar_ready = true');
              Shiny.setInputValue('molstar_ready', Math.random(), {priority: 'event'});
            } else {
              console.error('[PROTEIN_VIZ] Shiny not available!');
            }
          }
          
          // ========== 2. Hover from NGL to ggiraph ==========
          if (event.data && event.data.type === 'ngl-hover') {
            var pos = event.data.pos;
            var target = event.data.target || 'ige';  // Default to IgE if not specified
            console.log('🎯 Hover from NGL (' + target.toUpperCase() + ', position):', pos);
            
            if (window.Shiny) {
              Shiny.setInputValue('ngl_hovered_pos', pos, {priority: 'event'});
            }
            
            // Highlight in corresponding SVG snake plot
            var svgSelector = target === 'ige' ? '#protein_snake_ige svg' : '#protein_snake_igg4 svg';
            var svg = document.querySelector(svgSelector);
            
            if (svg) {
              var prevHovered = svg.querySelectorAll('.hovered-from-ngl');
              prevHovered.forEach(function(el) {
                el.classList.remove('hovered-from-ngl');
                el.style.stroke = '';
                el.style.strokeWidth = '';
                el.style.opacity = '';
              });
              
              if (pos) {
                var selector = '[data-id=\"' + pos + '\"]';
                var elements = svg.querySelectorAll(selector);
                elements.forEach(function(el) {
                  el.classList.add('hovered-from-ngl');
                  el.style.stroke = 'gold';
                  el.style.strokeWidth = '2';
                  el.style.opacity = '1';
                });
              }
            }
          }
        });
        
        // ========== 3. Send messages to NGL iframes ==========
        function sendToMolstar(data) {
          // If target is specified, send only to that iframe
          if (data.target) {
            var iframe = null;
            if (data.target === 'ige') {
              iframe = document.querySelector('[id*=\"protein_3d_ige\"] iframe');
            } else if (data.target === 'igg4') {
              iframe = document.querySelector('[id*=\"protein_3d_igg4\"] iframe');
            }
            
            if (iframe && iframe.contentWindow) {
              console.log('📤 Sending to ' + data.target.toUpperCase() + ' NGL viewer:', data.type);
              iframe.contentWindow.postMessage(data, '*');
            }
          } else {
            // Send to BOTH iframes (for polarity, surface, etc.)
            var iframes = [
              document.querySelector('[id*=\"protein_3d_ige\"] iframe'),
              document.querySelector('[id*=\"protein_3d_igg4\"] iframe')
            ];
            
            iframes.forEach(function(iframe, index) {
              if (iframe && iframe.contentWindow) {
                var analyte = index === 0 ? 'IgE' : 'IgG4';
                console.log('📤 Sending to ' + analyte + ' NGL viewer:', data.type);
                iframe.contentWindow.postMessage(data, '*');
              }
            });
          }
        }
        
        Shiny.addCustomMessageHandler('send_to_molstar', function(message) {
          console.log('📨 Message from Shiny for Molstar:', message);
          sendToMolstar(message);
        });
        
        // ========== 4. Setup SVG hover listeners for BOTH snake plots ==========
        function setupSvgListeners() {
          var svgs = [
            document.querySelector('#protein_snake_ige svg'),
            document.querySelector('#protein_snake_igg4 svg')
          ];
          
          svgs.forEach(function(svg, index) {
            if (!svg) {
              console.log('⏳ SVG ' + (index === 0 ? 'IgE' : 'IgG4') + ' not found yet...');
              return;
            }
            
            if (svg.dataset.listenersConfigured === 'true') {
              console.log('ℹ️ Listeners already configured for ' + (index === 0 ? 'IgE' : 'IgG4'));
              return;
            }
            
            var analyte = index === 0 ? 'IgE' : 'IgG4';
            var targetName = index === 0 ? 'ige' : 'igg4';
            console.log('✅ SVG ' + analyte + ' found, configuring listeners...');
            
            svg.addEventListener('mouseover', function(e) {
              var target = e.target;
              while (target && target !== svg) {
                var dataId = target.getAttribute('data-id');
                if (dataId) {
                  console.log('🖱️ Hover on ' + analyte + ':', dataId);
                  var pos = parseInt(dataId);
                  if (!isNaN(pos)) {
                    sendToMolstar({
                      type: 'hover_residue',
                      pos: pos,
                      target: targetName
                    });
                  }
                  return;
                }
                target = target.parentElement;
              }
            });
            
            svg.addEventListener('mouseout', function(e) {
              if (!svg.contains(e.relatedTarget)) {
                console.log('🖱️ Hover out from ' + analyte);
                sendToMolstar({
                  type: 'hover_residue',
                  pos: null,
                  target: targetName
                });
              }
            });
            
            svg.dataset.listenersConfigured = 'true';
            console.log('✅ Listeners configured successfully for ' + analyte);
          });
        }
        
        // ========== 5. Initialize on Shiny connected ==========
        $(document).on('shiny:connected', function() {
          console.log('🔗 Shiny connected, initializing...');
          setTimeout(setupSvgListeners, 1000);
        });
        
        // ========== 6. MutationObserver for BOTH SVG regenerations ==========
        $(document).on('shiny:connected', function() {
          var containers = [
            { id: 'protein_snake_ige', name: 'IgE' },
            { id: 'protein_snake_igg4', name: 'IgG4' }
          ];
          
          containers.forEach(function(config) {
            var container = document.getElementById(config.id);
            if (container) {
              var observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                  if (mutation.addedNodes.length > 0) {
                    console.log('🔄 Detected change in ' + config.name + ' snake plot, reconfiguring listeners...');
                    setTimeout(setupSvgListeners, 500);
                  }
                });
              });
              
              observer.observe(container, { 
                childList: true, 
                subtree: true 
              });
              
              console.log('👁️ MutationObserver active on #' + config.id);
            }
          });
        });
      "))
    ),
    
    # CSS personalizado
    tags$style(HTML("
      .row-flex { display:flex; gap:12px; }
      .col-left { flex: 1.2; min-width: 520px; }
      .col-right { flex: 1; min-width: 520px; }
      
      .biomarker-badge {
        background: #ff6b35;
        color: white;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 11px;
        font-weight: bold;
        margin-left: 6px;
        display: inline-block;
      }
      
      .protein-sidebar {
        background: #f8f9fa;
        padding: 15px;
        border-radius: 8px;
        margin-bottom: 15px;
      }
      
      .protein-sidebar h4 {
        margin-top: 0;
        color: #2c3e50;
        font-size: 16px;
        border-bottom: 2px solid #3498db;
        padding-bottom: 8px;
        margin-bottom: 12px;
      }
      
      .control-section {
        margin-bottom: 15px;
      }
      
      .control-section label {
        font-weight: 600;
        font-size: 13px;
        color: #34495e;
      }
      
      /* Responsive content - MISMO patrón que ML */
      #protein-content {
        transition: margin-left 0.3s ease;
        margin-left: 0;
      }
    ")),
    
    # Floating Sidebar (MISMO patrón que ML)
    tags$div(
      id = "protein-sidebar",
      class = "ml-sidebar",
      
      tags$h4(
        icon("dna", style = "margin-right: 10px;"),
        "Protein Viz"
      ),
      
      # Sidebar Toggle Button
      tags$div(
        id = "protein-sidebar-toggle",
        class = "ml-sidebar-toggle",
        icon("bars")
      ),
      
      # Configuration Section
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "CONFIGURATION"),
        
        tags$div(
          style = "padding: 10px;",
          
          textInput(
            "protein_uniprot_id",
            HTML("<strong>UniProt ID:</strong>"),
            value = "",
            placeholder = "e.g.: P02663"
          ),
          
          textInput(
            "protein_regex",
            HTML("<strong>Regex (protein):</strong>"),
            value = "",
            placeholder = "e.g.: ovoalb, a_s2_cas"
          ),
          
          uiOutput("protein_peptide_count"),
          
          actionButton(
            "protein_load",
            "Load and Visualize",
            icon = icon("play-circle"),
            style = "width: 100%; margin-top: 15px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; padding: 10px; font-weight: bold;"
          )
        )
      ),
      
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "3D VISUALIZATION"),
        
        tags$div(
          style = "padding: 10px;",
          
          selectInput(
            "protein_color_mode",
            HTML("<strong>Color mode:</strong>"),
            choices = c(
              "Biomarkers" = "biomarkers",
              "Expression" = "expression",
              "Polarity" = "polarity"
            ),
            selected = "biomarkers"
          ),
          
          checkboxInput(
            "protein_show_surface",
            "Show surface",
            value = FALSE
          )
        )
      ),
      
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "INFO"),
        
        tags$div(
          style = "padding: 10px;",
          uiOutput("protein_info_display")
        )
      )
    ),
    
    # Main Content Area (responsive with sidebar)
    tags$div(
      id = "protein-content",
      
      # Container with padding
      tags$div(
        style = "background: white; padding: 30px; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); margin-top: 20px;",
        
        # ============ ROW 1: IgE VISUALIZATION ============
        h4("IgE Analysis", style = "color: #191c32; font-weight: bold; margin-bottom: 20px;"),
        
        tags$div(
          class = "row-flex",
          tags$div(
            class = "col-left",
            ggiraph::girafeOutput("protein_snake_ige", width = "100%", height = "1000px")
          ),
          tags$div(
            class = "col-right",
            htmlOutput("protein_3d_ige")
          )
        ),
        
        tags$div(style = "margin: 40px 0;"),
        
        # ============ ROW 2: IgG4 VISUALIZATION ============
        h4("IgG4 Analysis", style = "color: #191c32; font-weight: bold; margin-bottom: 20px;"),
        
        tags$div(
          class = "row-flex",
          tags$div(
            class = "col-left",
            ggiraph::girafeOutput("protein_snake_igg4", width = "100%", height = "1000px")
          ),
          tags$div(
            class = "col-right",
            htmlOutput("protein_3d_igg4")
          )
        )
      )
    )
  )
}
