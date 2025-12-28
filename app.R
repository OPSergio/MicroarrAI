# ============================================================================
# MicroarrAI - Main Application Entry Point
# ============================================================================
# Description: Shiny application for peptide microarray analysis
# Author: Sergio Olmos Piñero, Val Fernández Lanza, et al.
# ============================================================================

# Load global configuration, libraries, and utility functions
source("R/global.R")


########################### UI ##############################################
ui <- fluidPage(
  # ===== Head: Metadata & External Resources =====
  tags$head(
    tags$title("MicroarrAI"),
    tags$link(rel = "icon", type = "image/png", href = "assets/logov2.png")
  ),
  
  # ===== Shiny Extensions =====
  useShinyjs(),
  
  # ===== Bootstrap Theme =====
  theme = bs_theme(
    fg = "#191c32", 
    primary = "#191c32", 
    font_scale = NULL, 
    `enable-gradients` = TRUE, 
    `enable-shadows` = TRUE, 
    bg = "#ffffff"
  ),
  
  # ===== External Stylesheets & Scripts =====
  includeCSS("www/styles.css"),
  includeScript("www/custom.js"),
  
  # ===== Title Panel with Logo =====
  titlePanel(
    fluidRow(
      class = "title",
      column(
        12,
        tags$div(
          tags$img(src = "assets/logov2.png", class = "logo_app"),
          class = "logo-container"
        )
      )
    )
  ),
  
  # ===== Tab Navigation =====
  tabsetPanel(
    ui_home(),
    ui_preprocess(),
    ui_peptide(),
    ui_ml(),
    ui_2d_visualization(),
    ui_3d_visualization()
  
  )# Cierre del body
) # Cierre del UI


