# CHANGELOG - Preprocessing Pipeline Update

## Version 2.0 - December 30, 2025

### Major Features Added

#### 🔬 Dual Input Mode Support
- **RAW microarray processing**: GenePix CSV files with automatic header detection
- **Processed matrix upload**: Direct upload of pre-normalized data
- Radio button selector for choosing input mode
- Conditional UI rendering based on selected mode

#### 🎯 User-Configurable Controls
- **Dynamic negative control selector**: Populated from actual data
- **Optional positive control selector**: For QC purposes
- **No hardcoded assumptions**: Users select their own controls
- **Multi-select support**: Choose multiple negative controls

#### 🧬 Independent Channel Processing
- **Dual-channel normalization**: Ch1 and Ch2 processed separately
- **Custom channel labels**: User-defined (default: IgE, IgG4)
- **Channel prefixing**: Output columns clearly labeled (e.g., IgE_p001)
- **Full data preservation**: Both channels maintained throughout pipeline

#### 📊 Advanced Normalization Options
- **Intra-sample methods**: Z-score (robust), Median Scaling
- **Inter-sample normalization**: Optional second-stage normalization
  - Robust scaling
  - Centering
  - Quantile (with warning)
- **Control-based Z-score**: Uses user-selected negative controls

#### 📝 Interactive Metadata Management
- **File upload**: .csv and .xlsx support
- **Interactive preview**: Search, filter, and browse
- **Editable table**: Click cells to modify values
- **Apply/Revert**: Save or discard changes
- **Column selectors**: Choose sample ID and target variable
- **Validation**: Ensures sample ID matching

#### 📥 Enhanced Data Export
- **Multi-sheet Excel workbook**:
  - Expression data (dual-channel)
  - Clinical metadata (with user edits)
  - Processing log (complete parameter record)
- **Comprehensive documentation**: All analysis parameters preserved

---

### Core Functions Added

#### `R/server/data_processing.R`

**New Functions:**
1. `detect_genepix_header(file_path)`
   - Automatically finds header row in GenePix files
   - No more hardcoded skip values

2. `clean_analyte_ids(ids)`
   - Standardizes analyte identifiers
   - Ensures uniqueness
   - Removes special characters

3. `normalize_channel(expression, ids, method, negative_controls)`
   - Channel-independent normalization
   - User-configurable controls
   - Z-score and Median Scaling support

4. `get_unique_analytes(file_paths)`
   - Extracts unique analyte IDs
   - Populates UI control selectors

5. `validate_processed_matrix(file_path)`
   - Validates uploaded matrices
   - Returns validation status and messages

**Updated Functions:**
1. `read_microarray_file()`
   - Auto-detects GenePix header
   - Cleans analyte IDs
   - Returns dual-channel data

2. `process_microarray_batch()`
   - Accepts negative_controls parameter
   - Accepts channel_labels parameter
   - Normalizes channels independently
   - Adds channel prefixes to output

3. `normalize_expression()` (Legacy)
   - Updated to use normalize_channel()
   - Maintains backward compatibility

---

### UI Components Added

#### `R/ui/ui_preprocess.R`

**New Components:**
1. Input mode selector (radio buttons)
2. Channel label text inputs
3. Negative controls multi-select
4. Positive controls multi-select  
5. Inter-sample normalization controls
6. Matrix validation status display
7. Metadata column selectors
8. Editable metadata table (rhandsontable)
9. Apply/Revert metadata buttons

**Updated Components:**
1. Conditional panels for RAW vs. Processed modes
2. Enhanced normalization settings section
3. Improved download button with multi-sheet support

---

### Server Logic Updates

#### `app.R`

**New Reactive Values:**
- `available_analytes()`: Stores unique IDs from RAW files
- `database_edited()`: Stores user metadata edits

**New Observers:**
1. Analyte ID extraction on folder selection
2. Processed matrix validation on upload
3. Metadata table rendering
4. Apply metadata edits handler
5. Revert metadata edits handler

**Updated Observers:**
1. Process button - supports dual-channel processing
2. Database upload - supports .csv and .xlsx
3. Download handler - creates multi-sheet workbook
4. Example data loaders - initialize metadata editing

**Updated Reactives:**
1. `pepdata()` - simplified to use processed_data() from both modes

---

### Dependencies Added

#### `R/global.R`
- **rhandsontable**: Interactive editable tables for metadata

---

### File Structure Changes

```
MicroarrAI/
├── R/
│   ├── server/
│   │   └── data_processing.R          [UPDATED]
│   ├── ui/
│   │   └── ui_preprocess.R            [UPDATED]
│   └── global.R                        [UPDATED]
├── app.R                               [UPDATED]
└── docs/
    ├── preprocessing_pipeline_update.md [NEW]
    ├── preprocessing_quick_start.md     [NEW]
    └── CHANGELOG.md                     [NEW]
```

