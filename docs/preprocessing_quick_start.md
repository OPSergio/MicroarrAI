# MicroarrAI Preprocessing - Quick Start Guide

## For Users Processing RAW GenePix Data

### Step-by-Step Instructions

#### 1. Prepare Your Data
- Organize GenePix CSV files in a single folder
- Ensure clinical metadata is in .csv or .xlsx format
- Clinical file should have an 'id' column matching sample names

#### 2. Select Input Mode
- Open MicroarrAI
- Go to **Preprocess** tab
- Select **"RAW microarray files (GenePix)"**

#### 3. Load Your RAW Data
- Click **"Select Folder"**
- Navigate to your GenePix CSV directory
- Click **Select Folder** to confirm

#### 4. Configure Channels
The system will automatically:
- Detect the GenePix header
- Extract unique analyte IDs
- Populate the control selectors

**Set channel labels:**
- Channel 1 Label: Enter your antibody (e.g., "IgE")
- Channel 2 Label: Enter your antibody (e.g., "IgG4")

#### 5. Select Negative Controls
- **Required!** Select at least one negative control
- Common examples: PBS_1X, Blank, Buffer
- You can select multiple controls
- These will be used for normalization

#### 6. (Optional) Select Positive Controls
- Used only for quality control
- Not required for normalization
- Helps verify assay performance

#### 7. Choose Normalization Method
**Intra-sample Normalization:**
- **Z-score** (Recommended): Robust, uses median and MAD of negative controls
- **Median Scaling**: Simple centering

**Inter-sample Normalization (Optional):**
- Check the box to enable
- **Robust Scaling**: Recommended for most cases
- **Centering**: Centers data across samples
- **Quantile**: Forces identical distributions (use with caution!)

#### 8. Upload Clinical Metadata
- Click **"Upload clinical database"**
- Select your .csv or .xlsx file
- The file will be validated and previewed

#### 9. Configure Metadata
- Select **Sample ID Column**: Column containing sample identifiers
- Select **Target Variable Column**: Your outcome/grouping variable
- **Edit metadata if needed**: Click on any cell to edit
- Click **"Apply Changes"** to save edits
- Click **"Revert Changes"** to undo

#### 10. Start Processing
- Click **"Start Normalization Process"**
- Progress bar will show processing status
- Wait for completion

#### 11. Review Results
- Check the **Expression Data Preview** table
- Review the **Density Plot** for quality check
- Look for unusual patterns or outliers

#### 12. Download Your Results
- Click **"Download Processed Data"**
- You'll get an Excel file with three sheets:
  1. **Expression_Data**: Normalized dual-channel data
  2. **Clinical_Metadata**: Your edited metadata
  3. **Processing_Log**: Parameters used for this run

---

## For Users Uploading Pre-Processed Data

### Step-by-Step Instructions

#### 1. Prepare Your Matrix
Your file should have:
- First column named 'id' with sample identifiers
- Remaining columns: numeric expression values
- Optional: Channel prefixes (e.g., IgE_peptide1, IgG4_peptide1)

#### 2. Select Input Mode
- Go to **Preprocess** tab
- Select **"Processed expression matrix"**

#### 3. Upload Your Matrix
- Click **"Upload processed matrix"**
- Select your .csv or .xlsx file
- System will validate your file
- Check the validation message

#### 4. Upload Clinical Metadata
- Click **"Upload clinical database"**
- Select your metadata file
- Configure columns as described above

#### 5. Edit and Download
- Edit metadata if needed
- Click **"Download Processed Data"**
- Ready to use in Peptide and ML tabs!

---

## Example Data

### Load Example Data to Test
1. Click **"Load example clinical Data"**
2. Click **"Load sample peptide Data"**
3. Explore the interface with synthetic data

---

## Common Issues and Solutions

### "Please select at least one negative control"
- **Solution**: You must select at least one control before processing
- Click on the **Negative Controls** dropdown and select your controls

### "No negative controls found in data"
- **Solution**: The control IDs you selected don't match the data
- Check that your control names match exactly (after cleaning)
- IDs are cleaned: spaces→underscores, special chars removed

### "Missing 'id' column"
- **Solution**: For processed matrices, ensure first column is named 'id'
- Rename in Excel/CSV before uploading

### Validation Failed
- **Solution**: Check that your matrix has:
  - An 'id' column
  - At least one numeric column
  - No completely empty rows

---

## Tips for Best Results

### RAW Data Processing
1. **Use multiple negative controls**: More robust normalization
2. **Name samples consistently**: Makes downstream analysis easier
3. **Check density plots**: Should show similar distributions
4. **Use Z-score normalization**: More robust than median scaling

### Metadata Management
1. **Clean your data first**: Remove typos before uploading
2. **Use consistent naming**: Match sample IDs exactly
3. **Save your edits**: Click "Apply Changes" before downloading
4. **Document changes**: Keep notes on edits made

### Quality Control
1. **Review density plots**: Look for outliers
2. **Check negative controls**: Should have low variance
3. **Verify sample counts**: Match between expression and metadata
4. **Save processing log**: Documents your analysis parameters

---

## Next Steps

After preprocessing:
1. Navigate to **Peptide** tab for summary statistics
2. Use **ML** tab for supervised/unsupervised learning
3. Create visualizations in **Visualization** tabs
4. Export results for publication

---

## Need Help?

- Check the density plot for data quality
- Review the processing log for parameters used
- Ensure sample IDs match between expression and metadata
- Try example data first to learn the interface

## Technical Support

For technical issues or questions:
- Check documentation in `docs/` folder
- Review `preprocessing_pipeline_update.md` for detailed information
- Contact: Sergio Olmos Piñero, Val Fernández Lanza
