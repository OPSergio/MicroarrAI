# Preprocessing Pipeline Update - Documentation

## Overview
This document describes the robust preprocessing pipeline implemented for two-channel microarray data analysis in MicroarrAI.

## Date
December 30, 2025

---

## Key Features Implemented

### 1. **Dual Input Mode Support**
- **RAW microarray files (GenePix CSV)**: Process raw scanner output
- **Processed expression matrix**: Upload pre-normalized data

### 2. **Automatic GenePix Header Detection**
- No more hardcoded skip values
- Automatically detects the header row by searching for "Block" column
- Fallback to default (60 rows) if detection fails

### 3. **Analyte ID Cleaning**
- Trims whitespace
- Replaces spaces with underscores
- Removes special characters (keeps only alphanumeric, underscore, hyphen)
- Ensures uniqueness across all analytes

### 4. **User-Configurable Negative Controls**
- Dynamic control selector populated from actual data
- No hardcoded assumptions (e.g., "PBS 1X")
- Supports multiple negative controls
- Optional positive controls for QC

### 5. **Channel-Independent Normalization**
- Each channel (Ch1, Ch2) normalized separately
- User-defined channel labels (default: IgE, IgG4)
- Supported methods:
  - **Z-score**: Based on user-selected negative controls
  - **Median Scaling**: Simple centering

### 6. **Inter-Sample Normalization (Optional)**
- Robust Scaling (mean centering + scaling)
- Centering only
- Quantile normalization (with warning about distribution alteration)

### 7. **Clinical Metadata Management**
- File upload (.csv, .xlsx)
- Interactive preview table with search/filter
- **Editable table** (rhandsontable integration)
- Apply/Revert changes functionality
- Column selectors for sample ID and target variable
- Validation of sample ID matching

### 8. **Enhanced Download**
Multi-sheet Excel workbook containing:
- Expression data (dual-channel with prefixes)
- Clinical metadata (with user edits)
- Processing log (parameters, controls, date)

---

## File Changes

### Core Processing Functions (`R/server/data_processing.R`)

#### New Functions Added:

1. **`detect_genepix_header(file_path)`**
   - Automatically finds header row in GenePix files
   - Returns skip value for read.csv()

2. **`clean_analyte_ids(ids)`**
   - Standardizes analyte identifiers
   - Ensures uniqueness

3. **`normalize_channel(expression, ids, method, negative_controls)`**
   - Channel-independent normalization
   - User-configurable negative controls
   - Returns normalized vector

4. **`get_unique_analytes(file_paths)`**
   - Extracts unique analyte IDs from RAW files
   - Used to populate UI control selectors

5. **`validate_processed_matrix(file_path)`**
   - Validates uploaded processed matrices
   - Checks for ID column and numeric features

#### Updated Functions:

1. **`read_microarray_file()`**
   - Added auto-detection of GenePix header
   - Integrated analyte ID cleaning
   - Returns both channels (Expression_Ch1, Expression_Ch2)

2. **`process_microarray_batch()`**
   - Added parameters: `negative_controls`, `channel_labels`
   - Normalizes each channel independently
   - Pivots data with channel prefixes (e.g., IgE_p001, IgG4_p001)
   - Averages technical replicates

3. **`normalize_expression()` (Legacy)**
   - Updated to use new `normalize_channel()` function
   - Maintains backward compatibility

---

### UI Updates (`R/ui/ui_preprocess.R`)

#### New UI Components:

1. **Input Mode Selector**
   ```r
   radioButtons("input_mode", ...)
   - "RAW microarray files (GenePix)"
   - "Processed expression matrix"
   ```

2. **RAW Mode Controls** (conditionalPanel)
   - Folder selector
   - Channel label text inputs (ch1_label, ch2_label)
   - Negative controls multi-select
   - Positive controls multi-select (optional)

3. **Processed Mode Controls** (conditionalPanel)
   - File upload (.csv/.xlsx)
   - Validation status display

4. **Normalization Settings** (RAW mode only)
   - Intra-sample method selector
   - Inter-sample normalization checkbox
   - Inter-sample method selector (conditional)

5. **Metadata Preview Section**
   - Column selectors (sample ID, target variable)
   - Editable rhandsontable
   - Apply/Revert buttons

#### Updated Components:
- Download button now downloads multi-sheet Excel workbook
- Data preview shows expression matrix
- Density plot maintained

---

### Server Logic Updates (`app.R`)

#### New Reactive Values:
- `available_analytes()`: Stores unique analyte IDs from RAW files
- `database_edited()`: Stores user edits to clinical metadata

#### New Observers:

1. **Analyte ID Extraction** (`observeEvent(path1())`)
   - Triggers when RAW folder selected
   - Populates control selectors

2. **Process Button** (Updated)
   - Validates negative controls selection
   - Passes channel labels to batch processor
   - Applies inter-sample normalization if enabled

