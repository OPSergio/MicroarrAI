# =============================================================================
# STAGING UPLOADED RAW SCANS
# =============================================================================
# Users upload their own scan files; nothing is ever read from, or written to,
# a shared location on the server. The RAW pipeline works on a *directory* of
# GenePix CSVs and derives sample IDs from the file names, but Shiny hands
# uploads over as randomly named temp files (0.csv, 1.csv, ...). These helpers
# copy an upload back into a per-session directory under its original names, so
# the rest of the pipeline keeps working unchanged and sample IDs stay correct.
#
# The directory lives in the session's tempdir and is deleted when the session
# ends, so no user data persists in the container.
# =============================================================================


#' Create a private staging directory for one session's uploads
#'
#' @return Absolute path to a new, empty directory inside the R temp directory.
new_upload_dir <- function() {
  dir <- file.path(tempdir(), paste0("microarrai_raw_", basename(tempfile(""))))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}


#' Copy an uploaded file set into a staging directory under its original names
#'
#' @param upload The data frame Shiny puts in `input$<id>` for a fileInput with
#'   `multiple = TRUE`: one row per file, with `name` (the name on the user's
#'   machine) and `datapath` (Shiny's temp copy).
#' @param dir Target directory. Emptied first, so re-uploading replaces the
#'   previous selection instead of silently merging with it.
#' @return `dir`, or `""` when there is nothing to stage.
stage_uploaded_files <- function(upload, dir) {
  if (is.null(upload) || nrow(upload) == 0) return("")

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  unlink(list.files(dir, full.names = TRUE), recursive = TRUE)

  # basename() keeps a crafted upload name from escaping the staging directory
  targets <- file.path(dir, basename(upload$name))
  copied <- file.copy(upload$datapath, targets, overwrite = TRUE)

  if (!all(copied)) {
    warning("Could not stage ", sum(!copied), " of ", nrow(upload),
            " uploaded files.")
  }

  dir
}