---

### Breaking Changes

**None!** This update is fully backward compatible.

- Existing code using `process_microarray_batch()` still works
- Default parameters maintain old behavior
- Legacy `normalize_expression()` function preserved
- Downstream tabs (Peptide, ML, Viz) unchanged
- Example data generation unchanged

---

### Bug Fixes

1. **Fixed hardcoded PBS assumption**: Z-score normalization now uses user-selected controls
2. **Fixed hardcoded skip value**: GenePix header now auto-detected
3. **Fixed ID inconsistencies**: All IDs now cleaned and standardized
4. **Fixed single-channel limitation**: Now supports dual-channel processing

---

### Performance Improvements

1. **Efficient ID cleaning**: Vectorized operations
2. **Parallel-safe functions**: All core functions are pure
3. **Minimal memory overhead**: Progressive processing of large batches
4. **Optimized pivoting**: Uses tidyr for efficient wide format conversion

---

### Documentation Added

1. **Technical Documentation** (`preprocessing_pipeline_update.md`):
   - Complete feature description
   - Function reference
   - Data flow diagrams
   - Testing recommendations

2. **User Guide** (`preprocessing_quick_start.md`):
   - Step-by-step instructions
   - RAW data workflow
   - Processed matrix workflow
   - Troubleshooting guide
   - Tips for best results

3. **Changelog** (this file):
   - Version history
   - Feature summary
   - Migration guide

---

### Testing Recommendations

#### Unit Testing
- [ ] Test `detect_genepix_header()` with various file formats
- [ ] Test `clean_analyte_ids()` with edge cases
- [ ] Test `normalize_channel()` with different control sets
- [ ] Test `validate_processed_matrix()` with invalid inputs

#### Integration Testing
- [ ] Process RAW GenePix files end-to-end
- [ ] Upload processed matrix and verify downstream compatibility
- [ ] Edit metadata and verify changes persist
- [ ] Download multi-sheet workbook and verify content

#### UI Testing
- [ ] Toggle between RAW and Processed modes
- [ ] Select various negative controls
- [ ] Enable/disable inter-sample normalization
- [ ] Edit and revert metadata
- [ ] Navigate to downstream tabs

---

### Known Limitations

1. **Quantile normalization**: May alter biological signal distribution
2. **No batch correction**: Multi-batch experiments need external tools
3. **No missing value imputation**: NA values must be handled beforehand
4. **Single file validation**: Processed matrices validated individually

---

### Future Enhancements (Roadmap)

#### High Priority
- [ ] QC metrics dashboard (control statistics, signal distribution)
- [ ] Sample correlation heatmap
- [ ] Batch effect detection and correction
- [ ] Export to additional formats (.rds, .h5)

#### Medium Priority
- [ ] Alternative background subtraction methods
- [ ] Channel merging options (ratio, difference)
- [ ] Missing value imputation
- [ ] Automated outlier detection

#### Low Priority
- [ ] Multi-batch processing
- [ ] Advanced QC plots
- [ ] Comparison to other normalization methods
- [ ] Automated report generation

---

### Migration Guide

#### For Existing Users

**No changes required!** Your existing workflows will continue to work.

**To use new features:**
1. Select "RAW microarray files" mode in Preprocess tab
2. Follow the new workflow as described in Quick Start guide
3. Enjoy enhanced flexibility and control

#### For Developers

**Function signatures changed:**
- `process_microarray_batch()`: Added optional parameters
  - `negative_controls` (default: "PBS_1X")
  - `channel_labels` (default: list(ch1="IgE", ch2="IgG4"))
  
**Backward compatible:** Old calls still work with defaults.

**New function available:**
- Use `normalize_channel()` for channel-independent normalization
- Use `get_unique_analytes()` to extract IDs from RAW files
- Use `validate_processed_matrix()` for upload validation

---

### Contributors

- **Implementation**: GitHub Copilot (Claude Sonnet 4.5)
- **Requirements**: User specifications
- **Testing**: Pending user validation
- **Documentation**: Complete

---

### References

- GenePix File Format: Standard microarray scanner output
- Robust Normalization: Median + MAD approach
- R Packages: tidyverse, rhandsontable, openxlsx

---

## Version History

### v2.0 (2025-12-30)
- Initial implementation of robust preprocessing pipeline
- Dual input mode support
- Interactive metadata editing
- Enhanced normalization options

### v1.x (Previous)
- Basic RAW file processing
- Hardcoded PBS controls
- Fixed skip values
- Single normalization method
