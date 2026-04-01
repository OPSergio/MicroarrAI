# ============================================================================
# MicroarrAI - Preprocess Tab UI
# ============================================================================
# Description: Data upload, normalization, and quality control interface
# Dependencies: ui_helpers.R
# ============================================================================

ui_preprocess <- function() {
  tabPanel(
    "Preprocess",
    
    # Floating Sidebar (SAME STYLE AS ML/PEPTIDE)
    tags$div(
      id = "preprocess-sidebar",
      class = "ml-sidebar",
      
      tags$h4(
        icon("cogs", style = "margin-right: 10px;"),
        "Data Preprocessing"
      ),
      
      # Navigation Sections
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "SETUP"),
        
        tags$div(
          class = "ml-sidebar-item active",
          `data-target` = "step1_input_mode",
          icon("upload", style = "margin-right: 10px;"),
          "1. Input Mode"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "step2_data_loading",
          icon("folder-open", style = "margin-right: 10px;"),
          "2. Load Data"
        ),
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "step3_controls",
          icon("sliders-h", style = "margin-right: 10px;"),
          "3. Configure Controls"
        )
      ),
      
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "NORMALIZATION"),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "step4_normalization",
          icon("balance-scale", style = "margin-right: 10px;"),
          "4. Normalization"
        )
      ),
      
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "METADATA"),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "step5_metadata",
          icon("table", style = "margin-right: 10px;"),
          "5. Clinical Data"
        )
      ),
      
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "RESULTS"),
        
        tags$div(
          class = "ml-sidebar-item",
          `data-target` = "step6_preview",
          icon("eye", style = "margin-right: 10px;"),
          "6. Preview & Download"
        )
      ),
      
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "EXAMPLE DATA"),
        
        tags$div(
          style = "padding: 10px;",
          actionButton("load_example_db", 
                     label = tagList(icon("users"), " Load Clinical Data"),
                     style = "width: 100%; margin-bottom: 8px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; padding: 8px;"),
          actionButton("load_example_pep", 
                     label = tagList(icon("dna"), " Load Peptide Data"),
                     style = "width: 100%; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; padding: 8px;")
        )
      )
    ),
    
    # Sidebar Toggle Button
    tags$div(
      id = "preprocess-sidebar-toggle",
      class = "ml-sidebar-toggle",
      icon("bars")
    ),
    
    # Main Content
    tags$div(
      class = "ml-content",
      
      # ===== STEP 1: INPUT MODE =====
      tags$div(
        id = "step1_input_mode",
        style = "margin-top: 20px;",
        
        section_title("STEP 1: SELECT INPUT MODE", size = "2.5em"),
        
        card_container_highlighted(
          style = "margin: 0 15px; padding: 30px;",
          
          fluidRow(
            column(
              12,
              tags$div(
                style = "background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;",
                tags$h5(icon("info-circle"), " What is this step?", style = "color: #191c32; margin-bottom: 10px;"),
                tags$p("Choose how you want to provide your expression data:", style = "color: #191c32;"),
                tags$ul(
                  style = "color: #191c32;",
                  tags$li(tags$b("RAW microarray files:"), " Process GenePix scanner output (CSV files). This gives you full control over normalization and quality filters."),
                  tags$li(tags$b("Processed matrix:"), " Upload pre-normalized data. Skip normalization if you've already processed your data externally.")
                )
              )
            )
          ),
          
          fluidRow(
            column(
              6,
              radioButtons(
                "input_mode",
                label = dark_label("Select Input Mode:"),
                choices = c("RAW microarray files (GenePix)" = "raw",
                           "Processed expression matrix" = "processed"),
                selected = "raw"
              )
            ),
            column(
              6,
              uiOutput("input_mode_info")
            )
          )
        ),
        
        spacer(30)
      ),
      
      # ===== STEP 2: DATA LOADING =====
      tags$div(
        id = "step2_data_loading",
        
        section_title("STEP 2: LOAD YOUR DATA", size = "2.5em"),
        
        card_container_highlighted(
          style = "margin: 0 15px; padding: 30px;",
          
          # Info box
          fluidRow(
            column(
              12,
              tags$div(
                style = "background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;",
                uiOutput("step2_instructions")
              )
            )
          ),
          
          # RAW mode inputs
          conditionalPanel(
            condition = "input.input_mode == 'raw'",
            
            fluidRow(
              column(
                6,
                tags$div(
                  style = "border: 2px dashed #191c32; padding: 20px; border-radius: 8px; text-align: center;",
                  shinyDirButton('directory', 'Select Folder', 'Choose RAW data folder',
                                icon = icon("folder-open"), 
                                style = "font-size: 16px; padding: 12px 30px;"),
                  br(), br(),
                  uiOutput("folder_status")
                )
              ),
              column(
                6,
                tags$div(
                  style = "background: #e8f4f8; padding: 15px; border-radius: 8px; border-left: 4px solid #17a2b8;",
                  tags$h6(icon("lightbulb"), " Tips:", style = "color: #191c32; margin-bottom: 10px;"),
                  tags$ul(
                    style = "color: #191c32; font-size: 14px;",
                    tags$li("All GenePix CSV files should be in one folder"),
                    tags$li("Each file = one two-channel microarray"),
                    tags$li("File names will become sample IDs")
                  )
                )
              )
            )
          ),
          
          # Processed matrix mode inputs
          conditionalPanel(
            condition = "input.input_mode == 'processed'",
            fluidRow(
              column(
                6,
                tags$div(
                  style = "border: 2px dashed #191c32; padding: 20px; border-radius: 8px;",
                  fileInput(
                    "pep_fileinput",
                    buttonLabel = "Browse...",
                    label = dark_label("Upload processed matrix:"),
                    accept = c(".csv", ".xlsx", ".xls")
                  )
                )
              ),
              column(
                6,
                verbatimTextOutput("matrix_validation_status"),
                tags$div(
                  style = "background: #e8f4f8; padding: 15px; border-radius: 8px; border-left: 4px solid #17a2b8; margin-top: 10px;",
                  tags$h6(icon("lightbulb"), " Required format:", style = "color: #191c32;"),
                  tags$ul(
                    style = "color: #191c32; font-size: 14px;",
                    tags$li("Column 1: 'id' with sample names"),
                    tags$li("Other columns: numeric expression values"),
                    tags$li("Optional: channel prefixes (IgE_, IgG4_)")
                  )
                )
              )
            )
          )
        ),
        
        spacer(30)
      ),
      
      # ===== STEP 3: CONFIGURE CONTROLS =====
      tags$div(
        id = "step3_controls",
        
        conditionalPanel(
          condition = "input.input_mode == 'raw'",
          
          section_title("STEP 3: CONFIGURE CONTROLS & CHANNELS", size = "2.5em"),
          
          card_container_highlighted(
            style = "margin: 0 15px; padding: 30px;",
            
            # Info box
            fluidRow(
              column(
                12,
                tags$div(
                  style = "background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;",
                  tags$h5(icon("info-circle"), " What is this step?", style = "color: #191c32; margin-bottom: 10px;"),
                  tags$p("Configure your experimental setup:", style = "color: #191c32;"),
                  tags$ul(
                    style = "color: #191c32;",
                    tags$li(tags$b("Channel labels:"), " Name your antibodies/detection systems (e.g., IgE, IgG4)"),
                    tags$li(tags$b("Negative controls:"), " Select spots used for background/normalization (required for Z-score)"),
                    tags$li(tags$b("Positive controls:"), " Optional reference spots for quality assessment")
                  )
                )
              )
            ),
            
            # Channel configuration
            fluidRow(
              column(
                6,
                tags$h5(icon("tag"), " Channel Labels", style = "color: #191c32; margin-bottom: 15px;"),
                textInput("ch1_label", dark_label("Channel 1 (usually IgE):"), value = "IgE"),
                textInput("ch2_label", dark_label("Channel 2 (usually IgG4):"), value = "IgG4")
              ),
              column(
                6,
                tags$div(
                  style = "background: #fff3cd; padding: 15px; border-radius: 8px; border-left: 4px solid #ffc107;",
                  tags$h6(icon("exclamation-triangle"), " Important:", style = "color: #856404;"),
                  tags$p("These labels will prefix all feature columns in the output (e.g., IgE_p001, IgG4_p001)",
                        style = "color: #856404; font-size: 14px; margin: 0;")
                )
              )
            ),
            
            tags$hr(style = "margin: 25px 0;"),
            
            # Controls selection
            fluidRow(
              column(
                6,
                tags$h5(icon("crosshairs"), " Negative Controls", style = "color: #191c32; margin-bottom: 15px;"),
                tags$div(
                  style = "margin-bottom: 10px;",
                  selectizeInput(
                    "negative_controls",
                    dark_label("Select negative control spots:"),
                    choices = NULL,
                    multiple = TRUE,
                    options = list(
                      placeholder = 'Select controls or use regex below',
                      maxOptions = 1000,
                      maxItems = 1000,
                      plugins = list('remove_button')
                    )
                  ),
                  # Resumen de selección
                  uiOutput("neg_controls_summary")
                ),
                tags$div(
                  style = "margin-top: 10px; display: flex; gap: 5px;",
                  textInput("neg_ctrl_regex", NULL, placeholder = "Regex pattern (e.g., PBS.*|Blank.*)", width = "70%"),
                  actionButton("apply_neg_regex", "Apply", 
                             style = "background: #191c32; color: white; border: none; padding: 6px 15px;")
                ),
                tags$div(
                  style = "background: #e3f2fd; padding: 8px; border-radius: 4px; margin-top: 5px;",
                  tags$small(
                    icon("info-circle"), " Tip: Use ", tags$code("PBS.*"), " to match all PBS variants, or ", tags$code("PBS.*|CREB.*"), " for multiple patterns",
                    style = "color: #1565c0; font-size: 12px;"
                  )
                ),
                tags$div(
                  style = "background: #f8d7da; padding: 10px; border-radius: 4px; border-left: 3px solid #dc3545; margin-top: 10px;",
                  tags$small(icon("asterisk"), " Required for Z-score normalization", style = "color: #721c24;")
                )
              ),
              column(
                6,
                tags$h5(icon("check-circle"), " Positive Controls (Optional)", style = "color: #191c32; margin-bottom: 15px;"),
                tags$div(
                  style = "margin-bottom: 10px;",
                  selectizeInput(
                    "positive_controls",
                    dark_label("Select positive control spots:"),
                    choices = NULL,
                    multiple = TRUE,
                    options = list(
                      placeholder = 'Select controls or use regex below',
                      maxOptions = 1000,
                      maxItems = 1000,
                      plugins = list('remove_button')
                    )
                  ),
                  # Resumen de selección
                  uiOutput("pos_controls_summary")
                ),
                tags$div(
                  style = "margin-top: 10px; display: flex; gap: 5px;",
                  textInput("pos_ctrl_regex", NULL, placeholder = "Regex pattern (e.g., Ctrl.*)", width = "70%"),
                  actionButton("apply_pos_regex", "Apply", 
                             style = "background: #191c32; color: white; border: none; padding: 6px 15px;")
                ),
                tags$div(
                  style = "background: #e3f2fd; padding: 8px; border-radius: 4px; margin-top: 5px;",
                  tags$small(
                    icon("info-circle"), " Tip: Use ", tags$code("IgG.*"), " for all IgG, or ", tags$code("IgG.*|IgA.*"), " for multiple",
                    style = "color: #1565c0; font-size: 12px;"
                  )
                ),
                tags$div(
                  style = "background: #d1ecf1; padding: 10px; border-radius: 4px; border-left: 3px solid #17a2b8; margin-top: 10px;",
                  tags$small(icon("info-circle"), " Used for QC, not normalization", style = "color: #0c5460;")
                )
              )
            )
          ),
          
          spacer(30)
        )
      ),
      
      # ===== STEP 4: NORMALIZATION =====
      tags$div(
        id = "step4_normalization",
        
        conditionalPanel(
          condition = "input.input_mode == 'raw'",
          
          section_title("STEP 4: NORMALIZATION SETTINGS", size = "2.5em"),
          
          card_container_highlighted(
            style = "margin: 0 15px; padding: 30px;",
            
            # Info box
            fluidRow(
              column(
                12,
                tags$div(
                  style = "background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;",
                  tags$h5(icon("info-circle"), " What is this step?", style = "color: #191c32; margin-bottom: 10px;"),
                  tags$p("Choose how to normalize your data:", style = "color: #191c32;"),
                  tags$ul(
                    style = "color: #191c32;",
                    tags$li(tags$b("Intra-sample:"), " Normalizes within each sample using negative controls"),
                    tags$li(tags$b("Inter-sample (optional):"), " Additional normalization across all samples to remove batch effects")
                  )
                )
              )
            ),
            
            fluidRow(
              column(
                6,
                tags$h5(icon("balance-scale"), " Intra-sample Normalization", style = "color: #191c32; margin-bottom: 15px;"),
                selectInput(
                  "normalization_method",
                  dark_label("Method:"),
                  choices = c("Z-score (recommended)" = "Z-score", 
                             "Median Scaling" = "Median Scaling"),
                  selected = "Z-score"
                ),
                tags$div(
                  style = "background: #e8f4f8; padding: 12px; border-radius: 4px; margin-top: 10px;",
                  uiOutput("normalization_method_description")
                )
              ),
              column(
                6,
                tags$h5(icon("project-diagram"), " Inter-sample Normalization", style = "color: #191c32; margin-bottom: 15px;"),
                checkboxInput("enable_inter_norm", "Enable inter-sample normalization", FALSE),
                conditionalPanel(
                  condition = "input.enable_inter_norm == true",
                  selectInput(
                    "inter_norm_method",
                    dark_label("Method:"),
                    choices = c("Robust Scaling (recommended)" = "robust", 
                               "Centering" = "center",
                               "Quantile (use with caution)" = "quantile"),
                    selected = "robust"
                  ),
                  tags$div(
                    style = "background: #fff3cd; padding: 10px; border-radius: 4px; border-left: 3px solid #ffc107; margin-top: 10px;",
                    tags$small(icon("exclamation-triangle"), " Quantile normalization may alter biological signal distributions",
                              style = "color: #856404;")
                  )
                )
              )
            ),
            
            tags$hr(style = "margin: 25px 0;"),
            
            fluidRow(
              column(
                12,
                style = "text-align: center;",
                actionButton("process_button", 
                           label = tagList(icon("play-circle"), " Start Normalization Process"),
                           style = "font-size: 18px; padding: 15px 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 8px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);")
              )
            )
          ),
          
          spacer(30)
        )
      ),
      
      # ===== STEP 5: METADATA =====
      tags$div(
        id = "step5_metadata",
        
        section_title("STEP 5: CLINICAL METADATA", size = "2.5em"),
        
        card_container_highlighted(
          style = "margin: 0 15px; padding: 30px;",
          
          # Info box
          fluidRow(
            column(
              12,
              tags$div(
                style = "background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;",
                tags$h5(icon("info-circle"), " What is this step?", style = "color: #191c32; margin-bottom: 10px;"),
                tags$p("Upload and configure your clinical/experimental metadata:", style = "color: #191c32;"),
                tags$ul(
                  style = "color: #191c32;",
                  tags$li("Must include sample IDs matching your expression data"),
                  tags$li("Should include your target/grouping variable (e.g., treatment, disease status)"),
                  tags$li("Can include additional covariates (age, sex, etc.)")
                )
              )
            )
          ),
          
          fluidRow(
            column(
              6,
              tags$div(
                style = "border: 2px dashed #191c32; padding: 20px; border-radius: 8px;",
                fileInput(
                  "db_fileinput",
                  buttonLabel = "Browse...",
                  label = dark_label("Upload clinical database:"),
                  accept = c(".csv", ".xlsx", ".xls")
                ),
                tags$a(
                  href = "#",
                  id = "advanced_metadata_upload",
                  style = "margin-top: 10px; cursor: pointer; color: #007bff;",
                  onclick = "event.preventDefault(); Shiny.setInputValue('toggle_advanced_upload', Math.random());",
                  icon("cog"), " Advanced Upload Options"
                )
              )
            ),
            column(
              6,
              tags$div(
                style = "background: #e8f4f8; padding: 15px; border-radius: 8px; border-left: 4px solid #17a2b8;",
                tags$h6(icon("lightbulb"), " Tips:", style = "color: #191c32; margin-bottom: 10px;"),
                tags$ul(
                  style = "color: #191c32; font-size: 14px;",
                  tags$li("First column should be 'id' with sample names"),
                  tags$li("Sample IDs must match expression data"),
                  tags$li("Use clear column names"),
                  tags$li("Remove special characters from headers")
                )
              ),
              verbatimTextOutput("data_status_db")
            )
          ),
          
          # Advanced upload modal placeholder
          conditionalPanel(
            condition = "input.toggle_advanced_upload > 0",
            tags$div(
              id = "advanced_upload_panel",
              style = "margin-top: 20px; padding: 20px; background: #f8f9fa; border-radius: 8px;",
              
              tags$h5(icon("sliders-h"), " Advanced Upload Options", style = "color: #191c32; margin-bottom: 15px;"),
              
              fluidRow(
                column(
                  4,
                  selectInput("csv_separator", 
                             dark_label("CSV Separator:"),
                             choices = c("Comma (,)" = ",", 
                                       "Semicolon (;)" = ";",
                                       "Tab" = "\t"),
                             selected = ",")
                ),
                column(
                  4,
                  checkboxInput("csv_header", "First row is header", value = TRUE)
                ),
                column(
                  4,
                  selectInput("csv_encoding",
                             dark_label("File encoding:"),
                             choices = c("UTF-8" = "UTF-8",
                                       "Latin1" = "latin1",
                                       "Windows-1252" = "Windows-1252"),
                             selected = "UTF-8")
                )
              )
            )
          ),
          
          # Metadata configuration and editing
          conditionalPanel(
            condition = "output.data_status_db",
            
            tags$hr(style = "margin: 25px 0;"),
            
            fluidRow(
              column(
                6,
                selectInput("sample_id_col", 
                           dark_label("Sample ID Column:"), 
                           choices = NULL)
              ),
              column(
                6,
                selectInput("target_col", 
                           dark_label("Target Variable Column:"), 
                           choices = NULL)
              )
            ),
            
            tags$hr(style = "margin: 25px 0;"),
            
            tags$h5(icon("edit"), " Edit Metadata (click cells to modify)", 
                   style = "color: #191c32; margin-bottom: 15px;"),
            
            # Find & Replace panel
            tags$div(
              style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 8px; padding: 15px; margin-bottom: 15px; color: white;",
              tags$h6(icon("search"), " Find & Replace", style = "color: white; margin-bottom: 10px;"),
              fluidRow(
                column(
                  3,
                  selectInput("replace_column", "Column:", choices = NULL, width = "100%")
                ),
                column(
                  3,
                  textInput("find_text", "Find:", placeholder = "Text to find", width = "100%")
                ),
                column(
                  3,
                  textInput("replace_text", "Replace with:", placeholder = "New text", width = "100%")
                ),
                column(
                  3,
                  br(),
                  actionButton("apply_find_replace", "Replace All", 
                             style = "background: white; color: #667eea; border: none; padding: 8px 20px; width: 100%; font-weight: bold;")
                )
              )
            ),
            
            rhandsontable::rHandsontableOutput("metadata_table", height = 400),
            
            br(),
            
            fluidRow(
              column(
                6,
                actionButton("apply_metadata_edits", 
                           label = tagList(icon("check"), " Apply Changes"),
                           style = "width: 100%; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; padding: 10px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);")
              ),
              column(
                6,
                actionButton("revert_metadata_edits", 
                           label = tagList(icon("undo"), " Revert Changes"),
                           style = "width: 100%; background: #191c32; color: white; border: none; padding: 10px;")
              )
            )
          )
        ),
        
        spacer(30)
      ),
      
      # ===== STEP 6: PREVIEW & DOWNLOAD =====
      tags$div(
        id = "step6_preview",
        
        section_title("STEP 6: PREVIEW & DOWNLOAD", size = "2.5em"),
        
        card_container_highlighted(
          style = "margin: 0 15px; padding: 30px;",
          
          # Info box
          fluidRow(
            column(
              12,
              tags$div(
                style = "background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;",
                tags$h5(icon("info-circle"), " What is this step?", style = "color: #191c32; margin-bottom: 10px;"),
                tags$p("Review your processed data and download the complete results package.", style = "color: #191c32;")
              )
            )
          ),
          
          # Data status
          fluidRow(
            column(
              12,
              verbatimTextOutput("data_status_pep")
            )
          ),
          
          tags$hr(style = "margin: 25px 0;"),
          
          # Expression Data Preview
          tags$h5(icon("table"), " Expression Data Preview", style = "color: #191c32; margin-bottom: 15px;"),
          DT::DTOutput("data_table"),
          
          tags$hr(style = "margin: 25px 0;"),
          
          # Density Plot
          tags$h5(icon("chart-area"), " Quality Control: Density Plot", style = "color: #191c32; margin-bottom: 15px;"),
          plotOutput("density_plot", height = "400px"),
          
          tags$hr(style = "margin: 25px 0;"),
          
          # Download button
          fluidRow(
            column(
              6,
              style = "text-align: center;",
              downloadButton("download_button", 
                           label = "Download Complete Dataset (Excel)",
                           style = "font-size: 16px; padding: 12px 30px; background: #191c32; color: white; border: none; border-radius: 8px;")
            ),
            column(
              6,
              style = "text-align: center;",
              actionButton("finish_preprocess", 
                         label = tagList(icon("rocket"), " Finish Preprocess & Continue"),
                         style = "font-size: 16px; padding: 12px 30px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 8px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);")
            )
          )
        )
      )
    )
  )
}
