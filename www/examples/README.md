# MicroarrAI example datasets (synthetic)

Three two-group cohorts for the tutorial (`www/tutorial/index.html`) and as the
test data the software needs to ship with. In the app, load them from
**Preprocessing › sidebar ☰ › Example data › Load example**.

**These data are synthetic and contain no patient information.** The signal levels
follow aggregate statistics of real slides: blank log2(F/B) SD ≈ 0.1, local
background ≈ 1240 (Ch1) and ≈ 330 (Ch2), and peptide-specific non-specific binding
shared by duplicate spots. No individual patient value was used.

| Folder | Groups | Channels | Proteins (UniProt) | Peptides |
|---|---|---|---|---|
| `food_allergy` | 62 Allergic · 58 Tolerant | Ch1 IgG4 (red) · Ch2 IgE (green) | Ara h 2 (Q6PSU2), Bos d 5 (P02754), Bos d 9 (P02662), Gal d 1 (P01005), Pru p 3 (P81402) | 257 × 20-mers, offset 3 |
| `airborne_allergy` | 56 Symptomatic · 54 Asymptomatic | Ch1 IgG4 (red) · Ch2 IgE (green) | Bet v 1 (P15494), Der p 1 (P08176), Der p 2 (P49278), Fel d 1 (P30438), Ole e 1 (P19963) | 162 × 15-mers, offset 5 |
| `viral_serology` | 65 Multiple sclerosis · 65 Control | Ch1 IgA (red) · Ch2 IgG (green) | EBNA1 330–641 (P03211), VCA p18 (P14348), SARS-CoV-2 spike RBD 319–541 (P0DTC2), nucleoprotein (P0DTC9) | 271 × 15-mers, offset 4 |

Each folder holds:

- `arrays/` holds one ScanArray-style CSV per patient. Each has two channels, duplicate peptide spots (`p N (Protein)`), 60 `PBS 1X` blanks, 4 `empty` spots and a 4-step positive-control series (`aIgE_…` or `aIgG_…`).
- `clinical.csv` has `id` (matching the array file names) and `Group`, plus a few covariates.
- `annotation.csv` holds the peptide positions for the 3D visualization tab (`protein, accession, number, start, end, peptide`).

## Simulated biology

- **Group 1 epitopes.** Epitopes marked `diff` are recognised by 75 % of group-1 patients in the primary isotype (IgE or IgG, Ch2) and by 20 % of group-2 patients, with stronger binding in group 1.
- **Allergy cohorts, IgG4 (Ch1).** In both allergy cohorts, IgG4 favours the second group on the same epitopes, mimicking tolerance.
- **Shared epitopes.** Epitopes marked `shared` appear in both groups at the same rate. In the viral cohort this applies to all SARS-CoV-2 epitopes and to IgA.

## Problem arrays (planted for the Quality Control tab)

| Cohort | Failed assay (no signal, flat positive control) | Print defects (12 % of spots flagged) | Background gradient |
|---|---|---|---|
| food_allergy | FA-058 | FA-110 | FA-055 |
| airborne_allergy | AA-034 | AA-100 | AA-007 |
| viral_serology | VS-119 | VS-048 | VS-051 |

## Regenerating

Run this from the repo root. It needs internet access, because sequences are fetched from UniProt.

```
Rscript www/examples/make_examples.R
```

The seed is fixed (2026), so the output is reproducible as long as the UniProt sequences do not change.
