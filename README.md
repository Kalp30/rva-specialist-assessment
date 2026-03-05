# RVA Specialist Coding Assessment

**Candidate:** Kalp Kalani
**Submitted:** March 2026  
**R Version:** 4.2.0 or above

---

## A bit of context

This repo has my solutions for the three-part coding assessment. The work covers clinical data wrangling, building a regulatory-style AE summary table, creating a publication-ready visualization, and putting it all together in an interactive Shiny dashboard. All three questions use the `pharmaverseadam` package as the data source.

I've kept each question in its own folder so things stay organized and easy to navigate.

---

## Folder layout

```
rva-specialist-assessment/
│
├── README.md
│
├── question_1/
│   ├── question_1.R
│   └── teae_summary_table.html
│
├── question_2/
│   ├── question_2.R
│   └── ae_severity_plot.png
│
└── question_3/
    └── question_3.R
```

---

## How I ran this locally

**Packages you'll need**

Everything runs on six packages. I have used the below command so that it installs all of them in one go:

```r
install.packages(c("pharmaverseadam", "tidyverse", "gtsummary", "ggplot2", "shiny", "gt"))
```

**Working directory**

I made sure that R is pointed at the root of this repo before running anything. In RStudio that's Session → Set Working Directory → Choose Directory. Or in the console:

```r
setwd("/path/to/rva-specialist-assessment")
```

**Question 1**

```r
source("question_1/question_1.R")
```

Produces `teae_summary_table.html` inside the question_1 folder. I opened the output in a browser.

**Question 2**

```r
source("question_2/question_2.R")
```

Produces `ae_severity_plot.png` inside the question_2 folder.

**Question 3**

```r
shiny::runApp("question_3/question_3.R")
```

This opened the dashboard in my browser. The checkboxes on the left let me cut the chart by Treatment Arm, the plot re-renders automatically as I change the selection.

---

## My approach to each question

### Question 1 — TEAE Summary Table

The main challenge here was getting the structure right, this is the kind of nested SOC/PT table you'd expect to see in an actual CSR, so the details matter.

The denominator comes from ADSL rather than ADAE. That's intentional, using ADAE would exclude subjects who had no adverse events at all, which would quietly inflate every percentage in the table. ADSL gives the true enrolled population per arm.

I also deduplicated carefully before counting. If the same subject had the same Preferred Term flagged multiple times within a SOC, they get counted once — not once per occurrence. The table then builds up as an overall TEAE row at the top, SOC rows below it in bold (ordered by how frequently they appear), and the individual PTs indented underneath each SOC alphabetically.

The whole thing renders through `{gt}` and saves as a standalone HTML file.

### Question 2 — AE Severity Bar Chart

The deduplication logic here mirrors Question 1, one record per subject per SOC per severity level, so nobody gets counted twice just because they had two MILD events in the same SOC.

For the ordering I went with ascending total subject count, which puts the most affected SOC at the top of the horizontal chart. The severity color scale runs light to dark red (Mild → Moderate → Severe) which felt like the most natural mapping — darker meaning more serious. It also holds up reasonably well if someone prints it in greyscale.

Output is saved at 300 dpi so it's genuinely usable in a report or slide deck without looking pixelated.

### Question 3 — Interactive Shiny Dashboard

The app embeds the same chart from Question 2 but lets the user slice it by Treatment Arm using a checkbox group on the left.

One thing I was deliberate about: the data cleaning and deduplication runs once when the app loads, outside the reactive layer. If that logic sat inside a reactive expression it would re-run on every filter change, which is unnecessary and slows things down. Keeping it outside means the app stays snappy even if someone is rapidly clicking through different arm combinations.

The SOC ordering also recalculates on every filter change based on the filtered data, not the full dataset. That way the chart always reflects the actual frequencies for whatever cohort is currently selected.

I added Select All and Clear All buttons because clicking through six checkboxes individually to reset a view gets old fast. If someone deselects everything, a warning appears in place of the chart rather than just showing a blank or throwing an error.

---

## A couple of notes on the outputs

The HTML file for Question 1 might show a "file too large to preview" message on GitHub, that's just a GitHub rendering limitation and doesn't mean anything is wrong with the file. Download it and open it locally and it'll display fine.

For Question 3 there's no output file to commit, the script itself is the deliverable. Run it with `shiny::runApp("question_3/question_3.R")` and the dashboard comes up in the browser.
