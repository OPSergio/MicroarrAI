# Array file reader: .gpr (ATF) from different scanners, plus ScanArray CSV.
# Fixtures are synthetic copies of each layout, written byte for byte.

suppressWarnings(suppressPackageStartupMessages({ library(dplyr); library(tidyr) }))  # "built under R x.y" noise
source(file.path(repo, "R", "server", "normalization.R"), encoding = "UTF-8")
source(file.path(repo, "R", "server", "data_processing.R"), encoding = "UTF-8")

crlf <- function(...) paste0(paste(c(...), collapse = "\r\n"), "\r\n")
row <- function(...) paste(c(...), collapse = "\t")

# Mapix / InnoScan .gpr: CRLF, quoted header names, unquoted values with
# commas inside the peptide name, GenePix flags: 100 good, 0, -50 not found
# (blank PBS and non-reactive peptides, like the real scans), -100 bad, -75 absent
mapix_gpr <- function(path, shift = 0) {
  write_log(path, crlf(
    "ATF\t1.0", "3\t14",
    '"Type=GenePix Results 3"', '"Creator=Mapix 9.1.0"', '"Supplier=Scienion AG"',
    row('"Name"', '"ID"', '"Block"', '"Column"', '"Row"', '"X"', '"SNR 532"', '"Y"', '"Flags"',
        '"F532 Median"', '"B532 Median"', '"F635 Median"', '"B635 Median"', '"F635 % Sat."'),
    row("anti-rat (0,1 ug/ul)", "anti-rat (0,1 ug/ul)", 1, 1, 1, 9358, 194.5, 7377, 100, 65535, 598, 900, 300, 0),
    row("PBS 1X", "PBS 1X", 1, 2, 1, 9650, 2.1, 7374, 0, 600 + shift, 500, 310, 300, 0),
    row("PBS 1X", "PBS 1X", 1, 3, 1, 9950, 2.3, 7373, 0, 640 + shift, 500, 320, 300, 0),
    row("PBS 1X", "PBS 1X", 1, 4, 1, 9970, 2.0, 7373, -50, 580 + shift, 500, 300, 300, 0),
    row("pep1 (2 ug/ul)", "pep1 (2 ug/ul)", 1, 5, 1, 10250, 30.5, 7378, 100, 4000 + shift, 500, 1200, 300, 3),
    row("pep2 (2 ug/ul)", "pep2 (2 ug/ul)", 1, 6, 1, 10550, 0.4, 7378, -50, 520, 500, 310, 300, 0),
    row("pep3 (2 ug/ul)", "pep3 (2 ug/ul)", 1, 7, 1, 10850, 9.0, 7378, -100, 3000, 500, 900, 300, 0),
    row("pep4 (2 ug/ul)", "pep4 (2 ug/ul)", 1, 8, 1, 11150, 0.1, 7378, -75, 500, 500, 300, 300, 0)))
}

test_that("a Mapix .gpr is read: header, both channels, commas inside names", {
  f <- withr::local_tempfile(fileext = ".gpr")
  mapix_gpr(f)

  h <- detect_array_header(f)
  expect_equal(h[c("skip", "sep", "atf")], list(skip = 5, sep = "\t", atf = TRUE))

  spots <- read_microarray_file(f)
  expect_setequal(unique(spots$channel), c("532", "635"))
  expect_true("anti-rat_01_ugul" %in% spots$ID)
  pep1 <- spots$Expression[spots$ID == "pep1_2_ugul" & spots$channel == "532"]
  expect_equal(pep1, log2(4000 / 500))
})

test_that(".gpr flags follow GenePix: drop -100 (bad) and -75 (absent), keep the rest", {
  f <- withr::local_tempfile(fileext = ".gpr")
  mapix_gpr(f)
  spots <- read_microarray_file(f)
  ids <- unique(spots$ID)

  expect_true(all(c("anti-rat_01_ugul", "pep1_2_ugul") %in% ids))  # 100 (good)
  expect_true("pep2_2_ugul" %in% ids)                              # -50: no signal is data
  expect_equal(sum(spots$ID == "PBS_1X" & spots$channel == "532"), 3)  # 0, 0 and -50 all kept
  expect_false(any(c("pep3_2_ugul", "pep4_2_ugul") %in% ids))      # -100, -75
})

test_that("an ATF file whose declared header length is wrong still finds the header", {
  # GenePix-like: says 2 header lines but has 3, quoted values, one channel, LF
  f <- withr::local_tempfile(fileext = ".gpr")
  write_log(f, paste0(paste(
    "ATF\t1.0", "2\t6", '"Type=GenePix Results 3"', '"Creator=GenePix Pro 7"', '"Scanner=GenePix 4000B"',
    row('"Block"', '"Column"', '"Row"', '"Name"', '"ID"', '"Flags"', '"F635 Median"', '"B635 Median"'),
    row(1, 1, 1, '"pep1"', '"pep1"', 0, 2000, 250),
    row(1, 2, 1, '"pep2"', '"pep2"', -100, 300, 250),
    sep = "\n"), "\n"))

  expect_equal(detect_array_header(f)$skip, 5)
  spots <- read_microarray_file(f)
  expect_equal(unique(spots$channel), "635")
  expect_equal(spots$ID, "pep1")                       # -100 (bad) dropped
  expect_equal(spots$Expression, log2(2000 / 250))
})

test_that("ScanArray CSV keeps its own flag rule (below the threshold)", {
  f <- withr::local_tempfile(fileext = ".csv")
  write_log(f, crlf(
    "ScanArray Express export", "",
    "ID,Ch1 Median,Ch1 B Median,Flags",
    "pepA,1000,100,0", "pepB,1000,100,3", "pepC,1000,100,5"))

  h <- detect_array_header(f)
  expect_false(h$atf)
  expect_equal(read_microarray_file(f)$ID, c("pepA", "pepB"))
})

