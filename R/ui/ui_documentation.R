# ============================================================================
# MicroarrAI - Documentation Tab UI
# ============================================================================
# Self-contained, step-by-step user guide. Everything is static HTML rendered
# client-side (no R markdown rendering, no server round-trip). The sidebar
# scrolls to in-page sections.
# ============================================================================

ui_documentation <- function() {
  tabPanel(
    "Documentation",

    tags$head(tags$style(HTML("
      .doc-content { margin-left: 0; transition: margin-left .3s ease; padding: 30px 48px;
        overflow-y: auto; background:#fff; min-height: calc(100vh - 150px); max-width: 1000px; }
      .doc-content.sidebar-open { margin-left: 320px; }
      .doc-content h1 { color:#191c32; font-size:30px; font-weight:700; margin:0 0 6px;
        border-bottom:3px solid #18BC9C; padding-bottom:10px; }
      .doc-content h2 { color:#191c32; font-size:22px; font-weight:700; margin:38px 0 12px;
        padding-top:8px; border-top:1px solid #eef0f4; }
      .doc-content h3 { color:#2a2d4a; font-size:17px; font-weight:600; margin:22px 0 8px; }
      .doc-content p, .doc-content li { color:#33384a; font-size:15px; line-height:1.7; }
      .doc-content ul, .doc-content ol { padding-left:26px; margin-bottom:14px; }
      .doc-content li { margin-bottom:6px; }
      .doc-content code { background:#f3f4f7; padding:2px 6px; border-radius:3px;
        font-family: ui-monospace, 'Courier New', monospace; font-size:13px; color:#0e7d6e; }
      .doc-content .lead { font-size:16px; color:#5a6072; margin-bottom:8px; }
      .doc-content .step { background:#f8fafb; border:1px solid #e6e8ec; border-left:4px solid #18BC9C;
        border-radius:8px; padding:16px 18px; margin:14px 0; }
      .doc-content .note { background:#e7f3ff; border-left:4px solid #2196F3; padding:12px 16px;
        border-radius:6px; margin:14px 0; }
      .doc-content .warn { background:#fff3cd; border-left:4px solid #ffc107; padding:12px 16px;
        border-radius:6px; margin:14px 0; }
      .doc-content table { width:100%; border-collapse:collapse; margin:16px 0; font-size:14px; }
      .doc-content th { background:#191c32; color:#fff; text-align:left; padding:10px 12px; }
      .doc-content td { padding:9px 12px; border-bottom:1px solid #e6e8ec; vertical-align:top; }
      .doc-content tr:nth-child(even) td { background:#fafbfc; }
      .doc-content .tag { display:inline-block; background:#18BC9C; color:#fff; font-size:11px;
        font-weight:600; padding:2px 8px; border-radius:10px; margin-left:6px; vertical-align:middle; }
      @media (max-width:768px){ .doc-content{padding:20px} .doc-content.sidebar-open{margin-left:0} }
    "))),

    # ---- Sidebar (scrolls to in-page sections) ----
    tags$div(
      id = "doc-sidebar", class = "ml-sidebar",
      tags$h4(icon("book"), " User Guide"),
      tags$div(id = "doc-sidebar-toggle", class = "ml-sidebar-toggle", icon("bars")),
      tags$div(
        class = "ml-sidebar-section",
        tags$div(class = "ml-sidebar-section-title", "CONTENTS"),
        doc_nav("sec-overview",  "home",         "Overview"),
        doc_nav("sec-data",      "table",        "Data you need"),
        doc_nav("sec-preprocess","cogs",         "1. Preprocessing"),
        doc_nav("sec-peptide",   "microscope",   "2. Peptide finder"),
        doc_nav("sec-ml",        "brain",        "3. Machine learning"),
        doc_nav("sec-protein",   "dna",          "4. Protein 3D"),
        doc_nav("sec-tips",      "life-ring",    "Tips & troubleshooting")
      )
    ),

    # ---- Content ----
    tags$div(class = "doc-content ml-content", id = "doc-scroll", HTML(doc_body())),

    tags$script(HTML("
      $(document).on('click', '#doc-sidebar-toggle', function(){
        var open = $('#doc-sidebar').toggleClass('open').hasClass('open');
        $('#doc-sidebar').css('left', open ? '0' : '-320px');
        $('.doc-content').toggleClass('sidebar-open', open);
        $(this).html(open ? '<i class=\"fa fa-times\"></i>' : '<i class=\"fa fa-bars\"></i>');
      });
      $(document).on('click', '.doc-nav', function(){
        $('.doc-nav').removeClass('active'); $(this).addClass('active');
        var el = document.getElementById($(this).attr('data-go'));
        if (el) el.scrollIntoView({behavior:'smooth', block:'start'});
      });
    "))
  )
}

# Sidebar link that scrolls to a section
doc_nav <- function(target, ic, label) {
  tags$div(class = "ml-sidebar-item doc-nav", `data-go` = target,
           icon(ic), label)
}

# The full guide as static HTML
doc_body <- function() {
  '
<h1 id="sec-overview">MicroarrAI — User Guide</h1>
<p class="lead">MicroarrAI turns peptide/protein microarray scans into normalized expression, finds
differential peptides, runs machine-learning biomarker discovery, and maps biomarkers onto the 2D/3D
protein structure. Work through the four steps in order.</p>

<div class="step"><b>The workflow at a glance</b>
<ol>
<li><b>Preprocessing</b> — load scans (or a ready matrix), pick controls, normalize, impute missing values.</li>
<li><b>Peptide finder</b> — load clinical metadata, run differential analysis, pick candidate biomarkers.</li>
<li><b>Machine learning</b> — train models on the selected biomarkers and find a robust consensus.</li>
<li><b>Protein 3D</b> — visualize where the biomarkers sit on the protein in 2D and 3D.</li>
</ol></div>

<p>The top bar lets you switch tabs, toggle light/dark (&#9728;) and reset the whole pipeline with the
&#8635; button in the top-right corner (clears all data and results without reloading the browser).</p>

<h2 id="sec-data">Data you need</h2>
<table>
<tr><th>Input</th><th>Format</th><th>Notes</th></tr>
<tr><td>Microarray scans</td><td>One CSV per sample (ScanArray / GenePix export)</td>
<td>The data block is auto-detected. Two channels are read: <code>Ch1 = IgE</code>, <code>Ch2 = IgG4</code>.</td></tr>
<tr><td>Pre-processed matrix</td><td>CSV / XLSX</td><td>Samples in rows, peptide columns. Use this if you already normalized elsewhere.</td></tr>
<tr><td>Clinical metadata</td><td>CSV / XLSX</td><td>One row per sample. Must contain the sample ID and at least one grouping (outcome) column.</td></tr>
</table>
<div class="note">Sample IDs in the metadata must match the sample (file) names from the expression
data so the two tables can be joined.</div>

<h2 id="sec-preprocess">1. Preprocessing <span class="tag">tab: Preprocessing</span></h2>
<p>Goal: produce a clean, normalized peptide expression matrix.</p>

<h3>1.1 Choose the input mode</h3>
<ul>
<li><b>RAW files</b> — point the app at a folder of scan CSVs. Analyte IDs are extracted automatically.</li>
<li><b>Processed matrix</b> — upload an expression matrix and skip normalization.</li>
</ul>

<h3>1.2 Select controls (RAW mode)</h3>
<ul>
<li><b>Negative controls</b> — spots used to calibrate normalization (e.g. buffer/PBS). Select them from
the list or with a regex. They define the zero point and the spread of each array.</li>
<li><b>Positive controls</b> — used only for quality control. They are excluded from the analysis.</li>
</ul>
<div class="note">Both control sets are removed from the final matrix. Negatives drive the normalization;
positives are just QA.</div>

<h3>1.3 Normalization</h3>
<p><b>Intra-sample (within array)</b> — robust Z-score against the negative controls:
<code>(value &minus; median(neg)) / MAD(neg)</code>. A value of, say, 3 means "3 robust SDs above this
array&rsquo;s background". Each array is referenced to its own controls, so arrays become comparable.</p>
<p><b>Inter-sample (between arrays, optional)</b> — makes whole samples comparable:</p>
<ul>
<li><b>Robust per-sample</b> — centers each sample by its median and scales by its MAD.</li>
<li><b>Quantile</b> — forces all samples to share the same value distribution (use when arrays are technically comparable).</li>
</ul>

<h3>1.4 Missing-value imputation</h3>
<p>Spots removed by quality flags are missing &mdash; not zero. Choose how to fill them so no sample is
dropped downstream:</p>
<ul>
<li><b>kNN</b> (recommended) — fills from the most similar peptides.</li>
<li><b>Random Forest</b> — captures non-linear structure; slower.</li>
<li><b>Per-peptide median</b> — fast, robust fallback.</li>
</ul>

<div class="step"><b>Run it:</b> click <b>Start Normalization Process</b>. A spinner runs while the matrix is
built; a preview appears when it finishes.</div>

<h2 id="sec-peptide">2. Peptide finder <span class="tag">tab: Peptide finder</span></h2>
<p>Goal: load clinical groups, explore positivity, run differential analysis and pick candidate biomarkers.</p>

<h3>2.1 Load and edit clinical metadata</h3>
<ul>
<li>Upload the clinical database (CSV/XLSX).</li>
<li>Set the <b>Sample ID column</b>. It is renamed to <code>id</code> and used to join with the expression matrix.</li>
<li>Edit values directly in the table; use <b>Find &amp; Replace</b> to fix labels in bulk. Edits are kept as you go.</li>
</ul>

<h3>2.2 Data overview</h3>
<p>The KPI cards summarise samples, peptides, mean/median expression, average positive peptides per sample
and how many peptides contain missing values (before imputation). The donut shows positive calls per
isotype; the distribution plot shows expression per isotype. The <b>Expression threshold</b> slider sets
what counts as "positive".</p>

<h3>2.3 Differential analysis</h3>
<ol>
<li>Pick the <b>analysis type</b> and the <b>target</b> (the outcome/contrast variable).</li>
<li>Run the analysis. Results appear as a table of peptides with p-value, FDR and effect size.</li>
</ol>

<h3>2.4 Volcano plot</h3>
<p>The volcano shows effect size (x = mean difference B&minus;A) vs significance (y).</p>
<ul>
<li><b>Contrast Variable</b> defaults to the variable the analysis runs with.</li>
<li><b>Y axis</b> switch: FDR (p-adjust) or raw p-value. The significance colouring (Up / Down / NS) and the
dashed threshold line follow whichever metric is selected.</li>
<li>The two sliders set the <b>significance threshold</b> and the minimum <b>effect size</b>. Points update
instantly. Hover any point for its details.</li>
</ul>

<h3>2.5 Select biomarkers for ML</h3>
<p>Peptides are ranked by significance and AUC. Pick the <b>top N</b> or set an <b>AUC threshold</b>, then send
the selection to the Machine learning tab.</p>

<h2 id="sec-ml">3. Machine learning <span class="tag">tab: Machine Learning</span></h2>
<p>Goal: train models on the selected biomarkers and find a robust multi-model consensus.</p>

<h3>3.1 Set up</h3>
<ul>
<li>The pipeline uses the biomarkers sent from the Peptide finder (or all peptides if none were selected).</li>
<li>Pick the <b>target variable</b> (defined once here and reused by the other tabs).</li>
<li>Choose methods:
  <ul>
  <li><b>Unsupervised</b>: heatmap, PCA, PCoA, NMDS, DBSCAN, PLS-DA.</li>
  <li><b>Supervised</b>: C5.0, Random Forest, SVM, XGBoost.</li>
  </ul></li>
</ul>

<h3>3.2 Options</h3>
<table>
<tr><th>Option</th><th>What it does</th></tr>
<tr><td><b>RFE</b></td><td>Recursive Feature Elimination &mdash; pre-screens the most informative features.</td></tr>
<tr><td><b>Cross-validation</b></td><td>Repeated k-fold CV for honest performance estimates.</td></tr>
<tr><td><b>Tuning</b></td><td>Hyperparameter search (only active with CV). Grids per model; the best combo is chosen by ROC/Kappa. Slower.</td></tr>
</table>

<div class="step"><b>Run it:</b> click <b>Run pipeline</b>. A spinner covers training. Re-runs are blocked for
10 seconds to avoid queuing the pipeline multiple times.</div>

<h3>3.3 Read the results</h3>
<ul>
<li>Per-model metrics: Accuracy, AUC, F1, etc., plus variable importance, ROC and decision boundaries.</li>
<li><b>Feature Overlap (Venn)</b> &mdash; interactive. Hover any region to see exactly which peptides are
shared between models. With 4+ models it switches to an interactive intersection list.</li>
<li><b>Consensus biomarkers</b> &mdash; features found by 2+ models (more robust). Send them to the Protein 3D tab.</li>
</ul>

<h2 id="sec-protein">4. Protein 3D <span class="tag">tab: Protein Visualization</span></h2>
<p>Goal: see where biomarkers sit on the protein, in sequence, 2D and 3D &mdash; all linked.</p>

<h3>4.1 Load a protein</h3>
<ol>
<li>Upload the <b>peptide annotation</b> of your array: one row per spotted peptide, with columns
<code>protein</code>, <code>accession</code>, <code>number</code>, <code>start</code> and either <code>end</code>
or the peptide <code>sequence</code>. Spanish headers
(<code>proteina, accesion, numero, inicio, fin, peptido</code>) are accepted too.</li>
<li>Pick the <b>protein</b> from the list the file declares.</li>
<li>Click <b>Load and Visualize</b>. The sequence and structure are fetched from the accession in the file.</li>
</ol>
<p>Positions are read from the file, not regenerated: an array tiled 15/1 or 12/1 maps as correctly as
the 20/3 design. When the file carries the peptide sequence, each position is checked against the UniProt
sequence, and whether the file numbers from the mature protein or from the full entry is detected rather
than assumed.</p>

<h3>4.2 The three linked views</h3>
<ul>
<li><b>Sequence strip</b> &mdash; the linear amino-acid list.</li>
<li><b>2D recognition map</b> &mdash; the serpentine peptide map: expression colour, biomarker halos,
disulfide bonds and PTMs.</li>
<li><b>3D structure</b> &mdash; cartoon (optionally surface) coloured by expression, with biomarkers highlighted.</li>
</ul>
<div class="note">Hovering a residue in any view highlights it in the other two and shows a tooltip
(full amino-acid name, position, biomarker, fold change, expression, PTM, disulfide partner).</div>

<h3>4.3 Controls</h3>
<ul>
<li><b>Isotype</b> (IgE / IgG4) and <b>Group</b> for colouring.</li>
<li><b>Colour by</b>: Expression, &Delta; between groups, or IgE&minus;IgG4.</li>
<li><b>FDR slider</b>, <b>surface</b> toggle, <b>biomarkers</b> toggle.</li>
<li><b>Export biomarkers (FASTA)</b> &mdash; downloads the significant biomarker peptide sequences.</li>
</ul>

<h2 id="sec-tips">Tips &amp; troubleshooting</h2>
<ul>
<li><b>Start fresh</b> &mdash; the &#8635; button (top-right) resets everything in one click.</li>
<li><b>Nothing joins / empty results</b> &mdash; check that metadata sample IDs match the expression sample names,
and that you set the right Sample ID column in the Peptide finder.</li>
<li><b>Volcano shows the wrong contrast</b> &mdash; set the Contrast Variable to your outcome; it defaults to the
analysis target.</li>
<li><b>Protein 3D shows nothing</b> &mdash; the protein name in the annotation file must appear in the peptide
column names, and those columns must carry a position id (e.g. <code>p11</code> or <code>p_11</code>).
The sidebar reports how many columns matched.</li>
<li><b>Models error or look wrong</b> &mdash; make sure a target with at least two groups is selected and that
enough features are available.</li>
</ul>
'
}