3. **Processed Matrix Upload** (`observeEvent(input$pep_fileinput)`)
   - Validates uploaded matrix
   - Sets processed_data() directly

4. **Metadata Editing**
   - `output$metadata_table`: Renders editable table
   - `apply_metadata_edits`: Saves user changes
   - `revert_metadata_edits`: Restores original

5. **Clinical Database Upload** (Updated)
   - Supports .csv and .xlsx
   - Initializes both `database()` and `database_edited()`
   - Updates column selectors

6. **Download Handler** (Updated)
   - Creates multi-sheet workbook
   - Includes processing log

#### Updated Reactives:

1. **`pepdata()`**
   - Simplified to use `processed_data()` from both modes
   - Removes file upload dependency (now handled in preprocess tab)
   - Maintains example data generation

---

## Dependencies Added

- **rhandsontable**: For editable metadata tables
  - Added to `R/global.R`

---

## Usage Flow

### RAW Microarray Workflow:

1. **Select Input Mode**: Choose "RAW microarray files"
2. **Select Folder**: Browse to GenePix CSV directory
3. **Configure Channels**: Set labels (default: IgE, IgG4)
4. **Select Controls**: 
   - Choose negative controls (required)
   - Optionally select positive controls
5. **Choose Normalization**: 
   - Intra-sample method (Z-score or Median Scaling)
   - Optionally enable inter-sample normalization
6. **Upload Clinical Data**: Upload metadata (.csv/.xlsx)
7. **Edit Metadata**: Use interactive table to make corrections
8. **Process**: Click "Start Normalization Process"
9. **Download**: Export multi-sheet Excel with data, metadata, and log

### Processed Matrix Workflow:

1. **Select Input Mode**: Choose "Processed expression matrix"
2. **Upload Matrix**: Upload .csv or .xlsx file
3. **Validation**: System checks for ID column and numeric features
4. **Upload Clinical Data**: Upload metadata
5. **Edit Metadata**: Use interactive table
6. **Download**: Export combined workbook

---

## Backward Compatibility

### Maintained:
- Legacy `normalize_expression()` function still works
- Existing pepdata reactive works with both input modes
- All downstream tabs (Peptide, ML, Visualization) receive data unchanged

### Breaking Changes:
- None! The new system is additive and backward compatible

---

## Data Flow

```
RAW Mode:
GenePix CSV → read_microarray_file() → normalize_channel() (Ch1 & Ch2) 
→ process_microarray_batch() → processed_data() → pepdata() → ML/Viz tabs

Processed Mode:
Uploaded Matrix → validate_processed_matrix() → processed_data() 
→ pepdata() → ML/Viz tabs

Clinical Data:
Upload → database() → database_edited() (user edits) → Download
```

---

## Quality Control

### Implemented:
- Flag filtering (Flags < threshold)
- Automatic header detection
- Analyte ID cleaning and uniqueness
- Matrix validation for uploads
- Sample ID matching between expression and metadata

### Future Enhancements:
- QC metrics display (negative control statistics)
- Positive control signal verification
- Sample correlation heatmap
- Batch effect visualization
- Missing value handling options

---

## Testing Recommendations

1. **Test RAW Processing**:
   - Upload GenePix CSV files
   - Verify analyte IDs populate controls
   - Test Z-score normalization with different controls
   - Check dual-channel output format

2. **Test Processed Matrix Upload**:
   - Upload pre-normalized data
   - Verify validation messages
   - Ensure downstream compatibility

3. **Test Metadata Editing**:
   - Upload clinical data
   - Make edits in table
   - Apply and verify changes
   - Test revert functionality

4. **Test Downloads**:
   - Verify all sheets present
   - Check processing log accuracy
   - Validate metadata edits included

5. **Test Downstream Compatibility**:
   - Navigate to Peptide tab
   - Run ML models
   - Generate visualizations
   - Ensure no errors with dual-channel data

---

## Notes for Future Development

### Potential Enhancements:
1. **Background subtraction methods**: Currently uses simple ratio; could add alternatives
2. **Batch correction**: Combat or similar for multi-batch experiments
3. **Missing value imputation**: Handle missing features gracefully
4. **Sample outlier detection**: Automatic flagging of problematic samples
5. **Channel merging options**: Ratio, difference, or other metrics
6. **Export to other formats**: Support for .rds, .h5, etc.

### Code Maintenance:
- All core functions are pure (no Shiny dependencies)
- Server logic is modular and reactive
- UI is conditionally rendered based on mode
- Error handling with user-friendly messages

---

## Summary

This update implements a **robust, flexible, and user-friendly preprocessing pipeline** that:
- ✅ Supports both RAW and processed input
- ✅ Handles dual-channel data independently
- ✅ Eliminates hardcoded assumptions
- ✅ Provides interactive metadata editing
- ✅ Maintains full backward compatibility
- ✅ Delivers comprehensive output with documentation

The implementation follows best practices with clean separation of concerns, pure backend functions, and reactive frontend orchestration.
