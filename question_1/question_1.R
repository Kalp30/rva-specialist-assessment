# -----------------------------------------------------------------------
# Question 1: Treatment-Emergent Adverse Events (TEAE) Summary Table
# -----------------------------------------------------------------------
# The goal here is to produce a clean, regulatory-style summary table
# that shows how many subjects experienced adverse events across the
# different treatment arms. This is the kind of table you'd typically
# see in a clinical study report (CSR).
#
# What this script does, in plain English:
#   1. Loads the adverse event (ADAE) and subject-level (ADSL) datasets
#   2. Keeps only treatment-emergent AEs (TRTEMFL == "Y")
#   3. Makes sure each subject is counted only ONCE per Preferred Term
#      within each System Organ Class — no double counting
#   4. Pulls the total number of subjects per arm from ADSL (not ADAE)
#      because that's the correct denominator for percentages
#   5. Builds the table: Overall row on top, then SOC rows (bold),
#      then Preferred Term rows (indented) underneath each SOC
#   6. Saves it as an HTML file
# -----------------------------------------------------------------------

library(pharmaverseadam)   # gives us the ADAE and ADSL datasets
library(tidyverse)         # for all the data wrangling (dplyr, tidyr, etc.)
library(gtsummary)         # great for clinical summary tables
library(gt)                # used under the hood by gtsummary for rendering


# -----------------------------------------------------------------------
# Step 1: Load the datasets
# -----------------------------------------------------------------------

adae <- pharmaverseadam::adae    # one row per adverse event per subject
adsl <- pharmaverseadam::adsl    # one row per subject (the "spine" of the trial)


# -----------------------------------------------------------------------
# Step 2: Figure out the denominators from ADSL
#
# This is important — we want to know how many subjects were in each
# treatment arm overall, not just those who had AEs. That way, if
# someone had NO adverse events, they still count in the denominator.
# -----------------------------------------------------------------------

arm_n <- adsl %>%
  count(ACTARM, name = "N") %>%
  arrange(ACTARM)

# Turn it into a simple named vector so it's easy to look up: arm -> N
denom     <- setNames(arm_n$N, arm_n$ACTARM)
arm_levels <- arm_n$ACTARM   # we'll use this to keep arm columns in order


# -----------------------------------------------------------------------
# Step 3: Filter to TEAEs and remove duplicate subject-event combos
#
# We only want Treatment-Emergent AEs (TRTEMFL == "Y").
# Then we deduplicate so that if the same subject had the same PT
# in the same SOC multiple times, they're only counted once.
# -----------------------------------------------------------------------

teae <- adae %>%
  filter(TRTEMFL == "Y") %>%
  select(USUBJID, ACTARM, AESOC, AEDECOD) %>%
  distinct()   # this is the deduplication step


# -----------------------------------------------------------------------
# Step 4: A helper function to format counts as "n (x%)"
#
# This is what you see in clinical tables: 12 (14%) means 12 subjects,
# which is 14% of the total arm population.
# -----------------------------------------------------------------------

fmt_cell <- function(n, arm_denom) {
  pct <- round(n / arm_denom * 100, 1)
  paste0(n, " (", pct, "%)")
}


# -----------------------------------------------------------------------
# Step 5: Count subjects and pivot to wide format (one col per arm)
#
# This helper does the heavy lifting:
#   - counts unique subjects for a given grouping
#   - fills in zeros where a combo has no events (important!)
#   - pivots wide so each arm becomes its own column
#   - formats each cell as "n (x%)"
# -----------------------------------------------------------------------

count_wide <- function(data, group_vars) {
  data %>%
    select(all_of(c("USUBJID", "ACTARM", group_vars))) %>%
    distinct() %>%
    count(ACTARM, across(all_of(group_vars)), name = "n") %>%
    # complete() fills in the zero counts — crucial for arms with no events
    complete(
      ACTARM = arm_levels,
      !!!setNames(lapply(group_vars, function(v) unique(data[[v]])), group_vars),
      fill = list(n = 0L)
    ) %>%
    pivot_wider(names_from = ACTARM, values_from = n, values_fill = 0L) %>%
    mutate(
      across(
        all_of(arm_levels),
        ~ fmt_cell(.x, denom[cur_column()]),
        .names = "{.col}_disp"   # creates display columns like "Placebo_disp"
      )
    )
}


# -----------------------------------------------------------------------
# Step 6: Build the three types of rows for our table
# -----------------------------------------------------------------------

