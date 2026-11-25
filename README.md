# MicroarrAI

**End-to-end analysis platform for peptide microarrays**

[![R](https://img.shields.io/badge/R-4.4+-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/Shiny-1.7+-green.svg)](https://shiny.rstudio.com/)
[![License](https://img.shields.io/badge/license-MIT-orange.svg)](LICENSE)

MicroarrAI is an open-source R/Shiny web application for peptide microarray data. It takes raw scanner files through quality control, normalization, statistical testing, machine-learning biomarker selection and mapping of the signal onto each protein's sequence and 3D structure. No programming is required.

---

## Workflow

The app is organised in tabs that follow the analysis order:

1. **Preprocessing**: read the arrays, configure the controls and channels, normalize, impute and attach the clinical metadata
2. **Quality control**: score each array
3. **Peptide analysis**: run differential analysis and select candidate peptides
4. **Machine learning**: run supervised and unsupervised models and build a consensus biomarker list
5. **Protein visualization**: map the signal onto each protein in 2D and 3D

Built-in example data can be loaded from the Preprocessing tab.

### 1. Data input and preprocessing

- **Input modes:** raw scanner files, or an already processed expression matrix (samples in rows or in columns; .csv/.txt/.tsv/.xlsx).
- **Scanner files:** GenePix ATF `.gpr` and tabular exports (`.csv`, `.txt`, `.tsv`). The reader detects the header, separator, encoding and the foreground/background column pair of every channel. The array-reader tests cover GenePix, Mapix/InnoScan and ScanArray files. Any number of channels is supported (e.g. IgE and IgG4), and channels with no signal (scanned at gain 0) are reported and dropped.
- **Spot filtering:** GenePix flags drop *bad* (−100) and *absent* (−75) spots. *Not found* (−50) spots are kept, because they are non-reactive peptides and blank controls. ScanArray-style flags use a threshold.
- **Spot value:** `log2(foreground / background)` (default) or `foreground − background`, computed from the median intensities.
- **Within-array normalization:** a robust z-score against the negative-control spots, `(x − median_neg) / MAD_neg`, computed per array and channel. Positive and negative controls are then removed and technical replicates are averaged.
- **Between-array normalization (optional):** per-sample median/MAD scaling, or quantile normalization (Bolstad et al., 2003).
- **Missing values:** they come from flagged spots, so they are imputed rather than set to zero. Options are k-nearest neighbours (default), Random Forest (missForest-style) or the per-peptide median.
- **Output:** the processed expression matrix can be previewed and downloaded.

### 2. Quality control

Each array gets a scorecard with six metrics, each graded green/amber/red against thresholds that are documented in the app:

- replicate agreement
- positive-control dilution slope
- signal-to-noise ratio of the top-dose positive control (green ≥ 10 SD, red < 3 SD: the classical quantification and detection limits)
- background stability
- % missing spots
- % saturated spots

The tab also shows per-array signal distributions and Q-Q plots.

### 3. Differential analysis and candidate selection

- Near-zero-variance peptides are removed.
- A linear model `Expression ~ Group` is fitted per peptide. With two groups it reports the mean difference and its p-value. With three or more it reports the global F-test plus pairwise contrasts taken from the same model.
- Alternative tests: t-test, ANOVA, Wilcoxon and Kruskal–Wallis.
- Multiple testing: Benjamini–Hochberg FDR.
- Plots: volcano plots and annotated heatmaps (ComplexHeatmap).
- Per-peptide discrimination: logistic (binomial or multinomial) regression with ROC curves and AUC (pROC).
- The peptides passed to machine learning are either the top N by p-value and AUC, or those above an AUC threshold.

### 4. Machine learning

**Supervised** (caret):

- Classifiers: C5.0, Random Forest, SVM and XGBoost.
- Evaluation: repeated k-fold cross-validation, with optional hyperparameter tuning and recursive feature elimination (RFE).
- Metrics, computed on out-of-fold predictions: accuracy, kappa, sensitivity, specificity and AUC.
- Variable importance per model, plus SHAP values for XGBoost (shapviz).
- **Consensus biomarkers:** peptides that rank in the top N of at least two models.
- PLS-DA score plot (mixOmics) as a supervised projection.
- A warning is shown when the sample size is small or much smaller than the number of peptides.

**Unsupervised:**

- PCA, PCoA and NMDS, with Euclidean, Manhattan, Canberra or Bray–Curtis distance.
- DBSCAN and hierarchical clustering heatmaps.
- Clinical variables are used only to colour the plots. The projections can be explored in 2D and in interactive 3D, drawn natively in the browser.

### 5. Protein mapping (2D and 3D)

- The sequence, post-translational modifications and signal peptide are retrieved from **UniProt** using the protein's accession.
- Each array peptide is placed on the sequence, either from the array annotation or from the tiling design (peptide length and offset).
- The residue-level signal is the mean of all peptides covering that residue, computed per clinical group and isotype.
- **2D:** an interactive snake plot that highlights the selected biomarker peptides.
- **3D:** the **AlphaFold** model of the protein, with its pLDDT confidence and coverage reported. When no model exists, the app uses the best-covering experimental **PDB** structure (via the PDBe/SIFTS mappings). The signal is coloured onto the structure with **3Dmol.js**.
- This tab needs internet access to UniProt, AlphaFold DB and PDBe.

### Report, downloads and logs
- **Report (PDF):** the *Report* button (top right, any tab) builds a PDF with every parameter entered, the input data, the quality-control scorecard, the differential analysis, the model validation with confidence intervals, the consensus biomarkers and their positions on the proteins, plus software versions and a methods summary. Steps not yet run are marked as such.
- **All results (Excel):** the same content as one workbook, one sheet per table (scorecard, differential results, validation, consensus, train/test partition, variable importance per model, …).
- Every interactive chart downloads as PNG or SVG, every server-rendered plot as PNG; the processed matrix, volcano table, QC scorecard, biomarker FASTA and residue-level signal have their own downloads.
- **Step log:** each step writes `date level [session] STEP | what was asked or done | details` to the server log (shown live in the admin panel). Refusals and failures say why and what to do (`why=…, hint=…`). Only counts and setting names are logged, never patient values.

---

## Installation & Deployment

MicroarrAI ships as **Docker** and **Singularity/Apptainer** images. Both are built on `rocker/shiny-verse:4.4.0` from one dependency list (`dependencies.R`), so workstation and HPC deployments run the same software.

### Quick Start

```bash
git clone https://github.com/OPSergio/MicroarrAI.git
cd MicroarrAI
chmod +x deploy.sh docker/docker-deploy.sh singularity/singularity-deploy.sh
./deploy.sh
```

See [INSTALLATION.md](INSTALLATION.md) for detailed configuration, persistent data management and troubleshooting.
