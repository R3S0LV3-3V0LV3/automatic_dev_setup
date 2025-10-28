# Data Analysis Notebook Template

This Jupyter notebook starter bundles the boilerplate you need for exploratory data analysis:

- Imports for pandas, numpy, seaborn, and matplotlib
- Reusable utilities for plotting and profiling datasets
- Markdown cells that document objectives, dataset assumptions, and findings

## Usage
1. Create and activate a virtual environment (see `__project-formatting.txt` for guidance).
2. Install the scientific stack:
   ```bash
   pip install -r requirements.txt  # craft one for your project
   ```
3. Launch Jupyter Lab or VS Code:
   ```bash
   jupyter lab
   ```
4. Duplicate `analysis-notebook.ipynb`, rename it for your dataset, and start exploring.

## Tips
- Keep raw data outside the repository; commit only small, anonymised samples or synthetic fixtures.
- Snapshot conclusions in Markdown sections so collaborators can skim findings quickly.
- Export charts to `reports/figures/` (tracked in git) when ready to share.
