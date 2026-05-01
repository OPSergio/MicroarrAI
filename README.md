# MicroarrAI

**Advanced Peptide Microarray Analysis Platform**

[![R](https://img.shields.io/badge/R-4.4+-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/Shiny-1.7+-green.svg)](https://shiny.rstudio.com/)
[![License](https://img.shields.io/badge/license-MIT-orange.svg)](LICENSE)

MicroarrAI is a comprehensive Shiny-based computing platform for peptide microarray data analysis, featuring advanced machine learning algorithms, statistical analysis, and interactive visualizations.

---

## Platform Modules & Methodology

### Preprocessing and Quality Control
The preprocessing module performs quality control filtering by removing spots with negative scanner quality flags, followed by local or global background subtraction. Inter-array technical variability is addressed using systematic normalization methods documented for the platform, including quantile normalization and variance-stabilizing normalization [8]. Intensities are transformed to logarithmic scale, and replicated spots are aggregated to feature-level summaries, typically by median. The resulting normalized matrix is exposed by the preprocessing module and represents the principal dependency for all inferential and machine-learning stages. Quality diagnostics include MA and density representations of pre- and post-normalization distributions, and cleaned outputs are produced in exportable tabular formats.

### Peptide Summarization
A peptide summarization module transforms platform-centric coordinates into biology-centric entities. Expression matrices are merged with GAL or custom annotation tables to map spots to peptide sequences and parent protein identifiers. Technical replicates with identical peptide sequences are collapsed using configurable aggregation operators (mean, median, or maximum). Sequence strings are standardized, including optional removal of linker fragments such as `GSGSG` when present. The module generates peptide-level data structures and positional annotation-ready structures that are used by downstream sequence mapping and protein visualization routines.

### Statistical Analysis
**Categorical Analysis:** Conducted on normalized peptide data using user-defined contrasts derived from categorical metadata. Peptide-wise hypothesis testing is executed primarily through Linear Models (LMs), providing a robust estimation of differential expression and coefficients for complex designs. Effect sizes are represented as $\log_2$ fold changes, and multiplicity control is applied using Benjamini-Hochberg false discovery rate adjustment. In future updates, the PERSEO statistical framework will be natively implemented to expand the suite of available statistical tests and imputation methods.

**Continuous Association Analysis:** Implemented in a dedicated regression module using normalized peptide intensities and continuous metadata covariates aligned by sample intersection. Missingness is handled by pairwise deletion or imputation according to workflow configuration. Peptide-wise ordinary least squares models are fitted iteratively, with optional multivariate configurations when covariates are defined. The general formulation is:

$$ Y_{ij} = \beta_{0j} + \beta_{1j}X_i + \varepsilon_{ij} $$

where $Y_{ij}$ denotes normalized expression for peptide $j$ in sample $i$, and $X_i$ denotes the selected clinical continuous variable. Reported outputs include beta estimates, confidence intervals, $R^2$, F-statistics, and multiplicity-adjusted *p*-values.

### Machine Learning
**Supervised Learning:** The supervised machine-learning module receives normalized matrices and categorical targets from metadata. Data are partitioned into training and internal testing subsets (e.g., 70% and 30%), optional centering and scaling are applied within folds to reduce leakage, and model fitting is performed through cross-validated grid search. Documented algorithms include Random Forest, SVM with radial kernel, and PLS-DA [17-19]. Hold-out predictions are used to derive confusion matrices and classification metrics. For binary classification outputs, reported metrics follow standard definitions:

$$ \mathrm{Sensitivity}=\frac{TP}{TP+FN}, \quad \mathrm{Specificity}=\frac{TN}{TN+FP}, \quad \mathrm{PPV}=\frac{TP}{TP+FP} $$

The ROC-area endpoint is summarized as:

$$ \mathrm{AUC}=\int_{0}^{1} TPR(FPR)\,d(FPR) $$

The auxiliary `ml_rfe_helpers.R` module implements recursive feature elimination (RFE) as a backward-selection wrapper that repeatedly ranks and prunes low-importance peptides under $k$-fold cross-validation. Subset selection is guided by cross-validated performance profiles (accuracy, kappa, and AUC), and the selected subset size corresponds to the maximal score under the specified resampling design.

**Unsupervised Learning:** Performs exploratory structure analysis without using labels for model fitting. Matrices are reformatted to sample-by-feature orientation when needed and standardized by feature-wise Z-scores:

$$ Z_{ij}=\frac{X_{ij}-\mu_j}{\sigma_j} $$

before dimensionality reduction with PCA, t-SNE, or UMAP [11]. Optional clustering is performed using $k$-means or agglomerative hierarchical procedures in reduced or full spaces. Clinical metadata are projected post hoc for color mapping only. The module produces coordinate matrices, scree outputs for PCA, two- and three-dimensional embeddings, and dendrogram-ready structures. Because t-SNE and UMAP are stochastic, reproducibility depends on fixed random seeds as indicated in module documentation.

### Protein Mapping and Visualization
**Linear Protein Mapping:** Protein-focused visualization maps aggregated peptide signals to full-length target protein sequences. Short peptides (e.g., 15-mers) are aligned to primary sequences to recover start and end indices, and reactivity trajectories are summarized along residue positions using moving averages and optional LOESS smoothing. Statistical outputs from categorical testing can be used to highlight significant regions in the linear profile. This layer generates positional epitope data frames and linear N-terminus-to-C-terminus snake plots. When HTML integration is enabled, mapped signals can be superimposed on three-dimensional structures through NGL-based logic.

**Interactive 3D Visualization:** The dedicated three-dimensional visualization module consumes coordinate outputs from unsupervised analyses and merges them with metadata for interactive rendering. Axis mappings, hover labels, and color encodings are user-configurable. Plot generation is implemented with Plotly WebGL traces and supports zoom, pan, rotation, and widget-level export. According to the module specification, rendering performance declines substantially beyond approximately 10,000 points in a single interactive scene.

---

## Installation & Deployment

MicroarrAI supports both **Docker** and **Singularity/Apptainer** deployments to ensure reproducibility across workstations and HPC environments.

### Quick Start

```bash
git clone https://github.com/OPSergio/MicroarrAI.git
cd MicroarrAI
chmod +x deploy.sh docker/docker-deploy.sh singularity/singularity-deploy.sh
./deploy.sh
```

Please refer to [INSTALLATION.md](INSTALLATION.md) for detailed configuration, persistent data management, and troubleshooting.