server <- function(input, output, session){
  
  ########################### INDEX ###########################################
  volumes <- getVolumes()()
  shinyDirChoose(input, 'directory', roots=volumes, session=session)
  
  path1 <- reactive({
    parseDirPath(volumes, input$directory)
  })
  
  raw_data <- reactiveVal(NULL)
  processed_data <- reactiveVal(NULL)
  database <- reactiveVal(NULL)
  pepdata <- reactiveVal(NULL)
  
##### Preprocesado de datos ####
  observeEvent(input$process_button, {
    req(path1())
    
    files <- list.files(path = path1(), pattern = "\\.csv$", full.names = TRUE)
    
    withProgress(message = 'Processing files...', value = 0, {
      processed_data(
        process_microarray_batch(
          files, 
          input$normalization_method,
          progress_callback = function(i, total, name) {
            incProgress(1/total, detail = paste("Sample", name, "complete"))
          }
        )
      )
    })
  })
  
  observeEvent(input$scale_button, {
    req(processed_data())
    scaled_data <- processed_data() %>%
      mutate(across(where(is.numeric), scale))
    processed_data(scaled_data)
  })
  
  
  ##### Descargar los datos en Excel ####
  output$download_button <- downloadHandler(
    filename = function() {
      paste("normalized_data_", Sys.Date(), ".xlsx", sep = "")
    },
    content = function(file) {
      openxlsx::write.xlsx(processed_data(), file, rowNames = FALSE)
    }
  )
  
  
  output$data_table <- renderDT({
    req(processed_data())
    datatable(processed_data(), style="bootstrap4",
              options = list(
                scrollY = "250px",
                pageLength = 5,
                lengthMenu = c(5, 10, 15, 20)
              ))
  })
  
  output$density_plot <- renderPlot({
    req(processed_data())
    
    data_long <- tidyr::pivot_longer(processed_data(), cols = -id, names_to = "ID", values_to = "MExpression")
    
    unique_ids <- unique(data_long$ID)
    selected_ids <- sample(unique_ids, size = min(20, length(unique_ids)))
    
    data_filtered <- data_long %>%
      dplyr::filter(ID %in% selected_ids)
    
    ggplot(data_filtered, aes(x = MExpression, y = ID, fill = ID)) +
      ggridges::geom_density_ridges(scale = 1) +
      theme_microarrai() +
      scale_fill_viridis_d(option = "mako") + 
      theme(legend.position = "none") +  # Eliminar la leyenda
      labs(title = "Density Plot of Normalized Expression (20 Variables)", x = "Normalized Expression", y = "Variable (ID)")
  })
  
  #### Fin preprocesado ####
  
  observeEvent(input$load_example_db, {
    req(input$load_example_db)  # Asegura que el botón fue presionado
    
    num_patients <- 130  # Definir aquí si no es accesible globalmente
    
    # 🔹 Crear base de datos de ejemplo
    example_db <- data.frame(
      id = paste0("Patient_", 1:num_patients),
      Age = sample(30:80, num_patients, replace = TRUE),
      Sex = sample(c("Male", "Female"), num_patients, replace = TRUE),
      CRP = runif(num_patients, 0.5, 15),  
      IL6 = runif(num_patients, 2, 100),   
      BMI = runif(num_patients, 18.5, 35),  
      Glucose = runif(num_patients, 70, 140),  
      Cholesterol = runif(num_patients, 150, 250),  
      Blood_Pressure = runif(num_patients, 100, 180),  
      Liver_Enzymes = runif(num_patients, 10, 50),  
      Target = sample(c("Tratamiento 1", "Tratamiento 2", "Tratamiento 3"), num_patients, replace = TRUE)  
    )
    
    # 🔹 Asegurar que la base de datos tiene datos antes de asignarla
    if (nrow(example_db) > 0) {
      database(example_db)  # Asigna la base de datos reactiva
    } else {
      stop("Error: No se pudo generar la base de datos de ejemplo.")
    }
  })
  
  observeEvent(input$db_fileinput, {
    req(input$db_fileinput)
    
    database(NULL)
    
    df <- readxl::read_excel(input$db_fileinput$datapath)

    if (!is.null(df) && nrow(df) > 0) {
      database(df) 
    } else {
      stop("Error: Data base is empty.")
    }
  })
  
  ##### Mostrar estado de la base de datos clínica #####
  output$data_status_db <- renderText({
    if (is.null(database())) {
      "No hay datos clínicos cargados."
    } else {
      paste("Rows:", nrow(database()), "Columns:", ncol(database()))
    }
  })
  
  

  ## Peptide tab
  pepdata <- reactive({
    file <- input$pep_fileinput
    files <- list.files(path = path1(), pattern = "\\.csv$", full.names = TRUE)
    
    if (is.null(file) && length(files) == 0 && input$load_example_pep == 0) {
      stop("Please upload a valid format.")
    }
    
    # Priority 1: Use processed microarray data
    if (length(files) > 0 && !is.null(processed_data())) {
      data <- processed_data()
    } 
    # Priority 2: Use uploaded Excel file
    else if (!is.null(file)) {
      data <- readxl::read_excel(file$datapath)
    } 
    # Priority 3: Generate synthetic example data
    else if (input$load_example_pep > 0) {
      data <- generate_synthetic_peptide_data(
        num_patients = 130,
        num_peptides = 180,
        num_markers = 15,
        database = database()
      )
    } else {
      stop("No valid data source found.")
    }

    # Clean column names and remove NA rows
    colnames(data) <- make.names(colnames(data))
    data <- na.omit(data)
    
    return(data)
  })
  
  output$data_status_pep <- renderText({
    if (is.null(pepdata())) {
      "No hay datos de péptidos cargados."
    } else {
      paste("Rows:", nrow(pepdata()), "Columns:", ncol(pepdata()))
    }
  })
 
  
  
  output$peptide_hplot <- renderPlot({
    req(pepdata())
    
    # Convert to numeric matrix
    mat <- prepare_matrix(pepdata(), row_col = "id")
    
    # Limit to 300 features for performance
    mat_sampled <- sample_heatmap_features(mat, max_features = 300, seed = 123)
    
    iso <- split_isotype_mats(mat_sampled)
    
    # Define color palette with app background for 0 values
    ige_colors <- colorRampPalette(c("#191c32","lightgreen", "green"))(50)
    igg4_colors <- colorRampPalette(c("#191c32", "#fd6b6bff", "red"))(50)
    default_colors <- colorRampPalette(c("#191c32", "lightgreen", "green"))(50)
    
    if (iso$any_iso) {
      ht_list <- NULL
      if (!is.null(iso$ige) && ncol(iso$ige) > 0) {
        ht_ige <- ComplexHeatmap::Heatmap(
          iso$ige, name = "IgE",
          col = ige_colors,
          cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
          show_column_names = FALSE,
          show_row_names = FALSE,
          row_dend_gp = grid::gpar(col = "white"),
          column_dend_gp = grid::gpar(col = "white"),
          heatmap_legend_param = list(
            border = "white",
            title_gp = grid::gpar(fontsize = 10, fontface = "bold", col = "white"),
            labels_gp = grid::gpar(fontsize = 9, col = "white")
          )
        )
        ht_list <- ht_ige
      }
      if (!is.null(iso$igg4) && ncol(iso$igg4) > 0) {
        ht_igg4 <- ComplexHeatmap::Heatmap(
          iso$igg4, name = "IgG4",
          col = igg4_colors,  
          cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
          show_column_names = FALSE,
          show_row_names = FALSE,
          row_dend_gp = grid::gpar(col = "white"),
          column_dend_gp = grid::gpar(col = "white"),
          heatmap_legend_param = list(
            border = "white",
            title_gp = grid::gpar(fontsize = 10, fontface = "bold", col = "white"),
            labels_gp = grid::gpar(fontsize = 9, col = "white")
          )
        )
        ht_list <- if (is.null(ht_list)) ht_igg4 else (ht_list + ht_igg4)
      }
      ComplexHeatmap::draw(
        ht_list, 
        heatmap_legend_side = "right",
        background = "transparent"
      )
    } else {
      ht <- ComplexHeatmap::Heatmap(
        mat_sampled, name = "Expression",
        col = default_colors,
        cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
        show_column_names = FALSE,
        show_row_names = FALSE,
        row_dend_gp = grid::gpar(col = "white"),
        column_dend_gp = grid::gpar(col = "white"),
        heatmap_legend_param = list(
          border = "white",
          title_gp = grid::gpar(fontsize = 10, fontface = "bold", col = "white"),
          labels_gp = grid::gpar(fontsize = 9, col = "white")
        )
      )
      ComplexHeatmap::draw(
        ht, 
        heatmap_legend_side = "right",
        background = "transparent"
      )
    }
  }, bg = "transparent")
  outputOptions(output, "peptide_hplot", suspendWhenHidden = FALSE)
  
  
  # ========== GLOBAL SUMMARY PANEL ==========
  
  # Calculate summary statistics
  peptide_summary <- reactive({
    req(pepdata())
    req(input$zscore_threshold)
    calculate_peptide_summary(pepdata(), expression_threshold = input$zscore_threshold)
  })
  
  # Isotype donut chart
  output$isotype_donut <- renderPlotly({
    req(peptide_summary())
    create_isotype_donut_chart(peptide_summary()$isotype_summary)
  })
  
  # Expression distribution plot
  output$expression_dist_plot <- renderPlotly({
    req(pepdata())
    create_expression_distribution_plot(pepdata())
  })
  
  # KPI value boxes
  output$kpi_boxes <- renderUI({
    req(peptide_summary())
    kpi_data <- create_summary_value_boxes(peptide_summary())
    
    # Icons for each KPI
    kpi_icons <- c("users", "dna", "chart-line", "chart-area", "plus-circle", "arrows-alt-h")
    
    # KPI cards
    fluidRow(
        lapply(1:nrow(kpi_data), function(i) {
          column(
            width = 2,
            div(
              style = paste0(
                "background: white;",
                "border-radius: 12px;",
                "padding: 20px 15px;",
                "margin-bottom: 15px;",
                "min-height: 120px;",
                "box-shadow: 0 4px 15px rgba(0,0,0,0.1);",
                "transition: transform 0.3s ease, box-shadow 0.3s ease;",
                "position: relative;",
                "overflow: hidden;"
              ),
              # Icon background decoration
              div(
                style = "position: absolute; right: -10px; top: -10px; opacity: 0.03; font-size: 60px; color: #191c32;",
                tags$i(class = paste0("fa fa-", kpi_icons[i]))
              ),
              # Content
              div(
                style = "position: relative; z-index: 2;",
                tags$div(
                  style = "align-items: center; margin-bottom: 10px;",
                  icon(kpi_icons[i], style = "font-size: 18px; color: #191c32; margin-right: 8px;"),
                  tags$span(kpi_data$Metric[i], style = "font-size: 14px; color: #191c32; font-weight: 600;")
                ),
                tags$div(
                  style = "font-size: 32px; font-weight: bold; color: #191c32; margin: 5px 0;",
                  kpi_data$Value[i]
                )
              )
            )
          )
        })
      )
  })
  
  # ========== Threshold Info Panel ==========
  output$threshold_info_panel <- renderUI({
    req(input$zscore_threshold)
    div(
      style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 8px; padding: 15px; margin-top: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);",
      tags$p(
        style = "margin: 0; color: white; font-size: 16px;",
        tags$i(class = "fa fa-info-circle", style = "margin-right: 10px;"),
        tags$strong("Expression Threshold: "), 
        input$zscore_threshold,
        " | Peptides with expression > ",
        input$zscore_threshold,
        " are considered positive"
      )
    )
  })
  
  # Styled summary table (top samples)
  output$top_samples_table <- DT::renderDataTable({
    req(peptide_summary())
    table_data <- create_styled_summary_table(peptide_summary()$per_sample, top_n = 10)
    
    DT::datatable(
      table_data,
      options = list(
        dom = 't',
        ordering = TRUE,
        pageLength = 10,
        scrollX = TRUE,
        scrollY = "250px",
        scrollCollapse = TRUE,
        columnDefs = list(
          list(className = 'dt-center', targets = '_all')
        )
      ),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        'Positive Peptides',
        background = DT::styleColorBar(range(table_data$`Positive Peptides`), '#667eea'),
        backgroundSize = '100% 90%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  # Isotype summary table
  output$isotype_table <- DT::renderDataTable({
    req(peptide_summary())
    isotype_data <- peptide_summary()$isotype_summary %>%
      mutate(
        mean_expression = round(mean_expression, 2),
        median_expression = round(median_expression, 2),
        percentage = round(n_peptides / sum(n_peptides) * 100, 1)
      ) %>%
      dplyr::select(Isotype, `N Peptides` = n_peptides, `Percentage (%)` = percentage,
                    `Mean Expr` = mean_expression, `Median Expr` = median_expression)
    
    DT::datatable(
      isotype_data,
      options = list(
        dom = 't',
        ordering = FALSE,
        pageLength = 10
      ),
      rownames = FALSE
    )
  })
  
  
  output$stats_var <- renderUI({
    req(database())
    selectInput("stats", 
                label = tags$span(style = "color: #191c32;", "Choose grouping var to analysis"),
                choices = colnames(meta_data() %>% 
                                     dplyr::select((ncol(pepdata()) +1):ncol(meta_data())) %>% 
                                     as.data.frame())) 
  })

  
  ####### Peptide #####
  shinyjs::hide("stats_div")
  shinyjs::hide("feature_level_div")
  shinyjs::hide("loader")
  shinyjs::hide("results_summary_div")
  
  observeEvent(input$run_analysis_1, {
    # Mostrar el loader cuando se hace clic en el botón de análisis
    shinyjs::show("loader")
    
    # Condicional para ejecutar sólo si se selecciona la opción correcta
    if (input$analysis_type == "Comparison between groups (Classification)") {
      req(tests())  
      req(reg_models())
      
      # Después de 3 segundos, ocultar el loader y mostrar los divs
      Sys.sleep(3)
      shinyjs::hide("loader")
      shinyjs::show("stats_div")
      shinyjs::show("feature_level_div")
      shinyjs::show("volcano_div")
      shinyjs::show("results_filters_div")
      shinyjs::show("results_summary_div")
      shinyjs::show("funnel_div")
      
      
    } else {
      showNotification("The selected analysis option is not yet implemented.", type = "error")
      shinyjs::hide("loader")  # Asegurarse de ocultar el loader si hay error
    }
  })
  

  tests <- eventReactive(input$run_analysis_1, {
    req(input$analysis_type == "Comparison between groups (Classification)")  
    req(pepdata(), database())
    
    # Always use Linear Model-based differential analysis
    lm_results <- perform_lm_differential_analysis(
      peptide_data = pepdata(),
      clinical_data = database(),
      target_variable = input$stats,
      test_method = "lm"  # Always LM as primary method
    )
    
    # If contrast test is requested, also run it
    if (!is.null(input$add_contrast_test) && input$add_contrast_test == TRUE) {
      contrast_results <- perform_lm_differential_analysis(
        peptide_data = pepdata(),
        clinical_data = database(),
        target_variable = input$stats,
        test_method = input$contrast_method  # Will be "anova" or "kruskal"
      )
      
      # Add contrast p-values as additional columns
      lm_results <- lm_results %>%
        left_join(
          contrast_results %>% select(peptide, contrast_p = p, contrast_p.adj = p.adj),
          by = "peptide"
        )
    }
    
    return(lm_results)
  })
  
  tests_filtered <- reactive({
    req(tests())
    req(input$results_pval_threshold)
    
    filtered <- filter_biomarkers(
      stats_results = tests(),
      pval_raw_threshold = 0.05,
      pval_adj_threshold = input$results_pval_threshold
    )
    
    # Ensure consistent column names: rename p.value -> p
    if ("p.value" %in% names(filtered) && !"p" %in% names(filtered)) {
      filtered <- filtered %>% rename(p = p.value)
    }
    
    # Note: log2FC and status are contrast-specific (calculated in volcano plot)
    # They don't belong to the peptide itself, only to a 2-group comparison
    
    return(filtered)
  })
  
  
  output$stats_table <- DT::renderDataTable({
    req(tests_filtered())
    
    # Format table with rounded p-values
    table_data <- tests_filtered() %>%
      as.data.frame()
    
    # Round numeric columns safely
    if ("p" %in% names(table_data)) {
      table_data$p <- round(as.numeric(table_data$p), 4)
    }
    if ("p.adj" %in% names(table_data)) {
      table_data$p.adj <- round(as.numeric(table_data$p.adj), 4)
    }
    if ("log2FC" %in% names(table_data)) {
      table_data$log2FC <- round(as.numeric(table_data$log2FC), 4)
    }
    
    # If contrast columns exist, round them too
    if ("contrast_p" %in% names(table_data)) {
      table_data$contrast_p <- round(as.numeric(table_data$contrast_p), 4)
      table_data$contrast_p.adj <- round(as.numeric(table_data$contrast_p.adj), 4)
    }
    
    DT::datatable(
      table_data,
      options = list(
        scrollY = "250px",
        pageLength = 5,
        lengthMenu = c(5, 10, 15, 20)
      ),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        'p.adj',
        background = DT::styleColorBar(c(0, max(table_data$p.adj, na.rm = TRUE)), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  # ========== Unified Stats Table (DEG + Regression) ==========
  output$unified_stats_table <- DT::renderDataTable({
    req(tests_filtered(), reg_models())
    
    # Merge stats and regression tables (without log2FC - that's contrast-specific)
    stats_data <- tests_filtered() %>%
      as.data.frame() %>%
      select(peptide, p, p.adj)
    
    reg_data <- reg_models() %>%
      as.data.frame() %>%
      select(Peptide, Method, Accuracy, AUC, F1, Recall) %>%
      rename(peptide = Peptide)
    
    unified_data <- stats_data %>%
      left_join(reg_data, by = "peptide") %>%
      select(Peptide = peptide, Method, `P-value` = p, `P-adj` = p.adj, 
             Accuracy, AUC, F1, Recall) %>%
      mutate(
        `P-value` = round(as.numeric(`P-value`), 4),
        `P-adj` = round(as.numeric(`P-adj`), 4),
        Accuracy = round(as.numeric(Accuracy), 2),
        AUC = round(as.numeric(AUC), 2),
        F1 = round(as.numeric(F1), 2),
        Recall = round(as.numeric(Recall), 2)
      )
    
    DT::datatable(
      unified_data,
      options = list(
        scrollY = "600px",
        scrollX = TRUE,
        pageLength = 15,
        lengthMenu = c(10, 25, 50),
        columnDefs = list(
          list(className = 'dt-center', targets = '_all')
        )
      ),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        'P-adj',
        background = DT::styleColorBar(c(0, max(unified_data$`P-adj`, na.rm = TRUE)), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      ) %>%
      DT::formatStyle(
        'AUC',
        background = DT::styleColorBar(c(0, 1), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      ) %>%
      DT::formatStyle(
        'F1',
        background = DT::styleColorBar(c(0, 1), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      ) %>%
      DT::formatStyle(
        'Accuracy',
        background = DT::styleColorBar(c(0, 1), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      ) %>%
      DT::formatStyle(
        'Recall',
        background = DT::styleColorBar(c(0, 1), '#667eea'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  ### Boxplots + p-value
  output$stats_var_plot <- renderUI({
    req(tests_filtered())
    df <- tests_filtered()
    req(database())
    selectInput("stats_plot_var", "Grouping var",
                choices = df$peptide) 
  })
  
  
  output$stats_plot <- renderPlotly({
    req(tests_filtered(), input$stats_plot_var)
    peps <- pepdata()
    tmp1 <- database()
    meta <- peps %>% inner_join(tmp1)
    testt <- tests_filtered()
    df <- meta
    df <- df %>% rename(target = !!rlang::sym(input$stats)) %>% dplyr::select(id,target)
    df2 <- meta %>% dplyr::select(1:ncol(peps))
    df3 <- df %>% inner_join(df2) %>% dplyr::select(-id) %>% 
      pivot_longer(names_to = "pep", values_to = "Expression", cols = -target)
    
    # Validate that stats_plot_var exists in data
    if (!input$stats_plot_var %in% unique(df3$pep)) {
      return(plotly::plot_ly())
    }
    
    # Create ggplot
    p <- df3 %>% filter(pep == input$stats_plot_var) %>% 
      ggplot(aes(x= as.factor(target), y= Expression, color = target,
                 fill = target)) +
      geom_point(size=2,
                 alpha= 0.7,
                 position=position_jitter(width = .1)) +
      geom_boxplot(lwd = 0.8,
                   width= 0.3,
                   alpha= 0,
                   outlier.color="red",
                   outlier.fill="red",
                   outlier.size=5) +
      labs(subtitle = input$stats_plot_var) +
      xlab("") +
      stat_boxplot(geom= "errorbar", width= 0.2, alpha= .6) +
      geom_violin(alpha= .1, lwd= 0.5, width= .6, alpha= .6) +
      theme_microarrai() +
      scale_color_microarrai() +
      scale_fill_microarrai()
    
    # Convert to plotly for interactivity
    plotly::ggplotly(p, tooltip = c("x", "y"))
  })
  #################### Logistic regression ####################################
  
  reg_models <- eventReactive(input$run_analysis_1,{
    req(input$analysis_type == "Comparison between groups (Classification)")
    req(pepdata())  
    req(database()) 
    req(tests_filtered())
    
    testt <- tests_filtered() %>% as.data.frame()
    peps <- pepdata()
    tmp1 <- database()
    meta <- peps %>% inner_join(tmp1)
    df <- tmp1 %>% rename(target = !!rlang::sym(input$stats)) %>% dplyr::select(id,target)
    df2 <- meta %>% dplyr::select(1:ncol(peps))
    df3 <- df %>% inner_join(df2) %>% dplyr::select(-id) %>% 
      mutate(target = as.factor(target)) %>% 
      pivot_longer(names_to = "pep", values_to = "Expression", cols = -target)
    
    perfor <- data.frame()
    nlevels_target <- nlevels(as.factor(df3$target))
    
    for (i in testt$peptide) {
      M <- df3 %>% filter(pep == i) %>% filter(!is.na(Expression))
      
      # Use modular regression functions
      if (nlevels_target > 2) {
        # Multinomial regression
        result <- fit_multinomial_regression(
          expression_data = M$Expression,
          target = M$target
        )
        Method <- "Multinomial logistic"
      } else {
        # Binary GLM
        result <- fit_binary_glm(
          expression_data = M$Expression,
          target = M$target
        )
        Method <- "Logistic regression (GLM)"
      }
      
      # Calculate performance metrics
      metrics <- calculate_performance_metrics(
        predictions = result$predictions,
        actual = M$target,
        probabilities = if (nlevels_target > 2) result$probabilities else result$probabilities[, 2]
      )
      
      perfor <- bind_rows(perfor, data.frame(
        i = i,
        Method = Method,
        Accuracy = round(metrics$accuracy, 2),
        AUC = round(metrics$auc, 2),
        F1 = round(metrics$f1, 2),
        Recall = round(metrics$recall, 2)
      ))
    }
    
    perfor %>% rename(Peptide = i)
  })
  
  
  output$reg_table <- DT::renderDataTable({
    req(tests_filtered())
    table <- reg_models() %>% 
      as.data.frame() %>%
      mutate(
        Accuracy = round(Accuracy, 4),
        AUC = round(AUC, 4),
        F1 = round(F1, 4),
        Recall = round(Recall, 4)
      )
    rownames(table) <- NULL
    
    DT::datatable(
      table,
      options = list(
        scrollY = "250px",
        pageLength = 5,
        lengthMenu = c(5, 10, 15, 20)
      ),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        'AUC',
        background = DT::styleColorBar(c(0, 1), '#4facfe'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  # -------- Helpers volcano --------
  volcano_colors <- c(
    Up   = MICROARRAI_COLORS[2],  # verde corporativo
    Down = MICROARRAI_COLORS[6],  # rojo corporativo
    NS   = "#9CA3AF"              # gris
  )
  
  # Variable de agrupación (solo factores/char de la base clínica)
  output$volcano_group_var_ui <- renderUI({
    req(database())
    db <- database()
    facs <- names(db)[vapply(db, function(x) is.factor(x) || is.character(x), logical(1))]
    facs <- setdiff(facs, "id")
    selectInput("volcano_group_var", dark_label("Contrast Variable:"), choices = facs)
  })
  
  # Niveles A y B (contraste binario)
  output$volcano_level_a_ui <- renderUI({
    req(database(), input$volcano_group_var)
    lv <- levels(as.factor(database()[[input$volcano_group_var]]))
    selectInput("volcano_level_a", dark_label("Group A (numerator):"), choices = lv)
  })
  output$volcano_level_b_ui <- renderUI({
    req(database(), input$volcano_group_var)
    lv <- levels(as.factor(database()[[input$volcano_group_var]]))
    sel <- if (length(lv) >= 2) lv[min(2, length(lv))] else lv[1]
    selectInput("volcano_level_b", dark_label("Group B (denominator):"), choices = lv, selected = sel)
  })
  
  # Tabla base para volcano (1 o 2 isotipos)
  volcano_tbl <- reactive({
    req(pepdata(), database(),
        input$volcano_group_var, input$volcano_level_a, input$volcano_level_b)
    validate(need(input$volcano_level_a != input$volcano_level_b,
                  "Choose levels"))
    
    # merge pep + clínica y filtra contraste binario
    dat <- dplyr::inner_join(pepdata(), database(), by = "id") %>%
      dplyr::filter(.data[[input$volcano_group_var]] %in% c(input$volcano_level_a, input$volcano_level_b)) %>%
      dplyr::mutate(.grp = factor(.data[[input$volcano_group_var]],
                                  levels = c(input$volcano_level_a, input$volcano_level_b)))
    
    # columnas peptídicas numéricas
    pep_cols <- setdiff(names(pepdata()), "id")
    is_num   <- vapply(pepdata()[pep_cols], is.numeric, logical(1))
    pep_cols <- pep_cols[is_num]
    
    # detección de prefijos
    has_ige  <- any(grepl("^IgE_",  pep_cols))
    has_igg4 <- any(grepl("^IgG4_", pep_cols))
    has_iso  <- has_ige || has_igg4
    
    # columnas elegidas
    if (has_iso) {
      # respetar el filtro del UI (mezclar = seleccionar los dos)
      iso_pat <- paste0("^(", paste(input$volcano_isotypes, collapse = "|"), ")_")
      chosen  <- grep(iso_pat, pep_cols, value = TRUE)
      if (length(chosen) == 0) {
        # si el usuario desmarca todo, no bloqueamos: usamos todas las que tengan prefijo
        chosen <- c(grep("^IgE_", pep_cols,  value = TRUE),
                    grep("^IgG4_", pep_cols, value = TRUE))
      }
      long <- dat %>%
        dplyr::select(id, .grp, dplyr::all_of(chosen)) %>%
        tidyr::pivot_longer(cols = dplyr::all_of(chosen),
                            names_to = "peptide", values_to = "expr") %>%
        dplyr::mutate(
          expr    = suppressWarnings(as.numeric(expr)),
          isotype = sub("^([^_]+).*", "\\1", peptide)  # IgE / IgG4
        )
    } else {
      # fallback solicitado: mezclar todas las features
      chosen <- pep_cols
      long <- dat %>%
        dplyr::select(id, .grp, dplyr::all_of(chosen)) %>%
        tidyr::pivot_longer(cols = dplyr::all_of(chosen),
                            names_to = "peptide", values_to = "expr") %>%
        dplyr::mutate(
          expr    = suppressWarnings(as.numeric(expr)),
          isotype = factor("Mixed")
        )
    }
    
    # resumen por feature: log2FC + t.test + FDR
    res <- long %>%
      dplyr::group_by(peptide, isotype) %>%
      dplyr::summarise(
        nA    = sum(.grp == levels(.grp)[1], na.rm = TRUE),
        nB    = sum(.grp == levels(.grp)[2], na.rm = TRUE),
        meanA = mean(expr[.grp == levels(.grp)[1]], na.rm = TRUE),
        meanB = mean(expr[.grp == levels(.grp)[2]], na.rm = TRUE),
        log2FC = log2((meanB + 1e-9) / (meanA + 1e-9)),
        p = {
          g1 <- expr[.grp == levels(.grp)[1]]
          g2 <- expr[.grp == levels(.grp)[2]]
          if ((stats::sd(g1, na.rm = TRUE) == 0) && (stats::sd(g2, na.rm = TRUE) == 0)) NA_real_
          else tryCatch(stats::t.test(g2, g1)$p.value, error = function(e) NA_real_)
        },
        .groups = "drop"
      ) %>%
      dplyr::mutate(
        padj = p.adjust(p, method = "BH"),
        neglog10_padj = -log10(padj),
        status = dplyr::case_when(
          padj <= input$volcano_padj_thr & log2FC >=  input$volcano_lfc_thr ~ "Up",
          padj <= input$volcano_padj_thr & log2FC <= -input$volcano_lfc_thr ~ "Down",
          TRUE ~ "NS"
        ),
        group_var = input$volcano_group_var,
        group_A   = input$volcano_level_a,
        group_B   = input$volcano_level_b
      ) %>%
      dplyr::arrange(padj, dplyr::desc(abs(log2FC)))
    
    res
  })
  
  
  # Contenedor del gráfico (plot o plotly)
  output$volcano_plot_container <- renderUI({
    if (isTRUE(input$volcano_interactive)) {
      plotlyOutput("volcano_plotly", height = "540px")
    } else {
      plotOutput("volcano_plot", height = "540px")
    }
  })
  
  # Volcano estático
  output$volcano_plot <- renderPlot({
    tb <- volcano_tbl()
    thr_y <- -log10(input$volcano_padj_thr)
    
    gp <- ggplot(tb, aes(x = log2FC, y = neglog10_padj, color = status, shape = isotype)) +
      geom_hline(yintercept = thr_y, linetype = "dashed") +
      geom_vline(xintercept = c(-input$volcano_lfc_thr, input$volcano_lfc_thr), linetype = "dashed") +
      geom_point(alpha = 0.9, size = 2.2) +
      scale_color_manual(values = volcano_colors) +
      scale_shape_manual(values = c(IgE = 16, IgG4 = 17)) +
      theme_microarrai() +
      labs(
        title = paste0("Volcano — ", paste(input$volcano_isotypes, collapse = " + "),
                       "  (", input$volcano_level_a, " vs ", input$volcano_level_b, ")"),
        x = "log2 Fold-Change (B vs A)",
        y = expression(-log[10]("FDR (BH)")),
        color = NULL, shape = "Isotype"
      )
    
    if (isTRUE(input$volcano_facet_isotype) && length(unique(tb$isotype)) > 1) {
      gp <- gp + facet_wrap(~isotype, nrow = 1, scales = "free_x")
    }
    
    gp
  })
  
  # Volcano interactivo
  output$volcano_plotly <- plotly::renderPlotly({
    tb <- volcano_tbl()
    thr_y <- -log10(input$volcano_padj_thr)
    
    gp <- ggplot(tb, aes(
      x = log2FC, y = neglog10_padj, color = status, shape = isotype,
      text = paste0(
        "<b>", peptide, "</b>",
        "<br>Isotype: ", isotype,
        "<br>log2FC: ", round(log2FC, 2),
        "<br>FDR: ", round(padj, 4),
        "<br>nA: ", nA, "  nB: ", nB
      )
    )) +
      geom_hline(yintercept = thr_y, linetype = "dashed") +
      geom_vline(xintercept = c(-input$volcano_lfc_thr, input$volcano_lfc_thr), linetype = "dashed") +
      geom_point(alpha = 0.9, size = 2.2) +
      scale_color_manual(values = volcano_colors) +
      scale_shape_manual(values = c(IgE = 16, IgG4 = 17, Mixed = 15)) +
      theme_microarrai() +
      labs(
        title = paste0("Volcano — ",
                       if (all(tb$isotype == "Mixed")) "Mixed" else paste(unique(as.character(tb$isotype)), collapse = " + "),
                       "  (", input$volcano_level_a, " vs ", input$volcano_level_b, ")"),
        x = "log2 Fold-Change (B vs A)",
        y = "-log[10](p-adjust)",
        color = NULL, shape = "Isotype"
      )
    
    if (isTRUE(input$volcano_facet_isotype) && length(unique(tb$isotype)) > 1) {
      gp <- gp + facet_wrap(~isotype, nrow = 1, scales = "free_x")
    }
    
    plotly::ggplotly(gp, tooltip = "text") %>%
      plotly::layout(
        legend = list(orientation = "v", x = 1.02, xanchor = "left", y = 1, yanchor = "top"),
        margin = list(r = 140)
      )
  })
  
  # Tabla de “hits”
  output$volcano_hits_table <- DT::renderDT({
    tb <- volcano_tbl() %>%
      dplyr::mutate(
        meanA = round(meanA, 4),
        meanB = round(meanB, 4),
        log2FC = round(log2FC, 4),
        p = round(p, 4),
        padj = round(padj, 4),
        neglog10_padj = round(neglog10_padj, 4)
      )
    DT::datatable(
      tb,
      options = list(pageLength = 10, scrollY = "350px"),
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        'padj',
        background = DT::styleColorBar(c(0, max(tb$padj, na.rm = TRUE)), '#4facfe'),
        backgroundSize = '95% 80%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
  
  # Descarga de resultados
  output$download_volcano_tbl <- downloadHandler(
    filename = function() {
      iso <- paste(input$volcano_isotypes, collapse = "+")
      paste0("volcano_", iso, "_", input$volcano_level_a, "_vs_", input$volcano_level_b, ".csv")
    },
    content = function(file) {
      readr::write_csv(volcano_tbl(), file)
    }
  )
  
  
  
  ####################### ROC PLOTS ###########################################
  
  output$rocs_plot <- renderPlot({
    req(tests_filtered(), input$stats_plot_var)
    
    peps <- pepdata()
    tmp1 <- database()
    meta <- peps %>% inner_join(tmp1)
    testt <- tests_filtered()
    df <- meta
    df <- df %>% rename(target = !!rlang::sym(input$stats)) %>% dplyr::select(id,target)
    df2 <- meta %>% dplyr::select(1:ncol(peps))
    df3 <- df %>% inner_join(df2) %>% dplyr::select(-id) %>% 
      pivot_longer(names_to = "pep", values_to = "Expression", cols = -target) %>% 
      mutate(target = as.factor(target))
    
    # Validate that stats_plot_var exists in data
    if (!input$stats_plot_var %in% unique(df3$pep)) {
      plot.new()
      text(0.5, 0.5, "Selected peptide not found in data", cex = 1.5)
      return()
    }
    
    df3 <- df3 %>%
      filter(pep == input$stats_plot_var) %>%
      filter(!is.na(Expression))
    
    # Validate minimum data
    if (nrow(df3) < 5) {
      plot.new()
      text(0.5, 0.5, "Insufficient data for ROC curve", cex = 1.5)
      return()
    }
    
    nlevels_target <- nlevels(df3$target)
    
    # Use modular regression functions
    if (nlevels_target > 2) {
      # Multinomial regression
      result <- tryCatch({
        fit_multinomial_regression(
          expression_data = df3$Expression,
          target = df3$target
        )
      }, error = function(e) {
        plot.new()
        text(0.5, 0.5, paste("Error fitting model:", e$message), cex = 1.2)
        return(NULL)
      })
      
      if (is.null(result)) return()
      
      # Calculate ROC curve data
      roc_data <- tryCatch({
        calculate_roc_curve(
          actual = df3$target,
          probabilities = result$probabilities
        )
      }, error = function(e) {
        plot.new()
        text(0.5, 0.5, paste("Error calculating ROC:", e$message), cex = 1.2, col = "red")
        return(NULL)
      })
      
      if (is.null(roc_data) || nrow(roc_data) == 0) {
        plot.new()
        text(0.5, 0.5, "No ROC data generated", cex = 1.5)
        return()
      }
      
      # Ensure numeric columns
      roc_data$specificity <- as.numeric(roc_data$specificity)
      roc_data$sensitivity <- as.numeric(roc_data$sensitivity)
      
      # Remove NA values
      roc_data <- roc_data %>% 
        filter(!is.na(specificity), !is.na(sensitivity))
      
      if (nrow(roc_data) == 0) {
        plot.new()
        text(0.5, 0.5, "No valid ROC data points", cex = 1.5)
        return()
      }
      
      # Plot multiclass ROC
      plot_obj <- ggplot(roc_data, aes(x = 1 - specificity, y = sensitivity, color = class)) +
        geom_line(size = 1.5, alpha = 0.8) +
        geom_point(size = 2, alpha = 0.5) +
        geom_abline(slope = 1, linetype = "dotted", color = "gray50") +
        coord_fixed() +
        theme_microarrai() +
        labs(
          color = "Class", 
          title = "ROC Curves (One-vs-Rest)",
          x = "1 - Specificity (FPR)",
          y = "Sensitivity (TPR)"
        ) +
        scale_color_microarrai() +
        scale_fill_microarrai() +
        theme(
          legend.position = "right",
          plot.title = element_text(hjust = 0.5, face = "bold")
        )
      
      print(plot_obj)
      print(plot_obj)
      plot_obj
    } else {
      # Binary GLM
      result <- tryCatch({
        fit_binary_glm(
          expression_data = df3$Expression,
          target = df3$target
        )
      }, error = function(e) {
        plot.new()
        text(0.5, 0.5, paste("Error fitting model:", e$message), cex = 1.2)
        return(NULL)
      })
      
      if (is.null(result)) return()
      
      # Validate probabilities
      if (is.null(result$probabilities) || ncol(result$probabilities) < 2) {
        plot.new()
        text(0.5, 0.5, "Error: Invalid probability predictions", cex = 1.5)
        return()
      }
      
      # Calculate ROC curve data
      roc_data <- calculate_roc_curve(
        actual = df3$target,
        probabilities = result$probabilities[, 2]
      )
      
      # Plot using pROC for binary (static plot)
      pROC::plot.roc(
        df3$target, 
        result$probabilities[, 2], 
        percent = TRUE,
        main = paste0("ROC Curve (AUC = ", round(roc_data$auc[1], 3), ")"),
        add = FALSE, 
        asp = NA, 
        print.auc = TRUE,
        col = MICROARRAI_COLORS[1],
        lwd = 2
      )
    }
  })
  
  
  # Reactive to filter results by AUC threshold
  results_filtered <- reactive({
    req(tests_filtered())
    req(reg_models())
    req(input$results_auc_threshold)
    
    results_data <- tests_filtered() %>%
      left_join(reg_models() %>% rename(peptide = Peptide), by = "peptide")
    
    # Filter by AUC threshold
    results_data %>% filter(AUC >= input$results_auc_threshold)
  })
  
  # ====== RESULTS KPI BOXES ======
  output$results_kpi_boxes <- renderUI({
    req(results_filtered())
    
    results_data <- results_filtered()
    
    total_selected <- nrow(results_data)
    mean_auc <- mean(results_data$AUC, na.rm = TRUE)
    mean_f1 <- mean(results_data$F1, na.rm = TRUE)
    mean_accuracy <- mean(results_data$Accuracy, na.rm = TRUE)
    
    # IgE/IgG4 breakdown (count only, no up/down without specific contrast)
    ige_data <- results_data %>% filter(grepl("IgE", peptide))
    igg4_data <- results_data %>% filter(grepl("IgG4", peptide))
    
    n_ige <- nrow(ige_data)
    n_igg4 <- nrow(igg4_data)
    
    # Calculate mean AUC per isotype
    ige_mean_auc <- if(n_ige > 0) round(mean(ige_data$AUC, na.rm = TRUE), 2) else 0
    igg4_mean_auc <- if(n_igg4 > 0) round(mean(igg4_data$AUC, na.rm = TRUE), 2) else 0
    
    kpi_icons <- c("check-circle", "dna", "dna", "bullseye", "trophy", "chart-bar")
    kpi_data <- list(
      list(label = "Selected Peptides", value = total_selected, icon = kpi_icons[1]),
      list(label = "IgE Peptides", 
           value = n_ige,
           subtitle = paste0("Mean AUC: ", ige_mean_auc),
           icon = kpi_icons[2]),
      list(label = "IgG4 Peptides", 
           value = n_igg4,
           subtitle = paste0("Mean AUC: ", igg4_mean_auc),
           icon = kpi_icons[3]),
      list(label = "Mean AUC", value = round(mean_auc, 2), icon = kpi_icons[4]),
      list(label = "Mean F1", value = round(mean_f1, 2), icon = kpi_icons[5]),
      list(label = "Mean Accuracy", value = round(mean_accuracy, 2), icon = kpi_icons[6])
    )
    
    fluidRow(
      lapply(1:length(kpi_data), function(i) {
        kpi <- kpi_data[[i]]
        column(
          width = 2,
          div(
            style = paste0(
              "background: white;",
              "border-radius: 12px;",
              "padding: 20px 15px;",
              "margin-bottom: 15px;",
              "min-height: 142px;",
              "box-shadow: 0 4px 15px rgba(0,0,0,0.1);",
              "transition: transform 0.3s ease, box-shadow 0.3s ease;",
              "position: relative;",
              "overflow: hidden;"
            ),
            # Icon background decoration
            div(
              style = "position: absolute; right: -10px; top: -10px; opacity: 0.03; font-size: 60px; color: #191c32;",
              tags$i(class = paste0("fa fa-", kpi$icon))
            ),
            # Content
            div(
              style = "position: relative; z-index: 2;",
              tags$div(
                style = "align-items: center; margin-bottom: 10px;",
                icon(kpi$icon, style = "font-size: 18px; color: #191c32; margin-right: 8px;"),
                tags$span(kpi$label, style = "font-size: 14px; color: #191c32; font-weight: 600;")
              ),
              tags$div(
                style = "font-size: 32px; font-weight: bold; color: #191c32; margin: 5px 0;",
                kpi$value
              ),
              if (!is.null(kpi$subtitle)) {
                tags$div(
                  style = "font-size: 12px; color: #666; margin-top: 5px;",
                  kpi$subtitle
                )
              } else {
                NULL
              }
            )
          )
        )
      })
    )
  })
  
  # ====== RESULTS DONUT CHART ======
  output$results_donut <- plotly::renderPlotly({
    req(results_filtered())
    
    results_data <- results_filtered()
    
    isotype_counts <- data.frame(
      Isotype = c("IgE", "IgG4"),
      Count = c(
        sum(grepl("IgE", results_data$peptide)),
        sum(grepl("IgG4", results_data$peptide))
      )
    )
    
    plotly::plot_ly(
      isotype_counts,
      labels = ~Isotype,
      values = ~Count,
      type = 'pie',
      hole = 0.6,
      marker = list(
        colors = c('#191c32', '#667eea'),
        line = list(color = 'transparent', width = 0)
      ),
      textposition = 'inside',
      textinfo = 'label+percent',
      textfont = list(size = 14, color = 'white', family = 'Arial'),
      hoverinfo = 'label+value+percent',
      showlegend = TRUE
    ) %>%
      plotly::layout(
        paper_bgcolor = 'transparent',
        plot_bgcolor = 'transparent',
        margin = list(l = 20, r = 20, t = 40, b = 20),
        legend = list(
          orientation = 'h',
          x = 0.5,
          xanchor = 'center',
          y = -0.1,
          font = list(size = 12, color = '#191c32')
        ),
        annotations = list(
          list(
            text = paste0("<b>", sum(isotype_counts$Count), "</b><br>Total"),
            x = 0.5,
            y = 0.5,
            xref = 'paper',
            yref = 'paper',
            showarrow = FALSE,
            font = list(size = 20, color = '#191c32', family = 'Arial')
          )
        )
      ) %>%
      plotly::config(displayModeBar = FALSE)
  })
  
  # ====== RESULTS SUMMARY TEXT ======
  output$results_summary_text <- renderUI({
    req(results_filtered())
    req(input$results_pval_threshold)
    req(input$results_auc_threshold)
    
    results_data <- results_filtered()
    
    num_peptides <- nrow(results_data)
    
    if (num_peptides == 0) {
      tags$div(
        style = "color: #191c32; padding: 20px;",
        HTML("<h5>No candidate variables identified</h5>
             <p>Try adjusting the p-value or AUC thresholds in the filters section.</p>")
      )
    } else {
      # Top 5 peptides by AUC
      top_peptides <- results_data %>%
        arrange(desc(AUC)) %>%
        head(5)
      
      tags$div(
        style = "color: #191c32;",
        tags$h5("Top 5 Peptides by AUC:", style = "font-weight: bold; margin-bottom: 15px;"),
        tags$ul(
          style = "list-style-type: none; padding: 0;",
          lapply(1:nrow(top_peptides), function(i) {
            tags$li(
              style = "padding: 8px; margin-bottom: 8px; background: rgba(79, 172, 254, 0.1); border-radius: 6px;",
              HTML(sprintf(
                "<strong>%d.</strong> %s<br>
                <small style='color: #666;'>AUC: %.3f | p-adj: %s</small>",
                i,
                top_peptides$peptide[i],
                top_peptides$AUC[i],
                format(top_peptides$p.adj[i], scientific = TRUE, digits = 2)
              ))
            )
          })
        ),
        tags$hr(style = "margin: 20px 0; border-color: rgba(25, 28, 50, 0.1);"),
        tags$div(
          style = "margin-bottom: 15px;",
          tags$h5("Applied Filters:", style = "color: #191c32; font-weight: bold; margin-bottom: 10px;"),
          tags$ul(
            style = "color: #666; line-height: 1.8;",
            tags$li(paste0("Adjusted p-value < ", input$results_pval_threshold)),
            tags$li(paste0("Minimum AUC ≥ ", input$results_auc_threshold)),
            tags$li("Logistic/multinomial regression models applied")
          )
        )
      )
    }
  })
  
  # ====== FUNNEL: estado global de selección ===================================
  selected_biomarkers <- reactiveVal(character(0))
  
  # Ranking combinando p.adj (↑ significancia) y AUC (↑ rendimiento)
  ml_ranked_peptides <- reactive({
    req(results_filtered())
    
    base <- results_filtered() %>% dplyr::select(peptide, p.adj, AUC)
    
    base %>%
      dplyr::mutate(
        score = (-log10(p.adj)) + AUC
      ) %>%
      dplyr::arrange(dplyr::desc(score))
  })
  
  # Apply selection when button is clicked
  # ML biomarker selection
  selected_peptides_ml <- reactiveVal(NULL)
  
  observeEvent(input$ml_select_peptides, {
    req(ml_ranked_peptides())
    
    ranked <- ml_ranked_peptides()
    
    if (input$ml_selection_method == "top_n") {
      # Select top N peptides
      n <- min(input$ml_top_n, nrow(ranked))
      selected <- ranked$peptide[1:n]
    } else {
      # Select by AUC threshold
      selected <- ranked %>%
        filter(AUC >= input$ml_auc_threshold) %>%
        pull(peptide)
    }
    
    selected_peptides_ml(selected)
    
    showNotification(
      paste(length(selected), "peptides selected"),
      type = "message"
    )
  })
  
  # Summary of selected peptides
  output$ml_selection_summary <- renderUI({
    selected <- selected_peptides_ml()
    
    if (is.null(selected) || length(selected) == 0) {
      return(
        tags$div(
          style = "text-align: center; color: #666;",
          icon("info-circle", style = "font-size: 48px; margin-bottom: 15px; color: #667eea;"),
          tags$p("Click 'Apply Selection' to choose biomarkers", style = "font-size: 16px; margin: 0;")
        )
      )
    }
    
    ranked <- ml_ranked_peptides()
    selected_data <- ranked %>% filter(peptide %in% selected)
    
    tags$div(
      style = "text-align: center;",
      tags$div(
        style = "font-size: 48px; font-weight: bold; color: #667eea; margin-bottom: 10px;",
        length(selected)
      ),
      tags$div(
        style = "font-size: 18px; color: #191c32; font-weight: 600; margin-bottom: 20px;",
        "Peptides Selected"
      ),
      tags$hr(style = "margin: 20px 0;"),
      tags$div(
        style = "font-size: 14px; color: #191c32;",
        tags$p(
          tags$strong("Mean AUC:"), " ", 
          round(mean(selected_data$AUC, na.rm = TRUE), 3),
          style = "margin: 5px 0;"
        ),
        tags$p(
          tags$strong("Mean Accuracy:"), " ", 
          round(mean(selected_data$Accuracy, na.rm = TRUE), 3),
          style = "margin: 5px 0;"
        ),
        tags$p(
          tags$strong("Mean p-adj:"), " ", 
          format(mean(selected_data$p.adj, na.rm = TRUE), scientific = TRUE, digits = 3),
          style = "margin: 5px 0;"
        )
      )
    )
  })
  
  # Send selected peptides to ML tab
  observeEvent(input$ml_send_to_tab, {
    sel <- selected_peptides_ml()
    if (is.null(sel) || length(sel) == 0) {
      showNotification("Click 'Apply Selection' first to choose peptides.", type = "warning")
      return(NULL)
    }
    selected_biomarkers(sel)
    showNotification(
      paste(length(sel), "biomarkers sent to Machine Learning tab."), 
      type = "message",
      duration = 5
    )
    
    # Switch to ML tab automatically
    updateTabsetPanel(session, "main_tabs", selected = "Machine Learning")
  })
  # ============================================================================
  
  # ====== Conjunto de péptidos activos para ML (aplica el filtro del funnel) ===
  active_pepdata <- reactive({
    req(pepdata())
    p <- pepdata()
    sel <- selected_biomarkers()
    
    if (!is.null(sel) && length(sel) > 0) {
      keep <- intersect(colnames(p), c("id", sel))
      if (length(keep) < 2) {
        showNotification("Ninguno de los péptidos seleccionados está en la matriz. Uso todos.", type = "warning")
        return(p)
      }
      p[, keep, drop = FALSE]
    } else {
      p
    }
  })
  
  meta_data_ML <- reactive({
    req(active_pepdata(), database())
    dplyr::inner_join(active_pepdata(), database())
  })
  
  ############################### Combined #####################################
  
  meta_data <- reactive({
    req(pepdata())
    req(database())
    tmp1 <- pepdata()
    tmp2 <- database()
    dplyr::inner_join(tmp1, tmp2)
  })
  
  
  output$target_hgroup <- renderUI({
    req(database())
    selectInput("h_target", "Target Variable",
                multiple = TRUE,
                choices = colnames(meta_data_ML() %>% 
                                     dplyr::select((ncol(active_pepdata()) +1):ncol(meta_data_ML())) %>% 
                                     as.data.frame()),
                selected = 1) ## PODRIA MEJORARSE CON SOLO CARACTERES
  })
  
  ################ HEATMAP CON ANOTACION ######################################
  
  rowa <- reactive({
    target_var <- active_target_var()
    req(target_var)
    df <- meta_data_ML()
    df %>% dplyr::select(all_of(target_var))
  })
  
  output$comb_table <- renderTable({
    req(rowa())
    df <- as.data.frame(rowa())
    gt::gt(prop.table(df))
  })
  
  output$Combined_hplot <- renderPlot({
    req(input$ml_use_heatmap)  # Only render if selected
    req(active_pepdata(), meta_data_ML(), rowa())
    
    df <- meta_data_ML()
    
    mat <- df %>%
      dplyr::select(1:ncol(active_pepdata())) %>%
      tibble::column_to_rownames("id") %>%
      as.matrix()
    mat[] <- lapply(as.data.frame(mat), function(x) suppressWarnings(as.numeric(x))) %>% as.data.frame() %>% as.matrix()
    
    ann <- as.data.frame(lapply(rowa(), function(x) as.factor(as.character(x))))
    rownames(ann) <- rownames(mat)
    ann <- ann[rownames(mat), , drop = FALSE]
    ra  <- ComplexHeatmap::rowAnnotation(df = ann)
    
    iso <- split_isotype_mats(mat)
    
    # Define color palette with app background for 0 values
    ige_colors <- colorRampPalette(c("#f4f6f9", "#d0e8f2", "lightgreen", "green"))(50)
    igg4_colors <- colorRampPalette(c("#f4f6f9", "#ffd6e0", "#ff9999", "red"))(50)
    default_colors <- colorRampPalette(c("#f4f6f9", "#d0e8f2", "lightgreen", "green"))(50)
    
    if (iso$any_iso) {
      ht_list <- NULL
      if (!is.null(iso$ige) && ncol(iso$ige) > 0) {
        ht_ige <- ComplexHeatmap::Heatmap(
          iso$ige, name = "IgE",
          col = ige_colors,
          cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
          heatmap_legend_param = list(
            border = "#191c32",
            title_gp = grid::gpar(fontsize = 10, fontface = "bold"),
            labels_gp = grid::gpar(fontsize = 9)
          )
        )
        ht_list <- ht_ige
      }
      if (!is.null(iso$igg4) && ncol(iso$igg4) > 0) {
        ht_igg4 <- ComplexHeatmap::Heatmap(
          iso$igg4, name = "IgG4",
          col = igg4_colors,
          cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
          heatmap_legend_param = list(
            border = "#191c32",
            title_gp = grid::gpar(fontsize = 10, fontface = "bold"),
            labels_gp = grid::gpar(fontsize = 9)
          )
        )
        ht_list <- if (is.null(ht_list)) ht_igg4 else (ht_list + ht_igg4)
      }
      ComplexHeatmap::draw(
        ra + ht_list, 
        heatmap_legend_side = "right", 
        annotation_legend_side = "right",
        background = "transparent"
      )
    } else {
      ht <- ComplexHeatmap::Heatmap(
        mat, name = "Expression",
        col = default_colors,
        cluster_rows = TRUE, cluster_columns = TRUE, border = FALSE,
        show_column_names = FALSE,
        show_row_names = FALSE,
        heatmap_legend_param = list(
          border = "#191c32",
          title_gp = grid::gpar(fontsize = 10, fontface = "bold"),
          labels_gp = grid::gpar(fontsize = 9)
        )
      )
      ComplexHeatmap::draw(
        ra + ht, 
        heatmap_legend_side = "right", 
        annotation_legend_side = "right",
        background = "transparent"
      )
    }
  }, bg = "transparent")
  outputOptions(output, "Combined_hplot", suspendWhenHidden = FALSE)
  
  
  
  
  
  
  
  ######################### PCA  + 3D #########################################
  
  ## INPUT 
  
  output$target_PCA <- renderUI({
    req(database())
    req(active_pepdata())
    selectInput("PCA_target", 
                label = tags$span(style = "color: #ffffff;", "Target Variable for Machine Learning analysis"),
                choices = colnames(meta_data_ML() %>% 
                                     dplyr::select((ncol(active_pepdata()) +1):ncol(meta_data_ML())) %>% 
                                     as.data.frame())) 
  })
  
  
  ########################## PLOT PCA ############################################
  output$PCA_2d <- renderPlot({
    req(input$ml_use_pca)  # Only render if selected
    
    df <- meta_data_ML()
    
    # Use modular PCA function
    pca_data <- df %>% dplyr::select(1: ncol(active_pepdata())) %>% dplyr::select(-id)
    pca_result <- compute_pca(pca_data, center = TRUE, scale. = TRUE)
    
    # Get groups
    groups <- extract_target_groups(df, active_target_var())
    
    # Calculate variance
    variance <- calculate_pca_variance(stats::prcomp(pca_data, center = TRUE, scale. = TRUE))
    var_pc1 <- round(variance[1], 1)
    var_pc2 <- round(variance[2], 1)
    
    # Prepare plot data
    pca_df <- pca_result
    pca_df$target <- groups
    
    ggplot(pca_df, aes(x = PC1, y = PC2, color = target, fill = target)) +
      geom_point(size = 3, alpha = 0.7) +  
      stat_ellipse(level = 0.95, alpha = 0.2) +  
      labs(
        x = paste0("PC1 (", var_pc1, "% Varianza)"),
        y = paste0("PC2 (", var_pc2, "% Varianza)"),
        title = "Análisis PCA"
      ) +
      theme_microarrai() +
      scale_color_microarrai() +
      scale_fill_microarrai()
  })
  
  PCA_mod <- reactive({
    df1 <- meta_data_ML()
    PCA_DB <- df1 %>% dplyr::select(1: ncol(active_pepdata())) %>% select_if(funs(is.numeric(.)))
    PCA_DB[is.na(PCA_DB)] <- 0
    
    # Use modular PCA function
    compute_pca(PCA_DB, center = TRUE, scale. = FALSE)
  })
  

  ellipsoid_PCA <- reactiveVal(FALSE)
  surface_PCA <- reactiveVal("smooth")

  observeEvent(input$toggle_ellipsoid_PCA, {
    ellipsoid_PCA(!ellipsoid_PCA())
  })
  

  observeEvent(input$toggle_surface_PCA, {
    # Use modular toggle function
    surface_PCA(toggle_surface_fit(surface_PCA()))
  })
  

  output$d3_PCA <- renderRglwidget({
    req(input$ml_use_pca)  # Only render if selected
    # Get PCA coordinates and groups
    pca <- PCA_mod()
    groups <- extract_target_groups(meta_data_ML(), active_target_var())
    
    # Use modular 3D visualization function
    create_3d_pca(
      pca_coords = pca,
      groups = groups,
      variance = NULL,  # Could add variance calculation if needed
      surface = !ellipsoid_PCA(),
      ellipsoid = ellipsoid_PCA(),
      fit = surface_PCA(),
      surface_col = custom_palette
    )
  })
  

  output$current_params_PCA <- renderText({
    paste("Ellipsoid:", ellipsoid_PCA(), "| Surface:", surface_PCA())
  })
  
  ########################## PCoA + NMDS dist.matrix ############################################
  dist.matrix <- reactive({
    req(input$distance_method)
    
    # Use modular distance matrix function
    compute_distance_matrix(
      data = meta_data_ML(),
      group_var = active_target_var(),
      distance_method = input$distance_method,
      scale_data = TRUE,
      impute_na = TRUE
    )
  })
  
  ########################## PLOT PCoA ############################################
  
  output$PCoA_2d <- renderPlot({
    req(input$ml_use_pcoa)  # Only render if selected
    # Use modular PCoA function
    pcoa_coords <- perform_pcoa(dist.matrix(), k = 2)
    groups <- extract_target_groups(meta_data_ML(), active_target_var())
    
    positions <- pcoa_coords
    positions$target <- groups
    
    
    p1 <-positions %>%
      ggplot (aes (x= pcoa1, y = pcoa2, color = target))+
      geom_point()+
      stat_ellipse()+
      labs(color = "") +
      theme_microarrai() +
      scale_color_microarrai() +
      scale_fill_microarrai()
    
    
    xdens <- 
      axis_canvas(p1, axis = "x") + 
      geom_density(data = positions, aes(x = pcoa1, fill = target, 
                                         colour = target), alpha = 0.3) +
      scale_color_microarrai() +
      scale_fill_microarrai()
    
    ydens <-
      axis_canvas(p1, axis = "y", coord_flip = TRUE) + 
      geom_density(data = positions, aes(x = pcoa2, fill = target, 
                                         colour = target), alpha = 0.3) +
      coord_flip() +
      scale_color_microarrai() +
      scale_fill_microarrai()
    
    p1 %>%
      insert_xaxis_grob(xdens, grid::unit(1, "in"), position = "top") %>%
      insert_yaxis_grob(ydens, grid::unit(1, "in"), position = "right") %>%
      ggdraw()
    
  })
  

  ellipsoid_PCOA <- reactiveVal(FALSE)
  surface_PCOA <- reactiveVal("smooth")
  
  observeEvent(input$toggle_ellipsoid_PCOA, {
    ellipsoid_PCOA(!ellipsoid_PCOA())
  })
  
  observeEvent(input$toggle_surface_PCOA, {
    # Use modular toggle function
    surface_PCOA(toggle_surface_fit(surface_PCOA()))
  })
  
  output$PCoA_3d <- renderRglwidget({
    req(input$ml_use_pcoa)  # Only render if selected
    # Use modular PCoA 3D function
    pcoa_coords <- perform_pcoa(dist.matrix(), k = 3)
    groups <- extract_target_groups(meta_data_ML(), active_target_var())
    
    create_3d_pcoa(
      pcoa_coords = pcoa_coords,
      groups = groups,
      surface = !ellipsoid_PCOA(),
      ellipsoid = ellipsoid_PCOA(),
      fit = surface_PCOA(),
      surface_col = custom_palette
    )
  })
  
  
  ########################## PLOT NMDS ############################################
  output$NMDS_2d <- renderPlot({
    req(input$ml_use_nmds)  # Only render if selected
    # Use modular NMDS function
    nmds_coords <- perform_nmds(dist.matrix(), k = 2)
    groups <- extract_target_groups(meta_data_ML(), active_target_var())
    
    data <- nmds_coords
    data$target <- groups
    
    data %>% ggplot(aes(x= NMDS1, y= NMDS2, fill= target, color= target)) +
      geom_point()+
      stat_ellipse()+
      theme_microarrai() +
      scale_color_microarrai() +
      scale_fill_microarrai()
    
  })
  
  
  ellipsoid_NMDS <- reactiveVal(FALSE)
  surface_NMDS <- reactiveVal("smooth")
  
  observeEvent(input$toggle_ellipsoid_NMDS, {
    ellipsoid_NMDS(!ellipsoid_NMDS())
  })
  
  observeEvent(input$toggle_surface_NMDS, {
    # Use modular toggle function
    surface_NMDS(toggle_surface_fit(surface_NMDS()))
  })
  

  output$NMDS_3d <- renderRglwidget({
    req(input$ml_use_nmds)  # Only render if selected
    # Use modular NMDS 3D function
    nmds_coords <- perform_nmds(dist.matrix(), k = 3)
    groups <- extract_target_groups(meta_data_ML(), active_target_var())
    
    create_3d_nmds(
      nmds_coords = nmds_coords,
      groups = groups,
      surface = !ellipsoid_NMDS(),
      ellipsoid = ellipsoid_NMDS(),
      fit = surface_NMDS(),
      surface_col = custom_palette
    )
  })
  
  output$current_params_NMDS <- renderText({
    paste("Ellipsoid:", ellipsoid_NMDS(), "| Surface:", surface_NMDS())
  })
  
  ####### Supervised machine learning ####
  
  ML.db <- reactive({
    # Use modular ML data preparation function
    prepare_ml_data(
      data = meta_data_ML(),
      group_var = active_target_var(),
      id_column = "id"
    )
  })
  
  
  
  ## Modelo C5.0 ##
  variables_c5 <- reactive({
    req(input$ml_use_c50)  # Only compute if selected
    # Use modular C5.0 functions
    model <- train_c50_model(ML.db(), trials = 50, seed = 120)
    extract_c50_importance(model, top_n = 30)
  })
  
  output$c5.plot <- renderPlot({
    req(input$ml_use_c50)  # Only render if selected
    # Use modular C5.0 functions
    model <- train_c50_model(ML.db(), trials = 50, seed = 120)
    
    # Extract and plot importance
    as.data.frame(C50::C5imp(model)) %>%
      dplyr::slice_head(n = 15) %>% 
      rownames_to_column(var = "Var") %>% 
      ggplot(aes(x = Var, y= Overall)) +
      geom_bar(stat = "identity", fill = "steelblue") +
      coord_flip() +
      theme_microarrai() 
  })
  
  output$c5.tree <- renderPlot({
    req(input$ml_use_c50)  # Only render if selected
    # Use modular C5.0 function
    model <- train_c50_model(ML.db(), trials = 50, seed = 1234)
    plot(model)
  })
  
  
  output$c5.decision <- renderPlot({
    req(input$ml_use_c50)  # Only render if selected
    # Use modular decision boundary function
    c5_vars <- variables_c5()
    create_decision_boundary_plot(
      data = ML.db(), 
      model_type = "c50", 
      important_vars = c5_vars,
      trials = 100
    ) +
      theme_microarrai() +
      scale_color_microarrai() +
      scale_fill_microarrai()
  })
  ## Random Forest ## 
  variables_rf <- reactive({
    req(input$ml_use_rf)  # Only compute if selected
    # Use modular Random Forest functions
    model <- train_randomforest_model(ML.db())
    extract_rf_importance(model, top_n = 30)
  })
  
  output$rf.plot <- renderPlot({
    req(input$ml_use_rf)  # Only render if selected
    # Use modular Random Forest functions
    model <- train_randomforest_model(ML.db())
    
    caret::varImp(model) %>% 
      as.data.frame() %>% 
      arrange(desc(Overall)) %>% 
      dplyr::slice_head(n = 15) %>% 
      rownames_to_column(var = "Var") %>% 
      ggplot(aes(x = Var, y= Overall)) +
      geom_bar(stat = "identity", fill = "steelblue") +
      coord_flip() +
      labs(title = "Feature Selection by Random Forest") +
      theme_microarrai()
  })
  
  output$rf.decision <- renderPlot({
    req(input$ml_use_rf)  # Only render if selected
    # Use modular decision boundary function
    rf_vars <- variables_rf()
    create_decision_boundary_plot(
      data = ML.db(), 
      model_type = "rf", 
      important_vars = rf_vars
    ) +
      theme_microarrai() +
      scale_color_microarrai() +
      scale_fill_microarrai()
  })
  
  
  ## SVM ##
  
  variables_importantes_reactive <- reactive({
    req(input$ml_use_svm)  # Only compute if selected
    # Use modular RFE function
    df_scaled <- scale_ml_data(ML.db())
    perform_rfe_svm(df_scaled, sizes = c(1:10), cv_folds = 2)
  })
  
  ## SVM ##
  
  output$svm.plot <- renderPlot({
    req(input$ml_use_svm)  # Only render if selected
    withProgress(message = 'Running RFE', value = 0, {
      # Use modular scaling and decision boundary functions
      df.scaled <- scale_ml_data(ML.db())
      
      incProgress(0.6, detail = "RFE completed, selecting important variables...")
      
      svm_vars <- variables_importantes_reactive()
      
      incProgress(0.8, detail = "Creating decision boundary plot...")
      
      plot <- create_decision_boundary_plot(
        data = df.scaled, 
        model_type = "svm", 
        important_vars = svm_vars,
        cost = 10
      ) +
        theme_microarrai() +
        scale_color_microarrai() +
        scale_fill_microarrai()
      
      incProgress(1, detail = "Completado")
      
      plot
    })
  })
  
  ## Visualización 3D ##
  output$svm3d.plot <- renderPlotly({
    req(input$ml_use_svm)  # Only render if selected
    withProgress(message = 'Creando gráfico 3D', value = 0, {
      # Use modular scaling function
      df.scaled <- scale_ml_data(ML.db())
      
      # Obtener las variables importantes de la expresión reactiva
      variables_importantes <- variables_importantes_reactive()
      
      # Seleccionar las tres mejores variables para el gráfico 3D
      predictoras_3d <- variables_importantes[1:3]
      
      
      # Entrenar el modelo SVM con las tres mejores variables
      modelo_svm_3d <- svm(formula = as.formula(paste("target ~", paste(predictoras_3d, collapse = " + "))),
                           data = df.scaled, kernel = "linear", cost = 10)
      
      # Crear una cuadrícula de valores para las tres variables predictoras
      x_min <- min(df.scaled[,predictoras_3d[1]])
      x_max <- max(df.scaled[,predictoras_3d[1]])
      y_min <- min(df.scaled[,predictoras_3d[2]])
      y_max <- max(df.scaled[,predictoras_3d[2]])
      z_min <- min(df.scaled[,predictoras_3d[3]])
      z_max <- max(df.scaled[,predictoras_3d[3]])
      
      # Crear la cuadrícula
      grid_3d <- expand.grid(
        x1 = seq(x_min, x_max, length.out = 30),
        x2 = seq(y_min, y_max, length.out = 30),
        x3 = seq(z_min, z_max, length.out = 30)
      )
      names(grid_3d) <- predictoras_3d
      
      # Hacer predicciones en la cuadrícula
      grid_3d$target <- predict(modelo_svm_3d, grid_3d)
      
      # Convertir target a factor
      grid_3d$target <- as.factor(grid_3d$target)
      
      incProgress(0.5, detail = "Generating 3D graphics...")
      
      # Crear la visualización 3D
      fig <- plot_ly() %>%
        # Graficar los puntos originales
        add_markers(data = df.scaled, 
                    x = ~df.scaled[,predictoras_3d[1]], 
                    y = ~df.scaled[,predictoras_3d[2]], 
                    z = ~df.scaled[,predictoras_3d[3]], 
                    color = ~df.scaled$target,
                    colors = custom_palette,
                    marker = list(size = 5),
                    opacity = 0.8) %>%
        # Graficar la frontera de decisión
        add_markers(data = grid_3d, 
                    x = ~grid_3d[,predictoras_3d[1]], 
                    y = ~grid_3d[,predictoras_3d[2]], 
                    z = ~grid_3d[,predictoras_3d[3]], 
                    color = ~grid_3d$target, 
                    colors = custom_palette,
                    marker = list(size = 3),
                    opacity = 0.15) %>%
        layout(scene = list(xaxis = list(title = predictoras_3d[1]),
                            yaxis = list(title = predictoras_3d[2]),
                            zaxis = list(title = predictoras_3d[3]),
                            aspectmode = 'cube'))
      
      incProgress(1, detail = "Completed 3D graphic")
      
      fig
    })
  })
  
  ## XGBoost - Selección de variables importantes ##
  variables_xgb <- reactive({
    req(input$ml_use_xgboost)  # Only compute if selected
    # Use modular XGBoost functions
    xgb_result <- train_xgboost_model(ML.db(), max_depth = 3, eta = 0.1, nrounds = 100)
    extract_xgboost_importance(xgb_result, top_n = 30)
  })
  

  ## XGBoost SHAP ##
  xgb.shap <- reactive({
    req(input$ml_use_xgboost)  # Only compute if selected
    # Use modular XGBoost and SHAP functions
    xgb_result <- train_xgboost_model(ML.db(), max_depth = 3, eta = 0.1, nrounds = 100)
    calculate_shap_values(xgb_result)
  })
  

  output$shap_importance_plot <- renderPlot({
    req(input$ml_use_xgboost)  # Only render if selected
    shap_values <- xgb.shap()
    sv_importance(shap_values, show_numbers = TRUE) +
      theme_microarrai() +
      ggtitle("SHAP Importance Plot")
  })
  
  output$shap_importance_bee_plot <- renderPlot({
    req(input$ml_use_xgboost)  # Only render if selected
    shap_values <- xgb.shap()
    sv_importance(shap_values, kind = "bee") +
      theme_microarrai() +
      ggtitle("SHAP Bee Swarm Plot")
  })
  
  # Waterfall plot 
  output$shap_waterfall_plot <- renderPlot({
    req(input$ml_use_xgboost)  # Only render if selected
    shap_values <- xgb.shap()
    sv_waterfall(shap_values, row_id = 2) +
      ggtitle("Waterfall plot for second prediction") +
      theme_microarrai()
  })
  
  # Force plot
  output$shap_force_plot <- renderPlot({
    req(input$ml_use_xgboost)  # Only render if selected
    shap_values <- xgb.shap()
    sv_force(shap_values, row_id = 2) +
      ggtitle("Force plot for second prediction") +
      theme_microarrai()
  })
  #### End supervised Machine ####
  
  
  output$venn.plot <- renderPlot({
    # Build list dynamically based on selected models
    model_vars <- list()
    
    if (!is.null(input$ml_use_c50) && input$ml_use_c50) {
      model_vars[["C5.0"]] <- variables_c5()
    }
    
    if (!is.null(input$ml_use_rf) && input$ml_use_rf) {
      model_vars[["Random Forest"]] <- variables_rf()
    }
    
    if (!is.null(input$ml_use_svm) && input$ml_use_svm) {
      model_vars[["SVM"]] <- variables_importantes_reactive()
    }
    
    if (!is.null(input$ml_use_xgboost) && input$ml_use_xgboost) {
      model_vars[["XGBoost"]] <- variables_xgb()
    }
    
    # Only render if at least 2 models selected
    req(length(model_vars) >= 2)
    
    ggvenn(
      model_vars,
      fill_color = custom_palette,
      stroke_size = 0.5, set_name_size = 4, text_size = 4
    ) +
      ggtitle("Consensus of Variables across Selected Models")
  })
  
  output$consensus_vars <- renderText({
    # Build list dynamically based on selected models
    model_vars <- list()
    
    if (!is.null(input$ml_use_c50) && input$ml_use_c50) {
      model_vars[["C5.0"]] <- variables_c5()
    }
    
    if (!is.null(input$ml_use_rf) && input$ml_use_rf) {
      model_vars[["Random Forest"]] <- variables_rf()
    }
    
    if (!is.null(input$ml_use_svm) && input$ml_use_svm) {
      model_vars[["SVM"]] <- variables_importantes_reactive()
    }
    
    if (!is.null(input$ml_use_xgboost) && input$ml_use_xgboost) {
      model_vars[["XGBoost"]] <- variables_xgb()
    }
    
    req(length(model_vars) >= 2)
    
    consensus <- Reduce(intersect, unname(model_vars))
    if (length(consensus) > 0) {
      paste(consensus, collapse = ", ")
    } else {
      "There are no variables in common between the models."
    }
  })
  
  # ============================================================================
  # MACHINE LEARNING - NEW PIPELINE SYSTEM
  # ============================================================================
  
  # Hide all ML result sections initially
  shinyjs::hide("ml_heatmap_section")
  shinyjs::hide("ml_ordination_section")
  shinyjs::hide("ml_pca_results")
  shinyjs::hide("ml_pcoa_results")
  shinyjs::hide("ml_nmds_results")
  shinyjs::hide("ml_dbscan_results")
  shinyjs::hide("ml_plsda_results")
  shinyjs::hide("ml_c50_results")
  shinyjs::hide("ml_rf_results")
  shinyjs::hide("ml_svm_results")
  shinyjs::hide("ml_xgboost_results")
  shinyjs::hide("ml_venn_results")
  
  # Unified target variable (new system uses ml_target_var, old uses PCA_target/h_target)
  active_target_var <- reactive({
    if (!is.null(input$ml_target_var)) {
      return(input$ml_target_var)
    } else if (!is.null(input$PCA_target)) {
      return(input$PCA_target)
    } else if (!is.null(input$h_target)) {
      return(input$h_target[1])  # Take first if multiple
    }
    NULL
  })
  
  # ML Target Variable Selector
  output$ml_target_selector <- renderUI({
    req(database())
    req(active_pepdata())
    
    choices <- colnames(meta_data_ML() %>% 
                         dplyr::select((ncol(active_pepdata()) + 1):ncol(meta_data_ML())) %>% 
                         as.data.frame())
    
    selectInput(
      "ml_target_var", 
      label = NULL,
      choices = choices,
      selected = choices[1],
      width = "100%"
    )
  })
  
  # Run ML Pipeline
  observeEvent(input$ml_run_pipeline, {
    req(input$ml_target_var)
    
    # Validate at least one method selected
    any_unsupervised <- input$ml_use_heatmap || input$ml_use_pca || 
                        input$ml_use_pcoa || input$ml_use_nmds || 
                        input$ml_use_dbscan || input$ml_use_plsda
    
    any_supervised <- input$ml_use_c50 || input$ml_use_rf || 
                      input$ml_use_svm || input$ml_use_xgboost
    
    if (!any_unsupervised && !any_supervised) {
      showNotification(
        "Please select at least one ML method to run.",
        type = "warning",
        duration = 5
      )
      return()
    }
    
    # Check biomarker selection
    sel_biomarkers <- selected_biomarkers()
    if (is.null(sel_biomarkers) || length(sel_biomarkers) == 0) {
      showNotification(
        "No biomarkers selected. Using all peptides from the database.",
        type = "warning",
        duration = 5
      )
    } else {
      showNotification(
        paste("Using", length(sel_biomarkers), "selected biomarkers from Peptide tab"),
        type = "message",
        duration = 4
      )
    }
    
    # Run with progress bar
    withProgress(message = 'Running ML Pipeline...', value = 0, {
      
      # Step 1: Show/hide heatmap
      incProgress(0.1, detail = "Configuring heatmap...")
      if (input$ml_use_heatmap) {
        shinyjs::show("ml_heatmap_section")
      } else {
        shinyjs::hide("ml_heatmap_section")
      }
      
      # Step 2: Configure unsupervised methods
      incProgress(0.2, detail = "Configuring unsupervised methods...")
      
      # Show ordination section if any ordination method is selected
      if (input$ml_use_pca || input$ml_use_pcoa || input$ml_use_nmds) {
        shinyjs::show("ml_ordination_section")
      } else {
        shinyjs::hide("ml_ordination_section")
      }
      
      if (input$ml_use_pca) {
        shinyjs::show("ml_pca_results")
      } else {
        shinyjs::hide("ml_pca_results")
      }
      
      if (input$ml_use_pcoa) {
        shinyjs::show("ml_pcoa_results")
      } else {
        shinyjs::hide("ml_pcoa_results")
      }
      
      if (input$ml_use_nmds) {
        shinyjs::show("ml_nmds_results")
      } else {
        shinyjs::hide("ml_nmds_results")
      }
      
      if (input$ml_use_dbscan) {
        shinyjs::show("ml_dbscan_results")
      } else {
        shinyjs::hide("ml_dbscan_results")
      }
      
      if (input$ml_use_plsda) {
        shinyjs::show("ml_plsda_results")
      } else {
        shinyjs::hide("ml_plsda_results")
      }
      
      # Step 3: Configure supervised methods
      incProgress(0.4, detail = "Configuring supervised methods...")
      
      if (input$ml_use_c50) {
        shinyjs::show("ml_c50_results")
      } else {
        shinyjs::hide("ml_c50_results")
      }
      
      if (input$ml_use_rf) {
        shinyjs::show("ml_rf_results")
      } else {
        shinyjs::hide("ml_rf_results")
      }
      
      if (input$ml_use_svm) {
        shinyjs::show("ml_svm_results")
      } else {
        shinyjs::hide("ml_svm_results")
      }
      
      if (input$ml_use_xgboost) {
        shinyjs::show("ml_xgboost_results")
      } else {
        shinyjs::hide("ml_xgboost_results")
      }
      
      # Show Venn diagram if more than one supervised method
      if (sum(c(input$ml_use_c50, input$ml_use_rf, input$ml_use_svm, input$ml_use_xgboost)) > 1) {
        shinyjs::show("ml_venn_results")
      } else {
        shinyjs::hide("ml_venn_results")
      }
      
      # Step 4: Switch to appropriate tab
      incProgress(0.6, detail = "Navigating to results...")
      
      if (any_unsupervised) {
        updateTabsetPanel(session, "ml_subtabs", selected = "Unsupervised Learning")
      } else if (any_supervised) {
        updateTabsetPanel(session, "ml_subtabs", selected = "Supervised Learning")
      }
      
      # Step 5: Complete
      incProgress(1, detail = "Pipeline configured successfully!")
      Sys.sleep(0.5)  # Brief pause to show completion
    })
    
    showNotification(
      "ML pipeline ready! Results will appear as they are computed.",
      type = "message",
      duration = 4
    )
  })
  
  # ============================================================================
  # ============================== LEGACY CODE =================================
  # ============================================================================
  # Below this line: Original ML outputs that compute the actual results
  # These use active_target_var() and active_pepdata() (filtered by selected_biomarkers)
  
  # ============================================================================
  # MACHINE LEARNING - LEGACY CODE (TO BE ENCAPSULATED)
  # ============================================================================
  
  output$explanation <- renderUI({
    tagList(
      p("The variable selection process includes two approaches: "),
      tags$ul(
        tags$li(
          strong("Recursive Feature Elimination (RFE): "),
          "RFE is an iterative process that selects the most relevant variables while eliminating the less important ones according to the underlying model. It is commonly used in models such as SVM."
        ),
        tags$li(
          strong("Embedded selection methods: "),
          "In models such as Random Forest and C5.0, the variable selection process is embedded within the model training itself. These methods automatically select important variables during model building."
        )
      ),
      p("The Venn diagram below represents the variables selected by each model, showing the intersections or consensus between them."),
      p(strong("Consensus variables: "), textOutput("consensus_vars"))
    )
  })
  
  #### 2D Represent Logic ####
  
  
  fasta_data <- reactive({
    req(input$fasta_file)
    read_csv(input$fasta_file$datapath, col_names = FALSE, skip = 1)
  })
  
  
  bio_data <- reactive({
    req(input$bio_file)
    read_delim(input$bio_file$datapath, delim = "\t", escape_double = FALSE, 
               col_names = FALSE, trim_ws = TRUE, skip = 1)
  })
  
  
  observeEvent(input$plot_btn, {
    req(fasta_data(), bio_data())
    
   
    P01003_fasta <- fasta_data()
    
    Ref.P01003 <- P01003_fasta %>%
      separate_rows(X1, sep = "") %>%
      filter(X1 != "") %>%
      rename(AA_ref = X1) %>%
      mutate(Pos = 1:nrow(.))
    
    
    P01003 <- bio_data() %>%
      select(X3, X4, X5) %>%
      rename(Biochemical_info = X3, AA_Start = X4, AA_Finish = X5)
    
    
    P01003.S <- P01003 %>% filter(Biochemical_info == "Disulfide bond") 
    P01003.S1 <- P01003.S %>% select(Biochemical_info, AA_Start) %>% rename(Pos = AA_Start)
    P01003.S2 <-  P01003.S %>% select(Biochemical_info, AA_Finish) %>% rename(Pos = AA_Finish)
    P01003.S <- bind_rows(P01003.S1, P01003.S2)
    
    P01003.G <- P01003 %>% filter(Biochemical_info == "Glycosylation") %>%
      select(Biochemical_info, AA_Start) %>%
      rename(Pos = AA_Start)
    
    
    Biochemical.P01003 <- bind_rows(P01003.S, P01003.G)
    
    
    Protein <- Ref.P01003 %>% full_join(Biochemical.P01003) %>%
      mutate(Representation = ifelse(Biochemical_info == "Disulfide bond", "S", "Ch"))
    
 
    rep.pos <- posiciones(input$amino_count, input$chain_length, input$spacing, input$offset)
    Protein <- bind_cols(Protein, rep.pos)
    
    # Output del gráfico
    output$protein_plot <- renderPlot({
      Protein %>% ggplot(aes(x= x, y= y, label = AA_ref)) +
        geom_point(size = 10, alpha= .3) +
        geom_text(size = 4) +
        ggrepel::geom_text_repel(aes(label= Representation, nudge_y = ifelse(y == max(y), y+1, y)),
                                 box.padding = 0.5,    
                                 point.padding = 0.3, 
                                 size = 4, 
                                 label.size = 0,
                                 segment.color = 'black', 
                                 nudge_x = 0.7,    
                                 fill = NA,        
                                 label.r = 0.2) +
        theme_microarrai()
    })
  })

  #### End 2D Represent ####
  
  
}


shiny::shinyApp(ui, server)
