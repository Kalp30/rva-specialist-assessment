# -----------------------------------------------------------------------
# Question 2: AE Severity Visualization
# -----------------------------------------------------------------------
# The goal here is to make a clean, publication-quality bar chart that
# shows how adverse events are distributed across System Organ Classes
# (SOCs), broken down by severity (Mild, Moderate, Severe).
#
# The key rule: if the same subject had the same SOC flagged as both
# MILD and MODERATE (e.g., they had two different events), they get
# counted once per severity level — not once per event. This avoids
# inflating the numbers.
#
# The bars are horizontal (SOC on the Y-axis), stacked by severity,
# and sorted so the most affected SOC appears at the top.
# -----------------------------------------------------------------------

library(pharmaverseadam)   # our data source
library(tidyverse)         # data wrangling
library(ggplot2)           # the actual plotting


# -----------------------------------------------------------------------
# Step 1: Load the adverse event dataset
# -----------------------------------------------------------------------

adae <- pharmaverseadam::adae


# -----------------------------------------------------------------------
# Step 2: Clean and deduplicate the data
#
# We drop rows where severity or SOC is missing (can't plot those),
# then deduplicate to get one row per subject × SOC × severity combo.
# This ensures a subject is counted at most once per severity level
# within each SOC — exactly as the question requires.
# -----------------------------------------------------------------------

ae_dedup <- adae %>%
  filter(!is.na(AESEV), !is.na(AESOC)) %>%
  select(USUBJID, AESOC, AESEV) %>%
  distinct()


# -----------------------------------------------------------------------
# Step 3: Count unique subjects per SOC and severity
# -----------------------------------------------------------------------

ae_counts <- ae_dedup %>%
  count(AESOC, AESEV, name = "n_subjects")


# -----------------------------------------------------------------------
# Step 4: Determine the order for the Y-axis (SOC ordering)
#
# We want the SOC with the MOST subjects to appear at the TOP of the
# chart and the least frequent at the bottom. In ggplot horizontal bars,
# the factor order goes bottom-to-top, so we arrange ascending here and
# let ggplot flip it visually.
# -----------------------------------------------------------------------

soc_order <- ae_counts %>%
  group_by(AESOC) %>%
  summarise(total = sum(n_subjects), .groups = "drop") %>%
  arrange(total) %>%      # ascending → bottom of chart = least frequent
  pull(AESOC)

# Apply the ordering as a factor so ggplot respects it
ae_counts <- ae_counts %>%
  mutate(
    AESOC = factor(AESOC, levels = soc_order),
    # Order severity logically: Mild at the base of the stack, Severe at the tip
    AESEV = factor(AESEV, levels = c("MILD", "MODERATE", "SEVERE"))
  )


# -----------------------------------------------------------------------
# Step 5: Define the color palette
#
# Using a sequential red palette — light for Mild, dark for Severe.
# This is intuitive (darker = more serious) and works well in print too.
# -----------------------------------------------------------------------

severity_colors <- c(
  "MILD"     = "#FDDBC7",   # soft salmon — low concern
  "MODERATE" = "#D6604D",   # medium red-orange — moderate concern
  "SEVERE"   = "#A50026"    # deep red — high concern
)


# -----------------------------------------------------------------------
# Step 6: Build the plot
# -----------------------------------------------------------------------

p <- ggplot(ae_counts, aes(x = n_subjects, y = AESOC, fill = AESEV)) +

  # Stacked horizontal bars — width = 0.7 gives a bit of breathing room
  geom_col(position = "stack", width = 0.7, colour = "white", linewidth = 0.2) +

  # Apply our custom severity colors
  scale_fill_manual(
    values = severity_colors,
    name   = "Severity"
  ) +

  # X-axis starts at 0, with a little padding on the right for readability
  scale_x_continuous(
    expand = expansion(mult = c(0, 0.04)),
    breaks = scales::pretty_breaks(n = 6)
  ) +

  # Axis labels and title
  labs(
    title   = "Unique Subjects per SOC and Severity Level",
    x       = "Number of Unique Subjects",
    y       = "System Organ Class",
    caption = "Note: Each subject is counted at most once per severity level within each SOC.\nSource: pharmaverseadam::adae"
  ) +

  # Clean minimal theme as a base, then we customize below
  theme_minimal(base_size = 11) +
  theme(
    # Center and bold the title
    plot.title         = element_text(face = "bold", size = 13, hjust = 0.5,
                                      margin = margin(b = 10)),

    # Bold axis labels
    axis.title.x       = element_text(face = "bold", size = 10, margin = margin(t = 6)),
    axis.title.y       = element_text(face = "bold", size = 10, margin = margin(r = 6)),

    # Keep axis text readable but not oversized
    axis.text.y        = element_text(size = 8),
    axis.text.x        = element_text(size = 9),

    # Legend on the right — keeps chart area clean
    legend.position    = "right",
    legend.title       = element_text(face = "bold", size = 9),
    legend.text        = element_text(size = 9),

    # Only show vertical gridlines (they help read the X values)
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = "grey85", linewidth = 0.4),
    panel.grid.minor   = element_blank(),

    # Small caption at the bottom
    plot.caption       = element_text(size = 7, colour = "grey50", hjust = 0),

    # A bit of margin around the whole plot
    plot.margin        = margin(10, 15, 10, 10)
  )


# -----------------------------------------------------------------------
# Step 7: Save as a high-resolution PNG
# -----------------------------------------------------------------------

if (!dir.exists("question_2")) dir.create("question_2", recursive = TRUE)

ggsave(
  filename = "question_2/ae_severity_plot.png",
  plot     = p,
  width    = 12,
  height   = 8,
  dpi      = 300,       # 300 dpi = publication quality
  bg       = "white"    # white background (default is transparent in some themes)
)

message("Done! Chart saved to: question_2/ae_severity_plot.png")
