# RVA Specialist Coding Assessment — Roche PD Data Science & Analytics

**Candidate:** Kalp  
**Submitted:** March 2026  
**R Version Required:** 4.2.0 or above

---

## Repository Structure

```
rva-specialist-assessment/
│
├── README.md                        ← You are here — start here!
│
├── question_1/
│   ├── question_1.R                 ← TEAE Summary Table script
│   └── teae_summary_table.html     ← Output (generated when you run the script)
│
├── question_2/
│   ├── question_2.R                 ← AE Severity Bar Chart script
│   └── ae_severity_plot.png        ← Output (generated when you run the script)
│
└── question_3/
    └── question_3.R                 ← Interactive Shiny Dashboard (run to launch)
```

---

## How to Set Up and Run

### Step 1 — Install required packages (do this once)

Open R or RStudio and run:

```r
install.packages(c("pharmaverseadam", "tidyverse", "gtsummary", "ggplot2", "shiny", "gt"))
```

---

### Step 2 — Set your working directory to this folder

**In RStudio:** Session → Set Working Directory → Choose Directory → select this folder  
**Or in the console:**

```r
setwd("/path/to/rva-specialist-assessment")
```

---

### Step 3 — Run Question 1 (TEAE Table → HTML)

```r
source("question_1/question_1.R")
```

Output: `question_1/teae_summary_table.html`  
Open the HTML file in any browser to view the formatted clinical table.

---

### Step 4 — Run Question 2 (AE Bar Chart → PNG)

```r
source("question_2/question_2.R")
```

Output: `question_2/ae_severity_plot.png`  
Open the PNG to see the publication-quality bar chart.

---

### Step 5 — Run Question 3 (Shiny Dashboard)

```r
shiny::runApp("question_3/question_3.R")
```

This launches the interactive dashboard in your browser.  
Use the checkboxes on the left to filter by Treatment Arm.

---

## What Each Question Does

### Question 1 — TEAE Summary Table
- Loads `adae` and `adsl` from `{pharmaverseadam}`
- Filters to treatment-emergent AEs (`TRTEMFL == "Y"`)
- De-duplicates so each subject is counted once per Preferred Term per SOC
- Uses ADSL (not ADAE) as the denominator — includes subjects with zero AEs
- Builds a nested table: Overall row → SOC rows (bold) → PT rows (indented)
- SOCs are sorted by descending frequency; PTs are alphabetical within SOC
- Rendered with `{gt}` and saved as HTML

### Question 2 — AE Severity Bar Chart
- Loads `adae` from `{pharmaverseadam}`
- De-duplicates to one record per subject × SOC × severity
- Counts unique subjects per SOC per severity level
- Orders SOCs by increasing total (least frequent at the bottom of the chart)
- Uses a sequential red palette: light = Mild, dark = Severe
- Saved as a 300 dpi PNG (publication quality)

### Question 3 — Interactive Shiny Dashboard
- Embeds the same bar chart from Question 2 inside a Shiny app
- Left sidebar has a `checkboxGroupInput` to filter by Treatment Arm (`ACTARM`)
- "Select All" and "Clear All" buttons for convenience
- Chart re-orders SOCs dynamically based on the filtered subset (not just the full dataset)
- Friendly warning shown if no arm is selected
- Data preparation happens outside the reactive context for better performance