test_that("quality columns are found whatever the scanner names them", {
  f <- withr::local_tempfile(fileext = ".gpr")
  mapix_gpr(f)
  q <- read_microarray_file(f, with_quality = TRUE)

  expect_equal(q$snr[q$ID == "pep1_2_ugul" & q$channel == "532"], 30.5)   # "SNR 532"
  expect_equal(q$saturation[q$ID == "pep1_2_ugul" & q$channel == "635"], 3) # "F635 % Sat."
  expect_true(all(is.na(q$saturation[q$channel == "532"])))                # no F532 % Sat.
})

test_that("list_array_files takes .gpr/.GPR/.tsv and ignores anything else", {
  d <- withr::local_tempdir()
  for (n in c("a.gpr", "b.GPR", "c.csv", "d.txt", "e.tsv", "f.pdf", "g.gal")) write_log(file.path(d, n), "x")
  expect_setequal(basename(list_array_files(d)), c("a.gpr", "b.GPR", "c.csv", "d.txt", "e.tsv"))
})

test_that("a channel scanned at gain 0 is reported as silent, and the other one still works", {
  f <- withr::local_tempfile(fileext = ".gpr")
  write_log(f, crlf("ATF\t1.0", "0\t7",
    row('"Name"', '"ID"', '"Flags"', '"F532 Median"', '"B532 Median"', '"F635 Median"', '"B635 Median"'),
    row("PBS", "PBS", 0, 600, 500, 0, 0), row("PBS", "PBS", 0, 650, 500, 1, 0),
    row("PBS", "PBS", 0, 560, 500, 0, 0), row("pep1", "pep1", 100, 4000, 500, 0, 0)))
  header <- detect_array_header(f)
  df <- utils::read.delim(f, sep = header$sep, skip = header$skip, check.names = FALSE)
  expect_equal(silent_array_channels(df), "635")

  mapix <- withr::local_tempfile(fileext = ".gpr")
  mapix_gpr(mapix)
  header <- detect_array_header(mapix)
  expect_length(silent_array_channels(utils::read.delim(mapix, sep = "\t", skip = header$skip, check.names = FALSE)), 0)

  # Analysing only the live channel normalizes fine
  d <- withr::local_tempdir()
  file.copy(f, file.path(d, "s1.gpr"))
  out <- process_microarray_batch(list_array_files(d), negative_controls = "PBS", channels = "532")
  expect_equal(nrow(out), 1)
  expect_true(any(grepl("pep1", names(out))))
  expect_false(any(grepl("635", names(out))))
})

test_that("the encoding is detected per file: UTF-8 .gpr and latin1 CSV both decode", {
  gpr <- withr::local_tempfile(fileext = ".gpr")
  write_log(gpr, crlf("ATF\t1.0", "0\t5",
                      row('"Name"', '"ID"', '"Flags"', '"F532 Median"', '"B532 Median"'),
                      row("caseína (0,1 ug/ul)", "caseína (0,1 ug/ul)", 100, 900, 300)))
  expect_equal(detect_array_header(gpr)$encoding, "UTF-8")
  expect_false(grepl("Ã", read_microarray_file(gpr)$ID))   # no "caseÃ­na"
  expect_match(read_microarray_file(gpr)$ID, "^case.*na_01_ugul$")

  csv <- withr::local_tempfile(fileext = ".csv")
  con <- file(csv, "wb")
  writeBin(iconv("ID,Ch1 Median,Ch1 B Median,Ch1 Rgn R²\r\npep µ1,1000,100,0.9\r\n", "UTF-8", "latin1", toRaw = TRUE)[[1]], con)
  close(con)
  expect_equal(detect_array_header(csv)$encoding, "latin1")
  expect_equal(read_microarray_file(csv)$Expression, log2(10))
})

test_that("a batch of .gpr files becomes one row per file, named after it", {
  d <- withr::local_tempdir()
  names <- c("2026-10-22_10µm_Huevo_0005_b1", "2026-10-22_10µm_Huevo_0005_b2", "2026-10-22_10µm_Huevo_0006_b1")
  for (i in seq_along(names)) mapix_gpr(file.path(d, paste0(names[i], ".gpr")), shift = 10 * i)

  out <- process_microarray_batch(list_array_files(d), negative_controls = c("PBS_1X"))
  expect_equal(nrow(out), 3)
  expect_setequal(out$id, names)
  expect_true(any(grepl("pep1_2_ugul", names(out))))
  expect_true(any(grepl("pep2_2_ugul", names(out))))             # -50 kept
  expect_false(any(grepl("pep3|pep4", names(out))))               # -100, -75 dropped
  expect_false(any(grepl("PBS_1X", names(out))))   # negative control removed
})

# Optional: run the reader over real scanner files without committing them.
#   MICROARRAI_GPR_SAMPLES=/path/to/gpr/folder Rscript tests/run_tests.R
test_that("real .gpr files (if provided) are all readable", {
  dir <- Sys.getenv("MICROARRAI_GPR_SAMPLES")
  skip_if(!nzchar(dir), "MICROARRAI_GPR_SAMPLES not set")
  files <- list_array_files(dir)
  expect_gt(length(files), 0)
  for (f in files) {
    spots <- read_microarray_file(f, with_quality = TRUE)
    expect_gt(nrow(spots), 0, label = basename(f))
    expect_false(anyNA(spots$ID), label = basename(f))
  }
})
