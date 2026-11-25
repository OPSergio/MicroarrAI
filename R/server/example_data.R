# =============================================================================
# Built-in example datasets (www/examples, made by www/examples/make_examples.R)
# =============================================================================
# Synthetic two-group cohorts in ScanArray CSV format. Loading one stages its
# arrays exactly like an upload, so the whole pipeline runs on it unchanged.
# =============================================================================

EXAMPLE_DATASETS <- c(
  "Food allergy (IgE/IgG4)"   = "food_allergy",      # 120 patients, 5 food allergens
  "Airborne allergy (IgE/IgG4)" = "airborne_allergy", # 110 patients, pollen/mite/cat
  "Viral serology (IgG/IgA)"  = "viral_serology"     # 130 patients, EBV + SARS-CoV-2
)

#' Antibody isotype read in each scanner channel (Ch1, Ch2)
# Scanner channel 1 (red) then channel 2 (green), as on the lab's slides
EXAMPLE_CHANNELS <- list(food_allergy = c("IgG4", "IgE"),
                         airborne_allergy = c("IgG4", "IgE"),
                         viral_serology = c("IgA", "IgG"))

#' Folder of one example dataset
example_dir <- function(key) file.path("www", "examples", key)

#' Copy an example's arrays into a staging directory, as an upload would be
#'
#' @param key Character. One of EXAMPLE_DATASETS
#' @param dir Staging directory (emptied first)
#' @return `dir`
stage_example_arrays <- function(key, dir) {
  files <- list_array_files(file.path(example_dir(key), "arrays"))
  stage_uploaded_files(data.frame(name = basename(files), datapath = files), dir)
}