# --- Row type A: The overall "any TEAE" summary row (goes at the top) ---
# Count subjects who had at least one TEAE, regardless of SOC or PT
overall_w <- teae %>%
  select(USUBJID, ACTARM) %>%
  distinct() %>%
  count(ACTARM, name = "n") %>%
  complete(ACTARM = arm_levels, fill = list(n = 0L)) %>%
  pivot_wider(names_from = ACTARM, values_from = n, values_fill = 0L) %>%
  mutate(
    across(all_of(arm_levels), ~ fmt_cell(.x, denom[cur_column()]), .names = "{.col}_disp"),
    AESOC    = "Treatment Emergent Adverse Events",
    AEDECOD  = NA_character_,
    indent   = FALSE,
    sort_key = 0   # sort_key = 0 means this row always stays at position 1
  )

# --- Row type B: System Organ Class (SOC) summary rows ---
soc_w <- count_wide(teae, "AESOC") %>%
  mutate(AEDECOD = NA_character_, indent = FALSE)

# Work out the order of SOCs — we want most frequent at the top
soc_totals <- teae %>%
  select(USUBJID, AESOC) %>%
  distinct() %>%
  count(AESOC, name = "total") %>%
  arrange(desc(total)) %>%
  mutate(sort_key = row_number() * 100)   # multiply by 100 to leave room for PTs

soc_w <- soc_w %>% left_join(soc_totals, by = "AESOC")

# --- Row type C: Preferred Term (PT) rows, nested under each SOC ---
pt_w <- count_wide(teae, c("AESOC", "AEDECOD")) %>%
  mutate(indent = TRUE) %>%
  left_join(soc_totals %>% select(AESOC, sort_key), by = "AESOC") %>%
  arrange(AESOC, AEDECOD) %>%
  group_by(AESOC) %>%
  mutate(sort_key = sort_key + row_number()) %>%   # PTs sit just after their SOC
  ungroup()


# -----------------------------------------------------------------------
# Step 7: Stack all three row types into one final table
# -----------------------------------------------------------------------

disp_cols <- paste0(arm_levels, "_disp")   # the formatted "n (%)" columns

# Small helper to pull the right label column for each row type
bind_display <- function(df, label_col) {
  df %>%
    mutate(label = .data[[label_col]]) %>%
    select(label, indent, sort_key, all_of(disp_cols))
}

final_tbl <- bind_rows(
  overall_w %>% mutate(label = AESOC) %>% select(label, indent, sort_key, all_of(disp_cols)),
  bind_display(soc_w, "AESOC"),
  bind_display(pt_w,  "AEDECOD")
) %>%
  arrange(sort_key)   # this puts everything in the right order


# -----------------------------------------------------------------------
# Step 8: Render the table with {gt} and apply clinical styling
# -----------------------------------------------------------------------

# Build the column header labels with the arm name and N underneath
col_labels <- setNames(
  lapply(arm_levels, function(arm) {
    md(paste0("**", arm, "**  \nN = ", denom[[arm]]))
  }),
  disp_cols
)

gt_tbl <- final_tbl %>%
  select(-indent, -sort_key) %>%   # these were just helpers, don't show them
  gt() %>%

  # Title and subtitle
  tab_header(
    title    = md("**Treatment Emergent Adverse Events (TEAEs)**"),
    subtitle = "n (%) based on total subjects per arm in ADSL"
  ) %>%

  # Column headers
  cols_label(
    label = md("**System Organ Class / Preferred Term**"),
    !!!col_labels
  ) %>%

  # Indent the PT rows so they look nested under the SOC
  tab_style(
    style     = cell_text(indent = px(20), size = "small"),
    locations = cells_body(rows = final_tbl$indent == TRUE)
  ) %>%

  # Bold the SOC rows so they stand out
  tab_style(
    style     = cell_text(weight = "bold"),
    locations = cells_body(rows = final_tbl$indent == FALSE & final_tbl$sort_key > 0)
  ) %>%

  # Give the top "overall TEAE" row a light blue background to make it pop
  tab_style(
    style     = list(cell_fill(color = "#dce8f7"), cell_text(weight = "bold")),
    locations = cells_body(rows = 1)
  ) %>%

  # General table styling — clean and readable
  tab_options(
    table.font.size         = px(12),
    column_labels.font.size = px(12),
    data_row.padding        = px(3),
    table.border.top.style  = "solid",
    table.border.top.width  = px(2),
    table.border.top.color  = "black"
  ) %>%
  opt_table_font(font = google_font("Source Sans Pro"))


# -----------------------------------------------------------------------
# Step 9: Save the output as an HTML file
# -----------------------------------------------------------------------

# Make sure the output folder exists before saving
if (!dir.exists("question_1")) dir.create("question_1", recursive = TRUE)

gtsave(gt_tbl, "question_1/teae_summary_table.html")
message("Done! Table saved to: question_1/teae_summary_table.html")
